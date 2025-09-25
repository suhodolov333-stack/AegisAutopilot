#pragma once
struct AEG_Fibo { double e1618,e2618,e3618,e4236,t0786,t1618,t0382,t0000,t0886; double baseStart,baseEnd; bool ok; };
struct AEG_PlannedLevel { int idx; bool isLong; double price, sl, tp, lots, riskMoney; bool head; };
#define AEG_MAX_SYMS 4
#define AEG_MAX_LVLS 5
AEG_PlannedLevel AEG_Plans[AEG_MAX_SYMS][AEG_MAX_LVLS];
int AEG_PlansCount[AEG_MAX_SYMS];
void AEG_PlansReset(int si){ AEG_PlansCount[si]=0; }
void AEG_PlansAdd(int si,const AEG_PlannedLevel &pl){ int c=AEG_PlansCount[si]; if(c>=AEG_MAX_LVLS) return; AEG_Plans[si][c]=pl; AEG_PlansCount[si]=c+1; }
// Заглушки — перенос реальной логики позже
bool AEG_DetectImpulse(const string sym, AEG_Fibo &fibo){ return false; }
bool AEG_BuildMainLevels(const string sym, const AEG_Fibo &fibo, int symIdx){ return true; }