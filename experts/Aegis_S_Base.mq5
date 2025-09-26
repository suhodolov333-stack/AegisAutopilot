#property strict
#property copyright "Aegis"
#property version   "5.1.0-mod"
// [CI] smoke trigger:

#include "..\\includes\\aegis_core.mqh"

int OnInit(){
  AEG_Log("[INIT] Aegis Base modular start");
  for(int i=0;i<AEG_MAX_SYMS;i++) AEG_Phases[i]=AEG_PH_IDLE;
  return(INIT_SUCCEEDED);
}

void OnTick(){
  for(int i=0;i<AEG_MAX_SYMS;i++){
    AEG_RiskSnapshot rs = AEG_GetRisk(AEG_SYMS[i]);
    AEG_AutoPauseCheck(rs);
    if(AEG_GlobalAutoPause) continue;
    AEG_FSM_ProcessSymbol(i, rs);
  }
}

void OnDeinit(const int reason){
  AEG_Log("[DEINIT] reason="+IntegerToString(reason));
}