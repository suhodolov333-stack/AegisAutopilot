//+------------------------------------------------------------------+
//| MultiSymbol Pool Manager (virtual netting for hedging)          |
//| Version: 1.2 — MQL5 compliant (log only to journal)              |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

input bool   OnlyBuys        = false;
input bool   OnlySells       = false;
input bool   EnableLog       = true;
input int    MinTPMovePoints = 0;

CTrade       trade;
CPositionInfo pos;

// Структура пула
struct Pool
{
   string   sym;
   long     type;
   double   totalLots;
   double   weightedPrice;
   ulong    firstTicket;
   datetime firstTime;
   double   firstTP;
   double   firstSL;
};

// Логирование — только Print в журнал терминала
void Log(const string msg)
{
   if(!EnableLog) return;
   Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " | " + msg);
}

// Поиск пула по символу и типу позиции
int FindPoolIndex(Pool &pools[], const string sym, const long type)
{
   int size = ArraySize(pools);
   for(int i = 0; i < size; i++)
      if(pools[i].sym == sym && pools[i].type == type)
         return i;
   return -1;
}

// Добавление нового пула (инициализация полей)
int AddPool(Pool &pools[], const string sym, const long type)
{
   int n = ArraySize(pools);
   ArrayResize(pools, n + 1);
   pools[n].sym = sym;
   pools[n].type = type;
   pools[n].totalLots = 0.0;
   pools[n].weightedPrice = 0.0;
   pools[n].firstTicket = 0;
   pools[n].firstTime = 0;
   pools[n].firstTP = 0.0;
   pools[n].firstSL = 0.0;
   return n;
}

// ------------------------------------------------------------
// Жизненный цикл
int OnInit()
{
   Log("EA INIT");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Log("EA DEINIT reason=" + IntegerToString(reason));
}

void OnTick()
{
   Pool pools[]; // динамический массив пулов
   int total = PositionsTotal();

   // Сбор позиций в пулы
   for(int i = 0; i < total; i++)
   {
      if(!pos.SelectByIndex(i)) continue;

      string sym = pos.Symbol();
      long   type = (long)pos.PositionType();

      if(OnlyBuys  && type != POSITION_TYPE_BUY)  continue;
      if(OnlySells && type != POSITION_TYPE_SELL) continue;

      double lot = pos.Volume();
      if(lot <= 0.0) continue;

      double openPrice = pos.PriceOpen();
      double tp        = pos.TakeProfit();
      double sl        = pos.StopLoss();
      ulong  ticket    = pos.Ticket();
      datetime opent   = pos.Time();

      int idx = FindPoolIndex(pools, sym, type);
      if(idx < 0) idx = AddPool(pools, sym, type);

      pools[idx].totalLots     += lot;
      pools[idx].weightedPrice += openPrice * lot;

      // Если это самая ранняя позиция — сохраняем её TP/SL и ticket/time
      if(pools[idx].firstTicket == 0 || (pools[idx].firstTime == 0) || (opent < pools[idx].firstTime))
      {
         pools[idx].firstTicket = ticket;
         pools[idx].firstTime   = opent;
         pools[idx].firstTP     = tp;
         pools[idx].firstSL     = sl;
      }
   }

   // Обработка каждого пула — вычисление AVG и назначение новых TP/SL
   int pools_count = ArraySize(pools);
   for(int p = 0; p < pools_count; p++)
   {
      string sym = pools[p].sym;
      long   type = pools[p].type;

      if(pools[p].totalLots <= 0.0) continue;

      // Требуем, чтобы на первой позиции были заданы TP и SL
      if(pools[p].firstTP <= 0.0 || pools[p].firstSL <= 0.0)
      {
         Log("Skip " + sym + " " + (type == POSITION_TYPE_BUY ? "BUY" : "SELL") + " — no TP/SL on first order");
         continue;
      }

      double avg = pools[p].weightedPrice / pools[p].totalLots;
      if(avg <= 0.0)
      {
         Log("Skip " + sym + " — avg price invalid");
         continue;
      }

      double tp_distance = (type == POSITION_TYPE_BUY)
                           ? (pools[p].firstTP - avg)
                           : (avg - pools[p].firstTP);

      if(tp_distance <= 0.0)
      {
         Log("Skip " + sym + " " + (type == POSITION_TYPE_BUY ? "BUY" : "SELL") + " — TPfirst not beyond avg");
         continue;
      }

      double tp_percent = tp_distance / avg;
      double newSL = pools[p].firstSL;
      double newTP = (type == POSITION_TYPE_BUY)
                     ? avg * (1.0 + tp_percent)
                     : avg * (1.0 - tp_percent);

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      if(digits < 0) digits = 5;
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(point <= 0.0) point = MathPow(10.0, -digits);

      // Пробегаем по позициям и обновляем SL/TP при необходимости
      for(int i = 0; i < total; i++)
      {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol() != sym || pos.PositionType() != type) continue;

         ulong ticket = pos.Ticket();
         double curTP = pos.TakeProfit();
         double curSL = pos.StopLoss();

         // Если ни текущий TP, ни SL заданы — обновляем
         bool needUpdate = false;
         if(curTP == 0.0 || curSL == 0.0)
            needUpdate = true;
         else if(MinTPMovePoints > 0)
         {
            double dTP = MathAbs(newTP - curTP) / point;
            double dSL = MathAbs(newSL - curSL) / point;
            if(dTP >= MinTPMovePoints || dSL >= MinTPMovePoints)
               needUpdate = true;
         }
         else
         {
            // Если MinTPMovePoints == 0 — всегда пробуем обновить
            needUpdate = true;
         }

         if(!needUpdate) continue;

         // PositionModify ожидает ticket, затем stoploss и takeprofit
         if(trade.PositionModify(ticket, newSL, newTP))
         {
            Log("Update " + sym + " " + (type == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                " ticket=" + IntegerToString((int)ticket) +
                " SL=" + DoubleToString(newSL, digits) +
                " TP=" + DoubleToString(newTP, digits));
         }
         else
         {
            Log("FAIL " + sym + " ticket=" + IntegerToString((int)ticket) +
                " SL=" + DoubleToString(newSL, digits) +
                " TP=" + DoubleToString(newTP, digits) +
                " ret=" + IntegerToString(trade.ResultRetcode()));
         }
      }
   }
}
//+------------------------------------------------------------------+