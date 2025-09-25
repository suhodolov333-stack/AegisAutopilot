#property strict
#property copyright "Aegis"
#property version   "5.0.0-base"
#include "..\\includes\\aegis_core.mqh"
input string Symbols = "BTCUSD,LTCUSD,BCHUSD,ETHUSD";
string AEG_SymbolList[4];
int    AEG_SymbolCount=0;
void AEG_ParseSymbols(){ int p=0,start=0; string s=Symbols; while(true){ p=StringFind(s,",",start); string token; if(p<0){ token=StringSubstr(s,start); start=StringLen(s); } else { token=StringSubstr(s,start,p-start); start=p+1; } StringTrimLeft(token); StringTrimRight(token); if(StringLen(token)>0 && AEG_SymbolCount<4) AEG_SymbolList[AEG_SymbolCount++]=token; if(p<0) break; } }
int OnInit(){ AEG_Log("[INIT] Aegis Base start"); AEG_ParseSymbols(); return(INIT_SUCCEEDED); }
void OnTick(){ for(int i=0;i<AEG_SymbolCount;i++){ AEG_RiskSnapshot rs = AEG_GetRisk(AEG_SymbolList[i]); AEG_AutoPauseCheck(rs); if(AEG_GlobalAutoPause) continue; AEG_FSM_Update(); } }
void OnDeinit(const int reason){ AEG_Log("[DEINIT] reason="+IntegerToString(reason)); }