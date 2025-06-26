///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Handles mouse double-click, "Enter" key, and hyperlink activation in report spreadsheets.
// See "Form field extension for a spreadsheet document field.Choice" in Syntax Assistant.
//
// Parameters:
//   ReportForm          - ClientApplicationForm - a report form.
//   Item              - FormField        - a spreadsheet document.
//   Area              - SpreadsheetDocumentRange - a selected value.
//   StandardProcessing - Boolean - indicates whether standard event processing is executed.
//
Procedure SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing) Export
	
	If ReportForm.ReportSettings.FullName = "Report.DocumentRegisterRecords" Then
		
		If Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle
			And TypeOf(Area.Details) = Type("Structure") Then
			OpenRegisterFormFromRecordsReport(ReportForm, Area.Details, StandardProcessing);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Open the register form with filter by recorder
//
// Parameters:
//   ReportForm      - ClientApplicationForm - a report form.
//   Details      - Structure:
//      * RegisterType - a register kind: "AccumulationRegister", "InformationRegister", "AccountingRegister", or "CalculationRegister".
//      * RegisterName - a name of a register as a metadata object.
//      * Recorder - a reference to a document recorder for which you need to make a filter
//                      in the opened register form.
//   StandardProcessing - Boolean  - indicates whether standard (system) event processing is executed.
//
Procedure OpenRegisterFormFromRecordsReport(ReportForm, Details, StandardProcessing)

	StandardProcessing = False;
	
	UserSettings    = New DataCompositionUserSettings;
	Filter                        = UserSettings.Items.Add(Type("DataCompositionFilter"));
	FilterElement                = Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField(Details.RecorderFieldName);
	FilterElement.RightValue = Details.Recorder;
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.Use  = True;
	
	RegisterFormName = StringFunctionsClientServer.SubstituteParametersToString("%1.%2.ListForm",
		Details.RegisterType, Details.RegisterName);
	
	RegisterForm = GetForm(RegisterFormName);
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Field",          Details.RecorderFieldName);
	FilterParameters.Insert("Value",      Details.Recorder);
	FilterParameters.Insert("ComparisonType",  DataCompositionComparisonType.Equal);
	FilterParameters.Insert("Use", True);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ToUserSettings", True);
	AdditionalParameters.Insert("ReplaceCurrent",       True);
	
	AddFilter(RegisterForm.List.SettingsComposer, FilterParameters, AdditionalParameters);
	
	RegisterForm.Open();
	
EndProcedure

// Adds a filter to the collection of the composer filters or group of selections
//
// Parameters:
//   StructureItem        - DataCompositionSettingsComposer
//                           - DataCompositionSettings - a data composition structure item.
//   FilterParameters         - Structure - contains data composition filter parameters.:
//     * Field                - String - a field name, by which a filter is added.
//     * Value            - Arbitrary - a filter value of data composition (Undefined by default).
//     * ComparisonType        - DataCompositionComparisonType - a comparison type of data composition (Undefined by default).
//     * Use       - Boolean - indicates that filter is used (True by default).
//   AdditionalParameters - Structure - contains additional parameters, listed below:
//     * ToUserSettings - Boolean - a flag of adding to data composition user settings (False by default).
//     * ReplaceCurrent       - Boolean - a flag of complete replacement of existing filter by field (True by default).
//
// Returns:
//   DataCompositionFilterItem - an added filter.
//
Function AddFilter(StructureItem, FilterParameters, AdditionalParameters = Undefined)
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ToUserSettings", False);
		AdditionalParameters.Insert("ReplaceCurrent",       True);
	Else
		If Not AdditionalParameters.Property("ToUserSettings") Then
			AdditionalParameters.Insert("ToUserSettings", False);
		EndIf;
		If Not AdditionalParameters.Property("ReplaceCurrent") Then
			AdditionalParameters.Insert("ReplaceCurrent", True);
		EndIf;
	EndIf;
	
	If TypeOf(FilterParameters.Field) = Type("String") Then
		NewField = New DataCompositionField(FilterParameters.Field);
	Else
		NewField = FilterParameters.Field;
	EndIf;
	
	ExistingUserSettingID = Undefined;
	
	If TypeOf(StructureItem) = Type("DataCompositionSettingsComposer") Then
		Filter = StructureItem.Settings.Filter;
		
		If AdditionalParameters.ToUserSettings Then
			
			For Each Item In Filter.Items Do
				If Item.LeftValue = NewField Then
					ExistingUserSettingID = Item.UserSettingID;
					ExistingFilter = Item;
					Break;
				EndIf;
			EndDo;
			
			For Each SettingItem In StructureItem.UserSettings.Items Do
				If SettingItem.UserSettingID =
					StructureItem.Settings.Filter.UserSettingID Then
					Filter = SettingItem;
				EndIf;
			EndDo;
		EndIf;
	
	ElsIf TypeOf(StructureItem) = Type("DataCompositionSettings") Then
		Filter = StructureItem.Filter;
	Else
		Filter = StructureItem;
	EndIf;
	
	FilterElement = Undefined;
	If AdditionalParameters.ReplaceCurrent Then
		For Each Item In Filter.Items Do
	
			If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then
				Continue;
			EndIf;
	
			If Item.LeftValue = NewField Then
				FilterElement = Item;
			EndIf;
	
		EndDo;
		
		If ExistingUserSettingID <> Undefined Then
			FilterElement = ExistingFilter;
			For Each Item In StructureItem.UserSettings.Items Do
				If Item.UserSettingID = ExistingUserSettingID Then
					Item.Use  = FilterParameters.Use;
					Item.ComparisonType   = ?(FilterParameters.ComparisonType = Undefined, DataCompositionComparisonType.Equal,
						FilterParameters.ComparisonType);
					Item.RightValue = FilterParameters.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If FilterElement = Undefined Then
		FilterElement = Filter.Items.Add(Type("DataCompositionFilterItem"));
	EndIf;
	FilterElement.Use  = FilterParameters.Use;
	FilterElement.LeftValue  = NewField;
	FilterElement.ComparisonType   = ?(FilterParameters.ComparisonType = Undefined, DataCompositionComparisonType.Equal,
		FilterParameters.ComparisonType);
	FilterElement.RightValue = FilterParameters.Value;
	
	Return FilterElement;
	
EndFunction

#EndRegion