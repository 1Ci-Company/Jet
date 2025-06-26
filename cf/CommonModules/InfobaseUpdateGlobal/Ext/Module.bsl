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

// Checks deferred update status. If there occurred errors
// during an update procedure, this function informs a user and an administrator about it.
//
Procedure CheckDeferredUpdateStatus() Export
	
#If MobileClient Then
	If MainServerAvailable() = False Then
		Return;
	EndIf;
#EndIf
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	
	If ClientParameters.Property("ShowInvalidHandlersMessage") Then
		OpenForm("DataProcessor.ApplicationUpdateResult.Form.ApplicationUpdateResult");
	Else
		InfobaseUpdateClient.NotifyDeferredHandlersNotExecuted();
	EndIf;
	
EndProcedure

#EndRegion
