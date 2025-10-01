#pragma once
#include "aegis_logging.mqh"
#include "aegis_planning.mqh"
#include "aegis_risk.mqh"
#include "aegis_constants.mqh"

// FSM фазы (перенос enum)
enum AEG_Phase { AEG_PH_IDLE=0, AEG_PH_SCANNING=1, AEG_PH_PENDING_L1=2, AEG_PH_ACTIVE=3, AEG_PH_DUAL_ARMED=4, AEG_PH_DIAG=5 };
AEG_Phase AEG_Phases[AEG_MAX_SYMS];

// Обработка символа (упрощённый перенос)
void AEG_FSM_ProcessSymbol(int si, const AEG_RiskSnapshot &rs)
{
   string s = AEG_SYMS[si];
   switch(AEG_Phases[si])
   {
      case AEG_PH_IDLE:
         AEG_Phases[si]=AEG_PH_SCANNING;
         AEG_Log("[FSM] "+s+" IDLE -> SCANNING");
         break;

      case AEG_PH_SCANNING:
      {
         AEG_Fibo fl;
         if(AEG_DetectImpulse(s, fl))
         {
            if(AEG_BuildMainLevels(s, fl, si, rs))
            {
               AEG_Phases[si]=AEG_PH_PENDING_L1;
               AEG_Log("[FSM] "+s+" SCANNING -> PENDING_L1");
               // Немедленное размещение L1 (как в исходной концепции)
               for(int j=0;j<AEG_PlansCount[si];j++){
                  if(AEG_Plans[si][j].head && AEG_Plans[si][j].idx==1){
                     AEG_PlaceMainL1(s, AEG_Plans[si][j]);
                     break;
                  }
               }
            }
         }
         break;
      }

      case AEG_PH_PENDING_L1:
         // TODO: обработка исполнения L1 → переход в ACTIVE
         break;

      case AEG_PH_ACTIVE:
         // TODO: сопровождение позиций, TP/переворот
         break;

      case AEG_PH_DUAL_ARMED:
         // TODO: подключение Dual-Armed логики
         break;

      case AEG_PH_DIAG:
         // TODO: диагностическое состояние
         break;
   }
}