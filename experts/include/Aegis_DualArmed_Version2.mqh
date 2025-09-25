//+------------------------------------------------------------------+
//| Aegis Dual-Armed mode (двойное «вооружение» сеток)               |
//| Основа: Финальное ТЗ v4.0 — цикличность, левая/правая,           |
//|       «всегда в рынке», безопасность: постановка по близости.    |
//| Задача: после выхода по TP (в т.ч. после усреднения) —           |
//|  1) построить две сетки (вверх/вниз) от импульса по телам;        |
//|  2) «вооружить» обе (без реальных order),                         |
//|  3) ждать, какая L1 (e1618) первой попадёт в зону proximity;      |
//|  4) выбранную сторону активировать: построить план и поставить L1 |
//+------------------------------------------------------------------+
#pragma once

// Порог близости к L1: доля расстояния |e1618 - baseStart|
#define AEGIS_PROX_TRIGGER_RATIO 0.618

struct DualArmedState
{
   bool   armed;
   bool   upValid;
   bool   downValid;
   FiboLevels up;     // сетка «вверх» (dir=+1)
   FiboLevels down;   // сетка «вниз» (dir=-1)
   int    chosenDir;  // 0=нет, +1=up выбрана, -1=down выбрана
};

// Глобальное состояние по символам (ожидает: SYMS[4])
DualArmedState g_dual[4];

// Построить две сетки от базового импульса (по телам)
static bool BuildDualFromImpulse(const string s, FiboLevels &flUp, FiboLevels &flDown)
{
   FiboLevels base;
   if(!DetectImpulse(s, base))
      return false;

   double seg = (base.baseEnd - base.baseStart);
   double mod = MathAbs(seg);

   // «Вверх»: dir=+1 от baseStart
   flUp.baseStart = base.baseStart;
   flUp.baseEnd   = base.baseStart + (+1)*mod;
   flUp.e1618 = flUp.baseStart + (+1)*mod*1.618;
   flUp.e2618 = flUp.baseStart + (+1)*mod*2.618;
   flUp.e3618 = flUp.baseStart + (+1)*mod*3.618;
   flUp.e4236 = flUp.baseStart + (+1)*mod*4.236;
   // TP‑зоны зеркалим по телам исходного импульса
   flUp.t0786 = base.baseEnd + (base.baseStart - base.baseEnd)*0.786;
   flUp.t1618 = base.baseEnd + (base.baseStart - base.baseEnd)*1.618;
   flUp.t0382 = base.baseEnd + (base.baseStart - base.baseEnd)*0.382;
   flUp.t0000 = base.baseEnd;
   flUp.t0886 = base.baseEnd + (base.baseStart - base.baseEnd)*0.886;
   flUp.ok = true;

   // «Вниз»: dir=-1 от baseStart
   flDown.baseStart = base.baseStart;
   flDown.baseEnd   = base.baseStart + (-1)*mod;
   flDown.e1618 = flDown.baseStart + (-1)*mod*1.618;
   flDown.e2618 = flDown.baseStart + (-1)*mod*2.618;
   flDown.e3618 = flDown.baseStart + (-1)*mod*3.618;
   flDown.e4236 = flDown.baseStart + (-1)*mod*4.236;
   flDown.t0786 = base.baseEnd + (base.baseStart - base.baseEnd)*0.786;
   flDown.t1618 = base.baseEnd + (base.baseStart - base.baseEnd)*1.618;
   flDown.t0382 = base.baseEnd + (base.baseStart - base.baseEnd)*0.382;
   flDown.t0000 = base.baseEnd;
   flDown.t0886 = base.baseEnd + (base.baseStart - base.baseEnd)*0.886;
   flDown.ok = true;

   return true;
}

// Вооружить две стороны для символа si
static bool ArmDualGrids(const int si)
{
   string s = SYMS[si];
   FiboLevels up, down;
   if(!BuildDualFromImpulse(s, up, down))
   {
      g_dual[si].armed=false; g_dual[si].upValid=false; g_dual[si].downValid=false; g_dual[si].chosenDir=0;
      LogAudit("[ЦИКЛ][DUAL] "+s+" не удалось построить импульс (двойной режим отключён)");
      return false;
   }
   g_dual[si].armed     = true;
   g_dual[si].up        = up;   g_dual[si].upValid   = true;
   g_dual[si].down      = down; g_dual[si].downValid = true;
   g_dual[si].chosenDir = 0;
   LogAudit("[ЦИКЛ][DUAL] "+s+" вооружены две сетки (вверх/вниз)");
   return true;
}

// Проверка близости к L1 (e1618) — без «свечения» ордеров
static bool IsNearL1(const string s, const FiboLevels &fl)
{
   MqlTick t; SymbolInfoTick(s,t);
   double priceNow = (t.bid + t.ask)*0.5;
   double l1 = fl.e1618;
   double seg = MathAbs(fl.e1618 - fl.baseStart);
   double thr = seg * AEGIS_PROX_TRIGGER_RATIO;
   return (MathAbs(priceNow - l1) <= thr);
}

// Активировать сторону, которая первой подошла к L1: построить план и поставить L1
static bool CheckDualProximityAndPlace(const int si)
{
   if(!g_dual[si].armed) return false;
   string s = SYMS[si];

   bool upReady   = g_dual[si].upValid   && IsNearL1(s, g_dual[si].up);
   bool downReady = g_dual[si].downValid && IsNearL1(s, g_dual[si].down);

   if(!upReady && !downReady)
      return false;

   MqlTick t; SymbolInfoTick(s,t); double p=(t.bid+t.ask)*0.5;
   double dUp   = upReady   ? MathAbs(p - g_dual[si].up.e1618)   : 1e100;
   double dDown = downReady ? MathAbs(p - g_dual[si].down.e1618) : 1e100;

   int dir = (dUp <= dDown ? +1 : -1);
   const FiboLevels &flChosen = (dir>0? g_dual[si].up : g_dual[si].down);

   // Риск‑снимок и проверка авто‑паузы
   RiskSnapshot rs = GetRiskSnapshot(s);
   AutoPauseCheck(rs);
   if(rs.autoPaused)
   {
      LogAudit("[РИСК][PAUSE] "+s+" Dual-активация заблокирована (авто‑пауза)");
      return false;
   }

   // План и постановка L1
   int idx=si;
   if(!BuildMainLevels(s, flChosen, idx, rs))
   {
      LogAudit("[ПЛАН][FAIL] "+s+" не удалось построить план для выбранной стороны");
      return false;
   }

   for(int j=0;j<PlansCount[idx];j++)
   {
      if(Plans[idx][j].head && Plans[idx][j].idx==1)
      {
         if(!PlaceMainL1(s, Plans[idx][j]))
            return false;
         break;
      }
   }

   // Выбранная — «левая», противоположная станет «правой» в рабочем цикле
   LastLeftImpulse[idx] = flChosen;
   LastLeftValid[idx]   = true;

   g_dual[idx].chosenDir = dir;
   g_dual[idx].armed     = false;

   LogAudit("[ЦИКЛ][DUAL->LEFT] "+s+" активировано направление "+(dir>0?"UP":"DOWN"));
   return true;
}