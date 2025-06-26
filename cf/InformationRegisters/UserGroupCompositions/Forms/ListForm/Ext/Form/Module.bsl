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
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	ShowMessageBox(, DataUpdateResult());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function DataUpdateResult()
	
	TemplateUpdated = NStr("en = '%1: Updated successfully.';");
	TemplateNoUpdateRequired = NStr("en = '%1: No update required.';");
	
	HasHierarchyChanges = False;
	HasChangesInComposition = False;
	
	InformationRegisters.UserGroupCompositions.UpdateHierarchyAndComposition(HasHierarchyChanges,
		HasChangesInComposition);
	
	Result = New Array;
	Result.Add(StringFunctionsClientServer.SubstituteParametersToString(
		?(HasHierarchyChanges, TemplateUpdated, TemplateNoUpdateRequired),
		Metadata.InformationRegisters.UserGroupsHierarchy.Presentation()));
	
	Result.Add(StringFunctionsClientServer.SubstituteParametersToString(
		?(HasChangesInComposition, TemplateUpdated, TemplateNoUpdateRequired),
		Metadata.InformationRegisters.UserGroupCompositions.Presentation()));
	
	Items.List.Refresh();
	
	Return StrConcat(Result, Chars.LF);
	
EndFunction

#EndRegion
