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

// Parameters:
//  Form - ClientApplicationForm
//  Item - FormField
//          - FormFieldExtensionForASpreadsheetDocumentField
//  Area - SpreadsheetDocumentRange
//
Procedure ShowTheContextSettingOfTheReport(Form, Item, Area, StandardProcessing) Export 
	
	If TypeOf(Area) <> Type("SpreadsheetDocumentRange")
		Or Area.AreaType <> SpreadsheetDocumentCellAreaType.Rectangle
		Or Area.Details <> Undefined
		And TypeOf(Area.Details) <> Type("DataCompositionDetailsID") Then
		
		Return;
	EndIf;
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	
	Headers = ResultProperties.Headers;
	
	Area = Item.CurrentArea; // SpreadsheetDocumentRange
	TitleProperties = Headers[Area.Name]; // 
	
	If TypeOf(TitleProperties) <> Type("Structure")
		Or TypeOf(TitleProperties.Field) <> Type("DataCompositionField")
		Or TitleProperties.ValueType.Types().Count() = 0 
		Or TitleProperties.SectionOrder <> 1 Then 
		
		Return;
	EndIf;
	
	SettingsComposer = ReportSettingsBuilder(Form);
	
	FiltersValuesCache = CommonClientServer.StructureProperty(
		SettingsComposer.UserSettings.AdditionalProperties, "FiltersValuesCache", New Map);
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", SettingsComposer);
	FormParameters.Insert("DetailsData", Form.ReportDetailsData);
	FormParameters.Insert("Document", Form.ReportSpreadsheetDocument);
	FormParameters.Insert("Headers", Headers);
	FormParameters.Insert("TitleProperties", TitleProperties);
	FormParameters.Insert("FiltersValuesCache", FiltersValuesCache);
	
	OpenForm(
		"SettingsStorage.ReportsVariantsStorage.Form.FieldSetup",
		FormParameters,
		Form,
		Form.UUID);
	
	StandardProcessing = False
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  Item - FormField
//          - FormFieldExtensionForASpreadsheetDocumentField
//  Details - DataCompositionID
//  StandardProcessing - Boolean
//
Procedure DetailProcessing(Form, Item, Details, StandardProcessing) Export 
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	CurrentArea = Item.CurrentArea; // SpreadsheetDocumentRange
	
	Headers = ResultProperties.Headers[CurrentArea.Name];
	
	If TypeOf(Headers) = Type("Structure") Then 
		
		StandardProcessing = False;
		Form.Items.HeadingAreaContextMenu.Visible = True;
		
	EndIf;
	
EndProcedure

Procedure AdditionalDetailProcessing(Form, Data, Item, Details, StandardProcessing) Export 
	
	If Data = Undefined Then
		Return;
	EndIf;
	
	AreaProperties = PropertiesOfTheDecryptionArea(Form, Item.CurrentArea, Data.Field);
	
	If TypeOf(AreaProperties) <> Type("Structure")
		Or TypeOf(AreaProperties.TitleProperties) <> Type("Structure") Then 
		
		Return;
	EndIf;
	
	MainMenu = New Array;
	
	If AreaProperties.ThisIsTheTitle Then 
		
		TitleProperties = AreaProperties.TitleProperties;
		
		If TypeOf(TitleProperties.Field) <> Type("DataCompositionField")
			Or TitleProperties.ValueType.Types().Count() = 0 Then 
			
			Return;
		EndIf;
		
		AdditionalMenu = HeadingAreaContextMenu();
	Else
		MainMenu.Add(DataCompositionDetailsProcessingAction.DrillDown);
		AdditionalMenu = DataAreaContextMenu(AreaProperties.TitleProperties, Data.AvailableCompareTypes);
	EndIf;
	
	DetailProcessing = New DataCompositionDetailsProcess(
		Form.ReportDetailsData, New DataCompositionAvailableSettingsSource(Form.ReportSettings.SchemaURL));
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("Data", Data);
	AdditionalParameters.Insert("Details", Details);
	AdditionalParameters.Insert("DetailProcessing", DetailProcessing);
	AdditionalParameters.Insert("AreaProperties", AreaProperties);
	AdditionalParameters.Insert("Menu", AdditionalMenu);
	
	ReportField = Form.Items.ReportSpreadsheetDocument; // SpreadsheetDocumentField
	
	Handler = New NotifyDescription("ExecuteDecryption", ThisObject, AdditionalParameters);
	DetailProcessing.ShowActionChoice(Handler, Details, MainMenu, AdditionalMenu,, ReportField);
	
	StandardProcessing = False;
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  Item - FormField
//          - FormFieldExtensionForASpreadsheetDocumentField
//
Procedure WhenActivatingTheReportResult(Form, Item) Export 
	
	Area = Item.CurrentArea; // SpreadsheetDocumentRange
	
	If TypeOf(Area) <> Type("SpreadsheetDocumentRange") Then 
		Return;
	EndIf;
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult 
	Items = Form.Items;
	ReportField = Items.ReportSpreadsheetDocument; // FormField, FormFieldExtensionForASpreadsheetDocumentField
	
	TitleProperties = ResultProperties.Headers[Area.Name];
	ThisIsTheTranscript = Area.AreaType = SpreadsheetDocumentCellAreaType.Rectangle
		And TypeOf(Area.Details) = Type("DataCompositionDetailsID");
	
	Items.HeadingAreaContextMenu.Visible = (TypeOf(TitleProperties) = Type("Structure"))
		And TypeOf(TitleProperties.Field) = Type("DataCompositionField") And TitleProperties.SectionOrder = 1;
	
	Items.DataAreaContextMenu.Visible = Not Items.HeadingAreaContextMenu.Visible
		And ThisIsTheTranscript;
	
	Items.GroupsLevelsGroupContextMenu.Visible = Not ThisIsTheTranscript;
	Items.AreaContextMenuCommonEdit.Visible = Not ThisIsTheTranscript;
	
	Items.DataAreaContextMenuPasteFromClipboard.Enabled = ReportField.Edit;
	Items.AreaContextMenuCommonPasteFromClipboard.Enabled = ReportField.Edit;
	
	ReportsOptionsInternalClientServer.DetermineTheAvailabilityOfContextMenuActions(Form, TitleProperties);
	
	If Items.HeadingAreaContextMenu.Visible Then 
		
		ButtonTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Group by the %1 field';"), TitleProperties.Text);
		
		CommonClientServer.SetFormItemProperty(
			Items, "HeadingAreaContextMenuGroupBySelectedField", "Title", ButtonTitle);
		
	EndIf;
	
EndProcedure

Function ThisIsAContextSettingEvent(Event) Export 
	
	If TypeOf(Event) <> Type("Structure") Or Not Event.Property("Action") Then
		Return False;
	EndIf;

	Events = ContextConfigurationEvents();
	Return Events[Event.Action] = True;
	
EndFunction

#Region HandlersCommandsOnTheContextMenuOfTheTableOfTheDocumentIsTheResultOfTheReport

#Region InsertingAFieldOrGrouping

Procedure GroupBySelectedField(Form, Command) Export 
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	
	SelectedField = Settings.GroupAvailableFields.FindField(TitleProperties.Field);
	If SelectedField = Undefined Then 
		Return;
	EndIf;
	
	Section = Settings.GetObjectByID(TitleProperties.SectionID);
	Section2 = Settings2.GetObjectByID(TitleProperties.SectionID);
	
	If TypeOf(Section) = Type("DataCompositionTable") Then 
		Groups = Section.Rows;
		Groups2 = Section2.Rows;
	Else
		Groups = Section.Parent.Structure;
		Groups2 = Section2.Parent.Structure;
	EndIf;
	
	MovableGroupings = New Array;
	
	For Each Item In Groups Do 
		MovableGroupings.Add(Item);
	EndDo;
	
	DetailedRecords = DetailedRecords(Groups2);
	
	If TypeOf(Groups) = Type("DataCompositionSettingStructureItemCollection") Then 
		NewGrouping = Groups.Insert(0, Type("DataCompositionGroup")); // DataCompositionGroup
	Else
		NewGrouping = Groups.Insert(0);
	EndIf;
	
	NewField = NewGrouping.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewField.Field = SelectedField.Field;
	NewField.Use = True;
	
	NewGrouping.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	NewGrouping.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	If DetailedRecords <> Undefined Then 
		
		SearchForItems = New Map;
		ReportsClientServer.CopyRecursive(
			Settings, DetailedRecords, NewGrouping.Structure, 0, SearchForItems);
		
	EndIf;
	
	For Each Group In MovableGroupings Do 
		Groups.Delete(Group);
	EndDo;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Procedure InsertFieldLeft(Form, Command) Export 
	
	SelectAReportFieldFromTheMenu(Form, Command);
	
EndProcedure

Procedure InsertFieldRight(Form, Command) Export 
	
	SelectAReportFieldFromTheMenu(Form, Command);
	
EndProcedure

Procedure InsertGroupAbove(Form, Command) Export 
	
	SelectAReportFieldFromTheMenu(Form, Command);
	
EndProcedure

Procedure InsertGroupBelow(Form, Command) Export 
	
	SelectAReportFieldFromTheMenu(Form, Command);
	
EndProcedure

#EndRegion

#Region MovingAField

Procedure MoveFieldLeft(Form, Command) Export 
	
	MoveTheFieldHorizontally(Form, Command);
	
EndProcedure

Procedure MoveFieldRight(Form, Command) Export 
	
	MoveTheFieldHorizontally(Form, Command);
	
EndProcedure

Procedure MoveFieldUp(Form, Command) Export 
	
	MoveTheFieldVertically(Form, Command);
	
EndProcedure

Procedure MoveFieldDown(Form, Command) Export 
	
	MoveTheFieldVertically(Form, Command);
	
EndProcedure

#EndRegion

#Region Appearance

Procedure ClearAppearance(Form, TitleProperties) Export 
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		ClearTheLayoutOfTheReportGrouping(Group.Settings, TitleProperties);
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		ClearTheLayoutOfTheReportGrouping(Settings, TitleProperties);
	Else
		Section = Settings.GetObjectByID(TitleProperties.SectionID);
		If TypeOf(Section) = Type("DataCompositionTable") Then 
			ClearTheLayoutOfTheReportSectionGroupings(Section.Rows, TitleProperties);
		Else
			ClearTheLayoutOfTheReportSectionGrouping(Section, TitleProperties);
		EndIf;
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, "ClearAppearance", TitleProperties.Text);
	
EndProcedure

Procedure HighlightInRed(Form, Command, TitleProperties = Undefined, Value = Undefined) Export 
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	CommandAction = CommandAction(Command);
	
	ColoringOptions = ReportSectionColoringOptions(CommandAction);
	ColoringOptions.Condition.LeftValue = TitleProperties.Field;
	
	If CommandAction = "FormatNegativeValues" Then 
		
		If Not ActionOnTheFieldIsAvailable(CommandAction, TitleProperties) Then 
			Return;
		EndIf;
		
		ColoringOptions.Condition.ComparisonType = DataCompositionComparisonType.Less;
		ColoringOptions.Condition.RightValue = 0;
		
		ColoringOptions.Presentation = NStr("en = 'Make negative values red';");
		
	Else
		
		ColoringOptions.Condition.ComparisonType = TypeOfComparisonTermsOfRegistration(Value);
		ColoringOptions.Condition.RightValue = Value;
		
		ColoringOptions.Presentation = NStr("en = 'Highlight in red';");
		
	EndIf;
	
	StyleItems = StandardSubsystemsClient.StyleItems();
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "TextColor";
	Appearance.Value = StyleItems.NegativeValueTextColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "BackColor";
	Appearance.Value = StyleItems.NegativeValueBackColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	
	ColorizeTheReportSection(Form, ColoringOptions, TitleProperties);
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction, TitleProperties.Text);
	
EndProcedure

Procedure HighlightInGreen(Form, Command, TitleProperties = Undefined, Value = Undefined) Export 
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	CommandAction = CommandAction(Command);
	
	ColoringOptions = ReportSectionColoringOptions(CommandAction);
	ColoringOptions.Condition.LeftValue = TitleProperties.Field;
	
	If CommandAction = "FormatPositiveValues" Then 
		
		If Not ActionOnTheFieldIsAvailable(CommandAction, TitleProperties) Then 
			Return;
		EndIf;
		
		ColoringOptions.Condition.ComparisonType = DataCompositionComparisonType.Greater;
		ColoringOptions.Condition.RightValue = 0;
		
		ColoringOptions.Presentation = NStr("en = 'Make positive values green';");
		
	Else
		
		ColoringOptions.Condition.ComparisonType = TypeOfComparisonTermsOfRegistration(Value);
		ColoringOptions.Condition.RightValue = Value;
		
		ColoringOptions.Presentation = NStr("en = 'Highlight in green';");
		
	EndIf;
	
	StyleItems = StandardSubsystemsClient.StyleItems();
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "TextColor";
	Appearance.Value = StyleItems.PositiveValueTextColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "BackColor";
	Appearance.Value = StyleItems.PositiveValueBackColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	
	ColorizeTheReportSection(Form, ColoringOptions, TitleProperties);
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction, TitleProperties.Text);
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  Command - FormCommand
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//  RowHeight - Number
//               - Undefined
//  LineHeightParameters - See ReportsOptionsInternal.StandardReportHeaderProperties 
//
Procedure SetRowHeight(Form, Command, TitleProperties = Undefined,
	RowHeight = Undefined, LineHeightParameters = Undefined) Export 
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	If RowHeight = Undefined Then 
		
		LineHeightParameters = ReportFieldSizeParameters(Form, TitleProperties);
		
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Form", Form);
		HandlerParameters.Insert("Command", Command);
		HandlerParameters.Insert("TitleProperties", TitleProperties);
		HandlerParameters.Insert("FieldSizeParameters", LineHeightParameters);
		
		Handler = New NotifyDescription("AfterEnteringTheReportLineHeight", ThisObject, HandlerParameters);
		ShowInputNumber(Handler, LineHeightParameters.Size, NStr("en = 'Row height';"), 5);
		
		Return;
		
	EndIf;
	
	If LineHeightParameters = Undefined
		Or LineHeightParameters.Item = Undefined Then 
		
		AddReportFieldSizeParameters(Form, TitleProperties, RowHeight);
	Else
		UpdateSizeSettings(LineHeightParameters, RowHeight);
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  Command - FormCommand
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//  ColumnWidth - Number
//                - Undefined
//  ColumnWidthParameters - See ReportsOptionsInternal.StandardReportHeaderProperties 
//
Procedure SetColumnWidth(Form, Command, TitleProperties = Undefined,
	ColumnWidth = Undefined, ColumnWidthParameters = Undefined) Export 
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	ColumnWidthParameters = ReportFieldSizeParameters(Form, TitleProperties, "Width");
	
	If ColumnWidth = Undefined Then 
		
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Form", Form);
		HandlerParameters.Insert("Command", Command);
		HandlerParameters.Insert("TitleProperties", TitleProperties);
		HandlerParameters.Insert("FieldSizeParameters", ColumnWidthParameters);
		
		Handler = New NotifyDescription("AfterEnteringTheWidthOfTheReportColumn", ThisObject, HandlerParameters);
		ShowInputNumber(Handler, ColumnWidthParameters.Size, NStr("en = 'Column width';"), 5);
		
		Return;
		
	EndIf;
	
	If ColumnWidthParameters = Undefined
		Or ColumnWidthParameters.Item = Undefined Then 
		
		AddReportFieldSizeParameters(Form, TitleProperties, ColumnWidth, "Width");
	Else
		UpdateSizeSettings(ColumnWidthParameters, ColumnWidth);
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Procedure ApplyAppearanceMore(Form, Command, TitleProperties = Undefined, Value = Undefined) Export 
	
	If Not TheActionIsAvailable(Form,, TitleProperties) Then 
		Return;
	EndIf;
	
	SettingsUsed = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Group = SettingsUsed.GetObjectByID(TitleProperties.GroupingID);
	
	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		GroupingID = SettingsUsed.GetIDByObject(Group);
		DesignID = IDOfTheReportGroupingDesignElement(Group.Settings, TitleProperties.Field);
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		GroupingID = Undefined;
		DesignID = IDOfTheReportGroupingDesignElement(SettingsUsed, TitleProperties.Field);
	Else
		GroupingID = SettingsUsed.GetIDByObject(Group);
		DesignID = IDOfTheReportGroupingDesignElement(Group, TitleProperties.Field);
	EndIf;
	
	SettingsComposer = ReportSettingsBuilder(Form);
	
	DesignParameters = New Structure;
	DesignParameters.Insert("SettingsComposer", SettingsComposer);
	DesignParameters.Insert("ReportSettings", Form.ReportSettings);
	DesignParameters.Insert("SettingsStructureItemID", GroupingID);
	DesignParameters.Insert("DCID", DesignID);
	DesignParameters.Insert("Description", "");
	DesignParameters.Insert("Field", TitleProperties.Field);
	DesignParameters.Insert("Condition", ConditionForFormattingAReportGrouping(TitleProperties.Field, Value));
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Form", Form);
	HandlerParameters.Insert("CommandAction", CommandAction(Command));
	HandlerParameters.Insert("TitleProperties", TitleProperties);
	
	Handler = New NotifyDescription("AfterChangingTheLayoutElementOfTheReportGrouping", ThisObject, HandlerParameters);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ConditionalReportAppearanceItem",
		DesignParameters, Form, Form.UUID,,, Handler);
	
EndProcedure

#EndRegion

#Region Filtering

Procedure ShowAdvancedFilterSetting(Form, TitleProperties) Export 
	
	If Not TheActionIsAvailable(Form,, TitleProperties) Then 
		Return;
	EndIf;
	
	ReportSettings = Form.ReportSettings;
	
	Field = Form.Items.ReportSpreadsheetDocument; // SpreadsheetDocumentField
	CurrentArea = Field.CurrentArea;
	
	Cell = New Structure("Text, Details", "");
	
	If CurrentArea.Top <> TitleProperties.Top
		Or CurrentArea.Bottom <> TitleProperties.Bottom
		Or CurrentArea.Left <> TitleProperties.Left
		Or CurrentArea.Right <> TitleProperties.Right Then 
			
		FillPropertyValues(Cell, CurrentArea);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentVariantKey", Form.CurrentVariantKey);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", ReportSettingsBuilder(Form));
	FormParameters.Insert("TitleProperties", TitleProperties);
	FormParameters.Insert("DetailsData", Form.ReportDetailsData);
	FormParameters.Insert("Cell", Cell);
	
	OpenForm(
		"SettingsStorage.ReportsVariantsStorage.Form.FilterByField",
		FormParameters,
		Form,
		Form.UUID);
	
EndProcedure

Procedure DisableFilter(Form, TitleProperties, DetailsData = Undefined) Export 
	
	ThisIsAGrouping = (DetailsData <> Undefined
		And DetailsData.Type = ReportsOptionsInternalClientServer.TheTypeOfTheDecryptionElementIsGrouping());
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	
	DisplayFilters = ReportsOptionsInternalClientServer.ReportSectionFilters(Settings, TitleProperties, ThisIsAGrouping);
	Filter = ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field,, True);
	
	If Filter = Undefined Then 
		
		DisplayFilters = ReportsOptionsInternalClientServer.ReportSectionFilters(Settings, TitleProperties, Not ThisIsAGrouping);
		Filter = ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field,, True);
		
	EndIf;
	
	If Filter = Undefined Then 
		
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No filters by the ""%1"" field';"), TitleProperties.Text);
		
		ShowMessageBox(, WarningText);
		Return;
		
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, "DisableFilter", TitleProperties.Text);
	
EndProcedure

#EndRegion

#Region OtherActions

Procedure HideField(Form, Command) Export 
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	
	If TitleProperties.IDOfTheSettings = Undefined Then 
		Return;
	EndIf;
	
	SettingsComposer2 = ReportSettingsBuilder(Form, True);
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Section = Settings.GetObjectByID(TitleProperties.SectionID);
	Section2 = Settings2.GetObjectByID(TitleProperties.SectionID);
	
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);
	FieldDetails = DescriptionOfTheReportField(SettingsComposer2, TitleProperties.Field);
	
	ThisIsAGroupingOfDetailedRecords = ThisIsAGroupingOfDetailedRecords(Group2);
	
	If FieldDetails <> Undefined
		And FieldDetails.Resource Then 
		
		HideTheSelectedSectionField(Section, Section2, TitleProperties.Field);
	Else
		HideTheSelectedGroupingField(Group, Group2, TitleProperties.Field);
		
		If Not ThisIsAGroupingOfDetailedRecords Then 
			HideAGrouping(Settings, Group, Settings2, Group2, TitleProperties.Field);
		EndIf;
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Procedure RenameField(Form, Command, Title = "") Export 
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	
	SettingsComposer2 = ReportSettingsBuilder(Form, True);
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);
	
	FieldDetails = DescriptionOfTheReportField(SettingsComposer2, TitleProperties.Field);
	
	ReportField = ReportField(Group, Group2, TitleProperties.Field, "Selection").Field;
	
	If Not ValueIsFilled(Title) Then 
		
		HandlerParameters = New Structure("Form, Command", Form, Command);
		Handler = New NotifyDescription("AfterEnteringTheReportFieldTitle", ThisObject, HandlerParameters);
		
		CurrentTitle = CurrentReportFieldTitle(ReportField, FieldDetails);
		
		DialogTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Field header: %1';"),
			?(FieldDetails = Undefined, String(ReportField), FieldDetails.Title));
		
		ShowInputString(Handler, CurrentTitle, DialogTitle);
		
		Return;
		
	EndIf;
	
	If ReportField <> Undefined Then 
		SetTheReportFieldTitle(Settings, ReportField, FieldDetails, Title);
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Procedure Sort(Form, Command, TitleProperties = Undefined) Export 
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	If Not TheSortTypeOfTheSectionIsAvailable(Command, TitleProperties) Then 
		Return;
	EndIf;
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	ResetSorting(Settings, TitleProperties);
	
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		SortingElements = Group.Settings.Order.Items;
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		SortingElements = Settings.Order.Items;
	Else
		Section = Settings.GetObjectByID(TitleProperties.SectionID);
		If TypeOf(Section) = Type("DataCompositionTable") And Section.Rows.Count() = 1 Then 
			MainGrouping = Section.Rows[0];
			GroupingField = ReportsOptionsInternalClientServer.ReportField(MainGrouping.GroupFields, TitleProperties.Field);
			If TitleProperties.Resource Or GroupingField <> Undefined Then 
				Group = MainGrouping;
			EndIf;
		EndIf;
		SortingElements = Group.Order.Items;
	EndIf;
	
	SortingElement = SectionSortElement(SortingElements, TitleProperties.Field);
	
	If SortingElement = Undefined Then 
		
		IndexOf = IndexSectionSortElement(SortingElements, TitleProperties.Field);
		SortingElement = SortingElements.Insert(IndexOf, Type("DataCompositionOrderItem"));
		SortingElement.Field = TitleProperties.Field;
		
	EndIf;
	
	SortingElement.OrderType = TypeOfSectionSorting(Command);
	SortingElement.Use = True;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command));
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region InsertingAField

Procedure InsertAField(Settings, Settings2, SelectedField, Action, TitleProperties, FieldRoles)
	
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);
	
	InsertAFieldInTheGroupingFields(Group, Group2, SelectedField, TitleProperties.Field, Action, FieldRoles);
	InsertAFieldInASectionGrouping(Group, Group2, SelectedField, TitleProperties.Field, Action, FieldRoles);
	
EndProcedure

Procedure InsertAFieldInTheGroupingFields(Group, Group2, SelectedField, CurrentField, Action, FieldRoles)
	
	If SelectedField.Resource Then 
		Return;
	EndIf;
	
	Fields2 = Group2.GroupFields;
	FoundTheCurrentField2 = ReportsOptionsInternalClientServer.ReportField(Fields2, CurrentField);
	
	If FoundTheCurrentField2 = Undefined Then 
		Return;
	EndIf;
	
	TheCurrentFieldIsAPeriod = (FieldRoles.TimeIntervals_[CurrentField] <> Undefined);
	TheSelectedFieldIsAPeriod = (FieldRoles.TimeIntervals_[SelectedField.Field] <> Undefined);
	
	If TheCurrentFieldIsAPeriod And Not TheSelectedFieldIsAPeriod
		Or Not TheCurrentFieldIsAPeriod And TheSelectedFieldIsAPeriod Then 
		
		Return;
	EndIf;
	
	MakeCopyOfFields(Group, Group2, "GroupFields");
	Fields = Group.GroupFields;
	
	FoundTheCurrentField = ReportsOptionsInternalClientServer.ReportField(Fields, CurrentField);
	
	FieldIndex = Fields.Items.IndexOf(FoundTheCurrentField);
	
	If Action = "InsertFieldRight" Then 
		FieldIndex = FieldIndex + 1;
	EndIf;
	
	FoundField = ReportsOptionsInternalClientServer.ReportField(Fields, SelectedField.Field);
	FieldToInsert = Undefined;
	
	If FoundField <> Undefined Then 
		
		If Fields.Items.IndexOf(FoundField) = FieldIndex Then 
			
			FieldToInsert = FoundField;
			FieldToInsert.Use = True;
			
		Else
			Fields.Items.Delete(FoundField);
		EndIf;
		
	EndIf;
	
	If FieldToInsert <> Undefined Then 
		Return;
	EndIf;
	
	FieldToInsert = Fields.Items.Insert(FieldIndex, Type("DataCompositionGroupField"));
	FillPropertyValues(FieldToInsert, SelectedField);
	
EndProcedure

Procedure InsertAFieldInASectionGrouping(Group, Group2, SelectedField, CurrentField, Action, FieldRoles)
	
	If TypeOf(Group) <> Type("DataCompositionGroup")
		And TypeOf(Group) <> Type("DataCompositionTableGroup") Then 
		
		Return;
	EndIf;
	
	MakeCopyOfFields(Group, Group2, "Selection");
	Fields = Group.Selection;
	FoundTheCurrentField = ReportsOptionsInternalClientServer.ReportField(Fields, CurrentField);
	
	If FoundTheCurrentField = Undefined Then 
		
		FieldIndex = 0;
		
	Else
		
		FieldIndex = Fields.Items.IndexOf(FoundTheCurrentField);
		
		If FieldIndex = -1 And FoundTheCurrentField.Parent <> Undefined Then
			FieldIndex = Fields.Items.IndexOf(FoundTheCurrentField.Parent);
		EndIf;
		
		If Action = "InsertFieldRight" Then 
			FieldIndex = FieldIndex + 1;
		EndIf;
		
	EndIf;
	
	FoundField = ReportsOptionsInternalClientServer.ReportField(Fields, SelectedField.Field, False);
	FieldToInsert = Undefined;
	FieldTitle = SelectedField.Title;
	
	If FoundField <> Undefined Then 
		
		If Fields.Items.IndexOf(FoundField) = FieldIndex Then 
			
			FieldToInsert = FoundField;
			FieldToInsert.Use = True;
			
		Else
			
			FieldTitle = FoundField.Title;
			Fields.Items.Delete(FoundField);
			FieldIndex = FieldIndex - 1;
			
		EndIf;
		
	EndIf;
	
	If FieldToInsert = Undefined Then 
		
		FieldToInsert = Fields.Items.Insert(FieldIndex, Type("DataCompositionSelectedField"));
		FillPropertyValues(FieldToInsert, SelectedField);
		FieldToInsert.Title = FieldTitle;
		
	EndIf;
	
	SetTheOutputOfTheGroupingDetailsSeparately(Group);
	
	InsertAFieldInTheGroupingSection(Group, Group2, SelectedField, CurrentField, Action, FieldRoles);
	
EndProcedure

Procedure InsertAFieldInTheGroupingSection(Parent, Parent2, SelectedField, CurrentField, Action, FieldRoles)
	
	If Not SelectedField.Resource Then 
		Return;
	EndIf;
	
	If TypeOf(Parent) = Type("DataCompositionTable") Then 
		Groups = Parent.Rows;
		Groups2 = Parent2.Rows;
	Else
		Groups = Parent.Structure;
		Groups2 = Parent2.Structure;
	EndIf;
	
	For DimensionNumber_ = 1 To Groups.Count() Do 
		Group = Groups[DimensionNumber_ - 1];
		Group2 = Groups2[DimensionNumber_ - 1];
		InsertAFieldInASectionGrouping(Group, Group2, SelectedField, CurrentField, Action, FieldRoles);
	EndDo;
	
EndProcedure

Procedure SetTheOutputOfTheGroupingDetailsSeparately(Group)
	
	If TypeOf(Group) <> Type("DataCompositionGroup")
		And Not TypeOf(Group) <> Type("DataCompositionTableGroup") Then 
		
		Return;
	EndIf;
	
	WithdrawalOfBankDetails = Group.OutputParameters.Items.Find("AttributePlacement");
	
	If Not WithdrawalOfBankDetails.Use Then 
		
		WithdrawalOfBankDetails.Value = DataCompositionAttributesPlacement.Separately;
		WithdrawalOfBankDetails.Use = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InsertingAGrouping

// Parameters:
//  Action - DataCompositionSettings
//  Actions - String
//  Field - DataCompositionField
//       - DataCompositionAvailableField
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//
Procedure InsertAGrouping(Settings, Action, Field, TitleProperties)
	
	Section = Settings.GetObjectByID(TitleProperties.SectionID);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	
	GroupingCollection = CollectionOfSectionDimensions(
		Section, Group, TitleProperties.GroupingID, Action);
	
	MovableGroupings = New Array;
	
	For Each Item In GroupingCollection.Groups Do 
		MovableGroupings.Add(Item);
	EndDo;
	
	If TypeOf(GroupingCollection.Groups) = Type("DataCompositionSettingStructureItemCollection") Then 
		
		NewGrouping = GroupingCollection.Groups.Insert(
			GroupingCollection.GroupingIndex, Type("DataCompositionGroup")); // DataCompositionGroup
		
	Else
		
		NewGrouping = GroupingCollection.Groups.Insert(GroupingCollection.GroupingIndex);
		
	EndIf;
	
	NewField = NewGrouping.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	NewField.Field = ?(TypeOf(Field) = Type("DataCompositionField"), Field, Field.Field);
	NewField.Use = True;
	
	NewGrouping.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	NewGrouping.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	For Each Group In MovableGroupings Do 
		
		SearchForItems = New Map;
		ReportsClientServer.CopyRecursive(
			Settings, Group, NewGrouping.Structure, GroupingCollection.GroupingIndex, SearchForItems);
		
		GroupingCollection.Groups.Delete(Group);
		
	EndDo;
	
EndProcedure

// Parameters:
//  Section - DataCompositionSettings
//         - DataCompositionNestedObjectSettings
//         - DataCompositionGroup
//         - DataCompositionSettingStructureItemCollection
//         - DataCompositionTable
//         - DataCompositionTableGroup
//         - DataCompositionTableStructureItemCollection
//         - Undefined
//  Group - DataCompositionSettings
//              - DataCompositionNestedObjectSettings
//              - DataCompositionGroup
//              - DataCompositionSettingStructureItemCollection
//              - DataCompositionTable
//              - DataCompositionTableGroup
//              - DataCompositionTableStructureItemCollection
//              - Undefined
//  GroupingID - DataCompositionID
//  Action - String
//
// Returns:
//  Structure:
//    * GroupingIndex - Number
//    * Groups - DataCompositionSettingStructureItemCollection
//                  - DataCompositionTableStructureItemCollection
//
Function CollectionOfSectionDimensions(Section, Group, GroupingID, Action)
	
	Collection = New Structure;
	Collection.Insert("Groups", Undefined);
	Collection.Insert("GroupingIndex", 0);
	
	If Action = "InsertGroupBelow" Then 
		
		Collection.Groups = Group.Structure;
		
		Return Collection;
		
	EndIf;
	
	Parent = Group.Parent; // DataCompositionGroup, DataCompositionTableGroup
	
	If Parent <> Section Then 
		
		Groups = Parent.Structure; // DataCompositionSettingStructureItemCollection, DataCompositionTableStructureItemCollection
		Collection.Groups = Groups;
		Collection.GroupingIndex = Groups.IndexOf(Group);
		
		Return Collection;
		
	EndIf;
	
	If TypeOf(Section) = Type("DataCompositionTable") Then 
		
		Collection.Groups = ?(StrFind(GroupingID, "/row/") > 0, Section.Rows, Section.Columns);
		
	Else
		
		Collection.Groups = Section.Structure;
		
	EndIf;
	
	Groups = Collection.Groups; // DataCompositionSettingStructureItemCollection, DataCompositionTableStructureItemCollection 
	Collection.GroupingIndex = Groups.IndexOf(Group);
	
	Return Collection;
	
EndFunction

#EndRegion

#Region HidingAField

Function ThisIsAGroupingOfDetailedRecords(Group2)
	
	Return Group2.GroupFields.Items.Count() = 0;
	
EndFunction

Procedure HideTheSelectedSectionField(Section, Section2, Field)
	
	SectionDimensions = New Array;
	SectionDimensions2 = New Array;
	
	If TypeOf(Section2) = Type("DataCompositionTable") Then 
		
		SectionDimensions.Add(Section.Rows);
		SectionDimensions.Add(Section.Columns);
		SectionDimensions2.Add(Section2.Rows);
		SectionDimensions2.Add(Section2.Columns);
		
	Else
		
		SectionDimensions.Add(Section.Structure);
		SectionDimensions2.Add(Section2.Structure);
		HideTheSelectedGroupingField(Section, Section2, Field);
		
	EndIf;
	
	For SectionGroupingNumber = 1 To SectionDimensions2.Count() Do
		Groups = SectionDimensions[SectionGroupingNumber - 1];
		Groups2 = SectionDimensions2[SectionGroupingNumber - 1];
		
		For DimensionNumber_ = 1 To Groups2.Count() Do
			Group = Groups[DimensionNumber_ - 1];
			Group2 = Groups2[DimensionNumber_ - 1];
			
			HideTheSelectedGroupingField(Group, Group2, Field);
			HideTheSelectedSectionField(Group, Group2, Field);
		EndDo;
	EndDo;
	
EndProcedure

Procedure HideTheSelectedGroupingField(Group, Group2, Field)
	
	If TypeOf(Group2) <> Type("DataCompositionGroup")
		And TypeOf(Group2) <> Type("DataCompositionTableGroup") Then 
		
		Return;
	EndIf;
	
	FieldFound = False;
	HideSelectedFieldInGroupingCollection(Group, Group2, Field, "GroupFields", True, FieldFound);
	HideSelectedFieldInGroupingCollection(Group, Group2, Field, "Selection", FieldFound);
	HideSelectedFieldInGroupingCollection(Group, Group2, Field, "Order", True);
	
EndProcedure

Procedure HideSelectedFieldInGroupingCollection(Group, Group2, Field, CollectionName,
			ShouldNotCopy = False, FieldFound = False)
	
	ReportField = ReportField(Group, Group2, Field, CollectionName, , ShouldNotCopy);
	If ReportField = Undefined Then
		Return;
	EndIf;
	
	FieldFound = True;
	
	ReportField.Field.Use = False;
	ReportField.Field2.Use = False;
	
EndProcedure

Function ReportField(Group, Group2, Field, CollectionName, FieldTitle = Undefined, ShouldNotCopy = False)
	
	ReportField2 = ReportsOptionsInternalClientServer.ReportField(Group2[CollectionName], Field,, FieldTitle);
	If ReportField2 = Undefined Then
		Return Undefined;
	EndIf;
	
	ReportField = ReportsOptionsInternalClientServer.ReportField(Group[CollectionName], Field,, FieldTitle);
	If ReportField = Undefined Then
		If ShouldNotCopy Then
			Return Undefined;
		EndIf;
		MakeCopyOfFields(Group, Group2, CollectionName);
		ReportField = ReportsOptionsInternalClientServer.ReportField(Group[CollectionName], Field,, FieldTitle);
	EndIf;
	
	Return New Structure("Field, Field2", ReportField, ReportField2);
	
EndFunction

Procedure MakeCopyOfFields(Group, Group2, CollectionName)
	
	GroupItems = ?(ValueIsFilled(CollectionName), Group[CollectionName].Items, Group.Items);
	GroupItems2 = ?(ValueIsFilled(CollectionName), Group2[CollectionName].Items, Group2.Items);
	
	GroupItems.Clear();
	For Each CurrentField2 In GroupItems2 Do
		NewField = GroupItems.Add(TypeOf(CurrentField2));
		FillPropertyValues(NewField, CurrentField2);
		If TypeOf(CurrentField2) = Type("DataCompositionSelectedFieldGroup") Then
			MakeCopyOfFields(NewField, CurrentField2, "");
		EndIf;
	EndDo;
	
EndProcedure

Procedure HideAGrouping(Settings, Group, Settings2, Group2, Field)
	
	Fields = Group2.GroupFields;
	
	FieldsToUseCount = 0;
	
	For Each Item In Fields.Items Do 
		
		If Item.Use Then 
			FieldsToUseCount = FieldsToUseCount + 1;
		EndIf;
		
	EndDo;
	
	If FieldsToUseCount > 0 Then 
		Return;
	EndIf;
	
	Group.Use = False;
	Group2.Use = False;
	ParentGrouping = Group.Parent;
	ParentGrouping2 = Group2.Parent;
	
	If TypeOf(ParentGrouping2) = Type("DataCompositionTable") Then 
		
		GroupingID2 = Settings2.GetIDByObject(Group2);
		
		If StrFind(GroupingID2, "/row/") > 0 Then 
			Groups = ParentGrouping.Rows;
			Groups2 = ParentGrouping2.Rows;
		Else
			Groups2 = ParentGrouping2.Columns;
		EndIf;
		
	Else
		Groups = ParentGrouping.Structure;
		Groups2 = ParentGrouping2.Structure;
	EndIf;
	
	GroupingIndex = Groups.IndexOf(Group);
	GroupingIndex2 = Groups2.IndexOf(Group2);
	
	For ChildGroupingNumber = 1 To Group2.Structure.Count() Do
		ChildGrouping  = Group.Structure[ChildGroupingNumber - 1];
		ChildGrouping2 = Group2.Structure[ChildGroupingNumber - 1];
		
		If Not ChildGrouping2.Use Then 
			Continue;
		EndIf;
		
		ReportsClientServer.CopyRecursive(Settings, ChildGrouping, Groups, GroupingIndex);
		ReportsClientServer.CopyRecursive(Settings2, ChildGrouping2, Groups2, GroupingIndex2);
		
		ChildGrouping.Use = False;
		ChildGrouping2.Use = False;
		
	EndDo;
	
EndProcedure

Function FieldsToUseCount(Fields, Count = Undefined)
	
	If Count = Undefined Then 
		Count = 0;
	EndIf;
	
	For Each Item In Fields.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then 
			
			FieldsToUseCount(Item, Count);
			
		ElsIf Item.Use Then 
			
			Count = Count + 1;
			
		EndIf;
		
	EndDo;
	
	Return Count;
	
EndFunction

#EndRegion

#Region RenamingAField

Procedure AfterEnteringTheReportFieldTitle(Title, AdditionalParameters) Export 
	
	If ValueIsFilled(Title) Then 
		RenameField(AdditionalParameters.Form, AdditionalParameters.Command, Title);
	EndIf;
	
EndProcedure

Function CurrentReportFieldTitle(Field, FieldDetails)
	
	CurrentTitle = "";
	
	If Field <> Undefined
		And ValueIsFilled(Field.Title) Then 
		
		CurrentTitle = Field.Title;
		
	ElsIf FieldDetails <> Undefined Then 
		
		CurrentTitle = FieldDetails.Title;
		
	ElsIf Field <> Undefined Then 
		
		CurrentTitle = String(Field);
		
	EndIf;
	
	Return CurrentTitle;
	
EndFunction

Procedure SetTheReportFieldTitle(Settings, Field, FieldDetails, Title)
	
	If FieldDetails <> Undefined
		And Title = FieldDetails.Title Then 
		
		Field.Title = "";
		
	Else
		
		Field.Title = Title;
		
	EndIf;
	
	Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(Settings, Field.Field);
	
	If TypeOf(Formula) = Type("DataCompositionUserFieldExpression") Then 
		Formula.Title = Title;
	EndIf;
	
EndProcedure

#EndRegion

#Region Filtering

Procedure FilterCommand(Form, Var_ComparisonType, TitleProperties, DetailsData)
	
	If TypeOf(Var_ComparisonType) = Type("String") Then 
		
		ShowAdvancedFilterSetting(Form, TitleProperties);
		Return;
		
	EndIf;
	
	ThisIsAGrouping = (DetailsData.Type = ReportsOptionsInternalClientServer.TheTypeOfTheDecryptionElementIsGrouping());
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	
	DisplayFilters = Settings.Filter;
	Filter = ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field);
	
	If Settings.Structure.Count() > 1 Then
		If Filter = Undefined
		   Or Filter <> Undefined And Filter.ComparisonType <> Var_ComparisonType Or Filter.RightValue <> DetailsData.Value Then
			DisplayFilters = ReportsOptionsInternalClientServer.ReportSectionFilters(Settings, TitleProperties, ThisIsAGrouping);
			Filter = ReportsOptionsInternalClientServer.ReportSectionFilter(DisplayFilters, TitleProperties.Field);
		EndIf;
	EndIf;
	
	If Filter = Undefined Then 
		
		Filter = DisplayFilters.Items.Add(Type("DataCompositionFilterItem"));
		Filter.LeftValue = TitleProperties.Field;
		
	EndIf;
	
	Filter.ComparisonType = Var_ComparisonType;
	Filter.RightValue = DetailsData.Value;
	Filter.Use = True;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, "FilterCommand", TitleProperties.Text);
	
EndProcedure

#EndRegion

#Region Sort

Function TheSortTypeOfTheSectionIsAvailable(Command, TitleProperties)
	
	WarningText = "";
	WarningTemplate = NStr("en = 'Field ""%1"" is already sorted by %2';");
	
	If StrEndsWith(CommandAction(Command), "Ascending")
		And Not TitleProperties.SortAsc Then 
		
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			WarningTemplate, TitleProperties.Text, NStr("en = 'ascending';"));
		
	ElsIf StrEndsWith(CommandAction(Command), "Descending")
		And Not TitleProperties.SortDesc Then 
		
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			WarningTemplate, TitleProperties.Text, NStr("en = 'descending';"));
		
	EndIf;
	
	If ValueIsFilled(WarningText) Then 
		
		ShowMessageBox(, WarningText);
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

Function TypeOfSectionSorting(Command)
	
	If StrEndsWith(CommandAction(Command), "Ascending") Then 
		
		Return DataCompositionSortDirection.Asc;
		
	EndIf;
	
	Return DataCompositionSortDirection.Desc;
	
EndFunction

Function SectionSortElement(SortingElements, Field)
	
	SortingElement = Undefined;
	
	For Each Item In SortingElements Do 
		
		If TypeOf(Item) <> Type("DataCompositionAutoOrderItem")
			And Item.Field = Field Then 
			
			SortingElement = Item;
			Break;
			
		EndIf;
		
	EndDo;
	
	Return SortingElement;
	
EndFunction

Function IndexSectionSortElement(SortingElements, Field)
	
	For Each Item In SortingElements Do 
		
		If TypeOf(Item) = Type("DataCompositionAutoOrderItem") Then 
			Return SortingElements.IndexOf(Item);
		EndIf;
		
	EndDo;
	
	Return SortingElements.Count();
	
EndFunction

Procedure ResetSorting(Settings, TitleProperties, StructureItems = Undefined)
	
	If StructureItems = Undefined Then 
		Settings.ClearItemOrder(Settings);
		StructureItems = Settings.Structure;
	EndIf;
		
	For Each Item In StructureItems Do 
		
		Settings.ClearItemOrder(Item);
		ElementType = TypeOf(Item);
		
		If ElementType = Type("DataCompositionTable") Then 
			ResetSorting(Settings, TitleProperties, Item.Rows);
			ResetSorting(Settings, TitleProperties, Item.Columns);
		ElsIf ElementType = Type("DataCompositionNestedObjectSettings") Then 
			ResetSorting(Item.Settings, TitleProperties);
		ElsIf ElementType = Type("DataCompositionGroup")
			Or ElementType = Type("DataCompositionTableGroup") Then 
			ResetSorting(Settings, TitleProperties, Item.Structure);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Appearance

#Region ClearingTheDesign

Procedure ClearTheLayoutOfTheReportSectionGroupings(Groups, TitleProperties)
	
	For Each Group In Groups Do 
		ClearTheLayoutOfTheReportSectionGrouping(Group, TitleProperties);
	EndDo;
	
EndProcedure

Procedure ClearTheLayoutOfTheReportSectionGrouping(Group, TitleProperties)
	
	If TypeOf(Group) = Type("DataCompositionTable") Then 
		
		ClearTheLayoutOfTheReportSectionGroupings(Group.Rows, TitleProperties);
		
	Else
		
		ClearTheLayoutOfTheReportGrouping(Group, TitleProperties);
		
		ClearTheLayoutOfTheReportSectionGroupings(Group.Structure, TitleProperties)
		
	EndIf;
	
EndProcedure

Procedure ClearTheLayoutOfTheReportGrouping(Group, TitleProperties)
	
	For Each AppearanceItem In Group.ConditionalAppearance.Items Do 
		
		FormattedFields = AppearanceItem.Fields.Items;
		
		TheFieldsToBeDrawnUpAreSuitable = New Array;
		TheFieldsToBeDrawnUpAreUsed = New Array;
		
		For Each FormattedField In FormattedFields Do 
			
			If FormattedField.Field = TitleProperties.Field Then 
				TheFieldsToBeDrawnUpAreSuitable.Add(FormattedField);
			EndIf;
			
			If FormattedField.Use Then 
				TheFieldsToBeDrawnUpAreUsed.Add(FormattedField);
			EndIf;
			
		EndDo;
		
		If TheFieldsToBeDrawnUpAreUsed.Count() = 1
			And TheFieldsToBeDrawnUpAreUsed[0].Field = TitleProperties.Field Then 
			
			TheFieldsToBeDrawnUpAreUsed.Clear();
			
		ElsIf TheFieldsToBeDrawnUpAreSuitable.Count() > 0 Then 
			
			TheFieldsToBeDrawnUpAreSuitable[0].Use = False;
			
		EndIf;
		
		If TheFieldsToBeDrawnUpAreUsed.Count() = 0 Then 
			AppearanceItem.Use = False;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

Procedure HighlightInYellow(Form, Command, TitleProperties = Undefined, Value = Undefined)
	
	If TitleProperties = Undefined Then 
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	ColoringOptions = ReportSectionColoringOptions(CommandAction(Command));
	ColoringOptions.Condition.LeftValue = TitleProperties.Field;
	ColoringOptions.Condition.ComparisonType = TypeOfComparisonTermsOfRegistration(Value);
	ColoringOptions.Condition.RightValue = Value;
	
	StyleItems = StandardSubsystemsClient.StyleItems();
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "TextColor";
	Appearance.Value = StyleItems.WarningTextColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	
	Appearance = StandardParameterForColoringAReportSection();
	Appearance.Parameter = "BackColor";
	Appearance.Value = StyleItems.AttentionBackColor;
	
	ColoringOptions.Appearance.Add(Appearance);
	ColoringOptions.Presentation = NStr("en = 'Highlight in yellow';");
	
	ColorizeTheReportSection(Form, ColoringOptions, TitleProperties);
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

#Region ColoringTheReportGrouping

// Parameters:
//  Action - String
//
// Returns:
//  Structure:
//    * Condition - Structure:
//        ** LeftValue - DataCompositionField
//        ** ComparisonType - DataCompositionComparisonType
//        ** RightValue - Undefined
//    * Array
//
Function ReportSectionColoringOptions(Action)
	
	Condition = New Structure;
	Condition.Insert("LeftValue", Undefined);
	Condition.Insert("ComparisonType", DataCompositionComparisonType.Equal);
	Condition.Insert("RightValue", Undefined);
	
	ColoringOptions = New Structure;
	ColoringOptions.Insert("Condition", Condition);
	ColoringOptions.Insert("Appearance", New Array);
	ColoringOptions.Insert("Presentation", "");
	
	Return ColoringOptions;
	
EndFunction

// Returns:
//  Structure:
//    * Parameter - String
//    * Value - Undefined
//
Function StandardParameterForColoringAReportSection()
	
	Parameter = New Structure;
	Parameter.Insert("Parameter", "");
	Parameter.Insert("Value", Undefined);
	
	Return Parameter;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  ColoringOptions - See ReportSectionColoringOptions
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//
Procedure ColorizeTheReportSection(Form, ColoringOptions, TitleProperties)
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);

	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		ApplyReportGroupingColoring(Group.Settings, Group2.Settings, ColoringOptions, TitleProperties);
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		ApplyReportGroupingColoring(Settings, Settings2, ColoringOptions, TitleProperties);
	Else
		Section = Settings.GetObjectByID(TitleProperties.SectionID);
		Section2 = Settings2.GetObjectByID(TitleProperties.SectionID);
		If TypeOf(Section) = Type("DataCompositionTable") Then 
			ColorizeReportSectionGroupings(Section.Rows, Section2.Rows, ColoringOptions, TitleProperties);
		Else
			ColorizeTheReportSectionGrouping(Section, Section2, ColoringOptions, TitleProperties);
		EndIf;
	EndIf;
	
EndProcedure

Procedure ColorizeReportSectionGroupings(Groups, Groups2, ColoringOptions, TitleProperties)
	
	For DimensionNumber_ = 1 To Groups.Count() Do
		Group = Groups[DimensionNumber_ - 1];
		Group2 = Groups2[DimensionNumber_ - 1];
		ColorizeTheReportSectionGrouping(Group, Group2, ColoringOptions, TitleProperties);
	EndDo;
	
EndProcedure

Procedure ColorizeTheReportSectionGrouping(Group, Group2, ColoringOptions, TitleProperties)
	
	If TypeOf(Group) = Type("DataCompositionTable") Then 
		
		ColorizeReportSectionGroupings(Group.Rows, Group2.Rows, ColoringOptions, TitleProperties);
		
	Else
		
		ApplyReportGroupingColoring(Group, Group2, ColoringOptions, TitleProperties);
		
		ColorizeReportSectionGroupings(Group.Structure, Group2.Structure, ColoringOptions, TitleProperties)
		
	EndIf;
	
EndProcedure

Procedure ApplyReportGroupingColoring(Group, Group2, ColoringOptions, TitleProperties)
	
	AppearanceField = CommonClientServer.StructureProperty(ColoringOptions.Condition, "LeftValue");
	
	TheColoringOptionsAreApplicable = TheLayoutIsApplicableToTheGrouping(Group2,
		AppearanceField, TitleProperties.Resource);
	
	If TheColoringOptionsAreApplicable Then 
		
		ColoringBook = ColoringTheReportGrouping(Group.ConditionalAppearance, ColoringOptions);
		
		If ColoringBook = Undefined Then 
			AddReportGroupingColoring(Group.ConditionalAppearance, ColoringOptions);
		EndIf;
		
	EndIf;
	
EndProcedure

// Parameters:
//  Group - DataCompositionSettings
//              - DataCompositionNestedObjectSettings
//              - DataCompositionGroup
//              - DataCompositionChart
//              - DataCompositionChartStructureItemCollection
//              - DataCompositionChartGroup
//              - DataCompositionTableStructureItemCollection
//              - DataCompositionTableGroup
//              - Undefined
//  Field - DataCompositionField
//       - Undefined
//  ThisIsAResource - Boolean
//
// Returns:
//   Boolean
//
Function TheLayoutIsApplicableToTheGrouping(Group, Field, ThisIsAResource)
	
	If TypeOf(Group) <> Type("DataCompositionGroup")
		And TypeOf(Group)<> Type("DataCompositionTableGroup") Then 
		
		Return True;
	EndIf;
	
	GroupFields = Group.GroupFields;
	
	Return ThisIsAResource
		Or Field = Undefined
		Or GroupFields.Items.Count() = 0
		Or ReportsOptionsInternalClientServer.ReportField(GroupFields, Field) <> Undefined;
	
EndFunction

Function ColoringTheReportGrouping(ConditionalAppearance, ColoringOptions)
	
	 For Each Item In ConditionalAppearance.Items Do 
		
		Condition = ConditionForColoringTheReportGrouping(Item.Filter, ColoringOptions.Condition);
		
		If Condition <> Undefined Then 
			
			UpdateTheReportGroupingColoring(Item, Condition, ColoringOptions);
			Return Item;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function ConditionForColoringTheReportGrouping(Filter, Search)
	
	Condition = Undefined;
	
	For Each Item In Filter.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionFilterItem")
			And Item.LeftValue = Search.LeftValue
			And Item.ComparisonType = Search.ComparisonType
			And Item.RightValue = Search.RightValue Then 
			
			Condition = Item;
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Condition;
	
EndFunction

Procedure UpdateTheReportGroupingColoring(Appearance, Condition, ColoringOptions)
	
	Appearance.Use = True;
	Condition.Use = True;
	
	Appearance.Fields.Items.Clear();
	
	Field = Appearance.Fields.Items.Add();
	Field.Field = ColoringOptions.Condition.LeftValue;
	Field.Use = True;
	
	ResetTheLayoutOfTheReportGrouping(Appearance);
	
	For Each Parameter In ColoringOptions.Appearance Do 
		Appearance.Appearance.SetParameterValue(Parameter.Parameter, Parameter.Value);
	EndDo;
	
	SetTheLayoutAreaForTheReportGrouping(Appearance);
	
EndProcedure

Procedure AddReportGroupingColoring(ConditionalAppearance, ColoringOptions)
	
	Appearance = ConditionalAppearance.Items.Add();
	
	Condition = Appearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FillPropertyValues(Condition, ColoringOptions.Condition);
	Condition.Use = True;
	
	Field = Appearance.Fields.Items.Add();
	Field.Field = ColoringOptions.Condition.LeftValue;
	Field.Use = True;
	
	For Each Parameter In ColoringOptions.Appearance Do 
		Appearance.Appearance.SetParameterValue(Parameter.Parameter, Parameter.Value);
	EndDo;
	
	Appearance.UserSettingPresentation = ColoringOptions.Presentation;
	
	SetTheLayoutAreaForTheReportGrouping(Appearance);
	
EndProcedure

Procedure ResetTheLayoutOfTheReportGrouping(AppearanceItem, ParametersOnly = True)
	
	For Each Item In AppearanceItem.Appearance.Items Do 
		Item.Use = False;
	EndDo;
	
	If ParametersOnly Then 
		Return;
	EndIf;
	
	AppearanceItem.Fields.Items.Clear();
	AppearanceItem.Filter.Items.Clear();
	
EndProcedure

#EndRegion

#Region SizeChange

Procedure AfterEnteringTheReportLineHeight(RowHeight, AdditionalParameters) Export 
	
	If ValueIsFilled(RowHeight) Then 
		
		SetRowHeight(
			AdditionalParameters.Form,
			AdditionalParameters.Command,
			AdditionalParameters.TitleProperties,
			RowHeight,
			AdditionalParameters.FieldSizeParameters);
		
	EndIf;
	
EndProcedure

Procedure AfterEnteringTheWidthOfTheReportColumn(ColumnWidth, AdditionalParameters) Export 
	
	If ValueIsFilled(ColumnWidth) Then 
		
		SetColumnWidth(
			AdditionalParameters.Form,
			AdditionalParameters.Command,
			AdditionalParameters.TitleProperties,
			ColumnWidth,
			AdditionalParameters.FieldSizeParameters);
		
	EndIf;
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  TitleProperties - See ReportsOptionsInternal.StandardReportHeaderProperties
//  Var_Orientation - String
//
// Returns:
//  Structure:
//    * Size - Number
//    * MaximumSize - Number
//    * MinimumSize - Number
//    * Item - ConditionalAppearanceItem
//    * Field - DataCompositionField
//
Function ReportFieldSizeParameters(Form, TitleProperties, Var_Orientation = "Height") Export 
	
	If TypeOf(TitleProperties.IDOfTheSettings) <> Type("DataCompositionID") Then 
		Return StandardParametersForTheReportFieldSize();
	EndIf;
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		Appearance = Group.Settings.ConditionalAppearance;
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		Appearance = Settings.ConditionalAppearance;
	Else
		Appearance = Group.ConditionalAppearance;
	EndIf;
	
	For Each Item In Appearance.Items Do 
		
		DesignParameters = Item.Appearance.Items;
		
		IDs = FieldSizeParameterIds(Var_Orientation);
		MinimumSize = DesignParameters.Find(IDs.MinimumSize);
		MaximumSize = DesignParameters.Find(IDs.MaximumSize);
		
		If MinimumSize.Use
			Or MaximumSize.Use Then 
			
			Parameters = StandardParametersForTheReportFieldSize();
			Parameters.Field = TitleProperties.Field;
			Parameters.Item = Item;
			Parameters.MinimumSize = MinimumSize;
			Parameters.MaximumSize = MaximumSize;
			Parameters.Size = Max(MinimumSize.Value, MaximumSize.Value);
			
			Return Parameters;
			
		EndIf;
		
	EndDo;
	
	Return StandardParametersForTheReportFieldSize();
	
EndFunction

Function FieldSizeParameterIds(Var_Orientation)
	
	IDs = New Structure;
	
	If Var_Orientation = "Height" Then 
		
		IDs.Insert("MinimumSize", "MinimumHeight");
		IDs.Insert("MaximumSize", "MaximumHeight");
		
	Else
		
		IDs.Insert("MinimumSize", "MinimumWidth");
		IDs.Insert("MaximumSize", "MaximumWidth");
		
	EndIf;
	
	Return IDs;
	
EndFunction

Procedure AddReportFieldSizeParameters(Form, TitleProperties, Size, Var_Orientation = "Height")
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	If TypeOf(Group) = Type("DataCompositionNestedObjectSettings") Then
		Item = Group.Settings.ConditionalAppearance.Items.Add();
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		Item = Settings.ConditionalAppearance.Items.Add();
	Else
		Item = Group.ConditionalAppearance.Items.Add();
	EndIf;
	
	DesignParameters = Item.Appearance.Items;
	IDs = FieldSizeParameterIds(Var_Orientation);
	
	Parameters = StandardParametersForTheReportFieldSize(Size);
	Parameters.Field = TitleProperties.Field;
	Parameters.Item = Item;
	Parameters.MinimumSize = DesignParameters.Find(IDs.MinimumSize);
	Parameters.MaximumSize = DesignParameters.Find(IDs.MaximumSize);
	
	UpdateSizeSettings(Parameters, Size);
	
EndProcedure

Procedure UpdateSizeSettings(Parameters, Size)
	
	Parameters.Item.Use = True;
	
	Parameters.MinimumSize.Value = Size;
	Parameters.MinimumSize.Use = True;
	
	Parameters.MaximumSize.Value = Size;
	Parameters.MaximumSize.Use = True;
	
	CheckTheFieldToChange(Parameters.Item.Fields, Parameters.Field);
	SetTheResizingArea(Parameters.Item);
	
EndProcedure

// Parameters:
//  Size - Number
//         - Undefined
//
// Returns:
//  Structure:
//    * Size - Number
//             - Undefined
//    * MaximumSize - Number
//    * MinimumSize - Number
//    * Item - ConditionalAppearanceItem
//    * Field - SpreadsheetDocumentField
//
Function StandardParametersForTheReportFieldSize(Size = 0)
	
	Parameters = New Structure;
	Parameters.Insert("Field", Undefined);
	Parameters.Insert("Item", Undefined);
	Parameters.Insert("MinimumSize", Undefined);
	Parameters.Insert("MaximumSize", Undefined);
	Parameters.Insert("Size", Size);
	
	Return Parameters;
	
EndFunction

// Parameters:
//  Fields - DataCompositionAppearanceFields
//  TheFieldIsRequired - DataCompositionField
//
Procedure CheckTheFieldToChange(Fields, TheFieldIsRequired)
	
	Field = Undefined;
	
	For Each Item In Fields.Items Do 
		
		If Item.Field = TheFieldIsRequired Then 
			
			Field = Item;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Field = Undefined Then 
		
		Field = Fields.Items.Add();
		Field.Field = TheFieldIsRequired;
		
	EndIf;
	
	Field.Use = True;
	
EndProcedure

Procedure SetTheResizingArea(Item)
	
	UnusedAreas = New Array;
	UnusedAreas.Add("UseInOverall");
	UnusedAreas.Add("UseInFilter");
	UnusedAreas.Add("UseInParameters");
	UnusedAreas.Add("UseInOverallHeader");
	For Each Area In UnusedAreas Do 
		Item[Area] = DataCompositionConditionalAppearanceUse.DontUse;
	EndDo;
	
EndProcedure

#EndRegion

#Region AdvancedFormattingOfTheReportGrouping

Function ReportGroupingDesignElement(Group, Field)
	
	Appearance = Group.ConditionalAppearance;
	
	For Each AppearanceItem In Appearance.Items Do 
		
		For Each AppearanceField In AppearanceItem.Fields.Items Do 
			
			If AppearanceField.Field = Field Then 
				Return AppearanceItem;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function IDOfTheReportGroupingDesignElement(Group, Field)
	
	AppearanceItem = ReportGroupingDesignElement(Group, Field);
	
	If AppearanceItem <> Undefined Then 
		Return Group.ConditionalAppearance.GetIDByObject(AppearanceItem);
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ConditionForFormattingAReportGrouping(Field, Value)
	
	If Value = Undefined Then 
		Return Undefined;
	EndIf;
	
	Condition = New Structure;
	Condition.Insert("LeftValue", Field);
	Condition.Insert("ComparisonType", TypeOfComparisonTermsOfRegistration(Value));
	Condition.Insert("RightValue", Value);
	
	Return Condition;
	
EndFunction

Function TypeOfComparisonTermsOfRegistration(Value)
	
	If TypeOf(Value) = Type("ValueList") Then 
		Return DataCompositionComparisonType.InList;
	EndIf;
	
	Return DataCompositionComparisonType.Equal;
	
EndFunction

// Parameters:
//  Result - Structure
//  AdditionalParameters - Structure
//
Procedure AfterChangingTheLayoutElementOfTheReportGrouping(Result, AdditionalParameters) Export 
	
	If TypeOf(Result) <> Type("Structure") Then 
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	TitleProperties = AdditionalParameters.TitleProperties;
	
	Settings = SettingsUsed(Form);
	
	If Result.Property("DescriptionOfFormulas") Then 
		AddFormulas(Settings, Settings.SelectionAvailableFields, Result.DescriptionOfFormulas);
	EndIf;
	
	SettingsUsed = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	SettingsUsed2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Section = SettingsUsed.GetObjectByID(TitleProperties.SectionID);
	Section2 = SettingsUsed2.GetObjectByID(TitleProperties.SectionID);
	
	SampleDesign = Result.DCItem;
	If TypeOf(Section) = Type("DataCompositionNestedObjectSettings") Then
		ApplyTheLayoutOfTheReportGrouping(Section.Settings, Section2.Settings, SampleDesign, TitleProperties);
	ElsIf TitleProperties.NumberOfPartitions = 1 Then 
		ApplyTheLayoutOfTheReportGrouping(SettingsUsed, SettingsUsed2, SampleDesign, TitleProperties);
	ElsIf TypeOf(Section) = Type("DataCompositionTable") Then 
		FormalizeTheReportSectionDimensions(Section.Rows, Section2.Rows, Result.DCItem, TitleProperties);
	Else
		ArrangeTheGroupingOfTheReportSection(Section, Section2, Result.DCItem, TitleProperties);
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, AdditionalParameters.CommandAction);
	
EndProcedure

Procedure ApplyTheLayoutOfTheReportGrouping(Group, Group2, SampleDesign, TitleProperties)
	
	TheLayoutIsApplicableToTheGrouping = TheLayoutIsApplicableToTheGrouping(Group2,
		TitleProperties.Field, TitleProperties.Resource);
	
	If TheLayoutIsApplicableToTheGrouping Then 
		
		Appearance = Group.ConditionalAppearance;
		AppearanceItem = ReportGroupingDesignElement(Group, TitleProperties.Field);
		
		If AppearanceItem = Undefined Then 
			AppearanceItem = Appearance.Items.Add();
		Else
			ResetTheLayoutOfTheReportGrouping(AppearanceItem, False);
		EndIf;
		
		ReportsClientServer.FillPropertiesRecursively(Appearance, AppearanceItem, SampleDesign);
		
		SetTheLayoutAreaForTheReportGrouping(AppearanceItem);
		
	EndIf;
	
EndProcedure

Procedure FormalizeTheReportSectionDimensions(Groups, Groups2, SampleDesign, TitleProperties)
	
	For DimensionNumber_ = 1 To Groups.Count() Do
		Group = Groups[DimensionNumber_ - 1];
		Group2 = Groups2[DimensionNumber_ - 1];
		ArrangeTheGroupingOfTheReportSection(Group, Group2, SampleDesign, TitleProperties);
	EndDo;
	
EndProcedure

Procedure ArrangeTheGroupingOfTheReportSection(Group, Group2, SampleDesign, TitleProperties)
	
	If TypeOf(Group) = Type("DataCompositionTable") Then 
		
		FormalizeTheReportSectionDimensions(Group.Rows, Group2.Rows, SampleDesign, TitleProperties);
		
	Else
		
		ApplyTheLayoutOfTheReportGrouping(Group, Group2, SampleDesign, TitleProperties);
		
		FormalizeTheReportSectionDimensions(Group.Structure, Group2.Structure, SampleDesign, TitleProperties);
		
	EndIf;
	
EndProcedure

Procedure SetTheLayoutAreaForTheReportGrouping(AppearanceItem)
	
	UnusedAreas = UnusedDesignAreas();
	
	For Each Area In UnusedAreas Do 
		AppearanceItem[Area] = DataCompositionConditionalAppearanceUse.DontUse;
	EndDo;
	
EndProcedure

Function UnusedDesignAreas()
	
	UnusedAreas = New Array;
	UnusedAreas.Add("UseInHeader");
	UnusedAreas.Add("UseInFieldsHeader");
	UnusedAreas.Add("UseInOverall");
	UnusedAreas.Add("UseInFilter");
	UnusedAreas.Add("UseInParameters");
	UnusedAreas.Add("UseInResourceFieldsHeader");
	UnusedAreas.Add("UseInOverallHeader");
	UnusedAreas.Add("UseInOverallResourceFieldsHeader");
	
	Return UnusedAreas;
	
EndFunction

#EndRegion

#EndRegion

#Region SelectingAField

Procedure SelectAReportField(Form, Action, CollectionName, Handler = Undefined,
	Field = Undefined, SettingsNodeID = Undefined)
	
	If Handler = Undefined Then 
		Handler = ReportFieldSelectionHandler(Form, Action);
	EndIf;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("ReportSettings", Form.ReportSettings);
	ChoiceParameters.Insert("SettingsComposer", ReportSettingsBuilder(Form));
	ChoiceParameters.Insert("Mode", CollectionName);
	ChoiceParameters.Insert("DCField", Field);
	ChoiceParameters.Insert("SettingsStructureItemID",
		SettingsStructureItemID(Form, SettingsNodeID));
	
	OpenForm(
		"SettingsStorage.ReportsVariantsStorage.Form.SelectReportField",
		ChoiceParameters, Form, Form.UUID,,, Handler);
	
EndProcedure

Procedure SelectAReportFieldFromTheMenu(Form, Command, CollectionName = "SelectedFields")
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	Handler = ReportFieldSelectionHandler(Form, CommandAction(Command));
	SpecifyTheNameOfTheCollection(CollectionName, Handler);
	
	ReportFields = ReportFields(Form, Command, CollectionName);
	
	If ReportFields = Undefined Then 
		Return;
	EndIf;
	
	If ReportFields.Count() > 20
		Or ReportFields.Count() = 1
		And ReportFields.FindByValue("More") <> Undefined Then 
		
		SelectAReportField(Form, CommandAction(Command), CollectionName, Handler);
		Return;
		
	EndIf;
	
	Form.ShowChooseFromMenu(Handler, ReportFields, Form.CurrentItem);
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  Action - String
//
// Returns:
//  NotifyDescription
//
Function ReportFieldSelectionHandler(Form, Action)
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Form", Form);
	HandlerParameters.Insert("Action", Action);
	HandlerParameters.Insert("TitleProperties", ReportTitleProperties(Form));
	
	Return New NotifyDescription("AfterSelectingAField", Form, HandlerParameters);
	
EndFunction

// Parameters:
//  SelectedField - ValueListItem
//                - DataCompositionSelectedField
//  AdditionalParameters - Structure:
//    * Form - ClientApplicationForm
//    * Action - String
//    * TitleProperties - See ReportTitleProperties
//
Procedure AfterSelectingAField(SelectedField, AdditionalParameters) Export 
	
	If SelectedField = Undefined Then 
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	Field = ?(TypeOf(SelectedField) = Type("ValueListItem"), SelectedField.Value, SelectedField);
	
	If Field = "More" Then 
		
		SelectAReportField(Form, AdditionalParameters.Action, AdditionalParameters.CollectionName);
		Return;
		
	EndIf;
	
	TitleProperties = AdditionalParameters.TitleProperties;
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Action = AdditionalParameters.Action;
	FieldRoles = Form.ReportSettings.ResultProperties.FieldRoles;
	
	If StrCompare(Action, "InsertFieldLeft") = 0 Or StrCompare(Action, "InsertFieldRight") = 0 Then
		
		AddFormula(Settings, Settings.SelectionAvailableFields, Field);
		InsertAField(Settings, Settings2, Field, Action, TitleProperties, FieldRoles);
		
	ElsIf StrStartsWith(Action, "InsertAGrouping") Then 
		
		AddFormula(Settings, Settings.GroupAvailableFields, Field);
		InsertAGrouping(Settings, Action, Field, TitleProperties);
		
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, Action, TitleProperties.Text);
	
EndProcedure

#EndRegion

#Region ReportFields

Function ReportFields(Form, Command, CollectionName)
	
	AvailableFields = AvailableReportFields(ReportSettingsBuilder(Form), CollectionName);
	ReportFields = MainReportFields(Form.ReportSettings.ResultProperties, AvailableFields);
	
	If ReportFields.Count() = 0 Then 
		AddAvailableReportFields(ReportFields, AvailableFields);
	EndIf;
	
	ExcludeUsedReportFields(ReportFields, Form, Command);
	ExcludeUnavailableReportFields(ReportFields, Form, Command);
	
	TitleProperties = ReportTitleProperties(Form);
	
	If TitleProperties = Undefined Then 
		Return Undefined;
	EndIf;
	
	If ReportFields.FindByValue("More") = Undefined Then 
		ReportFields.Add("More", NStr("en = 'More…';"));
	EndIf;
	
	Return ReportFields;
	
EndFunction

Function DescriptionOfTheReportField(SettingsComposer, Field, CollectionName = "Selection")
	
	AvailableFields = AvailableReportFields(SettingsComposer, CollectionName);
	
	Return AvailableFields.FindField(Field);
	
EndFunction

Function AvailableReportFields(SettingsComposer, CollectionName = "Selection")
	
	If CollectionName = "Filters" Then 
		
		Return SettingsComposer.Settings.FilterAvailableFields;
		
	ElsIf CollectionName = "Sort" Then 
		
		Return SettingsComposer.Settings.OrderAvailableFields;
		
	ElsIf CollectionName = "GroupFields" Then 
		
		Return SettingsComposer.Settings.GroupAvailableFields;
		
	EndIf;
	
	Return SettingsComposer.Settings.SelectionAvailableFields;
	
EndFunction

Function MainReportFields(ResultProperties, AvailableFields)
	
	TheMainFieldsAvailableAre = New ValueList;
	
	MainField = ResultProperties.MainField;
	
	For Each Field In MainField Do 
		
		AvailableField = AvailableFields.FindField(New DataCompositionField(Field));
		
		If AvailableField <> Undefined
			And TheMainFieldsAvailableAre.FindByValue(AvailableField) = Undefined Then 
			
			TheMainFieldsAvailableAre.Add(AvailableField, AvailableField.Title,, FieldPicture(AvailableField.ValueType));
		EndIf;
		
	EndDo;
	
	Return TheMainFieldsAvailableAre;
	
EndFunction

Procedure AddAvailableReportFields(ReportFields, AvailableFields)
	
	For Each AvailableField In AvailableFields.Items Do 
		
		If Not AvailableField.Folder Then 
			ReportFields.Add(AvailableField, AvailableField.Title,, FieldPicture(AvailableField.ValueType));
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  MainField - ValueList
//  Form - ClientApplicationForm
//  Command - FormCommand
//
Procedure ExcludeUsedReportFields(MainField, Form, Command)
	
	Owner = Form.CurrentItem;
	
	If TypeOf(Owner) <> Type("FormButton")
		And (TypeOf(Owner) <> Type("FormField") Or Owner.Type <> FormFieldType.SpreadsheetDocumentField) Then 
		
		Return;
	EndIf;
	
	If CommandAction(Command) <> "InsertFieldLeft"
		And CommandAction(Command) <> "InsertFieldRight" Then 
		
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	UsedFields = ReportFieldsUsed(
		TitleProperties, Form.ReportSettings.ResultProperties.FieldsIndex);
	
	IndexOf = MainField.Count() - 1;
	
	While IndexOf >= 0 Do 
		
		AvailableField = MainField[IndexOf].Value;
		
		If UsedFields[AvailableField.Field] <> Undefined Then 
			MainField.Delete(IndexOf);
		EndIf;
		
		IndexOf = IndexOf - 1;
		
	EndDo;
	
EndProcedure

Function ReportFieldsUsed(TitleProperties, FieldsIndex)
	
	IndexOfTheSectionFields = FieldsIndex[TitleProperties.SectionOrder];
	IndexOfTheGroupingFields = IndexOfTheSectionFields[TitleProperties.GroupingOrder];
	
	Return IndexOfTheGroupingFields;
	
EndFunction

Function FieldPicture(FieldValueType)
	
	AvailableTypes = FieldValueType.Types();
	
	If AvailableTypes.Count() = 0 Then 
		Return PictureLib.IsEmpty;
	EndIf;
	
	If AvailableTypes.Count() > 1 Then 
		Return PictureLib.TypeFlexibleMain;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Number")) Then 
		Return PictureLib.NumberType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("String")) Then 
		Return PictureLib.StringType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Date")) Then 
		Return PictureLib.DateType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("Boolean")) Then 
		Return PictureLib.BooleanType;
	EndIf;
	
	If FieldValueType.ContainsType(Type("UUID")) Then 
		Return PictureLib.TypeID;
	EndIf;
	
	Return PictureLib.TypeRef;
	
EndFunction

// Parameters:
//  MainField - ValueList
//  Form - ClientApplicationForm
//  Command - FormCommand
//
Procedure ExcludeUnavailableReportFields(MainField, Form, Command)
	
	Owner = Form.CurrentItem;
	
	If TypeOf(Owner) <> Type("FormButton")
		And (TypeOf(Owner) <> Type("FormField") Or Owner.Type <> FormFieldType.SpreadsheetDocumentField) Then 
		
		Return;
	EndIf;
	
	If CommandAction(Command) <> "InsertFieldLeft"
		And CommandAction(Command) <> "InsertFieldRight" Then 
		
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	FieldRoles = Form.ReportSettings.ResultProperties.FieldRoles;
	
	IndexOf = MainField.Count() - 1;
	
	While IndexOf >= 0 Do 
		
		AvailableField = MainField[IndexOf].Value;
		
		If TitleProperties.Resource
			And Not AvailableField.Resource Then 
			
			MainField.Delete(IndexOf);
			
		ElsIf TitleProperties.Period
			And FieldRoles.TimeIntervals_[AvailableField.Field] = Undefined Then 
			
			MainField.Delete(IndexOf);
			
		ElsIf Not TitleProperties.Period
			And FieldRoles.TimeIntervals_[AvailableField.Field] <> Undefined Then 
			
			MainField.Delete(IndexOf);
			
		ElsIf TitleProperties.UsedInGroupingFields
			And TitleProperties.MoveFieldRight
			And CommandAction(Command) = "InsertFieldRight"
			And AvailableField.Resource Then 
			
			MainField.Delete(IndexOf);
			
		ElsIf TitleProperties.UsedInGroupingFields
			And CommandAction(Command) = "InsertFieldLeft"
			And AvailableField.Resource Then 
			
			MainField.Delete(IndexOf);
			
		EndIf;
		
		IndexOf = IndexOf - 1;
		
	EndDo;
	
EndProcedure

#Region MovingAField

Procedure MoveTheFieldHorizontally(Form, Command)
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Group = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);
	
	If Group = Undefined Or Group2 = Undefined Then
		Return;
	EndIf;
	
	MakeCopyOfFields(Group, Group2, "Selection");
	
	Fields = Group.Selection;
	MoveResourcesToEnd(Fields);
	CurrentField = ReportsOptionsInternalClientServer.ReportField(Fields, TitleProperties.Field);
	
	SourceFieldIndex = Fields.Items.IndexOf(CurrentField);
	
	If CommandAction(Command) = "MoveFieldLeft" Then 
		
		ShiftDirection = -1
		
	ElsIf CommandAction(Command) = "MoveFieldRight" Then 
		
		ShiftDirection = 1
		
	EndIf;
	
	FinalIndexOfTheField = SourceFieldIndex + ShiftDirection;
	
	If FinalIndexOfTheField >= 0 Then 
	
		AdjacentField = Fields.Items[FinalIndexOfTheField];
		
		While FinalIndexOfTheField > 0 And Not AdjacentField.Use Do 
			
			FinalIndexOfTheField = FinalIndexOfTheField + ShiftDirection;
			AdjacentField = Fields.Items[FinalIndexOfTheField];
			
		EndDo;
		
	EndIf;
	
	Fields.Items.Move(CurrentField, FinalIndexOfTheField - SourceFieldIndex);
	
	If Not ThisIsAGroupingOfDetailedRecords(Group2) Then
		CopyFieldsOrder(Group.GroupFields, Fields);
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Procedure MoveResourcesToEnd(Fields)
	
	Resources = New Map;
	GatherAllResourcesRecursively(Resources, Fields.SelectionAvailableFields.Items);
	
	IndexOf = Fields.Items.Count();
	LastResourceIndex = IndexOf;
	While IndexOf > 0 Do
		IndexOf = IndexOf - 1;
		CurrentItem = Fields.Items[IndexOf];
		If Resources.Get(CurrentItem.Field) = Undefined Then
			Continue;
		EndIf;
		Move = LastResourceIndex - IndexOf - 1;
		LastResourceIndex = IndexOf + Move;
		If Move > 0 Then
			Fields.Items.Move(CurrentItem, Move);
		EndIf;
	EndDo;
	
EndProcedure

Procedure GatherAllResourcesRecursively(Resources, Items)
	For Each AvailableField In Items Do
		If AvailableField.Resource Then
			Resources.Insert(AvailableField.Field, True);
		ElsIf AvailableField.Folder Then
			GatherAllResourcesRecursively(Resources, AvailableField.Items)
		EndIf;
	EndDo;
EndProcedure

Procedure CopyFieldsOrder(GroupFields, SelectionFields)
	
	IndexOf = 0;
	For Each ComboBox In SelectionFields.Items Do
		For CurrentIndex = IndexOf To GroupFields.Items.Count() - 1 Do
			GroupingField = GroupFields.Items[CurrentIndex];
			If GroupingField.Field = ComboBox.Field Then
				Move = IndexOf - GroupFields.Items.IndexOf(GroupingField);
				GroupFields.Items.Move(GroupingField, Move);
				IndexOf = IndexOf + 1;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure MoveTheFieldVertically(Form, Command, Response = Undefined)
	
	If Not TheActionIsAvailable(Form, Command) Then 
		Return;
	EndIf;
	
	TitleProperties = ReportTitleProperties(Form);
	
	Settings = SettingsUsed(Form, TitleProperties.IDOfTheSettings);
	Settings2 = SettingsUsed(Form, TitleProperties.IDOfTheSettings, True);
	Group  = Settings.GetObjectByID(TitleProperties.GroupingID);
	Group2 = Settings2.GetObjectByID(TitleProperties.GroupingID);
	MakeCopyOfFields(Group, Group2, "GroupFields");
	MakeCopyOfFields(Group, Group2, "Selection");
	MoveResourcesToEnd(Group.Selection);
	CopyFieldsOrder(Group.GroupFields, Group.Selection);
	
	GroupingField = ReportsOptionsInternalClientServer.ReportField(
		Group.GroupFields, TitleProperties.Field);
	
	SelectedField = ReportsOptionsInternalClientServer.ReportField(
		Group.Selection, TitleProperties.Field,, TitleProperties.Text);
	
	NeighboringGrouping = NeighboringGrouping(Form, Command, Settings, TitleProperties.GroupingOrder);
	
	If NeighboringGrouping = Undefined Then 
		Return;
	EndIf;
	
	NeighboringGrouping2 = NeighboringGrouping(Form, Command, Settings2, TitleProperties.GroupingOrder);
	MakeCopyOfFields(NeighboringGrouping, NeighboringGrouping2, "GroupFields");
	MakeCopyOfFields(NeighboringGrouping, NeighboringGrouping2, "Selection");
	MoveResourcesToEnd(NeighboringGrouping.Selection);
	CopyFieldsOrder(NeighboringGrouping.GroupFields, NeighboringGrouping.Selection);
	
	SourceFieldIndex = Group.Selection.Items.IndexOf(SelectedField);
	
	Fields = NeighboringGrouping.Selection;
	MovementParameters = New Structure("Form, Command, Response", Form, Command, Response);
	FieldIndex = IndexOfTheSelectedField(SourceFieldIndex, Fields, TitleProperties.Field, MovementParameters);
	
	If FieldIndex = Undefined Then 
		Return;
	EndIf;
	
	AdjacentSelectedField = ReportsOptionsInternalClientServer.ReportField(Fields, TitleProperties.Field, False);
	If AdjacentSelectedField = Undefined Then
		AdjacentSelectedField = Fields.Items.Insert(FieldIndex, Type("DataCompositionSelectedField"));
	Else
		Fields.Items.Move(AdjacentSelectedField, FieldIndex - Fields.Items.IndexOf(AdjacentSelectedField));
	EndIf;
	FillPropertyValues(AdjacentSelectedField, SelectedField);
	MoveResourcesToEnd(Fields);
	
	SetTheOutputOfTheGroupingDetailsSeparately(NeighboringGrouping);
	
	Fields = NeighboringGrouping.GroupFields;
	FieldsCount = Fields.Items.Count();
	
	If FieldsCount > 0 Then 
		AdjacentGroupingField = ReportsOptionsInternalClientServer.ReportField(Fields, TitleProperties.Field, False);
		If AdjacentGroupingField = Undefined Then
			AdjacentGroupingField = Fields.Items.Add(Type("DataCompositionGroupField"));
		EndIf;
		FillPropertyValues(AdjacentGroupingField,
			?(GroupingField = Undefined, SelectedField, GroupingField));
		CopyFieldsOrder(Fields, NeighboringGrouping.Selection);
	EndIf;
	
	If GroupingField <> Undefined Then 
		Group.GroupFields.Items.Delete(GroupingField);
	EndIf;
	
	If SelectedField <> Undefined Then 
		
		If Group.GroupFields.Items.Count() = 0 Then 
			
			SelectedField.Use = False;
			
			If FieldsToUseCount(Group.Selection) = 0 Then 
				HideAGrouping(Settings, Group, Settings, Group, TitleProperties.Field);
			EndIf;
			
		Else
			Group.Selection.Items.Delete(SelectedField);
		EndIf;
		
	EndIf;
	
	NotifyAboutTheCompletionOfTheContextSetting(Form, CommandAction(Command), TitleProperties.Text);
	
EndProcedure

Function NeighboringGrouping(Form, Command, Settings, GroupingOrder)
	
	Headers = ReportHeaders(Form);
	MinGroupingOrder = 0;
	MaxGroupingOrder = 0;
	
	For Each Properties In Headers Do
		If MaxGroupingOrder < Properties.Value.GroupingOrder Then
			MaxGroupingOrder = Properties.Value.GroupingOrder;
		EndIf;
		If MinGroupingOrder = 0
		 Or MinGroupingOrder > Properties.Value.GroupingOrder Then
			MinGroupingOrder = Properties.Value.GroupingOrder;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(MinGroupingOrder) Then
		Return Undefined;
	EndIf;
	
	Move = 0;
	While True Do
		Move = Move + 1;
		If CommandAction(Command) = "MoveFieldUp" Then 
			TheOrderOfTheNeighboringGrouping = GroupingOrder - Move;
		Else
			TheOrderOfTheNeighboringGrouping = GroupingOrder + Move;
		EndIf;
		If TheOrderOfTheNeighboringGrouping < MinGroupingOrder
		 Or TheOrderOfTheNeighboringGrouping > MaxGroupingOrder Then
			Break;
		EndIf;
		
		For Each Properties In Headers Do 
			If Properties.Value.GroupingOrder = TheOrderOfTheNeighboringGrouping Then 
				Return Settings.GetObjectByID(Properties.Value.GroupingID);
			EndIf;
		EndDo;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function IndexOfTheSelectedField(SourceFieldIndex, FinalCollectionOfFields, Field, MovementParameters)
	
	Boundary = FinalCollectionOfFields.Items.Count();
	
	NewField = ReportsOptionsInternalClientServer.ReportField(FinalCollectionOfFields, Field);
	AvailableField = FinalCollectionOfFields.SelectionAvailableFields.FindField(Field);
	
	If NewField <> Undefined Then 
		
		If MovementParameters.Response = Undefined Then 
			
			Handler = New NotifyDescription("ContinueMovingTheFieldVertically", ThisObject, MovementParameters);
			
			QuestionTextTemplate = NStr("en = 'The grouping already contains a similar field: %1.
				|Delete the field?';");
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				QuestionTextTemplate, ?(AvailableField = Undefined, Field, AvailableField.Title));
			
			ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNoCancel,, DialogReturnCode.Yes);
			
			Return Undefined;
			
		ElsIf MovementParameters.Response = DialogReturnCode.Yes Then 
			
			FinalCollectionOfFields.Items.Delete(NewField);
			
		EndIf;
		
	EndIf;
	
	For Each Item In FinalCollectionOfFields.Items Do 
		
		If TypeOf(Item) = Type("DataCompositionAutoSelectedField")
			Or TypeOf(Item) = Type("DataCompositionSelectedFieldGroup") Then 
			
			Continue;
		EndIf;
		
		AvailableField = FinalCollectionOfFields.SelectionAvailableFields.FindField(Item.Field);
		
		If AvailableField <> Undefined
			And AvailableField.Resource Then 
			
			Boundary = FinalCollectionOfFields.Items.IndexOf(Item);
			Break;
			
		EndIf;
		
	EndDo;
	
	Return ?(SourceFieldIndex < Boundary, SourceFieldIndex, Boundary);
	
EndFunction

Procedure ContinueMovingTheFieldVertically(Response, MovementParameters) Export 
	
	If Response = DialogReturnCode.Yes
		Or Response = DialogReturnCode.No Then 
		
		MoveTheFieldVertically(MovementParameters.Form, MovementParameters.Command, Response);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region AdditionalDetailProcessing

// Parameters:
//  Form - ClientApplicationForm
//  Area - SpreadsheetDocumentRange
//          - SpreadsheetDocumentDrawing
//  FieldName - String
//
// Returns:
//  Structure:
//    * ThisIsTheTitle - Boolean
//
Function PropertiesOfTheDecryptionArea(Form, Area, FieldName)
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
	TitleProperties = ResultProperties.Headers[Area.Name]; // See ReportsOptionsInternal.StandardReportHeaderProperties
	
	AreaProperties = New Structure;
	AreaProperties.Insert("ThisIsTheTitle", TypeOf(TitleProperties) = Type("Structure"));
	AreaProperties.Insert("TitleProperties", TitleProperties);
	
	If AreaProperties.ThisIsTheTitle Or TypeOf(Area) = Type("SpreadsheetDocumentDrawing") Then
		Return AreaProperties;
	EndIf;
	
	SectionOrder = 0;
	BorderOfTheCurrentSection = 0;
	
	For Each Boundary In ResultProperties.TheBoundariesOfThePartitions Do 
		
		SectionOrder = SectionOrder + 1;
		
		If Area.Top >= BorderOfTheCurrentSection
			And Area.Top < Boundary.Value Then 
			
			Break;
		EndIf;
		
		BorderOfTheCurrentSection = Boundary.Value;
		
	EndDo;
	
	Field = New DataCompositionField(FieldName);
	
	For Each Item In ResultProperties.Headers Do 
		
		TitleProperties = Item.Value;
		
		If TitleProperties.SectionOrder = SectionOrder
			And TitleProperties.Field = Field
			And TitleProperties.Left = Area.Left Then 
			
			AreaProperties.TitleProperties = TitleProperties;
			Return AreaProperties;
			
		EndIf;
		
	EndDo;
	
	Return AreaProperties;
	
EndFunction

#Region ContextMenu

Function HeadingAreaContextMenu()
	
	ContextMenu = New ValueList;
	ContextMenu.Add(DataCompositionDetailsProcessingAction.OpenValue, NStr("en = 'Open';"));
	
	// Filter.
	ContextMenu.Add("DisableFilter", NStr("en = 'Clear filter';"));
	ContextMenu.Add("FilterCommand", NStr("en = 'Filter…';"),, PictureLib.DataCompositionFilter);
	
	// Sort.
	ContextMenu.Add(DataCompositionSortDirection.Asc, NStr("en = 'Sort ascending';"),, PictureLib.SortRowsAsc);
	ContextMenu.Add(DataCompositionSortDirection.Desc, NStr("en = 'Sort descending';"),, PictureLib.SortRowsDesc);
	
	// Apply appearance.
	DesignSubmenu = New ValueList;
	DesignSubmenu.Add("SetRowHeight", NStr("en = 'Row height…';"),, PictureLib.RowHeight);
	DesignSubmenu.Add("SetColumnWidth", NStr("en = 'Column width…';"),, PictureLib.ColumnWidth);
	
	ContextMenu.Add(DesignSubmenu, NStr("en = 'Format';"),, PictureLib.DataCompositionConditionalAppearance);
	
	Return ContextMenu;
	
EndFunction

Function DataAreaContextMenu(TitleProperties, AvailableCompareTypes)
	
	ContextMenu = New ValueList;
	ContextMenu.Add(DataCompositionDetailsProcessingAction.OpenValue, NStr("en = 'Open';"));
	
	If TypeOf(TitleProperties) <> Type("Structure") 
	   Or TitleProperties.SectionOrder <> 1 Then
		Return ContextMenu;
	EndIf;
	
	DesignImages = New Structure;
	DesignImages.Insert("HighlightInRed", PictureLib["AppearanceCircleRed"]);
	DesignImages.Insert("HighlightInYellow", PictureLib["AppearanceCircleYellow"]);
	DesignImages.Insert("HighlightInGreen", PictureLib["AppearanceCircleGreen"]);
	
	// Filter.
	SpecifyTheAvailableTypesOfComparison(AvailableCompareTypes);
	ContextMenu.Add(AvailableCompareTypes, NStr("en = 'Filter';"),, PictureLib.DataCompositionFilter);
	
	// Sort.
	ContextMenu.Add(DataCompositionSortDirection.Asc, NStr("en = 'Sort ascending';"),, PictureLib.SortRowsAsc);
	ContextMenu.Add(DataCompositionSortDirection.Desc, NStr("en = 'Sort descending';"),, PictureLib.SortRowsDesc);
	
	// Apply appearance.
	DesignSubmenu = New ValueList;
	
	DesignSubmenu.Add("ClearAppearance", NStr("en = 'Clear appearance';"));
	DesignSubmenu.Add("HighlightInRed", NStr("en = 'Red';"),, DesignImages.HighlightInRed);
	DesignSubmenu.Add("HighlightInYellow", NStr("en = 'Yellow';"),, DesignImages.HighlightInYellow);
	DesignSubmenu.Add("HighlightInGreen", NStr("en = 'Green';"),, DesignImages.HighlightInGreen);
	DesignSubmenu.Add("FormatNegativeValues", NStr("en = 'Negative in red';"));
	DesignSubmenu.Add("FormatPositiveValues", NStr("en = 'Positive in green';"));
	DesignSubmenu.Add("SetRowHeight", NStr("en = 'Row height…';"),, PictureLib.RowHeight);
	DesignSubmenu.Add("SetColumnWidth", NStr("en = 'Column width…';"),, PictureLib.ColumnWidth);
	DesignSubmenu.Add("ApplyAppearanceMore", NStr("en = 'More…';"));
	
	ContextMenu.Add(DesignSubmenu, NStr("en = 'Format';"),, PictureLib.DataCompositionConditionalAppearance);
	
	// Decrypt.
	ContextMenu.Add("DecodeByDetailedRecords", NStr("en = 'Drill down by detailed records';"));
	
	Return ContextMenu;
	
EndFunction

Procedure SpecifyTheAvailableTypesOfComparison(AvailableCompareTypes)
	
	UnavailableTypesOfComparison = New Array;
	UnavailableTypesOfComparison.Add(DataCompositionComparisonType.InList);
	UnavailableTypesOfComparison.Add(DataCompositionComparisonType.NotInList);
	UnavailableTypesOfComparison.Add(DataCompositionComparisonType.InListByHierarchy);
	UnavailableTypesOfComparison.Add(DataCompositionComparisonType.NotInListByHierarchy);
	
	For Each Kind In UnavailableTypesOfComparison Do 
		
		FoundView = AvailableCompareTypes.FindByValue(Kind);
		
		If FoundView <> Undefined Then 
			AvailableCompareTypes.Delete(FoundView);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Details

Procedure ExecuteDecryption(ExecutedAction, ChosenActionParameter, AdditionalParameters) Export 
	
	If ExecutedAction = Undefined
		Or ExecutedAction = DataCompositionDetailsProcessingAction.None Then 
		
		Return;
	EndIf;
	
	Form = AdditionalParameters.Form;
	Data = AdditionalParameters.Data;
	AreaProperties = AdditionalParameters.AreaProperties;
	Menu = AdditionalParameters.Menu;
	
	If AreaProperties.ThisIsTheTitle Then 
		
		TitleProperties = AreaProperties.TitleProperties;
		
		If TypeOf(ExecutedAction) = Type("String")
			And TitleProperties.Property(ExecutedAction)
			And Not TitleProperties[ExecutedAction] Then 
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Action ""%1"" is unavailable';"), Menu.FindByValue(ExecutedAction));
			
			ShowMessageBox(, MessageText);
			
		EndIf;
		
		If StrFind(TitleProperties.GroupingID, "/column/") = 0 Then 
			Return;
		EndIf;
		
	EndIf;
	
	If TypeOf(ExecutedAction) = Type("String")
		And ExecutedAction = "DisableFilter" Then 
		
		DisableFilter(Form, AreaProperties.TitleProperties, Data);
		Return;
		
	EndIf;
	
	If TypeOf(ExecutedAction) = Type("DataCompositionComparisonType")
		Or TypeOf(ExecutedAction) = Type("String") And StrStartsWith(ExecutedAction, "FilterCommand") Then 
		
		FilterCommand(Form, ExecutedAction, AreaProperties.TitleProperties, Data);
		Return;
		
	EndIf;
	
	If TypeOf(ExecutedAction) = Type("DataCompositionSortDirection") Then 
		
		If ExecutedAction = DataCompositionSortDirection.Asc Then 
			Command = Form.Commands.Find("SortAsc");
		Else
			Command = Form.Commands.Find("SortDesc");
		EndIf;
		
		Sort(Form, Command, AreaProperties.TitleProperties);
		Return;
		
	EndIf;
	
	If TypeOf(ExecutedAction) = Type("String")
		And ExecutedAction = "ClearAppearance" Then 
		
		ClearAppearance(Form, AreaProperties.TitleProperties);
		Return;
		
	EndIf;
	
	If TypeOf(ExecutedAction) = Type("String")
		And (ExecutedAction = "HighlightInRed"
		Or ExecutedAction = "HighlightInYellow"
		Or ExecutedAction = "HighlightInGreen"
		Or ExecutedAction = "FormatNegativeValues"
		Or ExecutedAction = "FormatPositiveValues"
		Or ExecutedAction = "SetRowHeight"
		Or ExecutedAction = "SetColumnWidth"
		Or ExecutedAction = "ApplyAppearanceMore") Then 
		
		Command = Form.Commands.Find(ExecutedAction);
		
		If Command = Undefined Then
			Command = ExecutedAction;
		EndIf;
		
		If ExecutedAction = "HighlightInRed"
			Or ExecutedAction = "FormatNegativeValues" Then 
			
			HighlightInRed(Form, Command, AreaProperties.TitleProperties, Data.Values);
			
		ElsIf ExecutedAction = "HighlightInYellow" Then 
			
			HighlightInYellow(Form, Command, AreaProperties.TitleProperties, Data.Values);
			
		ElsIf ExecutedAction = "HighlightInGreen"
			Or ExecutedAction = "FormatPositiveValues" Then 
			
			HighlightInGreen(Form, Command, AreaProperties.TitleProperties, Data.Values);
			
		ElsIf ExecutedAction = "SetRowHeight" Then 
			
			SetRowHeight(Form, Command, AreaProperties.TitleProperties);
			
		ElsIf ExecutedAction = "SetColumnWidth" Then 
			
			SetColumnWidth(Form, Command, AreaProperties.TitleProperties);
			
		ElsIf ExecutedAction = "ApplyAppearanceMore" Then 
			
			ApplyAppearanceMore(Form, Command, AreaProperties.TitleProperties, Data.Values);
			
		EndIf;
		
		Return;
		
	EndIf;
	
	If ExecutedAction = DataCompositionDetailsProcessingAction.OpenValue Then
		
		ShowValue(, Data.Value);
		Return;
		
	EndIf;
	
	If ExecutedAction =  "DecodeByDetailedRecords" Then 
		ChosenActionParameter = New DataCompositionSettings;
		DataCompositionGroup = ChosenActionParameter.Structure.Add(Type("DataCompositionGroup"));
		DataCompositionGroup.Name = "Details";
		
		AdditionalParameters.Insert("Settings", ChosenActionParameter);
		OpenReportForm(Form, AdditionalParameters);
		Return;
	EndIf;
	
	If ExecutedAction = DataCompositionDetailsProcessingAction.DrillDown Then
		
		AdditionalParameters.Insert("Settings", ChosenActionParameter);
		OpenReportForm(Form, AdditionalParameters);
		
	EndIf;
	
EndProcedure

Procedure OpenReportForm(Form, OpeningParameters)
	
	ReportSettings = Form.ReportSettings;
	Details = OpeningParameters.Details;
	
	Details = New DataCompositionDetailsProcessDescription(
		Form.ReportDetailsData, OpeningParameters.Details, OpeningParameters.Settings); 
	
	VariantPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 (Details)';"), Form.CurrentVariantPresentation);
	
	FormParameters = New Structure;
	FormParameters.Insert("Details", Details);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("VariantPresentation", VariantPresentation);
	FormParameters.Insert("ReportSettings", ReportSettings);
	
	If OpeningParameters.Property("Filter")
		And TypeOf(OpeningParameters.Filter) = Type("Structure") Then 
		
		FormParameters.Insert("Filter", OpeningParameters.Filter);
	EndIf;
	
	OpenForm(ReportSettings.FullName + ".Form", FormParameters, Form, Form.UUID);
	
EndProcedure

#EndRegion

#EndRegion

#Region Common

// Parameters:
//  Form - ClientApplicationForm
//  IsWithoutAutoFields - Boolean
//
// Returns:
//  DataCompositionSettingsComposer
//
Function ReportSettingsBuilder(Form, IsWithoutAutoFields = False)
	
	If StrEndsWith(Form.FormName, "ContextReportSetting") Then 
		
		SettingsComposer = Form.SettingsComposer;
		If IsWithoutAutoFields Then 
			SettingsComposer.ExpandAutoFields();
		EndIf;
	Else
		ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
		ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
		
		If IsWithoutAutoFields Then
			SettingsComposer = ResultProperties.SettingsComposerWithoutAutoFields;
		Else
			SettingsComposer = ResultProperties.SettingsComposer;
		EndIf;
	EndIf;
	
	Return SettingsComposer;
	
EndFunction

// Parameters:
//   Form - ClientApplicationForm
//   IDOfTheSettings - DataCompositionID
//                         - Undefined
//   IsWithoutAutoFields - Boolean
//
// Returns:
//  DataCompositionSettings
//
Function SettingsUsed(Form, IDOfTheSettings = Undefined, IsWithoutAutoFields = False)
	
	SettingsComposer = ReportSettingsBuilder(Form, IsWithoutAutoFields);
	SettingsUsed = SettingsComposer.Settings;
	
	If TypeOf(IDOfTheSettings) <> Type("DataCompositionID") Then 
		Return SettingsUsed;
	EndIf;
	
	SettingsByID = SettingsUsed.GetObjectByID(IDOfTheSettings);
	
	If SettingsByID = Undefined Then 
		Return SettingsUsed;
	EndIf;
	
	Return SettingsByID;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//
// Returns:
//  Map
//
Function ReportHeaders(Form)
	
	If StrEndsWith(Form.FormName, "Form")
		Or StrEndsWith(Form.FormName, "ReportForm")
		Or StrEndsWith(Form.FormName, "ContextReportSetting") Then 
		
		ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
		ResultProperties = ReportSettings.ResultProperties; // See ReportsOptionsInternal.PropertiesOfTheReportResult
		
		Return ResultProperties.Headers;
	EndIf;
	
	Return Form.ReportHeaders;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//
// Returns:
//   See ReportsOptionsInternal.StandardReportHeaderProperties
//
Function ReportTitleProperties(Form)
	
	If StrEndsWith(Form.FormName, "Form")
		Or StrEndsWith(Form.FormName, "ReportForm") Then 
		
		Headers = ReportHeaders(Form);
		Field = Form.ReportSpreadsheetDocument; // FormField, FormFieldExtensionForASpreadsheetDocumentField
		Area = Field.CurrentArea; // SpreadsheetDocumentRange
		
		Return Headers[Area.Name];
		
	EndIf;
	
	Return Form.TitleProperties;
	
EndFunction

Procedure SpecifyTheNameOfTheCollection(CollectionName, Handler)
	
	AdditionalParameters = Handler.AdditionalParameters;
	TitleProperties = AdditionalParameters.TitleProperties;
	
	If TitleProperties = Undefined Then 
		Return;
	EndIf;
	
	If TitleProperties.FieldType = Type("DataCompositionGroupField") Then 
		CollectionName = "GroupFields";
	EndIf;
	
	AdditionalParameters.Insert("CollectionName", CollectionName);
	
EndProcedure

Function SettingsStructureItemID(Form, SettingsNodeID)
	
	If SettingsNodeID <> Undefined Then 
		Return SettingsNodeID;
	EndIf;
	
	If StrEndsWith(Form.FormName, "Form")
		Or StrEndsWith(Form.FormName, "ReportForm") Then 
		
		Return Undefined;
	EndIf;
	
	Return Form.SettingsStructureItemID;
	
EndFunction

Function CommandAction(Command)
	
	If Command = Undefined Then 
		Return Undefined;
	EndIf;
	
	If TypeOf(Command) = Type("String") Then
		Return Command;
	EndIf;
	
	Return ?(ValueIsFilled(Command.Action), Command.Action, Command.Name);
	
EndFunction

Function DetailedRecords(StructureItems, DetailedRecords = Undefined)
	
	For Each Item In StructureItems Do 
		
		ElementType = TypeOf(Item);
		
		If ElementType = Type("DataCompositionGroup")
			Or ElementType = Type("DataCompositionTableGroup") Then 
			
			GroupFields = Item.GroupFields.Items;
			
			If GroupFields.Count() = 0 Then 
				DetailedRecords = Item;
			Else
				DetailedRecords(Item.Structure, DetailedRecords);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return DetailedRecords;
	
EndFunction

Procedure NotifyAboutTheCompletionOfTheContextSetting(Form, Action, CurrentField = Undefined)
	
	ThisIsAFormOfTheReport = StrEndsWith(Form.FormName, "Form")
		Or StrEndsWith(Form.FormName, "ReportForm");
	
	SettingsComposer = ReportSettingsBuilder(Form);
	SettingsUsed = SettingsComposer.Settings;
	
	AddSettingstoStack(Form, SettingsUsed, Action, CurrentField);
	
	OwnerID = ?(ThisIsAFormOfTheReport, Form.UUID, Form.FormOwner.UUID);
	
	Result = ResultContextSettings(SettingsComposer, Action, OwnerID);
	
	If ThisIsAFormOfTheReport Then 
		Notify(Action, Result, ThisObject);
	Else
		Form.NotifyChoice(Result);
	EndIf;
	
EndProcedure

// Parameters:
//  SettingsComposer - DataCompositionSettingsComposer
//  Action - String
//  OwnerID - UUID
//
// Returns:
//   Structure:
//     * Action - String
//     * OwnerID - UUID
//     * SettingsComposer - DataCompositionSettingsComposer
//     * Regenerate - Boolean
//     * VariantModified - Boolean
//     * UserSettingsModified - Boolean
//     * ResetCustomSettings - Boolean
//
Function ResultContextSettings(SettingsComposer, Action, OwnerID) Export 
	
	Result = New Structure;
	Result.Insert("DCSettingsComposer", SettingsComposer);
	Result.Insert("Action", Action);
	Result.Insert("OwnerID", OwnerID);
	Result.Insert("Regenerate", False);
	Result.Insert("VariantModified", True);
	Result.Insert("UserSettingsModified", True);
	Result.Insert("ResetCustomSettings", True);
	
	Return Result;
	
EndFunction

Function ContextConfigurationEvents()
	
	Events = New Map;
	Events.Insert("GroupBySelectedField", True);
	
	Events.Insert("InsertFieldLeft", True);
	Events.Insert("InsertFieldRight", True);
	Events.Insert("InsertGroupAbove", True);
	Events.Insert("InsertGroupBelow", True);
	
	Events.Insert("MoveFieldLeft", True);
	Events.Insert("MoveFieldRight", True);
	Events.Insert("MoveFieldUp", True);
	Events.Insert("MoveFieldDown", True);
	
	Events.Insert("HideField", True);
	Events.Insert("RenameField", True);
	
	Events.Insert("DisableFilter", True);
	Events.Insert("FilterCommand", True);
	Events.Insert("FilterAndGenerate", True);
	
	Events.Insert("SortAsc", True);
	Events.Insert("SortDesc", True);
	
	Events.Insert("ClearAppearance", True);
	
	Events.Insert("HighlightInRed", True);
	Events.Insert("HighlightInYellow", True);
	Events.Insert("HighlightInGreen", True);
	
	Events.Insert("FormatNegativeValues", True);
	Events.Insert("FormatPositiveValues", True);
	
	Events.Insert("SetRowHeight", True);
	Events.Insert("SetColumnWidth", True);
	
	Events.Insert("ApplyAppearanceMore", True);
	
	Return Events;
	
EndFunction

Function TheActionIsAvailable(Form, Command = Undefined, TitleProperties = Undefined)
	
	If TitleProperties = Undefined Then
		TitleProperties = ReportTitleProperties(Form);
	EndIf;
	
	CommandAction = CommandAction(Command);
	
	If TypeOf(TitleProperties) <> Type("Structure")
		Or CommandAction <> Undefined And Not TitleProperties[CommandAction] Then 
		
		ShowMessageBox(, NStr("en = 'Action is unavailable';"));
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

Function ActionOnTheFieldIsAvailable(Action, TitleProperties)
	
	If Not TitleProperties[Action] Then 
		
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Action is unavailable for the %1 field';"), TitleProperties.Text);
		
		ShowMessageBox(, WarningText);
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure AskAboutUserNotification(NotifyDescription, UsersCount) Export 
	
	RepresentationOfTheNumberOfUsers = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
		NStr("en = '; %1 user; ; %1 users; %1 users; %1 users';"),
		UsersCount);
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Do you want to notify in chat %1 that this option will be displayed on their report panel?';"),
		RepresentationOfTheNumberOfUsers);
	
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.No);
	
EndProcedure

Procedure AddFormulas(Settings, FieldsCollection, DescriptionOfFormulas) Export 
	
	For Each FormulaDescription In DescriptionOfFormulas Do 
		AddFormula(Settings, FieldsCollection, FormulaDescription);
	EndDo;
	
EndProcedure

Procedure AddFormula(Settings, FieldsCollection, FormulaDescription) Export 
	
	ThisIsCustomDataLayoutExpressionField = TypeOf(FormulaDescription) = Type("DataCompositionUserFieldExpression");
	If Not ThisIsCustomDataLayoutExpressionField And (TypeOf(FormulaDescription) <> Type("Structure")
		Or Not FormulaDescription.Property("Formula")) Then
		Return; 
	EndIf;
		
	If ThisIsCustomDataLayoutExpressionField Then
		DataPath = FormulaDescription.DataPath;
		FormulaDescription = DescriptionOfTheFormulaAccordingToTheSample(FormulaDescription);
	EndIf;
	Formulae = Settings.UserFields.Items;
	
	If ValueIsFilled(DataPath) Then 
		Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(Settings, DataPath);
	Else
		Formula = TheFormulaForTheExpression(Formulae, FormulaDescription.Formula);
	EndIf;
	
	If Formula = Undefined Then 
		Formula = Formulae.Add(Type("DataCompositionUserFieldExpression"));
	EndIf;
	
	AdditionalParameters = New Structure("FieldsCollection, Formula", FieldsCollection, Formula);
	SetFormulaProperties(FormulaDescription, AdditionalParameters);
	
	FormulaDescription = FieldsCollection.FindField(New DataCompositionField(Formula.DataPath));
	SetTotalRecordExpression(Formula, FormulaDescription);
	
EndProcedure

Function TheFormulaForTheExpression(Formulae, Expression)
	
	For Each Formula In Formulae Do 
		
		If TypeOf(Formula) <> Type("DataCompositionUserFieldExpression") Then
			Continue;
		EndIf;

		If TrimAll(Expression) = Formula.GetDetailRecordExpression() Then 
			Return Formula;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure ChangeFormula(Form, Settings, DataPath, CollectionName = "SelectionAvailableFields") Export 
	
	Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(Settings, DataPath);
	
	If TypeOf(Formula) <> Type("DataCompositionUserFieldExpression") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'You can edit field ""%1"" in the form of the settings for a technician on the User-defined fields tab';"),
			Formula.Title);
		
		ShowMessageBox(Undefined, MessageText);
		Return;
	EndIf;
	
	FormulaEditingOptions = FormulasConstructorClient.FormulaEditingOptions();
	FormulaEditingOptions.Operands = Form.ReportSettings.SchemaURL;
	FormulaEditingOptions.OperandsDCSCollectionName = CollectionName;
	FormulaEditingOptions.Formula = Formula.GetDetailRecordExpression();
	FormulaEditingOptions.Description = Formula.Title;
	FormulaEditingOptions.ForQuery = True;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("FieldsCollection", Settings.SelectionAvailableFields);
	AdditionalParameters.Insert("Formula", Formula);
	
	Handler = New NotifyDescription("AfterChangingTheFormula", Form, AdditionalParameters);
	FormulasConstructorClient.StartEditingTheFormula(FormulaEditingOptions, Handler);
	
EndProcedure

// Parameters:
//  FormulaDescription - DataCompositionAvailableField
//                  - Structure:
//                      * Formula - String
//                      * FormulaPresentation - String
//                      * Description - String
//  AdditionalParameters - Structure:
//    * Formula - DataCompositionUserFieldExpression
//    * FieldsCollection - DataCompositionAvailableFields
//  
Procedure AfterChangingTheFormula(FormulaDescription, AdditionalParameters) Export 
	
	If TypeOf(FormulaDescription) <> Type("Structure")
		Or Not FormulaDescription.Property("Formula") Then 
		
		Return;
	EndIf;
	
	SetFormulaProperties(FormulaDescription, AdditionalParameters);
	
EndProcedure

// Parameters:
//  Pattern - DataCompositionUserFieldExpression
// 
// Returns:
//  Structure:
//    * Formula - String
//    * FormulaPresentation - String
//    * Description - String
//
Function DescriptionOfTheFormulaAccordingToTheSample(Pattern)
	
	FormulaDescription = New Structure;
	FormulaDescription.Insert("Formula", Pattern.GetDetailRecordExpression());
	FormulaDescription.Insert("FormulaPresentation", Pattern.GetDetailRecordExpressionPresentation());
	FormulaDescription.Insert("Description", Pattern.Title);
	
	Return FormulaDescription;
	
EndFunction

// Parameters:
//  FormulaDescription - DataCompositionAvailableField
//                  - Structure:
//                      * Formula - String
//                      * FormulaPresentation - String
//                      * Description - String
//  AdditionalParameters - Structure:
//    * Formula - DataCompositionUserFieldExpression
//    * FieldsCollection - DataCompositionAvailableFields
//
Procedure SetFormulaProperties(FormulaDescription, AdditionalParameters) 
	
	Expression = TrimAll(FormulaDescription.Formula);
	RepresentationOfTheExpression = TrimAll(FormulaDescription.FormulaPresentation);
	Title = TrimAll(FormulaDescription.Description);
	
	Formula = AdditionalParameters.Formula;
	Formula.SetDetailRecordExpression(Expression);
	Formula.Title = ?(ValueIsFilled(Title), Title, RepresentationOfTheExpression);
	
	FormulaDescription = AdditionalParameters.FieldsCollection.FindField(New DataCompositionField(Formula.DataPath));
	SetTotalRecordExpression(Formula, FormulaDescription);
	
EndProcedure

Procedure SetTotalRecordExpression(Formula, FormulaDescription)
	
	If FormulaDescription = Undefined
		Or FormulaDescription.Type.Types().Count() > 1
		Or Not FormulaDescription.Type.ContainsType(Type("Number")) Then 
		
		Return;
	EndIf;
	
	DetailedRecordsExpression = Formula.GetDetailRecordExpression();
	
	If IsBlankString(DetailedRecordsExpression) Then
		Return;
	EndIf;
	
	If ExpressionContainsAggregateFunction(DetailedRecordsExpression) Then
		TotalRecordsExpression = DetailedRecordsExpression;
	Else
		TotalRecordsExpression = StringFunctionsClientServer.SubstituteParametersToString(
			"Sum(%1)", DetailedRecordsExpression);
	EndIf;
	
	Formula.SetExpressions(DetailedRecordsExpression, TotalRecordsExpression);
	
EndProcedure

Function ExpressionContainsAggregateFunction(Val Expression)
	
	Expression = Upper(StrConcat(StrSplit(Expression, " " + Chars.Tab + Chars.LF, False), ""));
	
	If StrFind(Expression, "SUM(")
		Or StrFind(Expression, "COUNT(")
		Or StrFind(Expression, "MAX(")
		Or StrFind(Expression, "MIN(")
		Or StrFind(Expression, "AVG(") Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ParametersForSavingAReportVariantToAFile(Form) Export 
	
	SavingParameters = New Structure();
	
	ReportSettings = Form.ReportSettings;
	SettingsComposer = Form.Report.SettingsComposer;
	
	SavingParameters.Insert("Ref",  ReportSettings.OptionRef);
	SavingParameters.Insert("ReportName",  ReportSettings.FullName);
	SavingParameters.Insert("Settings",  SettingsComposer.Settings);
	SavingParameters.Insert("VariantKey",  Form.CurrentVariantKey);
	SavingParameters.Insert("VariantPresentation",  Form.CurrentVariantPresentation);
	SavingParameters.Insert("UserSettingsKey",  Form.CurrentUserSettingsKey);
	SavingParameters.Insert("UserSettingsPresentation",  Form.CurrentUserSettingsPresentation);
	
	Return SavingParameters;
	
EndFunction

Function ThisReportForm(Form)
	
	Return StrEndsWith(Form.FormName, "Form")
		Or StrEndsWith(Form.FormName, "ReportForm");
	
EndFunction

#Region StackSettings

Procedure AddSettingstoStack(Form, Settings, Action, CurrentField = Undefined) Export 
	
	StackSettings = StackReportSettings(Form);
	
	If StackSettings = Undefined Then 
		Return;
	EndIf;
	
	RemoveStackBreakSettings(StackSettings);
	ResetStackNotesSettings(StackSettings);
	
	Record = StackSettings.Add();
	Record.Order = StackSettings.Count();
	Record.Check = True;
	Record.Settings = Settings;
	Record.Action = Action;
	Record.PresentationAction = ViewActionStackSettings(Form, Record, CurrentField);
	
	DeleteRedundantStackEntriesSettings(StackSettings);
	
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//  WriteStackSettings - FormDataCollectionItem:
//    * Action - String
//    * Settings - DataCompositionSettings
//    * Check - Boolean
//    * Order - Number
//    * PresentationAction - String
//  CurrentField - Undefined
//              - String
// 
// Returns:
//  String
//
Function ViewActionStackSettings(Form, WriteStackSettings, CurrentField)
	
	Action = WriteStackSettings.Action;
	
	If CurrentField = Undefined Then 
		
		TitleProperties = ReportTitleProperties(Form);
		CurrentField = ?(TitleProperties = Undefined, Undefined, TitleProperties.Text);
		
	EndIf;
	
	ReportSettings = Form.ReportSettings; // See ReportsOptions.ReportFormSettings
	EventPresentation = StrReplace(ReportSettings.EventsSettings[Action], "...", "");
	
	If ValueIsFilled(CurrentField) Then 
		
		Return StringFunctionsClientServer.SubstituteParametersToString(
			"%1 '%2'", EventPresentation, CurrentField);
		
	EndIf;
	
	Return EventPresentation;

EndFunction

Function StackReportSettings(Form)
	
	If ThisReportForm(Form) Then 
		Return Form.StackSettings;
	EndIf;
	
	FormOwner = Form.FormOwner;
	
	If FormOwner <> Undefined
		And ThisReportForm(FormOwner) Then 
		
		Return FormOwner.StackSettings;
	EndIf;
	
	Return Undefined;
	
EndFunction

Procedure RemoveStackBreakSettings(StackSettings)
	
	NumberofStackSettings = StackSettings.Count();
	
	If NumberofStackSettings = 0 Then 
		Return;
	EndIf;
	
	StackSettings.Sort("Order Asc");
	
	CurrentStackSettings = StackSettings.FindRows(New Structure("Check", True));
	
	If CurrentStackSettings.Count() = 0 Then 
		Return;
	EndIf;
	
	IndexCurrentSettings = StackSettings.IndexOf(CurrentStackSettings[0]);
	StackBorderSettings = NumberofStackSettings - 1;
	
	If IndexCurrentSettings = StackBorderSettings Then 
		Return;
	EndIf;
	
	While StackBorderSettings > IndexCurrentSettings Do 
		
		StackSettings.Delete(StackBorderSettings);
		StackBorderSettings = StackBorderSettings - 1;
		
	EndDo;
	
EndProcedure

Procedure ResetStackNotesSettings(StackSettings) Export 
	
	For Each Record In StackSettings Do 
		Record.Check = False;
	EndDo;
	
EndProcedure

Procedure DeleteRedundantStackEntriesSettings(StackSettings)
	
	If StackSettings.Count() <= ReportsOptionsInternalClientServer.MaxStackSizeSettings() Then 
		Return;
	EndIf;
	
	StackSettings.Delete(0);
	
	Order = 0;
	
	For Each Record In StackSettings Do 
		
		Order = Order + 1;
		Record.Order = Order;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion
