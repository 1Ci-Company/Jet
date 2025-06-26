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
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// For new objects, run the form initializer in "OnCreateAtServer".
	// For existing objects, in "OnReadAtServer".
	If Object.Ref.IsEmpty() Then
		InitializeTheForm();
	EndIf;
	
	SetPrivilegedMode(True);
	AuthorAsString = String(Object.Author);
	
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
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	BusinessProcessesAndTasksClient.TaskFormNotificationProcessing(ThisObject, EventName, Parameter, Source);
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

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OpenTaskFormDecorationClick(Item)
	
	ShowValue(,Object.Ref);
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SubjectOfClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(,Object.SubjectOf);
	
EndProcedure

&AtClient
Procedure CompletionDateOnChange(Item)
	
	If Object.CompletionDate = BegOfDay(Object.CompletionDate) Then
		Object.CompletionDate = EndOfDay(Object.CompletionDate);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndCloseExecute(Command)
	
	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject);
	
EndProcedure

&AtClient
Procedure ExecutedExecute(Command)

	BusinessProcessesAndTasksClient.WriteAndCloseExecute(ThisObject, True);

EndProcedure

&AtClient
Procedure More(Command)
	
	BusinessProcessesAndTasksClient.OpenAdditionalTaskInfo(Object.Ref);
	
EndProcedure

// StandardSubsystems.AttachableCommands

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion

#Region Private

&AtServer
Procedure InitializeTheForm()
	
	If ValueIsFilled(Object.BusinessProcess) Then
		FormParameters = BusinessProcessesAndTasksServerCall.TaskExecutionForm(Object.Ref);
		HasBusinessProcessTaskForm = FormParameters.Property("FormName");
		Items.ExecutionFormGroup.Visible = HasBusinessProcessTaskForm;
		Items.Executed.Enabled = Not HasBusinessProcessTaskForm;
	Else
		Items.ExecutionFormGroup.Visible = False;
	EndIf;
	InitialExecutionFlag = Object.Executed;
	If Object.Ref.IsEmpty() Then
		Object.Importance = Enums.TaskImportanceOptions.Ordinary;
		Object.TaskDueDate = CurrentSessionDate();
	EndIf;
	
	Items.SubjectOf.Hyperlink = Object.SubjectOf <> Undefined And Not Object.SubjectOf.IsEmpty();
	SubjectString = Common.SubjectString(Object.SubjectOf);	
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.ExecutionStartDateScheduledTime.Visible = UseDateAndTimeInTaskDeadlines;
	Items.CompletionDateTime.Visible = UseDateAndTimeInTaskDeadlines;
	BusinessProcessesAndTasksServer.SetDateFormat(Items.TaskDueDate);
	BusinessProcessesAndTasksServer.SetDateFormat(Items.Date);
	
	BusinessProcessesAndTasksServer.TaskFormOnCreateAtServer(ThisObject, Object, 
		Items.StateGroup, Items.CompletionDate);
		
	If Users.IsExternalUserSession() Then
		Items.Author.Visible = False;
		Items.AuthorAsString.Visible = True;
		Items.Performer.OpenButton = False;
	EndIf;
	
	Items.Executed.Enabled = AccessRight("Update", Metadata.Tasks.PerformerTask);
	
EndProcedure

#EndRegion
