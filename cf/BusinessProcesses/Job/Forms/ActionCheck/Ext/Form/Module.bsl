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
	
	// For new objects, run the form initializer in "OnCreateAtServer".
	// For existing objects, in "OnReadAtServer".
	If Object.Ref.IsEmpty() Then
		InitializeTheForm();
	EndIf;

	CurrentUser = Users.CurrentUser();
	
	// StandardSubsystems.StoredFiles
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		HyperlinkParameters = ModuleFilesOperations.FilesHyperlink();
		HyperlinkParameters.Location = "CommandBar";
		HyperlinkParameters.Owner = "Object.BusinessProcess";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, HyperlinkParameters);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	BusinessProcessesAndTasksClient.UpdateAcceptForExecutionCommandsAvailability(ThisObject);
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	ExecuteTask = False;
	If Not (WriteParameters.Property("ExecuteTask", ExecuteTask) And ExecuteTask) Then
		Return;
	EndIf;

	If Not JobCompleted And Not JobConfirmed And Not ValueIsFilled(CurrentObject.ExecutionResult) Then
		Common.MessageToUser(
			NStr("en = 'Please tell why the task should be fixed.';"),, 
			"Object.ExecutionResult",, Cancel);
		Return;
	ElsIf Not JobCompleted And JobConfirmed And Not ValueIsFilled(CurrentObject.ExecutionResult) Then
		Common.MessageToUser(
			NStr("en = 'Please tell why the task is canceled.';"),, 
			"Object.ExecutionResult",, Cancel);
		Return;
	EndIf;
	
	// Pre-write the business process to ensure proper functioning of the route point handler.
	WriteBusinessProcessAttributes(CurrentObject);

EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	InitializeTheForm();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);

	If EventName = "Write_Job" Then
		If (Source = JobReference Or (TypeOf(Source) = Type("Array") 
			And Source.Find(JobReference) <> Undefined)) Then
			Read();
		EndIf;
	EndIf;
	
	// StandardSubsystems.StoredFiles
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.StoredFiles

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExecutionStartDateScheduledOnChange(Item)

	If Object.StartDate = BegOfDay(Object.StartDate) Then
		Object.StartDate = EndOfDay(Object.StartDate);
	EndIf;

EndProcedure

&AtClient
Procedure SubjectOfClick(Item, StandardProcessing)

	StandardProcessing = False;
	ShowValue(, Object.SubjectOf);

EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_PreviewFieldCheckDragging(Item, DragParameters, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item, DragParameters,
			StandardProcessing);
	EndIf;

EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndCloseExecute(Command)

	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject);

EndProcedure

&AtClient
Procedure Completed2(Command)

	JobConfirmed = True;
	JobCompleted = True;
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure Returned(Command)

	JobConfirmed = False;
	JobCompleted = False;
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure Canceled(Command)

	JobConfirmed = True;
	JobCompleted = False;
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure ChangeJobExecute(Command)

	If Modified Then
		Write();
	EndIf;
	ShowValue(, JobReference);

EndProcedure

&AtClient
Procedure More(Command)

	BusinessProcessesAndTasksClient.OpenAdditionalTaskInfo(Object.Ref);

EndProcedure

&AtClient
Procedure AcceptForExecution(Command)

	BusinessProcessesAndTasksClient.AcceptTaskForExecution(ThisObject, CurrentUser);

EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)

	BusinessProcessesAndTasksClient.CancelAcceptTaskForExecution(ThisObject);

EndProcedure

// StandardSubsystems.StoredFiles
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)

	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;

EndProcedure
// End StandardSubsystems.StoredFiles

#EndRegion

#Region Private

&AtServer
Procedure InitializeTheForm()

	InitialExecutionFlag = Object.Executed;
	ReadBusinessProcessAttributes();
	SetItemsState();

	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.ExecutionStartDateScheduledTime.Visible = UseDateAndTimeInTaskDeadlines;
	Items.CompletionDateTime.Visible = UseDateAndTimeInTaskDeadlines;
	BusinessProcessesAndTasksServer.SetDateFormat(Items.TaskDueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);

	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject, Object, Items.StateGroup,
		Items.CompletionDate);
	Items.ResultDetails.ReadOnly = Object.Executed;
	Performer = ?(ValueIsFilled(Object.Performer), Object.Performer, Object.PerformerRole);

	If AccessRight("Update", Metadata.BusinessProcesses.Job) Then
		Items.Completed2.Enabled = True;
		Items.Canceled.Enabled = True;
		Items.Returned.Enabled = True;
	Else
		Items.Completed2.Enabled = False;
		Items.Canceled.Enabled = False;
		Items.Returned.Enabled = False;
	EndIf;

EndProcedure

&AtServer
Procedure ReadBusinessProcessAttributes()

	TaskObject = FormAttributeToValue("Object");

	SetPrivilegedMode(True);
	JobObject = TaskObject.BusinessProcess.GetObject(); // BusinessProcessObject
	JobCompleted = JobObject.Completed2;
	JobReference = JobObject.Ref;
	JobConfirmed = JobObject.Accepted;
	JobExecutionResult = JobObject.ExecutionResult;
	JobContent = JobObject.Content;

EndProcedure

&AtServer
Procedure WriteBusinessProcessAttributes(TaskObject)

	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(TaskObject.BusinessProcess);

		JobObject = TaskObject.BusinessProcess.GetObject();
		LockDataForEdit(JobObject.Ref);

		JobObject.Completed2 = JobCompleted;
		JobObject.Accepted = JobConfirmed;
		JobObject.Write(); // ACC:1327 - A lock is set in BusinessProcessesAndTasksServer.LockBusinessProcesses.

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

&AtServer
Procedure SetItemsState()

	BusinessProcesses.Job.SetTaskFormItemsState(ThisObject);

EndProcedure

#EndRegion