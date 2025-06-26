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

// StandardSubsystems.BatchEditObjects

// Returns the object attributes that are not recommended to be edited
// using a bulk attribute modification data processor.
//
// Returns:
//  Array of String
//
Function AttributesToSkipInBatchProcessing() Export
	
	NotAttributesToEdit = New Array;
	NotAttributesToEdit.Add("UsersType");
	NotAttributesToEdit.Add("User");
	NotAttributesToEdit.Add("MainSuppliedProfileAccessGroup");
	NotAttributesToEdit.Add("AccessKinds.*");
	NotAttributesToEdit.Add("AccessValues.*");
	
	Return NotAttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsFolder
	|	OR Profile <> VALUE(Catalog.AccessGroupProfiles.Administrator)
	|	  AND IsAuthorizedUser(EmployeeResponsible)";

EndProcedure

// End StandardSubsystems.AccessManagement

// SaaSTechnology.ExportImportData

// Attached in ExportImportDataOverridable.OnRegisterDataExportHandlers.
//
// Parameters:
//   Container - DataProcessorObject.ExportImportDataContainerManager
//   ObjectExportManager - DataProcessorObject.ExportImportDataInfobaseDataExportManager
//   Serializer - XDTOSerializer
//   Object - ConstantValueManager
//          - CatalogObject
//          - DocumentObject
//          - BusinessProcessObject
//          - TaskObject
//          - ChartOfAccountsObject
//          - ExchangePlanObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - SequenceRecordSet
//          - RecalculationRecordSet
//   Artifacts - Array of XDTODataObject
//   Cancel - Boolean
//
Procedure BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel) Export
	
	AccessManagementInternal.BeforeExportObject(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel);
	
EndProcedure

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("Description");
	Fields.Add("User");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If Not ValueIsFilled(Data.User) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	Presentation = AccessManagementInternalClientServer.PresentationAccessGroups(Data);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure ExcludeExpiredMembers() Export
	
	CurrentSessionDateDayStart = BegOfDay(CurrentSessionDate());
	
	Query = New Query;
	Query.SetParameter("DateEmpty", '00010101');
	Query.SetParameter("CurrentSessionDateDayStart", CurrentSessionDateDayStart);
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroups_Users.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroups_Users
	|WHERE
	|	AccessGroups_Users.ValidityPeriod <> &DateEmpty
	|	AND AccessGroups_Users.ValidityPeriod <= &CurrentSessionDateDayStart";
	
	Selection = Query.Execute().Select();
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	
	While Selection.Next() Do
		LockItem.SetValue("Ref", Selection.Ref);
		BeginTransaction();
		Try
			Block.Lock();
			AccessGroupObject = Selection.Ref.GetObject();
			If AccessGroupObject <> Undefined Then
				HasChanges = False;
				IndexOf = AccessGroupObject.Users.Count() - 1;
				While IndexOf >= 0 Do
					TSRow = AccessGroupObject.Users[IndexOf];
					If ValueIsFilled(TSRow.ValidityPeriod)
					   And TSRow.ValidityPeriod <= CurrentSessionDateDayStart Then
						AccessGroupObject.Users.Delete(IndexOf);
						HasChanges = True;
					EndIf;
					IndexOf = IndexOf - 1;
				EndDo;
				If HasChanges Then
					AccessGroupObject.Write();
				EndIf;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// See AccessManagement.AdministratorsAccessGroup
Function AdministratorsAccessGroup(ProfileAdministrator = Undefined) Export
	
	If ValueIsFilled(ProfileAdministrator) Then
		UsersInternal.CheckSafeModeIsDisabled(
			"Catalogs.AccessGroups.AdministratorsAccessGroup");
	EndIf;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(ProfileAdministrator) Then
		ProfileAdministrator = AccessManagement.ProfileAdministrator();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &ProfileAdministrator
	|
	|ORDER BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.PredefinedDataName = &PredefinedDataName
	|
	|ORDER BY
	|	Ref";
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	Query.SetParameter("PredefinedDataName", "Administrators");
	
	QueryResults = Query.ExecuteBatch();
	SelectionByProfile           = QueryResults[0].Select();
	SelectionByPredefined = QueryResults[1].Select();
	
	If SelectionByProfile.Next()
	   And SelectionByPredefined.Next()
	   And SelectionByProfile.Count() = 1
	   And SelectionByPredefined.Count() = 1
	   And SelectionByProfile.Ref = SelectionByPredefined.Ref Then
		
		Return SelectionByProfile.Ref;
	EndIf;
	
	Block = New DataLock;
	Block.Add("Catalog.AccessGroups");
	
	BeginTransaction();
	Try
		Block.Lock();
		QueryResults = Query.ExecuteBatch();
		SelectionByProfile           = QueryResults[0].Select();
		SelectionByPredefined = QueryResults[1].Select();
		If SelectionByProfile.Next() Then
			AccessGroupObject = SelectionByProfile.Ref.GetObject();
			If AccessGroupObject.PredefinedDataName <> "Administrators" Then
				AccessGroupObject.PredefinedDataName = "Administrators";
			EndIf;
		ElsIf SelectionByPredefined.Next() Then
			AccessGroupObject = SelectionByPredefined.Ref.GetObject();
			AccessGroupObject.Profile = ProfileAdministrator;
		Else
			AccessGroupByName = AccessGroupByName(
				NStr("en = 'Administrators';", Common.DefaultLanguageCode()));
			If ValueIsFilled(AccessGroupByName) Then
				AccessGroupObject = AccessGroupByName.GetObject();
			Else
				AccessGroupObject = CreateItem();
			EndIf;
			AccessGroupObject.Profile = ProfileAdministrator;
			AccessGroupObject.PredefinedDataName = "Administrators";
		EndIf;
		If AccessGroupObject.Modified() Then
			InfobaseUpdate.WriteObject(AccessGroupObject, False, False);
		EndIf;
		
		ObjectsToUnlink = New Map;
		While SelectionByProfile.Next() Do
			If SelectionByProfile.Ref <> AccessGroupObject.Ref Then
				ObjectsToUnlink.Insert(SelectionByProfile.Ref);
			EndIf;
		EndDo;
		While SelectionByPredefined.Next() Do
			If SelectionByPredefined.Ref <> AccessGroupObject.Ref Then
				ObjectsToUnlink.Insert(SelectionByPredefined.Ref);
			EndIf;
		EndDo;
		For Each KeyAndValue In ObjectsToUnlink Do
			CurrentAccessGroupObject = KeyAndValue.Key.GetObject();
			CurrentAccessGroupObject.Profile = Undefined;
			CurrentAccessGroupObject.PredefinedDataName = "";
			InfobaseUpdate.WriteObject(CurrentAccessGroupObject, False, False);
		EndDo;
		For Each KeyAndValue In ObjectsToUnlink Do
			CurrentAccessGroupObject = KeyAndValue.Key.GetObject();
			InfobaseUpdate.WriteObject(CurrentAccessGroupObject);
		EndDo;
		
		AccessGroupObject.Description = NStr("en = 'Administrators';",
			Common.DefaultLanguageCode());
		InfobaseUpdate.WriteObject(AccessGroupObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return AccessGroupObject.Ref;
	
EndFunction

// For the AdministratorsAccessGroup function.
Function AccessGroupByName(Description)
	
	Query = New Query;
	Query.SetParameter("Description", Description);
	Query.Text =
	"SELECT TOP 1
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Description = &Description
	|
	|ORDER BY
	|	Ref";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Sets a deletion mark for access groups if the
// deletion mark is set for the access group profile. It is required, for example,
// upon deleting the predefined profiles of access groups,
// since the platform does not call object handlers
// when setting the deletion mark for former predefined
// items upon the database configuration update.
//
// Parameters:
//  HasChanges - Boolean - return value. If recorded,
//                  True is set, otherwise, it does not change.
//
Procedure MarkForDeletionSelectedProfilesAccessGroups(HasChanges = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("ProfileAdministrator", AccessManagement.ProfileAdministrator());
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile <> &ProfileAdministrator
	|	AND AccessGroups.Profile.DeletionMark
	|	AND NOT AccessGroups.DeletionMark
	|	AND NOT AccessGroups.Predefined";
	
	Selection = Query.Execute().Select();
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	
	While Selection.Next() Do
		LockItem.SetValue("Ref", Selection.Ref);
		BeginTransaction();
		Try
			Block.Lock();
			AccessGroupObject = Selection.Ref.GetObject();
			AccessGroupObject.DeletionMark = True;
			InfobaseUpdate.WriteObject(AccessGroupObject);
			InformationRegisters.AccessGroupsTables.UpdateRegisterData(Selection.Ref);
			InformationRegisters.AccessGroupsValues.UpdateRegisterData(Selection.Ref);
			// @skip-check query-in-loop - Batch-wise data processing within a transaction
			UsersForUpdate = UsersForRolesUpdate(Undefined, AccessGroupObject);
			AccessManagement.UpdateUserRoles(UsersForUpdate);
			HasChanges = True;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

// Updates access kinds of access groups for the specified profile.
//  It is possible not to remove access kinds from the access group,
// which are deleted in the access group profile,
// if access values are assigned in the access group by
// the type of access to be deleted.
// 
// Parameters:
//  Profile - CatalogRef.AccessGroupProfiles - an access group profile.
//
//  UpdatingAccessGroupsWithObsoleteSettings - Boolean - update access groups.
//
// Returns:
//  Boolean - if True, an access group is changed,
//           if False, nothing is changed.
//
Function UpdateProfileAccessGroups(Profile, UpdatingAccessGroupsWithObsoleteSettings = False) Export
	
	AccessGroupUpdated = False;
	
	ProfileAccessKinds = Common.ObjectAttributeValue(Profile, "AccessKinds").Unload();
	IndexOf = ProfileAccessKinds.Count() - 1;
	While IndexOf >= 0 Do
		String = ProfileAccessKinds[IndexOf];
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(String.AccessKind);
		
		If AccessKindProperties = Undefined Then
			ProfileAccessKinds.Delete(String);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("ProfileAdministrator",        AccessManagement.ProfileAdministrator());
	Query.SetParameter("AdministratorsAccessGroup", AccessManagement.AdministratorsAccessGroup());
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	NOT(AccessGroups.Profile <> &Profile
	|				AND NOT(&Profile = &ProfileAdministrator
	|						AND AccessGroups.Ref = &AdministratorsAccessGroup))";
	
	Query.SetParameter("Profile", Profile);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		// Checking if an access group must or can be updated.
		AccessGroup = Selection.Ref.GetObject();
		
		If AccessGroup.Ref = AccessManagement.AdministratorsAccessGroup()
		   And AccessGroup.Profile <> AccessManagement.ProfileAdministrator() Then
			// Setting the Administrator profile if it is not set.
			AccessGroup.Profile = AccessManagement.ProfileAdministrator();
		EndIf;
		
		// Checking access kind content.
		AccessKindsContentChanged1 = False;
		HasAccessKindsToDeleteWithSpecifiedAccessValues = False;
		If AccessGroup.AccessKinds.Count() <> ProfileAccessKinds.FindRows(New Structure("Predefined", False)).Count() Then
			AccessKindsContentChanged1 = True;
		Else
			For Each AccessKindRow In AccessGroup.AccessKinds Do
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, Predefined", AccessKindRow.AccessKind, False)).Count() = 0 Then
					AccessKindsContentChanged1 = True;
					If AccessGroup.AccessValues.Find(AccessKindRow.AccessKind, "AccessKind") <> Undefined Then
						HasAccessKindsToDeleteWithSpecifiedAccessValues = True;
					EndIf;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessKindsContentChanged1
		   And ( UpdatingAccessGroupsWithObsoleteSettings
		       Or Not HasAccessKindsToDeleteWithSpecifiedAccessValues ) Then
			// Access group update.
			// 1. Delete unnecessary access kinds and access values.
			CurrentRowNumber1 = AccessGroup.AccessKinds.Count()-1;
			While CurrentRowNumber1 >= 0 Do
				CurrentAccessKind = AccessGroup.AccessKinds[CurrentRowNumber1].AccessKind;
				If ProfileAccessKinds.FindRows(New Structure("AccessKind, Predefined", CurrentAccessKind, False)).Count() = 0 Then
					AccessKindValuesRows = AccessGroup.AccessValues.FindRows(New Structure("AccessKind", CurrentAccessKind));
					For Each ValueRow In AccessKindValuesRows Do
						AccessGroup.AccessValues.Delete(ValueRow);
					EndDo;
					AccessGroup.AccessKinds.Delete(CurrentRowNumber1);
				EndIf;
				CurrentRowNumber1 = CurrentRowNumber1 - 1;
			EndDo;
			// 2. Add new access kinds (if any).
			For Each AccessKindRow In ProfileAccessKinds Do
				If Not AccessKindRow.Predefined 
				   And AccessGroup.AccessKinds.Find(AccessKindRow.AccessKind, "AccessKind") = Undefined Then
					
					NewRow = AccessGroup.AccessKinds.Add();
					NewRow.AccessKind   = AccessKindRow.AccessKind;
					NewRow.AllAllowed = AccessKindRow.AllAllowed;
				EndIf;
			EndDo;
		EndIf;
		
		If AccessGroup.Modified() Then
			
			If Not InfobaseUpdate.InfobaseUpdateInProgress()
			   And Not InfobaseUpdate.IsCallFromUpdateHandler() Then
				
				LockDataForEdit(AccessGroup.Ref, AccessGroup.DataVersion);
			EndIf;
			
			If Not Catalogs.ExtensionsVersions.AllExtensionsConnected() Then
				PreviousValues1 = Common.ObjectAttributesValues(AccessGroup.Ref, "AccessKinds, AccessValues");
				Catalogs.AccessGroupProfiles.RestoreNonexistentViewsFromAccessValue(PreviousValues1, AccessGroup);
			EndIf;
			
			AccessGroup.AdditionalProperties.Insert("DoNotUpdateUsersRoles");
			InfobaseUpdate.WriteObject(AccessGroup);
			AccessGroupUpdated = True;
			
			If Not InfobaseUpdate.InfobaseUpdateInProgress()
			   And Not InfobaseUpdate.IsCallFromUpdateHandler() Then
				
				UnlockDataForEdit(AccessGroup.Ref);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return AccessGroupUpdated;
	
EndFunction

// Returns a reference to a parent group of personal access groups.
//  If the parent group is not found, it will be created.
//
// Parameters:
//  DoNotCreate  - Boolean - if True, the parent is not automatically created
//                 and the function returns Undefined if the parent is not found.
//
//  ItemsGroupDescription - String
//
// Returns:
//  CatalogRef.AccessGroups - a parent group reference.
//
Function PersonalAccessGroupsParent(Val DoNotCreate = False, ItemsGroupDescription = "") Export
	
	SetPrivilegedMode(True);
	
	ItemsGroupDescription = NStr("en = 'Personal access groups';");
	
	Query = New Query(
		"SELECT
		|	AccessGroups.Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Description LIKE &ItemsGroupDescription ESCAPE ""~""
		|	AND AccessGroups.IsFolder");
	Query.SetParameter("ItemsGroupDescription", 
		Common.GenerateSearchQueryString(ItemsGroupDescription));
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Items_Group = Selection.Ref;
	ElsIf DoNotCreate Then
		Items_Group = Undefined;
	Else
		ItemsGroupObject = CreateFolder();
		ItemsGroupObject.Description = ItemsGroupDescription;
		ItemsGroupObject.Write();
		Items_Group = ItemsGroupObject.Ref;
	EndIf;
	
	Return Items_Group;
	
EndFunction

Function AccessKindsOrAccessValuesChanged(PreviousValues1, CurrentObject) Export
	
	If PreviousValues1.Ref <> CurrentObject.Ref Then
		Return True;
	EndIf;
	
	AccessKinds     = PreviousValues1.AccessKinds.Unload();
	AccessValues = PreviousValues1.AccessValues.Unload();
	
	If AccessKinds.Count()     <> CurrentObject.AccessKinds.Count()
	 Or AccessValues.Count() <> CurrentObject.AccessValues.Count() Then
		
		Return True;
	EndIf;
	
	Filter = New Structure("AccessKind, AllAllowed");
	For Each String In CurrentObject.AccessKinds Do
		FillPropertyValues(Filter, String);
		If AccessKinds.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Filter = New Structure("AccessKind, AccessValue, IncludeSubordinateAccessValues");
	For Each String In CurrentObject.AccessValues Do
		FillPropertyValues(Filter, String);
		If AccessValues.FindRows(Filter).Count() = 0 Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function UsersForRolesUpdate(PreviousValues1, DataElement) Export
	
	If PreviousValues1 = Undefined Then
		PreviousValues1 = New Structure("Ref, Profile, DeletionMark")
	EndIf;
	
	// Updating roles for added, remaining, and removed users.
	Query = New Query;
	
	Query.SetParameter("NewMembers", ?(TypeOf(DataElement) <> Type("ObjectDeletion"),
		DataElement.Users.UnloadColumn("User"), New Array));
	
	Query.SetParameter("OldMembers", ?(DataElement.Ref = PreviousValues1.Ref,
		PreviousValues1.Users.Unload().UnloadColumn("User"), New Array));
	
	If TypeOf(DataElement)         =  Type("ObjectDeletion")
	 Or DataElement.Profile         <> PreviousValues1.Profile
	 Or DataElement.DeletionMark <> PreviousValues1.DeletionMark Then
		
		// Selecting all access group members.
		Query.Text =
		"SELECT DISTINCT
		|	UserGroupCompositions.User AS User
		|FROM
		|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|WHERE
		|	(UserGroupCompositions.UsersGroup IN (&OldMembers)
		|			OR UserGroupCompositions.UsersGroup IN (&NewMembers))";
	Else
		// Selecting changes of access group members.
		Query.Text =
		"SELECT
		|	Data.User AS User
		|FROM
		|	(SELECT DISTINCT
		|		UserGroupCompositions.User AS User,
		|		-1 AS LineChangeType
		|	FROM
		|		InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|	WHERE
		|		UserGroupCompositions.UsersGroup IN(&OldMembers)
		|	
		|	UNION ALL
		|	
		|	SELECT DISTINCT
		|		UserGroupCompositions.User,
		|		1
		|	FROM
		|		InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|	WHERE
		|		UserGroupCompositions.UsersGroup IN(&NewMembers)) AS Data
		|
		|GROUP BY
		|	Data.User
		|
		|HAVING
		|	SUM(Data.LineChangeType) <> 0";
	EndIf;
	
	Return Query.Execute().Unload().UnloadColumn("User");
	
EndFunction

Function UsersForRolesUpdateByProfile(Profiles) Export
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	
	Query.Text =
	"SELECT DISTINCT
	|	UserGroupCompositions.User AS User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
	|		ON UserGroupCompositions.UsersGroup = AccessGroups_Users.User
	|			AND (AccessGroups_Users.Ref.Profile IN (&Profiles))";
	
	Return Query.Execute().Unload().UnloadColumn("User");
	
EndFunction

Function RolesForUpdatingRights(PreviousValues1, DataElement) Export
	
	If PreviousValues1 = Undefined Then
		PreviousValues1 = New Structure("Ref, Profile, DeletionMark")
	EndIf;
	
	// Updating roles for added, remaining, and removed users.
	Query = New Query;
	
	Query.SetParameter("NewProfile",
		?(TypeOf(DataElement) <> Type("ObjectDeletion") And Not DataElement.DeletionMark,
		DataElement.Profile, Catalogs.AccessGroupProfiles.EmptyRef()));
	
	Query.SetParameter("OldProfile",
		?(DataElement.Ref = PreviousValues1.Ref And Not PreviousValues1.DeletionMark,
		PreviousValues1.Profile, Catalogs.AccessGroupProfiles.EmptyRef()));
	
	If TypeOf(DataElement) = Type("ObjectDeletion")
	 Or DataElement.DeletionMark <> PreviousValues1.DeletionMark Then
		
		// Select all roles of the old or new access group profile.
		Query.Text =
		"SELECT DISTINCT
		|	ProfilesRoles.Role AS Role
		|FROM
		|	Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
		|WHERE
		|	ProfilesRoles.Ref IN (&OldProfile, &NewProfile)";
	Else
		// Select access group role changes.
		Query.Text =
		"SELECT
		|	Data.Role AS Role
		|FROM
		|	(SELECT DISTINCT
		|		ProfilesRoles.Role AS Role,
		|		-1 AS LineChangeType
		|	FROM
		|		Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
		|	WHERE
		|		ProfilesRoles.Ref = &OldProfile
		|	
		|	UNION ALL
		|	
		|	SELECT DISTINCT
		|		ProfilesRoles.Role,
		|		1
		|	FROM
		|		Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
		|	WHERE
		|		ProfilesRoles.Ref = &NewProfile) AS Data
		|
		|GROUP BY
		|	Data.Role
		|
		|HAVING
		|	SUM(Data.LineChangeType) <> 0";
	EndIf;
	
	Return Query.Execute().Unload().UnloadColumn("Role");
	
EndFunction

Function ProfileAccessGroups(Profiles) Export
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile IN(&Profiles)
	|	AND NOT AccessGroups.IsFolder";
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload().UnloadColumn("Ref");
	
EndFunction

// For internal use only.
//
// Parameters:
//  Object - CatalogObject.AccessGroupProfiles
//  PreviousValues1 - Structure
//
// Returns:
//  Boolean
//
Function IsProfileMarkedForDeletion(Object, PreviousValues1) Export
	Return Object.DeletionMark And PreviousValues1.DeletionMark = False;
EndFunction

// For internal use only.
//
// Parameters:
//  Object - CatalogObject.AccessGroups
//         - CatalogObject.AccessGroupProfiles
//  PreviousValues1 - Structure
//
Procedure RegisterChangeInAccessGroupsMembers(Object, PreviousValues1) Export
	
	Data = New Structure;
	Data.Insert("DataStructureVersion", 1);
	Data.Insert("ChangesInMembers", New Array);
	Data.Insert("AccessGroupsPresentation", New Array);
	Data.Insert("UserGroupCompositions", New Array);
	
	If TypeOf(Object) = Type("CatalogObject.AccessGroups") Then
		If Object.AdditionalProperties.Property("MarkAccessGroupForDeletionWhenProfileMarkedForDeletion") Then
			If Not PrivilegedMode() Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Property ""%1"" is supported only in privileged mode.';"),
					"MarkAccessGroupForDeletionWhenProfileMarkedForDeletion");
				Raise ErrorText;
			EndIf;
			Return;
		EndIf;
		ProfileDeletionMark = Common.ObjectAttributeValue(Object.Profile, "DeletionMark");
		ProfileDeletionMark = ?(TypeOf(ProfileDeletionMark) = Type("Boolean"), ProfileDeletionMark, False);
		
		WasAccessGroupActivityChanged = Object.DeletionMark <> PreviousValues1.DeletionMark
			Or Object.Profile <> PreviousValues1.Profile
			Or ProfileDeletionMark <> PreviousValues1.ProfileDeletionMark;
		
		ChangesInMembers = Object.Users.Unload();
		ChangesInMembers.Indexes.Add("User");
		ChangesInMembers.GroupBy("User, ValidityPeriod");
		ChangesInMembers.Columns.Add("ChangeType", New TypeDescription("String"));
		ChangesInMembers.FillValues("Added2", "ChangeType");
		ChangesInMembers.Columns.Add("OldValidityPeriod", New TypeDescription("Date"));
		
		If PreviousValues1.Users <> Undefined Then
			Selection = PreviousValues1.Users.Select();
			While Selection.Next() Do
				FoundRow = ChangesInMembers.Find(Selection.User, "User");
				If FoundRow = Undefined Then
					NewRow = ChangesInMembers.Add();
					FillPropertyValues(NewRow, Selection);
					NewRow.ChangeType = "Deleted";
				ElsIf FoundRow.ValidityPeriod <> Selection.ValidityPeriod Then
					FoundRow.OldValidityPeriod = Selection.ValidityPeriod;
					FoundRow.ChangeType = "IsChanged";
				ElsIf WasAccessGroupActivityChanged Then
					FoundRow.OldValidityPeriod = FoundRow.ValidityPeriod;
					FoundRow.ChangeType = "IsChanged";
				Else
					ChangesInMembers.Delete(FoundRow);
				EndIf;
			EndDo;
		EndIf;
		
		If Not WasAccessGroupActivityChanged
		   And Not ValueIsFilled(ChangesInMembers) Then
			Return;
		EndIf;
		
		ActiveMembers = ActiveMembers(ChangesInMembers);
		ChangesInMembers.Columns.Add("AccessGroup");
		ChangesInMembers.FillValues(Object.Ref, "AccessGroup");
		
		Properties = New Structure;
		Properties.Insert("AccessGroup", SerializedRef(Object.Ref));
		Properties.Insert("Presentation", RepresentationOfTheReference(Object.Ref));
		Properties.Insert("DeletionMark", Object.DeletionMark);
		Properties.Insert("Profile", SerializedRef(Object.Profile));
		Properties.Insert("ProfilePresentation", RepresentationOfTheReference(Object.Profile));
		Properties.Insert("ProfileDeletionMark", ProfileDeletionMark);
		Properties.Insert("OldPropertyValues", New Structure);
		
		If Object.DeletionMark <> PreviousValues1.DeletionMark Then
			Properties.OldPropertyValues.Insert("DeletionMark", PreviousValues1.DeletionMark);
		EndIf;
		If Object.Profile <> PreviousValues1.Profile Then
			Properties.OldPropertyValues.Insert("Profile", SerializedRef(PreviousValues1.Profile));
			ProfileOldPresentation = RepresentationOfTheReference(PreviousValues1.Profile);
			If Properties.ProfilePresentation <> ProfileOldPresentation Then
				Properties.OldPropertyValues.Insert("ProfilePresentation", ProfileOldPresentation);
			EndIf;
		EndIf;
		If ProfileDeletionMark <> PreviousValues1.ProfileDeletionMark Then
			Properties.OldPropertyValues.Insert("ProfileDeletionMark", PreviousValues1.ProfileDeletionMark);
		EndIf;
		Data.AccessGroupsPresentation.Add(Properties);
	Else
		If Object.DeletionMark = PreviousValues1.DeletionMark Then
			Return;
		EndIf;
		AccessGroupToExclude = Catalogs.AccessGroups.EmptyRef();
		If Object.AdditionalProperties.Property("UnmarkProfileForDeletionWhenAccessGroupUnmarkedForDeletion") Then
			If Not PrivilegedMode() Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Property ""%1"" is supported only in privileged mode.';"),
					"UnmarkProfileForDeletionWhenAccessGroupUnmarkedForDeletion");
				Raise ErrorText;
			EndIf;
			AccessGroupToExclude =
				Object.AdditionalProperties.UnmarkProfileForDeletionWhenAccessGroupUnmarkedForDeletion;
		EndIf;
		Query = New Query;
		Query.SetParameter("AccessGroupToExclude", AccessGroupToExclude);
		Query.SetParameter("Profile", Object.Ref);
		Query.SetParameter("IsNewDeletionMark", IsProfileMarkedForDeletion(Object, PreviousValues1));
		// ACC:1377-off - No.654.2.1. All four types are required for requests using dot notation.
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref,
		|	&IsNewDeletionMark AS DeletionMark
		|INTO AccessGroups
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.Ref <> &AccessGroupToExclude
		|	AND NOT AccessGroups.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccessGroups.Ref AS Ref,
		|	AccessGroups.DeletionMark AS DeletionMark
		|FROM
		|	AccessGroups AS AccessGroups
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccessGroupsMembers.Ref AS AccessGroup,
		|	AccessGroupsMembers.User AS User,
		|	NOT ISNULL(AccessGroupsMembers.User.DeletionMark, TRUE)
		|		AND NOT ISNULL(AccessGroupsMembers.User.Invalid, FALSE) AS Used,
		|	AccessGroupsMembers.ValidityPeriod AS ValidityPeriod,
		|	AccessGroupsMembers.ValidityPeriod AS OldValidityPeriod
		|FROM
		|	AccessGroups AS AccessGroups
		|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsMembers
		|		ON (AccessGroupsMembers.Ref = AccessGroups.Ref)";
		// ACC:1377-on
		QueryResults = Query.ExecuteBatch();
		If QueryResults[1].IsEmpty() Then
			Return;
		EndIf;
		
		ChangesInMembers = QueryResults[2].Unload();
		ChangesInMembers.Columns.Add("ChangeType", New TypeDescription("String"));
		ChangesInMembers.FillValues("IsChanged", "ChangeType");
		ActiveMembers = Undefined;
		
		Selection = QueryResults[1].Select();
		While Selection.Next() Do
			Properties = New Structure;
			Properties.Insert("AccessGroup", SerializedRef(Selection.Ref));
			Properties.Insert("Presentation", RepresentationOfTheReference(Selection.Ref));
			Properties.Insert("DeletionMark", Selection.DeletionMark);
			Properties.Insert("Profile", SerializedRef(Object.Ref));
			Properties.Insert("ProfilePresentation", RepresentationOfTheReference(Object.Ref));
			Properties.Insert("ProfileDeletionMark", Object.DeletionMark);
			Properties.Insert("OldPropertyValues", New Structure);
			
			If Object.Ref <> PreviousValues1.Ref Then
				Properties.OldPropertyValues.Insert("Profile", SerializedRef(PreviousValues1.Ref));
				ProfileOldPresentation = RepresentationOfTheReference(PreviousValues1.Ref);
				If Properties.ProfilePresentation <> ProfileOldPresentation Then
					Properties.OldPropertyValues.Insert("ProfilePresentation", ProfileOldPresentation);
				EndIf;
			EndIf;
			If Object.DeletionMark <> PreviousValues1.DeletionMark Then
				Properties.OldPropertyValues.Insert("ProfileDeletionMark",
					?(TypeOf(PreviousValues1.DeletionMark) = Type("Boolean"),
						PreviousValues1.DeletionMark, False));
			EndIf;
			Data.AccessGroupsPresentation.Add(Properties);
		EndDo;
	EndIf;
	
	AddedUserGroups = New Map;
	UserGroups = New Array;
	GroupsTypesDetails = New TypeDescription("CatalogRef.UserGroups,
		|CatalogRef.ExternalUsersGroups");
	
	For Each String In ChangesInMembers Do
		If Not ValueIsFilled(String.User) Then
			Continue;
		EndIf;
		If GroupsTypesDetails.ContainsType(TypeOf(String.User))
		   And AddedUserGroups.Get(String.User) = Undefined Then
			UserGroups.Add(String.User);
		EndIf;
		Properties = New Structure;
		Properties.Insert("AccessGroup", SerializedRef(String.AccessGroup));
		Properties.Insert("Member", SerializedRef(String.User));
		Properties.Insert("IsMemberUsed", ?(ActiveMembers = Undefined, String.Used,
			ActiveMembers.Find(String.User, "User") <> Undefined));
		Properties.Insert("ParticipantPresentation", RepresentationOfTheReference(String.User));
		Properties.Insert("ValidityPeriod", String.ValidityPeriod);
		Properties.Insert("OldPropertyValues", New Structure);
		If String.ChangeType = "IsChanged"
		   And String.ValidityPeriod <> String.OldValidityPeriod Then
			Properties.OldPropertyValues.Insert("ValidityPeriod", String.OldValidityPeriod);
		EndIf;
		Properties.Insert("ChangeType", String.ChangeType);
		Data.ChangesInMembers.Add(Properties);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("UserGroups", UserGroups);
	Query.SetParameter("AllUsersGroup", Users.AllUsersGroup());
	Query.SetParameter("AllExternalUsersGroup", ExternalUsers.AllExternalUsersGroup());
	Query.Text =
	"SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	UserGroupCompositions.User AS User,
	|	UserGroupCompositions.Used AS Used,
	|	PRESENTATION(UserGroupCompositions.User) AS UserPresentation2,
	|	NOT UserGroupsComposition.User IS NULL
	|		OR NOT ExternalUserGroupsComposition.ExternalUser IS NULL
	|		OR UserGroupCompositions.UsersGroup = &AllUsersGroup
	|		OR UserGroupCompositions.UsersGroup = &AllExternalUsersGroup AS UserInGroup
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		LEFT JOIN Catalog.UserGroups.Content AS UserGroupsComposition
	|		ON (UserGroupsComposition.Ref = UserGroupCompositions.UsersGroup)
	|			AND (UserGroupsComposition.User = UserGroupCompositions.User)
	|		LEFT JOIN Catalog.ExternalUsersGroups.Content AS ExternalUserGroupsComposition
	|		ON (ExternalUserGroupsComposition.Ref = UserGroupCompositions.UsersGroup)
	|			AND (ExternalUserGroupsComposition.ExternalUser = UserGroupCompositions.User)
	|WHERE
	|	UserGroupCompositions.UsersGroup IN(&UserGroups)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Properties = New Structure;
		Properties.Insert("UsersGroup", SerializedRef(Selection.UsersGroup));
		Properties.Insert("User", SerializedRef(Selection.User));
		Properties.Insert("IsBelongToLowerLevelGroup", Not Selection.UserInGroup);
		Properties.Insert("Used", Selection.Used);
		Properties.Insert("UserPresentation2", Selection.UserPresentation2);
		Data.UserGroupCompositions.Add(Properties);
	EndDo;
	
	EventName = AccessManagementInternal.NameOfLogEventAccessGroupsMembersChanged();
	
	WriteLogEvent(EventName,
		EventLogLevel.Information,
		Object.Metadata(),
		Common.ValueToXMLString(Data),
		,
		EventLogEntryTransactionMode.Transactional);
	
EndProcedure

// Intended for procedure "RegisterChangeInAccessGroupsMembers".
Function ActiveMembers(ChangesInMembers)
	
	Attendees = ChangesInMembers.Copy(, "User");
	Attendees.GroupBy("User");
	
	Query = New Query;
	Query.SetParameter("Attendees", Attendees);
	Query.Text =
	"SELECT
	|	Attendees.User AS User
	|INTO Attendees
	|FROM
	|	&Attendees AS Attendees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Attendees.User AS User
	|FROM
	|	Attendees AS Attendees
	|		LEFT JOIN Catalog.Users AS Users
	|		ON (Users.Ref = Attendees.User)
	|		LEFT JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (ExternalUsers.Ref = Attendees.User)
	|		LEFT JOIN Catalog.UserGroups AS UserGroups
	|		ON (UserGroups.Ref = Attendees.User)
	|		LEFT JOIN Catalog.ExternalUsersGroups AS ExternalUsersGroups
	|		ON (ExternalUsersGroups.Ref = Attendees.User)
	|WHERE
	|	CASE
	|			WHEN NOT Users.Ref IS NULL
	|				THEN NOT Users.DeletionMark
	|						AND NOT Users.Invalid
	|			WHEN NOT ExternalUsers.Ref IS NULL
	|				THEN NOT ExternalUsers.DeletionMark
	|						AND NOT ExternalUsers.Invalid
	|			WHEN NOT UserGroups.Ref IS NULL
	|				THEN NOT UserGroups.DeletionMark
	|			WHEN NOT ExternalUsersGroups.Ref IS NULL
	|				THEN NOT ExternalUsersGroups.DeletionMark
	|			ELSE FALSE
	|		END";
	
	Result = Query.Execute().Unload();
	Result.Indexes.Add("User");
	
	Return Result;
	
EndFunction

// See UsersInternal.SerializedRef
Function SerializedRef(Ref)
	Return UsersInternal.SerializedRef(Ref);
EndFunction

// See UsersInternal.RepresentationOfTheReference
Function RepresentationOfTheReference(Ref)
	Return UsersInternal.RepresentationOfTheReference(Ref);
EndFunction

// For internal use only.
//
// Parameters:
//  Object - CatalogObject.AccessGroups
//         - CatalogObject.AccessGroupProfiles
//         - DefinedType.AccessValueObject - Intended for registering changes in access value group usage and
//             parent's hierarchy membership changes if the access value is used with the lower-level values.
//         - Structure:
//            * AccessKindsChange - ValueTable:
//                ** AccessKind    - DefinedType.AccessValue
//                ** Use - Boolean - A new usage of the access kind after a change made to
//                     the information register "UsedAccessKinds".
//                ** ChangeType  - String - Either of the values: "Added", "Removed", "IsChanged".
//            * ChangeInUserGroupsMembership - See UsersInternal.NewChangeInRegistrableGroupMembership
//
//  PreviousValues1 - Structure - Properties' old values (applicable if the object is not Structure).
//                 - Undefined - Applicable if the object is Structure.
//
Procedure RegisterChangeInAllowedValues(Object, PreviousValues1) Export
	
	If TypeOf(Object) = Type("Structure") Then
		Source = New Array;
		SourcePresentation = Undefined;
		If Object.Property("AccessKindsChange") Then
			URLToSource = "e1cib/list/InformationRegister.UsedAccessKinds";
			ObjectMetadata = Metadata.InformationRegisters.UsedAccessKinds;
		Else
			URLToSource = "e1cib/list/InformationRegister.UserGroupCompositions";
			ObjectMetadata = Metadata.InformationRegisters.UserGroupCompositions;
		EndIf;
	Else
		Source = SerializedRef(Object.Ref);
		SourcePresentation = RepresentationOfTheReference(Object.Ref);
		URLToSource = GetURL(Object.Ref);
		ObjectMetadata = Object.Metadata();
	EndIf;
	
	Data = New Structure;
	Data.Insert("DataStructureVersion", 1);
	Data.Insert("Source", Source);
	Data.Insert("URLToSource", URLToSource);
	Data.Insert("SourcePresentation", SourcePresentation);
	Data.Insert("AccessKindsChange", New Array);
	Data.Insert("AccessKindsPresentation", New Array);
	Data.Insert("AccessValuesChange", New Array);
	Data.Insert("ChangeInAccessValuesGroups", New Array);
	Data.Insert("AccessGroupsPresentation", New Array);
	Data.Insert("AccessValuesPresentation", New Array);
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	
	If TypeOf(Object) = Type("CatalogObject.AccessGroups") Then
		
		// Add the access kind membership changes and the "AllAllowed" flag.
		PreviousValues1.Insert("ProfileAccessKinds", Undefined);
		ProfileProperties = Common.ObjectAttributesValues(Object.Profile,
			"DeletionMark, AccessKinds, AccessValues");
		If PreviousValues1.Profile = Object.Profile Then
			PreviousValues1.ProfileAccessKinds = ProfileProperties.AccessKinds;
		ElsIf ValueIsFilled(PreviousValues1.Profile) Then
			PreviousValues1.ProfileAccessKinds = Common.ObjectAttributeValue(
				PreviousValues1.Profile, "AccessKinds");
		EndIf;
		ProfilePredefinedAccessKinds = ?(ValueIsFilled(PreviousValues1.Ref),
			Undefined, New Map);
		NewAccessKinds = AccessKindsUnduplicated(Object.AccessKinds.Unload(),,
			ProfileProperties.AccessKinds, ProfilePredefinedAccessKinds);
		AccessKindsChange = ChangeInAccessKindsComposition(NewAccessKinds, PreviousValues1);
		
		// Add changes in the access value list and access value group, the "IncludeSubordinateAccessValues" flag,
		// and the access values in whose access kind the "AllAllowed" flag was added, removed, or modified.
		AccessValuesChange = ChangeInAccessValuesComposition(Object,
			PreviousValues1, AccessKindsChange, AccessKindsProperties);
		
		If Not ValueIsFilled(AccessKindsChange)
		   And Not ValueIsFilled(AccessValuesChange) Then
			Return;
		EndIf;
		
		// Add unmodified access kinds whose access value is changed.
		AddAccessKindsWhoseAccessValuesChanged(AccessValuesChange,
			AccessKindsChange, NewAccessKinds);
		
		AccessKindsChange.FillValues(Object.Ref, "AccessGroupOrProfile");
		AccessValuesChange.FillValues(Object.Ref, "AccessGroupOrProfile");
		
		// Add the profile's predefined access groups and their values when creating an access group.
		AddPredefinedAccessKindsWithValues(AccessKindsChange, AccessValuesChange,
			Object.Profile, ProfilePredefinedAccessKinds, ProfileProperties.AccessValues, AccessKindsProperties);
		
		// Populate the list of modified access value groups.
		// Populate the subordinate access values if "IncludeSubordinateAccessValues" is selected or toggled.
		ChangeInAccessValuesGroups = ValuesGroupsValues(AccessValuesChange, AccessKindsProperties);
		DeleteExcessiveUnchangedValuesAndGroups(AccessValuesChange, ChangeInAccessValuesGroups);
		
		// Add the presentations of the access group.
		ProfileDeletionMark = ?(TypeOf(ProfileProperties.DeletionMark) = Type("Boolean"),
			ProfileProperties.DeletionMark, False);
		
		Properties = New Structure;
		Properties.Insert("AccessGroup", SerializedRef(Object.Ref));
		Properties.Insert("Presentation", RepresentationOfTheReference(Object.Ref));
		Properties.Insert("DeletionMark", Object.DeletionMark);
		Properties.Insert("Profile", SerializedRef(Object.Profile));
		Properties.Insert("ProfilePresentation", RepresentationOfTheReference(Object.Profile));
		Properties.Insert("ProfileDeletionMark", ProfileDeletionMark);
		Properties.Insert("OldPropertyValues", New Structure);
		
		If Object.DeletionMark <> PreviousValues1.DeletionMark Then
			Properties.OldPropertyValues.Insert("DeletionMark", PreviousValues1.DeletionMark);
		EndIf;
		If Object.Profile <> PreviousValues1.Profile Then
			Properties.OldPropertyValues.Insert("Profile", SerializedRef(PreviousValues1.Profile));
			ProfileOldPresentation = RepresentationOfTheReference(PreviousValues1.Profile);
			If Properties.ProfilePresentation <> ProfileOldPresentation Then
				Properties.OldPropertyValues.Insert("ProfilePresentation", ProfileOldPresentation);
			EndIf;
		EndIf;
		If ProfileDeletionMark <> PreviousValues1.ProfileDeletionMark Then
			Properties.OldPropertyValues.Insert("ProfileDeletionMark", PreviousValues1.ProfileDeletionMark);
		EndIf;
		Data.AccessGroupsPresentation.Add(Properties);
		
	ElsIf TypeOf(Object) = Type("CatalogObject.AccessGroupProfiles") Then
		
		// Add the access kind membership changes and the "AllAllowed" and "Predefined" flags.
		AccessKindsWithChangePredefined = New Array;
		NewAccessKinds = AccessKindsUnduplicated(Object.AccessKinds.Unload(), True);
		AccessKindsChange = ChangeInAccessKindsComposition(NewAccessKinds,
			PreviousValues1, True, AccessKindsWithChangePredefined);
		
		// Add changes in the access value list and access value group, the "IncludeSubordinateAccessValues" flag,
		// and the access values in whose access kind the "AllAllowed" flag was added, removed, or modified.
		AccessValuesChange = ChangeInAccessValuesComposition(Object, PreviousValues1,
			AccessKindsChange, AccessKindsProperties);
		
		If Not ValueIsFilled(AccessKindsChange)
		   And Not ValueIsFilled(AccessValuesChange) Then
			Return;
		EndIf;
		
		// Add unmodified access kinds whose access value is changed.
		AddAccessKindsWhoseAccessValuesChanged(AccessValuesChange,
			AccessKindsChange, NewAccessKinds);
		
		AccessKindsChange.FillValues(Object.Ref, "AccessGroupOrProfile");
		AccessValuesChange.FillValues(Object.Ref, "AccessGroupOrProfile");
		
		// Add access values and kinds for the profile's access groups
		// (for profile access kinds whose "Predefined" flag was modified).
		AccessGroupsProperties = ProfileAccessGroupsProperties(Object.Ref, AccessKindsWithChangePredefined);
		FillAccessKindsAndValues(AccessKindsChange,
			AccessValuesChange, AccessGroupsProperties, AccessKindsProperties);
		
		// Populate the list of modified access value groups.
		// Populate the subordinate access values if "IncludeSubordinateAccessValues" is selected or toggled.
		ChangeInAccessValuesGroups = ValuesGroupsValues(AccessValuesChange, AccessKindsProperties);
		DeleteExcessiveUnchangedValuesAndGroups(AccessValuesChange, ChangeInAccessValuesGroups);
		
		// Add the presentations of the profile's access groups.
		ProfileSerializedRef = SerializedRef(Object.Ref);
		ProfilePresentation = RepresentationOfTheReference(Object.Ref);
		OldPropertyValues = New Structure;
		If Object.DeletionMark <> PreviousValues1.DeletionMark Then
			OldPropertyValues.Insert("ProfileDeletionMark",
				?(TypeOf(PreviousValues1.DeletionMark) = Type("Boolean"),
					PreviousValues1.DeletionMark, False));
		EndIf;
		ProfileOldPresentation = RepresentationOfTheReference(PreviousValues1.Ref);
		If ProfilePresentation <> ProfileOldPresentation Then
			OldPropertyValues.Insert("ProfilePresentation", ProfileOldPresentation);
		EndIf;
		If Not ValueIsFilled(AccessGroupsProperties.AccessGroups) Then
			NewRow = AccessGroupsProperties.AccessGroups.Add();
			NewRow.AccessGroup = Catalogs.AccessGroups.EmptyRef();
			NewRow.Presentation = "<" + NStr("en = 'No access group';",
				Common.DefaultLanguageCode()) + ">";
		EndIf;
		For Each AccessGroupDetails In AccessGroupsProperties.AccessGroups Do
			Properties = New Structure;
			Properties.Insert("AccessGroup", SerializedRef(AccessGroupDetails.AccessGroup));
			Properties.Insert("Presentation", AccessGroupDetails.Presentation);
			Properties.Insert("DeletionMark", AccessGroupDetails.DeletionMark);
			Properties.Insert("Profile", ProfileSerializedRef);
			Properties.Insert("ProfilePresentation", ProfilePresentation);
			Properties.Insert("ProfileDeletionMark", Object.DeletionMark);
			Properties.Insert("OldPropertyValues", OldPropertyValues);
			Data.AccessGroupsPresentation.Add(Properties);
		EndDo;
		
	ElsIf TypeOf(Object) <> Type("Structure")
	      Or Object.Property("ChangeInUserGroupsMembership") Then
		
		AccessKindsChange = AccessKindsNewChange();
		AccessValuesChange = NewChangeInAccessValues();
		ChangeInAccessValuesGroups = Undefined;
		
		If TypeOf(Object) = Type("Structure") Then
			ChangeInAccessValuesGroups = Object.ChangeInUserGroupsMembership.Copy(,
				"UsersGroup, User, ChangeType");
			ChangeInAccessValuesGroups.Columns.UsersGroup.Name = "ValuesGroup";
			ChangeInAccessValuesGroups.Columns.User.Name = "AccessValue";
			Filter = New Structure("ChangeType", "IsChanged");
			FoundRows = ChangeInAccessValuesGroups.FindRows(Filter);
			For Each FoundRow In FoundRows Do
				ChangeInAccessValuesGroups.Delete(FoundRow);
			EndDo;
			AccessGroupsAndProfilesProperties = ValueGroupsChangesAccessGroupsAndProfilesProperties(
				ChangeInAccessValuesGroups);
			
		ElsIf PreviousValues1.Property("AccessGroup")
		      Or PreviousValues1.Property("AccessGroups") Then
			
			Properties = AccessKindsProperties.AccessValuesWithGroups.ByTypesForUpdate.Get(TypeOf(Object));
			If Properties = Undefined
			 Or Properties.ValuesGroupsType <> Type("Undefined") Then
				Return;
			EndIf;
			ChangeInAccessValuesGroups = ChangeInAccessValuesGroups(Object,
				PreviousValues1, Properties.MultipleValuesGroups);
			
			AccessGroupsAndProfilesProperties = ValueGroupsChangesAccessGroupsAndProfilesProperties(
				ChangeInAccessValuesGroups);
			
		ElsIf PreviousValues1.Property("Parent") Then
			Properties = AccessKindsProperties.ByValuesTypesWithHierarchy.Get(TypeOf(Object));
			If Properties = Undefined Then
				Return;
			EndIf;
			ChangeInAccessValuesGroups = ParentsAccessValuesChange(Object, PreviousValues1);
			
			AccessGroupsAndProfilesProperties = ValueGroupsChangesAccessGroupsAndProfilesProperties(
				ChangeInAccessValuesGroups, True);
		EndIf;
		
		FillAccessKindsAndValues(AccessKindsChange,
			AccessValuesChange, AccessGroupsAndProfilesProperties, AccessKindsProperties);
		
		DeleteExcessiveUnchangedValuesAndGroups(AccessValuesChange, ChangeInAccessValuesGroups);
		
		// Add the presentations of the profiles' access groups.
		FillProfilesAccessGroupsPresentation(Data, AccessGroupsAndProfilesProperties.AccessGroups);
	Else
		// Add the changes of the access kind usage.
		For Each String In Object.AccessKindsChange Do
			Properties = New Structure;
			Properties.Insert("AccessKind",   SerializedRef(String.AccessKind));
			Properties.Insert("Used", String.Used);
			Properties.Insert("ChangeType", String.ChangeType);
			Data.Source.Add(Properties);
		EndDo;
		
		AccessKindsChange = AccessKindsNewChange();
		AccessValuesChange = NewChangeInAccessValues();
		
		AccessGroupsAndProfilesProperties = AccessKindsChangesAccessGroupsAndProfilesProperties(Object.AccessKindsChange);
		FillAccessKindsAndValues(AccessKindsChange,
			AccessValuesChange, AccessGroupsAndProfilesProperties, AccessKindsProperties);
		
		// Populate the list of modified access value groups.
		// Populate the subordinate access values if "IncludeSubordinateAccessValues" is selected.
		ChangeInAccessValuesGroups = ValuesGroupsValues(AccessValuesChange, AccessKindsProperties);
		
		// Add the presentations of the profiles' access groups.
		FillProfilesAccessGroupsPresentation(Data, AccessGroupsAndProfilesProperties.AccessGroups);
	EndIf;
	
	If Not ValueIsFilled(AccessKindsChange)
	   And Not ValueIsFilled(AccessValuesChange) Then
		Return;
	EndIf;
	
	// Populate access kind changes.
	For Each String In AccessKindsChange Do
		Properties = New Structure;
		Properties.Insert("AccessGroupOrProfile", SerializedRef(String.AccessGroupOrProfile));
		Properties.Insert("AccessKind",              SerializedRef(String.AccessKind));
		Properties.Insert("AllAllowed",            String.AllAllowed);
		Properties.Insert("Predefined",       String.Predefined);
		Properties.Insert("ChangeType",            String.ChangeType);
		Properties.Insert("OldPropertyValues",   String.OldPropertyValues);
		Data.AccessKindsChange.Add(Properties);
	EndDo;
	
	// Populate access kind presentations.
	AccessKindsToRegister = AccessKindsChange.Copy(, "AccessKind");
	AccessKindsToRegister.GroupBy("AccessKind");
	AccessKindsPropertiesByTypes = AccessKindsProperties.ByGroupsAndValuesTypes;
	UsedAccessKinds = AccessManagementInternal.UsedAccessKinds(True);
	AccessKindsPresentation = AccessManagementInternal.AccessKindsPresentation();
	
	For Each String In AccessKindsToRegister Do
		AccessKindValueType = TypeOf(String.AccessKind);
		Properties = New Structure;
		Properties.Insert("AccessKind", SerializedRef(String.AccessKind));
		Properties.Insert("Used", UsedAccessKinds.Get(String.AccessKind) <> Undefined);
		Properties.Insert("Name", "");
		Properties.Insert("Presentation", "");
		AccessKindProperties = AccessKindsPropertiesByTypes.Get(AccessKindValueType);
		If AccessKindProperties = Undefined Then
			Properties.Presentation = "? " + String(AccessKindValueType);
		Else
			Properties.Name = AccessKindProperties.Name;
			Properties.Presentation = AccessKindsPresentation.Get(AccessKindValueType);
		EndIf;
		Data.AccessKindsPresentation.Add(Properties);
	EndDo;
	
	// Populate access value changes.
	For Each String In AccessValuesChange Do
		Properties = New Structure;
		Properties.Insert("AccessGroupOrProfile", SerializedRef(String.AccessGroupOrProfile));
		Properties.Insert("AccessKind",              SerializedRef(String.AccessKind));
		Properties.Insert("AccessValue",         SerializedRef(String.AccessValue));
		Properties.Insert("IsValuesGroup",       String.IsValuesGroup);
		Properties.Insert("IncludeSubordinateAccessValues",      String.IncludeSubordinateAccessValues);
		Properties.Insert("ChangeType",            String.ChangeType);
		Properties.Insert("OldPropertyValues",   String.OldPropertyValues);
		Data.AccessValuesChange.Add(Properties);
	EndDo;
	
	ValuesToRegister = AccessValuesChange.Copy(, "AccessValue");
	
	// Populate access value group changes.
	If ValueIsFilled(ChangeInAccessValuesGroups) Then
		For Each String In ChangeInAccessValuesGroups Do
			Properties = New Structure;
			Properties.Insert("ValuesGroup",  SerializedRef(String.ValuesGroup));
			Properties.Insert("AccessValue", SerializedRef(String.AccessValue));
			Properties.Insert("ChangeType",    String.ChangeType);
			Data.ChangeInAccessValuesGroups.Add(Properties);
			ValuesToRegister.Add().AccessValue = String.ValuesGroup;
			ValuesToRegister.Add().AccessValue = String.AccessValue;
		EndDo;
	EndIf;
	
	// Populate access value groups and presentations.
	ValuesToRegister.GroupBy("AccessValue");
	EnumerationsCodes = AccessManagementInternalCached.EnumerationsCodes();
	EnumsAllRefsType = Enums.AllRefsType();
	For Each String In ValuesToRegister Do
		Properties = New Structure;
		Properties.Insert("Value", SerializedRef(String.AccessValue));
		Properties.Insert("Presentation", RepresentationOfTheReference(String.AccessValue));
		Properties.Insert("URL", "");
		If StrStartsWith(Properties.Value, "{") Then
			If EnumsAllRefsType.ContainsType(TypeOf(String.AccessValue)) Then
				Properties.URL = StrTemplate("e1cib/list/%1?name=%2",
					String.AccessValue.Metadata().FullName(), EnumerationsCodes.Get(String.AccessValue));
			Else
				Properties.URL = GetURL(String.AccessValue);
			EndIf;
		EndIf;
		Data.AccessValuesPresentation.Add(Properties);
	EndDo;
	
	EventName = AccessManagementInternal.NameOfLogEventAllowedValuesChanged();
	
	WriteLogEvent(EventName,
		EventLogLevel.Information,
		ObjectMetadata,
		Common.ValueToXMLString(Data),
		,
		EventLogEntryTransactionMode.Transactional);
	
EndProcedure

Function AccessKindsNewChange(NewAccessKinds = Undefined)
	
	If NewAccessKinds = Undefined Then
		ProfileTemplate = Catalogs.AccessGroupProfiles.CreateItem();
		AccessKindsChange = ProfileTemplate.AccessKinds.Unload(New Array);
	Else
		AccessKindsChange = NewAccessKinds;
	EndIf;
	
	AccessKindsChange.Columns.Add("AccessGroupOrProfile");
	AccessKindsChange.Columns.Add("ChangeType", New TypeDescription("String"));
	AccessKindsChange.Columns.Add("OldPropertyValues", New TypeDescription("Structure"));
	
	Return AccessKindsChange;
	
EndFunction

Function ChangeInAccessKindsComposition(NewAccessKinds, PreviousValues1, ThisProfile = False,
			AccessKindsWithChangePredefined = Undefined)
	
	AccessKindsChange = AccessKindsNewChange(NewAccessKinds.Copy());
	AccessKindsChange.FillValues("Added2", "ChangeType");
	
	If PreviousValues1.AccessKinds = Undefined Then
		Return AccessKindsChange;
	EndIf;
	
	OldAccessTypes = AccessKindsUnduplicated(PreviousValues1.AccessKinds.Unload(),
		ThisProfile, ?(ThisProfile, Undefined, PreviousValues1.ProfileAccessKinds));
	
	For Each OldRow In OldAccessTypes Do
		NewRow = AccessKindsChange.Find(OldRow.AccessKind, "AccessKind");
		
		If NewRow = Undefined Then
			NewRow = AccessKindsChange.Add();
			FillPropertyValues(NewRow, OldRow);
			NewRow.ChangeType = "Deleted";
			
		ElsIf NewRow.AllAllowed <> OldRow.AllAllowed
		      Or NewRow.Predefined <> OldRow.Predefined Then
			
			NewRow.ChangeType = "IsChanged";
			If NewRow.AllAllowed <> OldRow.AllAllowed Then
				NewRow.OldPropertyValues.Insert("AllAllowed", OldRow.AllAllowed);
			EndIf;
			If NewRow.Predefined <> OldRow.Predefined Then
				NewRow.OldPropertyValues.Insert("Predefined", OldRow.Predefined);
				AccessKindsWithChangePredefined.Add(NewRow.AccessKind);
			EndIf;
		Else
			AccessKindsChange.Delete(NewRow);
		EndIf;
	EndDo;
	
	Return AccessKindsChange;
	
EndFunction

Function NewChangeInAccessValues(NewAccessValues = Undefined)
	
	If NewAccessValues = Undefined Then
		ProfileTemplate = Catalogs.AccessGroupProfiles.CreateItem();
		AccessValuesChange = ProfileTemplate.AccessValues.Unload(New Array);
		AccessValuesChange.Columns.Add("IsValuesGroup", New TypeDescription("Boolean"));
	Else
		AccessValuesChange = NewAccessValues;
	EndIf;
	
	AccessValuesChange.Columns.Add("AccessGroupOrProfile");
	AccessValuesChange.Columns.Add("ChangeType", New TypeDescription("String"));
	AccessValuesChange.Columns.Add("OldPropertyValues", New TypeDescription("Structure"));
	AccessValuesChange.Columns.Add("OldValueIncludeSubordinateAccessValues", New TypeDescription("Boolean"));
	
	Return AccessValuesChange;
	
EndFunction

Function ChangeInAccessValuesComposition(Object, PreviousValues1, AccessKindsChange, AccessKindsProperties)
	
	NewAccessValues = AccessValuesUnduplicated(Object.AccessValues.Unload(),
		AccessKindsProperties);
	
	AccessValuesChange = NewChangeInAccessValues(NewAccessValues);
	AccessValuesChange.FillValues("Added2", "ChangeType");
	
	If PreviousValues1.AccessValues <> Undefined Then
		OldAccessValues = AccessValuesUnduplicated(PreviousValues1.AccessValues.Unload(),
			AccessKindsProperties);
		
		For Each OldRow In OldAccessValues Do
			Filter = New Structure("AccessKind, AccessValue");
			FillPropertyValues(Filter, OldRow);
			FoundRows = AccessValuesChange.FindRows(Filter);
			NewRow = ?(ValueIsFilled(FoundRows), FoundRows[0], Undefined);
			
			If NewRow = Undefined Then
				NewRow = AccessValuesChange.Add();
				FillPropertyValues(NewRow, OldRow);
				NewRow.ChangeType = "Deleted";
				
			ElsIf NewRow.IncludeSubordinateAccessValues <> OldRow.IncludeSubordinateAccessValues Then
				NewRow.ChangeType = "IsChanged";
				NewRow.OldPropertyValues.Insert("IncludeSubordinateAccessValues", OldRow.IncludeSubordinateAccessValues);
				NewRow.OldValueIncludeSubordinateAccessValues = OldRow.IncludeSubordinateAccessValues;
				
			ElsIf AccessKindsChange.Find(OldRow.AccessKind, "AccessKind") <> Undefined Then
				NewRow.ChangeType = "IsChanged";
			Else
				NewRow.ChangeType = "";
			EndIf;
		EndDo;
		
		AccessKindsChangeByValues = AccessValuesChange.Copy(, "AccessKind, ChangeType");
		AccessKindsChangeByValues.GroupBy("AccessKind, ChangeType");
		AccessKinds = AccessKindsChangeByValues.Copy(, "AccessKind");
		AccessKinds.GroupBy("AccessKind");
		For Each AccessKindDetails In AccessKinds Do
			Filter = New Structure("AccessKind", AccessKindDetails.AccessKind);
			FoundRows = AccessKindsChangeByValues.FindRows(Filter);
			If FoundRows.Count() <> 1 Or FoundRows[0].ChangeType <> "" Then
				Continue;
			EndIf;
			FoundRows = AccessValuesChange.FindRows(Filter);
			For Each FoundRow In FoundRows Do
				AccessValuesChange.Delete(FoundRow);
			EndDo;
		EndDo;
	EndIf;
	
	Return AccessValuesChange;
	
EndFunction

Function AccessKindsUnduplicated(Table, ThisProfile = False, ProfileAccessKinds = Undefined,
			ProfilePredefinedAccessKinds = Undefined)
	
	If Not ThisProfile Then
		PredefinedAccessKinds = New Map;
		If TypeOf(ProfileAccessKinds) = Type("QueryResult") Then
			Upload0 = ProfileAccessKinds.Unload();
			For Each TSRow In Upload0 Do
				PredefinedAccessKinds.Insert(TSRow.AccessKind, TSRow);
			EndDo;
		EndIf;
		If ProfilePredefinedAccessKinds <> Undefined Then
			ProfilePredefinedAccessKinds = PredefinedAccessKinds;
		EndIf;
	EndIf;
	
	Result = Table.Copy(, "AccessKind");
	Result.GroupBy("AccessKind");
	Result.Columns.Add("AllAllowed", New TypeDescription("Boolean"));
	Result.Columns.Add("Predefined");
	Filter = New Structure("AccessKind");
	
	For Each String In Result Do
		Filter.AccessKind = String.AccessKind;
		FoundRows = Table.FindRows(Filter);
		For Each FoundRow In FoundRows Do
			String.AllAllowed = String.AllAllowed Or FoundRow.AllAllowed;
			If ThisProfile Then
				String.Predefined = FoundRow.Predefined
					Or ?(String.Predefined = Undefined, False, String.Predefined);
			EndIf;
		EndDo;
		If Not ThisProfile Then
			// Ignore access group settings if the access group profile's
			// has a predefined or missing access kind.
			TSRow = PredefinedAccessKinds.Get(String.AccessKind);
			If TSRow <> Undefined Then
				String.Predefined = TSRow.Predefined;
				If Not TSRow.Predefined Then
					PredefinedAccessKinds.Delete(String.AccessKind);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function AccessValuesUnduplicated(Table, AccessKindsProperties)
	
	Result = Table.Copy(, "AccessKind, AccessValue");
	Result.GroupBy("AccessKind, AccessValue");
	Result.Columns.Add("IncludeSubordinateAccessValues", New TypeDescription("Boolean"));
	Result.Columns.Add("IsValuesGroup", New TypeDescription("Boolean"));
	Filter = New Structure("AccessKind, AccessValue");
	
	PropertiesByValueTypes       = AccessKindsProperties.ByValuesTypes;
	PropertiesByValueAndGroupTypes = AccessKindsProperties.ByGroupsAndValuesTypes;
	
	For Each String In Result Do
		FillPropertyValues(Filter, String);
		FoundRows = Table.FindRows(Filter);
		For Each FoundRow In FoundRows Do
			String.IncludeSubordinateAccessValues = String.IncludeSubordinateAccessValues Or FoundRow.IncludeSubordinateAccessValues;
		EndDo;
		ValueType = TypeOf(String.AccessValue);
		String.IsValuesGroup = PropertiesByValueTypes.Get(ValueType) = Undefined
			And PropertiesByValueAndGroupTypes.Get(ValueType) <> Undefined;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure AddAccessKindsWhoseAccessValuesChanged(AccessValuesChange, AccessKindsChange,
			NewAccessKinds)
	
	AccessKindsWithModifiedValues = AccessValuesChange.Copy(, "AccessKind");
	AccessKindsWithModifiedValues.GroupBy("AccessKind");
	
	For Each String In AccessKindsWithModifiedValues Do
		FoundRow = AccessKindsChange.Find(String.AccessKind, "AccessKind");
		If FoundRow <> Undefined Then
			Continue;
		EndIf;
		NewRow = AccessKindsChange.Add();
		NewRow.ChangeType = "IsChanged";
		FoundRow = NewAccessKinds.Find(String.AccessKind, "AccessKind");
		If FoundRow <> Undefined Then
			FillPropertyValues(NewRow, FoundRow);
		Else
			NewRow.AccessKind = String.AccessKind;
			NewRow.AllAllowed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure AddPredefinedAccessKindsWithValues(AccessKindsChange, AccessValuesChange,
			Profile, ProfilePredefinedAccessKinds, AccessValueProfileProperties, AccessKindsProperties);
	
	If Not ValueIsFilled(ProfilePredefinedAccessKinds) Then
		Return;
	EndIf;
	
	If TypeOf(AccessValueProfileProperties) = Type("QueryResult") Then
		ProfileAccessValues = AccessValuesUnduplicated(AccessValueProfileProperties.Unload(),
			AccessKindsProperties);
	Else
		ProfileAccessValues = Undefined;
	EndIf;
	
	For Each AccessKindDetails In ProfilePredefinedAccessKinds Do
		NewRow = AccessKindsChange.Add();
		FillPropertyValues(NewRow, AccessKindDetails.Value);
		NewRow.AccessGroupOrProfile = Profile;
		NewRow.ChangeType = "IsChanged";
		If ProfileAccessValues = Undefined Then
			Continue;
		EndIf;
		Filter = New Structure("AccessKind", NewRow.AccessKind);
		FoundRows = ProfileAccessValues.FindRows(Filter);
		For Each FoundRow In FoundRows Do
			NewRow = AccessValuesChange.Add();
			FillPropertyValues(NewRow, FoundRow);
			NewRow.AccessGroupOrProfile = Profile;
			NewRow.ChangeType = "IsChanged";
		EndDo;
	EndDo;
	
EndProcedure

Function ValuesGroupsValues(AccessValuesChange, AccessKindsProperties)
	
	Query = New Query;
	QueryParts = New Array;
	
	AddQueriesForValuesGroupsValues(Query, QueryParts, AccessValuesChange, AccessKindsProperties);
	AddQueriesForLowerLevelValues(Query, QueryParts, AccessValuesChange);
	
	If Not ValueIsFilled(QueryParts) Then
		Return Undefined;
	EndIf;
	
	Query.Text = Query.Text + StrConcat(QueryParts, Common.UnionAllText());
	
	Result = Query.Execute().Unload();
	Result.Columns.Add("ChangeType");
	Result.FillValues("IsChanged", "ChangeType");
	
	Return Result;
	
EndFunction

// Intended for function "ChangeInAccessValuesGroups".
Procedure AddQueriesForValuesGroupsValues(Query, QueryParts, AccessValuesChange, AccessKindsProperties)
	
	Filter = New Structure("IsValuesGroup", True);
	FoundRows = AccessValuesChange.FindRows(Filter);
	If Not ValueIsFilled(FoundRows) Then
		Return;
	EndIf;
	
	TemporaryTableQueryText =
	"SELECT
	|	ValueGroups.AccessValue AS AccessValuesGroup
	|INTO CurrentValueGroups
	|FROM
	|	&ValueGroups AS ValueGroups";
	
	QuerySegmentTemplate =
	"SELECT DISTINCT
	|	CurrentTable.AccessGroup AS ValuesGroup,
	|	CurrentTable.Ref AS AccessValue
	|FROM
	|	AccessValuesTable AS CurrentTable
	|		INNER JOIN CurrentValueGroups AS CurrentValueGroups
	|		ON CurrentTable.AccessGroup = CurrentValueGroups.AccessValuesGroup";
	
	UsersQuerySegmentTemplate =
	"SELECT DISTINCT
	|	CurrentTable.UsersGroup AS ValuesGroup,
	|	CurrentTable.User AS AccessValue
	|FROM
	|	InformationRegister.UserGroupCompositions AS CurrentTable
	|		INNER JOIN CurrentValueGroups AS CurrentValueGroups
	|		ON CurrentTable.UsersGroup = CurrentValueGroups.AccessValuesGroup";
	
	AccessKindsPropertiesByRefs = AccessKindsProperties.ByRefs;
	AccessKinds = AccessValuesChange.Copy(FoundRows, "AccessKind");
	AccessKinds.GroupBy("AccessKind");
	IsUsersQuerySegmentTemplateAdded = False;
	
	For Each String In AccessKinds Do
		Properties = AccessKindsPropertiesByRefs.Get(String.AccessKind);
		If Properties = Undefined Then
			Continue;
		EndIf;
		If Properties.Name = "Users" Or Properties.Name = "ExternalUsers" Then
			If Not IsUsersQuerySegmentTemplateAdded Then
				QueryParts.Add(UsersQuerySegmentTemplate);
				IsUsersQuerySegmentTemplateAdded = True;
			EndIf;
			Continue;
		EndIf;
		AddQuerySegment(Properties, QueryParts, QuerySegmentTemplate);
		For Each CurrentProperties In Properties.AdditionalTypes Do
			AddQuerySegment(CurrentProperties, QueryParts, QuerySegmentTemplate);
		EndDo;
	EndDo;
	
	If Not ValueIsFilled(QueryParts) Then
		Return;
	EndIf;
	
	ValueGroups = AccessValuesChange.Copy(FoundRows, "AccessValue");
	ValueGroups.GroupBy("AccessValue");
	
	Query.SetParameter("ValueGroups", ValueGroups);
	Query.Text = TemporaryTableQueryText + Common.QueryBatchSeparator();
	
EndProcedure

// Intended for procedure "AddQueriesForValuesGroupsValues".
Procedure AddQuerySegment(Properties, QueryParts, QuerySegmentTemplate)
	
	If Properties.ValuesGroupsType = Type("Undefined") Then
		Return;
	EndIf;
	
	MetadataObject = Metadata.FindByType(Properties.ValuesType);
	If MetadataObject = Undefined Then
		Return;
	EndIf;
	
	FullTableName = MetadataObject.FullName();
	If Properties.MultipleValuesGroups Then
		FullTableName = FullTableName + "." + MetadataObject.TabularSections.AccessGroups.Name;
	EndIf;
	
	QueryParts.Add(StrReplace(QuerySegmentTemplate, "AccessValuesTable", FullTableName));
	
EndProcedure

// Intended for function "ChangeInAccessValuesGroups".
Procedure AddQueriesForLowerLevelValues(Query, QueryParts, AccessValuesChange)
	
	Filter = New Structure("IncludeSubordinateAccessValues", True);
	FoundRows = AccessValuesChange.FindRows(Filter);
	AccessValues = AccessValuesChange.Copy(FoundRows, "AccessValue");
	Filter = New Structure("IncludeSubordinateAccessValues, OldValueIncludeSubordinateAccessValues", False, True);
	FoundRows = AccessValuesChange.FindRows(Filter);
	For Each FoundRow In FoundRows Do
		FillPropertyValues(AccessValues.Add(), FoundRow);
	EndDo;
	AccessValues.GroupBy("AccessValue");
	AccessValuesWithLowerLevelChange = New Map;
	
	For Each ValueDescription In AccessValues Do
		ValueType = TypeOf(ValueDescription.AccessValue);
		ValuesByType = AccessValuesWithLowerLevelChange.Get(ValueType);
		If ValuesByType = Undefined Then
			ValuesByType = New Map;
			AccessValuesWithLowerLevelChange.Insert(ValueType, ValuesByType);
		EndIf;
		ValuesByType.Insert(ValueDescription.AccessValue);
	EndDo;
	
	QueryTemplate =
	"SELECT
	|	&AccessValue AS ValuesGroup,
	|	Table.Ref AS AccessValue
	|FROM
	|	&Table AS Table
	|WHERE
	|	Table.Ref IN HIERARCHY(&AccessValue)";
	
	IndexOf = 0;
	For Each ValuesByType In AccessValuesWithLowerLevelChange Do
		MetadataObject = Metadata.FindByType(ValuesByType.Key);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		QueryText = StrReplace(QueryTemplate, "&Table", MetadataObject.FullName());
		For Each ValueDescription In ValuesByType.Value Do
			IndexOf = IndexOf + 1;
			ParameterName = "AccessValue" + XMLString(IndexOf);
			Query.SetParameter(ParameterName, ValueDescription.Key);
			QueryParts.Add(StrReplace(QueryText, "&AccessValue", "&" + ParameterName));
		EndDo;
	EndDo;
	
EndProcedure

Procedure DeleteExcessiveUnchangedValuesAndGroups(AccessValuesChange, ChangeInAccessValuesGroups)
	
	If ChangeInAccessValuesGroups <> Undefined Then
		ChangeInAccessValuesGroups.Indexes.Add("ValuesGroup");
		ChangeInAccessValuesGroups.Indexes.Add("AccessValue");
	EndIf;
	
	// Delete unwanted unmodified values and value groups.
	AccessValuesChange.Indexes.Add("AccessGroupOrProfile, AccessKind");
	Filter = New Structure("ChangeType", "");
	FoundRows = AccessValuesChange.FindRows(Filter);
	FiltersDetails = AccessValuesChange.Copy(FoundRows, "AccessGroupOrProfile, AccessKind");
	FiltersDetails.GroupBy("AccessGroupOrProfile, AccessKind");
	ValuesFilter = New Structure("AccessGroupOrProfile, AccessKind");
	
	For Each FilterDetails In FiltersDetails Do
		FillPropertyValues(ValuesFilter, FilterDetails);
		Values = AccessValuesChange.FindRows(ValuesFilter);
		ValuesUnchanged = New Array;
		ValuesWithChange = New Map;
		For Each SpecificationRow In Values Do
			If SpecificationRow.ChangeType = "" Then
				ValuesUnchanged.Add(SpecificationRow);
			Else
				ValuesWithChange.Insert(SpecificationRow.AccessValue, True);
			EndIf;
		EndDo;
		For Each ValueDescription In ValuesUnchanged Do
			ThereIsIntersection = False;
			If ChangeInAccessValuesGroups <> Undefined
			   And (ValueDescription.IsValuesGroup Or ValueDescription.IncludeSubordinateAccessValues) Then
				Filter = New Structure("ValuesGroup", ValueDescription.AccessValue);
				ValuesOfGroup = ChangeInAccessValuesGroups.FindRows(Filter);
				For Each ValueOfGroup In ValuesOfGroup Do
					ThereIsIntersection = IsValueBelongsToModified(ValueOfGroup.AccessValue,
						ValuesWithChange, ChangeInAccessValuesGroups);
					If ThereIsIntersection Then
						Break;
					EndIf;
				EndDo;
			EndIf;
			If ThereIsIntersection Then
				Continue;
			EndIf;
			If Not ValueDescription.IsValuesGroup Or ValueDescription.IncludeSubordinateAccessValues Then
				ThereIsIntersection = IsValueBelongsToModified(ValueDescription.AccessValue,
					ValuesWithChange, ChangeInAccessValuesGroups);
			EndIf;
			If ThereIsIntersection Then
				Continue;
			EndIf;
			AccessValuesChange.Delete(ValueDescription);
		EndDo;
	EndDo;
	
	// Delete unwanted value groups and their values.
	If ChangeInAccessValuesGroups = Undefined Then
		Return;
	EndIf;
	ValueGroups = ChangeInAccessValuesGroups.Copy(, "ValuesGroup");
	ValueGroups.GroupBy("ValuesGroup");
	AccessValuesChange.Indexes.Add("AccessValue");
	
	For Each ValueGroupDetails In ValueGroups Do
		Filter = New Structure("AccessValue", ValueGroupDetails.ValuesGroup);
		If AccessValuesChange.Find(ValueGroupDetails.ValuesGroup, "AccessValue") <> Undefined Then
			Continue;
		EndIf;
		Filter = New Structure("ValuesGroup", ValueGroupDetails.ValuesGroup);
		FoundRows = ChangeInAccessValuesGroups.FindRows(Filter);
		For Each FoundRow In FoundRows Do
			ChangeInAccessValuesGroups.Delete(FoundRow);
		EndDo;
	EndDo;
	
EndProcedure

// Intended for procedure "DeleteExcessiveUnchangedValuesAndGroups".
Function IsValueBelongsToModified(ValueUnchanged, ValuesAndGroupsWithChange, ValueGroups)
	
	If ValuesAndGroupsWithChange.Get(ValueUnchanged) <> Undefined Then
		Return True;
	EndIf;
	
	If ValueGroups = Undefined Then
		Return False;
	EndIf;
	
	Filter = New Structure("AccessValue", ValueUnchanged);
	Groups = ValueGroups.FindRows(Filter);
	
	For Each GroupDetails In Groups Do
		If ValuesAndGroupsWithChange.Get(GroupDetails.ValuesGroup) <> Undefined Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function ProfileAccessGroupsProperties(Profile, AccessKindsWithChangePredefined)
	
	Query = New Query;
	Query.SetParameter("Profile", Profile);
	Query.SetParameter("AccessKindsWithChangePredefined", AccessKindsWithChangePredefined);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.DeletionMark AS DeletionMark,
	|	PRESENTATION(AccessGroups.Ref) AS Presentation
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.DeletionMark AS DeletionMark,
	|	AccessGroups.Presentation AS Presentation
	|FROM
	|	AccessGroups AS AccessGroups
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessKinds.Ref AS AccessGroupOrProfile,
	|	AccessGroupsAccessKinds.AccessKind AS AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed AS AllAllowed
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON (AccessGroupsAccessKinds.Ref = AccessGroups.Ref)
	|			AND (AccessGroupsAccessKinds.AccessKind IN (&AccessKindsWithChangePredefined))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessValuesOfAccessGroups.Ref AS AccessGroupOrProfile,
	|	AccessValuesOfAccessGroups.AccessKind AS AccessKind,
	|	AccessValuesOfAccessGroups.AccessValue AS AccessValue,
	|	AccessValuesOfAccessGroups.IncludeSubordinateAccessValues AS IncludeSubordinateAccessValues
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|		ON (AccessValuesOfAccessGroups.Ref = AccessGroups.Ref)
	|			AND (AccessValuesOfAccessGroups.AccessKind IN (&AccessKindsWithChangePredefined))";
	QueryResults = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("AccessGroups",   QueryResults[1].Unload());
	Result.Insert("AccessKinds",     QueryResults[2].Unload());
	Result.Insert("AccessValues", QueryResults[3].Unload());
	
	Return Result;
	
EndFunction

Function AccessKindsChangesAccessGroupsAndProfilesProperties(AccessKindsChange)
	
	Query = New Query;
	Query.SetParameter("ModifiedAccessKinds",
		AccessKindsChange.UnloadColumn("AccessKind"));
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.DeletionMark AS DeletionMark,
	|	PRESENTATION(AccessGroups.Ref) AS Presentation,
	|	AccessGroups.Profile AS Profile,
	|	ISNULL(AccessGroups.Profile.DeletionMark, FALSE) AS ProfileDeletionMark,
	|	PRESENTATION(AccessGroups.Profile) AS ProfilePresentation
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.Profile IN
	|					(SELECT
	|						ProfilesAccessKinds.Ref
	|					FROM
	|						Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|					WHERE
	|						ProfilesAccessKinds.AccessKind IN (&ModifiedAccessKinds)
	|		
	|					UNION ALL
	|		
	|					SELECT
	|						ProfilesAccessValues.Ref
	|					FROM
	|						Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|					WHERE
	|						ProfilesAccessValues.AccessKind IN (&ModifiedAccessKinds))
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN
	|					(SELECT
	|						AccessGroupsAccessKinds.Ref
	|					FROM
	|						Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|					WHERE
	|						AccessGroupsAccessKinds.AccessKind IN (&ModifiedAccessKinds)
	|		
	|					UNION ALL
	|		
	|					SELECT
	|						AccessValuesOfAccessGroups.Ref
	|					FROM
	|						Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|					WHERE
	|						AccessValuesOfAccessGroups.AccessKind IN (&ModifiedAccessKinds))
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesAccessKinds.Ref AS AccessGroupOrProfile,
	|	ProfilesAccessKinds.AccessKind AS AccessKind,
	|	ProfilesAccessKinds.Predefined AS Predefined,
	|	ProfilesAccessKinds.AllAllowed AS AllAllowed
	|FROM
	|	Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|WHERE
	|	ProfilesAccessKinds.AccessKind IN(&ModifiedAccessKinds)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroupsAccessKinds.Ref,
	|	AccessGroupsAccessKinds.AccessKind,
	|	ISNULL(ProfilesAccessKinds.Predefined, UNDEFINED),
	|	AccessGroupsAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (AccessGroupsAccessKinds.AccessKind IN (&ModifiedAccessKinds))
	|			AND (AccessGroups.Ref = AccessGroupsAccessKinds.Ref)
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON (ProfilesAccessKinds.Ref = AccessGroups.Profile)
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesAccessValues.Ref AS AccessGroupOrProfile,
	|	ProfilesAccessValues.AccessKind AS AccessKind,
	|	ProfilesAccessValues.AccessValue AS AccessValue,
	|	ProfilesAccessValues.IncludeSubordinateAccessValues AS IncludeSubordinateAccessValues
	|FROM
	|	Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|WHERE
	|	ProfilesAccessValues.AccessKind IN(&ModifiedAccessKinds)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessValuesOfAccessGroups.Ref,
	|	AccessValuesOfAccessGroups.AccessKind,
	|	AccessValuesOfAccessGroups.AccessValue,
	|	AccessValuesOfAccessGroups.IncludeSubordinateAccessValues
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|WHERE
	|	AccessValuesOfAccessGroups.AccessKind IN(&ModifiedAccessKinds)";
	
	QueryResults = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("AccessGroups",   QueryResults[0].Unload());
	Result.Insert("AccessKinds",     QueryResults[1].Unload());
	Result.Insert("AccessValues", QueryResults[2].Unload());
	
	Return Result;
	
EndFunction

Function ValueGroupsChangesAccessGroupsAndProfilesProperties(ChangeInAccessValuesGroups, HierarchicalValues = False)
	
	Query = New Query;
	Query.SetParameter("ModifiedValueGroups",
		ChangeInAccessValuesGroups.UnloadColumn("ValuesGroup"));
	Query.SetParameter("ChangeKindModified", "IsChanged");
	Query.SetParameter("ChangeKindEmpty", "");
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessGroups.DeletionMark AS DeletionMark,
	|	PRESENTATION(AccessGroups.Ref) AS Presentation,
	|	AccessGroups.Profile AS Profile,
	|	ISNULL(AccessGroups.Profile.DeletionMark, FALSE) AS ProfileDeletionMark,
	|	PRESENTATION(AccessGroups.Profile) AS ProfilePresentation
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	CASE
	|			WHEN AccessGroups.Profile IN
	|					(SELECT
	|						ProfilesAccessValues.Ref
	|					FROM
	|						Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|					WHERE
	|						ProfilesAccessValues.AccessValue IN (&ModifiedValueGroups)
	|						AND &ProfilesAccessValuesIncludingLowerLevel)
	|				THEN TRUE
	|			WHEN AccessGroups.Ref IN
	|					(SELECT
	|						AccessValuesOfAccessGroups.Ref
	|					FROM
	|						Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|					WHERE
	|						AccessValuesOfAccessGroups.AccessValue IN (&ModifiedValueGroups)
	|						AND &AccessGroupsAccessValuesIncludingLowerLevel)
	|				THEN TRUE
	|			ELSE FALSE
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfilesAccessKinds.Ref AS AccessGroupOrProfile,
	|	ProfilesAccessKinds.AccessKind AS AccessKind,
	|	ProfilesAccessKinds.Predefined AS Predefined,
	|	ProfilesAccessKinds.AllAllowed AS AllAllowed
	|FROM
	|	Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON (ProfilesAccessValues.AccessValue IN (&ModifiedValueGroups))
	|			AND (&ProfilesAccessValuesIncludingLowerLevel)
	|			AND (ProfilesAccessKinds.Ref = ProfilesAccessValues.Ref)
	|			AND (ProfilesAccessKinds.AccessKind = ProfilesAccessValues.AccessKind)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AccessGroupsAccessKinds.Ref,
	|	AccessGroupsAccessKinds.AccessKind,
	|	ISNULL(ProfilesAccessKinds.Predefined, UNDEFINED),
	|	AccessGroupsAccessKinds.AllAllowed
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON (AccessValuesOfAccessGroups.AccessValue IN (&ModifiedValueGroups))
	|			AND (&AccessGroupsAccessValuesIncludingLowerLevel)
	|			AND (AccessGroupsAccessKinds.Ref = AccessValuesOfAccessGroups.Ref)
	|			AND (AccessGroupsAccessKinds.AccessKind = AccessValuesOfAccessGroups.AccessKind)
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (AccessGroups.Ref = AccessValuesOfAccessGroups.Ref)
	|		LEFT JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON (ProfilesAccessKinds.Ref = AccessGroups.Profile)
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfilesAccessValues.Ref AS Ref,
	|	ProfilesAccessValues.AccessKind AS AccessKind
	|INTO ProfilesValuesAccessKinds
	|FROM
	|	Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|WHERE
	|	ProfilesAccessValues.AccessValue IN(&ModifiedValueGroups)
	|	AND &ProfilesAccessValuesIncludingLowerLevel
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValuesOfAccessGroups.Ref AS Ref,
	|	AccessValuesOfAccessGroups.AccessKind AS AccessKind
	|INTO AccessGroupsValuesAccessKinds
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|WHERE
	|	AccessValuesOfAccessGroups.AccessValue IN(&ModifiedValueGroups)
	|	AND &AccessGroupsAccessValuesIncludingLowerLevel
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesAccessValues.Ref AS AccessGroupOrProfile,
	|	ProfilesAccessValues.AccessKind AS AccessKind,
	|	ProfilesAccessValues.AccessValue AS AccessValue,
	|	ProfilesAccessValues.IncludeSubordinateAccessValues AS IncludeSubordinateAccessValues,
	|	CASE
	|		WHEN ProfilesAccessValues.AccessValue IN (&ModifiedValueGroups)
	|				AND &ProfilesAccessValuesIncludingLowerLevel
	|			THEN &ChangeKindModified
	|		ELSE &ChangeKindEmpty
	|	END AS ChangeType
	|FROM
	|	ProfilesValuesAccessKinds AS ProfilesValuesAccessKinds
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessValues AS ProfilesAccessValues
	|		ON (ProfilesAccessValues.Ref = ProfilesValuesAccessKinds.Ref)
	|			AND (ProfilesAccessValues.AccessKind = ProfilesValuesAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessValuesOfAccessGroups.Ref,
	|	AccessValuesOfAccessGroups.AccessKind,
	|	AccessValuesOfAccessGroups.AccessValue,
	|	AccessValuesOfAccessGroups.IncludeSubordinateAccessValues,
	|	CASE
	|		WHEN AccessValuesOfAccessGroups.AccessValue IN (&ModifiedValueGroups)
	|				AND &AccessGroupsAccessValuesIncludingLowerLevel
	|			THEN &ChangeKindModified
	|		ELSE &ChangeKindEmpty
	|	END
	|FROM
	|	AccessGroupsValuesAccessKinds AS AccessGroupsValuesAccessKinds
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValuesOfAccessGroups
	|		ON (AccessValuesOfAccessGroups.Ref = AccessGroupsValuesAccessKinds.Ref)
	|			AND (AccessValuesOfAccessGroups.AccessKind = AccessGroupsValuesAccessKinds.AccessKind)";
	
	Query.Text = StrReplace(Query.Text,
		"&ProfilesAccessValuesIncludingLowerLevel",
		?(HierarchicalValues, "ProfilesAccessValues.IncludeSubordinateAccessValues", "TRUE"));
	
	Query.Text = StrReplace(Query.Text,
		"&AccessGroupsAccessValuesIncludingLowerLevel",
		?(HierarchicalValues, "AccessValuesOfAccessGroups.IncludeSubordinateAccessValues", "TRUE"));
	
	QueryResults = Query.ExecuteBatch();
	
	Result = New Structure;
	Result.Insert("AccessGroups",   QueryResults[0].Unload());
	Result.Insert("AccessKinds",     QueryResults[1].Unload());
	Result.Insert("AccessValues", QueryResults[4].Unload());
	
	Return Result;
	
EndFunction

Procedure FillAccessKindsAndValues(AccessKindsChange, AccessValuesChange,
			AccessGroupsProperties, AccessKindsProperties)
	
	Filter = New Structure("AccessGroupOrProfile, AccessKind");
	HasChangeKind = AccessGroupsProperties.AccessValues.Columns.Find("ChangeType") <> Undefined;
	PropertiesByValueTypes       = AccessKindsProperties.ByValuesTypes;
	PropertiesByValueAndGroupTypes = AccessKindsProperties.ByGroupsAndValuesTypes;
	
	For Each String In AccessGroupsProperties.AccessValues Do
		NewRow = AccessValuesChange.Add();
		FillPropertyValues(NewRow, String);
		If Not HasChangeKind Then
			NewRow.ChangeType = "IsChanged";
		EndIf;
		ValueType = TypeOf(NewRow.AccessValue);
		NewRow.IsValuesGroup = PropertiesByValueTypes.Get(ValueType) = Undefined
			And PropertiesByValueAndGroupTypes.Get(ValueType) <> Undefined;
		
		FillPropertyValues(Filter, String);
		If AccessGroupsProperties.AccessKinds.FindRows(Filter).Count() = 0 Then
			NewRow = AccessGroupsProperties.AccessKinds.Add();
			FillPropertyValues(NewRow, String);
			NewRow.AllAllowed = True;
			NewRow.Predefined = Undefined;
		EndIf;
	EndDo;
	
	AccessGroupsProperties.AccessKinds.Indexes.Add("AccessGroupOrProfile, AccessKind");
	For Each String In AccessGroupsProperties.AccessKinds Do
		NewRow = AccessKindsChange.Add();
		FillPropertyValues(NewRow, String);
		NewRow.ChangeType = "IsChanged";
	EndDo;
	
EndProcedure

Function ChangeInAccessValuesGroups(Object, PreviousValues1, MultipleValuesGroups)
	
	Result = New ValueTable;
	Result.Columns.Add("ValuesGroup", Metadata.DefinedTypes.AccessValue);
	Result.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue);
	Result.Columns.Add("ChangeType");
	
	If MultipleValuesGroups Then
		If TypeOf(PreviousValues1.AccessGroups) = Type("QueryResult") Then
			OldGroups = PreviousValues1.AccessGroups.Unload();
			For Each SpecificationRow In OldGroups Do
				If SpecificationRow.AccessGroup = Undefined
				 Or Object.AccessGroups.Find(SpecificationRow.AccessGroup, "AccessGroup") <> Undefined Then
					Continue;
				EndIf;
				NewRow = Result.Add();
				NewRow.ValuesGroup = SpecificationRow.AccessGroup;
				NewRow.AccessValue = Object.Ref;
				NewRow.ChangeType = "Deleted";
			EndDo;
		EndIf;
		For Each TSRow In Object.AccessGroups Do
			If TSRow.AccessGroup = Undefined
			 Or OldGroups.Find(TSRow.AccessGroup, "AccessGroup") <> Undefined Then
				Continue;
			EndIf;
			NewRow = Result.Add();
			NewRow.ValuesGroup = SpecificationRow.AccessGroup;
			NewRow.AccessValue = Object.Ref;
			NewRow.ChangeType = "Added2";
		EndDo;
	Else
		If Object.AccessGroup <> Undefined Then
			NewRow = Result.Add();
			NewRow.ValuesGroup = Object.AccessGroup;
			NewRow.AccessValue = Object.Ref;
			NewRow.ChangeType = "Added2";
		EndIf;
		If PreviousValues1.AccessGroup <> Undefined Then
			NewRow = Result.Add();
			NewRow.ValuesGroup = PreviousValues1.AccessGroup;
			NewRow.AccessValue = Object.Ref;
			NewRow.ChangeType = "Deleted";
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillProfilesAccessGroupsPresentation(Data, AccessGroups)
	
	For Each AccessGroupDetails In AccessGroups Do
		Properties = New Structure;
		Properties.Insert("AccessGroup", SerializedRef(AccessGroupDetails.AccessGroup));
		Properties.Insert("Presentation", AccessGroupDetails.Presentation);
		Properties.Insert("DeletionMark", AccessGroupDetails.DeletionMark);
		Properties.Insert("Profile", SerializedRef(AccessGroupDetails.Profile));
		Properties.Insert("ProfilePresentation", AccessGroupDetails.ProfilePresentation);
		Properties.Insert("ProfileDeletionMark", AccessGroupDetails.ProfileDeletionMark);
		Properties.Insert("OldPropertyValues", New Structure);
		Data.AccessGroupsPresentation.Add(Properties);
	EndDo;
	
EndProcedure

Function ParentsAccessValuesChange(Object, PreviousValues1)
	
	OldParents = ValueWithParents(PreviousValues1.Parent);
	NewParents  = ValueWithParents(Object.Parent);
	
	Result = New ValueTable;
	Result.Columns.Add("ValuesGroup",  Metadata.DefinedTypes.AccessValue.Type);
	Result.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	Result.Columns.Add("ChangeType");
	
	For Each PreviousParent In OldParents Do
		If NewParents.Find(PreviousParent) <> Undefined Then
			Continue;
		EndIf;
		NewRow = Result.Add();
		NewRow.ValuesGroup = PreviousParent;
		NewRow.AccessValue = Object.Ref;
		NewRow.ChangeType = "Deleted";
	EndDo;
	
	For Each NewParent In NewParents Do
		If OldParents.Find(NewParent) <> Undefined Then
			Continue;
		EndIf;
		NewRow = Result.Add();
		NewRow.ValuesGroup = NewParent;
		NewRow.AccessValue = Object.Ref;
		NewRow.ChangeType = "Added2";
	EndDo;
	
	Return Result;
	
EndFunction

Function ValueWithParents(Parent)
	
	Result = New Array;
	MetadataTables = Metadata.FindByType(TypeOf(Parent));
	If MetadataTables = Undefined Then
		Return Result;
	EndIf;
	
	Properties = New Structure("Hierarchical", False);
	FillPropertyValues(Properties, MetadataTables);
	
	If Not Properties.Hierarchical Then
		Return Result;
	EndIf;
	
	Result.Add(Parent);
	If Not ValueIsFilled(Parent) Then
		Return Result;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", Parent);
	Query.Text =
	"SELECT
	|	CurrentTable.Parent AS Parent1,
	|	CurrentTable.Parent.Parent AS Parent2,
	|	CurrentTable.Parent.Parent.Parent AS Parent3,
	|	CurrentTable.Parent.Parent.Parent.Parent AS Parent4,
	|	CurrentTable.Parent.Parent.Parent.Parent.Parent AS Parent5
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	CurrentTable.Ref = &Ref";
	
	Query.Text = StrReplace(Query.Text, "&CurrentTable", MetadataTables.FullName());

	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result.Add(Selection.Parent1);
		If ValueIsFilled(Selection.Parent1) Then
			Result.Add(Selection.Parent2);
			If ValueIsFilled(Selection.Parent2) Then
				Result.Add(Selection.Parent3);
				If ValueIsFilled(Selection.Parent3) Then
					Result.Add(Selection.Parent4);
					If ValueIsFilled(Selection.Parent4) Then
						AdditionalResult = ValueWithParents(Selection.Parent5);
						For Each Value In AdditionalResult Do
							Result.Add(Value);
						EndDo;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to support data exchange in DIB.

// For internal use only.
//
// Parameters:
//  DataElement - CatalogObject.AccessGroups
//
Procedure RestoreAdministratorsAccessGroupMembers(DataElement) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"Catalogs.AccessGroups.RestoreAdministratorsAccessGroupMembers");
	
	AdministratorsAccessGroup = AccessManagement.AdministratorsAccessGroup();
	If DataElement.Ref <> AdministratorsAccessGroup Then
		Return;
	EndIf;
	
	DataElement.Users.Clear();
	
	Query = New Query;
	Query.SetParameter("AdministratorsAccessGroup", AdministratorsAccessGroup);
	Query.Text =
	"SELECT DISTINCT
	|	AccessGroups_Users.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroups_Users
	|WHERE
	|	AccessGroups_Users.Ref = &AdministratorsAccessGroup";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If DataElement.Users.Find(Selection.User, "User") = Undefined Then
			DataElement.Users.Add().User = Selection.User;
		EndIf;
	EndDo;
	
EndProcedure

// For internal use only.
Procedure DeleteMembersOfAdministratorsAccessGroupWithoutIBUser() Export
	
	AdministratorsAccessGroup = AccessManagement.AdministratorsAccessGroup();
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", AdministratorsAccessGroup);
	
	BeginTransaction();
	Try
		Block.Lock();
		AdministratorsAccessGroup = AdministratorsAccessGroup.GetObject();
		
		IndexOf = AdministratorsAccessGroup.Users.Count() - 1;
		While IndexOf >= 0 Do
			CurrentUser = AdministratorsAccessGroup.Users[IndexOf].User;
			If TypeOf(CurrentUser) = Type("CatalogRef.Users") Then
				IBUserID = Common.ObjectAttributeValue(CurrentUser,
					"IBUserID");
			Else
				IBUserID = Undefined;
			EndIf;
			If TypeOf(IBUserID) = Type("UUID") Then
				IBUser = InfoBaseUsers.FindByUUID(
					IBUserID);
			Else
				IBUser = Undefined;
			EndIf;
			If IBUser = Undefined Then
				AdministratorsAccessGroup.Users.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		
		If AdministratorsAccessGroup.Modified() Then
			AdministratorsAccessGroup.Write();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


// For internal use only.
// 
// Parameters:
//  DataElement - CatalogObject.AccessGroups
//                - ObjectDeletion
//
Procedure RegisterChangeUponDataImport(DataElement) Export
	
	PreviousValues1 = Common.ObjectAttributesValues(DataElement.Ref,
		"Ref, Profile, DeletionMark, Users, AccessKinds, AccessValues");
	
	Required2Registration = False;
	AccessGroup = DataElement.Ref;
	
	If TypeOf(DataElement) = Type("ObjectDeletion") Then
		If PreviousValues1.Ref = Undefined Then
			Return;
		EndIf;
		Required2Registration = True;
		
	ElsIf PreviousValues1.Ref <> DataElement.Ref Then
		Required2Registration = True;
		AccessGroup = UsersInternal.ObjectRef2(DataElement);
	
	ElsIf DataElement.DeletionMark <> PreviousValues1.DeletionMark
	      Or DataElement.Profile         <> PreviousValues1.Profile Then
		
		Required2Registration = True;
	Else
		HasMembers = DataElement.Users.Count() <> 0;
		HasOldMembers = Not PreviousValues1.Users.IsEmpty();
		
		If HasMembers <> HasOldMembers
		 Or AccessKindsOrAccessValuesChanged(PreviousValues1, DataElement) Then
			
			Required2Registration = True;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Required2Registration Then
		UsersInternal.RegisterRefs("AccessGroups", AccessGroup);
	EndIf;
	
	UsersInternal.RegisterRefs("AccessGroups_Users",
		UsersForRolesUpdate(PreviousValues1, DataElement));
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		RolesToUpdate = RolesForUpdatingRights(PreviousValues1, DataElement);
		UsersInternal.RegisterRefs("AccessGroupsRoles", RolesToUpdate);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure ProcessChangeRegisteredUponDataImport() Export
	
	If Common.DataSeparationEnabled() Then
		// Changes of the access groups in SWP are blocked and are not imported into the data area.
		Return;
	EndIf;
	
	RegistrationCleanup = New Array;
	ProcessRegisteredChangeInAccessGroups("AccessGroups", RegistrationCleanup);
	ProcessRegisteredChangeInRoles("AccessGroupsRoles", RegistrationCleanup);
	ProcessRegisteredChangeInMembers("AccessGroups_Users", RegistrationCleanup);
	
	For Each RefsKindName In RegistrationCleanup Do
		UsersInternal.RegisterRefs(RefsKindName, Null);
	EndDo;
	
EndProcedure

// Intended for procedure "ProcessChangeRegisteredUponDataImport".
Procedure ProcessRegisteredChangeInAccessGroups(RefsKindName, RegistrationCleanup)

	ChangedAccessGroups = UsersInternal.RegisteredRefs(RefsKindName);
	If ChangedAccessGroups.Count() = 0 Then
		Return;
	EndIf;
	
	If ChangedAccessGroups.Count() = 1
	   And ChangedAccessGroups[0] = Undefined Then
		
		ChangedAccessGroups = Undefined;
	EndIf;
	
	InformationRegisters.AccessGroupsTables.UpdateRegisterData(ChangedAccessGroups);
	InformationRegisters.AccessGroupsValues.UpdateRegisterData(ChangedAccessGroups);
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		LongDesc = "UpdateAccessGroupsAuxiliaryDataChangedOnImport";
		AccessManagementInternal.ScheduleAccessGroupsSetsUpdate(LongDesc);
		
		ChangedMembersTypes = New Structure("Users, ExternalUsers", True, True);
		AccessManagementInternal.ScheduleAccessUpdateOnChangeAccessGroupMembers(
			ChangedAccessGroups, ChangedMembersTypes, True);
		
		AccessManagementInternal.UpdateAccessGroupsOfAllowedAccessKey(ChangedAccessGroups);
	EndIf;
	
	RegistrationCleanup.Add(RefsKindName);
	
EndProcedure

// Intended for procedure "ProcessChangeRegisteredUponDataImport".
Procedure ProcessRegisteredChangeInRoles(RefsKindName, RegistrationCleanup)
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	CompositionOfRoleChanges = UsersInternal.RegisteredRefs(RefsKindName);
	If CompositionOfRoleChanges.Count() = 0 Then
		Return;
	EndIf;
	
	If CompositionOfRoleChanges.Count() = 1
	   And CompositionOfRoleChanges[0] = Undefined Then
		
		CompositionOfRoleChanges = Undefined;
	EndIf;
	
	LongDesc = "UpdateAccessGroupsAuxiliaryDataChangedOnImport";
	AccessManagementInternal.ScheduleAnAccessUpdateWhenTheAccessGroupProfileChanges(LongDesc,
		CompositionOfRoleChanges, True);
	
	RegistrationCleanup.Add(RefsKindName);
	
EndProcedure

// Intended for procedure "ProcessChangeRegisteredUponDataImport".
Procedure ProcessRegisteredChangeInMembers(RefsKindName, RegistrationCleanup)
	
	Content = UsersInternal.RegisteredRefs(RefsKindName);
	If Content.Count() = 0 Then
		Return;
	EndIf;
	
	If Content.Count() = 1 And Content[0] = Undefined Then
		Content = Undefined;
	EndIf;
	
	AccessManagement.UpdateUserRoles(Content);
	
	RegistrationCleanup.Add(RefsKindName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initial population

// See also InfobaseUpdateOverridable.OnSetUpInitialItemsFilling
// 
// Parameters:
//  Settings - See InfobaseUpdateOverridable.OnSetUpInitialItemsFilling.Settings
//
Procedure OnSetUpInitialItemsFilling(Settings) Export
	
	Settings.OnInitialItemFilling = False;
	
EndProcedure

// See also InfobaseUpdateOverridable.OnInitialItemsFilling
// 
// Parameters:
//   LanguagesCodes - See InfobaseUpdateOverridable.OnInitialItemsFilling.LanguagesCodes
//   Items - See InfobaseUpdateOverridable.OnInitialItemsFilling.Items
//   TabularSections - See InfobaseUpdateOverridable.OnInitialItemsFilling.TabularSections
//
Procedure OnInitialItemsFilling(LanguagesCodes, Items, TabularSections) Export

	Item = Items.Add();
	Item.PredefinedDataName = "Administrators";
	Item.Description = NStr("en = 'Administrators';", Common.DefaultLanguageCode());
	Item.Profile      = AccessManagement.ProfileAdministrator();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Procedure FillAdministratorsAccessGroupProfile() Export
	
	Object = AccessManagement.AdministratorsAccessGroup().GetObject();
	If Object.Profile <> AccessManagement.ProfileAdministrator() Then
		Object.Profile = AccessManagement.ProfileAdministrator();
		InfobaseUpdate.WriteData(Object);
	EndIf;
	
EndProcedure

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups";
	
	InfobaseUpdate.MarkForProcessing(Parameters,
		Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	ParametersOfUpdate = New Structure;
	If Parameters.Property("AccessGroups") Then
		AccessGroups = Parameters.AccessGroups;
		ParametersOfUpdate.Insert("RaiseException1");
	Else
		Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.AccessGroups");
		AccessGroups = New Array;
		While Selection.Next() Do
			AccessGroups.Add(Selection.Ref);
		EndDo;
	EndIf;
	ParametersOfUpdate.Insert("AccessGroups", AccessGroups);
	
	If Catalogs.ExtensionsVersions.ExtensionsChangedDynamically()
	   And (Not Common.FileInfobase()
	      Or CurrentRunMode() <> Undefined) Then
		
		ResultAddress = PutToTempStorage(Undefined);
		ParametersOfUpdate.Insert("ResultAddress", ResultAddress);
		JobDescription =
			NStr("en = 'Updating service data of access groups';",
				Common.DefaultLanguageCode());
		BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
			"AccessManagementInternal.UpdateAuxiliaryAccessGroupsData",
			CommonClientServer.ValueInArray(ParametersOfUpdate),,
			JobDescription);
		BackgroundJob = BackgroundJob.WaitForExecutionCompletion();
		If BackgroundJob.State <> BackgroundJobState.Completed Then
			If BackgroundJob.ErrorInfo <> Undefined Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Background job ""%1"" completed with error:
					           |%2';"),
					JobDescription,
					ErrorProcessing.DetailErrorDescription(BackgroundJob.ErrorInfo));
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Background job ""%1"" did not complete.';"), JobDescription);
			EndIf;
			Raise ErrorText;
		EndIf;
		Result = GetFromTempStorage(ResultAddress);
		If TypeOf(Result) <> Type("Structure") Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Background job ""%1"" did not return the result.';"), JobDescription);
			Raise ErrorText;
		EndIf;
	Else
		UpdateAuxiliaryAccessGroupsData(ParametersOfUpdate);
		Result = ParametersOfUpdate.Result;
	EndIf;
	For Each AccessGroup In Result.ProcessedAccessGroups Do
		InfobaseUpdate.MarkProcessingCompletion(AccessGroup);
	EndDo;
	ObjectsProcessed = Result.ProcessedAccessGroups.Count();
	ObjectsWithIssuesCount = Result.ObjectsWithIssuesCount;
	
	If Parameters.Property("AccessGroups") Then
		Return;
	EndIf;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.AccessGroups") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some access groups: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information,
			Metadata.Catalogs.AccessGroups,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of access groups is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

Procedure UpdateAuxiliaryAccessGroupsData(Parameters) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IsInternal";
	
	Selection = Query.Execute().Select();
	UtilityUsers = New Map;
	While Selection.Next() Do
		UtilityUsers.Insert(Selection.Ref, True);
	EndDo;
	
	AccessGroupProcessingErrorTemplate =
		NStr("en = 'Couldn''t process the ""%1"" access group. Reason:
		           |%2';");
	AccessGroupsTablesUpdateErrorTemplate =
		NStr("en = 'Cannot update tables of the ""%1"" access group. Reason:
		           |%2';");
	AccessGroupsValuesUpdateErrorTemplate =
		NStr("en = 'Cannot update Access Values of the ""%1"" access group. Reason:
		           |%2';");
	
	ObjectsWithIssuesCount = 0;
	ProcessedAccessGroups = New Array;
	
	For Each AccessGroup In Parameters.AccessGroups Do
		Block = New DataLock;
		LockItem = Block.Add("Catalog.AccessGroups");
		LockItem.SetValue("Ref", AccessGroup);
		RepresentationOfTheReference = String(AccessGroup);
		BeginTransaction();
		Try
			ErrorTemplate = AccessGroupProcessingErrorTemplate;
			Block.Lock();
			
			AccessGroupObject = AccessGroup.GetObject(); // CatalogObject.AccessGroups
			IndexOf = AccessGroupObject.Users.Count();
			While IndexOf > 0 Do
				IndexOf = IndexOf - 1;
				TSRow = AccessGroupObject.Users.Get(IndexOf);
				If UtilityUsers.Get(TSRow.User) <> Undefined Then
					AccessGroupObject.Users.Delete(IndexOf);
				EndIf;
			EndDo;
			
			If AccessGroupObject.Modified() Then
				InfobaseUpdate.WriteObject(AccessGroupObject, False);
				AccessManagementInternal.ScheduleAccessGroupsSetsUpdate(
					"UpdateAuxiliaryAccessGroupsData", True, False);
			EndIf;
			
			ErrorTemplate = AccessGroupsTablesUpdateErrorTemplate;
			InformationRegisters.AccessGroupsTables.UpdateRegisterData(AccessGroup);
			
			ErrorTemplate = AccessGroupsValuesUpdateErrorTemplate;
			InformationRegisters.AccessGroupsValues.UpdateRegisterData(AccessGroup);
			
			ErrorTemplate = AccessGroupProcessingErrorTemplate;
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			ErrorInfo = ErrorInfo();
			If Parameters.Property("RaiseException1") Then
				Raise;
			EndIf;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate,
				RepresentationOfTheReference,
				ErrorProcessing.DetailErrorDescription(ErrorInfo));
			
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Warning, , , MessageText);
			Continue;
		EndTry;
		
		ProcessedAccessGroups.Add(AccessGroup);
	EndDo;
	
	Result = New Structure;
	Result.Insert("ObjectsWithIssuesCount", ObjectsWithIssuesCount);
	Result.Insert("ProcessedAccessGroups", ProcessedAccessGroups);
	
	If Parameters.Property("ResultAddress") Then
		PutToTempStorage(Result, Parameters.ResultAddress);
	Else
		Parameters.Insert("Result", Result);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
