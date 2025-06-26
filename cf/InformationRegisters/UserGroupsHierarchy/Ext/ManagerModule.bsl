///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// This procedure updates all register data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded, "True".
//                  Otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	Block.Add("InformationRegister.UserGroupsHierarchy");
	
	LockItem = Block.Add("Catalog.UserGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	LockItem = Block.Add("Catalog.ExternalUsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
		
		UsersInternal.UpdateGroupsHierarchy(
			Catalogs.UserGroups.EmptyRef(), ChangesInComposition);
		
		UsersInternal.UpdateGroupsHierarchy(
			Catalogs.ExternalUsersGroups.EmptyRef(), ChangesInComposition);
		
		If ValueIsFilled(ChangesInComposition.ModifiedGroups) Then
			HasChanges = True;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf