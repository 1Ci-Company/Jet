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
	
	List.Parameters.SetParameterValue("MetadataObject", Parameters.MetadataObject);
	
	If ValueIsFilled(Parameters.MetadataObject) Then
		Items.MetadataObject.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'Updated successfully.';");
	Else
		Text = NStr("en = 'The update is not required.';");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	ParametersOfUpdate = InformationRegisters.ApplicationRuntimeParameters.ParametersOfUpdate();
	ParametersOfUpdate.AccessManagement.RolesRights.ShouldUpdate = True;
	
	InformationRegisters.ApplicationRuntimeParameters.ExecuteUpdateUnsharedDataInBackground(
		ParametersOfUpdate, UUID);
	
	If ParametersOfUpdate.AccessManagement.RolesRights.HasChanges Then
		HasChanges = True;
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
