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

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export

	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.PredefinedReportOptionsUpdate;
	Setting.IsParameterized = True;

EndProcedure

// Properties of the report (spreadsheet document and settings) result for context setup.
//
// Returns:
//   Structure:
//     * Headers - Map
//     * TheBoundariesOfThePartitions - See ReportSectionBoundaries
//     * FieldRoles - See ReportFieldRoles
//     * FieldsIndex - See IndexOfFieldsInTheReportStructure
//     * MainField - Array of See MainReportFields
//     * FinalSettings - DataCompositionSettings - See "DataCompositionSettingsComposer" in Syntax Assistant.
//     * SettingsComposer - DataCompositionSettingsComposer - Without executing the ExpandAutoFields method.
//     * SettingsComposerWithoutAutoFields - DataCompositionSettingsComposer - After executing the ExpandAutoFields method.
//     * LayoutsAreDescribed - Boolean
//     * FormationTime - Number
//
Function PropertiesOfTheReportResult() Export 
	
	ResultProperties = New Structure;
	ResultProperties.Insert("AddressOfTheReportStructureIndex", Undefined);
	ResultProperties.Insert("Headers", New Map);
	ResultProperties.Insert("TheBoundariesOfThePartitions", New ValueList);
	ResultProperties.Insert("FieldRoles", New Structure);
	ResultProperties.Insert("FieldsIndex", New Map);
	ResultProperties.Insert("MainField", New Array);
	ResultProperties.Insert("FinalSettings", Undefined);
	ResultProperties.Insert("SettingsComposer", Undefined);
	ResultProperties.Insert("SettingsComposerWithoutAutoFields", Undefined);
	ResultProperties.Insert("LayoutsAreDescribed", False);
	ResultProperties.Insert("FormationTime", 0);
	
	Return ResultProperties;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForReports
//
Procedure InitializeReportHeaders(Form) Export 
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(Form.CurrentVariantKey)
		Or Not ReportSettings.EditOptionsAllowed
		Or ReportSettings.DisableStandardContextMenu Then 
		
		Return;
	EndIf;
	
	Headers = New Map;
	
	Items = Form.Items;
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	ReportResult = Form.ReportSpreadsheetDocument; // SpreadsheetDocument
	
	IndexOfTheReportStructure = IndexOfTheReportStructure(Form);
	SectionHeaderBorder = Undefined;
	HeaderPropertiesSection = StandardSectionOfReportHeaderProperties();
	
	For LineNumber = 1 To ReportResult.TableHeight Do 
		
		StartCell = ReportResult.Area(LineNumber, 1);
		
		If AbortScanReportResult(StartCell, IndexOfTheReportStructure, SectionHeaderBorder) Then 
			Break;
		EndIf;
		
		If Not ThisReportHeaderCell(StartCell) Then 
			Continue;
		EndIf;
		
		For ColumnNumber = 1 To ReportResult.TableWidth Do 
			
			Cell = ReportResult.Area(LineNumber, ColumnNumber);
			
			If Not ThisReportHeaderCell(Cell) Then 
				Continue;
			EndIf;
			
			If Form.GetCurrentResultViewMode() = ReportResultViewMode.Default Then
				Cell.Hyperlink = True;
			EndIf;
			
			FillPropertyValues(HeaderPropertiesSection.Add(), Cell);
			
			TitleProperties = StandardReportHeaderProperties();
			FillPropertyValues(TitleProperties, Cell);
			
			Headers.Insert(Cell.Name, TitleProperties);
			
		EndDo;
		
	EndDo;
	
	DefineTheHierarchyOfReportHeaders(HeaderPropertiesSection, Headers);
	TheBoundariesOfThePartitions = ReportSectionBoundaries(ReportResult, HeaderPropertiesSection);
	
	AddPropertiesToReportHeaders(Form, ReportResult, Headers, HeaderPropertiesSection, IndexOfTheReportStructure, TheBoundariesOfThePartitions);
	
	Cell = Items.ReportSpreadsheetDocument.CurrentArea;
	
	If Cell <> Undefined Then 
		ReportsOptionsInternalClientServer.DetermineTheAvailabilityOfContextMenuActions(Form, Headers[Cell.Name]);
	EndIf;
	
	ResultProperties.Headers = Headers;
	ResultProperties.TheBoundariesOfThePartitions = TheBoundariesOfThePartitions;
	
EndProcedure

// 
Procedure OnDefineObjectsWithTablePresentation(Objects) Export
	Objects.Add("Catalog.ReportsOptions");
	Objects.Add("Catalog.PredefinedExtensionsReportsOptions");
EndProcedure

// 
Procedure OnDefineObjectsWithTablePresentationCommonData(Objects) Export
	Objects.Add("Catalog.PredefinedReportsOptions");
EndProcedure

#Region PresentationOfDataLayoutSettings

Function RepresentationOfStructureElements(StructureItems) Export 
	
	RepresentationOfElements = New Array;
	
	For Each Item In StructureItems Do 
		
		If Not Item.Use Then 
			Continue;
		EndIf;
		
		ItemPresentation = RepresentationOfAStructureElement(Item);
		
		If ValueIsFilled(ItemPresentation) Then 
			RepresentationOfElements.Add(ItemPresentation);
		EndIf;
		
	EndDo;
	
	Return StrConcat(RepresentationOfElements, ", ");
	
EndFunction

Function RepresentationOfAStructureElement(Item) Export 
	
	ItemPresentation = "";
	
	If ValueIsFilled(Item.UserSettingPresentation) Then 
		
		ItemPresentation = Item.UserSettingPresentation;
		
	Else
		
		ElementType = TypeOf(Item);
		
		HeaderUsageParameter = Item.OutputParameters.Items.Find("TitleOutput");
		HeaderParameter = Item.OutputParameters.Items.Find("Title");
		
		If ValueIsFilled(HeaderParameter.Value)
			And (HeaderParameter.Use
			Or HeaderUsageParameter.Use
			And HeaderUsageParameter.Value <> DataCompositionTextOutputType.DontOutput) Then 
			
			ItemPresentation = HeaderParameter.Value;
			
		ElsIf ElementType = Type("DataCompositionTable") Then 
			
			ItemPresentation = NStr("en = 'Table';");
			
		ElsIf ElementType = Type("DataCompositionChart") Then 
			
			ItemPresentation = NStr("en = 'Chart';");
			
		ElsIf ElementType = Type("DataCompositionGroup")
			Or ElementType = Type("DataCompositionChartGroup")
			Or ElementType = Type("DataCompositionTableGroup") Then 
			
			ItemPresentation = GroupFieldsPresentation(Item);
			
		EndIf;
		
	EndIf;
	
	Return ItemPresentation;
	
EndFunction

Function GroupFieldsPresentation(Group, DeletionMark = False) Export 
	
	If ValueIsFilled(Group.UserSettingPresentation) Then 
		Return Group.UserSettingPresentation;
	EndIf;
	
	Fields = Group.GroupFields; // DataCompositionGroupFields
	
	If Fields.Items.Count() = 0 Then 
		Return NStr("en = '<Detailed records>';");
	EndIf;
	
	FieldsPresentation = New Array;
	
	For Each Item In Fields.Items Do 
		
		If Not Item.Use
			Or TypeOf(Item) = Type("DataCompositionAutoGroupField") Then
			
			Continue;
		EndIf;
		
		FieldDetails = Fields.GroupFieldsAvailableFields.FindField(Item.Field);
		
		If FieldDetails = Undefined Then
			
			DeletionMark = True;
			FieldPresentation = String(Item.Field);
			
		Else
			FieldPresentation = FieldDetails.Title;
		EndIf;
		
		If Item.GroupType <> DataCompositionGroupType.Items Then 
			FieldPresentation = FieldPresentation + " (" + Item.GroupType + ")";
		EndIf;
		
		FieldsPresentation.Add(FieldPresentation);
	EndDo;
	
	If FieldsPresentation.Count() = 0 Then 
		Return NStr("en = '<Detailed records>';");
	EndIf;
	
	Return StrConcat(FieldsPresentation, ", ");
	
EndFunction

Function RepresentationOfSelectedFields(SelectedFields, Collection = Undefined, FieldsPresentation = Undefined) Export 
	
	If ValueIsFilled(SelectedFields.UserSettingPresentation) Then 
		Return SelectedFields.UserSettingPresentation;
	EndIf;
	
	If Collection = Undefined Then 
		Collection = SelectedFields;
	EndIf;
	
	If FieldsPresentation = Undefined Then 
		FieldsPresentation = New Array;
	EndIf;
	
	For Each Item In Collection.Items Do 
		
		If Not Item.Use Then 
			Continue;
		EndIf;
		
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField") Then 
			
			FieldsPresentation.Add(NStr("en = 'Auto';"));
			
		ElsIf TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then 
			
			RepresentationOfSelectedFields(SelectedFields, Item, FieldsPresentation);
			
		ElsIf ValueIsFilled(Item.Title) Then 
			
			FieldsPresentation.Add(Item.Title);
			
		Else
			
			FieldDetails = SelectedFields.SelectionAvailableFields.FindField(Item.Field); // DataCompositionAvailableField
			
			FieldPresentation = ?(FieldDetails = Undefined, String(Item.Field), FieldDetails.Title);
			FieldsPresentation.Add(FieldPresentation);
			
		EndIf;
		
	EndDo;
	
	Return StrConcat(FieldsPresentation, ", ");
	
EndFunction

Function PresentationOfTheConditionalDesign(ConditionalAppearance) Export 
	
	AppearancePresentation = New Array;
	
	For Each Item In ConditionalAppearance.Items Do 
		
		If Not Item.Use Then 
			Continue;
		EndIf;
		
		ItemPresentation = ReportsClientServer.ConditionalAppearanceItemPresentation(Item, Undefined, "");
		
		If ValueIsFilled(ItemPresentation) Then 
			AppearancePresentation.Add(ItemPresentation);
		EndIf;
		
	EndDo;
	
	If AppearancePresentation.Count() = 0 Then 
		Return NStr("en = 'Appearance';");
	EndIf;
	
	Return StrConcat(AppearancePresentation, ", ");
	
EndFunction

// Parameters:
//  Sort - DataCompositionOrder
// 
// Returns:
//  String 
//
Function SortingView(Sort) Export 
	
	SortingView = New Array;
	
	For Each Item In Sort.Items Do 
		
		If Not Item.Use Then 
			Continue;
		EndIf;
		
		ItemPresentation = RepresentationOfTheSortingElement(Item, Sort);
		
		If ValueIsFilled(ItemPresentation) Then 
			SortingView.Add(ItemPresentation);
		EndIf;
		
	EndDo;
	
	If SortingView.Count() = 0 Then 
		Return NStr("en = 'Sort';");
	EndIf;
	
	Return StrConcat(SortingView, ", ");
	
EndFunction

// Parameters:
//  Item - DataCompositionOrderItem, DataCompositionAutoOrderItem
//  Sort - Undefined, DataCompositionOrder
// 
// Returns:
//  String
//
Function RepresentationOfTheSortingElement(Item, Sort = Undefined) Export 
	
	Title = "";
	
	If Not Item.Use Then 
		Return Title;
	EndIf;
	
	If TypeOf(Item) = Type("DataCompositionAutoOrderItem") Then 
		Return NStr("en = 'Auto';");
	EndIf;
	
	If TypeOf(Sort) = Type("DataCompositionOrder") Then
		SettingDetails = Sort.OrderAvailableFields.FindField(Item.Field);
		If SettingDetails <> Undefined Then
			Title = SettingDetails.Title;
		EndIf;
	EndIf;
	
	If IsBlankString(Title) Then
		Title = String(Item.Field);
	EndIf;
	
	If Item.OrderType = DataCompositionSortDirection.Asc Then 
		Return Title;
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (desc)';"), Title);
	
EndFunction

Function ReportOptionEmptyAssignment() Export
	
	Return PredefinedValue("Enum.ReportOptionPurposes.EmptyRef");
	
EndFunction

// Determines the default report option assignment.
// Returns:
//  EnumRef.ReportOptionPurposes
//
Function AssigningDefaultReportOption() Export
	Return Enums.ReportOptionPurposes.ForComputersAndTablets;
EndFunction

#EndRegion

#EndRegion

#Region Private

Function MeasurementsKey(FullReportName, VariantKey) Export
	Return Common.TrimStringUsingChecksum(
		FullReportName + "." + VariantKey, 135);
EndFunction

#Region IndexingSectionsOfTheReport

Function IndexOfTheReportStructure(Form) Export
	
	ReportSettings = Form.ReportSettings;
	ResultProperties = ReportSettings.ResultProperties;
	
	Settings = Form.Report.SettingsComposer.GetSettings();
	
	SettingsComposer = SettingsComposerCopy(Form.Report.SettingsComposer,
		ReportSettings.SchemaURL, Settings);
	
	SettingsComposer2 = SettingsComposerCopy(Form.Report.SettingsComposer,
		ReportSettings.SchemaURL, Settings);
	
	SettingsComposer2.ExpandAutoFields();
	Settings2 = SettingsComposer2.GetSettings();
	
	ResultProperties.FinalSettings = Settings;
	ResultProperties.SettingsComposer = SettingsComposer;
	ResultProperties.SettingsComposerWithoutAutoFields = SettingsComposer2;
	ResultProperties.FieldRoles = ReportFieldRoles(ReportSettings.SchemaURL);
	
	IndexOfTheReportStructure = Undefined;
	
	If IsTempStorageURL(ResultProperties.AddressOfTheReportStructureIndex) Then 
		IndexOfTheReportStructure = GetFromTempStorage(ResultProperties.AddressOfTheReportStructureIndex);
	EndIf;
	
	If IndexOfTheReportStructure = Undefined
		Or Form.VariantModified Then 
		
		IndexOfTheReportStructure = IndexOfTheReportStructureWithoutContext(Settings, Settings2);
		
		DefineFieldRoles(IndexOfTheReportStructure, ResultProperties.FieldRoles);
		DefineFormulaFields(ReportSettings.SchemaURL, Settings, IndexOfTheReportStructure);
		SetTheReportStructureIndexIDs(IndexOfTheReportStructure);
		DefineAvailableReportFieldActions(IndexOfTheReportStructure);
		
		ResultProperties.AddressOfTheReportStructureIndex = PutToTempStorage(
			IndexOfTheReportStructure, Form.UUID);
		
		FillReportHeaderLayoutProperties(ReportSettings.SchemaURL, IndexOfTheReportStructure);
		IndexOfTheReportStructure.Indexes.Add("SectionOrder, FieldPresentation, Text");
		
	EndIf;
	
	ResultProperties.FieldsIndex = IndexOfFieldsInTheReportStructure(IndexOfTheReportStructure);
	ResultProperties.MainField = MainReportFields(Form);
	ResultProperties.LayoutsAreDescribed = DataLayoutLayoutsAreDescribed(ReportSettings.SchemaURL);
	
	Return IndexOfTheReportStructure;
	
EndFunction

Function SettingsComposerCopy(CurrentSettingsComposer, SchemaURL, FinalSettings)
	
	SettingsComposer = New DataCompositionSettingsComposer;
	ReportsServer.InitializeSettingsComposer(SettingsComposer, SchemaURL);
	SettingsComposer.LoadSettings(FinalSettings);
	
	CopyAdditionalSettingsProperties(SettingsComposer, CurrentSettingsComposer);
	
	Return SettingsComposer;
	
EndFunction

Function IndexOfTheReportStructureWithoutContext(Settings, Settings2) Export 
	
	IndexOfTheReportStructure = NewReportStructureIndex();
	IndexReportSections(Settings2, Settings2, IndexOfTheReportStructure);
	IndexReportDimensions(Settings, Settings2, IndexOfTheReportStructure);
	
	DeleteUnidentifiedFields(IndexOfTheReportStructure);
	SpecifyTheOrderOfTheSections(IndexOfTheReportStructure);
	
	Return IndexOfTheReportStructure;
	
EndFunction

Procedure CopyAdditionalSettingsProperties(Receiver, Source)
	
	SettingsKinds = StrSplit("Settings, UserSettings", ", ", False);
	
	For Each SettingsType In SettingsKinds Do 
		
		SourceProperties = Source[SettingsType].AdditionalProperties;
		
		ThePropertiesOfTheReceiver = Receiver[SettingsType].AdditionalProperties;
		ThePropertiesOfTheReceiver.Clear();
		
		For Each Property In SourceProperties Do 
			ThePropertiesOfTheReceiver.Insert(Property.Key, Property.Value);
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure IndexReportSections(FinalSettings, Settings, IndexOfTheReportStructure, SectionOrder = 0)
	
	For Each Section In Settings.Structure Do 
		
		If Not Section.Use
			Or TypeOf(Section) = Type("DataCompositionChart") Then 
			
			Continue;
		EndIf;
		
		If TypeOf(Section) = Type("DataCompositionNestedObjectSettings") Then 
			
			IndexReportSections(FinalSettings, Section.Settings, IndexOfTheReportStructure, SectionOrder);
		
		Else
			
			SectionOrder = SectionOrder + 1;
			
			SectionIndex = IndexOfTheReportStructure.Add();
			SectionIndex.SectionOrder = SectionOrder;
			SectionIndex.IDOfTheSettings = FinalSettings.GetIDByObject(Settings);
			SectionIndex.SectionID = Settings.GetIDByObject(Section);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  ReportsSectionsIndex See NewReportStructureIndex
// 
// Returns:
//  Structure:
//   * IndexOfTheReportStructure - See NewReportStructureIndex
//   * GroupingOrder - Number
//   * FieldOrder - Number
//   * SortFields - Map
//
Function NewContextOfReportGroupingIndexing(IndexOfTheReportStructure)
	
	Context = New Structure;
	Context.Insert("IndexOfTheReportStructure", IndexOfTheReportStructure);
	Context.Insert("GroupingOrder", 0);
	Context.Insert("FieldOrder", 0);
	Context.Insert("SortFields", New Map);
	
	Return Context;
	
EndFunction

Procedure IndexReportDimensions(FinalSettings, FinalSettings2, IndexOfTheReportStructure)
	
	IndexOfReportSections = IndexOfTheReportStructure.Copy();
	
	For Each SectionIndex In IndexOfReportSections Do 
		
		Settings = FinalSettings.GetObjectByID(SectionIndex.IDOfTheSettings);
		Settings2 = FinalSettings2.GetObjectByID(SectionIndex.IDOfTheSettings);
		Section = Settings.GetObjectByID(SectionIndex.SectionID); // DataCompositionGroup, DataCompositionTable
		Section2 = Settings2.GetObjectByID(SectionIndex.SectionID); // DataCompositionGroup, DataCompositionTable
		
		If TypeOf(Section2) = Type("DataCompositionChart") Then 
			Continue;
		EndIf;
		
		Context = NewContextOfReportGroupingIndexing(IndexOfTheReportStructure);
		
		SortFields(Settings, Settings, Context.SortFields);
		
		If TypeOf(Section2) = Type("DataCompositionTable") Then 
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Section.Rows, Settings2, Section2.Rows);
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Section.Columns, Settings2, Section2.Columns);
		Else
			GroupingIndex = ReportGroupingIndex(Context, SectionIndex, Settings2, Section2);
			
			SortFields(Section, Settings, Context.SortFields);
			
			IndexReportGroupingFields(Context, GroupingIndex,
				Settings, Section, Settings2, Section2);
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Section.Structure, Settings2, Section2.Structure);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure IndexReportSectionDimensions(Context, SectionIndex,
			Settings, Groups, Settings2, Groups2)
	
	For DimensionNumber_ = 1 To Groups2.Count() Do
		Item = Groups[DimensionNumber_ - 1];
		Item2 = Groups2[DimensionNumber_ - 1];
		
		If Not Item2.Use Then 
			Continue;
		EndIf;
		
		ElementType = TypeOf(Item2);
		
		If ElementType = Type("DataCompositionNestedObjectSettings") Then 
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Item.Settings, Item.Settings.Structure, Item2.Settings, Item2.Settings.Structure);
			
		ElsIf ElementType = Type("DataCompositionTable") Then 
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Item.Rows, Settings2, Item2.Rows);
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Item.Columns, Settings2, Item2.Columns);
			
		ElsIf ElementType <> Type("DataCompositionChart") Then 
			
			SortFields(Item, Settings, Context.SortFields);
			
			GroupingIndex = ReportGroupingIndex(Context, SectionIndex, Settings2, Item2);
			
			IndexReportGroupingFields(Context, GroupingIndex,
				Settings, Item, Settings2, Item2);
			
			IndexReportSectionDimensions(Context, SectionIndex,
				Settings, Item.Structure, Settings2, Item2.Structure);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  Group - DataCompositionSettings
//              - DataCompositionGroup
//              - DataCompositionTableGroup
//  Settings - DataCompositionSettings
//  SortFields - Map of KeyAndValue:
//   * Key - DataCompositionField
//   * Value - DataCompositionSortDirection
//                 
//  Replace - Boolean
//
// Returns:
//  Map
//
Function SortFields(Group, Settings, SortFields = Undefined, Replace = True)
	
	If SortFields = Undefined Then 
		SortFields = New Map;
	EndIf;
	
	GroupType = TypeOf(Group);
	
	If GroupType <> Type("DataCompositionSettings")
		And GroupType <> Type("DataCompositionGroup")
		And GroupType <> Type("DataCompositionTableGroup") Then 
		
		Return SortFields;
	EndIf;
	
	SortingElements = Group.Order.Items;
	
	For Each Item In SortingElements Do 
		
		If Not Item.Use Then 
			Continue;
		EndIf;
		
		If TypeOf(Item) = Type("DataCompositionAutoOrderItem")
			And GroupType <> Type("DataCompositionSettings") Then 
			
			For Each FieldItem In Group.GroupFields.Items Do
				If TypeOf(FieldItem) = Type("DataCompositionGroupField")
				   And SortFields.Get(FieldItem.Field) = Undefined Then
					SortFields.Insert(FieldItem.Field, DataCompositionSortDirection.Asc);
				EndIf;
			EndDo;
			
		ElsIf TypeOf(Item) <> Type("DataCompositionAutoOrderItem")
			And (Replace Or SortFields[Item.Field] = Undefined) Then 
			
			SortFields.Insert(Item.Field, Item.OrderType);
			
		EndIf;
		
	EndDo;
	
	Return SortFields;
	
EndFunction

Function ReportGroupingIndex(Context, SectionIndex, Settings, Group)
	
	Context.GroupingOrder = Context.GroupingOrder + 1;
	
	GroupingIndex = Context.IndexOfTheReportStructure.Add();
	FillPropertyValues(GroupingIndex, SectionIndex);
	
	GroupingIndex.GroupingOrder = Context.GroupingOrder;
	GroupingIndex.GroupingID = Settings.GetIDByObject(Group);
	GroupingIndex.GroupName = Group.Name;
	GroupingIndex.PerformanceGroup = GroupFieldsPresentation(Group);
	GroupingIndex.ContainsTheParentGroup = ContainsTheParentGroup(Group);
	GroupingIndex.ContainsChildGroupings = ContainsChildGroupings(Group);
	
	Return GroupingIndex;
	
EndFunction

Function ContainsTheParentGroup(Group)
	
	ParentType = TypeOf(Group.Parent);
	
	Return ParentType = Type("DataCompositionGroup")
		Or ParentType = Type("DataCompositionTableGroup")
	
EndFunction

Function ContainsChildGroupings(Group)
	
	For Each Item In Group.Structure Do 
		
		ElementType = TypeOf(Item);
		
		If ElementType <> Type("DataCompositionGroup")
			And ElementType <> Type("DataCompositionTableGroup") Then 
			
			Continue;
		EndIf;
		
		If Item.Use Then 
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure IndexReportGroupingFields(Context, GroupingIndex,
			Settings, Group, Settings2, Group2)
	
	GroupingFieldsUsed = New Map;
	
	TheAutoFieldIsUsed = TheAutoFieldIsUsed(Group.Selection);
	SettingsUsed = ReportGroupingSettingsUsed(Settings, Group);
	
	GroupFields = Group2.GroupFields;
	
	For Each Item In GroupFields.Items Do 
		
		If TypeOf(Item) <> Type("DataCompositionGroupField")
			Or Not Item.Use Then 
			
			Continue;
		EndIf;
		
		GroupingFieldsUsed.Insert(Item.Field, Item);
		
		If TheAutoFieldIsUsed
			And Not ReportsOptionsInternalClientServer.TheFieldIsContainedInTheReportGrouping(Group.Selection, Item.Field)
			And Not ReportsOptionsInternalClientServer.TheFieldIsContainedInTheReportGrouping(SettingsUsed.Selection, Item.Field) Then 
			
			AddAReportFieldToTheIndex(Context,
				GroupingIndex, GroupFields, Item, GroupingFieldsUsed);
			
		EndIf;
		
	EndDo;
	
	IndexSelectedReportGroupingFields(Context,
		GroupingIndex, Settings2, Group2, GroupingFieldsUsed);
	
EndProcedure

Function TheAutoFieldIsUsed(Fields)
	
	For Each Item In Fields.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField")
			Or TypeOf(Item) = Type("DataCompositionAutoGroupField") Then 
			
			Return Item.Use;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure IndexSelectedReportGroupingFields(Context, GroupingIndex, Settings,
			Group, GroupingFieldsUsed, Fields = Undefined, Parent = Undefined)
	
	If Fields = Undefined Then 
		Fields = Group.Selection;
	EndIf;
	
	If Parent = Undefined Then 
		Parent = Group.Selection;
	EndIf;
	
	For Each Item In Fields.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField") Then 
			
			IndexTheSelectedFieldsOfTheReportSettings(Context,
				GroupingIndex, Settings, Group, GroupingFieldsUsed);
			
		ElsIf TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then 
			
			IndexSelectedReportGroupingFields(Context, GroupingIndex, Settings,
				Group, GroupingFieldsUsed, Item, Parent);
			
		ElsIf AllowedToUseTheFieldInTheGrouping(Group, Item.Field) Then 
			
			AddAReportFieldToTheIndex(Context,
				GroupingIndex, Parent, Item, GroupingFieldsUsed);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure IndexTheSelectedFieldsOfTheReportSettings(Context, GroupingIndex, Settings,
			Group, GroupingFieldsUsed, Fields = Undefined, Parent = Undefined)
	
	SettingsUsed = ReportGroupingSettingsUsed(Settings, Group);
	
	If Fields = Undefined Then 
		Fields = SettingsUsed.Selection;
	EndIf;
	
	If Parent = Undefined Then 
		Parent = SettingsUsed.Selection;
	EndIf;
	
	SortFields(Group, Settings, Context.SortFields);
	
	For Each Item In Fields.Items Do 
		
		ElementType = TypeOf(Item);
		
		If ElementType = Type("DataCompositionSelectedFieldGroup") Then 
			
			IndexTheSelectedFieldsOfTheReportSettings(Context, GroupingIndex, Settings,
				Group, GroupingFieldsUsed, Item, Parent);
			
		ElsIf ElementType <> Type("DataCompositionAutoSelectedField")
			And AllowedToUseTheFieldInTheGrouping(Group, Item.Field)
			And Not ReportsOptionsInternalClientServer.TheFieldIsContainedInTheReportGrouping(Group.Selection, Item.Field, False) Then 
			
			AddAReportFieldToTheIndex(Context, GroupingIndex, Parent, Item, GroupingFieldsUsed);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function AllowedToUseTheFieldInTheGrouping(Group, Field)
	
	Items = Group.GroupFields.Items;
	ThisIsAGroupingOfDetailedRecords = (Items.Count() = 0);
	
	If ThisIsAGroupingOfDetailedRecords
		And (ReportsOptionsInternalClientServer.TheFieldIsContainedInTheReportGrouping(Group.Selection, Field)
		Or Not ReportsOptionsInternalClientServer.ThisFieldIsUsedInTheParentReportDimensions(Group.Parent, Field)) Then 
		
		Return True;
	EndIf;
	
	AvailableField = Group.Selection.SelectionAvailableFields.FindField(Field);
	
	If AvailableField = Undefined Then 
		AvailableField = Group.GroupFields.GroupFieldsAvailableFields.FindField(Field);
	EndIf;
	
	If AvailableField <> Undefined
		And AvailableField.Resource Then 
		
		Return True;
	EndIf;
	
	For Each Item In Items Do 
		
		If TypeOf(Item) = Type("DataCompositionGroupField")
			And Item.Use
			And (Item.Field = Field
				Or StrFind(String(Item.Field), String(Field)) > 0
				Or StrFind(String(Field), String(Item.Field)) > 0) Then 
			
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function ReportGroupingSettingsUsed(Settings, Group)
	
	If TypeOf(Group.Parent) = Type("DataCompositionSettings") Then 
		Return Group.Parent;
	EndIf;
	
	Return Settings;
	
EndFunction

Procedure AddAReportFieldToTheIndex(Context, GroupingIndex, Parent, Field, GroupingFieldsUsed)
	
	If Not Field.Use Then 
		Return;
	EndIf;
	
	FieldDetails = DescriptionOfTheReportField(Parent, Field, GroupingFieldsUsed);
	
	If FieldDetails.Resource
		And StrFind(GroupingIndex.GroupingID, "/row/") > 0 Then 
		
		Return;
	EndIf;
	
	Search = New Structure("SectionOrder, GroupingOrder, Field");
	FillPropertyValues(Search, GroupingIndex);
	Search.Field = Field.Field;
	
	FoundFieldIndexes = Context.IndexOfTheReportStructure.FindRows(Search);
	
	If FoundFieldIndexes.Count() > 0 Then 
		
		FieldIndex = FoundFieldIndexes[0];
		
	Else
		
		Context.FieldOrder = Context.FieldOrder + 1;
		
		FieldIndex = Context.IndexOfTheReportStructure.Add();
		FillPropertyValues(FieldIndex, GroupingIndex);
		FieldIndex.FieldOrder = Context.FieldOrder;
		
	EndIf;
	
	FillPropertyValues(FieldIndex, FieldDetails);
	
	FieldIndex.FieldPresentation = Upper(FieldIndex.FieldPresentation);
	FieldIndex.SortDirection = Context.SortFields[Field.Field];
	FieldIndex.TheFieldIsSorted = (FieldIndex.SortDirection <> Undefined);
	
	If FieldIndex.ValueType.ContainsType(Type("ValueTable")) Then
		FieldIndex.ValueType = New TypeDescription;
	EndIf;
	
EndProcedure

Function DescriptionOfTheReportField(Parent, Field, GroupingFieldsUsed)
	
	FieldDetails = New Structure;
	FieldDetails.Insert("Field", Field.Field);
	FieldDetails.Insert("FieldID", Parent.GetIDByObject(Field));
	FieldDetails.Insert("FieldPresentation", String(Field.Field));
	FieldDetails.Insert("FieldType", TypeOf(Field));
	FieldDetails.Insert("ValueType", New TypeDescription("Undefined"));
	FieldDetails.Insert("Resource", False);
	
	GroupingField = GroupingFieldsUsed[Field.Field];
	GroupType = ?(GroupingField = Undefined, DataCompositionGroupType.Items, GroupingField.GroupType);
	
	FieldDetails.Insert("UsedInGroupingFields", GroupingField <> Undefined);
	FieldDetails.Insert("GroupType", GroupType);
	
	AvailableField = Undefined;
	
	If FieldDetails.FieldType = Type("DataCompositionGroupField") Then 
		
		AvailableField = Parent.GroupFieldsAvailableFields.FindField(Field.Field);
		
	ElsIf FieldDetails.FieldType = Type("DataCompositionSelectedField") Then 
		
		AvailableField = Parent.SelectionAvailableFields.FindField(Field.Field);
		
	EndIf;
	
	If AvailableField <> Undefined Then 
		
		FieldDetails.FieldPresentation = AvailableField.Title;
		FieldDetails.Resource = AvailableField.Resource;
		FieldDetails.ValueType = AvailableField.ValueType;
		
	EndIf;
	
	If FieldDetails.FieldType = Type("DataCompositionSelectedField")
		And ValueIsFilled(Field.Title) Then 
		
		FieldDetails.FieldPresentation = Field.Title;
	EndIf;
	
	Return FieldDetails;
	
EndFunction

Procedure DeleteUnidentifiedFields(IndexOfTheReportStructure)
	
	FoundRecords = IndexOfTheReportStructure.FindRows(New Structure("FieldID", Undefined));
	For Each Record In FoundRecords Do 
		IndexOfTheReportStructure.Delete(Record);
	EndDo;
	
EndProcedure

Procedure SpecifyTheOrderOfTheSections(IndexOfTheReportStructure)
	
	IndexOfTheReportStructure.Sort("SectionOrder, GroupingOrder, FieldOrder");
	
	Sections = IndexOfTheReportStructure.Copy();
	Sections.GroupBy("SectionOrder");
	
	Search = New Structure("SectionOrder");
	
	For SectionOrder = 1 To Sections.Count() Do 
		
		Search.SectionOrder = Sections[SectionOrder - 1].SectionOrder;
		FoundRecords = IndexOfTheReportStructure.FindRows(Search);
		
		For Each Record In FoundRecords Do 
			Record.SectionOrder = SectionOrder;
		EndDo;
		
	EndDo;
	
	IndexOfTheReportStructure.FillValues(Sections.Count(), "NumberOfPartitions");
	
EndProcedure

Procedure DefineFieldRoles(IndexOfTheReportStructure, FieldRoles)
	
	For Each Record In IndexOfTheReportStructure Do 
		
		Record.Period = (FieldRoles.TimeIntervals_[Record.Field] <> Undefined);
		Record.Dimension = (FieldRoles.Dimensions[Record.Field] <> Undefined);
		
	EndDo;
	
EndProcedure

Function ReportFieldRoles(SchemaURL)
	
	FieldRoles = New Structure;
	FieldRoles.Insert("TimeIntervals_", New Map);
	FieldRoles.Insert("Dimensions", New Map);
	FieldRoles.Insert("Balance", New Map);
	
	Schema = GetFromTempStorage(SchemaURL);
	
	For Each DataSet In Schema.DataSets Do 
		
		For Each Field In DataSet.Fields Do 
			
			If TypeOf(Field) = Type("DataCompositionSchemaDataSetFieldFolder")
				Or TypeOf(Field) = Type("DataCompositionSchemaNestedDataSet") Then 
				
				Continue;
			EndIf;
			
			If Field.Role.PeriodNumber > 0 Then 
				
				FieldRoles.TimeIntervals_.Insert(New DataCompositionField(Field.Field), DescriptionOfTheReportFieldRole(Field.Role));
				
			ElsIf Field.Role.Dimension Then 
				
				FieldRoles.Dimensions.Insert(New DataCompositionField(Field.Field), DescriptionOfTheReportFieldRole(Field.Role));
				
			ElsIf Field.Role.Balance Then 
				
				FieldRoles.Balance.Insert(New DataCompositionField(Field.Field), DescriptionOfTheReportFieldRole(Field.Role));
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return FieldRoles;
	
EndFunction

Function DescriptionOfTheReportFieldRole(Role)
	
	RoleDetails = New Structure("AccountTypeExpression, BalanceGroup, IgnoreNULLValues, Dimension,
		|PeriodNumber, Required, Balance, AccountField, DimensionAttribute, ParentDimension, Account");
	
	FillPropertyValues(RoleDetails, Role);
	
	RoleDetails.Insert("AccountingBalanceType", String(Role.AccountingBalanceType));
	RoleDetails.Insert("ParentDimension", String(Role.ParentDimension));
	RoleDetails.Insert("PeriodType", String(Role.PeriodType));
	
	Return RoleDetails;
	
EndFunction

Procedure DefineFormulaFields(SchemaURL, Settings, IndexOfTheReportStructure)
	
	For Each Record In IndexOfTheReportStructure Do 
		Record.IsFormula = ThisIsACustomField(Settings.UserFields, Record.Field);
	EndDo;
	
	If Not IsTempStorageURL(SchemaURL) Then 
		Return;
	EndIf;
	
	Schema = GetFromTempStorage(SchemaURL);
	
	If TypeOf(Schema) <> Type("DataCompositionSchema") Then 
		Return;
	EndIf;
	
	FoundRecords = IndexOfTheReportStructure.FindRows(New Structure("IsFormula", False));
	CalculatedFields = Schema.CalculatedFields;
	
	For Each Record In FoundRecords Do 
		Record.IsFormula = CalculatedFields.Find(String(Record.Field)) <> Undefined;
	EndDo;
	
EndProcedure

Function ThisIsACustomField(UserFields, Field)
	
	For Each Item In UserFields.Items Do 
		
		If Item.DataPath = String(Field) Then 
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure SetTheReportStructureIndexIDs(IndexOfTheReportStructure)
	
	For Each IndexOf In IndexOfTheReportStructure Do 
		IndexOf.IndexID = New UUID();
	EndDo;
	
	IndexOfTheReportStructure.Indexes.Add("IndexID");
	
EndProcedure

Procedure DefineAvailableReportFieldActions(IndexOfTheReportStructure)
	
	Sections = IndexOfTheReportStructure.Copy();
	Sections.GroupBy("SectionOrder");
	OrderOfSections = Sections.UnloadColumn("SectionOrder");
	
	For Each SectionOrder In OrderOfSections Do 
		
		DefineTheAvailableActionsOfTheReportSectionFields(IndexOfTheReportStructure, SectionOrder);
		DefineTheAvailableActionsOfTheReportSectionFields(IndexOfTheReportStructure, SectionOrder, True);
		
	EndDo;
	
EndProcedure

Procedure DefineTheAvailableActionsOfTheReportSectionFields(IndexOfTheReportStructure, SectionOrder, ThisIsAResource = False)
	
	SearchForSectionFields = New Structure("SectionOrder, Resource", SectionOrder, ThisIsAResource);
	GroupingFields = IndexOfTheReportStructure.Copy(SearchForSectionFields);
	
	SearchForGroupingFields = New Structure("GroupingOrder");
	
	Groups = GroupingFields.Copy();
	Groups.GroupBy("GroupingOrder");
	TheOrderOfTheGroups = Groups.UnloadColumn("GroupingOrder");
	TheGroupingFieldsAreHigher = Undefined;
	
	For Each GroupingOrder In TheOrderOfTheGroups Do 
		
		SearchForGroupingFields.GroupingOrder = GroupingOrder;
		GroupFields = GroupingFields.Copy(SearchForGroupingFields);
		GroupFields.Sort("FieldOrder");
		
		TheGroupingFieldsAreBelow = Undefined;
		IndexOf = TheOrderOfTheGroups.Find(GroupingOrder);
		If IndexOf + 1 < TheOrderOfTheGroups.Count() Then
			SearchForGroupingFields.GroupingOrder = TheOrderOfTheGroups[IndexOf + 1];
			TheGroupingFieldsAreBelow = GroupingFields.Copy(SearchForGroupingFields);
		EndIf;
		
		For Each GroupingField In GroupFields Do 
			
			ThisIsTheColumnGroupingField = StrFind(GroupingField.GroupingID, "/column/") > 0
				And GroupingField.UsedInGroupingFields;
			
			IndexOf = IndexOfTheReportStructure.Find(GroupingField.IndexID, "IndexID");
			IndexOf.GroupBySelectedField = Not ThisIsTheColumnGroupingField;
			IndexOf.InsertFieldLeft = Not ThisIsTheColumnGroupingField;
			IndexOf.InsertFieldRight = Not ThisIsTheColumnGroupingField;
			IndexOf.InsertGroupAbove = Not ThisIsTheColumnGroupingField And Not ThisIsAResource;
			IndexOf.InsertGroupBelow = Not ThisIsTheColumnGroupingField And Not ThisIsAResource;
			
			IndexOf.MoveFieldUp = Not ThisIsTheColumnGroupingField
				And SectionOrder = 1
				And Not ThisIsAResource
				And IndexOf.ContainsTheParentGroup
				And TheGroupingFieldsAreHigher <> Undefined
				And TheGroupingFieldsAreHigher.Find(Not GroupingField.Period, "Period") = Undefined;
			
			IndexOf.MoveFieldDown = Not ThisIsTheColumnGroupingField
				And SectionOrder = 1
				And Not ThisIsAResource
				And IndexOf.ContainsChildGroupings
				And TheGroupingFieldsAreBelow <> Undefined
				And TheGroupingFieldsAreBelow.Find(Not GroupingField.Period, "Period") = Undefined;
			
			If Not ThisIsTheColumnGroupingField
				And GroupFields.IndexOf(GroupingField) > 0 Then 
				
				IndexOf.MoveFieldLeft = True;
			EndIf;
			
			If Not ThisIsTheColumnGroupingField
				And GroupFields.IndexOf(GroupingField) < GroupFields.Count() - 1 Then 
				
				IndexOf.MoveFieldRight = True;
			EndIf;
			
			IndexOf.HideField = Not ThisIsTheColumnGroupingField;
			IndexOf.RenameField = Not ThisIsTheColumnGroupingField;
			IndexOf.ApplyAppearanceMore = Not ThisIsTheColumnGroupingField;
			
		EndDo;
		
		TheGroupingFieldsAreHigher = GroupFields;
	EndDo;
	
EndProcedure

Function IndexOfFieldsInTheReportStructure(IndexOfTheReportStructure)
	
	FieldsIndex = New Map;
	
	Sections = IndexOfTheReportStructure.Copy();
	Sections.GroupBy("SectionOrder");
	
	OrderOfSections = Sections.UnloadColumn("SectionOrder");
	
	SearchForGroupings = New Structure("SectionOrder");
	SearchForAField = New Structure("SectionOrder, GroupingOrder");
	
	For Each SectionOrder In OrderOfSections Do 
		
		SearchForGroupings.SectionOrder = SectionOrder;
		Groups = IndexOfTheReportStructure.Copy(SearchForGroupings);
		Groups.GroupBy("GroupingOrder");
		
		TheOrderOfTheGroups = Groups.UnloadColumn("GroupingOrder");
		
		IndexOfTheSectionFields = FieldsIndex[SectionOrder];
		If IndexOfTheSectionFields = Undefined Then 
			IndexOfTheSectionFields = New Map;
		EndIf;
		
		For Each GroupingOrder In TheOrderOfTheGroups Do 
			
			SearchForAField.SectionOrder = SectionOrder;
			SearchForAField.GroupingOrder = GroupingOrder;
			GroupFields = IndexOfTheReportStructure.FindRows(SearchForAField);
			
			IndexOfTheGroupingFields = IndexOfTheSectionFields[GroupingOrder];
			If IndexOfTheGroupingFields = Undefined Then 
				IndexOfTheGroupingFields = New Map;
			EndIf;
			
			For Each GroupingField In GroupFields Do 
				
				FieldProperties = StandardReportFieldProperties();
				FillPropertyValues(FieldProperties, GroupingField);
				
				IndexOfTheGroupingFields.Insert(GroupingField.Field, FieldProperties);
				
			EndDo;
			
			IndexOfTheSectionFields.Insert(GroupingOrder, IndexOfTheGroupingFields);
			
		EndDo;
		
		FieldsIndex.Insert(SectionOrder, IndexOfTheSectionFields);
		
	EndDo;
	
	Return FieldsIndex;
	
EndFunction

Function MainReportFields(Form)
	
	MainField = New Array;
	
	ReportsOverridable.WhenDefiningTheMainFields(Form, MainField);
	
	// Local override for a report.
	If Form.ReportSettings.Events.WhenDefiningTheMainFields Then 
		
		Report = ReportsServer.ReportObject(Form.ReportSettings.FullName);
		Report.WhenDefiningTheMainFields(Form, MainField);
		
	EndIf;
	
	Return MainField;
	
EndFunction

Function DataLayoutLayoutsAreDescribed(SchemaURL)
	
	Schema = GetFromTempStorage(SchemaURL);
	
	If TypeOf(Schema) <> Type("DataCompositionSchema") Then 
		Return False;
	EndIf;
	
	Return Schema.Templates.Count() > 0
		Or Schema.GroupHeaderTemplates.Count() > 0
		Or Schema.GroupTemplates.Count() > 0
		Or Schema.FieldTemplates.Count() > 0
		Or Schema.TotalFieldsTemplates.Count() > 0;
	
EndFunction

Procedure FillReportHeaderLayoutProperties(SchemaURL, IndexOfTheReportStructure)
	
	Schema = GetFromTempStorage(SchemaURL);
	
	LayoutsByTypes = New Array;
	LayoutsByTypes.Add(Schema.GroupHeaderTemplates);
	LayoutsByTypes.Add(Schema.GroupTemplates);
	
	For Each LayoutsByType In LayoutsByTypes Do 
	
		For Each Template In LayoutsByType Do 
			
			GroupingIndex = IndexOfTheReportStructure.Find(Template.GroupName, "GroupName");
			If GroupingIndex = Undefined Then 
				Continue;
			EndIf;
			
			TemplateDetails = Schema.Templates.Find(Template.Template);
			
			If TypeOf(TemplateDetails.Template) <> Type("DataCompositionAreaTemplate") Then 
				Continue;
			EndIf;
			
			For Each TableRow In TemplateDetails.Template Do 
				For Each Cell In TableRow.Cells Do 
					If Cell.Items.Count() > 0 Then 
						GroupingIndex.Text = Cell.Items[0].Value;
					EndIf;
				EndDo;
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Returns:
//  ValueTable:
//    * SectionOrder - Number
//    * NumberOfPartitions - Number
//    * GroupingOrder - Number
//    * FieldOrder - Number
//    * IDOfTheSettings - DataCompositionID
//    * SectionID - DataCompositionID
//    * GroupingID - DataCompositionID
//    * FieldID - DataCompositionID
//    * Field - DataCompositionField
//    * FieldType - Type
//    * UsedInGroupingFields - Boolean
//    * GroupType - DataCompositionGroupType
//    * GroupName - String
//    * PerformanceGroup - String
//    * FieldPresentation - String
//    * Text - String
//    * Period - Boolean
//    * Dimension - Boolean
//    * Resource - Boolean
//    * IsFormula - Boolean
//    * ValueType - Type
//    * TheFieldIsSorted - Boolean
//    * SortDirection - DataCompositionSortDirection
//    * GroupBySelectedField - Boolean
//    * InsertFieldLeft - Boolean
//    * InsertFieldRight - Boolean
//    * InsertGroupAbove - Boolean
//    * InsertGroupBelow - Boolean
//    * MoveFieldLeft - Boolean
//    * MoveFieldRight - Boolean
//    * MoveFieldUp - Boolean
//    * MoveFieldDown - Boolean
//    * HideField - Boolean
//    * RenameField - Boolean
//    * FormatNegativeValues - Boolean
//    * FormatPositiveValues - Boolean
//    * ApplyAppearanceMore - Boolean
//    * ContainsTheParentGroup - Boolean
//    * ContainsChildGroupings - Boolean
//    * IndexID - UUID
// 
Function NewReportStructureIndex() Export 
	
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	FlagDetails = New TypeDescription("Boolean");
	FieldDetails = New TypeDescription("DataCompositionField");
	TypeDescription = New TypeDescription("TypeDescription");
	TypeDetails = New TypeDescription("Type");
	IDDetails = New TypeDescription("UUID");
	DescriptionOfTheGroupingType = New TypeDescription("DataCompositionGroupType");
	
	IndexOf = New ValueTable;
	IndexOf.Columns.Add("SectionOrder", NumberDetails);
	IndexOf.Columns.Add("NumberOfPartitions", NumberDetails);
	IndexOf.Columns.Add("GroupingOrder", NumberDetails);
	IndexOf.Columns.Add("FieldOrder", NumberDetails);
	
	IndexOf.Columns.Add("IDOfTheSettings");
	IndexOf.Columns.Add("SectionID");
	IndexOf.Columns.Add("GroupingID");
	IndexOf.Columns.Add("FieldID");
	
	IndexOf.Columns.Add("Field", FieldDetails);
	IndexOf.Columns.Add("FieldType", TypeDetails);
	
	IndexOf.Columns.Add("UsedInGroupingFields", FlagDetails);
	IndexOf.Columns.Add("GroupType", DescriptionOfTheGroupingType);
	
	IndexOf.Columns.Add("GroupName", RowDescription);
	IndexOf.Columns.Add("PerformanceGroup", RowDescription);
	IndexOf.Columns.Add("FieldPresentation", RowDescription);
	IndexOf.Columns.Add("Text", RowDescription);
	
	IndexOf.Columns.Add("Period", FlagDetails);
	IndexOf.Columns.Add("Dimension", FlagDetails);
	IndexOf.Columns.Add("Resource", FlagDetails);
	IndexOf.Columns.Add("IsFormula", FlagDetails);
	
	IndexOf.Columns.Add("ValueType", TypeDescription);
	IndexOf.Columns.Add("TheFieldIsSorted", FlagDetails);
	IndexOf.Columns.Add("SortDirection");
	
	IndexOf.Columns.Add("GroupBySelectedField", FlagDetails);
	
	IndexOf.Columns.Add("InsertFieldLeft", FlagDetails);
	IndexOf.Columns.Add("InsertFieldRight", FlagDetails);
	IndexOf.Columns.Add("InsertGroupAbove", FlagDetails);
	IndexOf.Columns.Add("InsertGroupBelow", FlagDetails);
	
	IndexOf.Columns.Add("MoveFieldLeft", FlagDetails);
	IndexOf.Columns.Add("MoveFieldRight", FlagDetails);
	IndexOf.Columns.Add("MoveFieldUp", FlagDetails);
	IndexOf.Columns.Add("MoveFieldDown", FlagDetails);
	
	IndexOf.Columns.Add("HideField", FlagDetails);
	IndexOf.Columns.Add("RenameField", FlagDetails);
	
	IndexOf.Columns.Add("FormatNegativeValues", FlagDetails);
	IndexOf.Columns.Add("FormatPositiveValues", FlagDetails);
	IndexOf.Columns.Add("ApplyAppearanceMore", FlagDetails);
	
	IndexOf.Columns.Add("ContainsTheParentGroup", FlagDetails);
	IndexOf.Columns.Add("ContainsChildGroupings", FlagDetails);
	
	IndexOf.Columns.Add("IndexID", IDDetails);
	
	Return IndexOf;
	
EndFunction

Function StandardReportFieldProperties()
	
	IndexOf = New Structure;
	IndexOf.Insert("FieldOrder", 0);
	IndexOf.Insert("FieldID", Undefined);
	IndexOf.Insert("FieldPresentation", "");
	
	IndexOf.Insert("TheFieldIsSorted", False);
	IndexOf.Insert("SortDirection", Undefined);
	
	IndexOf.Insert("Resource", False);
	IndexOf.Insert("ValueType", Undefined);
	IndexOf.Insert("FieldType", Undefined);
	
	IndexOf.Insert("IDOfTheSettings", Undefined);
	IndexOf.Insert("SectionID", Undefined);
	IndexOf.Insert("GroupingID", Undefined);
	
	IndexOf.Insert("IndexID", Undefined);
	
	Return IndexOf;
	
EndFunction

#EndRegion

#Region InitializeThePropertiesOfTheTableHeaders

Procedure DefineTheHierarchyOfReportHeaders(HeaderPropertiesSection, Headers)
	
	HeaderPropertiesSection.GroupBy("Top, Left, Bottom, Right, Name, Details");
	HeaderPropertiesSection.Sort("Top, Left");
	HeaderPropertiesSection.Indexes.Add("Top, Bottom, Left");
	
	For Each Record In HeaderPropertiesSection Do 
		
		If Record.Details <> Undefined Then 
			Continue;
		EndIf;
		
		Top = Record.Bottom + 1;
		FoundAreas = HeaderPropertiesSection.FindRows(New Structure("Top, Left", Top, Record.Left));
		
		While FoundAreas.Count() > 0 Do 
			
			AreaProperties = Headers[Record.Name];
			AreaProperties.NumberOfChildHeaders = AreaProperties.NumberOfChildHeaders + 1;
			
			Top = Top + 1;
			FoundAreas = HeaderPropertiesSection.FindRows(New Structure("Top, Left", Top, Record.Left));
			
		EndDo;
		
		Bottom = Record.Top - 1;
		FoundAreas = HeaderPropertiesSection.FindRows(New Structure("Bottom, Left", Bottom, Record.Left));
		
		While FoundAreas.Count() > 0 Do 
			
			AreaProperties = Headers[Record.Name];
			AreaProperties.NumberOfParentHeaders = AreaProperties.NumberOfParentHeaders + 1;
			
			Bottom = Bottom - 1;
			FoundAreas = HeaderPropertiesSection.FindRows(New Structure("Bottom, Left", Bottom, Record.Left));
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function ReportSectionBoundaries(ReportResult, HeaderPropertiesSection)
	
	Boundaries = New ValueList;
	
	UpperBounds = HeaderPropertiesSection.Copy();
	UpperBounds.GroupBy("Top");
	UpperBounds.Sort("Top");
	
	For Each Record In UpperBounds Do 
		
		IndexOf = UpperBounds.IndexOf(Record);
		
		If IndexOf = 0 Then 
			Continue;
		EndIf;
		
		If (Record.Top - UpperBounds[IndexOf - 1].Top) > 1 Then 
			Boundaries.Add(Max(0, Record.Top - 1));
		EndIf;
		
	EndDo;
	
	Boundaries.Add(ReportResult.TableHeight);
	
	Return Boundaries;
	
EndFunction

Procedure AddPropertiesToReportHeaders(Form, ReportResult, Headers, HeaderPropertiesSection, IndexOfTheReportStructure, TheBoundariesOfThePartitions)
	
	SectionOrder = 1;
	BorderOfTheCurrentSection = 0;
	ProcessedFields = New Map;
	
	For Each Boundary In TheBoundariesOfThePartitions Do 
		
		For Each Record In HeaderPropertiesSection Do 
			
			TitleProperties = Headers[Record.Name];
			
			If TitleProperties.Top >= BorderOfTheCurrentSection
				And TitleProperties.Top <= Boundary.Value Then 
				
				FieldIndex = IndexOfTheFieldByHeaderProperties(
					Form, TitleProperties, IndexOfTheReportStructure, SectionOrder, ProcessedFields);
				
				If FieldIndex = Undefined Then 
					Continue;
				EndIf;
				
				FillPropertyValues(TitleProperties, FieldIndex,, "Text");
				
				If ValueIsFilled(FieldIndex.Text) Then 
					TitleProperties.Text = FieldIndex.Text;
				EndIf;
				
				IsNumber = TitleProperties.ValueType.ContainsType(Type("Number"));
				TitleProperties.FormatNegativeValues = IsNumber;
				TitleProperties.FormatPositiveValues = IsNumber;
				
				If Form.GetCurrentResultViewMode() = ReportResultViewMode.Default Then
					InsertSortingIndicator(FieldIndex, TitleProperties, ReportResult.Area(Record.Name));
				EndIf;
				
			EndIf;
			
		EndDo;
		
		SectionOrder = SectionOrder + 1;
		BorderOfTheCurrentSection = Boundary.Value;
		
	EndDo;
	
EndProcedure

Function IndexOfTheFieldByHeaderProperties(Form, TitleProperties, IndexOfTheReportStructure, SectionOrder, ProcessedFields)
	
	Search = New Structure("SectionOrder, FieldPresentation", SectionOrder, Upper(TitleProperties.Text));
	FieldIndex = IndexOfTheFieldByView(IndexOfTheReportStructure, Search, ProcessedFields);
	
	If FieldIndex = Undefined Then 
		FieldIndex = IndexOfTheFieldByDecryption(Form, TitleProperties.Details, IndexOfTheReportStructure, Search, ProcessedFields);
	EndIf;
	
	If FieldIndex <> Undefined Then 
		Return FieldIndex;
	EndIf;
	
	Search = New Structure("SectionOrder, Text", SectionOrder, TitleProperties.Text);
	FoundRecords = IndexOfTheReportStructure.FindRows(Search);
	
	If FoundRecords.Count() > 0 Then 
		FieldIndex = FoundRecords[0];
	EndIf;
	
	Return FieldIndex;
	
EndFunction

Function IndexOfTheFieldByDecryption(Form, Details, IndexOfTheReportStructure, Search, ProcessedFields)
	
	If TypeOf(Details) <> Type("DataCompositionDetailsID") Then 
		Return Undefined;
	EndIf;
	
	Data = DataOfTheDecryptionElement(Form, Details);
	
	If Data = Undefined Then 
		Return Undefined;
	EndIf;
	
	SearchByField = New Structure;
	SearchByField.Insert("SectionOrder", Search.SectionOrder);
	SearchByField.Insert("Field", New DataCompositionField(Data.Field));
	
	FoundFields = IndexOfTheReportStructure.FindRows(SearchByField);
	
	If FoundFields.Count() > 0 Then 
		Return FoundFields[0];
	EndIf;
	
	Search.FieldPresentation = Upper(Data.Field);
	
	Return IndexOfTheFieldByView(IndexOfTheReportStructure, Search, ProcessedFields);
	
EndFunction

Function IndexOfTheFieldByView(IndexOfTheReportStructure, Search, ProcessedFields)
	
	SuitableField = SuitableField(IndexOfTheReportStructure, Search, ProcessedFields);
	
	If SuitableField <> Undefined Then 
		Return SuitableField;
	EndIf;
	
	OwnerSAreaWithBankDetails = StrFind(Search.FieldPresentation, ",") > 0;
	
	If OwnerSAreaWithBankDetails Then 
		Search.FieldPresentation = StrSplit(Search.FieldPresentation, ",")[0];
	EndIf;
	
	SuitableField = SuitableField(IndexOfTheReportStructure, Search, ProcessedFields);
	
	If SuitableField <> Undefined Then 
		Return SuitableField;
	EndIf;
	
	TitleDescription = StrSplit(Search.FieldPresentation, ".");
	
	SearchForASection = New Structure("SectionOrder", Search.SectionOrder);
	FoundFields = IndexOfTheReportStructure.FindRows(SearchForASection);
	
	For Each FieldIndex In FoundFields Do 
		
		DescriptionOfTheView = StrSplit(FieldIndex.FieldPresentation, ".");
		
		NumberOfMatches = 0;
		
		For Each Particle In TitleDescription Do 
			
			NormalizedFragment = TrimAll(Particle);
			
			If DescriptionOfTheView.Find(NormalizedFragment) <> Undefined Then 
				NumberOfMatches = NumberOfMatches + 1;
			EndIf;
			
		EndDo;
		
		If OwnerSAreaWithBankDetails
			And NumberOfMatches = DescriptionOfTheView.Count()
			Or Not OwnerSAreaWithBankDetails
			And NumberOfMatches = TitleDescription.Count() Then 
			
			Return FieldIndex;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function SuitableField(IndexOfTheReportStructure, Search, ProcessedFields)
	
	FoundFields = IndexOfTheReportStructure.FindRows(Search);
	
	Return FieldIndexRaw(
		IndexOfTheReportStructure, Search.FieldPresentation, FoundFields, ProcessedFields);
	
EndFunction

Function FieldIndexRaw(IndexOfTheReportStructure, FieldPresentation, FoundFields, ProcessedFields)
	
	If FoundFields.Count() = 0 Then 
		Return Undefined;
	EndIf;
	
	If FoundFields.Count() = 1 Then 
		Return FoundFields[0];
	EndIf;
	
	ProcessedIndexes = ProcessedFields[FieldPresentation];
	
	If ProcessedIndexes = Undefined Then 
		
		SuitableField = FoundFields[0];
		
		ProcessedIndexes = New Map;
		ProcessedIndexes.Insert(IndexOfTheReportStructure.IndexOf(SuitableField), SuitableField);
		
		ProcessedFields.Insert(FieldPresentation, ProcessedIndexes);
		
		Return SuitableField;
		
	EndIf;
	
	SuitableField = Undefined;
	
	For Each FoundField In FoundFields Do 
		
		FieldIndex = IndexOfTheReportStructure.IndexOf(FoundField);
		
		If ProcessedIndexes[FieldIndex] = Undefined Then 
			
			SuitableField = FoundField;
			Break;
			
		EndIf;
		
	EndDo;
	
	If SuitableField = Undefined Then 
		Return FoundFields[0];
	EndIf;
	
	ProcessedIndexes.Insert(FieldIndex, SuitableField);
	ProcessedFields.Insert(FieldPresentation, ProcessedIndexes);
	
	Return SuitableField;
	
EndFunction

Procedure InsertSortingIndicator(FieldIndex, TitleProperties, Cell)
	
	If Not FieldIndex.TheFieldIsSorted Then 
		Return;
	EndIf;
	
	MinimumColumnWidthForIndicatorOutput = 5;
	
	If Cell.ColumnWidth > 0
		And Cell.ColumnWidth <= MinimumColumnWidthForIndicatorOutput Then 
		
		Return;
	EndIf;
	
	If TitleProperties.SectionOrder <> 1 Then
		Return;
	EndIf;
	
	If FieldIndex.SortDirection = DataCompositionSortDirection.Asc Then 
		
		TitleProperties.SortAsc = False;
		Cell.Picture = PictureLib.SortRowsAsc;
		
	ElsIf FieldIndex.SortDirection = DataCompositionSortDirection.Desc Then 
		
		TitleProperties.SortDesc = False;
		Cell.Picture = PictureLib.SortRowsDesc;
		
	EndIf;
	
	Cell.PictureSize = PictureSize.RealSize;
	Cell.PictureHorizontalAlign = HorizontalAlign.Right;
	Cell.PictureVerticalAlign = VerticalAlign.Top;
	
EndProcedure

Function AbortScanReportResult(Cell, IndexOfTheReportStructure, SectionHeaderBorder)
	
	If IndexOfTheReportStructure.Count() = 0 Then 
		Return True;
	EndIf;
	
	NumberOfPartitions = IndexOfTheReportStructure[0].NumberOfPartitions;
	
	If NumberOfPartitions > 1 Then 
		Return False;
	EndIf;
	
	If SectionHeaderBorder = Undefined
		And Not ThisReportHeaderCell(Cell) Then 
		
		Return False;
	EndIf;
	
	If SectionHeaderBorder = Undefined
		Or ThisReportHeaderCell(Cell) And Cell.Top - SectionHeaderBorder = 1 Then 
		
		SectionHeaderBorder = Cell.Bottom;
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function ThisReportHeaderCell(Cell)
	
	Return Cell.ColumnSizeChangeMode = SizeChangeMode.QuickChange;
	
EndFunction

Function StandardSectionOfReportHeaderProperties()
	
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	
	Properties = New ValueTable;
	Properties.Columns.Add("Top", NumberDetails);
	Properties.Columns.Add("Left", NumberDetails);
	Properties.Columns.Add("Bottom", NumberDetails);
	Properties.Columns.Add("Right", NumberDetails);
	Properties.Columns.Add("Name", RowDescription);
	Properties.Columns.Add("Details");
	
	Return Properties;
	
EndFunction

// Returns:
//  Structure:
//    * IndexID - UUID
//    * FormatPositiveValues - Boolean
//    * FormatNegativeValues - Boolean
//    * SortDesc - Boolean
//    * SortAsc - Boolean
//    * MoveFieldDown - Boolean
//    * MoveFieldUp - Boolean
//    * MoveFieldRight - Boolean
//    * MoveFieldLeft - Boolean
//    * GroupBySelectedField - Boolean
//    * InsertGroupBelow - Boolean
//    * InsertGroupAbove - Boolean
//    * InsertFieldRight - Boolean
//    * InsertFieldLeft - Boolean
//    * HideField - Boolean
//    * RenameField - Boolean
//    * ApplyAppearanceMore - Boolean
//    * UsedInGroupingFields - Boolean
//    * FieldType - Type
//    * ValueType - TypeDescription
//    * Resource - Boolean
//    * Dimension - Boolean
//    * Period - Boolean
//    * SortDirection - DataCompositionSortDirection
//                            - Undefined
//    * TheFieldIsSorted - Boolean
//    * Field - DataCompositionField
//    * FieldID - DataCompositionID
//    * GroupingID - DataCompositionID
//    * SectionID - DataCompositionID
//    * IDOfTheSettings - DataCompositionID
//    * FieldOrder - Number
//    * GroupingOrder - Number
//    * SectionOrder - Number
//    * NumberOfParentHeaders - Number
//    * NumberOfChildHeaders - Number
//    * Details - DataCompositionDetailsID
//                  - Undefined
//    * Right - Number
//    * Left - Number
//    * Bottom - Number
//    * Top - Number
//    * Text - String
//
Function StandardReportHeaderProperties() Export
	
	Properties = New Structure;
	Properties.Insert("Text", "");
	Properties.Insert("Top", 0);
	Properties.Insert("Bottom", 0);
	Properties.Insert("Left", 0);
	Properties.Insert("Right", 0);
	Properties.Insert("Details", Undefined);
	
	Properties.Insert("NumberOfChildHeaders", 0);
	Properties.Insert("NumberOfParentHeaders", 0);
	
	Properties.Insert("SectionOrder", 0);
	Properties.Insert("NumberOfPartitions", 0);
	Properties.Insert("GroupingOrder", 0);
	Properties.Insert("FieldOrder", 0);
	
	Properties.Insert("IDOfTheSettings", Undefined);
	Properties.Insert("SectionID", Undefined);
	Properties.Insert("GroupingID", Undefined);
	Properties.Insert("FieldID", Undefined);
	
	Properties.Insert("Field", Undefined);
	Properties.Insert("TheFieldIsSorted", False);
	Properties.Insert("SortDirection", Undefined);
	
	Properties.Insert("Period", False);
	Properties.Insert("Dimension", False);
	Properties.Insert("Resource", False);
	Properties.Insert("IsFormula", False);
	
	Properties.Insert("ValueType", Undefined);
	Properties.Insert("FieldType", Undefined);
	
	Properties.Insert("UsedInGroupingFields", False);
	Properties.Insert("GroupType", Undefined);
	
	Properties.Insert("GroupBySelectedField", False);
	
	Properties.Insert("InsertFieldLeft", False);
	Properties.Insert("InsertFieldRight", False);
	Properties.Insert("InsertGroupAbove", False);
	Properties.Insert("InsertGroupBelow", False);
	
	Properties.Insert("MoveFieldLeft", False);
	Properties.Insert("MoveFieldRight", False);
	Properties.Insert("MoveFieldUp", False);
	Properties.Insert("MoveFieldDown", False);
	
	Properties.Insert("SortAsc", True);
	Properties.Insert("SortDesc", True);
	
	Properties.Insert("HideField", False);
	Properties.Insert("RenameField", False);
	
	Properties.Insert("FormatNegativeValues", False);
	Properties.Insert("FormatPositiveValues", False);
	Properties.Insert("ApplyAppearanceMore", False);
	
	Properties.Insert("IndexID", Undefined);
	
	Return Properties;
	
EndFunction

#EndRegion

#Region DataOfTheDecryptionElement

Function DataOfTheDecryptionElement(Form, Details) Export 
	
	If Not ReportsOptionsInternalClientServer.ReportOptionMode(Form.CurrentVariantKey)
		Or Not Form.ReportSettings.EditOptionsAllowed
		Or Not TypeOf(Details) = Type("DataCompositionDetailsID") Then
		
		Return Undefined;
	EndIf; 
	
	Report = Form.Report;
	Document = Form.ReportSpreadsheetDocument;
	DocumentField = Form.Items.ReportSpreadsheetDocument;
	
	SelectedDocumentAreas = DocumentField.GetSelectedAreas();
	
	Data = GetFromTempStorage(Form.ReportDetailsData);
	DetailsItem = Data.Items.Get(Details);
	
	Parents = DetailsItem.GetParents();
	Parent = ?(Parents.Count() = 0, Undefined, Parents[0]);
	
	If TypeOf(DetailsItem) = Type("DataCompositionGroupDetailsItem")
		Or TypeOf(Parent) <> Type("DataCompositionGroupDetailsItem") Then 
	
		TypeOfTheDecryptionElement = ReportsOptionsInternalClientServer.TheTypeOfTheDecryptionElementIsGrouping();
	Else
		TypeOfTheDecryptionElement = TypeOfProps();
	EndIf;
	
	DataOfTheDecryptionElement = New Structure;
	DataOfTheDecryptionElement.Insert("Type", TypeOfTheDecryptionElement);
	DataOfTheDecryptionElement.Insert("Settings", Data.Settings);
	DataOfTheDecryptionElement.Insert("Filter", SelectingTheDecryptionElement(DetailsItem));
	DataOfTheDecryptionElement.Insert("Filters", SelectionsOfSelectedDecryptionElements(Document, SelectedDocumentAreas, Data));
	
	Fields = DetailsItem.GetFields();
	
	If Fields.Count() = 0 Then
		
		DataOfTheDecryptionElement.Insert("Value", Undefined);
		DataOfTheDecryptionElement.Insert("Values", Undefined);
		DataOfTheDecryptionElement.Insert("Field", "");
		
	Else 
		
		FieldProperties = Fields[0];
		
		DataOfTheDecryptionElement.Insert("Value", ?(FieldProperties.Value = Null, Undefined, FieldProperties.Value));
		DataOfTheDecryptionElement.Insert("Values", DataOfTheDecryptionElement.Filters[FieldProperties.Field]);
		DataOfTheDecryptionElement.Insert("Field", FieldProperties.Field);
		
	EndIf;
	
	DataOfTheDecryptionElement.Insert("IsReference", Common.IsReference(TypeOf(DataOfTheDecryptionElement.Value)));
	
	AvailableCompareTypes = New ValueList;
	
	If ValueIsFilled(DataOfTheDecryptionElement.Field) Then
		
		AvailableField = Report.SettingsComposer.Settings.SelectionAvailableFields.FindField(
			New DataCompositionField(DataOfTheDecryptionElement.Field));
		
		If AvailableField = Undefined Then
			
			DataOfTheDecryptionElement.Insert("ValueType", Type("Undefined"));
			DataOfTheDecryptionElement.Insert("Resource", False);
			
		Else
			
			DataOfTheDecryptionElement.Insert("ValueType", AvailableField.ValueType);
			DataOfTheDecryptionElement.Insert("Resource", AvailableField.Resource);
			
			If DataOfTheDecryptionElement.Value = Undefined Then 
				
				Area = DocumentField.CurrentArea;
				
				If TypeOf(Area) = Type("SpreadsheetDocumentRange") Then 
					
					DataOfTheDecryptionElement.Value = AvailableField.ValueType.AdjustValue(Area.Text);
					DataOfTheDecryptionElement.Values = TheGivenValuesOfTheSelectedAreas(
						Document, SelectedDocumentAreas, AvailableField.ValueType);
					
				EndIf;
				
			EndIf;
			
		EndIf; 
		
		TheAvailableFieldSelection = Report.SettingsComposer.Settings.FilterAvailableFields.FindField(
			New DataCompositionField(DataOfTheDecryptionElement.Field));
		
		If TheAvailableFieldSelection <> Undefined Then 
			AvailableCompareTypes = TheAvailableFieldSelection.AvailableCompareTypes;
		EndIf;
		
	Else
		
		DataOfTheDecryptionElement.Insert("ValueType", Type("Undefined"));
		DataOfTheDecryptionElement.Insert("Resource", False);
		
	EndIf; 
	
	If AvailableCompareTypes.Count() = 0 Then 
		
		For Each Kind In DataCompositionComparisonType Do 
			AvailableCompareTypes.Add(Kind);
		EndDo;
		
	EndIf;
	
	If AvailableCompareTypes.FindByValue("DisableFilter") = Undefined Then 
		AvailableCompareTypes.Insert(0, "DisableFilter", NStr("en = 'Clear filter';"));
	EndIf;
	
	If AvailableCompareTypes.FindByValue("FilterMore") = Undefined Then 
		AvailableCompareTypes.Add("FilterMore", NStr("en = 'More…';"));
	EndIf;
	
	DataOfTheDecryptionElement.Insert("AvailableCompareTypes", AvailableCompareTypes);
	
	Return DataOfTheDecryptionElement;
	
EndFunction

Function SelectingTheDecryptionElement(DetailsItem, Result = Undefined)
	
	If Result = Undefined Then
		Result = New Map;
	EndIf; 
	
	If TypeOf(DetailsItem) = Type("DataCompositionFieldDetailsItem") Then
		
		Fields = DetailsItem.GetFields();
		
		For Each Field In Fields Do
			
			If Field.Value = Null Then
				Continue;
			EndIf;
			
			Value = Result[Field.Field];
			
			If Value = Undefined Then 
				
				Result.Insert(Field.Field, Field.Value);
				Continue;
				
			EndIf;
			
			Values = ReportsClientServer.ValuesByList(Value);
			
			If Values.FindByValue(Field.Value) = Undefined Then 
				Values.Add(Field.Value);
			EndIf;
			
			Result.Insert(Field.Field, Values);
			
		EndDo; 
	EndIf;
	
	Parents = DetailsItem.GetParents();
	
	For Each Parent In Parents Do
		SelectingTheDecryptionElement(Parent, Result);
	EndDo;
	
	Return Result;
	
EndFunction

Function SelectionsOfSelectedDecryptionElements(Document, SelectedDocumentAreas, Data)
	
	Result = New Map;
	
	For Each SelectedArea1 In SelectedDocumentAreas Do
		
		If TypeOf(SelectedArea1) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For LineNumber = SelectedArea1.Top To SelectedArea1.Bottom Do 
			
			Area = Document.Area(LineNumber, SelectedArea1.Left, LineNumber, SelectedArea1.Right);
			
			If Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle
				And TypeOf(Area.Details) = Type("DataCompositionDetailsID") Then 
				
				DetailsItem = Data.Items.Get(Area.Details);
				SelectingTheDecryptionElement(DetailsItem, Result);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function TheGivenValuesOfTheSelectedAreas(Document, SelectedDocumentAreas, ValueType)
	
	Result = New ValueList;
	
	For Each SelectedArea1 In SelectedDocumentAreas Do
		
		If TypeOf(SelectedArea1) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For LineNumber = SelectedArea1.Top To SelectedArea1.Bottom Do 
			
			Area = Document.Area(LineNumber, SelectedArea1.Left, LineNumber, SelectedArea1.Right);
			
			If Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle Then 
				
				Value = ValueType.AdjustValue(Area.Text);
				
				If Result.FindByValue(Value) = Undefined Then 
					Result.Add(Value);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function TypeOfProps()
	
	Return "Attribute";	
	
EndFunction

#EndRegion

#Region CellValue

// Parameters:
//  FillParameters - Structure:
//    * Values - ValueList
//    * TitleProperties - See StandardReportHeaderProperties
//    * Document - SpreadsheetDocument
//    * Headers - Map
//    * PartitionBoundary - See ReportSectionBoundaries
//    * DetailsData - DataCompositionDetailsData
//    * FirstLinesToReadCount - Number
//    * AllReportSectionValuesDisplayed - Boolean
//    * AvailableValues - ValueList
//
// Returns:
//  Structure:
//    * Values - ValueList
//    * LinesInReportSectionCount - Number
//    * AllReportSectionValuesDisplayed - Boolean
//
Function FillInTheFilterValues(FillParameters) Export 
	
	Values = FillParameters.Values;
	TitleProperties = FillParameters.TitleProperties;
	Document = FillParameters.Document;
	Headers = FillParameters.Headers;
	PartitionBoundary = FillParameters.PartitionBoundary;
	DetailsData = FillParameters.DetailsData;
	FirstLinesToReadCount = FillParameters.FirstLinesToReadCount;
	AllReportSectionValuesDisplayed = FillParameters.AllReportSectionValuesDisplayed;
	AvailableValues = FillParameters.AvailableValues;
	
	AvailableTypes = Values.ValueType;
	IndexOfCellValues = New Map;
	
	NumberOfLinesRead = 0;
	LinesInReportSectionCount = PartitionBoundary - TitleProperties.Bottom;
	
	If AllReportSectionValuesDisplayed Then 
		NumberOfLinesToRead = LinesInReportSectionCount;
	Else
		NumberOfLinesToRead = Min(FirstLinesToReadCount + TitleProperties.Bottom, LinesInReportSectionCount);
	EndIf;
	
	For LineNumber = TitleProperties.Bottom + 1 To Document.TableHeight Do 
		
		NumberOfLinesRead = NumberOfLinesRead + 1;
		
		If NumberOfLinesRead > NumberOfLinesToRead Then 
			Break;
		EndIf;
		
		Cell = Document.Area(LineNumber, TitleProperties.Left);
		
		If Headers[Cell.Name] <> Undefined
			Or Cell.AreaType <> SpreadsheetDocumentCellAreaType.Rectangle
			Or Not ValueIsFilled(Cell.Text) Then 
			
			Continue;
		EndIf;
		
		CellValue = CellValue(Cell, AvailableTypes, DetailsData);
		
		If Not TheCellValueIsConsistent(CellValue, IndexOfCellValues, AvailableTypes) Then 
			Continue;
		EndIf;
		
		AvailableValue = AvailableValues.FindByValue(CellValue.Value);
		
		If AvailableValue = Undefined Then 
			
			FillPropertyValues(Values.Add(), CellValue);
			
		Else
			
			AvailableValue.Check = True;
			FillPropertyValues(Values.Add(), AvailableValue);
			
		EndIf;
		
	EndDo;
	
	AllReportSectionValuesDisplayed = (NumberOfLinesToRead = LinesInReportSectionCount);
	
	FillingResult = New Structure;
	FillingResult.Insert("Values", Values);
	FillingResult.Insert("LinesInReportSectionCount", LinesInReportSectionCount);
	FillingResult.Insert("AllReportSectionValuesDisplayed", AllReportSectionValuesDisplayed);
	
	Return FillingResult;
	
EndFunction

// Parameters:
//  Cell - SpreadsheetDocumentRange
//         - Structure:
//             * Text - String
//             * Details - DataCompositionDetailsID
//                           - Undefined
//  AvailableTypes - TypeDescription
//  DetailsData - DataCompositionDetailsData
//
// Returns:
//   See StandardCellValue
//
Function CellValue(Cell, AvailableTypes, DetailsData) Export 
	
	CellValue = StandardCellValue(Cell.Text);
	
	NumberOfAvailableTypes = AvailableTypes.Types().Count();
	
	If TypeOf(Cell.Details) = Type("DataCompositionDetailsID") Then 
		
		DetailsItem = DetailsData.Items[Cell.Details];
		Fields = DetailsItem.GetFields();
		
		If Fields.Count() > 0 Then 
			
			Value = Fields[0].Value;
			
			If NumberOfAvailableTypes = 0 Then 
				
				CellValue.Value = Value;
				
			ElsIf ValueIsFilled(Value)
				And Not AvailableTypes.ContainsType(TypeOf(Value)) Then 
				
				CellValue.Value = Null;
				
			ElsIf Value = Null Then 
				
				CellValue.Value = AvailableTypes.AdjustValue(Cell.Text);
				
			Else
				
				CellValue.Value = AvailableTypes.AdjustValue(Value);
				
			EndIf;
			
			If CellValue.Value = Undefined Then 
				CellValue.Value = Null;
			EndIf;
			
			Return CellValue;
			
		EndIf;
		
	EndIf;
	
	If CommonClientServer.IsNumber(Cell.Text) Then 
		
		NumberDetails = New TypeDescription("Number");
		CellValue.Value = NumberDetails.AdjustValue(Cell.Text);
		Return CellValue;
		
	EndIf;
	
	Value = CommonClientServer.StringToDate(CellValue.Value);
	
	If ValueIsFilled(Value) Then 
		CellValue.Value = Value;
	Else
		CellValue.Value = AvailableTypes.AdjustValue(Value);
	EndIf;
	
	Return CellValue;
	
EndFunction

Function TheCellValueIsConsistent(CellValue, IndexOfCellValues, AvailableTypes)
	
	If Not ValueIsFilled(CellValue.Value)
		And ValueIsFilled(CellValue.Presentation) Then 
		
		Return False;
	EndIf;
	
	If IndexOfCellValues[CellValue.Value] <> Undefined Then 
		Return False;
	EndIf;
	
	NumberOfAvailableTypes = AvailableTypes.Types().Count();
	
	If NumberOfAvailableTypes > 0
		And Not AvailableTypes.ContainsType(TypeOf(CellValue.Value)) Then 
		
		Return False;
	EndIf;
	
	IndexOfCellValues.Insert(CellValue.Value, True);
	
	Return True;
	
EndFunction

// Parameters:
//  Value - String
//
// Returns:
//   Structure:
//     * Value - String
//     * Presentation - String
//     * Check - Boolean
//
Function StandardCellValue(Value)
	
	CellValue = New Structure;
	CellValue.Insert("Value", Value);
	CellValue.Insert("Presentation", Value);
	CellValue.Insert("Check", True);
	
	Return CellValue;
	
EndFunction

#EndRegion

#Region TranscriptionByDetailedRecords

Procedure PrepareReportSettingsToDecipherByDetailedRecords(Form, OptionSettings, UsedSettings) Export 
	
	ActionProcessingDecoding = CommonClientServer.StructureProperty(
		UsedSettings.AdditionalProperties, "ActionProcessingDecoding");
	
	If Not ValueIsFilled(ActionProcessingDecoding) Then 
		Return;
	EndIf;
	
	TitleProperties = CommonClientServer.StructureProperty(
		UsedSettings.AdditionalProperties, "TitleProperties");
	
	If TypeOf(OptionSettings) = Type("DataCompositionSettings") Then 
		Settings = OptionSettings;
	Else
		Settings = Form.Report.SettingsComposer.Settings;
	EndIf;
	
	DeleteIdleReportSection(Settings, TitleProperties);
	PrepareReportSectionStructureToDecipher(Settings);
	
	OptionSettings = Settings;
	
EndProcedure

Procedure DeleteIdleReportSection(Settings, TitleProperties)
	
	SectionIndex = Settings.Structure.Count() - 1;
	
	While SectionIndex >= 0 Do 
		
		Section = Settings.Structure[SectionIndex];
		
		If Not Section.Use
			Or TypeOf(Section) <> Type("DataCompositionGroup")
			And TypeOf(Section) <> Type("DataCompositionTable") Then 
			
			Settings.Structure.Delete(Section);
		EndIf;
		
		SectionIndex = SectionIndex - 1;
		
	EndDo;
	
	CurrentSectionNumber = TitleProperties.SectionOrder;
	NumberOfPartitions = Settings.Structure.Count();
	Sections_ToDelete = New Array;
	
	For SectionNumber = 1 To NumberOfPartitions Do 
		
		If SectionNumber <> CurrentSectionNumber Then 
			Sections_ToDelete.Add(Settings.Structure[SectionNumber - 1]);
		EndIf;
		
	EndDo;
	
	For Each Section In Sections_ToDelete Do 
		Settings.Structure.Delete(Section);
	EndDo;
	
EndProcedure

Procedure PrepareReportSectionStructureToDecipher(Settings)
	
	If Settings.Structure.Count() <> 1 Then 
		Return;
	EndIf;
	
	StructureItem = Settings.Structure[0];
	Group = Undefined;
	
	If TypeOf(StructureItem) = Type("DataCompositionGroup") Then 
		
		Group = StructureItem;
		
	ElsIf TypeOf(StructureItem) = Type("DataCompositionTable") Then 
		
		If StructureItem.Rows.Count() > 0 Then 
			Group = StructureItem.Rows[0];
		EndIf;
		
	EndIf;
	
	If Group = Undefined Then 
		Return;
	EndIf;
	
	Group.Structure.Clear();
	Group.GroupFields.Items.Clear();
	
EndProcedure

Function DecryptionHandlerSelectionPropertiesByDetailRecords() Export
	
	SelectionItemProperties = New Structure;
	SelectionItemProperties.Insert("Value", Undefined);
	SelectionItemProperties.Insert("ComparisonType", DataCompositionComparisonType.Equal);
	SelectionItemProperties.Insert("ViewMode", DataCompositionSettingsItemViewMode.Inaccessible);
	SelectionItemProperties.Insert("Presentation", "");
	SelectionItemProperties.Insert("UserSettingID", "");
	
	Return SelectionItemProperties;
	
EndFunction

#EndRegion

#EndRegion
