///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to check rights.

// Checks whether the user has a role in one of the profiles of the access groups, to which they belong. 
// For example, the ViewEventLog role, the UnpostedDocumentsPrint role.
//
// If an object (or access value sets) is specified, it is required to check
// whether the access group provides the Read right for the specified object (or the specified access value set is allowed).
//
// Parameters:
//  Role           - String - Role name.
//
//  ObjectReference - AnyRef - a reference to the object, for which the access value sets are filled
//                   to check the Read right.
//                 - ValueTable - A table of arbitrary access value sets. Columns are:
//                     * SetNumber     - Number  - a number grouping multiple rows in a separate set.
//                     * AccessKind      - String - an access kind name specified in the overridable module.
//                     * AccessValue - DefinedType.AccessValue - a reference to the access value type
//                       specified in the overridable module.
//                       You can receive a blank prepared table using the
//                       AccessValuesSetsTable function of the AccessManagement common module
//                       (do not fill in the Read and Update columns).
//
//  User   - CatalogRef.Users
//                 - CatalogRef.ExternalUsers
//                 - Undefined - if the parameter is not specified,
//                     the right is checked for the current user.
//
// Returns:
//  Boolean - if True, the user has a role with restrictions.
//
Function HasRole(Val Role, Val ObjectReference = Undefined, Val User = Undefined) Export
	
	User = ?(ValueIsFilled(User), User, Users.AuthorizedUser());
	If Users.IsFullUser(User) Then
		Return True;
	EndIf;
	Role = Common.MetadataObjectID("Role." + Role);
	
	SetPrivilegedMode(True);
	
	If ObjectReference = Undefined Or Not LimitAccessAtRecordLevel() Then
		// Checking that the role is assigned to the user using an access group profile.
		Query = New Query;
		Query.SetParameter("AuthorizedUser", User);
		Query.SetParameter("Role", Role);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	Catalog.AccessGroups.Users AS AccessGroups_Users
		|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|		ON (UserGroupCompositions.User = &AuthorizedUser)
		|			AND (UserGroupCompositions.UsersGroup = AccessGroups_Users.User)
		|			AND (UserGroupCompositions.Used)
		|			AND (NOT AccessGroups_Users.Ref.DeletionMark)
		|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
		|		ON AccessGroups_Users.Ref.Profile = AccessGroupProfilesRoles.Ref
		|			AND (AccessGroupProfilesRoles.Role = &Role)
		|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)";
		Return Not Query.Execute().IsEmpty();
	EndIf;
		
	If TypeOf(ObjectReference) = Type("ValueTable") Then
		AccessValuesSets = ObjectReference.Copy();
	Else
		AccessValuesSets = AccessValuesSetsTable();
		ObjectReference.GetObject().FillAccessValuesSets(AccessValuesSets);
		// Selecting the access value sets used to check the Read right.
		ReadSetsRows = AccessValuesSets.FindRows(New Structure("Read", True));
		SetsNumbers = New Map;
		For Each String In ReadSetsRows Do
			SetsNumbers.Insert(String.SetNumber, True);
		EndDo;
		IndexOf = AccessValuesSets.Count() - 1;
		While IndexOf >= 0 Do
			If SetsNumbers[AccessValuesSets[IndexOf].SetNumber] = Undefined Then
				AccessValuesSets.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		AccessValuesSets.FillValues(False, "Read, Update");
	EndIf;
	
	// Adjusting access value sets.
	AccessKindsNames = AccessManagementInternal.AccessKindsProperties().ByNames;
	
	For Each String In AccessValuesSets Do
		
		If String.AccessKind = "" Then
			Continue;
		EndIf;
		
		If Upper(String.AccessKind) = Upper("ReadRight1")
		 Or Upper(String.AccessKind) = Upper("EditRight") Then
			
			If TypeOf(String.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				If Common.IsReference(TypeOf(String.AccessValue)) Then
					String.AccessValue = Common.MetadataObjectID(TypeOf(String.AccessValue));
				Else
					String.AccessValue = Undefined;
				EndIf;
			EndIf;
			
			If Upper(String.AccessKind) = Upper("EditRight") Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error in function ""%1"" of module ""%2"".
					           |The access value set contains the ""%3"" access kind 
					           |for the table with ID ""%4"".
					           |The only additional right that can be included
					           |in the access restriction is Read.';"),
					"HasRole",
					"AccessManagement",
					"EditRight",
					String.AccessValue,
					"Reads");
				Raise ErrorText;
			EndIf;
		ElsIf AccessKindsNames.Get(String.AccessKind) <> Undefined
		      Or String.AccessKind = "RightsSettings" Then
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in function ""%1"" of module ""%2"".
				           |The access value set contains a known access kind ""%3.""
				           |It cannot contain this access kind.
				           |
				           |It can only contain special access kinds
				           |""%4"" and ""%5"".';"),
				"HasRole",
				"AccessManagement",
				String.AccessKind,
				"ReadRight1",
				"EditRight");
			Raise ErrorText;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in function ""%1"" of module ""%2"".
				           |The access value set contains an unknown access kind ""%1"".';"),
				"HasRole",
				"AccessManagement",
				String.AccessKind);
			Raise ErrorText;
		EndIf;
		
		String.AccessKind = "";
	EndDo;
	
	// Adding internal fields to an access value set.
	AccessManagementInternal.PrepareAccessValuesSetsForWrite(Undefined, AccessValuesSets, True);
	
	// Check that the user is assigned the role via the access group by a profile with an allowed access value set.
	// 
	
	Query = New Query;
	Query.SetParameter("AuthorizedUser", User);
	Query.SetParameter("Role", Role);
	Query.SetParameter("AccessValuesSets", AccessValuesSets);
	Query.SetParameter("RightsSettingsOwnersTypes", SessionParameters.RightsSettingsOwnersTypes);
	Query.Text =
	"SELECT DISTINCT
	|	AccessValuesSets.SetNumber,
	|	AccessValuesSets.AccessValue,
	|	AccessValuesSets.ValueWithoutGroups,
	|	AccessValuesSets.StandardValue
	|INTO AccessValuesSets
	|FROM
	|	&AccessValuesSets AS AccessValuesSets
	|
	|INDEX BY
	|	AccessValuesSets.SetNumber,
	|	AccessValuesSets.AccessValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroups_Users.Ref AS Ref
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroups_Users
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.User = &AuthorizedUser)
	|			AND (UserGroupCompositions.UsersGroup = AccessGroups_Users.User)
	|			AND (UserGroupCompositions.Used)
	|			AND (NOT AccessGroups_Users.Ref.DeletionMark)
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON AccessGroups_Users.Ref.Profile = AccessGroupProfilesRoles.Ref
	|			AND (AccessGroupProfilesRoles.Role = &Role)
	|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sets.SetNumber
	|INTO SetsNumbers
	|FROM
	|	AccessValuesSets AS Sets
	|
	|INDEX BY
	|	Sets.SetNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	AccessGroups AS AccessGroups
	|WHERE
	|	NOT(TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						SetsNumbers AS SetsNumbers
	|					WHERE
	|						TRUE IN
	|							(SELECT TOP 1
	|								TRUE
	|							FROM
	|								AccessValuesSets AS ValueSets
	|							WHERE
	|								ValueSets.SetNumber = SetsNumbers.SetNumber
	|								AND NOT TRUE IN
	|										(SELECT TOP 1
	|											TRUE
	|										FROM
	|											InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|										WHERE
	|											DefaultValues.AccessGroup = AccessGroups.Ref
	|											AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|											AND DefaultValues.NoSettings = TRUE)))
	|				AND NOT TRUE IN
	|						(SELECT TOP 1
	|							TRUE
	|						FROM
	|							SetsNumbers AS SetsNumbers
	|						WHERE
	|							TRUE IN
	|								(SELECT TOP 1
	|									TRUE
	|								FROM
	|									AccessValuesSets AS ValueSets
	|								WHERE
	|									ValueSets.SetNumber = SetsNumbers.SetNumber
	|									AND NOT TRUE IN
	|											(SELECT TOP 1
	|												TRUE
	|											FROM
	|												InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|											WHERE
	|												DefaultValues.AccessGroup = AccessGroups.Ref
	|												AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|												AND DefaultValues.NoSettings = TRUE))
	|							AND NOT FALSE IN
	|									(SELECT TOP 1
	|										FALSE
	|									FROM
	|										AccessValuesSets AS ValueSets
	|									WHERE
	|										ValueSets.SetNumber = SetsNumbers.SetNumber
	|										AND NOT CASE
	|												WHEN ValueSets.ValueWithoutGroups
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|																	LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																	ON
	|																		Values.AccessGroup = AccessGroups.Ref
	|																			AND Values.AccessValue = ValueSets.AccessValue
	|															WHERE
	|																DefaultValues.AccessGroup = AccessGroups.Ref
	|																AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																AND ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|												WHEN ValueSets.StandardValue
	|													THEN CASE
	|															WHEN TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|																	WHERE
	|																		AccessValuesGroups.AccessValue = ValueSets.AccessValue
	|																		AND AccessValuesGroups.AccessValuesGroup = &AuthorizedUser)
	|																THEN TRUE
	|															ELSE TRUE IN
	|																	(SELECT TOP 1
	|																		TRUE
	|																	FROM
	|																		InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|																			INNER JOIN InformationRegister.AccessValuesGroups AS ValueGroups
	|																			ON
	|																				ValueGroups.AccessValue = ValueSets.AccessValue
	|																					AND DefaultValues.AccessGroup = AccessGroups.Ref
	|																					AND VALUETYPE(DefaultValues.AccessValuesType) = VALUETYPE(ValueSets.AccessValue)
	|																			LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|																			ON
	|																				Values.AccessGroup = AccessGroups.Ref
	|																					AND Values.AccessValue = ValueGroups.AccessValuesGroup
	|																	WHERE
	|																		ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))
	|														END
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|													THEN TRUE
	|												WHEN ValueSets.AccessValue = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|													THEN FALSE
	|												WHEN VALUETYPE(ValueSets.AccessValue) = TYPE(Catalog.MetadataObjectIDs)
	|													THEN TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.AccessGroupsTables AS AccessGroupsTablesObjectRightCheck
	|															WHERE
	|																AccessGroupsTablesObjectRightCheck.AccessGroup = AccessGroups.Ref
	|																AND AccessGroupsTablesObjectRightCheck.Table = ValueSets.AccessValue)
	|												ELSE TRUE IN
	|															(SELECT TOP 1
	|																TRUE
	|															FROM
	|																InformationRegister.ObjectsRightsSettings AS RightsSettings
	|																	INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																	ON
	|																		SettingsInheritance.Object = ValueSets.AccessValue
	|																			AND RightsSettings.Object = SettingsInheritance.Parent
	|																			AND SettingsInheritance.UsageLevel < RightsSettings.ReadingPermissionLevel
	|																	INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|																	ON
	|																		UserGroupCompositions.User = &AuthorizedUser
	|																			AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|														AND NOT FALSE IN
	|																(SELECT TOP 1
	|																	FALSE
	|																FROM
	|																	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|																		INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|																		ON
	|																			SettingsInheritance.Object = ValueSets.AccessValue
	|																				AND RightsSettings.Object = SettingsInheritance.Parent
	|																				AND SettingsInheritance.UsageLevel < RightsSettings.ReadingProhibitionLevel
	|																		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|																		ON
	|																			UserGroupCompositions.User = &AuthorizedUser
	|																				AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|											END)))";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Checks whether object right permissions are set for the user.
//  For example, you can set the RightsManagement, Read, and FoldersChange rights to a file folder,
// the Read right is both the right to the file folder and the right to the files.
//
// Parameters:
//  Right          - String - a right name as it is specified in the OnFillAvailableRightsForObjectsRightsSettings procedure
//                   of the AccessManagementOverridable common module.
//
//  ObjectReference - CatalogRef
//                 - ChartOfCharacteristicTypesRef - a reference to one of the right owners
//                   specified in the OnFillAvailableRightsForObjectsRightsSettings procedure
//                   of the AccessManagementOverridable common module, for example, a reference to a file folder.
//
//  User   - CatalogRef.Users
//                 - CatalogRef.ExternalUsers
//                 - Undefined - if the parameter is not specified,
//                     the right is checked for the current user.
//
// Returns:
//  Boolean - if True, the right permission is set up according to all allowed and
//           prohibited settings in the hierarchy.
//
Function HasRight(Right, ObjectReference, Val User = Undefined) Export
	
	ForPrivilegedMode = True;
	If ValueIsFilled(User) Then
		ForPrivilegedMode = False;
	Else
		User = Users.AuthorizedUser();
	EndIf;
	If Users.IsFullUser(User,, ForPrivilegedMode) Then
		Return True;
	EndIf;
	
	If Not LimitAccessAtRecordLevel()
	 Or AccessManagementInternalCached.IsUserWithUnlimitedAccess(User) Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	RightsDetails = AvailableRights.ByTypes.Get(TypeOf(ObjectReference));
	
	If RightsDetails = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Details about rights valid for table ""%1"" are missing.';"),
			ObjectReference.Metadata().FullName());
		Raise ErrorText;
	EndIf;
	
	RightDetails = RightsDetails.Get(Right);
	
	If RightDetails = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Details about right ""%1"" for table ""%2"" are missing.';"),
			Right, ObjectReference.Metadata().FullName());
		Raise ErrorText;
	EndIf;
	
	If Not ValueIsFilled(ObjectReference) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ObjectReference", ObjectReference);
	Query.SetParameter("User", User);
	Query.SetParameter("Right", Right);
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.ObjectsRightsSettings AS RightsSettings
	|					INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|					ON
	|						SettingsInheritance.Object = &ObjectReference
	|							AND RightsSettings.Right = &Right
	|							AND SettingsInheritance.UsageLevel < RightsSettings.RightPermissionLevel
	|							AND RightsSettings.Object = SettingsInheritance.Parent
	|					INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					ON
	|						UserGroupCompositions.User = &User
	|							AND UserGroupCompositions.UsersGroup = RightsSettings.User)
	|	AND NOT FALSE IN
	|				(SELECT TOP 1
	|					FALSE
	|				FROM
	|					InformationRegister.ObjectsRightsSettings AS RightsSettings
	|						INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|						ON
	|							SettingsInheritance.Object = &ObjectReference
	|								AND RightsSettings.Right = &Right
	|								AND SettingsInheritance.UsageLevel < RightsSettings.RightProhibitionLevel
	|								AND RightsSettings.Object = SettingsInheritance.Parent
	|						INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|						ON
	|							UserGroupCompositions.User = &User
	|								AND UserGroupCompositions.UsersGroup = RightsSettings.User)";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Checks whether the specified user is allowed
// to read an object from the database at the level of rights and record.
// When a record set is specified, the database records
// corresponding to the Filter property are checked.
//
// Warning: if the subsystem operates in standard restriction mode, and
// a user is specified, but not the current one,
// an exception will be raised (for checking, use the HighPerformanceMode function).
//
// Parameters:
//  DataDetails - CatalogRef
//                 - DocumentRef
//                 - ChartOfCharacteristicTypesRef
//                 - ChartOfAccountsRef
//                 - ChartOfCalculationTypesRef
//                 - BusinessProcessRef
//                 - TaskRef
//                 - ExchangePlanRef - a reference to the object to be checked.
//                 - InformationRegisterRecordKey
//                 - AccumulationRegisterRecordKey
//                 - AccountingRegisterRecordKey
//                 - CalculationRegisterRecordKey - a record key to be checked.
//                 - CatalogObject
//                 - DocumentObject
//                 - ChartOfCharacteristicTypesObject
//                 - ChartOfAccountsObject
//                 - ChartOfCalculationTypesObject
//                 - BusinessProcessObject
//                 - TaskObject
//                 - ExchangePlanObject - — the object in memory and database to be checked.
//                 - InformationRegisterRecordSet
//                 - AccumulationRegisterRecordSet
//                 - AccountingRegisterRecordSet
//                 - CalculationRegisterRecordSet - — a record set with the configured Filter property
//                     used to determine the database records to be checked.
//
//  User   - CatalogRef.Users
//                 - CatalogRef.ExternalUsers
//                 - Undefined - — a current user.
//                   When the parameter is specified, privileged mode is not considered.
//                   Checking the rights of a non-current user requires administrative rights.
//
// Returns:
//  Boolean
//
Function ReadingAllowed(DataDetails, User = Undefined) Export
	
	Return AccessManagementInternal.AccessAllowed(DataDetails, False,,, User);
	
EndFunction

// Checks whether the specified user is allowed
// to change an object in the database to an object in memory at the level of rights and record.
// For a new object, the object in memory is checked only.
// If a reference or a record key is specified, the object in the database is checked only.
//
// Warning: if the subsystem operates in standard restriction mode,
// and not in universal restriction mode,
// the Edit right to the table is checked; at the record level only the Read right is checked.
// If a user is specified, but not the current one,
// an exception will be raised (for checking, use the HighPerformanceMode function).
//
// Parameters:
//  DataDetails - CatalogRef
//                 - DocumentRef
//                 - ChartOfCharacteristicTypesRef
//                 - ChartOfAccountsRef
//                 - ChartOfCalculationTypesRef
//                 - BusinessProcessRef
//                 - TaskRef
//                 - ExchangePlanRef - — a reference to the object in the database to be checked.
//                 - InformationRegisterRecordKey
//                 - AccumulationRegisterRecordKey
//                 - AccountingRegisterRecordKey
//                 - CalculationRegisterRecordKey - — a record key in the database to be checked.
//                 - CatalogObject
//                 - DocumentObject
//                 - ChartOfCharacteristicTypesObject
//                 - ChartOfAccountsObject
//                 - ChartOfCalculationTypesObject
//                 - BusinessProcessObject
//                 - TaskObject
//                 - ExchangePlanObject - — the object in memory and database to be checked.
//                 - InformationRegisterRecordSet
//                 - AccumulationRegisterRecordSet
//                 - AccountingRegisterRecordSet
//                 - CalculationRegisterRecordSet - — the record set in memory and database
//                                                to be checked.
//
//  User   - CatalogRef.Users
//                 - CatalogRef.ExternalUsers
//                 - Undefined - — a current user.
//                   When the parameter is specified, privileged mode is not considered.
//                   Checking the rights of a non-current user requires administrative rights.
//
// Returns:
//  Boolean
//
Function EditionAllowed(DataDetails, User = Undefined) Export
	
	Return AccessManagementInternal.AccessAllowed(DataDetails, True,,, User);
	
EndFunction

// Same as the ReadingAllowed function but if not allowed an exception is raised.
// 
// Parameters:
//  DataDetails - See ReadingAllowed.DataDetails
//
Procedure CheckReadAllowed(DataDetails) Export
	
	AccessManagementInternal.AccessAllowed(DataDetails, False, True);
	
EndProcedure

// Same as the EditionAllowed function but if not allowed an exception is raised.
// 
// Parameters:
//  DataDetails - See EditionAllowed.DataDetails
//
Procedure CheckChangeAllowed(DataDetails) Export
	
	AccessManagementInternal.AccessAllowed(DataDetails, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures for including and excluding a user in access group profile.

// Assigning an access group profile to a user by including
// them in a personal access group (only for simplified setting of rights).
//
// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers - a required user.
//  Profile      - CatalogRef.AccessGroupProfiles - a profile, for which you need to find or create a personal
//                   access group and include a user in it.
//               - UUID - UUID of a built-in profile,
//                   using which you need to find an access group profile.
//               - String - a built-in profile name, 
//                   using which you need to find an access group profile.
//
Procedure EnableProfileForUser(User, Profile) Export
	EnableDisableUserProfile(User, Profile, True);
EndProcedure

// Canceling assignment of an access group profile to a user by excluding them
// from a personal access group (only for simplified setting of rights).
//
// Parameters:
//  User - CatalogRef.Users
//               - CatalogRef.ExternalUsers - a required user.
//  Profile      - CatalogRef.AccessGroupProfiles - a profile, for which you need to find or create a personal
//                    access group and include a user in it.
//               - UUID - UUID of a built-in profile,
//                    using which you need to find an access group profile.
//               - String - a built-in profile name,
//                    using which you need to find an access group profile.
//               - Undefined - disable all user profiles.
//
Procedure DisableUserProfile(User, Profile = Undefined) Export
	EnableDisableUserProfile(User, Profile, False);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to get common subsystem settings.

// Checks whether access restriction is used at the record level.
//
// Returns:
//  Boolean - if True, access is restricted at the record level.
//
Function LimitAccessAtRecordLevel() Export
	
	SetPrivilegedMode(True);
	SetSafeModeDisabled(True);
	
	Result = AccessManagementInternalCached.ConstantLimitAccessAtRecordLevel();
	
	SetSafeModeDisabled(False);
	SetPrivilegedMode(False);
	
	Return Result;
	
EndFunction

// Returns access restriction operation mode at the record level.
//
// It is required when using the extended
// ReadingAllowed and EditingAllowed functions in high-performance mode.
//
// Returns:
//  Boolean - — if False, the standard option, otherwise high-performance.
//
Function ProductiveOption() Export
	
	Return AccessManagementInternal.LimitAccessAtRecordLevelUniversally(False, True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for setting client application form interface.

// The OnReadAtServer form event handler, which is embedded into item forms of catalogs, documents, register records,
// and other objects to lock the form if data changes are denied.
//
// Parameters:
//  Form               - ClientApplicationForm - an item form of an object or a register record form.
//
//  CurrentObject       - CatalogObject
//                      - DocumentObject
//                      - ChartOfCharacteristicTypesObject
//                      - ChartOfAccountsObject
//                      - ChartOfCalculationTypesObject
//                      - BusinessProcessObject
//                      - TaskObject
//                      - ExchangePlanObject - Object being checked.
//                      - InformationRegisterRecordManager - The manager of the record being checked.
//                      - InformationRegisterRecordSet
//                      - AccumulationRegisterRecordSet
//                      - AccountingRegisterRecordSet
//                      - CalculationRegisterRecordSet - — the set of the records being checked.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	If AccessManagementInternal.AccessAllowed(CurrentObject, True, False, True) Then
		Return;
	EndIf;
	
	Form.ReadOnly = True;
	
EndProcedure

// The AfterWriteAtServer form event handler that is embedded in the forms
// of items of catalog, documents, register records and so on to speed up
// the access update start for dependent objects when the update is scheduled.
//
// Parameters:
//  Form           - ClientApplicationForm - an item form of an object or a register record form.
//
//  CurrentObject   - CatalogObject
//                  - DocumentObject
//                  - ChartOfCharacteristicTypesObject
//                  - ChartOfAccountsObject
//                  - ChartOfCalculationTypesObject
//                  - BusinessProcessObject
//                  - TaskObject
//                  - ExchangePlanObject - The object being checked.
//                  - InformationRegisterRecordManager - The manager of the record being checked.
//
//  WriteParameters - Structure - a standard parameter passed to the event handler.
//
Procedure AfterWriteAtServer(Form, CurrentObject, WriteParameters) Export
	
	AccessManagementInternal.StartAccessUpdate();
	
EndProcedure

// ACC:142-off #640.5 Optional parameters are more than 3 for backward compatibility.

// Configures a form of access value, which uses access value groups
// to select allowed values in user access groups.
//
// Supported only when a
// single access value group is selected for an access value.
//
// For the AccessGroup form item related to the AccessGroup attribute, it sets
// the access value group list to the selection parameter that provide access to change the access values.
//
// When creating a new access value, if the number of access value groups, which provide access
// to change the access value, is zero, an exception will be raised.
//
// If the database already contains an access value group that does not provide access to change the access value
// or the number of access value groups, which provide access to change the access values, is zero,
// the ViewOnly form parameter is set to True.
//
// If neither a restriction at the record level or restriction by access kind is used,
// the form item is hidden.
//
// Parameters:
//  Form - ClientApplicationForm - a form of an access value
//            that uses groups to select allowed values.
//
//  AdditionalParameters - See ParametersOnCreateAccessValueForm
//
//  DeleteItems       - Undefined - obsolete, use AdditionalParameters instead.
//  DeleteValueType    - Undefined - obsolete, use AdditionalParameters instead.
//  DeleteCreateNewAccessValue - Undefined - obsolete, use AdditionalParameters instead.
//
Procedure OnCreateAccessValueForm(Form, AdditionalParameters = Undefined,
			DeleteItems = Undefined, DeleteValueType = Undefined, DeleteCreateNewAccessValue = Undefined) Export
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		Attribute       = AdditionalParameters.Attribute;
		Items       = AdditionalParameters.Items;
		ValueType    = AdditionalParameters.ValueType;
		CreateNewAccessValue = AdditionalParameters.CreateNewAccessValue;
	Else
		Attribute       = AdditionalParameters;
		Items       = DeleteItems;
		ValueType    = DeleteValueType;
		CreateNewAccessValue = DeleteCreateNewAccessValue;
	EndIf;
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1
		           |of common module %2.';"),
		"OnCreateAccessValueForm",
		"AccessManagement");
	
	If TypeOf(CreateNewAccessValue) <> Type("Boolean") Then
		Try
			FormObject = Form.Object; // DefinedType.AccessValue - Object's actual "FormDataStructure".
			CreateNewAccessValue = Not ValueIsFilled(FormObject.Ref);
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameter ""%1"" is required. Automatic filling
				           |from form attribute ""%2"" is not available. Reason:
				           |%3';"),
				"CreateNewAccessValue",
				"Object.Ref",
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Raise ErrorText;
		EndTry;
	EndIf;
	
	If TypeOf(ValueType) <> Type("Type") Then
		Try
			FormObject = Form.Object; // DefinedType.AccessValue - 
			AccessValueType = TypeOf(FormObject.Ref);
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameter ""%1"" is required. Automatic filling
				           |from form attribute ""%2"" is not available. Reason:
				           |%3';"),
				"ValueType",
				"Object.Ref",
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Raise ErrorText;
		EndTry;
	Else
		AccessValueType = ValueType;
	EndIf;
	
	If Items = Undefined Then
		FormItems = New Array;
		FormItems.Add("AccessGroup");
		
	ElsIf TypeOf(Items) <> Type("Array") Then
		FormItems = New Array;
		FormItems.Add(Items);
	EndIf;
	
	GroupsProperties = AccessValueGroupsProperties(AccessValueType, ErrorTitle);
	
	If Attribute = Undefined Then
		Try
			AccessValuesGroup = Form.Object.AccessGroup;
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameter ""Attribute"" is required. Cannot populate is automatically
				           |form attribute ""%2"" due to:
				           |%3';"),
				"Attribute",
				"Object.AccessGroup",
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Raise ErrorText;
		EndTry;
	Else
		PointPosition = StrFind(Attribute, ".");
		If PointPosition = 0 Then
			Try
				AccessValuesGroup = Form[Attribute];
			Except
				ErrorInfo = ErrorInfo();
				ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t get the value of form attribute ""%1""
					           |specified in parameter ""%2"". Reason:
					           |%3';"),
					Attribute,
					"Attribute",
					ErrorProcessing.BriefErrorDescription(ErrorInfo));
				Raise ErrorText;
			EndTry;
		Else
			Try
				AccessValuesGroup = Form[Left(Attribute, PointPosition - 1)][Mid(Attribute, PointPosition + 1)];
			Except
				ErrorInfo = ErrorInfo();
				ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t get the value of form attribute ""%1""
					           |specified in parameter ""%2"". Reason:
					           |%3';"),
					Attribute,
					"Attribute",
					ErrorProcessing.BriefErrorDescription(ErrorInfo));
				Raise ErrorText;
			EndTry;
		EndIf;
	EndIf;
	
	If TypeOf(AccessValuesGroup) <> GroupsProperties.Type Then
		ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""%2"" access kind
			           |with ""%3"" value type
			           |specified in the overridable module is used for access values of ""%1"" type.
			           |This type does not match the ""%4"" type of the %5 attribute
			           |in the access value form.';"),
			String(AccessValueType),
			String(GroupsProperties.AccessKind),
			String(GroupsProperties.Type),
			String(TypeOf(AccessValuesGroup)),
			"AccessGroup");
		Raise ErrorText;
	EndIf;
	
	If Not AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind) Then
		For Each Item In FormItems Do
			Form.Items[Item].Visible = False;
		EndDo;
		Return;
	EndIf;
	
	If Users.IsFullUser( , , False) Then
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.FindByType(AccessValueType)) Then
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	ValuesGroupsForChange =
		AccessValuesGroupsAllowingAccessValuesChange(AccessValueType);
	
	If ValuesGroupsForChange.Count() = 0
	   And CreateNewAccessValue Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot add an item because this requires allowed ""%1"".';"),
			Metadata.FindByType(GroupsProperties.Type).Presentation());
		Raise ErrorText;
	EndIf;
	
	If ValuesGroupsForChange.Count() = 0
	 Or Not CreateNewAccessValue
	   And ValuesGroupsForChange.Find(AccessValuesGroup) = Undefined Then
		
		Form.ReadOnly = True;
		Return;
	EndIf;
	
	If CreateNewAccessValue
	   And Not ValueIsFilled(AccessValuesGroup)
	   And ValuesGroupsForChange.Count() = 1 Then
		
		If Attribute = Undefined Then
			Form.Object.AccessGroup = ValuesGroupsForChange[0];
		Else
			PointPosition = StrFind(Attribute, ".");
			If PointPosition = 0 Then
				Form[Attribute] = ValuesGroupsForChange[0];
			Else
				Form[Left(Attribute, PointPosition - 1)][Mid(Attribute, PointPosition + 1)] = ValuesGroupsForChange[0];
			EndIf;
		EndIf;
	EndIf;
	
	NewChoiceParameter = New ChoiceParameter(
		"Filter.Ref", New FixedArray(ValuesGroupsForChange));
	
	ChoiceParameters = New Array;
	ChoiceParameters.Add(NewChoiceParameter);
	
	For Each Item In FormItems Do
		Form.Items[Item].ChoiceParameters = New FixedArray(ChoiceParameters);
	EndDo;
	
EndProcedure

// ACC:142-on

// Details of the additional parameters used in the OnCreateAccessValueForm procedure.
// 
// Returns:
//  Structure:
//    * Attribute       - Undefined - Name of the Object.AccessGroup form attribute.
//                     - String - a form attribute name containing the access group.
//
//    * Items       - Undefined - the AccessGroup form item name.
//                     - String - Form item name.
//                     - Array - Form item names.
//
//    * ValueType    - Undefined - getting a type from the Object.Ref form attribute.
//                     - Type - an access value reference type.
//
//    * CreateNewAccessValue - Undefined - getting the NOT ValueFilled(Form.Object.Ref) value
//                       to determine whether a new access value is being created or not.
//                     - Boolean - the specified value is used.
//
Function ParametersOnCreateAccessValueForm() Export
	
	Return New Structure("Attribute, Items, ValueType, CreateNewAccessValue");
	
EndFunction

// Returns an array of access value groups allowing to change access values.
//
// Supported only when a single access value group is selected.
//
// Parameters:
//  AccessValuesType - Type - an access value reference type.
//  ReturnAll1      - Boolean - if True, when no restrictions are set
//                       , an array of all groups will be returned instead of Undefined.
//
// Returns:
//  Undefined - access values can be changed in all access value groups.
//  Array - an array of found access value groups.
//
Function AccessValuesGroupsAllowingAccessValuesChange(AccessValuesType, ReturnAll1 = False) Export
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1
		           |of common module %2.';"),
		"AccessValuesGroupsAllowingAccessValuesChange",
		"AccessManagement");
	
	GroupsProperties = AccessValueGroupsProperties(AccessValuesType, ErrorTitle);
	
	If Not AccessRight("Read", Metadata.FindByType(GroupsProperties.Type)) Then
		Return New Array;
	EndIf;
	
	If Not AccessManagementInternal.AccessKindUsed(GroupsProperties.AccessKind)
	 Or Users.IsFullUser( , , False) Then
		
		If ReturnAll1 Then
			Query = New Query;
			Query.Text =
			"SELECT ALLOWED
			|	AccessValuesGroups.Ref AS Ref
			|FROM
			|	&AccessValueGroupsTable AS AccessValuesGroups";
			Query.Text = StrReplace(
				Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
			
			Return Query.Execute().Unload().UnloadColumn("Ref");
		EndIf;
		
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("AccessValuesType",  GroupsProperties.ValueTypeBlankRef);
	
	Query.SetParameter("AccessValuesID",
		Common.MetadataObjectID(AccessValuesType));
	
	Query.Text =
	"SELECT
	|	AccessGroups.Ref
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|			WHERE
	|				AccessGroupsTables.Table = &AccessValuesID
	|				AND AccessGroupsTables.AccessGroup = AccessGroups.Ref
	|				AND AccessGroupsTables.RightUpdate = TRUE)
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|					INNER JOIN Catalog.AccessGroups.Users AS AccessGroups_Users
	|					ON
	|						UserGroupCompositions.Used
	|							AND UserGroupCompositions.User = &CurrentUser
	|							AND AccessGroups_Users.User = UserGroupCompositions.UsersGroup
	|							AND AccessGroups_Users.Ref = AccessGroups.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessValuesGroups.Ref AS Ref
	|INTO ValueGroups
	|FROM
	|	&AccessValueGroupsTable AS AccessValuesGroups
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				UserAccessGroups AS UserAccessGroups
	|					INNER JOIN InformationRegister.DefaultAccessGroupsValues AS DefaultValues
	|					ON
	|						DefaultValues.AccessGroup = UserAccessGroups.Ref
	|							AND DefaultValues.AccessValuesType = &AccessValuesType
	|					LEFT JOIN InformationRegister.AccessGroupsValues AS Values
	|					ON
	|						Values.AccessGroup = UserAccessGroups.Ref
	|							AND Values.AccessValue = AccessValuesGroups.Ref
	|			WHERE
	|				ISNULL(Values.ValueAllowed, DefaultValues.AllAllowed))";
	Query.Text = StrReplace(Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
	Query.TempTablesManager = New TempTablesManager;
	
	SetPrivilegedMode(True);
	Query.Execute();
	SetPrivilegedMode(False);
	
	Query.Text =
	"SELECT ALLOWED
	|	AccessValuesGroups.Ref AS Ref
	|FROM
	|	&AccessValueGroupsTable AS AccessValuesGroups
	|		INNER JOIN ValueGroups AS ValueGroups
	|		ON AccessValuesGroups.Ref = ValueGroups.Ref";
	
	Query.Text = StrReplace(
		Query.Text, "&AccessValueGroupsTable", GroupsProperties.Table);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Sets the condition WHERE of the dynamic list to permanent filters
// based on the allowed access values of the specified types within all access groups.
// This helps to speed up opening of the dynamic list.
// If the total number of allowed values is over 100, the filter is not set.
//
// For the procedure to operate, a dynamic list must have a main table,
// an arbitrary query, and it must support a conversion of this kind:
//   QuerySchema - New QuerySchema;
//   QuerySchema.SetQueryText(List.QueryText);
//   List.QueryText = QuerySchema.GetQueryText();
// If you cannot fulfill this condition, add the filters yourself
// using the AllowedDynamicListValues function as in this procedure.
//
// Parameters:
//  List          - DynamicList - a dynamic list that requires setting of filters.
//  FiltersDetails - Map of KeyAndValue:
//    * Key     - String - a field name of the main table of the dynamic list,
//                          which requires setting the <Field> value IN (&AllowedValues).
//    * Value - Type    - a type of access values to be included in the
//                          &AllowedValues parameter.
//               - Array - array of the types specified above.
//
Procedure SetDynamicListFilters(List, FiltersDetails) Export
	
	If Not LimitAccessAtRecordLevel()
	 Or AccessManagementInternal.LimitAccessAtRecordLevelUniversally(False, True)
	 Or Users.IsFullUser(,, False) Then
		Return;
	EndIf;
	
	If TypeOf(List) <> Type("DynamicList") Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error calling procedure ""%1"" of common module ""%2"".
			           |Value ""%4"" of parameter ""%3"" is not a dynamic list.';"),
			"SetDynamicListFilters",
			"AccessManagement",
			"List",
			String(List));
		Raise ErrorText;
	EndIf;
	
	If Not ValueIsFilled(List.MainTable) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error calling procedure ""%1"" of common module ""%2"".
			           |The main table of the dynamic list passed to the procedure is not specified.';"),
			"SetDynamicListFilters",
			"AccessManagement");
		Raise ErrorText;
	EndIf;
	
	If Not List.CustomQuery Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error calling procedure ""%1"" of common module ""%2"".
			           |The passed dynamic list is missing flag ""%3"".';"),
			"SetDynamicListFilters",
			"AccessManagement",
			"CustomQuery");
		Raise ErrorText;
	EndIf;
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(List.QueryText);
	Parameters = New Map;
	
	For Each FilterDetails In FiltersDetails Do
		FieldName = FilterDetails.Key;
		Values = AccessManagementInternal.AllowedDynamicListValues(
			List.MainTable, FilterDetails.Value);
		If Values = Undefined Then
			Continue;
		EndIf;
		
		Sources = QuerySchema.QueryBatch[0].Operators[0].Sources;
		Alias = "";
		For Each Source In Sources Do
			If Source.Source.TableName = List.MainTable Then
				Alias = Source.Source.Alias;
				Break;
			EndIf;
		EndDo;
		If Not ValueIsFilled(Alias) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error calling procedure ""%1"" of common module ""%2"".
				           |Cannot find the alias of the ""%1"" main table
				           |of the dynamic list passed to the procedure.';"),
				"SetDynamicListFilters",
				"AccessManagement",
				List.MainTable);
			Raise ErrorText;
		EndIf;
		Filter = QuerySchema.QueryBatch[0].Operators[0].Filter;
		ParameterName = "AllowedFieldValues" + FieldName;
		Parameters.Insert(ParameterName, Values);
		
		Condition = Alias + "." + FieldName + " IN (&" + ParameterName + ")";
		Filter.Add(Condition);
	EndDo;
	
	List.QueryText = QuerySchema.GetQueryText();
	
	For Each KeyAndValue In Parameters Do
		UpdateDataCompositionParameterValue(List, KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
EndProcedure

// Returns an array of allowed values of the specified types within all access groups.
// Used in the SetDynamicListFilters procedure to speed up the opening of dynamic lists.
// 
// Parameters:
//  Table      - String - a full name of the metadata object, for example, Document.PurchaseInvoice.
//  ValuesType  - Type    - a type of access values whose allowed values are to be returned.
//               - Array - array of the types specified above.
//  User - Undefined - return allowed values for the authorized user.
//               - CatalogRef.Users
//               - CatalogRef.ExternalUsers - return
//                   allowed values for the specified user.
//  ReturnAll   - Boolean - if set to True, all values will be returned, even
//                   if there are more than 100 values.
//
// Returns:
//  Undefined - either all values are allowed for the types specified in the ValuesType parameter,
//                 or (when ReturnAll = False) the number of the allowed values exceeds 100.
//  Array - references of allowed values of the specified types.
//
Function AllowedDynamicListValues(Table, ValuesType, User = Undefined, ReturnAll = False) Export
	
	If Not LimitAccessAtRecordLevel()
	 Or Users.IsFullUser(User, , False) Then
		Return Undefined;
	EndIf;
	
	Return AccessManagementInternal.AllowedDynamicListValues(Table, ValuesType, , User, ReturnAll);
	
EndFunction

// Returns access rights to metadata objects of reference type by specified IDs.
//
// Parameters:
//  IDs - Array - Values of the CatalogRef.MetadataObjectIDs,
//                            reference type metadata objects, for which rights are to be returned.
//
// Returns:
//  Map of KeyAndValue:
//    * Key     - CatalogRef.MetadataObjectIDs - Object ID.
//    * Value - Structure:
//        ** Key     - String - Name of the access right ("Read", "Update", "Insert").
//        ** Value - Boolean - if True, there is the right, otherwise, there is not.
//
Function RightsByIDs(IDs = Undefined) Export
	
	IDsMetadataObjects =
		Common.MetadataObjectsByIDs(IDs);
	
	RightsByIDs = New Map;
	For Each IDMetadataObject In IDsMetadataObjects Do
		MetadataObject = IDMetadataObject.Value;
		Rights = New Structure;
		Rights.Insert("Read",     AccessRight("Read",     MetadataObject));
		Rights.Insert("Update",  AccessRight("Update",  MetadataObject));
		Rights.Insert("Create", AccessRight("Insert", MetadataObject));
		RightsByIDs.Insert(IDMetadataObject.Key, Rights);
	EndDo;
	
	Return RightsByIDs;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for access value set management.

// Checks whether the procedure of filling in access value sets is provided for the metadata object.
// 
// Parameters:
//  Ref - AnyRef - a reference to any object.
//
// Returns:
//  Boolean - if True, you can fill in access value sets.
//
Function CanFillAccessValuesSets(Ref) Export
	
	ObjectType = Type(Common.ObjectKindByRef(Ref) + "Object." + Ref.Metadata().Name);
	
	SetsFilled = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets
		|WriteDependentAccessValuesSets").Get(ObjectType) <> Undefined;
	
	Return SetsFilled;
	
EndFunction

// Returns a blank table to be filled and passed to the HasRole function and
// to FillAccessValuesSets(Table) procedures defined by an applied developer.
//
// Returns:
//  ValueTable:
//    * SetNumber     - Number  - optional if there is only one set.
//    * AccessKind      - String - optional, except for special kinds: ReadRight and UpdateRight.
//    * AccessValue - DefinedType.AccessValue - an access value type specified for the access kind
//                        in the OnFillAccessKinds procedure of the AccessManagementOverridable common module.
//    * Read          - Boolean - optional if a set for all rights is only set for one line of the set.
//    * Update       - Boolean - optional if a set for all rights is only set for one line of the set.
//
Function AccessValuesSetsTable() Export
	
	SetPrivilegedMode(True);
	
	Table = New ValueTable;
	Table.Columns.Add("SetNumber",     New TypeDescription("Number", New NumberQualifiers(4, 0, AllowedSign.Nonnegative)));
	Table.Columns.Add("AccessKind",      New TypeDescription("String", , New StringQualifiers(20)));
	Table.Columns.Add("AccessValue", Metadata.DefinedTypes.AccessValue.Type);
	Table.Columns.Add("Read",          New TypeDescription("Boolean"));
	Table.Columns.Add("Update",       New TypeDescription("Boolean"));
	// Service field cannot be filled in or changed manually (it is filled in automatically).
	Table.Columns.Add("Refinement",       New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
	Return Table;
	
EndFunction

// 
// Populates access value sets for the passed Object value by calling
// the FillAccessValuesSets procedure defined in the module of this object,
//
// and returns them in the Table parameter.
// Objects are to be included in the event subscription WriteAccessValuesSets
//
// or WriteDependentAccessValuesSets.
//  In the object modules, place a handler procedure with the following parameters:
//
// Table - ValueTable - Returned by the AccessValuesSetsTable function.
//
//// See AccessManagement.FillAccessValuesSets.
//Here is an example of a handler procedure for copying to object modules.
//	
//	// 
//	Procedure FillAccessValuesSets(Table) Export
//	// Restriction logic:
//	
//	// Read: Organization.
//	// Update: Organization And EmployeeResponsible.
//	// Read: Set #1.
//	String = Table.Add();
//	String.SetNumber = 1;
//	
//	String.Read = True;
//	String.AccessValue = Organization;
//	// Update: Set #2.
//	String = Table.Add();
//	String.SetNumber = 2;
//	
//	String.Update = True;
//	String.AccessValue = Organization;
//	String = Table.Add();
//	
//String.SetNumber = 2;
// String.AccessValue = EmployeeResponsible;
// EndProcedure
//
// Parameters:
//  Object  - AnyRef
//          - DefinedType.AccessValuesSetsOwnerObject - a reference or an object
//            (catalog item, document, business process, task, chart of characteristic types, etc.),
//            for which you want to fill in access value sets.
//
//  Table - See AccessValuesSetsTable
//          - Undefined - returns prepared sets of access values in this parameter. 
//            If Undefined is passed, a new table of access value sets will be created and filled in.
//
//  SubordinateObjectRef - AnyRef - Intended for populating owner access value sets for the given subordinate object.
//            For details, see AccessManagementOverridable.OnFillAccessRightsDependencies.
//            
//
Procedure FillAccessValuesSets(Val Object, Table, Val SubordinateObjectRef = Undefined) Export
	
	SetPrivilegedMode(True);
	
	// Get the object if a Ref is passed.
	// The object is not modified. It is used to call "FillAccessValuesSets".
	Object = ?(Object = Object.Ref, Object.GetObject(), Object);
	ObjectReference = Object.Ref;
	ValueTypeObject = TypeOf(Object);
	
	SetsFilled = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets
		|WriteDependentAccessValuesSets").Get(ValueTypeObject) <> Undefined;
	
	If Not SetsFilled Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid parameters.
			           |Cannot find object type ""%1""
			           |in event subscriptions %2, %3.';"),
			ValueTypeObject,
			"WriteAccessValuesSets",
			"WriteDependentAccessValuesSets");
		Raise ErrorText;
	EndIf;
	
	Table = ?(TypeOf(Table) = Type("ValueTable"), Table, AccessValuesSetsTable());
	Try
		Object.FillAccessValuesSets(Table);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 ""%2""
			           |has not generated an access value set. Reason:
			           |%3';"),
			TypeOf(ObjectReference),
			Object,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		Raise ErrorText;
	EndTry;
	
	If Table.Count() = 0 Then
		// If this condition is disabled, the scheduled job that populates data
		// for access restriction will get stuck in a loop.
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 ""%2""
			           |generated a blank access value set.';"),
			TypeOf(ObjectReference),
			Object);
		Raise ErrorText;
	EndIf;
	
	SpecifyAccessValuesSets(ObjectReference, Table);
	
	If SubordinateObjectRef = Undefined Then
		Return;
	EndIf;
	
	// Add sets to check the "Read" and "Update" rights on the main owner object
	// when generating child value sets in procedures prepared by the developer.
	// This doesn't apply to cases where the end-set is being filled, even if it has child sets.
	//
	// The reason is that standard templates have access right checks embedded into the "Object" access logic.
	// 
	
	// Adding a blank set to set all rights check boxes and arrange set rows.
	AddAccessValuesSets(Table, AccessValuesSetsTable());
	
	// Preparing object sets for some rights.
	ReadingSets     = AccessValuesSetsTable();
	ChangeSets  = AccessValuesSetsTable();
	For Each String In Table Do
		If String.Read Then
			NewRow = ReadingSets.Add();
			NewRow.SetNumber     = String.SetNumber + 1;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Refinement       = String.Refinement;
		EndIf;
		If String.Update Then
			NewRow = ChangeSets.Add();
			NewRow.SetNumber     = (String.SetNumber + 1)*2;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Refinement       = String.Refinement;
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessRightsDependencies AS AccessRightsDependencies
	|WHERE
	|	AccessRightsDependencies.SubordinateTable = &SubordinateTable
	|	AND AccessRightsDependencies.LeadingTableType = &LeadingTableType";
	
	Query.SetParameter("SubordinateTable", Common.MetadataObjectID(
		SubordinateObjectRef.Metadata().FullName()));
	
	TypesArray = New Array;
	TypesArray.Add(TypeOf(ObjectReference));
	TypeDescription = New TypeDescription(TypesArray);
	Query.SetParameter("LeadingTableType", TypeDescription.AdjustValue(Undefined));
	
	RightsDependencies = Query.Execute().Unload();
	Table.Clear();
	
	Id = Common.MetadataObjectID(TypeOf(ObjectReference));
	
	If RightsDependencies.Count() = 0 Then
		
		// Adding sets by a standard rule.
		
		// Check if the user has the "Read" right on the set's parent object when
		// checking the "Read" right on a child object.
		String = Table.Add();
		String.SetNumber     = 1;
		String.AccessKind      = "ReadRight1";
		String.AccessValue = Id;
		String.Read          = True;
		
		// Check if the user has the "Update" right on the set's parent object when
		// checking the "Insert", "Update" and "Delete" rights on a child object.
		String = Table.Add();
		String.SetNumber     = 2;
		String.AccessKind      = "EditRight";
		String.AccessValue = Id;
		String.Update       = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object.
		ReadingSets.FillValues(True, "Read");
		// Marking the rights that require checking the update right restriction sets for the leading owner object.
		ChangeSets.FillValues(True, "Update");
		
		AddAccessValuesSets(ReadingSets, ChangeSets);
		AddAccessValuesSets(Table, ReadingSets, True);
	Else
		// Adding sets by a nonstandard rule: check the read rights instead of update rights.
		
		// Check if the user has the "Read" right on the set's parent object when
		// checking the "Read" right on a child object.
		String = Table.Add();
		String.SetNumber     = 1;
		String.AccessKind      = "ReadRight1";
		String.AccessValue = Id;
		String.Read          = True;
		String.Update       = True;
		
		// Marking the rights that require checking the read right restriction sets for the leading owner object.
		ReadingSets.FillValues(True, "Read");
		ReadingSets.FillValues(True, "Update");
		AddAccessValuesSets(Table, ReadingSets, True);
	EndIf;
	
EndProcedure

// Adds an access value set table to another access value set
// table, either by logical addition or by logical multiplication.
//
// The result is returned in the Destination parameter.
//
// Parameters:
//  Receiver - ValueTable - with columns identical to the table returned by the AccessValuesSetsTable function.
//  Source - ValueTable - with columns identical to the table returned by the AccessValuesSetsTable function.
//
//  Multiplication - Boolean - determines a method to logically join sets of destination and source.
//  Simplify - Boolean - determines whether the sets must be simplified after addition.
//
Procedure AddAccessValuesSets(Receiver, Val Source, Val Multiplication = False, Val Simplify = False) Export
	
	If Source.Count() = 0 And Receiver.Count() = 0 Then
		Return;
		
	ElsIf Multiplication And ( Source.Count() = 0 Or  Receiver.Count() = 0 ) Then
		Receiver.Clear();
		Source.Clear();
		Return;
	EndIf;
	
	If Receiver.Count() = 0 Then
		Value = Receiver;
		Receiver = Source;
		Source = Value;
	EndIf;
	
	If Simplify Then
		
		// Determine duplicates of sets and their rows within access rights caused by additions and multiplications.
		// Duplication happens due to removed parentheses in logical expressions:
		//
		// For sets within a right and sets that belong to different rights:
		//  X AND X = X,
		//     X OR X = X, where X is a set or argument rows.
		//     Only for sets within an access right:
		//  (a AND b AND c) OR (a AND b) = (a AND b), where a, b, c are set rows.
		//     Based on these rules, you can delete duplicate rights within a set and duplicate sets.
		// 
		
		If Multiplication Then
			MultiplySetsAndSimplify(Receiver, Source);
		Else // Add.
			AddSetsAndSimplify(Receiver, Source);
		EndIf;
	Else
		
		If Multiplication Then
			MultiplySets(Receiver, Source);
		Else // Add.
			AddSets(Receiver, Source);
		EndIf;
	EndIf;
	
EndProcedure

// Updates object access value sets if they are changed.
// The sets are updated both in the tabular section (if used) and
// in the AccessValuesSets information register.
//
// Parameters:
//  ReferenceOrObject - AnyRef
//                  - DefinedType.AccessValuesSetsOwnerObject - a reference or an object,
//                    for which access value sets are populated.
//  
//  IBUpdate    - Boolean - if True, write data 
//                             without performing unnecessary and redundant actions with the data.
//                             See InfobaseUpdate.WriteData.
//
Procedure UpdateAccessValuesSets(ReferenceOrObject, IBUpdate = False) Export
	
	AccessManagementInternal.UpdateAccessValuesSets(ReferenceOrObject,, IBUpdate);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used in the overridable module.

// Returns a structure used for easier description of built-in profiles.
//
// Returns:
//  Structure:
//   * Name           - String - can be used in the API,
//                        for example in the EnableProfileForUser procedure.
//   * Parent      - String - the name of a profile folder that contains the profile.
//   * Id - String - a UUID string of the built-in
//                       profile used to search in the database.
//                       To receive the ID, create a profile in 1C:Enterprise mode and
//                       get the reference UUID.Do not specify IDs
//                       received using an arbitrary method as this may violate the uniqueness of the references.
//   * Description  - String - a built-in profile description.
//   * LongDesc      - String - a built-in profile details.
//   * Roles          - Array of String - names of the built-in profile roles.
//   * Purpose    - Array of Type - Types of user references and external
//                       user authorization objects. If empty, then it is intended for users.
//                       They must be part of the User type collection.
//   * AccessKinds   - ValueList:
//                     ** Value      - String - Access kind name specified in procedure
//                          OnFillAccessKinds of overridable module AccessManagementOverridable.
//                     ** Presentation - String - a predefined item name, for example,
//                          "Catalog.UserGroups.AllUsers".
//
//   * AccessValues - ValueList:
//                     ** Value      - String - Name of the access kind passed in the "AccessKinds" parameter.
//                     ** Presentation - String - Name of a predefined item.
//                          For example, "Catalog.UserGroups.AllUsers".
//
//   * Is_Directory - Boolean - Always set to "False". Must not be modified.
//
// Example:
// 
//	// User profile.
//	ProfileDetails = AccessManagement.NewAccessGroupProfileDetails(),
//	ProfileDetails.Name = User;
//	ProfileDetails.ID = 09e56dbf-90a0-11de-862c-001d600d9ad2;
//	ProfileDetails.Description = NStr("en = 'User'", Common.DefaultLanguageCode());
//	// Redefining an assignment.
//	CommonClientServer.SupplementArray(ProfileDetails.Assignment,
//		Metadata.DefinedTypes.ExternalUser.Type.Types());
//	ProfileDetails.Details =
//		NStr("en = 'Common actions allowed for most users.
//		           |As a rule, these are rights to view the infobase data.'");
//	// Using 1C: Enterprise.
//	ProfileDetails.Roles.Add("StartThinClient");
//	ProfileDetails.Roles.Add("OutputToPrinterFileClipboard");
//	ProfileDetails.Roles.Add("SaveUserData");
//	// …
//	// Using the application.
//	ProfileDetails.Roles.Add("BasicAccessSSL");
//	ProfileDetails.Roles.Add("ViewApplicationChangeLog");
//	ProfileDetails.Roles.Add("EditCurrentUser");
//	// …
//	// Using master data.
//	ProfileDetails.Roles.Add("ReadBasicMasterData");
//	ProfileDetails.Roles.Add("ReadCommonBasicMasterData");
//	// …
//	// Standard features.
//	ProfileDetails.Roles.Add("AddEditPersonalReportsOptions");
//	ProfileDetails.Roles.Add("ViewRelatedDocuments");
//	// …
//	// Basic profile features.
//	ProfileDetails.Roles.Add("AddEditNotes");
//	ProfileDetails.Roles.Add("AddEditNotifications");
//	ProfileDetails.Roles.Add("AddEditJobs");
//	ProfileDetails.Roles.Add("EditCompleteTask");
//	// …
//	// Profile access restriction kinds.
//	ProfileDetails.AccessKinds.Add("Companies");
//	ProfileDetails.AccessKinds.Add("Users", "Preset");
//	ProfileDetails.AccessKinds.Add("BusinessTransactions", "Preset");
//	ProfileDetails.AccessValues.Add("BusinessTransactions",
//		"Enumeration.BusinessTransactions.IssueCashToAdvanceHolder");
//	/ …
//	ProfilesDetails.Add(ProfileDetails);
//
Function NewAccessGroupProfileDescription() Export
	
	NewDetails = New Structure;
	NewDetails.Insert("Name",             "");
	NewDetails.Insert("Parent",        "");
	NewDetails.Insert("Id",   "");
	NewDetails.Insert("Description",    "");
	NewDetails.Insert("LongDesc",        "");
	NewDetails.Insert("Roles",            New Array);
	NewDetails.Insert("Purpose",      New Array);
	NewDetails.Insert("AccessKinds",     New ValueList);
	NewDetails.Insert("AccessValues", New ValueList);
	NewDetails.Insert("Is_Directory",        False);
	
	Return NewDetails;
	
EndFunction

// Returns a structure used for easier description of the built-in profile folders (item groups).
//
// Returns:
//  Structure:
//   * Name           - String - used in the Parent field for profile and profile folders.
//   * Parent      - String - the name of another profile folder that contains this folder.
//   * Id - String - the string of the built-in profile folder UUID
//                       which is used for searching in the database.
//                       To receive an ID, you need to create a profile folder in 1C:Enterprise mode
//                       and to get a reference UUID. Do not specify IDs
//                       received using an arbitrary method as this might violate the uniqueness of the references.
//   * Description  - String - a built-in profile folder description.
//   * Is_Directory      - Boolean - Always set to "True". Must not be modified.
//
// Example:
//	// The "Additional profiles" profile folder.
//	FolderDetails = AccessManagement.NewAccessGroupsProfilesFolderDetails();
//	FolderDetails.Name = "Additional profiles";
//	FolderDetails.ID = "";
//	FolderDetails.Description = NStr("en = 'Additional profiles'", Common.DefaultLanguageCode());
//	//…
//	ProfilesDetails.Add(ProfileDetails);
//
Function NewDescriptionOfTheAccessGroupProfilesFolder() Export
	
	NewDetails = New Structure;
	NewDetails.Insert("Name",           "");
	NewDetails.Insert("Parent",      "");
	NewDetails.Insert("Id", "");
	NewDetails.Insert("Description",  "");
	NewDetails.Insert("Is_Directory",      True);
	
	Return NewDetails;
	
EndFunction

// Adds additional types to the OnFillAccessKinds procedure
// of the AccessManagementOverridable common module.
//
// Parameters:
//  AccessKind             - ValueTableRow - added to the AccessKinds parameter.
//  ValuesType            - Type - an additional type of access values.
//  ValuesGroupsType       - Type - an additional access value group type, it can match
//                           the type of the previously specified value groups for the same access kind.
//  MultipleValuesGroups - Boolean - - True if you can specify multiple value groups
//                           for an additional access value type (the AccessGroups tabular section exists).
// 
Procedure AddExtraAccessKindTypes(AccessKind, ValuesType,
		ValuesGroupsType = Undefined, MultipleValuesGroups = False) Export
	
	AdditionalTypes = AccessKind.AdditionalTypes; // See AccessManagementInternal.NewAdditionalAccessKindTypesTable
	
	If AdditionalTypes.Columns.Count() = 0 Then
		AdditionalTypes = AccessManagementInternal.NewAdditionalAccessKindTypesTable();
		AccessKind.AdditionalTypes = AdditionalTypes;
	EndIf;
	
	AdditionalTypes = AccessKind.AdditionalTypes;
	
	NewRow = AdditionalTypes.Add();
	NewRow.ValuesType            = ValuesType;
	NewRow.ValuesGroupsType       = ValuesGroupsType;
	NewRow.MultipleValuesGroups = MultipleValuesGroups;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used for infobase update.

// Replaces roles in profiles, except for built-in profiles updated automatically.
// It is called from the exclusive update handler.
//
// Parameters:
//  RolesToReplace - Map of KeyAndValue:
//    * Key     - String - a name of the role to be replaced, for example, ReadBasicMasterData. If the role is deleted,
//                          add the prefix "?" to the name, for example, "? ReadBasicMasterData".
//
//    * Value - Array - names of roles for replacing the specified one (an empty array, in order to delete the specified role,
//                          you can specify the role to be replaced, for example, when divided it into several).
//
Procedure ReplaceRolesInProfiles(RolesToReplace) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"AccessManagement.ReplaceRolesInProfiles");
	
	RolesRefsToReplace = New Map;
	RolesToReplaceArray = New Array;
	
	For Each KeyAndValue In RolesToReplace Do
		If StrStartsWith(KeyAndValue.Key, "? ") Then
			RoleRefs = Catalogs.MetadataObjectIDs.DeletedMetadataObjectID(
				"Role." + TrimAll(Mid(KeyAndValue.Key, 3)));
		Else
			RoleRefs = New Array;
			RoleRefs.Add(Common.MetadataObjectID("Role." + KeyAndValue.Key));
		EndIf;
		For Each RoleRef1 In RoleRefs Do
			RolesToReplaceArray.Add(RoleRef1);
			NewRoles = New Array;
			RolesRefsToReplace.Insert(RoleRef1, NewRoles);
			For Each NewRole In KeyAndValue.Value Do
				NewRoles.Add(Common.MetadataObjectID("Role." + NewRole));
			EndDo;
		EndDo;
	EndDo;
	
	// Find profiles that use the roles being replaced.
	Query = New Query;
	Query.SetParameter("RolesToReplaceArray", RolesToReplaceArray);
	Query.SetParameter("BlankID",
		CommonClientServer.BlankUUID());
	
	Query.Text =
	"SELECT
	|	ProfilesRoles.Ref AS Profile,
	|	ProfilesRoles.Role AS Role
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|		ON (ProfilesRoles.Ref = Profiles.Ref)
	|			AND (ProfilesRoles.Role IN (&RolesToReplaceArray))
	|			AND (Profiles.SuppliedDataID = &BlankID
	|				OR Profiles.SuppliedProfileChanged)
	|TOTALS BY
	|	Profile";
	
	ProfilesTree = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroupProfiles");
	
	For Each ProfileRow In ProfilesTree.Rows Do
		LockItem.SetValue("Ref", ProfileRow.Profile);
		BeginTransaction();
		Try
			Block.Lock();
			ProfileObject = ProfileRow.Profile.GetObject();
			ProfileRoles = ProfileObject.Roles;
		
			For Each RoleRow In ProfileRow.Rows Do
				
				// Deleting the role being replaced from the profile.
				Filter = New Structure("Role", RoleRow.Role);
				FoundRows = ProfileRoles.FindRows(Filter);
				For Each FoundRow In FoundRows Do
					ProfileRoles.Delete(FoundRow);
				EndDo;
				
				// Adding new roles to the profile instead of the role being replaced.
				RolesToAdd = RolesRefsToReplace.Get(RoleRow.Role);
				
				For Each RoleToAdd In RolesToAdd Do
					Filter = New Structure;
					Filter.Insert("Role", RoleToAdd);
					If ProfileRoles.FindRows(Filter).Count() = 0 Then
						NewRow = ProfileRoles.Add();
						NewRow.Role = RoleToAdd;
					EndIf;
				EndDo;
			EndDo;
			
			InfobaseUpdate.WriteData(ProfileObject);
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	Catalogs.AccessGroupProfiles.UpdateAuxiliaryProfilesData(
		ProfilesTree.Rows.UnloadColumn("Profile"));
	
EndProcedure

// Returns a reference to the built-in profile or profile folder by ID.
//
// Parameters:
//  Id - String - Name or UUID of a built-in profile or profile folder.
//                  In the same form as specified in the OnFillSuppliedAccessGroupProfiles procedure of the AccessManagementOverridable common module.
//                  
//
// Returns:
//  CatalogRef.AccessGroupProfiles - If the built-in profile or profile folder is found in the catalog.
//  Undefined - If the built-in profile or profile folder does not exist in the catalog.
//
Function SuppliedProfileByID(Id) Export
	
	Return Catalogs.AccessGroupProfiles.SuppliedProfileByID(Id);
	
EndFunction

// Returns the reference to the standard built-in Administrator profile.
//
// Returns:
//  CatalogRef.AccessGroupProfiles
//
Function ProfileAdministrator() Export
	
	Return AccessManagementInternalCached.ProfileAdministrator();
	
EndFunction

// Returns the reference to the standard built-in Administrators access group.
//
// Returns:
//  CatalogRef.AccessGroups
//
Function AdministratorsAccessGroup() Export
	
	Return AccessManagementInternalCached.AdministratorsAccessGroup();
	
EndFunction

// Returns a blank table to be filled in and
// passed to the ReplaceRightsInObjectsRightsSettings procedure.
//
// Returns:
//  ValueTable:
//    * OwnersType - DefinedType.RightsSettingsOwner - a blank reference of the rights owner type,
//                      for example a blank reference of the FilesFolders catalog.
//    * OldName     - String - a previous right name.
//    * NewName      - String - a new right name.
//
Function TableOfRightsReplacementInObjectsRightsSettings() Export
	
	Dimensions = Metadata.InformationRegisters.ObjectsRightsSettings.Dimensions;
	
	Table = New ValueTable;
	Table.Columns.Add("OwnersType", Dimensions.Object.Type);
	Table.Columns.Add("OldName",     Dimensions.Right.Type);
	Table.Columns.Add("NewName",      Dimensions.Right.Type);
	
	Return Table;
	
EndFunction

// Replaces rights used in the object rights settings.
// After the replacement, service data is updated in
// the ObjectsRightsSettings information register, so the procedure is to be called
// only once to avoid performance decrease.
// 
// Parameters:
//  RenamedTable - ValueTable:
//    * OwnersType - DefinedType.RightsSettingsOwner - a blank reference of the rights owner type,
//                      for example a blank reference of the FilesFolders catalog.
//    * OldName     - String - a previous right name related to the specified owner type.
//    * NewName      - String - a new right name related to the specified owner type.
//                      If a blank string is specified, the old right setting will be deleted.
//                      If two new names are mapped to the previous name,
//                      the previous right setting will be duplicated.
//  
Procedure ReplaceRightsInObjectsRightsSettings(RenamedTable) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"AccessManagement.ReplaceRightsInObjectsRightsSettings");
	
	// ACC:96-off - No.434. Using JOIN is acceptable as the rows should be unique and
	// this is a one-time operation in an update handler.
	Query = New Query;
	Query.Parameters.Insert("RenamedTable", RenamedTable);
	Query.Text =
	"SELECT
	|	RenamedTable.OwnersType,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName
	|INTO RenamedTable
	|FROM
	|	&RenamedTable AS RenamedTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right,
	|	MAX(RightsSettings.RightIsProhibited) AS RightIsProhibited,
	|	MAX(RightsSettings.InheritanceIsAllowed) AS InheritanceIsAllowed,
	|	MAX(RightsSettings.SettingsOrder) AS SettingsOrder
	|INTO OldRightsSettings
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.Right
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OldRightsSettings.Object,
	|	OldRightsSettings.User,
	|	RenamedTable.OldName,
	|	RenamedTable.NewName,
	|	OldRightsSettings.RightIsProhibited,
	|	OldRightsSettings.InheritanceIsAllowed,
	|	OldRightsSettings.SettingsOrder
	|INTO RightsSettings
	|FROM
	|	OldRightsSettings AS OldRightsSettings
	|		INNER JOIN RenamedTable AS RenamedTable
	|		ON (VALUETYPE(OldRightsSettings.Object) = VALUETYPE(RenamedTable.OwnersType))
	|			AND OldRightsSettings.Right = RenamedTable.OldName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.NewName
	|
	|HAVING
	|	RightsSettings.NewName <> """" AND
	|	COUNT(RightsSettings.NewName) > 1
	|
	|UNION
	|
	|SELECT
	|	RightsSettings.NewName
	|FROM
	|	RightsSettings AS RightsSettings
	|		LEFT JOIN OldRightsSettings AS OldRightsSettings
	|		ON RightsSettings.Object = OldRightsSettings.Object
	|			AND RightsSettings.User = OldRightsSettings.User
	|			AND RightsSettings.NewName = OldRightsSettings.Right
	|WHERE
	|	NOT OldRightsSettings.Right IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	RightsSettings.OldName,
	|	RightsSettings.NewName,
	|	RightsSettings.RightIsProhibited,
	|	RightsSettings.InheritanceIsAllowed,
	|	RightsSettings.SettingsOrder
	|FROM
	|	RightsSettings AS RightsSettings";
	// ACC:96-on
	
	Block = New DataLock;
	Block.Add("InformationRegister.ObjectsRightsSettings");
	
	BeginTransaction();
	Try
		Block.Lock();
		QueryResults = Query.ExecuteBatch();
		
		RepeatedNewNames = QueryResults[QueryResults.Count()-2].Unload();
		
		If RepeatedNewNames.Count() > 0 Then
			RepeatedNewRightsNames = "";
			For Each String In RepeatedNewNames Do
				RepeatedNewRightsNames = RepeatedNewRightsNames
					+ ?(ValueIsFilled(RepeatedNewRightsNames), "," + Chars.LF, "")
					+ String.NewName;
			EndDo;
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error in procedure ""%1""
				           |of common module ""%2""..
				           |
				           |After the update, the following new access right names will have identical settings:
				           |%1.';"),
				"ReplaceRightsInObjectsRightsSettings",
				"AccessManagement",
				RepeatedNewRightsNames);
			Raise ErrorText;
		EndIf;
		
		ReplacementTable1 = QueryResults[QueryResults.Count()-1].Unload();
		
		RecordSet = InformationRegisters.ObjectsRightsSettings.CreateRecordSet();
		
		IBUpdate = InfobaseUpdate.InfobaseUpdateInProgress()
		           Or InfobaseUpdate.IsCallFromUpdateHandler();
		
		For Each String In ReplacementTable1 Do
			RecordSet.Filter.Object.Set(String.Object);
			RecordSet.Filter.User.Set(String.User);
			RecordSet.Filter.Right.Set(String.OldName);
			RecordSet.Read();
			If RecordSet.Count() > 0 Then
				RecordSet.Clear();
				If IBUpdate Then
					InfobaseUpdate.WriteData(RecordSet);
				Else
					RecordSet.Write();
				EndIf;
			EndIf;
		EndDo;
		
		NewRecord = RecordSet.Add();
		For Each String In ReplacementTable1 Do
			If String.NewName = "" Then
				Continue;
			EndIf;
			RecordSet.Filter.Object.Set(String.Object);
			RecordSet.Filter.User.Set(String.User);
			RecordSet.Filter.Right.Set(String.NewName);
			FillPropertyValues(NewRecord, String);
			NewRecord.Right = String.NewName;
			If IBUpdate Then
				InfobaseUpdate.WriteData(RecordSet);
			Else
				RecordSet.Write();
			EndIf;
		EndDo;
		
		InformationRegisters.ObjectsRightsSettings.UpdateAuxiliaryRegisterData();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions used to update internal data.

// Updates a role list of infobase users by their current
// access groups. Infobase users with the FullAccess role are skipped.
// 
// Parameters:
//  UsersArray - Array
//                      - Undefined
//                      - Type - an array
//     of the CatalogRef.Users or CatalogRef.ExternalUsers items.
//     If Undefined, update all user roles.
//     If Type = Catalog.ExternalUsers, all external user roles are updated,
//     otherwise, all user roles are updated.
//
//  ServiceUserPassword - String - Password to sign in the Service Manager.
//
Procedure UpdateUserRoles(Val UsersArray = Undefined, Val ServiceUserPassword = Undefined) Export
	
	AccessManagementInternal.UpdateUserRoles(UsersArray, ServiceUserPassword);
	
EndProcedure

// Updates the AccessGroupsValues and DefaultAccessGroupsValues registers
// that are filled in on the basis of the access group settings and access kind use.
//
Procedure UpdateAllowedValuesOnChangeAccessKindsUsage() Export
	
	InformationRegisters.UsedAccessKinds.UpdateRegisterData();
	
EndProcedure

// Sequentially fills in and partially updates data required by the AccessManagement
// subsystem in access restriction mode at the record level.
// 
// Fills in access value sets when the access restriction mode is enabled
// at the record level. The sets are filled in by portions during each run, until all
// access value sets are filled in.
//
// When the restriction access mode at the record level is disabled, the access value sets
// filled in earlier are removed upon rewriting the objects, not immediately.
//
// Updates secondary data
// (access value groups and additional fields in the existing access value sets) regardless of the access restriction mode at the record level.
// Disables the scheduled job after all updates are completed and data is filled.
//
// The progress information is written to the event log.
// The procedure can be called from the application, for example, when updating the infobase.
//
// Parameters:
//  DataVolume - Number - a return value. Contains the number of data objects 
//                             that were filled.
//
Procedure DataFillingForAccessRestriction(DataVolume = 0) Export
	
	AccessManagementInternal.DataFillingForAccessRestriction(DataVolume);
	
EndProcedure

// To speed up batch processing in the current session (full-access user),
// it toggles the calculation of rights when recording an object or a record set
// (update of access keys to objects and register records, as well as the rights
//  to access groups, users, and external users to new access keys).
//
// Use cases:
// - When restoring from XML backup.
// - When bulk importing from a file.
// - When bulk importing during data exchange.
// - During bulk object modification.
//
// Parameters:
//  Disconnect - Boolean - True - disables the update of access keys and enables the mode
//                         of collecting components of tables (lists), for which access keys will be
//                         updated while continuing update of access keys.
//                       False - schedules update of the table access keys collected in the disable
//                         mode and enables the standard mode of access keys update.
//
//  ScheduleUpdate1 - Boolean - scheduling an update when disabling and continuing.
//                            When Disable = True, determines whether to collect
//                              the table components, for which an update will be scheduled.
//                              False - it is only required in the import mode from the XML backup when
//                              all the infobase data is imported, including all service data.
//                            When Disable = False, it determines whether an
//                              update for the collected tables are to be scheduled.
//                              False is required in the processing of an exception after a transaction is canceled
//                              if there is an external transaction, since any record
//                              to the database in this state will result in an error, and besides,
//                              there is no need to schedule an update after canceling the transaction.
// Example:
//
//  Option 1. Recording an object set out of a transaction (TransactionActive() = False).
//
//	AccessManagement.DisableAccessKeysUpdate(True);
//	Try
//		// Recording a set of objects.
//		// …
//		AccessManagement.DisableAccessKeysUpdate(False);
//	Except
//		AccessManagement.DisableAccessKeysUpdate(False);
//		//…
//		RaiseException
//	EndTry;
//
//  Option 2. Recording an object set in the transaction (TransactionActive() = True).
//
//	AccessManagement.DisableAccessKeysUpdate(True);
//	StartTransaction();
//	Try
//		DataLock.Lock();
//		// …
//		// Recording a set of objects.
//		// …
//		AccessManagement.DisableAccessKeysUpdate(False);
//		CommitTransaction();
//	Except
//		CancelTransaction();
//		AccessManagement.DisableAccessKeysUpdate(False, False);
//		//…
//		RaiseException;
//	EndTry;
//
Procedure DisableAccessKeysUpdate(Disconnect, ScheduleUpdate1 = True) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	UsersInternal.CheckSafeModeIsDisabled(
		"AccessManagement.DisableAccessKeysUpdate");
	
	If Disconnect And Not Users.IsFullUser() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid call of procedure ""%1"" of common module ""%2"".
			           |Only full-access users or
			           |users that run the application in privileged mode can disable update of access keys.';"),
			"DisableAccessKeysUpdate",
			"AccessManagement");
		Raise ErrorText;
	EndIf;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	DisableUpdate = SessionParameters.DIsableAccessKeysUpdate; // See AccessManagementInternal.NewDisableOfAccessKeysUpdate
	Regularly = Disconnect And    ScheduleUpdate1;
	Full      = Disconnect And Not ScheduleUpdate1;
	
	If DisableUpdate.Regularly = Regularly
	   And DisableUpdate.Full      = Full Then
		Return;
	EndIf;
	
	DisableUpdate = New Structure(DisableUpdate);
	
	If Not Disconnect And ScheduleUpdate1 Then
		EditedLists = DisableUpdate.EditedLists.Get();
		If EditedLists.Count() > 0 Then
			If AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
				Lists = New Array;
				AddedLists = New Map;
				For Each KeyAndValue In EditedLists Do
					FullName = Metadata.FindByType(KeyAndValue.Key).FullName();
					Lists.Add(FullName);
					AddedLists.Insert(FullName, True);
				EndDo;
				UnavailableLists = New Array;
				AccessManagementInternal.AddDependentLists(Lists, AddedLists, UnavailableLists);
				PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
				PlanningParameters.AllowedAccessKeys = False;
				PlanningParameters.LongDesc = "DisableAccessKeysUpdateOnFinishDisabling";
				AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
				If UnavailableLists.Count() > 0 Then
					AccessManagementInternal.ScheduleAccessUpdate(UnavailableLists, PlanningParameters);
				EndIf;
			EndIf;
			DisableUpdate.EditedLists = New ValueStorage(New Map);
			AccessManagementInternalCached.ChangedListsCacheOnDisabledAccessKeysUpdate().Clear();
		EndIf;
	EndIf;
	
	If Not Regularly And Not Full Then
		If DisableUpdate.NestedDisconnections.Count() > 0 Then
			NestedDisconnections = New Array(DisableUpdate.NestedDisconnections);
			Regularly = NestedDisconnections[0].Regularly;
			Full      = NestedDisconnections[0].Full;
			NestedDisconnections.Delete(0);
			DisableUpdate.NestedDisconnections = New FixedArray(NestedDisconnections);
		EndIf;
	ElsIf DisableUpdate.Regularly Or DisableUpdate.Full Then
		If DisableUpdate.Full Then
			Regularly = False;
			Full = True;
		EndIf;
		NestedDisconnection = New Structure;
		NestedDisconnection.Insert("Regularly", DisableUpdate.Regularly);
		NestedDisconnection.Insert("Full",      DisableUpdate.Full);
		NestedDisconnections = New Array(DisableUpdate.NestedDisconnections);
		NestedDisconnections.Add(New FixedStructure(NestedDisconnection));
		DisableUpdate.NestedDisconnections = New FixedArray(NestedDisconnections);
	EndIf;
	
	DisableUpdate.Regularly = Regularly;
	DisableUpdate.Full      = Full;
	
	SessionParameters.DIsableAccessKeysUpdate = New FixedStructure(DisableUpdate);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

// Adds deferred update handler that enables the universal restriction of access
// (enables the LimitAccessAtRecordLevelUniversally constant).
// Use only in final standard solutions, not in the library distributions.
//
// For the file infobase, a handler is not added (except for the initial filling).
// Accordingly, in client server bases with DIB, a handler is also not added,
// as DIB might contain file infobases (if case the opposite is true, the behavior can be overridden).
//
// Parameters:
//  Version      - String - Version to be used in "InfobaseUpdate.NewUpdateHandlersTable".
//                  Pass an empty string if "IsInitialPopulationOnly" is set to "True".
//  Handlers - See InfobaseUpdate.NewUpdateHandlerTable
//  IsInitialPopulationOnly - Boolean - Indicates whether only an initial population handler should be added.
//                  It is intended for cases where only newly created infobases are planned to
//                  be switched to the high-performance mode.
//  ExclusiveOfDIB - Boolean - Indicates whether an update handler should be added ignoring the DIB presence.
//                  It is required in cases where you need to switch client/server infobases to high-performance mode
//                  as it is assumed that a DIB does not include file infobases, at least ones with many active users
//                  that modify RLS data concurrently.
//                  
//
// Example:
//	Procedure OnAddUpdateHandlers(Handlers) Export
//		AccessManagement.AddUpdateHandlerToEnableUniversalRestriction(3.0.3.7, Handlers);
//	EndProcedure
//
Procedure AddUpdateHandlerToEnableUniversalRestriction(Version, Handlers,
			IsInitialPopulationOnly = False, ExclusiveOfDIB = False) Export
	
	If Common.IsSubordinateDIBNode()
	 Or Common.SeparatedDataUsageAvailable()
	   And AccessManagementInternal.LimitAccessAtRecordLevelUniversally(True) Then
		Return;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "InformationRegisters.AccessRestrictionParameters.EnableUniversalRecordLevelAccessRestriction";
	Handler.ExecutionMode = "Seamless";
	
	If IsInitialPopulationOnly
	 Or Common.FileInfobase() Then
		Return;
	EndIf;
	
	DIBEnabled = False;
	If Not ExclusiveOfDIB
	   And Not Common.DataSeparationEnabled()
	   And Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		ExchangePlansNames = New Array;
		For Each ExchangePlan In Metadata.ExchangePlans Do
			If ExchangePlan.DistributedInfoBase Then
				ExchangePlansNames.Add(ExchangePlan.Name);
			EndIf;
		EndDo;
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		Table = ModuleDataExchangeServer.DataExchangeMonitorTable(ExchangePlansNames);
		Boundary = CurrentSessionDate() - ('00010701' - '00010101');
		For Each String In Table Do
			If Not ValueIsFilled(String.LastRunDate)
			 Or String.LastRunDate > Boundary Then
				DIBEnabled = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If DIBEnabled Then
		Return;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.Version = Version;
	Handler.Procedure = "InformationRegisters.AccessRestrictionParameters.ProcessDataForMigrationToNewVersion";
	Handler.ExecutionMode = "Deferred";
	Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
	Handler.Comment = NStr("en = 'Enables universal record-level access restriction.';");
	Handler.Id = New UUID("74cb1992-c9ac-4b46-90db-810544dee86c");
	Handler.UpdateDataFillingProcedure = "InformationRegisters.AccessRestrictionParameters.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead = "InformationRegister.AccessRestrictionParameters";
	Handler.ObjectsToChange = "InformationRegister.AccessRestrictionParameters";
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// ServiceSubsystems.TMPAMEMObjects

// Assignment: for a universal document journal in the register (ERP).
// Used to hide a duplicate journal entry for transfer records
// when it is known that there will be two entries at once.
//
// Checks whether there is a table restriction by the specified access kind.
//
// If for all table access kinds in at least one access group that grants rights to
// the specified table the restriction is not configured (all values are allowed for all access kinds),
// there is no restriction by the specified access kind. Otherwise, there is no restriction
// by the specified access kind unless it is present in all the access groups for the specified table.
// 
// Parameters:
//  Table        - String - a full name of the metadata object, for example, Document.PurchaseInvoice.
//  AccessKind     - String - an access kind name, for example, Companies.
//  AllAccessKinds - String - names of all access kinds used in table restrictions,
//                            for example, Companies,PartnersGroups,Warehouses.
//
// Returns:
//  Boolean - if True, there is a table restriction by a specified access kind.
// 
Function HasTableRestrictionByAccessKind(Table, AccessKind, AllAccessKinds) Export
	
	Return AccessManagementInternal.HasTableRestrictionByAccessKind(Table,
		AccessKind, AllAccessKinds);
	
EndFunction

// End ServiceSubsystems.TMPAMEM

// Development.RightsAndAccessRestrictionsDevelopment

// Assignment: to call ASDS restrictions from the constructor.
// 
// Parameters:
//  MainTable  - String - a full name of the main table of the metadata object, for example, Document.SalesOrder.
//  RestrictionText - String - a restriction text specified in the metadata object
//    manager module to restrict users or external users.
//
// Returns:
//  Structure:
//   * InternalData - Structure - data to pass to the RestrictionStructure function.
//   * TablesFields       - Map of KeyAndValue:
//     ** Key     - String - a name of the metadata object collection, for example, Catalogs.
//     ** Value - Map of KeyAndValue:
//       *** Key     - String - a table (metadata object) name in uppercase.
//       *** Value - Structure:
//         **** TableExists - Boolean - False (True to fill in, if exists).
//         **** Fields - Map of KeyAndValue:
//           ***** Key - String - an attribute name in uppercase, including dot-separated,
//                                 for example, OWNER.COMPANY, GOODS.PRODUCTS.
//           ***** Value - Structure:
//             ****** FieldWithError - Number - 0 (for filling, if the field has an error.
//                       If 1, then there is an error in the name of the first part of the field.
//                       If 2, then an error is in the name of the second part of the field, i.e. after the first dot).
//             ****** ErrorKind - String - NotFound, TabularSectionWithoutField,
//                       TabularSectionAfterDot.
//             ****** Collection - String - a blank row (for filling, if the first part
//                       of the field exists, i.e. a field part before the first dot). Options: Attributes,
//                      TabularSections, StandardAttributes, StandardTabularSections,
//                      Dimensions, Resources, Graphs, AccountingFlags, ExtDimensionAccountingFlags,
//                      AddressingAttributes, SpecialFields. Special fields are
//                      Value - for the Constant.* tables,
//                      Recorder and Period - for the Sequence.* tables,
//                      RecalculationObject, CalculationType for the CalculationRegister.<Name>.<RecalculationName> tables.
//                      Fields after the first dot can be related only to the following collections: Attributes,
//                      StandardAttributes, AccountingFlags, and AddressingAttributes. You do not need to specify a collection
//                      for these parts of the field name.
//             ****** ContainsTypes - Map of KeyAndValue:
//               ******* Key - String - a full name of the reference table in uppercase.
//               ******* Value - Structure:
//                 ******** TypeName     - String - a type name whose presence you need to check.
//                 ******** ContainsType - Boolean - False (True for filling in,
//                                                         if the field of the last field has a type).
//         **** Predefined - Map of KeyAndValue:
//           ***** Key - String - a predefined item name.
//           ***** Value - Structure:
//             ****** NameExists - Boolean - False (True to fill in, if there is a predefined item).
//
//         **** Extensions - Map of KeyAndValue:
//           ***** Key - String - a name of the third table name, for example, a tabular section name.
//           ***** Value - Structure:
//             ****** TableExists - Boolean - False (True to fill in, if exists).
//             ****** Fields - Map - Same properties as in the main table (see above).
//
Function ParsedRestriction(MainTable, RestrictionText) Export
	
	Return AccessManagementInternal.ParsedRestriction(MainTable, RestrictionText);
	
EndFunction

// Assignment: to call ASDS restrictions from the constructor.
// Before transferring the ParsedRestriction parameter, in the TablesFields property, fill in
// the TableExists, FieldWithError, ContainsType, NameExists attachment properties.
// 
// Parameters:
//  ParsedRestriction - See ParsedRestriction
//
// Returns:
//  Structure:
//   * ErrorsDescription - Structure:
//      ** HasErrors  - Boolean - if True, one or more errors are found.
//      ** ErrorsText - String - a text of all errors.
//      ** Restriction - String - a numbered text of the restriction with the <<?>> symbols.
//      ** Errors      - Array of Structure - the descriptions of separate errors:
//         *** LineNumber    - Number -  a line in the multiline text, in which an error was found.
//         *** PositionInRow - Number -  a number of the character, from which the error was found.
//                                       It can be outside the line (line length + 1).
//         *** ErrorText    - String - an error text without describing the position.
//         *** ErrorString   - String - a line, in which an error with the added <<?>> was found.
//      ** AddOn - String - description of options of the first restriction part keywords.
//
//   * AdditionalTables - Array of Structure:
//      ** Table           - String - Full name of a metadata object.
//      ** Alias         - String - a table alias name.
//      ** ConnectionCondition - Structure - as in the ChangeRestriction property, but the
//                                     nodes are: "Field", "Value", "Constant", "AND", "=".
//   * MainTableAlias - String - filled in if additional tables are specified.
//   * ReadRestriction    - Structure - as in the ChangeRestriction property.
//   * UpdateRestriction - Structure:
//
//      ** Node - String - One of the lines:
//           Field, Value, Constant, And, Or, Not, =, <>, In, IsNull,
//           Type, ValueType, Choice, ValueAllowed, IsAuthorizedUser, ReadObjectAllowed,
//           EditObjectAllowed, ReadListAllowed, EditListAllowed, ForAllLines, ForOneOfLines.
//           Properties of the Field node:
//           
//
//     
//       ** Name       - String - Table name. For example, "Catalog.Companies".
//                               Properties of the ValueType node:
//       ** Table   - String - a table name of this field (or a blank row for the main table).
//       ** Alias - String - an attached table alias name (or a blank row for the main table),
//                        for example, "SettingInformationRegister" for the "MainCompany" field.
//       ** Cast  - String - a table name (if used), for example, to describe a field as:
//                       CAST(CAST(Owner AS Catalog.Files).FileOwner AS Catalog.Companies).Ref".
//       ** Attachment  - Structure - the Field node that contains the CAST nested action (with or without IsNull).
//                    - Undefined - there is no nested field.
//       ** IsNull  - Structure - the Value Or Constant node, for example, to describe an expression of the following type:
//                        "IsNULL(Owner, Value(Catalog.Files.BlankRef))".
//                    - Undefined - If IsNull is not used (including cases when the Attachment property is assigned a value).
//
//     Properties of the Value node:
//       ** Name - String - Table name. For example, "Catalog.Companies".
//                                                 Properties of the ValueType node:
//
//     
//       ** Value - Boolean
//                   - Number  - an arbitrary integer number up to 16 digits
//                   - String - an arbitrary string up to 150 characters.
//                   - Undefined
//
//     Properties of the And & Or nodes:
//       ** Arguments - Array - with the following elements:
//            *** Value - Structure - Any node except for Value or Constant.
//
//     Properties of the Not node:
//       ** Argument - Structure - Any node except for "Value" or "Constant".
//
//     Properties of the "=" and "<>" nodes:
//       ** FirstArgument - Structure - the Field node.
//       ** SecondArgument - Structure - Nodes Value and Constant. The Field node is only for the connection condition.
//
//     Properties of the In node:
//       ** SearchFor  - Structure - the Field node.
//       ** Values - Array - with the following elements:
//            *** Value - Structure - Value or Constant nodes.
//
//     Properties of the IsNull node:
//       ** Argument - Structure - Any node except for "Value" or "Constant".
//
//     Properties of the "=" and "<>" nodes:
//       ** Name - String - Table name. For example, "Catalog.Companies".
//
//     Properties of the ValueType node:
//       ** Argument - Structure - Any node except for "Value" or "Constant".
//
//     Properties of the "=" and "<>" nodes:
//       ** Case - Structure - the Field node.
//                - Undefined - the conditions contain an expression, not the Value node.
//       ** When - Array - with the following elements:
//            *** Value - Structure:
//                  **** Condition  - Structure - the Value node if the Case property is specified, otherwise,
//                                              nodes And, Or, Not, =, <>, In (applied to the nested content).
//                  **** Value - Structure - any node, except for Case.
//       ** Else - Structure - Any node, except for CASE and Value (the Field and Constant nodes can be only of the Boolean type).
//
//     Properties of the ValueAllowed, IsAuthorizedUser,
//                    "ReadObjectAllowed", "EditObjectAllowed",
//                    "ReadListAllowed", "EditListAllowed":
//       ** Field - Structure - the Field node.
//       ** Types - Array - with the following elements:
//            *** Value - String - a full table name.
//       ** CheckTypesExceptListed - Boolean - if True, all types of the Field property,
//                                                 except for those specified in the Types property.
//       ** ComparisonClarifications - Map of KeyAndValue:
//            *** Key     - String - a clarified value is Undefined, Null, or BlankRef,
//                                    <a full table name>, "Number", "String", "Date", and "Boolean".
//            *** Value - String - Result False or True.
//
//     Properties of the ForAllLines, ForOneOfLines nodes:
//       ** Argument - Structure - Any node except for "Value" or "Constant".
//                                 Properties of the "=" and "<>" nodes:
//
Function RestrictionStructure(ParsedRestriction) Export
	
	Return AccessManagementInternal.RestrictionStructure(ParsedRestriction);
	
EndFunction

// End Development.RightsAndAccessRestrictionsDevelopment

#EndRegion

#EndRegion

#Region Private

// Addition to the FillAccessValuesSets procedure.

// Casts a value set table to the tabular section or record set format.
//  It is executed before writing to the AccessValuesSets register or
// before writing an object with the AccessValuesSets tabular section.
//
// Parameters:
//  ObjectReference - AnyRef - Reference to the object from DefinedType.AccessValuesSetsOwnerObject
//                                 whose access value sets will be populated.
//
//  Table - See AccessValuesSetsTable
//
Procedure SpecifyAccessValuesSets(ObjectReference, Table)
	
	AccessKindsNames = AccessManagementInternal.AccessKindsProperties().ByNames;
	
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	RightsSettingsOwnersTypes = AvailableRights.ByRefsTypes;
	
	For Each String In Table Do
		
		If RightsSettingsOwnersTypes.Get(TypeOf(String.AccessValue)) <> Undefined
		   And Not ValueIsFilled(String.Refinement) Then
			
			String.Refinement = Common.MetadataObjectID(TypeOf(ObjectReference));
		EndIf;
		
		If String.AccessKind = "" Then
			Continue;
		EndIf;
		
		If String.AccessKind = "ReadRight1"
		 Or String.AccessKind = "EditRight" Then
			
			If TypeOf(String.AccessValue) <> Type("CatalogRef.MetadataObjectIDs") Then
				String.AccessValue =
					Common.MetadataObjectID(TypeOf(String.AccessValue));
			EndIf;
			
			If String.AccessKind = "ReadRight1" Then
				String.Refinement = Catalogs.MetadataObjectIDs.EmptyRef();
			Else
				String.Refinement = String.AccessValue;
			EndIf;
		
		ElsIf AccessKindsNames.Get(String.AccessKind) <> Undefined
		      Or String.AccessKind = "RightsSettings" Then
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Object ""%1"" generated an access value set
				           |containing a known access kind ""%2."" It cannot contain this access kind.
				           |
				           |It can only contain special access kinds
				           |""%3"" and ""%4"".';"),
				TypeOf(ObjectReference),
				String.AccessKind,
				"ReadRight1",
				"EditRight");
			Raise ErrorText;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Object ""%1"" generated an access value set
				           |containing an unknown access kind ""%2.""';"),
				TypeOf(ObjectReference),
				String.AccessKind);
			Raise ErrorText;
		EndIf;
		
		String.AccessKind = "";
	EndDo;
	
EndProcedure

// For the AddAccessValuesSets procedure.

Function TablesSets(Table, RightsNormalization = False)
	
	TablesSets = New Map;
	
	For Each String In Table Do
		Set = TablesSets.Get(String.SetNumber);
		If Set = Undefined Then
			Set = New Structure;
			Set.Insert("Read", False);
			Set.Insert("Update", False);
			Set.Insert("Rows", New Array);
			TablesSets.Insert(String.SetNumber, Set);
		EndIf;
		If String.Read Then
			Set.Read = True;
		EndIf;
		If String.Update Then
			Set.Update = True;
		EndIf;
		Set.Rows.Add(String);
	EndDo;
	
	If RightsNormalization Then
		For Each SetDetails In TablesSets Do
			Set = SetDetails.Value;
			
			If Not Set.Read And Not Set.Update Then
				Set.Read    = True;
				Set.Update = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return TablesSets;
	
EndFunction

Procedure AddSets(Receiver, Source)
	
	DestinationSets = TablesSets(Receiver);
	SourceSets = TablesSets(Source);
	
	MaxSetNumber = -1;
	
	For Each DestinationSetDetails In DestinationSets Do
		DestinationSet1 = DestinationSetDetails.Value;
		
		If Not DestinationSet1.Read And Not DestinationSet1.Update Then
			DestinationSet1.Read    = True;
			DestinationSet1.Update = True;
		EndIf;
		
		For Each String In DestinationSet1.Rows Do
			String.Read    = DestinationSet1.Read;
			String.Update = DestinationSet1.Update;
		EndDo;
		
		If DestinationSetDetails.Key > MaxSetNumber Then
			MaxSetNumber = DestinationSetDetails.Key;
		EndIf;
	EndDo;
	
	NewSetNumber = MaxSetNumber + 1;
	
	For Each SourceSetDetails In SourceSets Do
		SourceSet = SourceSetDetails.Value;
		
		If Not SourceSet.Read And Not SourceSet.Update Then
			SourceSet.Read    = True;
			SourceSet.Update = True;
		EndIf;
		
		For Each SourceRow1 In SourceSet.Rows Do
			NewRow = Receiver.Add();
			FillPropertyValues(NewRow, SourceRow1);
			NewRow.SetNumber = NewSetNumber;
			NewRow.Read      = SourceSet.Read;
			NewRow.Update   = SourceSet.Update;
		EndDo;
		
		NewSetNumber = NewSetNumber + 1;
	EndDo;
	
EndProcedure

Procedure MultiplySets(Receiver, Source)
	
	DestinationSets = TablesSets(Receiver);
	SourceSets = TablesSets(Source, True);
	Table = AccessValuesSetsTable();
	
	CurrentSetNumber = 1;
	For Each DestinationSetDetails In DestinationSets Do
			DestinationSet1 = DestinationSetDetails.Value;
		
		If Not DestinationSet1.Read And Not DestinationSet1.Update Then
			DestinationSet1.Read    = True;
			DestinationSet1.Update = True;
		EndIf;
		
		For Each SourceSetDetails In SourceSets Do
			SourceSet = SourceSetDetails.Value;
			
			ReadMultiplication    = DestinationSet1.Read    And SourceSet.Read;
			ChangeMultiplication = DestinationSet1.Update And SourceSet.Update;
			If Not ReadMultiplication And Not ChangeMultiplication Then
				Continue;
			EndIf;
			For Each DestinationRow1 In DestinationSet1.Rows Do
				String = Table.Add();
				FillPropertyValues(String, DestinationRow1);
				String.SetNumber = CurrentSetNumber;
				String.Read      = ReadMultiplication;
				String.Update   = ChangeMultiplication;
			EndDo;
			For Each SourceRow1 In SourceSet.Rows Do
				String = Table.Add();
				FillPropertyValues(String, SourceRow1);
				String.SetNumber = CurrentSetNumber;
				String.Read      = ReadMultiplication;
				String.Update   = ChangeMultiplication;
			EndDo;
			CurrentSetNumber = CurrentSetNumber + 1;
		EndDo;
	EndDo;
	
	Receiver = Table;
	
EndProcedure

Procedure AddSetsAndSimplify(Receiver, Source)
	
	DestinationSets = TablesSets(Receiver);
	SourceSets = TablesSets(Source);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumerationsCodes   = New Map;
	SetRowsTable = New ValueTable;
	
	FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable);
	
	CurrentSetNumber = 1;
	
	AddSimplifiedSetsToResult(
		ResultSets, DestinationSets, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable);
	
	AddSimplifiedSetsToResult(
		ResultSets, SourceSets, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable);
	
	FillDestinationByResultSets(Receiver, ResultSets);
	
EndProcedure

Procedure MultiplySetsAndSimplify(Receiver, Source)
	
	DestinationSets = TablesSets(Receiver);
	SourceSets = TablesSets(Source, True);
	
	ResultSets   = New Map;
	TypesCodes          = New Map;
	EnumerationsCodes   = New Map;
	SetRowsTable = New ValueTable;
	
	FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable);
	
	CurrentSetNumber = 1;
	
	For Each DestinationSetDetails In DestinationSets Do
		DestinationSet1 = DestinationSetDetails.Value;
		
		If Not DestinationSet1.Read And Not DestinationSet1.Update Then
			DestinationSet1.Read    = True;
			DestinationSet1.Update = True;
		EndIf;
		
		For Each SourceSetDetails In SourceSets Do
			SourceSet = SourceSetDetails.Value;
			
			ReadMultiplication    = DestinationSet1.Read    And SourceSet.Read;
			ChangeMultiplication = DestinationSet1.Update And SourceSet.Update;
			If Not ReadMultiplication And Not ChangeMultiplication Then
				Continue;
			EndIf;
			
			SetStrings = SetRowsTable.Copy();
			
			For Each DestinationRow1 In DestinationSet1.Rows Do
				String = SetStrings.Add();
				String.AccessKind      = DestinationRow1.AccessKind;
				String.AccessValue = DestinationRow1.AccessValue;
				String.Refinement       = DestinationRow1.Refinement;
				FillRowID(String, TypesCodes, EnumerationsCodes);
			EndDo;
			For Each SourceRow1 In SourceSet.Rows Do
				String = SetStrings.Add();
				String.AccessKind      = SourceRow1.AccessKind;
				String.AccessValue = SourceRow1.AccessValue;
				String.Refinement       = SourceRow1.Refinement;
				FillRowID(String, TypesCodes, EnumerationsCodes);
			EndDo;
			
			SetStrings.GroupBy("RowID, AccessKind, AccessValue, Refinement");
			SetStrings.Sort("RowID");
			
			SetID = "";
			For Each String In SetStrings Do
				SetID = SetID + String.RowID + Chars.LF;
			EndDo;
			
			ExistingSet = ResultSets.Get(SetID);
			If ExistingSet = Undefined Then
				
				SetProperties = New Structure;
				SetProperties.Insert("Read",      ReadMultiplication);
				SetProperties.Insert("Update",   ChangeMultiplication);
				SetProperties.Insert("Rows",      SetStrings);
				SetProperties.Insert("SetNumber", CurrentSetNumber);
				ResultSets.Insert(SetID, SetProperties);
				CurrentSetNumber = CurrentSetNumber + 1;
			Else
				If ReadMultiplication Then
					ExistingSet.Read = True;
				EndIf;
				If ChangeMultiplication Then
					ExistingSet.Update = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	FillDestinationByResultSets(Receiver, ResultSets);
	
EndProcedure

Procedure FillTypesCodesAndSetStringsTable(TypesCodes, EnumerationsCodes, SetRowsTable)
	
	EnumerationsCodes = AccessManagementInternalCached.EnumerationsCodes();
	
	TypesCodes = AccessManagementInternalCached.RefsTypesCodes("DefinedType.AccessValue");
	
	TypeCodeLength = 0;
	For Each KeyAndValue In TypesCodes Do
		TypeCodeLength = StrLen(KeyAndValue.Value);
		Break;
	EndDo;
	
	RowIDLength =
		20 // String of the access kind name
		+ TypeCodeLength
		+ 36 // Length of the string presentation of a UUID (access value).
		+ 36 // Length of the string presentation of a UUID (adjustment).
		+ 6; // Space for separators
	
	SetRowsTable = New ValueTable;
	SetRowsTable.Columns.Add("RowID", New TypeDescription("String", , New StringQualifiers(RowIDLength)));
	SetRowsTable.Columns.Add("AccessKind",          New TypeDescription("String", , New StringQualifiers(20)));
	SetRowsTable.Columns.Add("AccessValue",     Metadata.DefinedTypes.AccessValue.Type);
	SetRowsTable.Columns.Add("Refinement",           New TypeDescription("CatalogRef.MetadataObjectIDs"));
	
EndProcedure

Procedure FillRowID(String, TypesCodes, EnumerationsCodes)
	
	If String.AccessValue = Undefined Then
		AccessValueID = "";
	Else
		AccessValueID = EnumerationsCodes.Get(String.AccessValue);
		If AccessValueID = Undefined Then
			AccessValueID = String(String.AccessValue.UUID());
		EndIf;
	EndIf;
	
	String.RowID = String.AccessKind + ";"
		+ TypesCodes.Get(TypeOf(String.AccessValue)) + ";"
		+ AccessValueID + ";"
		+ String.Refinement.UUID() + ";";
	
EndProcedure

Procedure AddSimplifiedSetsToResult(ResultSets, SetsToAdd, CurrentSetNumber, TypesCodes, EnumerationsCodes, SetRowsTable)
	
	For Each SetToAddDetails In SetsToAdd Do
		SetToAdd = SetToAddDetails.Value;
		
		If Not SetToAdd.Read And Not SetToAdd.Update Then
			SetToAdd.Read    = True;
			SetToAdd.Update = True;
		EndIf;
		
		SetStrings = SetRowsTable.Copy();
		
		For Each StringOfSetToAdd In SetToAdd.Rows Do
			String = SetStrings.Add();
			String.AccessKind      = StringOfSetToAdd.AccessKind;
			String.AccessValue = StringOfSetToAdd.AccessValue;
			String.Refinement       = StringOfSetToAdd.Refinement;
			FillRowID(String, TypesCodes, EnumerationsCodes);
		EndDo;
		
		SetStrings.GroupBy("RowID, AccessKind, AccessValue, Refinement");
		SetStrings.Sort("RowID");
		
		SetID = "";
		For Each String In SetStrings Do
			SetID = SetID + String.RowID + Chars.LF;
		EndDo;
		
		ExistingSet = ResultSets.Get(SetID);
		If ExistingSet = Undefined Then
			
			SetProperties = New Structure;
			SetProperties.Insert("Read",      SetToAdd.Read);
			SetProperties.Insert("Update",   SetToAdd.Update);
			SetProperties.Insert("Rows",      SetStrings);
			SetProperties.Insert("SetNumber", CurrentSetNumber);
			ResultSets.Insert(SetID, SetProperties);
			
			CurrentSetNumber = CurrentSetNumber + 1;
		Else
			If SetToAdd.Read Then
				ExistingSet.Read = True;
			EndIf;
			If SetToAdd.Update Then
				ExistingSet.Update = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillDestinationByResultSets(Receiver, ResultSets)
	
	Receiver = AccessValuesSetsTable();
	
	SetsList = New ValueList;
	For Each SetDetails In ResultSets Do
		SetsList.Add(SetDetails.Value, SetDetails.Key);
	EndDo;
	SetsList.SortByPresentation();
	
	CurrentSetNumber = 1;
	For Each ListItem In SetsList Do
		SetProperties = ListItem.Value;
		For Each String In SetProperties.Rows Do
			NewRow = Receiver.Add();
			NewRow.SetNumber     = CurrentSetNumber;
			NewRow.AccessKind      = String.AccessKind;
			NewRow.AccessValue = String.AccessValue;
			NewRow.Refinement       = String.Refinement;
			NewRow.Read          = SetProperties.Read;
			NewRow.Update       = SetProperties.Update;
		EndDo;
		CurrentSetNumber = CurrentSetNumber + 1;
	EndDo;
	
EndProcedure

// For the OnCreateAccessValueForm and AccessValuesGroupsAllowingAccessValuesChange procedures.
Function AccessValueGroupsProperties(AccessValueType, ErrorTitle)
	
	SetPrivilegedMode(True);
	
	GroupsProperties = New Structure;
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	AccessKindProperties = AccessKindsProperties.AccessValuesWithGroups.ByTypes.Get(AccessValueType); // See AccessManagementInternal.AccessKindProperties
	
	If AccessKindProperties = Undefined Then
		ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Access value groups are not used for
			           |access values of ""%1"" type.';"),
			String(AccessValueType));
		Raise ErrorText;
	EndIf;
	
	GroupsProperties.Insert("AccessKind", AccessKindProperties.Name);
	GroupsProperties.Insert("Type",        AccessKindProperties.ValuesGroupsType);
	
	GroupsProperties.Insert("Table",    Metadata.FindByType(
		AccessKindProperties.ValuesGroupsType).FullName());
	
	GroupsProperties.Insert("ValueTypeBlankRef",
		AccessManagementInternal.MetadataObjectEmptyRef(AccessValueType));
	
	Return GroupsProperties;
	
EndFunction

// For the ConfigureDynamicListFilters function.
Procedure UpdateDataCompositionParameterValue(Val ParametersOwner,
                                                    Val ParameterName,
                                                    Val ParameterValue)
	
	For Each Parameter In ParametersOwner.Parameters.Items Do
		If String(Parameter.Parameter) = ParameterName Then
			
			If Parameter.Use
			   And Parameter.Value = ParameterValue Then
				Return;
			EndIf;
			Break;
			
		EndIf;
	EndDo;
	
	ParametersOwner.Parameters.SetParameterValue(ParameterName, ParameterValue);
	
EndProcedure

// For the EnableProfileForUser and DisableProfileForUser procedures.
Procedure EnableDisableUserProfile(User, Profile, Enable, Source = Undefined) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"AccessManagement.EnableDisableUserProfile");
	
	If Not AccessManagementInternal.SimplifiedAccessRightsSetupInterface() Then
		ErrorText =
			NStr("en = 'This operation is available only in the simplified
			           |access rights interface.';");
		Raise ErrorText;
	EndIf;
	
	If Enable Then
		NameOfAProcedureOrAFunction = "EnableProfileForUser";
	Else
		NameOfAProcedureOrAFunction = "DisableUserProfile";
	EndIf;
	
	// Checking value types of the User parameter.
	If TypeOf(User) <> Type("CatalogRef.Users")
	   And TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
		
		ParameterName = "User";
		ParameterValue = User;
		Types = New Array;
		Types.Add(Type("CatalogRef.Users"));
		Types.Add(Type("CatalogRef.ExternalUsers"));
		ExpectedTypes = New TypeDescription(Types);
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2. 
			           |Expected value: %3, actual value: %4 (%5 type).';"),
			ParameterName,
			NameOfAProcedureOrAFunction,
			ExpectedTypes, 
			?(ParameterValue <> Undefined, ParameterValue, NStr("en = 'Undefined';")),
			TypeOf(ParameterValue));
		Raise ErrorText;
	EndIf;
	
	// Checking value types of the Profile parameter.
	If TypeOf(Profile) <> Type("CatalogRef.AccessGroupProfiles")
	   And TypeOf(Profile) <> Type("String")
	   And TypeOf(Profile) <> Type("UUID")
	   And Not (Not Enable And TypeOf(Profile) = Type("Undefined")) Then
		
		ParameterName = "Profile";
		ParameterValue = Profile;
		Types = New Array;
		Types.Add(Type("CatalogRef.AccessGroupProfiles"));
		Types.Add(Type("String"));
		Types.Add(Type("UUID"));
		If Not Enable Then
			Types.Add(Type("Undefined"));
		EndIf;
		ExpectedTypes = New TypeDescription(Types);
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of the %1 parameter in %2. 
			           |Expected value: %3, actual value: %4 (%5 type).';"),
			ParameterName,
			NameOfAProcedureOrAFunction,
			ExpectedTypes, 
			?(ParameterValue <> Undefined, ParameterValue, NStr("en = 'Undefined';")),
			TypeOf(ParameterValue));
		Raise ErrorText;
	EndIf;
	
	If TypeOf(Profile) = Type("CatalogRef.AccessGroupProfiles")
	 Or TypeOf(Profile) = Type("Undefined") Then
		
		CurrentProfile = Profile;
	Else
		CurrentProfile = Catalogs.AccessGroupProfiles.SuppliedProfileByID(
			Profile, True, True);
	EndIf;
	
	If CurrentProfile <> Undefined Then
		ProfileProperties = Common.ObjectAttributesValues(CurrentProfile,
			"Description, AccessKinds");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	&FilterCriterion";
	Query.SetParameter("User", User);
	If CurrentProfile = ProfileAdministrator() Then
		FilterCriterion = "AccessGroups.Ref = &AdministratorsAccessGroup";
		Query.SetParameter("AdministratorsAccessGroup",
			AdministratorsAccessGroup());
	Else
		FilterCriterion = "AccessGroups.User = &User";
		If Enable Or CurrentProfile <> Undefined Then
			FilterCriterion = FilterCriterion + Chars.LF + "	AND AccessGroups.Profile = &Profile"; // @query-part-1
			Query.SetParameter("Profile", CurrentProfile);
		EndIf;
	EndIf;
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", FilterCriterion);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	Block = New DataLock();
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.DataSource = QueryResult;
	
	BeginTransaction();
	Try
		Block.Lock();
		Selection.Next();
		While True Do
			PersonalAccessGroup = Selection.Ref;
			If ValueIsFilled(PersonalAccessGroup) Then
				AccessGroupObject = PersonalAccessGroup.GetObject();
				AccessGroupObject.DeletionMark = False;
				
			ElsIf CurrentProfile <> Undefined Then
				// Creating a personal access group.
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.PersonalAccessGroupsParent();
				AccessGroupObject.Description = ProfileProperties.Description;
				AccessGroupObject.User = User;
				AccessGroupObject.Profile      = CurrentProfile;
				FillAccessKindsAndValuesOfNewAccessGroup(AccessGroupObject,
					ProfileProperties, Source);
			Else
				AccessGroupObject = Undefined;
			EndIf;
			
			If PersonalAccessGroup = AdministratorsAccessGroup() Then
				UserDetails =  AccessGroupObject.Users.Find(
					User, "User");
				
				If Enable And UserDetails = Undefined Then
					AccessGroupObject.Users.Add().User = User;
				ElsIf Not Enable And UserDetails <> Undefined Then
					AccessGroupObject.Users.Delete(UserDetails);
				EndIf;
				
				If Not Common.DataSeparationEnabled() Then
					// Checking a blank list of infobase users in the Administrators access group.
					ErrorDescription = "";
					AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
						AccessGroupObject.Users, ErrorDescription);
					
					If ValueIsFilled(ErrorDescription) Then
						ErrorText =
							NStr("en = 'At least one user authorized to log in
							           |must have the Administrator profile.';");
						Raise ErrorText;
					EndIf;
				EndIf;
			ElsIf AccessGroupObject <> Undefined Then
				AccessGroupObject.Users.Clear();
				If Enable Then
					AccessGroupObject.Users.Add().User = User;
				EndIf;
			EndIf;
			
			If AccessGroupObject <> Undefined Then
				AccessGroupObject.Write();
			EndIf;
			
			If Not Selection.Next() Then
				Break;
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure FillAccessKindsAndValuesOfNewAccessGroup(AccessGroupObject, ProfileProperties, Source)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &Profile
	|	AND AccessGroups.User = &User";
	Query.SetParameter("Profile", AccessGroupObject.Profile);
	Query.SetParameter("User", Source);
	
	Selection = Query.Execute().Select();
	If Selection.Next() And Selection.Count() = 1 Then
		GroupProperties = Common.ObjectAttributesValues(Selection.Ref,
			"AccessKinds, AccessValues");
		AccessGroupObject.AccessKinds.Load(GroupProperties.AccessKinds.Unload());
		AccessGroupObject.AccessValues.Load(GroupProperties.AccessValues.Unload());
	Else
		AccessGroupObject.AccessKinds.Load(AccessKindsForNewAccessGroup(ProfileProperties));
	EndIf;
	
EndProcedure

Function AccessKindsForNewAccessGroup(ProfileProperties)
	
	AccessKinds = ProfileProperties.AccessKinds.Unload();
	
	Filter = New Structure;
	Filter.Insert("Predefined", True);
	Predefined1 = AccessKinds.FindRows(Filter);
	
	For Each Predefined In Predefined1 Do
		AccessKinds.Delete(Predefined);
	EndDo;
	
	Return AccessKinds;
	
EndFunction

#EndRegion
