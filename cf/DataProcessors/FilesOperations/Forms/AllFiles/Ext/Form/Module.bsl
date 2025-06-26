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
	
	CurrentUser = Users.AuthorizedUser();
	If TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers") Then
		FilesOperationsInternal.ChangeFormForExternalUser(ThisObject, True);
	EndIf;
	
	List.Parameters.SetParameterValue(
		"CurrentUser", CurrentUser);
	
	FilesOperationsInternal.FillConditionalAppearanceOfFilesList(List);
	
	FilesOperationsInternal.AddFiltersToFilesList(List);
	Items.ShowServiceFiles.Visible = Users.IsFullUser();
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
	URL = "e1cib/app/" + FormName;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_FilesFolders" Then
		Items.List.Refresh();
	ElsIf EventName = "Write_File" Then
		Items.List.Refresh();
		If ValueIsFilled(Parameter.File) Then
			Items.List.CurrentRow = Parameter.File;
		ElsIf Source <> Undefined Then
			Items.List.CurrentRow = Source;
		EndIf;
	ElsIf Upper(EventName) = Upper("Write_ConstantsSet")
	   And (Upper(Source) = Upper("UseDigitalSignature")
		  Or Upper(Source) = Upper("UseEncryption")) Then
		AttachIdleHandler("SigningOrEncryptionUsageOnChange", 0.3, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetCommandsAvailability(False, False);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentData.Ref, Undefined, UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	SetFileCommandsAvailability();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenForViewing(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFile(FileData);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(Items.List.CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	If Not FileCommandsAvailable() Then 
		Return;
	EndIf;
	
	Handler = New NotifyDescription("ReleaseCompletion", ThisObject);
	FilesOperationsInternalClient.UnlockFiles(Items.List);
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	AttachIdleHandler("SetFileCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return
	EndIf;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure SetDeletionMark(Command)
	SetClearDeletionMark(Items.List.SelectedRows);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	SetClearDeletionMark(Items.List.SelectedRows);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure ShowServiceFiles(Command)
	
	Items.ShowServiceFiles.Check = 
		FilesOperationsInternalClient.ShowServiceFilesClick(List);
	
EndProcedure

&AtClient
Procedure Delete(Command)
	
	If Items.List.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	FilesOperationsInternalClient.DeleteData(
		New NotifyDescription("AfterDeleteData", ThisObject),
		Items.List.CurrentData.Ref, UUID);
	
EndProcedure

&AtClient
Procedure ShowMarkedFiles(Command)
	
	FilesOperationsInternalClient.ChangeFilterByDeletionMark(List.Filter, Items.ShowMarkedFiles);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ReleaseCompletion(Result, ExecutionParameters) Export
	SetFileCommandsAvailability();
EndProcedure

&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Items.List.Refresh();
	
EndProcedure

// File commands are available. There is at least one row in the list and grouping is not selected.
&AtClient
Function FileCommandsAvailable()
	
	If Items.List.CurrentRow = Undefined Then 
		Return False;
	EndIf;
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow") Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Procedure SetFileCommandsAvailability()
	
	EditedByCurrentUser = False;
	AreFilesBeingEditedSelected = False;
	
	CurrentRow = Items.List.CurrentRow;
	If CurrentRow <> Undefined
		And TypeOf(CurrentRow) <> Type("DynamicListGroupRow") Then
		
		CurrentData = Items.List.CurrentData;
		AreFilesBeingEditedSelected = ValueIsFilled(CurrentData.BeingEditedBy);
		If Not AreFilesBeingEditedSelected Then
			For Each Item In Items.List.SelectedRows Do
				AreFilesBeingEditedSelected = ValueIsFilled(Items.List.RowData(Item).BeingEditedBy);
				If AreFilesBeingEditedSelected Then
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		EditedByCurrentUser = CurrentData.CurrentUserEditsFile;
					
	EndIf;
	
	SetCommandsAvailability(EditedByCurrentUser, AreFilesBeingEditedSelected);
	
EndProcedure

&AtServerNoContext
Procedure SetClearDeletionMark(Val SelectedRows)
	
	If TypeOf(SelectedRows) = Type("Array") Then
		For Each SelectedRow In SelectedRows Do
			File = SelectedRow.File.GetObject();
			File.SetDeletionMark(Not File.DeletionMark);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCommandsAvailability(EditedByCurrentUser, AreFilesBeingEditedSelected)
	
	Items.FormRelease.Enabled = AreFilesBeingEditedSelected;
	Items.ListContextMenuRelease.Enabled = AreFilesBeingEditedSelected;
	Items.FormDelete.Enabled = EditedByCurrentUser;
	Items.ListContextMenuDelete.Enabled = EditedByCurrentUser;
	
EndProcedure

&AtClient
Procedure SigningOrEncryptionUsageOnChange()
	
	OnChangeUseOfSigningOrEncryptionAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeUseOfSigningOrEncryptionAtServer()
	
	FilesOperationsInternal.CryptographyOnCreateFormAtServer(ThisObject,, True);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return
	EndIf;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref);
	
EndProcedure

#EndRegion
