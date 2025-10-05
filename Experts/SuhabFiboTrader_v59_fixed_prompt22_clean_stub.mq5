//+------------------------------------------------------------------+
//|                                             SuhabFiboTrader.mq5 |
//|                        Исправленная версия prompt22_clean_stub  |
//+------------------------------------------------------------------+
#property copyright "Suhab Project"
#property version   "5.9"
#property strict

#include <Trade/Trade.mqh>
#include <Object.mqh>

//--- удалены конфликтные include
// #include <OrderInfo.mqh>
// #include <HistoryOrderInfo.mqh>
// #include <PositionInfo.mqh>
// #include <DealInfo.mqh>

// --- Заглушки для торговли (временно, пока нет торговой логики)
class COrderInfo { };
class CHistoryOrderInfo { };
class CPositionInfo { };
class CDealInfo { };

//--- глобальное состояние рисования
int DrawState = 0; // 0=NONE, 1=ENTRY_FIRST, 2=ENTRY_SECOND, 3=TAKE_FIRST, 4=TAKE_SECOND

//--- глобальные переменные
string ENTRY_PREFIX = "ENTRY_";
string TAKE_PREFIX  = "TAKE_";

//+------------------------------------------------------------------+
//| OnChartEvent                                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_CLICK)
     {
      if(DrawState == 0)
        {
         Print("Щелчок А: сохраняем первую точку");
         DrawState = 1;
        }
      else if(DrawState == 1)
        {
         Print("Щелчок Б: сохраняем вторую точку и строим Фибо");
         DrawState = 0;
        }
     }
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Советник запущен");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("Советник выгружен");
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // основной торговый цикл (пока пусто)
  }

//+------------------------------------------------------------------+
//| ЖУРНАЛ ОШИБОК (накопительный)                                    |
//+------------------------------------------------------------------+
// 1) prompt22_fix — Ошибки include (OrderInfo.mqh и др. не найдены).
//    Решение: временно вставлены заглушки для классов COrderInfo, 
//             CHistoryOrderInfo, CPositionInfo, CDealInfo.
// 2) prompt22_stub — Конфликт объявлений (already used), т.к. были и
//    include, и заглушки одновременно. Решение: отключить include.
// 3) prompt22_clean_stub — Полностью удалены include, оставлены только
//    заглушки. Теперь код компилируется чисто, без конфликтов.
//+------------------------------------------------------------------+
