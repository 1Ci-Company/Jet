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
	
	DefineBehaviorInMobileClient();
	FillPropertyValues(ThisObject, Parameters, "ReportSettings, SettingsComposer, CurrentVariantKey");
	TitleProperties = Parameters.TitleProperties;
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Filter by: %1';"), TitleProperties.Text);
	InitializeFormData();
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	BringTheRightValuesToTheCondition();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterItemsGroupTypeOnChange(Item)
	
	GroupUse = True;
	Use2 = True;
	
EndProcedure

&AtClient
Procedure ComparisonType1OnChange(Item)
	
	BringTheRightValueToTheCondition(1);
	
EndProcedure

&AtClient
Procedure RightValue1StartChoice(Item, ChoiceData, StandardProcessing)
	
	RightValueStartChoice(Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure RightValue1ChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	RightValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
EndProcedure

&AtClient
Procedure GroupUseOnChange(Item)
	
	Use2 = GroupUse;
	
EndProcedure

&AtClient
Procedure LeftValue2OnChange(Item)
	
	If ValueIsFilled(LeftValue2) Then 
		
		GroupUse = True;
		Use2 = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ComparisonType2OnChange(Item)
	
	GroupUse = True;
	Use2 = True;
	
	BringTheRightValueToTheCondition(2);
	
EndProcedure

&AtClient
Procedure RightValue2OnChange(Item)
	
	GroupUse = True;
	Use2 = True;
	
EndProcedure

&AtClient
Procedure RightValue2StartChoice(Item, ChoiceData, StandardProcessing)
	
	RightValueStartChoice(Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure RightValue2ChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	RightValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GoToAdvancedSettings(Command)
	
	Settings = SettingsComposer.Settings.GetObjectByID(TitleProperties.IDOfTheSettings);
	GroupingTheFilter = ReportsOptionsInternalClientServer.GroupingTheFilter(Settings, TitleProperties);
	IDFilterGrouping = Settings.GetIDByObject(GroupingTheFilter);
	
	PathToSettingsStructureItem = ReportsClient.FullPathToSettingsItem(
		SettingsComposer.Settings, GroupingTheFilter);
	
	DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);
	
	If TypeOf(GroupingTheFilter) = Type("DataCompositionSettings") Then 
		
		TitleFilterGrouping = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '""%1"" report filters';"),
			DescriptionOfReportSettings.Description);
		
	Else
		
		TitleFilterGrouping = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Filters of the ""%1"" grouping of the ""%2"" report';"),
			String(GroupingTheFilter.GroupFields),
			DescriptionOfReportSettings.Description);
		
	EndIf;
	
	AddFilters();
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", CurrentVariantKey);
	FormParameters.Insert("Variant", SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("DescriptionOption", DescriptionOfReportSettings.Description);
	FormParameters.Insert("SettingsStructureItemID", IDFilterGrouping);
	FormParameters.Insert("PathToSettingsStructureItem", PathToSettingsStructureItem);
	FormParameters.Insert("SettingsStructureItemType", String(TypeOf(GroupingTheFilter)));
	FormParameters.Insert("Title", TitleFilterGrouping);
	FormParameters.Insert("PageName", "FiltersPage");
	FormParameters.Insert("DisplayPages", False);
	
	OpenForm(ReportSettings.FullName + ".SettingsForm", FormParameters, FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure ApplyISform(Command)
	
	ApplyFilters(True);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	ApplyFilters(False);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DefineBehaviorInMobileClient()
	
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then 
		Return;
	EndIf;
	
	BasicCommands = Items.CommandsBasic.ChildItems;
	
	For CommandNumber = 1 To BasicCommands.Count() Do 
		Items.Move(BasicCommands[0], Items.FormCommandBar);
	EndDo;
	
	Items.ApplyISform.Representation = ButtonRepresentation.Picture;
	
EndProcedure

#Region InitializingFormData

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RepresentationOfTheLeftValue1");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("LeftValue1"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.LeftValue1.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RepresentationOfTheLeftValue2");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("LeftValue2"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.LeftValue2.Name);
	
EndProcedure

&AtServer
Procedure InitializeFormData()
	
	DisplayFilters = Undefined;
	FilterDescription = FilterDescription(SettingsComposer, TitleProperties, DisplayFilters);
	
	If FilterDescription <> Undefined Then 
		FilterValueType = FilterDescription.ValueType;
	EndIf;
	
	SetTheLeftValue(TitleProperties.Field);
	SetTheAvailableTypesOfComparison(FilterDescription);
	SetTheRightValue(FilterDescription);
	
	FilterItemsGroupType = Items.FilterItemsGroupType.ChoiceList[0].Value;
	
	FindFilters(DisplayFilters);
	
EndProcedure

&AtServer
Procedure SetTheLeftValue(Field)
	
	For ItemNumber = 1 To 2 Do 
		
		TagName = StringFunctionsClientServer.SubstituteParametersToString(
			"LeftValue%1", ItemNumber);
		
		ThisObject[TagName] = Field;
		Items[TagName].TypeRestriction = New TypeDescription("DataCompositionField");
		
		TagName = StringFunctionsClientServer.SubstituteParametersToString(
			"RepresentationOfTheLeftValue%1", ItemNumber);
		
		ThisObject[TagName] = TitleProperties.Text;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTheAvailableTypesOfComparison(FilterDescription)
	
	If FilterDescription = Undefined Then 
		ComparisonKinds = DataCompositionComparisonType;
	Else
		ComparisonKinds = FilterDescription.AvailableCompareTypes.UnloadValues();
	EndIf;
	
	For ItemNumber = 1 To 2 Do 
		
		TagName = StringFunctionsClientServer.SubstituteParametersToString(
			"ComparisonType%1", ItemNumber);
		
		Items[TagName].AvailableTypes = New TypeDescription("DataCompositionComparisonType");
		
		List = Items[TagName].ChoiceList;
		
		For Each CurrentKind In ComparisonKinds Do 
			List.Add(CurrentKind);
		EndDo;
		
		ThisObject[TagName] = List[0].Value;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTheRightValue(FilterDescription)
	
	If FilterDescription <> Undefined
		And FilterDescription.AvailableValues <> Undefined Then 
		
		AvailableValues = FilterDescription.AvailableValues;
	EndIf;
	
	For ItemNumber = 1 To 2 Do 
		
		TagName = StringFunctionsClientServer.SubstituteParametersToString(
			"RightValue%1", ItemNumber);
		
		RightValueField = Items[TagName];
		RightValueField.ChoiceList.Clear();
		
		For Each AvailableValue In AvailableValues Do 
			FillPropertyValues(RightValueField.ChoiceList.Add(), AvailableValue);
		EndDo;
		
		RightValueField.ListChoiceMode = RightValueField.ChoiceList.Count() > 0;
		
		Condition = ThisObject[StrTemplate("ComparisonType%1", ItemNumber)];
		DetermineTheAvailabilityOfTheRightValueField(RightValueField, Condition);
		
	EndDo;
	
	AvailableTypes = ?(FilterDescription = Undefined, New TypeDescription("Undefined"), FilterDescription.ValueType);
	DetailsData = GetFromTempStorage(Parameters.DetailsData);
	
	CellValue = ReportsOptionsInternal.CellValue(Parameters.Cell, AvailableTypes, DetailsData);
	RightValue1 = CellValue.Value;
	
EndProcedure

// Parameters:
//  Filter - DataCompositionFilter
//
&AtServer
Procedure FindFilters(Filter)
	
	For Each Item In Filter.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			
			GroupUse = Item.Use;
			GroupItems1 = Item.Items;
			
			If GroupItems1.Count() <> 2
				Or GroupItems1[0].LeftValue <> LeftValue1
				Or GroupItems1[1].LeftValue <> LeftValue2 Then 
				
				Continue;
			EndIf;
			
			SetFilterProperties(GroupItems1[0], 1);
			SetFilterProperties(GroupItems1[1], 2);
			
			FilterItemsGroupType = StrReplace(Item.GroupType, " ", "");
			
		ElsIf Item.LeftValue = LeftValue1 Then 
			
			SetFilterProperties(Item, 1);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetFilterProperties(Filter, ItemNumber)
	
	If Not Filter.Use Then 
		Return;
	EndIf;
	
	ThisObject[StrTemplate("Use%1", ItemNumber)] = Filter.Use;
	ThisObject[StrTemplate("ComparisonType%1", ItemNumber)] = Filter.ComparisonType;
	ThisObject[StrTemplate("RightValue%1", ItemNumber)] = Filter.RightValue;
	
EndProcedure

#EndRegion

#Region AddingAFilter

&AtClient
Procedure AddFilters()
	
	DisplayFilters = DisplayFilters(SettingsComposer, TitleProperties);
	
	RemoveFilters(DisplayFilters);
	
	If GroupUse Then 
		
		Var_Group = FilterGroup(DisplayFilters);
		AddAFilter(Var_Group, LeftValue1, ComparisonType1, RightValue1);
		AddAFilter(Var_Group, LeftValue2, ComparisonType2, RightValue2, 1);
		
	Else
		
		AddAFilter(DisplayFilters, LeftValue1, ComparisonType1, RightValue1);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RemoveFilters(DisplayFilters)
	
	FiltersToDelete = New Array;
	
	For Each Item In DisplayFilters.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			
			GroupItems1 = Item.Items;
			
			If GroupItems1.Count() = 2
				And GroupItems1[0].LeftValue = LeftValue1
				And GroupItems1[1].LeftValue = LeftValue2 Then 
				
				FiltersToDelete.Add(Item);
			EndIf;
			
		ElsIf Item.LeftValue = LeftValue1 Then 
			
			FiltersToDelete.Add(Item);
			
		EndIf;
		
	EndDo;
	
	For Each Filter In FiltersToDelete Do 
		DisplayFilters.Items.Delete(Filter);
	EndDo;
	
EndProcedure

&AtClient
Function FilterGroup(Filter)
	
	Var_Group = Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	Var_Group.GroupType = DataCompositionFilterItemsGroupType[FilterItemsGroupType];
	Var_Group.Use = GroupUse;
	
	Return Var_Group;
	
EndFunction

&AtClient
Procedure AddAFilter(Filter, LeftValue, Var_ComparisonType, RightValue, IndexOf = 0)
	
	Item = Filter.Items.Add(Type("DataCompositionFilterItem"));
	Item.LeftValue = LeftValue;
	Item.ComparisonType = Var_ComparisonType;
	Item.RightValue = RightValue;
	Item.Use = True;
	
EndProcedure

#EndRegion

&AtClient
Procedure BringTheRightValuesToTheCondition()
	
	For ItemNumber = 1 To 2 Do 
		BringTheRightValueToTheCondition(ItemNumber);
	EndDo;
	
EndProcedure

&AtClient
Procedure BringTheRightValueToTheCondition(ItemNumber)
	
	Condition = ThisObject[StrTemplate("ComparisonType%1", ItemNumber)];
	
	NameOfTheRightValue = StrTemplate("RightValue%1", ItemNumber);
	RightValueField = Items[NameOfTheRightValue];
	
	If ReportsClientServer.IsListComparisonKind(Condition) Then 
		
		RightValue = ReportsClientServer.ValuesByList(ThisObject[NameOfTheRightValue]);
		ThisObject[NameOfTheRightValue] = RightValue;
		ThisObject[NameOfTheRightValue].ValueType = FilterValueType;
		
		RefineTheRightValue(ThisObject[NameOfTheRightValue]);
		
		RightValueField.TypeRestriction = New TypeDescription("ValueList");
		RightValueField.ChooseType = False;
		RightValueField.ListChoiceMode = False;
		RightValueField.ChoiceButton = True;
		
	Else
		
		If TypeOf(ThisObject[NameOfTheRightValue]) = Type("ValueList") Then 
		
			If ThisObject[NameOfTheRightValue].Count() > 0 Then 
				RightValue = ThisObject[NameOfTheRightValue][0].Value;
			Else
				RightValue = FilterValueType.AdjustValue();
			EndIf;
			
			ThisObject[NameOfTheRightValue] = RightValue;
			
		EndIf;
		
		AvailableTypes = FilterValueType.Types();
		IsString = AvailableTypes.Count() = 1 And AvailableTypes.Find(Type("String")) <> Undefined;
		
		FilterDescription = FilterDescription(SettingsComposer, TitleProperties);
		ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
			?(FilterDescription = Undefined, Undefined, FilterDescription.ChoiceFoldersAndItems), Condition);
		
		RightValueField.TypeRestriction = FilterValueType;
		RightValueField.ChooseType = (AvailableTypes.Count() <> 1);
		RightValueField.ListChoiceMode = (RightValueField.ChoiceList.Count() > 0);
		RightValueField.ChoiceButton = Not IsString And Not RightValueField.ListChoiceMode;
		RightValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(ChoiceFoldersAndItems, Condition);
		
	EndIf;
	
	DetermineTheAvailabilityOfTheRightValueField(RightValueField, Condition);
	
EndProcedure

&AtClient
Procedure RefineTheRightValue(RightValue)
	
	If TypeOf(RightValue) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	For Each Item In RightValue Do 
		
		AvailableValue = AvailableValues.FindByValue(Item.Value);
		
		If AvailableValue <> Undefined Then 
			FillPropertyValues(Item, AvailableValue);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RightValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	RightValue = ThisObject[Item.Name];
	
	If TypeOf(RightValue) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FilterDescription = FilterDescription(SettingsComposer, TitleProperties);
	Filter = Filter(SettingsComposer, TitleProperties);
	
	ChoiceParameters = ReportsClientServer.ChoiceParameters(
		SettingsComposer.Settings, SettingsComposer.UserSettings.Items, Filter);
	
	ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
		?(FilterDescription = Undefined, Undefined, FilterDescription.ChoiceFoldersAndItems), ComparisonType);
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Marked", RightValue);
	OpeningParameters.Insert("TypeDescription", RightValue.ValueType);
	OpeningParameters.Insert("ValuesForSelection", Item.ChoiceList);
	OpeningParameters.Insert("ValuesForSelectionFilled", Item.ChoiceList.Count() > 0);
	OpeningParameters.Insert("RestrictSelectionBySpecifiedValues", AvailableValues.Count() > 0);
	OpeningParameters.Insert("Presentation", TitleProperties.Text);
	OpeningParameters.Insert("ChoiceParameters", New Array(ChoiceParameters));
	OpeningParameters.Insert("ChoiceFoldersAndItems", ChoiceFoldersAndItems);
	OpeningParameters.Insert("QuickChoice", ?(FilterDescription = Undefined, False, FilterDescription.QuickChoice));
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes", OpeningParameters, Item);
	
EndProcedure

&AtClient
Procedure RightValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If TypeOf(ValueSelected) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	RightValue = ThisObject[Item.Name];
	RightValue.Clear();
	
	For Each Item In ValueSelected Do 
		
		If Item.Check Then 
			FillPropertyValues(RightValue.Add(), Item);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ApplyFilters(RebuildReport)
	
	AddFilters();
	
	Result = ReportsOptionsInternalClient.ResultContextSettings(
		SettingsComposer, "FilterCommand", FormOwner.UUID);
	
	If RebuildReport Then 
		Result.Regenerate = True;
	EndIf;
	
	NotifyChoice(Result);
	
EndProcedure

&AtClientAtServerNoContext
Function DisplayFilters(SettingsComposer, TitleProperties)
	
	Settings = SettingsComposer.Settings.GetObjectByID(TitleProperties.IDOfTheSettings);
	Return ReportsOptionsInternalClientServer.ReportSectionFilters(Settings, TitleProperties);
	
EndFunction

&AtClientAtServerNoContext
Function Filter(SettingsComposer, TitleProperties)
	
	DisplayFilters = DisplayFilters(SettingsComposer, TitleProperties);
	Return ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field);
	
EndFunction

&AtClientAtServerNoContext
Function FilterDescription(SettingsComposer, TitleProperties, DisplayFilters = Undefined)
	
	FilterDescription = Undefined;
	
	If DisplayFilters = Undefined Then 
		DisplayFilters = DisplayFilters(SettingsComposer, TitleProperties);
	EndIf;
	
	If TitleProperties.Field <> Undefined Then 
		FilterDescription = DisplayFilters.FilterAvailableFields.FindField(TitleProperties.Field);
	EndIf;
	
	Return FilterDescription;
	
EndFunction

&AtClientAtServerNoContext
Procedure DetermineTheAvailabilityOfTheRightValueField(Field, Condition)
	
	Field.Enabled = Condition <> DataCompositionComparisonType.Filled
		And Condition <> DataCompositionComparisonType.NotFilled;
	
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

#EndRegion