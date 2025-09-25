//+------------------------------------------------------------------+
//| aegis_planning.mqh                                               |
//| Структуры и функции планирования уровней Фибо                    |
//+------------------------------------------------------------------+
#pragma once

//================= Структуры планирования =========================
struct FiboLevels {
  double e1618,e2618,e3618,e4236, t0786,t1618,t0382,t0000,t0886;
  double baseStart,baseEnd;
  bool ok;
};

struct PlannedLevel {
  int idx;
  bool isLong;
  double price, sl, tp, lots, riskMoney;
  bool head;
};

// Глобальные переменные планирования
PlannedLevel Plans[4][5];
int PlansCount[4];
FiboLevels LastLeftImpulse[4];
bool LastLeftValid[4] = {false,false,false,false};

//================= Функции планирования =============================
void PlansReset(int idx){ PlansCount[idx]=0; }
void PlansAdd(int idx, const PlannedLevel &pl){ int c=PlansCount[idx]; if(c>=5) return; Plans[idx][c]=pl; PlansCount[idx]=c+1; }

bool DetectImpulse(const string s, FiboLevels &fl)
{
   // По телам: берём первое и последнее «значимые» тела (порог оставляем минимальным для цикличности)
   int bars=40; double bodyStart=0, bodyEnd=0; int shiftStart=-1, shiftEnd=-1;
   for(int i=bars;i>=1;i--){
      double o=iOpen(s,GridTF_Default,i), c=iClose(s,GridTF_Default,i);
      double body=MathAbs(c-o);
      if(shiftStart==-1 && body>Pt(s)*100){ bodyStart=o; shiftStart=i; }
      if(bodyStart>0 && body>Pt(s)*100){ bodyEnd=c; shiftEnd=i; }
   }
   if(shiftStart==-1 || shiftEnd==-1 || bodyStart==bodyEnd) return false;

   double e1=bodyStart, e2=bodyEnd, t1=bodyEnd, t2=bodyStart;
   fl.e1618 = e1 + (e2-e1)*1.618;
   fl.e2618 = e1 + (e2-e1)*2.618;
   fl.e3618 = e1 + (e2-e1)*3.618;
   fl.e4236 = e1 + (e2-e1)*4.236;
   fl.t0786 = t1 + (t2-t1)*0.786;
   fl.t1618 = t1 + (t2-t1)*1.618;
   fl.t0382 = t1 + (t2-t1)*0.382;
   fl.t0000 = t1 + (t2-t1)*0.0;
   fl.t0886 = t1 + (t2-t1)*0.886;
   fl.baseStart=e1; fl.baseEnd=e2; fl.ok=true;
   return true;
}

bool IsLongScenario(const FiboLevels &fl){ return (fl.t1618 > fl.e1618); }

// Построение основного плана (с масштабированием вниз, без нарушения 1:1:2:4)
bool BuildMainLevels(const string &s, const FiboLevels &fl, int symIdx, const RiskSnapshot &rs)
{
   PlansReset(symIdx);
   bool isLong = IsLongScenario(fl);
   double avg = (fl.e1618*WEIGHTS[0]+fl.e2618*WEIGHTS[1]+fl.e3618*WEIGHTS[2]+fl.e4236*WEIGHTS[3])/WEIGHTS_SUM;
   double step = MathAbs(fl.e4236 - fl.e3618);
   double sl   = isLong ? (fl.e4236 - step) : (fl.e1618 + step);
   double dP   = MathAbs(avg - sl);
   if(dP<=0){ LogAudit("[ПЛАН][FAIL] dP=0"); return false; }

   double freeDaily = rs.workableDynamic - rs.totalUsed;
   if(freeDaily<=0){ LogAudit("[ПЛАН][DENY] нет свободного дневного риска"); return false; }
   double symCap = MathMin(rs.symbolCapRaw, freeDaily);

   // Суммарный лот по риску
   double lotTotalRaw = symCap / MathMax(1e-9, MoneyLossPerLot(s,dP));
   double lotTotal = RoundLots(s, lotTotalRaw);
   if(lotTotal<=0){ LogAudit("[ПЛАН][DENY] lotTotal=0"); return false; }

   // База и веса
   double base = lotTotal/WEIGHTS_SUM;
   double lots[4];
   for(int k=0;k<4;k++) lots[k]=RoundLots(s, base*WEIGHTS[k]);

   double lprice[4] = {fl.e1618, fl.e2618, fl.e3618, fl.e4236};
   double tp1 = fl.t0786;

   // Заполняем уровни
   for(int k=0;k<4;k++){
      PlannedLevel pl;
      pl.idx=k+1; pl.isLong=isLong; pl.price=lprice[k];
      pl.sl=sl; pl.tp=tp1; pl.lots=lots[k];
      pl.riskMoney = MoneyLossPerLot(s, MathAbs(pl.price - pl.sl))*pl.lots;
      pl.head=(k==0);
      PlansAdd(symIdx, pl);
   }
   LogAudit("[ПЛАН][OK] "+s+" L1="+DoubleToString(lprice[0],Dg(s))+" lotsTotal="+DoubleToString(lotTotal,2));
   return true;
}