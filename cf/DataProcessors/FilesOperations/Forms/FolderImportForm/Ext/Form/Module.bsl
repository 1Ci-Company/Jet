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
	
	If Not ValueIsFilled(Parameters.DirectoryOnHardDrive) Then
		Raise NStr("en = 'The data processor cannot be opened manually.';");
	EndIf;
	
	FilesGroup = Parameters.FilesGroup;
	Directory = Parameters.DirectoryOnHardDrive;
	FolderForAdding = Parameters.FolderForAdding;
	FolderToAddAsString = Common.SubjectString(FolderForAdding);
	DirectoriesChoice = True;
	StoreVersions = FilesOperationsInternalServerCall.IsDirectoryFiles(FolderForAdding);
	Items.StoreVersions.Visible = StoreVersions;
	
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

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SelectedDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	// Code is called only from IE or thin client, check on the web client is not required.
	Mode = FileDialogMode.ChooseDirectory;
	
	OpenFileDialog = New FileDialog(Mode);
	
	OpenFileDialog.Directory = Directory;
	OpenFileDialog.FullFileName = "";
	Filter = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All files (%1)|%1';"), GetAllFilesMask());
	OpenFileDialog.Filter = Filter;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = NStr("en = 'Select directory';");
	If OpenFileDialog.Choose() Then
		
		If DirectoriesChoice = True Then 
			
			Directory = OpenFileDialog.Directory;
			
		EndIf;
		
	EndIf;
		
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ImportExecute()
	
	If IsBlankString(Directory) Then
		
		CommonClient.MessageToUser(
			NStr("en = 'Select a folder for import.';"), , "Directory");
		Return;
		
	EndIf;
	
	If FolderForAdding.IsEmpty() Then
		CommonClient.MessageToUser(
			NStr("en = 'Please select a folder.';"), , "FolderForAdding");
		Return;
	EndIf;
	
	SelectedFiles = New ValueList;
	SelectedFiles.Add(Directory);
	
	Handler = New NotifyDescription("ImportCompletion", ThisObject);
	
	ExecutionParameters = FilesOperationsInternalClient.FilesImportParameters();
	ExecutionParameters.ResultHandler          = Handler;
	ExecutionParameters.Owner                      = FolderForAdding;
	ExecutionParameters.SelectedFiles                = SelectedFiles; 
	ExecutionParameters.Comment                   = LongDesc;
	ExecutionParameters.StoreVersions                 = StoreVersions;
	ExecutionParameters.ShouldDeleteAddedFiles   = ShouldDeleteAddedFiles;
	ExecutionParameters.Recursively                    = True;
	ExecutionParameters.FormIdentifier            = UUID;
	ExecutionParameters.Encoding                     = FileTextEncoding;
	ExecutionParameters.FilesGroup                  = FilesGroup;
	FilesOperationsInternalClient.ExecuteFilesImport(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure ImportCompletion(Result, ExecutionParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	Close();
	Notify("Write_FilesFolders", New Structure, Result.FolderForAddingCurrent);
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

#EndRegion
