//+------------------------------------------------------------------+
//| aegis_risk.mqh                                                   |
//| Система управления рисками и маржей                              |
//+------------------------------------------------------------------+
#pragma once

//================= Структуры риска и FSM =========================
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

struct FlowState {
  bool main_tp1, main_tp2;
  bool ct_tp1, ct_tp2;
};

// Глобальные переменные риска
double dailyStartEquity = 0.0;
double portfolioRiskBase = 0.0;
bool   portfolioRiskFixed = false;
datetime lastRiskReset = 0;
bool   globalAutoPause = false;

//================= Функции риска ====================================
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
      // TODO: Временно закомментировано из-за циклических зависимостей
      // if(!anyPos){ for(int i=0;i<4;i++){ PlansCount[i]=0; phases[i]=PH_IDLE; flow[i].main_tp1=false; flow[i].main_tp2=false; } LogAudit("[РИСК] DAILY_RESET: планы очищены"); }
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