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
	
	File = Parameters.File;
	FileData = Parameters.FileData;
	FileToOpenName = Parameters.FileToOpenName;
	OwnerID = Parameters.OwnerID;
	
	If Not ValueIsFilled(OwnerID) Then
		OwnerID = UUID;
	EndIf;
	
	If FileData.CurrentUserEditsFile Then
		EditMode = True;
	EndIf;
	
	If FileData.Version <> FileData.CurrentVersion Then
		EditMode = False;
	EndIf;
	
	ReadOnly = Not AccessRight("Edit", File.Metadata());
	
	Items.Text.ReadOnly                = Not EditMode;
	Items.ShowDifferences.Visible           = Common.IsWindowsClient();
	Items.ShowDifferences.Enabled         = EditMode;
	Items.Edit.Enabled           = Not EditMode And Not ReadOnly;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled        = EditMode;
	Items.Write.Enabled                = EditMode;
	
	If FileData.Version <> FileData.CurrentVersion
		Or FileData.IsInternal Then
		Items.Edit.Enabled = False;
	EndIf;
	
	TitleRow = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileData.Extension);
	
	If Not EditMode Then
		TitleRow = TitleRow + " " + NStr("en = '(Read-only)';");
	EndIf;
	Title = TitleRow;
	
	If FileData.Property("Encoding") Then
		FileTextEncoding = FileData.Encoding;
	EndIf;
	
	If ValueIsFilled(FileTextEncoding) Then
		EncodingsList = FilesOperationsInternal.Encodings();
		ListItem = EncodingsList.FindByValue(FileTextEncoding);
		If ListItem = Undefined Then
			EncodingPresentation = FileTextEncoding;
		Else
			EncodingPresentation = ListItem.Presentation;
		EndIf;
	Else
		EncodingPresentation = NStr("en = 'Default';");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Text.Read(FileToOpenName, TextEncodingForRead());
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File"
	   And Parameter.Event = "FileWasEdited"
	   And Source = File Then
		
		EditMode = True;
		SetCommandsAvailability();
	EndIf;
	
	If EventName = "Write_File"
	   And Parameter.Event = "FileDataChanged"
	   And Source = File Then
		
		FileDataParameters = FilesOperationsClientServer.FileDataParameters();
		FileDataParameters.GetBinaryDataRef = False;
		FileData = FilesOperationsInternalServerCall.FileData(File,,FileDataParameters);
		
		EditMode = False;
		
		If FileData.CurrentUserEditsFile Then
			EditMode = True;
		EndIf;
		
		If FileData.Version <> FileData.CurrentVersion Then
			EditMode = False;
		EndIf;
		
		SetCommandsAvailability();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	Cancel = True;
	
	NameAndExtension = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileExtention());
	
	If Exit Then
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The changes in file ""%1"" will be lost.';"), NameAndExtension);
		Return;
	EndIf;

	ResultHandler = New NotifyDescription("BeforeCloseAfterAnswerQuestionOnClosingTextEditor", ThisObject);
	ReminderText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'File ""%1"" was changed.
			|Do you want to save the changes?';"), 
		NameAndExtension);
	Buttons = New ValueList;
	Buttons.Add("Save", NStr("en = 'Save';"));
	Buttons.Add("NotPreserve", NStr("en = 'Do not save';"));
	Buttons.Add("Cancel",  NStr("en = 'Cancel';"));
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Picture", PictureLib.DialogInformation);
	ReminderParameters.Insert("Title", NStr("en = 'Warning';"));
	ReminderParameters.Insert("PromptDontAskAgain", False);
	StandardSubsystemsClient.ShowQuestionToUser(
			ResultHandler, ReminderText, Buttons, ReminderParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SaveAs(Command)
	
	SelectingFile = New FileDialog(FileDialogMode.Save);
	SelectingFile.Multiselect = False;
	
	NameWithExtension = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileExtention());
	
	SelectingFile.FullFileName = NameWithExtension;
	Filter = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'All files (*.%1)|*.%1';"), FileExtention());
	SelectingFile.Filter = Filter;
	
	If SelectingFile.Choose() Then
		
		SelectedFullFileName = SelectingFile.FullFileName;
		WriteTextToFile(SelectedFullFileName);
		
		ShowUserNotification(NStr("en = 'File saved';"), , SelectedFullFileName);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	ShowValue(, File);
	
EndProcedure

&AtClient
Procedure ExternalEditor(Command)
	
	WriteText();
	FileSystemClient.OpenFile(FileToOpenName);
	Close();
	
EndProcedure

&AtClient
Procedure Edit(Command)
	
	FilesOperationsInternalClient.EditWithNotification(Undefined, File, OwnerID);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteText();
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Scenario", "TakeNoAction");
	Handler = New NotifyDescription("EndEditCompletion", ThisObject, HandlerParameters);
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, OwnerID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.SaveFileChangesWithNotification(Handler, File, OwnerID);
		
EndProcedure

&AtClient
Procedure EndEdit(Command)
	
	WriteText();
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Scenario", "EndEdit");
	Handler = New NotifyDescription("EndEditCompletion", ThisObject, HandlerParameters);
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, OwnerID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure ShowDifferences(Command)
	
#If WebClient Then
	ShowMessageBox(, NStr("en = 'The web client does not support file version comparison.';"));
	Return;
#ElsIf MobileClient Then
	ShowMessageBox(, NStr("en = 'The mobile client does not support file version comparison.';"));
	Return;
#Else
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("CurrentStep", 1);
	ExecutionParameters.Insert("FileVersionsComparisonMethod", Undefined);
	ExecutionParameters.Insert("FullFileNameLeft", GetTempFileName(FileExtention()));
	ExecuteCompareFiles(-1, ExecutionParameters);
#EndIf
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteText();
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("Scenario", "WriteAndClose");
	Handler = New NotifyDescription("EndEditCompletion", ThisObject, HandlerParameters);
	
	FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, OwnerID);
	FileUpdateParameters.Encoding = FileTextEncoding;
	FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
	
EndProcedure

&AtClient
Procedure SelectEncoding(Command)
	FormParameters = New Structure;
	FormParameters.Insert("CurrentEncoding", FileTextEncoding);
	Handler = New NotifyDescription("SelectEncodingCompletion", ThisObject);
	OpenForm("DataProcessor.FilesOperations.Form.SelectEncoding", FormParameters, ThisObject, , , , Handler);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforeCloseAfterAnswerQuestionOnClosingTextEditor(Result, ExecutionParameters) Export
	
	If Result.Value = "Save" Then
		
		WriteText();
		HandlerParameters = New Structure;
		HandlerParameters.Insert("Scenario", "Close");
		Handler = New NotifyDescription("EndEditCompletion", ThisObject, HandlerParameters);
		FileUpdateParameters = FilesOperationsInternalClient.FileUpdateParameters(Handler, File, OwnerID);
		FileUpdateParameters.Encoding = FileTextEncoding;
		FilesOperationsInternalClient.EndEditAndNotify(FileUpdateParameters);
		
	ElsIf Result.Value = "NotPreserve" Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectEncodingCompletion(Result, ExecutionParameters) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	FileTextEncoding   = Result.Value;
	EncodingPresentation = Result.Presentation;
	
	If EditMode Then
		Modified = True;
	EndIf;
	
	ReadText();
	
EndProcedure

&AtClient
Procedure EndEditCompletion(Result, ExecutionParameters) Export
	If Result <> True Then
		Return;
	EndIf;
	
	If ExecutionParameters.Scenario = "EndEdit" Then
		EditMode = False;
		SetCommandsAvailability();
	ElsIf ExecutionParameters.Scenario = "WriteAndClose" Then
		EditMode = False;
		SetCommandsAvailability();
		Close();
	ElsIf ExecutionParameters.Scenario = "Close" Then
		Modified = False;
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteText()
	
	If Not Modified Then
		Return;
	EndIf;
	
	WriteTextToFile(FileToOpenName);
	Modified = False;
	
EndProcedure

&AtClient
Procedure WriteTextToFile(FileName)
	
	FileText = CommonClientServer.ReplaceProhibitedXMLChars(Text.GetText());
	Text.SetText(FileText);
	
	If FileTextEncoding = "utf-8_WithoutBOM" Then
		
		BinaryData = GetBinaryDataFromString(Text.GetText(), "utf-8", False);
		BinaryData.Write(FileName);
		
	Else
		
		Text.Write(FileName,
			?(ValueIsFilled(FileTextEncoding), FileTextEncoding, Undefined));
		
	EndIf;
	
	FilesOperationsInternalServerCall.WriteFileVersionEncodingAndExtractedText(
		FileData.Version, FileTextEncoding, Text.GetText());
	
EndProcedure

&AtClient
Procedure SetCommandsAvailability()
	
	Items.Text.ReadOnly                = Not EditMode;
	Items.ShowDifferences.Enabled         = EditMode;
	Items.Edit.Enabled           = Not EditMode;
	Items.EndEdit.Enabled = EditMode;
	Items.WriteAndClose.Enabled        = EditMode;
	Items.Write.Enabled                = EditMode;
	Items.FormSelectEncoding.Enabled   = EditMode;
	
	TitleRow = CommonClientServer.GetNameWithExtension(
		FileData.FullVersionDescription, FileExtention());
	
	If Not EditMode Then
		TitleRow = TitleRow + " " + NStr("en = '(Read-only)';");
	EndIf;
	Title = TitleRow;
	
EndProcedure

&AtClient
Procedure ReadText()
	
	Text.Read(FileToOpenName, TextEncodingForRead());
	
EndProcedure

&AtClient
Function TextEncodingForRead()
	
	TextEncodingForRead = ?(ValueIsFilled(FileTextEncoding), FileTextEncoding, Undefined);
	If TextEncodingForRead = "utf-8_WithoutBOM" Then
		TextEncodingForRead = "utf-8";
	EndIf;
	
	Return TextEncodingForRead;
	
EndFunction

&AtClient
Procedure ExecuteCompareFiles(Result, ExecutionParameters) Export
	If ExecutionParameters.CurrentStep = 1 Then
		PersonalSettings = FilesOperationsInternalClient.PersonalFilesOperationsSettings();
		ExecutionParameters.FileVersionsComparisonMethod = PersonalSettings.FileVersionsComparisonMethod;
		// First call means that the setting has not been initialized yet.
		If ExecutionParameters.FileVersionsComparisonMethod = Undefined Then
			ExecutionParameters.CurrentStep = 1.1;
			Handler = New NotifyDescription("ExecuteCompareFiles", ThisObject, ExecutionParameters);
			OpenForm("DataProcessor.FilesOperations.Form.SelectVersionCompareMethod", , ThisObject, , , , Handler);
			Return;
		EndIf;
		ExecutionParameters.CurrentStep = 2;
	ElsIf ExecutionParameters.CurrentStep = 1.1 Then
		If Result <> DialogReturnCode.OK Then
			Return;
		EndIf;
		PersonalSettings = FilesOperationsInternalClient.PersonalFilesOperationsSettings();
		ExecutionParameters.FileVersionsComparisonMethod = PersonalSettings.FileVersionsComparisonMethod;
		If ExecutionParameters.FileVersionsComparisonMethod = Undefined Then
			Return;
		EndIf;
		ExecutionParameters.CurrentStep = 2;
	EndIf;
	
	If ExecutionParameters.CurrentStep = 2 Then
		// Saving file for the right part.
		WriteText(); // Full name is placed to the FileToOpenName attribute.
		
		// Saving file for the left part.
		If FileData.CurrentVersion = FileData.Version Then
			LeftFileData = FilesOperationsInternalServerCall.FileDataToSave(File, , OwnerID);
			LeftFileAddress = LeftFileData.CurrentVersionURL;
		Else
			LeftFileAddress = FilesOperationsInternalServerCall.GetURLToOpen(
				FileData.Version,
				OwnerID);
		EndIf;
		TransmittedFiles = New Array;
		TransmittedFiles.Add(New TransferableFileDescription(ExecutionParameters.FullFileNameLeft, LeftFileAddress));
		If Not GetFiles(TransmittedFiles,, ExecutionParameters.FullFileNameLeft, False) Then
			Return;
		EndIf;
		
		// Comparison.
		FilesOperationsInternalClient.ExecuteCompareFiles(
			ExecutionParameters.FullFileNameLeft,
			FileToOpenName,
			ExecutionParameters.FileVersionsComparisonMethod);
	EndIf;
EndProcedure

&AtClient
Function FileExtention()
	
	Data = FileData; // See FilesOperations.FileData
	Return Data.Extension;
	
EndFunction

#EndRegion
