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
	
	FolderForAdding = Parameters.FolderForAdding;
	
	For Each FilePath In Parameters.FileNamesArray Do
		ListFileNames.Add(FilePath);
	EndDo;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	WarningText =
		NStr("en = 'File upload is not available in the web client. Please use the ""Add"" command in the file list.';");
	ShowMessageBox(, WarningText);
	Cancel = True;
	Return;
#EndIf
	
	StoreVersions = True;
	DirectoriesOnly = True;
	
	For Each FilePath In ListFileNames Do
		FillFileList(FilePath, FilesTree.GetItems(), True, DirectoriesOnly);
	EndDo;
	
	If DirectoriesOnly Then
		Title = NStr("en = 'Upload folders';");
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.FilesOperations.Form.SelectEncoding") Then
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		FileTextEncoding = ValueSelected.Value;
		EncodingPresentation = ValueSelected.Presentation;
		SetCodingCommandPresentation(EncodingPresentation);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFilesTree

&AtClient
Procedure FilesTreeCheckOnChange(Item)
	DataElement = FilesTree.FindByID(Items.FilesTree.CurrentRow);
	SetMark(DataElement, DataElement.Check);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ImportFiles()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	PseudoFileSystem = New Map;
	
	SelectedFiles = New ValueList;
	For Each FileNested In FilesTree.GetItems() Do
		If FileNested.Check = True Then
			SelectedFiles.Add(FileNested.FullPath);
		EndIf;
	EndDo;
	
	For Each FileNested In FilesTree.GetItems() Do
		FillFileSystem(PseudoFileSystem, FileNested);
	EndDo;
	
	If SelectedFiles.Count() = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'No files to add.';"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonClient.MessageToUser(
			NStr("en = 'Please select a folder.';"), , "FolderForAdding");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler = New NotifyDescription("AddRunAfterImport", ThisObject);
	ExecutionParameters.Owner = FolderForAdding;
	ExecutionParameters.SelectedFiles = SelectedFiles; 
	ExecutionParameters.Comment = Comment;
	ExecutionParameters.StoreVersions = StoreVersions;
	ExecutionParameters.ShouldDeleteAddedFiles = ShouldDeleteAddedFiles;
	ExecutionParameters.Recursively = True;
	ExecutionParameters.FormIdentifier = UUID;
	ExecutionParameters.PseudoFileSystem = PseudoFileSystem;
	ExecutionParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AddRunAfterImport(Result, ExecutionParameters) Export
	Close();
	If Result <> Undefined Then
		Notify("Write_FilesFolders", New Structure, Result.FolderForAddingCurrent);
	EndIf;
EndProcedure

&AtClient
Procedure FillFileList(FilePath, Val TreeItems, TopLevelItem, DirectoriesOnly = Undefined)
	
	MovedFile = New File(FilePath);
	
	NewItem = TreeItems.Add();
	NewItem.FullPath = MovedFile.FullName;
	NewItem.FileName = MovedFile.Name;
	NewItem.Check = True;
	
	If MovedFile.IsDirectory() Then
		NewItem.PictureIndex = 2; // Folder
	Else
		NewItem.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(MovedFile.Extension);
	EndIf;
		
	If MovedFile.IsDirectory() Then
		
		Path = MovedFile.FullName + GetPathSeparator();
		
		FilesFound = FindFiles(Path, GetAllFilesMask());
		
		FileSorted = New Array;
		
		// Folders come first.
		For Each FileNested In FilesFound Do
			If FileNested.IsDirectory() Then
				FileSorted.Add(FileNested.FullName);
			EndIf;
		EndDo;
		
		// Then come files.
		For Each FileNested In FilesFound Do
			If Not FileNested.IsDirectory() Then
				FileSorted.Add(FileNested.FullName);
			EndIf;
		EndDo;
		
		For Each FileNested In FileSorted Do
			FillFileList(FileNested, NewItem.GetItems(), False);
		EndDo;
		
	Else
		
		If TopLevelItem Then
			DirectoriesOnly = False;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillFileSystem(PseudoFileSystem, TreeItem)
	If TreeItem.Check = True Then
		SubordinateItems = TreeItem.GetItems();
		If SubordinateItems.Count() <> 0 Then
			
			FilesAndSubdirectories = New Array;
			For Each FileNested In SubordinateItems Do
				FillFileSystem(PseudoFileSystem, FileNested);
				
				If FileNested.Check = True Then
					FilesAndSubdirectories.Add(FileNested.FullPath);
				EndIf;
			EndDo;
			
			PseudoFileSystem.Insert(TreeItem.FullPath, FilesAndSubdirectories);
		EndIf;
	EndIf;
EndProcedure

// Recursively marks all child items.
&AtClient
Procedure SetMark(TreeItem, Check)
	SubordinateItems = TreeItem.GetItems();
	
	For Each FileNested In SubordinateItems Do
		FileNested.Check = Check;
		SetMark(FileNested, Check);
	EndDo;
EndProcedure

&AtServer
Procedure SetCodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

#EndRegion
