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
	
	If Parameters.FolderForAdding = Undefined Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	FilesGroup = Parameters.FilesGroup;
	FolderForAdding = Parameters.FolderForAdding;
	FolderToAddAsString = Common.SubjectString(FolderForAdding);
	StoreVersions = FilesOperationsInternalServerCall.IsDirectoryFiles(FolderForAdding);
	Items.StoreVersions.Visible = StoreVersions;
	
	If TypeOf(Parameters.FileNamesArray) = Type("Array") Then
		For Each FilePath In Parameters.FileNamesArray Do
			MovedFile = New File(FilePath);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FilePath;
			NewItem.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(MovedFile.Extension);
		EndDo;
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

#Region FormTableItemsEventHandlersSelectedFiles

&AtClient
Procedure SelectedFilesBeforeAddRow(Item, Cancel, Copy)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure AddExecute()
	
	ClearMessages();
	
	FieldsNotFilled = False;
	
	If SelectedFiles.Count() = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'No files to add.';"), , "SelectedFiles");
		FieldsNotFilled = True;
	EndIf;
	
	If FieldsNotFilled = True Then
		Return;
	EndIf;
	
	SelectedFileValueList = New ValueList;
	For Each ListLine In SelectedFiles Do
		SelectedFileValueList.Add(ListLine.Path);
	EndDo;
	
#If WebClient Then
	
	OperationArray = New Array;
	
	For Each ListLine In SelectedFiles Do
		CallDetails = New Array;
		CallDetails.Add("PutFiles");
		
		Files = New Array;
		LongDesc = New TransferableFileDescription(ListLine.Path, "");
		Files.Add(LongDesc);
		CallDetails.Add(Files);
		
		CallDetails.Add(Undefined); // Obsolete.
		CallDetails.Add(Undefined); // Obsolete.
		CallDetails.Add(False);         // Interactively = False
		
		OperationArray.Add(CallDetails);
	EndDo;
	
	If Not RequestUserPermission(OperationArray) Then
		// User did not give a permission.
		Close();
		Return;
	EndIf;	
#EndIf	
	
	AddedFiles = New Array;
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("AddedFiles", AddedFiles);
	Handler = New NotifyDescription("AddExecuteCompletion", ThisObject, HandlerParameters);
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler          = Handler;
	ExecutionParameters.Owner                      = FolderForAdding;
	ExecutionParameters.SelectedFiles                = SelectedFileValueList; 
	ExecutionParameters.Comment                   = Comment;
	ExecutionParameters.StoreVersions                 = StoreVersions;
	ExecutionParameters.ShouldDeleteAddedFiles   = ShouldDeleteAddedFiles;
	ExecutionParameters.Recursively                    = False;
	ExecutionParameters.FormIdentifier            = UUID;
	ExecutionParameters.AddedFiles              = AddedFiles;
	ExecutionParameters.Encoding                     = FileTextEncoding;
	ExecutionParameters.FilesGroup                  = FilesGroup;
	
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
EndProcedure

&AtClient
Procedure SelectFilesExecute()
	
	Handler = New NotifyDescription("SelectFilesExecuteAfterInstallExtension", ThisObject);
	FilesOperationsInternalClient.ShowFileSystemExtensionInstallationQuestion(Handler);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetCodingCommandPresentation(Presentation)
	
	Commands.SelectEncoding.Title = Presentation;
	
EndProcedure

&AtClient
Procedure AddExecuteCompletion(Result, ExecutionParameters) Export
	Close();
	
	Source = Undefined;
	AddedFilesCount = Result.AddedFiles.Count();
	If AddedFilesCount > 0 Then
		Source = Result.AddedFiles[AddedFilesCount - 1].FileRef;
	EndIf;
	FileWriteNotificationParameters = FilesOperationsInternalClient.FileWriteNotificationParameters();
	FileWriteNotificationParameters.IsNew = True;
	Notify("Write_File", FileWriteNotificationParameters, Source);
EndProcedure

&AtClient
Procedure SelectFilesExecuteAfterInstallExtension(ExtensionInstalled, ExecutionParameters) Export
	If Not ExtensionInstalled Then
		Return;
	EndIf;
	
	Mode = FileDialogMode.Open;
	
	OpenFileDialog = New FileDialog(Mode);
	OpenFileDialog.FullFileName = "";
	Filter = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = True;
	OpenFileDialog.Title = NStr("en = 'Select files';");
	If OpenFileDialog.Choose() Then
		SelectedFiles.Clear();
		
		FilesArray = OpenFileDialog.SelectedFiles;
		For Each FileName In FilesArray Do
			MovedFile = New File(FileName);
			NewItem = SelectedFiles.Add();
			NewItem.Path = FileName;
			NewItem.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(MovedFile.Extension);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion
