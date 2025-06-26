///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseFullTextSearch = FullTextSearchServer.UseSearchFlagValue();
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations")
	   And Users.IsFullUser() Then
		
		// Visibility settings at startup.
		Items.AutomaticTextsExtractionGroup.Visible =
			  Users.IsFullUser(, True)
			And Not Common.DataSeparationEnabled()
			And Not Common.IsMobileClient();
		
	Else
		Items.AutomaticTextsExtractionGroup.Visible = False;
	EndIf;
	
	If Items.AutomaticTextsExtractionGroup.Visible Then
		
		If Common.FileInfobase() Then
			ChoiceList = Items.ExtractFilesTextsAtWindowsServer.ChoiceList;
			ChoiceList[0].Presentation = NStr("en = 'All workstations run on Windows.';");
			
			ChoiceList = Items.ExtractFilesTextsAtLinuxServer.ChoiceList;
			ChoiceList[0].Presentation = NStr("en = 'One or more workstations run on Linux.';");
		EndIf;
		
		// Form attributes values.
		ExtractTextFilesOnServer = ?(ConstantsSet.ExtractTextFilesOnServer, 1, 0);
	
		ScheduledJobsInfo = New Structure;
		FillScheduledJobInfo("TextExtraction");
	Else
		AutoTitle = False;
		Title = NStr("en = 'Full-text search management';");
		Items.SectionDetails.Title =
			NStr("en = 'Full-text search toggle, search index update.';");
	EndIf;
	
	// Update items states.
	SetAvailability();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	RefreshApplicationInterface();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	FullTextSearchClient.UseSearchFlagChangeNotificationProcessing(
		EventName, 
		UseFullTextSearch);
	
	SetAvailability();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseFullTextSearchOnChange(Item)
	
	FullTextSearchClient.OnChangeUseSearchFlag(UseFullTextSearch);
	
EndProcedure

&AtClient
Procedure ExtractFilesTextsAtServerOnChange(Item)
	Attachable_OnChangeAttribute(Item, False);
EndProcedure

&AtClient
Procedure IndexedDataMaxSizeOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure LimitMaxIndexedDataSizeOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure UpdateIndex(Command)
	UpdateIndexServer();
	ShowUserNotification(NStr("en = 'Full-text search';"),, NStr("en = 'Index has been updated';"));
EndProcedure

&AtClient
Procedure ClearIndex(Command)
	QueryText = NStr("en = 'The search index will be cleared, and you
		|will not be able to use the full-text search.
		|To enable the full-text search, update the index.
		|
		|Continue?';");
	
	Handler = New NotifyDescription("ClearTheIndexAfterAnsweringTheQuestion", ThisObject);
	ShowQueryBox(Handler, QueryText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure CheckIndex(Command)
	ClearMessages();
	CheckIndexServer();
	ShowUserNotification(NStr("en = 'Full-text search';"),, NStr("en = 'Index is up to date';"));
EndProcedure

&AtClient
Procedure EditScheduledJob(Command)
	ScheduledJobsHyperlinkClick("TextExtraction");
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	Result = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If Result.Property("CannotEnableFullTextSearchMode") Then
		// Display a warning message.
		QueryText = NStr("en = 'To change the full-text search mode, close all sessions, except for the current user session.';");
		
		Buttons = New ValueList;
		Buttons.Add("ActiveUsers", NStr("en = 'Active users';"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("OnChangeAttributeAfterAnswerToQuestion", ThisObject);
		ShowQueryBox(Handler, QueryText, Buttons, , "ActiveUsers");
		Return;
	EndIf;
	
	If ShouldRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If Result.ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, Result.ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsHyperlinkClick(PredefinedItemName)
	InformationRecords = ScheduledJobInfoClient(PredefinedItemName);
	If InformationRecords.Id = Undefined Then
		Return;
	EndIf;
	Context = New Structure;
	Context.Insert("PredefinedItemName", PredefinedItemName);
	Context.Insert("FlagChanged", False);
	Handler = New NotifyDescription("ScheduledJobsAfterChangeSchedule", ThisObject, Context);
	Dialog = New ScheduledJobDialog(InformationRecords.Schedule);
	Dialog.Show(Handler);
EndProcedure

&AtClient
Procedure ScheduledJobsAfterChangeSchedule(Schedule, Context) Export
	If Schedule = Undefined Then
		If Context.FlagChanged Then
			ThisObject[Context.CheckBoxName] = False;
		EndIf;
		Return;
	EndIf;
	
	Changes = New Structure("Schedule", Schedule);
	If Context.FlagChanged Then
		ThisObject[Context.CheckBoxName] = True;
		Changes.Insert("Use", True);
	EndIf;
	ScheduledJobsSave(Context.PredefinedItemName, Changes, True);
EndProcedure

&AtClient
Procedure OnChangeAttributeAfterAnswerToQuestion(Response, ExecutionParameters) Export
	If Response = "ActiveUsers" Then
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf;
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearTheIndexAfterAnsweringTheQuestion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		ClearIndexServer();
		ShowUserNotification(NStr("en = 'Full-text search';"),, NStr("en = 'Index has been cleaned up';"));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call.

&AtServer
Procedure UpdateIndexServer()
	FullTextSearch.UpdateIndex(False, False);
	SetAvailability("Command.UpdateIndex");
EndProcedure

&AtServer
Procedure ClearIndexServer()
	FullTextSearch.ClearIndex();
	SetAvailability("Command.ClearIndex");
EndProcedure

&AtServer
Procedure CheckIndexServer()
	Try
		IndexContainsCorrectData = FullTextSearch.CheckIndex();
	Except
		ErrorMessageText = 
			NStr("en = 'Cannot check index status. The index is being updated or cleaned up.';");
		Common.MessageToUser(ErrorMessageText);
		FullTextSearchServer.LogRecord(EventLogLevel.Warning, 
			"", ErrorInfo());
	EndTry;
	SetAvailability("Command.CheckIndex", True);
EndProcedure

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	Result = SaveAttributeValue(DataPathAttribute);
	SetAvailability(DataPathAttribute);
	If Result.Property("CannotEnableFullTextSearchMode") Then
		Return Result;
	EndIf;
	RefreshReusableValues();
	Return Result;
	
EndFunction

&AtServer
Procedure ScheduledJobsSave(PredefinedItemName, Changes, SetVisibilityAvailability)
	InformationRecords = ScheduledJobInfo(PredefinedItemName);
	If InformationRecords.Id = Undefined Then
		Return;
	EndIf;
	ScheduledJobsServer.ChangeJob(InformationRecords.Id, Changes);
	FillPropertyValues(InformationRecords, Changes);
	ScheduledJobsInfo.Insert(PredefinedItemName, InformationRecords);
	If SetVisibilityAvailability Then
		SetAvailability("ScheduledJob." + PredefinedItemName);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	Result = New Structure("ConstantName", "");
	
	// Saving values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "" Then
		Return Result;
	EndIf;
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		If DataPathAttribute = "ExtractTextFilesOnServer" Then
			ConstantName = "ExtractTextFilesOnServer";
			ConstantsSet.ExtractTextFilesOnServer = ExtractTextFilesOnServer;
			Changes = New Structure("Use", ConstantsSet.ExtractTextFilesOnServer);
			ScheduledJobsSave("TextExtraction", Changes, False);
		ElsIf DataPathAttribute = "IndexedDataMaxSize"
			Or DataPathAttribute = "LimitMaxIndexedDataSize" Then
			Try
				If LimitMaxIndexedDataSize Then
					// When you enable the restriction for the first time, the default value of the platform 1 MB is set.
					If IndexedDataMaxSize = 0 Then
						IndexedDataMaxSize = 1;
					EndIf;
					If FullTextSearch.GetMaxIndexedDataSize() <> IndexedDataMaxSize * 1048576 Then
						FullTextSearch.SetMaxIndexedDataSize(IndexedDataMaxSize * 1048576);
					EndIf;
				Else
					FullTextSearch.SetMaxIndexedDataSize(0);
				EndIf;
			Except
				WriteLogEvent(
					NStr("en = 'Full-text search';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				Result.Insert("CannotEnableFullTextSearchMode", True);
				Return Result;
			EndTry;
		EndIf;
	Else
		ConstantName = NameParts[1];
	EndIf;
	
	If IsBlankString(ConstantName) Then
		Return Result;
	EndIf;

	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Result.ConstantName = ConstantName;
	Return Result;
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "", IndexChecked = False)
	
	State = FullTextSearchServer.FullTextSearchStatus();
	
	Items.FullTextSearchManagementGroup.Enabled = (UseFullTextSearch = 1);
	Items.AutomaticTextsExtractionGroup.Enabled = (UseFullTextSearch = 1);
	
	If DataPathAttribute = ""
		Or DataPathAttribute = "LimitMaxIndexedDataSize"
		Or DataPathAttribute = "IndexedDataMaxSize"
		Or DataPathAttribute = "UseFullTextSearch"
		Or DataPathAttribute = "Command.UpdateIndex"
		Or DataPathAttribute = "Command.ClearIndex"
		Or DataPathAttribute = "Command.CheckIndex" Then
		
		If UseFullTextSearch = 1 Then
			IndexUpdateDate = FullTextSearch.UpdateDate();
			IndexTrue = (State = "SearchAllowed");
			If IndexChecked And Not IndexContainsCorrectData Then
				IndexStatus = NStr("en = 'Cleanup and update required';");
			ElsIf IndexTrue Then
				IndexStatus = NStr("en = 'No update required';");
			Else
				IndexStatus = NStr("en = 'Update required';");
			EndIf;
		Else
			IndexUpdateDate = '00010101';
			IndexTrue = False;
			IndexStatus = NStr("en = 'Full-text search is disabled';");
		EndIf;
		IndexedDataMaxSize = FullTextSearch.GetMaxIndexedDataSize() / 1048576;
		LimitMaxIndexedDataSize = IndexedDataMaxSize <> 0;
		
		Items.IndexedDataMaxSize.Enabled = LimitMaxIndexedDataSize;
		Items.MBDecoration.Enabled = LimitMaxIndexedDataSize;
		
		Items.UpdateIndex.Enabled = Not IndexTrue;
		
	EndIf;
	
	If Items.AutomaticTextsExtractionGroup.Visible
		And (DataPathAttribute = ""
		Or DataPathAttribute = "ExtractTextFilesOnServer"
		Or DataPathAttribute = "ScheduledJob.TextExtraction") Then
		Items.EditScheduledJob.Enabled = ConstantsSet.ExtractTextFilesOnServer;
		Items.StartTextExtraction.Enabled       = Not ConstantsSet.ExtractTextFilesOnServer;
		If ConstantsSet.ExtractTextFilesOnServer Then
			InformationRecords = ScheduledJobInfo("TextExtraction");
			SchedulePresentation = String(InformationRecords.Schedule);
			SchedulePresentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			SchedulePresentation = NStr("en = 'Automatic text extraction is not scheduled.';");
		EndIf;
		Items.EditScheduledJob.ExtendedTooltip.Title = SchedulePresentation;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillScheduledJobInfo(PredefinedItemName)
	InformationRecords = NewInformationAboutTheRoutineTask();
	ScheduledJobsInfo.Insert(PredefinedItemName, InformationRecords);
	Job = ScheduledJobsFindPredefinedItem(PredefinedItemName);
	If Job = Undefined Then
		Return;
	EndIf;
	InformationRecords.Id = Job.UUID;
	InformationRecords.Use = Job.Use;
	InformationRecords.Schedule    = Job.Schedule;
EndProcedure

// Returns:
//  Structure:
//   * Id - UUID 
//   * Use - Boolean
//   * Schedule - JobSchedule
// 
&AtServer
Function NewInformationAboutTheRoutineTask()
	Return New Structure("Id, Use, Schedule");
EndFunction

// Returns:
//   See NewInformationAboutTheRoutineTask
// 
&AtServer
Function ScheduledJobInfo(PredefinedItemName)
	Return ScheduledJobsInfo[PredefinedItemName];
EndFunction

// Returns:
//   See NewInformationAboutTheRoutineTask
// 
&AtClient
Function ScheduledJobInfoClient(PredefinedItemName)
	Return ScheduledJobsInfo[PredefinedItemName];
EndFunction

&AtServer
Function ScheduledJobsFindPredefinedItem(PredefinedItemName)
	Filter = New Structure("Metadata", PredefinedItemName);
	FoundItems = ScheduledJobsServer.FindJobs(Filter);
	Return ?(FoundItems.Count() = 0, Undefined, FoundItems[0]);
EndFunction

#EndRegion
