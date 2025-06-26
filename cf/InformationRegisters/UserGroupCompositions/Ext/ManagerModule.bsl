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

#Region Internal

// This procedure updates all register data.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	Block.Add("InformationRegister.UserGroupCompositions");
	
	LockItem = Block.Add("Catalog.Users");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.UserGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	LockItem = Block.Add("Catalog.ExternalUsers");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.ExternalUsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		// Update user mapping.
		ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
		
		UsersInternal.UpdateAllUsersGroupComposition(
			Catalogs.Users.EmptyRef(), ChangesInComposition);
		
		UsersInternal.UpdateHierarchicalUserGroupCompositions(
			Catalogs.UserGroups.EmptyRef(), ChangesInComposition);
		
		UsersInternal.AfterUserGroupsUpdate(ChangesInComposition, HasChanges);
		
		// Updating external user mapping
		ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
		
		UsersInternal.UpdateAllUsersGroupComposition(
			Catalogs.ExternalUsers.EmptyRef(), ChangesInComposition);
		
		UsersInternal.UpdateGroupCompositionsByAuthorizationObjectType(Undefined,
			Undefined, ChangesInComposition);
		
		UsersInternal.UpdateHierarchicalUserGroupCompositions(
			Catalogs.ExternalUsersGroups.EmptyRef(), ChangesInComposition);
		
		UsersInternal.AfterUserGroupsUpdate(ChangesInComposition, HasChanges);
		
		UsersInternal.UpdateExternalUsersRoles();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region Private

// This procedure updates data of the registers "UserGroupsHierarchy" and "UserGroupCompositions".
//
// Parameters:
//  HasHierarchyChanges - Boolean - (return value) - If recorded, "True".
//                            Otherwise, it does not change.
//  HasChangesInComposition - Boolean - (return value) - If recorded, "True".
//                            Otherwise, it does not change.
//
Procedure UpdateHierarchyAndComposition(HasHierarchyChanges = Undefined, HasChangesInComposition = Undefined) Export

	Block = New DataLock;
	Block.Add("InformationRegister.UserGroupsHierarchy");
	Block.Add("InformationRegister.UserGroupCompositions");
	
	LockItem = Block.Add("Catalog.Users");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.UserGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	LockItem = Block.Add("Catalog.ExternalUsers");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Block.Add("Catalog.ExternalUsersGroups");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		InformationRegisters.UserGroupsHierarchy.UpdateRegisterData(HasHierarchyChanges);
		UpdateRegisterData(HasChangesInComposition);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf