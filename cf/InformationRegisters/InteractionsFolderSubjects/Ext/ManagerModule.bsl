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
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	TRUE
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ObjectUpdateAllowed(Interaction)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Generates a blank structure to write to the InteractionsFolderSubjects information register.
//
// Returns:
//  Structure:
//   * SubjectOf - AnyRef
//   * Folder - CatalogRef.EmailMessageFolders
//   * Reviewed - Boolean
//   * ReviewAfter - Date
//   * CalculateReviewedItems - Boolean
//
Function InteractionAttributes() Export

	Result = New Structure;
	Result.Insert("SubjectOf"                , Undefined);
	Result.Insert("Folder"                  , Undefined);
	Result.Insert("Reviewed"            , Undefined);
	Result.Insert("ReviewAfter"       , Undefined);
	Result.Insert("CalculateReviewedItems", True);
	
	Return Result;
	
EndFunction

// Sets a folder, subject, and review attributes for interactions.
//
// Parameters:
//  Interaction - DocumentRef.IncomingEmail
//                 - DocumentRef.OutgoingEmail
//                 - DocumentRef.Meeting
//                 - DocumentRef.PlannedInteraction
//                 - DocumentRef.PhoneCall - Interaction to assign a folder and topic for.
//  Attributes    - See InformationRegisters.InteractionsFolderSubjects.InteractionAttributes.
//  RecordSet - InformationRegisterRecordSet.InteractionsFolderSubjects - a register record set if is created
//                 at the time of the procedure call.
//
Procedure WriteInteractionFolderSubjects(Interaction, Attributes, RecordSet = Undefined) Export
	
	Folder                   = Attributes.Folder;
	SubjectOf                 = Attributes.SubjectOf;
	Reviewed             = Attributes.Reviewed;
	ReviewAfter        = Attributes.ReviewAfter;
	CalculateReviewedItems = Attributes.CalculateReviewedItems;
	
	CreateAndWrite = (RecordSet = Undefined);
	
	If Folder = Undefined And SubjectOf = Undefined And Reviewed = Undefined
		And ReviewAfter = Undefined Then
		Return;
	EndIf;
		
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.InteractionsFolderSubjects");
		LockItem.SetValue("Interaction", Interaction);
		Block.Lock();
		
		If Folder = Undefined Or SubjectOf = Undefined Or Reviewed = Undefined 
			Or ReviewAfter = Undefined Then
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	InteractionsFolderSubjects.SubjectOf,
			|	InteractionsFolderSubjects.EmailMessageFolder,
			|	InteractionsFolderSubjects.Reviewed,
			|	InteractionsFolderSubjects.ReviewAfter
			|FROM
			|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
			|WHERE
			|	InteractionsFolderSubjects.Interaction = &Interaction";
			
			Query.SetParameter("Interaction", Interaction);
			
			Result = Query.Execute();
			If Not Result.IsEmpty() Then
				
				Selection = Result.Select();
				Selection.Next();
				
				If Folder = Undefined Then
					Folder = Selection.EmailMessageFolder;
				EndIf;
				
				If SubjectOf = Undefined Then
					SubjectOf = Selection.SubjectOf;
				EndIf;
				
				If Reviewed = Undefined Then
					Reviewed = Selection.Reviewed;
				EndIf;
				
				If ReviewAfter = Undefined Then
					ReviewAfter = Selection.ReviewAfter;
				EndIf;
				
			EndIf;
		EndIf;
		
		If CreateAndWrite Then
			RecordSet = CreateRecordSet();
			RecordSet.Filter.Interaction.Set(Interaction);
		EndIf;
		Record = RecordSet.Add();
		Record.Interaction          = Interaction;
		Record.SubjectOf                 = SubjectOf;
		Record.EmailMessageFolder = Folder;
		Record.Reviewed             = Reviewed;
		Record.ReviewAfter        = ReviewAfter;
		RecordSet.AdditionalProperties.Insert("CalculateReviewedItems", CalculateReviewedItems);
		
		If CreateAndWrite Then
			RecordSet.Write();
		EndIf;
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Locks the InteractionsFoldersSubjects information register.
// 
// Parameters:
//  Block - DataLock - a lock to be set.
//  Interactions - Array
//                 - DocumentRef.PlannedInteraction
//                 - DocumentRef.Meeting
//                 - DocumentRef.PhoneCall
//                 - DocumentRef.SMSMessage
//                 - DocumentRef.IncomingEmail
//                 - DocumentRef.OutgoingEmail - Documents to lock.
//
Procedure BlockInteractionFoldersSubjects(Block, Interactions) Export
	
	LockItem = Block.Add("InformationRegister.InteractionsFolderSubjects"); 
	If TypeOf(Interactions) = Type("Array") Then
		For Each InteractionHyperlink In Interactions Do
			LockItem.SetValue("Interaction", InteractionHyperlink);
		EndDo	
	Else
		LockItem.SetValue("Interaction", Interactions);
	EndIf;	
	
EndProcedure

// Locks the InteractionsFoldersSubjects information register.
// 
// Parameters:
//  Block       - DataLock - a set lock.
//  DataSource   - ValueTable - a data source to be locked.
//  NameSourceField - String - the source field name that will be used to set the lock by interaction.
//
Procedure BlochFoldersSubjects(Block, DataSource, NameSourceField) Export
	
	LockItem = Block.Add("InformationRegister.InteractionsFolderSubjects"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Interaction", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf
