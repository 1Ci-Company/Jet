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
	
	SetUpDynamicList();
	
	List.Parameters.SetParameterValue("BeingEditedBy", Parameters.BeingEditedBy);
	If ValueIsFilled(Parameters.FileOwner) Then
		List.Parameters.SetParameterValue("FileOwner", Parameters.FileOwner);
	EndIf;
	
	If Not IsBlankString(Parameters.YesButtonTitle) Then 
		Items.Yes.Title = Parameters.YesButtonTitle;
	EndIf;
	
	If Not IsBlankString(Parameters.NoButtonTitle) Then 
		Items.None.Title = Parameters.NoButtonTitle;
	EndIf;
	
	If Parameters.ApplicationShutdown Then 
		Response = Parameters.ApplicationShutdown;
		If Response = True Then
			Items.ShowLockedFilesOnExit.Visible = Response;
			WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
		EndIf;
	EndIf;
	
	ShowLockedFilesOnExit = Common.CommonSettingsStorageLoad(
		"ApplicationSettings", 
		"ShowLockedFilesOnExit", True);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" Then
		Items.List.Refresh(); 
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(Items.List.CurrentData.Ref, Undefined, UUID);
	FilesOperationsInternalClient.OpenFileWithNotification(Undefined, FileData);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	Cancel = True;
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

#Region FormCommandsEventHandlers

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
Procedure OpenFileDirectory(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataToOpen(CurrentData.Ref, Undefined, UUID);
	FilesOperationsClient.OpenFileDirectory(FileData);
	
EndProcedure

&AtClient
Procedure UpdateFromFileOnHardDrive(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileData = FilesOperationsInternalServerCall.FileDataAndWorkingDirectory(CurrentData.Ref);
	FilesOperationsInternalClient.UpdateFromFileOnHardDriveWithNotification(Undefined, FileData, UUID);
	
EndProcedure

&AtClient
Procedure Release(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	FileUnlockParameters = FilesOperationsInternalClient.FileUnlockParameters(Undefined, CurrentData.Ref);
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
Procedure WriteAndClose(Command)
	StructuresArray = New Array;
	
	StructuresArray.Add(SettingDetails(
		"ApplicationSettings",
		"ShowLockedFilesOnExit",
		ShowLockedFilesOnExit));
	
	CommonServerCall.CommonSettingsStorageSaveArray(StructuresArray);
	
	Close(DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then 
		Return;
	EndIf;
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(
		Undefined, TableRow.Ref, UUID);
	FileUpdateParameters.StoreVersions = TableRow.StoreVersions;
	FileUpdateParameters.CurrentUserEditsFile = True;
	FileUpdateParameters.BeingEditedBy = TableRow.BeingEditedBy;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	Items.List.Refresh();
EndProcedure

&AtClient
Procedure OpenFileProperties(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return
	EndIf;
	
	FilesOperationsClient.OpenFileForm(CurrentData.Ref);
	
EndProcedure

#EndRegion

#Region Private

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
		"SELECT ALLOWED DISTINCT
		|	VALUETYPE(FilesInfo.File) AS FileType
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.BeingEditedBy = &BeingEditedBy";
		
	Query.SetParameter("BeingEditedBy", Parameters.BeingEditedBy);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	TypesArray      = QueryResult.Unload().UnloadColumn("FileType");
	SetPrivilegedMode(False);
	
	QueryText = "";
	For Each CatalogType In TypesArray Do
		CatalogMetadata = Metadata.FindByType(CatalogType);
		
		If Not AccessRight("Update", CatalogMetadata) Then
			Continue;
		EndIf;
		
		If CatalogMetadata.Name <> "FilesVersions" Then
			
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "
				|
				|UNION ALL
				|
				|	SELECT"; //@query-part
			Else
				QueryText = QueryText + "
				|	SELECT ALLOWED"; //@query-part
			EndIf;
			
			QueryText = QueryText + "
			|	Files.BeingEditedBy,
			|	Files.PictureIndex,
			|	Files.Description,
			|	Files.LongDesc,
			|	Files.Ref,
			|	Files.StoreVersions,
			|	Files.FileOwner,
			|	Files.Size / 1024,
			|	Files.Author
			|FROM
			|	" + CatalogMetadata.FullName() + " AS Files
			|WHERE
			|	Files.BeingEditedBy = &BeingEditedBy";
			
			If ValueIsFilled(Parameters.FileOwner) Then 
				QueryText = QueryText + "
					|	AND Files.FileOwner = &BeingEditedBy";
			EndIf;
			
		EndIf;
	EndDo;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = False;
	ListProperties.QueryText                 = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

#EndRegion
