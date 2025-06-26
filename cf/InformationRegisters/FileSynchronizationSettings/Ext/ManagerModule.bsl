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

// Returns:
//   ValueTable:
//   * FileOwner - AnyRef
//   * OwnerID - CatalogRef.MetadataObjectIDs
//   * IsCatalogItemSetup - Boolean
//   * FileOwnerType - CatalogRef.MetadataObjectIDs
//   * FilterRule - ValueStorage
//   * IsFile - Boolean
//   * Synchronize - Boolean
//   * Account - CatalogRef.FileSynchronizationAccounts
//   * Description - String
//
Function CurrentSynchronizationSettings() Export
	
	SetPrivilegedMode(True);
	
	RefreshSynchronizationSettings();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	MetadataObjectIDs.Ref AS OwnerID,
		|	CASE
		|		WHEN VALUETYPE(MetadataObjectIDs.Ref) <> VALUETYPE(FileSynchronizationSettings.FileOwner)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsCatalogItemSetup,
		|	FileSynchronizationSettings.FileOwnerType,
		|	FileSynchronizationSettings.FilterRule,
		|	FileSynchronizationSettings.IsFile,
		|	FileSynchronizationSettings.Synchronize,
		|	FileSynchronizationSettings.Account,
		|	FileSynchronizationSettings.Description
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	FileSynchronizationSettings.Account <> VALUE(Catalog.FileSynchronizationAccounts.EmptyRef)";
		
	Return Query.Execute().Unload();
	
EndFunction

Procedure RefreshSynchronizationSettings()
	
	FilesOwnersTable = New ValueTable;
	FilesOwnersTable.Columns.Add("FileOwner",     New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("FileOwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("IsFile",           New TypeDescription("Boolean"));
	
	FilesSynchronizationExceptions = New Map;
	For Each SynchronizationException In FilesOperationsInternal.OnDefineFileSynchronizationExceptionObjects() Do
		FilesSynchronizationExceptions[SynchronizationException.FullName()] = True;
	EndDo;	
	
	For Each Catalog In Metadata.Catalogs Do
		If Catalog.Attributes.Find("FileOwner") = Undefined Then
			Continue;
		EndIf;
			
		FilesOwnersTypes = Common.MetadataObjectIDs(Catalog.Attributes.FileOwner.Type.Types());
		For Each OwnerType In FilesOwnersTypes Do
			
			If FilesSynchronizationExceptions[OwnerType.Key] <> Undefined Then
				Continue;
			EndIf;	
				
			FileOwner = OwnerType.Value;
			NewRow  = FilesOwnersTable.Add();
			NewRow.FileOwner = FileOwner;
			NewRow.FileOwnerType= Common.MetadataObjectID(Catalog);
			NewRow.IsFile = Not StrEndsWith(Catalog.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles());
		EndDo;
	EndDo;
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	FilesOwnersTable.FileOwner AS FileOwner,
		|	FilesOwnersTable.FileOwnerType AS FileOwnerType,
		|	FilesOwnersTable.IsFile AS IsFile
		|INTO FilesOwnersTable
		|FROM
		|	&FilesOwnersTable AS FilesOwnersTable
		|
		|INDEX BY
		|	FileOwner,
		|	IsFile
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType,
		|	FileSynchronizationSettings.IsFile AS IsFile,
		|	MetadataObjectIDs.Ref AS ObjectID,
		|	FileSynchronizationSettings.Description
		|INTO SubordinateSettings
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FileSynchronizationSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	VALUETYPE(FileSynchronizationSettings.FileOwner) <> TYPE(Catalog.MetadataObjectIDs)
		|
		|INDEX BY
		|	ObjectID,
		|	IsFile,
		|	FileOwnerType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FileSynchronizationSettings.FileOwner,
		|	FileSynchronizationSettings.FileOwnerType AS FileOwnerType,
		|	FileSynchronizationSettings.IsFile,
		|	FALSE AS NewSetting,
		|	FileSynchronizationSettings.Description
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|		LEFT JOIN FilesOwnersTable AS FilesOwnersTable
		|		ON FileSynchronizationSettings.FileOwner = FilesOwnersTable.FileOwner
		|			AND FileSynchronizationSettings.IsFile = FilesOwnersTable.IsFile
		|			AND FileSynchronizationSettings.FileOwnerType = FilesOwnersTable.FileOwnerType
		|WHERE
		|	FilesOwnersTable.FileOwner IS NULL 
		|	AND VALUETYPE(FileSynchronizationSettings.FileOwner) = TYPE(Catalog.MetadataObjectIDs)
		|
		|UNION ALL
		|
		|SELECT
		|	SubordinateSettings.FileOwner,
		|	SubordinateSettings.FileOwnerType,
		|	SubordinateSettings.IsFile,
		|	FALSE,
		|	SubordinateSettings.Description
		|FROM
		|	SubordinateSettings AS SubordinateSettings
		|		LEFT JOIN FilesOwnersTable AS FilesOwnersTable
		|		ON SubordinateSettings.FileOwnerType = FilesOwnersTable.FileOwnerType
		|			AND SubordinateSettings.IsFile = FilesOwnersTable.IsFile
		|			AND SubordinateSettings.ObjectID = FilesOwnersTable.FileOwner
		|WHERE
		|	FilesOwnersTable.FileOwner IS NULL ";
	
	Query.Parameters.Insert("FilesOwnersTable", FilesOwnersTable);
	CommonSettingsTable = Query.Execute().Unload();
	
	SettingsForDelete = CommonSettingsTable.FindRows(New Structure("NewSetting", False));
	For Each Setting In SettingsForDelete Do
		RecordManager = CreateRecordManager();
		RecordManager.FileOwner = Setting.FileOwner;
		RecordManager.FileOwnerType = Setting.FileOwnerType;
		RecordManager.Delete();
	EndDo;
	
EndProcedure

#EndRegion

#EndIf