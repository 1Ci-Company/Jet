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
	
	ErrorTitle = NStr("en = 'An error occurred when configuring the dynamic list of attachments.';");
	ErrorEnd = NStr("en = 'Cannot configure the dynamic list.';");
	
	FileOwner = Common.ObjectAttributeValue(Parameters.File, "FileOwner");
	
	FileVersionsStorageCatalogName = FilesOperationsInternal.FilesVersionsStorageCatalogName(
		FileOwner, "", ErrorTitle, ErrorEnd);
		
	If Not IsBlankString(FileVersionsStorageCatalogName) Then
		SetUpDynamicList(FileVersionsStorageCatalogName);
	EndIf;
	
	CommandCompareVisibility = 
		Not Common.IsLinuxClient() And Not Common.IsWebClient();
	Items.FormCompare.Visible = CommandCompareVisibility;
	Items.ContextMenuListCompare.Visible = CommandCompareVisibility;
	
	FileCardUUID = Parameters.FileCardUUID;
	
	List.Parameters.SetParameterValue("Owner", Parameters.File);
	VersionOwner = Parameters.File;
	
	FilesOperationsInternal.SetFilterByDeletionMark(List.Filter);
	
	If Common.IsMobileClient() Then
		
		Items.FormOpenVersion.Picture = PictureLib.InputFieldOpen;
		Items.FormOpenVersion.Representation = ButtonRepresentation.Picture;
		Items.ListComment.Visible = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MakeActiveExecute()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	NewActiveVersion = CurrentData.Ref;
	
	FileDataParameters = FilesOperationsClientServer.FileDataParameters();
	FileDataParameters.GetBinaryDataRef = False;
	
	FileData = FilesOperationsInternalServerCall.FileData(CurrentData.Owner, CurrentData.Ref, FileDataParameters);
	
	If ValueIsFilled(FileData.BeingEditedBy) Then
		ShowMessageBox(, NStr("en = 'Cannot change the active version because the file is locked.';"));
	ElsIf FileData.SignedWithDS Then
		ShowMessageBox(, NStr("en = 'Cannot change the active version because the file is signed.';"));
	Else
		ChangeActiveFileVersion(NewActiveVersion);
		FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters("ActiveVersionChanged");
		Notify("Write_File", FileWriteNotificationParameters, Parameters.File);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
		And (Parameter.Event = "EditFinished"
		Or Parameter.Event = "VersionSaved") Then
		
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Owner, CurrentData.Ref, UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Items.List.CurrentRow <> Undefined Then
		ChangeCommandsAvailability();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenCard(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("DataProcessor.FilesOperations.Form.AttachedFileVersion", FormOpenParameters);
		
	EndIf;
	
EndProcedure

// Compare the two selected versions. 
&AtClient
Procedure Compare(Command)
	
	SelectedRowsCount = Items.List.SelectedRows.Count();
	If SelectedRowsCount <> 2 And SelectedRowsCount <> 1 Then
		ShowMessageBox(, NStr("en = 'To view the differences, select two file versions.';"));
		Return;
	EndIf;
		
	If SelectedRowsCount = 2 Then
		FirstFile = Items.List.SelectedRows[0];
		SecondFile = Items.List.SelectedRows[1];
	ElsIf SelectedRowsCount = 1 Then
		FirstFile = Items.List.CurrentData.Ref;
		SecondFile = Items.List.CurrentData.ParentVersion;
	EndIf;
	
	Extension = Lower(Items.List.CurrentData.Extension);
	FilesOperationsInternalClient.CompareFiles(UUID, FirstFile, SecondFile, Extension, VersionOwner);
	
EndProcedure

&AtClient
Procedure OpenVersion(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Owner, CurrentData.Ref ,UUID);
	FilesOperationsInternalClient.OpenFileVersion(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(CurrentData.Owner, CurrentData.Ref , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, UUID);
	
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
Procedure ChangeCommandsAvailability()
	
	CurrentUserIsAuthor =
		Items.List.CurrentData.Author = UsersClient.AuthorizedUser();
	
	Items.FormDelete.Enabled = CurrentUserIsAuthor;
	Items.ListContextMenuDelete.Enabled = CurrentUserIsAuthor;
	
EndProcedure

&AtClient
Procedure AfterDeleteData(Result, AdditionalParameters) Export
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure ChangeActiveFileVersion(Version)
	
	BeginTransaction();
	Try
		
		VersionLock = New DataLock;
		
		DataLockItem = VersionLock.Add(Metadata.FindByType(TypeOf(Version)).FullName());
		DataLockItem.SetValue("Ref", Version);
		DataLockItem.Mode = DataLockMode.Shared;
		
		VersionLock.Lock();
		
		NewVersionAttributes = Common.ObjectAttributesValues(Version, "Owner, TextStorage");
		
		Block = New DataLock;
		
		DataLockItem = Block.Add(Metadata.FindByType(TypeOf(NewVersionAttributes.Owner)).FullName());
		DataLockItem.SetValue("Ref", NewVersionAttributes.Owner);
		
		Block.Lock();
		
		LockDataForEdit(NewVersionAttributes.Owner, , FileCardUUID);
		LockDataForEdit(Version, , FileCardUUID);
		
		FileObject1 = NewVersionAttributes.Owner.GetObject();
		If FileObject1.SignedWithDS Then
			Raise NStr("en = 'Cannot change the active version because the file is signed.';");
		EndIf;
		FileObject1.CurrentVersion = Version;
		FileObject1.TextStorage = NewVersionAttributes.TextStorage;
		FileObject1.Write();
		
		VersionObject = Version.GetObject();
		VersionObject.Write();
		
		UnlockDataForEdit(FileObject1.Ref, FileCardUUID);
		UnlockDataForEdit(Version, FileCardUUID);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetUpDynamicList(FileVersionsStorageCatalogName)
	
	ListProperties = Common.DynamicListPropertiesStructure();
	
	QueryText = 
		"SELECT ALLOWED
		|	FilesVersions.Code AS Code,
		|	FilesVersions.Size AS Size,
		|	FilesVersions.Comment AS Comment,
		|	FilesVersions.Author AS Author,
		|	FilesVersions.CreationDate AS CreationDate,
		|	FilesVersions.Description AS FullDescr,
		|	FilesVersions.ParentVersion AS ParentVersion,
		|	CASE
		|		WHEN FilesVersions.DeletionMark
		|			THEN FilesVersions.PictureIndex + 1
		|		ELSE FilesVersions.PictureIndex
		|	END AS PictureIndex,
		|	FilesVersions.DeletionMark AS DeletionMark,
		|	FilesVersions.Owner AS Owner,
		|	FilesVersions.Ref AS Ref,
		|	CASE
		|		WHEN FilesVersions.Owner.CurrentVersion = FilesVersions.Ref
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS IsCurrent,
		|	FilesVersions.Extension AS Extension,
		|	FilesVersions.VersionNumber AS VersionNumber
		|FROM
		|	&CatalogName AS FilesVersions
		|WHERE
		|	FilesVersions.Owner = &Owner";
	
	FullCatalogName = "Catalog." + FileVersionsStorageCatalogName;
	QueryText = StrReplace(QueryText, "&CatalogName", FullCatalogName);
	
	ListProperties.MainTable  = FullCatalogName;
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

#EndRegion
