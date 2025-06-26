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
//  Folder  - CatalogRef.EmailMessageFolders  - a folder, for which the record is being deleted.
//         - Undefined - Entire register will be cleared.
//
Procedure DeleteRecordFromRegister(Folder = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = CreateRecordSet();
	If Folder <> Undefined Then
		RecordSet.Filter.Folder.Set(Folder);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Writes to the information register for the specified folder.
//
// Parameters:
//  Folder  - CatalogRef.EmailMessageFolders - a folder to be recorded.
//  Count  - Number - a number of unreviewed interactions for this folder.
//
Procedure ExecuteRecordToRegister(Folder, Count) Export

	SetPrivilegedMode(True);
	
	Record = CreateRecordManager();
	Record.Folder = Folder;
	Record.NotReviewedInteractionsCount = Count;
	Record.Write(True);

EndProcedure

// Locks the EmailFolderStates information register.
// 
// Parameters:
//  Block       - DataLock - a set lock.
//  DataSource   - ValueTable - a data source to be locked.
//  NameSourceField - String - the source field name that will be used to set the lock by folder.
//
Procedure BlockEmailsFoldersStatus(Block, DataSource, NameSourceField) Export
	
	LockItem = Block.Add("InformationRegister.EmailFolderStates"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Folder", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf