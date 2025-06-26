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

	SetConditionalAppearance();
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateAuxiliaryRegisterData(Command)
	
	HasChanges = False;
	
	UpdateAuxiliaryRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'Updated successfully.';");
	Else
		Text = NStr("en = 'No update required.';");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("en = 'All tables except for selected ones';"));
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("Table");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("Table");
	
EndProcedure

&AtServer
Procedure UpdateAuxiliaryRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ObjectsRightsSettings.UpdateAuxiliaryRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
