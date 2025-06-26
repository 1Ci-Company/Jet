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

#Region Variables

// 
Var IsNew, PreviousAuthorizationObject;
Var IBUserProcessingParameters; // Parameters to be populated when processing a user.

#EndRegion

// Region Public.
//
// The object API is implemented using "AdditionalProperties".
//
// IBUserDetails - Structure (same as in the "Users" catalog object module).
//
// EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	UsersInternal.UserObjectBeforeWrite(ThisObject, IBUserProcessingParameters);
	// ACC:75-on
	
	// ACC:75-off - The check "DataExchange.Import" should run after the registers are locked.
	If Common.FileInfobase() Then
		UsersInternal.LockRegistersBeforeWritingToFileInformationSystem(False);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	IsNew = IsNew();
	
	If Not ValueIsFilled(AuthorizationObject) Then
		ErrorText = NStr("en = 'No authorization object is set for the external user.';");
		Raise ErrorText;
	Else
		ErrorText = "";
		If UsersInternal.AuthorizationObjectIsInUse(
		         AuthorizationObject, Ref, , , ErrorText) Then
			Raise ErrorText;
		EndIf;
	EndIf;
	
	// Checking whether the authorization object was not changed.
	If IsNew Then
		PreviousAuthorizationObject = Null;
	Else
		PreviousAuthorizationObject = Common.ObjectAttributeValue(
			Ref, "AuthorizationObject");
		
		If ValueIsFilled(PreviousAuthorizationObject)
		   And PreviousAuthorizationObject <> AuthorizationObject Then
			
			ErrorText = NStr("en = 'Cannot change a previously specified authorization object.';");
			Raise ErrorText;
		EndIf;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	If DataExchange.Load And IBUserProcessingParameters <> Undefined Then
		UsersInternal.EndIBUserProcessing(
			ThisObject, IBUserProcessingParameters);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Updating the content of the group that contains the new external user (provided that it is in a group).
	If AdditionalProperties.Property("NewExternalUserGroup")
	   And ValueIsFilled(AdditionalProperties.NewExternalUserGroup) Then
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.ExternalUsersGroups");
		LockItem.SetValue("Ref", AdditionalProperties.NewExternalUserGroup);
		Block.Lock();
		
		GroupObject1 = AdditionalProperties.NewExternalUserGroup.GetObject(); // CatalogObject.ExternalUsersGroups
		GroupObject1.Content.Add().ExternalUser = Ref;
		GroupObject1.Write();
	EndIf;
	
	// Update the membership of the automatic group "AllExternalUsers"
	// and groups with the "AllAuthorizationObjects" flag raised.
	ChangesInComposition = UsersInternal.GroupsCompositionNewChanges();
	UsersInternal.UpdateUserGroupCompositionUsage(Ref, ChangesInComposition);
	UsersInternal.UpdateAllUsersGroupComposition(Ref, ChangesInComposition);
	UsersInternal.UpdateGroupCompositionsByAuthorizationObjectType(Undefined,
		Ref, ChangesInComposition);
	
	UsersInternal.EndIBUserProcessing(ThisObject,
		IBUserProcessingParameters);
	
	UsersInternal.AfterUserGroupsUpdate(ChangesInComposition);
	
	If PreviousAuthorizationObject <> AuthorizationObject
	   And Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		AuthorizationObjects = New Array;
		If PreviousAuthorizationObject <> Null Then
			AuthorizationObjects.Add(PreviousAuthorizationObject);
		EndIf;
		AuthorizationObjects.Add(AuthorizationObject);
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.AfterChangeExternalUserAuthorizationObject(AuthorizationObjects);
	EndIf;
	
	SSLSubsystemsIntegration.AfterAddChangeUserOrGroup(Ref, IsNew);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// ACC:75-off - A "DataExchange" check. Import should start on demand after the infobase user is handled.
	UsersInternal.UserObjectBeforeDelete(ThisObject);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	UsersInternal.UpdateGroupsCompositionBeforeDeleteUserOrGroup(Ref);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	AdditionalProperties.Insert("CopyingValue", CopiedObject.Ref);
	
	IBUserID = Undefined;
	ServiceUserID = Undefined;
	Prepared = False;
	
	Comment = "";
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf