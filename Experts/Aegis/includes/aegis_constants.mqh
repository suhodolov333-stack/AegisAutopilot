#pragma once
// Централизованные константы и параметры (Документ: Финальное ТЗ v4.0)
#define AEG_MAX_SYMS 4
#define AEG_MAX_LVLS 5

// Базовые символы (Документ: "Что делает Эгида сейчас")
string AEG_SYMS[AEG_MAX_SYMS] = {"BTCUSD","LTCUSD","BCHUSD","ETHUSD"};

// Весовая модель сеток 1:1:2:4 (инвариант — Финальное ТЗ)
const double AEG_WEIGHTS[4] = {1.0,1.0,2.0,4.0};
const double AEG_WEIGHTS_SUM = 8.0;

// Порог маржинальной проекции (%) — временно фикс
double AEG_MARGIN_PCT = 45.0;

// Порог тела свечи для импульса (множитель к Point)
int    AEG_BODY_THRESHOLD_MULT = 100;