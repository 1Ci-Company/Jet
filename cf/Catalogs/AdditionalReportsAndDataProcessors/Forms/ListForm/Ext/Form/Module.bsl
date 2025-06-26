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
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;

	If ValueIsFilled(Parameters.Title) Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	If Parameters.Representation <> Undefined Then
		Items.List.Representation = TableRepresentation[Parameters.Representation];
	EndIf;
	
	PublicationsKindsList = Items.PublicationFilter.ChoiceList;
	
	KindUsed = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	KindDebugMode = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	AvaliablePublicationKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	
	AllPublicationsExceptDisabled = New Array;
	AllPublicationsExceptDisabled.Add(KindUsed);
	If AvaliablePublicationKinds.Find(KindDebugMode) <> Undefined Then
		AllPublicationsExceptDisabled.Add(KindDebugMode);
	EndIf;
	If AllPublicationsExceptDisabled.Count() > 1 Then
		ArrayPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 or %2';"),
			String(AllPublicationsExceptDisabled[0]),
			String(AllPublicationsExceptDisabled[1]));
		PublicationsKindsList.Add(1, ArrayPresentation);
	EndIf;
	For Each EnumerationValue In Enums.AdditionalReportsAndDataProcessorsPublicationOptions Do
		If AvaliablePublicationKinds.Find(EnumerationValue) <> Undefined Then
			PublicationsKindsList.Add(EnumerationValue, String(EnumerationValue));
		EndIf;
	EndDo;
	
	If Parameters.Filter.Property("Publication") Then
		PublicationFilter = Parameters.Filter.Publication;
		Parameters.Filter.Delete("Publication");
		If PublicationsKindsList.FindByValue(PublicationFilter) = Undefined Then
			PublicationFilter = Undefined;
		EndIf;
	EndIf;
	
	ChoiceList = Items.KindFilter.ChoiceList;
	ChoiceList.Add(1, NStr("en = 'Reports only';"));
	ChoiceList.Add(2, NStr("en = 'Data processors only';"));
	For Each EnumerationValue In Enums.AdditionalReportsAndDataProcessorsKinds Do
		ChoiceList.Add(EnumerationValue, String(EnumerationValue));
	EndDo;
	
	AddlReportsKinds = New Array;
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	
	List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	List.Parameters.SetParameterValue("KindFilter",        KindFilter);
	List.Parameters.SetParameterValue("AddlReportsKinds",  AddlReportsKinds);
	List.Parameters.SetParameterValue("AllPublicationsExceptDisabled", AllPublicationsExceptDisabled);
	
	InsertRight1 = AdditionalReportsAndDataProcessors.InsertRight1();
	CommonClientServer.SetFormItemProperty(Items, "Create",              "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "CreateMenu",          "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "CreateFolder",        "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "CreateMenuGroup",    "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "Copy",          "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "CopyMenu",      "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "LoadFromFile",     "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "ExportFromMenuFile", "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "ExportToFile",       "Visible", InsertRight1);
	CommonClientServer.SetFormItemProperty(Items, "ExportToFileMenu",   "Visible", InsertRight1);
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
		Or Not AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Items.ChangeSelectedItems.Visible = False;
		Items.ChangeSelectedItemsMenu.Visible = False;
	EndIf;
	
	If Parameters.Property("AdditionalReportsAndDataProcessorsCheck") Then
		Items.Create.Visible = False;
		Items.CreateFolder.Visible = False;
	EndIf;
	
	Items.NoteServiceGroup.Visible = Common.DataSeparationEnabled();
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	If Not ValueIsFilled(PublicationFilter) Then
		PublicationFilter = Settings.Get("PublicationFilter");
		List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	EndIf;
	KindFilter = Settings.Get("KindFilter");
	List.Parameters.SetParameterValue("KindFilter", KindFilter);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PublicationFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("PublicationFilter");
	If DCParameterValue.Value <> PublicationFilter Then
		DCParameterValue.Value = PublicationFilter;
	EndIf;
EndProcedure

&AtClient
Procedure KindFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("KindFilter");
	If DCParameterValue.Value <> KindFilter Then
		DCParameterValue.Value = KindFilter;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	If Copy Then
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExportToFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	ExportingParameters = New Structure;
	ExportingParameters.Insert("Ref",   RowData.Ref);
	ExportingParameters.Insert("IsReport", RowData.IsReport);
	ExportingParameters.Insert("FileName", RowData.FileName);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportingParameters);
EndProcedure

&AtClient
Procedure ImportReportDataProcessorsFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", RowData.Ref);
	FormParameters.Insert("ShowImportFromFileDialogOnOpen", True);
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ObjectForm", FormParameters);
EndProcedure

&AtClient
Procedure ChangeSelectedItems(Command)
	ModuleBatchObjectsModificationClient = CommonClient.CommonModule("BatchEditObjectsClient");
	ModuleBatchObjectsModificationClient.ChangeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure PublicationAvailable(Command)
	EditPublication("Used");
EndProcedure

&AtClient
Procedure PublicationDisabled(Command)
	EditPublication("isDisabled");
EndProcedure

&AtClient
Procedure PublicationDebugMode(Command)
	EditPublication("DebugMode");
EndProcedure

#EndRegion

#Region Private

&AtClient
Function ItemSelected(RowData)
	If TypeOf(RowData.Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		ShowMessageBox(, NStr("en = 'Cannot run the command for the object.
			|Please select an additional report or data processor.';"));
		Return False;
	EndIf;
	If RowData.IsFolder Then
		ShowMessageBox(, NStr("en = 'Cannot run the command for a group.
			|Please select an additional report or data processor.';"));
		Return False;
	EndIf;
	Return True;
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Publication");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Publication");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure EditPublication(PublicationOption)
	
	ClearMessages();
	
	SelectedRows = Items.List.SelectedRows;
	RowsCount = SelectedRows.Count();
	If RowsCount = 0 Then
		ShowMessageBox(, NStr("en = 'No additional report or data processor is selected.';"));
		Return;
	EndIf;
	
	EditingPublication(PublicationOption);
	
	If RowsCount = 1 Then
		MessageText = NStr("en = 'Availability for the additional report or data processor has been changed: %1.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, String(SelectedRows[0]));
	Else
		MessageText = NStr("en = 'Availability for the additional reports or data processors have been changed: %1.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, RowsCount);
	EndIf;
	
	ShowUserNotification(NStr("en = 'Availability changed';"),, MessageText);
	
EndProcedure

&AtServer
Procedure EditingPublication(PublicationOption)
	
	Query = New Query;
	Query.SetParameter("SelectedRows", Items.List.SelectedRows);
	Query.Text =
		"SELECT
		|	AdditionalReportsAndDataProcessors.Ref
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS AdditionalReportsAndDataProcessors
		|WHERE
		|	AdditionalReportsAndDataProcessors.Ref IN (&SelectedRows)
		|	AND NOT AdditionalReportsAndDataProcessors.IsFolder";
	SelectedRows = Query.Execute().Unload().UnloadColumn("Ref");
	
	BeginTransaction();
	Try
		For Each AdditionalReportOrDataProcessor In SelectedRows Do
			LockDataForEdit(AdditionalReportOrDataProcessor);
			
			Block = New DataLock;
			LockItem = Block.Add("Catalog.AdditionalReportsAndDataProcessors");
			LockItem.SetValue("Ref", AdditionalReportOrDataProcessor);
			Block.Lock();
		EndDo;
		
		For Each AdditionalReportOrDataProcessor In SelectedRows Do
			Object = AdditionalReportOrDataProcessor.GetObject();
			If PublicationOption = "Used" Then
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
			ElsIf PublicationOption = "DebugMode" Then
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
			Else
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.isDisabled;
			EndIf;
			
			Object.AdditionalProperties.Insert("ListCheck");
			If Not Object.CheckFilling() Then
				ErrorPresentation = "";
				ArrayOfMessages = GetUserMessages(True);
				For Each UserMessage In ArrayOfMessages Do
					ErrorPresentation = ErrorPresentation + UserMessage.Text + Chars.LF;
				EndDo;
				
				Raise ErrorPresentation;
			EndIf;
			
			Object.Write();
		EndDo;
		
		UnlockDataForEdit();
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit();
		Raise;
	EndTry;
	Items.List.Refresh();
	
EndProcedure

#EndRegion
