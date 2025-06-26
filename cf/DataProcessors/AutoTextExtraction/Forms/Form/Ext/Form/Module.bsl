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
	
	If Common.IsWebClient() Or Not Common.IsWindowsClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	TextExtractionEnabled = False;
	
	ExecutionTimeInterval = Common.CommonSettingsStorageLoad("AutoTextExtraction", "ExecutionTimeInterval");
	If ExecutionTimeInterval = 0 Then
		ExecutionTimeInterval = 60;
		Common.CommonSettingsStorageSave("AutoTextExtraction", "ExecutionTimeInterval",  ExecutionTimeInterval);
	EndIf;
	
	FileCountInBlock = Common.CommonSettingsStorageLoad("AutoTextExtraction", "FileCountInBlock");
	If FileCountInBlock = 0 Then
		FileCountInBlock = 100;
		Common.CommonSettingsStorageSave("AutoTextExtraction", "FileCountInBlock",  FileCountInBlock);
	EndIf;
	
	Items.UnextractedTextFilesCountInfo.Title = StatusTextCalculation();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not TextsExtractionAvailable() Then
		Cancel = True;
		MessageText = NStr("en = 'Text extraction is only available in the Windows client.';");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
	UpdateInformationOnFilesWithNonExtractedTextCount();
	
EndProcedure

&AtClient
Procedure ExecutionTimeIntervalOnChange(Item)
	
	CommonServerCall.CommonSettingsStorageSave("AutoTextExtraction", "ExecutionTimeInterval",  ExecutionTimeInterval);
	
	If TextExtractionEnabled Then
		DetachIdleHandler("TextExtractionClientHandler");
		ExpectedExtractionStartTime = CommonClient.SessionDate() + ExecutionTimeInterval;
		AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
		CountdownUpdate();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FileCountInBlockOnChange(Item)
	CommonServerCall.CommonSettingsStorageSave("AutoTextExtraction", "FileCountInBlock",  FileCountInBlock);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Start(Command)
	
	TextExtractionEnabled = True; 
	
	ExpectedExtractionStartTime = CommonClient.SessionDate();
	AttachIdleHandler("TextExtractionClientHandler", ExecutionTimeInterval);
	
#If Not WebClient And Not MobileClient Then
	TextExtractionClientHandler();
#EndIf
	
	AttachIdleHandler("CountdownUpdate", 1);
	CountdownUpdate();
	
EndProcedure

&AtClient
Procedure CommandStop(Command)
	ExecuteStop();
EndProcedure

&AtClient
Procedure ExtractAll(Command)
	
#If Not WebClient And Not MobileClient Then
		UnextractedTextFileCountBeforeOperation = UnextractedTextFileCount;
		Status = "";
		PortionSize = 0; // Extract all
		TextExtractionClient(PortionSize);
		
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Extracting text from all files
			         |with extraction pending is completed.
			         |
			         | Files processed: %1.';"),
			UnextractedTextFileCountBeforeOperation));
#EndIf
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function TextsExtractionAvailable()
	
#If WebClient Or MobileClient Then
	Return False;
#Else
	Return CommonClient.IsWindowsClient();
#EndIf
	
EndFunction

&AtClientAtServerNoContext
Function StatusTextCalculation()
	Return NStr("en = 'Searching for files with text extraction pending…';");
EndFunction

&AtClient
Procedure UpdateInformationOnFilesWithNonExtractedTextCount()
	
	DetachIdleHandler("StartUpdateInformationOnFileCountWithUnextractedText");
	If CurrentBackgroundJob = "Calculation1" And ValueIsFilled(BackgroundJobIdentifier) Then
		CancelBackgroundJob1();
	EndIf;
	AttachIdleHandler("StartUpdateInformationOnFileCountWithUnextractedText", 2, True);
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob1()
	CancelJobExecution(BackgroundJobIdentifier);
	CurrentBackgroundJob = "";
	BackgroundJobIdentifier = "";
EndProcedure

&AtServerNoContext
Procedure CancelJobExecution(BackgroundJobIdentifier)
	If ValueIsFilled(BackgroundJobIdentifier) Then 
		TimeConsumingOperations.CancelJobExecution(BackgroundJobIdentifier);
	EndIf;
EndProcedure

&AtClient
Procedure StartUpdateInformationOnFileCountWithUnextractedText()
	
	If ValueIsFilled(BackgroundJobIdentifier) Then
		Items.UnextractedTextFilesCountInfo.Title = StatusTextCalculation();
		Return;
	EndIf;
	
	Items.UnextractedTextFilesCountInfo.Title = StatusTextCalculation();
	TimeConsumingOperation = ExecuteSearchOfFilesWIthNonExtractedText();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	
	NotifyDescription = New NotifyDescription("OnCompleteUpdateUnextractedTextFilesCountInformation", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure OnCompleteUpdateUnextractedTextFilesCountInformation(Result, AdditionalParameters) Export
	
	BackgroundJobIdentifier = "";
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;

	OutputInformationOnNonExtractedTextFilesCount();
	
EndProcedure

&AtClient
Procedure OutputInformationOnNonExtractedTextFilesCount()
	
	UnextractedTextFilesCountInfo = GetFromTempStorage(ResultAddress);
	If UnextractedTextFilesCountInfo = Undefined Then
		Return;
	EndIf;
	
	UnextractedTextFileCount = UnextractedTextFilesCountInfo;
	
	If UnextractedTextFileCount > 0 Then
		Items.UnextractedTextFilesCountInfo.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Files with text extraction pending: %1';"),
			UnextractedTextFileCount);
	Else
		Items.UnextractedTextFilesCountInfo.Title = NStr("en = 'Files with text extraction pending: None';");
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteSearchOfFilesWIthNonExtractedText()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Search for files with text extraction pending.';");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "FilesOperationsInternal.VersionsWithUnextractedTextCount");
	CurrentBackgroundJob = "Calculation1";
	BackgroundJobIdentifier = TimeConsumingOperation.JobID;
	ResultAddress = TimeConsumingOperation.ResultAddress;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtServerNoContext
Procedure WriteLogEventServer(MessageText)
	
	WriteLogEvent(NStr("en = 'Files.Extract text';", Common.DefaultLanguageCode()),
		EventLogLevel.Error,,, MessageText);
	
EndProcedure

&AtClient
Procedure CountdownUpdate()
	
	Left = ExpectedExtractionStartTime - CommonClient.SessionDate();
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Text extraction starts in %1 sec';"),
		Left);
	
	If Left <= 1 Then
		MessageText = "";
	EndIf;
	
	ExecutionTimeInterval = Items.ExecutionTimeInterval.EditText;
	Status = MessageText;
	
EndProcedure

&AtClient
Procedure TextExtractionClientHandler()
	
#If Not WebClient And Not MobileClient Then
	TextExtractionClient();
#EndIf

EndProcedure

#If Not WebClient And Not MobileClient Then
	
// Extracts text from files for full-text search.
&AtClient
Procedure TextExtractionClient(PortionSize = Undefined)
	
	ExpectedExtractionStartTime = CommonClient.SessionDate() + ExecutionTimeInterval;
	
	Try
		
		PortionSizeCurrent = FileCountInBlock;
		If PortionSize <> Undefined Then
			PortionSizeCurrent = PortionSize;
		EndIf;
		FilesArray = GetFilesForTextExtraction(PortionSizeCurrent);
		
		If FilesArray.Count() = 0 Then
			ShowUserNotification(NStr("en = 'Extract text';"),, NStr("en = 'No files for text extraction.';"));
			Return;
		EndIf;
		
		For IndexOf = 0 To FilesArray.Count() - 1 Do
			
			Extension = FilesArray[IndexOf].Extension;
			FileDescription = FilesArray[IndexOf].Description;
			FileOrFileVersion = FilesArray[IndexOf].Ref;
			Encoding = FilesArray[IndexOf].Encoding;
			
			Try
				FileAddress = GetFileNavigationLink(
					FileOrFileVersion, UUID);
				
				NameWithExtension = CommonClientServer.GetNameWithExtension(
					FileDescription, Extension);
				
				Progress = IndexOf * 100 / FilesArray.Count();
				Status(NStr("en = 'Extracting text from files';"), Progress, NameWithExtension);
				
				FilesOperationsInternalClient.ExtractVersionText(
					FileOrFileVersion, FileAddress, Extension, UUID, Encoding);
			
			Except
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An unexpected error occurred while extracting the text from the ""%1"" file:
						|%2';"),
					String(FileOrFileVersion), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
				Status(MessageText);
				ExtractionResult = "FailedExtraction";
				ExtractionErrorRecord(FileOrFileVersion, ExtractionResult, MessageText);
			EndTry;
			
		EndDo;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Text extraction completed.
			           |Files processed: %1';"),
			FilesArray.Count());		
		ShowUserNotification(NStr("en = 'Extract text';"),, MessageText);
		
	Except
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An unexpected error occurred while extracting the text from the ""%1"" file:
			|%2';"),
			String(FileOrFileVersion), ErrorProcessing.BriefErrorDescription(ErrorInfo()));	
		ShowUserNotification(NStr("en = 'Extract text';"),, MessageText);	
		WriteLogEventServer(MessageText);
	EndTry;
	
	UpdateInformationOnFilesWithNonExtractedTextCount();
	
EndProcedure

#EndIf

&AtServerNoContext
Procedure ExtractionErrorRecord(FileOrFileVersion, ExtractionResult, MessageText)
	
	SetPrivilegedMode(True);
	
	FilesOperationsInternal.RecordTextExtractionResult(FileOrFileVersion, ExtractionResult, "");
	
	// Record to the event log.
	WriteLogEventServer(MessageText);
	
EndProcedure


// Parameters:
//   FileCountInBlock - Number
// Returns:
//   Array of Structure:
//   * Ref - DefinedType.AttachedFile
//   * Extension - String
//   * Description - String
//   * Encoding - String 
//
&AtServerNoContext
Function GetFilesForTextExtraction(FileCountInBlock)
	
	Result = New Array;
	
	Query = New Query;
	GetAllFiles = (FileCountInBlock = 0);
	
	Query = New Query;
	Query.Text = FilesOperationsInternal.QueryTextToExtractText(GetAllFiles, True);
	
	Upload0 = Query.Execute().Unload();
	
	For Each String In Upload0 Do
		
		StringStructure = New Structure;
		StringStructure.Insert("Ref",       String.Ref);
		StringStructure.Insert("Extension",   String.Extension);
		StringStructure.Insert("Description", String.Description);
		StringStructure.Insert("Encoding",    String.Encoding);
		
		Result.Add(StringStructure);
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetFileNavigationLink(Val FileOrFileVersion, Val UUID)
	
	Return FilesOperationsInternal.FileURL2(FileOrFileVersion,
		UUID);
	
EndFunction

&AtClient
Procedure ExecuteStop()
	DetachIdleHandler("TextExtractionClientHandler");
	DetachIdleHandler("CountdownUpdate");
	Status = "";
	TextExtractionEnabled = False;
EndProcedure

#EndRegion
