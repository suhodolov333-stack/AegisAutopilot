//+------------------------------------------------------------------+
//| aegis_core.mqh                                                   |
//| Основной файл подключения всех модулей Aegis                     |
//+------------------------------------------------------------------+
#pragma once

// Порядок подключения модулей важен из-за зависимостей:
// utils → logging → planning → risk → fsm
#include "aegis_utils.mqh"
#include "aegis_logging.mqh"
#include "aegis_planning.mqh"
#include "aegis_risk.mqh"
#include "aegis_fsm.mqh"