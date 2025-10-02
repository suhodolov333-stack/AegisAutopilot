//+------------------------------------------------------------------+
//| SuhabFiboTrader_v567.mq5                                         |
//| UI версия на русском + финальный XY wrapper + журнал ошибок      |
//+------------------------------------------------------------------+
#property copyright "Suhab"
#property version   "1.74"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//----------------------- CONFIG -------------------------------------
#define ENTRY_PREFIX "SUHABENTRY_"
#define TAKE_PREFIX  "SUHABTAKE_"
#define IDYES 6
#define IDNO  7

input double DefaultRiskLimit = 1900.0;

double fib_left[4]  = {1.618, 2.618, 3.618, 4.236};
double fib_right[2] = {0.786, 1.618};
string lvl_names[4] = {"L1", "L2", "L3", "L4"};
double weights[4]   = {1.0, 1.0, 2.0, 4.0};

//----------------------- STATE --------------------------------------
enum DrawStateEnum {DS_NONE = 0, DS_DRAW_ENTRY_FIRST, DS_DRAW_ENTRY_SECOND, DS_DRAW_TAKE_FIRST, DS_DRAW_TAKE_SECOND};
int DrawState = DS_NONE;

string ActiveEntryName = "";
string ActiveTakeName  = "";
double CurrentRiskLimit = DefaultRiskLimit;

datetime tmp_time1=0, tmp_time2=0;
double   tmp_price1=0.0, tmp_price2=0.0;

string OBJ_BTN_DRAW_ENTRY = "SUHAB_BTN_DRAW_ENTRY";
string OBJ_BTN_DRAW_TAKE  = "SUHAB_BTN_DRAW_TAKE";
string OBJ_BTN_CALC       = "SUHAB_BTN_CALC";
string OBJ_BTN_PLACE      = "SUHAB_BTN_PLACE";
string OBJ_BTN_NEXTCFG    = "SUHAB_BTN_NEXTCFG";
string OBJ_BTN_DELETECFG  = "SUHAB_BTN_DELETECFG";
string OBJ_EDIT_RISK      = "SUHAB_EDIT_RISK";
string OBJ_LABEL_INFO     = "SUHAB_LABEL_INFO";

struct LevelRow {
    string name;
    double weight;
    double lot;
    double entry;
    double avg;
    double sl;
    double tp1;
    double tp2;
    double margin;
    double risk;
    double pnl1;
    double pnl2;
};
LevelRow tableRows[4];
double sumRisk = 0.0, sumMargin = 0.0, sumPnl1 = 0.0, sumPnl2 = 0.0;
bool tableReady = false;

//----------------------- FORWARD DECLARATIONS ------------------------
string GetFirstEntryObject();
string GetNextEntryObject(const string current);
bool ReadEntryPrices(const string entryName, double &L1, double &L2, double &L3, double &L4);
bool ReadTakeCoeffs(const string takeName, double &tp1coeff, double &tp2coeff);
double ComputeAvgUpTo(int i, const double &entriesArr[]);
bool ComputeTableAndTotals(const string entryObj, const string takeObj, double risklimit);
void DrawTableOnChart();
bool PlaceOrdersForActiveConfig();
void DeleteConfig(const string entryObj);
bool CreateEntryFiboFromPoints(const string name, datetime t1, double p1, datetime t2, double p2);
bool CreateTakeFiboFromPoints(const string name, datetime t1, double p1, datetime t2, double p2);
double NormalizeLot(double vol, double step, double minv, double maxv);
ulong MagicFromName(const string name);
double StrToDouble(const string s);
bool GetTimePriceFromXY(long chart_id,int x,int y,datetime &t,double &p);

//----------------------- UI HELPERS ----------------------------------
void CreateButton(const string name, const string text, int x, int y, int w=140, int h=24) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) {
      PrintFormat("SUHAB ERR: CreateButton failed name=%s err=%d", name, GetLastError());
      return;
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void CreateEdit(const string name, const string text, int x, int y, int w=120, int h=18) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0)) {
      PrintFormat("SUHAB ERR: CreateEdit failed name=%s err=%d", name, GetLastError());
      return;
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void CreateLabel(const string name, const string text, int x, int y, int w=300, int h=20) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) {
      PrintFormat("SUHAB ERR: CreateLabel failed name=%s err=%d", name, GetLastError());
      return;
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0,  name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//----------------------- MAIN LOGIC -----------------------------
int OnInit() {
   CreateButton(OBJ_BTN_DRAW_ENTRY,  "Построить Фибо входа",       10,  30);
   CreateButton(OBJ_BTN_DRAW_TAKE,   "Построить Фибо тейков",     160,  30);
   CreateButton(OBJ_BTN_CALC,        "Рассчитать",                310,  30);
   CreateButton(OBJ_BTN_PLACE,       "Выставить ордера",          460,  30);
   CreateButton(OBJ_BTN_NEXTCFG,     "Следующая конфигурация",    610,  30);
   CreateButton(OBJ_BTN_DELETECFG,   "Удалить конфигурацию",      760,  30);

   CreateEdit(OBJ_EDIT_RISK, DoubleToString(DefaultRiskLimit, 2), 10, 60, 100, 20);
   CreateLabel(OBJ_LABEL_INFO, "Лимит риска", 120, 65);

   Print("SuhabFiboTrader_v567 UI (русская версия) инициализирован");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   ObjectDelete(0, OBJ_BTN_DRAW_ENTRY);
   ObjectDelete(0, OBJ_BTN_DRAW_TAKE);
   ObjectDelete(0, OBJ_BTN_CALC);
   ObjectDelete(0, OBJ_BTN_PLACE);
   ObjectDelete(0, OBJ_BTN_NEXTCFG);
   ObjectDelete(0, OBJ_BTN_DELETECFG);
   ObjectDelete(0, OBJ_EDIT_RISK);
   ObjectDelete(0, OBJ_LABEL_INFO);

   Print("SuhabFiboTrader_v567 UI (русская версия) деинициализирован");
}

//----------------------- XY WRAPPER ------------------------------
bool GetTimePriceFromXY(long chart_id,int x,int y,datetime &t,double &p) {
   int sub_win = 0; // должен передаваться по ссылке
   if(!ChartXYToTimePrice(chart_id, x, y, sub_win, t, p)) {
      PrintFormat("SUHAB ERR: ChartXYToTimePrice failed err=%d", GetLastError());
      return false;
   }
   return true;
}

//==================================================================
// ПРАВИЛО ВЕДЕНИЯ ЖУРНАЛА ОШИБОК
// Журнал ошибок всегда кумулятивный.
// При каждой новой версии сохраняем ВСЕ старые записи и добавляем новые.
// Никогда не затираем старые записи.
// При написании нового кода всегда сверяемся с журналом, чтобы не повторять прошлых ошибок.
//
// ЖУРНАЛ ОШИБОК
// 29.09.2025: Ошибка "function 'GetFirstEntryObject' must have a body"
// Причина: объявлена функция без реализации.
// Решение: добавлять тело функции или заглушку { return ""; }.
//
// 29.09.2025: Ошибка "variable expected" в ChartXYToTimePrice (первый вариант).
// Причина: использовалась сигнатура с 7 аргументами (новая версия MT5).
// Решение: убрать лишний аргумент sub_window_out.
//
// 29.09.2025: Ошибка "variable expected" в ChartXYToTimePrice (второй вариант).
// Причина: передавался параметр sub_window по значению (int), хотя он нужен по ссылке (int&).
// Решение: использовать локальную переменную sub_win и передавать её по ссылке.
//==================================================================
