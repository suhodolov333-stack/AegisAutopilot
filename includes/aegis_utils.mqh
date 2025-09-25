#pragma once
// Утилиты
double AEG_Eq(){ return AccountInfoDouble(ACCOUNT_EQUITY); }
double AEG_Bal(){ return AccountInfoDouble(ACCOUNT_BALANCE); }
double AEG_UsedMargin(){ return AccountInfoDouble(ACCOUNT_MARGIN); }
double AEG_Pt(const string &s){ return SymbolInfoDouble(s,SYMBOL_POINT); }
ulong AEG_NowMs(){ return GetTickCount(); }
string AEG_TS(){ return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS); }