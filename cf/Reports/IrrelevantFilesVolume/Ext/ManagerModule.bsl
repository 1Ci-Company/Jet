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
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "IrrelevantFilesVolumeByOwners");
	OptionSettings.LongDesc = NStr("en = 'Total size of unused files.';");
	
EndProcedure

// See ReportsOptionsOverridable.DefineObjectsWithReportCommands.
Procedure OnDefineObjectsWithReportCommands(Objects) Export
	
	Objects.Add(Metadata.InformationRegisters.FilesClearingSettings);
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// Generates a table of unused files.
//
// Returns:
//   ValueTable:
//   * FileOwner - DefinedType.FilesOwner
//   * IrrelevantFilesVolume - Number - size in bytes.
//
Function UnusedFilesTable() Export
	
	CleanupSettings = InformationRegisters.FilesClearingSettings.CurrentClearSettings();
	
	UnusedFilesTable = New ValueTable;
	UnusedFilesTable.Columns.Add("FileOwner");
	UnusedFilesTable.Columns.Add("IrrelevantFilesVolume", New TypeDescription("Number"));
	
	FilesClearingSettings  = CleanupSettings.FindRows(New Structure("IsCatalogItemSetup", False));
	
	For Each Setting In FilesClearingSettings Do
		
		ExceptionsArray = New Array;
		DetailedSettings = CleanupSettings.FindRows(New Structure(
			"OwnerID, IsCatalogItemSetup",
			Setting.FileOwner,
			True));
		If DetailedSettings.Count() > 0 Then
			For Each ExceptionItem In DetailedSettings Do
				ExceptionsArray.Add(ExceptionItem.FileOwner);
				ToSupplementTheTableOfUnnecessaryFiles(UnusedFilesTable, ExceptionItem, ExceptionsArray);
			EndDo;
		EndIf;
		
		ToSupplementTheTableOfUnnecessaryFiles(UnusedFilesTable, Setting, ExceptionsArray);
	EndDo;
	
	Return UnusedFilesTable;
	
EndFunction

Procedure ToSupplementTheTableOfUnnecessaryFiles(UnusedFilesTable, ClearingSetup, ExceptionsArray)
	
	If ClearingSetup.Action = Enums.FilesCleanupOptions.NotClear Then
		Return;
	EndIf;
	
	If ExceptionsArray = Undefined Then
		ExceptionsArray = New Array;
	EndIf;
	
	UnusedFiles = FilesOperationsInternal.CollectUnusedFiles(ClearingSetup, ExceptionsArray);
	For Each UnnecessaryFile In UnusedFiles.Rows Do
		NewRow = UnusedFilesTable.Add();
		NewRow.FileOwner = UnnecessaryFile.FileOwner;
		NewRow.IrrelevantFilesVolume = ?(UnnecessaryFile.Rows.Count() > 0, 0, UnnecessaryFile.Size);
		For Each UnusedFileVersion In UnnecessaryFile.Rows Do
			NewRow.IrrelevantFilesVolume = NewRow.IrrelevantFilesVolume + UnusedFileVersion.Size;
		EndDo
	EndDo;
	
EndProcedure

#EndRegion

#EndIf