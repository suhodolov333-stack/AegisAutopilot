0//+------------------------------------------------------------------+
//| LEGACY: Aegis S_Base_RiskSkeleton_v2                             |
//| *** ЭТОТ ФАЙЛ ОТМЕЧЕН КАК LEGACY И НЕ ИСПОЛЬЗУЕТСЯ ***            |
//| Внедрение Dual‑Armed режима: после выхода по TP (в т.ч. усредн.) |
//|  — строим две сетки (вверх/вниз), «вооружаем», ждём близости L1  |
//|  — активируем сторону, ставим L1, продолжаем цикл                |
//| Совместимо с:                                                    |
//|  - Геометрия по телам (без теней), веса 1:1:2:4                  |
//|  - Строгий риск/маржа (80% cap, авто‑пауза), перенос TP (SELL-спред)|
//|  - CT/усреднение (каркас сохранён; CT — по близости, отдельный)  |
//| Док‑опоры: Финальное ТЗ v4.0, "Что делает сейчас", Реализация v4.0|
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade Trade;

//================= Входные параметры (как в исходнике) ===============
input double DAILY_RISK_PCT       = 3.0;
input double RISK_BUFFER_PCT      = 5.0;
input double MAIN_CAP             = 1.9;
input double MARGIN_PCT           = 80.0;
input double CT_RATIO             = 0.5;
input bool   CT_Enable            = false;
input bool   TP_SplitEnable       = true;
input int    MaxActivePositions   = 4;
input ENUM_TIMEFRAMES GridTF_Default = PERIOD_M5;
input ENUM_TIMEFRAMES GridTF_News    = PERIOD_H4;
input double PORTFOLIO_RISK_PCT   = 6.0;

//================= Базовые массивы/константы =========================
string SYMS[4] = {"BTCUSD","LTCUSD","BCHUSD","ETHUSD"};
double WEIGHTS[4] = {1,1,2,4};
double WEIGHTS_SUM = 8.0;
long   MainMagic[4], CTMagic[4];

//================= FSM ===============================================
enum Phase { PH_IDLE=0, PH_SCANNING=1, PH_PENDING_L1=2, PH_ACTIVE=3, PH_DUAL_ARMED=4, PH_DIAG=5 };
Phase phases[4];

//================= Структуры сеток/состояний =========================
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
struct FlowState {
  bool main_tp1, main_tp2;
  bool ct_tp1, ct_tp2;
};
FlowState flow[4];
PlannedLevel Plans[4][5];
int PlansCount[4];
FiboLevels LastLeftImpulse[4];
bool LastLeftValid[4] = {false,false,false,false};

//================= Аудит =============================================
string auditLog[1200];
int auditLen=0;
void LogAudit(const string &msg){ if(auditLen<ArraySize(auditLog)) auditLog[auditLen++]=msg; Print(msg); }

//================= Утилиты ===========================================
double Eq(){ return AccountInfoDouble(ACCOUNT_EQUITY); }
double Bal(){ return AccountInfoDouble(ACCOUNT_BALANCE); }
double UsedMargin(){ return AccountInfoDouble(ACCOUNT_MARGIN); }
double Pt(const string &s){ return SymbolInfoDouble(s,SYMBOL_POINT); }
int Dg(const string &s){ return (int)SymbolInfoInteger(s,SYMBOL_DIGITS); }
int SymIndex(const string &s){ for(int i=0;i<4;i++) if(SYMS[i]==s) return i; return -1; }

//================= Риск / суточный цикл ==============================
struct RiskSnapshot {
   double realized;          // реализованный P/L дня
   double floating;          // плавающий P/L
   double swap;              // своп суммарный
   double totalUsed;         // использованный риск (|neg|)
   double baseDaily;         // базовый лимит дня
   double workableDynamic;   // рабочий лимит дня с расширением (профит/плавающий/своп+)
   double symbolCapRaw;      // лимит на символ (MAIN_CAP%)
   bool   autoPaused;        // авто‑пауза
};
double dailyStartEquity = 0.0;
double portfolioRiskBase = 0.0;
bool   portfolioRiskFixed = false;
datetime lastRiskReset = 0;
bool   globalAutoPause = false;

// Портфельная база и суточный reset (UTC-3)
double PortfolioRiskBudgetRaw(){ return (!portfolioRiskFixed? Bal():portfolioRiskBase) * (PORTFOLIO_RISK_PCT/100.0); }
void CheckPortfolioRiskBase(){ if(!portfolioRiskFixed && Eq()<Bal()){ portfolioRiskBase=Bal(); portfolioRiskFixed=true; LogAudit("[РИСК] База портфеля зафиксирована="+DoubleToString(portfolioRiskBase,2)); } }
long DayKeyUTCm3(datetime t){ return (long)((t - 3*3600)/86400); }
void DailyResetIfNeeded()
{
   static long lastKey=-1; long cur=DayKeyUTCm3(TimeCurrent());
   if(lastKey==-1) lastKey=cur;
   if(cur!=lastKey){
      lastRiskReset=TimeCurrent(); dailyStartEquity=Eq();
      globalAutoPause=false;
      // Очистка планов при отсутствии позиций
      bool anyPos=false; for(int i=0;i<4;i++) if(PositionSelect(SYMS[i])){ anyPos=true; break; }
      if(!anyPos){ for(int i=0;i<4;i++){ PlansCount[i]=0; phases[i]=PH_IDLE; flow[i].main_tp1=false; flow[i].main_tp2=false; } LogAudit("[РИСК] DAILY_RESET: планы очищены"); }
      auditLen=0; lastKey=cur; LogAudit("[РИСК] DAILY_RESET завершён (UTC-3)");
   }
}
RiskSnapshot GetRiskSnapshot(const string &sym)
{
   RiskSnapshot rs; rs.realized=rs.floating=rs.swap=rs.totalUsed=0; rs.autoPaused=globalAutoPause;
   rs.baseDaily = dailyStartEquity * (DAILY_RISK_PCT/100.0);

   HistorySelect(lastRiskReset, TimeCurrent());
   int deals=(int)HistoryDealsTotal();
   for(int i=0;i<deals;i++){
      ulong t=HistoryDealGetTicket(i); if(t==0) continue;
      if((int)HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_OUT){
         rs.realized += HistoryDealGetDouble(t, DEAL_PROFIT);
         rs.swap     += HistoryDealGetDouble(t, DEAL_SWAP);
      }
   }
   int ptotal=(int)PositionsTotal();
   for(int i=ptotal-1;i>=0;i--){
      if(!PositionSelectByIndex(i)) continue;
      rs.floating += PositionGetDouble(POSITION_PROFIT);
      rs.swap     += PositionGetDouble(POSITION_SWAP);
   }
   double posReal = (rs.realized>0? rs.realized:0.0);
   double posFloat= (rs.floating>0? rs.floating:0.0);
   double posSwap = (rs.swap>0? rs.swap:0.0);
   rs.workableDynamic = (rs.baseDaily + posReal + posFloat + posSwap) * (1.0 - RISK_BUFFER_PCT/100.0);

   double negReal = (rs.realized<0? -rs.realized:0.0);
   double negFloat= (rs.floating<0? -rs.floating:0.0);
   double negSwap = (rs.swap<0? -rs.swap:0.0);
   rs.totalUsed = negReal + negFloat + negSwap;

   rs.symbolCapRaw = PortfolioRiskBudgetRaw() * (MAIN_CAP/100.0);
   return rs;
}
void AutoPauseCheck(const RiskSnapshot &rs)
{
   if(!globalAutoPause && rs.totalUsed >= rs.workableDynamic){
      globalAutoPause=true;
      LogAudit("[РИСК][PAUSE] totalUsed="+DoubleToString(rs.totalUsed,2)+" >= workable="+DoubleToString(rs.workableDynamic,2));
   }
}

//================= Геометрия / планирование ==========================
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
double MoneyLossPerLot(const string &s, double dist)
{
   double tick_val = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
   double tick_sz  = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   if(tick_sz<=0) return 0.0;
   return MathAbs(dist)*(tick_val/tick_sz);
}
double RoundLots(const string &s, double lots)
{
   double step = SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
   if(step<=0) step=0.01;
   double r=MathFloor(lots/step)*step;
   return MathMax(minv, r);
}

// Риск‑допуск по марже (проекция): target < MARGIN_PCT%
bool CheckMarginProjection(const string &sym, bool isBuy, double lots, double price)
{
   // TODO: заменить на OrderCalcMargin — каркас упрощён
   double contract = SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE); if(contract<=0) contract=1.0;
   double leverage = 2.0;
   double add = price * contract * lots / leverage;
   double post = UsedMargin() + add;
   double pct  = Bal()>0 ? (post / Bal()) * 100.0 : 9999.0;
   if(pct >= MARGIN_PCT){
      LogAudit("[МАРЖА][DENY] "+sym+" proj="+DoubleToString(pct,2)+"% >= "+DoubleToString(MARGIN_PCT,1)+"%");
      return false;
   }
   return true;
}

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

//================= Spread/TP обслуживание =============================
double Spread(const string &s){ MqlTick t; SymbolInfoTick(s,t); return (t.ask - t.bid); }

void HandleTP_BE_TP2(const string &s, const FiboLevels &fl)
{
   int idx=SymIndex(s); if(idx<0) return;
   int ptotal=(int)PositionsTotal();
   for(int i=ptotal-1;i>=0;i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=s) continue;

      ulong tk = (ulong)PositionGetInteger(POSITION_TICKET);
      bool isLong = IsLongScenario(fl);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);

      double tp1=fl.t0786, tp2=fl.t1618;
      if(!isLong){ double spr=Spread(s); tp1-=spr; tp2-=spr; }

      bool hitTP1 = isLong ? (price>=tp1) : (price<=tp1);
      bool hitTP2 = isLong ? (price>=tp2) : (price<=tp2);

      if(hitTP1 && !flow[idx].main_tp1)
      {
         double pct = TP_SplitEnable ? 75.0 : 100.0;
         double stepV=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);
         double minV =SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
         double partRaw=vol*(pct/100.0);
         double part = MathMax(minV, MathFloor(partRaw/stepV)*stepV);
         if(part>0 && part<vol){
            if(Trade.PositionClosePartial(tk, part))
               LogAudit("[TP][PARTIAL] "+s+" part="+DoubleToString(part,2));
         }
         Trade.PositionModify(tk, open, tp2);
         flow[idx].main_tp1=true;
         LogAudit("[TP][BE_SET] "+s+" BE="+DoubleToString(open,Dg(s))+" TP2="+DoubleToString(tp2,Dg(s)));
      }
      if(hitTP2)
      {
         if(Trade.PositionClose(tk))
         {
            flow[idx].main_tp2=true; flow[idx].main_tp1=false;
            LogAudit("[TP][FULL_CLOSE] "+s+" — переход к Dual‑Armed");

            // СРАЗУ запускаем Dual‑Armed: вооружаем две стороны, ждём близости к L1
            phases[idx]=PH_DUAL_ARMED;
            ArmDualGrids(idx);
         }
      }
   }
}

//================= CT / размещение L1 ================================
bool PlaceMainL1(const string &s, const PlannedLevel &pl)
{
   if(globalAutoPause){ LogAudit("[ORDER][BLOCK] AUTO_PAUSE "+s); return false; }
   if(pl.lots<=0) return false;
   if(!CheckMarginProjection(s, pl.isLong, pl.lots, pl.price)) return false;

   string comment="Aegis MAIN L"+IntegerToString(pl.idx);
   bool ok=false;
   if(pl.isLong)
       ok=Trade.BuyLimit(pl.lots, NormalizeDouble(pl.price,Dg(s)), s, pl.sl, pl.tp, comment);
   else
       ok=Trade.SellLimit(pl.lots, NormalizeDouble(pl.price,Dg(s)), s, pl.sl, pl.tp, comment);
   if(ok) LogAudit("[ORDER][PLACE] MAIN L1 "+s+" lots="+DoubleToString(pl.lots,2));
   else   LogAudit("[ORDER][FAIL] MAIN L1 "+s+" err="+IntegerToString(_LastError));
   return ok;
}

//================= Dual‑Armed (подключение) ==========================
#include "include/Aegis_DualArmed.mqh"

//================= FSM обработка =====================================
void FSM_ProcessSymbol(int si, const RiskSnapshot &rs)
{
   string s=SYMS[si];
   // агрегаты по факту рынка
   bool hasPos=false, hasPending=false;
   int ptotal=(int)PositionsTotal(), ototal=(int)OrdersTotal();

   int activeCount=0;
   for(int i=ptotal-1;i>=0;i--) if(PositionSelectByIndex(i)) if(PositionGetString(POSITION_SYMBOL)==s){ hasPos=true; activeCount++; }
   for(int i=ototal-1;i>=0;i--){ ulong tk=OrderGetTicket(i); if(tk==0) continue; if(!OrderSelect(tk)) continue; if(OrderGetString(ORDER_SYMBOL)==s){ hasPending=true; } }

   switch(phases[si])
   {
      case PH_IDLE:
         phases[si]=PH_SCANNING;
         LogAudit("[FSM] "+s+" PH_IDLE -> PH_SCANNING");
         break;

      case PH_SCANNING:
      {
         FiboLevels fl;
         if(DetectImpulse(s, fl))
         {
            LastLeftImpulse[si]=fl; LastLeftValid[si]=true;
            if(BuildMainLevels(s, fl, si, rs))
            {
               phases[si]=PH_PENDING_L1;
               LogAudit("[FSM] "+s+" PH_SCANNING -> PH_PENDING_L1");
               // Внимание: L1 ставим по proximity (Dual‑armed берёт на себя после выхода),
               // здесь допускаем немедленную постановку L1, если нужно «всегда в рынке» сразу:
               for(int j=0;j<PlansCount[si];j++)
               {
                  if(Plans[si][j].head && Plans[si][j].idx==1)
                  {
                     PlaceMainL1(s, Plans[si][j]); // постановка L1
                     break;
                  }
               }
            }
         }
      } break;

      case PH_PENDING_L1:
         if(hasPos){
            phases[si]=PH_ACTIVE;
            LogAudit("[FSM] "+s+" PH_PENDING_L1 -> PH_ACTIVE");
         }
         break;

      case PH_ACTIVE:
         if(LastLeftValid[si]){
            HandleTP_BE_TP2(s, LastLeftImpulse[si]); // TP‑сопровождение и перевод в Dual‑Armed по выходу
         }
         break;

      case PH_DUAL_ARMED:
         // Ждём близости к L1 одной из двух «вооружённых» сторон
         if(CheckDualProximityAndPlace(si))
         {
            phases[si]=PH_PENDING_L1; // дальше стандартный маршрут
            LogAudit("[FSM] "+s+" PH_DUAL_ARMED -> PH_PENDING_L1");
         }
         break;

      case PH_DIAG:
         // Аварийный режим — постановки запрещены
         break;
   }
}

//================= Панель/таймер =====================================
void UI_DrawPanel(const RiskSnapshot &rs)
{
   Print("[ПАНЕЛЬ] Mode:", "WORK",
         " Eq=", DoubleToString(Eq(),2),
         " Used=", DoubleToString(rs.totalUsed,2), "/", DoubleToString(rs.workableDynamic,2),
         " AutoPause=", (int)rs.autoPaused,
         " Ph0=", phases[0]);
}

int OnInit()
{
   for(int i=0;i<4;i++){
      MainMagic[i]=9001001 + i*10;
      CTMagic[i]=9001002 + i*10;
      phases[i]=PH_IDLE;
      PlansCount[i]=0;
      flow[i].main_tp1=false; flow[i].main_tp2=false;
   }
   dailyStartEquity=Eq();
   lastRiskReset=TimeCurrent();
   portfolioRiskBase=Bal();
   portfolioRiskFixed=false;
   LogAudit("[INIT] Aegis S_Base_RiskSkeleton_v2 стартовал");
   EventSetTimer(60);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){ EventKillTimer(); LogAudit("[DEINIT] reason="+IntegerToString(reason)); }
void OnTimer()
{
   DailyResetIfNeeded();
   CheckPortfolioRiskBase();
   RiskSnapshot rs = GetRiskSnapshot(SYMS[0]);
   AutoPauseCheck(rs);
   UI_DrawPanel(rs);
}
void OnTick()
{
   DailyResetIfNeeded();
   for(int i=0;i<4;i++){
      RiskSnapshot rs = GetRiskSnapshot(SYMS[i]);
      AutoPauseCheck(rs);
      if(globalAutoPause) { /* постановки блокированы */ }
      FSM_ProcessSymbol(i, rs);
   }
}
//+------------------------------------------------------------------+
