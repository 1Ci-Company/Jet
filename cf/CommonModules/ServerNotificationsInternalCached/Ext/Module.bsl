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

// Returns:
//  Boolean
//
Function IsSessionSendServerNotificationsToClients() Export
	
	If CurrentRunMode() <> Undefined Then
		Return False;
	EndIf;
	
	CurrentBackgroundJob = GetCurrentInfoBaseSession().GetBackgroundJob();
	If CurrentBackgroundJob = Undefined
	 Or CurrentBackgroundJob.MethodName
	     <> Metadata.ScheduledJobs.SendServerNotificationsToClients.MethodName Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns details on the last Collaboration System check.
//
// Returns:
//  Structure:
//   * Date - Date
//   * Connected - Boolean
//
Function LastCheckOfInteractionSystemConnection() Export
	
	Result = New Structure;
	Result.Insert("Date", '00010101');
	Result.Insert("Connected", False);
	
	Return Result;
	
EndFunction

#EndRegion
