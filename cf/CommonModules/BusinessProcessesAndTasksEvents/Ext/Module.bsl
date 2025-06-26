///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Subsystem event subscription handlers.

// The WriteToBusinessProcessesList event subscription handler.
//
Procedure WriteToBusinessProcessesList(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.BusinessProcessesData");
	LockItem.SetValue("Owner", Source.Ref);
	Block.Lock();
	
	OldState = Undefined;
	If Source.AdditionalProperties.Property("OldState", OldState) Then
		BusinessProcessesAndTasksServer.OnChangeBusinessProcessState(Source, OldState);
	EndIf;	
	
	RecordSet = InformationRegisters.BusinessProcessesData.CreateRecordSet();
	RecordSet.Filter.Owner.Set(Source.Ref);
	Record = RecordSet.Add();
	Record.Owner = Source.Ref;
	FieldList = "Number,Date,Completed,Started,Author,CompletedOn,Description,DeletionMark";
	If Source.Metadata().Attributes.Find("State") <> Undefined Then 
		FieldList = FieldList + ",State";
	EndIf;
	FillPropertyValues(Record, Source, FieldList);
	If Not ValueIsFilled(Record.State) Then
		Record.State = Enums.BusinessProcessStates.Running;
	EndIf;
	
	BusinessProcessesAndTasksOverridable.OnWriteBusinessProcessesList(Record);
	
	SetPrivilegedMode(True);
	RecordSet.Write();

EndProcedure

// MarkTasksForDeletion event subscription handler.
//
Procedure MarkTasksForDeletion(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
        Return;  
	EndIf; 
	
	If Source.IsNew() Then 
        Return;  
	EndIf; 
	
	PrevDeletionMark = Common.ObjectAttributeValue(Source.Ref, "DeletionMark");
	If Source.DeletionMark <> PrevDeletionMark Then
		SetPrivilegedMode(True);
		BusinessProcessesAndTasksServer.MarkTasksForDeletion(Source.Ref, Source.DeletionMark);
	EndIf;	
	
EndProcedure

// The UpdateBusinessProcessState event subscription handler.
//
Procedure UpdateBusinessProcessState(Source, Cancel) Export
	
	If Source.DataExchange.Load Then 
        Return;  
	EndIf; 
	
	If Source.Metadata().Attributes.Find("State") = Undefined Then
		Return;
	EndIf;	
	
	If Not Source.IsNew() Then
		OldState = Common.ObjectAttributeValue(Source.Ref, "State");
		If Source.State <> OldState Then
			Source.AdditionalProperties.Insert("OldState", OldState);
		EndIf;
	EndIf;	
	
EndProcedure

// The StartDeferredProcesses scheduled job handler
//
Procedure StartDeferredProcesses() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.StartDeferredProcesses);
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProcessesToStart.Owner AS BusinessProcess
		|FROM
		|	InformationRegister.ProcessesToStart AS ProcessesToStart
		|		INNER JOIN InformationRegister.BusinessProcessesData AS BusinessProcessesData
		|		ON ProcessesToStart.Owner = BusinessProcessesData.Owner
		|WHERE
		|	ProcessesToStart.State = VALUE(Enum.ProcessesStatesForStart.ReadyToStart)
		|	AND ProcessesToStart.DeferredStartDate <= &CurrentDate
		|	AND ProcessesToStart.DeferredStartDate <> DATETIME(1, 1, 1)
		|	AND BusinessProcessesData.DeletionMark = FALSE";
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	Selection  = Query.Execute().Select();
	
	While Selection.Next() Do
		BusinessProcessesAndTasksServer.StartDeferredProcess(Selection.BusinessProcess);
	EndDo;
	
EndProcedure

#EndRegion
