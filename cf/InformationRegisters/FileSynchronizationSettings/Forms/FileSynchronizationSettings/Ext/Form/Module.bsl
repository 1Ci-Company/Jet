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
	
	If ValueIsFilled(Parameters.FileOwner) Then
		CurrentFileOwner = Common.MetadataObjectID(TypeOf(Parameters.FileOwner));
		FileOwner        = Parameters.FileOwner;
	EndIf;
	
	FillObjectTypesInValueTree();
	
	AutomaticallySynchronizeFiles       = AutomaticSynchronizationEnabled();
	
	Items.Schedule.Title            = CurrentSchedule();
	Items.Schedule.Enabled          = AutomaticallySynchronizeFiles;
	Items.SetUpSchedule.Enabled = AutomaticallySynchronizeFiles;
	
	If Common.DataSeparationEnabled() Then
		Items.SetUpSchedule.Visible = False;
		Items.Schedule.Visible          = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		
		Items.MetadataObjectsTree.Header = False;
		Items.MetadataObjectsTreeAccount.Visible = False;
		Items.MetadataObjectsTreeFilterRule.Visible = False;
		Items.MetadataObjectsTreeSynchronize.Visible = False;
		Items.MetadataObjectsTreeFileOwnerType.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AutomaticallySynchronizeFilesOnChange(Item)
	
	SetScheduledJobParameter("Use", AutomaticallySynchronizeFiles);
	Items.Schedule.Enabled = AutomaticallySynchronizeFiles;
	Items.SetUpSchedule.Enabled = AutomaticallySynchronizeFiles;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersMetadataObjectsTree

&AtClient
Procedure MetadataObjectsTreeSynchronizeOnChange(Item)
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	If Not ValueIsFilled(CurrentData.Account) Then
		CurrentData.Synchronize = False;
		OpenSettingsForm();
		Return;
	EndIf;
	
	If CurrentData.GetItems().Count() > 1 Then
		SetSynchronizationValueToSubordinateObjects(CurrentData.Synchronize);
	Else
		WriteCurrentSettings();
	EndIf;
	
	If Not CurrentData.Synchronize And CurrentData.PreviousSynchronization Then
	
		Notification = New NotifyDescription("AftertheQuestionAboutDisablingSynchronization", ThisObject);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Do you want to finish and disable file synchronization for ""%1""?';"), 
			CurrentData.ObjectDescriptionSynonym);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		
	Else
		CurrentData.PreviousSynchronization = CurrentData.Synchronize;
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeOnActivateRow(Item)
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	
	If CurrentData <> Undefined Then
		HasSettings = ValueIsFilled(CurrentData.Account);
		Items.MetadataObjectsTreeContextMenuDelete.Enabled                        = HasSettings;
		Items.FormMetadataObjectsTreeDelete.Enabled                                  = HasSettings;
		Items.FormChangeSyncSetting.Enabled                                   = HasSettings;
		Items.MetadataObjectsTreeContextMenuChangeSyncSetting.Enabled = HasSettings;
	EndIf;
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	OpenSettingsForm();
EndProcedure

&AtClient
Procedure MetadataObjectsTreeBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure MetadataObjectsTreeFilterRuleStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSettingsForm();
	
EndProcedure

&AtClient
Procedure MetadataObjectsTreeBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	QueryText = NStr("en = 'If you delete the setting, you will not be able
		|to synchronize files according to the rules defined in it. Continue?';");
		
	NotifyDescription = New NotifyDescription("DeleteSettingItemCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Warning';"));
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetUpSchedule(Command)
	ScheduleDialog1 = New ScheduledJobDialog(CurrentSchedule());
	NotifyDescription = New NotifyDescription("SetUpScheduleCompletion", ThisObject);
	ScheduleDialog1.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure ItemSynchronization(Command)
	
	TreeRow = Items.MetadataObjectsTree.CurrentData;
	If Not TreeRow.DetailedInfoAvailable Then
		MessageText = NStr("en = 'The setting is only available for hierarchical catalogs.';");
		CommonClient.MessageToUser(MessageText);
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
Procedure Synchronize(Command)
	
	SynchronizeFiles();
	
EndProcedure

&AtClient
Procedure ChangeSyncSetting(Command)
	
	OpenSettingsForm();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AftertheQuestionAboutDisablingSynchronization(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Items.MetadataObjectsTree.CurrentData.PreviousSynchronization = False;
		SynchronizeFiles();
	Else
		Items.MetadataObjectsTree.CurrentData.Synchronize = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizeFiles()
	
	CancelBackgroundJob1();
	RunScheduledJob();
	SetSynchronizeCommandVisibility();
	AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
	
EndProcedure

&AtClient
Procedure SetUpScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	SetScheduledJobParameter("Schedule", Schedule);
	Items.Schedule.Title = Schedule;
	
EndProcedure

&AtServer
Procedure FillObjectTypesInValueTree()
	
	SettingsTree = FormAttributeToValue("MetadataObjectsTree");
	SettingsTree.Rows.Clear();
	
	FilesOwnersTable = New ValueTable;
	FilesOwnersTable.Columns.Add("FileOwner");
	FilesOwnersTable.Columns.Add("FileOwnerType");
	FilesOwnersTable.Columns.Add("FileOwnerName");
	FilesOwnersTable.Columns.Add("IsFile", New TypeDescription("Boolean"));
	FilesOwnersTable.Columns.Add("DetailedInfoAvailable", New TypeDescription("Boolean"));
	
	FilesSynchronizationExceptions = New Map;
	For Each SynchronizationException In FilesOperationsInternal.OnDefineFileSynchronizationExceptionObjects() Do
		FilesSynchronizationExceptions[SynchronizationException] = True;
	EndDo;
	
	OwnersMetadata = New Array;
	For Each Catalog In Metadata.Catalogs Do
		
		If Catalog.Attributes.Find("FileOwner") = Undefined Then
			Continue;
		EndIf;
			
		FilesOwnersTypes = Catalog.Attributes.FileOwner.Type.Types();
		For Each OwnerType In FilesOwnersTypes Do
			
			OwnerMetadata = Metadata.FindByType(OwnerType);
			If FilesSynchronizationExceptions[OwnerMetadata] <> Undefined Then
				Continue;
			EndIf;
			OwnersMetadata.Add(OwnerMetadata.FullName());
			
			NewRow                        = FilesOwnersTable.Add();
			NewRow.FileOwner          = OwnerType;
			NewRow.FileOwnerType      = Catalog;
			NewRow.FileOwnerName      = OwnerMetadata.FullName();
			NewRow.DetailedInfoAvailable = True;
			NewRow.IsFile                = Not StrEndsWith(Catalog.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles());
			
		EndDo;
		
	EndDo;
	
	SynchronizationSettings = InformationRegisters.FileSynchronizationSettings.CurrentSynchronizationSettings();
	SynchronizationSettings.Indexes.Add("OwnerID, IsFile");
	
	OwnersIDs = Common.MetadataObjectIDs(OwnersMetadata);
	
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	CatalogsNode = Undefined;
	DocumentsNode = Undefined;
	BusinessProcessesNode = Undefined;
	
	FilesOwners = New Array;
	For Each OwnerInfo1 In FilesOwnersTable Do
		
		FileOwnerType = OwnerInfo1.FileOwnerType; // MetadataObjectCatalog
		If StrStartsWith(FileOwnerType.Name, "Delete")
			Or FilesOwners.Find(OwnerInfo1.FileOwnerName) <> Undefined Then
			Continue;
		EndIf;
		
		FilesOwners.Add(OwnerInfo1.FileOwnerName);
		
		If AllCatalogs.ContainsType(OwnerInfo1.FileOwner) Then
			If CatalogsNode = Undefined Then
				CatalogsNode = SettingsTree.Rows.Add();
				CatalogsNode.ObjectDescriptionSynonym = NStr("en = 'Catalogs';");
			EndIf;
			NewTableRow = CatalogsNode.Rows.Add();
		ElsIf AllDocuments.ContainsType(OwnerInfo1.FileOwner) Then
			If DocumentsNode = Undefined Then
				DocumentsNode = SettingsTree.Rows.Add();
				DocumentsNode.ObjectDescriptionSynonym = NStr("en = 'Documents';");
			EndIf;
			NewTableRow = DocumentsNode.Rows.Add();
		ElsIf BusinessProcesses.AllRefsType().ContainsType(OwnerInfo1.FileOwner) Then
			If BusinessProcessesNode = Undefined Then
				BusinessProcessesNode = SettingsTree.Rows.Add();
				BusinessProcessesNode.ObjectDescriptionSynonym = NStr("en = 'Business processes';");
			EndIf;
			NewTableRow = BusinessProcessesNode.Rows.Add();
		EndIf;
		
		ObjectID = OwnersIDs[OwnerInfo1.FileOwnerName];
		Filter = New Structure("OwnerID, IsFile", ObjectID, OwnerInfo1.IsFile);
		DetailedSettings = SynchronizationSettings.FindRows(Filter);
		If DetailedSettings.Count() > 0 Then
			For Each Setting In DetailedSettings Do
				FilterRule                               = Setting.FilterRule.Get(); // DataCompositionSettings
				DetalizedSetting                   = NewTableRow.Rows.Add();
				DetalizedSetting.FileOwner     = Setting.FileOwner;
				DetalizedSetting.FileOwnerType = Setting.FileOwnerType;
				
				HasFilterRules = False;
				If FilterRule <> Undefined Then
					HasFilterRules = FilterRule.Filter.Items.Count() > 0;
				EndIf;
				
				If Not IsBlankString(Setting.Description) Then
					DetalizedSetting.ObjectDescriptionSynonym = Setting.Description;
				Else
					DetalizedSetting.ObjectDescriptionSynonym = Setting.FileOwner;
				EndIf;
				
				HasFilterRules = False;
				If FilterRule <> Undefined Then
					HasFilterRules = FilterRule.Filter.Items.Count() > 0;
				EndIf;
				
				DetalizedSetting.Synchronize        = Setting.Synchronize;
				DetalizedSetting.PreviousSynchronization = Setting.Synchronize;
				DetalizedSetting.Account    = Setting.Account;
				DetalizedSetting.IsFile          = Setting.IsFile;
				DetalizedSetting.FilterRule    =
					?(HasFilterRules, NStr("en = 'Selected files';"), NStr("en = 'All files';"));
				
			EndDo;
		EndIf;
		
		ObjectMetadata = Metadata.FindByType(OwnerInfo1.FileOwner);
		NewTableRow.FileOwner = Common.MetadataObjectID(OwnerInfo1.FileOwner);
		NewTableRow.FileOwnerType = Common.MetadataObjectID(OwnerInfo1.FileOwnerType);
		NewTableRow.ObjectDescriptionSynonym = ObjectMetadata.Synonym;
		NewTableRow.IsFile = OwnerInfo1.IsFile;
		NewTableRow.DetailedInfoAvailable = OwnerInfo1.DetailedInfoAvailable;
		
		Filter = New Structure("FileOwner, IsFile", NewTableRow.FileOwner, NewTableRow.IsFile);
		FoundSettings = SynchronizationSettings.FindRows(Filter);
		
		If FoundSettings.Count() > 0 Then
			
			FilterRule = FoundSettings[0].FilterRule.Get(); // DataCompositionSettings
			
			NewTableRow.Synchronize = FoundSettings[0].Synchronize;
			NewTableRow.Account    = FoundSettings[0].Account;
			If FilterRule <> Undefined And FilterRule.Filter.Items.Count() > 0 Then
				NewTableRow.FilterRule = ?(IsBlankString(FoundSettings[0].Description), 
					NStr("en = 'Selected files';"), FoundSettings[0].Description);
			Else
				NewTableRow.FilterRule = NStr("en = 'All files';");
			EndIf;
			
		Else
			NewTableRow.Synchronize = Enums.FilesCleanupOptions.NotClear;
			NewTableRow.FilterRule = NStr("en = 'All files';");
		EndIf;
		
		NewTableRow.PreviousSynchronization = NewTableRow.Synchronize;
		
	EndDo;
	
	For Each TopLevelNode In SettingsTree.Rows Do
		TopLevelNode.Rows.Sort("ObjectDescriptionSynonym");
	EndDo;
	ValueToFormAttribute(SettingsTree, "MetadataObjectsTree");
	
EndProcedure

&AtClient
Procedure WriteCurrentSettings()
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	SaveCurrentObjectSettings(
		CurrentData.FileOwner,
		CurrentData.FileOwnerType,
		CurrentData.Synchronize,
		CurrentData.Account,
		CurrentData.IsFile);
	
EndProcedure

// Parameters:
//   ValueSelected - Structure:
//   * FileOwner - AnyRef
//   * NewSetting - Boolean
//   * Description - String
//   AdditionalParameters - Structure
//
&AtClient
Procedure SetFilterSettings(ValueSelected, AdditionalParameters) Export
	
	Var RowToRefresh;
	
	If ValueSelected = Undefined Then
		Return
	EndIf;
	
	RowOwner = MetadataObjectsTree.FindByID(AdditionalParameters.Id);
	
	// Detailable string.
	If RowOwner.FileOwner <> ValueSelected.FileOwner Then
		OwnerElement   = RowOwner.GetItems();
		
		// For new settings, another (not the active) user account can be chosen.
		ThisIsANewSetting = CommonClientServer.StructureProperty(
								AdditionalParameters,
								"NewSetting",
								False);
		If Not ThisIsANewSetting Then
			RowToRefresh = OwnerStringInTheCollection(OwnerElement, ValueSelected);
		EndIf;
		
		If RowToRefresh = Undefined Then
			RowToRefresh = OwnerElement.Add();
		EndIf;
	Else
		RowToRefresh = RowOwner;
	EndIf;
	
	FillPropertyValues(RowToRefresh, ValueSelected);
	
	If ValueSelected.HasFilterRules Then
		RowToRefresh.FilterRule =
			?( ValueIsFilled(ValueSelected.Description), ValueSelected.Description, NStr("en = 'Selected files';"));
	Else
		RowToRefresh.FilterRule = NStr("en = 'All files';");
	EndIf;
	
EndProcedure

&AtClient
Function OwnerStringInTheCollection(OwnerElement, ValueSelected)
	Var RowToRefresh;
	For Each SettingString In OwnerElement Do
			If SettingString.FileOwner = ValueSelected.FileOwner 
					And SettingString.Account = ValueSelected.Account Then
				RowToRefresh = SettingString;
				Break;
			EndIf;
	EndDo;
	
	Return RowToRefresh;
EndFunction

&AtServer
Procedure SetSynchronizationValueToSubordinateObjects(Val Synchronize)
	
	For Each RowID In Items.MetadataObjectsTree.SelectedRows Do
		TreeItem = MetadataObjectsTree.FindByID(RowID);
		If TreeItem.GetParent() <> Undefined Then
			SetObjectSynchronizationValue(TreeItem, Synchronize);
			Continue;
		EndIf;
		For Each TreeChildItem In TreeItem.GetItems() Do
			SetObjectSynchronizationValue(TreeChildItem, Synchronize);
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetObjectSynchronizationValue(SelectedObject, Val Synchronize)
	
	SelectedObject.Synchronize = Synchronize;
	SaveCurrentObjectSettings(
		SelectedObject.FileOwner,
		SelectedObject.FileOwnerType,
		Synchronize,
		SelectedObject.Account,
		SelectedObject.IsFile);
	
EndProcedure

&AtServer
Procedure SaveCurrentObjectSettings(FileOwner, FileOwnerType, Synchronize, Account, IsFile)
	
	Setting                   = InformationRegisters.FileSynchronizationSettings.CreateRecordManager();
	Setting.FileOwner     = FileOwner;
	Setting.FileOwnerType = FileOwnerType;
	Setting.Synchronize  = Synchronize;
	Setting.Account     = Account;
	Setting.IsFile           = IsFile;
	Setting.Write();
	
EndProcedure

&AtClient
Procedure OpenSettingsForm()
	
	CurrentData = Items.MetadataObjectsTree.CurrentData;
	If Not ValueIsFilled(CurrentData.FileOwner)
		Or Not ValueIsFilled(CurrentData.FileOwnerType) Then
		Return;
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("FileOwner",     CurrentData.FileOwner);
	Filter.Insert("FileOwnerType", CurrentData.FileOwnerType);
	Filter.Insert("Account",     CurrentData.Account);
	
	If ValueIsFilled(CurrentData.Account) Then
		ParametersOfKey = CommonClientServer.ValueInArray(Filter);
		RecordKey = New(Type("InformationRegisterRecordKey.FileSynchronizationSettings"), ParametersOfKey);
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", RecordKey);
		FormParameters.Insert("ForbidChangeAccount", True);
	Else
		FormParameters = Filter;
		FormParameters.Insert("IsFile", CurrentData.IsFile);
	EndIf;
	
	AdditionalParameters = New Structure();
	If CurrentData.DetailedInfoAvailable Then
		AdditionalParameters.Insert("Id", CurrentData.GetID());
	Else
		AdditionalParameters.Insert("Id", CurrentData.GetParent().GetID());
	EndIf;
	
	Notification = New NotifyDescription("SetFilterSettings", ThisObject, AdditionalParameters);
	OpenForm("InformationRegister.FileSynchronizationSettings.RecordForm", 
		FormParameters, ThisObject,,,, Notification);
	
EndProcedure

&AtServer
Function ChoiceFormPath(FileOwner)
	
	MetadataObject = Common.MetadataObjectByID(FileOwner);
	Return MetadataObject.FullName() + ".ChoiceForm";
	
EndFunction

&AtServer
Function ClearSettingData()
	
	ServerCallParameters = New Structure();
	
	BackgroundExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	BackgroundExecutionParameters.BackgroundJobDescription = NStr("en = 'Subsystem ""File management"": Disable file synchronization with cloud service';");
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground("FilesOperationsInternal.UnlockLockedFilesBackground",
		ServerCallParameters, BackgroundExecutionParameters);
	
	Return BackgroundJob;
	
EndFunction

// Parameters:
//   Result - Structure
//   AdditionalParameters - Structure:
//   * CurrentRow - Number
//
&AtClient
Procedure ClearSettingDataCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	If Result.Status <> "Completed2" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	ClearSettingDataAtServer(AdditionalParameters.CurrentRow);
	
EndProcedure

&AtClient
Procedure DeleteSettingItemCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SettingToDelete = MetadataObjectsTree.FindByID(Items.MetadataObjectsTree.CurrentRow);
		SettingToDelete.Synchronize = False;
		SetSynchronizationValueToSubordinateObjects(False);
		WriteCurrentSettings();
		
		CallAdditionalParameters = New Structure();
		CallAdditionalParameters.Insert("CurrentRow", Items.MetadataObjectsTree.CurrentRow);
		
		BackgroundJob = ClearSettingData();
		WaitSettings                                = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		WaitSettings.OutputIdleWindow           = True;
		Handler = New NotifyDescription("ClearSettingDataCompletion", ThisObject, CallAdditionalParameters);
		TimeConsumingOperationsClient.WaitCompletion(BackgroundJob, Handler, WaitSettings);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateFilesSynchronization(Command)
	
	TreeRow = Items.MetadataObjectsTree.CurrentData;
	If TreeRow = Undefined Or TreeRow.GetParent() = Undefined Then
		Return;
	EndIf;
	
	If TreeRow.DetailedInfoAvailable Then
		FileOwner = TreeRow.FileOwner;
		Id = TreeRow.GetID();
	Else
		FileOwner = TreeRow.GetParent().FileOwner;
		Id = TreeRow.GetParent().GetID();
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("FileOwner",     FileOwner);
	FormParameters.Insert("FileOwnerType", TreeRow.FileOwnerType);
	FormParameters.Insert("IsFile",           TreeRow.IsFile);
	FormParameters.Insert("NewSetting",    True);
	FormParameters.Insert("Id",     Id);
	
	Notification = New NotifyDescription("SetFilterSettings", ThisObject, FormParameters);
	OpenForm("InformationRegister.FileSynchronizationSettings.RecordForm", FormParameters, ThisObject,,,, Notification);
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob1()
	
	CancelJobExecution(BackgroundJobIdentifier);
	DetachIdleHandler("CheckBackgroundJobExecution");
	CurrentBackgroundJob        = "";
	BackgroundJobIdentifier = "";
	
EndProcedure

&AtServerNoContext
Procedure CancelJobExecution(BackgroundJobIdentifier)
	If ValueIsFilled(BackgroundJobIdentifier) Then
		TimeConsumingOperations.CancelJobExecution(BackgroundJobIdentifier);
	EndIf;
EndProcedure

&AtClient
Procedure CheckBackgroundJobExecution()
	
	If ValueIsFilled(BackgroundJobIdentifier) And Not JobCompleted(BackgroundJobIdentifier) Then
		AttachIdleHandler("CheckBackgroundJobExecution", 5, True);
	Else
		BackgroundJobIdentifier = "";
		CurrentBackgroundJob        = "";
		UpdateSyncFlags(MetadataObjectsTree.GetItems());
		ReadOnly = False;
		SetSynchronizeCommandVisibility();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateSyncFlags(Rows)
	
	For Each String In Rows Do
		
		String.PreviousSynchronization = String.Synchronize;
		If String.GetItems().Count() > 0 Then
			UpdateSyncFlags(String.GetItems());
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobIdentifier)
	Return TimeConsumingOperations.JobCompleted(BackgroundJobIdentifier);
EndFunction

&AtServer
Procedure RunScheduledJob()
	
	ScheduledJobMetadata1 = Metadata.ScheduledJobs.FilesSynchronization;
	
	Filter = New Structure;
	MethodName = ScheduledJobMetadata1.MethodName;
	Filter.Insert("MethodName", MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	SynchronizationBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If SynchronizationBackgroundJobs.Count() > 0 Then
		BackgroundJobIdentifier = SynchronizationBackgroundJobs[0].UUID;
	Else
		JobParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		JobParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Manual start: %1';"), ScheduledJobMetadata1.Synonym);
		JobResult = TimeConsumingOperations.ExecuteInBackground(ScheduledJobMetadata1.MethodName, New Structure, JobParameters);
		If ValueIsFilled(BackgroundJobIdentifier) Then
			BackgroundJobIdentifier = JobResult.JobID;
		EndIf;
	EndIf;
	
	CurrentBackgroundJob = "Synchronization";
	
EndProcedure

&AtClient
Procedure SetSynchronizeCommandVisibility()
	
	SubordinatePages = Items.FilesSynchronization.ChildItems;
	If IsBlankString(CurrentBackgroundJob) Then
		Items.FilesSynchronization.CurrentPage  = SubordinatePages.Synchronization;
		Items.MetadataObjectsTree.Enabled = True;
	Else
		Items.FilesSynchronization.CurrentPage  = SubordinatePages.BackgroundJobStatus;
		Items.MetadataObjectsTree.Enabled = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetScheduledJobParameter(ParameterName, ParameterValue)
	
	FilesOperationsInternal.SetFilesSynchronizationScheduledJobParameter(ParameterName, ParameterValue);
	
EndProcedure

&AtServer
Function GetScheduledJobParameter(ParameterName, DefaultValue)
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", Metadata.ScheduledJobs.FilesSynchronization);
	If Not Common.DataSeparationEnabled() Then
		JobParameters.Insert("MethodName", Metadata.ScheduledJobs.FilesSynchronization.MethodName);
	EndIf;
	
	SetPrivilegedMode(True);
	
	JobsList = ScheduledJobsServer.FindJobs(JobParameters);
	For Each Job In JobsList Do
		Return Job[ParameterName];
	EndDo;
	
	Return DefaultValue;
	
EndFunction

&AtServer
Function CurrentSchedule()
	Return GetScheduledJobParameter("Schedule", New JobSchedule);
EndFunction

&AtServer
Function AutomaticSynchronizationEnabled()
	Return GetScheduledJobParameter("Use", False);
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeObjectDescriptionSynonym");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("MetadataObjectsTree.Synchronize");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Font", StyleFonts.ImportantLabelFont);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeFilterRule");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Synchronize");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("Visible", False);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("MetadataObjectsTreeAccount");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Synchronize");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataObjectsTree.Account");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
EndProcedure

&AtServer
Procedure ClearSettingDataAtServer(Val CurrentRow)
	
	SettingToDelete = MetadataObjectsTree.FindByID(CurrentRow);
	
	If ValueIsFilled(SettingToDelete.Account) Then
		RecordManager                   = InformationRegisters.FileSynchronizationSettings.CreateRecordManager();
		RecordManager.FileOwner     = SettingToDelete.FileOwner;
		RecordManager.FileOwnerType = SettingToDelete.FileOwnerType;
		RecordManager.Account     = SettingToDelete.Account;
		RecordManager.IsFile           = SettingToDelete.IsFile;
		RecordManager.Read();
		RecordManager.Delete();
		
		SettingsItemParent = SettingToDelete.GetParent();
		If SettingsItemParent <> Undefined Then
			// You do not need to remove the parent setting from the tree; you only have to clear the custom fields.
			SettingToDelete.CloudServiceSubfolder = "";
			SettingToDelete.FilterRule            = "";
			SettingToDelete.Synchronize         = False;
			SettingToDelete.Account            = Undefined;
			If Not SettingToDelete.DetailedInfoAvailable Then
				SettingsItemParent.GetItems().Delete(SettingToDelete);
			EndIf;
		Else
			MetadataObjectsTree.GetItems().Delete(SettingToDelete);
		EndIf;
	EndIf;

EndProcedure

#EndRegion