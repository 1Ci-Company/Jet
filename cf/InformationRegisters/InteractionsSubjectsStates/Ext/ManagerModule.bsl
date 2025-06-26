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

#Region Private

// Deletes one record or all records from the register.
//
// Parameters:
//  SubjectOf  - DocumentRef
//           - CatalogRef
//           - Undefined - Topic whose record is being deleted.
//                            If Undefined, the entire register will be cleared.
//                            
//
Procedure DeleteRecordFromRegister(SubjectOf = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = CreateRecordSet();
	If SubjectOf <> Undefined Then
		RecordSet.Filter.SubjectOf.Set(SubjectOf);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Writes to the information register for the specified subject.
//
// Parameters:
//  SubjectOf                       - DocumentRef
//                                - CatalogRef - Topic being recorded.
//  NotReviewedInteractionsCount       - Number - a number of unreviewed interactions for the subject.
//  LastInteractionDate  - Date - date of last interaction on subject.
//  Running                       - Boolean - indicates that the subject is active.
//
Procedure ExecuteRecordToRegister(SubjectOf,
	                              NotReviewedInteractionsCount = Undefined,
	                              LastInteractionDate = Undefined,
	                              Running = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If NotReviewedInteractionsCount = Undefined And LastInteractionDate = Undefined And Running = Undefined Then
		
		Return;
		
	ElsIf NotReviewedInteractionsCount = Undefined Or LastInteractionDate = Undefined Or Running = Undefined Then
		
		Query = New Query;
		Query.Text = "
		|SELECT
		|	InteractionsSubjectsStates.SubjectOf,
		|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
		|	InteractionsSubjectsStates.LastInteractionDate,
		|	InteractionsSubjectsStates.Running
		|FROM
		|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|WHERE
		|	InteractionsSubjectsStates.SubjectOf = &SubjectOf";
		
		Query.SetParameter("SubjectOf",SubjectOf);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			If NotReviewedInteractionsCount = Undefined Then
				NotReviewedInteractionsCount = Selection.NotReviewedInteractionsCount;
			EndIf;
			
			If LastInteractionDate = Undefined Then
				LastInteractionDate = LastInteractionDate.SubjectOf;
			EndIf;
			
			If Running = Undefined Then
				Running = Selection.Running;
			EndIf;
			
		EndIf;
	EndIf;

	RecordSet = CreateRecordSet();
	RecordSet.Filter.SubjectOf.Set(SubjectOf);
	
	Record = RecordSet.Add();
	Record.SubjectOf                      = SubjectOf;
	Record.NotReviewedInteractionsCount      = NotReviewedInteractionsCount;
	Record.LastInteractionDate = LastInteractionDate;
	Record.Running                      = Running;
	RecordSet.Write();

EndProcedure

// Locks the InteractionsSubjectsStates information register.
// 
// Parameters:
//  Block       - DataLock - a set lock.
//  DataSource   - ValueTable - a data source to be locked.
//  NameSourceField - String - the source field name that will be used to set the lock by subject.
//
Procedure BlockInteractionObjectsStatus(Block, DataSource, NameSourceField) Export
	
	LockItem = Block.Add("InformationRegister.InteractionsSubjectsStates"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("SubjectOf", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf