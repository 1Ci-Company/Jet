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
	
	If Parameters.ExportFolder <> Undefined Then
		WhatToSave = Parameters.ExportFolder;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		
		EncryptedFilesExtension =
			ModuleDigitalSignature.PersonalSettings().EncryptedFilesExtension;
	Else
		EncryptedFilesExtension = "p7m";
	EndIf;
	
	FilesStorageCatalogName       = Parameters.FilesStorageCatalogName;
	FileVersionsStorageCatalogName = Parameters.FileVersionsStorageCatalogName;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Use the last used export directory as the "My documents" export directory.
	// 
	FolderForExport = FilesOperationsInternalClient.DumpDirectory();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FolderForExportOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	If Not IsBlankString(Item.EditText) Then
		FileSystemClient.OpenExplorer(Item.EditText);
	EndIf;
	
EndProcedure

&AtClient
Procedure FolderForExportStartChoice(Item, ChoiceData, StandardProcessing)
	
	// Open the window of saving folder selection.
	StandardProcessing = False;
	SelectingFile = New FileDialog(FileDialogMode.ChooseDirectory);
	SelectingFile.Multiselect = False;
	SelectingFile.Directory = Item.EditText;
	If SelectingFile.Choose() Then
		FolderForExport = SelectingFile.Directory + GetPathSeparator();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveFolder()
	
	If IsBlankString(FolderForExport) Or FolderForExport = GetPathSeparator() Then
		ShowMessageBox(, NStr("en = 'Select a folder.';"));
		Return;
	EndIf;
	
	If Not StrEndsWith(FolderForExport, GetPathSeparator()) Then
		FolderForExport = FolderForExport + GetPathSeparator();
	EndIf;
	
	// Checking if the dump directory exists. Create it if it does not.
	DumpDirectory = New File(FolderForExport);
	
	If Not DumpDirectory.Exists() Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Folder ""%1"" is not found.
			           |Please select another folder.';"),
			FolderForExport));
		Return;
	EndIf;
	
	FullExportPath = FolderForExport + String(WhatToSave) + GetPathSeparator();
	If TransliterateFileAndFolderNames Then
		FullExportPath = StringFunctionsClient.LatinString(FullExportPath);
	EndIf;
	
	// If exported folder does not exist, create it.
	DumpDirectory = New File(FullExportPath);
	If Not DumpDirectory.Exists() Then
		ErrorText = "";
		Try
			CreateDirectory(FullExportPath);
			If Not DumpDirectory.Exists() Then
				Raise NStr("en = 'The created subfolder is not found.';");
			EndIf;
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create subfolder ""%1"" in folder ""%2"". Reason:
				           |%3';"),
				String(WhatToSave),
				FolderForExport,
				ErrorProcessing.BriefErrorDescription(ErrorInfo));
		EndTry;
		If ErrorText <> "" Then
			ShowMessageBox(, ErrorText);
			Return;
		EndIf;
	EndIf;
	
	// Receiving the list of exported files.
	GenerateFilesTree(WhatToSave);
	
	// After that start exporting
	Handler = New NotifyDescription("SaveFolderCompletion", ThisObject);
	ProcessFilesTree(Handler, FilesTree, FullExportPath, WhatToSave, Undefined);
EndProcedure

&AtClient
Procedure SaveFolderCompletion(Result, ExecutionParameters) Export
	If Result.Success = True Then
		PathToSave = FolderForExport;
		CommonServerCall.CommonSettingsStorageSave("ExportFolderName", "ExportFolderName",  PathToSave);
		
		ShowUserNotification(NStr("en = 'Export folder';"),,
		             StringFunctionsClientServer.SubstituteParametersToString(
		               NStr("en = 'The ""%1"" folder is exported
		                          |to the ""%2"" directory on the computer.';"),
		               String(WhatToSave), String(FolderForExport) ) );
		
		Close();
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateFilesTree(Val FolderParent)
	
	Query = New Query;
	QueryText =
	"SELECT ALLOWED
	|	Files.FileOwner AS Folder,
	|	CAST(Files.FileOwner AS Catalog.FilesFolders).Description AS FolderDescription,
	|	&CurrentVersion AS CurrentVersion,
	|	Files.Description AS FullDescr,
	|	Files.Extension AS Extension,
	|	Files.Size AS Size,
	|	Files.UniversalModificationDate AS UniversalModificationDate,
	|	Files.Ref AS Ref,
	|	Files.DeletionMark AS DeletionMark,
	|	Files.Encrypted AS Encrypted
	|FROM
	|	Catalog.Files AS Files
	|WHERE
	|	Files.FileOwner IN HIERARCHY(&Ref)
	|	AND Files.DeletionMark = FALSE
	|TOTALS BY
	|	Folder HIERARCHY";
	Query.Parameters.Insert("Ref", FolderParent);
	
	If Not IsBlankString(FilesStorageCatalogName) Then
		
		QueryText = StrReplace(QueryText, "Files", FilesStorageCatalogName);
		QueryText = StrReplace(QueryText, "&CurrentVersion", FilesStorageCatalogName + ".Ref");
		QueryText = StrReplace(QueryText, "FileOwner", "Parent");
		QueryText = StrReplace(QueryText, "FilesFolders", FilesStorageCatalogName);
		
	Else
		
		CurrentVersionChoice = "CASE
		|		WHEN Files.CurrentVersion = VALUE(Catalog.FilesVersions.EmptyRef)
		|			THEN Files.Ref
		|		ELSE ISNULL(Files.CurrentVersion, VALUE(Catalog.FilesVersions.EmptyRef))
		|	END";
		
		QueryText = StrReplace(QueryText, "&CurrentVersion", CurrentVersionChoice);
		
	EndIf;
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	ExportedTable = Result.Unload(QueryResultIteration.ByGroupsWithHierarchy);
	If TransliterateFileAndFolderNames And ExportedTable.Rows.Count() > 0 Then
		RootFolderForExport = ExportedTable.Rows[0];
		RootFolderForExport.FolderDescription = StringFunctions.LatinString(RootFolderForExport.FolderDescription);
		RootFolderForExport.FullDescr = StringFunctions.LatinString(RootFolderForExport.FullDescr);
		RootFolderForExport.Extension = StringFunctions.LatinString(RootFolderForExport.Extension);
		ChangeNamesOfFilesAndFolders(RootFolderForExport);
	EndIf;
	
	ValueToFormAttribute(ExportedTable, "FilesTree");
	
EndProcedure

// Recursive function that exports files to the computer.
//
// Parameters:
//   ResultHandler - NotifyDescription
//                        - Structure
//                        - Undefined - description of the procedure that receives
//                          the method result.
//   TableOfFiles - FormDataTree
//                 - FormDataTreeItem - value tree with files to export.
//   BaseSaveDirectory - String - a row with the folder name, to which files are saved.
//                 It recreates the folder structure (as in the file tree)
//                 if necessary.
//   ParentFolder - CatalogRef.FilesFolders - items to save.
//   CommonParameters - Structure:
//       * ForAllFiles - Boolean -
//                 True if the user picks an action when overwriting the file and
//                 selects the "For all" check box. No more questions are asked.
//                 False if a question is asked every time a file in the infobase
//                 has the same name as a file on the computer.
//       * BaseAction - DialogReturnCode -
//                 When performing one action for all conflicts
//                 when writing a file (the ForAllFiles parameter is True),
//                 performs the action specified by that parameter.
//                 DialogReturnCode.Yes - Rewrite.
//                 DialogReturnCode.Ignore - Skip a file.
//                 DialogReturnCode.Abort - Cancel export.
//
&AtClient
Procedure ProcessFilesTree(ResultHandler, TableOfFiles, BaseSaveDirectory, ParentFolder, CommonParameters)
	
	If CommonParameters = Undefined Then
		CommonParameters = New Structure;
		CommonParameters.Insert("BaseAction", DialogReturnCode.Ignore);
		CommonParameters.Insert("ForAllFiles", False);
		CommonParameters.Insert("NotMetFolderToBeExportedYet", True);
	EndIf;
	
	ExecutionParameters = ExecutionParameters(ResultHandler, TableOfFiles, BaseSaveDirectory,
		ParentFolder, CommonParameters);
	
	CompletionHandler = New NotifyDescription("ProcessFilesTree2", ThisObject);
	FilesOperationsInternalClient.RegisterCompletionHandler(ExecutionParameters, CompletionHandler);
	
	StartIterateThroughFilesTree(ExecutionParameters);
EndProcedure

// Returns:
//  Structure:
//   * ResultHandler - See ProcessFilesTree.ResultHandler
//   * TableOfFiles - See ProcessFilesTree.TableOfFiles
//   * BaseSaveDirectory - See ProcessFilesTree.BaseSaveDirectory
//   * ParentFolder - See ProcessFilesTree.ParentFolder
//   * CommonParameters - See ProcessFilesTree.CommonParameters
//   * Result - Undefined, DialogReturnCode - is added later
//   * Success - Boolean
//   * Items - See DataProcessor.FilesOperations.Form.ExportFolderForm.FilesTree
//   * UBound - Number
//   * IndexOf - Number
//   * LoopStartRequired - Boolean
//   * WritingFile - FormDataTreeItem of See DataProcessor.FilesOperations.Form.ExportFolderForm.FilesTree
//
&AtClient
Function ExecutionParameters(Val ResultHandler, Val TableOfFiles, Val BaseSaveDirectory, Val ParentFolder, Val CommonParameters)
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ResultHandler", ResultHandler);
	ExecutionParameters.Insert("TableOfFiles", TableOfFiles);
	ExecutionParameters.Insert("BaseSaveDirectory", BaseSaveDirectory);
	ExecutionParameters.Insert("ParentFolder", ParentFolder);
	ExecutionParameters.Insert("CommonParameters", CommonParameters);
	
	// Result parameters.
	ExecutionParameters.Insert("Success", False);
	
	// Loop parameters.
	ExecutionParameters.Insert("Items", ExecutionParameters.TableOfFiles.GetItems());
	ExecutionParameters.Insert("UBound", ExecutionParameters.Items.Count()-1);
	ExecutionParameters.Insert("IndexOf",   -1);
	ExecutionParameters.Insert("LoopStartRequired", True);

	ExecutionParameters.Insert("WritingFile", Undefined);

	Return ExecutionParameters;

EndFunction

&AtClient
Procedure StartIterateThroughFilesTree(ExecutionParameters)
	If Not ExecutionParameters.LoopStartRequired Then
		Return;
	EndIf;

	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		Return;
	EndIf;
	
	ExecutionParameters.IndexOf = ExecutionParameters.IndexOf + 1;
	ExecutionParameters.LoopStartRequired = False;
	
	For IndexOf = ExecutionParameters.IndexOf To ExecutionParameters.UBound Do
		ExecutionParameters.WritingFile = ExecutionParameters.Items[IndexOf];
		ExecutionParameters.IndexOf = IndexOf;
		ProcessFilesTree1(ExecutionParameters);
		If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
			Return;
		EndIf;
	EndDo;
	
	ExecutionParameters.Success = True;
	FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree1(ExecutionParameters)
	If ExecutionParameters.CommonParameters.NotMetFolderToBeExportedYet = True Then
		If ExecutionParameters.WritingFile.Folder = WhatToSave Then
			ExecutionParameters.CommonParameters.NotMetFolderToBeExportedYet = False;
		EndIf;
	EndIf;
	
	If ExecutionParameters.CommonParameters.NotMetFolderToBeExportedYet = True Then
		
		CompletionHandler = New NotifyDescription("ProcessFilesTree2", ThisObject);
		FilesOperationsInternalClient.RegisterCompletionHandler(ExecutionParameters, CompletionHandler);
		
		ProcessFilesTree(ExecutionParameters, ExecutionParameters.WritingFile, ExecutionParameters.BaseSaveDirectory, 
			ExecutionParameters.WritingFile.Folder, ExecutionParameters.CommonParameters);
		
		If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
			Return;
		EndIf;
		
		ProcessFilesTree2(ExecutionParameters.AsynchronousDialog.ResultWhenNotOpen, ExecutionParameters);
		Return;
	EndIf;
	
	ProcessFilesTree3(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree2(Result, ExecutionParameters) Export
	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		ExecutionParameters.LoopStartRequired = True;
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, False);
	EndIf;
	
	If Result.Success <> True Then
		ExecutionParameters.Success = False;
		ExecutionParameters.LoopStartRequired = False; // Loop restart is not required.
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	EndIf;
	
	StartIterateThroughFilesTree(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree3(ExecutionParameters)
	ExecutionParameters.Insert("SaveFileBaseDirectory", ExecutionParameters.BaseSaveDirectory);
	If ExecutionParameters.WritingFile.Folder <> WhatToSave
		And ExecutionParameters.WritingFile.CurrentVersion = Undefined
		And ExecutionParameters.WritingFile.Folder <> ExecutionParameters.ParentFolder Then
		ExecutionParameters.SaveFileBaseDirectory = ExecutionParameters.SaveFileBaseDirectory
			+ ExecutionParameters.WritingFile.FolderDescription	+ GetPathSeparator();
	EndIf;
	
	Folder = New File(ExecutionParameters.SaveFileBaseDirectory);
	If Not Folder.Exists() Then
		CreateSubdirectory(ExecutionParameters); 
		Return;
	EndIf;
	
	ProcessFilesTree6(ExecutionParameters);
EndProcedure

&AtClient
Procedure CreateSubdirectory(ExecutionParameters)
	ErrorText = "";
	Try
		CreateDirectory(ExecutionParameters.SaveFileBaseDirectory);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot create the ""%1"" directory due to:
				|%2';"),
			ExecutionParameters.SaveFileBaseDirectory,
			ErrorProcessing.BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	If ErrorText <> "" Then
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, True);
		Handler = New NotifyDescription("ProcessFilesTree5", ThisObject, ExecutionParameters);
		ShowQueryBox(Handler, ErrorText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
		Return;
	EndIf;
	
	ProcessFilesTree6(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree5(Response, ExecutionParameters) Export
	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		ExecutionParameters.LoopStartRequired = True;
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, False);
	EndIf;
	
	If Response = DialogReturnCode.Abort Then
		ExecutionParameters.Success = False;
		ExecutionParameters.LoopStartRequired = False; 
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	ElsIf Response = DialogReturnCode.Ignore Then
		ExecutionParameters.Success = True;
		ExecutionParameters.LoopStartRequired = False; 
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	EndIf;
	
	// Trying to create a folder again.
	CreateSubdirectory(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree6(ExecutionParameters)

	SubordinateItems = ExecutionParameters.WritingFile.GetItems();
	If SubordinateItems.Count() > 0 Then
		
		CompletionHandler = New NotifyDescription("ProcessFilesTree7", ThisObject);
		FilesOperationsInternalClient.RegisterCompletionHandler(ExecutionParameters, CompletionHandler);
		
		ProcessFilesTree(ExecutionParameters, ExecutionParameters.WritingFile,
			ExecutionParameters.SaveFileBaseDirectory, ExecutionParameters.WritingFile.Folder,
			ExecutionParameters.CommonParameters);
		
		If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
			Return;
		EndIf;
		
		ProcessFilesTree7(ExecutionParameters.AsynchronousDialog.ResultWhenNotOpen, ExecutionParameters);
		Return;
	EndIf;
	
	ProcessFilesTree8(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree7(Result, ExecutionParameters) Export
	
	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		ExecutionParameters.LoopStartRequired = True;
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, False);
	EndIf;
	
	If Result.Success <> True Then
		ExecutionParameters.Success = False;
		ExecutionParameters.LoopStartRequired = False;
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	EndIf;
	
	// Continue processing the item.
	ProcessFilesTree8(ExecutionParameters);
	
	// Restart if the dialog was open.
	StartIterateThroughFilesTree(ExecutionParameters);
	
EndProcedure

&AtClient
Procedure ProcessFilesTree8(ExecutionParameters)
	If (ExecutionParameters.WritingFile.CurrentVersion <> Undefined
		And ExecutionParameters.WritingFile.CurrentVersion.IsEmpty()) Or ExecutionParameters.WritingFile.CurrentVersion = Undefined Then
		// This is an item of Files catalog without a file. Skip it.
		Return;
	EndIf;
	
	// Writing file to the base directory.
	ExecutionParameters.Insert("FileNameWithExtension", Undefined);
	ExecutionParameters.FileNameWithExtension = CommonClientServer.GetNameWithExtension(
		ExecutionParameters.WritingFile.FullDescr,
		ExecutionParameters.WritingFile.Extension);
		
	CommonInternalClient.ShortenFileName(ExecutionParameters.FileNameWithExtension);
	
	If ExecutionParameters.WritingFile.Encrypted Then
		ExecutionParameters.FileNameWithExtension = ExecutionParameters.FileNameWithExtension + "." + EncryptedFilesExtension;
	EndIf;
	ExecutionParameters.Insert("FullFileName", ExecutionParameters.SaveFileBaseDirectory + ExecutionParameters.FileNameWithExtension);
	
	ExecutionParameters.Insert("Result", Undefined);
	ProcessFilesTree9(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree9(ExecutionParameters)
	ExecutionParameters.Insert("FileOnHardDrive", New File(ExecutionParameters.FullFileName));
	If ExecutionParameters.FileOnHardDrive.Exists() And ExecutionParameters.FileOnHardDrive.IsDirectory() Then
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'A file named
			           |""%1""
			           |is found instead of a folder.
			           |
			           |Do you want to download the file again?';"),
			ExecutionParameters.FullFileName);
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, True);
		Handler = New NotifyDescription("ProcessFilesTree10", ThisObject, ExecutionParameters);
		ShowQueryBox(Handler, QueryText, QuestionDialogMode.RetryCancel, , DialogReturnCode.Cancel);
		Return;
	EndIf;
	
	// There is no file, proceed to the next step.
	ExecutionParameters.Result = DialogReturnCode.Retry;
	ProcessFilesTree11(ExecutionParameters);
EndProcedure

// Parameters:
//  Response - DialogReturnCode
//  ExecutionParameters - See ExecutionParameters
//
&AtClient
Procedure ProcessFilesTree10(Response, ExecutionParameters) Export
	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		ExecutionParameters.LoopStartRequired = True;
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, False);
	EndIf;
	
	If Response = DialogReturnCode.Retry Then
		// Ignore the file.
		ProcessFilesTree9(ExecutionParameters);
		Return;
	EndIf;
	
	// Continue processing the item.
	ExecutionParameters.Result = DialogReturnCode.Cancel;
	ProcessFilesTree11(ExecutionParameters);
	
	// Restart if the dialog was open.
	StartIterateThroughFilesTree(ExecutionParameters);
EndProcedure

// Parameters:
//  ExecutionParameters - See ExecutionParameters
//
&AtClient
Procedure ProcessFilesTree11(ExecutionParameters)
	If ExecutionParameters.Result = DialogReturnCode.Cancel Then
		// Ignoring the file named like a folder.
		Return;
	EndIf;
	
	ExecutionParameters.Result = DialogReturnCode.No;
	
	// Asking what to do with the current file.
	If ExecutionParameters.FileOnHardDrive.Exists() Then
		
		// If the file is for reading only and the change time is less than in the infobase, simply rewrite it.
		If  ExecutionParameters.FileOnHardDrive.GetReadOnly()
			And ExecutionParameters.FileOnHardDrive.GetModificationUniversalTime() <= ExecutionParameters.WritingFile.UniversalModificationDate Then
			ExecutionParameters.Result = DialogReturnCode.Yes;
		Else
			If Not ExecutionParameters.CommonParameters.ForAllFiles Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Folder ""%1""
					           |contains file ""%2"".
					           |The existing file size is %3 bytes, last modified on %4.
					           |The stored file size is %5 bytes, last modified on %6.
					           |
					           |Do you want to overwrite the existing file with the file from the storage?';"),
					ExecutionParameters.SaveFileBaseDirectory,
					ExecutionParameters.FileNameWithExtension,
					ExecutionParameters.FileOnHardDrive.Size(),
					ToLocalTime(ExecutionParameters.FileOnHardDrive.GetModificationUniversalTime()),
					ExecutionParameters.WritingFile.Size,
					ToLocalTime(ExecutionParameters.WritingFile.UniversalModificationDate));
				
				ParametersStructure = New Structure;
				ParametersStructure.Insert("MessageText",   MessageText);
				ParametersStructure.Insert("ApplyForAll", ExecutionParameters.CommonParameters.ForAllFiles);
				ParametersStructure.Insert("BaseAction",  String(ExecutionParameters.CommonParameters.BaseAction));
				
				FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, True);
				Handler = New NotifyDescription("ProcessFilesTree12", ThisObject, ExecutionParameters);
				
				OpenForm("DataProcessor.FilesOperations.Form.FileExists", ParametersStructure, , , , , Handler);
				Return;
			EndIf;
			
			ExecutionParameters.Result = ExecutionParameters.CommonParameters.BaseAction;
			ProcessFilesTree13(ExecutionParameters);
			Return;
		EndIf;
	EndIf;
	
	// If there is no file, do not ask.
	ExecutionParameters.Result = DialogReturnCode.Yes;
	ProcessFilesTree14(ExecutionParameters);
EndProcedure

// Parameters:
//  Result - DialogReturnCode
//  ExecutionParameters - See ExecutionParameters
//
&AtClient
Procedure ProcessFilesTree12(Result, ExecutionParameters) Export
	If FilesOperationsInternalClient.LockingFormOpen(ExecutionParameters) Then
		ExecutionParameters.LoopStartRequired = True;
		FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, False);
	EndIf;
	
	ExecutionParameters.Result = Result.ReturnCode;
	ExecutionParameters.CommonParameters.ForAllFiles = Result.ApplyForAll;
	ExecutionParameters.CommonParameters.BaseAction = ExecutionParameters.Result;
	
	// Continue processing the item.
	ProcessFilesTree13(ExecutionParameters);
	
	// Restart loop if an asynchronous dialog box was opened.
	StartIterateThroughFilesTree(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree13(ExecutionParameters)
	If ExecutionParameters.Result = DialogReturnCode.Abort Then
		// Abort export.
		ExecutionParameters.Success = False;
		ExecutionParameters.LoopStartRequired = False; // Loop restart is not required.
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	ElsIf ExecutionParameters.Result = DialogReturnCode.Ignore Then
		// Skip the file.
		Return;
	EndIf;
	
	// Writing file to the file system if it is possible.
	If ExecutionParameters.Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ProcessFilesTree14(ExecutionParameters);
EndProcedure

&AtClient
Procedure ProcessFilesTree14(ExecutionParameters)

	ExecutionParameters.FileOnHardDrive = New File(ExecutionParameters.FullFileName);
	If ExecutionParameters.FileOnHardDrive.Exists() Then
		ExecutionParameters.FileOnHardDrive.SetReadOnly(False);
		
		// Always delete and then generate again.
		ErrorInfo = Undefined;
		Try
			DeleteFiles(ExecutionParameters.FullFileName);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
		
		If ErrorInfo <> Undefined Then
			ProcessFilesTree15(ErrorInfo, ExecutionParameters);
			Return;
		EndIf;
	EndIf;
	
	// Re-write the file.
	FileAddressToOpen = FilesOperationsInternalServerCall.GetURLToOpen(
		ExecutionParameters.WritingFile.CurrentVersion,
		UUID);
	
	Try
		FilesToObtain  = New Array;
		FileToPass = New TransferableFileDescription();
		ObtainedFiles  = New Array;// Array of File

		FileToPass.Location = FileAddressToOpen;
		FileToPass.Name      = ExecutionParameters.FullFileName;
		FilesToObtain.Add(FileToPass);
		
		GetFiles(FilesToObtain, ObtainedFiles, ExecutionParameters.SaveFileBaseDirectory, False);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	If ErrorInfo <> Undefined Then
		ProcessFilesTree15(ErrorInfo, ExecutionParameters);
		Return;
	EndIf;
		
	If ObtainedFiles.Count() = 0 
		Or IsBlankString(ObtainedFiles[0].Name) Then
		// File was not received.
		Return;
	EndIf;
	
	// For the option of storing files in volumes, delete the file from the temporary storage after receiving it.
	If IsTempStorageURL(FileAddressToOpen) Then
		DeleteFromTempStorage(FileAddressToOpen);
	EndIf;
	
	ExecutionParameters.FileOnHardDrive = New File(ExecutionParameters.FullFileName);
	
	Try
		ExecutionParameters.FileOnHardDrive.SetReadOnly(True);
		// Setting the modification time as in the infobase.
		ExecutionParameters.FileOnHardDrive.SetModificationUniversalTime(
			ExecutionParameters.WritingFile.UniversalModificationDate);
	Except
		ErrorInfo = ErrorInfo();
	EndTry;
	
	If ErrorInfo <> Undefined Then
		ProcessFilesTree15(ErrorInfo, ExecutionParameters);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessFilesTree15(ErrorInfo, ExecutionParameters)
	// An error occurred when writing the file and changing its attributes.
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot save the file
		           |""%1""
		           |due to:
		           |%2';"),
		ExecutionParameters.FullFileName,
		ErrorProcessing.BriefErrorDescription(ErrorInfo));
	
	FilesOperationsInternalClient.SetLockingFormFlag(ExecutionParameters, True);
	Handler = New NotifyDescription("ProcessFilesTree16", ThisObject, ExecutionParameters);
	
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.AbortRetryIgnore, , DialogReturnCode.Retry);
EndProcedure

&AtClient
Procedure ProcessFilesTree16(Response, ExecutionParameters) Export
	If Response = DialogReturnCode.Abort Then
		// Just exit with an error.
		ExecutionParameters.Success = False;
		ExecutionParameters.LoopStartRequired = False; // Do not restart the cycle.
		// False.
		FilesOperationsInternalClient.ReturnResult(ExecutionParameters.ResultHandler, ExecutionParameters);
		Return;
	ElsIf Response = DialogReturnCode.Ignore Then
		// Skipping this file and proceeding to the next step.
		Return;
	EndIf;
	
	// Trying to create a folder again.
	ProcessFilesTree14(ExecutionParameters);
EndProcedure

&AtServer
Procedure ChangeNamesOfFilesAndFolders(TreeItem)
	
	For Each FileOrFolder In TreeItem.Rows Do
		FileOrFolder.FolderDescription = StringFunctions.LatinString(FileOrFolder.FolderDescription);
		FileOrFolder.FullDescr = StringFunctions.LatinString(FileOrFolder.FullDescr);
		FileOrFolder.Extension = StringFunctions.LatinString(FileOrFolder.Extension);
		ChangeNamesOfFilesAndFolders(FileOrFolder);
	EndDo;
	
EndProcedure;

#EndRegion
