//+------------------------------------------------------------------+
//|                                             SuhabFiboTrader.mq5 |
//|                        Проверочная версия prompt23_trade_full   |
//+------------------------------------------------------------------+
#property copyright "Suhab Project"
#property version   "5.9"
#property strict

#include <Trade/Trade.mqh>
#include <Object.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>

//--- объекты для торговли
CTrade            trade;
COrderInfo        order;
CHistoryOrderInfo histOrder;
CPositionInfo     pos;
CDealInfo         deal;

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

   // список всех позиций
   int total_pos = PositionsTotal();
   PrintFormat("Всего открытых позиций: %d", total_pos);
   for(int i=0; i<total_pos; i++)
     {
      if(pos.SelectByIndex(i))
        {
         PrintFormat("POS[%d]: %s  Объем=%.2f  Цена=%.5f  Прибыль=%.2f",
                     i, pos.Symbol(), pos.Volume(), pos.PriceOpen(), pos.Profit());
        }
     }

   // список всех ордеров
   int total_ord = OrdersTotal();
   PrintFormat("Всего ордеров: %d", total_ord);
   for(int j=0; j<total_ord; j++)
     {
      ulong ticket = OrderGetTicket(j);
      if(order.Select(ticket))
        {
         PrintFormat("ORD[%d]: Тикет=%I64d  Символ=%s  Объем=%.2f  Цена=%.5f",
                     j, order.Ticket(), order.Symbol(), order.VolumeInitial(), order.PriceOpen());
        }
     }

   // список сделок (история за последние 7 дней)
   datetime from = TimeCurrent() - 7*24*60*60;
   datetime to   = TimeCurrent();
   if(HistorySelect(from,to))
     {
      int total_deals = HistoryDealsTotal();
      PrintFormat("Всего сделок за 7 дней: %d", total_deals);
      for(int k=0; k<total_deals; k++)
        {
         ulong deal_ticket = HistoryDealGetTicket(k);
         if(deal.Select(deal_ticket))
           {
            PrintFormat("DEAL[%d]: Тикет=%I64d  Символ=%s  Цена=%.5f  Объем=%.2f  Прибыль=%.2f",
                        k, deal.Ticket(), deal.Symbol(), deal.Price(), deal.Volume(), deal.Profit());
           }
        }
     }

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
//    Решение: временно вставлены заглушки.
// 2) prompt22_stub — Конфликт объявлений (already used).
//    Решение: отключить include.
// 3) prompt22_clean_stub — Удалены include, оставлены только заглушки.
// 4) prompt23_trade — Подключены реальные include. Вывод позиций и ордеров.
// 5) prompt23_trade_fix — Исправлен вызов order.Select (через ticket).
// 6) prompt23_trade_full — Добавлен вывод истории сделок (History/Deals).
//+------------------------------------------------------------------+
