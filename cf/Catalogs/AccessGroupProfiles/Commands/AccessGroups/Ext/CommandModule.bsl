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
	
	If SimplifiedInterface() Then
		VariantKey = "UsersRightsToTables";
		
		Filter = New Structure;
		Filter.Insert("AccessGroup", CommandParameter);
		Filter.Insert("CanSignIn", True);
		
		ReportParameters = New Structure;
		ReportParameters.Insert("GenerateOnOpen", True);
		ReportParameters.Insert("Filter", Filter);
		ReportParameters.Insert("VariantKey", VariantKey);
		ReportParameters.Insert("PurposeUseKey", VariantKey);
		
		OpenForm("Report.AccessRightsAnalysis.Form", ReportParameters, ThisObject);
		
	Else
		FormParameters = New Structure;
		FormParameters.Insert("Profile", CommandParameter);
		OpenForm("Catalog.AccessGroups.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	EndIf;
	
EndProcedure

&AtServer
Function SimplifiedInterface()
	
	Return AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
EndFunction

#EndRegion
