// Эгида v4.0 — Индикатор ручных уровней Фибоначчи (рабочий шаблон для MetaTrader 5)
// Основано на: Финальное ТЗ, "Что делает Эгида сейчас", v4.0 архитектура

#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

double FiboBuffer0[];
double FiboBuffer1[];
double FiboBuffer2[];
double FiboBuffer3[];
double FiboBuffer4[];
double FiboBuffer5[];
double FiboBuffer6[];

double fibo_levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
color fibo_colors[7] = {clrDodgerBlue, clrDeepSkyBlue, clrGreen, clrGold, clrRed, clrMagenta, clrGray};

int OnInit()
{
   SetIndexBuffer(0, FiboBuffer0, INDICATOR_DATA);
   SetIndexBuffer(1, FiboBuffer1, INDICATOR_DATA);
   SetIndexBuffer(2, FiboBuffer2, INDICATOR_DATA);
   SetIndexBuffer(3, FiboBuffer3, INDICATOR_DATA);
   SetIndexBuffer(4, FiboBuffer4, INDICATOR_DATA);
   SetIndexBuffer(5, FiboBuffer5, INDICATOR_DATA);
   SetIndexBuffer(6, FiboBuffer6, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, fibo_colors[0]);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, fibo_colors[1]);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, fibo_colors[2]);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, fibo_colors[3]);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, fibo_colors[4]);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, fibo_colors[5]);
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, fibo_colors[6]);

   IndicatorShortName("Aegis Manual Fibo Levels"); // Исправлено и завершено точкой с запятой

   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 2)
      return(0);

   // Для теста: берем первую и последнюю точку на графике
   double point_price1 = close[0];
   double point_price2 = close[rates_total-1];

   for(int i=0; i<rates_total; i++)
   {
      double base_price = point_price1;
      double price_diff = point_price2 - point_price1;
      FiboBuffer0[i] = base_price + price_diff * fibo_levels[0];
      FiboBuffer1[i] = base_price + price_diff * fibo_levels[1];
      FiboBuffer2[i] = base_price + price_diff * fibo_levels[2];
      FiboBuffer3[i] = base_price + price_diff * fibo_levels[3];
      FiboBuffer4[i] = base_price + price_diff * fibo_levels[4];
      FiboBuffer5[i] = base_price + price_diff * fibo_levels[5];
      FiboBuffer6[i] = base_price + price_diff * fibo_levels[6];
   }

   return(rates_total);
}