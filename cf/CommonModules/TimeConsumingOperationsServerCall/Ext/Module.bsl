///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

Function IsBackgroundJobCompleted(JobID) Export
	
	BackgroundJob = BackgroundJobs.FindByUUID(JobID);
	If BackgroundJob = Undefined Then
		Return True;
	EndIf;
	
	If BackgroundJob.State <> BackgroundJobState.Active Then
		Return True;
	EndIf;
	
	BackgroundJob = BackgroundJob.WaitForExecutionCompletion(3);
	
	Return BackgroundJob.State <> BackgroundJobState.Active;
	
EndFunction

#EndRegion
