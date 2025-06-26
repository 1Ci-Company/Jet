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

Var PreviousValues1; // See PreviousValues1

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// ACC:75-off - "DataExchange.Import" check must follow the logging of changes.
	If IsFolder Then
		Return;
	EndIf;
	
	If UsersInternalCached.ShouldRegisterChangesInAccessRights()
	 Or Not DataExchange.Load Then
		
		If Common.FileInfobase() Then
			AccessManagementInternal.LockRegistersBeforeWritingAccessConfigurationObjectToFileInformationSystem();
		EndIf;
		PreviousValues1 = PreviousValues1();
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InformationRegisters.RolesRights.CheckRegisterData();

	If Not Catalogs.ExtensionsVersions.AllExtensionsConnected() Then
		Catalogs.AccessGroupProfiles.RestoreNonexistentViewsFromAccessValue(PreviousValues1, ThisObject);
	EndIf;
	
	// Check roles.
	AdministratorRoles = New Array;
	AdministratorRoles.Add("Role.FullAccess");
	AdministratorRoles.Add("Role.SystemAdministrator");
	RoleIDs = Common.MetadataObjectIDs(AdministratorRoles);
	ProcessedRoles = New Map;
	ProfileAdministrator = AccessManagement.ProfileAdministrator();
	IndexOf = Roles.Count();
	While IndexOf > 0 Do
		IndexOf = IndexOf - 1;
		Role = Roles[IndexOf].Role;
		If ProcessedRoles.Get(Role) <> Undefined Then
			Roles.Delete(IndexOf);
			Continue;
		EndIf;
		ProcessedRoles.Insert(Role, True);
		If Ref = ProfileAdministrator Then
			Continue;
		EndIf;
		If Role = RoleIDs["Role.FullAccess"]
		 Or Role = RoleIDs["Role.SystemAdministrator"] Then
			
			Roles.Delete(IndexOf);
		EndIf;
	EndDo;
	
	Catalogs.AccessGroupProfiles.FillStandardExtensionRoles(Roles);
	
	If Not AdditionalProperties.Property("DoNotUpdateAttributeSuppliedProfileChanged") Then
		NewValue1CSuppliedProfileModified =
			Catalogs.AccessGroupProfiles.SuppliedProfileChanged(ThisObject);
		
		If SuppliedProfileChanged <> NewValue1CSuppliedProfileModified
		   And (Not NewValue1CSuppliedProfileModified
			  Or Catalogs.AccessGroupProfiles.Are1CSuppliedProfileAreasModified(ThisObject, PreviousValues1)) Then
			
			SuppliedProfileChanged = NewValue1CSuppliedProfileModified;
		EndIf;
	EndIf;
	
	// Updating descriptions for personal access groups of this profile (if any).
	InterfaceSimplified = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	If InterfaceSimplified Then
		
		Query = New Query;
		Query.SetParameter("Profile",      Ref);
		Query.SetParameter("Description", Description);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	AccessGroups.Profile = &Profile
		|	AND AccessGroups.User <> UNDEFINED
		|	AND AccessGroups.User <> VALUE(Catalog.Users.EmptyRef)
		|	AND AccessGroups.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
		|	AND AccessGroups.Description <> &Description";
		
		BeginTransaction();
		Try
			ChangedAccessGroups = Query.Execute().Unload().UnloadColumn("Ref"); // Array of CatalogRef.AccessGroupProfiles
			
			If ChangedAccessGroups.Count() > 0 Then
				Block = New DataLock;
				For Each AccessGroupRef In ChangedAccessGroups Do
					LockItem = Block.Add("Catalog.AccessGroups");
					LockItem.SetValue("Ref", AccessGroupRef);
				EndDo;
				Block.Lock();
				
				For Each AccessGroupRef In ChangedAccessGroups Do
					PersonalAccessGroupObject = AccessGroupRef.GetObject();
					PersonalAccessGroupObject.Description = Description;
					InfobaseUpdate.WriteData(PersonalAccessGroupObject);
				EndDo;
				AdditionalProperties.Insert("PersonalAccessGroupsWithUpdatedDescription", ChangedAccessGroups);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;	
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// ACC:75-off - "DataExchange.Import" check must follow the logging of changes.
	If IsFolder Then
		Return;
	EndIf;
	
	If UsersInternalCached.ShouldRegisterChangesInAccessRights() Then
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		Catalogs.AccessGroupProfiles.RegisterChangeInProfilesRoles(ThisObject, PreviousValues1);
		Catalogs.AccessGroups.RegisterChangeInAccessGroupsMembers(ThisObject, PreviousValues1);
		Catalogs.AccessGroups.RegisterChangeInAllowedValues(ThisObject, PreviousValues1);
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	EndIf;
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CheckSuppliedDataUniqueness();
	
	// When setting a deletion mark, the deletion mark is also set for the profile access groups.
	If Catalogs.AccessGroups.IsProfileMarkedForDeletion(ThisObject, PreviousValues1) Then
		Query = New Query;
		Query.SetParameter("Profile", Ref);
		Query.Text =
		"SELECT
		|	AccessGroups.Ref AS Ref
		|FROM
		|	Catalog.AccessGroups AS AccessGroups
		|WHERE
		|	(NOT AccessGroups.DeletionMark)
		|	AND AccessGroups.Profile = &Profile";
		
		BeginTransaction();
		Try
			ChangedAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
			If ChangedAccessGroups.Count() > 0 Then
				Block = New DataLock;
				For Each AccessGroupRef In ChangedAccessGroups Do
					LockItem = Block.Add("Catalog.AccessGroups");
					LockItem.SetValue("Ref", AccessGroupRef);
					LockDataForEdit(AccessGroupRef);
				EndDo;
				Block.Lock();
				
				SetPrivilegedMode(True);
				For Each AccessGroupRef In ChangedAccessGroups Do
					AccessGroupObject = AccessGroupRef.GetObject();
					AccessGroupObject.AdditionalProperties.Insert("MarkAccessGroupForDeletionWhenProfileMarkedForDeletion");
					AccessGroupObject.DeletionMark = True;
					AccessGroupObject.Write();
				EndDo;
				SetPrivilegedMode(False);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	If AdditionalProperties.Property("UpdateProfileAccessGroups") Then
		Catalogs.AccessGroups.UpdateProfileAccessGroups(Ref, True);
	EndIf;
	
	TablesContentChangesOnChangeRoles = UpdateUsersRolesOnChangeProfileRoles();
	
	If TablesContentChangesOnChangeRoles.Count() > 0 Then
		ProfileAccessGroups = Catalogs.AccessGroups.ProfileAccessGroups(Ref);
		InformationRegisters.AccessGroupsTables.UpdateRegisterData(ProfileAccessGroups,
			TablesContentChangesOnChangeRoles);
	EndIf;
	
	If Catalogs.AccessGroupProfiles.AccessKindsOrValuesOrAssignmentChanged(PreviousValues1, ThisObject)
	 Or DeletionMark <> PreviousValues1.DeletionMark Then
		
		If ProfileAccessGroups = Undefined Then
			ProfileAccessGroups = Catalogs.AccessGroups.ProfileAccessGroups(Ref);
		EndIf;
		InformationRegisters.AccessGroupsValues.UpdateRegisterData(ProfileAccessGroups);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("VerifiedObjectAttributes") Then
		Common.DeleteNotCheckedAttributesFromArray(
			CheckedAttributes, AdditionalProperties.VerifiedObjectAttributes);
	EndIf;
	
	CheckSuppliedDataUniqueness(True, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If IsFolder Then
		Return;
	EndIf;
	
	SuppliedDataID = Undefined;
	
	If Not CopiedObject.AdditionalProperties.Property("SkipClearingRoles")
	   And CopiedObject.Ref = AccessManagement.ProfileAdministrator() Then
		Roles.Clear();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Function UpdateUsersRolesOnChangeProfileRoles()
	
	Query = New Query;
	Query.SetParameter("Profile", ?(DeletionMark,
		Catalogs.AccessGroupProfiles.EmptyRef(), Ref));
	
	Query.SetParameter("OldProfileRoles",
		?(Ref = PreviousValues1.Ref And Not PreviousValues1.DeletionMark,
			PreviousValues1.Roles.Unload(), Roles.Unload(New Array)));
	
	Query.Text =
	"SELECT
	|	OldProfileRoles.Role
	|INTO OldProfileRoles
	|FROM
	|	&OldProfileRoles AS OldProfileRoles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Data.Role
	|INTO ModifiedRoles
	|FROM
	|	(SELECT
	|		OldProfileRoles.Role AS Role,
	|		-1 AS LineChangeType
	|	FROM
	|		OldProfileRoles AS OldProfileRoles
	|	
	|	UNION ALL
	|	
	|	SELECT DISTINCT
	|		NewProfileRoles.Role,
	|		1
	|	FROM
	|		Catalog.AccessGroupProfiles.Roles AS NewProfileRoles
	|	WHERE
	|		NewProfileRoles.Ref = &Profile) AS Data
	|
	|GROUP BY
	|	Data.Role
	|
	|HAVING
	|	SUM(Data.LineChangeType) <> 0
	|
	|INDEX BY
	|	Data.Role";
	
	QueryText =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ExtensionsRolesRights.EditRight AS EditRight,
	|	ExtensionsRolesRights.LineChangeType AS LineChangeType
	|INTO ExtensionsRolesRights
	|FROM
	|	&ExtensionsRolesRights AS ExtensionsRolesRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ExtensionsRolesRights.EditRight AS EditRight
	|INTO RolesRights
	|FROM
	|	ExtensionsRolesRights AS ExtensionsRolesRights
	|WHERE
	|	ExtensionsRolesRights.LineChangeType = 1
	|
	|UNION ALL
	|
	|SELECT
	|	RolesRights.MetadataObject,
	|	RolesRights.Role,
	|	RolesRights.AddRight,
	|	RolesRights.RightUpdate,
	|	RolesRights.UnrestrictedReadRight,
	|	RolesRights.UnrestrictedAddRight,
	|	RolesRights.UnrestrictedUpdateRight,
	|	RolesRights.ViewRight,
	|	RolesRights.InteractiveAddRight,
	|	RolesRights.EditRight
	|FROM
	|	InformationRegister.RolesRights AS RolesRights
	|		LEFT JOIN ExtensionsRolesRights AS ExtensionsRolesRights
	|		ON RolesRights.MetadataObject = ExtensionsRolesRights.MetadataObject
	|			AND RolesRights.Role = ExtensionsRolesRights.Role
	|WHERE
	|	ExtensionsRolesRights.MetadataObject IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	RolesRights.MetadataObject AS MetadataObject
	|FROM
	|	RolesRights AS RolesRights
	|		INNER JOIN ModifiedRoles AS ModifiedRoles
	|		ON RolesRights.Role = ModifiedRoles.Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ModifiedRoles.Role AS Role
	|FROM
	|	ModifiedRoles AS ModifiedRoles";
	
	Query.Text = Query.Text + "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|" + QueryText;
	
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	QueriesResults = Query.ExecuteBatch();
	
	If AccessManagementInternal.LimitAccessAtRecordLevelUniversally()
	   And Not QueriesResults[5].IsEmpty() Then
			
			ModifiedRoles = QueriesResults[5].Unload().UnloadColumn("Role");
			AccessManagementInternal.ScheduleAccessUpdatesWhenProfileRolesChange(
				"UpdateUsersRolesOnChangeProfileRoles", ModifiedRoles);
	EndIf;
	
	If Not AdditionalProperties.Property("DoNotUpdateUsersRoles")
	   And Not QueriesResults[5].IsEmpty() Then
		
		UsersForRolesUpdate = Catalogs.AccessGroups.UsersForRolesUpdateByProfile(Ref);
		AccessManagement.UpdateUserRoles(UsersForRolesUpdate);
	EndIf;
	
	Return QueriesResults[4].Unload().UnloadColumn("MetadataObject");
	
EndFunction

Procedure CheckSuppliedDataUniqueness(Var_FillChecking = False, Cancel = False)
	
	// Checking the supplied data for uniqueness.
	If Not ValueIsFilled(SuppliedDataID) Then
		Return;
	EndIf;

	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("SuppliedDataID", SuppliedDataID);
	Query.Text =
	"SELECT
	|	AccessGroupProfiles.Ref AS Ref,
	|	AccessGroupProfiles.Description AS Description
	|FROM
	|	Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|WHERE
	|	AccessGroupProfiles.SuppliedDataID = &SuppliedDataID";
	
	Selection = Query.Execute().Select();
	If Selection.Count() > 1 Then
		
		BriefErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '1C-supplied profile ""%1"" already exists:';"),
			Description);
		
		DetailErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""%1"" default master data ID is already used in the ""%2"" profile:';"),
			String(SuppliedDataID),
			Description);
		
		While Selection.Next() Do
			If Selection.Ref <> Ref Then
				
				BriefErrorDescription = BriefErrorDescription
					+ Chars.LF + """" + Selection.Description + """.";
				
				DetailErrorDescription = DetailErrorDescription
					+ Chars.LF + """" + Selection.Description + """ ("
					+ String(Selection.Ref.UUID())+ ")."
			EndIf;
		EndDo;
		
		If Var_FillChecking Then
			Common.MessageToUser(BriefErrorDescription,,,, Cancel);
		Else
			WriteLogEvent(
				NStr("en = 'Access management.Duplicate built-in profile';",
				     Common.DefaultLanguageCode()),
				EventLogLevel.Error, , , DetailErrorDescription);
		EndIf;
	EndIf;
	
EndProcedure

// Values of some attributes and tabular sections of the profile
// before it is changed for use in the OnWrite event handler.
// 
// Returns:
//  Structure:
//     * Ref - CatalogRef.AccessGroupProfiles
//     * Description    - String
//     * Parent        - CatalogRef.AccessGroupProfiles
//     * DeletionMark - Boolean
//     * Roles - QueryResult
//     * Purpose - QueryResult
//     * AccessKinds - QueryResult
//     * AccessValues - QueryResult
//
Function PreviousValues1()

	Return Common.ObjectAttributesValues(Ref,
		"Ref, Description, Parent, DeletionMark, Roles, Purpose, AccessKinds, AccessValues");
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf