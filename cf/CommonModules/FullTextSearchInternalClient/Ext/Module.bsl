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

Procedure ShowExclusiveChangeModeWarning() Export
	
	QueryText = 
		NStr("en = 'To change the full-text search mode, close all sessions,
		           |except for the current user session.';");
	
	Buttons = New ValueList;
	Buttons.Add("ActiveUsers", NStr("en = 'Active users';"));
	Buttons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("AfterDisplayWarning", ThisObject);
	ShowQueryBox(Handler, QueryText, Buttons,, "ActiveUsers");
	
EndProcedure

Procedure AfterDisplayWarning(Response, ExecutionParameters) Export
	
	If Response = "ActiveUsers" Then
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf
	
EndProcedure

#EndRegion