//+------------------------------------------------------------------+
//| AegisEA_S5_RU_MIN_RollingPersistFSM.mq5                          |
//| Aegis S5 RU MIN v1.61 (FIX):                                     |
//|  - Monitoring + Invariants + FSM + DRY Protective                |
//|  - Persistence (durations + index)                               |
//|  - Rolling CSV                                                   |
//|  - State durations & multi-scenario simulation                   |
//|  - Summary file                                                  |
//|  - FIX 1.61: ParseScenarioConfig() — убрана вложенная             |
//|    конструкция StringTrimRight(StringTrimLeft(token))            |
//|    (MQL5 trim-функции возвращают int, работают по ссылке).       |
//| Док. опоры: Финальное ТЗ v4.0 (Monitoring/Invariant/FSM/          |
//| Persistence/Observability/Prepared Averaging Layer)              |
//+------------------------------------------------------------------+
#property strict
#property version "1.61"
#property description "Aegis S5 RU MIN: rolling log + state durations + scenarios (DRY, fix trim)"

////////////////////////////////////////////////////////////
// INPUTS
////////////////////////////////////////////////////////////
input bool   ShowHelpOnInit             = true;
input bool   EnableSuggestions          = true;
input bool   EnableFileLog              = true;
input int    LogEveryTicks              = 5;
input bool   EnableProtectiveActions    = false;    // DRY only
input bool   InvariantStrict            = true;
input bool   InvariantDirectionalStrict = true;
input int    InvariantReportEveryTicks  = 25;
input int    SL_Points                  = 1500;
input int    TP_Points                  = 1500;
input int    AvgStepPoints              = 500;
input int    NextAvgIndexInit           = 1;
input int    MinDistancePoints          = 100;
input int    ModificationThrottleMs     = 1500;
input bool   DebugVerbose               = true;

// Persistence
input bool   EnablePersistence          = true;
input int    PersistEveryTicks          = 20;

// Simulation (primary)
input bool   EnableAvgSimulation        = true;
input double SimulatedExtraVolume       = 0.10;

// Logging extras
input bool   FlushEveryWrites           = true;
input bool   LogWhenNoPosition          = false;
input int    ForceLogEverySeconds       = 0;
input bool   LogHeaderOnRotate          = true;
input int    MaxLogLines                = 5000;  // 0 = no rotation

// Scenarios
input string ScenarioConfig             = "1;2;3";
input double ScenarioVolume             = 0.10;

////////////////////////////////////////////////////////////
// ENUM STATE
////////////////////////////////////////////////////////////
enum AegisState { STATE_IDLE=0, STATE_MONITOR=1, STATE_PROTECT=2, STATE_SAFE=3 };
AegisState g_state = STATE_IDLE;

////////////////////////////////////////////////////////////
// CONTEXT
////////////////////////////////////////////////////////////
struct Ctx
{
   bool   has_pos;
   ulong  ticket;
   long   type;
   double volume;
   double entry;
   double p_sl;
   double p_tp;
   double p_avg;
};
Ctx g_ctx;

////////////////////////////////////////////////////////////
// GLOBALS
////////////////////////////////////////////////////////////
string g_symbol = "";
int    g_NextAvgIndex = 1;

double g_lastModifyMs = 0.0;
int    g_tick = 0;
bool   g_invariantsOk = true;
string g_invMsg = "";
int    g_logCountdown = 0;

int    g_fileHandle = INVALID_HANDLE;
string g_fileName = "";
int    g_logLinesWritten = 0;
int    g_logPart = 0;

int    g_persistCountdown = 0;
string g_persistFile = "";

double g_simNewAvg = 0.0;

// FSM durations
datetime g_stateEnterTime = 0;
double   g_stateDurations[4] = {0.0,0.0,0.0,0.0};

// Scenarios
int      g_scenarioCount = 0;
int      g_scenarioSteps[5];
double   g_scenarioPrice[5];
double   g_scenarioNewAvg[5];

////////////////////////////////////////////////////////////
// HELPERS
////////////////////////////////////////////////////////////
double Pt(){ return _Point; }
double NowMs(){ return (double)GetTickCount(); }
string TS(){ return TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS); }
string PosTypeName(long t){ if(t==POSITION_TYPE_BUY) return "BUY"; if(t==POSITION_TYPE_SELL) return "SELL"; return "UNKNOWN"; }

void ResetCtx()
{
   g_ctx.has_pos=false; g_ctx.ticket=0; g_ctx.type=-1;
   g_ctx.volume=0.0; g_ctx.entry=0.0; g_ctx.p_sl=0.0; g_ctx.p_tp=0.0; g_ctx.p_avg=0.0;
   g_simNewAvg=0.0;
}

string BuildLogName()
{
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   if(g_logPart==0)
      return StringFormat("Aegis_S5_RU_MIN_%s_%04d%02d%02d_%02d%02d%02d.csv",
                          g_symbol, tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
   else
      return StringFormat("Aegis_S5_RU_MIN_%s_part%d.csv", g_symbol, g_logPart);
}

string BuildPersistName(){ return StringFormat("Aegis_S5_Persist_%s.dat", g_symbol); }

string BuildSummaryName()
{
   MqlDateTime tm; TimeToStruct(TimeCurrent(), tm);
   return StringFormat("Aegis_S5_Summary_%s_%04d%02d%02d_%02d%02d%02d.csv",
                       g_symbol, tm.year, tm.mon, tm.day, tm.hour, tm.min, tm.sec);
}

void Help()
{
   Print("=== Aegis S5 RU MIN Help (v1.61) ===");
   Print("Rolling: MaxLogLines>0 -> _partN");
   Print("Scenarios: ScenarioConfig '1;2;3' -> множители AvgStepPoints");
   Print("Durations в summary при деинициализации");
   Print("====================================");
}

////////////////////////////////////////////////////////////
// SCENARIO PARSE (FIX 1.61)
////////////////////////////////////////////////////////////
void ParseScenarioConfig()
{
   g_scenarioCount=0;
   for(int i=0;i<5;i++)
   {
      g_scenarioSteps[i]=0;
      g_scenarioPrice[i]=0.0;
      g_scenarioNewAvg[i]=0.0;
   }

   if(StringLen(ScenarioConfig)==0) return;

   string temp = ScenarioConfig;
   StringReplace(temp,",",";");
   while(StringFind(temp,";;")>=0) StringReplace(temp,";;",";");

   int start=0;
   for(int slot=0; slot<5 && start<StringLen(temp); slot++)
   {
      int p = StringFind(temp,";",start);
      string token;
      if(p<0){ token=StringSubstr(temp,start); start=StringLen(temp); }
      else    { token=StringSubstr(temp,start,p-start); start=p+1; }

      StringTrimLeft(token);
      StringTrimRight(token);

      if(StringLen(token)==0) continue;
      int val = (int)StringToInteger(token);
      if(val<=0) continue;
      g_scenarioSteps[g_scenarioCount]=val;
      g_scenarioCount++;
   }

   if(DebugVerbose)
      PrintFormat("[Aegis][SCENARIO] Parsed %d scenario(s)", g_scenarioCount);
}

////////////////////////////////////////////////////////////
// FILE LOG
////////////////////////////////////////////////////////////
void WriteLogHeader()
{
   if(g_fileHandle==INVALID_HANDLE) return;
   FileWrite(g_fileHandle,
             "timestamp","tick","state",
             "dur_idle","dur_monitor","dur_protect","dur_safe",
             "symbol","has_pos","ticket","type",
             "entry","sl_pts","tp_pts","avg_step_pts","next_idx",
             "prop_sl","prop_tp","prop_avg",
             "sim_extra_vol","sim_new_avg",
             "sc1_price","sc1_newavg","sc2_price","sc2_newavg",
             "sc3_price","sc3_newavg","sc4_price","sc4_newavg",
             "sc5_price","sc5_newavg",
             "spread","inv_ok","inv_msg","action");
   if(FlushEveryWrites) FileFlush(g_fileHandle);
   g_logLinesWritten=0;
}

void OpenLog(bool first)
{
   if(!EnableFileLog) return;
   g_fileName = BuildLogName();
   g_fileHandle = FileOpen(g_fileName, FILE_WRITE|FILE_CSV|FILE_SHARE_READ, ';');
   if(g_fileHandle==INVALID_HANDLE)
   {
      PrintFormat("[Aegis][LOG][WARN] Не открыть лог %s err=%d", g_fileName, _LastError);
      return;
   }
   WriteLogHeader();
   PrintFormat("[Aegis][LOG] Открыт: %s", g_fileName);
   if(first) g_logLinesWritten=0;
}

void RotateLogIfNeeded()
{
   if(!EnableFileLog || MaxLogLines<=0) return;
   if(g_fileHandle==INVALID_HANDLE) return;
   if(g_logLinesWritten < MaxLogLines) return;

   FileFlush(g_fileHandle);
   FileClose(g_fileHandle);
   PrintFormat("[Aegis][LOG] Ротация (lines=%d)", g_logLinesWritten);
   g_fileHandle=INVALID_HANDLE;
   g_logPart++;
   OpenLog(false);
}

void CloseLog()
{
   if(g_fileHandle!=INVALID_HANDLE)
   {
      FileFlush(g_fileHandle);
      FileClose(g_fileHandle);
      PrintFormat("[Aegis][LOG] Закрыт: %s", g_fileName);
      g_fileHandle=INVALID_HANDLE;
   }
}

////////////////////////////////////////////////////////////
// PERSIST
////////////////////////////////////////////////////////////
void SavePersistence()
{
   if(!EnablePersistence) return;
   int fh = FileOpen(g_persistFile, FILE_WRITE|FILE_TXT|FILE_SHARE_READ);
   if(fh==INVALID_HANDLE)
   {
      PrintFormat("[Aegis][PERSIST][WARN] Не открыть %s err=%d", g_persistFile, _LastError);
      return;
   }
   FileWrite(fh,"next_idx="+(string)g_NextAvgIndex);
   FileWrite(fh,"dur_idle="+DoubleToString(g_stateDurations[STATE_IDLE],2));
   FileWrite(fh,"dur_monitor="+DoubleToString(g_stateDurations[STATE_MONITOR],2));
   FileWrite(fh,"dur_protect="+DoubleToString(g_stateDurations[STATE_PROTECT],2));
   FileWrite(fh,"dur_safe="+DoubleToString(g_stateDurations[STATE_SAFE],2));
   FileClose(fh);
   if(DebugVerbose) Print("[Aegis][PERSIST] Сохранено");
}

void LoadPersistence()
{
   if(!EnablePersistence) return;
   if(!FileIsExist(g_persistFile)) return;
   int fh=FileOpen(g_persistFile, FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(fh==INVALID_HANDLE)
   {
      PrintFormat("[Aegis][PERSIST][WARN] Не открыть %s err=%d", g_persistFile, _LastError);
      return;
   }
   int lines=0;
   while(!FileIsEnding(fh) && lines<30)
   {
      string ln=FileReadString(fh);
      if(StringFind(ln,"next_idx=")==0)
      {
         int idx=(int)StringToInteger(StringSubstr(ln,9));
         if(idx>0) g_NextAvgIndex=idx;
      }
      else if(StringFind(ln,"dur_idle=")==0)
         g_stateDurations[STATE_IDLE]=StringToDouble(StringSubstr(ln,9));
      else if(StringFind(ln,"dur_monitor=")==0)
         g_stateDurations[STATE_MONITOR]=StringToDouble(StringSubstr(ln,12));
      else if(StringFind(ln,"dur_protect=")==0)
         g_stateDurations[STATE_PROTECT]=StringToDouble(StringSubstr(ln,12));
      else if(StringFind(ln,"dur_safe=")==0)
         g_stateDurations[STATE_SAFE]=StringToDouble(StringSubstr(ln,9));
      lines++;
   }
   FileClose(fh);
   if(DebugVerbose)
      PrintFormat("[Aegis][PERSIST] Загружено (idx=%d, d_idle=%.1f, d_monitor=%.1f, d_protect=%.1f, d_safe=%.1f)",
                  g_NextAvgIndex,
                  g_stateDurations[STATE_IDLE], g_stateDurations[STATE_MONITOR],
                  g_stateDurations[STATE_PROTECT], g_stateDurations[STATE_SAFE]);
}

////////////////////////////////////////////////////////////
// POSITION
////////////////////////////////////////////////////////////
bool DetectPos()
{
   if(PositionSelect(g_symbol))
   {
      ulong t=(ulong)PositionGetInteger(POSITION_TICKET);
      long ty=(long)PositionGetInteger(POSITION_TYPE);
      double v=PositionGetDouble(POSITION_VOLUME);
      double e=PositionGetDouble(POSITION_PRICE_OPEN);

      bool isNew=(!g_ctx.has_pos || g_ctx.ticket!=t);
      double prevVol=g_ctx.volume;
      bool volChanged=(g_ctx.has_pos && !isNew && MathAbs(prevVol - v)>1e-10);

      g_ctx.has_pos=true; g_ctx.ticket=t; g_ctx.type=ty; g_ctx.volume=v; g_ctx.entry=e;

      if(isNew)
         PrintFormat("[Aegis][INFO] Позиция: ticket=%I64u type=%s vol=%.2f entry=%.5f",
                     t, PosTypeName(ty), v, e);
      else if(volChanged && DebugVerbose)
         PrintFormat("[Aegis][INFO] Объём: %.2f -> %.2f", prevVol, v);

      return true;
   }
   else
   {
      if(g_ctx.has_pos)
      {
         Print("[Aegis][INFO] Позиция закрыта - сброс");
         ResetCtx();
      }
      return false;
   }
}

////////////////////////////////////////////////////////////
// SUGGEST + SIMULATION
////////////////////////////////////////////////////////////
void CalcPrimary()
{
   if(!g_ctx.has_pos){ g_simNewAvg=0.0; return; }
   double avg=g_ctx.entry;
   g_ctx.p_sl=(SL_Points>0)?(g_ctx.type==POSITION_TYPE_BUY?avg-SL_Points*Pt():avg+SL_Points*Pt()):0.0;
   g_ctx.p_tp=(TP_Points>0)?(g_ctx.type==POSITION_TYPE_BUY?avg+TP_Points*Pt():avg-TP_Points*Pt()):0.0;
   g_ctx.p_avg=(AvgStepPoints>0 && g_NextAvgIndex>0)?
               (g_ctx.type==POSITION_TYPE_BUY?avg-g_NextAvgIndex*AvgStepPoints*Pt():avg+g_NextAvgIndex*AvgStepPoints*Pt()):0.0;

   if(EnableAvgSimulation && g_ctx.p_avg>0 && SimulatedExtraVolume>0)
      g_simNewAvg=(avg*g_ctx.volume + g_ctx.p_avg*SimulatedExtraVolume)/(g_ctx.volume+SimulatedExtraVolume);
   else
      g_simNewAvg=0.0;
}

void CalcScenarios()
{
   for(int i=0;i<g_scenarioCount && i<5;i++){ g_scenarioPrice[i]=0.0; g_scenarioNewAvg[i]=0.0; }
   if(!g_ctx.has_pos || AvgStepPoints<=0 || g_scenarioCount<=0) return;

   double avg=g_ctx.entry;
   for(int i=0;i<g_scenarioCount && i<5;i++)
   {
      int mult=g_scenarioSteps[i];
      if(mult<=0) continue;
      double price=(g_ctx.type==POSITION_TYPE_BUY)?
                   (avg - mult*AvgStepPoints*Pt()):
                   (avg + mult*AvgStepPoints*Pt());
      g_scenarioPrice[i]=price;
      if(ScenarioVolume>0)
         g_scenarioNewAvg[i]=(avg*g_ctx.volume + price*ScenarioVolume)/(g_ctx.volume+ScenarioVolume);
   }
}

////////////////////////////////////////////////////////////
// INVARIANTS
////////////////////////////////////////////////////////////
bool CheckInv(string &m)
{
   bool ok=true; m="";
   if(SL_Points<=0){ ok=false; m+="SL<=0; "; }
   if(TP_Points<=0){ ok=false; m+="TP<=0; "; }
   if(AvgStepPoints<=0){ ok=false; m+="AvgStep<=0; "; }
   if(g_NextAvgIndex<1){ ok=false; m+="Idx<1; "; }
   if(MinDistancePoints<10){ ok=false; m+="MinDist<10; "; }
   if(ModificationThrottleMs<200){ ok=false; m+="Throttle<200; "; }

   if(g_ctx.has_pos)
   {
      double avg=g_ctx.entry;
      double md=MinDistancePoints*Pt();
      if(g_ctx.p_sl>0 && MathAbs(avg-g_ctx.p_sl)<md){ ok=false; m+="SLdist<Min; "; }
      if(g_ctx.p_tp>0 && MathAbs(avg-g_ctx.p_tp)<md){ ok=false; m+="TPdist<Min; "; }
      if(InvariantDirectionalStrict)
      {
         if(g_ctx.type==POSITION_TYPE_BUY)
         {
            if(!(g_ctx.p_sl==0 || g_ctx.p_sl<avg)) { ok=false; m+="BUY SL !< entry; "; }
            if(!(g_ctx.p_tp==0 || g_ctx.p_tp>avg)) { ok=false; m+="BUY TP !> entry; "; }
         }
         else if(g_ctx.type==POSITION_TYPE_SELL)
         {
            if(!(g_ctx.p_sl==0 || g_ctx.p_sl>avg)) { ok=false; m+="SELL SL !> entry; "; }
            if(!(g_ctx.p_tp==0 || g_ctx.p_tp<avg)) { ok=false; m+="SELL TP !< entry; "; }
         }
      }
      if(g_ctx.p_sl>0 && MathAbs(g_ctx.p_sl-avg)<1e-12) { ok=false; m+="SL==entry; "; }
      if(g_ctx.p_tp>0 && MathAbs(g_ctx.p_tp-avg)<1e-12) { ok=false; m+="TP==entry; "; }
      if(g_ctx.p_sl>0 && g_ctx.p_tp>0 && MathAbs(g_ctx.p_sl-g_ctx.p_tp)<1e-12) { ok=false; m+="SL==TP; "; }
   }
   if(m=="") m="OK";
   return ok;
}

void EvalInv(bool force=false)
{
   string m; bool ok=CheckInv(m);
   bool changed=(ok!=g_invariantsOk)||force;
   g_invariantsOk=ok; g_invMsg=m;
   if(changed)
      PrintFormat("[Aegis][INVAR][%s] %s", ok?"OK":"FAIL", m);
}

////////////////////////////////////////////////////////////
// FSM + DURATIONS
////////////////////////////////////////////////////////////
void AccumulateStateTime()
{
   if(g_stateEnterTime==0){ g_stateEnterTime=TimeCurrent(); return; }
   datetime now=TimeCurrent();
   double delta=(double)(now - g_stateEnterTime);
   if(delta<0) delta=0;
   g_stateDurations[g_state]+=delta;
   g_stateEnterTime=now;
}

void UpdateState()
{
   AegisState prev=g_state;
   if(!g_ctx.has_pos) g_state=STATE_IDLE;
   else
   {
      if(!g_invariantsOk && InvariantStrict) g_state=STATE_SAFE;
      else if(g_invariantsOk && EnableProtectiveActions) g_state=STATE_PROTECT;
      else g_state=STATE_MONITOR;
   }
   if(prev!=g_state && DebugVerbose)
   {
      PrintFormat("[Aegis][STATE] %d->%d", prev, g_state);
      g_stateEnterTime=TimeCurrent();
   }
}

////////////////////////////////////////////////////////////
// DRY PROTECT
////////////////////////////////////////////////////////////
void DryProtect()
{
   if(!EnableProtectiveActions) return;
   if(g_state==STATE_SAFE) return;
   if(!g_ctx.has_pos) return;

   double desiredSL=g_ctx.p_sl;
   double desiredTP=g_ctx.p_tp;
   if(desiredSL<=0 && desiredTP<=0) return;

   double nowMs=NowMs();
   if(nowMs - g_lastModifyMs < ModificationThrottleMs) return;

   g_lastModifyMs=nowMs;
   PrintFormat("[Aegis][PROTECT][DRY] SL=%.5f TP=%.5f",
               desiredSL>0?desiredSL:0.0, desiredTP>0?desiredTP:0.0);
   LogRow("DRY_APPLY");
}

////////////////////////////////////////////////////////////
// LOG ROW
////////////////////////////////////////////////////////////
void LogRow(string tag="NONE")
{
   if(!EnableFileLog || g_fileHandle==INVALID_HANDLE) return;
   if(!g_ctx.has_pos && !LogWhenNoPosition) return;

   double spread=0.0;
   if(SymbolInfoDouble(g_symbol,SYMBOL_BID)!=0 || SymbolInfoDouble(g_symbol,SYMBOL_ASK)!=0)
      spread=(SymbolInfoDouble(g_symbol,SYMBOL_ASK)-SymbolInfoDouble(g_symbol,SYMBOL_BID))/Pt();

   FileWrite(g_fileHandle,
             TS(), g_tick, (int)g_state,
             g_stateDurations[STATE_IDLE],
             g_stateDurations[STATE_MONITOR],
             g_stateDurations[STATE_PROTECT],
             g_stateDurations[STATE_SAFE],
             g_symbol,(int)g_ctx.has_pos,
             (long)(g_ctx.has_pos?g_ctx.ticket:0),
             (g_ctx.has_pos?PosTypeName(g_ctx.type):"-"),
             (g_ctx.has_pos?g_ctx.entry:0.0),
             SL_Points, TP_Points, AvgStepPoints, g_NextAvgIndex,
             g_ctx.p_sl, g_ctx.p_tp, g_ctx.p_avg,
             SimulatedExtraVolume, g_simNewAvg,
             g_scenarioPrice[0], g_scenarioNewAvg[0],
             g_scenarioPrice[1], g_scenarioNewAvg[1],
             g_scenarioPrice[2], g_scenarioNewAvg[2],
             g_scenarioPrice[3], g_scenarioNewAvg[3],
             g_scenarioPrice[4], g_scenarioNewAvg[4],
             spread, (int)g_invariantsOk, g_invMsg,
             (g_ctx.has_pos?tag:"NOPOS"));

   g_logLinesWritten++;
   if(FlushEveryWrites) FileFlush(g_fileHandle);
   RotateLogIfNeeded();
}

////////////////////////////////////////////////////////////
// TIMER
////////////////////////////////////////////////////////////
void SetupTimer()
{
   if(ForceLogEverySeconds>0) EventSetTimer((uint)ForceLogEverySeconds);
   else EventKillTimer();
}
void OnTimer()
{
   AccumulateStateTime();
   LogRow("TIMER");
}

////////////////////////////////////////////////////////////
// SUMMARY
////////////////////////////////////////////////////////////
void WriteSummary()
{
   string name=BuildSummaryName();
   int fh=FileOpen(name, FILE_WRITE|FILE_CSV|FILE_SHARE_READ, ';');
   if(fh==INVALID_HANDLE)
   {
      PrintFormat("[Aegis][SUMMARY][WARN] Не открыть %s err=%d", name, _LastError);
      return;
   }
   FileWrite(fh,"state","seconds");
   FileWrite(fh,"IDLE",   DoubleToString(g_stateDurations[STATE_IDLE],2));
   FileWrite(fh,"MONITOR",DoubleToString(g_stateDurations[STATE_MONITOR],2));
   FileWrite(fh,"PROTECT",DoubleToString(g_stateDurations[STATE_PROTECT],2));
   FileWrite(fh,"SAFE",   DoubleToString(g_stateDurations[STATE_SAFE],2));
   FileClose(fh);
   PrintFormat("[Aegis][SUMMARY] Создан: %s", name);
}

////////////////////////////////////////////////////////////
// EVENTS
////////////////////////////////////////////////////////////
int OnInit()
{
   g_symbol=Symbol();
   g_NextAvgIndex=(NextAvgIndexInit>0?NextAvgIndexInit:1);
   PrintFormat("[Aegis][S5] Init %s (idx=%d)", g_symbol, g_NextAvgIndex);

   ResetCtx();
   for(int i=0;i<4;i++) g_stateDurations[i]=0.0;
   g_stateEnterTime=TimeCurrent();

   ParseScenarioConfig();

   g_persistFile=BuildPersistName();
   if(EnablePersistence) LoadPersistence();

   OpenLog(true);
   EvalInv(true);
   UpdateState();
   g_logCountdown=LogEveryTicks;
   g_persistCountdown=PersistEveryTicks;
   SetupTimer();

   if(ShowHelpOnInit) Help();
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   g_tick++;
   AccumulateStateTime();

   bool hasPos=DetectPos();
   if(hasPos)
   {
      CalcPrimary();
      CalcScenarios();
   }
   else
   {
      g_simNewAvg=0.0;
      for(int i=0;i<g_scenarioCount && i<5;i++){ g_scenarioPrice[i]=0.0; g_scenarioNewAvg[i]=0.0; }
   }

   bool forceInv=(InvariantReportEveryTicks>0 && (g_tick % InvariantReportEveryTicks==0));
   EvalInv(forceInv);
   UpdateState();
   DryProtect();

   if(LogEveryTicks>0)
   {
      g_logCountdown--;
      if(g_logCountdown<=0)
      {
         LogRow("TICK");
         g_logCountdown=LogEveryTicks;
      }
   }

   if(EnablePersistence && PersistEveryTicks>0)
   {
      g_persistCountdown--;
      if(g_persistCountdown<=0)
      {
         SavePersistence();
         g_persistCountdown=PersistEveryTicks;
      }
   }
}

void OnDeinit(const int reason)
{
   AccumulateStateTime();
   PrintFormat("[Aegis][S5] Deinit=%d", reason);
   if(EnablePersistence) SavePersistence();
   WriteSummary();
   CloseLog();
   EventKillTimer();
}
//+------------------------------------------------------------------+