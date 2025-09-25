//+------------------------------------------------------------------+
//| aegis_utils.mqh                                                  |
//| Утилитарные функции для работы с аккаунтом и символами           |
//+------------------------------------------------------------------+
#pragma once

//================= Утилиты ===========================================
double Eq(){ return AccountInfoDouble(ACCOUNT_EQUITY); }
double Bal(){ return AccountInfoDouble(ACCOUNT_BALANCE); }
double UsedMargin(){ return AccountInfoDouble(ACCOUNT_MARGIN); }
double Pt(const string &s){ return SymbolInfoDouble(s,SYMBOL_POINT); }
int Dg(const string &s){ return (int)SymbolInfoInteger(s,SYMBOL_DIGITS); }
int SymIndex(const string &s){ for(int i=0;i<4;i++) if(SYMS[i]==s) return i; return -1; }

// Дополнительные helper-функции для времени
double NowMs(){ return (double)GetTickCount(); }
string TS(){ return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS); }
string PosTypeName(long t){ if(t==POSITION_TYPE_BUY) return "BUY"; if(t==POSITION_TYPE_SELL) return "SELL"; return "UNKNOWN"; }

// Функции для рынка
double Spread(const string &s){ MqlTick t; SymbolInfoTick(s,t); return (t.ask - t.bid); }
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