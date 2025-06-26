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
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormName = "DataProcessor.SSLAdministrationPanel.Form.FilesOperationSettings";
	
	If Not CommonClient.SeparatedDataUsageAvailable() Then
		FormName = FormName + "InSaaS";
	EndIf;
	
	OpenForm(
		FormName,
		New Structure,
		CommandExecuteParameters.Source,
		FormName + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
