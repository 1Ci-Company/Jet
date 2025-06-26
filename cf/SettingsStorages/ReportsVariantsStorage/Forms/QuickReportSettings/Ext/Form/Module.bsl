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
	InitializeFormData();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshTitle();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersQuickSettings

&AtClient
Procedure QuickSettingsOnChange(Item)
	
	VariantModified = True;
	
EndProcedure

&AtClient
Procedure QuickSettingsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Item.CurrentItem = Items.QuickSettingsComparisonType Then 
		SelectComparisonType(Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure QuickSettingsCheckOnChange(Item)
	
	Record = Items.QuickSettings.CurrentData;
	ChangeTheDisplayModeOfTheSettingsItem(Record);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetMark(Command)
	
	 ChangeTheDisplayModeOfSettings();
	 VariantModified = True;
	
EndProcedure

&AtClient
Procedure ClearMark(Command)
	
	ChangeTheDisplayModeOfSettings(False);
	VariantModified = True;
	
EndProcedure

&AtClient
Procedure GoToAdvancedSettings(Command)
	
	ReportSettings.SettingsFormAdvancedMode = 1;
	
	DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", CurrentVariantKey);
	FormParameters.Insert("Variant", SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("DescriptionOption", DescriptionOfReportSettings.Description);
	FormParameters.Insert("PageName", "FiltersPage");
	FormParameters.Insert("ResetCustomSettings", True);
	
	OpenForm(ReportSettings.FullName + ".SettingsForm", FormParameters, FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	SaveTheOrderOfTheSettingsItems();
	
	Result = ReportsClientServer.ReportFormUpdateParameters(
		ReportsOptionsInternalClientServer.EventNameQuickSettingsChangesContent());
	Result.DCSettingsComposer = SettingsComposer;
	Result.VariantModified = VariantModified;
	Result.ResetCustomSettings = VariantModified;
	Result.UserSettingsModified = VariantModified;
	Result.Insert("OutputSettingsTitles", OutputSettingsTitles);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ElementSelectionGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	ElementSelectionGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = ElementSelectionGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuickSettings.SettingType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Type("DataCompositionSettingsParameterValue");
	
	ItemFilter = ElementSelectionGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuickSettings.SettingType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Type("DataCompositionFilterItem");
	
	Item.Appearance.SetParameterValue("Text", "");
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.QuickSettingsComparisonType.Name);
	
	//
	TheColorOfTheUnavailableValue = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("QuickSettings.SettingType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Type("DataCompositionSettingsParameterValue");
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("TextColor", TheColorOfTheUnavailableValue);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.QuickSettingsComparisonType.Name);
	
EndProcedure

#Region InitializingFormData

&AtServer
Procedure InitializeFormData()
	
	FillPropertyValues(ThisObject, Parameters, "ReportSettings, CurrentVariantKey, OutputSettingsTitles");
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
	SettingsComposer.LoadSettings(Parameters.SettingsComposer.GetSettings());
	
	FillInQuickSettings();
	
EndProcedure

&AtServer
Procedure FillInQuickSettings()
	
	InformationAboutSettings = ReportsServer.UserSettingsInfo(SettingsComposer.Settings);
	
	Schema = GetFromTempStorage(ReportSettings.SchemaURL);
	
	TheOrderOfTheSettingsElements = CommonClientServer.StructureProperty(
		SettingsComposer.Settings.AdditionalProperties, "TheOrderOfTheSettingsElements", New Map);
	
	UserSettings = SettingsComposer.UserSettings.Items;
	
	For Each SetupInformation In InformationAboutSettings Do 
		
		UserSettingID = SetupInformation.Key;
		ItemTheCustomSettings = UserSettings.Find(UserSettingID);
		
		If ItemTheCustomSettings = Undefined Then 
			Continue;
		EndIf;
		
		Settings = SetupInformation.Value.Settings;
		If TypeOf(Settings) <> Type("DataCompositionSettings") Then 
			Settings = SettingsComposer.Settings;
		EndIf;
		
		SettingDetails = SetupInformation.Value.SettingDetails;
		SettingsItem = SetupInformation.Value.SettingItem;
		
		If TheSchemeParameterIsDisabled(Schema, SettingsItem) Then 
			Continue;
		EndIf;
		
		SettingType = TypeOf(SettingsItem);
		
		If SettingType = Type("DataCompositionFilter") Then 
			Continue;
		EndIf;
		
		Record = QuickSettings.Add();
		Record.Check = (SettingsItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess);
		Record.Title = TitleSettings(SettingsItem, SettingDetails, SettingType, ItemTheCustomSettings);
		Record.UserSettingID = UserSettingID;
		Record.SettingType = SettingType;
		Record.PictureSettings = PictureSettings(SettingsItem, SettingType);
		
		If SettingDetails <> Undefined Then 
			Record.ValueType = SettingDetails.ValueType;
		EndIf;
		
		SetTheFilterCondition(Record, SettingDetails, SettingType, UserSettingID);
		
		TheOrderOfTheElement = TheOrderOfTheSettingsElements[UserSettingID];
		
		If TheOrderOfTheElement <> Undefined Then 
			Record.Order = TheOrderOfTheElement;
		EndIf;
		
	EndDo;
	
	QuickSettings.Sort("Order");
	
	FoundRecords = QuickSettings.FindRows(New Structure("Order", 0));
	
	If FoundRecords.Count() = 0 Then 
		Return;
	EndIf;
	
	Order = QuickSettings[QuickSettings.Count() - 1].Order;
	
	For Each Record In FoundRecords Do 
		
		Order = Order + 1;
		Record.Order = Order;
		
	EndDo;
	
	QuickSettings.Sort("Order");
	
EndProcedure

// Parameters:
//  Schema - DataCompositionSchema
//  SettingsItem - DataCompositionSettingsParameterValue
//
// Returns:
//  Boolean
//
&AtServer
Function TheSchemeParameterIsDisabled(Schema, SettingsItem)
	
	If TypeOf(SettingsItem) <> Type("DataCompositionSettingsParameterValue") Then 
		Return False;
	EndIf;
	
	SchemeParameter = Schema.Parameters.Find(String(SettingsItem.Parameter));
	
	If SchemeParameter = Undefined Then 
		Return False;
	EndIf;
	
	Return SchemeParameter.UseRestriction;
	
EndFunction

&AtServer
Function TitleSettings(SettingsItem, SettingDetails, SettingType, ItemTheCustomSettings)
	
	SettingValue = SettingValue(SettingsItem, SettingDetails, SettingType, ItemTheCustomSettings);
	SettingPresentation = SettingPresentation(SettingsItem, SettingDetails, SettingType);

	If TypeOf(SettingValue) = Type("DataCompositionField") Then
		AvailableField = SettingsComposer.Settings.Selection.SelectionAvailableFields.FindField(SettingValue);
		If AvailableField <> Undefined Then
			SettingValue = AvailableField.Title;
		EndIf;
	EndIf;
	
	If ValueIsFilled(SettingValue)
		And SettingValue <> SettingPresentation Then 
		
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (%2)';"), SettingValue, SettingPresentation);
		
	EndIf;
	
	Return SettingPresentation;
	
EndFunction

&AtServer
Function SettingValue(SettingsItem, SettingDetails, SettingType, ItemTheCustomSettings)
	
	SettingValue = Undefined;
	NameOfTheConfigurationField = Undefined;
	
	If SettingType = Type("DataCompositionSettingsParameterValue")
		And TypeOf(ItemTheCustomSettings.Value) <> Type("Boolean") Then 
		
		SettingValue = ItemTheCustomSettings.Value;
		NameOfTheConfigurationField = String(SettingsItem.Parameter);
		
	ElsIf SettingType = Type("DataCompositionFilterItem")
		And Not (TypeOf(ItemTheCustomSettings.RightValue) = Type("Boolean")
		And ValueIsFilled(SettingsItem.Presentation)) Then 
		
		SettingValue = ItemTheCustomSettings.RightValue;
		NameOfTheConfigurationField = String(SettingsItem.LeftValue);
	Else
		Return SettingValue;
	EndIf;
	
	If SettingDetails <> Undefined
		And SettingDetails.AvailableValues <> Undefined Then 
		
		AvailableValue = SettingDetails.AvailableValues.FindByValue(SettingValue);
		
		If AvailableValue <> Undefined
			And ValueIsFilled(AvailableValue.Presentation) Then 
			
			Return AvailableValue.Presentation;
		EndIf;
		
	EndIf;
	
	AvailableValues = CommonClientServer.StructureProperty(
		SettingsComposer.Settings.AdditionalProperties, "AvailableValues");
	
	If NameOfTheConfigurationField = Undefined
		Or TypeOf(AvailableValues) <> Type("Structure") Then 
		
		Return SettingValue;
	EndIf;
	
	Try
		AvailableSettingValues = CommonClientServer.StructureProperty(
			AvailableValues, NameOfTheConfigurationField, New ValueList);
	Except
		Return SettingValue;
	EndTry;
	
	TheFoundSettingValue = AvailableSettingValues.FindByValue(SettingValue);
	
	If TheFoundSettingValue <> Undefined
		And ValueIsFilled(TheFoundSettingValue.Presentation) Then 
		
		Return TheFoundSettingValue.Presentation;
	EndIf;
	
	If Not ValueIsFilled(SettingValue) Then 
		Return NStr("en = 'Not set';");
	EndIf;
	
	Return String(SettingValue);
	
EndFunction

// Parameters:
//  SettingsItem - DataCompositionFilterItem
//                  - DataCompositionOrder
//                  - DataCompositionOrderItem
//                  - DataCompositionConditionalAppearance
//                  - DataCompositionConditionalAppearanceItem
//                  - DataCompositionSelectedFields
//  SettingDetails - DataCompositionAvailableField
//                    - DataCompositionFilterAvailableField
//  SettingType - Type
//
// Returns:
//  String
//
&AtServer
Function SettingPresentation(SettingsItem, SettingDetails, SettingType)
	
	SettingPresentation = "";
	
	If ValueIsFilled(SettingsItem.UserSettingPresentation) Then 
		
		SettingPresentation = SettingsItem.UserSettingPresentation;
		
	ElsIf SettingType = Type("DataCompositionFilterItem")
		And ValueIsFilled(SettingsItem.Presentation) Then 
		
		SettingPresentation = SettingsItem.Presentation;
		
	ElsIf SettingDetails <> Undefined Then 
		
		SettingPresentation = SettingDetails.Title;
		
	ElsIf SettingType = Type("DataCompositionSettings")
		Or SettingType = Type("DataCompositionGroup")
		Or SettingType = Type("DataCompositionChart")
		Or SettingType = Type("DataCompositionChartGroup")
		Or SettingType = Type("DataCompositionTable")
		Or SettingType = Type("DataCompositionTableGroup") Then 
		
		SettingPresentation = ReportsOptionsInternal.RepresentationOfAStructureElement(SettingsItem);
		
	ElsIf SettingType = Type("DataCompositionSettingStructureItemCollection")
		Or SettingType = Type("DataCompositionTableStructureItemCollection")
		Or SettingType = Type("DataCompositionChartStructureItemCollection") Then 
		
		SettingPresentation = ReportsOptionsInternal.RepresentationOfStructureElements(SettingsItem);
		
	ElsIf SettingType = Type("DataCompositionSelectedFields") Then 
		
		SettingPresentation = ReportsOptionsInternal.RepresentationOfSelectedFields(SettingsItem);
		
	ElsIf SettingType = Type("DataCompositionOrder") Then 
		
		SettingPresentation = ReportsOptionsInternal.SortingView(SettingsItem);
		
	ElsIf SettingType = Type("DataCompositionOrderItem") Then 
		
		SettingPresentation = ReportsOptionsInternal.RepresentationOfTheSortingElement(SettingsItem);
		
	ElsIf SettingType = Type("DataCompositionConditionalAppearance") Then 
		
		SettingPresentation = ReportsOptionsInternal.PresentationOfTheConditionalDesign(SettingsItem);
			
	ElsIf SettingType = Type("DataCompositionConditionalAppearanceItem") Then 
		
		SettingPresentation = ReportsClientServer.ConditionalAppearanceItemPresentation(
			SettingsItem, Undefined, "");
		
	EndIf;
	
	Return SettingPresentation;
	
EndFunction

&AtServer
Function PictureSettings(SettingsItem, SettingType)
	
	PictureSettings = -1;
	
	If SettingType = Type("DataCompositionSettingsParameterValue")
		Or SettingType = Type("DataCompositionFilterItem") Then 
		
		PictureSettings = 17;
		
	ElsIf SettingType = Type("DataCompositionSettings") Then 
		
		PictureSettings = 20;
		
	ElsIf SettingType = Type("DataCompositionGroup")
		Or SettingType = Type("DataCompositionChartGroup")
		Or SettingType = Type("DataCompositionTableGroup") Then 
		
		PictureSettings = 7;
		
	ElsIf SettingType = Type("DataCompositionSettingStructureItemCollection")
		Or SettingType = Type("DataCompositionTableStructureItemCollection")
		Or SettingType = Type("DataCompositionChartStructureItemCollection") Then 
		
		PictureSettings = 22;
		
	ElsIf SettingType = Type("DataCompositionTable") Then 
		
		PictureSettings = 9;
		
	ElsIf SettingType = Type("DataCompositionChart") Then 
		
		PictureSettings = 11;
		
	ElsIf SettingType = Type("DataCompositionSelectedFields") Then 
		
		PictureSettings = 18;
		
	ElsIf SettingType = Type("DataCompositionOrder")
		Or SettingType = Type("DataCompositionOrderItem") Then 
		
		PictureSettings = 19;
		
	ElsIf SettingType = Type("DataCompositionConditionalAppearance")
		Or SettingType = Type("ConditionalAppearanceItem") Then 
		
		PictureSettings = 20;
		
	EndIf;
	
	Return PictureSettings;
	
EndFunction

&AtServer
Procedure SetTheFilterCondition(Record, SettingDetails, SettingType, UserSettingID)
	
	If SettingType <> Type("DataCompositionSettingsParameterValue")
		And SettingType <> Type("DataCompositionFilterItem") Then 
		
		Return;
	EndIf;
	
	ItemTheCustomSettings = SettingsComposer.UserSettings.Items.Find(
		UserSettingID);
	
	If SettingType = Type("DataCompositionFilterItem") Then 
		Record.ComparisonType = ItemTheCustomSettings.ComparisonType;
	EndIf;
	
	If SettingDetails = Undefined Then 
		Return;
	EndIf;
	
	If SettingType = Type("DataCompositionSettingsParameterValue") Then 
		
		If SettingDetails.ValueListAllowed Then 
			Record.ComparisonType = DataCompositionComparisonType.InList;
		Else
			Record.ComparisonType = DataCompositionComparisonType.Equal;
		EndIf;
		
		Return;
		
	EndIf;
	
	AvailableConditions = Record.AvailableCompareTypes;
	
	For Each Item In SettingDetails.AvailableCompareTypes Do 
		FillPropertyValues(AvailableConditions.Add(), Item);
	EndDo;
	
	If AvailableConditions.FindByValue(Record.ComparisonType) = Undefined Then
		Record.ComparisonType = AvailableConditions[0].Value;
	EndIf;
	
EndProcedure

#EndRegion

#Region ChangingTheDisplayMode

&AtClient
Procedure ChangeTheDisplayModeOfSettings(Check = True)
	
	For Each Record In QuickSettings Do 
		
		Record.Check = Check;
		ChangeTheDisplayModeOfTheSettingsItem(Record);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeTheDisplayModeOfTheSettingsItem(Record)
	
	Settings = SettingsComposer.UserSettings;
	
	SettingsItems = Settings.GetMainSettingsByUserSettingID(
		Record.UserSettingID);
	
	SettingsItem = SettingsItems[0];
	
	If Record.Check Then 
		SettingsItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	Else
		SettingsItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	EndIf;
	
	RefreshTitle();
	
EndProcedure

#EndRegion

&AtClient
Procedure RefreshTitle()
	
	NumberOfQuickSettings = 0;
	
	For Each Record In QuickSettings Do 
		
		If Record.Check Then
			NumberOfQuickSettings = NumberOfQuickSettings + 1;
		EndIf;
		
	EndDo;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Quick settings (%1 of %2)';"), NumberOfQuickSettings, QuickSettings.Count());
	
EndProcedure

&AtClient
Procedure SelectComparisonType(Item, StandardProcessing)
	
	Record = Items.QuickSettings.CurrentData;
	
	If Record = Undefined
		Or Record.SettingType <> Type("DataCompositionFilterItem") Then 
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	ChoiceParameters = New Structure("RecordID", Items.QuickSettings.CurrentRow);
	
	ShowChooseFromMenu(
		New NotifyDescription("AfterSelectingTheTypeOfComparison", ThisObject, ChoiceParameters),
		Record.AvailableCompareTypes,
		Item);
	
EndProcedure

&AtClient
Procedure AfterSelectingTheTypeOfComparison(SelectedTypeOfComparison, AdditionalParameters) Export 
	
	If TypeOf(SelectedTypeOfComparison) <> Type("ValueListItem") Then 
		Return;
	EndIf;
	
	Record = QuickSettings.FindByID(AdditionalParameters.RecordID);
	Record.ComparisonType = SelectedTypeOfComparison.Value;
	
	Settings = SettingsComposer.UserSettings;
	
	SettingsItems = Settings.GetMainSettingsByUserSettingID(
		Record.UserSettingID);
	
	SettingsItem = SettingsItems[0];
	SettingsItem.ComparisonType = SelectedTypeOfComparison.Value;
	
	VariantModified = True;
	
EndProcedure

// Parameters:
//  LongDesc - See ReportsOptions.ReportFormSettings
//
// Returns:
//   See ReportsOptions.ReportFormSettings
//
&AtClientAtServerNoContext
Function DescriptionOfReportSettings(LongDesc)
	
	Return LongDesc;
	
EndFunction

&AtClient
Procedure SaveTheOrderOfTheSettingsItems()
	
	TheOrderOfTheSettingsElements = New Map;
	
	Order = 0;
	
	For Each Record In QuickSettings Do 
		
		Order = Order + 1;
		Record.Order = Order;
		TheOrderOfTheSettingsElements.Insert(Record.UserSettingID, Order);
		
	EndDo;
	
	SettingsComposer.Settings.AdditionalProperties.Insert("TheOrderOfTheSettingsElements", TheOrderOfTheSettingsElements);
	
EndProcedure

#EndRegion