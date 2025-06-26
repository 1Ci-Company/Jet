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
//  Contact  - CatalogRef
//           - Undefined - Contact whose record is being deleted.
//             If Undefined, the entire register will be cleared.
//
Procedure DeleteRecordFromRegister(Contact = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = CreateRecordSet();
	If Contact <> Undefined Then
		RecordSet.Filter.Contact.Set(Contact);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Writes to the information register for the specified subject.
//
// Parameters:
//  Contact  - CatalogRef - a contact to be recorded.
//  NotReviewedInteractionsCount       - Number - a number of unreviewed interactions for the contact.
//  LastInteractionDate  - Date  - a date of last interaction on the contact.
//
Procedure ExecuteRecordToRegister(Contact, NotReviewedInteractionsCount = Undefined,
	LastInteractionDate = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If NotReviewedInteractionsCount = Undefined And LastInteractionDate = Undefined Then
		
		Return;
		
	ElsIf NotReviewedInteractionsCount = Undefined Or LastInteractionDate = Undefined Then
		
		Query = New Query;
		Query.Text = "
		|SELECT
		|	InteractionsContactStates.Contact,
		|	InteractionsContactStates.NotReviewedInteractionsCount,
		|	InteractionsContactStates.LastInteractionDate
		|FROM
		|	InformationRegister.InteractionsContactStates AS InteractionsContactStates
		|WHERE
		|	InteractionsContactStates.Contact = &Contact";
		
		Query.SetParameter("Contact", Contact);
		
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
			
		EndIf;
	EndIf;

	RecordSet = CreateRecordSet();
	RecordSet.Filter.Contact.Set(Contact);
	
	Record = RecordSet.Add();
	Record.Contact                      = Contact;
	Record.NotReviewedInteractionsCount      = NotReviewedInteractionsCount;
	Record.LastInteractionDate = LastInteractionDate;
	RecordSet.Write();

EndProcedure

// Locks the InteractionsContactStates information register.
// 
// Parameters:
//  Block       - DataLock - a set lock.
//  DataSource   - ValueTable - a data source to be locked.
//  NameSourceField - String - the source field name that will be used to set the lock by contact.
//
Procedure BlockInteractionContactsStates(Block, DataSource, NameSourceField) Export
	
	LockItem = Block.Add("InformationRegister.InteractionsContactStates"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Contact", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf