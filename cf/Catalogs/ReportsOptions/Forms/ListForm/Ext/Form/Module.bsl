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
	ClientParameters = ReportsOptions.ClientParameters();
	IncludingSubordinates = True;

	ValueTree = ReportsOptionsCached.CurrentUserSubsystems().Tree.Copy();
	SubsystemsTreeFillFullPresentation(ValueTree.Rows);

	TreeRow = ValueTree.Rows.Add();
	TreeRow.Name            = "NonIncludedToSections";
	TreeRow.FullName      = "NonIncludedToSections";
	TreeRow.Presentation  = NStr("en = 'Not included in sections';");
	TreeRow.Ref   = Catalogs.MetadataObjectIDs.EmptyRef();

	ValueToFormAttribute(ValueTree, "SubsystemsTree");

	SubsystemsTreeCurrentRow = -1;
	Items.SubsystemsTree.CurrentRow = 0;
	If Parameters.ChoiceMode = True Then
		FormOperationMode = "Case";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.Representation = TableRepresentation.List;
	ElsIf Parameters.SectionReference <> Undefined Then
		FormOperationMode = "AllReportsInSection";
		ParentItems = New Array; // Array of FormDataTreeItem
		ParentItems.Add(SubsystemsTree.GetItems()[0]);

		While ParentItems.Count() > 0 Do
			ParentItem = SubsystemsTreeItem(ParentItems);
			SubordinateItems = ParentItem.GetItems();
			ParentItems.Delete(0);

			For Each SubordinateItem In SubordinateItems Do
				If SubordinateItem.Ref = Parameters.SectionReference Then
					Items.SubsystemsTree.CurrentRow = SubordinateItem.GetID();
					ParentItems.Clear();
					Break;
				EndIf;

				ParentItems.Add(SubordinateItem);
			EndDo;
		EndDo;
	Else
		FormOperationMode = "List";
		CommonClientServer.SetFormItemProperty(Items, "Change", "Representation",
			ButtonRepresentation.PictureAndText);
		CommonClientServer.SetFormItemProperty(Items, "PlaceInSections",
			"OnlyInAllActions", False);
	EndIf;

	GlobalSettings = ReportsOptions.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;

	WindowOptionsKey = FormOperationMode;
	PurposeUseKey = FormOperationMode;

	SetListPropertyByFormParameter("ChoiceMode");
	SetListPropertyByFormParameter("ChoiceFoldersAndItems");
	SetListPropertyByFormParameter("MultipleChoice");
	SetListPropertyByFormParameter("CurrentRow");

	Items.Select.DefaultButton = Parameters.ChoiceMode;
	Items.Select.Visible = Parameters.ChoiceMode;
	Items.FilterReportType.Visible = ReportsOptions.FullRightsToOptions();

	ChoiceList = Items.FilterReportType.ChoiceList;
	ChoiceList.Add(1, NStr("en = 'All but external reports';"));
	ChoiceList.Add(Enums.ReportsTypes.BuiltIn, NStr("en = 'Integrated reports';"));
	ChoiceList.Add(Enums.ReportsTypes.Extension, NStr("en = 'Extensions';"));
	ChoiceList.Add(Enums.ReportsTypes.Additional, NStr("en = 'Additional reports';"));
	ChoiceList.Add(Enums.ReportsTypes.External, NStr("en = 'External reports';"));

	SearchString = Parameters.SearchString;
	If Parameters.Filter.Property("ReportType", FilterReportType) Then
		Parameters.Filter.Delete("ReportType");
	EndIf;
	If Parameters.OptionsOnly Then
		CommonClientServer.SetDynamicListFilterItem(List, "VariantKey", "",
			DataCompositionComparisonType.NotEqual,,, DataCompositionSettingsItemViewMode.Normal);
	EndIf;

	PersonalListSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(), "Catalog.ReportsOptions.ListForm");
	If PersonalListSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(PersonalListSettings.SearchStringSelectionList);
	EndIf;
	ListProperties = Common.DynamicListPropertiesStructure();
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();

	If CurrentLanguageSuffix <> Undefined Then

		If ValueIsFilled(CurrentLanguageSuffix) Then

			ListProperties.QueryText = StrReplace(List.QueryText, "ReportsOptions.Description",
				"ReportsOptions.Description" + CurrentLanguageSuffix);
			ListProperties.QueryText = StrReplace(ListProperties.QueryText, "ReportsOptions.LongDesc",
				"ReportsOptions.LongDesc" + CurrentLanguageSuffix);

			ListProperties.QueryText = StrReplace(ListProperties.QueryText, "ConfigurationOptions.Description",
				"ConfigurationOptions.Description" + CurrentLanguageSuffix);
			ListProperties.QueryText = StrReplace(ListProperties.QueryText, "ConfigurationOptions.LongDesc",
				"ConfigurationOptions.LongDesc" + CurrentLanguageSuffix);

		EndIf;

	Else
		ListProperties.QueryText = ViewQueryTextInOtherLanguagesInTabularPart();
	EndIf;

	DescriptionFieldsReportName =
	"CASE
	|	WHEN VALUETYPE(ReportsOptionsOverridable.Report) = TYPE(Catalog.MetadataObjectIDs)
	|		THEN CAST(ReportsOptionsOverridable.Report AS Catalog.MetadataObjectIDs).Name
	|	WHEN VALUETYPE(ReportsOptionsOverridable.Report) = TYPE(Catalog.ExtensionObjectIDs)
	|		THEN CAST(ReportsOptionsOverridable.Report AS Catalog.ExtensionObjectIDs).Name
	|	ELSE SUBSTRING(CAST(ReportsOptionsOverridable.Report AS STRING(150)), 14, 137)
	|END";

	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportTableName = ModuleAdditionalReportsAndDataProcessors.AdditionalReportTableName();
		DescriptionFieldsReportName = StringFunctionsClientServer.SubstituteParametersToString("CASE
			|	WHEN VALUETYPE(ReportsOptionsOverridable.Report) = TYPE(Catalog.MetadataObjectIDs)
			|		THEN CAST(ReportsOptionsOverridable.Report AS Catalog.MetadataObjectIDs).Name
			|	WHEN VALUETYPE(ReportsOptionsOverridable.Report) = TYPE(Catalog.ExtensionObjectIDs)
			|		THEN CAST(ReportsOptionsOverridable.Report AS Catalog.ExtensionObjectIDs).Name
			|	WHEN VALUETYPE(ReportsOptionsOverridable.Report) = TYPE(%1)
			|		THEN CAST(ReportsOptionsOverridable.Report AS %1).ObjectName
			|	ELSE SUBSTRING(CAST(ReportsOptionsOverridable.Report AS STRING(150)), 14, 137)
			|END", AdditionalReportTableName);
	EndIf;

	If Not ValueIsFilled(ListProperties.QueryText) Then
		ListProperties.QueryText = List.QueryText;
	EndIf;

	ListProperties.QueryText = StrReplace(ListProperties.QueryText, "&ReportName", DescriptionFieldsReportName);

	Common.SetDynamicListProperties(Items.List, ListProperties);

	If CurrentLanguageSuffix = Undefined Then
		List.Parameters.SetParameterValue("LanguageCode", CurrentLanguage().LanguageCode);
	EndIf;

	List.Parameters.SetParameterValue("AvailableReports", ReportsOptions.CurrentUserReports());
	List.Parameters.SetParameterValue("DIsabledApplicationOptions",
		New Array(ReportsOptionsCached.DIsabledApplicationOptions()));
	List.Parameters.SetParameterValue("IsMainLanguage", Common.IsMainLanguage());
	List.Parameters.SetParameterValue("ExtensionsVersion", SessionParameters.ExtensionsVersion);

	CurrentItem = Items.List;

	ReportsOptions.ComplementFiltersFromStructure(List.SettingsComposer.Settings.Filter, Parameters.Filter);
	Parameters.Filter.Clear();

	UpdateListContent("OnCreateAtServer");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If FormOperationMode = "AllReportsInSection" Or FormOperationMode = "Case" Then
		Items.SubsystemsTree.Expand(SubsystemsTreeCurrentRow, True);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = ReportsOptionsClient.EventNameChangingOption() Or EventName = "Write_ConstantsSet"
	   Or EventName = "Write_ReportsOptions" Then

		SubsystemsTreeCurrentRow = -1;
		AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);

	ElsIf EventName = ReportsOptionsClient.NameOfTheEventForUpdatingReportVariantsFromFiles() Then
		SetTheSelectionBasedOnTheUpdatedReportsFromTheFiles(Parameter);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterReportTypeOnChange(Item)
	UpdateListContent();
EndProcedure

&AtClient
Procedure FilterReportTypeClearing(Item, StandardProcessing)
	StandardProcessing = False;
	FilterReportType = Undefined;
	UpdateListContent();
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	UpdateListContentClient("SearchStringOnChange");
EndProcedure

&AtClient
Procedure IncludingSubordinatesOnChange(Item)
	SubsystemsTreeCurrentRow = -1;
	AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeBeforeRowChange(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure SubsystemsTreeOnActivateRow(Item)
	AttachIdleHandler("SubsystemsTreeRowActivationHandler", 0.1, True);

#If MobileClient Then
	AttachIdleHandler("SetSubsystemsTreeTitle", 0.1, True);
	CurrentItem = Items.List;
#EndIf
EndProcedure

&AtClient
Procedure SubsystemsTreeDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;

	If String = Undefined Then
		Return;
	EndIf;

	PlacementParameters = PlacementParameters(DragParameters, String);
	If PlacementParameters = Undefined Then
		Return;
	EndIf;

	If PlacementParameters.Variants.Total = 1 Then
		If PlacementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("en = 'Do you want to add ""%1"" to %4?';");
		Else
			QuestionTemplate = NStr("en = 'Do you want to move %1 from %3 to %4?';");
		EndIf;
	Else
		If PlacementParameters.Action = "Copy" Then
			QuestionTemplate = NStr("en = 'Do you want to add %2 report options %1 to %4?';");
		Else
			QuestionTemplate = NStr("en = 'Do you want to move %2 report options %1 from %3 to %4?';");
		EndIf;
	EndIf;

	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QuestionTemplate, 
		PlacementParameters.Variants.Presentation, Format(PlacementParameters.Variants.Total, "NG=0"),
		PlacementParameters.Source.FullPresentation, PlacementParameters.Receiver.FullPresentation);

	Handler = New NotifyDescription("SubsystemsTreeDragCompletion", ThisObject, PlacementParameters);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes);

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	ReportsOptionsClient.ShowReportSettings(Items.List.CurrentRow);
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	If FormOperationMode = "AllReportsInSection" Then
		StandardProcessing = False;
		ReportsOptionsClient.OpenReportForm(ThisObject, Items.List.CurrentData);
	ElsIf FormOperationMode = "List" Then
		StandardProcessing = False;
		ReportsOptionsClient.ShowReportSettings(RowSelected);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExecuteSearch(Command)
	UpdateListContentClient("ExecuteSearch");
EndProcedure

&AtClient
Procedure Change(Command)
	ReportsOptionsClient.ShowReportSettings(Items.List.CurrentRow);
EndProcedure

&AtClient
Procedure SaveReportOptionToFile(Command)
	SelectedReportsOptions = Items.List.SelectedRows;

	If SelectedReportsOptions.Count() = 0 Then
		Return;
	EndIf;

	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SaveReportOptionToFile",
		New Structure("SelectedReportsOptions", SelectedReportsOptions), ThisObject);
EndProcedure

&AtClient
Procedure UpdateReportOptionFromFile(Command)

	SelectedReportsOptions = Items.List.SelectedRows;
	If SelectedReportsOptions.Count() = 0 Then
		Return;
	EndIf;

	ReportOptionProperties = ReportsOptionsClient.BaseReportOptionProperties();
	ReportOptionProperties.Ref = SelectedReportsOptions[0];
	ReportOptionProperties.VariantPresentation = String(SelectedReportsOptions[0]);
	ReportsOptionsClient.UpdateReportOptionFromFiles(ReportOptionProperties, UUID);

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DefineBehaviorInMobileClient()
	If Not Common.IsMobileClient() Then
		Return;
	EndIf;

	Items.SearchString.Width = 0;
	Items.SearchString.HorizontalStretch = Undefined;
	Items.SearchString.TitleLocation = FormItemTitleLocation.None;
	Items.SearchString.DropListButton = False;
	Items.ExecuteSearch.Representation = ButtonRepresentation.Picture;
EndProcedure

&AtServer
Procedure SubsystemsTreeFillFullPresentation(RowsSet, ParentPresentation = "")
	For Each TreeRow In RowsSet Do
		If IsBlankString(TreeRow.Name) Then
			TreeRow.FullPresentation = "";
		ElsIf IsBlankString(ParentPresentation) Then
			TreeRow.FullPresentation = TreeRow.Presentation;
		Else
			TreeRow.FullPresentation = ParentPresentation + "." + TreeRow.Presentation;
		EndIf;
		SubsystemsTreeFillFullPresentation(TreeRow.Rows, TreeRow.FullPresentation);
	EndDo;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.LongDesc.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.LongDesc");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;

	NoteTextColor = Metadata.StyleItems.NoteText;
	Item.Appearance.SetParameterValue("TextColor", NoteTextColor.Value);

EndProcedure

// Returns drag-and-drop parameters.
// 
// Parameters:
//  DragParameters - DragParameters
//  String - Number
//
// Returns:
//  - Undefined
//  - Structure:
//      * Variants - Structure:
//          ** Array - Array of FormDataTreeItem
//          ** Total - Number
//          ** Presentation - String
//    * Action - String
//    * Receiver - See RowDataProperties
//    * Source - See RowDataProperties
//
&AtClient
Function PlacementParameters(DragParameters, String)

	RowsCount = DragParameters.Value.Count();
	If RowsCount = 0 Then
		Return Undefined;
	EndIf;

	DestinationRow = SubsystemsTree.FindByID(String);
	If DestinationRow = Undefined Or DestinationRow.Priority = "" Then
		Return Undefined;
	EndIf;

	PlacementParameters = New Structure("Variants, Action, Receiver, Source");
	PlacementParameters.Variants = New Structure("Array, Total, Presentation");
	PlacementParameters.Variants.Array = DragParameters.Value;
	PlacementParameters.Variants.Total  = RowsCount;

	Receiver = RowDataProperties();
	FillPropertyValues(Receiver, DestinationRow);
	Receiver.Id = DestinationRow.GetID();

	PlacementParameters.Receiver = Receiver;

	SourceRow = Items.SubsystemsTree.CurrentData;
	Source = RowDataProperties();
	If SourceRow = Undefined Or SourceRow.Priority = "" Then
		PlacementParameters.Action = "Copy";
	Else
		FillPropertyValues(Source, SourceRow);
		Source.Id = SourceRow.GetID();
		If DragParameters.Action = DragAction.Copy Then
			PlacementParameters.Action = "Copy";
		Else
			PlacementParameters.Action = "Move";
		EndIf;
	EndIf;

	PlacementParameters.Source = Source;

	If Source.Ref = Receiver.Ref Then
		ShowMessageBox(, NStr("en = 'Selected report options already assigned to this section.';"));
		Return Undefined;
	EndIf;

	If PlacementParameters.Variants.Total = 1 Then
		PlacementParameters.Variants.Presentation = String(PlacementParameters.Variants.Array[0]);
	Else
		PlacementParameters.Variants.Presentation = "";
		For Each OptionRef In PlacementParameters.Variants.Array Do
			PlacementParameters.Variants.Presentation = PlacementParameters.Variants.Presentation 
				+ ?(PlacementParameters.Variants.Presentation = "", "", ", ") + String(OptionRef);

			If StrLen(PlacementParameters.Variants.Presentation) > 23 Then
				PlacementParameters.Variants.Presentation = Left(PlacementParameters.Variants.Presentation, 20) + "...";
				Break;
			EndIf;
		EndDo;
	EndIf;

	Return PlacementParameters;

EndFunction

// Row data property constructor.
// 
// Returns:
//  Structure:
//    * Ref - Undefined
//             - CatalogRef.ExtensionObjectIDs
//             - CatalogRef.MetadataObjectIDs
//    * FullPresentation - String
//    * Id - Number
//
&AtClient
Function RowDataProperties()

	Properties = New Structure;
	Properties.Insert("Ref", Undefined);
	Properties.Insert("FullPresentation", "");
	Properties.Insert("Id", 0);

	Return Properties;

EndFunction

// Drop handler.
//
// Parameters:
//  Response - DialogReturnCode
//  PlacementParameters - See PlacementParameters
//
&AtClient
Procedure SubsystemsTreeDragCompletion(Response, PlacementParameters) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	ExecutionResult = AssignOptionsToSubsystem(PlacementParameters);
	ReportsOptionsClient.UpdateOpenForms();

	If PlacementParameters.Variants.Total = ExecutionResult.Placed Then
		If PlacementParameters.Variants.Total = 1 Then
			If PlacementParameters.Action = "Move" Then
				Template = NStr("en = 'Report successfully moved to %1.';");
			Else
				Template = NStr("en = 'Report successfully added to %1.';");
			EndIf;
			Text = PlacementParameters.Variants.Presentation;
			Ref = GetURL(PlacementParameters.Variants.Array[0]);
		Else
			If PlacementParameters.Action = "Move" Then
				Template = NStr("en = 'Reports successfully moved to %1.';");
			Else
				Template = NStr("en = 'Reports successfully added to %1.';");
			EndIf;
			Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 report options.';"),
				Format(PlacementParameters.Variants.Total, "NZ=0; NG=0"));
			Ref = Undefined;
		EndIf;
		Template = StringFunctionsClientServer.SubstituteParametersToString(Template,
			PlacementParameters.Receiver.FullPresentation);
		ShowUserNotification(Template, Ref, Text);
	Else
		ErrorsText = "";
		If Not IsBlankString(ExecutionResult.CannotBePlaced) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF) 
				+ NStr("en = 'Cannot add to the command interface:';") + Chars.LF
				+ ExecutionResult.CannotBePlaced;
		EndIf;
		If Not IsBlankString(ExecutionResult.AlreadyAssigned) Then
			ErrorsText = ?(ErrorsText = "", "", ErrorsText + Chars.LF + Chars.LF) 
				+ NStr("en = 'Already added to this section:';") + Chars.LF + ExecutionResult.AlreadyAssigned;
		EndIf;

		If PlacementParameters.Action = "Move" Then
			Template = NStr("en = '%1 out of %2 report options have been moved.
						  |Details:
						  |%3';");
		Else
			Template = NStr("en = '%1 out of %2 report options have been added.
						  |Details:
						  |%3';");
		EndIf;

		StandardSubsystemsClient.ShowQuestionToUser(Undefined,
			StringFunctionsClientServer.SubstituteParametersToString(Template, ExecutionResult.Placed,
			PlacementParameters.Variants.Total, ErrorsText), QuestionDialogMode.OK);
	EndIf;

EndProcedure

&AtServer
Procedure SetListPropertyByFormParameter(Var_Key)

	If Parameters.Property(Var_Key) And ValueIsFilled(Parameters[Var_Key]) Then
		Items.List[Var_Key] = Parameters[Var_Key];
	EndIf;

EndProcedure

&AtServer
Procedure UpdateListContent(Val Event = "")
	PersonalSettingsChanged = False;
	If ValueIsFilled(SearchString) Then
		ChoiceList = Items.SearchString.ChoiceList;
		ListItem = ChoiceList.FindByValue(SearchString);
		If ListItem = Undefined Then
			ChoiceList.Insert(0, SearchString);
			PersonalSettingsChanged = True;
			If ChoiceList.Count() > 10 Then
				ChoiceList.Delete(10);
			EndIf;
		Else
			IndexOf = ChoiceList.IndexOf(ListItem);
			If IndexOf <> 0 Then
				ChoiceList.Move(IndexOf, -IndexOf);
				PersonalSettingsChanged = True;
			EndIf;
		EndIf;
		CurrentItem = Items.SearchString;
	EndIf;

	If Event = "SearchStringOnChange" And PersonalSettingsChanged Then
		PersonalListSettings = New Structure("SearchStringSelectionList");
		PersonalListSettings.SearchStringSelectionList = Items.SearchString.ChoiceList.UnloadValues();
		Common.CommonSettingsStorageSave(
			ReportsOptionsClientServer.FullSubsystemName(), "Catalog.ReportsOptions.ListForm",
			PersonalListSettings);
	EndIf;

	SubsystemsTreeCurrentRow = Items.SubsystemsTree.CurrentRow;

	TreeRow = SubsystemsTree.FindByID(SubsystemsTreeCurrentRow);
	If TreeRow = Undefined Then
		Return;
	EndIf;

	AllSubsystems = Not ValueIsFilled(TreeRow.FullName);

	SearchParameters = New Structure;
	If ValueIsFilled(SearchString) Then
		SearchParameters.Insert("SearchString", SearchString);
		Items.List.InitialTreeView = InitialTreeView.ExpandAllLevels;
	Else
		Items.List.InitialTreeView = InitialTreeView.NoExpand;
	EndIf;
	If Not AllSubsystems Or ValueIsFilled(SearchString) Then
		ReportsSubsystems = New Array;
		If Not AllSubsystems Then
			ReportsSubsystems.Add(TreeRow.Ref);
		EndIf;
		If AllSubsystems Or IncludingSubordinates Then
			AddRecursively(ReportsSubsystems, TreeRow.GetItems());
		EndIf;
		SearchParameters.Insert("Subsystems", ReportsSubsystems);
	EndIf;
	If ValueIsFilled(FilterReportType) Then
		ReportsTypes = New Array;
		If FilterReportType = 1 Then
			ReportsTypes.Add(Enums.ReportsTypes.BuiltIn);
			ReportsTypes.Add(Enums.ReportsTypes.Extension);
			ReportsTypes.Add(Enums.ReportsTypes.Additional);
		Else
			ReportsTypes.Add(FilterReportType);
		EndIf;
		SearchParameters.Insert("ReportsTypes", ReportsTypes);
	EndIf;

	HasFilterByOptions = SearchParameters.Count() > 0;
	SearchParameters.Insert("DeletionMark", False);
	SearchParameters.Insert("ExactFilterBySubsystems", Not AllSubsystems);

	SearchResult = ReportsOptions.FindReportsOptions(SearchParameters);
	List.Parameters.SetParameterValue("HasFilterByOptions", HasFilterByOptions);
	List.Parameters.SetParameterValue("UserOptions", SearchResult.References);

EndProcedure

&AtClient
Procedure SubsystemsTreeRowActivationHandler()
	If SubsystemsTreeCurrentRow <> Items.SubsystemsTree.CurrentRow Then
		UpdateListContent();
	EndIf;
EndProcedure

&AtClient
Procedure SetSubsystemsTreeTitle()
	Items.SectionsGroup.Title = ?(Items.SubsystemsTree.CurrentData = Undefined, 
		NStr("en = 'All sections';", CommonClient.DefaultLanguageCode()),
		Items.SubsystemsTree.CurrentData.Presentation);
EndProcedure

&AtServer
Procedure AddRecursively(SubsystemsArray, TreeRowsCollection)
	For Each TreeRow In TreeRowsCollection Do
		SubsystemsArray.Add(TreeRow.Ref);
		AddRecursively(SubsystemsArray, TreeRow.GetItems());
	EndDo;
EndProcedure

&AtServer
Procedure SubsystemsTreeWritePropertyToArray(TreeRowsArray, PropertyName, ReferencesArrray)
	For Each TreeRow In TreeRowsArray Do
		ReferencesArrray.Add(TreeRow[PropertyName]);
		SubsystemsTreeWritePropertyToArray(TreeRow.GetItems(), PropertyName, ReferencesArrray);
	EndDo;
EndProcedure

// Writes data about the report option location.
//
// Parameters:
//  PlacementParameters - See PlacementParameters
//
// Returns:
//  Structure:
//    * Placed - Number
//    * AlreadyAssigned - String
//    * CannotBePlaced - String
//
&AtServer
Function AssignOptionsToSubsystem(PlacementParameters)
	SubsystemsToExclude = New Array;
	If PlacementParameters.Action = "Move" Then
		Source = PlacementParameters.Source; // See RowDataProperties
		SourceRow = SubsystemsTree.FindByID(Source.Id);
		SubsystemsToExclude.Add(SourceRow.Ref);
		SubsystemsTreeWritePropertyToArray(SourceRow.GetItems(), "Ref", SubsystemsToExclude);
	EndIf;

	Placed = 0;
	AlreadyAssigned = "";
	CannotBePlaced = "";

	BeginTransaction();
	Try
		Block = New DataLock;
		LockReportsOptionsBeforeAssignment(Block, PlacementParameters.Variants.Array);
		Block.Lock();

		For Each OptionRef In PlacementParameters.Variants.Array Do
			If OptionRef.ReportType = Enums.ReportsTypes.External Then
				CannotBePlaced = ?(CannotBePlaced = "", "", CannotBePlaced + Chars.LF) + "  " 
					+ String(OptionRef) + " (" + NStr("en = 'external';") + ")";
				Continue;
			ElsIf OptionRef.DeletionMark Then
				CannotBePlaced = ?(CannotBePlaced = "", "", CannotBePlaced + Chars.LF) + "  " 
					+ String(OptionRef) + " (" + NStr("en = 'marked for deletion';") + ")";
				Continue;
			EndIf;

			HasChanges = False;
			OptionObject = OptionRef.GetObject(); // CatalogObject.ReportsOptions - 

			Receiver = PlacementParameters.Receiver; // See RowDataProperties
			DestinationRow = OptionObject.Location.Find(Receiver.Ref, "Subsystem");
			If DestinationRow = Undefined Then
				DestinationRow = OptionObject.Location.Add();
				DestinationRow.Subsystem = Receiver.Ref;
			EndIf;
			
			// Delete the row from the source subsystem.
			// NOTE: To exclude a predefined report option from a subsystem,
			// clear the subsystem flag in the report option.
			If PlacementParameters.Action = "Move" Then
				For Each SubsystemToExclude In SubsystemsToExclude Do
					SourceRow = OptionObject.Location.Find(SubsystemToExclude, "Subsystem");
					If SourceRow <> Undefined Then
						If SourceRow.Use Then
							SourceRow.Use = False;
							If Not HasChanges Then
								FillPropertyValues(DestinationRow, SourceRow, "Important, SeeAlso");
								HasChanges = True;
							EndIf;
						EndIf;
						SourceRow.Important  = False;
						SourceRow.SeeAlso = False;
					ElsIf Not OptionObject.Custom Then
						SourceRow = OptionObject.Location.Add();
						SourceRow.Subsystem = SubsystemToExclude;
						HasChanges = True;
					EndIf;
				EndDo;
			EndIf;
			
			// Register a row in the destination subsystem.
			If Not DestinationRow.Use Then
				HasChanges = True;
				DestinationRow.Use = True;
			EndIf;

			If HasChanges Then
				Placed = Placed + 1;
				OptionObject.Write();
			Else
				AlreadyAssigned = ?(AlreadyAssigned = "", "", AlreadyAssigned + Chars.LF) + "  " + String(OptionRef);
			EndIf;
		EndDo;

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

	If PlacementParameters.Action = "Move" And Placed > 0 Then
		Items.SubsystemsTree.CurrentRow = Receiver.Id;
		UpdateListContent();
	EndIf;

	Return New Structure("Placed, AlreadyAssigned, CannotBePlaced", Placed, AlreadyAssigned, CannotBePlaced);
EndFunction

&AtServer
Procedure LockReportsOptionsBeforeAssignment(Block, ReportsOptions)

	DataSource = New ValueTable;
	DataSource.Columns.Add("Ref", New TypeDescription("CatalogRef.ReportsOptions"));

	For Each ReportVariant In ReportsOptions Do
		String = DataSource.Add();
		String.Ref = ReportVariant;
	EndDo;

	LockItem = Block.Add("Catalog.ReportsOptions");
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Ref", "Ref");

EndProcedure

&AtClient
Procedure UpdateListContentClient(Event)
	Measurement = StartMeasurement(Event);
	UpdateListContent(Event);
	EndMeasurement(Measurement);
EndProcedure

&AtClient
Function StartMeasurement(Event)
	If Not ClientParameters.RunMeasurements Then
		Return Undefined;
	EndIf;

	If ValueIsFilled(SearchString) And (Event = "SearchStringOnChange" Or Event = "ExecuteSearch") Then
		Name = "ReportsList.Search";
	Else
		Return Undefined;
	EndIf;

	Comment = New Map;
	If ValueIsFilled(SearchString) Then
		Comment.Insert("Search", True);
		Comment.Insert("SearchString", String(SearchString));
		Comment.Insert("IncludingSubordinates", IncludingSubordinates);
	Else
		Comment.Insert("Search", False);
	EndIf;

	Measurement = New Structure("ModulePerformanceMonitorClient, Id");
	Measurement.ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
	Measurement.Id = Measurement.ModulePerformanceMonitorClient.TimeMeasurement(Name, False, False);
	Measurement.ModulePerformanceMonitorClient.SetMeasurementComment(Measurement.Id, Comment);
	Return Measurement;
EndFunction

&AtClient
Procedure EndMeasurement(Measurement)
	If Measurement <> Undefined Then
		Measurement.ModulePerformanceMonitorClient.StopTimeMeasurement(Measurement.Id);
	EndIf;
EndProcedure

// Parameters:
//  TreeItems - Array of FormDataTreeItem:
//    * Ref - CatalogRef.MetadataObjectIDs
//             - CatalogRef.ExtensionObjectIDs
//    * Presentation - String
//    * Name - String
//    * FullName - String
//    * Priority - String
//    * FullPresentation - String
//
// Returns:
//  FormDataTreeItem:
//    * Ref - CatalogRef.MetadataObjectIDs
//             - CatalogRef.ExtensionObjectIDs
//    * Presentation - String
//    * Name - String
//    * FullName - String
//    * Priority - String
//    * FullPresentation - String
//
&AtServer
Function SubsystemsTreeItem(TreeItems)

	Return TreeItems[0];

EndFunction

// Parameters:
//  ReportsOptionsDetails - See ReportsOptions.UpdateReportOptionsFromFiles 
//
&AtClient
Procedure SetTheSelectionBasedOnTheUpdatedReportsFromTheFiles(ReportsOptionsDetails)

	UpdatedVersionsOfReports = New ValueList;

	For Each ReportOptionDetails In ReportsOptionsDetails Do
		UpdatedVersionsOfReports.Add(ReportOptionDetails.Ref);
	EndDo;

	ChildSubsystems = SubsystemsTree.GetItems();

	If ChildSubsystems.Count() > 0 Then
		Items.SubsystemsTree.CurrentRow = ChildSubsystems[0].GetID();
	EndIf;

	UpdateListContent();

	CommonClientServer.SetDynamicListFilterItem(List, "Ref",
		UpdatedVersionsOfReports, DataCompositionComparisonType.InList,,,
		DataCompositionSettingsItemViewMode.Normal);

EndProcedure

&AtServer
Function ViewQueryTextInOtherLanguagesInTabularPart()

	QueryText = "SELECT ALLOWED
				   |	ReportsOptionsOverridable.Ref,
				   |	ReportsOptionsOverridable.DeletionMark,
				   |	ISNULL(ConfigurationOptionsOverridable.MeasurementsKey, ExtensionOptionsOverridable.MeasurementsKey) AS
				   |		MeasurementsKey,
				   |	ReportsOptionsOverridable.Custom,
				   |	NOT ReportsOptionsOverridable.Custom AS Predefined,
				   |	CASE
				   |		WHEN &IsMainLanguage
				   |		AND (ReportsOptionsOverridable.Custom
				   |		OR ReportsOptionsOverridable.PredefinedOption IN (UNDEFINED,
				   |			VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
				   |			VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
				   |			THEN ReportsOptionsOverridable.Description
				   |		WHEN NOT &IsMainLanguage
				   |		AND (ReportsOptionsOverridable.Custom
				   |		OR ReportsOptionsOverridable.PredefinedOption IN (UNDEFINED,
				   |			VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
				   |			VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
				   |			THEN CAST(ISNULL(OptionsPresentations.Description, ReportsOptionsOverridable.Description) AS
				   |				STRING(150))
				   |		WHEN &IsMainLanguage
				   |			THEN CAST(ISNULL(ISNULL(ConfigurationOptionsOverridable.Description,
				   |				ExtensionOptionsOverridable.Description), ReportsOptionsOverridable.Description) AS STRING(150))
				   |		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.Description, PresentationsFromExtensions.Description),
				   |			ReportsOptionsOverridable.Description) AS STRING(150))
				   |	END AS Description,
				   |	NOT ReportsOptionsOverridable.AuthorOnly AS AvailableToAllUsers,
				   |	ReportsOptionsOverridable.Report,
				   |	ReportsOptionsOverridable.VariantKey,
				   |	ReportsOptionsOverridable.ReportType,
				   |	ReportsOptionsOverridable.Author,
				   |	CASE
				   |		WHEN &IsMainLanguage
				   |		AND SUBSTRING(ReportsOptionsOverridable.LongDesc, 1, 1) <> """"
				   |			THEN CAST(ReportsOptionsOverridable.LongDesc AS STRING(1000))
				   |		WHEN &IsMainLanguage
				   |		AND SUBSTRING(ReportsOptionsOverridable.LongDesc, 1, 1) = """"
				   |			THEN CAST(ISNULL(ConfigurationOptionsOverridable.LongDesc, ExtensionOptionsOverridable.LongDesc)
				   |				AS STRING(1000))
				   |		WHEN NOT &IsMainLanguage
				   |		AND SUBSTRING(OptionsPresentations.LongDesc, 1, 1) <> """"
				   |			THEN CAST(OptionsPresentations.LongDesc AS STRING(1000))
				   |		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.LongDesc, PresentationsFromExtensions.LongDesc),
				   |			ReportsOptionsOverridable.LongDesc) AS STRING(1000))
				   |	END AS LongDesc,
				   |	&ReportName AS ReportName,
				   |	ExtensionsInfo.FullObjectName AS FullReportName,
				   |	CASE
				   |		WHEN ReportsOptionsOverridable.DeletionMark = TRUE
				   |			THEN 4
				   |		WHEN ReportsOptionsOverridable.Custom = FALSE
				   |			THEN 5
				   |		ELSE 3
				   |	END AS PictureIndex
				   |FROM
				   |	Catalog.ReportsOptions AS ReportsOptionsOverridable
				   |		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptionsOverridable
				   |		ON ReportsOptionsOverridable.PredefinedOption = ConfigurationOptionsOverridable.Ref
				   |		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptionsOverridable
				   |		ON ReportsOptionsOverridable.PredefinedOption = ExtensionOptionsOverridable.Ref
				   |		LEFT JOIN Catalog.ReportsOptions.Presentations AS OptionsPresentations
				   |		ON ReportsOptionsOverridable.Ref = OptionsPresentations.Ref
				   |		AND (OptionsPresentations.LanguageCode = &LanguageCode)
				   |		LEFT JOIN Catalog.PredefinedReportsOptions.Presentations AS PresentationsFromConfiguration
				   |		ON ReportsOptionsOverridable.PredefinedOption = PresentationsFromConfiguration.Ref
				   |		AND (PresentationsFromConfiguration.LanguageCode = &LanguageCode)
				   |		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Presentations AS PresentationsFromExtensions
				   |		ON ReportsOptionsOverridable.PredefinedOption = PresentationsFromExtensions.Ref
				   |		AND (PresentationsFromExtensions.LanguageCode = &LanguageCode)
				   |		LEFT JOIN InformationRegister.ExtensionVersionObjectIDs AS ExtensionsInfo
				   |		ON ExtensionsInfo.ExtensionsVersion = &ExtensionsVersion
				   |		AND ExtensionsInfo.Id = ReportsOptionsOverridable.Report
				   |WHERE
				   |	ReportsOptionsOverridable.Report IN (&AvailableReports)
				   |	AND CASE
				   |			WHEN &HasFilterByOptions
				   |				THEN ReportsOptionsOverridable.Ref IN (&UserOptions)
				   |			WHEN NOT ReportsOptionsOverridable.PredefinedOption IN (&DIsabledApplicationOptions)
				   |				THEN TRUE
				   |			ELSE ReportsOptionsOverridable.Ref IN
				   |					(SELECT
				   |						ParentsOverridable.Parent
				   |					FROM
				   |						Catalog.ReportsOptions AS ParentsOverridable
				   |					WHERE
				   |						ParentsOverridable.Report IN (&AvailableReports)
				   |						AND NOT ParentsOverridable.Ref IN (&UserOptions))
				   |		END";

	Return QueryText;

EndFunction

#EndRegion