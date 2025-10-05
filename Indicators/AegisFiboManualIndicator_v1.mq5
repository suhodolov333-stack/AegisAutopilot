// Эгида v4.0 — Индикатор ручных уровней Фибоначчи (рабочий шаблон для MetaTrader 5)
// Основано на: Финальное ТЗ ("ручные сетки", контроль уровней, state machine), "Что делает Эгида сейчас" (поиск, сопровождение, журналирование), текущая реализация v4.0 (расширяемость, интеграция с автоматом)
// Пользователь на графике указывает две точки — индикатор строит уровни Фибо и делает их доступными для анализа, сопровождения и обучения

#property indicator_chart_window
#property indicator_plots 7

// --- Фибо уровни: 0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%
double fibo_levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};

// --- Буферы для линий
double FiboBuffer0[];
double FiboBuffer1[];
double FiboBuffer2[];
double FiboBuffer3[];
double FiboBuffer4[];
double FiboBuffer5[];
double FiboBuffer6[];

// --- Переменные для ручного выбора точек
datetime point_time1 = 0;
datetime point_time2 = 0;
double point_price1 = 0.0;
double point_price2 = 0.0;

// --- Цвета линий
color fibo_colors[7] = {clrDodgerBlue, clrDeepSkyBlue, clrGreen, clrGold, clrRed, clrMagenta, clrGray};

// --- Инициализация буферов
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
   
   IndicatorShortName("Aegis Manual Fibo Levels");

   return(INIT_SUCCEEDED);
}

// --- Основная логика индикатора
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
   // Проверка: выбраны ли точки пользователем вручную (например, через стандартный механизм или внешний интерфейс)
   // Для теста: используем крайние бары на истории (можно расширить под реальные клики)
   if(rates_total < 2)
      return(0);

   // Пример: берем первую и последнюю точку на графике
   point_time1 = time[0];
   point_time2 = time[rates_total-1];
   point_price1 = close[0];
   point_price2 = close[rates_total-1];

   // Вычисляем уровни Фибоначчи для каждого бара
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

   // Журналирование для анализа "Что делает Эгида сейчас"
   Print("Aegis Fibo: Start @ ", TimeToString(point_time1), ", Price=", DoubleToString(point_price1, _Digits));
   Print("Aegis Fibo: End   @ ", TimeToString(point_time2), ", Price=", DoubleToString(point_price2, _Digits));
   for(int k=0;k<ArraySize(fibo_levels);k++)
      Print("Level ", DoubleToString(fibo_levels[k]*100,1), "% = ", DoubleToString(point_price1 + price_diff*fibo_levels[k], _Digits));

   return(rates_total);
}