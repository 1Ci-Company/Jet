///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	File = Parameters.FileRef;
	VersionComment = Parameters.VersionComment;
	CreateNewVersion = Parameters.CreateNewVersion;
	
	If Common.ObjectAttributeValue(File, "StoreVersions") Then
		CreateNewVersion = True;
		Items.CreateNewVersion.Enabled = Parameters.CreateNewVersionAvailability;
		If Not Parameters.CreateNewVersionAvailability Then
			Items.CreateNewVersion.ToolTip = NStr("en = 'Settings for saving the attached file version are specified by its author and cannot be changed.';");
			Items.CreateNewVersion.ToolTipRepresentation = ToolTipRepresentation.Button;
		EndIf;
	Else
		CreateNewVersion = False;
		Items.CreateNewVersion.Enabled = False;
		Items.CreateNewVersion.ToolTip = NStr("en = 'Versions for this attachment are disabled.';");
		Items.CreateNewVersion.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Save(Command)
	
	ReturnStructure = New Structure("VersionComment, CreateNewVersion, ReturnCode",
		VersionComment, CreateNewVersion, DialogReturnCode.OK);
	
	Close(ReturnStructure);
	
	Notify("FilesOperationsNewFileVersionSaved");
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ReturnStructure = New Structure("VersionComment, CreateNewVersion, ReturnCode",
		VersionComment, CreateNewVersion, DialogReturnCode.Cancel);
	
	Close(ReturnStructure);
	
EndProcedure

#EndRegion