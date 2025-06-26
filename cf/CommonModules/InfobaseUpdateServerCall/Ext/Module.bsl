///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Used for integration with the subsystem "Configurations update".
// See the ConfigurationUpdateFileTemplate template for UpdateInstallation processing.
//
Function UpdateInfobase(ExecuteDeferredHandlers1 = False) Export
	
	StartDate = CurrentSessionDate();
	Result = InfobaseUpdate.UpdateInfobase(ExecuteDeferredHandlers1);
	EndDate = CurrentSessionDate();
	InfobaseUpdateInternal.WriteUpdateExecutionTime(StartDate, EndDate);
	
	Return Result;
	
EndFunction

#EndRegion
