#pragma once
struct AEG_RiskSnapshot { double totalUsed; double workableDynamic; double marginPct; double equity; double balance; };
bool AEG_GlobalAutoPause=false;
bool AEG_CheckMarginProjection(const string sym, bool isLong, double lots, double price){ return true; }
void AEG_AutoPauseCheck(const AEG_RiskSnapshot &rs){ }
AEG_RiskSnapshot AEG_GetRisk(const string sym){ AEG_RiskSnapshot r; r.equity=AEG_Eq(); r.balance=AEG_Bal(); r.totalUsed=0; r.workableDynamic=0; r.marginPct=0; return r; }