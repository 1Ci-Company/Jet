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
Procedure UpdateRegisterData(Command)
	
	HasChanges = False;
	
	UpdateRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("en = 'Updated successfully.';tr = 'Güncelleme başarılı.'");
	Else
		Text = NStr("en = 'No update required.';tr = 'Güncelleme gerekmiyor.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	ApplyDataGroupAppearance(0, NStr("en = 'Standard Access Values';tr = 'Standart erişim değerleri'"));
	ApplyDataGroupAppearance(1, NStr("en = 'Regular or external users';tr = 'Normal veya harici kullanıcılar'"));
	ApplyDataGroupAppearance(2, NStr("en = 'Regular or external user groups';tr = 'Normal veya harici kullanıcı grupları'"));
	ApplyDataGroupAppearance(3, NStr("en = 'Assignee groups';tr = 'Icracı gruplar'"));
	ApplyDataGroupAppearance(4, NStr("en = 'Authorization objects';tr = 'Doğrulama nesneleri'"));
	
EndProcedure

&AtServer
Procedure ApplyDataGroupAppearance(DataGroup, Text)
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("DataGroup");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DataGroup");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = DataGroup;
	
	AppearanceItem.Appearance.SetParameterValue("Text", Text);
	
EndProcedure

&AtServer
Procedure UpdateRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.AccessValuesGroups.UpdateRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
