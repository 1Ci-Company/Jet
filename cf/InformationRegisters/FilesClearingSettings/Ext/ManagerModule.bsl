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

// StandardSubsystems.ReportsOptions

// Defines the list of report commands.
//
// Parameters:
//  ReportsCommands - See ReportsOptionsOverridable.BeforeAddReportCommands.ReportsCommands
//  Parameters - See ReportsOptionsOverridable.BeforeAddReportCommands.Parameters
//
Procedure AddReportCommands(ReportsCommands, Parameters) Export
	
	If Not AccessRight("View", Metadata.Reports.IrrelevantFilesVolume) Then
		Return;
	EndIf;
	
	Command = ReportsCommands.Add();
	Command.VariantKey      = "IrrelevantFilesVolumeByOwners";
	Command.Presentation     = NStr("en = 'Unused files by owner (Top 10)';");
	Command.Id     = "IrrelevantFilesVolumeByOwners";
	Command.Manager          = "Report.IrrelevantFilesVolume";
	Command.WriteMode       = "NotWrite";
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private


// Returns:
//   ValueTable:
//   * FileOwner - AnyRef
//   * OwnerID - CatalogRef.MetadataObjectIDs
//   * IsCatalogItemSetup - Boolean
//   * FileOwnerType - CatalogRef.MetadataObjectIDs
//   * FilterRule - ValueStorage
//   * Action - EnumRef.FilesCleanupOptions
//   * ClearingPeriod - EnumRef.FilesCleanupPeriod
//   * IsFile - Boolean
//
Function CurrentClearSettings() Export
	
	SetPrivilegedMode(True);
	
	RefreshClearSettings();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesClearingSettings.FileOwner,
		|	MetadataObjectIDs.Ref AS OwnerID,
		|	CASE
		|		WHEN VALUETYPE(MetadataObjectIDs.Ref) <> VALUETYPE(FilesClearingSettings.FileOwner)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsCatalogItemSetup,
		|	FilesClearingSettings.FileOwnerType,
		|	FilesClearingSettings.FilterRule,
		|	FilesClearingSettings.Action,
		|	FilesClearingSettings.ClearingPeriod,
		|	FilesClearingSettings.IsFile
		|FROM
		|	InformationRegister.FilesClearingSettings AS FilesClearingSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FilesClearingSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))";
		
	Return Query.Execute().Unload();
	
EndFunction

Procedure RefreshClearSettings()
	
	MetadataCatalogs = Metadata.Catalogs;
	
	FilesOwnersTable = New ValueTable;
	FilesOwnersTable.Columns.Add("FileOwner",     New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("FileOwnerType", New TypeDescription("CatalogRef.MetadataObjectIDs"));
	FilesOwnersTable.Columns.Add("IsFile",           New TypeDescription("Boolean"));
	
	ExceptionsArray = FilesOperationsInternal.ExceptionItemsOnClearFiles();
	For Each Catalog In MetadataCatalogs Do
		
		If Catalog.Attributes.Find("FileOwner") = Undefined Then
			Continue;
		EndIf;
		
		FilesOwnersTypes = Catalog.Attributes.FileOwner.Type.Types();
		For Each OwnerType In FilesOwnersTypes Do
			
			OwnerMetadata = Metadata.FindByType(OwnerType);
			If ExceptionsArray.Find(OwnerMetadata) <> Undefined Then
				Continue;
			EndIf;
			
			NewRow = FilesOwnersTable.Add();
			NewRow.FileOwner = Common.MetadataObjectID(OwnerType);
			NewRow.FileOwnerType = Common.MetadataObjectID(Catalog);
			If Not StrEndsWith(Catalog.Name, FilesOperationsInternal.CatalogSuffixAttachedFiles()) Then
				NewRow.IsFile = True;
			EndIf;
			
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
		|	FilesClearingSettings.FileOwner,
		|	FilesClearingSettings.FileOwnerType AS FileOwnerType,
		|	FilesClearingSettings.IsFile AS IsFile,
		|	MetadataObjectIDs.Ref AS ObjectID
		|INTO SubordinateSettings
		|FROM
		|	InformationRegister.FilesClearingSettings AS FilesClearingSettings
		|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|		ON (VALUETYPE(FilesClearingSettings.FileOwner) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
		|WHERE
		|	VALUETYPE(FilesClearingSettings.FileOwner) <> TYPE(Catalog.MetadataObjectIDs)
		|
		|INDEX BY
		|	ObjectID,
		|	IsFile,
		|	FileOwnerType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FilesClearingSettings.FileOwner,
		|	FilesClearingSettings.FileOwnerType AS FileOwnerType,
		|	FilesClearingSettings.IsFile,
		|	FALSE AS NewSetting
		|FROM
		|	InformationRegister.FilesClearingSettings AS FilesClearingSettings
		|		LEFT JOIN FilesOwnersTable AS FilesOwnersTable
		|		ON FilesClearingSettings.FileOwner = FilesOwnersTable.FileOwner
		|			AND FilesClearingSettings.IsFile = FilesOwnersTable.IsFile
		|			AND FilesClearingSettings.FileOwnerType = FilesOwnersTable.FileOwnerType
		|WHERE
		|	FilesOwnersTable.FileOwner IS NULL 
		|	AND VALUETYPE(FilesClearingSettings.FileOwner) = TYPE(Catalog.MetadataObjectIDs)
		|
		|UNION ALL
		|
		|SELECT
		|	SubordinateSettings.FileOwner,
		|	SubordinateSettings.FileOwnerType,
		|	SubordinateSettings.IsFile,
		|	FALSE
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