///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

#Region FilesImportFromFileSystem

// Continuation of procedure FileSystemClient.ShowPutFile.
Procedure ShowPutFileOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	Interactively         = Context.Interactively;
	
	If Not ExtensionAttached
		And Not Interactively Then
		Raise NStr("en = 'Cannot upload the file because 1C:Enterprise Extension is not installed.';");
	EndIf;
		
	Try
		StartProcessingPuttingFiles(Context);
	Except
		Dialog               = Context.Dialog; // FileDialog - 
		Interactively         = Context.Interactively;
		CompletionHandler = Context.CompletionHandler;
	
		ProcessingResultsParameters = New Structure;
		ProcessingResultsParameters.Insert("MultipleChoice",   Dialog.Multiselect);
		ProcessingResultsParameters.Insert("CompletionHandler", CompletionHandler);
		
		NotifyDescription = New NotifyDescription(
			"AfterWarnedAboutFileUnavailability", ThisObject, ProcessingResultsParameters);
		ErrorInfo = ErrorInfo();
		ErrorDescription = ErrorInfo.Cause.Description;
		If StrFind(ErrorDescription, "32(0x00000020)") Then 
			ShowMessageBox(NotifyDescription, NStr("en = 'Complete the operation with the file in another application.';"), , NStr("en = 'The file is opened in another application';"));
		Else
			Raise ErrorDescription;
		EndIf;
		
	EndTry;

EndProcedure

// Runs after a warning about an unavailable file.
// 
// Parameters:
//  ProcessingResultsParameters - Structure:
//   * MultipleChoice - Boolean
//   * CompletionHandler - NotifyDescription
//
Procedure AfterWarnedAboutFileUnavailability(ProcessingResultsParameters) Export

		If ProcessingResultsParameters.MultipleChoice Then
			ProcessPutFilesResult(Undefined, ProcessingResultsParameters);
		Else
			ProcessPutFileResult(False, Undefined, Undefined,	ProcessingResultsParameters);
		EndIf;
	
EndProcedure
	
Procedure StartProcessingPuttingFiles(Context)
	
	Dialog               = Context.Dialog; // FileDialog - 
	Interactively         = Context.Interactively;
	FilesToUpload     = Context.FilesToUpload;
	FormIdentifier   = Context.FormIdentifier;
	CompletionHandler = Context.CompletionHandler;
	
	ProcessingResultsParameters = New Structure;
	ProcessingResultsParameters.Insert("MultipleChoice",   Dialog.Multiselect);
	ProcessingResultsParameters.Insert("CompletionHandler", CompletionHandler);
			
	If Dialog.Multiselect Then
		
		Files = ?(Interactively, Dialog, FilesToUpload);
		NotifyDescription = New NotifyDescription(
			"ProcessPutFilesResult", ThisObject, ProcessingResultsParameters);
		
		If ValueIsFilled(FormIdentifier) Then
			BeginPuttingFiles(NotifyDescription, Files, Interactively,
				FormIdentifier, Context.AcrtionBeforeStartPutFiles);
		Else
			BeginPuttingFiles(NotifyDescription, Files, Interactively, ,
				Context.AcrtionBeforeStartPutFiles);
		EndIf;
		
	Else
		
		File = ?(Interactively, Dialog, FilesToUpload.Name);
		NotifyDescription = New NotifyDescription(
			"ProcessPutFileResult", ThisObject, ProcessingResultsParameters);
		
		If ValueIsFilled(FormIdentifier) Then
			BeginPutFile(NotifyDescription, FilesToUpload.Location, File,
				Interactively, FormIdentifier, Context.AcrtionBeforeStartPutFiles);
		Else
			BeginPutFile(NotifyDescription, FilesToUpload.Location, File,
				Interactively, , Context.AcrtionBeforeStartPutFiles);
		EndIf;
		
	EndIf;
EndProcedure

// Putting files completion.
Procedure ProcessPutFilesResult(PlacedFiles, ProcessingResultsParameters) Export
	
	ProcessPutFileResult(PlacedFiles <> Undefined, PlacedFiles, Undefined,
		ProcessingResultsParameters);
	
EndProcedure

// Putting file completion.
Procedure ProcessPutFileResult(SelectionDone, AddressOrSelectionResult, SelectedFileName,
		ProcessingResultsParameters) Export
	
	If SelectionDone = True Then
		
		If TypeOf(AddressOrSelectionResult) = Type("Array") Then
			
			PutFilesToServe = New Array;
			For Each File In AddressOrSelectionResult Do
				
				FileProperties = New Structure("Name, FullName, Location");
				FillPropertyValues(FileProperties, File);
				
				FileProperties.Insert("FileName", File.Name);
				If Not IsBlankString(File.FullName) Then
					FileProperties.Name = File.FullName;
				EndIf;
				
				PutFilesToServe.Add(FileProperties);
				
			EndDo;
			
		Else
			
			PutFilesToServe = New Structure;
			PutFilesToServe.Insert("Location", AddressOrSelectionResult);
			PutFilesToServe.Insert("Name",      SelectedFileName);
			
		EndIf;
		
	Else
		PutFilesToServe = Undefined;
	EndIf;
	
	ExecuteNotifyProcessing(ProcessingResultsParameters.CompletionHandler, PutFilesToServe);
	
EndProcedure

#EndRegion

#Region ModifiesStoredDataToFileSystem

// Continuation of procedure FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		
		If Context.Interactively Then
			ShowDownloadFilesToDirectory(Context);
		ElsIf Not IsBlankString(Context.Dialog.Directory)Then
			Context.Dialog = Context.Dialog.Directory;
			ShowDownloadFilesToDirectory(Context);
		Else
			
			DirectoryReceiptNotification = New NotifyDescription(
				"ShowDownloadFilesAfterGetTempFilesDirectory", ThisObject, Context);
			BeginGettingTempFilesDir(DirectoryReceiptNotification);
				
		EndIf;
		
	Else
		
		For Each FileToReceive In Context.FilesToObtain Do
			GetFile(FileToReceive.Location, FileToReceive.Name, True);
		EndDo;
		
		If Context.CompletionHandler <> Undefined Then
			ExecuteNotifyProcessing(Context.CompletionHandler, Undefined);
		EndIf;
		
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesAfterGetTempFilesDirectory(TempFilesDirName, Context) Export
	
	Context.Dialog = TempFilesDirName;
	ShowDownloadFilesToDirectory(Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.ShowDownloadFiles procedure.
Procedure ShowDownloadFilesToDirectory(Context)
	
	CallbackOnCompletion = New NotifyDescription("NotifyGetFilesCompletion", ThisObject, Context);
	BeginGettingFiles(CallbackOnCompletion, Context.FilesToObtain,
		Context.Dialog, Context.Interactively);
	
EndProcedure

// Continuation of procedure FileSystemClient.ShowDownloadFiles procedure.
Procedure NotifyGetFilesCompletion(ObtainedFiles, AdditionalParameters) Export
	
	If AdditionalParameters.CompletionHandler <> Undefined Then
		ExecuteNotifyProcessing(AdditionalParameters.CompletionHandler, ObtainedFiles);
	EndIf;
	
EndProcedure

#EndRegion

#Region OpeningFiles

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileAfterSaving(SavedFiles, OpeningParameters) Export
	
	If SavedFiles = Undefined Then
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, False);
	Else
		
		FileDetails = 
			?(TypeOf(SavedFiles) = Type("Array"), 
				SavedFiles[0], 
				SavedFiles);
		
		OpeningParameters.Insert("PathToFile", FileDetails.FullName);
		CompletionHandler = New NotifyDescription(
			"OpenFileAfterEditingCompletion", ThisObject, OpeningParameters);
		
		OpenFileInViewer(FileDetails.FullName, CompletionHandler, OpeningParameters.ForEditing);
		
	EndIf;
	
EndProcedure

// Continues the FileSystemClient.OpenFile procedure.
// Opens the file in the application associated with the file type.
// Prevents executable files from opening.
//
// Parameters:
//  PathToFile        - String - The full path to the file to open.
//  Notification        - NotifyDescription - Notifies about file opening attempt.
//                    If not specified and an error occurs, the method returns a warning.:
//   * ApplicationStarted      - Boolean - True if the external application opened successfully.
//   * AdditionalParameters - Arbitrary - a value that was specified on creating the NotifyDescription object.
//  ForEditing - Boolean - True to open the file for editing, False otherwise.
//
Procedure OpenFileInViewer(PathToFile, Val Notification = Undefined,
		Val ForEditing = False)
	
	FileInfo3 = New File(PathToFile);
	
	Context = New Structure;
	Context.Insert("FileInfo3",          FileInfo3);
	Context.Insert("Notification",        Notification);
	Context.Insert("ForEditing", ForEditing);
	
	Notification = New NotifyDescription(
		"OpenFileInViewerAfterCheckFileSystemExtension", ThisObject, Context);
	
	SuggestionText = NStr("en = 'To open the file, install 1C:Enterprise Extension.';");
	FileSystemClient.AttachFileOperationsExtension(Notification, SuggestionText, False);
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	FileInfo3 = Context.FileInfo3;
	If ExtensionAttached Then
		
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIfExists", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo3.BeginCheckingExistence(Notification);
		
	Else
		
		ErrorDescription = NStr("en = 'Cannot open the file because 1C:Enterprise Extension is not installed.';");
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckIfExists(Exists, Context) Export
	
	FileInfo3 = Context.FileInfo3;
	If Exists Then
		 
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterCheckIsFIle", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		FileInfo3.BeginCheckingIsFile(Notification);
		
	Else 
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The file to open does not exist:
			           |%1';"),
			FileInfo3.FullName);
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterCheckIsFIle(IsFile, Context) Export
	
	// CAC:534-off safe start methods are provided with this function
	
	FileInfo3 = Context.FileInfo3;
	If IsFile Then
		
		If IsBlankString(FileInfo3.Extension) Then 
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The file name is missing extension:
				           |%1.';"),
				FileInfo3.FullName);
			
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
			
		EndIf;
		
		If IsExecutableFileExtension(FileInfo3.Extension) Then 
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Opening executable files is disabled:
				           |%1.';"),
				FileInfo3.FullName);
			
			OpenFileInViewerNotifyOnError(ErrorDescription, Context);
			Return;
			
		EndIf;
		
		Notification          = Context.Notification;
		WaitForCompletion = Context.ForEditing;
		
		Notification = New NotifyDescription(
			"OpenFileInViewerAfterStartApplication", ThisObject, Context,
			"OpenFileInViewerOnProcessError", ThisObject);
		BeginRunningApplication(Notification, FileInfo3.FullName,, WaitForCompletion);
		
	Else 
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The file to open does not exist:
			           |%1';"),
			FileInfo3.FullName);
			
		OpenFileInViewerNotifyOnError(ErrorDescription, Context);
		
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerOnProcessError(ErrorInfo, StandardProcessing, Context) Export
	
	StandardProcessing = False;
	OpenFileInViewerNotifyOnError("", Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileAfterEditingCompletion(ApplicationStarted, OpeningParameters) Export
	
	If ApplicationStarted
		And OpeningParameters.Property("AddressOfBinaryDataToUpdate") Then
		
		Notification = New NotifyDescription(
			"OpenFileAfterDataUpdateInStorage", ThisObject, OpeningParameters);
			
		BeginPutFile(Notification, OpeningParameters.AddressOfBinaryDataToUpdate,
			OpeningParameters.PathToFile, False);
		
	Else
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileAfterDataUpdateInStorage(IsDataUpdated, DataAddress, FileName,
		OpeningParameters) Export
	
	If OpeningParameters.Property("DeleteAfterDataUpdate") Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("IsDataUpdated", IsDataUpdated);
		AdditionalParameters.Insert("OpeningParameters", OpeningParameters);
		
		NotifyDescription = New NotifyDescription(
			"OpenFileAfterTempFileDeletion", ThisObject, AdditionalParameters);
			
		BeginDeletingFiles(NotifyDescription, FileName);
		
	Else
		ExecuteNotifyProcessing(OpeningParameters.CompletionHandler, IsDataUpdated);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileAfterTempFileDeletion(AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.OpeningParameters.CompletionHandler,
		AdditionalParameters.IsDataUpdated);
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenFile.
Procedure OpenFileInViewerNotifyOnError(ErrorDescription, Context)
	
	If Not IsBlankString(ErrorDescription) Then 
		ShowMessageBox(, ErrorDescription);
	EndIf;
	
	ApplicationStarted = False;
	ExecuteNotifyProcessing(Context.Notification, ApplicationStarted);
	
EndProcedure

// Parameters:
//  Extension - String - the Extension property of the File object.
//
Function IsExecutableFileExtension(Val Extension)
	
	Extension = Upper(Extension);
	
	// Windows
	Return Extension = ".BAT" // Batch File
		Or Extension = ".BIN" // Binary Executable
		Or Extension = ".CMD" // Command Script
		Or Extension = ".COM" // MS-DOS application.
		Or Extension = ".CPL" // Control Panel Extension
		Or Extension = ".EXE" // Executable file.
		Or Extension = ".GADGET" // Binary Executable
		Or Extension = ".HTA" // HTML Application
		Or Extension = ".INF1" // Setup Information File
		Or Extension = ".INS" // Internet Communication Settings
		Or Extension = ".INX" // InstallShield Compiled Script
		Or Extension = ".ISU" // InstallShield Uninstaller Script
		Or Extension = ".JOB" // Windows Task Scheduler Job File
		Or Extension = ".LNK" // File Shortcut
		Or Extension = ".MSC" // Microsoft Common Console Document
		Or Extension = ".MSI" // Windows Installer Package
		Or Extension = ".MSP" // Windows Installer Patch
		Or Extension = ".MST" // Windows Installer Setup Transform File
		Or Extension = ".OTM" // Microsoft Outlook macro.
		Or Extension = ".PAF" // Portable Application Installer File
		Or Extension = ".PIF" // Program Information File
		Or Extension = ".PS1" // Windows PowerShell Cmdlet
		Or Extension = ".REG" // Registry Data File
		Or Extension = ".RGS" // Registry Script
		Or Extension = ".SCT" // Windows Scriptlet
		Or Extension = ".SHB" // Windows Document Shortcut
		Or Extension = ".SHS" // Shell Scrap Object
		Or Extension = ".U3P" // U3 Smart Application
		Or Extension = ".VB"  // VBScript File
		Or Extension = ".VBE" // VBScript Encoded Script
		Or Extension = ".VBS" // VBScript File
		Or Extension = ".VBSCRIPT" // Visual Basic Script
		Or Extension = ".WS"  // Windows Script
		Or Extension = ".WSF" // Windows Script
	// Linux
		Or Extension = ".CSH" // C Shell Script
		Or Extension = ".KSH" // Unix Korn Shell Script
		Or Extension = ".OUT" // Executable file.
		Or Extension = ".RUN" // Executable file.
		Or Extension = ".SH"  // Shell Script
	// macOS
		Or Extension = ".ACTION" // Automator Action
		Or Extension = ".APP" // Executable file.
		Or Extension = ".COMMAND" // Terminal Command
		Or Extension = ".OSX" // Executable file.
		Or Extension = ".WORKFLOW" // Automator Workflow
	// Other OS
		Or Extension = ".AIR" // Adobe AIR distribution package
		Or Extension = ".COFFIE" // CoffeeScript (JavaScript) script.
		Or Extension = ".JAR" // Java archive.
		Or Extension = ".JS"  // JScript File
		Or Extension = ".JSE" // JScript Encoded File
		Or Extension = ".PLX" // Perl executable file
		Or Extension = ".PYC" // Python compiled file
		Or Extension = ".PYO"; // Python optimized code.
	
EndFunction

#EndRegion

#Region OpenExplorer

// Continuation of procedure FileSystemClient.OpenExplorer.
Procedure OpenExplorerAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	FileInfo3 = Context.FileInfo3;
	
	If ExtensionAttached Then
		Notification = New NotifyDescription(
			"OpenExplorerAfterCheckIfExists", ThisObject, Context, 
			"OpenExplorerOnProcessError", ThisObject);
		FileInfo3.BeginCheckingExistence(Notification);
	Else
		ErrorDescription = NStr("en = 'To open the folder, install 1C:Enterprise Extension.';");
		OpenExplorerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenExplorer.
Procedure OpenExplorerAfterCheckIfExists(Exists, Context) Export 
	
	FileInfo3 = Context.FileInfo3;
	
	If Exists Then 
		Notification = New NotifyDescription(
			"OpenExplorerAfterCheckIsFIle", ThisObject, Context, 
			"OpenExplorerOnProcessError", ThisObject);
		FileInfo3.BeginCheckingIsFile(Notification);
	Else 
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The directory to be opened in the Explorer, does not exist:
			           |""%1""';"),
			FileInfo3.FullName);
		OpenExplorerNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenExplorer.
Procedure OpenExplorerAfterCheckIsFIle(IsFile, Context) Export 
	
	// CAC:534-off safe start methods are provided with this function
	
	FileInfo3 = Context.FileInfo3;
	
	Notification = New NotifyDescription(,,, "OpenExplorerOnProcessError", ThisObject);
	If IsFile Then
		If CommonClient.IsWindowsClient() Then
			BeginRunningApplication(Notification, "explorer.exe /select, """ + FileInfo3.FullName + """");
		Else // It is Linux or macOS.
			BeginRunningApplication(Notification, "file:///" + FileInfo3.Path);
		EndIf;
	Else // It is a directory.
		BeginRunningApplication(Notification, "file:///" + FileInfo3.FullName);
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenExplorer.
Procedure OpenExplorerOnProcessError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenExplorerNotifyOnError("", Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenExplorer.
Procedure OpenExplorerNotifyOnError(ErrorDescription, Context)
	
	If Not IsBlankString(ErrorDescription) Then 
		ShowMessageBox(, ErrorDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region OpenURL

// Continuation of procedure FileSystemClient.OpenURL.
Procedure OpenURLAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	// CAC:534-off safe start methods are provided with this function
	
	URL = Context.URL;
	
	If ExtensionAttached Then
		
		Notification          = Context.Notification;
		WaitForCompletion = (Notification <> Undefined);
		
		Notification = New NotifyDescription(
			"OpenURLAfterStartApplication", ThisObject, Context,
			"OpenURLOnProcessError", ThisObject);
		BeginRunningApplication(Notification, URL,, WaitForCompletion);
		
	Else
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot follow link ""%1"" because 1C:Enterprise Extension is not installed.';"),
			URL);
		OpenURLNotifyOnError(ErrorDescription, Context);
	EndIf;
	
	// ACC:534-on
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenURL.
Procedure OpenURLAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	
	If Notification <> Undefined Then 
		ApplicationStarted = (ReturnCode = 0 Or ReturnCode = Undefined);
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenURL.
Procedure OpenURLOnProcessError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	OpenURLNotifyOnError("", Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.OpenURL.
Procedure OpenURLNotifyOnError(ErrorDescription, Context) Export
	
	Notification = Context.Notification;
	
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then 
			ShowMessageBox(, ErrorDescription);
		EndIf;
	Else 
		ApplicationStarted = False;
		ExecuteNotifyProcessing(Notification, ApplicationStarted);
	EndIf;
	
EndProcedure

// Checks whether the passed string is a web URL.
// 
// Parameters:
//  String - String - passed URL.
// 
// Returns:
//  Boolean
// 
Function IsWebURL(String) Export
	
	Return StrStartsWith(String, "http://")  // A common connection.
		Or StrStartsWith(String, "https://");// A secure connection.
	
EndFunction

// Checks whether the passed string is a reference to the online help.
// 
// Parameters:
//  String - String - passed URL.
// 
// Returns:
//  Boolean
//
Function IsHelpRef(String) Export
	
	Return StrStartsWith(String, "v8help://");
	
EndFunction

// Checks whether the passed string is a valid reference to the protocol whitelist.
// 
// Parameters:
//  String - String - passed URL.
// 
// Returns:
//  Boolean
//
Function IsAllowedRef(String) Export
	
	Return StrStartsWith(String, "e1c:")
		Or StrStartsWith(String, "e1cib/")
		Or StrStartsWith(String, "e1ccs/")
		Or StrStartsWith(String, "v8help:")
		Or StrStartsWith(String, "http:")
		Or StrStartsWith(String, "https:")
		Or StrStartsWith(String, "mailto:")
		Or StrStartsWith(String, "tel:")
		Or StrStartsWith(String, "skype:")
		Or StrStartsWith(String, "market:")
		Or StrStartsWith(String, "itms-apps:");
	
EndFunction

#EndRegion

#Region StartApplication

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		
		CurrentDirectory = Context.CurrentDirectory;
		
		If IsBlankString(CurrentDirectory) Then
			StartApplicationBeginRunning(Context);
		Else 
			FileInfo3 = New File(CurrentDirectory);
			Notification = New NotifyDescription(
				"StartApplicationAfterCheckIfExists", ThisObject, Context,
				"StartApplicationOnProcessError", ThisObject);
			FileInfo3.BeginCheckingExistence(Notification);
		EndIf;
		
	Else
		ErrorDescription = NStr("en = 'Cannot start the app because 1C:Enterprise Extension is not installed.';");
		StartApplicationNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationAfterCheckIfExists(Exists, Context) Export
	
	CurrentDirectory = Context.CurrentDirectory;
	FileInfo3 = New File(CurrentDirectory);
	
	If Exists Then 
		Notification = New NotifyDescription(
			"StartApplicationAfterCheckIsDirectory", ThisObject, Context,
			"StartApplicationOnProcessError", ThisObject);
		FileInfo3.BeginCheckingIsDirectory(Notification);
	Else 
		CommandString = Context.CommandString;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t start %1
			           | as the folder does not exist:
			           |%2';"),
			CommandString, CurrentDirectory);
		StartApplicationNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemInternalClient.StartFileSystemExtensionAttaching.
//
Procedure StartApplicationAfterCheckIsDirectory(IsDirectory, Context) Export
	
	If IsDirectory Then
		StartApplicationBeginRunning(Context);
	Else
		CommandString = Context.CommandString;
		CurrentDirectory = Context.CurrentDirectory;
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t start %1
			           | as the specified object is not a folder:
			           |%2';"),
			CommandString, CurrentDirectory);
		StartApplicationNotifyOnError(ErrorDescription, Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationBeginRunning(Context)
	
	// CAC:534-off safe start methods are provided with this function
	
	If Context.ThreadsEncoding = Undefined Then 
		Context.ThreadsEncoding = StandardStreamEncoding();
	EndIf;
	
	// Hardcode the default code page since cmd does not always take the current code page.
	If Context.ExecutionEncoding = Undefined And CommonClient.IsWindowsClient() Then 
		Context.ExecutionEncoding = "CP866";
	EndIf;

	If Context.ExecuteWithFullRights Then 
		StartApplicationWithFullRights(Context);
		Return;
	EndIf;
		
	ExecuteUsingPlatformMethod = True;
		
#If Not WebClient And Not MobileClient Then
		If CommonClient.IsWindowsClient() Then
			ExecuteUsingPlatformMethod = False; 
			CommandString = Context.CommandString;
			CurrentDirectory = Context.CurrentDirectory;
			ExecutionEncoding = Context.ExecutionEncoding;
			WaitForCompletion = Context.WaitForCompletion;
			
			CommandString = CommonInternalClientServer.TheWindowsCommandStartLine(CommandString, CurrentDirectory, WaitForCompletion, ExecutionEncoding);
			
			Try
				Shell = New COMObject("Wscript.Shell");
				ReturnCode = Shell.Run(CommandString, 0, WaitForCompletion);
				Shell = Undefined;
			Except
				Shell = Undefined;
				ErrorInfo = ErrorInfo();
				StandardProcessing = True;
				StartApplicationOnProcessError(ErrorInfo, StandardProcessing, Context);
				Return;
			EndTry;
			
			If ReturnCode = Undefined Then 
				ReturnCode = 0;
			EndIf;
			
			StartApplicationAfterStartApplication(ReturnCode, Context);
		EndIf;
#EndIf
	
	If ExecuteUsingPlatformMethod Then 
		CommandString = Context.CommandString;
		CurrentDirectory = Context.CurrentDirectory;
		WaitForCompletion = Context.WaitForCompletion;
		ExecutionEncoding = Context.ExecutionEncoding;
		
		If CommonClient.IsLinuxClient() And ValueIsFilled(ExecutionEncoding) Then
			CommandString = "LANGUAGE=" + ExecutionEncoding + " " + CommandString;
		EndIf;
		
		Notification = New NotifyDescription(
			"StartApplicationAfterStartApplication", ThisObject, Context,
			"StartApplicationOnProcessError", ThisObject);
		BeginRunningApplication(Notification, CommandString, CurrentDirectory, WaitForCompletion);
	EndIf;
	// ACC:534-on
	
EndProcedure

// Returns the encoding of the standard output and error streams for the current OS.
//
// Returns:
//  TextEncoding
//
Function StandardStreamEncoding()
	
	Return ?(CommonClient.IsWindowsClient(), "CP866", "UTF-8");
	
EndFunction

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationAfterStartApplication(ReturnCode, Context) Export 
	
	Notification = Context.Notification;
	If Notification = Undefined Then
		Return;
	EndIf;
		
	Result = ApplicationStartResult();
	If Context.WaitForCompletion And ReturnCode = Undefined Then
		Result.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An unexpected error occurred upon the startup of
				|%1';"),
			Context.CommandString);
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An unexpected error occurred upon the startup:
				|Command line: %1
				|Directory: %2
				|Return code: %3
				|Wait for completion: %4';"),
			Context.CommandString,
			Context.CurrentDirectory,
			Context.ReturnCode,
			Context.WaitForCompletion);
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Standard subsystems';", CommonClient.DefaultLanguageCode()),
			"Error", ErrorDescription);
	Else
		Result.ApplicationStarted = True;
	EndIf;
	
	Result.ReturnCode = ?(ReturnCode <> Undefined, ReturnCode, -1);
	If Context.WaitForCompletion Then
		FillThreadResult(Result, Context);
	EndIf;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationOnProcessError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	StartApplicationNotifyOnError(ErrorDescription, Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationNotifyOnError(ErrorDescription, Context)
	
	Notification = Context.Notification;
	If Notification = Undefined Then
		If Not IsBlankString(ErrorDescription) Then
			ShowMessageBox(, ErrorDescription);
		EndIf;
		Return;
	EndIf;
		
	Result = ApplicationStartResult();
	Result.ErrorDescription = ErrorDescription;
	If Context.WaitForCompletion Then
		FillThreadResult(Result, Context);
	EndIf;
	ExecuteNotifyProcessing(Notification, Result);
	
EndProcedure

// Continues the FileSystemClient.StartApplication procedure.
Function ApplicationStartResult()
	
	Result = New Structure;
	Result.Insert("ApplicationStarted", False);
	Result.Insert("ErrorDescription", "");
	Result.Insert("ReturnCode", -13);
	Result.Insert("OutputStream", "");
	Result.Insert("ErrorStream", "");
	
	Return Result;
	
EndFunction

// Continuation of procedure FileSystemClient.StartApplication.
Procedure StartApplicationWithFullRights(Context)
	
#If WebClient Then
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot start %1.
		           |Reason:
		           |The web client does not support starting apps with elevated privileges.';"),
		Context.CommandString);
	StartApplicationNotifyOnError(ErrorDescription, Context);
#ElsIf MobileClient Then
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Couldn''t start %1.
		           |Reason:
		           |The web client does not support starting apps with elevated privileges.';"),
		Context.CommandString);
	StartApplicationNotifyOnError(ErrorDescription, Context);
#Else
	
	If CommonClient.IsWindowsClient() Then 
		StartApplicationWithFullWindowsRights(Context);
	ElsIf CommonClient.IsLinuxClient() Then 
		StartApplicationWithFullLinuxRights(Context);
	Else
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t start %1.
			           |Reason:
			           |Starting apps with elevated privileges is supported for Windows and Linux only.';"),
			Context.CommandString);
		StartApplicationNotifyOnError(ErrorDescription, Context);
	EndIf;
	
#EndIf
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
//
Procedure FillThreadResult(Result, Context)
	
#If Not WebClient Then
		
	If Context.GetOutputStream
		And Not IsBlankString(Context.OutputThreadFileName) Then
		Result.OutputStream = ReadThreadFile(Context.OutputThreadFileName, Context.ThreadsEncoding);
	EndIf;
	
	If Context.GetErrorStream
		And Not IsBlankString(Context.ErrorsThreadFileName) Then
		Result.ErrorStream = ReadThreadFile(Context.ErrorsThreadFileName, Context.ThreadsEncoding);
	EndIf;
		
#EndIf

EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
//
Function ReadThreadFile(PathToFile, ThreadsEncoding)
	
	// CAC:566-off synchronous calls outside the thin client
	
#If WebClient Then
	Return "";
#Else
	ThreadFile = New File(PathToFile);
	If Not ThreadFile.Exists() Then
		Return "";
	EndIf;
	
	ReadThreadFile1 = New TextReader(PathToFile, ThreadsEncoding);
	Result = ReadThreadFile1.Read();
	ReadThreadFile1.Close();
	
	DeleteFiles(PathToFile);
	
	Return ?(Result = Undefined, "", Result);
#EndIf
	
	// ACC:566-on
	
EndFunction

#If Not WebClient And Not MobileClient Then

// Continuation of procedure FileSystemClient.StartApplication.
//
Procedure StartApplicationWithFullWindowsRights(Context)
	
	// CAC:534-off safe start methods are provided with this function
	
	CommandString = Context.CommandString;
	CurrentDirectory = Context.CurrentDirectory;
	ExecutionEncoding = Context.ExecutionEncoding;
	
	WaitForCompletion = False;
	
	CommandString = CommonInternalClientServer.TheWindowsCommandStartLine(CommandString, CurrentDirectory, WaitForCompletion, ExecutionEncoding);
	
	Try
		Shell = New COMObject("Shell.Application");
		// Run with elevated permissions.
		ReturnCode = Shell.ShellExecute("cmd", "/c """ + CommandString + """",, "runas", 0);
		Shell = Undefined;
	Except
		Shell = Undefined;
		ErrorInfo = ErrorInfo();
		StandardProcessing = True;
		StartApplicationOnProcessError(ErrorInfo, StandardProcessing, Context);
		Return;
	EndTry;
	
	If ReturnCode = Undefined Then 
		ReturnCode = 0;
	EndIf;
	
	StartApplicationAfterStartApplication(ReturnCode, Context);
	
	// ACC:534-on
	
EndProcedure

// Continuation of procedure FileSystemClient.StartApplication.
//
Procedure StartApplicationWithFullLinuxRights(Context)
	
	// CAC:534-off safe start methods are provided with this function
	
	CurrentDirectory = Context.CurrentDirectory;
	CommandString = Context.CommandString;
	
	CommandWithPrivilegeEscalation = "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY " + CommandString;
	WaitForCompletion = True;
	
	Notification = New NotifyDescription(
		"StartApplicationAfterStartApplication", ThisObject, Context,
		"StartApplicationOnProcessError", ThisObject);
	BeginRunningApplication(Notification, CommandWithPrivilegeEscalation, CurrentDirectory, WaitForCompletion);
	
	// ACC:534-on
	
EndProcedure

#EndIf

#EndRegion

#Region ChooseDirectory

// Continuation of procedure FileSystemClient.SelectDirectory.
Procedure SelectDirectoryOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	If Not ExtensionAttached Then
		ExecuteNotifyProcessing(Context.CompletionHandler, "");
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription(
		"SelectDirectoryAtSelectionEnd", ThisObject, Context.CompletionHandler);
	
	Dialog = New FileDialog(FileDialogMode.ChooseDirectory);
	Dialog.Multiselect = False;
	If Not IsBlankString(Context.Title) Then
		Dialog.Title = Context.Title;
	EndIf;
	If Not IsBlankString(Context.Directory) Then
		Dialog.Directory = Context.Directory;
	EndIf;
	
	Dialog.Show(NotifyDescription);
	
EndProcedure

// Continuation of procedure FileSystemClient.SelectDirectory.
Procedure SelectDirectoryAtSelectionEnd(DirectoriesArray, CompletionHandler) Export
	
	PathToDirectory = 
		?(DirectoriesArray = Undefined Or DirectoriesArray.Count() = 0,
			"", 
			DirectoriesArray[0]);
	
	ExecuteNotifyProcessing(CompletionHandler, PathToDirectory);
	
EndProcedure

#EndRegion

#Region ShowSelectionDialog

// Continuation of procedure FileSystemClient.ShowSelectionDialog.
//
Procedure ShowSelectionDialogOnAttachFileSystemExtension(ExtensionAttached, Context) Export
	
	If Not ExtensionAttached Then
		ExecuteNotifyProcessing(Context.CompletionHandler, "");
		Return;
	EndIf;
	
	Context.Dialog.Show(Context.CompletionHandler);
	
EndProcedure

#EndRegion

#Region FileSystemExtension

Procedure StartFileSystemExtensionAttachingOnSetExtension(Attached, Context) Export
	
	// If the extension is already installed, there is no need to ask about it
	If Attached Then
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion, "AttachmentNotRequired");
		Return;
	EndIf;
	
	// In macOS, the extension's web client supports only Google Chrome.
	If CommonClient.IsMacOSClient() 
			And Not AnExtensionForWorkingWithFilesIsAvailable() Then
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion);
		Return;
	EndIf;
	
	ParameterName = "StandardSubsystems.SuggestFileSystemExtensionInstallation";
	FirstCallDuringSession = ApplicationParameters[ParameterName] = Undefined;
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, SuggestFileSystemExtensionInstallation());
	EndIf;
	
	SuggestFileSystemExtensionInstallation = ApplicationParameters[ParameterName] Or FirstCallDuringSession;
	If Context.CanContinueWithoutInstalling And Not SuggestFileSystemExtensionInstallation Then
		
		ExecuteNotifyProcessing(Context.NotifyDescriptionCompletion);
		
	Else 
		
		FormParameters = New Structure;
		FormParameters.Insert("SuggestionText", Context.SuggestionText);
		FormParameters.Insert("CanContinueWithoutInstalling", Context.CanContinueWithoutInstalling);
		OpenForm(
			"CommonForm.FileSystemExtensionInstallationQuestion", 
			FormParameters,,,,, 
			Context.NotifyDescriptionCompletion);
		
	EndIf;
	
EndProcedure

Procedure StartFileSystemExtensionAttachingWhenAnsweringToInstallationQuestion(Action, ClosingNotification1) Export
	
	ExtensionAttached = (Action = "ExtensionAttached" Or Action = "AttachmentNotRequired");
	
#If WebClient Then
	If Action = "DoNotPrompt"
		Or Action = "ExtensionAttached" Then
		
		SystemInfo = New SystemInfo();
		ClientID = SystemInfo.ClientID;
		ApplicationParameters["StandardSubsystems.SuggestFileSystemExtensionInstallation"] = False;
		CommonServerCall.CommonSettingsStorageSave(
			"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, False);
		
	EndIf;
#EndIf
	
	ExecuteNotifyProcessing(ClosingNotification1, ExtensionAttached);
	
EndProcedure

Function SuggestFileSystemExtensionInstallation()
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	Return CommonServerCall.CommonSettingsStorageLoad(
		"ApplicationSettings/SuggestFileSystemExtensionInstallation", ClientID, True);
	
EndFunction

Function AnExtensionForWorkingWithFilesIsAvailable()

	SystemInfo = New SystemInfo;
	Return StrFind(SystemInfo.UserAgentInformation, "Chrome") > 0;

EndFunction

#EndRegion

#Region TemporaryFiles

#Region CreateTemporaryDirectory

// Continuation of procedure FileSystemClient.CreateTemporaryDirectory.
// 
// Parameters:
//  ExtensionAttached - Boolean
//  Context - Structure:
//   * Notification - NotifyDescription
//   * Extension - String
//
Procedure CreateTemporaryDirectoryAfterCheckFileSystemExtension(ExtensionAttached, Context) Export
	
	If ExtensionAttached Then
		Notification = New NotifyDescription(
			"CreateTemporaryDirectoryAfterGetTemporaryDirectory", ThisObject, Context,
			"CreateTemporaryDirectoryOnProcessError", ThisObject);
		BeginGettingTempFilesDir(Notification);
	Else
		CreateTemporaryDirectoryNotifyOnError(NStr("en = 'Cannot install 1C:Enterprise Extension.';"), Context);
	EndIf;
	
EndProcedure

// Continuation of procedure FileSystemClient.CreateTemporaryDirectory.
// 
// Parameters:
//  TempFilesDirName - String
//  Context - Structure:
//   * Notification - NotifyDescription
//   * Extension - String
//
Procedure CreateTemporaryDirectoryAfterGetTemporaryDirectory(TempFilesDirName, Context) Export 
	
	Notification = Context.Notification;
	Extension = Context.Extension;
	
	DirectoryName = "v8_" + String(New UUID);
	
	If Not IsBlankString(Extension) Then 
		DirectoryName = DirectoryName + "." + Extension;
	EndIf;
	
	BeginCreatingDirectory(Notification, TempFilesDirName + DirectoryName);
	
EndProcedure

// Continuation of procedure FileSystemClient.CreateTemporaryDirectory.
Procedure CreateTemporaryDirectoryOnProcessError(ErrorInfo, StandardProcessing, Context) Export 
	
	StandardProcessing = False;
	ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	CreateTemporaryDirectoryNotifyOnError(ErrorDescription, Context);
	
EndProcedure

// Continuation of procedure FileSystemClient.CreateTemporaryDirectory.
Procedure CreateTemporaryDirectoryNotifyOnError(ErrorDescription, Context)
	
	ShowMessageBox(, ErrorDescription);
	DirectoryName = "";
	ExecuteNotifyProcessing(Context.Notification, DirectoryName);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion