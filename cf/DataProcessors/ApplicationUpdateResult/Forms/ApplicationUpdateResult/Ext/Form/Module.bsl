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
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	ToolTipText      = SubsystemSettings.UpdateResultNotes;
	
	If Not IsBlankString(ToolTipText) Then
		Items.WhereToFindThisFormHint.Title = ToolTipText;
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		
		Items.MinimalUserActivityPeriodHintGroup.Visible = False;
		Items.WhereToFindThisFormHint.Title = 
			NStr("en = 'To view the progress of processing app data,
		               |go to Quick menu > Information > Release notes.';");
		
	EndIf;
	
	// Read constant values.
	GetInfobaseUpdateThreadsCount();
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdatePriority = ?(UpdateInfo.DeferredUpdateManagement.Property("ForceUpdate"), "DataProcessing", "UserWork");
	UpdateEndTime = UpdateInfo.UpdateEndTime;
	
	DeferredUpdateStartTime = UpdateInfo.DeferredUpdateStartTime;
	DeferredUpdatesEndTime = UpdateInfo.DeferredUpdatesEndTime;
	
	FileIB = Common.FileInfobase();
	
	If ValueIsFilled(UpdateEndTime) Then
		Items.UpdateCompletedInformation.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.UpdateCompletedInformation.Title,
			Metadata.Version,
			Format(UpdateEndTime, "DLF=D"),
			Format(UpdateEndTime, "DLF=T"),
			UpdateInfo.UpdateDuration);
	Else
		UpdateCompletedTitle = NStr("en = 'The application is updated to version %1.';");
		Items.UpdateCompletedInformation.Title = StringFunctionsClientServer.SubstituteParametersToString(UpdateCompletedTitle, Metadata.Version);
	EndIf;
	
	If UpdateInfo.DeferredUpdatesEndTime = Undefined Then
		
		If Not Users.IsFullUser(, True) Then
			Items.UpdateStatus.CurrentPage = Items.UpdateStatusForUser;
		Else
			
			If Not FileIB And UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined Then
				Items.UpdateStatus.CurrentPage = Items.UpdateInProgress;
				CheckPerformDeferredUpdate(UpdateInfo);
			Else
				Items.UpdateStatus.CurrentPage = Items.FileInfobaseUpdate;
			EndIf;
			
		EndIf;
		
	Else
		MessageText = UpdateResultMessage();
		Items.UpdateStatus.CurrentPage = Items.UpdateCompleted;
		
		TitleTemplate1 = NStr("en = 'Additional data processing procedures were completed on %1 at %2.';");
		Items.DeferredUpdateCompletedInformation.Title = 
		StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, 
			Format(UpdateInfo.DeferredUpdatesEndTime, "DLF=D"),
			Format(UpdateInfo.DeferredUpdatesEndTime, "DLF=T"));
		
	EndIf;
	
	SetVisibilityForInfobaseUpdateThreadsCount();
	
	If Not FileIB Then
		UpdateCompleted = False;
		ShowUpdateStatus(UpdateCompleted);
		SetAvailabilityForInfobaseUpdateThreadsCount(ThisObject);
		
		If UpdateCompleted Then
			RefreshUpdateCompletedPage(UpdateInfo);
			Items.UpdateStatus.CurrentPage = Items.UpdateCompleted;
		EndIf;
		
	Else
		UpdateInformationOnIssues();
		Items.UpdateStatusInformation.Visible = False;
		Items.ModifySchedule.Visible         = False;
	EndIf;
	
	If Users.IsFullUser(, True) Then
		
		If Common.DataSeparationEnabled() Then
			Items.ScheduleSetupGroup.Visible = False;
		Else
			JobsFilter = New Structure;
			JobsFilter.Insert("Metadata", Metadata.ScheduledJobs.DeferredIBUpdate);
			Jobs = ScheduledJobsServer.FindJobs(JobsFilter);
			For Each Job In Jobs Do
				Schedule = Job.Schedule;
				Break;
			EndDo;
		EndIf;
		
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Items.MainUpdateHyperlink.Visible = False;
		Items.PriorityGroup.Visible               = False;
	EndIf;
	
	ProcessUpdateResultAtServer();
	
	HideExtraGroupsInForm(Parameters.OpenedFromAdministrationPanel, UpdateInfo);
	
	Items.OpenDeferredHandlersList.Title = MessageText;
	Items.InformationTitle.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Additional data processing procedures required for upgrade to version %1 are in progress.
			|Operations with this data are temporarily restricted.';"), Metadata.Version);
	
	Items.FormRelaunchDeferredUpdate.Visible = Not Common.IsSubordinateDIBNode()
		And ThereHandlersWithParallelExecutionMode()
		And Users.IsFullUser();
	
	TroubleHintWithData = NStr("en = 'When the application is updating, data issues might prevent the processing.
		|If additional data processing procedures fail, do the following:
		| • Open the issue list and follow the recommendations.
		| • Follow the link <b>Some of the update procedures are not completed</b> and click <b>Run</b> to resume additional data processing procedures.';");
	TroubleHintWithData = StringFunctions.FormattedString(TroubleHintWithData);
	Items.Problemswithdata.ExtendedTooltip.Title = TroubleHintWithData;
	Items.IssuesDataCompleted.ExtendedTooltip.Title = TroubleHintWithData;
	
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable(); 
	Items.UpdateStatus.Visible = SeparatedDataUsageAvailable;
	Items.FormRelaunchDeferredUpdate.Visible = SeparatedDataUsageAvailable;
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		AreasUpdateProgressReport = ModuleInfobaseUpdateInternalSaaS.AreasUpdateProgressReport();
		
		Items.HyperlinkAreasUpdateProgress.Visible = Not SeparatedDataUsageAvailable;
	Else
		Items.HyperlinkAreasUpdateProgress.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If MobileClient Then
	CommandBarLocation = FormCommandBarLabelLocation.None;
#EndIf
	
	If Not FileIB Then
		AttachIdleHandler("CheckHandlersExecutionStatus", 15);
	EndIf;
	
	ProcessUpdateResultAtClient();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "DeferredUpdate" Then
		
		If Not FileIB Then
			Items.UpdateStatus.CurrentPage = Items.UpdateInProgress;
		EndIf;
		
		UpdateCompletedSuccessful = False;
		AttachIdleHandler("RunDeferredUpdate", 0.5, True);
	ElsIf EventName = "DeferredUpdateRestarted" Then
		If FileIB Then
			Items.UpdateStatus.CurrentPage = Items.FileInfobaseUpdate;
		Else
			Items.UpdateStatus.CurrentPage = Items.UpdateInProgress;
		EndIf;
		UpdateCompletedSuccessful = False;
		CheckHandlersExecutionStatus();
		AttachIdleHandler("CheckHandlersExecutionStatus", 15);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateStatusInformationClick(Item)
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredHandlers");
EndProcedure

&AtClient
Procedure MainUpdateHyperlinkClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", DeferredUpdateStartTime);
	If DeferredUpdatesEndTime <> Undefined Then
		FormParameters.Insert("EndDate", DeferredUpdatesEndTime);
	EndIf;
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

&AtClient
Procedure UpdateErrorInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	
	ApplicationsList = New Array;
	ApplicationsList.Add("COMConnection");
	ApplicationsList.Add("Designer");
	ApplicationsList.Add("1CV8");
	ApplicationsList.Add("1CV8C");
	
	FormParameters.Insert("User", UserName());
	FormParameters.Insert("ApplicationName", ApplicationsList);
	
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

&AtClient
Procedure UpdatePriorityOnChange(Item)
	
	SetUpdatePriority();
	SetAvailabilityForInfobaseUpdateThreadsCount(ThisObject);
	
EndProcedure

&AtClient
Procedure InfobaseUpdateThreadCountOnChange(Item)
	
	SetInfobaseUpdateThreadsCount();
	
EndProcedure

&AtClient
Procedure PatchesInstalledInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	ShowInstalledPatches();
EndProcedure

&AtClient
Procedure ExplanationUpdateNotRunningURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	If FormattedStringURL = "CheckLock" Then
		If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
			ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
			ModuleIBConnectionsClient.OnOpenUserActivityLockForm();
		EndIf;
	ElsIf FormattedStringURL = "Enable" Then
		EnableScheduledJob();
		MessageText = NStr("en = 'Duty is enabled. The status will refresh soon.';");
		ShowMessageBox(, MessageText);
	EndIf;
	
EndProcedure

&AtClient
Procedure HyperlinkAreasUpdateProgressClick(Item)
	OpenForm(AreasUpdateProgressReport);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RunUpdate(Command)
	
	If Not FileIB Then
		Items.UpdateStatus.CurrentPage = Items.UpdateInProgress;
	EndIf;
	
	AttachIdleHandler("RunDeferredUpdate", 0.5, True);
	
EndProcedure

&AtClient
Procedure OpenDeferredHandlersList(Command)
	OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredHandlers");
EndProcedure

&AtClient
Procedure ModifySchedule(Command)
	
	Dialog = New ScheduledJobDialog(Schedule);
	
	NotifyDescription = New NotifyDescription("ChangeScheduleAfterSetUpSchedule", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure InformationForTechnicalSupport(Command)
	
	If Not IsBlankString(ScriptDirectory) Then
		NotifyDescription = New NotifyDescription("BeginFindingFilesCompletion", ThisObject);
		BeginFindingFiles(NotifyDescription, ScriptDirectory, "log*.txt");
	EndIf;
	
EndProcedure

&AtClient
Procedure BeginFindingFilesCompletion(FilesArray, AdditionalParameters) Export
	If FilesArray.Count() > 0 Then
		LogFile = FilesArray[0];
		FileSystemClient.OpenFile(LogFile.FullName);
	Else
		// If there is no log, open temporary directory of the update script.
		FileSystemClient.OpenExplorer(ScriptDirectory);
	EndIf;
EndProcedure

&AtClient
Procedure ProblemSituationsClick(Item)
	Levels = New Array;
	Levels.Add("Error");
	Levels.Add("Warning");
	
	LogFilter = New Structure;
	LogFilter.Insert("StartDate", DeferredUpdateStartTime);
	LogFilter.Insert("Level", Levels);
	LogFilter.Insert("EventLogEvent", NStr("en = 'Infobase update';", CommonClient.DefaultLanguageCode()));
	EventLogClient.OpenEventLog(LogFilter, ThisObject);
EndProcedure

&AtClient
Procedure RelaunchDeferredUpdate(Command)
	OpenForm("InformationRegister.UpdateHandlers.Form.RestartDeferredUpdate");
EndProcedure

&AtClient
Procedure ProblemswithdataClick(Item)
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditClient = CommonClient.CommonModule("AccountingAuditClient");
		ModuleAccountingAuditClient.OpenIssuesReport("IBVersionUpdate", False);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure HideExtraGroupsInForm(OpenedFromAdministrationPanel, InformationRecords)
	
	IsFullUser = Users.IsFullUser(, True);
	
	If Not IsFullUser Or OpenedFromAdministrationPanel Then
		WindowOptionsKey = "FormForOrdinaryUser";
		
		Items.WhereToFindThisFormHint.Visible = False;
		Items.MainUpdateHyperlink.Visible = AccessRight("View", Metadata.DataProcessors.EventLog);
		
	Else
		WindowOptionsKey = "FormForAdministrator";
	EndIf;
	
	If IsFullUser
		And ValueIsFilled(InformationRecords.VersionPatchesDeletion)
		And Metadata.Version = InformationRecords.VersionPatchesDeletion Then
		Items.PatchesDeletionInformationGroup.Visible = True;
		WindowOptionsKey = "PatchesDeletionWarning";
	Else
		Items.PatchesDeletionInformationGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpdatePriority()
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.IBUpdateInfo");
		Block.Lock();
		
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		If UpdatePriority = "DataProcessing" Then
			UpdateInfo.DeferredUpdateManagement.Insert("ForceUpdate");
		Else
			UpdateInfo.DeferredUpdateManagement.Delete("ForceUpdate");
		EndIf;
		
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure SetInfobaseUpdateThreadsCount()
	
	Constants.InfobaseUpdateThreadCount.Set(InfobaseUpdateThreadCount);
	
EndProcedure

&AtClient
Procedure RunDeferredUpdate()
	
	ExecuteUpdateAtServer();
	If Not FileIB Then
		CheckHandlersExecutionStatus();
		AttachIdleHandler("CheckHandlersExecutionStatus", 15);
		Return;
	EndIf;
	
	Items.UpdateStatus.CurrentPage = Items.UpdateCompleted;
	
EndProcedure

&AtClient
Procedure CheckHandlersExecutionStatus()
	
	UpdateCompleted = False;
	CheckHandlersExecutionStatusAtServer(UpdateCompleted);
	If UpdateCompleted Then
		Items.UpdateStatus.CurrentPage = Items.UpdateCompleted;
		DetachIdleHandler("CheckHandlersExecutionStatus")
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckHandlersExecutionStatusAtServer(UpdateCompleted)
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdatesEndTime <> Undefined Then
		UpdateCompleted = True;
	Else
		ShowUpdateStatus(UpdateCompleted);
	EndIf;
	
	If UpdateCompleted = True Then
		RefreshUpdateCompletedPage(UpdateInfo);
		UpdateInformationOnIssues();
	Else
		CheckPerformDeferredUpdate(UpdateInfo);
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteUpdateAtServer()
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	
	UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined;
	UpdateInfo.DeferredUpdatesEndTime = Undefined;
	
	ResetHandlersStatus(Enums.UpdateHandlersStatuses.Error);
	ResetHandlersStatus(Enums.UpdateHandlersStatuses.Running);
	
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
	
	Constants.DeferredUpdateCompletedSuccessfully.Set(False);
	
	If Not FileIB Then
		EnableScheduledJob();
		Return;
	EndIf;
	
	InfobaseUpdateInternal.ExecuteDeferredUpdateNow(Undefined);
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	RefreshUpdateCompletedPage(UpdateInfo);
	
EndProcedure

&AtServer
Procedure ResetHandlersStatus(Status)
	
	// ACC:1327-off - There's no concurrent access to the register.
	// ACC:1328-off - There's no concurrent access to the register.
	Query = New Query;
	Query.SetParameter("Status", Status);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.Status = &Status";
	Handlers = Query.Execute().Unload();
	For Each Handler In Handlers Do
		RecordSet = InformationRegisters.UpdateHandlers.CreateRecordSet();
		RecordSet.Filter.HandlerName.Set(Handler.HandlerName);
		RecordSet.Read();
		
		Record = RecordSet[0];
		Record.AttemptCount = 0;
		Record.Status = Enums.UpdateHandlersStatuses.NotPerformed;
		ExecutionStatistics = Record.ExecutionStatistics.Get();
		ExecutionStatistics.Insert("StartsCount", 0);
		Record.ExecutionStatistics = New ValueStorage(ExecutionStatistics);
		
		RecordSet.Write();
	EndDo;
	// ACC:1327-on
	// ACC:1328-on
	
EndProcedure

&AtServer
Procedure RefreshUpdateCompletedPage(UpdateInfo)
	
	TitleTemplate1 = NStr("en = 'Additional data processing procedures were completed on %1 at %2.';");
	MessageText = UpdateResultMessage();
	
	Items.DeferredUpdateCompletedInformation.Title = 
		StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, 
			Format(UpdateInfo.DeferredUpdatesEndTime, "DLF=D"),
			Format(UpdateInfo.DeferredUpdatesEndTime, "DLF=T"));
	
	Items.OpenDeferredHandlersList.Title = MessageText;
	
	DeferredUpdatesEndTime = UpdateInfo.DeferredUpdatesEndTime;
	
EndProcedure

&AtServer
Function UpdateResultMessage()
	
	Progress = HandlersExecutionProgress();
	
	If Progress.TotalHandlerCount = Progress.CompletedHandlersCount Then
		
		If Progress.TotalHandlerCount = 0 Then
			Items.NoDeferredHandlersInformation.Visible = True;
			Items.DeferredUpdateCompletedInformation.Visible    = False;
			Items.SwitchToDeferredHandlersListGroup.Visible = False;
			MessageText = "";
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'All update procedures are completed (%1).';"), Progress.CompletedHandlersCount);
		EndIf;
		Items.CompletedPicture.Picture = PictureLib.Success32;
		UpdateCompletedSuccessful = True;
	Else
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Some of the update procedures are not completed (%1 out of %2 completed)';"), 
			Progress.CompletedHandlersCount, Progress.TotalHandlerCount);
		Items.CompletedPicture.Picture = PictureLib.DialogStop;
	EndIf;
	Return MessageText;
	
EndFunction

&AtServer
Procedure ShowUpdateStatus(UpdateCompleted = False)
	
	Progress = HandlersExecutionProgress();
	
	If Progress.TotalHandlerCount = Progress.CompletedHandlersCount Then
		UpdateCompleted = True;
	EndIf;
	
	Items.UpdateStatusInformation.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Completed: %1 out of %2.';"),
		Progress.CompletedHandlersCount,
		Progress.TotalHandlerCount);
	
	UpdateInformationOnIssues();
	
EndProcedure

&AtServer
Procedure UpdateInformationOnIssues()
	
	// Display information about the handler issue.
	NumberofProblemsInHandlers = ProblemSituationsInUpdateHandlers();
	If NumberofProblemsInHandlers <> 0 And Not UpdateCompletedSuccessful Then
		TextIndicator = NStr("en = 'Handler issues found';");
	Else
		TextIndicator = NStr("en = 'No handler issues found';");
	EndIf;
	
	Items.ProblemSituations.Title = TextIndicator; // On the update progress page.
	Items.ProblemSituationsCompleted.Title = TextIndicator; // On the completed handler page.
	
	// Display information about the data issue.
	ShouldShowDataIssues = InfobaseUpdateInternal.ShouldShowDataIssues();
	If ShouldShowDataIssues Then
		NumberofProblemswithData = InfobaseUpdateInternal.NumberofProblemswithData();
	Else
		NumberofProblemswithData = 0; 
		Items.GroupIndicationofProblemswithData.Visible = False;
		Items.GroupIndicationofProblemswithDataCompleted.Visible = False;
	EndIf;
	If NumberofProblemswithData <> 0 Then
		TextIndicator = NStr("en = 'Data issues (%1)';");
		TextIndicator = StringFunctionsClientServer.SubstituteParametersToString(TextIndicator, NumberofProblemswithData);
	Else
		TextIndicator = NStr("en = 'No data issues found';");
	EndIf;
	
	Items.Problemswithdata.Title = TextIndicator; // On the update progress page.
	Items.IssuesDataCompleted.Title = TextIndicator; // On the completed handler page.
	
	// Appearance of data issue elements.
	HyperlinkProblemsWithHandlers = False;
	HyperlinkProblemsWithData       = False;
	ImageProblemsWithHandlers = PictureLib.AppearanceCheckIcon;
	ImageProblemsWithData       = PictureLib.AppearanceCheckIcon;
	
	If NumberofProblemsInHandlers <> 0 And NumberofProblemswithData <> 0 Then
		If Not UpdateCompletedSuccessful Then
			ImageProblemsWithHandlers = Items.PictureTemplate.Picture;
			HyperlinkProblemsWithHandlers = True;
		EndIf;
		ImageProblemsWithData       = Items.PictureTemplate.Picture;
		HyperlinkProblemsWithData       = True;
		
	ElsIf NumberofProblemsInHandlers <> 0 And Not UpdateCompletedSuccessful And NumberofProblemswithData = 0 Then
		ImageProblemsWithHandlers = Items.PictureTemplate.Picture;
		HyperlinkProblemsWithHandlers = True;
		
	ElsIf NumberofProblemsInHandlers = 0 And NumberofProblemswithData <> 0 Then
		ImageProblemsWithData    = Items.PictureTemplate.Picture;
		HyperlinkProblemsWithData = True;
		
	EndIf;
	
	Items.Problemswithdata.Hyperlink   = HyperlinkProblemsWithData;
	Items.ProblemSituations.Hyperlink = HyperlinkProblemsWithHandlers;
	Items.IssuesDataCompleted.Hyperlink   = HyperlinkProblemsWithData;
	Items.ProblemSituationsCompleted.Hyperlink = HyperlinkProblemsWithHandlers;
	
	Items.DecorationIndicationProblems.Picture         = ImageProblemsWithHandlers;
	Items.DecorationIndicationProblemsWithData.Picture = ImageProblemsWithData;
	Items.DecorationIndicationProblemsCompleted.Picture         = ImageProblemsWithHandlers;
	Items.DecorationIndicationDataProblemsCompleted.Picture = ImageProblemsWithData;
	
	// Display warning about the data processor loop.
	WarnLooping = False;
	If UpdatePriority = "DataProcessing"
		And JobActive
		And CompletedAllSequentialHandlers() Then
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		UpdateSessionStartDate = UpdateInfo.UpdateSessionStartDate;
		If UpdateSessionStartDate <> Undefined
			And CurrentSessionDate() - UpdateSessionStartDate > 5400
			And Not HaveProgressIntervalsDataProcessing() Then
			WarnLooping = True;
		EndIf;
	EndIf;
	
	Items.DecorationWarningLooping.Visible = WarnLooping;
EndProcedure

&AtServer
Function HandlersExecutionProgress()
	
	Query = New Query;
	Query.SetParameter("ExecutionMode", Enums.HandlersExecutionModes.Deferred);
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.Text =
		"SELECT
		|	COUNT(UpdateHandlers.HandlerName) AS Count
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.ExecutionMode = &ExecutionMode
		|	AND UpdateHandlers.Status = &Status";
	Result = Query.Execute().Unload();
	CompletedHandlersCount = Result[0].Count;
	Query.Text =
		"SELECT
		|	COUNT(UpdateHandlers.HandlerName) AS Count
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.ExecutionMode = &ExecutionMode";
	Result = Query.Execute().Unload();
	TotalHandlerCount = Result[0].Count;
	
	Result = New Structure;
	Result.Insert("TotalHandlerCount", TotalHandlerCount);
	Result.Insert("CompletedHandlersCount", CompletedHandlersCount);
	
	Return Result;
	
EndFunction

&AtServer
Function CompletedAllSequentialHandlers()
	
	Query = New Query;
	Query.SetParameter("DeferredHandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Sequentially);
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.Text =
		"SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.DeferredHandlerExecutionMode = &DeferredHandlerExecutionMode
		|	AND UpdateHandlers.Status <> &Status";
	
	Return Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function HaveProgressIntervalsDataProcessing()
	
	CheckedInterval = BegOfHour(CurrentSessionDate() - 7200);
	
	Query = New Query;
	Query.SetParameter("IntervalHour", CheckedInterval);
	Query.Text =
		"SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.UpdateProgress AS UpdateProgress
		|WHERE
		|	UpdateProgress.IntervalHour >= &IntervalHour";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Procedure SetDeferredUpdateSchedule(NewSchedule)
	
	JobsFilter = New Structure;
	JobsFilter.Insert("Metadata", Metadata.ScheduledJobs.DeferredIBUpdate);
	Jobs = ScheduledJobsServer.FindJobs(JobsFilter);
	
	For Each Job In Jobs Do
		JobParameters = New Structure("Schedule", NewSchedule);
		ScheduledJobsServer.ChangeJob(Job, JobParameters);
	EndDo;
	
	Schedule = NewSchedule;
	
EndProcedure

&AtClient
Procedure ChangeScheduleAfterSetUpSchedule(NewSchedule, AdditionalParameters) Export
	
	If NewSchedule <> Undefined Then
		If NewSchedule.RepeatPeriodInDay = 0 Then
			Notification = New NotifyDescription("ChangeScheduleAfterQuery", ThisObject, NewSchedule);
			
			QuestionButtons = New ValueList;
			QuestionButtons.Add("SetUpSchedule", NStr("en = 'Set schedule';"));
			QuestionButtons.Add("RecommendedSettings1", NStr("en = 'Use recommended settings';"));
			
			MessageText = NStr("en = 'Additional data processing procedures are executed in small batches.
				|To have them executed correctly, specify the repeat interval.
				|
				|In the schedule settings window, click the ""Daily"" tab
				|and fill in the ""Repeat after"" field.';");
			ShowQueryBox(Notification, MessageText, QuestionButtons,, "SetUpSchedule");
		Else
			SetDeferredUpdateSchedule(NewSchedule);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeScheduleAfterQuery(Result, NewSchedule) Export
	
	If Result = "RecommendedSettings1" Then
		NewSchedule.RepeatPeriodInDay = 60;
		NewSchedule.RepeatPause = 60;
		SetDeferredUpdateSchedule(NewSchedule);
	Else
		NotifyDescription = New NotifyDescription("ChangeScheduleAfterSetUpSchedule", ThisObject);
		Dialog = New ScheduledJobDialog(NewSchedule);
		Dialog.Show(NotifyDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessUpdateResultAtServer()
	
	Items.InstalledPatchesGroup.Visible = False;
	// If it is the first start after a configuration update, storing and resetting status.
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate")
		And Common.SeparatedDataUsageAvailable() Then
		PatchInfo = Undefined;
		ModuleConfigurationUpdate = Common.CommonModule("ConfigurationUpdate");
		ModuleConfigurationUpdate.CheckUpdateStatus(UpdateResult, ScriptDirectory, PatchInfo);
		ProcessPatchInstallResult(PatchInfo);
	EndIf;
	
	If IsBlankString(ScriptDirectory) Then 
		Items.InformationForTechnicalSupport.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPatchInstallResult(PatchInfo)
	
	If TypeOf(PatchInfo) <> Type("Structure") Then
		Return;
	EndIf;
	
	TotalPatchCount = PatchInfo.TotalPatchCount;
	If TotalPatchCount = 0 Then
		Return;
	EndIf;
	
	Items.InstalledPatchesGroup.Visible = True;
	Corrections.LoadValues(PatchInfo.Installed);
	
	If PatchInfo.Unspecified > 0 Then
		InstalledSuccessfully = TotalPatchCount - PatchInfo.Unspecified;
		Ref = New FormattedString(NStr("en = 'Cannot install the patches';"),,,, "UnsuccessfulInstallation");
		PatchesLabel = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '(%1 out of %2).';"), InstalledSuccessfully, TotalPatchCount);
		PatchesLabel = New FormattedString(Ref, " ", PatchesLabel);
		Items.InstalledPatchesGroup.CurrentPage = Items.PatchesInstallationErrorGroup;
		Items.PatchesErrorInformation.Title = PatchesLabel;
	Else
		Ref = New FormattedString(NStr("en = 'The patches';"),,,, "InstalledPatches");
		PatchesLabel = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'are installed (%1).';"), TotalPatchCount);
		PatchesLabel = New FormattedString(Ref, " ", PatchesLabel);
		Items.PatchesInstalledInformation.Title = PatchesLabel;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessUpdateResultAtClient()
	
	If UpdateResult <> Undefined
		And CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.ProcessUpdateResult(UpdateResult, ScriptDirectory);
		If UpdateResult = False Then
			Items.UpdateResultsGroup.CurrentPage = Items.UpdateErrorGroup;
			// If the configuration is not updated, the deferred handlers are also not executed.
			Items.UpdateStatus.Visible = False;
			Items.WhereToFindThisFormHint.Visible = False;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowInstalledPatches()
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("Corrections", Corrections);
		
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.ShowInstalledPatches(OpeningParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInfobaseUpdateThreadsCount()
	
	If AccessRight("Read", Metadata.Constants.InfobaseUpdateThreadCount) Then
		InfobaseUpdateThreadCount =
			InfobaseUpdateInternal.InfobaseUpdateThreadCount();
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetAvailabilityForInfobaseUpdateThreadsCount(Form)
	
	Available = (Form.UpdatePriority = "DataProcessing");
	Form.Items.InfobaseUpdateThreadCount.Enabled = Available;
	
EndProcedure

&AtServer
Procedure SetVisibilityForInfobaseUpdateThreadsCount()
	
	MultithreadUpdateAllowed = InfobaseUpdateInternal.MultithreadUpdateAllowed();
	Items.InfobaseUpdateThreadCount.Visible = MultithreadUpdateAllowed;
	
	If MultithreadUpdateAllowed Then
		Items.UpdatePriority.ToolTipRepresentation = ToolTipRepresentation.None;
	Else
		Items.UpdatePriority.ToolTipRepresentation = ToolTipRepresentation.Button;
	EndIf;
	
EndProcedure

&AtServer
Function ProblemSituationsInUpdateHandlers()
	
	Query = New Query;
	Query.SetParameter("ExecutionMode", Enums.HandlersExecutionModes.Deferred);
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.ExecutionStatistics AS ExecutionStatistics
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.ExecutionMode = &ExecutionMode";
	Result = Query.Execute().Unload();
	
	IssuesCount = 0;
	For Each String In Result Do
		ExecutionStatistics = String.ExecutionStatistics;
		ExecutionStatistics = ExecutionStatistics.Get();
		If TypeOf(ExecutionStatistics) <> Type("Map") Then
			Continue;
		EndIf;
		
		If ExecutionStatistics["HasErrors"] = True Then
			IssuesCount = IssuesCount + 1;
		EndIf;
	EndDo;
	
	Return IssuesCount;
	
EndFunction

&AtServer
Procedure CheckPerformDeferredUpdate(UpdateInfo)
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	Job = ScheduledJobsServer.Job(Metadata.ScheduledJobs.DeferredIBUpdate);
	TaskIsRunning = False;
	Messages = New Array;
	IdentifierHyperlinks = "";
	If Job.Use Then
		JobsFilter = New Structure;
		JobsFilter.Insert("MethodName", "InfobaseUpdateInternal.ExecuteDeferredUpdate");
		FoundJobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
		
		For Each BackgroundJob In FoundJobs Do
			// Running background update job is found.
			If BackgroundJob.State = BackgroundJobState.Active Then
				JobActive = True;
				TaskIsRunning = True;
				Break;
			EndIf;
			JobActive = False;
			
			// ACC:143-off - Background jobs use the current date.
			// The background job ran recently.
			If BackgroundJob.End > CurrentDate() - Job.Schedule.RepeatPeriodInDay * 5 Then
				TaskIsRunning = True;
			EndIf;
			
			If Not TaskIsRunning Then
				ExecutionRequired = Job.Schedule.ExecutionRequired(CurrentDate(), BackgroundJob.Begin, BackgroundJob.End);
				TaskIsRunning = Not ExecutionRequired;
			EndIf;
			// ACC:143-on
			
			Break;
		EndDo;
		
		MessageText = NStr("en = 'Scheduled job <b>Deferred update</b> is active but not running.
			|Probably, the scheduled job lock is enabled.';");
		Messages.Add(StrConcat(StrSplit(MessageText, Chars.LF), " "));
		If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
			Messages.Add(NStr("en = '<a href=""%1"">Check scheduled job lock</a>';"));
			IdentifierHyperlinks = "CheckLock";
		EndIf;
	Else
		MessageText = NStr("en = 'Additional procedures of data processing are not running
			|because the <b>Deferred update</b> scheduled job is disabled.';");
		Messages.Add(StrConcat(StrSplit(MessageText, Chars.LF), " "));
		Messages.Add(NStr("en = '<a href=""%1"">Enable</a>';"));
		IdentifierHyperlinks = "Enable";
	EndIf;
	MessageText = StringFunctions.FormattedString(StrConcat(Messages, Chars.LF), IdentifierHyperlinks);
	Items.ExplanationUpdateNotRunning.Title = MessageText;
	
	Items.HeaderGroupClientServer.Visible = TaskIsRunning;
	Items.GroupHeaderUpdateNotRunning.Visible = Not TaskIsRunning;
	
EndProcedure

&AtServer
Procedure EnableScheduledJob()
	InfobaseUpdateInternal.OnEnableDeferredUpdate(True);
EndProcedure

&AtServer
Function ThereHandlersWithParallelExecutionMode()
	
	Query = New Query;
	Query.SetParameter("DeferredHandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Parallel);
	Query.Text =
		"SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.DeferredHandlerExecutionMode = &DeferredHandlerExecutionMode";
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion
