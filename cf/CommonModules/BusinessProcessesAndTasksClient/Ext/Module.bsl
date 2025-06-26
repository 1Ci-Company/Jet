///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Commands for business processes.

// Marks the specified business processes as suspended.
//
// Parameters:
//  CommandParameter  - Array of DefinedType.BusinessProcess
//                   - DefinedType.BusinessProcess
//
Procedure Stop(Val CommandParameter) Export
	
	QueryText = "";
	TaskCount1 = 0;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("en = 'No business process is selected.';"));
			Return;
		EndIf;
		
		If CommandParameter.Count() = 1 And TypeOf(CommandParameter[0]) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("en = 'No business process is selected.';"));
			Return;
		EndIf;
		
		TaskCount1 = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			If TaskCount1 > 0 Then
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Business process ""%1"" and all its unfinished tasks (%2) will be suspended. Continue?';"), 
					String(CommandParameter[0]), TaskCount1);
			Else
				QueryText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Business process ""%1"" will be suspended. Continue?';"), 
					String(CommandParameter[0]));
			EndIf;
		Else
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Business processes (%1) and all their unfinished tasks (%2) will be suspended. Continue?';"), 
				CommandParameter.Count(), TaskCount1);
		EndIf;
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("en = 'No business process is selected';"));
			Return;
		EndIf;
		
		TaskCount1 = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		If TaskCount1 > 0 Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Business process ""%1"" and all its unfinished tasks (%2) will be suspended. Continue?';"), 
				String(CommandParameter), TaskCount1);
		Else
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Business process ""%1"" will be suspended. Continue?';"), 
				String(CommandParameter));
		EndIf;
		
	EndIf;
	
	Notification = New NotifyDescription("StopCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Suspend business process';"));
	
EndProcedure

// Marks the specified business process as suspended.
//  The procedure is called from a business process form.
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects - a business process form, where:
//   * Object - DefinedType.BusinessProcessObject - business process. 
//
Procedure StopBusinessProcessFromObjectForm(Form) Export
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Suspended");
	ClearMessages();
	Form.Write();
	ShowUserNotification(
		NStr("en = 'The business process is suspended.';"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.DialogInformation);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified business processes as active.
//
// Parameters:
//  CommandParameter - Array of DefinedType.BusinessProcess
//                  - DynamicListGroupRow
//                  - DefinedType.BusinessProcess - business process.
//
Procedure Activate(Val CommandParameter) Export
	
	QueryText = "";
	TaskCount1 = 0;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("en = 'No business process is selected.';"));
			Return;
		EndIf;
		
		If CommandParameter.Count() = 1 And TypeOf(CommandParameter[0]) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("en = 'No business process is selected.';"));
			Return;
		EndIf;
		
		TaskCount1 = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Business process ""%1"" and its tasks (%2) will be active. Continue?';"),
				String(CommandParameter[0]), TaskCount1);
		Else		
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Business processes (%1) and their tasks (%2) will be active. Continue?';"),
				CommandParameter.Count(), TaskCount1);
		EndIf;
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("en = 'No business process is selected.';"));
			Return;
		EndIf;
		
		TaskCount1 = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Business process ""%1"" and its tasks (%2) will be active. Continue?';"),
			String(CommandParameter), TaskCount1);
			
	EndIf;
	
	Notification = New NotifyDescription("ActivateCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Suspend business process';"));
	
EndProcedure

// Marks the specified business processes as active.
// The procedure is intended for calling from a business process form.
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects - a business process form, where:
//   * Object - DefinedType.BusinessProcessObject - business process.
//
Procedure ContinueBusinessProcessFromObjectForm(Form) Export
	
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Running");
	ClearMessages();
	Form.Write();
	ShowUserNotification(
		NStr("en = 'The business process is activated';"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.DialogInformation);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified task as accepted for execution.
//
// Parameters:
//  TaskArray - Array of TaskRef.PerformerTask
//
Procedure AcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.AcceptTasksForExecution(TaskArray);
	If TaskArray.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	
	TaskValueType = Undefined;
	For Each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;
	EndDo;
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;
	
EndProcedure

// Marks the specified task as accepted for execution.
//
// Parameters:
//  Form               - ClientApplicationForm
//                      - ManagedFormExtensionForObjects - a task form, where:
//   * Object - TaskObject - task.
//  CurrentUser - CatalogRef.ExternalUsers
//                      - CatalogRef.Users - Reference to the current user.
//                                                        
//
Procedure AcceptTaskForExecution(Form, CurrentUser) Export
	
	Form.Object.AcceptedForExecution = True;
	
	// Keep "AcceptForExecutionDate" empty. 
	// It will be initialized with the current session date before writing the task.
	Form.Object.AcceptForExecutionDate = Date('00010101');
	If Not ValueIsFilled(Form.Object.Performer) Then
		Form.Object.Performer = CurrentUser;
	EndIf;
	
	ClearMessages();
	Form.Write();
	UpdateAcceptForExecutionCommandsAvailability(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified tasks as not accepted for execution.
//
// Parameters:
//  TaskArray - Array of TaskRef.PerformerTask
//
Procedure CancelAcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.CancelAcceptTasksForExecution(TaskArray);
	
	If TaskArray.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	
	TaskValueType = Undefined;
	For Each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;
	EndDo;
	
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;
	
EndProcedure

// Marks the specified task as not accepted for execution.
//
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForObjects - a task form, where:
//   * Object - TaskObject - task.
//
Procedure CancelAcceptTaskForExecution(Form) Export
	
	Form.Object.AcceptedForExecution      = False;
	Form.Object.AcceptForExecutionDate = "00010101000000";
	If Not Form.Object.PerformerRole.IsEmpty() Then
		Form.Object.Performer = Undefined;
	EndIf;
	
	ClearMessages();
	Form.Write();
	UpdateAcceptForExecutionCommandsAvailability(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Sets availability of commands for accepting for execution.
//
// Parameters:
//  Form - ClientApplicationForm - a task form, where:
//   * Items - FormAllItems - form items. The form contains:
//     ** FormAcceptForExecution - TextBox - a command button on the form.
//     ** FormCancelAcceptForExecution - TextBox - a command button on the form. 
//
Procedure UpdateAcceptForExecutionCommandsAvailability(Form) Export
	
	If Form.Object.AcceptedForExecution = True Then
		Form.Items.FormAcceptForExecution.Enabled = False;
		
		If Form.Object.Executed Then
			Form.Items.FormCancelAcceptForExecution.Enabled = False;
		Else
			Form.Items.FormCancelAcceptForExecution.Enabled = True;
		EndIf;
		
	Else	
		Form.Items.FormAcceptForExecution.Enabled = True;
		Form.Items.FormCancelAcceptForExecution.Enabled = False;
	EndIf;
		
EndProcedure

// Opens the form to set up deferred start of a business process.
//
// Parameters:
//  BusinessProcess  - DefinedType.BusinessProcess
//  TaskDueDate - Date
//
Procedure SetUpDeferredStart(BusinessProcess, TaskDueDate) Export
	
	If BusinessProcess.IsEmpty() Then
		WarningText = 
			NStr("en = 'Cannot set up deferred start for an unsaved process.';");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
		
	FormParameters = New Structure;
	FormParameters.Insert("BusinessProcess", BusinessProcess);
	FormParameters.Insert("TaskDueDate", TaskDueDate);
	
	OpenForm(
		"InformationRegister.ProcessesToStart.Form.DeferredProcessStartSetup",
		FormParameters,,,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions.

// Standard notification handler for task execution forms.
//  The procedure is intended for calling from the NotificationProcessing form event handler.
//
// Parameters:
//  Form      - ClientApplicationForm - a task execution form, where:
//   * Object - TaskObject  - Object's task.
//  EventName - String       - Event name.
//  Parameter   - Arbitrary - an event parameter.
//  Source   - Arbitrary - an event source.
//
Procedure TaskFormNotificationProcessing(Form, EventName, Parameter, Source) Export
	
	If EventName = "Write_PerformerTask" 
		And Not Form.Modified 
		And (Source = Form.Object.Ref Or (TypeOf(Source) = Type("Array") 
		And Source.Find(Form.Object.Ref) <> Undefined)) Then
		If Parameter.Property("Forwarded") Then
			Form.Close();
		Else
			Form.Read();
		EndIf;
	EndIf;
	
EndProcedure

// Standard BeforeAddRow handler for task lists.
//  The procedure is intended for calling from the BeforeAddRow form table event handler.
//
// Parameters:
//  Form        - ClientApplicationForm - task form.
//  Item      - FormTable - form table items.
//  Cancel        - Boolean - shows whether adding objects is canceled. If the parameter is set to
//                          True in the handler, the object is not added.
//  Copy  - Boolean - defines the copy mode. If True, the row is copied. 
//  Parent     - Undefined
//               - CatalogRef
//               - ChartOfAccountsRef - a reference to the item used
//                                    as a parent on adding.
//  Group       - Boolean - shows whether a group is added. True - a group is added. 
//
Procedure TaskListBeforeAddRow(Form, Item, Cancel, Copy, Parent, Group) Export
	
	If Copy Then
		Task = Item.CurrentRow;
		If Not ValueIsFilled(Task) Then
			Return;
		EndIf;
		FormParameters = New Structure("Basis", Task);
	EndIf;
	CreateJob(Form, FormParameters);
	Cancel = True;
	
EndProcedure

// Writes and closes the task execution form.
//
// Parameters:
//  Form  - ClientApplicationForm - a task execution form, where:
//   * Object - TaskObject - a business process task.
//  ExecuteTask  - Boolean - a task is written in the execution mode.
//  NotificationParameters - Structure - Additional notification parameters.
//
// Returns:
//   Boolean   - True if the task is written.
//
Function WriteAndCloseExecute(Form, ExecuteTask = False, NotificationParameters = Undefined) Export
	
	ClearMessages();
	
	NewObject = Form.Object.Ref.IsEmpty();
	NotificationText1 = "";
	If NotificationParameters = Undefined Then
		NotificationParameters = New Structure;
	EndIf;
	If Not Form.InitialExecutionFlag And ExecuteTask Then
		If Not Form.Write(New Structure("ExecuteTask", True)) Then
			Return False;
		EndIf;
		NotificationText1 = NStr("en = 'The task is completed';");
	Else
		If Not Form.Write() Then
			Return False;
		EndIf;
		NotificationText1 = ?(NewObject, NStr("en = 'The task is created';"), NStr("en = 'The task is changed';"));
	EndIf;
	
	Notify("Write_PerformerTask", NotificationParameters, Form.Object.Ref);
	ShowUserNotification(NotificationText1,
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.DialogInformation);
	Form.Close();
	Return True;
	
EndFunction

// Opens a new job form.
//
// Parameters:
//  OwnerForm  - ClientApplicationForm - a form that must be the owner for the form being opened.
//  FormParameters - Structure - parameters of the form to be opened.
//
Procedure CreateJob(Val OwnerForm = Undefined, Val FormParameters = Undefined) Export
	
	OpenForm("BusinessProcess.Job.ObjectForm", FormParameters, OwnerForm);
	
EndProcedure	

// Opens a form for forwarding one or several tasks to another assignee.
//
// Parameters:
//  RedirectedTasks_SSLs - Array of TaskRef.PerformerTask
//  OwnerForm - ClientApplicationForm - a form that must be the owner for the task forwarding
//                                               form being opened.
//
Procedure ForwardTasks(RedirectedTasks_SSLs, OwnerForm) Export
	
	If RedirectedTasks_SSLs = Undefined Then
		ShowMessageBox(,NStr("en = 'Tasks are not selected.';"));
		Return;
	EndIf;
		
	TasksCanBeForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks(
		RedirectedTasks_SSLs, Undefined, True);
	If Not TasksCanBeForwarded And RedirectedTasks_SSLs.Count() = 1 Then
		ShowMessageBox(,NStr("en = 'Cannot forward a task that is already completed or was sent to another user.';"));
		Return;
	EndIf;
		
	Notification = New NotifyDescription("ForwardTasksCompletion", ThisObject, RedirectedTasks_SSLs);
	OpenForm("Task.PerformerTask.Form.ForwardTasks",
		New Structure("Task,TaskCount,FormCaption", 
		RedirectedTasks_SSLs[0], RedirectedTasks_SSLs.Count(), 
		?(RedirectedTasks_SSLs.Count() > 1, NStr("en = 'Forward tasks';"), 
			NStr("en = 'Forward task';"))), 
		OwnerForm,,,,Notification);
		
EndProcedure

// Opens the form with additional information about the task.
//
// Parameters:
//  TaskRef - TaskRef.PerformerTask
// 
Procedure OpenAdditionalTaskInfo(Val TaskRef) Export
	
	OpenForm("Task.PerformerTask.Form.More", 
		New Structure("Key", TaskRef));
	
EndProcedure

#EndRegion

#Region Internal

Procedure OpenRolesAndTaskPerformersList() Export
	
	OpenForm("InformationRegister.TaskPerformers.Form.RolesAndTaskPerformers");
	
EndProcedure

// Opens the assignee role selection form.
// 
// Parameters:
//  FormParameters - See PerformerRoleChoiceFormParameters
//  Owner - Undefined
//           - ClientApplicationForm - The form where the assignee selection form opens.
//
Procedure OpenPerformerRoleChoiceForm(FormParameters, Owner) Export

	OpenForm("CommonForm.SelectPerformerRole", FormParameters, Owner);

EndProcedure

// The form opening parameters.
// 
// Parameters:
//  PerformerRole - CatalogRef.PerformerRoles - A role for role-based assignment of the task to business process members. 
//  MainAddressingObject - Arbitrary - The main business object for forwarding the task.
//  AdditionalAddressingObject - Arbitrary - An additional business object for forwarding the task.
// 
// Returns:
//  Structure:
//   * PerformerRole  - CatalogRef.PerformerRoles - A role for role-based assignment of the task to business process members.
//   * MainAddressingObject - Arbitrary - The main business object for forwarding the task.
//   * AdditionalAddressingObject - Arbitrary - An additional business object for forwarding the task.
//   * SelectAddressingObject - Boolean - If set to "True", the main business object is selected in the list.
// 
Function PerformerRoleChoiceFormParameters(PerformerRole, MainAddressingObject = Undefined, 
		AdditionalAddressingObject = Undefined) Export

	FormParameters = New Structure;
	FormParameters.Insert("PerformerRole",               PerformerRole);
	FormParameters.Insert("MainAddressingObject",       MainAddressingObject);
	FormParameters.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	FormParameters.Insert("SelectAddressingObject",         False);
	
	Return FormParameters;

EndFunction

#EndRegion

#Region Private

Procedure OpenBusinessProcess(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	If List.CurrentData.BusinessProcess = Undefined Then
		ShowMessageBox(,NStr("en = 'Business process of the selected task is not specified.';"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.BusinessProcess);
EndProcedure

Procedure OpenTaskSubject(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	If List.CurrentData.SubjectOf = Undefined Then
		ShowMessageBox(,NStr("en = 'Subject of the selected task is not specified.';"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.SubjectOf);
EndProcedure

// Standard handler DeletionMark used in the lists of business processes.
// The procedure is intended for calling from the DeletionMark list event handler.
//
// Parameters:
//   List  - FormTable - a form control (form table) with a list of business processes.
//
Procedure BusinessProcessesListDeletionMark(List) Export
	
	SelectedRows = List.SelectedRows;
	If SelectedRows = Undefined Or SelectedRows.Count() <= 0 Then
		ShowMessageBox(,NStr("en = 'Cannot run the command for the object.';"));
		Return;
	EndIf;
	Notification = New NotifyDescription("BusinessProcessesListDeletionMarkCompletion", ThisObject, List);
	ShowQueryBox(Notification, NStr("en = 'Change deletion mark?';"), QuestionDialogMode.YesNo);
	
EndProcedure

// Opens the assignee selection form.
//
// Parameters:
//   PerformerItem - FormField - a form item where an assignee is selected. 
//      The form item is specified as the owner of the assignee selection form.
//   PerformerAttribute - CatalogRef.Users - a previously selected Assignee value.
//      Used to set the current row in the assignee selection form.
//   SimpleRolesOnly - Boolean - If True, only roles without business objects 
//      are used in the selection.
//   NoExternalRoles - Boolean - If True, only roles without the ExternalRole flag
//      are used in the selection.
//
Procedure SelectPerformer(PerformerItem, PerformerAttribute, SimpleRolesOnly = False, NoExternalRoles = False) Export 
	
	StandardProcessing = True;
	BusinessProcessesAndTasksClientOverridable.OnPerformerChoice(PerformerItem, PerformerAttribute, 
		SimpleRolesOnly, NoExternalRoles, StandardProcessing);
	If Not StandardProcessing Then
		Return;
	EndIf;
			
	FormParameters = New Structure("Performer, SimpleRolesOnly, NoExternalRoles", 
		PerformerAttribute, SimpleRolesOnly, NoExternalRoles);
	OpenForm("CommonForm.SelectBusinessProcessPerformer", FormParameters, PerformerItem);
	
EndProcedure	

Procedure StopCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		BusinessProcessesAndTasksServerCall.StopBusinessProcesses(CommandParameter);
		
	Else
		
		BusinessProcessesAndTasksServerCall.StopBusinessProcess(CommandParameter);
		
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);
	EndIf;

EndProcedure

Procedure BusinessProcessesListDeletionMarkCompletion(Result, List) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SelectedRows = List.SelectedRows;
	BusinessProcessRef = BusinessProcessesAndTasksServerCall.MarkBusinessProcessesForDeletion(SelectedRows);
	List.Refresh();
	ShowUserNotification(NStr("en = 'The deletion mark is changed.';"), 
		?(BusinessProcessRef <> Undefined, GetURL(BusinessProcessRef), ""),
		?(BusinessProcessRef <> Undefined, String(BusinessProcessRef), ""));
	
EndProcedure

Procedure ActivateCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	If TypeOf(CommandParameter) = Type("Array") Then
		
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcesses(CommandParameter);
		
	Else
		
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcess(CommandParameter);
		
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);
	EndIf;
	
EndProcedure

Procedure ForwardTasksCompletion(Val Result, Val TaskArray) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	ForwardedTaskArray = Undefined;
	TasksAreForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks(
		TaskArray, Result, False, ForwardedTaskArray);
		
	Notify("Write_PerformerTask", New Structure("Forwarded", TasksAreForwarded), TaskArray);
	
EndProcedure

#EndRegion