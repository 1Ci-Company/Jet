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
	
	AccessManagementInternal.BeforeExportRecordSet(Container, ObjectExportManager, Serializer, Object, Artifacts, Cancel);
	
EndProcedure

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#Region Private

// The procedure updates register data when changing
// - allowed access group values,
// - allowed access group profile values,
// - access kind usage.
//
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups
//                - Array - array of values of the types specified above.
//                - Undefined - without filter.
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(AccessGroups = Undefined, HasChanges = Undefined) Export
	
	Block = New DataLock;
	
	If AccessGroups = Undefined Then
		Block.Add("InformationRegister.AccessGroupsValues");
		Block.Add("InformationRegister.DefaultAccessGroupsValues");
	Else
		LockValues = ?(TypeOf(AccessGroups) = Type("Array"), AccessGroups,
			CommonClientServer.ValueInArray(AccessGroups));
		For Each ValueOfLock In LockValues Do
			LockItem = Block.Add("InformationRegister.AccessGroupsValues");
			LockItem.SetValue("AccessGroup", ValueOfLock);
			LockItem = Block.Add("InformationRegister.DefaultAccessGroupsValues");
			LockItem.SetValue("AccessGroup", ValueOfLock);
		EndDo;
	EndIf;
	
	If Common.FileInfobase() Then
		LockItem = Block.Add("Catalog.AccessGroupProfiles");
		LockItem.Mode = DataLockMode.Shared;
		LockItem = Block.Add("Catalog.AccessGroups");
		LockItem.Mode = DataLockMode.Shared;
		LockItem = Block.Add("InformationRegister.UsedAccessKinds");
		LockItem.Mode = DataLockMode.Shared;
		If TransactionActive() Then
			// ACC:1320:off - No.783.1.3. It's acceptable to call a lock in a transaction external to the file infobase.
			// It is intended to avoid deadlocks caused by an automatic shared
			// lock set to the table when it is read by a query within a transaction.
			Block.Lock();
			// ACC:1320-on
		EndIf;
	EndIf;
	
	ProfileAdministrator = AccessManagement.ProfileAdministrator();
	
	BeginTransaction();
	Try
		Block.Lock();
		
		UsedAccessKinds = New ValueTable;
		UsedAccessKinds.Columns.Add("AccessKind", Metadata.DefinedTypes.AccessValue.Type);
		UsedAccessKinds.Columns.Add("AccessKindUsers",        New TypeDescription("Boolean"));
		UsedAccessKinds.Columns.Add("AccessKindExternalUsers", New TypeDescription("Boolean"));
		
		AccessRestrictionEnabled = Constants.LimitAccessAtRecordLevel.Get();
		If AccessManagement.LimitAccessAtRecordLevel() <> AccessRestrictionEnabled Then
			RefreshReusableValues();
		EndIf;
		AccessKindsProperties = AccessManagementInternal.AccessKindsProperties();
		AllUsedAccessKinds = AccessManagementInternal.UsedAccessKinds();
		
		For Each AccessKindProperties In AccessKindsProperties.Array Do
			If AllUsedAccessKinds.Get(AccessKindProperties.Ref) = Undefined Then
				Continue;
			EndIf;
			NewRow = UsedAccessKinds.Add();
			NewRow.AccessKind = AccessKindProperties.Ref;
			NewRow.AccessKindUsers        = (AccessKindProperties.Name = "Users");
			NewRow.AccessKindExternalUsers = (AccessKindProperties.Name = "ExternalUsers");
		EndDo;
		
		UpdateAllowedValues(UsedAccessKinds,
			AccessGroups, HasChanges, ProfileAdministrator);
		
		UpdateDefaultAllowedValues(UsedAccessKinds,
			AccessGroups, HasChanges, ProfileAdministrator);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure UpdateAllowedValues(UsedAccessKinds,
			AccessGroups, HasChanges, ProfileAdministrator)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("AccessKindsGroupsAndValuesTypes",
		AccessManagementInternalCached.AccessKindsGroupsAndValuesTypes());
		
	Query.SetParameter("SelectedAccessValues",
		SelectedAccessValues(AccessGroups, ProfileAdministrator));
	
	TemporaryTablesQueriesText =
	"SELECT
	|	SelectedAccessValues.Value AS Value,
	|	SelectedAccessValues.ValueInHierarchy AS ValueInHierarchy
	|INTO SelectedAccessValues
	|FROM
	|	&SelectedAccessValues AS SelectedAccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	UsedAccessKinds.AccessKindUsers AS AccessKindUsers,
	|	UsedAccessKinds.AccessKindExternalUsers AS AccessKindExternalUsers
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Purpose.Ref AS Profile,
	|	MIN(VALUETYPE(Purpose.UsersType) = TYPE(Catalog.Users)) AS OnlyForUsers,
	|	MIN(VALUETYPE(Purpose.UsersType) <> TYPE(Catalog.Users)
	|			AND Purpose.UsersType <> UNDEFINED) AS ForExternalUsersOnly
	|INTO ProfilesPurpose
	|FROM
	|	Catalog.AccessGroupProfiles.Purpose AS Purpose
	|
	|GROUP BY
	|	Purpose.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesPurpose.Profile AS Profile,
	|	UsedAccessKinds.AccessKind AS AccessKind
	|INTO ProfileAccessKindsAllDenied
	|FROM
	|	UsedAccessKinds AS UsedAccessKinds
	|		INNER JOIN ProfilesPurpose AS ProfilesPurpose
	|		ON (UsedAccessKinds.AccessKindUsers
	|					AND NOT ProfilesPurpose.OnlyForUsers
	|				OR UsedAccessKinds.AccessKindExternalUsers
	|					AND NOT ProfilesPurpose.ForExternalUsersOnly)
	|
	|INDEX BY
	|	ProfilesPurpose.Profile,
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS GroupAndValueType
	|INTO AccessKindsGroupsAndValuesTypes
	|FROM
	|	&AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|
	|INDEX BY
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType,
	|	AccessKindsGroupsAndValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> &ProfileAdministrator)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Profile AS Profile,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessValues.AccessKind AS AccessKind,
	|	ProfileAccessValues.AccessValue AS AccessValue,
	|	ProfileAccessValues.IncludeSubordinateAccessValues AS IncludeSubordinateAccessValues,
	|	CASE
	|		WHEN ProfileAccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ValueAllowed
	|INTO ValuesSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.Predefined)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessValues AS ProfileAccessValues
	|		ON (ProfileAccessValues.Ref = ProfileAccessKinds.Ref)
	|			AND (ProfileAccessValues.AccessKind = ProfileAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroups.Profile,
	|	AccessGroups.Ref,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue,
	|	AccessValues.IncludeSubordinateAccessValues,
	|	CASE
	|		WHEN AccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (NOT SpecifiedAccessKinds.Predefined)
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValues
	|		ON (AccessValues.Ref = AccessGroups.Ref)
	|			AND (AccessValues.AccessKind = AccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ValuesSettings.AccessGroup AS AccessGroup,
	|	CASE
	|		WHEN ValuesSettings.IncludeSubordinateAccessValues
	|			THEN SelectedAccessValues.ValueInHierarchy
	|		ELSE ValuesSettings.AccessValue
	|	END AS AccessValue,
	|	MAX(ValuesSettings.ValueAllowed) AS ValueAllowed
	|INTO NewData
	|FROM
	|	ValuesSettings AS ValuesSettings
	|		INNER JOIN AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		ON ValuesSettings.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind
	|			AND (VALUETYPE(ValuesSettings.AccessValue) = VALUETYPE(AccessKindsGroupsAndValuesTypes.GroupAndValueType))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON ValuesSettings.AccessKind = UsedAccessKinds.AccessKind
	|			AND (NOT (ValuesSettings.Profile, ValuesSettings.AccessKind) IN
	|					(SELECT
	|						ProfileAccessKindsAllDenied.Profile,
	|						ProfileAccessKindsAllDenied.AccessKind
	|					FROM
	|						ProfileAccessKindsAllDenied AS ProfileAccessKindsAllDenied))
	|		LEFT JOIN SelectedAccessValues AS SelectedAccessValues
	|		ON ValuesSettings.AccessValue = SelectedAccessValues.Value
	|
	|GROUP BY
	|	ValuesSettings.AccessGroup,
	|	CASE
	|		WHEN ValuesSettings.IncludeSubordinateAccessValues
	|			THEN SelectedAccessValues.ValueInHierarchy
	|		ELSE ValuesSettings.AccessValue
	|	END
	|
	|INDEX BY
	|	ValuesSettings.AccessGroup,
	|	AccessValue,
	|	ValueAllowed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ValuesSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValue,
	|	NewData.ValueAllowed,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValue"));
	Fields.Add(New Structure("ValueAllowed"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupsValues", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessGroupsValues);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FilterDimensions",       "AccessGroup");
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
		EndIf;
		
		If HasCurrentChanges
		   And AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Schedule an access update.
			BlankRefsByTypes = AccessManagementInternalCached.BlankRefsOfGroupsAndValuesTypes();
			ChangesContent = New ValueTable;
			ChangesContent.Columns.Add("AccessGroup", New TypeDescription("CatalogRef.AccessGroups"));
			ChangesContent.Columns.Add("AccessValuesType", Metadata.DefinedTypes.AccessValue.Type);
			
			For Each String In Data.EditStringContent Do
				BlankRefs = BlankRefsByTypes.Get(TypeOf(String.AccessValue));
				If BlankRefs <> Undefined Then
					For Each EmptyRef In BlankRefs Do
						NewRow = ChangesContent.Add();
						NewRow.AccessGroup = String.AccessGroup;
						NewRow.AccessValuesType = EmptyRef;
					EndDo;
				EndIf;
			EndDo;
			ChangesContent.GroupBy("AccessGroup, AccessValuesType");
			
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAllowedValues(ChangesContent);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateDefaultAllowedValues(UsedAccessKinds,
			AccessGroups, HasChanges, ProfileAdministrator)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("AccessKindsGroupsAndValuesTypes",
		AccessManagementInternalCached.AccessKindsGroupsAndValuesTypes());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	UsedAccessKinds.AccessKindUsers AS AccessKindUsers,
	|	UsedAccessKinds.AccessKindExternalUsers AS AccessKindExternalUsers
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Purpose.Ref AS Profile,
	|	MIN(VALUETYPE(Purpose.UsersType) = TYPE(Catalog.Users)) AS OnlyForUsers,
	|	MIN(VALUETYPE(Purpose.UsersType) <> TYPE(Catalog.Users)
	|			AND Purpose.UsersType <> UNDEFINED) AS ForExternalUsersOnly
	|INTO ProfilesPurpose
	|FROM
	|	Catalog.AccessGroupProfiles.Purpose AS Purpose
	|
	|GROUP BY
	|	Purpose.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesPurpose.Profile AS Profile,
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	FALSE AS FalseValue
	|INTO ProfileAccessKindsAllDenied
	|FROM
	|	UsedAccessKinds AS UsedAccessKinds
	|		INNER JOIN ProfilesPurpose AS ProfilesPurpose
	|		ON (UsedAccessKinds.AccessKindUsers
	|					AND NOT ProfilesPurpose.OnlyForUsers
	|				OR UsedAccessKinds.AccessKindExternalUsers
	|					AND NOT ProfilesPurpose.ForExternalUsersOnly)
	|
	|INDEX BY
	|	ProfilesPurpose.Profile,
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS GroupAndValueType
	|INTO AccessKindsGroupsAndValuesTypes
	|FROM
	|	&AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|
	|INDEX BY
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType,
	|	AccessKindsGroupsAndValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> &ProfileAdministrator)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessKinds.AccessKind AS AccessKind,
	|	ProfileAccessKinds.AllAllowed AS AllAllowed
	|INTO AccessKindsSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.Predefined)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (ProfileAccessKinds.AccessKind = UsedAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (NOT SpecifiedAccessKinds.Predefined)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (AccessKinds.AccessKind = UsedAccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValuesSettings.AccessGroup AS AccessGroup,
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	TRUE AS WithSettings
	|INTO HasValueSettings
	|FROM
	|	AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		INNER JOIN InformationRegister.AccessGroupsValues AS ValuesSettings
	|		ON (VALUETYPE(AccessKindsGroupsAndValuesTypes.GroupAndValueType) = VALUETYPE(ValuesSettings.AccessValue))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON AccessKindsGroupsAndValuesTypes.AccessKind = UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS AccessValuesType,
	|	MAX(ISNULL(ProfileAccessKindsAllDenied.FalseValue, ISNULL(AccessKindsSettings.AllAllowed, TRUE))) AS AllAllowed,
	|	MAX(ISNULL(ProfileAccessKindsAllDenied.FalseValue, AccessKindsSettings.AllAllowed IS NULL)) AS AccessKindNotUsed,
	|	MAX(ISNULL(HasValueSettings.WithSettings, FALSE)) AS WithSettings
	|INTO TemplateForNewData
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		ON (TRUE)
	|		LEFT JOIN ProfileAccessKindsAllDenied AS ProfileAccessKindsAllDenied
	|		ON (ProfileAccessKindsAllDenied.Profile = AccessGroups.Profile)
	|			AND (ProfileAccessKindsAllDenied.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind)
	|		LEFT JOIN AccessKindsSettings AS AccessKindsSettings
	|		ON (AccessKindsSettings.AccessGroup = AccessGroups.Ref)
	|			AND (AccessKindsSettings.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind)
	|		LEFT JOIN HasValueSettings AS HasValueSettings
	|		ON (HasValueSettings.AccessGroup = AccessKindsSettings.AccessGroup)
	|			AND (HasValueSettings.AccessKind = AccessKindsSettings.AccessKind)
	|
	|GROUP BY
	|	AccessGroups.Ref,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemplateForNewData.AccessGroup AS AccessGroup,
	|	TemplateForNewData.AccessValuesType AS AccessValuesType,
	|	TemplateForNewData.AllAllowed AS AllAllowed,
	|	CASE
	|		WHEN TemplateForNewData.AllAllowed = TRUE
	|				AND TemplateForNewData.WithSettings = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AllAllowedWithoutExceptions,
	|	TemplateForNewData.AccessKindNotUsed AS NoSettings
	|INTO NewData
	|FROM
	|	TemplateForNewData AS TemplateForNewData
	|
	|INDEX BY
	|	TemplateForNewData.AccessGroup,
	|	TemplateForNewData.AccessValuesType,
	|	TemplateForNewData.AllAllowed,
	|	AllAllowedWithoutExceptions,
	|	NoSettings
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP AccessKindsSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValuesType,
	|	NewData.AllAllowed,
	|	NewData.AllAllowedWithoutExceptions,
	|	NewData.NoSettings,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesType"));
	Fields.Add(New Structure("AllAllowed"));
	Fields.Add(New Structure("AllAllowedWithoutExceptions"));
	Fields.Add(New Structure("NoSettings"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.DefaultAccessGroupsValues", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.DefaultAccessGroupsValues);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FilterDimensions",       "AccessGroup");
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
			ChangesContent = Data.EditStringContent.Copy(, "AccessValuesType");
			ChangesContent.GroupBy("AccessValuesType");
			ChangingValueTypes = ChangesContent.UnloadColumn("AccessValuesType");
			InformationRegisters.UsedAccessKindsByTables.UpdateRegisterData(, ChangingValueTypes);
		EndIf;
		
		If HasCurrentChanges
		   And AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Schedule an access update.
			ChangesContent = Data.EditStringContent.Copy(, "AccessGroup, AccessValuesType");
			ChangesContent.GroupBy("AccessGroup, AccessValuesType");
			
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAllowedValues(ChangesContent);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function SelectedAccessValues(AccessGroups, ProfileAdministrator)
	
	QueryText =
	"SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> &ProfileAdministrator)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	Ref,
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUETYPE(AccessGroupsAccessValues.AccessValue) AS ValueType,
	|	AccessGroupsAccessValues.AccessValue AS AccessValue
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		INNER JOIN AccessGroups AS AccessGroups
	|		ON AccessGroupsAccessValues.Ref = AccessGroups.Ref
	|WHERE
	|	AccessGroupsAccessValues.IncludeSubordinateAccessValues
	|
	|GROUP BY
	|	VALUETYPE(AccessGroupsAccessValues.AccessValue),
	|	AccessGroupsAccessValues.AccessValue
	|
	|UNION ALL
	|
	|SELECT
	|	VALUETYPE(AccessGroupProfilesAccessValues.AccessValue),
	|	AccessGroupProfilesAccessValues.AccessValue
	|FROM
	|	Catalog.AccessGroupProfiles.AccessValues AS AccessGroupProfilesAccessValues
	|		INNER JOIN AccessGroups AS AccessGroups
	|		ON AccessGroupProfilesAccessValues.Ref = AccessGroups.Profile
	|WHERE
	|	AccessGroupProfilesAccessValues.IncludeSubordinateAccessValues
	|
	|GROUP BY
	|	VALUETYPE(AccessGroupProfilesAccessValues.AccessValue),
	|	AccessGroupProfilesAccessValues.AccessValue";
	
	Query = New Query(QueryText);
	Query.SetParameter("ProfileAdministrator", ProfileAdministrator);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref");
	
	AccessValuesSettings = Query.Execute().Unload();
	
	Query = New Query;
	
	QueriesTexts = New Array;
	For IndexOf = 0 To AccessValuesSettings.Count() - 1 Do
		Setting = AccessValuesSettings[IndexOf];
		
		MetadataObject = Metadata.FindByType(Setting.ValueType);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		QueryText = 
		"SELECT
		|	&AccessValue AS Value,
		|	Table.Ref AS ValueInHierarchy
		|FROM
		|	&Table AS Table
		|WHERE
		|	Table.Ref IN HIERARCHY(&AccessValue)";
		
		QueryText = StrReplace(QueryText, "&Table", MetadataObject.FullName());
		QueryText = StrReplace(QueryText, "&AccessValue", "&AccessValue" + XMLString(IndexOf));
		Query.SetParameter("AccessValue" + XMLString(IndexOf), Setting.AccessValue);
		QueriesTexts.Add(QueryText);
	EndDo;
	
	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF);
	Query.Text = QueryText;
	
	If ValueIsFilled(QueryText) Then
		Result = Query.Execute().Unload();
	Else
		Result = New ValueTable;
		Result.Columns.Add("Value", Metadata.DefinedTypes.AccessValue.Type);
		Result.Columns.Add("ValueInHierarchy", Metadata.DefinedTypes.AccessValue.Type);
	EndIf;
	
	Return Result;
	
EndFunction


#EndRegion

#EndIf
