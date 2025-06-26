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
	
	DataProcessorName      = "";
	DataProcessorFormName = "";
	
	If CommonClient.SeparatedDataUsageAvailable() Then
		DataProcessorName      = "SSLAdministrationPanel";
		DataProcessorFormName = "DataSynchronization";
	Else
		If Not CommonClient.SubsystemExists("CloudTechnology") Then
			Return;
		EndIf;
		
		DataProcessorName      = "SSLAdministrationPanelSaaS";
		DataProcessorFormName = "DataSynchronizationForServiceAdministrator";
	EndIf;
	
	NameOfFormToOpen_ = "DataProcessor.[DataProcessorName].Form.[DataProcessorFormName]";
	NameOfFormToOpen_ = StrReplace(NameOfFormToOpen_, "[DataProcessorName]", DataProcessorName);
	NameOfFormToOpen_ = StrReplace(NameOfFormToOpen_, "[DataProcessorFormName]", DataProcessorFormName);
	
	OpenForm(
		NameOfFormToOpen_,
		New Structure,
		CommandExecuteParameters.Source,
		NameOfFormToOpen_ + ?(CommandExecuteParameters.Window = Undefined, ".SingleWindow", ""),
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
