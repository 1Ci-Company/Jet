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

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	AttributesToEdit.Add("Comment");
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.ReportsOptions

// Defines the list of report commands.
//
// Parameters:
//  ReportsCommands - See ReportsOptionsOverridable.BeforeAddReportCommands.ReportsCommands
//  Parameters - See ReportsOptionsOverridable.BeforeAddReportCommands.Parameters
//
Procedure AddReportCommands(ReportsCommands, Parameters) Export
	
	If Not AccessRight("View", Metadata.Reports.VolumeIntegrityCheck) Then
		Return;
	EndIf;
	
	Command = ReportsCommands.Add();
	Command.VariantKey       = "Main";
	Command.Presentation      = NStr("en = 'Volume integrity check';");
	Command.Id      = "VolumeIntegrityCheck";
	Command.Manager           = "Report.VolumeIntegrityCheck";
	Command.MultipleChoice = False;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region Private

// For internal use only.
// 
// Parameters:
//   Queries - Array
//
Procedure AddRequestsToUseExternalResourcesForAllVolumes(Queries) Export
	
	If Common.DataSeparationEnabled() And Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FileStorageVolumes.Ref AS Ref,
	|	FileStorageVolumes.FullPathLinux,
	|	FileStorageVolumes.FullPathWindows,
	|	FileStorageVolumes.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.FileStorageVolumes AS FileStorageVolumes
	|WHERE
	|	FileStorageVolumes.DeletionMark = FALSE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Queries.Add(RequestToUseExternalResourcesForVolume(
			Selection.Ref, Selection.FullPathWindows, Selection.FullPathLinux));
	EndDo;
	
EndProcedure

// For internal use only.
// 
// Parameters:
//   Queries - Array
//
Procedure AddRequestsToStopUsingExternalResourcesForAllVolumes(Queries) Export
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
		Query = New Query;
		Query.Text =
		"SELECT
		|	FileStorageVolumes.Ref AS Ref,
		|	FileStorageVolumes.FullPathLinux,
		|	FileStorageVolumes.FullPathWindows,
		|	FileStorageVolumes.DeletionMark AS DeletionMark
		|FROM
		|	Catalog.FileStorageVolumes AS FileStorageVolumes";
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			Queries.Add(ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(
				Selection.Ref));
		EndDo;
	EndIf;
	
EndProcedure

// For internal use only.
Function RequestToUseExternalResourcesForVolume(Volume, FullPathWindows, FullPathLinux) Export
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
		Permissions = New Array;
		
		If ValueIsFilled(FullPathWindows) Then
			Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				FullPathWindows, True, True));
		EndIf;
		
		If ValueIsFilled(FullPathLinux) Then
			Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
				FullPathLinux, True, True));
		EndIf;
		
		Return ModuleSafeModeManager.RequestToUseExternalResources(Permissions, Volume);
	EndIf;
	
EndFunction

#EndRegion

#EndIf
