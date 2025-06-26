///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DontShowAgain = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SystemInfo = New SystemInfo;
	
	If StrFind(SystemInfo.UserAgentInformation, "Firefox") <> 0 Then
		Items.Additions.CurrentPage = Items.MozillaFireFox;
	Else
		Items.Additions.CurrentPage = Items.IsEmpty;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ContinueExecute(Command)
	
	If DontShowAgain = True Then
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings", "ShowTooltipsOnEditFiles", False,,, True);
	EndIf;
	
	Close(True);
	
EndProcedure

#EndRegion
