#pragma once
#define AEG_AUDIT_MAX 2000
string AEG_AUDIT_BUF[AEG_AUDIT_MAX];
int    AEG_AUDIT_LEN=0;
void AEG_Log(const string &m){ if(AEG_AUDIT_LEN<AEG_AUDIT_MAX) AEG_AUDIT_BUF[AEG_AUDIT_LEN++]=m; Print(m); }