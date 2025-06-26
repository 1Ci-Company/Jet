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
	
	For Each FileRef In Parameters.FilesArray Do
		NewItem = SelectedFiles.Add();
		NewItem.Ref = FileRef;
		NewItem.PictureIndex = FileRef.PictureIndex;
	EndDo;
	
	HaveFileVersions = Parameters.HaveFileVersions;
	BeingEditedBy = Parameters.BeingEditedBy;
	
	Items.StoreVersions.Visible = HaveFileVersions;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	StoreVersions = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSelectedFiles

&AtClient
Procedure SelectedFilesBeforeAddRow(Item, Cancel, Copy)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EndEdit()
	
	FilesArray = New Array;
	For Each ListItem In SelectedFiles Do
		FilesArray.Add(ListItem.Ref);
	EndDo;
	
	FilesUpdateParameters = New Structure;
	FilesUpdateParameters.Insert("FilesArray",                     FilesArray);
	FilesUpdateParameters.Insert("CanCreateFileVersions", HaveFileVersions);
	FilesUpdateParameters.Insert("StoreVersions", StoreVersions);
	If Not HaveFileVersions Then
		FilesUpdateParameters.Insert("CreateNewVersion", False);
	EndIf;
	FilesUpdateParameters.Insert("CurrentUserEditsFile", True);
	FilesUpdateParameters.Insert("ResultHandler",               Undefined);
	FilesUpdateParameters.Insert("FormIdentifier",                 UUID);
	FilesUpdateParameters.Insert("BeingEditedBy",                        BeingEditedBy);
	FilesUpdateParameters.Insert("VersionComment",                 Comment);
	FilesUpdateParameters.Insert("ShouldShowUserNotification",               False);
	FilesOperationsInternalClient.FinishEditByRefsWithNotification(FilesUpdateParameters);
	Close();
EndProcedure

#EndRegion