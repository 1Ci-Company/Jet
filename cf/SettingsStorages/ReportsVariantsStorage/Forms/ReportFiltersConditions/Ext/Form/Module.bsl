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
	
	CloseOnChoice = False;
	
	FillPropertyValues(ThisObject, Parameters, "ReportSettings, SettingsComposer");
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
	
	OwnerFormType = CommonClientServer.StructureProperty(
		Parameters, "OwnerFormType", ReportFormType.Main);
	
	UpdateFilters(OwnerFormType);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFiltersTable

&AtClient
Procedure FiltersOnActivateRow(Item)
	List = Items.FiltersComparisonType.ChoiceList;
	List.Clear();
	
	String = Item.CurrentData;
	If String = Undefined
		Or String.AvailableCompareTypes = Undefined Then 
		Return;
	EndIf;
	
	For Each ComparisonKinds In String.AvailableCompareTypes Do 
		FillPropertyValues(List.Add(), ComparisonKinds);
	EndDo;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	SelectAndClose();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
	// UserSettingPresentation - NotFilled.
	// Presentation - Filled.
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.UserSettingPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.Presentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Filters.Presentation"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
	
	// UserSettingPresentation - NotFilled.
	// Presentation - NotFilled.
	// Title - Filled.
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.UserSettingPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.Presentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Filters.Title"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
EndProcedure

&AtServer
Procedure UpdateFilters(OwnerFormType)
	Rows = Filters.GetItems();
	
	AllowedDisplayModes = New Array;
	AllowedDisplayModes.Add(DataCompositionSettingsItemViewMode.Auto);
	AllowedDisplayModes.Add(DataCompositionSettingsItemViewMode.QuickAccess);
	If OwnerFormType = ReportFormType.Settings Then 
		AllowedDisplayModes.Add(DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	UserSettings = SettingsComposer.UserSettings;
	For Each UserSettingItem In UserSettings.Items Do 
		If TypeOf(UserSettingItem) <> Type("DataCompositionFilterItem")
			Or TypeOf(UserSettingItem.RightValue) = Type("StandardPeriod") Then 
			Continue;
		EndIf;
		
		SettingItem = ReportsClientServer.GetObjectByUserID(
			SettingsComposer.Settings,
			UserSettingItem.UserSettingID,,
			UserSettings);
		
		If AllowedDisplayModes.Find(SettingItem.ViewMode) = Undefined Then 
			Continue;
		EndIf;
		
		SettingDetails = ReportsClientServer.FindAvailableSetting(SettingsComposer.Settings, SettingItem);
		If SettingDetails = Undefined Then 
			Continue;
		EndIf;
		
		String = Rows.Add();
		FillPropertyValues(String, SettingDetails);
		FillPropertyValues(String, SettingItem, "Presentation, UserSettingPresentation");
		
		String.ComparisonType = UserSettingItem.ComparisonType;
		
		AvailableCompareTypes = SettingDetails.AvailableCompareTypes;
		If AvailableCompareTypes <> Undefined
			And AvailableCompareTypes.Count() > 0
			And AvailableCompareTypes.FindByValue(String.ComparisonType) = Undefined Then 
			String.ComparisonType = AvailableCompareTypes[0].Value;
		EndIf;
		
		String.Id = UserSettings.GetIDByObject(UserSettingItem);
		String.InitialComparisonType = String.ComparisonType;
	EndDo;
EndProcedure

&AtClient
Procedure SelectAndClose()
	FiltersConditions = New Map;
	
	For Each Item In Filters.GetItems() Do
		If Item.InitialComparisonType <> Item.ComparisonType Then
			FiltersConditions.Insert(Item.Id, Item.ComparisonType);
		EndIf;
	EndDo;
	
	Close(FiltersConditions);
EndProcedure

#EndRegion
