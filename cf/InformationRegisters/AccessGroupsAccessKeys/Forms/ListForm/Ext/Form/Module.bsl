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

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	// Appearance.
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DecorationTextItem = AppearanceItem.Appearance.Items.Find("Text");
	DecorationTextItem.Value = NStr("en = 'Allowed empty access group';");
	DecorationTextItem.Use = True;
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField("AccessGroup");
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.AccessGroups.EmptyRef();
	FilterElement.Use  = True;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("AccessGroup");
	FieldItem.Use = True;
	
EndProcedure

#EndRegion
