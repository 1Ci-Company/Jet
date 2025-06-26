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

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TaskWasExecuted = Common.ObjectAttributeValue(Ref, "Executed");
	If Executed And TaskWasExecuted <> True And Not AddressingAttributesAreFilled() Then
		
		Common.MessageToUser(
			NStr("en = 'Specify a task assignee.';"),,,
			"Object.Performer", Cancel);
		Return;
			
	EndIf;
	
	If TaskDueDate <> '00010101' And StartDate > TaskDueDate Then
		Common.MessageToUser(
			NStr("en = 'Execution start date cannot be later than the deadline.';"),,,
			"Object.StartDate", Cancel);
		Return;
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Date = CurrentSessionDate();

EndProcedure


Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Ref.IsEmpty() Then
		InitialAttributes = Common.ObjectAttributesValues(Ref, 
			"Executed, DeletionMark, BusinessProcessState");
	Else
		InitialAttributes = New Structure(
			"Executed, DeletionMark, BusinessProcessState",
			False, False, Enums.BusinessProcessStates.EmptyRef());
	EndIf;
		
	If InitialAttributes.DeletionMark <> DeletionMark Then
		BusinessProcessesAndTasksServer.OnMarkTaskForDeletion(Ref, DeletionMark);
	EndIf;
	
	If Not InitialAttributes.Executed And Executed Then
		
		If BusinessProcessState = Enums.BusinessProcessStates.Suspended Then
			Raise NStr("en = 'Cannot perform tasks of suspended business processes.';");
		EndIf;
		
		// If the task is completed, assign the "Performer" attribute to the user who fulfilled it.
		// This is required for reporting.
		// (Assign only if it wasn't completed in the infobase and was in the object.)
		// 
		If Not ValueIsFilled(Performer) Then
			Performer = Users.AuthorizedUser();
		EndIf;
		If CompletionDate = Date(1, 1, 1) Then
			CompletionDate = CurrentSessionDate();
		EndIf;
	ElsIf Not DeletionMark And InitialAttributes.Executed And Executed Then
			Common.MessageToUser(
				NStr("en = 'This task is already completed.';"),,,, Cancel);
			Return;
	EndIf;
	
	If Importance.IsEmpty() Then
		Importance = Enums.TaskImportanceOptions.Ordinary;
	EndIf;
	
	If Not ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Running;
	EndIf;
	
	SubjectString = Common.SubjectString(SubjectOf);
	
	If Not Ref.IsEmpty() And InitialAttributes.BusinessProcessState <> BusinessProcessState Then
		SetSubordinateBusinessProcessesState(BusinessProcessState);
	EndIf;
	
	If Executed And Not AcceptedForExecution Then
		AcceptedForExecution = True;
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.AccessManagement
	SetPrivilegedMode(True);
	TaskPerformersGroup = BusinessProcessesAndTasksServer.TaskPerformersGroup(PerformerRole, 
		MainAddressingObject, AdditionalAddressingObject);
	SetPrivilegedMode(False);
	// End StandardSubsystems.AccessManagement
	
	// Populate attribute AcceptForExecutionDate.
	If AcceptedForExecution And AcceptForExecutionDate = Date('00010101') Then
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;
	
	If AdditionalProperties.Property("IsCheckOnly")
	   And AdditionalProperties.IsCheckOnly Then
		Executed = False;
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("TaskObject.PerformerTask") Then
		FillPropertyValues(ThisObject, FillingData, 
			"BusinessProcess,RoutePoint,Description,Performer,PerformerRole,MainAddressingObject," 
			+ "AdditionalAddressingObject,Importance,CompletionDate,Author,LongDesc,TaskDueDate," 
			+ "StartDate,ExecutionResult,SubjectOf");
		Date = CurrentSessionDate();
	EndIf;
	If Not ValueIsFilled(Importance) Then
		Importance = Enums.TaskImportanceOptions.Ordinary;
	EndIf;
	
	If Not ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Running;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetSubordinateBusinessProcessesState(NewState)
	
	BeginTransaction();
	Try
		SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.MainTaskBusinessProcesses(Ref, True);
		For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
			BusinessProcessObject = SubordinateBusinessProcess.GetObject();
			BusinessProcessObject.Lock();
			BusinessProcessObject.State = NewState;
			BusinessProcessObject.Write(); // CAC:1327 The lock is set in the BusinessProcessesAndTasksServer.MainTaskBusinessProcesses.
		EndDo;	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Determines whether addressing attributes are filled in: assignee or business role
// 
// Returns:
//  Boolean - Returns True if an assignee or a business role is specified in the task.
//
Function AddressingAttributesAreFilled()
	
	Return ValueIsFilled(Performer) Or Not PerformerRole.IsEmpty();

EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf