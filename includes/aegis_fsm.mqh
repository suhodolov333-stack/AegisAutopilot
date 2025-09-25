//+------------------------------------------------------------------+
//| aegis_fsm.mqh                                                    |
//| Состояния FSM и обработка автомата                               |
//+------------------------------------------------------------------+
#pragma once

//================= FSM состояния ===================================
// Из Aegis_S_Base_RiskSkeleton.mq5
enum Phase { PH_IDLE=0, PH_SCANNING=1, PH_PENDING_L1=2, PH_ACTIVE=3, PH_DUAL_ARMED=4, PH_DIAG=5 };
Phase phases[4];

// Из AegisEA_S5_RU_MIN_RollingPersistFSM_Version2.mq5
enum AegisState { STATE_IDLE=0, STATE_MONITOR=1, STATE_PROTECT=2, STATE_SAFE=3 };
AegisState g_state = STATE_IDLE;

//================= FSM функции =====================================
// TODO: Полная реализация FSM_ProcessSymbol будет перенесена на следующем этапе
void FSM_ProcessSymbol(int si, const RiskSnapshot &rs);  // Декларация для компиляции