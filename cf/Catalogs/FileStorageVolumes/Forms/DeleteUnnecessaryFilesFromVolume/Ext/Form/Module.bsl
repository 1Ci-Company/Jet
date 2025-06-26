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
	
	FileStorageVolume = Parameters.FileStorageVolume;
	
	FillExcessFilesTable();
	UnnecessaryFilesCount = UnnecessaryFiles.Count();
	
	DateFolder = Format(CurrentSessionDate(), "DF=yyyyMMdd") + GetPathSeparator();
	
	CopyFilesBeforeDelete                = False;
	Items.PathToFolderToCopy.Enabled = False;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DecorationMoreClick(Item)
	
	ReportParameters = New Structure();
	ReportParameters.Insert("GenerateOnOpen", True);
	ReportParameters.Insert("Filter", New Structure("Volume", FileStorageVolume));
	
	OpenForm("Report.VolumeIntegrityCheck.ObjectForm", ReportParameters);
	
EndProcedure

&AtClient
Procedure PathToFolderToCopyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.FullFileName = "";
	OpenFileDialog.Directory = PathToFolderToCopy;
	OpenFileDialog.Multiselect = False;
	OpenFileDialog.Title = Title;
	
	Context = New Structure("OpenFileDialog", OpenFileDialog);
	
	ChoiceDialogNotificationDetails = New NotifyDescription(
		"PathToFolderToCopyStartChoiceCompletion", ThisObject, Context);
	FileSystemClient.ShowSelectionDialog(ChoiceDialogNotificationDetails, OpenFileDialog);
	
EndProcedure

&AtClient
Procedure PathToFolderToCopyOnChange(Item)
	
	PathToFolderToCopy                     = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
	Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	
EndProcedure

&AtClient
Procedure CopyFilesBeforeDeleteOnChange(Item)
	
	If Not CopyFilesBeforeDelete Then
		PathToFolderToCopy                      = "";
		Items.PathToFolderToCopy.Enabled = False;
		Items.FormDeleteUnnecessaryFiles.Enabled  = True;
	Else
		Items.PathToFolderToCopy.Enabled = True;
		If ValueIsFilled(PathToFolderToCopy) Then
			Items.FormDeleteUnnecessaryFiles.Enabled = True;
		Else
			Items.FormDeleteUnnecessaryFiles.Enabled = False;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure DeleteUnnecessaryFiles(Command)
	
	If UnnecessaryFilesCount = 0 Then
		ShowMessageBox(, NStr("en = 'The volume has no unreferenced files';"));
		Return;
	EndIf;
	
	If CopyFilesBeforeDelete Then
		FileSystemClient.AttachFileOperationsExtension(
			New NotifyDescription("AttachFileSystemExtensionCompletion", ThisObject),, 
			False);
	Else
		AfterCheckWriteToDirectory(True, New Structure);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure PathToFolderToCopyStartChoiceCompletion(SelectedFiles, Context) Export
	
	OpenFileDialog = Context.OpenFileDialog;
	
	If SelectedFiles = Undefined Then
		Items.FormDeleteUnnecessaryFiles.Enabled = False;
	Else
		PathToFolderToCopy = OpenFileDialog.Directory;
		PathToFolderToCopy = CommonClientServer.AddLastPathSeparator(PathToFolderToCopy);
		Items.FormDeleteUnnecessaryFiles.Enabled = ValueIsFilled(PathToFolderToCopy);
	EndIf;

EndProcedure

&AtServer
Procedure FillExcessFilesTable()
	
	FilesTableOnHardDrive = FilesOperationsInVolumesInternal.UnnecessaryFilesOnHardDrive();
	VolumePath = TrimAll(FilesOperationsInVolumesInternal.FullVolumePath(FileStorageVolume));
	
	FilesArray = FindFiles(VolumePath,"*", True);
	For Each File In FilesArray Do
		
		If Not File.IsFile() Then
			Continue;
		EndIf;
		
		NewRow = FilesTableOnHardDrive.Add();
		NewRow.Name              = File.Name;
		NewRow.BaseName = File.BaseName;
		NewRow.FullName        = File.FullName;
		NewRow.Path             = File.Path;
		NewRow.Extension       = File.Extension;
		NewRow.CheckStatus   = NStr("en = 'Unreferenced files (files in the volume that have no entries in the application)';");
		NewRow.Count       = 1;
		NewRow.Volume              = FileStorageVolume;
		
	EndDo;
	
	FilesOperationsInVolumesInternal.FillInExtraFiles(FilesTableOnHardDrive, FileStorageVolume);
	FilesTableOnHardDrive.Indexes.Add("CheckStatus");
	ExcessFilesArray = FilesTableOnHardDrive.FindRows(
		New Structure("CheckStatus", NStr("en = 'Unreferenced files (files in the volume that have no entries in the application)';")));
	
	For Each File In ExcessFilesArray Do
		NewRow = UnnecessaryFiles.Add();
		FillPropertyValues(NewRow, File);
		NewRow.RelativePath = StrReplace(NewRow.FullName, VolumePath, "");
	EndDo;
	
	UnnecessaryFiles.Sort("Name");
	
EndProcedure

&AtClient
Procedure RightToWriteToDirectory(SourceNotification)
	
	If IsBlankString(PathToFolderToCopy) Then
		ExecuteNotifyProcessing(SourceNotification, True);
		Return
	EndIf;
	
	DirectoryName = PathToFolderToCopy + "CheckAccess\";
	
	DirectoryDeletionParameters  = New Structure("SourceNotification, DirectoryName", SourceNotification, DirectoryName);
	DirectoryCreationNotification = New NotifyDescription("AfterCreateDirectory", ThisObject, DirectoryDeletionParameters, "AfterDirectoryCreationError", ThisObject);
	BeginCreatingDirectory(DirectoryCreationNotification, DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDirectoryCreationError(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInfo, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure AfterCreateDirectory(Result, AdditionalParameters) Export
	
	BeginDeletingFiles(New NotifyDescription("AfterDeleteDirectory", ThisObject, AdditionalParameters, "AfterDirectoryDeletionError", ThisObject), AdditionalParameters.DirectoryName);
	
EndProcedure

&AtClient
Procedure AfterDeleteDirectory(AdditionalParameters) Export
	
	ExecuteNotifyProcessing(AdditionalParameters.SourceNotification, True);
	
EndProcedure

&AtClient
Procedure AfterDirectoryDeletionError(ErrorInfo, StandardProcessing, AdditionalParameters) Export
	
	ProcessAccessRightsError(ErrorInfo, AdditionalParameters.SourceNotification);
	
EndProcedure

&AtClient
Procedure ProcessAccessRightsError(ErrorInfo, SourceNotification)
	
	ErrorTemplate = NStr("en = 'Incorrect folder for copying.
		|An account on whose behalf 1C:Enterprise server is running
		|might have no access rights to the specified folder.
		|
		|%1';");
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
	CommonClient.MessageToUser(ErrorText, , , "PathToFolderToCopy");
	
	ExecuteNotifyProcessing(SourceNotification, False);
	
EndProcedure

// Parameters:
//   ErrorsReport - SpreadsheetDocument
//   FilesArrayWithErrors - Array of see ErrorStructure
//
&AtServer
Procedure GenerateErrorsReport(ErrorsReport)

	TabularTemplate = Catalogs.FileStorageVolumes.GetTemplate("ReportTemplate");
	
	HeaderArea_ = TabularTemplate.GetArea("Title");
	HeaderArea_.Parameters.LongDesc = NStr("en = 'Files with errors:';");
	ErrorsReport.Put(HeaderArea_);
	
	AreaRow = TabularTemplate.GetArea("String");
	
	For Each FileWithError In FormAttributeToValue("FilesWithErrors") Do
		AreaRow.Parameters.Name1 = FileWithError.Name;
		AreaRow.Parameters.Error = FileWithError.Error;
		Area = ErrorsReport.Put(AreaRow);
		Area.RowHeight = 0;
		Area.AutoRowHeight = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure AttachFileSystemExtensionCompletion(ExtensionAttached, AdditionalParameters) Export
	
	If Not ExtensionAttached Then
		ShowMessageBox(, NStr("en = 'Cannot perform the action because 1C:Enterprise Extension is not installed.';"));
		Return;
	EndIf;
	
	FolderForCopying = New File(PathToFolderToCopy);
	FolderForCopying.BeginCheckingExistence(New NotifyDescription("FolderExistanceCheckCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure FolderExistanceCheckCompletion(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		ShowMessageBox(, NStr("en = 'The specified folder does not exist.';"));
	Else
		RightToWriteToDirectory(New NotifyDescription("AfterCheckWriteToDirectory", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Async Procedure AfterCheckWriteToDirectory(Result, AdditionalParameters) Export
	
	If Not Result Then
		Return;
	EndIf;
	
	If UnnecessaryFiles.Count() = 0 Then
		Return;
	EndIf;
	
	If CopyFilesBeforeDelete Then
		
		FilesForDeletion = New Map;
	
		For Each ExtraFile In UnnecessaryFiles Do
			FilesForDeletion.Insert(ExtraFile.FullName, 
				New Structure("Name, RelativePath", ExtraFile.Name, ExtraFile.RelativePath));
		EndDo;
		
		UniqueFilenames = New Map;
		For Each FileToDelete In FilesForDeletion Do
			File = New File(FileToDelete.Value.RelativePath);
			If StrStartsWith(File.Extension, ".") Then
				Extension = File.Extension;
			ElsIf ValueIsFilled(File.Extension) Then
				Extension = "."+Extension;
			Else
				Extension = "";
			EndIf;
			
			RelativePath = File.BaseName + Extension;
					
			TargetPath = PathToFolderToCopy + DateFolder + GetPathSeparator() + RelativePath;
			If UniqueFilenames[TargetPath] = True Or Await File.ExistsAsync() Then
				RelativePath = File.BaseName + String(New UUID) + Extension;
				FileToDelete.Value.RelativePath = RelativePath;
			Else
				FileToDelete.Value.RelativePath = RelativePath;
				UniqueFilenames.Insert(TargetPath, True);
			EndIf;
		EndDo;
		
		FilesForDownloading = PrepareFilesAtServer(FilesForDeletion);
		Context = New Structure("FilesForDownloading, FilesForDeletion", FilesForDownloading, FilesForDeletion);
		AfterFilesReceivedFromServer = New NotifyDescription("AfterFilesReceivedFromServer", ThisObject, Context,
			"ErrorAfterGetFilesFromServer", ThisObject);
		BeginGetFilesFromServer(AfterFilesReceivedFromServer, FilesForDownloading, PathToFolderToCopy + DateFolder + GetPathSeparator());
		
	Else
		
		FilesForDeletion = New Array;
	
		For Each ExtraFile In UnnecessaryFiles Do
			FilesForDeletion.Add(ExtraFile.FullName);
		EndDo;
			
		DeleteVolumesFiles(FilesForDeletion);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteVolumesFiles(FilesForDeletion)
	DeletionResult = DeleteVolumesFilesOnServer(FilesForDeletion);
	NumberOfDeletedFiles = DeletionResult.Deleted;
	FilesWithErrors.Clear();
	For Each DeletionError In DeletionResult.DeletionErrors Do
		FillPropertyValues(FilesWithErrors.Add(), DeletionError);
	EndDo;
	
	AfterProcessFiles();
EndProcedure

&AtServerNoContext
Function DeleteVolumesFilesOnServer(Files)
	Return FilesOperationsInVolumesInternal.DeleteVolumesFiles(Files);
EndFunction

&AtClient
Procedure AfterFilesReceivedFromServer(ObtainedFiles, Context) Export
	FilesForDeletion = New Array;
	For Each File In Context.FilesForDeletion Do
		FilesForDeletion.Add(File.Key);
	EndDo;
		
	DeleteVolumesFiles(FilesForDeletion);
EndProcedure

&AtClient
Procedure ErrorAfterGetFilesFromServer(ErrorInfo, StandardProcessing, Context) Export
	FilesWithErrors.Clear();
	FileWithError = FilesWithErrors.Add();
	FileWithError.Error = ErrorProcessing.BriefErrorDescription(ErrorInfo);
	AfterProcessFiles();
EndProcedure

&AtServer
Function PrepareFilesAtServer(FilesForDeletion)
	Result = New Array;
	For Each File In FilesForDeletion Do
		BinaryData = New BinaryData(File.Key);
		Address = PutToTempStorage(BinaryData);
		FileName = File.Value.RelativePath;
		Result.Add(New TransferableFileDescription(FileName, Address))
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure AfterProcessFiles()

	If NumberOfDeletedFiles <> 0 Then
		NotificationText1 = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Files deleted: %1';"),
			NumberOfDeletedFiles);
		ShowUserNotification(
			NStr("en = 'Unreferenced files are deleted.';"),,
			NotificationText1, PictureLib.DialogInformation);
	EndIf;
	
	If FilesWithErrors.Count() > 0 Then
		ErrorsReport = New SpreadsheetDocument;
		GenerateErrorsReport(ErrorsReport);
		ErrorsReport.Show(NStr("en = 'Delete unreferenced volume files';"));
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion