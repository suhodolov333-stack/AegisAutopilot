//+------------------------------------------------------------------+
//|                   SuhabFiboTrader_v6.mq5                         |
//|               Построение Фибо-сеток Entry/Take                   |
//+------------------------------------------------------------------+
#property strict

// === НАСТРОЙКИ ===
bool UseBody = true; // true = строим по телам свечей, false = по теням

// === Переменные ===
datetime tA;
double   pA;
int Mode=0;      // 0 = Entry, 1 = Take
int DrawState=0; // 0 = ждём кнопку, 1 = ждём точку А, 2 = ждём точку B

// === Константы кнопок ===
string BTN_ENTRY="btn_entry";
string BTN_TAKE ="btn_take";
string BTN_CLEAR="btn_clear";

//+------------------------------------------------------------------+
//| Создание кнопки                                                  |
//+------------------------------------------------------------------+
void CreateButton(string name,string text,int x,int y,int w=100,int h=20)
  {
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
     {
      Print("Ошибка создания кнопки: ",name);
      return;
     }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlue);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
  }

//+------------------------------------------------------------------+
//| Очистить все сетки                                               |
//+------------------------------------------------------------------+
void ClearAllFibo()
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,"Fibo",0)>=0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//| Нормализация точки по телам/теням                                |
//+------------------------------------------------------------------+
void NormalizePointByCandle(datetime t,double &p)
  {
   int bar=iBarShift(_Symbol,_Period,t,true);
   if(bar<0) return;

   double o=Open[bar], c=Close[bar], h=High[bar], l=Low[bar];
   if(UseBody)
     {
      double min_body=MathMin(o,c);
      double max_body=MathMax(o,c);
      if(p<(o+c)/2.0) p=min_body; else p=max_body;
     }
   else
     {
      if(p<(o+c)/2.0) p=l; else p=h;
     }
  }

//+------------------------------------------------------------------+
//| Построение Фибо                                                  |
//+------------------------------------------------------------------+
void CreateEntryFiboFromPoints(string name,datetime t1,double p1,datetime t2,double p2)
  {
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_FIBO,0,t1,p1,t2,p2))
     {
      Print("Ошибка создания Fibo: ",name);
      return;
     }
   double levels[]={0.0,0.236,0.382,0.5,0.618,1.0,1.618,2.618,4.236};
   for(int i=0;i<ArraySize(levels);i++)
     {
      ObjectSetDouble(0,name,OBJPROP_LEVELVALUE,i,levels[i]);
      ObjectSetString(0,name,OBJPROP_LEVELTEXT,i,DoubleToString(levels[i],3));
     }
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrAqua);
  }

void CreateTakeFiboFromPoints(string name,datetime t1,double p1,datetime t2,double p2)
  {
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   if(!ObjectCreate(0,name,OBJ_FIBO,0,t1,p1,t2,p2))
     {
      Print("Ошибка создания Fibo: ",name);
      return;
     }
   double levels[]={0.0,0.236,0.382,0.5,0.618,1.0,1.618,2.618,4.236};
   for(int i=0;i<ArraySize(levels);i++)
     {
      ObjectSetDouble(0,name,OBJPROP_LEVELVALUE,i,levels[i]);
      ObjectSetString(0,name,OBJPROP_LEVELTEXT,i,DoubleToString(levels[i],3));
     }
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrOrange);
  }

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   CreateButton(BTN_ENTRY,"Сетка Entry",10,20);
   CreateButton(BTN_TAKE, "Сетка Take", 10,50);
   CreateButton(BTN_CLEAR,"Очистить",   10,80);
   Print("SUHAB: Советник запущен. Включено построение ",(UseBody?"по телам":"по теням"));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnChartEvent                                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   datetime t; double p; int subwin=0;

   if(id==CHARTEVENT_CLICK) // клик по графику
     {
      if(!ChartXYToTimePrice(0,(int)lparam,(int)dparam,subwin,t,p))
         return;

      if(DrawState==1)
        {
         tA=t; pA=p;
         NormalizePointByCandle(tA,pA);
         DrawState=2;
         PrintFormat("SUHAB: Точка А выбрана (%s), теперь выберите точку B [%s]",
                     (Mode==0?"Entry":"Take"),
                     (UseBody?"по телам":"по теням"));
        }
      else if(DrawState==2)
        {
         NormalizePointByCandle(t,p);
         if(Mode==0)
           {
            CreateEntryFiboFromPoints("FiboEntry",tA,pA,t,p);
            Print("SUHAB: Точка B выбрана (Entry), сетка построена");
           }
         else
           {
            CreateTakeFiboFromPoints("FiboTake",tA,pA,t,p);
            Print("SUHAB: Точка B выбрана (Take), сетка построена");
           }
         DrawState=0;
        }
     }

   if(id==CHARTEVENT_OBJECT_CLICK) // клик по кнопке
     {
      if(sparam==BTN_ENTRY)
        {
         Mode=0; DrawState=1;
         Print("SUHAB: Режим Entry активирован, выберите точку A на графике");
        }
      else if(sparam==BTN_TAKE)
        {
         Mode=1; DrawState=1;
         Print("SUHAB: Режим Take активирован, выберите точку A на графике");
        }
      else if(sparam==BTN_CLEAR)
        {
         ClearAllFibo();
         Print("SUHAB: Все сетки очищены");
        }
     }
  }

//+------------------------------------------------------------------+
