///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// Parameters:
//   Table - See AccessManagement.AccessValuesSetsTable
//
Procedure FillAccessValuesSets(Table) Export

	BusinessProcessesAndTasksOverridable.OnFillingAccessValuesSets(ThisObject, Table);

	If Table.Count() > 0 Then
		Return;
	EndIf;

	FillDefaultAccessValuesSets(Table);

EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

////////////////////////////////////////////////////////////////////////////////
// Business process event handlers.

Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;
	EndIf;

	If Author <> Undefined And Not Author.IsEmpty() Then
		AuthorAsString = String(Author);
	EndIf;

	BusinessProcessesAndTasksServer.ValidateRightsToChangeBusinessProcessState(ThisObject);

	If ValueIsFilled(MainTask) 
		And Common.ObjectAttributeValue(MainTask, "BusinessProcess") = Ref Then

		Raise NStr("en = 'A task that belongs to the duty cannot be specified as the main task.';");

	EndIf;

	SetPrivilegedMode(True);
	TaskPerformersGroup = ?(TypeOf(Performer) = Type("CatalogRef.PerformerRoles"),
		BusinessProcessesAndTasksServer.TaskPerformersGroup(Performer, MainAddressingObject,
			AdditionalAddressingObject), Performer);
	TaskPerformersGroupSupervisor = ?(TypeOf(Supervisor) = Type("CatalogRef.PerformerRoles"),
		BusinessProcessesAndTasksServer.TaskPerformersGroup(Supervisor, MainAddressingObjectSupervisor,
			AdditionalAddressingObjectSupervisor), Supervisor);
	SetPrivilegedMode(False);

	If Not IsNew() And Common.ObjectAttributeValue(Ref, "SubjectOf") <> SubjectOf Then
		ChangeTaskSubject();
	EndIf;

EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)

	If IsNew() Then
		Author = Users.AuthorizedUser();
		Supervisor = Users.AuthorizedUser();
		If TypeOf(FillingData) = Type("CatalogRef.Users") Then
			Performer = FillingData;
		Else
			// For auto completion in a blank Assignee field.
			Performer = Catalogs.Users.EmptyRef();
		EndIf;
	EndIf;

	If FillingData <> Undefined And TypeOf(FillingData) <> Type("Structure") 
		And FillingData <> Tasks.PerformerTask.EmptyRef() Then

		If TypeOf(FillingData) <> Type("TaskRef.PerformerTask") Then
			SubjectOf = FillingData;
		Else
			SubjectOf = Common.ObjectAttributeValue(FillingData, "SubjectOf");
		EndIf;

	EndIf;

	BusinessProcessesAndTasksServer.FillMainTask(ThisObject, FillingData);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	NotCheckedAttributeArray = New Array;
	If Not OnValidation Then
		NotCheckedAttributeArray.Add("Supervisor");
	EndIf;
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributeArray);
EndProcedure

Procedure OnCopy(CopiedObject)

	IterationNumber = 0;
	Completed2 = False;
	Accepted = False;
	ExecutionResult = "";
	CompletedOn = '00010101000000';
	State = Enums.BusinessProcessStates.Running;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Flowchart items event handlers.

// Parameters:
//   BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job
//   TasksBeingFormed - Array of TaskObject
//   Cancel - Boolean
// 
Procedure ExecuteWhenCreatingTasks(BusinessProcessRoutePoint, TasksBeingFormed, Cancel)

	IterationNumber = IterationNumber + 1;
	Write();
	
	// Setting the addressing attributes and additional attributes for each task.
	For Each Task In TasksBeingFormed Do

		Task.Author = Author;
		Task.AuthorAsString = String(Author);
		If TypeOf(Performer) = Type("CatalogRef.PerformerRoles") Then
			Task.PerformerRole = Performer;
			Task.MainAddressingObject = MainAddressingObject;
			Task.AdditionalAddressingObject = AdditionalAddressingObject;
			Task.Performer = Undefined;
		Else
			Task.Performer = Performer;
		EndIf;
		Task.Description = TaskDescriptionForExecution();
		Task.TaskDueDate = TaskDueDateForExecution();
		Task.Importance = Importance;
		Task.SubjectOf = SubjectOf;

	EndDo;

EndProcedure

Procedure ExecuteBeforeCreatingTasks(BusinessProcessRoutePoint, TasksBeingFormed, StandardProcessing)

	If SubjectOf = Undefined Or SubjectOf.IsEmpty() Then
		Return;
	EndIf;

EndProcedure

Procedure ExecuteWhenExecuted(BusinessProcessRoutePoint, Task, Cancel)

	ExecutionResult = CompletePointExecutionResult(Task) + ExecutionResult;
	Write();

EndProcedure
// Parameters:
//  BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job
//  TasksBeingFormed - Array of TaskObject
//  Cancel - Boolean
// 
Procedure CheckWhenCreatingTasks(BusinessProcessRoutePoint, TasksBeingFormed, Cancel)

	If Supervisor.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
	
	// Setting the addressing attributes and additional attributes for each task.
	For Each Task In TasksBeingFormed Do

		Task.Author = Author;
		If TypeOf(Supervisor) = Type("CatalogRef.PerformerRoles") Then
			Task.PerformerRole = Supervisor;
			Task.MainAddressingObject = MainAddressingObjectSupervisor;
			Task.AdditionalAddressingObject = AdditionalAddressingObjectSupervisor;
		Else
			Task.Performer = Supervisor;
		EndIf;

		Task.Description = TaskDescriptionForCheck();
		Task.TaskDueDate = TaskDueDateForCheck();
		Task.Importance = Importance;
		Task.SubjectOf = SubjectOf;

	EndDo;

EndProcedure

Procedure CheckWhenExecuting(BusinessProcessRoutePoint, Task, Cancel)

	ExecutionResult = ValidatePointExecutionResult(Task) + ExecutionResult;
	Write();

EndProcedure

Procedure NeedVerificationConditionVerification(BusinessProcessRoutePoint, Result)

	Result = OnValidation;

EndProcedure

Procedure ReturnFollowingConditionsToExecutor(BusinessProcessRoutePoint, Result)

	Result = Not Accepted;

EndProcedure

Procedure CompletionAtCompletion(BusinessProcessRoutePoint, Cancel)

	CompletedOn = BusinessProcessesAndTasksServer.BusinessProcessCompletionDate(Ref);
	Write();

EndProcedure

#EndRegion

#Region Private

// Updates attribute values of uncompleted tasks 
// according to the Job business process attributes:
//   Importance, TaskDueDate, Description, and Author.
//
Procedure ChangeUncompletedTasksAttributes() Export

	Block = New DataLock;
	LockItem = Block.Add("Task.PerformerTask");
	LockItem.SetValue("BusinessProcess", Ref);

	Query = New Query("SELECT
	  |	PerformerTasks.Ref AS Ref
	  |FROM
	  |	Task.PerformerTask AS PerformerTasks
	  |WHERE
	  |	PerformerTasks.BusinessProcess = &BusinessProcess
	  |	AND PerformerTasks.DeletionMark = FALSE
	  |	AND PerformerTasks.Executed = FALSE");
	Query.SetParameter("BusinessProcess", Ref);

	BeginTransaction();
	Try
		Block.Lock();
		SelectionDetailRecords = Query.Execute().Select();

		While SelectionDetailRecords.Next() Do
			TaskObject = SelectionDetailRecords.Ref.GetObject(); // TaskObject
			TaskObject.Importance = Importance;
			TaskObject.TaskDueDate = ?(TaskObject.RoutePoint = BusinessProcesses.Job.RoutePoints.Execute,
				TaskDueDateForExecution(), TaskDueDateForCheck());
			TaskObject.Description = ?(TaskObject.RoutePoint = BusinessProcesses.Job.RoutePoints.Execute,
				TaskDescriptionForExecution(), TaskDescriptionForCheck());
			TaskObject.Author = Author;
			// Don't check for the preliminary data edit lock:
			// this change has a higher priority than the opened task forms.
			TaskObject.Write();
		EndDo;

		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Procedure ChangeTaskSubject()

	Block = New DataLock;
	LockItem = Block.Add("Task.PerformerTask");
	LockItem.SetValue("BusinessProcess", Ref);

	Query = New Query("SELECT
	  |	PerformerTasks.Ref AS Ref
	  |FROM
	  |	Task.PerformerTask AS PerformerTasks
	  |WHERE
	  |	PerformerTasks.BusinessProcess = &BusinessProcess");

	Query.SetParameter("BusinessProcess", Ref);

	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Block.Lock();
		SelectionDetailRecords = Query.Execute().Select();

		While SelectionDetailRecords.Next() Do
			TaskObject = SelectionDetailRecords.Ref.GetObject(); // TaskObject
			TaskObject.SubjectOf = SubjectOf;
			// Don't check for the preliminary data edit lock:
			// this change has a higher priority than the opened task forms.
			TaskObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

Function TaskDescriptionForExecution()

	Return Description;

EndFunction

Function TaskDueDateForExecution()

	Return TaskDueDate;

EndFunction

Function TaskDescriptionForCheck()

	TaskDescription = NStr("en = 'Check';");
	Return ?(IsBlankString(TaskDescription), "", TaskDescription + ": ") + Description;

EndFunction

Function TaskDueDateForCheck()

	Return VerificationDueDate;

EndFunction

Function CompletePointExecutionResult(Val TaskRef)

	TaskData = Common.ObjectAttributesValues(TaskRef,
		"ExecutionResult,CompletionDate,Performer,Executed");

	StringFormat = ?(TaskData.Executed, 
		NStr("en = '%1, %2 completed the task:
			|%3';") + Chars.LF, 
		NStr("en = '%1, %2 rejected the task:
			|%3';") + Chars.LF);

	Comment = TrimAll(TaskData.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);

	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskData.CompletionDate,
		TaskData.Performer, Comment);
	Return Result;

EndFunction

Function ValidatePointExecutionResult(Val TaskRef)

	If Not Accepted Then
		StringFormat = NStr("en = '%1, %2 sent the task back for revision:
							|%3';") + Chars.LF;

	Else
		StringFormat = ?(Completed2, 
			NStr("en = '%1, %2 confirmed task completion:
				|%3';") + Chars.LF, 
			NStr("en = '%1, %2 confirmed task cancellation:
			   |%3';") + Chars.LF);
	EndIf;

	TaskData = Common.ObjectAttributesValues(TaskRef,
		"ExecutionResult,CompletionDate,Performer");
	Comment = TrimAll(TaskData.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskData.CompletionDate,
		TaskData.Performer, Comment);
	Return Result;

EndFunction

Procedure FillDefaultAccessValuesSets(Table)
	
	// The default access rights
	// - Read: Author OR Performer (addressing-wise) OR Supervisor (addressing-wise).
	// - Update: Author.
	
	// If the subject is not specified (the business process is not based on another subject), then the subject is not involved in the restriction logic.
	
	// Read, Update: Set #1.
	String = Table.Add();
	String.SetNumber     = 1;
	String.Read          = True;
	String.Update       = True;
	String.AccessValue = Author;
	
	// Read: Set #2.
	String = Table.Add();
	String.SetNumber     = 2;
	String.Read          = True;
	String.AccessValue = TaskPerformersGroup;
	
	// Read: Set #3.
	String = Table.Add();
	String.SetNumber     = 3;
	String.Read          = True;
	String.AccessValue = TaskPerformersGroupSupervisor;

EndProcedure

#EndRegion

#Else
	Raise NStr("en = 'Invalid object call on the client.';");
#EndIf