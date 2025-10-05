//+------------------------------------------------------------------+
//|                                           FibonacciIndicator.mq5 |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

input int      LevelsCount = 6;          // Number of Fibonacci levels
// Нельзя использовать input для массивов! 
// Вместо этого используем обычный массив:
double   FibLevels[6] = {0, 0.236, 0.382, 0.5, 0.618, 1}; // Fibonacci levels

input color    LevelColor = clrBlue;     // Color of levels
input int      LevelWidth = 2;           // Line thickness

//--- Internal variables
double startPrice, endPrice;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"Fibonacci Indicator");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   // Calculate the highest and lowest price in the visible chart range
   int startBar = WindowFirstVisibleBar();
   int barsOnChart = WindowBarsPerChart();
   int endBar = startBar + barsOnChart - 1;
   if(endBar > rates_total-1) endBar = rates_total-1;

   startPrice = high[startBar];
   endPrice = low[startBar];

   for(int i=startBar; i<=endBar; i++)
     {
      if(high[i] > startPrice)
         startPrice = high[i];
      if(low[i] < endPrice)
         endPrice = low[i];
     }

   // Draw Fibonacci levels
   for(int i=0; i<LevelsCount; i++)
     {
      double levelPrice = startPrice - (startPrice-endPrice)*FibLevels[i];
      string levelName = "FiboLevel_"+IntegerToString(i);
      if(ObjectFind(0,levelName)<0)
         ObjectCreate(0,levelName,OBJ_HLINE,0,0,levelPrice);
      ObjectSetDouble(0,levelName,OBJPROP_PRICE,levelPrice);
      ObjectSetInteger(0,levelName,OBJPROP_COLOR,LevelColor);
      ObjectSetInteger(0,levelName,OBJPROP_WIDTH,LevelWidth);
      ObjectSetInteger(0,levelName,OBJPROP_SELECTABLE,false);
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+