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

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.LongDesc = NStr("en = 'Volume integrity check.';");
	ReportSettings.DefineFormSettings = True;

EndProcedure

// See ReportsOptionsOverridable.DefineObjectsWithReportCommands.
Procedure OnDefineObjectsWithReportCommands(Objects) Export
	
	Objects.Add(Metadata.Catalogs.FileStorageVolumes);
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// Prepares a table for checking if the files exist in the volume.
// 
// Parameters:
//  Volume - CatalogRef.FileStorageVolumes - Volume
// 
// Returns:
//   See FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive
// 
Function FilesOnHardDrive(Volume) Export
	FilesTableOnHardDrive = FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive();
		
	VolumePath = FilesOperationsInVolumesInternal.FullVolumePath(Volume);
	
	CheckedFiles = FindFiles(VolumePath, "*", True);
	For Each File In CheckedFiles Do
		If Not File.IsFile() Then 
			Continue;
		EndIf;
		NewRow = FilesTableOnHardDrive.Add();
		NewRow.Name = File.Name;
		NewRow.BaseName = File.BaseName;
		NewRow.FullName = File.FullName;
		NewRow.Path = File.Path;
		NewRow.Extension = File.Extension;
		NewRow.CheckStatus = "ExtraFileInTome";
		NewRow.Count = 1;
		NewRow.Volume = Volume;
	EndDo;
	
	FilesOperationsInVolumesInternal.FillInExtraFiles(FilesTableOnHardDrive, Volume);
	Return FilesTableOnHardDrive;
EndFunction

// Restores file links in the given volume.
// 
// Parameters:
//  Volume - CatalogRef.FileStorageVolumes
// 
// Returns:
//  Structure:
//   * Processed - Number
//   * Total - Number
//
Function RecoverFiles(Volume) Export
	FilesTableOnHardDrive = FilesOnHardDrive(Volume);
	
	VolumePath = FilesOperationsInVolumesInternal.FullVolumePath(Volume);
	
	Filter = New Structure("CheckStatus", "FixingPossible");
	FilesToRecover = FilesTableOnHardDrive.Copy(Filter, "File,FullName");
	Return FilesOperationsInVolumesInternal.SetFilesStoragePaths(FilesToRecover, VolumePath);
EndFunction

#EndRegion

#EndIf