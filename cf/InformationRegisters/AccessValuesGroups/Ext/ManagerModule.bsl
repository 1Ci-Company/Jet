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

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// It must be called:
// 1) When adding a new user (or an external user),
//    When adding a new user group (or an external user group),
//    when changing the user group members (or groups of external users).
//    Parameters = Structure with one of the properties or both of them:
//    - Users: a single user or an array.
//    - UserGroups: a single user group or an array.
//
// 2) When changing assignee groups.
//    Parameters = Structure with one property:
//    - PerformersGroups: Undefined, a single assignee group or an array.
//
// 3) When changing an authorization object of an external user.
//    Parameters = Structure with one property:
//    - AuthorizationObjects: Undefined, a single authorization object or an array.
//
// Types used in the parameters:
//
//  User - CatalogRef.Users;
//                         CatalogRef.ExternalUsers.
//
//  User group - CatalogRef.UserGroups,
//                         CatalogRef.ExternalUsersGroups.
//
//  Performer - CatalogRef.Users,
//                         CatalogRef.ExternalUsers.
//
//  Group of assignees - for example, CatalogRef.TaskPerformersGroups.
//
//  Authorization object - for example, CatalogRef.Individuals.
//
// Parameters:
//  Parameters     - Undefined - Update everything without applying filters.
//                  See options above.
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateUsersGroups(Parameters = Undefined, HasChanges = Undefined) Export
	
	UpdateKind = "";
	
	If Parameters = Undefined Then
		UpdateKind = "All";
	
	ElsIf Parameters.Count() = 2
	        And Parameters.Property("Users")
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("Users") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("UserGroups") Then
		
		UpdateKind = "UsersAndUserGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("PerformersGroups") Then
		
		UpdateKind = "PerformersGroups";
		
	ElsIf Parameters.Count() = 1
	        And Parameters.Property("AuthorizationObjects") Then
		
		UpdateKind = "AuthorizationObjects";
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1
			           |of the %2 information register manager module.
			           |
			           |Some parameters are invalid.';"),
			"UpdateUsersGroups",
			"AccessValuesGroups");
		Raise ErrorText;
	EndIf;
	
	BeginTransaction();
	Try
		If InfobaseUpdate.InfobaseUpdateInProgress()
		 Or InfobaseUpdate.IsCallFromUpdateHandler() Then
			
			DeleteUnusedRecords(HasChanges);
		EndIf;
		
		If UpdateKind = "UsersAndUserGroups" Then
			
			If Parameters.Property("Users") Then
				UpdateUsers(        Parameters.Users, HasChanges);
				UpdatePerformersGroups( , Parameters.Users, HasChanges);
			EndIf;
			
			If Parameters.Property("UserGroups") Then
				UpdateUserGroups(Parameters.UserGroups, HasChanges);
			EndIf;
			
		ElsIf UpdateKind = "PerformersGroups" Then
			UpdatePerformersGroups(Parameters.PerformersGroups, , HasChanges);
			
		ElsIf UpdateKind = "AuthorizationObjects" Then
			UpdateAuthorizationObjects(Parameters.AuthorizationObjects, HasChanges);
		Else
			UpdateUsers(       ,   HasChanges);
			UpdateUserGroups( ,   HasChanges);
			UpdatePerformersGroups(  , , HasChanges);
			UpdateAuthorizationObjects(  ,   HasChanges);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Removes unused data after changing content
// of value types and access value groups.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges1() Export
	
	SetPrivilegedMode(True);
	
	If Constants.LimitAccessAtRecordLevel.Get() Then
		AccessManagementInternal.SetDataFillingForAccessRestriction(True);
	EndIf;
	
	UpdateEmptyAccessValuesGroups();
	DeleteUnusedRecords();
	
EndProcedure

#EndRegion

#Region Private

// Updates register data after changing access values.
//
// Parameters:
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	DeleteUnusedRecords(HasChanges);
	
	UpdateUsersGroups( , HasChanges);
	
	UpdateAccessValuesGroups( , HasChanges);
	
EndProcedure

// Updates access value groups in the InformationRegister.AccessValuesGroups.
//
// Parameters:
//  AccessValue - DefinedType.AccessValueObject - Object before writing.
//                  - DefinedType.AccessValue - Empty references are ignored.
//                      The value type must be included in the type list of the "AccessValue"
//                      dimension in the "AccessValuesGroups" information register.
//                  - Array of DefinedType.AccessValue
//                  - Undefined - Update for all values of any type.
//
//  HasChanges   - Boolean - (return value) - if recorded,
//                    True is set, otherwise, it does not change.
//
Procedure UpdateAccessValuesGroups(AccessValue = Undefined,
                                        HasChanges   = Undefined) Export
	
	If AccessValue = Undefined Then
		UpdateEmptyAccessValuesGroups(HasChanges);
	EndIf;
	UpdateAccessGroupsWithFilledValues(AccessValue, HasChanges);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	// Data registration is not required.
	Return;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	UpdateRegisterData();
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Deletes unnecessary records if any are found.
Procedure DeleteUnusedRecords(HasChanges = Undefined)
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	ValuesGroupsTypes = AccessKindsProperties.AccessValuesWithGroups.ValueGroupTypesForUpdate;
	
	GroupsAndValuesTypesTable = New ValueTable;
	GroupsAndValuesTypesTable.Columns.Add("ValuesType",      Metadata.DefinedTypes.AccessValue.Type);
	GroupsAndValuesTypesTable.Columns.Add("ValuesGroupsType", Metadata.DefinedTypes.AccessValue.Type);
	
	For Each KeyAndValue In ValuesGroupsTypes Do
		If TypeOf(KeyAndValue.Key) = Type("Type") Then
			Continue;
		EndIf;
		String = GroupsAndValuesTypesTable.Add();
		String.ValuesType      = KeyAndValue.Key;
		String.ValuesGroupsType = KeyAndValue.Value;
	EndDo;
	
	// Data groups in the register.
	// 0 - Standard access values.
	// 1 - Internal or external users.
	// 2 - Internal or external user groups.
	// 3 - Assignee groups.
	// 4 - Authorization objects.
	
	
	Query = New Query;
	Query.SetParameter("GroupsAndValuesTypesTable", GroupsAndValuesTypesTable);
	Query.Text =
	"SELECT
	|	TypesTable.ValuesType AS ValuesType,
	|	TypesTable.ValuesGroupsType AS ValuesGroupsType
	|INTO GroupsAndValuesTypesTable
	|FROM
	|	&GroupsAndValuesTypesTable AS TypesTable
	|
	|INDEX BY
	|	TypesTable.ValuesType,
	|	TypesTable.ValuesGroupsType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValueGroups.AccessValue AS AccessValue,
	|	ValueGroups.AccessValuesGroup AS AccessValuesGroup,
	|	ValueGroups.DataGroup AS DataGroup
	|FROM
	|	(SELECT
	|		AccessValuesGroups.AccessValue AS AccessValue,
	|		AccessValuesGroups.AccessValuesGroup AS AccessValuesGroup,
	|		AccessValuesGroups.DataGroup AS DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.AccessValue = UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 0
	|		AND NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						GroupsAndValuesTypesTable AS GroupsAndValuesTypesTable
	|					WHERE
	|						VALUETYPE(GroupsAndValuesTypesTable.ValuesType) = VALUETYPE(AccessValuesGroups.AccessValue)
	|						AND VALUETYPE(GroupsAndValuesTypesTable.ValuesGroupsType) = VALUETYPE(AccessValuesGroups.AccessValuesGroup))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsers)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 1
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 2
	|		AND VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 3
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.Users)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.UserGroups)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND (VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.ExternalUsersGroups))
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup = 4
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsers)
	|		AND VALUETYPE(AccessValuesGroups.AccessValuesGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValuesGroups.AccessValue,
	|		AccessValuesGroups.AccessValuesGroup,
	|		AccessValuesGroups.DataGroup
	|	FROM
	|		InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|	WHERE
	|		AccessValuesGroups.DataGroup > 4) AS ValueGroups";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			RecordSet = CreateRecordSet();
			RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
			RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
			RecordSet.Filter.DataGroup.Set(Selection.DataGroup);
			RecordSet.Write();
			HasChanges = True;
		EndDo;
	EndIf;
	
EndProcedure

// Fills groups for blank references to the access value types in use.
//
// Parameters:
//  HasChanges - See UpdateAccessValuesGroups.HasChanges
//
Procedure UpdateEmptyAccessValuesGroups(HasChanges = Undefined)
	
	QueryTemplateForRedundant =
	"SELECT
	|	VALUE(Catalog.Users.EmptyRef) AS AccessValue,
	|	AccessValuesGroups.AccessValuesGroup AS AccessValuesGroup
	|FROM
	|	InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|WHERE
	|	AccessValuesGroups.DataGroup = 0
	|	AND AccessValuesGroups.AccessValue = VALUE(Catalog.Users.EmptyRef)
	|	AND AccessValuesGroups.AccessValuesGroup <> VALUE(Catalog.UserGroups.EmptyRef)";
	
	QueryTemplateForMissing =
	"SELECT
	|	VALUE(Catalog.Users.EmptyRef) AS AccessValue,
	|	VALUE(Catalog.UserGroups.EmptyRef) AS AccessValuesGroup
	|WHERE
	|	NOT TRUE IN
	|				(SELECT TOP 1
	|					TRUE
	|				FROM
	|					InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|				WHERE
	|					AccessValuesGroups.DataGroup = 0
	|					AND AccessValuesGroups.AccessValue = VALUE(Catalog.Users.EmptyRef)
	|					AND AccessValuesGroups.AccessValuesGroup = VALUE(Catalog.UserGroups.EmptyRef))";
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	
	ByRefTypesForUpdate = AccessValuesWithGroups.ByRefTypesForUpdate;
	QueriesTextsForMissing = New Array;
	QueriesTextsForRedundant = New Array;
	
	// ACC:1319-off - The lock is set in the called procedure "UpdateFromQueryResult".
	Block = New DataLock;
	// ACC:1319-on
	
	For Each TableName In AccessValuesWithGroups.NamesOfTablesToUpdate Do
		RefType = Type(StrReplace(TableName, ".", "Ref."));
		Properties = ByRefTypesForUpdate.Get(RefType);
		GroupsTableName = TableName;
		If Properties.ValuesGroupsType <> Type("Undefined") Then
			GroupsTableName = Metadata.FindByType(Properties.ValuesGroupsType).FullName();
		EndIf;
		QueryTextForRedundant = StrReplace(QueryTemplateForRedundant,
			"Catalog.Users", TableName);
		QueryTextForRedundant = StrReplace(QueryTextForRedundant,
			"Catalog.UserGroups", GroupsTableName);
		QueriesTextsForRedundant.Add(QueryTextForRedundant);
		
		QueryTextForMissing = StrReplace(QueryTemplateForMissing,
			"Catalog.Users", TableName);
		QueryTextForMissing = StrReplace(QueryTextForMissing,
			"Catalog.UserGroups", GroupsTableName);
		QueriesTextsForMissing.Add(QueryTextForMissing);
		
		LockItem = Block.Add("InformationRegister.AccessValuesGroups");
		LockItem.SetValue("DataGroup", 0);
		LockItem.SetValue("AccessValue", Properties.Ref);
	EndDo;
	
	UnionAllText = Common.UnionAllText();
	
	Query = New Query;
	Query.Text = StrConcat(QueriesTextsForRedundant, UnionAllText)
		+ Common.QueryBatchSeparator()
		+ StrConcat(QueriesTextsForMissing, UnionAllText);
	
	QueryResults = Query.ExecuteBatch();
	
	If QueryResults[0].IsEmpty() And QueryResults[1].IsEmpty() Then
		Return;
	EndIf;
	
	UpdateFromQueryResult(Query,
		Block, ByRefTypesForUpdate, New Array, HasChanges);
	
EndProcedure

// Updates access value groups in "InformationRegister.AccessValuesGroups".
//
// Parameters:
//  AccessValue - See UpdateAccessValuesGroups.AccessValue
//  HasChanges   - See UpdateAccessValuesGroups.HasChanges
//
Procedure UpdateAccessGroupsWithFilledValues(AccessValue, HasChanges)
	
	SetPrivilegedMode(True);
	
	AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
	AccessValuesWithGroups = AccessKindsProperties.AccessValuesWithGroups;
	ByRefTypesForUpdate = AccessValuesWithGroups.ByRefTypesForUpdate;
	Object = Undefined;
	
	If AccessValue = Undefined Then
		NamesOfTablesToUpdate = AccessValuesWithGroups.NamesOfTablesToUpdate;
	Else
		If TypeOf(AccessValue) = Type("Array") Then
			CurLinks = AccessValue;
		Else
			AccessValueType = TypeOf(AccessValue);
			AccessKindProperties = AccessValuesWithGroups.ByTypesForUpdate.Get(AccessValueType);
			If AccessKindProperties = Undefined Then
				Raise ErrorTextTypeNotConfigured(AccessValueType);
			EndIf;
			If ByRefTypesForUpdate.Get(AccessValueType) = Undefined Then
				Ref = UsersInternal.ObjectRef2(AccessValue);
				Object = AccessValue;
			Else
				Ref = AccessValue;
			EndIf;
			CurLinks = CommonClientServer.ValueInArray(Ref);
		EndIf;
		
		NamesOfTablesToUpdate = New Array;
		ValuesByTypes = New Map;
		For Each CurrentRef In CurLinks Do
			RefType = TypeOf(CurrentRef);
			Values = ValuesByTypes.Get(RefType);
			If Values = Undefined Then
				AccessKindProperties = ByRefTypesForUpdate.Get(RefType);
				If AccessKindProperties = Undefined Then
					Raise ErrorTextTypeNotConfigured(RefType);
				EndIf;
				Values = New Array;
				ValuesByTypes.Insert(RefType, Values);
				NamesOfTablesToUpdate.Add(Metadata.FindByType(RefType).FullName());
			EndIf;
			If Not ValueIsFilled(CurrentRef) Then
				Continue;
			EndIf;
			If Values.Find(CurrentRef) = Undefined Then
				Values.Add(CurrentRef);
			EndIf;
		EndDo;
	EndIf;
	
	Query = New Query;
	
	If Object <> Undefined Then
		ObjectGroups = New ValueTable;
		ObjectGroups.Columns.Add("Ref", Metadata.DefinedTypes.AccessValue.Type);
		ObjectGroups.Columns.Add("AccessGroup", Metadata.DefinedTypes.AccessValue.Type);
		Query.SetParameter("CurrentTable", ObjectGroups);
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref,
		|	CurrentTable.AccessGroup AS AccessGroup
		|INTO CurrentValueTable
		|FROM
		|	&CurrentTable AS CurrentTable";
		Query.Text = Query.Text + Common.QueryBatchSeparator();
		Properties = ByRefTypesForUpdate.Get(TypeOf(Ref));
		Try
			If Properties.ValuesGroupsType = Type("Undefined") Then
				ObjectGroups.Add().Ref = Ref;
			ElsIf Properties.MultipleValuesGroups Then
				For Each TSRow In Object.AccessGroups Do
					NewRow = ObjectGroups.Add();
					NewRow.Ref = Ref;
					NewRow.AccessGroup = TSRow.AccessGroup;
				EndDo;
			Else
				NewRow = ObjectGroups.Add();
				NewRow.Ref = Ref;
				NewRow.AccessGroup = Object.AccessGroup;
			EndIf;
		Except
			CheckTablesMetadata(NamesOfTablesToUpdate, ByRefTypesForUpdate);
			Raise;
		EndTry;
	EndIf;
	
	QueryTemplateForRedundant =
	"SELECT
	|	AccessValuesGroups.AccessValue AS AccessValue,
	|	AccessValuesGroups.AccessValuesGroup AS AccessValuesGroup
	|FROM
	|	InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|		LEFT JOIN CurrentValueTable AS CurrentTable
	|		ON (CurrentTable.Ref = AccessValuesGroups.AccessValue)
	|			AND (CurrentTable.AccessGroup = AccessValuesGroups.AccessValuesGroup)
	|WHERE
	|	AccessValuesGroups.DataGroup = 0
	|	AND CurrentTable.Ref IS NULL
	|	AND &Filter1";
	
	QueryTemplateForMissing =
	"SELECT
	|	CurrentTable.Ref AS AccessValue,
	|	CurrentTable.AccessGroup AS AccessValuesGroup
	|FROM
	|	CurrentValueTable AS CurrentTable
	|		LEFT JOIN InformationRegister.AccessValuesGroups AS AccessValuesGroups
	|		ON (AccessValuesGroups.DataGroup = 0)
	|			AND CurrentTable.Ref = AccessValuesGroups.AccessValue
	|			AND CurrentTable.AccessGroup = AccessValuesGroups.AccessValuesGroup
	|WHERE
	|	AccessValuesGroups.AccessValue IS NULL
	|	AND &Filter2";
	
	QueriesTextsForMissing = New Array;
	QueriesTextsForRedundant = New Array;
	
	For Each TableName In NamesOfTablesToUpdate Do
		RefType = Type(StrReplace(TableName, ".", "Ref."));
		Properties = ByRefTypesForUpdate.Get(RefType);
		CurrentTableName = TableName;
		If Properties.ValuesGroupsType <> Type("Undefined") Then
			If Properties.MultipleValuesGroups Then
				CurrentTableName = TableName + ".AccessGroups";
			EndIf;
			FieldName = StrReplace("ISNULL(CAST(CurrentTable.AccessGroup AS %1),
				|				VALUE(%1.EmptyRef))",
				"%1", Metadata.FindByType(Properties.ValuesGroupsType).FullName());
		Else
			FieldName = "CurrentTable.Ref";
		EndIf;
		If Object <> Undefined Then
			CurrentTableName = "CurrentValueTable";
		EndIf;
		
		If AccessValue = Undefined Then
			Filter1 = "VALUETYPE(AccessValuesGroups.AccessValue) = TYPE(Catalog.Users)
			|	AND AccessValuesGroups.AccessValue <> VALUE(Catalog.Users.EmptyRef)";
			Filter2 = "TRUE";
		Else
			Filter1 = "CAST(AccessValuesGroups.AccessValue AS Catalog.Users) IN (&Values)";
			Filter2 = "CurrentTable.Ref IN (&Values)";
			ParameterName = StrReplace(TableName, ".", "_") + "_" + "Values";
			Query.SetParameter(ParameterName, ValuesByTypes.Get(RefType));
			Filter1 = StrReplace(Filter1, "&Values", "&" + ParameterName);
			Filter2 = StrReplace(Filter2, "&Values", "&" + ParameterName);
		EndIf;
		
		QueryTextForRedundant = StrReplace(QueryTemplateForRedundant, "&Filter1", Filter1);
		QueryTextForRedundant = StrReplace(QueryTextForRedundant, "CurrentValueTable", CurrentTableName);
		QueryTextForRedundant = StrReplace(QueryTextForRedundant, "CurrentTable.AccessGroup", FieldName);
		QueryTextForRedundant = StrReplace(QueryTextForRedundant, "Catalog.Users", TableName);
		QueriesTextsForRedundant.Add(QueryTextForRedundant);
		
		QueryTextForMissing = StrReplace(QueryTemplateForMissing, "&Filter2", Filter2);
		QueryTextForMissing = StrReplace(QueryTextForMissing, "CurrentValueTable", CurrentTableName);
		QueryTextForMissing = StrReplace(QueryTextForMissing, "CurrentTable.AccessGroup", FieldName);
		QueriesTextsForMissing.Add(QueryTextForMissing);
	EndDo;
	
	UnionAllText = Common.UnionAllText();
	
	Query.Text = Query.Text
		+ StrConcat(QueriesTextsForRedundant, UnionAllText)
		+ Common.QueryBatchSeparator()
		+ StrConcat(QueriesTextsForMissing, UnionAllText);
	
	Try
		QueryResults = Query.ExecuteBatch();
	Except
		CheckTablesMetadata(NamesOfTablesToUpdate, ByRefTypesForUpdate);
		Raise;
	EndTry;
	
	IndexOf = QueryResults.Count() - 2;
	If QueryResults[IndexOf].IsEmpty()
	   And QueryResults[IndexOf + 1].IsEmpty() Then
		Return;
	EndIf;
	
	// ACC:1319-off - The lock is set in the called procedure "UpdateFromQueryResult".
	Block = New DataLock;
	// ACC:1319-on
	
	If TypeOf(AccessValue) = Type("Array") And AccessValue.Count() <= 1000 Then
		For Each CurrentRef In AccessValue Do
			LockItem = Block.Add("InformationRegister.AccessValuesGroups");
			LockItem.SetValue("DataGroup", 0);
			LockItem.SetValue("AccessValue", CurrentRef);
		EndDo;
	Else
		LockItem = Block.Add("InformationRegister.AccessValuesGroups");
		LockItem.SetValue("DataGroup", 0);
		If AccessValue <> Undefined And TypeOf(AccessValue) <> Type("Array") Then
			LockItem.SetValue("AccessValue", Ref);
		EndIf;
	EndIf;
	
	IsNew = Object <> Undefined And Object.IsNew();
	
	UpdateFromQueryResult(Query,
		Block, ByRefTypesForUpdate, NamesOfTablesToUpdate, HasChanges, IsNew);
	
EndProcedure

// Intended for procedures "UpdateAccessValueGroups" and "UpdateEmptyAccessValuesGroups".
Procedure UpdateFromQueryResult(Query, Block,
			ByRefTypesForUpdate, NamesOfTablesToUpdate, HasChanges, IsNew = False)
	
	ValuesWithChangesByTypes = New Map;
	ProcessedTypes = New Map;
	
	BeginTransaction();
	Try
		Block.Lock();
		QueryResults = Query.ExecuteBatch();
		IndexOf = QueryResults.Count() - 2;
		
		If Not QueryResults[IndexOf].IsEmpty() Then
			RecordSet = InformationRegisters.AccessValuesGroups.CreateRecordSet();
			Selection = QueryResults[IndexOf].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.DataGroup.Set(0);
				RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
				RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
				RecordSet.Write(); // Delete unnecessary linkage records.
				
				ValueType = TypeOf(Selection.AccessValue);
				IsTypeProcessed = ProcessedTypes.Get(ValueType);
				If IsTypeProcessed <> True Then
					DoAddChanges(Selection.AccessValue,
						IsNew, ByRefTypesForUpdate, ValuesWithChangesByTypes, IsTypeProcessed);
					ProcessedTypes.Insert(ValueType, IsTypeProcessed);
				EndIf;
			EndDo;
			HasChanges = True;
		EndIf;
		
		If Not QueryResults[IndexOf + 1].IsEmpty() Then
			RecordSet = InformationRegisters.AccessValuesGroups.CreateRecordSet();
			Record = RecordSet.Add();
			Selection = QueryResults[IndexOf + 1].Select();
			
			While Selection.Next() Do
				RecordSet.Filter.AccessValue.Set(Selection.AccessValue);
				RecordSet.Filter.AccessValuesGroup.Set(Selection.AccessValuesGroup);
				RecordSet.Filter.DataGroup.Set(0);
				FillPropertyValues(Record, Selection);
				RecordSet.Write(); // Add missing linkage records.
				
				ValueType = TypeOf(Selection.AccessValue);
				IsTypeProcessed = ProcessedTypes.Get(ValueType);
				If IsTypeProcessed <> True Then
					DoAddChanges(Selection.AccessValue,
						IsNew, ByRefTypesForUpdate, ValuesWithChangesByTypes, IsTypeProcessed);
					ProcessedTypes.Insert(ValueType, IsTypeProcessed);
				EndIf;
			EndDo;
			HasChanges = True;
		EndIf;
		
		AccessManagementInternal.ScheduleUpdateOfDependentListsByValuesWithGroups(
			ValuesWithChangesByTypes);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		CheckTablesMetadata(NamesOfTablesToUpdate, ByRefTypesForUpdate);
		Raise;
	EndTry;
	
EndProcedure

// Intended for procedure "UpdateAccessGroupsWithFilledValues".
Procedure DoAddChanges(Ref, IsNew, ByRefTypesForUpdate, ValuesWithChangesByTypes, IsTypeProcessed)
	
	AccessKindProperties = ByRefTypesForUpdate.Get(TypeOf(Ref));
	IsTypeProcessed = True;
	
	If AccessKindProperties.ValuesGroupsType <> Type("Undefined") And Not IsNew Then
		CurrentRef = ValuesWithChangesByTypes.Get(AccessKindProperties.ValuesType);
		
		If CurrentRef = Undefined Then
			ValuesWithChangesByTypes.Insert(AccessKindProperties.ValuesType, Ref);
			IsTypeProcessed = False;
			
		ElsIf CurrentRef <> Ref Then
			ValuesWithChangesByTypes.Insert(AccessKindProperties.ValuesType, True);
		Else
			IsTypeProcessed = False;
		EndIf;
	EndIf;
	
EndProcedure

// Intended for procedure "UpdateAccessGroupsWithFilledValues".
Function ErrorTextTypeNotConfigured(AccessValueType)
	
	ErrorTitle =
		NStr("en = 'An error occurred when updating Access Value Groups.';")
		+ Chars.LF
		+ Chars.LF;
	
	ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'For type ""%1""
		           |usage of access value groups is not configured.';"),
		String(AccessValueType));
	
	Return ErrorText;
	
EndFunction

// Intended for procedure "UpdateAccessValueGroups".
Procedure CheckTablesMetadata(NamesOfTablesToUpdate, ByRefTypesForUpdate) Export
	
	ErrorTitle =
		NStr("en = 'An error occurred when updating Access Value Groups.';")
		+ Chars.LF
		+ Chars.LF;
	
	For Each TableName In NamesOfTablesToUpdate Do
		AccessValueType = Type(StrReplace(TableName, ".", "Ref."));
		AccessKindProperties = ByRefTypesForUpdate.Get(AccessValueType);
		TypeMetadata = Metadata.FindByType(AccessValueType);
		
		If AccessKindProperties.ValuesGroupsType = Type("Undefined") Then
			Continue;
			
		ElsIf AccessKindProperties.MultipleValuesGroups Then
			TabularSectionMetadata1 = TypeMetadata.TabularSections.Find("AccessGroups");
			
			If TabularSectionMetadata1 = Undefined
			 Or TabularSectionMetadata1.Attributes.Find("AccessGroup") = Undefined Then
				
				ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Special tabular section ""%2""
					           |with special attribute ""%3"" is not created
					           |for access value type ""%1"".';"),
					String(AccessValueType),
					"AccessGroups",
					"AccessGroup");
				Raise ErrorText;
			EndIf;
			
		ElsIf TypeMetadata.Attributes.Find("AccessGroup") = Undefined Then
			ErrorText = ErrorTitle + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Special attribute ""%2""
				           |is not created for access value type ""%1"".';"),
				String(AccessValueType), "AccessGroup");
			Raise ErrorText;
		EndIf;
	EndDo;
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User 1 - The same User.
//
//                               1 - User group
//                                   of the same user.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user 1 - The same External user.
//
//                               1 - External user group
//                                   of the same external user.
//
Procedure UpdateUsers(Users1 = Undefined,
                                HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT
	|	UserGroupCompositions.User AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	1 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.User,
	|	UserGroupCompositions.UsersGroup,
	|	1,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",       "&UserFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",          "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Users1, "Users",
		"&UserFilterCriterion1:UserGroupCompositions.User
		|&UserFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 1, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 1));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// User group 2 - The same User group.
//
//                               2 - A user
//                                   of the same user group.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// External user group 2 - The same External user group.
//
//                               2 - An external user
//                                   from the same external user group.
//
//
Procedure UpdateUserGroups(UserGroups = Undefined,
                                      HasChanges       = Undefined)
	
	SetPrivilegedMode(True);
	
	QueryText =
	"SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	2 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND &UserGroupFilterCriterion1
	|
	|UNION ALL
	|
	|SELECT
	|	UserGroupCompositions.UsersGroup,
	|	UserGroupCompositions.User,
	|	2,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|WHERE
	|	VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers)
	|	AND &UserGroupFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&UserGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query = New Query;
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, UserGroups, "UserGroups",
		"&UserGroupFilterCriterion1:UserGroupCompositions.UsersGroup
		|&UserGroupFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 2, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 2));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// A) for the Users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentUser}.
//
// Assignee group 3 - A user
//                                   of the same assignee group.
//
//                               3 - User group
//                                   of the same assignee group user.
//
// B) for the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Assignee group 3 - An external user
//                                   of the same assignee group.
//
//                               3 - An external user group
//                                   of an external user
//                                   of the same assignee group.
//
Procedure UpdatePerformersGroups(PerformersGroups = Undefined,
                                     Assignees        = Undefined,
                                     HasChanges      = Undefined)
	
	SetPrivilegedMode(True);
	
	// Prepare a table with additional user (assignee) groups.
	// 
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If PerformersGroups = Undefined
	   And Assignees        = Undefined Then
	
		ParameterContent = Undefined;
		ParameterValue   = Undefined;
	
	ElsIf PerformersGroups <> Undefined Then
		ParameterContent = "PerformersGroups";
		ParameterValue   = PerformersGroups;
		
	ElsIf Assignees <> Undefined Then
		ParameterContent = "Assignees";
		ParameterValue   = Assignees;
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Error in procedure %1
			           |of the %2 information register manager module.
			           |
			           |Some parameters are invalid.';"),
			"UpdatePerformersGroups",
			"AccessValuesGroups");
		Raise ErrorText;
	EndIf;
	
	NoPerformerGroups = True;
	SSLSubsystemsIntegration.OnDeterminePerformersGroups(Query.TempTablesManager,
		ParameterContent, ParameterValue, NoPerformerGroups);
	
	If NoPerformerGroups Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.DataGroup.Set(3);
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		Return;
	EndIf;
	
	// Preparing selected links of assignees and assignee groups.
	Query.SetParameter("EmptyValueGroupsReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValuesGroup").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueGroupsReferences.EmptyRef
	|INTO EmptyValueGroupsReferences
	|FROM
	|	&EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|
	|INDEX BY
	|	EmptyValueGroupsReferences.EmptyRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User
	|INTO AssigneeGroupsUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.Users)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.Users.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PerformerGroupsTable.PerformersGroup,
	|	PerformerGroupsTable.User AS ExternalUser
	|INTO ExternalPerformerGroupUsers
	|FROM
	|	PerformerGroupsTable AS PerformerGroupsTable
	|		INNER JOIN EmptyValueGroupsReferences AS EmptyValueGroupsReferences
	|		ON (VALUETYPE(PerformerGroupsTable.PerformersGroup) = VALUETYPE(EmptyValueGroupsReferences.EmptyRef))
	|			AND PerformerGroupsTable.PerformersGroup <> EmptyValueGroupsReferences.EmptyRef
	|WHERE
	|	VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.UserGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.Users)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsersGroups)
	|	AND VALUETYPE(PerformerGroupsTable.PerformersGroup) <> TYPE(Catalog.ExternalUsers)
	|	AND VALUETYPE(PerformerGroupsTable.User) = TYPE(Catalog.ExternalUsers)
	|	AND PerformerGroupsTable.User <> VALUE(Catalog.ExternalUsers.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PerformerGroupsTable";
	
	If PerformersGroups = Undefined
	   And Assignees <> Undefined Then
		
		// ACC:96-off - No.434. Using JOIN is acceptable as the rows should be unique and
		// the dataset is small (from units to hundreds).
		QueryText =
		"SELECT
		|	AssigneeGroupsUsers.PerformersGroup
		|FROM
		|	AssigneeGroupsUsers AS AssigneeGroupsUsers
		|
		|UNION
		|
		|SELECT
		|	ExternalPerformerGroupUsers.PerformersGroup
		|FROM
		|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers";
		// ACC:96-on
		
		Query.Text = TemporaryTablesQueriesText + "
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|" + QueryText;
		
		QueriesResults = Query.ExecuteBatch();
		Count = QueriesResults.Count();
		
		PerformersGroups = QueriesResults[Count-1].Unload().UnloadColumn("PerformersGroup");
		TemporaryTablesQueriesText = Undefined;
	EndIf;
	
	QueryText =
	"SELECT
	|	AssigneeGroupsUsers.PerformersGroup AS AccessValue,
	|	AssigneeGroupsUsers.User AS AccessValuesGroup,
	|	3 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AssigneeGroupsUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	AssigneeGroupsUsers AS AssigneeGroupsUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON AssigneeGroupsUsers.User = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.UserGroups))
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	ExternalPerformerGroupUsers.ExternalUser,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	ExternalPerformerGroupUsers.PerformersGroup,
	|	UserGroupCompositions.UsersGroup,
	|	3,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	ExternalPerformerGroupUsers AS ExternalPerformerGroupUsers
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON ExternalPerformerGroupUsers.ExternalUser = UserGroupCompositions.User
	|			AND (VALUETYPE(UserGroupCompositions.UsersGroup) = TYPE(Catalog.ExternalUsersGroups))";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue",         "&AssigneeGroupFilterCriterion"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",            "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, PerformersGroups, "PerformersGroups",
		"&AssigneeGroupFilterCriterion:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 3, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 3));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

// Updates user groups to check allowed values
// for the Users and ExternalUsers access kinds.
//
// <AccessValue field components> <AccessValuesGroup field components>.
//                               <DataGroup field components>.
//
// For the External users access kind:
// {comparing with T.<field>} {Comparing with AccessGroupsValues.AccessValue}.
//                                  {Comparing with &CurrentExternalUser}.
//
// Authorization object 4 - An external user
//                                   of the same authorization object.
//
//                               4 - An external user group
//                                   of an external user
//                                   of the same authorization object.
//
Procedure UpdateAuthorizationObjects(AuthorizationObjects = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("EmptyValueReferences",
		AccessManagementInternalCached.BlankSpecifiedTypesRefsTable(
			"InformationRegister.AccessValuesGroups.Dimension.AccessValue").Get());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	EmptyValueReferences.EmptyRef
	|INTO EmptyValueReferences
	|FROM
	|	&EmptyValueReferences AS EmptyValueReferences
	|
	|INDEX BY
	|	EmptyValueReferences.EmptyRef";
	
	QueryText =
	"SELECT
	|	CAST(UserGroupCompositions.User AS Catalog.ExternalUsers).AuthorizationObject AS AccessValue,
	|	UserGroupCompositions.UsersGroup AS AccessValuesGroup,
	|	4 AS DataGroup,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		INNER JOIN Catalog.ExternalUsers AS ExternalUsers
	|		ON (VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers))
	|			AND UserGroupCompositions.User = ExternalUsers.Ref
	|		INNER JOIN EmptyValueReferences AS EmptyValueReferences
	|		ON (VALUETYPE(ExternalUsers.AuthorizationObject) = VALUETYPE(EmptyValueReferences.EmptyRef))
	|			AND (ExternalUsers.AuthorizationObject <> EmptyValueReferences.EmptyRef)
	|WHERE
	|	&AuthorizationObjectFilterCriterion1";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessValue", "&AuthorizationObjectFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesGroup"));
	Fields.Add(New Structure("DataGroup",    "&UpdatedDataGroupFilterCriterion"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessValuesGroups", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AuthorizationObjects, "AuthorizationObjects",
		"&AuthorizationObjectFilterCriterion1:ExternalUsers.AuthorizationObject
		|&AuthorizationObjectFilterCriterion2:OldData.AccessValue");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, 4, "DataGroup",
		"&UpdatedDataGroupFilterCriterion:OldData.DataGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessValuesGroups);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FixedFilter",    New Structure("DataGroup", 4));
	
	AccessManagementInternal.UpdateInformationRegister(Data, HasChanges);
	
EndProcedure

#EndRegion

#EndIf