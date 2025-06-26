///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") Then
		If CommandExecuteParameters.Source.FormName =
			"Catalog.Users.Form.ListForm" Then
			FormParameters.Insert("Filter", "Users");
		ElsIf CommandExecuteParameters.Source.FormName =
			"Catalog.ExternalUsers.Form.ListForm" Then
			FormParameters.Insert("Filter", "ExternalUsers");
		EndIf;
	EndIf;
	
	OpenForm(
		"Catalog.Users.Form.InfoBaseUsers",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
