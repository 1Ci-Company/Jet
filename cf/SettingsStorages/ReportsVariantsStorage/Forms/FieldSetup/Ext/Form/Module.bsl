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
	DefineBehaviorInMobileClient();
	
	FillPropertyValues(ThisObject, Parameters, "ReportSettings, SettingsComposer, TitleProperties, Document");
	DetailsDataAddress = Parameters.DetailsData;
	ReportSettings.Insert("FiltersValuesCache", Parameters.FiltersValuesCache);
	
	Initialize();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillInTheValuesOfAdditionalFeatures();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseOnChange(Item)
	
	ClearFilterByCondition = Not Use;
	
EndProcedure

&AtClient
Procedure ComparisonTypeOnChange(Item)
	
	Use = True;
	RightValueField = Items.RightValue;
	
	If ReportsClientServer.IsListComparisonKind(ComparisonType) Then 
		
		RightValue = ReportsClientServer.ValuesByList(RightValue);
		RightValue.ValueType = Values.ValueType;
		
		RefineTheRightValue(RightValue, AvailableValues);
		
		RightValueField.TypeRestriction = New TypeDescription("ValueList");
		RightValueField.ChooseType = False;
		RightValueField.ListChoiceMode = False;
		RightValueField.ChoiceButton = True;
		
	Else
		
		If TypeOf(RightValue) = Type("ValueList") Then 
			
			If RightValue.Count() > 0 Then 
				RightValue = RightValue[0].Value;
			Else
				RightValue = Values.ValueType.AdjustValue();
			EndIf;
			
		EndIf;
		
		AvailableTypes = Values.ValueType.Types();
		IsString = AvailableTypes.Count() = 1 And AvailableTypes.Find(Type("String")) <> Undefined;
		
		FilterDescription = FilterDescription(SettingsComposer, TitleProperties);
		ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
			?(FilterDescription = Undefined, Undefined, FilterDescription.ChoiceFoldersAndItems), ComparisonType);
		
		RightValueField.TypeRestriction = Values.ValueType;
		RightValueField.ChooseType = (AvailableTypes.Count() <> 1);
		RightValueField.ListChoiceMode = (RightValueField.ChoiceList.Count() > 0);
		RightValueField.ChoiceButton = Not IsString And Not RightValueField.ListChoiceMode;
		RightValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(ChoiceFoldersAndItems, ComparisonType);
		
	EndIf;
	
	DetermineTheAvailabilityOfTheRightValueField(RightValueField, ComparisonType);
	
EndProcedure

&AtClient
Procedure RightValueOnChange(Item)
	
	Use = True;
	
EndProcedure

&AtClient
Procedure RightValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	If TypeOf(RightValue) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Filter = Filter(SettingsComposer, TitleProperties);
	FilterDescription = FilterDescription(SettingsComposer, TitleProperties);
	
	ChoiceParameters = ReportsClientServer.ChoiceParameters(
		SettingsComposer.Settings, SettingsComposer.UserSettings.Items, Filter);
	
	ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
		?(FilterDescription = Undefined, Undefined, FilterDescription.ChoiceFoldersAndItems), ComparisonType);
	
	If RightValue.Count() = 0 Then 
		Marked = New ValueList;
		For Each Value In Values Do 
			If Value.Check Then 
				FillPropertyValues(Marked.Add(), Value);
			EndIf;
		EndDo;
	Else
		Marked = CommonClient.CopyRecursive(RightValue);
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Marked", Marked);
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
	
	RightValue.Clear();
	
	For Each Item In ValueSelected Do 
		
		If Item.Check Then 
			FillPropertyValues(RightValue.Add(), Item);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersValues

&AtClient
Procedure ValuesOnChange(Item)
	
	Use = False;
	
EndProcedure

&AtClient
Procedure ValuesSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field <> Items.ValuesValue Then 
		Return;
	EndIf;
	
	String = Values.FindByID(RowSelected);
	
	ShowValue(Undefined, String.Value);
	
EndProcedure

&AtClient
Procedure ValuesCheckOnChange(Item)
	
	ClearFilterByCondition = False;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ApplyISform(Command)
	
	ApplySettings(True);
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	CloseOnChoice = False;
	ApplySettings(False);
	CloseOnChoice = True;
	
EndProcedure

#Region Sort

&AtClient
Procedure SortAsc(Command)
	
	ReportsOptionsInternalClient.Sort(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure SortDesc(Command)
	
	ReportsOptionsInternalClient.Sort(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region Group

&AtClient
Procedure GroupBySelectedField(Command)
	
	ReportsOptionsInternalClient.GroupBySelectedField(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region InsertSettings

&AtClient
Procedure InsertFieldLeft(Command)
	
	ReportsOptionsInternalClient.InsertFieldLeft(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure InsertFieldRight(Command)
	
	ReportsOptionsInternalClient.InsertFieldRight(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure InsertGroupAbove(Command)
	
	ReportsOptionsInternalClient.InsertGroupAbove(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure InsertGroupBelow(Command)
	
	ReportsOptionsInternalClient.InsertGroupBelow(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region Move

&AtClient
Procedure MoveFieldLeft(Command)
	
	ReportsOptionsInternalClient.MoveFieldLeft(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure MoveFieldRight(Command)
	
	ReportsOptionsInternalClient.MoveFieldRight(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure MoveFieldUp(Command)
	
	ReportsOptionsInternalClient.MoveFieldUp(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure MoveFieldDown(Command)
	
	ReportsOptionsInternalClient.MoveFieldDown(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region HidingRenaming

&AtClient
Procedure HideField(Command)
	
	ReportsOptionsInternalClient.HideField(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure RenameField(Command)
	
	If Not ValueIsFilled(FieldPresentation) Then 
		
		CommonClient.MessageToUser(
			NStr("en = 'Enter new field header';"),, "FieldPresentation");
		Return;
		
	EndIf;
	
	ReportsOptionsInternalClient.RenameField(ThisObject, Command, FieldPresentation);
	
EndProcedure

&AtClient
Procedure FieldPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FieldPresentation = Item.EditText;
	RenameField(Commands.Find("RenameField"));
	
EndProcedure

#EndRegion

#Region SetColor

&AtClient
Procedure FormatNegativeValues(Command)
	
	ReportsOptionsInternalClient.HighlightInRed(ThisObject, Command);
	
EndProcedure

&AtClient
Procedure FormatPositiveValues(Command)
	
	ReportsOptionsInternalClient.HighlightInGreen(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region SetWidthHeight

&AtClient
Procedure SetRowHeight(Command)
	
	If Not ValueIsFilled(RowHeight) Then 
		
		CommonClient.MessageToUser(
			NStr("en = 'Enter row height';"),, "RowHeight");
		Return;
		
	EndIf;
	
	ReportsOptionsInternalClient.SetRowHeight(ThisObject, Command, TitleProperties, RowHeight);
	NotifyChoice(SettingsComposer.Settings);
	
EndProcedure

&AtClient
Procedure SetColumnWidth(Command)
	
	If Not ValueIsFilled(ColumnWidth) Then 
		
		CommonClient.MessageToUser(
			NStr("en = 'Enter column width';"),, "ColumnWidth");
		Return;
		
	EndIf;
	
	ReportsOptionsInternalClient.SetColumnWidth(ThisObject, Command, TitleProperties, ColumnWidth);
	NotifyChoice(SettingsComposer.Settings);
	
EndProcedure

#EndRegion

#Region Appearance

&AtClient
Procedure ApplyAppearanceMore(Command)
	
	ReportsOptionsInternalClient.ApplyAppearanceMore(FormOwner, Command);
	Close();
	
EndProcedure

#EndRegion

#Region Common

&AtClient
Procedure OutputAllReportSectionValuesClick(Item)
	
	FillingResult = StartFillingInTheValues(UUID);
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	
	Handler = New NotifyDescription("AfterFillingInTheValues", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(FillingResult, Handler, IdleParameters);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Values.Value");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = '(Empty)';"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ValuesValue.Name);
	
EndProcedure

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
Procedure Initialize()
	
	FieldTitle = TitleProperties.Text;
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Field setting: %1';"), FieldTitle);
	
	FieldPresentation = FieldTitle;
	FirstLinesToReadCount = 500;
	
	SetFilterPropertiesByCondition(FieldTitle);
	DefineTypesForAHierarchyOfValues();
	
	FillValues();
	
	UpdateIndexesOfGroupsAndElements();
	RefineTheAvailableValueTypes();
	DetermineTheAvailabilityOfAdditionalFeatures();
	
EndProcedure

&AtServer
Procedure SetFilterPropertiesByCondition(FieldTitle)
	
	Items.ComparisonType.AvailableTypes = New TypeDescription("DataCompositionComparisonType");
	ComparisonKinds = Items.ComparisonType.ChoiceList;
	
	If TitleProperties.ValueType <> Undefined Then 
		Values.ValueType = TitleProperties.ValueType;
	EndIf;
	
	FilterDescription = FilterDescription(SettingsComposer, TitleProperties);
	
	If FilterDescription = Undefined Then 
		
		For Each CurrentKind In DataCompositionComparisonType Do 
			ComparisonKinds.Add(CurrentKind);
		EndDo;
	Else
		For Each CurrentKind In FilterDescription.AvailableCompareTypes Do 
			FillPropertyValues(ComparisonKinds.Add(), CurrentKind);
		EndDo;
		
		Values.ValueType = FilterDescription.ValueType;
		Items.ValuesValue.TypeRestriction = Values.ValueType;
		
		If FilterDescription.AvailableValues <> Undefined Then 
			
			AvailableValues.ValueType = FilterDescription.ValueType;
			AvailableValues = FilterDescription.AvailableValues;
			
		EndIf;
		
	EndIf;
	
	ComparisonType = ComparisonKinds[0].Value;
	
EndProcedure

&AtServer
Procedure RefineTheAvailableValueTypes()
	
	AvailableTypes = Values.ValueType.Types();
	
	If AvailableTypes.Count() = 0 Then 
		
		Indexes = New Map;
		
		For Each Item In Values Do 
			
			ValueType = TypeOf(Item.Value);
			
			If Indexes[ValueType] <> Undefined Then 
				Continue;
			EndIf;
			
			AvailableTypes.Add(ValueType);
			Indexes.Insert(ValueType, True);
			
		EndDo;
		
		Values.ValueType = New TypeDescription(AvailableTypes);
	
	EndIf;
	
	Filter = Filter(SettingsComposer, TitleProperties);
	
	If TypeOf(Filter) = Type("DataCompositionFilterItem") Then 
		
		FillPropertyValues(ThisObject, Filter, "Use, RightValue");
		
		AvailableCompareTypes = Items.ComparisonType.ChoiceList;
		
		If AvailableCompareTypes.FindByValue(Filter.ComparisonType) <> Undefined Then 
			ComparisonType = Filter.ComparisonType;
		EndIf;
		
	EndIf;
	
	IsList = (TypeOf(RightValue) = Type("ValueList"));
	
	If IsList Then 
		
		RightValue.ValueType = Values.ValueType;
		RightValue = Filter.RightValue;
		
		RefineTheRightValue(RightValue, AvailableValues);
		
	Else
		
		Items.RightValue.TypeRestriction = Values.ValueType;
		
	EndIf;
	
	RightValueField = Items.RightValue;
	
	For Each Item In AvailableValues Do 
		FillPropertyValues(RightValueField.ChoiceList.Add(), Item);
	EndDo;
	
	RightValueField.ListChoiceMode = Not IsList
		And (RightValueField.ChoiceList.Count() > 0);
	
	RightValueField.ChooseType = Not IsList
		And AvailableTypes.Count() <> 1
		And Not RightValueField.ListChoiceMode;
	
	IsString = Not IsList
		And AvailableTypes.Count() = 1
		And AvailableTypes.Find(Type("String")) <> Undefined;
	
	Items.RightValue.ChoiceButton = Not IsString
		And Not RightValueField.ListChoiceMode;
	
	DetermineTheAvailabilityOfTheRightValueField(RightValueField, ComparisonType);
	
EndProcedure

&AtServer
Procedure DetermineTheAvailabilityOfAdditionalFeatures()
	
	ActionsOfAdditionalFeatures = ActionsOfAdditionalFeatures();
	
	For Each Action In ActionsOfAdditionalFeatures Do 
		Items[Action].Enabled = TitleProperties[Action];
	EndDo;
	
	Items.FieldPresentation.Enabled = Items.RenameField.Enabled;
	Items.RenameFieldMore.Enabled = Items.RenameField.Enabled;
	
	SelectionPicture = PictureLib.AppearanceCheckBox;
	
	Items.RenameFieldMore.Picture = SelectionPicture;
	Items.SetRowHeightMore.Picture = SelectionPicture;
	Items.SetColumnWidthMore.Picture = SelectionPicture;
	
EndProcedure

&AtServer
Function ActionsOfAdditionalFeatures()
	
	Actions = New Array;
	Actions.Add("InsertFieldLeft");
	Actions.Add("InsertFieldRight");
	Actions.Add("InsertGroupAbove");
	Actions.Add("InsertGroupBelow");
	
	Actions.Add("MoveFieldLeft");
	Actions.Add("MoveFieldRight");
	Actions.Add("MoveFieldUp");
	Actions.Add("MoveFieldDown");
	
	Actions.Add("SortAsc");
	Actions.Add("SortDesc");
	
	Actions.Add("HideField");
	Actions.Add("RenameField");
	
	Actions.Add("FormatNegativeValues");
	Actions.Add("FormatPositiveValues");
	Actions.Add("ApplyAppearanceMore");
	
	Return Actions;
	
EndFunction

&AtClient
Procedure FillInTheValuesOfAdditionalFeatures()
	
	HeightParameters = ReportsOptionsInternalClient.ReportFieldSizeParameters(ThisObject, TitleProperties);
	RowHeight = HeightParameters.Size;
	
	WidthParameters = ReportsOptionsInternalClient.ReportFieldSizeParameters(ThisObject, TitleProperties, "Width");
	ColumnWidth = WidthParameters.Size;
	
EndProcedure

#Region FillingInValues

&AtServer
Function StartFillingInTheValues(JobID)
	
	AllReportSectionValuesDisplayed = True;
	Items.OptionsToFillInFilterByValue.Visible = Not AllReportSectionValuesDisplayed;
	
	Items.FilterByPageValue.CurrentPage = Items.Waiting;
	Items.WaitingStatuses.CurrentPage = Items.WaitingForFilling;
	
	Items.TimeConsumingOperationPresentation.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Reading field lines: %1';"), FieldPresentation);
	
	MethodParameters = TimeConsumingOperations.FunctionExecutionParameters(JobID);
	MethodParameters.BackgroundJobDescription = NStr("en = 'Fill in filter by value';");
	MethodParameters.RefinementErrors = NStr("en = 'Cannot fill in filter by value due to:';");
	
	FillingResult = TimeConsumingOperations.ExecuteFunction(
		MethodParameters,
		"ReportsOptionsInternal.FillInTheFilterValues",
		ParametersForFillingInValues());
	
	Return FillingResult;
	
EndFunction

&AtServer
Procedure FillValues()
	
	DetailsData = GetFromTempStorage(DetailsDataAddress);
	FillingResult = Undefined;
	
	If TypeOf(TitleProperties.Details) = Type("DataCompositionDetailsID") Then 
		FillInTheValuesOfTheGroupingColumns(DetailsData);
	Else
		FillingResult = ReportsOptionsInternal.FillInTheFilterValues(ParametersForFillingInValues());
		FillingResult.Delete("Values");
	EndIf;
	
	FinishFillingInTheValues(FillingResult);
	
EndProcedure

&AtServer
Procedure FinishFillingInTheValues(FillingResult = Undefined)
	
	If FillingResult <> Undefined Then 
		
		LinesInReportSectionCount = FillingResult.LinesInReportSectionCount;
		AllReportSectionValuesDisplayed = FillingResult.AllReportSectionValuesDisplayed;
		
		If FillingResult.Property("Values") Then 
			CommonClientServer.SupplementTable(FillingResult.Values, Values);
		EndIf;
		
	EndIf;
	
	Filter = Filter(SettingsComposer, TitleProperties);
	
	AddTheAvailableValues();
	AddValuesFromTheCache(Filter);
	ToClarifyTheMarkingValues(Filter);
	
	Values.SortByValue();
	
	ShowStatisticsOfFillingInValues();
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure AfterFillingInTheValues(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		
		CommentTemplate = NStr("en = 'Cannot fill in filter by value due to: %1';");	
		Items.WaitingStatuses.CurrentPage = Items.FillError;
		Items.FillErrorDescription.Title = StringFunctionsClientServer.SubstituteParametersToString(
			CommentTemplate, Result.BriefErrorDescription);
		StandardSubsystemsClient.OutputErrorInfo(Result.ErrorInfo);
		Return;
		
	ElsIf Result.Status = "Completed2" Then 
		
		FillingResult = GetFromTempStorage(Result.ResultAddress);
		FinishFillingInTheValues(FillingResult);
		
		Items.FilterByPageValue.CurrentPage = Items.FilterValues;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInTheValuesOfTheGroupingColumns(DetailsData)
	
	AvailableTypes = Values.ValueType;
	Indexes = New Map;
	
	For Each DetailsItem In DetailsData.Items Do 
		
		If TypeOf(DetailsItem) <> Type("DataCompositionFieldDetailsItem")
			Or DetailsItem.MainAction <> DataCompositionDetailsProcessingAction.OpenValue Then 
			
			Continue;
		EndIf;
		
		Fields = DetailsItem.GetFields();
		
		If Fields.Count() = 0 Then 
			Continue;
		EndIf;
		
		Value = Fields[0].Value;
		
		If Not ValueIsFilled(Value)
			Or Indexes[Value] <> Undefined
			Or Not AvailableTypes.ContainsType(TypeOf(Value)) Then 
			
			Continue;
		EndIf;
		
		Indexes.Insert(Value, True);
		
		AvailableValue = AvailableValues.FindByValue(Value);
		
		If AvailableValue = Undefined Then 
			
			Values.Add(Value,, True); 
			
		Else
			
			AvailableValue.Check = True;
			FillPropertyValues(Values.Add(), AvailableValue);
			
		EndIf;
		
	EndDo;
	
	AllReportSectionValuesDisplayed = True;
	
EndProcedure

&AtServer
Procedure AddTheAvailableValues()
	
	For Each Item In AvailableValues Do 
		
		If Values.FindByValue(Item.Value) = Undefined Then 
			FillPropertyValues(Values.Add(), Item,, "Check");
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddValuesFromTheCache(Filter)
	
	FilterValues = TheValueOfTheFilterFromTheCache(Filter);
	
	If TypeOf(FilterValues) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	For Each Item In FilterValues Do 
		
		If Values.FindByValue(Item.Value) = Undefined Then 
			FillPropertyValues(Values.Add(), Item,, "Check");
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function TheValueOfTheFilterFromTheCache(Filter)
	
	If TypeOf(Filter) <> Type("DataCompositionFilterItem") Then 
		Return Undefined;
	EndIf;
	
	FiltersValuesCache = ReportSettings.FiltersValuesCache;
	
	ValueOfFilter = Undefined;
	
	If ValueIsFilled(Filter.UserSettingID) Then 
		ValueOfFilter = FiltersValuesCache[Filter.UserSettingID];
	EndIf;
	
	If ValueOfFilter <> Undefined Then 
		Return ReportsClientServer.ValuesByList(ValueOfFilter);
	EndIf;
	
	BasicSettingsFilter = Undefined;
	
	If ValueIsFilled(Filter.UserSettingID) Then 
		
		FoundSettings = SettingsComposer.UserSettings.GetMainSettingsByUserSettingID(
			Filter.UserSettingID);
		
		If FoundSettings.Count() > 0 Then 
			BasicSettingsFilter = FoundSettings[0];
		EndIf;
		
	Else
		BasicSettingsFilter = Filter;
	EndIf;
	
	If TypeOf(BasicSettingsFilter) = Type("DataCompositionFilterItem") Then 
		ValueOfFilter = FiltersValuesCache[BasicSettingsFilter.LeftValue];
	EndIf;
	
	If ValueOfFilter <> Undefined Then 
		Return ReportsClientServer.ValuesByList(ValueOfFilter);
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure ToClarifyTheMarkingValues(Filter)
	
	If TypeOf(Filter) <> Type("DataCompositionFilterItem")
		Or Not Filter.Use Then 
		
		Return;
	EndIf;
	
	Check = Undefined;
	UnambiguousConditions = UnambiguousConditions();
	
	If UnambiguousConditions.Equality.Find(Filter.ComparisonType) <> Undefined Then 
		
		Check = True;
		
	ElsIf UnambiguousConditions.Inequalities.Find(Filter.ComparisonType) <> Undefined Then 
		
		Check = False;
		
	EndIf;
	
	If Check = Undefined Then 
		Return;
	EndIf;
	
	Values.FillChecks(Not Check);
	ValueOfFilter = ReportsClientServer.ValuesByList(Filter.RightValue);
	
	For Each Item In ValueOfFilter Do 
		
		FoundItem = Values.FindByValue(Item.Value);
		
		If FoundItem <> Undefined Then 
			FoundItem.Check = Check;
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns:
//   Structure:
//     * Equality - Array of DataCompositionComparisonType
//     * Inequalities - Array of DataCompositionComparisonType
//
&AtServer
Function UnambiguousConditions()
	
	EqualityConditions = New Array;
	EqualityConditions.Add(DataCompositionComparisonType.Equal);
	EqualityConditions.Add(DataCompositionComparisonType.InHierarchy);
	EqualityConditions.Add(DataCompositionComparisonType.InList);
	EqualityConditions.Add(DataCompositionComparisonType.InListByHierarchy);
	
	ConditionsOfInequality = New Array;
	ConditionsOfInequality.Add(DataCompositionComparisonType.NotEqual);
	ConditionsOfInequality.Add(DataCompositionComparisonType.NotInHierarchy);
	ConditionsOfInequality.Add(DataCompositionComparisonType.NotInList);
	ConditionsOfInequality.Add(DataCompositionComparisonType.NotInListByHierarchy);
	
	UnambiguousConditions = New Structure;
	UnambiguousConditions.Insert("Equality", EqualityConditions);
	UnambiguousConditions.Insert("Inequalities", ConditionsOfInequality);
	
	Return UnambiguousConditions;
	
EndFunction

&AtServer
Procedure UpdateIndexesOfGroupsAndElements()
	
	GroupsAndItemsIndexes = StandardIndexesOfGroupsAndElements();
	
	For Each Item In Values Do 
		
		Value = Item.Value;
		
		If Not ValueIsFilled(Value)
			Or Not Common.IsReference(TypeOf(Value)) Then 
			
			Continue;
		EndIf;
		
		ValueMetadata = Value.Metadata();
		
		If Not Common.IsCatalog(ValueMetadata)
			And Not Common.IsChartOfCharacteristicTypes(ValueMetadata) Then 
			
			Continue;
		EndIf;
		
		ValueProperties = New Structure("IsFolder");
		FillPropertyValues(ValueProperties, Value);
		
		If ValueProperties.IsFolder = True Then 
			GroupsAndItemsIndexes.Groups.Insert(Value, True);
		Else
			GroupsAndItemsIndexes.Items.Insert(Value, True);
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns:
//  Structure:
//    * Groups - Map
//    * Items - Map
//
&AtServer
Function StandardIndexesOfGroupsAndElements()
	
	Indexes = New Structure;
	Indexes.Insert("Groups", New Map);
	Indexes.Insert("Items", New Map);
	
	Return Indexes;
	
EndFunction

&AtServer
Procedure DefineTypesForAHierarchyOfValues()
	
	TypesOfValueHierarchy = New Map;
	
	TypesOfHierarchy = Metadata.ObjectProperties.HierarchyType;
	ValueTypes = Values.ValueType.Types();
	
	For Each ValueType In ValueTypes Do 
		
		If Not Common.IsReference(ValueType) Then 
			Continue;
		EndIf;
		
		ObjectMetadata = Metadata.FindByType(ValueType);
		
		If Not Common.IsCatalog(ObjectMetadata)
			And Not Common.IsChartOfCharacteristicTypes(ObjectMetadata) Then 
			
			Continue;
		EndIf;
		
		If Not ObjectMetadata.Hierarchical Then
			Continue;
		EndIf;
			
		If Common.IsCatalog(ObjectMetadata) And ObjectMetadata.HierarchyType = TypesOfHierarchy.HierarchyOfItems Then 
			HierarchyType = TheViewHierarchyIsAHierarchyOfElements();
		Else
			HierarchyType = TheViewHierarchyIsAHierarchyOfGroupsAndItems();
		EndIf;
		
		TypesOfValueHierarchy.Insert(ValueType, HierarchyType);
		
	EndDo;
	
	ReportSettings.Insert("TypesOfValueHierarchy", TypesOfValueHierarchy);
	
EndProcedure

&AtClientAtServerNoContext
Function TheViewHierarchyIsAHierarchyOfGroupsAndItems()
	
	Return "HierarchyFoldersAndItems";
	
EndFunction

&AtClientAtServerNoContext
Function TheViewHierarchyIsAHierarchyOfElements()
	
	Return "HierarchyOfItems";
	
EndFunction

&AtServer
Function ParametersForFillingInValues()
	
	Values.Clear();
	
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	PartitionBoundary = ResultProperties.TheBoundariesOfThePartitions[TitleProperties.SectionOrder - 1].Value;
	
	DetailsData = GetFromTempStorage(DetailsDataAddress);
	
	FillParameters = New Structure;
	FillParameters.Insert("Values", Values);
	FillParameters.Insert("TitleProperties", TitleProperties);
	FillParameters.Insert("Document", Document);
	FillParameters.Insert("Headers", ResultProperties.Headers);
	FillParameters.Insert("PartitionBoundary", PartitionBoundary);
	FillParameters.Insert("DetailsData", DetailsData);
	FillParameters.Insert("AvailableValues", AvailableValues);
	FillParameters.Insert("FirstLinesToReadCount", FirstLinesToReadCount);
	FillParameters.Insert("AllReportSectionValuesDisplayed", AllReportSectionValuesDisplayed);
	
	Return FillParameters;
	
EndFunction

#EndRegion

#EndRegion

&AtClient
Procedure AfterSelectingAField(SelectedField, AdditionalParameters) Export 
	
	ReportsOptionsInternalClient.AfterSelectingAField(SelectedField, AdditionalParameters);
	
	If TypeOf(SelectedField) = Type("DataCompositionAvailableField") Then 
		NotifyChoice(SettingsComposer.Settings);
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplySettings(RebuildReport)
	
	Cancel = False;
	
	If ClearFilterByCondition Then 
		ReportsOptionsInternalClient.DisableFilter(ThisObject, TitleProperties);
	Else
		ApplyAFilter(Cancel);
	EndIf;
	
	ReportsOptionsInternalClient.AddSettingstoStack(
		ThisObject, SettingsComposer.Settings, "FilterCommand", TitleProperties.Text);
	
	Result = ReportsOptionsInternalClient.ResultContextSettings(
		SettingsComposer, "FilterCommand", FormOwner.UUID);
	
	If RebuildReport Then 
		Result.Regenerate = True;
	EndIf;
	
	If Not Cancel Then 
		NotifyChoice(Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure ApplyAFilter(Cancel)
	
	Filter = Filter(SettingsComposer, TitleProperties);
	
	If TypeOf(Filter) <> Type("DataCompositionFilterItem") Then 
		
		DisplayFilters = ReportsOptionsInternalClientServer.ReportSectionFilters(
			SettingsComposer.Settings, TitleProperties);
		
		Filter = DisplayFilters.Items.Add(Type("DataCompositionFilterItem"));
		Filter.LeftValue = TitleProperties.Field;
		
	EndIf;
	
	Filter.Use = True;
	
	If Use Then 
		
		Filter.ComparisonType = ComparisonType;

		If ValueIsFilled(RightValue) Then 
			Filter.RightValue = RightValue;
		Else
			Filter.RightValue = Values.ValueType.AdjustValue(RightValue);
		EndIf;
		
		ReportsClient.CacheFilterValue(SettingsComposer, Filter, Values);
		Return;
		
	EndIf;
	
	MarkedItemList = New ValueList;
	AListOfTheUntagged = New ValueList;
	
	For Each Item In Values Do 
		
		If Item.Check Then 
			FillPropertyValues(MarkedItemList.Add(), Item);
		Else
			FillPropertyValues(AListOfTheUntagged.Add(), Item);
		EndIf;
		
	EndDo;
	
	If MarkedItemList.Count() = 1 Then 
		
		Filter.ComparisonType = DataCompositionComparisonType.Equal;
		Filter.RightValue = MarkedItemList[0].Value;
		
	Else
		
		Filter.ComparisonType = DataCompositionComparisonType.InList;
		Filter.RightValue = MarkedItemList;
		
	EndIf;
	
	If TypeOf(Filter) <> Type("DataCompositionFilterItem") Then 
		Return;
	EndIf;
	
	ToSpecifyAFilterCondition(Filter, Cancel);
	ReportsClient.CacheFilterValue(SettingsComposer, Filter, Values);
	
EndProcedure

&AtClient
Procedure ToSpecifyAFilterCondition(Filter, Cancel)
	
	GroupsAreUsed = False;
	TheElementsUsedAre = False;
	
	FilterValues = ReportsClientServer.ValuesByList(Filter.RightValue, True);
	
	If FilterValues.Count() = 0 Then 
		Return;
	EndIf;
	
	CheckTheUseOfGroupsAndElements(FilterValues, GroupsAreUsed, TheElementsUsedAre);
	
	If Not GroupsAreUsed
		And Not TheElementsUsedAre Then 
		
		Return;
	EndIf;
	
	If Not GroupsAreUsed
		And TheElementsUsedAre Then 
		
		Return;
	EndIf;
	
	If GroupsAreUsed
		And TheElementsUsedAre Then 
		
		Cancel = True;
		
		WarningText = NStr("en = 'The list contains both groups and items.
			|Select only groups or only items.';");
		
		ShowMessageBox(, WarningText);
		Return;
		
	EndIf;
	
	If Filter.ComparisonType = DataCompositionComparisonType.NotEqual Then 
		
		Filter.ComparisonType = DataCompositionComparisonType.NotInHierarchy;
		
	ElsIf Filter.ComparisonType = DataCompositionComparisonType.NotInList Then 
		
		Filter.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy;
		
	Else
		Filter.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
	EndIf;
	
EndProcedure

&AtClient
Procedure  CheckTheUseOfGroupsAndElements(FilterValues, GroupsAreUsed, TheElementsUsedAre)
	
	If GroupsAndItemsIndexes.Groups.Count() = 0
		And GroupsAndItemsIndexes.Items.Count() = 0 Then 
		
		Return;
	EndIf;
	
	TypeOfGroupingFields = TypeOfGroupingFields();
	TypesOfValueHierarchy = ReportSettings.TypesOfValueHierarchy;
	
	For Each Item In FilterValues Do 
		
		If GroupsAndItemsIndexes.Groups[Item.Value] = True
			Or (GroupsAndItemsIndexes.Items[Item.Value] = True
				And TypeOfGroupingFields <> DataCompositionGroupType.Items
				And TypesOfValueHierarchy[TypeOf(Item.Value)] = TheViewHierarchyIsAHierarchyOfElements()) Then 
			
			GroupsAreUsed = True;
			
		ElsIf GroupsAndItemsIndexes.Items[Item.Value] = True Then 
			
			TheElementsUsedAre = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function TypeOfGroupingFields()
	
	TypeOfGroupingFields = DataCompositionGroupType.Items;
	DataCompositionGroup = SettingsComposer.Settings.GetObjectByID(TitleProperties.GroupingID);
	
	If TypeOf(DataCompositionGroup) <> Type("DataCompositionGroup")
		And TypeOf(DataCompositionGroup) <> Type("DataCompositionTableGroup") Then 
		
		Return TypeOfGroupingFields;
	EndIf;
	
	GroupingField = ReportsOptionsInternalClientServer.ReportField(DataCompositionGroup.GroupFields, TitleProperties.Field);
	
	If GroupingField = Undefined Then 
		Return TypeOfGroupingFields;
	EndIf;
	
	Return GroupingField.GroupType;
	
EndFunction

&AtClientAtServerNoContext
Function Filter(SettingsComposer, TitleProperties, DisplayFilters = Undefined)
	
	If DisplayFilters = Undefined Then 
		DisplayFilters = ReportsOptionsInternalClientServer.ReportSectionFilters(SettingsComposer.Settings, TitleProperties);
	EndIf;
	
	Return ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field);
	
EndFunction

&AtClientAtServerNoContext
Function FilterDescription(SettingsComposer, TitleProperties)
	
	FilterDescription = Undefined;
	
	If TitleProperties.Field <> Undefined Then 
		FilterDescription = SettingsComposer.Settings.FilterAvailableFields.FindField(TitleProperties.Field);
	EndIf;
	
	Return FilterDescription;
	
EndFunction

&AtClientAtServerNoContext
Procedure RefineTheRightValue(RightValue, AvailableValues)
	
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

&AtClientAtServerNoContext
Procedure DetermineTheAvailabilityOfTheRightValueField(Field, Var_ComparisonType)
	
	Field.Enabled = Var_ComparisonType <> DataCompositionComparisonType.Filled
		And Var_ComparisonType <> DataCompositionComparisonType.NotFilled;
	
EndProcedure

&AtServer
Procedure ShowStatisticsOfFillingInValues()
	
	If AllReportSectionValuesDisplayed Then 
		
		Items.OptionsToFillInFilterByValue.Visible = Not AllReportSectionValuesDisplayed;
		Return;
		
	EndIf;
	
	Items.FilterByValueStatistics.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'The first %1 values are displayed.';"), Values.Count());
	
	Items.OutputAllReportSectionValues.ExtendedTooltip.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 unique values out of the first %2 lines of the report are displayed. The total number of lines in the report section is %3.';"),
		Values.Count(),
		FirstLinesToReadCount,
		LinesInReportSectionCount);
	
EndProcedure

#EndRegion