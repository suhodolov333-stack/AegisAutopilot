//+------------------------------------------------------------------+
//| aegis_logging.mqh                                                |
//| Система аудита и логгирования                                    |
//+------------------------------------------------------------------+
#pragma once

//================= Аудит =============================================
string auditLog[1200];
int auditLen=0;
void LogAudit(const string &msg){ if(auditLen<ArraySize(auditLog)) auditLog[auditLen++]=msg; Print(msg); }