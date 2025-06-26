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

// Updates the register data based on the result of changing the role rights
// saved when updating the RolesRights information register.
//
Procedure UpdateRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.RoleRightMetadataObjects");
	
	If LastChanges = Undefined Then
		UpdateRegisterData();
	Else
		MetadataObjects = New Array;
		For Each ChangesPart In LastChanges Do
			If TypeOf(ChangesPart) = Type("FixedArray") Then
				For Each MetadataObject In ChangesPart Do
					If MetadataObjects.Find(MetadataObject) = Undefined Then
						MetadataObjects.Add(MetadataObject);
					EndIf;
				EndDo;
			Else
				MetadataObjects = Undefined;
				Break;
			EndIf;
		EndDo;
		
		UpdateRegisterData(, MetadataObjects);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Updates the register data when changing the profile role content or
// access group profiles.
//
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups
//                - Array - values of the type specified above.
//                - Undefined - without filter.
//
//  Tables       - CatalogRef.MetadataObjectIDs
//                - CatalogRef.ExtensionObjectIDs
//                - Array - values of the type specified above.
//
//  HasChanges - Boolean - (return value) - if recorded,
//                  True is set, otherwise, it does not change.
//
Procedure UpdateRegisterData(AccessGroups = Undefined,
                                 Tables       = Undefined,
                                 HasChanges = Undefined) Export
	
	If TypeOf(Tables) = Type("Array") Or TypeOf(Tables) = Type("FixedArray") Then
		RecordsCount = Tables.Count();
		If RecordsCount = 0 Then
			Return;
		ElsIf RecordsCount > 500 Then
			Tables = Undefined;
		EndIf;
	EndIf;
	
	InformationRegisters.RolesRights.CheckRegisterData();
	
	SetPrivilegedMode(True);
	
	BlankRecordsQuery = New Query;
	BlankRecordsQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.Table = VALUE(Catalog.MetadataObjectIDs.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AccessGroupsTables AS AccessGroupsTables
	|WHERE
	|	AccessGroupsTables.AccessGroup = VALUE(Catalog.AccessGroups.EmptyRef)";
	
	TemporaryTablesQueriesText =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
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
	|	ExtensionsRolesRights.RightUpdate AS RightUpdate,
	|	ExtensionsRolesRights.AddRight AS AddRight,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight
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
	|	RolesRights.RightUpdate,
	|	RolesRights.AddRight,
	|	RolesRights.UnrestrictedReadRight,
	|	RolesRights.UnrestrictedUpdateRight,
	|	RolesRights.UnrestrictedAddRight
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
	|SELECT DISTINCT
	|	AccessGroups.Profile AS Ref
	|INTO Profiles
	|FROM
	|	AccessGroups AS AccessGroups
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesRoles.Ref AS Profile,
	|	RolesRights.MetadataObject AS Table,
	|	RolesRights.MetadataObject.EmptyRefValue AS TableType,
	|	MAX(RolesRights.RightUpdate) AS RightUpdate,
	|	MAX(RolesRights.RightUpdate)
	|		AND MAX(RolesRights.AddRight) AS AddRight,
	|	MAX(RolesRights.UnrestrictedReadRight) AS UnrestrictedReadRight,
	|	MAX(RolesRights.UnrestrictedUpdateRight) AS UnrestrictedUpdateRight,
	|	MAX(RolesRights.UnrestrictedUpdateRight)
	|		AND MAX(RolesRights.UnrestrictedAddRight) AS UnrestrictedAddRight
	|INTO ProfileTables
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|		INNER JOIN Profiles AS Profiles
	|		ON (Profiles.Ref = ProfilesRoles.Ref)
	|		INNER JOIN RolesRights AS RolesRights
	|		ON (&TableFilterCriterion1)
	|			AND (RolesRights.Role = ProfilesRoles.Role)
	|			AND (NOT RolesRights.Role.DeletionMark)
	|			AND (NOT RolesRights.MetadataObject.DeletionMark)
	|
	|GROUP BY
	|	ProfilesRoles.Ref,
	|	RolesRights.MetadataObject,
	|	RolesRights.MetadataObject.EmptyRefValue
	|
	|INDEX BY
	|	RolesRights.MetadataObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfileTables.Table AS Table,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileTables.RightUpdate AS RightUpdate,
	|	ProfileTables.AddRight AS AddRight,
	|	ProfileTables.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ProfileTables.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ProfileTables.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ProfileTables.TableType AS TableType
	|INTO NewData
	|FROM
	|	ProfileTables AS ProfileTables
	|		INNER JOIN AccessGroups AS AccessGroups
	|		ON (AccessGroups.Profile = ProfileTables.Profile)
	|
	|INDEX BY
	|	ProfileTables.Table,
	|	AccessGroups.Ref";
	
	QueryText =
	"SELECT
	|	NewData.Table,
	|	NewData.AccessGroup,
	|	NewData.RightUpdate,
	|	NewData.AddRight,
	|	NewData.UnrestrictedReadRight,
	|	NewData.UnrestrictedUpdateRight,
	|	NewData.UnrestrictedAddRight,
	|	NewData.TableType,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("Table",       "&TableFilterCriterion2"));
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("RightUpdate"));
	Fields.Add(New Structure("AddRight"));
	Fields.Add(New Structure("UnrestrictedReadRight"));
	Fields.Add(New Structure("UnrestrictedUpdateRight"));
	Fields.Add(New Structure("UnrestrictedAddRight"));
	Fields.Add(New Structure("TableType"));
	
	Query = New Query;
	Query.SetParameter("ProfileAdministrator", AccessManagement.ProfileAdministrator());
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupsTables", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, Tables, "Tables",
		"&TableFilterCriterion1:RolesRights.MetadataObject
		|&TableFilterCriterion2:OldData.Table");
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
		
	Block = New DataLock;
	If AccessGroups = Undefined Then
		Block.Add("InformationRegister.AccessGroupsTables");
	Else
		LockValues = ?(TypeOf(AccessGroups) = Type("Array"), AccessGroups,
			CommonClientServer.ValueInArray(AccessGroups));
		For Each ValueOfLock In LockValues Do
			LockItem = Block.Add("InformationRegister.AccessGroupsTables");
			LockItem.SetValue("AccessGroup", ValueOfLock);
		EndDo;
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		Results = BlankRecordsQuery.ExecuteBatch();
		If Not Results[0].IsEmpty() Then
			RecordSet = CreateRecordSet();
			RecordSet.Filter.Table.Set(Catalogs.MetadataObjectIDs.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		If Not Results[1].IsEmpty() Then
			RecordSet = CreateRecordSet();
			RecordSet.Filter.AccessGroup.Set(Catalogs.AccessGroups.EmptyRef());
			RecordSet.Write();
			HasChanges = True;
		EndIf;
		
		If AccessGroups <> Undefined
		   And Tables        = Undefined Then
			
			FilterDimensions = "AccessGroup";
		Else
			FilterDimensions = Undefined;
		EndIf;
		
		Data = New Structure;
		Data.Insert("RegisterManager",      InformationRegisters.AccessGroupsTables);
		Data.Insert("EditStringContent", Query.Execute().Unload());
		Data.Insert("FilterDimensions",       FilterDimensions);
		
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
			ChangesContent = Data.EditStringContent.Copy(, "Table");
			ChangesContent.GroupBy("Table");
			ChangingTables = ChangesContent.UnloadColumn("Table");
			InformationRegisters.UsedAccessKindsByTables.UpdateRegisterData(ChangingTables);
		EndIf;
		
		If HasCurrentChanges
		   And AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Schedule an access update.
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAccessGroupsTables(ChangesContent);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
