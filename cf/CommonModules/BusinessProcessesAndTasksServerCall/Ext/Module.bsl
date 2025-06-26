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

// Gets a structure with description of a task execution form.
//
// Parameters:
//  TaskRef - TaskRef.PerformerTask
//
// Returns:
//   See BusinessProcessesAndTasksOverridable.OnReceiveTaskExecutionForm.FormParameters
//
Function TaskExecutionForm(Val TaskRef) Export
	
	CommonClientServer.CheckParameter("BusinessProcessesAndTasksServerCall.TaskExecutionForm", 
		"TaskRef", TaskRef, Type("TaskRef.PerformerTask"));

	Attributes = Common.ObjectAttributesValues(TaskRef, "BusinessProcess,RoutePoint");
	If Attributes.BusinessProcess = Undefined Or Attributes.BusinessProcess.IsEmpty() Then
		Return New Structure();
	EndIf;
	
	BusinessProcessType = Attributes.BusinessProcess.Metadata(); // MetadataObjectBusinessProcess 
	FormParameters = BusinessProcesses[BusinessProcessType.Name].TaskExecutionForm(TaskRef,
		Attributes.RoutePoint);
	BusinessProcessesAndTasksOverridable.OnReceiveTaskExecutionForm(
		BusinessProcessType.Name, TaskRef, Attributes.RoutePoint, FormParameters);
	
	Return FormParameters;
	
EndFunction

// Checks whether the report cell contains a reference to the task and returns details value in
// the DetailsValue parameter.
//
// Parameters:
//  Details             - String - a cell name.
//  ReportDetailsData - String - address in temporary storage.
//  DetailsValue     - TaskRef.PerformerTask
//                          - Arbitrary - details value from the cell.
// 
// Returns:
//  Boolean - True if it is a task to an assignee.
//
Function IsPerformerTask(Val Details, Val ReportDetailsData, DetailsValue) Export
	
	ObjectDetailsData = GetFromTempStorage(ReportDetailsData); // DataCompositionDetailsData
	DetailsValue = ObjectDetailsData.Items[Details].GetFields()[0].Value;
	Return TypeOf(DetailsValue) = Type("TaskRef.PerformerTask");
	
EndFunction

// Completes the TaskRef task. If necessary executes
// DefaultCompletionHandler in the manager module
// of the business process where the TaskRef task belongs.
//
// Parameters:
//  TaskRef        - TaskRef
//  DefaultAction - Boolean       - shows whether it is required to call procedure 
//                                       DefaultCompletionHandler for the task business process.
//
Procedure ExecuteTask(TaskRef, DefaultAction = False) Export
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(TaskRef);
		
		TaskInfoRecords = Common.ObjectAttributesValues(TaskRef, "Executed, BusinessProcess, RoutePoint");
		If TaskInfoRecords.Executed Then
			Raise NStr("en = 'The task was completed earlier.';");
		EndIf;
		
		If DefaultAction 
			 And TaskInfoRecords.BusinessProcess <> Undefined
			 And Not TaskInfoRecords.BusinessProcess.IsEmpty() Then
				BusinessProcessType = TaskInfoRecords.BusinessProcess.Metadata(); // MetadataObjectBusinessProcess
				BusinessProcesses[BusinessProcessType.Name].DefaultCompletionHandler(TaskRef,
					TaskInfoRecords.BusinessProcess, TaskInfoRecords.RoutePoint);
		EndIf;
		
		TaskObject = TaskRef.GetObject();
		TaskObject.Executed = False;
		TaskObject.ExecuteTask();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Forwards the TaskArray tasks to a new assignee specified in the ForwardingInfo structure.
//
// Parameters:
//  RedirectedTasks_SSLs - Array of TaskRef.PerformerTask
//  ForwardingInfo   - Structure - new values of task addressing attributes.
//  IsCheckOnly         - Boolean    - If True, the function does not actually forward
//                                       tasks, it only checks 
//                                       whether they can be forwarded.
//  RedirectedTasks - Array of TaskRef.PerformerTask - forwarded tasks.
//                                       The array elements might not exactly match 
//                                       the TasksToRedirect elements if some tasks cannot be forwarded.
//
// Returns:
//   Boolean   - True if the tasks are forwarded successfully.
//
Function ForwardTasks(Val RedirectedTasks_SSLs, Val ForwardingInfo, Val IsCheckOnly = False,
	RedirectedTasks = Undefined) Export
	
	Result = True;
	
	TasksInfo = Common.ObjectsAttributesValues(RedirectedTasks_SSLs, "BusinessProcess,Executed");
	BeginTransaction();
	Try
		For Each Task In TasksInfo Do
			
			If Task.Value.Executed Then
				Result = False;
				If IsCheckOnly Then
					RollbackTransaction();
					Return Result;
				EndIf;
			EndIf;
			
			BusinessProcessesAndTasksServer.LockTasks(Task.Key);
			If ValueIsFilled(Task.Value.BusinessProcess) And Not Task.Value.BusinessProcess.IsEmpty() Then
				BusinessProcessesAndTasksServer.LockBusinessProcesses(Task.Value.BusinessProcess);
			EndIf;
		EndDo;
		
		If IsCheckOnly Then
			For Each Task In TasksInfo Do
				TaskObject = Task.Key.GetObject();
				TaskObject.Executed = False;
				TaskObject.AdditionalProperties.Insert("Redirection1", True);
				TaskObject.AdditionalProperties.Insert("IsCheckOnly",  True);
				TaskObject.ExecuteTask();
			EndDo;
			RollbackTransaction();
			Return Result;
		EndIf;
		
		For Each Task In TasksInfo Do
			
			If Not ValueIsFilled(RedirectedTasks) Then
				RedirectedTasks = New Array();
			EndIf;
			
			// Don't set a deadlock on "Task" to allow forwarding the task from its form. 
			// 
			TaskObject = Task.Key.GetObject();
			
			SetPrivilegedMode(True);
			NewTask = Tasks.PerformerTask.CreateTask();
			NewTask.Fill(TaskObject);
			FillPropertyValues(NewTask, ForwardingInfo, 
				"Performer,PerformerRole,MainAddressingObject,AdditionalAddressingObject");
			NewTask.Write();
			SetPrivilegedMode(False);
		
			RedirectedTasks.Add(NewTask.Ref);
			
			TaskObject.ExecutionResult = ForwardingInfo.Comment; 
			TaskObject.Executed = False;
			TaskObject.AdditionalProperties.Insert("Redirection1", True);
			TaskObject.ExecuteTask();
			
			SetPrivilegedMode(True);
			SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.SelectHeadTaskBusinessProcesses(Task.Key, True).Select();
			SetPrivilegedMode(False);
			While SubordinateBusinessProcesses.Next() Do
				BusinessProcessObject = SubordinateBusinessProcesses.Ref.GetObject();
				BusinessProcessObject.HeadTask = NewTask.Ref;
				BusinessProcessObject.Write();
			EndDo;
			
			SetPrivilegedMode(True);
			SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.MainTaskBusinessProcesses(Task.Key, True);
			SetPrivilegedMode(False);
			
			For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
				BusinessProcessObject = SubordinateBusinessProcess.GetObject();
				BusinessProcessObject.MainTask = NewTask.Ref;
				BusinessProcessObject.Write();
			EndDo;
			
			OnForwardTask(TaskObject, NewTask);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Result = False;
		If Not IsCheckOnly Then
			Raise;
		EndIf;
	EndTry;
	
	Return Result;
	
EndFunction

// Marks the specified business processes as active.
//
// Parameters:
//  Var_BusinessProcesses - Array of DefinedType.BusinessProcess
//
Procedure ActivateBusinessProcesses(Var_BusinessProcesses) Export
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(Var_BusinessProcesses);
		
		For Each BusinessProcess In Var_BusinessProcesses Do
			ActivateBusinessProcess(BusinessProcess);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified business processes as active.
//
// Parameters:
//  BusinessProcess - DefinedType.BusinessProcess
//
Procedure ActivateBusinessProcess(BusinessProcess) Export
	
	If TypeOf(BusinessProcess) = Type("DynamicListGroupRow") Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcess);
		
		Object = BusinessProcess.GetObject();
		If Object.State = Enums.BusinessProcessStates.Running Then
			
			If Object.Completed Then
				Raise NStr("en = 'Cannot activate the completed business processes.';");
			EndIf;
			
			If Not Object.Started Then
				Raise NStr("en = 'Cannot activate the business processes that are not started yet.';");
			EndIf;
			
			Raise NStr("en = 'The business process is already active.';");
		EndIf;
			
		Object.Lock();
		Object.State = Enums.BusinessProcessStates.Running;
		Object.Write(); // CAC:1327 The lock is set earlier in the BusinessProcessesAndTasksServer.LockBusinessProcesses.
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified business processes as suspended.
//
// Parameters:
//  Var_BusinessProcesses - Array of DefinedType.BusinessProcess
//
Procedure StopBusinessProcesses(Var_BusinessProcesses) Export
	
	BeginTransaction();
	Try 
		BusinessProcessesAndTasksServer.LockBusinessProcesses(Var_BusinessProcesses);
		
		For Each BusinessProcess In Var_BusinessProcesses Do
			StopBusinessProcess(BusinessProcess);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(BusinessProcessesAndTasksServer.EventLogEvent(), EventLogLevel.Error,,, 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified business process as suspended.
//
// Parameters:
//  BusinessProcess - DefinedType.BusinessProcess
//
Procedure StopBusinessProcess(BusinessProcess) Export
	
	If TypeOf(BusinessProcess) = Type("DynamicListGroupRow") Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcess);
		
		Object = BusinessProcess.GetObject();
		If Object.State = Enums.BusinessProcessStates.Suspended Then
			
			If Object.Completed Then
				Raise NStr("en = 'Cannot suspend the completed business processes.';");
			EndIf;
				
			If Not Object.Started Then
				Raise NStr("en = 'Cannot suspend the business processes that are not started yet.';");
			EndIf;
			
			Raise NStr("en = 'The business process is already suspended.';");
		EndIf;
		
		Object.Lock();
		Object.State = Enums.BusinessProcessStates.Suspended;
		Object.Write(); // CAC:1327 The lock is set earlier in the BusinessProcessesAndTasksServer.LockBusinessProcesses.
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Marks the specified task as accepted for execution.
//
// Parameters:
//   Var_Tasks - Array of TaskRef.PerformerTask
//
Procedure AcceptTasksForExecution(Var_Tasks) Export
	
	NewTaskArray = New Array();
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(Var_Tasks);
		
		For Each Task In Var_Tasks Do
			
			If TypeOf(Task) = Type("DynamicListGroupRow") Then
				Continue;
			EndIf;
			
			TaskObject = Task.GetObject();
			If TaskObject.Executed Then
				Continue;
			EndIf;
			
			TaskObject.Lock();
			TaskObject.AcceptedForExecution = True;
			TaskObject.AcceptForExecutionDate = CurrentSessionDate();
			If Not ValueIsFilled(TaskObject.Performer) Then
				TaskObject.Performer = Users.AuthorizedUser();
			EndIf;
			TaskObject.Write(); // CAC:1327 The lock is set earlier in the BusinessProcessesAndTasksServer.LockTasks.
			
			NewTaskArray.Add(Task);
			
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Var_Tasks = NewTaskArray;
	
EndProcedure

// Marks the specified tasks as not accepted for execution.
//
// Parameters:
//   Var_Tasks - Array of TaskRef.PerformerTask
//
Procedure CancelAcceptTasksForExecution(Var_Tasks) Export
	
	NewTaskArray = New Array();
	
	BeginTransaction();
	Try
		BusinessProcessesAndTasksServer.LockTasks(Var_Tasks);
		
		For Each Task In Var_Tasks Do
			
			If TypeOf(Task) = Type("DynamicListGroupRow") Then 
				Continue;
			EndIf;
			
			TaskObject = Task.GetObject();
			If TaskObject.Executed Then
				Continue;
			EndIf;
			
			TaskObject.Lock();
			TaskObject.AcceptedForExecution = False;
			TaskObject.AcceptForExecutionDate = "00010101000000";
			If Not TaskObject.PerformerRole.IsEmpty() Then
				TaskObject.Performer = Undefined;
			EndIf;
			TaskObject.Write(); // CAC:1327 The lock is set earlier in the BusinessProcessesAndTasksServer.LockTasks.
			
			NewTaskArray.Add(Task);
			
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Var_Tasks = NewTaskArray;
	
EndProcedure

// Checks whether the specified task is the head one.
//
// Parameters:
//  TaskRef  - TaskRef.PerformerTask
//
// Returns:
//   Boolean
//
Function IsHeadTask(TaskRef) Export
	
	SetPrivilegedMode(True);
	Result = BusinessProcessesAndTasksServer.SelectHeadTaskBusinessProcesses(TaskRef);
	Return Not Result.IsEmpty();
	
EndFunction

// Generates a choice list for picking assignees in input fields of flexible type ("User" and "Role").
//
// Parameters:
//  Text - String - a text fragment to search for possible assignees.
// 
// Returns:
//  ValueList - a selection list containing possible assignees.
//
Function GeneratePerformerChoiceData(Text) Export
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Description LIKE &Text ESCAPE ""~""
	|	AND Users.Invalid = FALSE
	|	AND Users.IsInternal = FALSE
	|	AND Users.DeletionMark = FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	PerformerRoles.Ref
	|FROM
	|	Catalog.PerformerRoles AS PerformerRoles
	|WHERE
	|	PerformerRoles.Description LIKE &Text ESCAPE ""~""
	|	AND NOT PerformerRoles.DeletionMark";
	Query.SetParameter("Text", Common.GenerateSearchQueryString(Text) + "%");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

#EndRegion

#Region Private

// Returns:
//  Number
//
Function UncompletedBusinessProcessesTasksCount(Var_BusinessProcesses) Export
	
	BusinessProcessesArray = New Array;
	For Each BusinessProcess In Var_BusinessProcesses Do
		If TypeOf(BusinessProcess) = Type("DynamicListGroupRow") Then
			Continue;
		EndIf;
		BusinessProcessesArray.Add(BusinessProcess);
	EndDo;
		
	If BusinessProcessesArray.Count() = 0 Then
		Return 0;
	EndIf;

	Query = New Query(
		"SELECT
		|	COUNT(*) AS Count
		|FROM
		|	Task.PerformerTask AS PerformerTasks
		|WHERE
		|	PerformerTasks.BusinessProcess IN (&BusinessProcesses)
		|	AND PerformerTasks.Executed = FALSE");

	Query.SetParameter("BusinessProcesses", BusinessProcessesArray);
	Return Query.Execute().Unload()[0].Count;
	
EndFunction

// Returns:
//  Number
//
Function UncompletedBusinessProcessTasksCount(BusinessProcess) Export
	
	Return UncompletedBusinessProcessesTasksCount(CommonClientServer.ValueInArray(BusinessProcess));
	
EndFunction

// Returns:
//  - BusinessProcessRef
//  - Undefined
//
Function MarkBusinessProcessesForDeletion(SelectedRows) Export
	
	Count = 0;
	For Each TableRow In SelectedRows Do
		BusinessProcessRef = TableRow.Owner;
		If BusinessProcessRef = Undefined Or BusinessProcessRef.IsEmpty() Then
			Continue;
		EndIf;
		BeginTransaction();
		Try
			BusinessProcessesAndTasksServer.LockBusinessProcesses(BusinessProcessRef);
			BusinessProcessObject = BusinessProcessRef.GetObject();
			BusinessProcessObject.SetDeletionMark(Not BusinessProcessObject.DeletionMark);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		Count = Count + 1;
	EndDo;
	Return ?(Count = 1, SelectedRows[0].Owner, Undefined);
EndFunction

Procedure OnForwardTask(TaskObject, NewTaskObject) 
	
	If TaskObject.BusinessProcess = Undefined Or TaskObject.BusinessProcess.IsEmpty() Then
		Return;
	EndIf;
	
	AttachedBusinessProcesses = New Map;
	AttachedBusinessProcesses.Insert(Metadata.BusinessProcesses.Job.FullName(), "");
	BusinessProcessesAndTasksOverridable.OnDetermineBusinessProcesses(AttachedBusinessProcesses);
	
	BusinessProcessType = TaskObject.BusinessProcess.Metadata();
	BusinessProcessInfo = AttachedBusinessProcesses[BusinessProcessType.FullName()];
	If BusinessProcessInfo <> Undefined Then 
		BusinessProcesses[BusinessProcessType.Name].OnForwardTask(TaskObject.Ref, NewTaskObject.Ref);
	EndIf;
	
EndProcedure

#EndRegion