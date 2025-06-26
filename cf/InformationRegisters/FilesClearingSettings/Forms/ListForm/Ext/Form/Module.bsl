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
	FillObjectTypesInValueTree();	
	FillChoiceLists();
	
	AutomaticallyCleanUpUnusedFiles = AutomaticClearingEnabled();
	Items.Schedule.Title     = CurrentSchedule();
	
	Items.Schedule.Enabled = AutomaticallyCleanUpUnusedFiles;
	Items.SetUpSchedule.Enabled = AutomaticallyCleanUpUnusedFiles;
	
	If Common.DataSeparationEnabled() Then
		Items.SetUpSchedule.Visible = False;
		Items.Schedule.Visible = False;
	EndIf;
	
	Items.PagesTotalsFilesToDelete.CurrentPage = Items.PageTotalsCalculationFilesToDelete;
	CalculateDeletableFilesInfo();
	FilesCleanupMode = FilesOperationsInternal.FilesCleanupMode();
	ConfigureFilePurgeModes();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	WaitDeletableFilesInfoCalculationEnd();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ConstantsSet" And Source = "FilesStorageMethod" Then
		ConfigureFilePurgeModes();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilesCleanupModeOnChange(Item)
	FilesCleanupModeOnChangeServer();
EndProcedure

&AtServer
Procedure FilesCleanupModeOnChangeServer()
	FilesOperationsInternal.SetTheFileCleaningMode(FilesCleanupMode);
EndProcedure

&AtClient
Procedure AutomaticallyCleanUpUnusedFilesOnChange(Item)
	SetObsoleteFileCleanUpScheduledJobParameter("Use", AutomaticallyCleanUpUnusedFiles);
	Items.Schedule.Enabled = AutomaticallyCleanUpUnusedFiles;
	Items.SetUpSchedule.Enabled = AutomaticallyCleanUpUnusedFiles;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersMetadataObjectsTree

&AtClient
Procedure MetadataObjectsTreeBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	
	Cancel = True;
	If Not Copy Then
		AttachIdleHandler("AddFileCleanupSettings", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() = Undefined Then
		Cancel = True;
	EndIf;
	
	If Item.CurrentItem = Items.MetadataObjectsTreeAction Then
		FillChoiceList(Items.MetadataObjectsTree.CurrentItem);
	EndIf;

EndProcedure

&AtClient
Procedure MetadataObjectsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name = "MetadataObjectsTreeFilterRule" Then
		StandardProcessing = False;
		OpenSettingsForm();
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeFilterRuleStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("OpenSettingsForm", 0.1, True);
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeActionOnChange(Item)
	
	WriteCurrentSettings();
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeClearingPeriodOnChange(Item)
	
	WriteCurrentSettings();
		
EndProcedure

&AtClient
Procedure MetadataObjectsTreeChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	AddSettingsByOwner(ValueSelected);

EndProcedure

&AtClient
Procedure MetadataObjectsTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	SettingToDelete = MetadataObjectsTree.FindByID(Items.MetadataObjectsTree.CurrentRow);
	If SettingToDelete <> Undefined Then
		
		SettingToDeleteParent = SettingToDelete.GetParent();
		
		If SettingToDeleteParent <> Undefined And SettingToDeleteParent.DetailedInfoAvailable Then
			
			QueryText = NStr("en = 'If you delete the setting, you will not be able
				|to clean up files according to the rules defined in it. Continue?';");
			NotifyDescription = New NotifyDescription("DeleteSettingItemCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Warning';"));
			Return;
			
		EndIf;
		
	EndIf;
	
	MessageText = NStr("en = 'Advanced file cleanup settings are unavailable for this object.';");
	ShowMessageBox(, MessageText);
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeClearingPeriodClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure MetadataObjectsTreeActionClearing(Item, StandardProcessing)
	
	StandardProcessing = False;	
	SetActionForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupOptions.NotClear"));
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure IrrelevantFilesVolume(Command)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.IrrelevantFilesVolume.ObjectForm", ReportParameters);
	
EndProcedure

&AtClient
Procedure SetUpSchedule(Command)
	ScheduleDialog1 = New ScheduledJobDialog(CurrentSchedule());
	NotifyDescription = New NotifyDescription("SetUpScheduleCompletion", ThisObject);
	ScheduleDialog1.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure SetActionDoNotCleanUp(Command)
	
	SetActionForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupOptions.NotClear"));
	
EndProcedure

&AtClient
Procedure SetActionCleanUpVersions(Command)
	
	If Not CanClearVersions() Then
		Return;
	EndIf;
	
	SetActionForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupOptions.CleanUpVersions"));
	
EndProcedure

&AtClient
Procedure SetActionCleanUpFiles(Command)
	
	SetActionForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupOptions.CleanUpFiles"));
	
EndProcedure

&AtClient
Procedure SetActionCleanUpFilesAndVersions(Command)
	
	If Not CanClearVersions() Then
		Return;
	EndIf;
	
	SetActionForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupOptions.CleanUpFilesAndVersions"));
	
EndProcedure

&AtClient
Function CanClearVersions()
	If Items.MetadataObjectsTree.SelectedRows.Count() = 1 Then
		CurrentData = Items.MetadataObjectsTree.CurrentData;
		If Not CurrentData.IsFile
			And CurrentData.FileOwner <> Undefined Then
			ShowMessageBox(, NStr("en = 'File versions are not stored for this object.';"));
			Return False;
		EndIf;
	EndIf;
	
	Return True;
EndFunction

&AtClient
Procedure OverOneMonth(Command)
	SetClearingPeriodForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupPeriod.OverOneMonth"));
EndProcedure

&AtClient
Procedure OverSixMonths(Command)
	SetClearingPeriodForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupPeriod.OverSixMonths"));
EndProcedure

&AtClient
Procedure OverOneYear(Command)
	SetClearingPeriodForSelectedObjects(
		PredefinedValue("Enum.FilesCleanupPeriod.OverOneYear"));
EndProcedure

&AtClient
Procedure Clear(Command)
	Notification = New NotifyDescription("ClearCompletion", ThisObject);
	ShowQueryBox(Notification, NStr("en = 'Clean up unused files?
		|
		|Unused files will be permanently deleted based on the settings you''ve configured.
		|You might want to create a backup of the infobase and network file storage volumes before deleting.';"), 
		QuestionDialogMode.OKCancel);
EndProcedure

&AtClient
Procedure DeletedFilesVolume(Command)
	OpenForm("Catalog.FileStorageVolumes.ListForm");
EndProcedure

&AtClient
Procedure GoToList(Command)
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ListFormName = ListFormName(CurrentData.FileOwner);
	If Not IsBlankString(ListFormName) Then
		OpenForm(ListFormName(CurrentData.FileOwner));
	EndIf;
	
EndProcedure


&AtClient
Procedure ShouldUpdateInfo(Command)
	CalculateDeletableFilesInfo();
	WaitDeletableFilesInfoCalculationEnd();
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		SelectedOwners = New Array;
		SelectedRows = Items.MetadataObjectsTree.SelectedRows;
		For Each RowID In SelectedRows Do
			ObjectTreeRow = MetadataObjectsTree.FindByID(RowID);
			AddFileOwner(SelectedOwners, ObjectTreeRow);
		EndDo;
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, SelectedOwners);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.MetadataObjectsTree);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Items.MetadataObjectsTree);
	EndIf;
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Procedure CalculateDeletableFilesInfo()
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.RefinementErrors =
		NStr("en = 'Cannot calculate the total size of files to delete:';");
	TotalsCalculationDetails = TimeConsumingOperations.ExecuteFunction(ExecutionParameters, 
		"FilesOperationsInternal.InformationAboutFilesToBeCleaned");
EndProcedure

&AtClient
Procedure WaitDeletableFilesInfoCalculationEnd()
	Handler = New NotifyDescription("OnFinishCalculatingDetailsAboutFilesToDelete", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputProgressBar = False;
	TimeConsumingOperationsClient.WaitCompletion(TotalsCalculationDetails, Handler, IdleParameters);
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure OnFinishCalculatingDetailsAboutFilesToDelete(Result, AdditionalParameters) Export
	
	Items.PagesTotalsFilesToDelete.CurrentPage = Items.PageTotalsDisplayFilesToDelete;
	
	If Result = Undefined Then
		Return;
	EndIf; 
	
	If Result.Status = "Error" Then
		DisplayTotals(0, 0);
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	EndIf;
	
	Totals = GetFromTempStorage(Result.ResultAddress); // See FilesOperationsInternal.InformationAboutFilesToBeCleaned
	DisplayTotals(Totals.TheAmountOfFilesBeingDeleted, Totals.IrrelevantFilesVolume);
	
EndProcedure

&AtClient
Procedure DisplayTotals(TheAmountOfFilesBeingDeleted, IrrelevantFilesVolume)
	Items.DeletedFilesVolume.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Files being deleted: %1 MB';"),
		 Format(TheAmountOfFilesBeingDeleted, "NFD=2; NZ=0;"));
	Items.IrrelevantFilesVolume.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Unused files: %1 MB';"),
		 Format(IrrelevantFilesVolume, "NFD=2; NZ=0;"));
EndProcedure

&AtServer
Function ChoiceFormPath(FileOwner)
	
	MetadataObject = Common.MetadataObjectByID(FileOwner);
	Return MetadataObject.FullName() + ".ChoiceForm";
	
EndFunction

&AtClient
Procedure SetCommandVisibilityClear()
	
	SubordinatePages = Items.FilesCleanup.ChildItems;
	If IsBlankString(CurrentBackgroundJob) Then
		Items.FilesCleanup.CurrentPage = SubordinatePages.Clearing;
	Else
		Items.FilesCleanup.CurrentPage = SubordinatePages.BackgroundJobStatus;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillChoiceLists()
	
	ChoiceListWithVersions = New ValueList;
	ChoiceListWithVersions.Add(Enums.FilesCleanupOptions.CleanUpFilesAndVersions);
	ChoiceListWithVersions.Add(Enums.FilesCleanupOptions.CleanUpVersions);
	ChoiceListWithVersions.Add(Enums.FilesCleanupOptions.NotClear);
	
	ChoiceListWithoutVersions = New ValueList;
	ChoiceListWithoutVersions.Add(Enums.FilesCleanupOptions.CleanUpFiles);
	ChoiceListWithoutVersions.Add(Enums.FilesCleanupOptions.NotClear);
	
EndProcedure

&AtClient
Procedure FillChoiceList(Item)
	
	TreeRow = Items.MetadataObjectsTree.CurrentData;
	
	Item.ChoiceList.Clear();
	
	If TreeRow.IsFile Then
		ChoiceList = ChoiceListWithVersions;
	Else
		ChoiceList = ChoiceListWithoutVersions;
	EndIf;
	
	For Each ListItem In ChoiceList Do
		Item.ChoiceList.Add(ListItem.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillObjectTypesInValueTree()
	
	CleanupSettings = InformationRegisters.FilesClearingSettings.CurrentClearSettings();
	
	MOTree = FormAttributeToValue("MetadataObjectsTree");
	MOTree.Rows.Clear();
	
	MetadataCatalogs = Metadata.Catalogs;
	
	TypesTable = New ValueTable;
	TypesTable.Columns.Add("FileOwner");
	TypesTable.Columns.Add("FileOwnerType");
	TypesTable.Columns.Add("FileOwnerName");
	TypesTable.Columns.Add("IsFile", New TypeDescription("Boolean"));
	TypesTable.Columns.Add("DetailedInfoAvailable"  , New TypeDescription("Boolean"));
	ExceptionsArray = FilesOperationsInternal.ExceptionItemsOnClearFiles();
	For Each Catalog In MetadataCatalogs Do
		
		If Catalog.Attributes.Find("FileOwner") = Undefined Then
			Continue;
		EndIf;
		
		FilesOwnersTypes = Catalog.Attributes.FileOwner.Type.Types();
		For Each OwnerType In FilesOwnersTypes Do
			
			OwnerMetadata = Metadata.FindByType(OwnerType);
			If ExceptionsArray.Find(OwnerMetadata) <> Undefined Then
				Continue;
			EndIf;
			
			NewRow = TypesTable.Add();
			NewRow.FileOwner = OwnerType;
			NewRow.FileOwnerType = Catalog;
			NewRow.FileOwnerName = OwnerMetadata.FullName();
			If Metadata.Catalogs.Contains(OwnerMetadata)
				And OwnerMetadata.Hierarchical Then
				
				NewRow.DetailedInfoAvailable = True;
			EndIf;
			
			If Not StrEndsWith(Catalog.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles()) Then
				NewRow.IsFile = True;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	AllCatalogs = Catalogs.AllRefsType();
	
	AllDocuments = Documents.AllRefsType();
	CatalogsNode = Undefined;
	DocumentsNode = Undefined;
	BusinessProcessesNode = Undefined;
	
	FilesOwners = New Array;
	For Each Type In TypesTable Do
		
		FileOwnerType = Type.FileOwnerType; // MetadataObjectCatalog
		If StrStartsWith(FileOwnerType.Name, "Delete")
			Or FilesOwners.Find(Type.FileOwnerName) <> Undefined Then
			Continue;
		EndIf;
		
		FilesOwners.Add(Type.FileOwnerName);
		
		If AllCatalogs.ContainsType(Type.FileOwner) Then
			If CatalogsNode = Undefined Then
				CatalogsNode = MOTree.Rows.Add();
				CatalogsNode.ObjectDescriptionSynonym = NStr("en = 'Catalogs';");
			EndIf;
			NewTableRow = CatalogsNode.Rows.Add();
			ObjectID = Common.MetadataObjectID(Type.FileOwner);
			DetailedSettings = CleanupSettings.FindRows(New Structure(
				"OwnerID, IsFile",
				ObjectID, Type.IsFile));
			If DetailedSettings.Count() > 0 Then
				For Each Setting In DetailedSettings Do
					DetalizedSetting = NewTableRow.Rows.Add();
					DetalizedSetting.FileOwner = Setting.FileOwner;
					DetalizedSetting.FileOwnerType = Setting.FileOwnerType;
					DetalizedSetting.ObjectDescriptionSynonym = Setting.FileOwner;
					DetalizedSetting.Action = Setting.Action;
					DetalizedSetting.FilterRule = "Change";
					DetalizedSetting.ClearingPeriod = Setting.ClearingPeriod;
					DetalizedSetting.IsFile = Setting.IsFile;
				EndDo;
			EndIf;
		ElsIf AllDocuments.ContainsType(Type.FileOwner) Then
			If DocumentsNode = Undefined Then
				DocumentsNode = MOTree.Rows.Add();
				DocumentsNode.ObjectDescriptionSynonym = NStr("en = 'Documents';");
			EndIf;
			NewTableRow = DocumentsNode.Rows.Add();
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type.FileOwner) Then
			If BusinessProcessesNode = Undefined Then
				BusinessProcessesNode = MOTree.Rows.Add();
				BusinessProcessesNode.ObjectDescriptionSynonym = NStr("en = 'Business processes';");
			EndIf;
			NewTableRow = BusinessProcessesNode.Rows.Add();
		EndIf;
		ObjectMetadata = Metadata.FindByType(Type.FileOwner);
		NewTableRow.FileOwner = Common.MetadataObjectID(Type.FileOwner);
		NewTableRow.FileOwnerType = Common.MetadataObjectID(Type.FileOwnerType);
		NewTableRow.ObjectDescriptionSynonym = ObjectMetadata.Synonym;
		NewTableRow.FilterRule = "Change";
		NewTableRow.IsFile = Type.IsFile;
		NewTableRow.DetailedInfoAvailable = Type.DetailedInfoAvailable;
		
		FoundSettings = CleanupSettings.FindRows(New Structure("FileOwner, IsFile", NewTableRow.FileOwner, Type.IsFile));
		If FoundSettings.Count() > 0 Then
			NewTableRow.Action = FoundSettings[0].Action;
			NewTableRow.ClearingPeriod = FoundSettings[0].ClearingPeriod;
		Else
			NewTableRow.Action = Enums.FilesCleanupOptions.NotClear;
			NewTableRow.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneYear;
		EndIf;
	EndDo;
	
	For Each TopLevelNode In MOTree.Rows Do
		TopLevelNode.Rows.Sort("ObjectDescriptionSynonym");
	EndDo;
	ValueToFormAttribute(MOTree, "MetadataObjectsTree");
	
EndProcedure

&AtClient
Procedure SetUpScheduleCompletion(Schedule, AdditionalParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	SetObsoleteFileCleanUpScheduledJobParameter("Schedule", Schedule);
	Items.Schedule.Title = Schedule;
	
EndProcedure

&AtServer
Procedure SetClearingPeriodForSelectedObjects(ClearingPeriod)
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetClearingPeriodForSelectedObject(TreeChildItem, ClearingPeriod);
			EndDo;
		Else
			SetClearingPeriodForSelectedObject(TreeItem, ClearingPeriod);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetClearingPeriodForSelectedObject(SelectedObject, ClearingPeriod)
	
	SelectedObject.ClearingPeriod = ClearingPeriod;
	SaveCurrentObjectSettings(
		SelectedObject.FileOwner,
		SelectedObject.FileOwnerType,
		SelectedObject.Action,
		ClearingPeriod,
		SelectedObject.IsFile);
	
EndProcedure

&AtServer
Procedure SetActionForSelectedObjects(Val Action)
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetActionOfSelectedObjectWithRecursion(TreeChildItem, Action);
			EndDo;
		Else
			SetActionOfSelectedObjectWithRecursion(TreeItem, Action);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetActionOfSelectedObjectWithRecursion(SelectedObject, Val Action)
	
	SetSelectedObjectAction(SelectedObject, Action);
	For Each ChildObject In SelectedObject.GetItems() Do
		SetSelectedObjectAction(ChildObject, Action);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetSelectedObjectAction(SelectedObject, Val Action)
	
	If Not SelectedObject.IsFile Then
		If Action = PredefinedValue("Enum.FilesCleanupOptions.CleanUpVersions") Then
			Return;
		ElsIf Action = PredefinedValue("Enum.FilesCleanupOptions.CleanUpFilesAndVersions") Then
			Action = PredefinedValue("Enum.FilesCleanupOptions.CleanUpFiles");
		EndIf;
	ElsIf Action = PredefinedValue("Enum.FilesCleanupOptions.CleanUpFiles") Then
		Action = PredefinedValue("Enum.FilesCleanupOptions.CleanUpFilesAndVersions");
	EndIf;
	
	SelectedObject.Action = Action;
	SaveCurrentObjectSettings(
		SelectedObject.FileOwner,
		SelectedObject.FileOwnerType,
		Action,
		SelectedObject.ClearingPeriod,
		SelectedObject.IsFile);
	
EndProcedure

&AtClient
Procedure WriteCurrentSettings()
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	SaveCurrentObjectSettings(
		CurrentData.FileOwner,
		CurrentData.FileOwnerType,
		CurrentData.Action,
		CurrentData.ClearingPeriod,
		CurrentData.IsFile);
	
EndProcedure

&AtServer
Procedure SaveCurrentObjectSettings(FileOwner, FileOwnerType, Action, ClearingPeriod, IsFile)
	
	Setting                   = InformationRegisters.FilesClearingSettings.CreateRecordManager();
	Setting.FileOwner     = FileOwner;
	Setting.FileOwnerType = FileOwnerType;
	Setting.Action          = Action;
	Setting.ClearingPeriod     = ClearingPeriod;
	Setting.IsFile           = IsFile;
	Setting.Write();
	
EndProcedure

&AtClient
Procedure OpenSettingsForm()
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	
	If CurrentData.ClearingPeriod <> PredefinedValue("Enum.FilesCleanupPeriod.ByRule") Then
		Return;
	EndIf;
	
	CheckSettingExistence(
		CurrentData.FileOwner,
		CurrentData.FileOwnerType,
		CurrentData.Action,
		CurrentData.ClearingPeriod,
		CurrentData.IsFile);
	
	Filter = New Structure(
		"FileOwner, FileOwnerType",
		CurrentData.FileOwner,
		CurrentData.FileOwnerType);
	
	ValueType = Type("InformationRegisterRecordKey.FilesClearingSettings");
	WriteParameters = New Array(1);
	WriteParameters[0] = Filter;
	
	RecordKey = New(ValueType, WriteParameters);
	
	WriteParameters = New Structure;
	WriteParameters.Insert("Key", RecordKey);
	
	OpenForm("InformationRegister.FilesClearingSettings.RecordForm", WriteParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob1()
	CancelJobExecution(BackgroundJobIdentifier);
	DetachIdleHandler("CheckBackgroundJobExecution");
	CurrentBackgroundJob = "";
	BackgroundJobIdentifier = "";
EndProcedure

&AtServerNoContext
Procedure CancelJobExecution(BackgroundJobIdentifier)
	If ValueIsFilled(BackgroundJobIdentifier) Then
		TimeConsumingOperations.CancelJobExecution(BackgroundJobIdentifier);
	EndIf;
EndProcedure

&AtServer
Procedure CheckSettingExistence(FileOwner, FileOwnerType, Action, ClearingPeriod, IsFile)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesClearingSettings.FileOwner,
		|	FilesClearingSettings.FileOwnerType
		|FROM
		|	InformationRegister.FilesClearingSettings AS FilesClearingSettings
		|WHERE
		|	FilesClearingSettings.FileOwner = &FileOwner
		|	AND FilesClearingSettings.FileOwnerType = &FileOwnerType";
	
	Query.SetParameter("FileOwner", FileOwner);
	Query.SetParameter("FileOwnerType", FileOwnerType);
	
	RecordsCount = Query.Execute().Unload().Count();
	
	If RecordsCount = 0 Then
		SaveCurrentObjectSettings(FileOwner, FileOwnerType, Action, ClearingPeriod, IsFile);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckBackgroundJobExecution()
	If ValueIsFilled(BackgroundJobIdentifier) And Not JobCompleted(BackgroundJobIdentifier) Then
		AttachIdleHandler("CheckBackgroundJobExecution", 5, True);
	Else
		BackgroundJobIdentifier = "";
		CurrentBackgroundJob = "";
		SetCommandVisibilityClear();
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobIdentifier)
	Return TimeConsumingOperations.JobCompleted(BackgroundJobIdentifier);
EndFunction

&AtServer
Procedure RunScheduledJob()
	
	ScheduledJobMetadata1 = Metadata.ScheduledJobs.CleanUpUnusedFiles;
	
	Filter = New Structure;
	MethodName = ScheduledJobMetadata1.MethodName;
	Filter.Insert("MethodName", MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CleanupBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If CleanupBackgroundJobs.Count() > 0 Then
		BackgroundJobIdentifier = CleanupBackgroundJobs[0].UUID;
	Else
		JobParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		JobParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Manual start: %1';"), ScheduledJobMetadata1.Synonym);
		JobResult = TimeConsumingOperations.ExecuteInBackground(ScheduledJobMetadata1.MethodName, 
			New Structure("ManualStart1", True), JobParameters);
		If ValueIsFilled(BackgroundJobIdentifier) Then
			BackgroundJobIdentifier = JobResult.JobID;
		EndIf;
	EndIf;
	
	CurrentBackgroundJob = "Clearing";
	
EndProcedure

&AtServerNoContext
Procedure SetObsoleteFileCleanUpScheduledJobParameter(ParameterName, ParameterValue)
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.CleanUpUnusedFiles);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.CleanUpUnusedFiles.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	If JobsList.Count() = 0 Then
		JobParameters.Insert(ParameterName, ParameterValue);
		ScheduledJobsServer.AddJob(JobParameters);
	Else
		JobParameters = New Structure(ParameterName, ParameterValue);
		For Each Job In JobsList Do
			ScheduledJobsServer.ChangeJob(Job, JobParameters);
		EndDo;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ObsoleteFileCleanUpScheduledJobParameter(ParameterName, DefaultValue)
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.CleanUpUnusedFiles);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.CleanUpUnusedFiles.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	For Each Job In JobsList Do
		Return Job[ParameterName];
	EndDo;
	
	Return DefaultValue;
	
EndFunction

&AtServer
Procedure AddSettingsByOwner(ValueSelected)
	
	RowOwner = MetadataObjectsTree.FindByID(Items.MetadataObjectsTree.CurrentRow);
	
	OwnerRecord = InformationRegisters.FilesClearingSettings.CreateRecordManager();
	FillPropertyValues(OwnerRecord, RowOwner);
	OwnerRecord.Write();
	
	OwnerElement = RowOwner.GetItems();
	For Each Setting In ValueSelected Do
		NewRecord = InformationRegisters.FilesClearingSettings.CreateRecordManager();
		NewRecord.FileOwner = Setting;
		NewRecord.FileOwnerType = RowOwner.FileOwnerType;
		NewRecord.Action = Enums.FilesCleanupOptions.NotClear;
		NewRecord.ClearingPeriod = Enums.FilesCleanupPeriod.OverOneYear;
		NewRecord.IsFile = RowOwner.IsFile;
		NewRecord.Write(True);

		DetalizedSetting = OwnerElement.Add();
		FillPropertyValues(DetalizedSetting, NewRecord);
		DetalizedSetting.ObjectDescriptionSynonym = Setting;
		DetalizedSetting.FilterRule = NStr("en = 'Change rule';");
	EndDo;
	
EndProcedure

&AtServer
Procedure ClearSettingData()
	
	SettingToDelete = MetadataObjectsTree.FindByID(Items.MetadataObjectsTree.CurrentRow);
	
	RecordManager = InformationRegisters.FilesClearingSettings.CreateRecordManager();
	RecordManager.FileOwner = SettingToDelete.FileOwner;
	RecordManager.FileOwnerType = SettingToDelete.FileOwnerType;
	RecordManager.Read();
	RecordManager.Delete();
	
	SettingsItemParent = SettingToDelete.GetParent();
	If SettingsItemParent <> Undefined Then
		SettingsItemParent.GetItems().Delete(SettingToDelete);
	Else
		MetadataObjectsTree.GetItems().Delete(SettingToDelete);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CurrentSchedule()
	Return ObsoleteFileCleanUpScheduledJobParameter("Schedule", New JobSchedule);
EndFunction

&AtServerNoContext
Function AutomaticClearingEnabled()
	Return ObsoleteFileCleanUpScheduledJobParameter("Use", False);
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeFilterRule");
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Action");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FilesCleanupOptions.NotClear;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.ClearingPeriod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.FilesCleanupPeriod.ByRule;
	
	Item.Appearance.SetParameterValue("Text", "");
	Item.Appearance.SetParameterValue("ReadOnly", True);

	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeClearingPeriod");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Action");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FilesCleanupOptions.NotClear;
	
	Item.Appearance.SetParameterValue("Text", "");
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeAction");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Action");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.FilesCleanupOptions.NotClear;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Action");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
	
	Item.Appearance.SetParameterValue("Font", StyleFonts.ImportantLabelFont);
	
EndProcedure

&AtClient
Procedure DeleteSettingItemCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearSettingData();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddFileCleanupSettings()
	
	TreeRow = Items.MetadataObjectsTree.CurrentData;
	
	If Not TreeRow.DetailedInfoAvailable Then
		MessageText = NStr("en = 'Advanced file cleanup settings are unavailable for this object.';");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
	ChoiceFormParameters = New Structure;
	
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", True);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", True);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	
	ChoiceFormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("SelectGroups", True);
	ChoiceFormParameters.Insert("UsersGroupsSelection", True);
	
	ChoiceFormParameters.Insert("AdvancedPick", True);
	ChoiceFormParameters.Insert("PickFormHeader", NStr("en = 'Select settings items';"));
	
	// Excluding already existing settings from the selection list.
	ExistingSettings1 = TreeRow.GetItems();
	FixedSettings = New DataCompositionSettings;
	SettingItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	SettingItem.LeftValue = New DataCompositionField("Ref");
	SettingItem.ComparisonType = DataCompositionComparisonType.NotInList;
	ExistingSettingsList = New Array;
	For Each Setting In ExistingSettings1 Do
		ExistingSettingsList.Add(Setting.FileOwner);
	EndDo;
	SettingItem.RightValue = ExistingSettingsList;
	SettingItem.Use = True;
	SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ChoiceFormParameters.Insert("FixedSettings", FixedSettings);
	
	OpenForm(ChoiceFormPath(TreeRow.FileOwner), ChoiceFormParameters, Items.MetadataObjectsTree);

EndProcedure

&AtClient
Procedure ClearCompletion(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;
	
	CancelBackgroundJob1();
	RunScheduledJob();
	SetCommandVisibilityClear();
	AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
	
EndProcedure

&AtServer
Function ListFormName(Val FileOwner)
	MetadataObject = Common.MetadataObjectByID(FileOwner, False);
	Return ?(MetadataObject <> Undefined And MetadataObject <> Null, MetadataObject.FullName() + ".ListForm", "");
EndFunction

&AtServer
Procedure ConfigureFilePurgeModes()
	
	UseVolumes = FilesOperationsInVolumesInternal.StoreFilesInVolumesOnHardDrive();
	Items.DeletedFilesVolume.Visible = UseVolumes;
	Items.FilesCleanupMode.Visible = UseVolumes;
	Items.AutomaticallyCleanUpUnusedFiles.Title = ?(UseVolumes, 
		NStr("en = 'Clean up automatically:';"), NStr("en = 'Clean up unused files automatically:';"));
	
EndProcedure

&AtClient
Procedure AddFileOwner(SelectedOwners, ObjectTreeRow)
	If TypeOf(ObjectTreeRow.FileOwner) = Type("CatalogRef.MetadataObjectIDs")
	   Or TypeOf(ObjectTreeRow.FileOwner) = Type("CatalogRef.ExtensionObjectIDs")
	   Or ObjectTreeRow.FileOwner = Undefined Then
		SubordinateRows = ObjectTreeRow.GetItems();
		For Each TreeRow In SubordinateRows Do
			AddFileOwner(SelectedOwners, TreeRow);
		EndDo;
	Else
		If SelectedOwners.Find(ObjectTreeRow.FileOwner) = Undefined Then
			SelectedOwners.Add(ObjectTreeRow.FileOwner);
		EndIf;
	EndIf;
EndProcedure

#EndRegion