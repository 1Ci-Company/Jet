///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	If SaveAsFileType = 0 Then
		Result = "xlsx";
	ElsIf SaveAsFileType = 1 Then
		Result = "csv";
	ElsIf SaveAsFileType = 3 Then
		Result = "xls";
	ElsIf SaveAsFileType = 4 Then
		Result = "ods";
	Else
		Result = "mxl";
	EndIf;
	Close(Result);
EndProcedure

&AtClient
Procedure InstallAddonForFacilitatingWorkWithFiles(Command)
	BeginInstallFileSystemExtension(Undefined);
EndProcedure

#EndRegion








