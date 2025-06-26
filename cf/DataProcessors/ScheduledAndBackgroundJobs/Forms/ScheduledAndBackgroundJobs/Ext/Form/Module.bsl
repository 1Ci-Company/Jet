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
	
	If Not Users.IsFullUser(, True) Then
		Raise(NStr("en = 'Insufficient access rights.';"), ErrorCategory.AccessViolation);
	EndIf;
	
	BlankID = String(CommonClientServer.BlankUUID());
	TextUndefined = ScheduledJobsInternal.TextUndefined();
	IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
	
	If Common.DebugMode() Then
		Items.ScheduledJobsTableContextMenuExecuteNotInBackground.Visible = True;
		Items.ScheduledJobsTableExecuteNotInBackground.Visible = True;
	EndIf;
	
	Items.ExternalResourcesOperationsLockGroup.Visible = ScheduledJobsServer.OperationsWithExternalResourcesLocked();
	
	If Common.IsMobileClient() Then
		
		Items.ScheduledJobsTableRefreshData.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.ScheduledJobsTableSetUpSchedule.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.HeaderGroup.ShowTitle = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not SettingsImported Then
		FillFormSettings(New Map);
	EndIf;
	
	ImportScheduledJobs();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ScheduledJobs" Then
		
		If ValueIsFilled(Parameter) Then
			ImportScheduledJobs(Parameter, True);
		Else
			AttachIdleHandler("ScheduledJobsDeferredUpdate", 0.1, True);
		EndIf;
	ElsIf EventName = "OperationsWithExternalResourcesAllowed" Then
		Items.ExternalResourcesOperationsLockGroup.Visible = False;
	ElsIf EventName = "Write_ConstantsSet" Then
		AttachIdleHandler("ScheduledJobsDeferredUpdate", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	FillFormSettings(Settings);
	
	SettingsImported = True;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure JobsOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.BackgroundJobs And Not BackgroundJobsPageOpened Then
		BackgroundJobsPageOpened = True;
		UpdateBackgroundJobsTableAtClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterKindByPeriodOnChange(Item)
	
	CurrentSessionDate = CurrentSessionDateAtServer();
	
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodFor.ReadOnly = Not (FilterKindByPeriod = 4);
	
	If FilterKindByPeriod = 0 Then
		FilterPeriodFrom  = '00010101';
		FilterPeriodFor = '00010101';
		Items.SettingArbitraryPeriod.Visible = False;
	ElsIf FilterKindByPeriod = 4 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		FilterPeriodFor = FilterPeriodFrom;
		Items.SettingArbitraryPeriod.Visible = True;
	Else
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate);
		Items.SettingArbitraryPeriod.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterByScheduledJobOnChange(Item)

	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
EndProcedure

&AtClient
Procedure ScheduledJobForFilterClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	ScheduledJobForFilterID = BlankID;
	
EndProcedure

&AtClient
Procedure ExternalResourcesOperationsLockNoteURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	Items.ExternalResourcesOperationsLockGroup.Visible = False;
	LockOfOperationsWithExternalResourcesURLProcessingAtServerNote();
	Notify("OperationsWithExternalResourcesAllowed");
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersBackgroundJobsTable

&AtClient
Procedure BackgroundJobsTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenBackgroundJob();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersScheduledJobsTable

&AtClient
Procedure ScheduledJobsTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field = "Predefined"
	 Or Field = "Use" Then
		
		AddCopyEditScheduledJob("Change");
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsTableBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	
	AddCopyEditScheduledJob(?(Copy, "Copy", "Add"));
	
EndProcedure

&AtClient
Procedure ScheduledJobsTableBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	AddCopyEditScheduledJob("Change");
	
EndProcedure

&AtClient
Procedure ScheduledJobsTableBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
	If Items.ScheduledJobsTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en = 'Select one scheduled job.';"));
		
	ElsIf Item.CurrentData.Predefined Then
		ShowMessageBox(, NStr("en = 'Predefined scheduled job cannot be deleted.';") );
	Else
		ShowQueryBox(
			New NotifyDescription("ScheduledJobsTableBeforeDeleteRowCompletion", ThisObject),
			NStr("en = 'Do you want to delete the scheduled job?';"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UpdateScheduledJobs(Command)
	
	If Items.Jobs.CurrentPage = Items.BackgroundJobs Then
		UpdateBackgroundJobsTableAtClient();
	Else
		ImportScheduledJobs();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobManually(Command)

	If Items.ScheduledJobsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.';"));
		Return;
	EndIf;
	
	SelectedRows = New Array;
	For Each SelectedRow In Items.ScheduledJobsTable.SelectedRows Do
		SelectedRows.Add(SelectedRow);
	EndDo;
	IndexOf = 0;
	
	SelectedJobsCount = SelectedRows.Count();
	ErrorMessageArray = New Array;
	
	For Each SelectedRow In SelectedRows Do
		CurrentData = ScheduledJobsTable.FindByID(SelectedRow);
		
		If CurrentData.Parameterized And SelectedJobsCount = 1 Then
			ShowMessageBox(, NStr("en = 'The scheduled job cannot be started manually.';"));
			Return;
		ElsIf CurrentData.Parameterized Then
			Continue;
		EndIf;
		
		ExecutionParameters = ExecuteScheduledJobManuallyAtServer(CurrentData.Id);
		If ExecutionParameters.Started1 Then
			
			ShowUserNotification(
				NStr("en = 'Scheduled job started';"), ,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1.
					|The scheduled job has been started in the background job ""%2"".';"),
					CurrentData.Description,
					String(ExecutionParameters.StartedAt)),
				PictureLib.ExecuteScheduledJobManually);
			
			BackgroundJobIDsOnManualExecution.Add(
				ExecutionParameters.BackgroundJobIdentifier,
				CurrentData.Description);
			
			AttachIdleHandler(
				"NotifyAboutManualScheduledJobCompletion", 0.1, True);
		ElsIf ExecutionParameters.ProcedureAlreadyExecuting Then
			ErrorMessageArray.Add(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The scheduled job ""%1"" is running in
					|the background job ""%2""  started on %3.';"),
					CurrentData.Description,
					ExecutionParameters.BackgroundJobPresentation,
					String(ExecutionParameters.StartedAt)));
		Else
			Items.ScheduledJobsTable.SelectedRows.Delete(
				Items.ScheduledJobsTable.SelectedRows.Find(SelectedRow));
		EndIf;
		
		IndexOf = IndexOf + 1;
	EndDo;
	
	ErrorsCount = ErrorMessageArray.Count();
	If ErrorsCount > 0 Then
		ErrorTextTitle = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The jobs are not completed (%1 out of %2)';"),
			Format(ErrorsCount, "NG="),
			Format(SelectedRows.Count(), "NG="));
		
		AllErrorsText = New TextDocument;
		AllErrorsText.AddLine(ErrorTextTitle + ":");
		For Each ThisErrorText In ErrorMessageArray Do
			AllErrorsText.AddLine("");
			AllErrorsText.AddLine(ThisErrorText);
		EndDo;
		
		If ErrorsCount > 5 Then
			Buttons = New ValueList;
			Buttons.Add(1, NStr("en = 'Show errors';"));
			Buttons.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(
				New NotifyDescription(
					"ExecuteScheduledJobManuallyCompletion", ThisObject, AllErrorsText),
				ErrorTextTitle, Buttons);
		Else
			ShowMessageBox(, TrimAll(AllErrorsText.GetText()));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetUpSchedule(Command)
	
	CurrentData = Items.ScheduledJobsTable.CurrentData;
	
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.';"));
	
	ElsIf Items.ScheduledJobsTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en = 'Select one scheduled job.';"));
	Else
		Dialog = New ScheduledJobDialog(
			GetSchedule(CurrentData.Id));
		
		Dialog.Show(New NotifyDescription(
			"OpenScheduleEnd", ThisObject, CurrentData));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableScheduledJob(Command)
	
	SetScheduledJobUsage(True);
	
EndProcedure

&AtClient
Procedure DisableScheduledJob(Command)
	
	SetScheduledJobUsage(False);
	
EndProcedure

&AtClient
Procedure OpenBackgroundJobAtClient(Command)
	
	OpenBackgroundJob();
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob(Command)
	
	If Items.BackgroundJobsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a background job.';"));
		Return;
	EndIf;

	CancelBackgroundJobAtServer(Items.BackgroundJobsTable.CurrentData.Id);
	ImportScheduledJobs(, True);
	
	ShowMessageBox(,
		NStr("en = 'You have canceled the background job, but the server will stop it with a delay.,
		           |You might need to update data on the client manually.';"));
	
EndProcedure

&AtClient
Procedure ShowAllJobs(Command)
	Value = Items.ScheduledJobsTableShowAllJobs.Check;
	Items.ScheduledJobsTableShowAllJobs.Check = Not Value;
	
	SetDisabledJobsVisibility(Not Value);
EndProcedure

&AtClient
Procedure ExecuteNotInBackground(Command)
	
	If Items.ScheduledJobsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a scheduled job.';"));
		Return;
	EndIf;
	
	SelectedRows = New Array;
	For Each SelectedRow In Items.ScheduledJobsTable.SelectedRows Do
		SelectedRows.Add(SelectedRow);
	EndDo;
	IndexOf = 0;
	SelectedJobsCount = SelectedRows.Count();
	
	For Each SelectedRow In SelectedRows Do
		CurrentData = ScheduledJobsTable.FindByID(SelectedRow);
		
		If CurrentData.Parameterized And SelectedJobsCount = 1 Then
			ShowMessageBox(, NStr("en = 'The scheduled job cannot be started manually.';"));
			Return;
		ElsIf CurrentData.Parameterized Then
			Continue;
		EndIf;
		
		RunScheduledJobNotInBackground(CurrentData.Id);
		IndexOf = IndexOf + 1;
	EndDo;
	
	ShowUserNotification(
		NStr("en = 'Scheduled job completed';"), ,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1.
			|The scheduled job has been completed manually.';"),
			CurrentData.Description),
		PictureLib.ExecuteScheduledJobManually);
	
EndProcedure

&AtServer
Procedure RunScheduledJobNotInBackground(JobID)
	
	ScheduledJobsInternal.RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	Job = ScheduledJobsServer.GetScheduledJob(JobID);
	MethodName = Job.Metadata.MethodName;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.BeforeRunScheduledJobNotInBackground(Job);
	EndIf;
	
	Common.SystemSettingsStorageSave("ScheduledJobs", MethodName, True);
	Common.ExecuteConfigurationMethod(MethodName, Job.Parameters);
	Common.SystemSettingsStorageSave("ScheduledJobs", MethodName, Undefined);
	
EndProcedure

&AtClient
Procedure EventLogEvents(Command)
	
	EventFilter = New Structure;
	If Items.Jobs.CurrentPage = Items.ScheduledJobs Then
		CurrentData = Items.ScheduledJobsTable.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("en = 'Select a scheduled job.';"));
			Return;
		EndIf;
		If Not ValueIsFilled(CurrentData.StartDate) And Not ValueIsFilled(CurrentData.EndDate)
			Or (CurrentData.StartDate = TextUndefined And CurrentData.EndDate = TextUndefined) Then
			ShowMessageBox(, NStr("en = 'The scheduled job has not run yet. There are no related records in the event log.';"));
			Return;
		EndIf;
		EventFilter.Insert("StartDate", CurrentData.StartDate);
		EventFilter.Insert("EndDate", CurrentData.EndDate);
		AddSelectionBySession(EventFilter, CurrentData.Id);
	ElsIf Items.Jobs.CurrentPage = Items.BackgroundJobs Then
		CurrentData = Items.BackgroundJobsTable.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("en = 'Select a background job.';"));
			Return;
		EndIf;
		EventFilter.Insert("StartDate", CurrentData.Begin);
		EventFilter.Insert("EndDate", CurrentData.End);
		AddSelectionBySession(EventFilter, CurrentData.ScheduledJobID);
	EndIf;
	
	EventLogClient.OpenEventLog(EventFilter, ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.End.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("BackgroundJobsTable.End");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Text", NStr("en = '<>';"));
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExecutionState.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobsTable.ExecutionState");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = '<undefined>';");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EndDate.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobsTable.EndDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = '<undefined>';");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StartDate.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobsTable.StartDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("en = '<undefined>';");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Use.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Description.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExecutionState.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EndDate.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StartDate.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UserName.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Predefined.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ScheduledJobsTable.JobName");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	ItemFilter.RightValue = DisabledJobs;
	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtServer
Procedure SetDisabledJobsVisibility(Show)
	
	Item = ConditionalAppearance.Items.Get(4);
	AppearanceItem = Item.Appearance.Items.Find("Visible");
	
	If Not Show Then
		Item.Filter.Items.Clear();
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue  = New DataCompositionField("ScheduledJobsTable.JobName");
		ItemFilter.ComparisonType   = DataCompositionComparisonType.InList;
		ItemFilter.RightValue = DisabledJobs;
		
		AppearanceItem.Use = True;
	Else
		Item.Filter.Items.Clear();
		AppearanceItem.Use = False;
	EndIf;
	
	ParenthesisPosition = StrFind(Items.ScheduledJobs.Title, " (");
	If ParenthesisPosition > 0 Then
		Items.ScheduledJobs.Title = Left(Items.ScheduledJobs.Title, ParenthesisPosition - 1);
	EndIf;
	ItemsOnList = ScheduledJobsTable.Count();
	If ItemsOnList > 0 Then
		If Not Show Then
			ItemsOnList = ItemsOnList - DisabledJobs.Count();
		EndIf;
		Items.ScheduledJobs.Title = Items.ScheduledJobs.Title + " (" + Format(ItemsOnList, "NG=") + ")";
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsTableBeforeDeleteRowCompletion(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		DeleteScheduledJobExecuteAtServer(
			Items.ScheduledJobsTable.CurrentData.Id);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobManuallyCompletion(Response, AllErrorsText) Export
	
	If Response = 1 Then
		AllErrorsText.Show();
	EndIf;
	
EndProcedure

// Parameters:
//  NewSchedule - JobSchedule
//  CurrentData   - FormDataCollectionItem:
//     * Id - String
//
&AtClient
Procedure OpenScheduleEnd(NewSchedule, CurrentData) Export

	If NewSchedule <> Undefined Then
		SetSchedule(CurrentData.Id, NewSchedule);
		ImportScheduledJobs(CurrentData.Id, True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSchedule(Val ScheduledJobID)
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.JobSchedule(
		ScheduledJobID);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val ScheduledJobID, Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(
		ScheduledJobID,
		Schedule);
	
EndProcedure

&AtServer
Procedure FillFormSettings(Val Settings)
	
	DefaultSettings = New Structure;
	
	// Background job filter setting.
	If Settings.Get("FilterByActiveState") = Undefined Then
		Settings.Insert("FilterByActiveState", True);
	EndIf;
	
	If Settings.Get("FilterByCompletedState") = Undefined Then
		Settings.Insert("FilterByCompletedState", True);
	EndIf;
	
	If Settings.Get("FilterByFailedState") = Undefined Then
		Settings.Insert("FilterByFailedState", True);
	EndIf;

	If Settings.Get("FilterByStateCanceled") = Undefined Then
		Settings.Insert("FilterByStateCanceled", True);
	EndIf;
	
	If Settings.Get("FilterByScheduledJob") = Undefined
	 Or Settings.Get("ScheduledJobForFilterID")   = Undefined Then
		Settings.Insert("FilterByScheduledJob", False);
		Settings.Insert("ScheduledJobForFilterID", BlankID);
	EndIf;
	
	// Set the period filter to "All time".
	// See also the radio button event handler "FilterKindByPeriodOnChange".
	If Settings.Get("FilterKindByPeriod") = Undefined
	 Or Settings.Get("FilterPeriodFrom")       = Undefined
	 Or Settings.Get("FilterPeriodFor")      = Undefined Then
		
		Settings.Insert("FilterKindByPeriod", 0);
		CurrentSessionDate = CurrentSessionDate();
		Settings.Insert("FilterPeriodFrom",  BegOfDay(CurrentSessionDate) - 3*3600);
		Settings.Insert("FilterPeriodFor", BegOfDay(CurrentSessionDate) + 9*3600);
	EndIf;
	
	For Each Setting In Settings Do
		DefaultSettings.Insert(Setting.Key, Setting.Value);
	EndDo;
	
	FillPropertyValues(ThisObject, DefaultSettings);
	
	// Setting visibility and accessibility.
	Items.SettingArbitraryPeriod.Visible = (FilterKindByPeriod = 4);
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodFor.ReadOnly = Not (FilterKindByPeriod = 4);
	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
	RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
	
EndProcedure

&AtClient
Procedure OpenBackgroundJob()
	
	If Items.BackgroundJobsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a background job.';"));
		Return;
	EndIf;
	
	PassedPropertyList =
	"Id,
	|Key,
	|Description,
	|MethodName,
	|State,
	|Begin,
	|End,
	|Placement,
	|MessagesToUserAndErrorDescription,
	|ScheduledJobID,
	|ScheduledJobDescription";
	CurrentDataValues = New Structure(PassedPropertyList);
	FillPropertyValues(CurrentDataValues, Items.BackgroundJobsTable.CurrentData);
	
	FormParameters = New Structure;
	FormParameters.Insert("Id", Items.BackgroundJobsTable.CurrentData.Id);
	FormParameters.Insert("BackgroundJobProperties", CurrentDataValues);
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.BackgroundJob", FormParameters, ThisObject);
	
EndProcedure

&AtServerNoContext
Function CurrentSessionDateAtServer()
	
	Return CurrentSessionDate();
	
EndFunction

&AtServer
Function ScheduledJobsFinishedNotification()
	
	CompletionNotifications = New Array;
	
	If BackgroundJobIDsOnManualExecution.Count() > 0 Then
		IndexOf = BackgroundJobIDsOnManualExecution.Count() - 1;
		
		SetPrivilegedMode(True);
		While IndexOf >= 0 Do
			
			NewUUID = New UUID(
				BackgroundJobIDsOnManualExecution[IndexOf].Value);
			Filter = New Structure;
			Filter.Insert("UUID", NewUUID);
			
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			
			If BackgroundJobArray.Count() = 1 Then
				FinishedAt = BackgroundJobArray[0].End;
				
				If ValueIsFilled(FinishedAt) Then
					
					CompletionNotifications.Add(
						New Structure(
							"ScheduledJobPresentation,
							|FinishedAt",
							BackgroundJobIDsOnManualExecution[IndexOf].Presentation,
							FinishedAt));
					
					BackgroundJobIDsOnManualExecution.Delete(IndexOf);
				EndIf;
			Else
				BackgroundJobIDsOnManualExecution.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		SetPrivilegedMode(False);
	EndIf;
	
	Return CompletionNotifications;
	
EndFunction

&AtClient
Procedure NotifyAboutManualScheduledJobCompletion()
	
	CompletionNotifications = ScheduledJobsFinishedNotification();
	
	For Each Notification In CompletionNotifications Do
		
		ShowUserNotification(
			NStr("en = 'Scheduled job procedure completed';"),
			,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1.
				           |The scheduled job has been completed in the background job ""%2"".';"),
				Notification.ScheduledJobPresentation,
				String(Notification.FinishedAt)),
			PictureLib.ExecuteScheduledJobManually);
	EndDo;
	
	If BackgroundJobIDsOnManualExecution.Count() > 0 Then
		
		AttachIdleHandler(
			"NotifyAboutManualScheduledJobCompletion", 2, True);
	Else
		ImportScheduledJobs(, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobChoiceList()
	
	Table = ScheduledJobsTable;
	List  = Items.ScheduledJobForFilter.ChoiceList;
	
	// Add a predefined item.
	If List.Count() = 0 Then
		List.Add(BlankID, TextUndefined);
	EndIf;
	
	IndexOf = 1;
	For Each Job In Table Do
		If IndexOf >= List.Count()
		 Or List[IndexOf].Value <> Job.Id Then
			// Insert a new job.
			List.Insert(IndexOf, Job.Id, Job.Description);
		Else
			List[IndexOf].Presentation = Job.Description;
		EndIf;
		IndexOf = IndexOf + 1;
	EndDo;
	
	// Delete excessive rows.
	While IndexOf < List.Count() Do
		List.Delete(IndexOf);
	EndDo;
	
	ListItem = List.FindByValue(ScheduledJobForFilterID);
	If ListItem = Undefined Then
		ScheduledJobForFilterID = BlankID;
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteScheduledJobManuallyAtServer(Val ScheduledJobID)
	
	Result = ScheduledJobsInternal.ExecuteScheduledJobManually(ScheduledJobID);
	Return Result;
	
EndFunction

&AtServer
Procedure CancelBackgroundJobAtServer(Val Id)
	
	ScheduledJobsInternal.CancelBackgroundJob(Id);
	UpdateBackgroundJobTable();
	
EndProcedure

&AtServer
Procedure DeleteScheduledJobExecuteAtServer(Val Id)
	
	String = ScheduledJobsTable.FindRows(New Structure("Id", Id))[0];
	ScheduledJobsServer.DeleteScheduledJob(Id);
	ScheduledJobsTable.Delete(ScheduledJobsTable.IndexOf(String));
	
EndProcedure

&AtClient
Procedure AddCopyEditScheduledJob(Val Action)
	
	FormParameters = New Structure;
	FormParameters.Insert("Action", Action);
	
	If Action <> "Add" Then
		If Items.ScheduledJobsTable.CurrentData = Undefined Then
			ShowMessageBox(, NStr("en = 'Select a scheduled job.';"));
			Return;
		Else
			FormParameters.Insert("Id", Items.ScheduledJobsTable.CurrentData.Id);
		EndIf;
	EndIf;
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJob", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ScheduledJobsDeferredUpdate()
	
	ImportScheduledJobs(, True);
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshAutomaticPeriod(Form, CurrentSessionDate)
	
	If Form.FilterKindByPeriod = 1 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 3*3600;
		Form.FilterPeriodFor = BegOfDay(CurrentSessionDate) + 9*3600;
		
	ElsIf Form.FilterKindByPeriod = 2 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 24*3600;
		Form.FilterPeriodFor = EndOfDay(Form.FilterPeriodFrom);
		
	ElsIf Form.FilterKindByPeriod = 3 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		Form.FilterPeriodFor = EndOfDay(Form.FilterPeriodFrom);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetScheduledJobUsage(isEnabled)
	
	For Each SelectedRow In Items.ScheduledJobsTable.SelectedRows Do
		CurrentData = ScheduledJobsTable.FindByID(SelectedRow);
		ScheduledJobsServer.ChangeScheduledJob(CurrentData.Id,
			New Structure("Use", isEnabled));
		CurrentData.Use = isEnabled;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure LockOfOperationsWithExternalResourcesURLProcessingAtServerNote()
	ScheduledJobsServer.UnlockOperationsWithExternalResources();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Background import of scheduled jobs.

&AtClient
Procedure ImportScheduledJobs(JobID = Undefined, UpdateSilently = False)
	
	If Not UpdateSilently Then
		Items.ScheduledJobsDeferredImportPages.CurrentPage = Items.ScheduledJobsImportPage;
	EndIf;
	If Items.ScheduledJobsTable.CurrentData <> Undefined Then
		CurrentRowID = Items.ScheduledJobsTable.CurrentData.Id;
	EndIf;
	Result = ScheduledJobsImport(JobID);
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CallbackOnCompletion = New NotifyDescription("ImportScheduledJobsCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitCompletion(Result, CallbackOnCompletion, IdleParameters);
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ImportScheduledJobsCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		ProcessResult(Result);
		Items.ScheduledJobsDeferredImportPages.CurrentPage = Items.ScheduledJobsPage;
	ElsIf Result.Status = "Error" Then
		Items.ScheduledJobsDeferredImportPages.CurrentPage = Items.ScheduledJobsPage;
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	EndIf;
	
EndProcedure

&AtServer
Function ScheduledJobsImport(JobID)
	
	If ExecutionResult <> Undefined
		And ValueIsFilled(ExecutionResult.JobID) Then
		TimeConsumingOperations.CancelJobExecution(ExecutionResult.JobID);
	EndIf;
	
	TimeConsumingOperationParameters = TimeConsumingOperationParameters();
	TimeConsumingOperationParameters.Insert("ScheduledJobID", JobID);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	If JobID <> Undefined Then
		ExecutionParameters.RunNotInBackground1 = True;
	EndIf;
	ExecutionParameters.WaitCompletion = 0; // Run immediately.
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Generate scheduled job list';");
	
	Return TimeConsumingOperations.ExecuteInBackground("ScheduledJobsInternal.GenerateScheduledJobsTable",
		TimeConsumingOperationParameters, ExecutionParameters);
	
EndFunction

&AtServer
Function TimeConsumingOperationParameters()
	
	OperationParametersList = New Structure;
	OperationParametersList.Insert("Table", FormAttributeToValue("ScheduledJobsTable"));
	OperationParametersList.Insert("DisabledJobs", DisabledJobs.Copy());
	
	Return OperationParametersList;
	
EndFunction

&AtServer
Procedure ProcessResult(JobParameters)
	
	Result = GetFromTempStorage(JobParameters.ResultAddress);
	DisabledJobs.Clear();
	For Each ListItem In Result.DisabledJobs Do
		DisabledJobs.Add(ListItem.Value);
	EndDo;
	
	SetDisabledJobsVisibility(Items.ScheduledJobsTableShowAllJobs.Check);
	
	ValueToFormAttribute(Result.Table, "ScheduledJobsTable");
	
	Items.ScheduledJobsTable.Refresh();
	
	// Positioning of the scheduled jobs list.
	If ValueIsFilled(CurrentRowID) Then
		SearchResult = ScheduledJobsTable.FindRows(New Structure("Id", CurrentRowID));
		If SearchResult.Count() = 1 Then
			String = SearchResult[0];
			Items.ScheduledJobsTable.CurrentRow = String.GetID();
		EndIf;
	EndIf;
	
	ParenthesisPosition = StrFind(Items.ScheduledJobs.Title, " (");
	If ParenthesisPosition > 0 Then
		Items.ScheduledJobs.Title = Left(Items.ScheduledJobs.Title, ParenthesisPosition - 1);
	EndIf;
	ItemsOnList = ScheduledJobsTable.Count();
	If ItemsOnList > 0 Then
		If Not Items.ScheduledJobsTableShowAllJobs.Check Then
			ItemsOnList = ItemsOnList - DisabledJobs.Count();
		EndIf;
		Items.ScheduledJobs.Title = Items.ScheduledJobs.Title + " (" + Format(ItemsOnList, "NG=") + ")";
	EndIf;
	
	UpdateScheduledJobChoiceList();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Background import of background jobs.

&AtClient
Procedure UpdateBackgroundJobsTableAtClient()
	
	Result = GenerateBackgroundJobsTableInBackground();
	If Result.Status = "Completed2" Or Result.Status = "Error" Then
		Return;
	EndIf;
	
	Items.HeaderGroup.Enabled = False;
	Items.BackgroundJobsDeferredImportPages.CurrentPage = Items.TimeConsumingOperationPage;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CallbackOnCompletion = New NotifyDescription("UpdateBackgroundJobTableCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(Result, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function GenerateBackgroundJobsTableInBackground()
	
	Filter = BackgroundJobsFilter();
	TransmittedParameters = New Structure;
	TransmittedParameters.Insert("Filter", Filter);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Scheduled jobs. Update background job list';");
	
	Result = TimeConsumingOperations.ExecuteInBackground("ScheduledJobsInternal.FillBackgroundJobsPropertiesTableInBackground",
		TransmittedParameters, ExecutionParameters);
		
	If Result.Status = "Completed2" Then
		UpdateBackgroundJobTable(Result.ResultAddress);
	ElsIf Result.Status = "Error" Then
		Raise Result.BriefErrorDescription;
	EndIf;
	
	Return Result;
		
EndFunction

&AtServer
Function BackgroundJobsFilter()
	
	// 1. Prepare filter.
	Filter = New Structure;
	
	// 1.1. Add filter by state.
	StateArray = New Array;
	
	If FilterByActiveState Then 
		StateArray.Add(BackgroundJobState.Active);
	EndIf;
	
	If FilterByCompletedState Then 
		StateArray.Add(BackgroundJobState.Completed);
	EndIf;
	
	If FilterByFailedState Then 
		StateArray.Add(BackgroundJobState.Failed);
	EndIf;
	
	If FilterByStateCanceled Then 
		StateArray.Add(BackgroundJobState.Canceled);
	EndIf;
	
	If StateArray.Count() <> 4 Then
		If StateArray.Count() = 1 Then
			Filter.Insert("State", StateArray[0]);
		Else
			Filter.Insert("State", StateArray);
		EndIf;
	EndIf;
	
	// 1.2. Add filter by scheduled job.
	If FilterByScheduledJob Then
		Filter.Insert(
				"ScheduledJobID",
				?(ScheduledJobForFilterID = BlankID,
				"",
				ScheduledJobForFilterID));
	EndIf;
	
	// 1.3. Add filter by period.
	If FilterKindByPeriod <> 0 Then
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
		Filter.Insert("Begin", FilterPeriodFrom);
		Filter.Insert("End",  FilterPeriodFor);
	EndIf;
	
	Return Filter;
	
EndFunction

&AtServer
Procedure UpdateBackgroundJobTable(ResultAddress = Undefined)
	
	// Refreshing the background job list.
	
	If ResultAddress <> Undefined Then
		DataFromStorage = GetFromTempStorage(ResultAddress);
		CurrentTable = DataFromStorage.PropertiesTable;
	Else
		Filter = BackgroundJobsFilter();
		CurrentTable = ScheduledJobsInternal.BackgroundJobsProperties(Filter);
	EndIf;
	
	Table = BackgroundJobsTable;
	IndexOf = 0;
	For Each Job In CurrentTable Do
		
		If IndexOf >= Table.Count()
		 Or Table.Get(IndexOf).Id <> Job.Id Then
			// Insert a new job.
			ToUpdate = Table.Insert(IndexOf);
			// Assign a UUID.
			ToUpdate.Id = Job.Id;
		Else
			ToUpdate = Table[IndexOf];
		EndIf;
		
		FillPropertyValues(ToUpdate, Job);
		
		// Setting the scheduled job description from the ScheduledJobTable collection.
		If ValueIsFilled(ToUpdate.ScheduledJobID) Then
			
			Rows = ScheduledJobsTable.FindRows(
				New Structure("Id", ToUpdate.ScheduledJobID));
			
			ToUpdate.ScheduledJobDescription
				= ?(Rows.Count() = 0, NStr("en = '<not found>';"), Rows[0].Description);
		Else
			ToUpdate.ScheduledJobDescription  = TextUndefined;
			ToUpdate.ScheduledJobID = TextUndefined;
		EndIf;
		
		// Getting error details.
		ToUpdate.MessagesToUserAndErrorDescription 
			= ScheduledJobsInternal.BackgroundJobMessagesAndErrorDescriptions(
				ToUpdate.Id, Job);
		
		// Index increase.
		IndexOf = IndexOf + 1;
	EndDo;
	
	// Deleting unnecessary rows.
	While IndexOf < Table.Count() Do
		Table.Delete(Table.Count()-1);
	EndDo;
	
	Items.BackgroundJobsTable.Refresh();
	
	ParenthesisPosition = StrFind(Items.BackgroundJobs.Title, " (");
	If ParenthesisPosition > 0 Then
		Items.BackgroundJobs.Title = Left(Items.BackgroundJobs.Title, ParenthesisPosition - 1);
	EndIf;
	ItemsOnList = BackgroundJobsTable.Count();
	If ItemsOnList > 0 Then
		Items.BackgroundJobs.Title = Items.BackgroundJobs.Title + " (" + Format(ItemsOnList, "NG=") + ")";
	EndIf;
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure UpdateBackgroundJobTableCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed2" Then
		UpdateBackgroundJobTable(Result.ResultAddress);
		Items.HeaderGroup.Enabled = True;
		Items.BackgroundJobsDeferredImportPages.CurrentPage = Items.BackgroundJobsPage;
	ElsIf Result.Status = "Error" Then
		Items.HeaderGroup.Enabled = True;
		Items.BackgroundJobsDeferredImportPages.CurrentPage = Items.BackgroundJobsPage;
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure AddSelectionBySession(Filter, Id)
	
	If Id = ScheduledJobsInternal.TextUndefined() Then
		Return;
	EndIf;
	
	FilterJobs = New Structure;
	FilterJobs.Insert("UUID", New UUID(Id));
	FoundJobs = ScheduledJobsServer.FindJobs(FilterJobs);
	ScheduledJob = Undefined;
	For Each FoundJob In FoundJobs Do
		ScheduledJob = FoundJob;
		Break;
	EndDo;
	
	If ScheduledJob = Undefined Then
		Return;
	EndIf;
	
	FilterCopy = Common.CopyRecursive(Filter); // Structure
	FilterCopy.Insert("Metadata", ScheduledJob.Metadata.FullName());
	
	Result = New ValueTable;
	UnloadEventLog(Result, FilterCopy, , , 1);
	For Each String In Result Do
		Sessions = New ValueList;
		Sessions.Add(String.Session);
		Filter.Insert("Session", Sessions);
	EndDo;
	
EndProcedure

#EndRegion
