///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
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

	If Not JobCompleted And Not ValueIsFilled(CurrentObject.ExecutionResult) Then
		Common.MessageToUser(
			NStr("en = 'Please tell why you decline the task.';"),, 
			"Object.ExecutionResult",, Cancel);
		Return;
	EndIf;
	
	// Pre-write the business process to ensure proper functioning of the route point handler.
	WriteBusinessProcessAttributes(CurrentObject);

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);
	If EventName = "Write_Job" Then
		If (Source = Object.BusinessProcess Or (TypeOf(Source) = Type("Array") And Source.Find(
			Object.BusinessProcess) <> Undefined)) Then
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
Procedure OnReadAtServer(CurrentObject)

	InitializeTheForm();
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

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
Procedure CompletionDateOnChange(Item)

	If Object.CompletionDate = BegOfDay(Object.CompletionDate) Then
		Object.CompletionDate = EndOfDay(Object.CompletionDate);
	EndIf;

EndProcedure

&AtClient
Procedure WriteAndCloseExecute()

	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject);

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
Procedure Completed2Execute(Command)

	JobCompleted = True;
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure Canceled(Command)

	JobCompleted = False;
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

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

&AtClient
Procedure ChangeJob(Command)

	If Modified Then
		Write();
	EndIf;
	ShowValue(, Object.BusinessProcess);

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

	Items.ChangeJob.Visible = (Object.Author = Users.CurrentUser());
	Performer = ?(ValueIsFilled(Object.Performer), Object.Performer, Object.PerformerRole);

	If AccessRight("Update", Metadata.BusinessProcesses.Job) Then
		Items.Completed2.Enabled = True;
		Items.TurnDown.Enabled = True;
	Else
		Items.Completed2.Enabled = False;
		Items.TurnDown.Enabled = False;
	EndIf;

EndProcedure

&AtServer
Procedure ReadBusinessProcessAttributes()

	TaskObject = FormAttributeToValue("Object");

	SetPrivilegedMode(True);
	JobObject = TaskObject.BusinessProcess.GetObject();
	JobCompleted = JobObject.Completed2;
	JobExecutionResult = JobObject.ExecutionResult;
	JobContent = JobObject.Content;

EndProcedure

&AtServer
Procedure WriteBusinessProcessAttributes(TaskObject)

	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(TaskObject.BusinessProcess);

		BusinessProcessObject = TaskObject.BusinessProcess.GetObject();
		LockDataForEdit(BusinessProcessObject.Ref);

		BusinessProcessObject.Completed2 = JobCompleted;
		BusinessProcessObject.Write(); // CAC:1327 The lock is set in the BusinessProcessesAndTasksServer.LockBusinessProcesses.

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