//+------------------------------------------------------------------+
//| TestDrawState.mq5                                               |
//| Минимальный тест для проверки ошибки undeclared identifier       |
//+------------------------------------------------------------------+
#property strict

// глобальная переменная для состояния
int DrawState = 0;

int OnInit()
{
   Print("Init OK, DrawState = ", DrawState);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("Deinit, DrawState = ", DrawState);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // переключаем состояние
      if(DrawState == 0)
         DrawState = 1;
      else
         DrawState = 0;

      Print("DrawState = ", DrawState);
   }
}
