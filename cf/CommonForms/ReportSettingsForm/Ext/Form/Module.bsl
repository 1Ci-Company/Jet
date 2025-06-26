///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var DragSourceAtClient;
&AtClient
Var DragDestinationAtClient;
&AtClient
Var List_BeforeStartChanges;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	
	DefineBehaviorInMobileClient();
	
	ParametersForm = ReportsOptions.StoredReportFormParameters(Parameters);
	ReportSettings = Parameters.ReportSettings;
	DescriptionOption = Parameters.DescriptionOption;
	
	DescriptionOfReportSettings = DescriptionOfReportSettings(ReportSettings);
	
	WindowOptionsKey = DescriptionOfReportSettings.FullName;
	If ValueIsFilled(CurrentVariantKey) Then
		WindowOptionsKey = WindowOptionsKey + "." + CurrentVariantKey;
	EndIf;
	
	DCSettings = Parameters.Variant;
	If DCSettings = Undefined Then
		DCSettings = Report.SettingsComposer.Settings;
	EndIf;
	
	SettingsStructureItemID = Parameters.SettingsStructureItemID;
	If TypeOf(SettingsStructureItemID) = Type("DataCompositionID") Then
		SettingsStructureItemChangeMode = True;
		Height = 0;
		WindowOptionsKey = WindowOptionsKey + ".Node";
		
		PathToSettingsStructureItem = CommonClientServer.StructureProperty(
			Parameters, "PathToSettingsStructureItem");
		
		StructureItem = ReportsServer.SettingsItemByFullPath(DCSettings, PathToSettingsStructureItem);
		If StructureItem <> Undefined Then
			SettingsStructureItemID = DCSettings.GetIDByObject(StructureItem);
		EndIf;
		
		Title = Parameters.Title;
		SettingsStructureItemType = Parameters.SettingsStructureItemType;
	Else
		If Not ValueIsFilled(DescriptionOption) Then
			DescriptionOption = DescriptionOfReportSettings.Description;
		EndIf;
		
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 report settings';"), DescriptionOption);
	EndIf;
	
	GlobalSettings = ReportsOptions.GlobalSettings();
	Items.AppearanceCustomizeHeadersFooters.Visible =
		GlobalSettings.OutputIndividualHeaderOrFooterSettings
		And Not SettingsStructureItemChangeMode
		And (Not Common.DataSeparationEnabled() Or Common.SeparatedDataUsageAvailable());
	
	If SettingsStructureItemChangeMode Then
		PageName = ?(IsBlankString(Parameters.PageName), "GroupingContentPage", Parameters.PageName);
		ExtendedMode = 1;
	Else
		ExtendedMode = DescriptionOfReportSettings.SettingsFormAdvancedMode;
		PageName = DescriptionOfReportSettings.SettingsFormPageName;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then 
		
		// Calculate the number of form creations, the standard separator is a period.
		CurMode = Items.ExtendedMode.ChoiceList.FindByValue(ExtendedMode);
		Comment = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 mode';"), CurMode.Presentation);
		
		ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
		ModuleMonitoringCenter.WriteBusinessStatisticsOperation("CommonForm.ReportSettingsForm", 1, Comment);
		
	EndIf;
	
	Page = Items.Find(PageName);
	If Page <> Undefined Then
		Items.SettingsPages.CurrentPage = Page;
	EndIf;
	
	If DescriptionOfReportSettings.SchemaModified Then
		Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DescriptionOfReportSettings.SchemaURL));
	EndIf;
	
	FontImportantLabel = Metadata.StyleItems.ImportantLabelFont;
	Items.OptionStructureTitle.Font = FontImportantLabel.Value;
	
	// Register commands and form attributes that will not be deleted when overwriting quick settings.
	AttributesSet = GetAttributes();
	For Each Attribute In AttributesSet Do
		ConstantAttributes.Add(FullAttributeName(Attribute));
	EndDo;
	
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	SettingsUpdateRequired = True;
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(NewDCSettings)
	
	If ReportsOptions.ItIsAcceptableToSetContext(ThisObject)
	   And TypeOf(ParametersForm.Filter) = Type("Structure") Then
		
		ReportsServer.SetFixedFilters(ParametersForm.Filter, NewDCSettings, ReportSettings);
	EndIf;
	
	SettingsUpdateRequired = True;
	
	// Prepare for calling the reinitialization event.
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewXMLSettings = Common.ValueToXMLString(NewDCSettings);
		Except
			NewXMLSettings = Undefined;
		EndTry;
		ReportSettings.NewXMLSettings = NewXMLSettings;
	EndIf;
EndProcedure

&AtServer
Procedure BeforeLoadUserSettingsAtServer(NewDCUserSettings)
	
	SettingsUpdateRequired = True;
	
	// Prepare for calling the reinitialization event.
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		Try
			NewUserXMLSettings = Common.ValueToXMLString(NewDCUserSettings);
		Except
			NewUserXMLSettings = Undefined;
		EndTry;
		ReportSettings.NewUserXMLSettings = NewUserXMLSettings;
	EndIf;
EndProcedure

&AtServer
Procedure OnUpdateUserSettingSetAtServer(StandardProcessing)
	
	StandardProcessing = False;
	VariantModified = False;
	
	If SettingsUpdateRequired Then
		SettingsUpdateRequired = False;
		
		FillParameters = ReportsClientServer.ReportFormUpdateParameters("OnCreateAtServer");
		FillParameters.UpdateOptionSettings = Not SettingsStructureItemChangeMode And ExtendedMode = 1;
		UpdateForm(FillParameters);
	EndIf;
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not SelectionResultGenerated Then
		Notification = New NotifyDescription("ConfirmAndClose", ThisObject);
		Modified = Modified Or VariantModified Or UserSettingsModified;
		CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit,
			NStr("en = 'The settings were changed. Save the changes?';"));
	EndIf;
	
	UserSettingsModified = False;
	VariantModified = False;
	
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	If OnCloseNotifyDescription <> Undefined Then
		ExecuteNotifyProcessing(OnCloseNotifyDescription, SelectionResult(False));
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExtendedModeOnChange(Item)
	If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		
		// Count how many times the mode switches. The delimiter is dot ( . ).
		ModuleMonitoringCenterClient = CommonClient.CommonModule("MonitoringCenterClient");
		ModuleMonitoringCenterClient.WriteBusinessStatisticsOperation("CommonForm.ReportSettingsForm.ExtendedMode.OnChange", 1);
		
	EndIf;
	
	ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters("ExtendedModeOnChange");
	ParametersOfUpdate.DCSettingsComposer = Report.SettingsComposer;
	ParametersOfUpdate.UpdateOptionSettings = (ExtendedMode = 1);
	ParametersOfUpdate.ResetCustomSettings = (ExtendedMode <> 1);
	UpdateForm(ParametersOfUpdate);
EndProcedure

&AtClient
Procedure NoUserSettingsWarningsURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	ExtendedMode = 1;
	ExtendedModeOnChange(Undefined);
EndProcedure

&AtClient
Procedure CurrentChartTypeOnChange(Item)
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(SettingsStructureItemID);
	If TypeOf(StructureItem) = Type("DataCompositionNestedObjectSettings") Then
		StructureItem = StructureItem.Settings;
	EndIf;
	
	SetOutputParameter(StructureItem, "ChartType", CurrentChartType);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure HasNestedReportsTooltipURLProcessing(Item, Address, StandardProcessing)
	StandardProcessing = False;
	String = Items.OptionStructure.CurrentData;
	ChangeStructureItem(String,, True);
EndProcedure

&AtClient
Procedure TitleOutputOnChange(Item)
	PredefinedParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	SettingItem = PredefinedParameters.Find("TITLE");
	SettingItem.Use = TitleOutput;
	
	SynchronizePredefinedOutputParameters(TitleOutput, SettingItem);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure OutputFiltersOnChange(Item)
	PredefinedParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	SettingItem = PredefinedParameters.Find("DATAPARAMETERSOUTPUT");
	SettingItem.Use = True;
	
	If OutputFilters Then 
		SettingItem.Value = DataCompositionTextOutputType.Auto;
	Else
		SettingItem.Value = DataCompositionTextOutputType.DontOutput;
	EndIf;
	
	SynchronizePredefinedOutputParameters(OutputFilters, SettingItem);
	DetermineIfModified();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable objects.

&AtClient
Procedure Attachable_Period_OnChange(Item)
	ReportsClient.SetPeriod(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_SettingItem_OnChange(Item)
	SettingsComposer = Report.SettingsComposer;
	
	IndexOf = PathToItemsData.ByName[Item.Name];
	If IndexOf = Undefined Then 
		IndexOf = ReportsClientServer.SettingItemIndexByPath(Item.Name);
	EndIf;
	
	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	
	IsFlag = StrStartsWith(Item.Name, "CheckBox") Or StrEndsWith(Item.Name, "CheckBox");
	If IsFlag Then 
		SettingItem.Value = ThisObject[Item.Name];
	EndIf;
	
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue")
		And ReportSettings.ImportSettingsOnChangeParameters.Find(SettingItem.Parameter) <> Undefined Then 
		
		ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters();
		ParametersOfUpdate.DCSettingsComposer = SettingsComposer;
		UpdateForm(ParametersOfUpdate);
	Else
		RegisterList(Item, SettingItem);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_List_OnChange(Item)
	SettingsComposer = Report.SettingsComposer;
	
	IndexOf = PathToItemsData.ByName[Item.Name];
	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	
	List = ThisObject[Item.Name];
	SelectedValues = New ValueList;
	For Each ListItem In List Do 
		If ListItem.Check Then 
			FillPropertyValues(SelectedValues.Add(), ListItem);
		EndIf;
	EndDo;
	
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		SettingItem.Value = SelectedValues;
	ElsIf TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
		SettingItem.RightValue = SelectedValues;
	EndIf;
	SettingItem.Use = True;
	
	ReportsClient.CacheFilterValue(SettingsComposer, SettingItem, List);
	
	RegisterList(Item, SettingItem);
EndProcedure

&AtClient
Procedure Attachable_List_BeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	ListPath = Item.Name;
	ListItem = Items[Item.Name + "Value"];
	
	FillParameters = ListFillingParameters(True, False);
	FillParameters.ListPath = ListPath;
	FillParameters.IndexOf = PathToItemsData.ByName[ListPath];
	
	ChoiceOverride = False;
	StartListFilling(ListItem, FillParameters, ChoiceOverride);
	
	If ChoiceOverride Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_List_BeforeStartChanges(Item, Cancel)
	
	List_BeforeStartChanges = Item;
	
	ListItem = Items[Item.Name + "Value"];
	ListItem.TextEdit = False;
	AttachIdleHandler("List_AtStartChanges", 0.1, True);
	
EndProcedure

&AtClient
Procedure Attachable_List_ChoiceProcessing(Item, SelectionResult, StandardProcessing)
	StandardProcessing = False;
	
	List = ThisObject[Item.Name];
	
	Selected_ = ReportsClientServer.ValuesByList(SelectionResult);
	Selected_.FillChecks(True);
	
	AddOn = CommonClientServer.SupplementList(List, Selected_, False, True);
	
	TheValueOfTheSettingElement = CommonClient.CopyRecursive(List);
	IndexOf = TheValueOfTheSettingElement.Count() - 1;
	While IndexOf >= 0 Do 
		CurrentValue = TheValueOfTheSettingElement[IndexOf];
		
		If Not CurrentValue.Check Then 
			TheValueOfTheSettingElement.Delete(CurrentValue);
		EndIf;
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	IndexOf = PathToItemsData.ByName[Item.Name];
	SettingsComposer = Report.SettingsComposer;
	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then
		SettingItem.Value = TheValueOfTheSettingElement;
	Else
		SettingItem.RightValue = TheValueOfTheSettingElement;
	EndIf;
	SettingItem.Use = True;
	
	RegisterList(Item, SettingItem);
	
	If AddOn.Total > 0 Then
		If AddOn.Total = 1 Then
			NotificationTitle = NStr("en = 'The item added to the list.';");
		Else
			NotificationTitle = NStr("en = 'The items added to the list.';");
		EndIf;
		
		ShowUserNotification(
			NotificationTitle,,
			String(Selected_),
			PictureLib.ExecuteTask);
	EndIf;
	
	ReportsClient.CacheFilterValue(SettingsComposer, SettingItem, List);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure Attachable_ListItemMark_OnChange(Item)
	
	DetachIdleHandler("List_AtStartChanges");
	List_BeforeStartChanges.EndEditRow(True);
	
EndProcedure

&AtClient
Procedure Attachable_ListItem_OnChange(Item)
	ListPath = StrReplace(Item.Name, "Value", "");
	
	String = Items[ListPath].CurrentData;
	
	ListItem = ThisObject[ListPath].FindByValue(String.Value);
	ListItem.Check = True;
EndProcedure

&AtClient
Procedure Attachable_ListItem_StartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	ListPath = StrReplace(Item.Name, "Value", "");
	
	FillParameters = ListFillingParameters(True, False, False);
	FillParameters.ListPath = ListPath;
	FillParameters.IndexOf = PathToItemsData.ByName[ListPath];
	FillParameters.Owner = Item;
	
	CurrentValue = Items[ListPath].CurrentData.Value;
	If CurrentValue <> Undefined Then
		InformationRecords = ReportsClient.SettingItemInfo(Report.SettingsComposer, FillParameters.IndexOf);
		UserSettings = Report.SettingsComposer.UserSettings.Items;
		ChoiceParameters = ReportsClientServer.ChoiceParameters(InformationRecords.Settings, UserSettings, InformationRecords.Item);
		FillParameters.Insert("ChoiceParameters", ChoiceParameters);
		FillParameters.Insert("CurrentRow", CurrentValue);
		
		TypesList = New ValueList;
		TypesList.Add(TypeOf(CurrentValue));
		ContinueFillingList(TypesList[0], FillParameters);
		Return;
	EndIf;
		
	StartListFilling(Item, FillParameters);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSort

&AtClient
Procedure SortSelection(Item, RowID, Field, StandardProcessing)
	StandardProcessing = False;
	
	String = Items.Sort.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(String.Field) = Type("DataCompositionField") Then
		If Field = Items.SortField Then // Modify the field.
#If Not MobileClient Then
				SortingSelectField(RowID, String);
#EndIf
		ElsIf Field = Items.SortOrderType Then // Change the order.
			ChangeOrderType(String);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SortBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	SelectField("Sort", New NotifyDescription("SortAfterFieldChoice", ThisObject));
EndProcedure

&AtClient
Procedure SortBeforeDeleteRow(Item, Cancel)
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure SortUseOnChange(Item)
	ChangeSettingItemUsage("Sort");
EndProcedure

&AtClient
Procedure Sort_Descending(Command)
	ChangeRowsOrderType(DataCompositionSortDirection.Desc);
EndProcedure

&AtClient
Procedure Sort_Ascending(Command)
	ChangeRowsOrderType(DataCompositionSortDirection.Asc);
EndProcedure

&AtClient
Procedure Sort_MoveUp(Command)
	ShiftSorting();
EndProcedure

&AtClient
Procedure Sort_MoveDown(Command)
	ShiftSorting(False);
EndProcedure

&AtClient
Procedure Sort_SelectAll(Command)
	ChangeUsage("Sort");
EndProcedure

&AtClient
Procedure Sorting_ClearAll(Command)
	ChangeUsage("Sort", False);
EndProcedure

&AtClient
Procedure SortDragStart(Item, DragParameters, EnableDrag)
	DragSourceAtClient = Item.Name;
EndProcedure

&AtClient
Procedure SortDragCheck(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	DragDestinationAtClient = Item.Name;
	
	If DragParameters.Value.Count() > 0 Then 
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure SortDrag(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	StandardProcessing = False;
	If DragSourceAtClient = Item.Name Then 
		DragSortingWithinCollection(DragParameters, CurrentRow);
	ElsIf DragSourceAtClient = Items.SelectedFields.Name Then 
		DragSelectedFieldsToSorting(DragParameters.Value);
	EndIf;
EndProcedure

&AtClient
Procedure SortDragEnd(Item, DragParameters, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_Right(Command)
	RowsIDs = Items.SelectedFields.SelectedRows;
	If RowsIDs = Undefined Then 
		Return;
	EndIf;
	
	Rows = New Array;
	For Each RowID In RowsIDs Do 
		String = SelectedFields.FindByID(RowID);
		If TypeOf(String.Id) = Type("DataCompositionID") Then 
			Rows.Add(String);
		EndIf;
	EndDo;
	
	DragSelectedFieldsToSorting(Rows);
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_Left(Command)
	RowsIDs = Items.Sort.SelectedRows;
	If RowsIDs = Undefined Then 
		Return;
	EndIf;
	
	Rows = New Array;
	For Each RowID In RowsIDs Do 
		String = Sort.FindByID(RowID);
		If TypeOf(String.Id) = Type("DataCompositionID") Then 
			Rows.Add(String);
		EndIf;
	EndDo;
	
	DragSortingFieldsToSelectedFields(Rows);
EndProcedure

&AtClient
Procedure SelectedFields_Sorting_LeftAll(Command)
	DragSortingFieldsToSelectedFields(Sort.GetItems()[0].GetItems());
EndProcedure

&AtClient
Procedure SelectedField_GroupAND(Command)
	RowID = Items.Filters.CurrentRow;
	If RowID <> Undefined Then
		FiltersAfterGroupChoice(DataCompositionFilterItemsGroupType.AndGroup, RowID);
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFields_GroupOR(Command)
	RowID = Items.Filters.CurrentRow;
	If RowID <> Undefined Then
		FiltersAfterGroupChoice(DataCompositionFilterItemsGroupType.OrGroup, RowID);
	EndIf;
EndProcedure

&AtClient
Procedure SelectedField_GroupNOT(Command)
	RowID = Items.Filters.CurrentRow;
	If RowID <> Undefined Then
		FiltersAfterGroupChoice(DataCompositionFilterItemsGroupType.NotGroup, RowID);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFields

&AtClient
Procedure SelectedFieldsSelection(Item, RowID, Field, StandardProcessing)
	StandardProcessing = False;
#If MobileClient Then
	Return;
#EndIf
	
	String = Items.SelectedFields.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	If Field = Items.SelectedFieldsField Then // Change the order.
		If String.IsFolder Then
			SelectedFieldsSelectGroup(RowID, String);
		ElsIf TypeOf(String.Field) = Type("DataCompositionField") Then
			SelectedFieldsSelectField(RowID, String);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsOnActivateRow(Item)
	AttachIdleHandler("AfterActivatingTheSelectedFields", 0.1, True);
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeDeleteRow(Item, Cancel)
	If ExtendedMode = 0 Then
		Cancel = True;
		Return;
	EndIf;
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure SelectedFieldsUseOnChange(Item)
	ChangeSettingItemUsage("SelectedFields");
EndProcedure

&AtClient
Procedure SelectedFields_MoveUp(Command)
	ShiftSelectedFields();
EndProcedure

&AtClient
Procedure SelectedFields_MoveDown(Command)
	ShiftSelectedFields(False);
EndProcedure

&AtClient
Procedure SelectedFields_Group(Command)
	GroupingParameters = GroupingParametersOfSelectedFields();
	If GroupingParameters = Undefined Then 
		Return;
	EndIf;
	
	FormParameters = New Structure("Placement", DataCompositionFieldPlacement.Auto);
	Handler = New NotifyDescription("SelectedFieldsBeforeGroupFields", ThisObject, GroupingParameters);
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectedFieldsGroup", FormParameters, 
		ThisObject, UUID,,, Handler, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure SelectedFields_Ungroup(Command)
	RowsIDs = Items.SelectedFields.SelectedRows;
	If RowsIDs.Count() <> 1 Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	SourceRowParent = SelectedFields.FindByID(RowsIDs[0]);
	If TypeOf(SourceRowParent.Id) <> Type("DataCompositionID") Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	SourceSettingItemParent = StructureItemProperty.GetObjectByID(SourceRowParent.Id);
	If TypeOf(SourceSettingItemParent) <> Type("DataCompositionSelectedFieldGroup") Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	DestinationSettingItemParent = SourceSettingItemParent.Parent;
	If SourceSettingItemParent.Parent = Undefined Then 
		DestinationSettingItemParent = StructureItemProperty;
	EndIf;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SourceSettingItemParent, DestinationSettingItemParent);
	
	DestinationRowParent1 = SourceRowParent.GetParent();
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRowParent, DestinationRowParent1);
	
	ChangeGroupingOfSelectedFields(StructureItemProperty, SourceRowParent.GetItems(), SettingsItemsInheritors, RowsInheritors);
	
	// Deleting basic grouping items.
	DestinationRowParent1.GetItems().Delete(SourceRowParent);
	DestinationSettingItemParent.Items.Delete(SourceSettingItemParent);
	
	Section = SelectedFields.GetItems()[0];
	Items.SelectedFields.Expand(Section.GetID(), True);
	Items.SelectedFields.CurrentRow = DestinationRowParent1.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure SelectedFields_SelectCheckBoxes(Command)
	ChangeUsage("SelectedFields");
EndProcedure

&AtClient
Procedure SelectedFields_ClearCheckBoxes(Command)
	ChangeUsage("SelectedFields", False);
EndProcedure

&AtClient
Procedure SelectedFieldsDragStart(Item, DragParameters, EnableDrag)
	DragSourceAtClient = Item.Name;
	
	CheckRowsToDragFromSelectedFields(DragParameters.Value);
	If DragParameters.Value.Count() = 0 Then 
		EnableDrag = False;
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsDragCheck(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	
	If DragSourceAtClient <> Item.Name Then
		Return;
	EndIf;
	
	CurrentData = SelectedFields.FindByID(CurrentRow);
	If CurrentData.IsSection Or CurrentData.IsFolder Then
		DestinationRow = CurrentData;
	Else
		DestinationRow = CurrentData.GetParent();
	EndIf;
	
	For Each RowID In DragParameters.Value Do 
		RowDrag = SelectedFields.FindByID(RowID);
		If TheseAreSubordinateElements(RowDrag, DestinationRow) Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
	EndDo;
	
	DragDestinationAtClient = Item.Name;
	
	If DragParameters.Value.Count() > 0 Then 
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedFieldsDrag(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	
	If DragParameters.Action = DragAction.Cancel Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If DragSourceAtClient = Item.Name Then 
		DragSelectedFieldsWithinCollection(DragParameters, CurrentRow);
	Else
		DragSortingFieldsToSelectedFields(DragParameters.Value);
	EndIf;
EndProcedure

&AtClient
Procedure SelectedFieldsDragEnd(Item, DragParameters, StandardProcessing)

	If DragParameters.Action = DragAction.Cancel Then
		Return;
	EndIf;
	
	If DragDestinationAtClient <> Item.Name Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	Rows = DragParameters.Value;
	Parent = Rows[0].GetParent();
	
	IndexOf = Rows.UBound();
	While IndexOf >= 0 Do 
		String = Rows[IndexOf];
		
		SettingItem = SettingItem(StructureItemProperty, String);
		SettingItemParent = StructureItemProperty;
		If SettingItem.Parent <> Undefined Then 
			SettingItemParent = SettingItem.Parent;
		EndIf;
		
		SettingItemParent.Items.Delete(SettingItem);
		Parent.GetItems().Delete(String);
		
		IndexOf = IndexOf - 1;
	EndDo;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilters

&AtClient
Procedure Filters_Group(Command)
	GroupingParameters = FiltersGroupingParameters();
	If GroupingParameters = Undefined Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	// Process settings items.
	SettingItemSource = StructureItemProperty;
	If TypeOf(GroupingParameters.Parent.Id) = Type("DataCompositionID") Then 
		SettingItemSource = StructureItemProperty.GetObjectByID(GroupingParameters.Parent.Id);
	EndIf;
	
	SettingItemDestination = SettingItemSource.Items.Insert(GroupingParameters.IndexOf, Type("DataCompositionFilterItemGroup"));
	SettingItemDestination.UserSettingID = New UUID;
	SettingItemDestination.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
	
	// Process strings.
	SourceRow = GroupingParameters.Parent;
	SourceItems = SourceRow.GetItems();
	DestinationRow = SettingsFormCollectionItem(SourceRow);
	DestinationRow = SourceItems.Insert(GroupingParameters.IndexOf); // See SettingsFormCollectionItem
	SetFiltersRowData(DestinationRow, StructureItemProperty, SettingItemDestination);
	DestinationRow.Id = StructureItemProperty.GetIDByObject(SettingItemDestination);
	
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRow, DestinationRow);
	
	ChangeFiltersGrouping(StructureItemProperty, GroupingParameters.Rows, SettingsItemsInheritors, RowsInheritors);
	DeleteBasicFiltersGroupingItems(StructureItemProperty, GroupingParameters);
	
	Section = DefaultRootRow("Filters");
	Items.Filters.Expand(Section.GetID(), True);
	Items.Filters.CurrentRow = DestinationRow.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure Filters_Ungroup(Command)
	RowsIDs = Items.Filters.SelectedRows;
	If RowsIDs.Count() <> 1 Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	SourceRowParent = Filters.FindByID(RowsIDs[0]);
	If TypeOf(SourceRowParent.Id) <> Type("DataCompositionID") Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	SourceSettingItemParent = StructureItemProperty.GetObjectByID(SourceRowParent.Id);
	If TypeOf(SourceSettingItemParent) <> Type("DataCompositionFilterItemGroup") Then 
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;
	
	DestinationSettingItemParent = SourceSettingItemParent.Parent;
	If SourceSettingItemParent.Parent = Undefined Then 
		DestinationSettingItemParent = StructureItemProperty;
	EndIf;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SourceSettingItemParent, DestinationSettingItemParent);
	
	DestinationRowParent1 = SourceRowParent.GetParent();
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRowParent, DestinationRowParent1);
	
	ChangeFiltersGrouping(StructureItemProperty, SourceRowParent.GetItems(), SettingsItemsInheritors, RowsInheritors);
	
	// Delete basic grouping items.
	DestinationRowParent1.GetItems().Delete(SourceRowParent);
	DestinationSettingItemParent.Items.Delete(SourceSettingItemParent);
	
	Section = DefaultRootRow("Filters");
	Items.Filters.Expand(Section.GetID(), True);
	Items.Filters.CurrentRow = DestinationRowParent1.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure Filters_MoveUp(Command)
	ShiftFilters();
EndProcedure

&AtClient
Procedure Filters_MoveDown(Command)
	ShiftFilters(False);
EndProcedure

&AtClient
Procedure Filters_SelectCheckBoxes(Command)
	ChangeUsage("Parameters");
	ChangeUsage("Filters");
EndProcedure

&AtClient
Procedure Filters_ClearCheckBoxes(Command)
	ChangeUsage("Parameters", False);
	ChangeUsage("Filters", False);
EndProcedure

&AtClient
Procedure Filters_ShowInReportHeader(Command)
	FiltersSetDisplayMode("ShowInReportHeader");
EndProcedure

&AtClient
Procedure Filters_ShowInReportSettings(Command)
	FiltersSetDisplayMode("ShowInReportSettings");
EndProcedure

&AtClient
Procedure Filters_ShowOnlyCheckBoxInReportHeader(Command)
	FiltersSetDisplayMode("ShowOnlyCheckBoxInReportHeader");
EndProcedure

&AtClient
Procedure Filters_ShowOnlyCheckBoxInReportSettings(Command)
	FiltersSetDisplayMode("ShowOnlyCheckBoxInReportSettings");
EndProcedure

&AtClient
Procedure Filters_DontShow(Command)
	FiltersSetDisplayMode("NotShow");
EndProcedure

&AtClient
Procedure FiltersSelection(Item, RowID, Field, StandardProcessing)
	String = Items.Filters.CurrentData;
	If String = Undefined Or String.IsSection Then
		Return;
	EndIf;
	
	If Field = Items.FiltersField Or Field = Items.FiltersParameter Or Field = Items.FiltersGroupType Then 
		StandardProcessing = False;
		If String.IsParameter Then 
			Return;
		EndIf;
		If String.IsFolder Then 
			FiltersSelectGroup(RowID);
		EndIf;

	ElsIf Field = Items.FiltersDisplayModePicture Then // Change quick access to the filter.
		StandardProcessing = False;
		If String.IsParameter Then 
			StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "DataParameters");
		Else
			StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Filter", SettingsStructureItemID);
		EndIf;
		SelectTheDisplayModeForTheLine(StructureItemProperty, "Filters", RowID, True, Not String.IsParameter);
	EndIf;
EndProcedure

&AtClient
Procedure FiltersOnActivateRow(Item)
	SetFilterElementEditOptions();
	AttachIdleHandler("FiltersOnChangeCurrentRow", 0.1, True);
EndProcedure

&AtClient
Procedure FiltersOnActivateCell(Item)
	String = Item.CurrentData;
	If String = Undefined Then 
		Return;
	EndIf;
	
	IsListField = String.ValueListAllowed Or ReportsClientServer.IsListComparisonKind(String.ComparisonType);
	
	ValueField = ?(String.IsParameter, Items.FiltersValue, Items.FiltersRightValue);
	ValueField.TypeRestriction = ?(IsListField, New TypeDescription("ValueList"), String.ValueType);
	ValueField.ListChoiceMode = Not IsListField And (String.AvailableValues <> Undefined);
	
	CastValueToComparisonKind(String);
	SetValuePresentation(String, Report.SettingsComposer.Settings.FilterAvailableFields);
EndProcedure

&AtClient
Procedure FiltersBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	QualifiersBeforeSelectField();
EndProcedure

&AtClient
Procedure FiltersFieldStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	QualifiersBeforeSelectField(Items.Filters.CurrentRow);
EndProcedure

&AtClient
Procedure FiltersFieldChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ValueSelected = Undefined Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	SettingDetails = StructureItemProperty.FilterAvailableFields.FindField(ValueSelected);
	RowID = Items.Filters.CurrentRow;
	
	FiltersAfterFieldChoice(SettingDetails, RowID);
EndProcedure

&AtClient
Procedure FiltersFieldAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	Query = TrimAll(Text);
	
	If Not ValueIsFilled(Query) Then 
		Return;
	EndIf;
	
	String = Items.Filters.CurrentData;
	
	If String = Undefined
		Or String.IsSection
		Or String.IsFolder
		Or String.IsParameter Then
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	AvailableFields = StructureItemProperty.FilterAvailableFields;
	DefineFilterItemSelectionDataOnQuery(Query, ChoiceData, AvailableFields);
	
EndProcedure

&AtClient
Procedure FiltersBeforeDeleteRow(Item, Cancel)
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure FiltersUseOnChange(Item)
	ChangeSettingItemUsage("Filters");
EndProcedure

&AtClient
Procedure FiltersComparisonTypeOnChange(Item)
	String = Items.Filters.CurrentData;
	If String = Undefined Then 
		Return;
	EndIf;
	
	PropertyKey = SettingsStructureItemPropertyKey("Filters", String);
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.ComparisonType = String.ComparisonType;
	
	If String.IsParameter Then 
		Condition = DataCompositionComparisonType.Equal;
		If String.ValueListAllowed Then 
			Condition = DataCompositionComparisonType.InList;
		EndIf;
	Else
		Condition = String.ComparisonType;
	EndIf;
	
	ValueField = ?(String.IsParameter, Items.FiltersValue, Items.FiltersRightValue);
	ValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(String.ChoiceFoldersAndItems, Condition);
	
	CastValueToComparisonKind(String, SettingItem);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FiltersValueOnChange(Item)
	String = Items.Filters.CurrentData;
	If String = Undefined Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "DataParameters");
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.Value = String.Value;
	
	DetermineIfModified();
	SetValuePresentation(String, Report.SettingsComposer.Settings.FilterAvailableFields);
	
	If ReportSettings.ImportSettingsOnChangeParameters.Find(SettingItem.Parameter) <> Undefined Then 
		WasOptionModified = VariantModified;
		Report.SettingsComposer.Settings.AdditionalProperties.Insert("ReportInitialized", False);
		VariantModified = WasOptionModified;
		
		ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters();
		ParametersOfUpdate.DCSettingsComposer = Report.SettingsComposer;
		UpdateParametersOptionModified = VariantModified;
		ParametersOfUpdate.UserSettingsModified = UserSettingsModified;
		ParametersOfUpdate.ResetCustomSettings = True;
		UpdateForm(ParametersOfUpdate);
	EndIf;
EndProcedure

&AtClient
Procedure FiltersValueStartChoice(Item, ChoiceData, StandardProcessing)
	String = Items.Filters.CurrentData;
	SetEditParameters(String);
	
	If ChoiceOverride(String, StandardProcessing) Then
		Return;
	EndIf;
	
	If String.ValueListAllowed Then 
		ShowChoiceList(String, StandardProcessing, Item);
	EndIf;
EndProcedure

&AtClient
Procedure FiltersRightValueOnChange(Item)
	String = Items.Filters.CurrentData;
	If String = Undefined Then 
		Return;
	EndIf;
	
	String.Use = True;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	FillPropertyValues(SettingItem, String, "Use, RightValue");
	
	DetermineIfModified();
	SetValuePresentation(String, Report.SettingsComposer.Settings.FilterAvailableFields);
EndProcedure

&AtClient
Procedure FiltersRightValueStartChoice(Item, ChoiceData, StandardProcessing)
	String = Items.Filters.CurrentData;
	SetEditParameters(String);
	
	If ChoiceOverride(String, StandardProcessing) Then
		Return;
	EndIf;
	
	If ReportsClientServer.IsListComparisonKind(String.ComparisonType) Then 
		ShowChoiceList(String, StandardProcessing, Item);
	EndIf;
EndProcedure

&AtClient
Procedure FiltersUserSettingPresentationOnChange(Item)
	String = Items.Filters.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(String.UserSettingPresentation) Then
		String.UserSettingPresentation = String.Title;
	EndIf;
	String.IsPredefinedTitle = (String.Title = String.UserSettingPresentation);
	
	If String.IsParameter Then 
		StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "DataParameters");
	Else
		StructureItemProperty = SettingsStructureItemProperty(
			Report.SettingsComposer, "Filter", SettingsStructureItemID);
	EndIf;
	
	SettingItem = SettingItem(StructureItemProperty, String);
	If String.IsPredefinedTitle Then
		SettingItem.UserSettingPresentation = "";
	Else
		SettingItem.UserSettingPresentation = String.UserSettingPresentation;
	EndIf;
	
	If Not String.IsParameter Then
		If String.DisplayModePicture = 1 Or String.DisplayModePicture = 3 Then
			// If "UserSettingPresentation" is assigned a value, "Presentation" behaves as a switch,
			// but it can also be used for importing to a spreadsheet.
			// 
			SettingItem.Presentation = String.UserSettingPresentation;
		Else
			SettingItem.Presentation = "";
		EndIf;
	EndIf;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure FiltersDragStart(Item, DragParameters, EnableDrag)
	DragSourceAtClient = Item.Name;
	
	CheckDraggableRowsFromSelections(DragParameters.Value);
	If DragParameters.Value.Count() = 0 Then 
		EnableDrag = False;
	EndIf;
EndProcedure

&AtClient
Procedure FiltersDragCheck(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	
	If CurrentRow = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	String = Filters.FindByID(CurrentRow);
	Parent = String.GetParent(); 
	If (Parent <> Undefined And Parent.Id = "DataParameters") 
		Or String.Id = "DataParameters" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;

	CurrentData = Filters.FindByID(CurrentRow);
	If CurrentData.IsSection Or CurrentData.IsFolder Then
		DestinationRow = CurrentData;
	Else
		DestinationRow = CurrentData.GetParent();
	EndIf;
	
	For Each RowID In DragParameters.Value Do 
		RowDrag = Filters.FindByID(RowID);
		If TheseAreSubordinateElements(RowDrag, DestinationRow) Then
			DragParameters.Action = DragAction.Cancel;
			Return;
		EndIf;
	EndDo;

	DragDestinationAtClient = Item.Name;
	
	If DragParameters.Value.Count() > 0 Then 
		StandardProcessing = False;
	EndIf;

EndProcedure

&AtClient
Procedure FiltersDrag(Item, DragParameters, StandardProcessing, CurrentRow, Field)
	
	If DragParameters.Action = DragAction.Cancel Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If DragSourceAtClient = Item.Name Then 
		DragSelectionsWithinCollection(DragParameters, CurrentRow);
	EndIf;
EndProcedure

&AtClient
Procedure FiltersDragEnd(Item, DragParameters, StandardProcessing)
	
	If DragParameters.Action = DragAction.Cancel Then
		Return;
	EndIf;
	
	If DragDestinationAtClient <> Item.Name Then 
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID, ExtendedMode);
	
	Rows = DragParameters.Value;
	Parent = Rows[0].GetParent();
	
	IndexOf = Rows.UBound();
	While IndexOf >= 0 Do 
		String = Rows[IndexOf];
		
		SettingItem = SettingItem(StructureItemProperty, String);
		SettingItemParent = StructureItemProperty;
		If SettingItem.Parent <> Undefined Then 
			SettingItemParent = SettingItem.Parent;
		EndIf;
		
		SettingItemParent.Items.Delete(SettingItem);
		Parent.GetItems().Delete(String);
		
		IndexOf = IndexOf - 1;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFields

&AtClient
Procedure ChangeFormula(Command)
	
	String = Items.SelectedFields.CurrentData;
	
	If String = Undefined Or Not String.IsFormula Then 
		Return;
	EndIf;

	Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(Report.SettingsComposer.Settings, String(String.Field));
	
	If TypeOf(Formula) <> Type("DataCompositionUserFieldExpression") Then
		NotifyDescription = New NotifyDescription("WhenClosingSettingsFormForTechnician", ThisObject);
		OpenSettingsFormForTechnician("UserFieldsPage", NotifyDescription);
		Return;
	EndIf;
		
	ReportsOptionsInternalClient.ChangeFormula(
		ThisObject, Report.SettingsComposer.Settings, String(String.Field));
	
EndProcedure

// Parameters:
//  FormulaDescription - DataCompositionAvailableField
//                  - Structure:
//                      * Description - String
//                      * FormulaPresentation - String
//                      * Formula - String
//  Formula - Structure:
//    * FieldsCollection - DataCompositionAvailableFields
//    * Formula - DataCompositionUserFieldExpression
//
&AtClient
Procedure AfterChangingTheFormula(FormulaDescription, Formula) Export 
	
	If TypeOf(FormulaDescription) <> Type("Structure") Then 
		Return;
	EndIf;
	
	ReportsOptionsInternalClient.AfterChangingTheFormula(FormulaDescription, Formula);
	
	String = Items.SelectedFields.CurrentData; // FormDataTreeItem
	
	If String <> Undefined Then 
		String.Title = FormulaDescription.Title;
	EndIf;
	
	DetermineIfModified();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOptionStructure

&AtClient
Procedure OptionStructureOnActivateRow(Item)
	AttachIdleHandler("OptionStructureOnChangeCurrentRow", 0.1, True);
EndProcedure

&AtClient
Procedure OptionStructureSelection(Item, IDRow, Field, StandardProcessing)
	If ExtendedMode = 0 Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	String = Item.CurrentData;
	If String = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	If String.Type = "DataCompositionSettings"
		Or String.Type = "DataCompositionTableStructureItemCollection"
		Or String.Type = "DataCompositionChartStructureItemCollection" Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	If Field = Items.OptionStructurePresentation
		Or Field = Items.OptionStructureContainsFilters
		Or Field = Items.OptionStructureContainsFieldsOrOrders
		Or Field = Items.OptionStructureContainsConditionalAppearance Then
		
		StandardProcessing = False;
		PageName = Undefined;
		If Field = Items.OptionStructureContainsFilters Then
			PageName = "FiltersPage";
		ElsIf Field = Items.OptionStructureContainsFieldsOrOrders Then
			PageName = "SelectedFieldsAndSortingsPage";
		ElsIf Field = Items.OptionStructureContainsConditionalAppearance Then
			PageName = "AppearancePage";
		EndIf;
		ChangeStructureItem(String, PageName);
	EndIf;
	
EndProcedure

&AtClient
Procedure OptionStructureBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Not Items.OptionStructure_Add.Enabled Then
		Return;
	EndIf;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	AddOptionStructureGrouping();
EndProcedure

&AtClient
Procedure OptionStructure_Group(Command)
	If Items.OptionStructure_Group.Enabled Then
		AddOptionStructureGrouping(False);
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_AddTable(Command)
	If Items.OptionStructure_AddTable.Enabled Then
		AddSettingsStructureItem(Type("DataCompositionTable"));
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_AddChart(Command)
	If Items.OptionStructure_AddChart.Enabled Then
		AddSettingsStructureItem(Type("DataCompositionChart"));
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_CheckAll(Command)
	ChangeUsage("OptionStructure");
EndProcedure

&AtClient
Procedure OptionStructure_UncheckAll(Command)
	ChangeUsage("OptionStructure", False);
EndProcedure

&AtClient
Procedure OptionStructureDragStart(Item, DragParameters, StandardProcessing)
	// Check general conditions.
	If ExtendedMode = 0 Then
		StandardProcessing = False;
		Return;
	EndIf;
	// Check the source.
	String = OptionStructure.FindByID(DragParameters.Value);
	If String = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	If String.Type = "DataCompositionChartStructureItemCollection"
		Or String.Type = "DataCompositionTableStructureItemCollection"
		Or String.Type = "DataCompositionSettings" Then
		StandardProcessing = False;
		Return;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructureDragCheck(Item, DragParameters, StandardProcessing, DestinationID, Field)
	// Check general conditions.
	If DestinationID = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Check the source.
	String = OptionStructure.FindByID(DragParameters.Value);
	If String = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	// Check the destination.
	NewParent = OptionStructure.FindByID(DestinationID);
	If NewParent = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	If NewParent.Type = "DataCompositionTable"
		Or NewParent.Type = "DataCompositionChart" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	// Check compatibility of the source and destination.
	OnlyGroupingsAreAllowed = False;
	If NewParent.Type = "TableStructureItemCollection"
		Or NewParent.Type = "ChartStructureItemCollection"
		Or NewParent.Type = "TableGroup"
		Or NewParent.Type = "ChartGroup" Then
		OnlyGroupingsAreAllowed = True;
	EndIf;
	
	If OnlyGroupingsAreAllowed
		And String.Type <> "Group"
		And String.Type <> "TableGroup"
		And String.Type <> "ChartGroup" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	CollectionsOfCollections = New Array;
	CollectionsOfCollections.Add(String.GetItems());
	Count = 1;
	While Count > 0 Do
		Collection = CollectionsOfCollections[0];
		Count = Count - 1;
		CollectionsOfCollections.Delete(0);
		For Each NestedRow In Collection Do
			If NestedRow = NewParent Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			If OnlyGroupingsAreAllowed
				And NestedRow.Type <> "Group"
				And NestedRow.Type <> "TableGroup"
				And NestedRow.Type <> "ChartGroup" Then
				DragParameters.Action = DragAction.Cancel;
				Return;
			EndIf;
			CollectionsOfCollections.Add(NestedRow.GetItems());
			Count = Count + 1;
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure OptionStructureDrag(Item, DragParameters, StandardProcessing, DestinationID, Field)
	// All checks have been passed.
	StandardProcessing = False;
	
	String = OptionStructure.FindByID(DragParameters.Value);
	NewParent = OptionStructure.FindByID(DestinationID);
	
	Result = MoveOptionStructureItems(String, NewParent);
	
	Items.OptionStructure.Expand(NewParent.GetID(), True);
	Items.OptionStructure.CurrentRow = Result.String.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure OptionStructureUseOnChange(Item)
	ChangeSettingItemUsage("OptionStructure");
EndProcedure

&AtClient
Procedure OptionStructureTitleOnChange(Item)
	String = Items.OptionStructure.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	UpdateOptionStructureItemTitle(String);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure OptionStructure_MoveUp(Command)
	Context = NewContext("OptionStructure", "MoveTo");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	ShiftRows(Context);
EndProcedure

&AtClient
Procedure OptionStructure_MoveDown(Command)
	Context = NewContext("OptionStructure", "MoveTo");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	ShiftRows(Context);
EndProcedure

&AtClient
Procedure OptionStructure_MoveOneLevelUp(Command)
	Context = NewContext("OptionStructure", "MoveToHierarchy");
	Context.Insert("Direction", -1);
	DefineSelectedRows(Context);
	
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveToHierarchy(Context);
EndProcedure

&AtClient
Procedure OptionStructure_MoveOneLevelBelow(Command)
	Context = NewContext("OptionStructure", "MoveToHierarchy");
	Context.Insert("Direction", 1);
	DefineSelectedRows(Context);
	
	If ValueIsFilled(Context.CancelReason) Then
		ShowMessageBox(, Context.CancelReason);
		Return;
	EndIf;
	
	MoveToHierarchy(Context);
EndProcedure

&AtClient
Procedure OptionStructure_Change(Command)
	TableItem = Items.OptionStructure;
	Field = TableItem.CurrentItem;
	StandardProcessing = True;
	IDRow = TableItem.CurrentRow;
	OptionStructureSelection(TableItem, IDRow, Field, StandardProcessing);
EndProcedure

&AtClient
Procedure OptionStructureBeforeDeleteRow(Item, Cancel)
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure OptionStructure_MoveUpAndLeft(Command)
	If Not Items.OptionStructure_MoveUpAndLeft.Enabled Then
		Return;
	EndIf;
	TableRowUp = Items.OptionStructure.CurrentData;
	If TableRowUp = Undefined Then
		Return;
	EndIf;
	TableRowDown = TableRowUp.GetParent();
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("Mode",              "UpAndLeft");
	ExecutionParameters.Insert("TableRowUp", TableRowUp);
	ExecutionParameters.Insert("TableRowDown",  TableRowDown);
	OptionStructure_MoveTo(-1, ExecutionParameters);
EndProcedure

&AtClient
Procedure OptionStructure_MoveDownAndRight(Command)
	If Not Items.OptionStructure_MoveDownAndRight.Enabled Then
		Return;
	EndIf;
	TableRowDown = Items.OptionStructure.CurrentData;
	If TableRowDown = Undefined Then
		Return;
	EndIf;
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("Mode",              "DownAndRight");
	ExecutionParameters.Insert("TableRowUp", Undefined);
	ExecutionParameters.Insert("TableRowDown",  TableRowDown);
	
	SubordinateRows = TableRowDown.GetItems();
	Count = SubordinateRows.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		ExecutionParameters.TableRowUp = SubordinateRows[0];
		OptionStructure_MoveTo(-1, ExecutionParameters);
	Else
		List = New ValueList;
		For LineNumber = 1 To Count Do
			SubordinateRow = SubordinateRows[LineNumber-1];
			List.Add(SubordinateRow.GetID(), SubordinateRow.Presentation);
		EndDo;
		Handler = New NotifyDescription("OptionStructure_MoveTo", ThisObject, ExecutionParameters);
		ShowChooseFromMenu(Handler, List);
	EndIf;
	
EndProcedure

&AtClient
Procedure OptionStructure_MoveTo(Result, ExecutionParameters) Export
	If Result <> -1 Then
		If TypeOf(Result) <> Type("ValueListItem") Then
			Return;
		EndIf;
		TableRowUp = OptionStructure.FindByID(Result.Value);
	Else
		TableRowUp = ExecutionParameters.TableRowUp;
	EndIf;
	TableRowDown = ExecutionParameters.TableRowDown;
	
	// 0. Memorize the item before which to insert the top row.
	RowsDown = TableRowDown.GetItems();
	IndexOf = RowsDown.IndexOf(TableRowUp);
	RowsIDsArrayDown = New Array;
	For Each TableRow In RowsDown Do
		If TableRow = TableRowUp Then
			Continue;
		EndIf;
		RowsIDsArrayDown.Add(TableRow.GetID());
	EndDo;
	
	// 1. Move the bottom row up to the top row level.
	Result = MoveOptionStructureItems(TableRowUp, TableRowDown.GetParent(), TableRowDown);
	TableRowUp = Result.String;
	
	// 2. Memorize which rows are to be moved.
	RowsUp = TableRowUp.GetItems();
	
	// 3. Switch the rows.
	For Each TableRow In RowsUp Do
		MoveOptionStructureItems(TableRow, TableRowDown);
	EndDo;
	For Each TableRowID In RowsIDsArrayDown Do
		TableRow = OptionStructure.FindByID(TableRowID);
		MoveOptionStructureItems(TableRow, TableRowUp);
	EndDo;
	
	// 4. Move the top row down to the bottom row level.
	RowsUp = TableRowUp.GetItems();
	If RowsUp.Count() - 1 < IndexOf Then
		BeforeWhatToInsert = Undefined;
	Else
		BeforeWhatToInsert = RowsUp[IndexOf];
	EndIf;
	Result = MoveOptionStructureItems(TableRowDown, TableRowUp, BeforeWhatToInsert);
	TableRowDown = Result.String;
	
	// Bells and whistles.
	If ExecutionParameters.Mode = "DownAndRight" Then
		CurrentRow = TableRowDown;
	Else
		CurrentRow = TableRowUp;
	EndIf;
	IDCurrentRow = CurrentRow.GetID();
	Items.OptionStructure.Expand(IDCurrentRow, True);
	Items.OptionStructure.CurrentRow = IDCurrentRow;
	
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

&AtClient
Procedure OptionStructure_SaveToFile(Command)
	Address = SettingsAddressInXMLString();
	FileName = NStr("en = 'Settings.xml';");
	
	SavingParameters = FileSystemClient.FileSavingParameters();
	SavingParameters.Dialog.Title = NStr("en = 'Select a file to save report settings';");
	SavingParameters.Dialog.Filter    = NStr("en = 'Report settings (*.xml)|*.xml';");
	
	FileSystemClient.SaveFile(Undefined, Address, FileName, SavingParameters);
EndProcedure

&AtServer
Function SettingsAddressInXMLString()
	Return PutToTempStorage(
		Common.ValueToXMLString(Report.SettingsComposer.Settings),
		UUID);
EndFunction

#EndRegion

#Region FormTableItemsEventHandlersGroupingComposition

&AtClient
Procedure GroupingCompositionUseOnChange(Item)
	ChangeSettingItemUsage("GroupingComposition");
EndProcedure

&AtClient
Procedure GroupingCompositionSelection(Item, RowID, Field, StandardProcessing)
	
	String = Items.GroupingComposition.CurrentData;
	If String = Undefined Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	If Field = Items.GroupingCompositionField Then
		StandardProcessing = False;
		If TypeOf(String.Field) = Type("DataCompositionField") Then 
			GroupContentSelectField(RowID, String);
		EndIf;
	ElsIf Field <> Items.GroupingCompositionGroupType
		And Field <> Items.GroupingCompositionAdditionType Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure GroupingCompositionBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	SelectField("GroupingComposition", New NotifyDescription("GroupCompositionAfterFieldChoice", ThisObject));
EndProcedure

&AtClient
Procedure GroupingCompositionBeforeDeleteRow(Item, Cancel)
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure GroupingCompositionGroupTypeOnChange(Item)
	String = Items.GroupingComposition.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.GroupType = String.GroupType;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure GroupingCompositionAdditionTypeOnChange(Item)
	String = Items.GroupingComposition.CurrentData;
	If String = Undefined Then
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.AdditionType = String.AdditionType;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure GroupingComposition_MoveUp(Command)
	ShiftGroupField();
EndProcedure

&AtClient
Procedure GroupingComposition_MoveDown(Command)
	ShiftGroupField(False);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAppearance

&AtClient
Procedure AppearanceBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	AppearanceChangeItem();
EndProcedure

&AtClient
Procedure AppearanceSelection(Item, RowID, Field, StandardProcessing)
	StandardProcessing = False;
	
	String = Items.Appearance.CurrentData;
	If String = Undefined Or String.IsSection Then 
		Return;
	EndIf;
	
	If String.IsOutputParameter Then 
		If String(String.Id) = "TITLE"
			And Field = Items.AppearanceTitle Then 
			
			Handler = New NotifyDescription("AppearanceTitleInputCompletion", ThisObject, RowID);
			ShowInputString(Handler, String.Value, NStr("en = 'Printing header';"),, True);
		EndIf;
	ElsIf Field = Items.AppearanceTitle Then // Change the order.
		AppearanceChangeItem(RowID, String);
	ElsIf Field = Items.AppearanceAccessPictureIndex Then // Change quick access to the filter.
		StructureItemProperty = SettingsStructureItemProperty(
			Report.SettingsComposer, "ConditionalAppearance", SettingsStructureItemID);
		SelectTheDisplayModeForTheLine(StructureItemProperty, "Appearance", RowID, True, False);
	EndIf;
EndProcedure

&AtClient
Procedure AppearanceBeforeDeleteRow(Item, Cancel)
	DeleteRows(Item, Cancel);
EndProcedure

&AtClient
Procedure AppearanceUseOnChange(Item)
	ChangeSettingItemUsage("Appearance");
EndProcedure

&AtClient
Procedure Appearance_MoveUp(Command)
	ShiftAppearance();
EndProcedure

&AtClient
Procedure Appearance_MoveDown(Command)
	ShiftAppearance(False);
EndProcedure

&AtClient
Procedure Appearance_SelectCheckBoxes(Command)
	ChangePredefinedOutputParametersUsage();
	ChangeUsage("Appearance");
EndProcedure

&AtClient
Procedure Appearance_ClearCheckBoxes(Command)
	ChangePredefinedOutputParametersUsage(False);
	ChangeUsage("Appearance", False);
EndProcedure

&AtClient
Procedure CustomizeHeadersFooters(Command)
	Var Settings;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Property("HeaderOrFooterSettings", Settings);
	
	OpenForm("CommonForm.HeaderAndFooterSettings",
		New Structure("Settings", Settings),
		ThisObject,
		UUID,,,
		New NotifyDescription("RememberHeaderFooterSettings", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure GenerateAndClose(Command)
	WriteAndClose(True);
EndProcedure

&AtClient
Procedure DontGenerateAndClose(Command)
	WriteAndClose(False);
EndProcedure

&AtClient
Procedure EditFiltersConditions(Command)
	FormParameters = New Structure;
	FormParameters.Insert("OwnerFormType", ReportFormType);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	Handler = New NotifyDescription("EditFiltersConditionsCompletion", ThisObject);
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ReportFiltersConditions", FormParameters, ThisObject, True,,, Handler);
EndProcedure

&AtClient
Procedure EditFiltersConditionsCompletion(FiltersConditions, Context) Export
	If FiltersConditions = Undefined
		Or FiltersConditions = DialogReturnCode.Cancel
		Or FiltersConditions.Count() = 0 Then
		Return;
	EndIf;
	
	ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters("EditFiltersConditions");
	ParametersOfUpdate.DCSettingsComposer = Report.SettingsComposer;
	ParametersOfUpdate.UserSettingsModified = True;
	ParametersOfUpdate.FiltersConditions =FiltersConditions;
	UpdateForm(ParametersOfUpdate);
EndProcedure

&AtClient
Procedure RemoveNonexistentFieldsFromSettings(Command)
	DeleteFiedsMarkedForDeletion();
	
	ParametersOfUpdate = ReportsClientServer.ReportFormUpdateParameters();
	ParametersOfUpdate.DCSettingsComposer = Report.SettingsComposer;
	UpdateForm(ParametersOfUpdate);
EndProcedure

&AtClient
Procedure GoToSettingsForTechnician(Command)
	
	OpenSettingsFormForTechnician(Items.SettingsPages.CurrentPage.Name);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Attachable commands.

&AtClient
Procedure Attachable_SelectPeriod(Command)
	ReportsClient.SelectPeriod(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_MoveThePeriodBack(Command)
	ReportsClient.ShiftThePeriod(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_MoveThePeriodForward(Command)
	ReportsClient.ShiftThePeriod(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_List_Pick(Command)
	ListPath = StrReplace(Command.Name, "Pickup", "");
	
	FillParameters = ListFillingParameters();
	FillParameters.ListPath = ListPath;
	FillParameters.IndexOf = PathToItemsData.ByName[ListPath];
	FillParameters.Owner = Items[ListPath];
	FillParameters.Insert("IsPick", True);
	
	StartListFilling(Items[Command.Name], FillParameters);
EndProcedure

&AtClient
Procedure Attachable_List_PasteFromClipboard(Command)
	ListPath = StrReplace(Command.Name, ReportsClientServer.PasteFromClipboardCommandName(), "");
	
	List = ThisObject[ListPath];
	ListBox = Items[ListPath]; // FormTable
	
	IndexOf = PathToItemsData.ByName[ListPath];
	InformationRecords = ReportsClient.SettingItemInfo(Report.SettingsComposer, IndexOf);
	UserSettings = Report.SettingsComposer.UserSettings.Items;
	
	ChoiceParameters = ReportsClientServer.ChoiceParameters(InformationRecords.Settings, UserSettings, InformationRecords.Item);
	List.ValueType = ReportsClient.ValueTypeRestrictedByLinkByType(
		InformationRecords.Settings, UserSettings, InformationRecords.Item, InformationRecords.LongDesc);
	
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", TypesDetailsWithoutPrimitiveOnes(List.ValueType));
	SearchParameters.Insert("FieldPresentation", ListBox.Title);
	SearchParameters.Insert("Scenario", "PastingFromClipboard");
	SearchParameters.Insert("ChoiceParameters", ChoiceParameters);
	
	Handler = New NotifyDescription("PasteFromClipboard1Completion", ThisObject, ListPath);
	
	ModuleDataImportFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleDataImportFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

#EndRegion

#Region Private

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

#Region GroupFields

// Read settings.

&AtServer
Procedure UpdateGroupFields()
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	For Each SettingItem In StructureItemProperty.Items Do 
		String = GroupingComposition.GetItems().Add();
		FillPropertyValues(String, SettingItem);
		String.Id = StructureItemProperty.GetIDByObject(SettingItem);
		
		If TypeOf(SettingItem) = Type("DataCompositionAutoGroupField") Then 
			String.Title  = NStr("en = 'Auto (all fields)';");
			String.Picture = ReportsClientServer.PictureIndex("Item", "Predefined");
			Continue;
		EndIf;
		
		SettingDetails = StructureItemProperty.GroupFieldsAvailableFields.FindField(SettingItem.Field);
		If SettingDetails = Undefined Then 
			SetDeletionMark("GroupingComposition", String);
			Continue;
		EndIf;
		
		FillPropertyValues(String, SettingDetails);
		String.ShowAdditionType = SettingDetails.ValueType.ContainsType(Type("Date"));
		
		If SettingDetails.Resource Then
			String.Picture = ReportsClientServer.PictureIndex("Resource");
		ElsIf SettingDetails.Table Then
			String.Picture = ReportsClientServer.PictureIndex("Table");
		ElsIf SettingDetails.Folder Then
			String.Picture = ReportsClientServer.PictureIndex("Group");
		Else
			String.Picture = ReportsClientServer.PictureIndex("Item");
		EndIf;
	EndDo;
EndProcedure

// Add and modify items.

&AtClient
Procedure GroupContentSelectField(RowID, String)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	SettingItem = SettingItem(StructureItemProperty, String);
	
	Handler = New NotifyDescription("GroupCompositionAfterFieldChoice", ThisObject, RowID);
	SelectField("GroupingComposition", Handler, SettingItem.Field);
EndProcedure

&AtClient
Procedure GroupCompositionAfterFieldChoice(SettingDetails, RowID) Export
	If SettingDetails = Undefined Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	ReportsOptionsInternalClient.AddFormula(Settings, Settings.GroupAvailableFields, SettingDetails);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	
	If RowID = Undefined Then 
		String = GroupingComposition.GetItems().Add();
		SettingItem = StructureItemProperty.Items.Add(Type("DataCompositionGroupField"));
	Else
		String = GroupingComposition.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
	EndIf;
	
	SettingItem.Use = True;
	SettingItem.Field = SettingDetails.Field;
	
	FillPropertyValues(String, SettingItem);
	String.Id = StructureItemProperty.GetIDByObject(SettingItem);
	
	FillPropertyValues(String, SettingDetails);
	
	String.ShowAdditionType = SettingDetails.ValueType.ContainsType(Type("Date"));
	
	If SettingDetails.Resource Then
		String.Picture = ReportsClientServer.PictureIndex("Resource");
	ElsIf SettingDetails.Table Then
		String.Picture = ReportsClientServer.PictureIndex("Table");
	ElsIf SettingDetails.Folder Then
		String.Picture = ReportsClientServer.PictureIndex("Group");
	Else
		String.Picture = ReportsClientServer.PictureIndex("Item");
	EndIf;
	
	ChangeUsageOfLinkedSettingsItems("GroupingComposition", String, SettingItem);
	
	Items.GroupingComposition.CurrentRow = String.GetID();
	
	DetermineIfModified();
EndProcedure

// Shift items.

&AtClient
Procedure ShiftGroupField(ToBeginning = True)
	RowsIDs = Items.GroupingComposition.SelectedRows;
	If RowsIDs.Count() = 0 Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "GroupFields", SettingsStructureItemID);
	
	For Each RowID In RowsIDs Do 
		String = GroupingComposition.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
		
		SettingsItems = StructureItemProperty.Items;
		Rows = GroupingComposition.GetItems();
		
		IndexOf = SettingsItems.IndexOf(SettingItem);
		Boundary = SettingsItems.Count() - 1;
		
		If ToBeginning Then // Shifting to the collection beginning.
			If IndexOf = 0 Then 
				SettingsItems.Move(SettingItem, Boundary);
				Rows.Move(IndexOf, Boundary);
			Else
				SettingsItems.Move(SettingItem, -1);
				Rows.Move(IndexOf, -1);
			EndIf;
		Else // Shifting to the collection end.
			If IndexOf = Boundary Then 
				SettingsItems.Move(SettingItem, -Boundary);
				Rows.Move(IndexOf, -Boundary);
			Else
				SettingsItems.Move(SettingItem, 1);
				Rows.Move(IndexOf, 1);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

#EndRegion

#Region DataParametersAndFilters

// Read settings.

&AtServer
Procedure UpdateDataParameters()
	If ExtendedMode = 0
		Or SettingsStructureItemChangeMode Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "DataParameters", SettingsStructureItemID);
	
	Section = Filters.GetItems().Add();
	Section.IsSection = True;
	Section.Title = NStr("en = 'Parameters';");
	Section.Picture = ReportsClientServer.PictureIndex("DataParameters");
	Section.Id = "DataParameters";
	SectionItems = Section.GetItems();
	
	If StructureItemProperty = Undefined
		Or StructureItemProperty.Items.Count() = 0 Then 
		Return;
	EndIf;
	
	Schema = GetFromTempStorage(ReportSettings.SchemaURL); // DataCompositionSchema
	
	For Each SettingItem In StructureItemProperty.Items Do 
		FoundParameter = Schema.Parameters.Find(SettingItem.Parameter);
		If FoundParameter <> Undefined And FoundParameter.UseRestriction Then 
			Continue;
		EndIf;
		
		String = SectionItems.Add();
		FillPropertyValues(String, SettingItem);
		String.Id = StructureItemProperty.GetIDByObject(SettingItem);
		String.DisplayModePicture = SettingItemDisplayModePicture(SettingItem);
		String.Picture = -1;
		String.IsParameter = True;
		String.IsPeriod = (TypeOf(String.Value) = Type("StandardPeriod"));
		
		SettingDetails = StructureItemProperty.AvailableParameters.FindParameter(SettingItem.Parameter);
		If SettingDetails <> Undefined Then 
			FillPropertyValues(String, SettingDetails,, "Use");
			String.DisplayUsage = (SettingDetails.Use <> DataCompositionParameterUse.Always);
			
			If SettingDetails.AvailableValues <> Undefined Then 
				ListItem = SettingDetails.AvailableValues.FindByValue(SettingItem.Value);
				If ListItem <> Undefined Then 
					String.ValuePresentation = ListItem.Presentation;
				EndIf;
			EndIf;
		EndIf;
		
		If Not ValueIsFilled(String.UserSettingPresentation) Then 
			String.UserSettingPresentation = String.Title;
		EndIf;
		String.IsPredefinedTitle = (String.Title = String.UserSettingPresentation);
	EndDo;
EndProcedure

&AtServer
Procedure UpdateFilters(Rows = Undefined, SettingsItems = Undefined)
	If ExtendedMode = 0 Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	If Rows = Undefined Then 
		Section = Filters.GetItems().Add();
		Section.IsSection = True;
		Section.Title = NStr("en = 'Filters';");
		Section.Picture = ReportsClientServer.PictureIndex("Filters");
		Section.Id = "Filters";
		Rows = Section.GetItems();
	EndIf;
	
	If SettingsItems = Undefined Then 
		SettingsItems = StructureItemProperty.Items;
	EndIf;
	
	For Each SettingItem In SettingsItems Do 
		String = Rows.Add();
		
		If Not SetFiltersRowData(String, StructureItemProperty, SettingItem) Then 
			SetDeletionMark("Filters", String);
		EndIf;
		
		If TypeOf(SettingItem) = Type("DataCompositionFilterItemGroup") Then 
			UpdateFilters(String.GetItems(), SettingItem.Items);
		EndIf;
	EndDo;
EndProcedure

&AtClientAtServerNoContext
Function SetFiltersRowData(String, StructureItemProperty, SettingItem, SettingDetails = Undefined)
	InstalledSuccessfully1 = True;
	
	IsFolder = (TypeOf(SettingItem) = Type("DataCompositionFilterItemGroup"));
	
	If SettingDetails = Undefined Then 
		If Not IsFolder Then 
			SettingDetails = StructureItemProperty.FilterAvailableFields.FindField(SettingItem.LeftValue);
			InstalledSuccessfully1 = (SettingDetails <> Undefined);
		EndIf;
		
		If SettingDetails = Undefined Then 
			SettingDetails = New Structure("AvailableValues, AvailableCompareTypes");
			SettingDetails.Insert("ValueType", New TypeDescription("Undefined"));
		EndIf;
	EndIf;
	
	AvailableCompareTypes = SettingDetails.AvailableCompareTypes;
	If AvailableCompareTypes <> Undefined
		And AvailableCompareTypes.Count() > 0
		And AvailableCompareTypes.FindByValue(SettingItem.ComparisonType) = Undefined Then 
		SettingItem.ComparisonType = AvailableCompareTypes[0].Value;
	EndIf;
	
	FillPropertyValues(String, SettingDetails);
	FillPropertyValues(String, SettingItem);
	
	String.Id = StructureItemProperty.GetIDByObject(SettingItem);
	String.Field = String.Title;
	String.DisplayUsage = True;
	String.IsPeriod = (TypeOf(String.RightValue) = Type("StandardPeriod"));
	String.IsUUID = (TypeOf(String.RightValue) = Type("UUID")); 

	If String.ValueType = New TypeDescription("Date") And Not ReportsClientServer.IsListComparisonKind(SettingItem.ComparisonType) Then
		String.ValueType = New TypeDescription("StandardBeginningDate");
	EndIf;

	String.IsFolder = IsFolder;
	String.DisplayModePicture = SettingItemDisplayModePicture(SettingItem);
	String.Picture = -1;
	
	If IsFolder Then 
		String.Title = String.GroupType;
	Else
		ReportsClientServer.CastValueToType(SettingItem.RightValue, SettingDetails.ValueType);
	EndIf;
	
	If Not ValueIsFilled(String.UserSettingPresentation) Then 
		If ValueIsFilled(SettingItem.Presentation) Then 
			String.UserSettingPresentation = SettingItem.Presentation;
		Else
			String.UserSettingPresentation = String.Title;
		EndIf;
	EndIf;
	String.IsPredefinedTitle = (String.Title = String.UserSettingPresentation);
	
	CastValueToComparisonKind(String, SettingItem);
	SetValuePresentation(String, StructureItemProperty.FilterAvailableFields);
	
	Return InstalledSuccessfully1;
EndFunction

// Add and modify items.

&AtClient
Procedure FiltersSelectGroup(RowID)
	Handler = New NotifyDescription("FiltersAfterGroupChoice", ThisObject, RowID);
	
	List = New ValueList;
	List.Add(DataCompositionFilterItemsGroupType.AndGroup);
	List.Add(DataCompositionFilterItemsGroupType.OrGroup);
	List.Add(DataCompositionFilterItemsGroupType.NotGroup);
	
	ShowChooseFromMenu(Handler, List);
EndProcedure

&AtClient
Procedure FiltersAfterGroupChoice(GroupType, RowID) Export
	If GroupType = Undefined Then
		Return;
	EndIf;
	
	String = Filters.FindByID(RowID);
	If String = Undefined Then
		Return;
	EndIf;
	If Not String.IsFolder Then
		ShowMessageBox(, NStr("en = 'Select a group.';"));
		Return;
	EndIf;

	String.GroupType = ?(TypeOf(GroupType) = Type("DataCompositionFilterItemsGroupType"), GroupType, GroupType.Value);
	String.Title = String.GroupType;
	String.UserSettingPresentation = String.GroupType;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.GroupType = String.GroupType;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure QualifiersBeforeSelectField(RowID = Undefined)
	If Not SettingsStructureItemChangeMode Then
		String = Items.Filters.CurrentData;
		
		If (String = Undefined)
			Or (String.IsParameter)
			Or (String.IsSection And String.Id = "DataParameters") Then
			
			String = Filters.GetItems()[1];
			Items.Filters.CurrentRow = String.GetID();
		EndIf;
	EndIf;
	
	Handler = New NotifyDescription("FiltersAfterFieldChoice", ThisObject, RowID);
	SelectField("Filters", Handler);
EndProcedure

&AtClient
Procedure FiltersAfterFieldChoice(SettingDetails, RowID) Export
	If SettingDetails = Undefined Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	ReportsOptionsInternalClient.AddFormula(Settings, Settings.FilterAvailableFields, SettingDetails);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	If RowID = Undefined Then 
		Parent = Items.Filters.CurrentData; // See SettingsFormCollectionItem
		If Parent = Undefined Then
			Parent = DefaultRootRow("Filters"); // See SettingsFormCollectionItem
		EndIf;
		If Not Parent.IsSection And Not Parent.IsFolder Then 
			Parent = Parent.GetParent();
		EndIf;
		String = Parent.GetItems().Add();
		
		SettingItemParent = StructureItemProperty;
		If TypeOf(Parent.Id) = Type("DataCompositionID") Then 
			SettingItemParent = StructureItemProperty.GetObjectByID(Parent.Id);
		EndIf;
		SettingItem = SettingItemParent.Items.Add(Type("DataCompositionFilterItem"));
	Else
		String = Filters.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
	EndIf;
	
	SettingItem.Use = True;
	SettingItem.LeftValue = SettingDetails.Field;
	SettingItem.RightValue = SettingDetails.Type.AdjustValue();
	SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	SettingItem.UserSettingID = New UUID;
	SettingItem.UserSettingPresentation = "";
	
	AvailableCompareTypes = SettingDetails.AvailableCompareTypes;
	If AvailableCompareTypes <> Undefined
		And AvailableCompareTypes.Count() > 0
		And AvailableCompareTypes.FindByValue(SettingItem.ComparisonType) = Undefined Then 
		SettingItem.ComparisonType = AvailableCompareTypes[0].Value;
	EndIf;
	
	SetFiltersRowData(String, StructureItemProperty, SettingItem, SettingDetails);
	
	Section = DefaultRootRow("Filters");
	Items.Filters.Expand(Section.GetID(), True);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure SetFilterElementEditOptions()
	
	String = Items.Filters.CurrentData;
	
	If String = Undefined
		Or String.IsSection
		Or String.IsFolder Then
		
		Return;
	EndIf;
	
#Region EditOptionsConditions
	
	ConditionField = Items.FiltersComparisonType;
	ConditionField.ListChoiceMode = (String.AvailableCompareTypes <> Undefined);
	
	If String.AvailableCompareTypes <> Undefined Then 
		
		List = ConditionField.ChoiceList;
		List.Clear();
		
		For Each ComparisonKinds In String.AvailableCompareTypes Do 
			FillPropertyValues(List.Add(), ComparisonKinds);
		EndDo;
		
	EndIf;
	
	If String.IsParameter Then 
		
		Condition = DataCompositionComparisonType.Equal;
		If String.ValueListAllowed Then 
			Condition = DataCompositionComparisonType.InList;
		EndIf;
		
	Else
		Condition = String.ComparisonType;
	EndIf;
	
#EndRegion
	
#Region EditParametersValues
	
	ValueField = ?(String.IsParameter, Items.FiltersValue, Items.FiltersRightValue);
	ValueField.AvailableTypes = String.ValueType;
	ValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(String.ChoiceFoldersAndItems, Condition);
	
	List = ValueField.ChoiceList;
	List.Clear();
	
	If String.AvailableValues <> Undefined Then 
		
		For Each AvailableValue In String.AvailableValues Do 
			FillPropertyValues(List.Add(), AvailableValue);
		EndDo;
		
	EndIf;
	
#EndRegion
	
EndProcedure

&AtClient
Procedure FiltersOnChangeCurrentRow()
	String = Items.Filters.CurrentData;
	
	If String = Undefined Then
		SetTheAvailabilityOfSelectionCommands();
	Else
		SetTheAvailabilityOfSelectionCommands(Not String.IsParameter And Not String.IsSection, String.IsSection);
	EndIf;
EndProcedure

&AtClient
Procedure SetTheAvailabilityOfSelectionCommands(IsFilter = False, IsSection = False)
	Items.Filters_Delete.Enabled = IsFilter;
	Items.Filters_Delete1.Enabled = IsFilter;
	Items.Filters_Group.Enabled = IsFilter;
	Items.Filters_Group1.Enabled = IsFilter;
	Items.Filters_Ungroup.Enabled = IsFilter;
	Items.Filters_Ungroup1.Enabled = IsFilter;
	Items.Filters_MoveUp.Enabled = IsFilter;
	Items.Filters_MoveUp1.Enabled = IsFilter;
	Items.Filters_MoveDown.Enabled = IsFilter;
	Items.Filters_MoveDown1.Enabled = IsFilter;
	
	Items.FiltersCommands_Show.Enabled = Not IsSection;
	Items.FiltersCommands_Show1.Enabled = Not IsSection;
	Items.Filters_ShowOnlyCheckBoxInReportHeader.Enabled = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportHeader1.Enabled = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportSettings.Enabled = IsFilter;
	Items.Filters_ShowOnlyCheckBoxInReportSettings1.Enabled = IsFilter;
EndProcedure

&AtClient
Procedure FiltersSetDisplayMode(ViewMode)
	
	IDOfTheRows = Items.Filters.SelectedRows;
	If IDOfTheRows.Count() = 0 Then 
		Return;
	EndIf;
	
	PropertiesOfSettingsElements = New Array;
	ParametersCount = 0;
	
	For Each RowID In IDOfTheRows Do 
		
		String = Filters.FindByID(RowID);
		
		If String.IsSection Then 
			Continue;
		EndIf;
		
		If String.IsParameter Then 
			StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "DataParameters");
			ParametersCount = ParametersCount + 1;
		Else
			StructureItemProperty = SettingsStructureItemProperty(
				Report.SettingsComposer, "Filter", SettingsStructureItemID);
		EndIf;
		
		SettingsItem = StructureItemProperty.GetObjectByID(String.Id);
		
		PropertiesOfTheSettingsElement = New Structure;
		PropertiesOfTheSettingsElement.Insert("RowID", RowID);
		PropertiesOfTheSettingsElement.Insert("IDOfTheSettingsElement", String.Id);
		PropertiesOfTheSettingsElement.Insert("SettingsItem", SettingsItem);
		
		PropertiesOfSettingsElements.Add(PropertiesOfTheSettingsElement);
		
	EndDo;
	
	ShowCheckBoxesModes = (ParametersCount = PropertiesOfSettingsElements.Count());
	SelectTheDisplayModeForRows(PropertiesOfSettingsElements, "Filters", ShowCheckBoxesModes, ViewMode);
	
EndProcedure

&AtClient
Procedure List_AtStartChanges()
	
	ListPath = List_BeforeStartChanges.Name;
	ListItem = Items[List_BeforeStartChanges.Name + "Value"];
	
	FillParameters = ListFillingParameters(True, False, False);
	FillParameters.ListPath = ListPath;
	FillParameters.IndexOf = PathToItemsData.ByName[ListPath];
	
	ChoiceOverride = False;
	StartListFilling(ListItem, FillParameters, ChoiceOverride);
	
	If ChoiceOverride Then
		List_BeforeStartChanges.EndEditRow(False);
		Return;
	EndIf;
	
	ListItem.TextEdit = True;
	
EndProcedure

// Modify item grouping.

// Returns:
//  Structure:
//    * Rows - Array of FormDataTreeItem:
//    * Parent - FormDataTreeItem:
//        ** Id - DataCompositionID
//    * IndexOf - Number
//   Undefined
//
&AtClient
Function FiltersGroupingParameters()
	Rows = New Array;
	Parents = New Array;
	
	RowsIDs = Items.Filters.SelectedRows;
	For Each RowID In RowsIDs Do 
		String = Filters.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID") Then 
			Continue;
		EndIf;
		
		Rows.Add(String);
		Parents.Add(Parent);
	EndDo;
	
	If Rows.Count() = 0 Then 
		ShowMessageBox(, NStr("en = 'Select items.';"));
		Return Undefined;
	EndIf;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		ShowMessageBox(, NStr("en = 'Cannot group selected items as they have different parents.';"));
		Return Undefined;
	EndIf;
	
	Rows = ArraySort(Rows);
	Parent = Parents[0];
	SubordinateItems = Parent.GetItems(); // FormDataTreeItemCollection 
	
	IndexOf = SubordinateItems.IndexOf(Rows[0]);
	
	Return New Structure("Rows, Parent, IndexOf", Rows, Parent, IndexOf);
EndFunction

&AtClient
Procedure ChangeFiltersGrouping(SettingsNodeFilters, Rows, SettingsItemsInheritors, RowsInheritors)
	For Each SourceRow In Rows Do 
		SettingItemSource = SettingsNodeFilters.GetObjectByID(SourceRow.Id);
		
		If SettingItemSource.Parent = Undefined Then 
			SourceSettingItemParent = SettingsNodeFilters;
		Else
			SourceSettingItemParent = SettingItemSource.Parent;
		EndIf;
		DestinationSettingItemParent = SettingsItemsInheritors.Get(SourceSettingItemParent); // DataCompositionFilterItemGroup
		
		SourceRowParent = SourceRow.GetParent();
		DestinationRowParent1 = RowsInheritors.Get(SourceRowParent);
		
		IndexOf = DestinationSettingItemParent.Items.IndexOf(SourceSettingItemParent);
		If IndexOf < 0 Then 
			SettingItemDestination = DestinationSettingItemParent.Items.Add(TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent1.GetItems().Add();
		Else // This is grouping deletion.
			SettingItemDestination = DestinationSettingItemParent.Items.Insert(IndexOf, TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent1.GetItems().Insert(IndexOf);
		EndIf;
		
		FillPropertyValues(SettingItemDestination, SettingItemSource);
		FillPropertyValues(DestinationRow, SourceRow);
		DestinationRow.Id = SettingsNodeFilters.GetIDByObject(SettingItemDestination);
		
		SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
		RowsInheritors.Insert(SourceRow, DestinationRow);
		
		ChangeFiltersGrouping(SettingsNodeFilters, SourceRow.GetItems(), SettingsItemsInheritors, RowsInheritors);
	EndDo;
EndProcedure

&AtClient
Procedure DeleteBasicFiltersGroupingItems(SettingsNodeFilters, GroupingParameters)
	Parent = GroupingParameters.Parent; // See SettingsFormCollectionItem
	Rows = Parent.GetItems();
	
	SettingsItems = SettingsNodeFilters.Items;
	If TypeOf(Parent.Id) = Type("DataCompositionID") Then 
		SettingsItems = SettingsNodeFilters.GetObjectByID(Parent.Id).Items;
	EndIf;
	
	IndexOf = GroupingParameters.Rows.UBound();
	While IndexOf >= 0 Do 
		String = GroupingParameters.Rows[IndexOf]; // See SettingsFormCollectionItem
		SettingItem = SettingsNodeFilters.GetObjectByID(String.Id);
		
		Rows.Delete(String);
		SettingsItems.Delete(SettingItem);
		
		IndexOf = IndexOf - 1;
	EndDo;
EndProcedure

// Drag items.

&AtClient
Procedure CheckDraggableRowsFromSelections(RowsIDs)
	Parents = New Array;
	
	IndexOf = RowsIDs.UBound();
	While IndexOf >= 0 Do 
		RowID = RowsIDs[IndexOf];
		
		String = Filters.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined
			Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID")
			Or Parent.Id = "DataParameters" Then 
			RowsIDs.Delete(IndexOf);
		Else
			Parents.Add(Parent);
		EndIf;
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		RowsIDs.Clear();
	EndIf;
EndProcedure

&AtClient
Procedure DragSelectionsWithinCollection(DragParameters, CurrentRow) 
	
	CurrentData = Filters.FindByID(CurrentRow);
	
	Rows = New Array;
	For Each RowID In DragParameters.Value Do 
		Rows.Add(Filters.FindByID(RowID));
	EndDo;
	
	SourceRow = Rows[0].GetParent(); // See SettingsFormCollectionItem
	If CurrentData.IsSection Or CurrentData.IsFolder Then 
		DestinationRow = CurrentData;
	Else
		DestinationRow = CurrentData.GetParent();
	EndIf; 
	
	IndexOf = DestinationRow.GetItems().IndexOf(CurrentData);
	If IndexOf < 0 Then 
		IndexOf = 0;
	EndIf;
	
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRow, DestinationRow);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID, ExtendedMode);
	
	SettingItemSource = StructureItemProperty;
	If TypeOf(SourceRow.Id) = Type("DataCompositionID") Then 
		SettingItemSource = StructureItemProperty.GetObjectByID(SourceRow.Id);
	EndIf;
	
	SettingItemDestination = StructureItemProperty;
	If TypeOf(DestinationRow.Id) = Type("DataCompositionID") Then 
		SettingItemDestination = StructureItemProperty.GetObjectByID(DestinationRow.Id);
	EndIf;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
	
	DragAndDropFilters(StructureItemProperty, IndexOf, Rows, SettingsItemsInheritors, RowsInheritors);
	
	Section = DefaultRootRow("Filters");
	Items.Filters.Expand(Section.GetID(), True);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure DragAndDropFilters(SelectedSettingsNodeFields, IndexOf, Rows, SettingsItemsInheritors, RowsInheritors)
	For Each SourceRow In Rows Do
		SettingItemSource = SelectedSettingsNodeFields.GetObjectByID(SourceRow.Id);
		
		SettingItemParentSource = SelectedSettingsNodeFields;
		If SettingItemSource.Parent <> Undefined Then 
			SettingItemParentSource = SettingItemSource.Parent;
		EndIf;
		
		SettingItemParentDestination = SettingsItemsInheritors.Get(SettingItemParentSource); // DataCompositionFilterItemGroup
		DestinationRowParent = RowsInheritors.Get(SourceRow.GetParent()); // See SettingsFormCollectionItem
		
		If IndexOf > SettingItemParentDestination.Items.Count() - 1 Then 
			SettingItemDestination = SettingItemParentDestination.Items.Add(TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent.GetItems().Add();
		Else
			SettingItemDestination = SettingItemParentDestination.Items.Insert(IndexOf, TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent.GetItems().Insert(IndexOf);
		EndIf;
		
		FillPropertyValues(SettingItemDestination, SettingItemSource);
		FillPropertyValues(DestinationRow, SourceRow);
		DestinationRow.Id = SelectedSettingsNodeFields.GetIDByObject(SettingItemDestination);
		DestinationRow.IsFolder = (TypeOf(SettingItemDestination) = Type("DataCompositionFilterItemGroup"));
		
		SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
		RowsInheritors.Insert(SourceRow, DestinationRow);
		
		If TypeOf(SettingItemDestination) = Type("DataCompositionFilterItemGroup") Then 
			DragAndDropFilters(SelectedSettingsNodeFields, IndexOf, SourceRow.GetItems(), SettingsItemsInheritors, RowsInheritors)
		EndIf;
	EndDo;
EndProcedure

// Shift items.

&AtClient
Procedure ShiftFilters(ToBeginning = True)
	ShiftParameters = FiltersShiftParameters();
	If ShiftParameters = Undefined Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Filter", SettingsStructureItemID);
	
	For Each ListLine In ShiftParameters.Rows Do 
		SettingItem = SettingItem(StructureItemProperty, ListLine);
		SettingsItems = StructureItemProperty.Items;
		
		If SettingItem.Parent <> Undefined Then
			SettingsItems = SettingItem.Parent.Items;
		EndIf;
		Rows = ShiftParameters.Parent.GetItems();
		
		IndexOf = SettingsItems.IndexOf(SettingItem);
		Boundary = SettingsItems.Count() - 1;
		
		If ToBeginning Then // Shifting to the collection beginning.
			If IndexOf = 0 Then 
				SettingsItems.Move(SettingItem, Boundary);
				Rows.Move(IndexOf, Boundary);
			Else
				SettingsItems.Move(SettingItem, -1);
				Rows.Move(IndexOf, -1);
			EndIf;
		Else // Shifting to the collection end.
			If IndexOf = Boundary Then 
				SettingsItems.Move(SettingItem, -Boundary);
				Rows.Move(IndexOf, -Boundary);
			Else
				SettingsItems.Move(SettingItem, 1);
				Rows.Move(IndexOf, 1);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Function FiltersShiftParameters()
	Rows = New Array;
	Parents = New Array;
	
	RowsIDs = Items.Filters.SelectedRows;
	For Each RowID In RowsIDs Do 
		String = Filters.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID") Then 
			Continue;
		EndIf;
		
		Rows.Add(String);
		Parents.Add(Parent);
	EndDo;
	
	If Rows.Count() = 0 Then 
		ShowMessageBox(, NStr("en = 'Select items.';"));
		Return Undefined;
	EndIf;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		ShowMessageBox(, NStr("en = 'Cannot move selected items as they have different parents.';"));
		Return Undefined;
	EndIf;
	
	Return New Structure("Rows, Parent", ArraySort(Rows), Parents[0]);
EndFunction

#EndRegion

#Region SelectedFields

// Read settings.

&AtServer
Procedure UpdateSelectedFields(Rows = Undefined, SettingsItems = Undefined)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	If Rows = Undefined Then 
		Section = SelectedFields.GetItems().Add();
		Section.IsSection = True;
		Section.Title = NStr("en = 'Fields';");
		Section.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(Undefined);
		Section.Id = "SelectedFields";
		Rows = Section.GetItems();
	EndIf;
	
	If SettingsItems = Undefined Then 
		SettingsItems = StructureItemProperty.Items;
	EndIf;
	
	For Each SettingItem In SettingsItems Do 
		String = Rows.Add();
		FillPropertyValues(String, SettingItem);
		String.Id = StructureItemProperty.GetIDByObject(SettingItem);
		
		If TypeOf(SettingItem) = Type("DataCompositionAutoSelectedField") Then 
			String.Title = NStr("en = 'Auto (parent fields)';");
			String.Picture = 18;
			Continue;
		EndIf;
		
		If TypeOf(SettingItem) = Type("DataCompositionSelectedFieldGroup") Then 
			String.IsFolder = True;
			String.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(Undefined, True);
			String.Title = SelectedFieldsGroupTitle(SettingItem, StructureItemProperty);
			
			UpdateSelectedFields(String.GetItems(), SettingItem.Items);
		Else
			SettingDetails = StructureItemProperty.SelectionAvailableFields.FindField(SettingItem.Field);
			If SettingDetails = Undefined Then 
				SetDeletionMark("SelectedFields", String);
			Else
				FillPropertyValues(String, SettingDetails);
				String.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(SettingDetails.ValueType);
				
				InstallTheFormulaIndicator(Report.SettingsComposer.Settings, SettingDetails, String);
			EndIf;
		EndIf;
	EndDo;
EndProcedure

// Add and modify items.

&AtClient
Procedure SelectedFieldsSelectGroup(RowID, String)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	
	FormParameters = New Structure;
	FormParameters.Insert("GroupTitle", String.Title);
	FormParameters.Insert("Placement", SettingItem.Placement);
	
	Handler = New NotifyDescription("SelectedFieldsAfterGroupChoice", ThisObject, RowID);
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectedFieldsGroup",
		FormParameters, ThisObject, UUID,,, Handler, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

// Parameters:
//  GroupProperties - Structure:
//    * GroupTitle - String
//    * Placement - DataCompositionFieldPlacement
//  RowID - Number
//
&AtClient
Procedure SelectedFieldsAfterGroupChoice(GroupProperties, RowID) Export
	If TypeOf(GroupProperties) <> Type("Structure") Then
		Return;
	EndIf;
	
	String = SelectedFields.FindByID(RowID);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItem.Title = GroupProperties.GroupTitle;
	SettingItem.Placement = GroupProperties.Placement;
	
	FillPropertyValues(String, SettingItem);
	
	If SettingItem.Placement <> DataCompositionFieldPlacement.Auto Then 
		String.Title = String.Title + " (" + String(SettingItem.Placement) + ")";
	EndIf;

	DetermineIfModified();
EndProcedure

&AtClient
Procedure SelectedFieldsSelectField(RowID, String)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	
	Handler = New NotifyDescription("SelectedFieldsAfterFieldChoice", ThisObject, RowID);
	SelectField("SelectedFields", Handler, SettingItem.Field);
EndProcedure

&AtClient
Procedure SelectedFieldsAfterFieldChoice(SettingDetails, RowID = Undefined) Export
	If SettingDetails = Undefined Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	ReportsOptionsInternalClient.AddFormula(Settings, Settings.SelectionAvailableFields, SettingDetails);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	If RowID = Undefined Then 
		Parent = Items.SelectedFields.CurrentData; // See SettingsFormCollectionItem
		If Parent = Undefined Then 
			Parent = DefaultRootRow("SelectedFields"); // See SettingsFormCollectionItem
		EndIf;
		
		If Not Parent.IsSection And Not Parent.IsFolder Then 
			Parent = Parent.GetParent(); // See SettingsFormCollectionItem
		EndIf;
		String = Parent.GetItems().Add();
		
		SettingItemParent = StructureItemProperty;
		If TypeOf(Parent.Id) = Type("DataCompositionID") Then 
			SettingItemParent = StructureItemProperty.GetObjectByID(Parent.Id);
		EndIf;
		SettingItem = SettingItemParent.Items.Add(Type("DataCompositionSelectedField"));
	Else
		String = SelectedFields.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
	EndIf;
	
	SettingItem.Use = True;
	SettingItem.Field = SettingDetails.Field;
	
	FillPropertyValues(String, SettingItem);
	FillPropertyValues(String, SettingDetails);
	
	String.Id = StructureItemProperty.GetIDByObject(SettingItem);
	String.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(SettingDetails.ValueType);
	
	InstallTheFormulaIndicator(Settings, SettingDetails, String);
	
	DetermineIfModified();
EndProcedure

&AtClientAtServerNoContext
Procedure InstallTheFormulaIndicator(Settings, SettingDetails, String)
	Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(Settings, String(SettingDetails.Field));
	String.IsFormula = (Formula <> Undefined);
	
	If String.IsFormula Then 
		String.FormulaIndicator = PictureLib.TypeFunction;
	Else
		String.FormulaIndicator = PictureLib.IsEmpty;
	EndIf;
EndProcedure

&AtClient
Procedure AfterActivatingTheSelectedFields()
	String = Items.SelectedFields.CurrentData;
	
	Items.SelectedFieldsChangeFormula.Enabled = String <> Undefined
		And String.IsFormula;
EndProcedure

&AtClient
Procedure SelectedFieldsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
	
	If Copy Then
		CopySettings(Item);
		Return;
	EndIf;
	
	Handler = New NotifyDescription("SelectedFieldsAfterFieldChoice", ThisObject);
	SelectField("SelectedFields", Handler);
EndProcedure

// Modify item grouping.

// Returns:
//  - Structure:
//      * Rows - Array of FormDataTreeItem
//      * Parent - See SettingsFormCollectionItem
//      * IndexOf - Number
//  - Undefined
//
&AtClient
Function GroupingParametersOfSelectedFields()
	Rows = New Array;
	Parents = New Array;
	
	RowsIDs = Items.SelectedFields.SelectedRows;
	For Each RowID In RowsIDs Do 
		String = SelectedFields.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID") Then 
			Continue;
		EndIf;
		
		Rows.Add(String);
		Parents.Add(Parent);
	EndDo;
	
	If Rows.Count() = 0 Then 
		ShowMessageBox(, NStr("en = 'Select items.';"));
		Return Undefined;
	EndIf;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		ShowMessageBox(, NStr("en = 'Cannot group selected items as they have different parents.';"));
		Return Undefined;
	EndIf;
	
	Rows = ArraySort(Rows);
	Parent = Parents[0]; // FormDataTreeItem
	IndexOf = Parent.GetItems().IndexOf(Rows[0]);
	
	Return New Structure("Rows, Parent, IndexOf", Rows, Parent, IndexOf);
EndFunction

// Parameters:
//  GroupProperties - Structure:
//    * GroupTitle - String
//    * Placement - DataCompositionFieldPlacement
//  GroupingParameters - See GroupingParametersOfSelectedFields
//
&AtClient
Procedure SelectedFieldsBeforeGroupFields(GroupProperties, GroupingParameters) Export
	If TypeOf(GroupProperties) <> Type("Structure") Then
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	// Process settings items.
	SettingItemSource = StructureItemProperty;
	If TypeOf(GroupingParameters.Parent.Id) = Type("DataCompositionID") Then 
		SettingItemSource = StructureItemProperty.GetObjectByID(GroupingParameters.Parent.Id);
	EndIf;
	
	SettingItemDestination = SettingItemSource.Items.Insert(GroupingParameters.IndexOf, Type("DataCompositionSelectedFieldGroup"));
	SettingItemDestination.Title = GroupProperties.GroupTitle;
	SettingItemDestination.Placement = GroupProperties.Placement;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
	
	// Process strings.
	SourceRow = GroupingParameters.Parent;
	DestinationRow = SourceRow.GetItems().Insert(GroupingParameters.IndexOf); // See SettingsFormCollectionItem
	FillPropertyValues(DestinationRow, SettingItemDestination);
	DestinationRow.Id = StructureItemProperty.GetIDByObject(SettingItemDestination);
	DestinationRow.IsFolder = True;
	DestinationRow.Picture = ReportsClientServer.PictureIndex("Group");
	DestinationRow.Title = SelectedFieldsGroupTitle(SettingItemDestination);
	
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRow, DestinationRow);
	
	ChangeGroupingOfSelectedFields(StructureItemProperty, GroupingParameters.Rows, SettingsItemsInheritors, RowsInheritors);
	DeleteBasicGroupingItemsOfSelectedFields(StructureItemProperty, GroupingParameters);
	
	Section = SelectedFields.GetItems()[0];
	Items.SelectedFields.Expand(Section.GetID(), True);
	Items.SelectedFields.CurrentRow = DestinationRow.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure ChangeGroupingOfSelectedFields(SelectedSettingsNodeFields, Rows, SettingsItemsInheritors, RowsInheritors)
	For Each SourceRow In Rows Do 
		SettingItemSource = SelectedSettingsNodeFields.GetObjectByID(SourceRow.Id);
		
		If SettingItemSource.Parent = Undefined Then 
			SourceSettingItemParent = SelectedSettingsNodeFields;
		Else
			SourceSettingItemParent = SettingItemSource.Parent;
		EndIf;
		DestinationSettingItemParent = SettingsItemsInheritors.Get(SourceSettingItemParent); // DataCompositionSelectedFieldGroup 
		
		SourceRowParent = SourceRow.GetParent();
		DestinationRowParent1 = RowsInheritors.Get(SourceRowParent);
		
		IndexOf = DestinationSettingItemParent.Items.IndexOf(SourceSettingItemParent);
		If IndexOf < 0 Then 
			SettingItemDestination = DestinationSettingItemParent.Items.Add(TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent1.GetItems().Add();
		Else // This is grouping deletion.
			SettingItemDestination = DestinationSettingItemParent.Items.Insert(IndexOf, TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent1.GetItems().Insert(IndexOf);
		EndIf;
		
		FillPropertyValues(SettingItemDestination, SettingItemSource);
		FillPropertyValues(DestinationRow, SourceRow);
		DestinationRow.Id = SelectedSettingsNodeFields.GetIDByObject(SettingItemDestination);
		DestinationRow.IsFolder = (TypeOf(SettingItemDestination) = Type("DataCompositionSelectedFieldGroup"));
		
		SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
		RowsInheritors.Insert(SourceRow, DestinationRow);
		
		ChangeGroupingOfSelectedFields(SelectedSettingsNodeFields, SourceRow.GetItems(), SettingsItemsInheritors, RowsInheritors);
	EndDo;
EndProcedure

&AtClient
Procedure DeleteBasicGroupingItemsOfSelectedFields(SelectedSettingsNodeFields, GroupingParameters)
	Rows = GroupingParameters.Parent.GetItems();
	
	SettingsItems = SelectedSettingsNodeFields.Items;
	Parent = GroupingParameters.Parent; // See SettingsFormCollectionItem
	
	If TypeOf(Parent.Id) = Type("DataCompositionID") Then 
		SettingsItems = SelectedSettingsNodeFields.GetObjectByID(Parent.Id).Items;
	EndIf;
	
	IndexOf = GroupingParameters.Rows.UBound();
	While IndexOf >= 0 Do 
		String = GroupingParameters.Rows[IndexOf]; // See SettingsFormCollectionItem
		SettingItem = SelectedSettingsNodeFields.GetObjectByID(String.Id);
		
		Rows.Delete(String);
		SettingsItems.Delete(SettingItem);
		
		IndexOf = IndexOf - 1;
	EndDo;
EndProcedure

&AtClientAtServerNoContext
Function SelectedFieldsGroupTitle(SettingItem, StructureItemProperty = Undefined)
	GroupTitle = SettingItem.Title;

	If Not ValueIsFilled(GroupTitle) And StructureItemProperty <> Undefined
	   And SettingItem.Field <> Undefined Then
		SettingDetails = StructureItemProperty.SelectionAvailableFields.FindField(SettingItem.Field);
		If SettingDetails <> Undefined Then 
			GroupTitle = SettingDetails.Title;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(GroupTitle) Then 
		GroupTitle = "(" + SettingItem.Placement + ")";
	ElsIf SettingItem.Placement <> DataCompositionFieldPlacement.Auto Then 
		GroupTitle = GroupTitle + " (" + SettingItem.Placement + ")";
	EndIf;
	
	Return GroupTitle;
EndFunction

// Drag items.

&AtClient
Procedure CheckRowsToDragFromSelectedFields(RowsIDs)
	Parents = New Array;
	
	IndexOf = RowsIDs.UBound();
	While IndexOf >= 0 Do 
		RowID = RowsIDs[IndexOf];
		
		String = SelectedFields.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined
			Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID") Then 
			RowsIDs.Delete(IndexOf);
		Else
			Parents.Add(Parent);
		EndIf;
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		RowsIDs.Clear();
	EndIf;
EndProcedure

&AtClient
Procedure DragSelectedFieldsWithinCollection(DragParameters, CurrentRow)
	CurrentData = SelectedFields.FindByID(CurrentRow);
	
	Rows = New Array;
	For Each RowID In DragParameters.Value Do 
		Rows.Add(SelectedFields.FindByID(RowID));
	EndDo;
	
	SourceRow = Rows[0].GetParent(); // See SettingsFormCollectionItem
	If CurrentData.IsSection Or CurrentData.IsFolder Then 
		DestinationRow = CurrentData;
	Else
		DestinationRow = CurrentData.GetParent();
	EndIf;
	
	IndexOf = DestinationRow.GetItems().IndexOf(CurrentData);
	If IndexOf < 0 Then 
		IndexOf = 0;
	EndIf;
	
	RowsInheritors = New Map;
	RowsInheritors.Insert(SourceRow, DestinationRow);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	SettingItemSource = StructureItemProperty;
	If TypeOf(SourceRow.Id) = Type("DataCompositionID") Then 
		SettingItemSource = StructureItemProperty.GetObjectByID(SourceRow.Id);
	EndIf;
	
	SettingItemDestination = StructureItemProperty;
	If TypeOf(DestinationRow.Id) = Type("DataCompositionID") Then 
		SettingItemDestination = StructureItemProperty.GetObjectByID(DestinationRow.Id);
	EndIf;
	
	SettingsItemsInheritors = New Map;
	SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
	
	DragSelectedFields(StructureItemProperty, IndexOf, Rows, SettingsItemsInheritors, RowsInheritors);
	
	Items.SelectedFields.Expand(SelectedFields.GetItems()[0].GetID(), True);
	
	DetermineIfModified();
EndProcedure

// Parameters:
//  SelectedSettingsNodeFields - DataCompositionSelectedFieldGroup
//                            - DataCompositionSelectedFields
//                            - DataCompositionSelectedField
//  IndexOf - Number
//  Rows - Array of FormDataTreeItem:
//    * Id - DataCompositionID
//  SettingsItemsInheritors - Map
//  RowsInheritors - Map
//
&AtClient
Procedure DragSelectedFields(SelectedSettingsNodeFields, IndexOf, Rows, SettingsItemsInheritors, RowsInheritors)
	For Each SourceRow In Rows Do
		SettingItemSource = SelectedSettingsNodeFields.GetObjectByID(SourceRow.Id);
		
		SettingItemParentSource = SelectedSettingsNodeFields;
		If SettingItemSource.Parent <> Undefined Then 
			SettingItemParentSource = SettingItemSource.Parent;
		EndIf;
		
		SettingItemParentDestination = SettingsItemsInheritors.Get(SettingItemParentSource); // DataCompositionSelectedFieldGroup
		DestinationRowParent = RowsInheritors.Get(SourceRow.GetParent()); // See SettingsFormCollectionItem
		
		If IndexOf > SettingItemParentDestination.Items.Count() - 1 Then 
			SettingItemDestination = SettingItemParentDestination.Items.Add(TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent.GetItems().Add();
		Else
			SettingItemDestination = SettingItemParentDestination.Items.Insert(IndexOf, TypeOf(SettingItemSource));
			DestinationRow = DestinationRowParent.GetItems().Insert(IndexOf);
		EndIf;
		
		FillPropertyValues(SettingItemDestination, SettingItemSource);
		FillPropertyValues(DestinationRow, SourceRow);
		DestinationRow.Id = SelectedSettingsNodeFields.GetIDByObject(SettingItemDestination);
		DestinationRow.Picture = ReportsClientServer.PictureIndex("Item");
		DestinationRow.IsFolder = (TypeOf(SettingItemDestination) = Type("DataCompositionSelectedFieldGroup"));
		
		SettingsItemsInheritors.Insert(SettingItemSource, SettingItemDestination);
		RowsInheritors.Insert(SourceRow, DestinationRow);
		
		If TypeOf(SettingItemDestination) = Type("DataCompositionSelectedFieldGroup") Then 
			DestinationRow.Picture = ReportsClientServer.PictureIndex("Group");
			DragSelectedFields(SelectedSettingsNodeFields, IndexOf, SourceRow.GetItems(), SettingsItemsInheritors, RowsInheritors)
		EndIf;
	EndDo;
EndProcedure

// Shift items.

&AtClient
Procedure ShiftSelectedFields(ToBeginning = True)
	ShiftParameters = ShiftParametersOfSelectedFields();
	If ShiftParameters = Undefined Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	For Each ListLine In ShiftParameters.Rows Do 
		SettingItem = SettingItem(StructureItemProperty, ListLine);
		
		SettingsItems = StructureItemProperty.Items;
		If SettingItem.Parent <> Undefined Then 
			SettingsItems = SettingItem.Parent.Items;
		EndIf;
		Rows = ShiftParameters.Parent.GetItems();
		
		IndexOf = SettingsItems.IndexOf(SettingItem);
		Boundary = SettingsItems.Count() - 1;
		
		If ToBeginning Then // Shifting to the collection beginning.
			If IndexOf = 0 Then 
				SettingsItems.Move(SettingItem, Boundary);
				Rows.Move(IndexOf, Boundary);
			Else
				SettingsItems.Move(SettingItem, -1);
				Rows.Move(IndexOf, -1);
			EndIf;
		Else // Shifting to the collection end.
			If IndexOf = Boundary Then 
				SettingsItems.Move(SettingItem, -Boundary);
				Rows.Move(IndexOf, -Boundary);
			Else
				SettingsItems.Move(SettingItem, 1);
				Rows.Move(IndexOf, 1);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Function ShiftParametersOfSelectedFields()
	Rows = New Array;
	Parents = New Array;
	
	RowsIDs = Items.SelectedFields.SelectedRows;
	For Each RowID In RowsIDs Do 
		String = SelectedFields.FindByID(RowID);
		Parent = String.GetParent();
		
		If Parent = Undefined Or Parent.GetItems().IndexOf(String) < 0
			Or TypeOf(String.Id) <> Type("DataCompositionID") Then 
			Continue;
		EndIf;
		
		Rows.Add(String);
		Parents.Add(Parent);
	EndDo;
	
	If Rows.Count() = 0 Then 
		ShowMessageBox(, NStr("en = 'Select items.';"));
		Return Undefined;
	EndIf;
	
	Parents = CommonClientServer.CollapseArray(Parents);
	If Parents.Count() > 1 Then 
		ShowMessageBox(, NStr("en = 'Cannot move selected items as they have different parents.';"));
		Return Undefined;
	EndIf;
	
	Return New Structure("Rows, Parent", ArraySort(Rows), Parents[0]);
EndFunction

// Common.

&AtClientAtServerNoContext
Procedure CastValueToComparisonKind(String, SettingItem = Undefined)
	ValueFieldName = ?(String.IsParameter, "Value", "RightValue");
	CurrentValue = String[ValueFieldName];
	
	If String.ValueListAllowed
		Or ReportsClientServer.IsListComparisonKind(String.ComparisonType) Then 
		
		If TypeOf(CurrentValue) = Type("StandardBeginningDate") Then
			CurrentValue = CurrentValue.Date;
		EndIf;
		
		Value = ReportsClientServer.ValuesByList(CurrentValue);
		Value.FillChecks(True);
		
		If String.AvailableValues <> Undefined Then 
			For Each ListItem In Value Do 
				FoundItem = String.AvailableValues.FindByValue(ListItem.Value);
				If FoundItem <> Undefined Then 
					FillPropertyValues(ListItem, FoundItem,, "Check");
				EndIf;
			EndDo;
		EndIf;
	Else
		Value = Undefined;
		If TypeOf(CurrentValue) <> Type("ValueList") Then 
			Value = CurrentValue;
		ElsIf CurrentValue.Count() > 0 Then 
			Value = CurrentValue[0].Value;
		EndIf;
	EndIf;
	
	String[ValueFieldName] = Value;
	
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue")
		Or TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
		SettingItem[ValueFieldName] = Value;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure SetValuePresentation(String, FilterAvailableFields)
	String.ValuePresentation = "";
	
	AvailableValues = String.AvailableValues;
	Value = ?(String.IsParameter, String.Value, String.RightValue);

	If AvailableValues = Undefined Then
		If TypeOf(Value) = Type("DataCompositionField") Then
			AvailableField = FilterAvailableFields.FindField(Value);
			If AvailableField <> Undefined Then
				String.ValuePresentation = AvailableField.Title;
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	FoundItem = AvailableValues.FindByValue(Value);
	If FoundItem <> Undefined Then 
		String.ValuePresentation = FoundItem.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SetEditParameters(String)
	SettingsComposer = Report.SettingsComposer;
	
	If String.IsParameter Then 
		ValueField = Items.FiltersValue;
		StructureItemProperty = SettingsStructureItemProperty(SettingsComposer, "DataParameters");
	Else
		ValueField = Items.FiltersRightValue;
		StructureItemProperty = SettingsStructureItemProperty(
			SettingsComposer, "Filter", SettingsStructureItemID);
	EndIf;
	
	UserSettings = SettingsComposer.UserSettings.Items;
	
	CurrentSettings = SettingsStructureItem(SettingsComposer.Settings, SettingsStructureItemID);
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItemDetails = ReportsClientServer.FindAvailableSetting(CurrentSettings, SettingItem);
	
	ValueField.ChoiceParameters = ReportsClientServer.ChoiceParameters(CurrentSettings, UserSettings, SettingItem, ExtendedMode = 1);
	
	String.ValueType = ReportsClient.ValueTypeRestrictedByLinkByType(
		CurrentSettings, UserSettings, SettingItem, SettingItemDetails);
	
	ValueField.AvailableTypes = String.ValueType;
EndProcedure

&AtClient
Function ChoiceOverride(String, StandardProcessing)
	
	If String.IsParameter Then
		ValueField = Items.FiltersValue;
		CurrentValue = String.Value;
	Else
		ValueField = Items.FiltersRightValue;
		CurrentValue = String.RightValue;
	EndIf;
	
	Handler = New NotifyDescription("CompleteChoiceFromList", ThisObject, String.GetID());
	
	PropertyKey = SettingsStructureItemPropertyKey("Filters", String);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, PropertyKey, SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	LongDesc = ReportsClientServer.FindAvailableSetting(Report.SettingsComposer.Settings, SettingItem);
	
	If ReportsClient.ChoiceOverride(ThisObject, Handler, LongDesc, String.ValueType,
		ReportsClientServer.ValuesByList(CurrentValue), ValueField.ChoiceParameters) Then
		
		StandardProcessing = False;
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure ShowChoiceList(String, StandardProcessing, Item)
	StandardProcessing = False;
	
	If String.IsParameter Then 
		ValueField = Items.FiltersValue;
		CurrentValue = String.Value;
	Else
		ValueField = Items.FiltersRightValue;
		CurrentValue = String.RightValue;
	EndIf;
	
	Handler = New NotifyDescription("CompleteChoiceFromList", ThisObject, String.GetID());
	AvailableTypes = SelectableTypes(String.ValueType);
	
	If ReportsClient.IsSelectMetadataObjects(AvailableTypes, CurrentValue, Handler) Then
		Return;
	EndIf;
	
	ValuesForSelection = ValuesForSelection(String);
	RestrictSelectionBySpecifiedValues = String.AvailableValues <> Undefined;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Marked", ReportsClientServer.ValuesByList(CurrentValue));
	OpeningParameters.Insert("TypeDescription", String.ValueType);
	OpeningParameters.Insert("ValuesForSelection", ValuesForSelection);
	OpeningParameters.Insert("ValuesForSelectionFilled", ValuesForSelection.Count() > 0);
	OpeningParameters.Insert("RestrictSelectionBySpecifiedValues", RestrictSelectionBySpecifiedValues);
	OpeningParameters.Insert("Presentation", String.UserSettingPresentation);
	OpeningParameters.Insert("ChoiceParameters", New Array(ValueField.ChoiceParameters));
	OpeningParameters.Insert("ChoiceFoldersAndItems", ValueField.ChoiceFoldersAndItems);
	
	Context = New Structure;
	Context.Insert("OpeningParameters", OpeningParameters);
	Context.Insert("Handler", Handler);
	
	If RestrictSelectionBySpecifiedValues Then
		ShowChoiceListFollowUp(Undefined, Context);
	Else
		ReportsClient.StartSelectUsers(ThisObject,
			Item, AvailableTypes, CurrentValue, ValueField.ChoiceParameters, Handler,
			New NotifyDescription("ShowChoiceListFollowUp", ThisObject, Context));
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowChoiceListFollowUp(Result, Context) Export
	
	OpenForm("CommonForm.InputValuesInListWithCheckBoxes",
		Context.OpeningParameters, ThisObject,,,, Context.Handler);
	
EndProcedure

&AtClient
Function ValuesForSelection(String)
	ValuesForSelection = CommonClient.CopyRecursive(String.AvailableValues);
	
	If ValuesForSelection = Undefined Then 
		ValuesForSelection = New ValueList;
	EndIf;
	
	ValuesForSelection.ValueType = String.ValueType;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, ?(String.IsParameter, "DataParameters", "Filter"));
	
	SettingItem = SettingItem(StructureItemProperty, String);
	If SettingItem = Undefined Then 
		Return ValuesForSelection;
	EndIf;
	
	FilterValue = ReportsClient.SelectionValueCache(Report.SettingsComposer, SettingItem);
	If FilterValue <> Undefined Then 
		CommonClientServer.SupplementList(ValuesForSelection, FilterValue);
	EndIf;
	
	ReportsClient.UpdateListViews(ValuesForSelection, String.AvailableValues);
	
	Return ValuesForSelection;
EndFunction

&AtServerNoContext
Function SelectableTypes(Val ValueType)
	
	Return ReportsServer.ExtendedTypesDetails(ValueType, True).TypesDetailsForForm;
	
EndFunction

&AtClient
Procedure CompleteChoiceFromList(List, RowID) Export
	If TypeOf(List) = Type("Array") Then
		SelectedValues = List;
		
		List = New ValueList;
		List.LoadValues(SelectedValues);
		List.FillChecks(True);
	ElsIf TypeOf(List) <> Type("ValueList") Then
		Return;
	EndIf;
	
	String = Filters.FindByID(RowID);
	If String = Undefined Then
		Return;
	EndIf;
	
	SelectedValues = New ValueList;
	For Each ListItem In List Do 
		If ListItem.Check Then 
			FillPropertyValues(SelectedValues.Add(), ListItem);
		EndIf;
	EndDo;
	
	ValueFieldName = ?(String.IsParameter, "Value", "RightValue");
	PropertyKey = SettingsStructureItemPropertyKey("Filters", String);
	
	String[ValueFieldName] = SelectedValues;
	String.Use = True;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, PropertyKey, SettingsStructureItemID);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	FillPropertyValues(SettingItem, String, "Use, " + ValueFieldName);
	
	ReportsClient.CacheFilterValue(SettingsComposer, SettingItem, List);
	
	DetermineIfModified();
EndProcedure

#EndRegion

#Region Order

// Read settings.

&AtServer
Procedure UpdateSorting()
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	Section = Sort.GetItems().Add();
	Section.IsSection = True;
	Section.Title = NStr("en = 'Sorts';");
	Section.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(Undefined);
	Rows = Section.GetItems();
	
	SettingsItems = StructureItemProperty.Items;
	
	For Each SettingItem In SettingsItems Do 
		String = Rows.Add();
		FillPropertyValues(String, SettingItem);
		String.Id = StructureItemProperty.GetIDByObject(SettingItem);
		
		If TypeOf(SettingItem) = Type("DataCompositionAutoOrderItem") Then 
			String.Title = NStr("en = 'Auto (parent orders)';");
			String.IsAutoField = True;
			String.Picture = 18;
			Continue;
		EndIf;
		
		SettingDetails = StructureItemProperty.OrderAvailableFields.FindField(SettingItem.Field);
		If SettingDetails = Undefined Then 
			SetDeletionMark("Sort", String);
		Else
			FillPropertyValues(String, SettingDetails);
			String.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(SettingDetails.ValueType);
		EndIf;
	EndDo;
EndProcedure

// Add and modify items.

&AtClient
Procedure SortingSelectField(RowID, String)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	
	Handler = New NotifyDescription("SortAfterFieldChoice", ThisObject, RowID);
	SelectField("Sort", Handler, SettingItem.Field);
EndProcedure

&AtClient
Procedure SortAfterFieldChoice(SettingDetails, RowID = Undefined) Export
	If SettingDetails = Undefined Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	ReportsOptionsInternalClient.AddFormula(Settings, Settings.OrderAvailableFields, SettingDetails);
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	If RowID = Undefined Then 
		Parent = Items.Sort.CurrentData;
		If Parent = Undefined Then
			Parent = DefaultRootRow("Sort");
		EndIf;
		If Not Parent.IsSection Then 
			Parent = Parent.GetParent();
		EndIf;
		String = Parent.GetItems().Add();
		
		SettingItemParent = StructureItemProperty;
		If TypeOf(Parent.Id) = Type("DataCompositionID") Then 
			SettingItemParent = StructureItemProperty.GetObjectByID(Parent.Id);
		EndIf;
		SettingItem = SettingItemParent.Items.Add(Type("DataCompositionOrderItem"));
	Else
		String = Sort.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
	EndIf;
	
	SettingItem.Use = True;
	SettingItem.Field = SettingDetails.Field;
	
	FillPropertyValues(String, SettingItem);
	FillPropertyValues(String, SettingDetails);
	
	String.Id = StructureItemProperty.GetIDByObject(SettingItem);
	String.Picture = ReportsClientServer.PictureIndex("Item");
	
	Items.Sort.Expand(Sort.GetItems()[0].GetID());
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure ChangeRowsOrderType(OrderType)
	Items = Sort.GetItems()[0].GetItems();
	If Items.Count() = 0 Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	For Each Item In Items Do 
		SettingItem = SettingItem(StructureItemProperty, Item);
		SettingItem.OrderType = OrderType;
		Item.OrderType = SettingItem.OrderType;
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure ChangeOrderType(String)
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	
	If SettingItem.OrderType = DataCompositionSortDirection.Asc Then 
		SettingItem.OrderType = DataCompositionSortDirection.Desc;
	Else
		SettingItem.OrderType = DataCompositionSortDirection.Asc;
	EndIf;
	String.OrderType = SettingItem.OrderType;
	
	DetermineIfModified();
EndProcedure

// Drag items.

// Parameters:
//  Rows - Array of FormDataTreeItem:
//    * Id - DataCompositionID
//
&AtClient
Procedure DragSelectedFieldsToSorting(Rows)
	SelectedStructureItemFields = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	StructureItemSorting = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	Section = Sort.GetItems()[0];
	
	For Each SourceRow In Rows Do 
		SettingItemSource = SelectedStructureItemFields.GetObjectByID(SourceRow.Id);
		If TypeOf(SettingItemSource) = Type("DataCompositionSelectedFieldGroup") Then 
			DragSelectedFieldsToSorting(SourceRow.GetItems());
		ElsIf TypeOf(SettingItemSource) = Type("DataCompositionAutoSelectedField") Then
			Found = False;
			For Each SettingItemDestination In StructureItemSorting.Items Do
				If TypeOf(SettingItemDestination) = Type("DataCompositionAutoOrderItem") Then
					Found = True;
					Break;
				EndIf;
			EndDo;
			If Not Found Then
				SettingItemDestination = StructureItemSorting.Items.Add(Type("DataCompositionAutoOrderItem"));
				SettingItemDestination.Use = True;
				DestinationRow = Section.GetItems().Add();
				FillPropertyValues(DestinationRow, SettingItemDestination);
				DestinationRow.Id = StructureItemSorting.GetIDByObject(SettingItemDestination);
				DestinationRow.Picture = 18;
				DestinationRow.Title = NStr("en = 'Auto (parent orders)';");
				DestinationRow.IsAutoField = True;
			EndIf;
		Else
			If FindOrderField(StructureItemSorting, SettingItemSource.Field) <> Undefined Then 
				Continue;
			EndIf;
			
			SettingDetails = StructureItemSorting.OrderAvailableFields.FindField(SettingItemSource.Field);
			
			If SettingDetails = Undefined Then
				Continue;
			EndIf;
			
			SettingItemDestination = StructureItemSorting.Items.Add(Type("DataCompositionOrderItem"));
			FillPropertyValues(SettingItemDestination, SettingItemSource);
			SettingItemDestination.Use = True;
			
			DestinationRow = Section.GetItems().Add();
			FillPropertyValues(DestinationRow, SettingItemDestination);
			FillPropertyValues(DestinationRow, SettingDetails);
			DestinationRow.Id = StructureItemSorting.GetIDByObject(SettingItemDestination);
			DestinationRow.Picture = ReportsOptionsInternalClientServer.IndexOfTheFieldImage(SettingDetails.ValueType);
		EndIf;
	EndDo;
	
	Items.Sort.Expand(Section.GetID());
	DetermineIfModified();
EndProcedure

&AtClient
Procedure DragSortingWithinCollection(DragParameters, CurrentRow)
	
EndProcedure

&AtClient
Function FindOrderField(SettingsNodeSorting, Field)
	For Each SettingItem In SettingsNodeSorting.Items Do 
		If TypeOf(SettingItem) <> Type("DataCompositionAutoOrderItem")
			And SettingItem.Field = Field Then 
			
			Return Field;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure DragSortingFieldsToSelectedFields(Rows)
	SelectedStructureItemFields = SettingsStructureItemProperty(
		Report.SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	
	StructureItemSorting = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	SelectedFieldsSection = SelectedFields.GetItems()[0];
	SortingFieldsSection = Sort.GetItems()[0];
	
	IndexOf = Rows.Count() - 1;
	While IndexOf >= 0 Do 
		SourceRow = Rows[IndexOf];
		SettingItemSource = StructureItemSorting.GetObjectByID(SourceRow.Id);
		
		If TypeOf(SettingItemSource) = Type("DataCompositionAutoOrderItem") Then
			Found = False;
			For Each SettingItemDestination In SelectedStructureItemFields.Items Do
				If TypeOf(SettingItemDestination) = Type("DataCompositionAutoSelectedField") Then
					Found = True;
					Break;
				EndIf;
			EndDo;
			If Not Found Then
				SettingItemDestination = SelectedStructureItemFields.Items.Add(Type("DataCompositionAutoSelectedField"));
				DestinationRow = SelectedFieldsSection.GetItems().Add();
				FillPropertyValues(DestinationRow, SettingItemDestination);
				DestinationRow.Id = SelectedStructureItemFields.GetIDByObject(SettingItemDestination);
				DestinationRow.Picture = 18;
				DestinationRow.Title = NStr("en = 'Auto (parent fields)';");
			EndIf;
			
		ElsIf FindSelectedField(SelectedStructureItemFields, SettingItemSource.Field) = Undefined Then 
			SettingItemDestination = SelectedStructureItemFields.Items.Add(Type("DataCompositionSelectedField"));
			FillPropertyValues(SettingItemDestination, SettingItemSource);
			
			SettingDetails = SelectedStructureItemFields.SelectionAvailableFields.FindField(SettingItemSource.Field);
			
			DestinationRow = SelectedFieldsSection.GetItems().Add();
			FillPropertyValues(DestinationRow, SettingItemDestination);
			FillPropertyValues(DestinationRow, SettingDetails);
			DestinationRow.Id = SelectedStructureItemFields.GetIDByObject(SettingItemDestination);
			DestinationRow.Picture = ReportsClientServer.PictureIndex("Item");
		EndIf;
		
		StructureItemSorting.Items.Delete(SettingItemSource);
		SortingFieldsSection.GetItems().Delete(SourceRow);
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	Items.SelectedFields.Expand(SelectedFieldsSection.GetID(), True);
	DetermineIfModified();
EndProcedure

&AtClient
Function FindSelectedField(SelectedSettingsNodeFields, Field)
	FoundField = Undefined;
	
	For Each SettingItem In SelectedSettingsNodeFields.Items Do 
		If TypeOf(SettingItem) = Type("DataCompositionSelectedFieldGroup") Then 
			FoundField = FindSelectedField(SettingItem, Field);
		ElsIf TypeOf(SettingItem) = Type("DataCompositionSelectedField")
			And SettingItem.Field = Field Then 
			FoundField = Field;
		EndIf;
	EndDo;
	
	Return FoundField;
EndFunction

// Shift items.

&AtClient
Procedure ShiftSorting(ToBeginning = True)
	RowsIDs = Items.Sort.SelectedRows;
	SectionID = Sort.GetItems()[0].GetID();
	
	SectionIndex = RowsIDs.Find(SectionID);
	If SectionIndex <> Undefined Then 
		RowsIDs.Delete(SectionIndex);
	EndIf;
	
	If RowsIDs.Count() = 0 Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	
	For Each RowID In RowsIDs Do 
		String = Sort.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
		
		SettingsItems = StructureItemProperty.Items;
		Rows = String.GetParent().GetItems();
		
		IndexOf = SettingsItems.IndexOf(SettingItem);
		Boundary = SettingsItems.Count() - 1;
		
		If ToBeginning Then // Shifting to the collection beginning.
			If IndexOf = 0 Then 
				SettingsItems.Move(SettingItem, Boundary);
				Rows.Move(IndexOf, Boundary);
			Else
				SettingsItems.Move(SettingItem, -1);
				Rows.Move(IndexOf, -1);
			EndIf;
		Else // Shifting to the collection end.
			If IndexOf = Boundary Then 
				SettingsItems.Move(SettingItem, -Boundary);
				Rows.Move(IndexOf, -Boundary);
			Else
				SettingsItems.Move(SettingItem, 1);
				Rows.Move(IndexOf, 1);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

#EndRegion

#Region Appearance

// Read settings.

&AtServer
Procedure UpdateAppearance()
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "ConditionalAppearance", SettingsStructureItemID);
	
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	ReadPredefinedAppearanceParameters();
	
	Rows = Appearance.GetItems();
	
	For Each SettingItem In StructureItemProperty.Items Do 
		String = Rows.Add();
		FillPropertyValues(String, SettingItem);
		String.Id = StructureItemProperty.GetIDByObject(SettingItem);
		String.Picture = -1;
		
		If AppearanceItemIsMarkedForDeletion(SettingItem.Fields) Then 
			SetDeletionMark("Appearance", String);
		EndIf;
		
		String.Presentation = ReportsClientServer.ConditionalAppearanceItemPresentation(
			SettingItem, SettingItem, ?(String.DeletionMark, "DeletionMark", ""));
		
		If ValueIsFilled(String.UserSettingPresentation) Then 
			String.Title = String.UserSettingPresentation;
		Else
			String.Title = String.Presentation;
		EndIf;
		
		String.IsPredefinedTitle = (String.Title = String.UserSettingPresentation);
		String.DisplayModePicture = SettingItemDisplayModePicture(SettingItem);
	EndDo;
EndProcedure

&AtServer
Function AppearanceItemIsMarkedForDeletion(Fields)
	AvailableFields = Fields.AppearanceFieldsAvailableFields;
	
	For Each Item In Fields.Items Do 
		If AvailableFields.FindField(Item.Field) = Undefined Then 
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Defines properties of output parameter that affect the display of the title, data parameters, and filters.
//  See also ReportsServer.InitializePredefinedOutputParameters().
//
&AtServer
Procedure ReadPredefinedAppearanceParameters()
	If SettingsStructureItemChangeMode Then 
		Return;
	EndIf;
	
	PredefinedParameters = PredefinedOutputParameters(Report.SettingsComposer.Settings);
	
	// Output parameter Title.
	Object = PredefinedParameters.TITLE.Object;
	
	String = Appearance.GetItems().Add();
	FillPropertyValues(String, Object, "Use, Value");
	String.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Show printing header: %1';"),
		?(ValueIsFilled(Object.Value), Object.Value, NStr("en = '<None>';")));
	String.Presentation = NStr("en = 'Show printing header';");
	String.Id = PredefinedParameters.TITLE.Id;
	String.Picture = -1;
	String.DisplayModePicture = 4;
	String.IsOutputParameter = True;
	
	// Output parameter OutputParameters.
	Object = PredefinedParameters.DATAPARAMETERSOUTPUT.Object;
	LinkedObject = PredefinedParameters.FILTEROUTPUT.Object;
	
	String = Appearance.GetItems().Add();
	String.Use = (Object.Value <> DataCompositionTextOutputType.DontOutput
		Or LinkedObject.Value <> DataCompositionTextOutputType.DontOutput);
	String.Title = NStr("en = 'Display filters';");
	String.Presentation = NStr("en = 'Display filters';");
	String.Id = PredefinedParameters.DATAPARAMETERSOUTPUT.Id;
	String.Picture = -1;
	String.DisplayModePicture = 4;
	String.IsOutputParameter = True;
EndProcedure

// Add and modify items.

&AtClient
Procedure AppearanceChangeItem(RowID = Undefined, String = Undefined)
	Handler = New NotifyDescription("AppearanceChangeItemCompletion", ThisObject, RowID);
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("SettingsComposer", Report.SettingsComposer);
	FormParameters.Insert("SettingsStructureItemID", SettingsStructureItemID);
	If String = Undefined Then
		FormParameters.Insert("DCID", Undefined);
		FormParameters.Insert("Description", "");
	Else
		FormParameters.Insert("DCID", String.Id);
		FormParameters.Insert("Description", String.Title);
	EndIf;
	FormParameters.Insert("Title", StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Conditional appearance item of report ""%1""';"), DescriptionOption));
	
	OpenForm("SettingsStorage.ReportsVariantsStorage.Form.ConditionalReportAppearanceItem",
		FormParameters, ThisObject, UUID,,, Handler);
EndProcedure

// Parameters:
//  Result - Structure:
//    * DCItem - ConditionalAppearanceItem
//    * Description - String
//  RowID - Number
//
&AtClient
Procedure AppearanceChangeItemCompletion(Result, RowID) Export
	If Result = Undefined Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	
	If Result.Property("DescriptionOfFormulas") Then 
		ReportsOptionsInternalClient.AddFormulas(Settings, Settings.SelectionAvailableFields, Result.DescriptionOfFormulas);
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "ConditionalAppearance", SettingsStructureItemID);
	
	Section = DefaultRootRow("Appearance");
	
	If RowID = Undefined Then
		If Section = Undefined Then 
			String = Appearance.GetItems().Add();
		Else
			String = Section.GetItems().Add();
		EndIf;
		SettingItem = StructureItemProperty.Items.Add();
	Else
		String = Appearance.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
		SettingItem.Filter.Items.Clear();
		SettingItem.Fields.Items.Clear();
	EndIf;
	
	ReportsClientServer.FillPropertiesRecursively(StructureItemProperty, SettingItem, Result.DCItem);
	SettingItem.UserSettingID = New UUID;
	
	If Not ValueIsFilled(SettingItem.UserSettingPresentation) Then 
		SettingItem.Presentation = Result.Description;
	EndIf;
	
	String.Id = StructureItemProperty.GetIDByObject(SettingItem);
	String.Use = SettingItem.Use;
	String.Title = Result.Description;
	
	If Not ValueIsFilled(SettingItem.UserSettingPresentation) Then 
		String.Presentation = Result.Description;
	EndIf;
	
	String.IsPredefinedTitle = (String.Title = String.Presentation);
	
	If String.IsPredefinedTitle Then
		SettingItem.UserSettingPresentation = "";
	Else
		SettingItem.UserSettingPresentation = String.Title;
	EndIf;
	
	String.Picture = -1;
	String.DisplayModePicture = SettingItemDisplayModePicture(SettingItem);
	
	Items.Appearance.CurrentRow = String.GetID();
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure SynchronizePredefinedOutputParameters(Use, SettingItem)
	OutputParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	Value = ?(Use, DataCompositionTextOutputType.Auto, DataCompositionTextOutputType.DontOutput);
	
	If SettingItem.Parameter = New DataCompositionParameter("Title") Then 
		LinkedSettingItem = OutputParameters.Find("TITLEOUTPUT");
		LinkedSettingItem.Use = True;
		LinkedSettingItem.Value = Value;
	ElsIf SettingItem.Parameter = New DataCompositionParameter("DataParametersOutput") Then 
		LinkedSettingItem = OutputParameters.Find("FILTEROUTPUT");
		FillPropertyValues(LinkedSettingItem, SettingItem, "Use, Value");
	EndIf;
EndProcedure

&AtClient
Procedure AppearanceTitleInputCompletion(Value, Id) Export 
	If Value = Undefined Then 
		Return;
	EndIf;
	
	String = Appearance.FindByID(Id);
	String.Use = True;
	String.Value = Value;
	String.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Show printing header: %1';"),
		?(ValueIsFilled(Value), Value, "<Missing>"));
	
	Settings = Report.SettingsComposer.Settings;
	
	OutputParameters = Settings.OutputParameters;
	SettingItem = OutputParameters.GetObjectByID(String.Id);
	SettingItem.Value = Value;
	SettingItem.Use = True;
	
	Settings.AdditionalProperties.Insert("TitleSetInteractively", ValueIsFilled(Value));
	
	DetermineIfModified();
EndProcedure

// Shift items.

&AtClient
Procedure ShiftAppearance(ToBeginning = True)
	RowsIDs = Items.Appearance.SelectedRows;
	Rows = Appearance.GetItems();
	
	BorderOfTheBeginningOfTheDesignElements = 2;
	TheBorderOfRowIdentifiers = RowsIDs.UBound();
	
	While TheBorderOfRowIdentifiers >= 0 Do 
		String = Appearance.FindByID(RowsIDs[TheBorderOfRowIdentifiers]);
		
		If Rows.IndexOf(String) < BorderOfTheBeginningOfTheDesignElements Then 
			RowsIDs.Delete(TheBorderOfRowIdentifiers);
		EndIf;
		
		TheBorderOfRowIdentifiers = TheBorderOfRowIdentifiers - 1;
	EndDo;
	
	If RowsIDs.Count() = 0 Then 
		Return;
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(
		Report.SettingsComposer, "ConditionalAppearance", SettingsStructureItemID);
	
	For Each RowID In RowsIDs Do 
		String = Appearance.FindByID(RowID);
		SettingItem = SettingItem(StructureItemProperty, String);
		
		If TypeOf(SettingItem) <> Type("DataCompositionConditionalAppearanceItem") Then 
			Continue;
		EndIf;
		
		SettingsItems = StructureItemProperty.Items;
		
		IndexOf = SettingsItems.IndexOf(SettingItem);
		Boundary = SettingsItems.Count() - 1;
		
		If ToBeginning Then // Shifting to the collection beginning.
			If IndexOf = 0 Then 
				SettingsItems.Move(SettingItem, Boundary);
				Rows.Move(IndexOf + BorderOfTheBeginningOfTheDesignElements, Boundary);
			Else
				SettingsItems.Move(SettingItem, -1);
				Rows.Move(IndexOf + BorderOfTheBeginningOfTheDesignElements, -1);
			EndIf;
		Else // Shifting to the collection end.
			If IndexOf = Boundary Then 
				SettingsItems.Move(SettingItem, -Boundary);
				Rows.Move(IndexOf + BorderOfTheBeginningOfTheDesignElements, -Boundary);
			Else
				SettingsItems.Move(SettingItem, 1);
				Rows.Move(IndexOf + BorderOfTheBeginningOfTheDesignElements, 1);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

// Item usage.

&AtClient
Procedure ChangePredefinedOutputParametersUsage(Use = True)
	If SettingsStructureItemChangeMode Then 
		Return;
	EndIf;
	
	Items = Appearance.GetItems();
	StructureItemProperty = Report.SettingsComposer.Settings.OutputParameters;
	
	For Each Item In Items Do 
		If TypeOf(Item.Id) <> Type("DataCompositionID") Then 
			Continue;
		EndIf;
		
		Item.Use = Use;
		SettingItem = SettingItem(StructureItemProperty, Item);
		SettingItem.Use = Use;
	EndDo;
EndProcedure

// A close handler of the HeaderAndFooterSettings form.
//  See OpenForm > OnCloseNotifyDescription in Syntax Assistant.
//
&AtClient
Procedure RememberHeaderFooterSettings(Settings, AdditionalParameters) Export 
	PreviousSettings = Undefined;
	Report.SettingsComposer.Settings.AdditionalProperties.Property("HeaderOrFooterSettings", PreviousSettings);
	
	If Settings <> PreviousSettings Then 
		DetermineIfModified();
	EndIf;
	
	Report.SettingsComposer.Settings.AdditionalProperties.Insert("HeaderOrFooterSettings", Settings);
EndProcedure

#EndRegion

#Region Structure

// Read settings.

&AtServer
Procedure UpdateStructure()
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	If StructureItemProperty = Undefined Then 
		Return;
	EndIf;
	
	Section = OptionStructure.GetItems().Add();
	Section.Presentation = NStr("en = 'Report';");
	Section.IsSection = True;
	Section.Picture = -1;
	Section.Type = StructureItemProperty;
	Rows = Section.GetItems();
	
	UpdateStructureCollection(StructureItemProperty, "Structure", Rows);
EndProcedure

&AtServer
Procedure UpdateStructureCollection(Val Node, Val CollectionName, Rows)
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	UserSettings = Report.SettingsComposer.UserSettings.Items;
	
	Collection = Node[CollectionName];
	CollectionType = TypeOf(Collection);
	CollectionsNames = StructureItemCollectionsNames(Collection);
	
	If CollectionType = Type("DataCompositionSettingStructureItemCollection") Then 
		
		If ValueIsFilled(Collection.UserSettingID) Then 
			ContainsUserStructureItems = True;
		EndIf;
		
	ElsIf CollectionsNames.Find(CollectionName) <> Undefined
		And (CollectionType = Type("DataCompositionTableStructureItemCollection")
			Or CollectionType = Type("DataCompositionChartStructureItemCollection")) Then 
		
		String = Rows.Add();
		String.Id = StructureItemProperty.GetIDByObject(Collection);
		
		String.Presentation = RepresentationOfACollectionOfAStructureElement(CollectionName);
		If ValueIsFilled(Collection.UserSettingPresentation) Then 
			String.Presentation = Collection.UserSettingPresentation;
		EndIf;
		
		String.Picture = -1;
		String.Type = Collection;
		String.Subtype = ?(StrFind("Series, Points", CollectionName) > 0, "Chart", "Table") + CollectionName;
		Rows = String.GetItems();
	EndIf;
	
	For Each Item In Collection Do 
		If ValueIsFilled(Item.UserSettingID) Then 
			ContainsUserStructureItems = True;
		EndIf;
		
		UserSettingItem = UserSettings.Find(Item.UserSettingID);
		
		String = Rows.Add();
		
		If UserSettingItem = Undefined Then 
			String.Use = Item.Use;
		Else
			String.Use = UserSettingItem.Use;
		EndIf;
		
		If TypeOf(Item) = Type("DataCompositionNestedObjectSettings") Then 
			Node = Item.Settings;
			ContainsNestedReports = True;
		Else
			Node = Item;
			FillPropertyValues(String, Item);
			
			If ExtendedMode = 0 And UserSettingItem <> Undefined Then 
				String.Use = UserSettingItem.Use;
			EndIf;
		EndIf;
		
		String.Id = StructureItemProperty.GetIDByObject(Node);
		String.AvailableFlag = (ExtendedMode = 1 Or UserSettingItem <> Undefined);
		
		ItemProperties = StructureCollectionItemProperties(Item);
		FillPropertyValues(String, ItemProperties);
		
		String.Subtype = String.GetParent().Subtype;
		
		If ItemProperties.DeletionMark Then 
			SetDeletionMark("OptionStructure", String);
		EndIf;
		
		For Each CollectionName In ItemProperties.CollectionsNames Do 
			UpdateStructureCollection(Node, CollectionName, String.GetItems());
		EndDo;
	EndDo;
EndProcedure

// Parameters:
//  Item - DataCompositionNestedObjectSettings
//
// Returns:
//  Structure:
//    * ContainsConditionalAppearance - Boolean
//    * ContainsFieldsOrOrders - Boolean
//    * ContainsFilters - Boolean
//    * Type - String
//    * Picture - Number
//    * DeletionMark - Boolean
//    * CollectionsNames - Array
//    * Title - String
//    * Presentation - String
//
&AtServer
Function StructureCollectionItemProperties(Item)
	ItemProperties = StructureCollectionItemPropertiesPalette();
	
	ElementType = TypeOf(Item);
	If ElementType = Type("DataCompositionGroup")
		Or ElementType = Type("DataCompositionTableGroup")
		Or ElementType = Type("DataCompositionChartGroup") Then 
		
		ItemProperties.Presentation = ReportsOptionsInternal.GroupFieldsPresentation(
			Item, ItemProperties.DeletionMark);
		
	ElsIf ElementType = Type("DataCompositionNestedObjectSettings") Then 
		
		Objects = AvailableSettingsObjects(Item);
		ObjectDetails = Objects.Find(Item.ObjectID);
		
		ItemProperties.Presentation = ObjectDetails.Title;
		If ValueIsFilled(Item.UserSettingPresentation) Then 
			ItemProperties.Presentation = Item.UserSettingPresentation;
		EndIf;
		
		If Not ValueIsFilled(ItemProperties.Presentation) Then
			ItemProperties.Presentation = NStr("en = 'Nested grouping';");
		EndIf;
		
	ElsIf ElementType = Type("DataCompositionTable") Then 
		
		ItemProperties.Presentation = NStr("en = 'Table';");
		If ValueIsFilled(Item.UserSettingPresentation) Then 
			ItemProperties.Presentation = Item.UserSettingPresentation;
		EndIf;
		
	ElsIf ElementType = Type("DataCompositionChart") Then 
		
		ItemProperties.Presentation = NStr("en = 'Chart';");
		If ValueIsFilled(Item.UserSettingPresentation) Then 
			ItemProperties.Presentation = Item.UserSettingPresentation;
		EndIf;
		
	Else
		ItemProperties.Presentation = String(ElementType);
	EndIf;
	
	If ElementType <> Type("DataCompositionNestedObjectSettings") Then 
		
		OutputParameters = Item.OutputParameters; // DataCompositionOutputParameterValues 
		ItemTitle = OutputParameters.Items.Find("Title");
		
		If ItemTitle <> Undefined Then 
			ItemProperties.Title = ItemTitle.Value;
		EndIf;
		
	EndIf;
	
	ItemProperties.CollectionsNames = StructureItemCollectionsNames(Item);
	
	ItemTypePresentation = ReportsClientServer.SettingTypeAsString(ElementType);
	ItemState = ?(ItemProperties.DeletionMark, "DeletionMark", Undefined);
	ItemProperties.Picture = ReportsClientServer.PictureIndex(ItemTypePresentation, ItemState);
	
	ItemProperties.Type = Item;
	
	SetFlagsOfNestedSettingsItems(Item, ItemProperties);
	
	Return ItemProperties;
EndFunction

&AtServer
Function StructureCollectionItemPropertiesPalette()
	ItemProperties = New Structure;
	ItemProperties.Insert("Presentation", "");
	ItemProperties.Insert("Title", "");
	ItemProperties.Insert("CollectionsNames", New Array);
	ItemProperties.Insert("DeletionMark", False);
	ItemProperties.Insert("Picture", -1);
	ItemProperties.Insert("Type", "");
	ItemProperties.Insert("ContainsFilters", False);
	ItemProperties.Insert("ContainsFieldsOrOrders", False);
	ItemProperties.Insert("ContainsConditionalAppearance", False);
	
	Return ItemProperties;
EndFunction

&AtServer
Function AvailableSettingsObjects(NestedObjectSettings)
	If TypeOf(NestedObjectSettings.Parent) = Type("DataCompositionSettings") Then 
		Return NestedObjectSettings.Parent.AvailableObjects.Items;
	Else
		Return AvailableSettingsObjects(NestedObjectSettings.Parent);
	EndIf;
EndFunction

&AtServer
Procedure SetFlagsOfNestedSettingsItems(StructureItem, StructureItemProperties)
	ElementType = TypeOf(StructureItem);
	If ElementType = Type("DataCompositionTable")
		Or ElementType = Type("DataCompositionChart") Then 
		Return;
	EndIf;
	
	Item = StructureItem;
	If ElementType = Type("DataCompositionNestedObjectSettings") Then 
		Item = StructureItem.Settings;
	EndIf;
	
	StructureItemProperties.ContainsFilters = Item.Filter.Items.Count();
	StructureItemProperties.ContainsConditionalAppearance = Item.ConditionalAppearance.Items.Count();
	
	NestedItems = Item.Selection.Items;
	ContainsFields = NestedItems.Count() > 0
		And Not (NestedItems.Count() = 1
		And TypeOf(NestedItems[0]) = Type("DataCompositionAutoSelectedField"));
	
	NestedItems = Item.Order.Items;
	ContainsSorting = NestedItems.Count() > 0
		And Not (NestedItems.Count() = 1
		And TypeOf(NestedItems[0]) = Type("DataCompositionAutoOrderItem"));
	
	StructureItemProperties.ContainsFieldsOrOrders = ContainsFields Or ContainsSorting;
	
	// Set service flags.
	If StructureItemProperties.ContainsFilters Then 
		ContainsNestedFilters = True;
	EndIf;
	
	If StructureItemProperties.ContainsFieldsOrOrders Then 
		ContainsNestedFieldsOrSorting = True;
	EndIf;
	
	If StructureItemProperties.ContainsConditionalAppearance Then 
		ContainsNestedConditionalAppearance = True;
	EndIf;
EndProcedure

// Add and modify items.

&AtClient
Procedure AddOptionStructureGrouping(NextLevel = True)
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("NextLevel", NextLevel);
	ExecutionParameters.Insert("Wrap", True);
	
	StructureItemID = Undefined;
	String = Items.OptionStructure.CurrentData;
	If String = Undefined Then
		String = DefaultRootRow("OptionStructure");
	EndIf;
			
	If String <> Undefined Then
		If Not NextLevel Then
			String = String.GetParent();
		EndIf;
		
		If NextLevel Then
			If (String.Type = "DataCompositionSettings" And Not String.AvailableFlag) 
				Or String.GetItems().Count() > 1 
				Or (String.Type = "DataCompositionTableStructureItemCollection"
					And String.Subtype = "ColumnsTable") Then 
				ExecutionParameters.Wrap = False;
			EndIf;
		EndIf;
		
		While String <> Undefined Do
			If String.Type = "DataCompositionSettings"
				Or String.Type = "DataCompositionNestedObjectSettings"
				Or String.Type = "DataCompositionGroup"
				Or String.Type = "DataCompositionTableGroup"
				Or String.Type = "DataCompositionChartGroup" Then
				StructureItemID = String.Id;
				Break;
			EndIf;
			String = String.GetParent();
		EndDo;
	EndIf;
	
	Handler = New NotifyDescription("OptionStructureAfterSelectField", ThisObject, ExecutionParameters);
	SelectField("OptionStructure", Handler, Undefined, StructureItemID);
EndProcedure

&AtClient
Procedure AddSettingsStructureItem(ElementType)
	CurrentRow = Items.OptionStructure.CurrentData;
	
	Result = InsertSettingsStructureItem(ElementType, CurrentRow, True);
	SettingItem = Result.SettingItem;
	
	String = Result.String;
	String.Type = SettingItem;
	String.Title = String.Presentation;
	String.AvailableFlag = True;
	String.Use = SettingItem.Use;
	
	ItemTypePresentation = ReportsClientServer.SettingTypeAsString(TypeOf(SettingItem));
	String.Picture = ReportsClientServer.PictureIndex(ItemTypePresentation);
	
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	SubordinateRows = String.GetItems();
	
	If String.Type = "DataCompositionChart" Then
		SettingItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
		SetOutputParameter(SettingItem, "ChartType.ValuesBySeriesConnection", ChartValuesBySeriesConnectionType.EdgesConnection);
		SetOutputParameter(SettingItem, "ChartType.ValuesBySeriesConnectionLines");
		SetOutputParameter(SettingItem, "ChartType.ValuesBySeriesConnectionColor", WebColors.Gainsboro);
		SetOutputParameter(SettingItem, "ChartType.SplineMode", ChartSplineMode.SmoothCurve);
		SetOutputParameter(SettingItem, "ChartType.SemitransparencyMode", ChartSemitransparencyMode.Use);
		
		String.Presentation = NStr("en = 'Chart';");
		
		SubordinateSettingItem = SettingItem.Points;
		SubordinateRow = SubordinateRows.Add(); // See SettingsFormCollectionItem
		SubordinateRow.Type = SubordinateSettingItem;
		SubordinateRow.Subtype = "ChartPoints";
		SubordinateRow.Id = StructureItemProperty.GetIDByObject(SubordinateSettingItem);
		SubordinateRow.Picture = -1;
		SubordinateRow.Presentation = NStr("en = 'Dots';");
		
		SubordinateSettingItem = SettingItem.Series;
		SubordinateRow = SubordinateRows.Add(); // See SettingsFormCollectionItem
		SubordinateRow.Type = SubordinateSettingItem;
		SubordinateRow.Subtype = "ChartSeries";
		SubordinateRow.Id = StructureItemProperty.GetIDByObject(SubordinateSettingItem);
		SubordinateRow.Picture = -1;
		SubordinateRow.Presentation = NStr("en = 'Series';");
	ElsIf String.Type = "DataCompositionTable" Then
		String.Presentation = NStr("en = 'Table';");
		
		SubordinateSettingItem = SettingItem.Rows;
		SubordinateRow = SubordinateRows.Add(); // See SettingsFormCollectionItem
		SubordinateRow.Type = SubordinateSettingItem;
		SubordinateRow.Subtype = "TableRows1";
		SubordinateRow.Id = StructureItemProperty.GetIDByObject(SubordinateSettingItem);
		SubordinateRow.Picture = -1;
		SubordinateRow.Presentation = NStr("en = 'Rows';");
		
		SubordinateSettingItem = SettingItem.Columns;
		SubordinateRow = SubordinateRows.Add(); // See SettingsFormCollectionItem
		SubordinateRow.Type = SubordinateSettingItem;
		SubordinateRow.Subtype = "ColumnsTable";
		SubordinateRow.Id = StructureItemProperty.GetIDByObject(SubordinateSettingItem);
		SubordinateRow.Picture = -1;
		SubordinateRow.Presentation = NStr("en = 'Columns';");
	EndIf;
	
	Items.OptionStructure.Expand(String.GetID(), True);
	DetermineIfModified();
EndProcedure

&AtClient
Procedure OptionStructureAfterSelectField(SettingDetails, ExecutionParameters) Export
	If SettingDetails = Undefined Then
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	ReportsOptionsInternalClient.AddFormula(Settings, Settings.GroupAvailableFields, SettingDetails);
	
	CurrentRow = Items.OptionStructure.CurrentData;
	
	RowsToMoveToNewGroup = New Array;
	If ExecutionParameters.Wrap Then
		If ExecutionParameters.NextLevel Then
			FoundItems = CurrentRow.GetItems();
			For Each RowToMove In FoundItems Do
				RowsToMoveToNewGroup.Add(RowToMove);
			EndDo;
		Else
			RowsToMoveToNewGroup.Add(CurrentRow);
		EndIf;
	EndIf;
	
	// Add a new grouping.
	Result = InsertSettingsStructureItem(Type("DataCompositionGroup"), CurrentRow, ExecutionParameters.NextLevel);
	
	SettingItem = Result.SettingItem;
	SettingItem.Use = True;
	SettingItem.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	SettingItem.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	If SettingDetails = "<>" Then
		// Detailed records: no need to add a field.
		Presentation = NStr("en = '<Detailed records>';");
	Else
		GroupingField = SettingItem.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Use = True;
		GroupingField.Field = SettingDetails.Field;
		Presentation = SettingDetails.Title;
	EndIf;
	
	String = Result.String;
	String.Use = SettingItem.Use;
	String.Presentation = Presentation;
	String.AvailableFlag = True;
	String.Type = SettingItem;
	
	ElementType = Type(String.Type);
	ItemTypePresentation = ReportsClientServer.SettingTypeAsString(ElementType);
	ItemState = ?(String.DeletionMark, "DeletionMark", Undefined);
	String.Picture = ReportsClientServer.PictureIndex(ItemTypePresentation, ItemState);
	
	If Not ExecutionParameters.NextLevel Then
		String.Title = CurrentRow.Title;
		UpdateOptionStructureItemTitle(String);
		CurrentRow.Title = "";
		UpdateOptionStructureItemTitle(CurrentRow);
	EndIf;
	
	// Moving the current grouping to a new one.
	For Each RowToMove In RowsToMoveToNewGroup Do
		Result = MoveOptionStructureItems(RowToMove, String);
	EndDo;
	
	Items.OptionStructure.Expand(String.GetID(), True);
	Items.OptionStructure.CurrentRow = String.GetID();
	
	DetermineIfModified();
EndProcedure

// Parameters:
//  ElementType - Type
//  String - See SettingsFormCollectionItem
//  NextLevel - Boolean
//
// Returns:
//  Structure:
//    * String - See SettingsFormCollectionItem
//    * StructureItemProperty - See SettingsStructureItemProperty
//    * SettingItem - See SettingItem
//
&AtClient
Function InsertSettingsStructureItem(ElementType, String, NextLevel)
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	
	If String = Undefined Then
		String = DefaultRootRow("OptionStructure");
	EndIf;
	
	Parent = GetParent("OptionStructure", String);
	If Not ValueIsFilled(String.Subtype) Then 
		String.Subtype = Parent.Subtype;
	EndIf;
	
	SettingItem = SettingItem(StructureItemProperty, String);
	CollectionName = ?(ValueIsFilled(String.Subtype), String.Subtype, Undefined);
	
	If NextLevel Then
		Rows = String.GetItems();
		IndexOf = Undefined;
		
		SettingsItems = SettingsItems(StructureItemProperty, SettingItem, CollectionName);
		SettingItemIndex = Undefined
	Else // Inserting it on the same level as the row.
		Parent = GetParent("OptionStructure", String);
		Rows = Parent.GetItems();
		IndexOf = Rows.IndexOf(String) + 1;
		
		SettingItemParent = GetSettingItemParent(StructureItemProperty, SettingItem);
		SettingsItems = SettingsItems(StructureItemProperty, SettingItemParent, CollectionName);
		SettingItemIndex = SettingsItems.IndexOf(SettingItem) + 1;
	EndIf;
	
	If IndexOf = Undefined Then
		NewRow = Rows.Add();
	Else
		NewRow = Rows.Insert(IndexOf);
	EndIf;
	
	If ReportsClient.SpecifyItemTypeOnAddToCollection(TypeOf(SettingsItems)) Then
		If SettingItemIndex = Undefined Then
			NewSettingItem = SettingsItems.Add(ElementType);
		Else
			NewSettingItem = SettingsItems.Insert(SettingItemIndex, ElementType);
		EndIf;
	Else
		If SettingItemIndex = Undefined Then
			NewSettingItem = SettingsItems.Add();
		Else
			NewSettingItem = SettingsItems.Insert(SettingItemIndex);
		EndIf;
	EndIf;
	Items.OptionStructure.CurrentRow = NewRow.GetID();
	NewRow.Id = StructureItemProperty.GetIDByObject(NewSettingItem);
	
	Result = New Structure("String, StructureItemProperty, SettingItem");
	Result.String = NewRow;
	Result.StructureItemProperty = StructureItemProperty;
	Result.SettingItem = NewSettingItem;
	
	Return Result;
EndFunction

&AtClient
Function MoveOptionStructureItems(Val String, Val NewParent,
	Val BeforeWhatToInsert = Undefined, Val IndexOf = Undefined, Val SettingItemIndex = Undefined)
	
	Result = New Structure("String, SettingItem, IndexOf, SettingItemIndex");
	
	AddToEnd = (NewParent = Undefined);
	WhereToInsert = GetItems(OptionStructure, NewParent);
	
	DCNode = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	
	DCItem = SettingItem(DCNode, String);
	NewDCParent = SettingItem(DCNode, NewParent);
	WhereToInsertDC = SettingsItems(DCNode, NewDCParent);
	BeforeWhatToInsertDC = SettingItem(DCNode, BeforeWhatToInsert);
	
	PreviousParent = GetParent("OptionStructure", String);
	FromWhereToMove = GetItems(OptionStructure, PreviousParent);
	
	PreviousDCParent = SettingItem(DCNode, PreviousParent);
	FromWhereToMoveDC = SettingsItems(DCNode, PreviousDCParent);
	
	If DCItem = BeforeWhatToInsertDC Then
		Result.SettingItem = DCItem;
		Result.String = String;
	Else
		If IndexOf = Undefined Or SettingItemIndex = Undefined Then
			If BeforeWhatToInsertDC = Undefined Then
				If AddToEnd Then
					IndexOf = WhereToInsert.Count();
					SettingItemIndex = WhereToInsertDC.Count();
				Else
					IndexOf = 0;
					SettingItemIndex = 0;
				EndIf;
			Else
				IndexOf = WhereToInsert.IndexOf(BeforeWhatToInsert);
				SettingItemIndex = WhereToInsertDC.IndexOf(BeforeWhatToInsertDC);
				If PreviousParent = NewParent Then
					PreviousIndex = FromWhereToMove.IndexOf(String);
					If PreviousIndex <= IndexOf Then
						IndexOf = IndexOf + 1;
						SettingItemIndex = SettingItemIndex + 1;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		SearchForDCItems = New Map;
		Result.SettingItem = ReportsClientServer.CopyRecursive(DCNode, DCItem, WhereToInsertDC, SettingItemIndex, SearchForDCItems);
		
		SearchForTableRows = New Map;
		Result.String = ReportsClientServer.CopyRecursive(Undefined, String, WhereToInsert, IndexOf, SearchForTableRows);
		
		For Each KeyAndValue In SearchForTableRows Do
			OldRow = KeyAndValue.Key; // See SettingsFormCollectionItem
			NewRow = KeyAndValue.Value; // See SettingsFormCollectionItem
			NewRow.Id = SearchForDCItems.Get(OldRow.Id);
		EndDo;
		
		FromWhereToMove.Delete(String);
		FromWhereToMoveDC.Delete(DCItem);
	EndIf;
	
	Result.IndexOf = WhereToInsert.IndexOf(Result.String);
	Result.SettingItemIndex = WhereToInsertDC.IndexOf(Result.SettingItem);
	
	Return Result;
EndFunction

&AtClient
Procedure OptionStructureOnChangeCurrentRow()
	String = Items.OptionStructure.CurrentData;
	Items.OptionStructureCommands_Add.Enabled = String <> Undefined;
	Items.OptionStructureCommands_Add1.Enabled = Items.OptionStructureCommands_Add.Enabled;
	If String <> Undefined Then
		SetTheAvailabilityOfTheOptionStructureCommands(String.GetID());
	EndIf;
EndProcedure

&AtClient
Procedure SetTheAvailabilityOfTheOptionStructureCommands(RowID)
	String = OptionStructure.FindByID(RowID);
	Parent = String.GetParent();
	HasParent = (Parent <> Undefined);
	ThereArePotentialParents = HasParent And GetItems(OptionStructure, Parent).IndexOf(String) > 0;
	HasSubordinateItems = (String.GetItems().Count() > 0);
	HasNeighbors = GetItems(OptionStructure, Parent).Count() > 1;
	
	CanAddNestedItems = (String.Type <> "DataCompositionTable"
		And String.Type <> "DataCompositionChart");
	
	CanGroup = (String.Type <> "DataCompositionSettings"
		And String.Type <> "DataCompositionNestedObjectSettings"
		And String.Type <> "DataCompositionTableStructureItemCollection"
		And String.Type <> "DataCompositionChartStructureItemCollection");
	
	CanOpen = (String.Type <> "DataCompositionSettings"
		And String.Type <> "DataCompositionNestedObjectSettings"
		And String.Type <> "DataCompositionTable"
		And String.Type <> "DataCompositionChart"
		And String.Type <> "DataCompositionTableStructureItemCollection"
		And String.Type <> "DataCompositionChartStructureItemCollection");
	
	CanRemoveAndMove = (String.Type <> "DataCompositionSettings"
		And String.Type <> "DataCompositionNestedObjectSettings"
		And String.Type <> "DataCompositionTableStructureItemCollection"
		And String.Type <> "DataCompositionChartStructureItemCollection");
	
	CanAddTablesAndCharts = (String.Type = "DataCompositionSettings"
		Or String.Type = "DataCompositionNestedObjectSettings"
		Or String.Type = "DataCompositionGroup");
	
	CanMoveParent = (HasParent
		And Parent.Type <> "DataCompositionSettings"
		And Parent.Type <> "DataCompositionTableStructureItemCollection"
		And Parent.Type <> "DataCompositionChartStructureItemCollection");
		
	Items.OptionStructure_Add.Enabled  = CanAddNestedItems;
	Items.OptionStructure_Add1.Enabled = CanAddNestedItems;
	Items.OptionStructure_Change.Enabled  = CanOpen;
	Items.OptionStructure_Change1.Enabled = CanOpen;
	Items.OptionStructure_AddTable.Enabled  = CanAddTablesAndCharts;
	Items.OptionStructure_AddTable1.Enabled = CanAddTablesAndCharts;
	Items.OptionStructure_AddChart.Enabled  = CanAddTablesAndCharts;
	Items.OptionStructure_AddChart1.Enabled = CanAddTablesAndCharts;
	Items.OptionStructure_Delete.Enabled  = CanRemoveAndMove;
	Items.OptionStructure_Delete1.Enabled = CanRemoveAndMove;
	Items.OptionStructure_Group.Enabled  = CanGroup;
	Items.OptionStructure_Group1.Enabled = CanGroup;
	Items.OptionStructure_MoveUpAndLeft.Enabled  = CanRemoveAndMove And CanMoveParent And CanAddNestedItems And CanGroup;
	Items.OptionStructure_MoveUpAndLeft1.Enabled = CanRemoveAndMove And CanMoveParent And CanAddNestedItems And CanGroup;
	Items.OptionStructure_MoveDownAndRight.Enabled  = CanRemoveAndMove And HasSubordinateItems And CanAddNestedItems And CanGroup;
	Items.OptionStructure_MoveDownAndRight1.Enabled = CanRemoveAndMove And HasSubordinateItems And CanAddNestedItems And CanGroup;
	Items.OptionStructure_MoveUp.Enabled  = CanRemoveAndMove And HasNeighbors;
	Items.OptionStructure_MoveUp1.Enabled = CanRemoveAndMove And HasNeighbors;
	Items.OptionStructure_MoveDown.Enabled  = CanRemoveAndMove And HasNeighbors;
	Items.OptionStructure_MoveDown1.Enabled = CanRemoveAndMove And HasNeighbors;
	Items.OptionStructure_MoveOneLevelUp.Enabled = CanRemoveAndMove And  HasParent And CanMoveParent;
	Items.OptionStructure_MoveOneLevelUp1.Enabled = CanRemoveAndMove And HasParent And CanMoveParent;
	Items.OptionStructure_MoveOneLevelBelow.Enabled = CanRemoveAndMove And ThereArePotentialParents;
	Items.OptionStructure_MoveOneLevelBelow1.Enabled = CanRemoveAndMove And ThereArePotentialParents;
EndProcedure

&AtClient
Procedure ChangeStructureItem(String, PageName = Undefined, UseOptionForm = Undefined)
	If String = Undefined Then
		Rows = OptionStructure.GetItems();
		If Rows.Count() = 0 Then
			Return;
		EndIf;
		String = Rows[0];
	EndIf;
	
	If UseOptionForm = Undefined Then
		UseOptionForm = (String.Type = "DataCompositionTable"
			Or String.Type = "DataCompositionNestedObjectSettings");
	EndIf;
	
	Handler = New NotifyDescription("ChangeStructureItemCompletion", ThisObject);
	
	TitleTemplate1 = NStr("en = '%1 settings of report %2';");
	If String.Type = "DataCompositionChart" Then
		ItemPresentation = NStr("en = 'Chart';");
	Else
		ItemPresentation = NStr("en = 'Grouping';");
	EndIf;
	
	If ValueIsFilled(String.Title) Then
		ItemPresentation = ItemPresentation + " """ + String.Title + """";
	ElsIf ValueIsFilled(String.Presentation) Then
		ItemPresentation = ItemPresentation + " """ + String.Presentation + """";
	EndIf;
	
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	SettingItem = SettingItem(StructureItemProperty, String);
	
	PathToSettingsStructureItem = ReportsClient.FullPathToSettingsItem(
		Report.SettingsComposer.Settings, SettingItem);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", String(CurrentVariantKey));
	FormParameters.Insert("Variant", Report.SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("DescriptionOption", DescriptionOption);
	FormParameters.Insert("SettingsStructureItemID", String.Id);
	FormParameters.Insert("PathToSettingsStructureItem", PathToSettingsStructureItem);
	FormParameters.Insert("SettingsStructureItemType", String.Type);
	FormParameters.Insert("Title", StringFunctionsClientServer.SubstituteParametersToString(
		TitleTemplate1, ItemPresentation, DescriptionOption));
	If PageName <> Undefined Then
		FormParameters.Insert("PageName", PageName);
	EndIf;
	
	RunMeasurements = ReportSettings.RunMeasurements And ValueIsFilled(ReportSettings.MeasurementsKey);
	If RunMeasurements Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		ModulePerformanceMonitorClient.TimeMeasurement(
			ReportSettings.MeasurementsKey + ".Settings", False, False);
	EndIf;
	
	NameOfFormToOpen_ = ReportSettings.FullName + ?(UseOptionForm, ".VariantForm", ".SettingsForm");
	OpenForm(NameOfFormToOpen_, FormParameters, ThisObject,,,, Handler, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure ChangeStructureItemCompletion(Result, Context) Export
	If TypeOf(Result) <> Type("Structure")
		Or Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Result.VariantModified Then 
		UpdateForm(Result);
		
		Section = DefaultRootRow("OptionStructure");
		Items.OptionStructure.Expand(Section.GetID(), True);
	EndIf;
EndProcedure

#EndRegion

#Region Common

#Region NotificationsHandlers

&AtClient
Function ListFillingParameters(Var_CloseOnChoice = False, MultipleChoice = True, AddRow1 = True)
	FillParameters = New Structure("ListPath, IndexOf, Owner, SelectedType, ChoiceFoldersAndItems");
	FillParameters.Insert("AddRow1", AddRow1);
	// Standard form parameters.
	FillParameters.Insert("CloseOnChoice", Var_CloseOnChoice);
	FillParameters.Insert("CloseOnOwnerClose", True);
	FillParameters.Insert("Filter", New Structure);
	// Standard parameters of the choice form. See "Client application form extension for dynamic lists" in Syntax Assistant.
	FillParameters.Insert("MultipleChoice", MultipleChoice);
	FillParameters.Insert("ChoiceMode", True);
	// Expected attributes.
	FillParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	FillParameters.Insert("EnableStartDrag", False);
	
	Return FillParameters;
EndFunction

&AtClient
Procedure StartListFilling(Item, FillParameters, ChoiceOverride = Undefined, IsPick = False)
	ValueType = ThisObject[FillParameters.ListPath].ValueType;
	ListBox = Items[FillParameters.ListPath]; // FormTable
	ValueField = Items[FillParameters.ListPath + "Value"];
	
	InformationRecords = ReportsClient.SettingItemInfo(Report.SettingsComposer, FillParameters.IndexOf);
	
	ChoiceFoldersAndItems = Undefined;
	If InformationRecords.LongDesc <> Undefined Then 
		ChoiceFoldersAndItems = InformationRecords.LongDesc.ChoiceFoldersAndItems;
	EndIf;
	
	UserSettingItem = InformationRecords.UserSettingItem;
	
	Condition = ReportsClientServer.SettingItemCondition(UserSettingItem, InformationRecords.LongDesc);
	ValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(
		ChoiceFoldersAndItems, Condition);
	FillParameters.ChoiceFoldersAndItems = ReportsClient.ValueOfFoldersAndItemsUseType(
		ChoiceFoldersAndItems, Condition);
	
	ExtendedTypesDetails = CommonClientServer.StructureProperty(
		Report.SettingsComposer.Settings.AdditionalProperties, "ExtendedTypesDetails", New Map);
	
	ExtendedTypeDetails = ExtendedTypesDetails[FillParameters.IndexOf];
	If ExtendedTypeDetails <> Undefined Then 
		ValueType = ExtendedTypeDetails.TypesDetailsForForm;
	EndIf;
	If CommonClientServer.StructureProperty(FillParameters, "IsPick", False) Then
		ValueType = TypesDetailsWithoutPrimitiveOnes(ValueType);
	EndIf;
	
	UserSettings = Report.SettingsComposer.UserSettings.Items;
	
	ChoiceParameters = ReportsClientServer.ChoiceParameters(InformationRecords.Settings, UserSettings, InformationRecords.Item);
	FillParameters.Insert("ChoiceParameters", ChoiceParameters);
	
	ValueType = ReportsClient.ValueTypeRestrictedByLinkByType(
		InformationRecords.Settings, UserSettings, InformationRecords.Item, InformationRecords.LongDesc, ValueType);
	
	If TypeOf(UserSettingItem) = Type("DataCompositionFilterItem") Then
		CurrentValue = UserSettingItem.RightValue;
	Else
		CurrentValue = UserSettingItem.Value;
	EndIf;
	
	MarkedValues = ReportsClientServer.ValuesByList(CurrentValue);
	
	If MarkedValues.Count() > 0 Then 
		FillParameters.Insert("CurrentRow", MarkedValues[0].Value);
	EndIf;
	
	Handler = New NotifyDescription("CompleteListFilling", ThisObject, FillParameters);
	
	If ReportsClient.ChoiceOverride(ThisObject, Handler, InformationRecords.LongDesc,
			ValueType, MarkedValues, ChoiceParameters) Then
		ChoiceOverride = True;
		Return;
	EndIf;
	
	If ChoiceOverride <> Undefined Then
		Return;
	EndIf;
	
	Types = ValueType.Types();
	If Types.Count() = 0 Then
		If FillParameters.AddRow1 Then 
			ListBox.AddRow();
		EndIf;
		Return;
	EndIf;
	
	If CommonClientServer.StructureProperty(FillParameters, "IsPick", False)
		And ReportsClient.IsSelectMetadataObjects(ValueType, MarkedValues, Handler) Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Types", Types);
	Context.Insert("FillParameters", FillParameters);
	Context.Insert("Item", Item);
	
	If CommonClientServer.StructureProperty(FillParameters, "IsPick", False) Then
		ReportsClient.StartSelectUsers(ThisObject,
			Item, ValueType, MarkedValues, ChoiceParameters, Handler,
			New NotifyDescription("StartListPopulationFollowUp", ThisObject, Context));
	Else
		StartListPopulationFollowUp(Undefined, Context);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartListPopulationFollowUp(SelectedElement, Context) Export
	
	If SelectedElement <> Undefined Then
		ContinueFillingList(SelectedElement, Context.FillParameters);
		Return;
	EndIf;
	
	If Context.Types.Count() = 1 Then
		Context.FillParameters.SelectedType = Context.Types[0];
		ContinueFillingList(-1, Context.FillParameters);
		Return;
	EndIf;
	
	AvailableTypes = New ValueList;
	AvailableTypes.LoadValues(Context.Types);
	
	Handler = New NotifyDescription("ContinueFillingList", ThisObject, Context.FillParameters);
	ShowChooseFromMenu(Handler, AvailableTypes, Context.Item);
EndProcedure

&AtClient
Procedure ContinueFillingList(SelectedElement, FillParameters) Export
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	If SelectedElement <> -1 Then
		FillParameters.SelectedType = SelectedElement.Value;
	EndIf;
	
	PickingParameters = CommonClientServer.StructureProperty(
		Report.SettingsComposer.Settings.AdditionalProperties, "PickingParameters", New Map);
	
	FormPath = PickingParameters[FillParameters.IndexOf];
	If Not ValueIsFilled(FormPath) Then 
		FormPath = PickingParameters[FillParameters.SelectedType];
	EndIf;
	If Not ValueIsFilled(FormPath) Then 
		List = ThisObject[FillParameters.ListPath];
		If TypeOf(List) = Type("ValueList")
		   And ValueIsFilled(List) Then
			LastItem = List[List.Count()-1];
			If LastItem.Value = Undefined Then
				TypeDetails = New TypeDescription(
					CommonClientServer.ValueInArray(SelectedElement.Value));
				LastItem.Value = TypeDetails.AdjustValue(Undefined);
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	For Each Parameter In FillParameters.ChoiceParameters Do 
		If Not ValueIsFilled(Parameter.Name) Then
			Continue;
		EndIf;
		
		If StrStartsWith(Upper(Parameter.Name), "FILTER.") Then 
			FillParameters.Filter.Insert(StrSplit(Parameter.Name, ".")[1], Parameter.Value);
		Else
			FillParameters.Insert(Parameter.Name, Parameter.Value);
		EndIf;
	EndDo;
	
	Owner = FillParameters.Owner;
	FillParameters.Delete("Owner");
	
	OpenForm(FormPath, FillParameters, Owner);
EndProcedure

&AtClient
Procedure CompleteListFilling(SelectedValues, FillParameters) Export
	If TypeOf(SelectedValues) = Type("Array") Then
		Values = SelectedValues;
		
		SelectedValues = New ValueList;
		SelectedValues.LoadValues(Values);
		SelectedValues.FillChecks(True);
	ElsIf TypeOf(SelectedValues) <> Type("ValueList") Then
		Return;
	EndIf;
	
	ListPath = FillParameters.ListPath;
	List = ThisObject[ListPath];
	
	IndexOf = List.Count() - 1;
	While IndexOf >= 0 Do 
		Item = List[IndexOf];
		IndexOf = IndexOf - 1;
		
		If Item.Check
			And SelectedValues.FindByValue(Item.Value) = Undefined Then 
			List.Delete(Item);
		EndIf;
	EndDo;
	
	For Each Item In SelectedValues Do 
		ReportsClientServer.AddUniqueValueToList(List, Item.Value, Item.Presentation, True);
	EndDo;
	
	SettingsComposer = Report.SettingsComposer;
	
	IndexOf = PathToItemsData.ByName[ListPath];
	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	SettingItem.Use = True;
	
	If TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then
		SettingItem.RightValue = SelectedValues;
	Else
		SettingItem.Value = SelectedValues;
	EndIf;
	
	RegisterList(Items[ListPath], SettingItem);
EndProcedure

&AtClient
Procedure PasteFromClipboard1Completion(FoundObjects, ListPath) Export
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	
	List = ThisObject[ListPath];
	
	SettingsComposer = Report.SettingsComposer;
	
	IndexOf = PathToItemsData.ByName[ListPath];
	SettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	
	If TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then
		If SettingItem.RightValue = Undefined Then
			SettingItem.RightValue = New ValueList;
		EndIf;
		
		Marked = SettingItem.RightValue;
	Else
		If SettingItem.Value = Undefined Then
			SettingItem.Value = New ValueList;
		EndIf;
		
		Marked = SettingItem.Value;
	EndIf;
	
	For Each Value In FoundObjects Do
		ReportsClientServer.AddUniqueValueToList(List, Value, Undefined, True);
		ReportsClientServer.AddUniqueValueToList(Marked, Value, Undefined, True);
	EndDo;
	
	SettingItem.Use = True;
	
	RegisterList(Items[ListPath], SettingItem);
EndProcedure

#EndRegion

&AtClientAtServerNoContext
Function SettingsStructureItemProperty(SettingsComposer, Var_Key, ItemID = Undefined, Mode = Undefined)
	Settings = SettingsComposer.Settings;
	
	If Var_Key = "Structure" Then 
		Return Settings;
	EndIf;
	
	StructureItem = SettingsStructureItem(Settings, ItemID);
	
	StructureItemType = TypeOf(StructureItem);
	If StructureItem = Undefined
		Or (StructureItemType = Type("DataCompositionTable") And Var_Key <> "Selection" And Var_Key <> "ConditionalAppearance")
		Or (StructureItemType = Type("DataCompositionChart") And Var_Key <> "Selection" And Var_Key <> "ConditionalAppearance")
		Or (StructureItemType = Type("DataCompositionSettings") And Var_Key = "GroupFields")
		Or (StructureItemType = Type("DataCompositionGroup") And Var_Key = "DataParameters")
		Or (StructureItemType = Type("DataCompositionTableGroup") And Var_Key = "DataParameters")
		Or (StructureItemType = Type("DataCompositionChartGroup") And Var_Key = "DataParameters") Then 
		Return Undefined;
	EndIf;
	
	StructureItemProperty = StructureItem[Var_Key];
	
	If Mode = 0
		And (TypeOf(StructureItemProperty) = Type("DataCompositionSelectedFields")
			Or TypeOf(StructureItemProperty) = Type("DataCompositionOrder"))
		And ValueIsFilled(StructureItemProperty.UserSettingID) Then 
		
		StructureItemProperty = SettingsComposer.UserSettings.Items.Find(
			StructureItemProperty.UserSettingID);
	EndIf;
	
	Return StructureItemProperty;
EndFunction

&AtClientAtServerNoContext
Function SettingsStructureItem(Settings, ItemID)
	If TypeOf(ItemID) = Type("DataCompositionID") Then 
		StructureItem = Settings.GetObjectByID(ItemID);
	Else
		StructureItem = Settings;
	EndIf;
	
	Return StructureItem;
EndFunction

&AtClientAtServerNoContext
Function SettingsStructureItemPropertyKey(CollectionName, String)
	Var_Key = Undefined;
	
	If CollectionName = "GroupingComposition" Then 
		Var_Key = "GroupFields";
	ElsIf CollectionName = "Parameters" Or CollectionName = "Filters" Then 
		Var_Key = ?(String.IsParameter, "DataParameters", "Filter");
	ElsIf CollectionName = "SelectedFields" Then 
		Var_Key = "Selection";
	ElsIf CollectionName = "Sort" Then 
		Var_Key = "Order";
	ElsIf CollectionName = "Appearance" Then 
		Var_Key = ?(String.IsOutputParameter, "OutputParameters", "ConditionalAppearance");
	ElsIf CollectionName = "OptionStructure" Then 
		Var_Key = "Structure";
	EndIf;
	
	Return Var_Key;
EndFunction

&AtClient
Procedure DeleteRows(Item, Cancel)
	Cancel = True;
	
	RowsIDs = Item.SelectedRows;
	
	IndexOf = RowsIDs.UBound();
	While IndexOf >= 0 Do 
		String = ThisObject[Item.Name].FindByID(RowsIDs[IndexOf]);
		IndexOf = IndexOf - 1;
		
		If TypeOf(String.Id) <> Type("DataCompositionID")
			Or (Item.Name = "Filters" And (String.IsSection Or String.IsParameter)) 
			Or (Item.Name = "Appearance" And String.IsOutputParameter) Then 
			Continue;
		EndIf;
		
		Rows = GetParent(Item.Name, String).GetItems();
		If Rows.IndexOf(String) < 0 Then 
			Continue;
		EndIf;
			
		PropertyKey = SettingsStructureItemPropertyKey(Item.Name, String);
		StructureItemProperty = SettingsStructureItemProperty(
			Report.SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);
		
		SettingItem = SettingItem(StructureItemProperty, String);
		If TypeOf(SettingItem) = Type("DataCompositionTableStructureItemCollection")
			Or TypeOf(SettingItem) = Type("DataCompositionChartStructureItemCollection") Then 
			Continue;
		EndIf;
		
		SettingItemParent = GetSettingItemParent(StructureItemProperty, SettingItem);
		CollectionName = SettingsCollectionNameByID(String.Id);
		SettingsItems = SettingsItems(StructureItemProperty, SettingItemParent, CollectionName);
		
		String.Use = False;
		ChangeUsageOfLinkedSettingsItems(Item.Name, String, SettingItem);
		
		SettingsItems.Delete(SettingItem);
		Rows.Delete(String);
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure CopySettings(Item)
	
	CopyingRow = Item.CurrentData;
	
	If TypeOf(CopyingRow.Id) <> Type("DataCompositionID")
		Or (CopyingRow.Property("IsSection") And CopyingRow.IsSection)
		Or (CopyingRow.Property("IsParameter") And CopyingRow.IsParameter)
		Or (CopyingRow.Property("IsOutputParameter") And CopyingRow.IsOutputParameter) Then 
		Return;
	EndIf;
	
	Parent = CopyingRow.GetParent();
	
	PropertyKey = SettingsStructureItemPropertyKey(Item.Name, CopyingRow);
	DCNode = SettingsStructureItemProperty(
			Report.SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);

	WhereToInsert = GetItems(ThisObject[Item.Name], Parent);
		
	DCItem = SettingItem(DCNode, CopyingRow);
	DCParent = SettingItem(DCNode, Parent);
	WhereToInsertDC = SettingsItems(DCNode, DCParent);
	
	IndexOf = WhereToInsert.Count();
	SettingItemIndex = WhereToInsertDC.Count();
	
	SearchForDCItems = New Map;
	ReportsClientServer.CopyRecursive(DCNode, DCItem, WhereToInsertDC, SettingItemIndex, SearchForDCItems);
	
	SearchForTableRows = New Map;
	ReportsClientServer.CopyRecursive(Undefined, CopyingRow, WhereToInsert, IndexOf, SearchForTableRows);  
	
	For Each KeyAndValue In SearchForTableRows Do
		OldRow = KeyAndValue.Key; 
		NewRow = KeyAndValue.Value;
		NewRow.Id = SearchForDCItems.Get(OldRow.Id);
	EndDo;
	
	DetermineIfModified();
	
EndProcedure

&AtClient
Procedure ChangeUsage(CollectionName, Use = True, Var_Items = Undefined)
	If Var_Items = Undefined Then 
		RootRow = DefaultRootRow(CollectionName);
		If RootRow = Undefined Then 
			Return;
		EndIf;
		
		Var_Items = RootRow.GetItems();
	EndIf;
	
	For Each Item In Var_Items Do 
		Item.Use = Use;
		
		PropertyKey = SettingsStructureItemPropertyKey(CollectionName, Item);
		StructureItemProperty = SettingsStructureItemProperty(
			Report.SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);
		
		SettingItem = SettingItem(StructureItemProperty, Item);
		If TypeOf(SettingItem) <> Type("DataCompositionSettings")
			And TypeOf(SettingItem) <> Type("DataCompositionTableStructureItemCollection")
			And TypeOf(SettingItem) <> Type("DataCompositionChartStructureItemCollection") Then 
			SettingItem.Use = Use;
		EndIf;
		
		ChangeUsage(CollectionName, Use, Item.GetItems());
	EndDo;
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure ChangeSettingItemUsage(CollectionName)
	String = Items[CollectionName].CurrentData;
	
	SettingsComposer = Report.SettingsComposer;
	
	PropertyKey = SettingsStructureItemPropertyKey(CollectionName, String);
	StructureItemProperty = SettingsStructureItemProperty(
		SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);
	
	SettingItem = SettingItem(StructureItemProperty, String);
	SettingItemParent = GetSettingItemParent(StructureItemProperty, SettingItem);
	
	If TypeOf(SettingItemParent) = Type("DataCompositionNestedObjectSettings") Then
		SettingItem = SettingItemParent;
	EndIf;
	
	SettingItem.Use = String.Use;
	
	If CollectionName = "Appearance" And  String.IsOutputParameter 
		And String(String.Id) = "DATAPARAMETERSOUTPUT" Then 
		
		SettingItem.Use = True;
		SettingItem.Value = ?(String.Use,
			DataCompositionTextOutputType.Auto, DataCompositionTextOutputType.DontOutput);
	EndIf;
	
	If ExtendedMode = 0 And CollectionName = "OptionStructure" Then 
		UserSettingItem = SettingsComposer.UserSettings.Items.Find(
			SettingItem.UserSettingID);
		If UserSettingItem <> Undefined Then 
			UserSettingItem.Use = SettingItem.Use;
		EndIf;
	EndIf;
	
	ChangeUsageOfLinkedSettingsItems(CollectionName, String, SettingItem);
	
	DetermineIfModified();
EndProcedure

&AtClient
Procedure ChangeUsageOfLinkedSettingsItems(CollectionName, String, SettingItem)

	If CollectionName = "Appearance" Then 
		If String.IsOutputParameter Then
			SynchronizePredefinedOutputParameters(String.Use, SettingItem);
		EndIf;
		Return;
	EndIf;

	LinkedCollections = New Array;
	If CollectionName = "GroupingComposition" Then
		LinkedCollections = StrSplit("SelectedFields,Sort", ",");
	ElsIf CollectionName = "SelectedFields" Then
		LinkedCollections = StrSplit("GroupingComposition,Sort", ",");
	EndIf;
	
	For Each LinkedCollection In LinkedCollections Do 
		ChangeFieldUsage(LinkedCollection, String.Field, String.Use);
	EndDo;
	
EndProcedure

&AtClient
Procedure ChangeFieldUsage(CollectionName, Field, Use)
	If Not ValueIsFilled(Field) Then
		Return;
	EndIf;
	Condition = New Structure("Field", Field);
	TableRows = ReportsClientServer.FindTableRows(ThisObject[CollectionName], Condition);
	
	StructureItemProperty = Undefined;
	For Each TableRow In TableRows Do
		If TableRow.Use = Use Then
			Continue;
		EndIf;
		
		If StructureItemProperty = Undefined Then
			PropertyKey = SettingsStructureItemPropertyKey(CollectionName, TableRow);
			StructureItemProperty = SettingsStructureItemProperty(
				Report.SettingsComposer, PropertyKey, SettingsStructureItemID, ExtendedMode);
		EndIf;
		
		SettingItem = SettingItem(StructureItemProperty, TableRow);
		If SettingItem <> Undefined Then
			TableRow.Use = Use;
			SettingItem.Use = Use;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SetDeletionMark(CollectionName, String)
	String.DeletionMark = True;
	
	If CollectionName = "Appearance" Then 
		String.Picture = ReportsClientServer.PictureIndex("Error");
	Else
		String.Picture = ReportsClientServer.PictureIndex("Item", "DeletionMark");
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure WriteAndClose(Regenerate)
	NotifyChoice(SelectionResult(Regenerate));
EndProcedure

&AtClient
Function SelectionResult(Regenerate)
	SelectionResultGenerated = True;
	
	If SettingsStructureItemChangeMode And Not Regenerate Then
		Return Undefined;
	EndIf;
	
	SelectionResult = ReportsClientServer.ReportFormUpdateParameters(ReportsOptionsInternalClientServer.NameEventFormSettings());
	SelectionResult.Regenerate = Regenerate;
	SelectionResult.ResetCustomSettings = (ExtendedMode = 1);
	SelectionResult.SettingsFormAdvancedMode = ExtendedMode;
	SelectionResult.SettingsFormPageName = Items.SettingsPages.CurrentPage.Name;
	SelectionResult.DCSettingsComposer = Report.SettingsComposer;
	SelectionResult.VariantModified = OptionChanged;
	SelectionResult.UserSettingsModified =
		OptionChanged Or UserSettingsModified;
	
	Return SelectionResult;
EndFunction

// Parameters:
//  Settings - DataCompositionSettings
//
// Returns:
//  Structure:
//    * TITLE - Structure:
//        ** Object - DataCompositionParameterValue
//        ** Id - DataCompositionID
//    * TITLEOUTPUT - Structure:
//        ** Object - DataCompositionParameterValue
//        ** Id - DataCompositionID
//    * DATAPARAMETERSOUTPUT - Structure:
//        ** Object - DataCompositionParameterValue
//        ** Id - DataCompositionID
//    * FILTEROUTPUT - Structure:
//        ** Object - DataCompositionParameterValue
//        ** Id - DataCompositionID
//
&AtClientAtServerNoContext
Function PredefinedOutputParameters(Settings)
	PredefinedParameters = New Structure("TITLE, TITLEOUTPUT, DATAPARAMETERSOUTPUT, FILTEROUTPUT");
	
	OutputParameters = Settings.OutputParameters;
	For Each Parameter In PredefinedParameters Do 
		ParameterProperties = New Structure("Object, Id");
		ParameterProperties.Object = OutputParameters.Items.Find(Parameter.Key);
		ParameterProperties.Id = OutputParameters.GetIDByObject(ParameterProperties.Object);
		
		PredefinedParameters[Parameter.Key] = ParameterProperties;
	EndDo;
	
	Return PredefinedParameters;
EndFunction

&AtClient
Procedure SetOutputParameter(StructureItem, ParameterName, Value = Undefined, Use = True)
	ParameterValue = StructureItem.OutputParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	If ParameterValue = Undefined Then
		Return;
	EndIf;
	
	If Value <> Undefined Then
		ParameterValue.Value = Value;
	EndIf;
	
	If Use <> Undefined Then
		ParameterValue.Use = Use;
	EndIf;
EndProcedure

// Parameters:
//  NameOfTable - String
//  Action - String
//
// Returns:
//  Structure:
//    * Action - String
//    * NameOfTable - String
//    * CancelReason - String
//    * TreeRows - Array of FormDataTreeItem
//    * CurrentRow - See SettingsFormCollectionItem
//    * CurrentParent - See SettingsFormCollectionItem
//
&AtClient
Function NewContext(Val NameOfTable, Val Action)
	Result = New Structure;
	Result.Insert("CancelReason", "");
	Result.Insert("NameOfTable", NameOfTable);
	Result.Insert("Action", Action);
	Return Result;
EndFunction

&AtClient
Procedure DefineSelectedRows(Context)
	Context.Insert("TreeRows", New Array); // Selected rows (not IDs).
	Context.Insert("CurrentRow", Undefined); // An active row (not an ID).
	TableItem = Items[Context.NameOfTable];
	TableAttribute1 = ThisObject[Context.NameOfTable];
	IDCurrentRow = TableItem.CurrentRow;
	
	Specifics = New Structure("CanBeSections, CanBeParameters,
		|CanBeOutputParameters, CanBeGroups, RequireOneParent");
	Specifics.CanBeSections = (Context.NameOfTable = "Filters"
		Or Context.NameOfTable = "SelectedFields"
		Or Context.NameOfTable = "Sort"
		Or Context.NameOfTable = "Appearance");
	Specifics.CanBeParameters = (Context.NameOfTable = "Filters");
	Specifics.CanBeOutputParameters = (Context.NameOfTable = "Appearance");
	Specifics.RequireOneParent = (Context.Action = "MoveTo"
		Or Context.Action = "MoveToHierarchy"
		Or Context.Action = "Group");
	Specifics.CanBeGroups = (Context.NameOfTable = "Filters" Or Context.NameOfTable = "SelectedFields");
	If Specifics.RequireOneParent Then
		Context.Insert("CurrentParent", -1);
	EndIf;
	If Specifics.CanBeGroups Then
		HadGroups = False;
	EndIf;
	
	SelectedRows = ArraySort(TableItem.SelectedRows, SortDirection.Asc);
	For Each IDRow In SelectedRows Do
		TreeRow = TableAttribute1.FindByID(IDRow);
		If Not RowAdded(Context, TreeRow, Specifics) Then
			Return;
		EndIf;
		If Specifics.CanBeGroups And TreeRow.IsFolder Then
			HadGroups = True;
		EndIf;
		If IDRow = IDCurrentRow Then
			Context.CurrentRow = TreeRow;
		EndIf;
	EndDo;
	If Context.TreeRows.Count() = 0 Then
		Context.CancelReason = NStr("en = 'Select items.';");
		Return;
	EndIf;
	If Context.CurrentRow = Undefined Then
		If Context.Action = "ChangeGroup" Then
			Context.CancelReason = NStr("en = 'Select group.';");
			Return;
		EndIf;
	EndIf;
	
	// Remove all subordinate rows whose parents are enabled from the list of rows to be removed.
	If Context.Action = "Delete" And Specifics.CanBeGroups And HadGroups Then
		Count = Context.TreeRows.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			Parent = Context.TreeRows[ReverseIndex];
			While Parent <> Undefined Do
				Parent = Parent.GetParent();
				If Context.TreeRows.Find(Parent) <> Undefined Then
					Context.TreeRows.Delete(ReverseIndex);
					Break;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
EndProcedure

&AtClient
Function RowAdded(Rows, TreeRow, Specifics)
	If Rows.TreeRows.Find(TreeRow) <> Undefined Then
		Return True; // Skip the row.
	EndIf;
	If Specifics.CanBeSections And TreeRow.IsSection Then
		Return True; // Skip the row.
	EndIf;
	If (Specifics.CanBeParameters And TreeRow.IsParameter)
		Or (Specifics.CanBeOutputParameters And TreeRow.IsOutputParameter) Then
		If Rows.Action = "MoveTo" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be moved.';");
		ElsIf Rows.Action = "Group" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be group participants.';");
		ElsIf Rows.Action = "Delete" Then
			Rows.CancelReason = NStr("en = 'Parameters cannot be deleted.';");
		EndIf;
		Return False;
	EndIf;
	If Specifics.RequireOneParent Then
		Parent = TreeRow.GetParent();
		If Rows.CurrentParent = -1 Then
			Rows.CurrentParent = Parent;
		ElsIf Rows.CurrentParent <> Parent Then
			If Rows.Action = "MoveTo" Then
				Rows.CancelReason = NStr("en = 'Cannot move selected items as they have different parents.';");
			ElsIf Rows.Action = "Group" Then
				Rows.CancelReason = NStr("en = 'Cannot group selected items as they have different parents.';");
			EndIf;
			Return False; 
		EndIf;
	EndIf;
	Rows.TreeRows.Add(TreeRow);
	Return True; // Next row.
EndFunction

&AtClient
Procedure ShiftRows(Context)
	CurrentParent = Context.CurrentParent; // See SettingsFormCollectionItem
	DCNode = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	
	If Context.CurrentParent = Undefined Then
		TableAttribute1 = ThisObject[Context.NameOfTable];
		If Context.NameOfTable = "Filters" And Not SettingsStructureItemChangeMode Then
			CurrentParent = TableAttribute1.GetItems()[1];
		Else
			CurrentParent = TableAttribute1;
		EndIf;
		DCCurrentParent = DCNode;
	ElsIf TypeOf(CurrentParent.Id) <> Type("DataCompositionID") Then
		DCCurrentParent = DCNode;
	Else
		DCCurrentParent = DCNode.GetObjectByID(CurrentParent.Id);
	EndIf;
	ParentRows = CurrentParent.GetItems();
	DCParentRows = SettingsItems(DCNode, DCCurrentParent);
	
	UpperRowsBound = ParentRows.Count() - 1;
	RowsSelectedCount = Context.TreeRows.Count();
	
	// An array of selected rows against the movement:
	// When moved toward "+", iterate from lesser to greater.
	// When moved toward "-", iterate from greater to lesser.
	MoveAsc = (Context.Direction < 0);
	
	For Number = 1 To RowsSelectedCount Do
		If MoveAsc Then 
			IndexInArray = Number - 1;
		Else
			IndexInArray = RowsSelectedCount - Number;
		EndIf;
		
		TreeRow = Context.TreeRows[IndexInArray]; // See SettingsFormCollectionItem
		DCItem = DCNode.GetObjectByID(TreeRow.Id);
		
		IndexInTree = ParentRows.IndexOf(TreeRow);
		WhereRowWillBe = IndexInTree + Context.Direction;
		If WhereRowWillBe < 0 Then // Moving rows "to the end".
			ParentRows.Move(IndexInTree, UpperRowsBound - IndexInTree);
			DCParentRows.Move(DCItem, UpperRowsBound - IndexInTree);
		ElsIf WhereRowWillBe > UpperRowsBound Then // Moving rows "to the beginning".
			ParentRows.Move(IndexInTree, -IndexInTree);
			DCParentRows.Move(DCItem, -IndexInTree);
		Else
			ParentRows.Move(IndexInTree, Context.Direction);
			DCParentRows.Move(DCItem, Context.Direction);
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

// Parameters:
//  Context - See NewContext
//
&AtClient
Procedure MoveToHierarchy(Context)
	
	If Context.CurrentParent = Undefined Then 
		Return;
	EndIf;
	
	If Context.Direction > 0 Then 
		
		Rows = Context.CurrentParent.GetItems();
		IndexOf = Rows.IndexOf(Context.CurrentRow) - 1;
		NewParent = ?(IndexOf < 0, Undefined, Rows.Get(IndexOf));
		
	Else
		NewParent = GetParent(Context.NameOfTable, Context.CurrentParent);
	EndIf;
	
	If NewParent = Undefined
		Or NewParent.Type = "DataCompositionTable"
		Or NewParent.Type = "DataCompositionChart" Then 
		
		Return;
	EndIf;
	
	If Context.Direction > 0 Then 
		IndexOf = NewParent.GetItems().Count();
	Else
		IndexOf = NewParent.GetItems().IndexOf(Context.CurrentParent) + 1;
	EndIf;
	
	If IndexOf < 0 Then 
		IndexOf = 0;
	EndIf;
	
	Result = MoveOptionStructureItems(Context.CurrentRow, NewParent,, IndexOf, IndexOf);
	
	Items.OptionStructure.Expand(NewParent.GetID(), True);
	Items.OptionStructure.CurrentRow = Result.String.GetID();
	
	DetermineIfModified();
	
EndProcedure

&AtClient
Function TheseAreSubordinateElements(ParentElementOfTree, TreeItem)
	ParentItem = TreeItem;
	While ParentItem <> Undefined Do
		If ParentElementOfTree = ParentItem Then
			Return True;
		EndIf;
		ParentItem = ParentItem.GetParent();
	EndDo;
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client - Fields tables (universal entry points).

&AtClient
Procedure SelectTheDisplayModeForRows(PropertiesOfSettingsElements, CollectionName, ShowCheckBoxesModes = False, CurrentDisplayMode = Undefined)
	
	AvailableDisplayModes = AvailableDisplayModes(ShowCheckBoxesModes);
	ViewMode = AvailableDisplayModes.FindByValue(CurrentDisplayMode);
	
	If ViewMode = Undefined Then
		Return;
	EndIf;
	
	AvailableImages = AvailableImagesOfDisplayModes();
	DisplayModePicture = AvailableImages[ViewMode.Value];
	
	For Each PropertiesOfTheSettingsElement In PropertiesOfSettingsElements Do 
		
		String = ThisObject[CollectionName].FindByID(PropertiesOfTheSettingsElement.RowID); // See SettingsFormCollectionItem
		SettingsItem = PropertiesOfTheSettingsElement.SettingsItem;
		
		If String <> Undefined And SettingsItem <> Undefined Then
			SetDisplayMode(CollectionName, String, SettingsItem, DisplayModePicture);
		EndIf;
		
	EndDo;
	
	DetermineIfModified();
	
EndProcedure

&AtClient
Procedure SelectTheDisplayModeForTheLine(SettingsNodeFilters, CollectionName, RowID, ShowInputModes, ShowCheckBoxesModes, CurrentDisplayMode = Undefined)
	
	Context = New Structure("SettingsNodeFilters, CollectionName, RowID", SettingsNodeFilters, CollectionName, RowID);
	Handler = New NotifyDescription("AfterSelectingTheLineDisplayMode", ThisObject, Context);
	
	AvailableDisplayModes = AvailableDisplayModes(ShowCheckBoxesModes);
	
	If CurrentDisplayMode = Undefined Then
		ShowChooseFromMenu(Handler, AvailableDisplayModes);
	Else
		ViewMode = AvailableDisplayModes.FindByValue(CurrentDisplayMode);
		ExecuteNotifyProcessing(Handler, ViewMode);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterSelectingTheLineDisplayMode(ViewMode, Context) Export
	
	If ViewMode = Undefined Then
		Return;
	EndIf;
	
	String = ThisObject[Context.CollectionName].FindByID(Context.RowID); // See SettingsFormCollectionItem
	If String = Undefined Then
		Return;
	EndIf;
	
	SettingItem = Context.SettingsNodeFilters.GetObjectByID(String.Id);
	If SettingItem = Undefined Then
		Return;
	EndIf;
	
	AvailableImages = AvailableImagesOfDisplayModes();
	DisplayModePicture = AvailableImages[ViewMode.Value];
	
	SetDisplayMode(Context.CollectionName, String, SettingItem, DisplayModePicture);
	DetermineIfModified();
	
EndProcedure

&AtClient
Function AvailableDisplayModes(ShowCheckBoxesModes)
	
	AvailableDisplayModes = New ValueList;
	AvailableDisplayModes.Add("ShowInReportHeader", NStr("en = 'In report header';"), , PictureLib.QuickAccess);
	
	If ShowCheckBoxesModes Then
		AvailableDisplayModes.Add("ShowOnlyCheckBoxInReportHeader", NStr("en = 'Only check box in report header';"), , PictureLib.QuickAccessWithFlag);
	EndIf;
	
	AvailableDisplayModes.Add("ShowInReportSettings", NStr("en = 'In report settings';"), , PictureLib.Attribute);
	
	If ShowCheckBoxesModes Then
		AvailableDisplayModes.Add("ShowOnlyCheckBoxInReportSettings", NStr("en = 'Only check box in report settings';"), , PictureLib.NormalAccessWithCheckBox);
	EndIf;
	
	AvailableDisplayModes.Add("NotShow", NStr("en = 'Hide';"), , PictureLib.GrayCross);
	
	Return AvailableDisplayModes;
	
EndFunction

&AtClient
Function AvailableImagesOfDisplayModes()
	
	AvailableImages = New Map;
	AvailableImages.Insert("ShowOnlyCheckBoxInReportHeader", 1);
	AvailableImages.Insert("ShowInReportHeader", 2);
	AvailableImages.Insert("ShowOnlyCheckBoxInReportSettings", 3);
	AvailableImages.Insert("ShowInReportSettings", 4);
	AvailableImages.Insert("NotShow", 5);
	
	Return AvailableImages;
	
EndFunction

// Parameters:
//  CollectionName - String
//  String - See SettingsFormCollectionItem
//  SettingItem - See SettingItem
//  DisplayModePicture - Undefined
//                            - Number
//
&AtClient
Procedure SetDisplayMode(CollectionName, String, SettingItem, DisplayModePicture = Undefined)
	If DisplayModePicture = Undefined Then
		DisplayModePicture = String.DisplayModePicture;
	Else
		String.DisplayModePicture = DisplayModePicture;
	EndIf;
	
	If DisplayModePicture = 1 Or DisplayModePicture = 2 Then
		SettingItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess;
	ElsIf DisplayModePicture = 3 Or DisplayModePicture = 4 Then
		SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	Else
		SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
	If CollectionName = "Filters" And Not String.IsParameter Then
		If DisplayModePicture = 1 Or DisplayModePicture = 3 Then
			// If "UserSettingPresentation" is assigned a value, "Presentation" behaves as a switch,
			// but it can also be used for importing to a spreadsheet.
			// 
			SettingItem.Presentation = String.Title;
		Else
			SettingItem.Presentation = "";
		EndIf;
		
		If Not String.IsPredefinedTitle Then
			SettingItem.UserSettingPresentation = String.Title;
		EndIf;
	ElsIf CollectionName = "Appearance" Then
		// CA feature: UserSettingPresentation can be cleared after GetSettings().
		If String.IsPredefinedTitle Then
			If DisplayModePicture = 1 Or DisplayModePicture = 3 Then
				// If "UserSettingPresentation" is assigned a value, "Presentation" behaves as a switch,
				// but it can also be used for importing to a spreadsheet.
				// 
				SettingItem.Presentation = String.Title;
			Else
				SettingItem.Presentation = "";
			EndIf;
		Else
			// If "UserSettingPresentation" is assigned a value, "Presentation" behaves as a switch,
			// but it can also be used for importing to a spreadsheet.
			// 
			SettingItem.Presentation = String.Title;
		EndIf;
	EndIf;
	
	If SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
		SettingItem.UserSettingID = "";
	ElsIf Not ValueIsFilled(SettingItem.UserSettingID) Then
		SettingItem.UserSettingID = New UUID;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function SettingItemDisplayModePicture(SettingItem)
	DisplayModePicture = 5;
	
	If ValueIsFilled(SettingItem.UserSettingID) Then
		If SettingItem.ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue")
				Or TypeOf(SettingItem) = Type("DataCompositionConditionalAppearanceItem") Then 
				DisplayModePicture = 2;
			Else
				DisplayModePicture = ?(ValueIsFilled(SettingItem.Presentation), 1, 2);
			EndIf;
		ElsIf SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Normal Then
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue")
				Or TypeOf(SettingItem) = Type("DataCompositionConditionalAppearanceItem") Then 
				DisplayModePicture = 4;
			Else
				DisplayModePicture = ?(ValueIsFilled(SettingItem.Presentation), 3, 4);
			EndIf;
		EndIf;
	EndIf;
	
	Return DisplayModePicture;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Client - fields tables (functional part).

// Parameters:
//  SettingsNode - DataCompositionSettings
//               - DataCompositionNestedObjectSettings
//               - DataCompositionSettingStructure
//               - DataCompositionChart
//               - DataCompositionOrder
//               - DataCompositionGroup
//               - DataCompositionTableGroup
//               - DataCompositionChartGroup
//               - DataCompositionConditionalAppearance
//               - DataCompositionSelectedFieldGroup
//               - DataCompositionFilterItemGroup
//               - DataCompositionFilterItem
//               - DataCompositionConditionalAppearanceItem
//               - DataCompositionOutputParameterValues
//               - DataCompositionSettingsParameterValue
//               - DataCompositionFilter
//               - DataCompositionSelectedFields
//               - DataCompositionTable
//               - Undefined
//  SettingItem - See SettingsFormCollectionItem
//
// Returns:
//   - DataCompositionSettings
//   - DataCompositionNestedObjectSettings
//   - DataCompositionSettingStructure
//   - DataCompositionGroup
//   - DataCompositionTable
//   - DataCompositionTableStructureItemCollection
//   - DataCompositionTableGroup
//   - DataCompositionChart
//   - DataCompositionChartStructureItemCollection
//   - DataCompositionChartGroup
//   - DataCompositionFilter
//   - DataCompositionFilterItem
//   - DataCompositionFilterItemGroup
//   - DataCompositionConditionalAppearanceItem
//   - DataCompositionOutputParameterValues
//   - DataCompositionSettingsParameterValue
//   - DataCompositionSelectedFields
//   - DataCompositionSelectedFieldGroup
//   - DataCompositionOrder
//   - DataCompositionConditionalAppearance
//   - DataCompositionConditionalAppearanceItemCollection
//   - Undefined
//
&AtClientAtServerNoContext
Function SettingItem(Val SettingsNode, Val SettingItem)
	Result = Undefined;
	
	If SettingItem <> Undefined
		And TypeOf(SettingItem.Id) = Type("DataCompositionID") Then
		
		Result = SettingsNode.GetObjectByID(SettingItem.Id);
	EndIf;
	
	If TypeOf(Result) = Type("DataCompositionNestedObjectSettings") Then
		Result = SettingItem.Settings;
	EndIf;
	
	Return Result;
EndFunction

&AtClientAtServerNoContext
Function SettingsItems(Val StructureItemProperty, Val SettingItem = Undefined, Val CollectionName = Undefined)
	If SettingItem = Undefined Then
		SettingItem = StructureItemProperty;
	EndIf;
	
	ObjectType = TypeOf(SettingItem);
	
	If CollectionName <> Undefined Then 
		CollectionName = StrReplace(CollectionName, "Table", "");
		CollectionName = StrReplace(CollectionName, "Chart", "");
		
		If ObjectType = Type("DataCompositionTable")
			And (CollectionName = "Rows" Or CollectionName = "Columns")
			Or ObjectType = Type("DataCompositionChart")
			And (CollectionName = "Series" Or CollectionName = "Points") Then 
			
			Return SettingItem[CollectionName];
		EndIf;
	EndIf;
	
	If ObjectType = Type("DataCompositionSettings")
		Or ObjectType = Type("DataCompositionGroup")
		Or ObjectType = Type("DataCompositionTableGroup")
		Or ObjectType = Type("DataCompositionChartGroup") Then
		
		Return SettingItem.Structure;
	ElsIf ObjectType = Type("DataCompositionSettingStructureItemCollection")
		Or ObjectType = Type("DataCompositionTableStructureItemCollection")
		Or ObjectType = Type("DataCompositionChartStructureItemCollection") Then
		
		Return SettingItem;
	ElsIf ObjectType = Type("DataCompositionNestedObjectSettings") Then 
		
		Return SettingItem.Settings.Structure;
	EndIf;
	
	Return SettingItem.Items;
EndFunction

&AtClient
Function SettingsCollectionNameByID(Id)
	CollectionName = Undefined;
	
	Path = Upper(Id);
	If StrFind(Path, "SERIES") > 0 Then 
		CollectionName = "Series";
	ElsIf StrFind(Path, "POINT") > 0 Then 
		CollectionName = "Points";
	ElsIf StrFind(Path, "ROW") > 0 Then 
		CollectionName = "Rows";
	ElsIf StrFind(Path, "COLUMN") > 0 Then 
		CollectionName = "Columns";
	EndIf;
	
	Return CollectionName;
EndFunction

&AtClient
Function GetSettingItemParent(Val StructureItemProperty, Val SettingItem)
	Parent = Undefined;
	
	ElementType = TypeOf(SettingItem);
	If SettingItem <> Undefined
		And ElementType <> Type("DataCompositionGroupField")
		And ElementType <> Type("DataCompositionAutoGroupField")
		And ElementType <> Type("DataCompositionAutoOrderItem")
		And ElementType <> Type("DataCompositionOrderItem")
		And ElementType <> Type("DataCompositionConditionalAppearanceItem")
		And ElementType <> Type("DataCompositionTableStructureItemCollection") Then 
		Parent = SettingItem.Parent;
	EndIf;
	
	If Parent = Undefined Then 
		Parent = StructureItemProperty;
	EndIf;
	
	Return Parent;
EndFunction

&AtClientAtServerNoContext
Function GetItems(Val Tree, Val String)
	If String = Undefined Then
		String = Tree;
	EndIf;
	Return String.GetItems();
EndFunction

&AtClient
Function GetParent(Val CollectionName, Val String = Undefined)
	Parent = Undefined;
	
	If String <> Undefined Then
		Parent = String.GetParent();
	EndIf;
	
	If Parent = Undefined Then
		Parent = DefaultRootRow(CollectionName);
	EndIf;
	
	If Parent = Undefined Then
		Parent = ThisObject[CollectionName];
	EndIf;
	
	Return Parent;
EndFunction

&AtClient
Function DefaultRootRow(Val CollectionName)
	RootRow = Undefined;
	
	If CollectionName = "SelectedFields" Then
		RootRow = SelectedFields.GetItems()[0];
	ElsIf CollectionName = "Sort" Then
		RootRow = Sort.GetItems()[0];
	ElsIf CollectionName = "OptionStructure" Then
		RootRow = OptionStructure.GetItems()[0];
	ElsIf CollectionName = "Parameters" Then
		If Not SettingsStructureItemChangeMode Then
			RootRow = Filters.GetItems()[0];
		EndIf;
	ElsIf CollectionName = "Filters" Then
		If SettingsStructureItemChangeMode Then
			RootRow = Filters.GetItems()[0];
		Else
			RootRow = Filters.GetItems()[1];
		EndIf;
	ElsIf CollectionName = "Appearance" Then
		If Not SettingsStructureItemChangeMode Then 
			RootRow = Appearance;
		EndIf;
	EndIf;
	
	Return RootRow;
EndFunction

&AtClient
Procedure SelectField(CollectionName, Handler, Field = Undefined, SettingsNodeID = Undefined)
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("ReportSettings", ReportSettings);
	ChoiceParameters.Insert("SettingsComposer", Report.SettingsComposer);
	ChoiceParameters.Insert("Mode", CollectionName);
	ChoiceParameters.Insert("DCField", Field);
	ChoiceParameters.Insert("SettingsStructureItemID", 
		?(SettingsNodeID = Undefined, SettingsStructureItemID, SettingsNodeID));
	
	OpenForm(
		"SettingsStorage.ReportsVariantsStorage.Form.SelectReportField",
		ChoiceParameters, ThisObject, UUID,,, Handler, FormWindowOpeningMode.LockOwnerWindow);
EndProcedure

&AtClient
Procedure UpdateOptionStructureItemTitle(String)
	StructureItemProperty = SettingsStructureItemProperty(Report.SettingsComposer, "Structure");
	
	SettingItem = SettingItem(StructureItemProperty, String);
	If SettingItem = Undefined Then
		Return;
	EndIf;
	
	ParameterValue = SettingItem.OutputParameters.FindParameterValue(New DataCompositionParameter("TitleOutput"));
	If ParameterValue <> Undefined Then
		ParameterValue.Use = True;
		If ValueIsFilled(String.Title) Then
			ParameterValue.Value = DataCompositionTextOutputType.Output;
		Else
			ParameterValue.Value = DataCompositionTextOutputType.DontOutput;
		EndIf;
	EndIf;
	
	ParameterValue = SettingItem.OutputParameters.FindParameterValue(New DataCompositionParameter("Title"));
	If ParameterValue <> Undefined Then
		ParameterValue.Use = True;
		ParameterValue.Value = String.Title;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client or server.

&AtClientAtServerNoContext
Function ArraySort(SourceArray, Direction = Undefined)
	If Direction = Undefined Then 
		Direction = SortDirection.Asc;
	EndIf;
	
	List = New ValueList;
	List.LoadValues(SourceArray);
	List.SortByValue(Direction);
	
	Return List.UnloadValues();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Procedure UpdateForm(ParametersOfUpdate)
	ContainsNestedReports = False;
	ContainsNestedFilters = False;
	ContainsNestedFieldsOrSorting = False;
	ContainsNestedConditionalAppearance = False;
	ContainsUserStructureItems = False;
	
	ImportSettingsToComposer(ParametersOfUpdate);
	
	If ExtendedMode = 0 Then 
		ReportsServer.UpdateSettingsFormItems(ThisObject, Items.IsMain, ParametersOfUpdate);
	EndIf;
	
	UpdateSettingsFormCollections();
	
	SetChartType();
	UpdateFormItemsProperties();
EndProcedure

&AtServer
Procedure UpdateSettingsFormCollections()
	// Clear settings.
	GroupingComposition.GetItems().Clear();
	Filters.GetItems().Clear();
	SelectedFields.GetItems().Clear();
	Sort.GetItems().Clear();
	Appearance.GetItems().Clear();
	OptionStructure.GetItems().Clear();
	
	SetChartType();
	
	// Update settings.
	UpdateGroupFields();
	UpdateDataParameters();
	UpdateFilters();
	UpdateSelectedFields();
	UpdateSorting();
	UpdateAppearance();
	UpdateStructure();
	
	// Searching for items marked for deletion.
	MarkedForDeletion.Clear();
	FindFieldsMarkedForDeletion();
EndProcedure

&AtServer
Procedure SetChartType()
	Items.CurrentChartType.Visible = False;
	
	If SettingsStructureItemType <> "DataCompositionChart" Then
		Return;
	EndIf;
	
	Items.CurrentChartType.TypeRestriction = New TypeDescription("ChartType");
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(SettingsStructureItemID);
	If TypeOf(StructureItem) = Type("DataCompositionNestedObjectSettings") Then
		StructureItem = StructureItem.Settings;
	EndIf;
	
	SettingItem = StructureItem.OutputParameters.FindParameterValue(New DataCompositionParameter("ChartType"));
	If SettingItem <> Undefined Then
		CurrentChartType = SettingItem.Value;
	EndIf;
	
	Items.CurrentChartType.Visible = (SettingItem <> Undefined);
EndProcedure

&AtServer
Procedure UpdateFormItemsProperties()
	SettingsComposer = Report.SettingsComposer;
	
#Region CommonItemsPropertiesFlags
	
	IsExtendedMode = Boolean(ExtendedMode);
	DisplayInformation1 = IsExtendedMode And Not SettingsStructureItemChangeMode;
	
#EndRegion
	
#Region SimpleEditModeItemsProperties
	
	Items.IsMain.Visible = Not IsExtendedMode;
	Items.More.Visible = Not IsExtendedMode And Not IsMobileClient;
	
	Items.TitleOutput.Visible = Not IsExtendedMode;
	Items.OutputFilters.Visible = Not IsExtendedMode;
	
#EndRegion
	
#Region GroupContentPageItemsProperties
	
	DisplayGroupContent = (IsExtendedMode
		And SettingsStructureItemChangeMode
		And SettingsStructureItemType <> "DataCompositionChart");
	
	Items.GroupingContentPage.Visible = DisplayGroupContent;
	Items.GroupContentCommands.Visible = DisplayGroupContent;
	Items.GroupingComposition.Visible = DisplayGroupContent;
	
#EndRegion
	
#Region FiltersPageItemsProperties
	
	DisplayFilters = (IsExtendedMode
		And SettingsStructureItemType <> "DataCompositionChart");
	
	If IsExtendedMode Then
		Items.FiltersPage.Title = NStr("en = 'Filters';");
	Else
		Items.FiltersPage.Title = NStr("en = 'Main';");
		If IsMobileClient Then
			GroupUserSettingsBasic = Items.IsMain.ChildItems.Find("SettingsComposerUserSettingsBasic");
			If GroupUserSettingsBasic <> Undefined Then
				If Items.IsMain.ChildItems.Count() = 1
					And Items.IsMain.Type = FormGroupType.Pages Then // FormGroup
					Items.IsMain.PagesRepresentation = FormPagesRepresentation.None;
				Else
					For Each SubordinateItem In Items.IsMain.ChildItems Do
						If SubordinateItem = GroupUserSettingsBasic Then
							Continue;
						EndIf;
						For Each SubordinateItem1 In SubordinateItem.ChildItems Do
							If TypeOf(SubordinateItem1) = Type("FormTable") Then
								SubordinateItem1.CommandBarLocation = FormItemCommandBarLabelLocation.None;
								SubordinateItem1.Header = False;
							EndIf;
						EndDo;
					EndDo;
				EndIf;
				If GroupUserSettingsBasic.ChildItems.Find(GroupUserSettingsBasic.Name+"1") = Undefined Then
					GroupUserSettingsBasic1 = Items.Add(GroupUserSettingsBasic.Name+"1", Type("FormGroup"), GroupUserSettingsBasic);
					GroupUserSettingsBasic1.Type = FormGroupType.UsualGroup; // FormGroup
					GroupUserSettingsBasic1.ShowTitle = False;
					GroupUserSettingsBasic1.HorizontalSpacing = FormItemSpacing.None;
					GroupUserSettingsBasic1.VerticalSpacing = FormItemSpacing.None;
					Counter = 0;
					While Counter < GroupUserSettingsBasic.ChildItems.Count() Do
						SubordinateItem = GroupUserSettingsBasic.ChildItems[Counter];
						If SubordinateItem = GroupUserSettingsBasic1 Then
							Counter = Counter + 1;
						Else
							If TypeOf(SubordinateItem) = Type("FormGroup") Then
								SubordinateItem.United = False;
							EndIf;
							Items.Move(SubordinateItem, GroupUserSettingsBasic1);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Items.Filters.Visible = DisplayFilters;
	Items.HasNestedFiltersGroup.Visible = DisplayFilters
		And ContainsNestedFilters
		And DisplayInformation1;
	
	Items.FiltersGoToSettingsForTechnician.Visible = IsExtendedMode
		And Not SettingsStructureItemChangeMode;
	
#EndRegion
	
#Region FieldsAndSortingPageItemsProperties
	
	StructureItemProperty = SettingsStructureItemProperty(
		SettingsComposer, "Selection", SettingsStructureItemID, ExtendedMode);
	DisplaySelectedFields =
		StructureItemProperty <> Undefined
		And (ValueIsFilled(StructureItemProperty.UserSettingID) Or IsExtendedMode);
	
	StructureItemProperty = SettingsStructureItemProperty(
		SettingsComposer, "Order", SettingsStructureItemID, ExtendedMode);
	DisplaySorting =
		SettingsStructureItemType <> "DataCompositionChart"
		And StructureItemProperty <> Undefined
		And (ValueIsFilled(StructureItemProperty.UserSettingID) Or IsExtendedMode);
	
	If DisplaySelectedFields And DisplaySorting Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Fields and sorts';");
	ElsIf DisplaySelectedFields Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Fields';");
	ElsIf DisplaySorting Then
		Items.SelectedFieldsAndSortingsPage.Title = NStr("en = 'Sorts';");
	EndIf;
	
	Items.SelectedFields.Visible = DisplaySelectedFields;
	Items.SelectedFieldsCommands_AddDelete.Visible = DisplaySelectedFields And IsExtendedMode;
	Items.SelectedFieldsCommands_AddDelete1.Visible = DisplaySelectedFields And IsExtendedMode;
	Items.SelectedFieldsCommands_Groups.Visible = DisplaySelectedFields And IsExtendedMode;
	Items.SelectedFieldsCommands_Groups1.Visible = DisplaySelectedFields And IsExtendedMode;
	
	Items.FieldsAndSortingCommands.Visible = DisplaySelectedFields And DisplaySorting;
	
	Items.Sort.Visible = DisplaySorting;
	Items.SortingCommands_AddDelete.Visible = DisplaySorting And IsExtendedMode;
	Items.SortingCommands_AddDelete1.Visible = DisplaySorting And IsExtendedMode;
	
	Items.HasNestedFieldsOrSortingGroup.Visible = ContainsNestedFieldsOrSorting And DisplayInformation1;
	
	Items.SelectedFieldsGoToSettingsForTechnician.Visible = IsExtendedMode
		And Not SettingsStructureItemChangeMode;
	
#EndRegion
	
#Region AppearancePageItemsProperties
	
	DisplayAppearance = IsExtendedMode;
	Items.Appearance.Visible = DisplayAppearance;
	Items.HasNestedAppearanceGroup.Visible = DisplayAppearance
		And ContainsNestedConditionalAppearance
		And DisplayInformation1;
	
	Items.AppearanceGoToSettingsForTechnician.Visible = IsExtendedMode
		And Not SettingsStructureItemChangeMode;
	
#EndRegion
	
#Region OptionStructurePageItemsProperties
	
	DisplayOptionStructure =
		ReportSettings.EditStructureAllowed
		And Not SettingsStructureItemChangeMode
		And (ContainsUserStructureItems Or IsExtendedMode);
	
	Items.OptionStructurePage.Visible = DisplayOptionStructure;
	
	Items.OptionStructureCommands_Add.Visible = IsExtendedMode;
	Items.OptionStructureCommands_Add1.Visible = IsExtendedMode;
	Items.OptionStructureCommands_Change.Visible = IsExtendedMode;
	Items.OptionStructureCommands_Change1.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveHierarchically.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveHierarchically1.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveInsideParent.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveInsideParent1.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveInHierarchy.Visible = IsExtendedMode;
	Items.OptionStructureCommands_MoveInHierarchy1.Visible = IsExtendedMode;
	
	Items.OptionStructure.ChangeRowSet = IsExtendedMode;
	Items.OptionStructure.ChangeRowOrder = IsExtendedMode;
	Items.OptionStructure.EnableStartDrag = IsExtendedMode;
	Items.OptionStructure.EnableDrag = IsExtendedMode;
	Items.OptionStructure.Header = IsExtendedMode;
	
	Items.OptionStructureTitle.Visible = IsExtendedMode;
	
	Items.OptionStructureContainsFilters.Visible = IsExtendedMode;
	Items.OptionStructureContainsFieldsOrOrders.Visible = IsExtendedMode;
	Items.OptionStructureContainsConditionalAppearance.Visible = IsExtendedMode;
	
	Items.OptionStructureGoToSettingsForTechnician.Visible = IsExtendedMode
		And Not SettingsStructureItemChangeMode;
	
#EndRegion
	
#Region CommonItemsProperties
	
	If TypeOf(CommonClientServer.StructureProperty(Parameters, "DisplayPages", Undefined)) = Type("Boolean") Then
		DisplayPages = (Parameters.DisplayPages <> False);
	ElsIf Not IsExtendedMode Then 
		DisplayPages = False;
	Else
		DisplayPages =
			DisplayGroupContent
			Or DisplayFilters
			Or DisplaySelectedFields
			Or DisplaySorting
			Or DisplayAppearance
			Or DisplayOptionStructure;
	EndIf;
	
	If DisplayPages Then 
		Items.SettingsPages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	Else
		Items.SettingsPages.CurrentPage = Items.FiltersPage;
		Items.SettingsPages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	Items.HasNestedReportsGroup.Visible = ContainsNestedReports And DisplayInformation1;
	Items.HasNonexistentFieldsGroup.Visible =  MarkedForDeletion.Count() > 0 And DisplayInformation1;
	
	Items.ExtendedMode.Visible = ReportSettings.EditOptionsAllowed And Not SettingsStructureItemChangeMode;
	Items.EditFiltersConditions.Visible = AllowEditingFiltersConditions();
	
	If SettingsStructureItemChangeMode Then
		Items.GenerateAndClose.Title = NStr("en = 'Finish editing';");
		Items.Close.Title = NStr("en = 'Cancel';");
	Else
		Items.GenerateAndClose.Title = NStr("en = 'Close and generate';");
		Items.Close.Title = NStr("en = 'Close';");
	EndIf;
	
	CountOfAvailableSettings = ReportsServer.CountOfAvailableSettings(Report.SettingsComposer);
	Items.GenerateAndClose.Visible = CountOfAvailableSettings.Total > 0 Or DisplayPages;
	If IsMobileClient Then
		Items.ExtendedMode.Visible = False;
		Items.SetupGroup.Visible = False;
		Items.HasNestedReportsGroup.Visible = True;
		Items.HasNestedReportsTooltip.Title = NStr(
			"en = 'Advanced setup mode is unavailable in a mobile client';");
		Items.GenerateAndClose.Representation = ButtonRepresentation.PictureAndText;
		Items.Close.Visible = False;
		Items.Help.Visible = False;
	EndIf;
	
#EndRegion
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Procedure DefineBehaviorInMobileClient()
	IsMobileClient = Common.IsMobileClient();
	If Not IsMobileClient Then 
		Return;
	EndIf;
	
	CommandBarLocation = FormCommandBarLabelLocation.Auto;
	Items.GenerateAndClose.Representation = ButtonRepresentation.Picture;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	ConditionalAppearance.Items.Clear();
	
#Region ConditionalTableAppearanceOfGroupContentForm
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupingComposition.ShowAdditionType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupingCompositionGroupType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupingComposition.ShowAdditionType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupingCompositionAdditionType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupingComposition.Field");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Undefined;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupingCompositionGroupType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("GroupingComposition.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("GroupingComposition.Title"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.GroupingCompositionField.Name);
	
#EndRegion
	
#Region ConditionalTableAppearanceOfFiltersForm
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersDisplayModePicture.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersRightValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUse.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersDisplayModePicture.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersDisplayModePicture.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersRightValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsPeriod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.DisplayUsage");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("ReadOnly", True);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUse.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersDisplayModePicture.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersDisplayModePicture.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersComparisonType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersRightValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Filters.GroupType"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsUUID");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersRightValue.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Filters.Title"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersParameter.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersGroupType.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersField.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.ValuePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Filters.ValuePresentation"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersValue.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersRightValue.Name);
	
	//
	ProhibitedCellTextColor = Metadata.StyleItems.InaccessibleCellTextColor;
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Filters.IsPredefinedTitle");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", ProhibitedCellTextColor.Value);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FiltersUserSettingPresentation.Name);
	
#EndRegion
	
#Region ConditionalTableAppearanceOfSelectedFieldsForm
	

	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SelectedFields.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SelectedFieldsUse.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SelectedFields.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("SelectedFields.Title"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SelectedFieldsField.Name);
	
#EndRegion
	
#Region ConditionalTableAppearanceOfSortingForm
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Sort.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortUse.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortOrderType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Sort.IsAutoField");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortOrderType.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Sort.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("Sort.Title"));
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.SortField.Name);
	
#EndRegion
	
#Region ConditionalTableAppearanceOfAppearanceForm
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AppearanceTitle.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Appearance.IsOutputParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AppearanceAccessPictureIndex.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Appearance.IsOutputParameter");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Visible", False);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AppearanceUse.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AppearanceTitle.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AppearanceAccessPictureIndex.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Appearance.IsSection");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
#EndRegion
	
#Region ConditionalTableAppearanceOfOptionStructureForm
	
	FontImportantLabel = Metadata.StyleItems.ImportantLabelFont.Value;
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.IsFolder");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Font", FontImportantLabel);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructurePresentation.Name);

	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.Title");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExtendedMode");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("OptionStructure.Title"));
	Item.Appearance.SetParameterValue("Font", FontImportantLabel);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructurePresentation.Name);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionStructure.AvailableFlag");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OptionStructureUse.Name);
	
#EndRegion
EndProcedure

&AtServer
Procedure ImportSettingsToComposer(ImportParameters)

	If Not ImportParameters.VariantModified Then
		ImportParameters.VariantModified = VariantModified;
	EndIf;
	If Not ImportParameters.UserSettingsModified Then
		ImportParameters.UserSettingsModified = UserSettingsModified;
	EndIf;
	ImportParameters.ReportObjectOrFullName = ReportSettings.FullName;
	
	ReportObject = FormAttributeToValue("Report");
	If ReportSettings.Events.BeforeFillQuickSettingsBar Then
		ReportObject.BeforeFillQuickSettingsBar(ThisObject, ImportParameters);
	EndIf;
	
	AvailableSettings = ReportsServer.AvailableSettings(ImportParameters, ReportSettings);
	
	UpdateOptionSettings = CommonClientServer.StructureProperty(ImportParameters, "UpdateOptionSettings", False);
	If UpdateOptionSettings Then
		AvailableSettings.Settings = Report.SettingsComposer.GetSettings();
		Report.SettingsComposer.LoadFixedSettings(New DataCompositionSettings);
		AvailableSettings.FixedSettings = Report.SettingsComposer.FixedSettings;
	EndIf;
	
	ReportsServer.ResetCustomSettings(AvailableSettings, ImportParameters);
	
	ReportsServer.FillinAdditionalProperties(ReportObject,
		AvailableSettings.Settings,
		CurrentVariantKey,
		ReportSettings.PredefinedOptionKey);
	
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		ReportObject.BeforeImportSettingsToComposer(
			ThisObject,
			ReportSettings.SchemaKey,
			CurrentVariantKey,
			AvailableSettings.Settings,
			AvailableSettings.UserSettings);
	EndIf;
	
	SettingsImported = ReportsClientServer.LoadSettings(
		Report.SettingsComposer,
		AvailableSettings.Settings,
		AvailableSettings.UserSettings,
		AvailableSettings.FixedSettings);
	
	// Fixed filters are set using the composer because it has the widest range of settings.
	// "BeforeImport" might be missing the parameters whose settings were not overridden.
	If SettingsImported
	   And ReportsOptions.ItIsAcceptableToSetContext(ThisObject)
	   And TypeOf(ParametersForm.Filter) = Type("Structure") Then
		
		ReportsServer.SetFixedFilters(ParametersForm.Filter, Report.SettingsComposer.Settings, ReportSettings);
	EndIf;
	
	If ParametersForm.Property("FixedSettings") Then 
		ParametersForm.FixedSettings = Report.SettingsComposer.FixedSettings;
	EndIf;
	
	ReportObject = FormAttributeToValue("Report");
	If ReportSettings.Events.AfterLoadSettingsInLinker Then
		ReportObject.AfterLoadSettingsInLinker(New Structure);
	EndIf;
	
	ReportsServer.SetAvailableValues(ReportObject, ThisObject);
	ReportsServer.InitializePredefinedOutputParameters(ReportSettings, AvailableSettings.Settings);
	
	If ImportParameters.FiltersConditions <> Undefined Then
		UserSettings = Report.SettingsComposer.UserSettings;
		For Each Condition In ImportParameters.FiltersConditions Do
			UserSettingItem = UserSettings.GetObjectByID(Condition.Key);
			If UserSettingItem <> Undefined Then 
				UserSettingItem.ComparisonType = Condition.Value;
			EndIf;
		EndDo;
	EndIf;
	
	InitializePredefinedOutputParametersAttributes();
	SettingsComposer = Report.SettingsComposer;
	
	ReportsServer.SetFiltersConditions(ImportParameters, SettingsComposer);
	
	If ImportParameters.VariantModified Then
		OptionChanged = True;
	EndIf;
	
	If ImportParameters.UserSettingsModified Then
		UserSettingsModified = True;
	EndIf;
EndProcedure

&AtServer
Procedure InitializePredefinedOutputParametersAttributes()
	PredefinedParameters = Report.SettingsComposer.Settings.OutputParameters.Items;
	
	Object = PredefinedParameters.Find("TITLE");
	TitleOutput = Object.Use;
	
	HeaderOutputField = Items.Find("TitleOutput");
	
	If HeaderOutputField <> Undefined Then 
		HeaderOutputField.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Show printing header: %1';"),
			?(ValueIsFilled(Object.Value), Object.Value, NStr("en = '<None>';")));
	EndIf;
	
	Object = PredefinedParameters.Find("DATAPARAMETERSOUTPUT");
	LinkedObject = PredefinedParameters.Find("FILTEROUTPUT");
	
	OutputFilters = (Object.Value <> DataCompositionTextOutputType.DontOutput
		Or LinkedObject.Value <> DataCompositionTextOutputType.DontOutput);
EndProcedure

&AtServer
Function FullAttributeName(Attribute)
	Return ?(IsBlankString(Attribute.Path), "", Attribute.Path + ".") + Attribute.Name;
EndFunction

&AtClientAtServerNoContext
Function TypesDetailsWithoutPrimitiveOnes(SourceDescriptionOfTypes)
	RemovedTypes = New Array;
	If SourceDescriptionOfTypes.ContainsType(Type("String")) Then
		RemovedTypes.Add(Type("String"));
	EndIf;
	If SourceDescriptionOfTypes.ContainsType(Type("Date")) Then
		RemovedTypes.Add(Type("Date"));
	EndIf;
	If SourceDescriptionOfTypes.ContainsType(Type("Number")) Then
		RemovedTypes.Add(Type("Number"));
	EndIf;
	If RemovedTypes.Count() = 0 Then
		Return SourceDescriptionOfTypes;
	EndIf;
	Return New TypeDescription(SourceDescriptionOfTypes, , RemovedTypes);
EndFunction

&AtClient
Procedure RegisterList(Item, SettingItem)
	Value = Undefined;
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		Value = SettingItem.Value;
	ElsIf TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
		Value = SettingItem.RightValue;
	EndIf;

	If TypeOf(Value) <> Type("ValueList") Then 
		Return;
	EndIf;
	
	IndexOf = SettingsComposer.UserSettings.Items.IndexOf(SettingItem);
	ListPath = PathToItemsData.ByIndex[IndexOf];
	If ListPath = Undefined Then 
		Return;
	EndIf;
	
	List = Items.Find(ListPath);
	If SettingItem.Use Then 
		List.TextColor = New Color;
	Else
		ClientParameter = StandardSubsystemsClient.ClientRunParameters();
		List.TextColor = ClientParameter.StyleItems.InaccessibleCellTextColor;
	EndIf;
EndProcedure

&AtServer
Function AllowEditingFiltersConditions()
	If Boolean(ExtendedMode) Then 
		Return False;
	EndIf;
	
	SettingsComposer = Report.SettingsComposer;
	
	UserSettings = SettingsComposer.UserSettings;
	For Each UserSettingItem In UserSettings.Items Do 
		SettingItem = ReportsClientServer.GetObjectByUserID(
			SettingsComposer.Settings,
			UserSettingItem.UserSettingID,,
			UserSettings);
		
		If TypeOf(SettingItem) <> Type("DataCompositionFilterItem")
			Or TypeOf(SettingItem.RightValue) = Type("StandardPeriod")
			Or SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then 
			Continue;
		EndIf;
		
		Return True;
	EndDo;
	
	Return False;
EndFunction

&AtClient
Procedure DetermineIfModified()
	UserSettingsModified = True;
	If ExtendedMode = 1 Then
		OptionChanged = True;
	EndIf;
EndProcedure

#EndRegion

#Region ProcessFieldsMarkedForDeletion

// Search for fields marked for deletion.

&AtServer
Procedure FindFieldsMarkedForDeletion(Val StructureItems = Undefined)
	If SettingsStructureItemChangeMode Then 
		Return;
	EndIf;
	
	Settings = Report.SettingsComposer.Settings;
	
	If StructureItems = Undefined Then 
		StructureItems = Settings.Structure;
		
		FindSelectedFieldsMarkedForDeletion(Settings);
		FindFilterFieldsMarkedForDeletion(Settings);
		FindOrderFieldsMarkedForDeletion(Settings);
		FindConditionalAppearanceItemsMarkedForDeletion(Settings);
	EndIf;
	
	For Each StructureItem In StructureItems Do 
		ElementType = TypeOf(StructureItem);
		If ElementType = Type("DataCompositionGroup")
			Or ElementType = Type("DataCompositionTableGroup")
			Or ElementType = Type("DataCompositionChartGroup") Then 
			
			FindSelectedFieldsMarkedForDeletion(Settings, StructureItem);
			FindFilterFieldsMarkedForDeletion(Settings, StructureItem);
			FindOrderFieldsMarkedForDeletion(Settings, StructureItem);
			FindConditionalAppearanceItemsMarkedForDeletion(Settings, StructureItem);
			FindGroupingFieldsMarkedForDeletion(Settings, StructureItem);
		EndIf;
		
		CollectionsNames = StructureItemCollectionsNames(StructureItem);
		For Each CollectionName In CollectionsNames Do 
			StructureItemCollection = SettingsItems(StructureItem,, CollectionName);
			FindFieldsMarkedForDeletion(StructureItemCollection);
		EndDo;
	EndDo;
	
	ProcessedItems = MarkedForDeletion.Unload();
	ProcessedItems.GroupBy("StructureItemID, ItemID, KeyStructureItemProperties");
	ProcessedItems.Sort("StructureItemID Desc, KeyStructureItemProperties, ItemID");
	
	MarkedForDeletion.Load(ProcessedItems);
EndProcedure

&AtServer
Procedure FindSelectedFieldsMarkedForDeletion(Settings, Val StructureItem = Undefined, Var_Group = Undefined)
	If StructureItem = Undefined Then 
		StructureItem = Settings;
	EndIf;
	
	StructureItemProperty = StructureItem.Selection;
	AvailableFields = StructureItemProperty.SelectionAvailableFields;
	AutoFieldType = Type("DataCompositionAutoSelectedField");
	GroupType = Type("DataCompositionSelectedFieldGroup");
	
	SettingsItems = ?(Var_Group = Undefined, StructureItemProperty.Items, Var_Group.Items);
	For Each SettingItem In SettingsItems Do 
		If TypeOf(SettingItem) = GroupType Then 
			FindSelectedFieldsMarkedForDeletion(Settings,  StructureItem, SettingItem);
			Continue;
		EndIf;
		
		If TypeOf(SettingItem) = AutoFieldType
			Or AvailableFields.FindField(SettingItem.Field) <> Undefined Then 
			Continue;
		EndIf;
		
		Record = MarkedForDeletion.Add();
		Record.StructureItemID = Settings.GetIDByObject(StructureItem);
		Record.ItemID = StructureItemProperty.GetIDByObject(SettingItem);
		Record.KeyStructureItemProperties = "Selection";
	EndDo;
EndProcedure

&AtServer
Procedure FindFilterFieldsMarkedForDeletion(Settings, Val StructureItem = Undefined, Var_Group = Undefined)
	If StructureItem = Undefined Then 
		StructureItem = Settings;
	EndIf;
	
	StructureItemProperty = StructureItem.Filter;
	AvailableFields = StructureItemProperty.FilterAvailableFields;
	GroupType = Type("DataCompositionFilterItemGroup");
	
	SettingsItems = ?(Var_Group = Undefined, StructureItemProperty.Items, Var_Group.Items);
	For Each SettingItem In SettingsItems Do 
		If TypeOf(SettingItem) = GroupType Then 
			FindFilterFieldsMarkedForDeletion(Settings,  StructureItem, SettingItem);
			Continue;
		EndIf;
		
		If TypeOf(SettingItem.LeftValue) <> Type("DataCompositionField")
			Or AvailableFields.FindField(SettingItem.LeftValue) <> Undefined Then 
			Continue;
		EndIf;
		
		Record = MarkedForDeletion.Add();
		Record.StructureItemID = Settings.GetIDByObject(StructureItem);
		Record.ItemID = StructureItemProperty.GetIDByObject(SettingItem);
		Record.KeyStructureItemProperties = "Filter";
	EndDo;
EndProcedure

&AtServer
Procedure FindOrderFieldsMarkedForDeletion(Settings, Val StructureItem = Undefined)
	If StructureItem = Undefined Then 
		StructureItem = Settings;
	EndIf;
	
	StructureItemProperty = StructureItem.Order;
	AvailableFields = StructureItemProperty.OrderAvailableFields;
	AutoFieldType = Type("DataCompositionAutoOrderItem");
	
	For Each SettingItem In StructureItemProperty.Items Do 
		If TypeOf(SettingItem) = AutoFieldType
			Or AvailableFields.FindField(SettingItem.Field) <> Undefined Then 
			Continue;
		EndIf;
		
		Record = MarkedForDeletion.Add();
		Record.StructureItemID = Settings.GetIDByObject(StructureItem);
		Record.ItemID = StructureItemProperty.GetIDByObject(SettingItem);
		Record.KeyStructureItemProperties = "Order";
	EndDo;
EndProcedure

&AtServer
Procedure FindConditionalAppearanceItemsMarkedForDeletion(Settings, Val StructureItem = Undefined)
	If StructureItem = Undefined Then 
		StructureItem = Settings;
	EndIf;
	
	StructureItemProperty = StructureItem.ConditionalAppearance;
	
	For Each SettingItem In StructureItemProperty.Items Do 
		AvailableFields = SettingItem.Fields.AppearanceFieldsAvailableFields;
		For Each Item In SettingItem.Fields.Items Do 
			If AvailableFields.FindField(Item.Field) <> Undefined Then 
				Continue;
			EndIf;
			
			Record = MarkedForDeletion.Add();
			Record.StructureItemID = Settings.GetIDByObject(StructureItem);
			Record.ItemID = StructureItemProperty.GetIDByObject(SettingItem);
			Record.KeyStructureItemProperties = "ConditionalAppearance";
		EndDo;
		
		FindConditionalAppearanceFilterItemsMarkedForDeletion(Settings, StructureItem, SettingItem);
	EndDo;
EndProcedure

&AtServer
Procedure FindConditionalAppearanceFilterItemsMarkedForDeletion(Settings, StructureItem, AppearanceItem, Var_Group = Undefined)
	StructureItemProperty = StructureItem.ConditionalAppearance;
	
	AvailableFields = AppearanceItem.Filter.FilterAvailableFields;
	GroupType = Type("DataCompositionFilterItemGroup");
	
	SettingsItems = ?(Var_Group = Undefined, AppearanceItem.Filter.Items, Var_Group.Items);
	For Each SettingItem In SettingsItems Do 
		If TypeOf(SettingItem) = GroupType Then 
			FindConditionalAppearanceFilterItemsMarkedForDeletion(
				Settings,  StructureItem, AppearanceItem, SettingItem);
			Continue;
		EndIf;
		
		If AvailableFields.FindField(SettingItem.LeftValue) <> Undefined Then 
			Continue;
		EndIf;
		
		Record = MarkedForDeletion.Add();
		Record.StructureItemID = Settings.GetIDByObject(StructureItem);
		Record.ItemID = StructureItemProperty.GetIDByObject(AppearanceItem);
		Record.KeyStructureItemProperties = "ConditionalAppearance";
	EndDo;
EndProcedure

&AtServer
Procedure FindGroupingFieldsMarkedForDeletion(Settings, StructureItem)
	StructureItemProperty = StructureItem.GroupFields;
	AvailableFields = StructureItemProperty.GroupFieldsAvailableFields;
	AutoFieldType = Type("DataCompositionAutoGroupField");
	
	For Each SettingItem In StructureItemProperty.Items Do 
		If TypeOf(SettingItem) = AutoFieldType
			Or AvailableFields.FindField(SettingItem.Field) <> Undefined Then 
			Continue;
		EndIf;
		
		Record = MarkedForDeletion.Add();
		Record.StructureItemID = Settings.GetIDByObject(StructureItem);
		Record.ItemID = StructureItemProperty.GetIDByObject(SettingItem);
		Record.KeyStructureItemProperties = "GroupFields";
	EndDo;
EndProcedure

&AtServer
Function StructureItemCollectionsNames(Item)
	CollectionsNames = "";
	
	ElementType = TypeOf(Item);
	If ElementType = Type("DataCompositionGroup")
		Or ElementType = Type("DataCompositionTableGroup")
		Or ElementType = Type("DataCompositionChartGroup")
		Or ElementType = Type("DataCompositionNestedObjectSettings")
		Or ElementType = Type("DataCompositionSettingStructureItemCollection") Then 
		
		CollectionsNames = "Structure";
		
	ElsIf ElementType = Type("DataCompositionTable")
		Or ElementType = Type("DataCompositionTableStructureItemCollection") Then 
	
		CollectionsNames = "Rows,Columns";
		
	ElsIf ElementType = Type("DataCompositionChart")
		Or ElementType = Type("DataCompositionChartStructureItemCollection") Then 
		
		CollectionsNames = "Points,Series";
		
	EndIf;
	
	Return StrSplit(CollectionsNames, ",");
EndFunction

&AtServer
Function RepresentationOfACollectionOfAStructureElement(CollectionName)
	
	PresentationOfCollections = New Map;
	PresentationOfCollections.Insert("Structure", NStr("en = 'Structure';"));
	PresentationOfCollections.Insert("Rows", NStr("en = 'Rows';"));
	PresentationOfCollections.Insert("Columns", NStr("en = 'Columns';"));
	PresentationOfCollections.Insert("Points", NStr("en = 'Dots';"));
	PresentationOfCollections.Insert("Series", NStr("en = 'Series';"));
	
	Return PresentationOfCollections[CollectionName];
	
EndFunction

// Delete fields marked for deletion.

&AtClient
Procedure DeleteFiedsMarkedForDeletion()
	SettingsComposer = Report.SettingsComposer;
	
	For Each Record In MarkedForDeletion Do 
		StructureItemProperty = SettingsStructureItemProperty(
			SettingsComposer, Record.KeyStructureItemProperties, Record.StructureItemID, ExtendedMode);
		If StructureItemProperty = Undefined Then 
			Continue;
		EndIf;
		
		SettingItem = StructureItemProperty.GetObjectByID(Record.ItemID);
		If SettingItem = Undefined Then 
			Continue;
		EndIf;
		
		SettingItemParent = GetSettingItemParent(StructureItemProperty, SettingItem);
		SettingsItems = SettingsItems(StructureItemProperty, SettingItemParent);
		SettingsItems.Delete(SettingItem);
		
		If SettingsItems.Count() = 0
			And TypeOf(SettingItemParent) = Type("DataCompositionGroupFields") Then 
			
			StructureItem = SettingsComposer.Settings.GetObjectByID(Record.StructureItemID);
			If TypeOf(StructureItem) = Type("DataCompositionGroup") Then 
				StructureItems = StructureItem.Structure;
				If StructureItems.Count() = 0 Then 
					Continue;
				EndIf;
				
				IndexOf = StructureItems.Count() - 1;
				While IndexOf >= 0 Do 
					StructureItems.Delete(StructureItems[IndexOf]);
					IndexOf = IndexOf - 1;
				EndDo;
			Else // DataCompositionTableGroup or DataCompositionChartGroup.
				StructureItemParent = GetSettingItemParent(StructureItemProperty, StructureItem);
				CollectionName = SettingsCollectionNameByID(Record.StructureItemID);
				StructureItems = SettingsItems(StructureItemProperty, StructureItemParent, CollectionName);
				StructureItems.Delete(StructureItem);
			EndIf;
		EndIf;
	EndDo;
	
	DetermineIfModified();
EndProcedure

#EndRegion

// ACC:568-on Adjust code (fixes typifying issue).

// Parameters:
//  Collection - FormDataTree
//
// Returns:
//  FormDataTreeItem:
//    * Id - DataCompositionID
//    * Use - Boolean
//    * DisplayUsage - Boolean
//    * UserSettingPresentation - String
//    * ComparisonType - DataCompositionComparisonType
//    * Value - Undefined
//    * ValuePresentation - String
//    * ValueType - TypeDescription
//    * AvailableValues - ValueList
//    * ValueListAllowed - Boolean
//    * DisplayModePicture - Number
//    * Title - String
//    * IsPredefinedTitle - Boolean
//    * IsSection - Boolean
//    * IsFolder - Boolean
//    * IsParameter - Boolean
//    * IsPeriod - Boolean
//    * Picture - Number
//    * ChoiceForm - String
//    * ChoiceFoldersAndItems - FoldersAndItemsUse
//    * AvailableCompareTypes - ValueList
//    * Parameter - DataCompositionParameter
//    * LeftValue - DataCompositionField
//    * RightValue - Undefined
//    * DeletionMark - Boolean
//    * IsUUID - Boolean
//
&AtClientAtServerNoContext
Function SettingsFormCollectionItem(Collection)
	
	If Collection.GetItems().Count() = 0  Then
		Return Undefined;
	EndIf;
	
	Return Collection.GetItems()[0];
	
EndFunction

// ACC:568-on

#Region DefiningSelectionItemSelectionData

&AtClient
Procedure DefineFilterItemSelectionDataOnQuery(InitialQuery, ChoiceData, AvailableFields, Query = Undefined, Parent = Undefined, IndexOf = 0)
	
	If ChoiceData = Undefined Then 
		ChoiceData = New ValueList;
	EndIf;
	
	If Query = Undefined Then 
		Query = InitialQuery;
	EndIf;
	
	QueryDetails = StrSplit(Query, ".", False);
	
	If StrEndsWith(Query, ".") Then 
		QueryDetails.Add(". ");
	EndIf;
	
	While IndexOf <= QueryDetails.UBound() Do 
		
		QueryFragment = TrimAll(QueryDetails[IndexOf]);
		SubordinateItems = ?(Parent = Undefined, AvailableFields.Items, Parent.Items);
		
		If IndexOf = QueryDetails.UBound() Then 
			
			FillSelectionItemSelectionData(InitialQuery, SubordinateItems, ChoiceData);
			
		ElsIf ChoiceData.Count() = 0 Then 
			
			DataPath = QueryFragment;
			
			If Parent <> Undefined Then 
				DataPath = StringFunctionsClientServer.SubstituteParametersToString(
					"%1.%2", Parent.Field, QueryFragment);
			EndIf;
			
			Field = New DataCompositionField(DataPath);
			FoundField = AvailableFields.FindField(Field);
		
			If FoundField = Undefined Then 
				FoundField = AvailableFilterFieldByTitle(QueryFragment, SubordinateItems);
			EndIf;
			
			QueryDetails.Delete(IndexOf);
			NewQuery = StrConcat(QueryDetails, ".");
			DefineFilterItemSelectionDataOnQuery(
				InitialQuery, ChoiceData, AvailableFields, NewQuery, FoundField, IndexOf);
			
		EndIf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillSelectionItemSelectionData(InitialQuery, SubordinateItems, ChoiceData)
	
	For Each Item In SubordinateItems Do 
		
		If Not Item.Folder
			And Not Item.Table
			And StrStartsWith(Upper(Item.Title), Upper(InitialQuery)) Then 
			
			ItemPresentation = SelectionItemView(Item, InitialQuery);
			ChoiceData.Add(Item.Field, ItemPresentation);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function SelectionItemView(FilterElement, InitialQuery)
	
	RequestStart = StrFind(Upper(FilterElement.Title), Upper(InitialQuery));
	EndRequest = RequestStart + StrLen(InitialQuery);
	LengthOfTheFoundFragment = ?(RequestStart = 0, 0, StrLen(InitialQuery));
	
	FragmentBeforeRequest = Left(FilterElement.Title, RequestStart - 1);
	QueryFragment = SelectionElementRequestFragment(Mid(FilterElement.Title, RequestStart, LengthOfTheFoundFragment));
	FragmentAfterRequest = Mid(FilterElement.Title, EndRequest);
	
	Return New FormattedString(
		FragmentBeforeRequest,
		QueryFragment,
		FragmentAfterRequest);
	
EndFunction

&AtClient
Function SelectionElementRequestFragment(Query)
	
	RequestFragmentTemplate = StringFunctionsClientServer.SubstituteParametersToString(
		"<span style=""color: %1; font: %2"">%3</span>",
		"MyReportsOptionsColor",
		"ImportantLabelFont",
		Query);
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	QueryFragment = StringFunctions.FormattedString(RequestFragmentTemplate);
#Else
	QueryFragment = StringFunctionsClient.FormattedString(RequestFragmentTemplate);
#EndIf
	
	Return QueryFragment;
	
EndFunction

&AtClient
Function AvailableFilterFieldByTitle(FieldTitle, SubordinateItems)
	
	For Each Item In SubordinateItems Do 
		
		If Not Item.Folder
			And Not Item.Table
			And Upper(Item.Title) = Upper(FieldTitle) Then 
				
			Return Item;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

&AtClient
Procedure OpenSettingsFormForTechnician(PageName, CompletionHandler = Undefined)
	
	FormParameters = New Structure;
	CommonClientServer.SupplementStructure(FormParameters, ParametersForm, True);
	FormParameters.Insert("VariantKey", String(CurrentVariantKey));
	FormParameters.Insert("Variant", Report.SettingsComposer.Settings);
	FormParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	FormParameters.Insert("ReportSettings", ReportSettings);
	FormParameters.Insert("DescriptionOption", DescriptionOption);
	FormParameters.Insert("SettingsStructureItemID", SettingsStructureItemID);
	FormParameters.Insert("PageName", PageName);
	FormParameters.Insert("VariantPresentation", DescriptionOption);
	FormParameters.Insert("VariantModified", OptionChanged);
	FormParameters.Insert("UserSettingsModified",
		OptionChanged Or UserSettingsModified);
	
	If CompletionHandler <> Undefined Then
		OpenForm(ReportSettings.FullName + ".VariantForm", FormParameters, FormOwner, , , , 
			CompletionHandler, FormWindowOpeningMode.LockOwnerWindow);
	Else
		OpenForm(ReportSettings.FullName + ".VariantForm", FormParameters, FormOwner);
		If CompletionHandler = Undefined Then
			SelectionResultGenerated = True;
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure WhenClosingSettingsFormForTechnician(Result, AdditionalParameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		UpdateForm(Result);
	EndIf;
	
EndProcedure

#EndRegion