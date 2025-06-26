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
	
	MessageQuestion = Parameters.MessageQuestion;
	MessageTitle = Parameters.MessageTitle;
	Title = Parameters.Title;
	Files = Parameters.Files;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFiles

&AtClient
Procedure FilesSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileRef = Files[RowSelected].Value;
	
	PersonalSettings = FilesOperationsInternalClient.PersonalFilesOperationsSettings();
	HowToOpen = PersonalSettings.ActionOnDoubleClick;
	If HowToOpen = "OpenCard" Then
		FormParameters = New Structure;
		FormParameters.Insert("Key", FileRef);
		OpenForm("Catalog.Files.ObjectForm", FormParameters, ThisObject);
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(FileRef, Undefined,UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

#EndRegion
