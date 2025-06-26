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
	
	FileCopy = Parameters.File;
	Message = Parameters.Message;
	
	FileCreationMode = 1;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveFile(Command)
	
	Close(FileCreationMode);
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FilesOperationsInternalClient.OpenExplorerWithFile(FileCopy);
	
EndProcedure

#EndRegion
