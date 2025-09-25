#pragma once
enum AEG_State { AEG_IDLE=0, AEG_SCANNING, AEG_PENDING_L1, AEG_ACTIVE, AEG_DUAL_ARMED, AEG_MONITOR, AEG_PROTECT, AEG_SAFE, AEG_DIAG };
AEG_State AEG_CurrentState=AEG_IDLE;
void AEG_FSM_Update(){ /* TODO: перенос фактической FSM логики */ }