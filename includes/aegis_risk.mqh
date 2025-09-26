#pragma once
#include "aegis_utils.mqh"
#include "aegis_logging.mqh"
#include "aegis_constants.mqh"

// Снимок риска (поля могут быть дополнены позже; сейчас — каркас)
struct AEG_RiskSnapshot {
  double realized;
  double floating;
  double swap;
  double totalUsed;
  double baseDaily;
  double workableDynamic;
  double symbolCapRaw;
  bool   autoPaused;
};

bool AEG_GlobalAutoPause=false;

// Маржинальная проекция (перенос исходной логики, без изменения формул)
bool AEG_CheckMarginProjection(const string &sym, bool isBuy, double lots, double price)
{
   double contract = SymbolInfoDouble(sym,SYMBOL_TRADE_CONTRACT_SIZE); if(contract<=0) contract=1.0;
   double leverage = 2.0; // TODO: вынести в конфиг
   double add = price * contract * lots / leverage;
   double post = AEG_UsedMargin() + add;
   double pct  = AEG_Bal()>0 ? (post / AEG_Bal()) * 100.0 : 9999.0;
   if(pct >= AEG_MARGIN_PCT){
      AEG_Log("[MARGIN][DENY] "+sym+" proj="+DoubleToString(pct,2)+"% >= "+DoubleToString(AEG_MARGIN_PCT,1)+"%");
      return false;
   }
   return true;
}

// Авто-пауза (перенос: условие totalUsed >= workableDynamic)
void AEG_AutoPauseCheck(const AEG_RiskSnapshot &rs)
{
   if(!AEG_GlobalAutoPause && rs.totalUsed >= rs.workableDynamic){
      AEG_GlobalAutoPause=true;
      AEG_Log("[RISK][PAUSE] totalUsed="+DoubleToString(rs.totalUsed,2)+" >= workable="+DoubleToString(rs.workableDynamic,2));
   }
}

// Заглушка получения снимка риска (будет расширяться позже)
AEG_RiskSnapshot AEG_GetRisk(const string sym)
{
   AEG_RiskSnapshot r;
   r.realized=0; r.floating=0; r.swap=0;
   r.totalUsed=0; r.baseDaily=0; r.workableDynamic=999999;
   r.symbolCapRaw=0; r.autoPaused=AEG_GlobalAutoPause;
   return r;
}