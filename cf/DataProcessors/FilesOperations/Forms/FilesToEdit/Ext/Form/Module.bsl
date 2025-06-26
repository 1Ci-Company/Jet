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
	
	SetUpDynamicList();
	
	User = Users.AuthorizedUser();
	
	List.Parameters.SetParameterValue("BeingEditedBy", User);
	
	ShowSizeColumn = FilesOperationsInternal.ShowSizeColumn();
	If ShowSizeColumn = False Then
		Items.ListCurrentVersionSize.Visible = False;
	EndIf;
	
	ApplicationShutdown = Undefined;
	If Parameters.Property("ApplicationShutdown", ApplicationShutdown) Then 
		Response = ApplicationShutdown;
		If Response = True Then
			Items.ShowLockedFilesOnExit.Visible = Response;
			Items.CommandBarGroup1.Visible                     = Response;
		EndIf;
	EndIf;
	
	ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", 
		"ShowLockedFilesOnExit", True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	OnCloseAtServer();
	StandardSubsystemsClient.SetClientParameter(
		"LockedFilesCount", LockedFilesCount);
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	
	LockedFilesCount = FilesOperationsInternal.LockedFilesCount();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Item.CurrentData.Ref, Undefined, UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("SetCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref, True);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Refresh(Command)
	
	Items.List.Refresh();
	
	AttachIdleHandler("SetCommandsAvailability", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFile(FileData);
	
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	TableRow = Items.List.CurrentRow;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref, True);
	
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(
		CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(CurrentData.Ref);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(New NotifyDescription("UpdateEditedFilesList", ThisObject), FileData, UUID);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileUnlockParameters = FilesOperationsInternalClient.FileUnlockParameters(
		New NotifyDescription("UpdateEditedFilesList", ThisObject), CurrentData.Ref);
	FileUnlockParameters.StoreVersions = CurrentData.StoreVersions;
	FileUnlockParameters.CurrentUserEditsFile = True;
	FileUnlockParameters.BeingEditedBy = CurrentData.BeingEditedBy;
	FilesOperationsInternalClient.UnlockFileWithNotification(FileUnlockParameters);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FilesOperationsInternalClient.SaveFileChangesWithNotification(
		Undefined,
		CurrentData.Ref,
		UUID);
	
EndProcedure

&AtClient
Procedure SaveAs(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToSave(
		CurrentData.Ref, , UUID);
	FilesOperationsInternalClient.SaveAs(Undefined, FileData, Undefined);
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(
		New NotifyDescription("UpdateEditedFilesList", ThisObject), CurrentData.Ref, UUID);
	FileUpdateParameters.StoreVersions = CurrentData.StoreVersions;
	FileUpdateParameters.CurrentUserEditsFile = True;
	FileUpdateParameters.BeingEditedBy = CurrentData.BeingEditedBy;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	StructuresArray = New Array;
	StructuresArray.Add(SettingDetails(
		"ApplicationSettings",
		"ShowLockedFilesOnExit",
		ShowLockedFilesOnExit));
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray, True);
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCommandsAvailability()
	
	Enabled = Items.List.CurrentRow <> Undefined;
	
	Items.FormEndEdit.Enabled = Enabled;
	Items.ListContextMenuEndEdit.Enabled = Enabled;
	
	Items.FormOpenFile.Enabled = Enabled;
	Items.ListContextMenuOpen.Enabled = Enabled;
	
	Items.FormOpenFileProperties.Enabled = Enabled;
	
	Items.ListContextMenuSaveChanges.Enabled = Enabled;
	Items.ListContextMenuOpenFileDirectory.Enabled = Enabled;
	Items.ListContextMenuSaveAs.Enabled = Enabled;
	Items.ListContextMenuRelease.Enabled = Enabled;
	Items.ListContextMenuUpdateFromFileOnHardDrive.Enabled = Enabled;
	
EndProcedure

&AtClient
Function SettingDetails(Object, Tincture, Value)
	
	Item = New Structure;
	Item.Insert("Object", Object);
	Item.Insert("Setting", Tincture);
	Item.Insert("Value", Value);
	
	Return Item;
	
EndFunction

&AtServer
Procedure SetUpDynamicList()
	
	Query = New Query;
	Query.Text = 
		"SELECT DISTINCT
		|	VALUETYPE(FilesInfo.File) AS FileType
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.BeingEditedBy = &BeingEditedBy";
	
	Query.SetParameter("BeingEditedBy", Users.AuthorizedUser());
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	TypesArray = QueryResult.Unload().UnloadColumn("FileType");
	SetPrivilegedMode(False);
	
	QueryText = "";
	For Each CatalogType In TypesArray Do
		CatalogMetadata = Metadata.FindByType(CatalogType);
		If Not AccessRight("Update", CatalogMetadata) Then
			Continue;
		EndIf;
		If CatalogMetadata.Name <> "FilesVersions" Then
			QueryFragment = "SELECT ALLOWED
			|	Files.BeingEditedBy,
			|	Files.PictureIndex,
			|	Files.Description,
			|	Files.LongDesc,
			|	Files.Ref,
			|	Files.FileOwner,
			|	Files.StoreVersions AS StoreVersions,
			|	Files.Size / 1024
			|FROM
			|	&TableName AS Files
			|WHERE
			|	Files.BeingEditedBy = &BeingEditedBy";
			QueryFragment = StrReplace(QueryFragment, "&TableName", CatalogMetadata.FullName());
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "
				|
				|UNION ALL
				|";
				QueryFragment = StrReplace(QueryFragment, "SELECT ALLOWED", "SELECT"); // @query-part-1 @query-part-2
			EndIf;
			QueryText = QueryText + QueryFragment;
			
		EndIf;
	EndDo;
		
	If Not IsBlankString(QueryText) Then
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.QueryText                 = QueryText;
		ListProperties.DynamicDataRead = False;
		Common.SetDynamicListProperties(Items.List, ListProperties);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateEditedFilesList(Result, AdditionalParameters) Export
	Items.List.Refresh();
EndProcedure

#EndRegion
