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

#If MobileClient Then
	OpenForm("InformationRegister.ReportsSnapshots.Form.ReportViewForm");
#Else
	CommonClient.MessageToUser(NStr(
			"en = 'This command is used in the mobile client.';"));
#EndIf

EndProcedure

#EndRegion