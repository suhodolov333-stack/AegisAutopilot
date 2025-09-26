#pragma once
#include "aegis_utils.mqh"
#include "aegis_logging.mqh"
#include "aegis_constants.mqh"
#include "aegis_risk.mqh"

// Fibo и план уровней (перенос структур)
struct AEG_Fibo {
  double e1618,e2618,e3618,e4236;
  double t0786,t1618,t0382,t0000,t0886;
  double baseStart,baseEnd;
  bool   ok;
};
struct AEG_PlannedLevel {
  int idx;
  bool isLong;
  double price, sl, tp, lots, riskMoney;
  bool head;
};

AEG_PlannedLevel AEG_Plans[AEG_MAX_SYMS][AEG_MAX_LVLS];
int AEG_PlansCount[AEG_MAX_SYMS];

void AEG_PlansReset(int si){ AEG_PlansCount[si]=0; }
void AEG_PlansAdd(int si,const AEG_PlannedLevel &pl){
  int c=AEG_PlansCount[si]; if(c>=AEG_MAX_LVLS) return;
  AEG_Plans[si][c]=pl; AEG_PlansCount[si]=c+1;
}

bool AEG_IsLongScenario(const AEG_Fibo &fl){ return (fl.e4236 > fl.e1618); }

// DetectImpulse (перенос, логика не изменена: поиск значимых тел)
bool AEG_DetectImpulse(const string s, AEG_Fibo &fl)
{
   int bars=40; double bodyStart=0, bodyEnd=0; int shiftStart=-1, shiftEnd=-1;
   for(int i=bars;i>=1;i--){
      double o=iOpen(s,PERIOD_H4,i), c=iClose(s,PERIOD_H4,i); // PERIOD_H4 как в исходнике (TODO конфиг)
      double body=MathAbs(c-o);
      if(shiftStart==-1 && body>AEG_Pt(s)*AEG_BODY_THRESHOLD_MULT){ bodyStart=o; shiftStart=i; }
      if(bodyStart>0 && body>AEG_Pt(s)*AEG_BODY_THRESHOLD_MULT){ bodyEnd=c; shiftEnd=i; }
   }
   if(shiftStart==-1 || shiftEnd==-1){ AEG_Log("[IMPULSE][MISS] "+s); return false; }
   fl.baseStart=bodyStart; fl.baseEnd=bodyEnd;
   double dir = (bodyEnd > bodyStart ? +1.0 : -1.0);
   double span = MathAbs(bodyEnd - bodyStart);
   fl.e1618 = bodyStart + dir*span*1.618;
   fl.e2618 = bodyStart + dir*span*2.618;
   fl.e3618 = bodyStart + dir*span*3.618;
   fl.e4236 = bodyStart + dir*span*4.236;
   fl.t0786 = bodyStart + dir*span*0.786;
   fl.t1618 = bodyStart + dir*span*1.618;
   fl.t0382 = bodyStart + dir*span*0.382;
   fl.t0000 = bodyStart;
   fl.t0886 = bodyStart + dir*span*0.886;
   fl.ok=true;
   AEG_Log("[IMPULSE][OK] "+s+" span="+DoubleToString(span,2));
   return true;
}

// BuildMainLevels (перенос, формулы сохранены)
bool AEG_BuildMainLevels(const string &s, const AEG_Fibo &fl, int symIdx, const AEG_RiskSnapshot &rs)
{
   AEG_PlansReset(symIdx);
   bool isLong = AEG_IsLongScenario(fl);
   double avg = (fl.e1618*AEG_WEIGHTS[0]+fl.e2618*AEG_WEIGHTS[1]+fl.e3618*AEG_WEIGHTS[2]+fl.e4236*AEG_WEIGHTS[3])/AEG_WEIGHTS_SUM;
   double step = MathAbs(fl.e4236 - fl.e3618);
   double sl   = isLong ? (fl.e4236 - step) : (fl.e1618 + step);
   double dP   = MathAbs(avg - sl);
   if(dP<=0){ AEG_Log("[PLAN][FAIL] dP=0"); return false; }

   AEG_PlannedLevel L1;
   L1.idx=1; L1.isLong=isLong;
   L1.price = isLong ? fl.e1618 : fl.e4236;
   L1.sl = sl;
   L1.tp = isLong ? (L1.price + dP) : (L1.price - dP);
   L1.lots = 0.10;     // TODO: формула размера (оставлено как в переносе-шаблоне)
   L1.riskMoney = 0.0;
   L1.head = true;
   AEG_PlansAdd(symIdx,L1);

   AEG_Log("[PLAN][L1] "+s+" price="+DoubleToString(L1.price,AEG_Digits(s))+" tp="+DoubleToString(L1.tp,AEG_Digits(s)));
   return true;
}

// Размещение L1 (PlaceMainL1) — заглушка без реальных ордеров (нет CTrade тут)
bool AEG_PlaceMainL1(const string &s, const AEG_PlannedLevel &pl)
{
   if(AEG_GlobalAutoPause){ AEG_Log("[ORDER][BLOCK] AUTO_PAUSE "+s); return false; }
   if(pl.lots<=0) return false;
   if(!AEG_CheckMarginProjection(s, pl.isLong, pl.lots, pl.price)) return false;
   bool ok=true; // TODO: интегрировать CTrade
   if(ok) AEG_Log("[ORDER][PLACE] MAIN L1 "+s+" lots="+DoubleToString(pl.lots,2));
   else   AEG_Log("[ORDER][FAIL] MAIN L1 "+s);
   return ok;
}