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
	
	SetConditionalAppearance();
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	DeferredUpdateStartTime = UpdateInfo.DeferredUpdateStartTime;
	DeferredUpdateEndTime = UpdateInfo.DeferredUpdatesEndTime;
	CurrentSessionNumber = UpdateInfo.SessionNumber;
	FileIB = Common.FileInfobase();
	
	FullUser = Users.IsFullUser(, False);
	If Not FullUser Then
		Items.RunAgainGroup.Visible = False;
		Items.Resume.Visible             = False;
		Items.Stop.Visible         = False;
		Items.OrderGroup.Visible         = False;
		Items.ContextMenuPause.Visible = False;
		Items.ContextMenuRun.Visible     = False;
		Items.DeferredHandlersContextMenuOrder.Visible = False;
	ElsIf Common.FileInfobase() Then
		Items.DeferredHandlersContextMenuOrder.Visible = False;
		Items.OrderGroup.Visible         = False;
	EndIf;
	
	If Not FileIB Then
		UpdateInProgress = (UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined);
	EndIf;
	
	If Not Common.DebugMode()
		Or UpdateInfo.DeferredUpdateCompletedSuccessfully = True Then
		Items.RunProcedure.Visible = False;
		Items.ContextMenuRunSelectedHandler.Visible = False;
	EndIf;
	
	If Not AccessRight("View", Metadata.DataProcessors.EventLog) Then
		Items.DeferredUpdateHyperlink.Visible = False;
	EndIf;
	
	Status = "AllProcedures";
	
	GenerateDeferredHandlerTable(, True);
	
	Items.UpdateProgressHyperlink.Visible = UseParallelMode;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		Items.ContentGroup.Representation = UsualGroupRepresentation.NormalSeparation;
		Items.Priority.Visible = False;
		Items.Number.Visible = False;
		Items.DeferredHandlersExecutionInterval.Visible = False;
		Items.DeferredHandlersExecutionDuration.Visible = False;
	EndIf;
	
	ValueError      = String(Enums.UpdateHandlersStatuses.Error);
	TheValueIsBeingExecuted = String(Enums.UpdateHandlersStatuses.Running);
	TheValueIsCompleted    = String(Enums.UpdateHandlersStatuses.Completed);
	Items.Status.ChoiceList.Add(ValueError, ValueError);
	Items.Status.ChoiceList.Add(TheValueIsBeingExecuted, TheValueIsBeingExecuted);
	Items.Status.ChoiceList.Add(TheValueIsCompleted, TheValueIsCompleted);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DeferredHandlersOnActivateRow(Item)
	If Item.CurrentData = Undefined
		Or Not FullUser Then
		Return;
	EndIf;
	
	If Item.CurrentData.Status = PredefinedValue("Enum.UpdateHandlersStatuses.Running") Then
		Items.ContextMenuRun.Enabled = False;
		Items.ContextMenuPause.Enabled = True;
		Items.Resume.Enabled = False;
		Items.Stop.Enabled = True;
	ElsIf Item.CurrentData.Status = PredefinedValue("Enum.UpdateHandlersStatuses.Paused") Then
		Items.ContextMenuRun.Enabled = True;
		Items.ContextMenuPause.Enabled = False;
		Items.Resume.Enabled = True;
		Items.Stop.Enabled = False;
	Else
		Items.ContextMenuRun.Enabled = False;
		Items.ContextMenuPause.Enabled = False;
		Items.Resume.Enabled = False;
		Items.Stop.Enabled = False;
	EndIf;
	
	If Not UpdateInProgress
		And Item.CurrentData.Status <> PredefinedValue("Enum.UpdateHandlersStatuses.Completed") Then
		Items.RunProcedure.Enabled = True;
		Items.ContextMenuRunSelectedHandler.Enabled = True;
	Else
		Items.RunProcedure.Enabled = False;
		Items.ContextMenuRunSelectedHandler.Enabled = False;
	EndIf;
	
	UpdatePriorityCommandStatuses(Item);
	
EndProcedure

&AtClient
Procedure HyperlinkHandlersUpdatesClick(Item)
	Filterlist0 = New Structure;
	Filterlist0.Insert("ExecutionMode", PredefinedValue("Enum.HandlersExecutionModes.Deferred"));
	
	OpenForm("InformationRegister.UpdateHandlers.ListForm", Filterlist0);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDeferredHandlers

&AtClient
Procedure DeferredHandlersSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field = Items.DeferredHandlersHandlerAddOn
	   And Item.CurrentData.IsObsoleteDataCleanupHandler Then
		
		OpenForm("DataProcessor.ApplicationUpdateResult.Form.ClearObsoleteData");
		Return;
	EndIf;
	
	HandlerName = Item.CurrentData.Id;
	
	Filter = New Structure("HandlerName",HandlerName);
	
	ValueType = Type("InformationRegisterRecordKey.UpdateHandlers");
	WriteParameters = New Array(1);
	WriteParameters[0] = Filter;
	
	RecordKey = New(ValueType, WriteParameters);
	ShowValue(Undefined, RecordKey);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure RunAgain(Command)
	Notify("DeferredUpdate");
	Close();
EndProcedure

&AtClient
Procedure DeferredUpdateHyperlinkClick(Item)
	
	GetUpdateInfo();
	If ValueIsFilled(DeferredUpdateStartTime) Then
		FormParameters = New Structure;
		FormParameters.Insert("StartDate", DeferredUpdateStartTime);
		If ValueIsFilled(DeferredUpdateEndTime) Then
			FormParameters.Insert("EndDate", DeferredUpdateEndTime);
		EndIf;
		FormParameters.Insert("Session", CurrentSessionNumber);
		
		OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	Else
		WarningText = NStr("en = 'Data has not been processed yet.';");
		ShowMessageBox(,WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateProgressHyperlinkClick(Item)
	OpenForm("Report.DeferredUpdateProgress.Form");
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "HighPriority" Then
		TableRowFilter = New Structure;
		TableRowFilter.Insert("Priority", PictureLib.ExclamationPointRed);
		Items.DeferredHandlers.RowFilter = New FixedStructure(TableRowFilter);
	ElsIf Status = "AllProcedures" Then
		Items.DeferredHandlers.RowFilter = New FixedStructure;
	Else
		TableRowFilter = New Structure;
		TableRowFilter.Insert("Status", Status);
		Items.DeferredHandlers.RowFilter = New FixedStructure(TableRowFilter);
	EndIf;
EndProcedure

&AtClient
Procedure SearchStringOnChange(Item)
	DeferredHandlers.Clear();
	GenerateDeferredHandlerTable(, True);
EndProcedure

&AtClient
Procedure Pause(Command)
	CurrentData = Items.DeferredHandlers.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	UpdateProcedure = CurrentData.Id;
	
	QueryText = NStr("en = 'If you stop an additional data processing procedure,
		|the application might malfunction.
		|It is recommended that you only stop a data processing procedure
		|if you find an error in it and only after technical support approval
		|because data processing procedures might depend on each other.';");
	QuestionButtons = New ValueList;
	QuestionButtons.Add("Yes", "Stop");
	QuestionButtons.Add("None", "Cancel");
	
	Notification = New NotifyDescription("PauseDeferredHandler", ThisObject, UpdateProcedure);
	ShowQueryBox(Notification, QueryText, QuestionButtons);
	
EndProcedure

&AtClient
Procedure Run(Command)
	CurrentData = Items.DeferredHandlers.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	UpdateProcedure = CurrentData.Id;
	StartDeferredHandler(UpdateProcedure);
	Notify("DeferredUpdate");
	AttachIdleHandler("UpdateHandlersTable", 1, True);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	UpdateHandlerStatuses(True);
EndProcedure

&AtClient
Procedure OnSchedule(Command)
	
	CurrentRow = Items.DeferredHandlers.CurrentData;
	If CurrentRow = Undefined
		Or Items.OnSchedule.Check Then
		Return;
	EndIf;
	
	ChangePriority("SchedulePriority", CurrentRow.Id, CurrentRow.Queue);
	CurrentRow.PriorityPicture = PictureLib.ExclamationMarkGray;
	CurrentRow.Priority = "Undefined";
	UpdatePriorityCommandStatuses(Items.DeferredHandlers);
	
EndProcedure

&AtClient
Procedure HighPriority(Command)
	CurrentRow = Items.DeferredHandlers.CurrentData;
	If CurrentRow = Undefined
		Or Items.HighPriority.Check Then
		Return;
	EndIf;
	
	ChangePriority("SpeedPriority", CurrentRow.Id, CurrentRow.Queue);
	CurrentRow.PriorityPicture = PictureLib.ExclamationMarkGray;
	CurrentRow.Priority = "Undefined";
	UpdatePriorityCommandStatuses(Items.DeferredHandlers);
	
EndProcedure

&AtClient
Procedure RunSelectedHandler(Command)
	If Items.DeferredHandlers.CurrentData = Undefined
		Or Not FullUser Then
		Return;
	EndIf;
	
	StartSelectedProcedureForDebug(Items.DeferredHandlers.CurrentData.Id);
	
EndProcedure

&AtClient
Procedure CheckPatches(Command)
	Result = AvailableFixesOnServer();
	
	NotifyDescription = New NotifyDescription("CheckAvailableFixesContinued", ThisObject, Result);
	InfobaseUpdateClient.ProcessManualPatchCheckResult(Result, NotifyDescription);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.DeferredHandlersHandlerAddOn.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("DeferredHandlers.HandlerAddOn");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

&AtServer
Procedure StartSelectedProcedureForDebug(HandlerName)
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined;
	UpdateInfo.DeferredUpdatesEndTime = Undefined;
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
	
	RecordSet = InformationRegisters.UpdateHandlers.CreateRecordSet();
	RecordSet.Filter.HandlerName.Set(HandlerName);
	RecordSet.Read();
	
	Handler = RecordSet[0];
	Handler.Status = Enums.UpdateHandlersStatuses.NotPerformed;
	Handler.ExecutionStatistics = New ValueStorage(New Map);
	
	// ACC:1327-off No competitive usage of the register.
	RecordSet.Write();
	// ACC:1327-on
	InfobaseUpdateInternal.ExecuteDeferredUpdateNow(Undefined);
	
EndProcedure

&AtClient
Procedure UpdatePriorityCommandStatuses(Item)
	
	If Item.CurrentData.Priority = "HighPriority" Then
		Items.HighPriority.Check = True;
		Items.HighPriorityContextMenu.Check = True;
		Items.OnSchedule.Check = False;
		Items.NormalPriorityContextMenu.Check = False;
	Else
		Items.OnSchedule.Check = True;
		Items.NormalPriorityContextMenu.Check = True;
		Items.HighPriority.Check = False;
		Items.HighPriorityContextMenu.Check = False;
	EndIf;
	
	If Item.CurrentData.Priority = "Undefined"
		Or Item.CurrentData.Status = PredefinedValue("Enum.UpdateHandlersStatuses.Completed") Then
		Items.OnSchedule.Enabled = False;
		Items.NormalPriorityContextMenu.Enabled = False;
		Items.HighPriority.Enabled = False;
		Items.HighPriorityContextMenu.Enabled = False;
	Else
		Items.OnSchedule.Enabled = True;
		Items.NormalPriorityContextMenu.Enabled = True;
		Items.HighPriority.Enabled = True;
		Items.HighPriorityContextMenu.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure PauseDeferredHandler(Result, UpdateProcedure) Export
	If Result = "None" Then
		Return;
	EndIf;
	
	PauseDeferredHandlerAtServer(UpdateProcedure);
EndProcedure

&AtServer
Procedure PauseDeferredHandlerAtServer(UpdateProcedure)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.IBUpdateInfo");
		Block.Lock();
		
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		If UpdateInfo.DeferredUpdateManagement.Property("StopHandlers")
			And TypeOf(UpdateInfo.DeferredUpdateManagement.StopHandlers) = Type("Array") Then
			StoppedHandlers = UpdateInfo.DeferredUpdateManagement.StopHandlers;
			If StoppedHandlers.Find(UpdateProcedure) = Undefined Then
				StoppedHandlers.Add(UpdateProcedure);
			EndIf;
		Else
			StoppedHandlers = New Array;
			StoppedHandlers.Add(UpdateProcedure);
			UpdateInfo.DeferredUpdateManagement.Insert("StopHandlers", StoppedHandlers);
		EndIf;
		
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure StartDeferredHandler(UpdateProcedure)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.IBUpdateInfo");
		Block.Lock();
		
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		If UpdateInfo.DeferredUpdateManagement.Property("RunHandlers")
			And TypeOf(UpdateInfo.DeferredUpdateManagement.RunHandlers) = Type("Array") Then
			RunningHandlers = UpdateInfo.DeferredUpdateManagement.RunHandlers;
			If RunningHandlers.Find(UpdateProcedure) = Undefined Then
				RunningHandlers.Add(UpdateProcedure);
			EndIf;
		Else
			RunningHandlers = New Array;
			RunningHandlers.Add(UpdateProcedure);
			UpdateInfo.DeferredUpdateManagement.Insert("RunHandlers", RunningHandlers);
		EndIf;
		
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtClient
Procedure UpdateHandlersTable()
	UpdateHandlerStatuses(False);
EndProcedure

&AtClient
Procedure UpdateHandlerStatuses(OnCommand)
	
	AllHandlersExecuted = True;
	GenerateDeferredHandlerTable(AllHandlersExecuted);
	
EndProcedure

&AtServer
Procedure GetUpdateInfo()
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	DeferredUpdateStartTime = UpdateInfo.DeferredUpdateStartTime;
	DeferredUpdateEndTime = UpdateInfo.DeferredUpdatesEndTime;
	CurrentSessionNumber = UpdateInfo.SessionNumber;
EndProcedure

&AtServer
Procedure GenerateDeferredHandlerTable(AllHandlersExecuted = True, InitialFilling = False)
	
	HandlersNotExecuted = True;
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	ChangingPriority = UpdateInfo.DeferredUpdateManagement.Property("SpeedPriority")
		Or UpdateInfo.DeferredUpdateManagement.Property("SchedulePriority");
	UpdateInProgress = (UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined);
	
	Query = New Query;
	Query.SetParameter("ExecutionMode", Enums.HandlersExecutionModes.Deferred);
	Query.Text =
	"SELECT
	|	UpdateHandlers.HandlerName AS HandlerName,
	|	UpdateHandlers.Status AS Status,
	|	UpdateHandlers.Version AS Version,
	|	UpdateHandlers.LibraryName AS LibraryName,
	|	UpdateHandlers.ProcessingDuration AS ProcessingDuration,
	|	UpdateHandlers.ExecutionMode AS ExecutionMode,
	|	UpdateHandlers.RegistrationVersion AS RegistrationVersion,
	|	UpdateHandlers.VersionOrder AS VersionOrder,
	|	UpdateHandlers.Id AS Id,
	|	UpdateHandlers.AttemptCount AS AttemptCount,
	|	UpdateHandlers.ErrorInfo AS ErrorInfo,
	|	UpdateHandlers.Comment AS Comment,
	|	UpdateHandlers.Priority AS Priority,
	|	UpdateHandlers.CheckProcedure AS CheckProcedure,
	|	UpdateHandlers.UpdateDataFillingProcedure AS UpdateDataFillingProcedure,
	|	UpdateHandlers.DeferredProcessingQueue AS DeferredProcessingQueue,
	|	UpdateHandlers.ExecuteInMasterNodeOnly AS ExecuteInMasterNodeOnly,
	|	UpdateHandlers.RunAlsoInSubordinateDIBNodeWithFilters AS RunAlsoInSubordinateDIBNodeWithFilters,
	|	UpdateHandlers.Multithreaded AS Multithreaded,
	|	UpdateHandlers.BatchProcessingCompleted AS BatchProcessingCompleted,
	|	UpdateHandlers.UpdateGroup AS UpdateGroup,
	|	UpdateHandlers.StartIteration AS StartIteration,
	|	UpdateHandlers.DeferredHandlerExecutionMode AS DeferredHandlerExecutionMode,
	|	UpdateHandlers.DataToProcess AS DataToProcess,
	|	UpdateHandlers.ExecutionStatistics AS ExecutionStatistics
	|FROM
	|	InformationRegister.UpdateHandlers AS UpdateHandlers
	|WHERE
	|	UpdateHandlers.ExecutionMode = &ExecutionMode";
	Handlers = Query.Execute().Unload();
	ObsoleteDataCleanupHandlerRow = Undefined;
	For Each Handler In Handlers Do
		If Not UseParallelMode Then
			UseParallelMode = (Handler.DeferredHandlerExecutionMode = Enums.DeferredHandlersExecutionModes.Parallel);
		EndIf;
		
		If Not IsBlankString(SearchString) Then
			If StrFind(Upper(Handler.Comment), Upper(SearchString)) = 0
				And StrFind(Upper(Handler.HandlerName), Upper(SearchString)) = 0 Then
				Continue;
			EndIf;
		EndIf;
		AddDeferredHandler(Handler, HandlersNotExecuted, AllHandlersExecuted,
			InitialFilling, ChangingPriority, ObsoleteDataCleanupHandlerRow);
		
		If Handler.DeferredHandlerExecutionMode <> Enums.DeferredHandlersExecutionModes.Parallel Then
			Continue;
		EndIf;
		
		HandlerInformation = Handler.DataToProcess.Get();
		If HandlerInformation = Undefined Then
			Continue;
		EndIf;
		
		HandlerObjects = New Map;
		TableProcessedData = FormAttributeToValue("DataToProcess");
		ListOfObjects = New ValueList;
		ProcessedObjectsByQueues = HandlerInformation.HandlerData;
		For Each ObjectToProcess In ProcessedObjectsByQueues Do
			ObjectName = ObjectToProcess.Key;
			Queue    = ObjectToProcess.Value.Queue;
			TableRow = TableProcessedData.Add();
			TableRow.Handler = Handler.HandlerName;
			TableRow.ObjectName = ObjectName;
			TableRow.Queue    = Queue;
			
			ListOfObjects.Add(ObjectName);
		EndDo;
		HandlerObjects.Insert(Handler.HandlerName, ListOfObjects);
		
		HandlerObjectsAddress = PutToTempStorage(HandlerObjects, UUID);
		ValueToFormAttribute(TableProcessedData, "DataToProcess");
	EndDo;
	
	If Status = "HighPriority" Then
		TableRowFilter = New Structure;
		TableRowFilter.Insert("Priority", PictureLib.ExclamationPointRed);
		Items.DeferredHandlers.RowFilter = New FixedStructure(TableRowFilter);
	ElsIf Status <> "AllProcedures" Then
		TableRowFilter = New Structure;
		TableRowFilter.Insert("Status", Status);
		Items.DeferredHandlers.RowFilter = New FixedStructure(TableRowFilter);
	EndIf;
	
	If AllHandlersExecuted Or UpdateInProgress Then
		Items.RunAgainGroup.Visible = False;
	EndIf;
	
	If HandlersNotExecuted Then
		Items.ExplanationText.Title = NStr("en = 'It is recommended that you start the data processing procedures that have not been completed.';");
	Else
		Items.ExplanationText.Title = NStr("en = 'It is recommended that you restart the procedures that have not been completed.';");
	EndIf;
	
	If ObsoleteDataCleanupHandlerRow <> Undefined Then
		RowIndex = DeferredHandlers.IndexOf(ObsoleteDataCleanupHandlerRow);
		DeferredHandlers.Move(RowIndex, DeferredHandlers.Count() - 1 - RowIndex);
		ObsoleteDataCleanupHandlerRow.IsObsoleteDataCleanupHandler = True;
		ObsoleteDataCleanupHandlerRow.HandlerAddOn =
			NStr("en = 'View and clear obsolete data manually.';");
	EndIf;
	
	ItemNumber = 1;
	For Each TableRow In DeferredHandlers Do
		TableRow.Number = ItemNumber;
		ItemNumber = ItemNumber + 1;
	EndDo;
	
	Items.UpdateInProgress.Visible = UpdateInProgress;
	
	Items.CheckPatches.Visible = UpdateInfo.DeferredUpdateCompletedSuccessfully <> True
		And InfobaseUpdateInternal.CanCheckForPatchesManually();
	
EndProcedure

&AtServer
Procedure AddDeferredHandler(HandlerRow, HandlersNotExecuted, AllHandlersExecuted,
			InitialFilling, ChangingPriority, ObsoleteDataCleanupHandlerRow)
	
	If InitialFilling Then
		ListLine = DeferredHandlers.Add();
	Else
		FilterParameters = New Structure;
		FilterParameters.Insert("Id", HandlerRow.HandlerName);
		ListLine = DeferredHandlers.FindRows(FilterParameters)[0];
	EndIf;
	If InfobaseUpdateInternal.IsObsoleteDataCleanupHandler(HandlerRow) Then
		ObsoleteDataCleanupHandlerRow = ListLine;
	EndIf;
	
	ExecutionStatistics = HandlerRow.ExecutionStatistics.Get();
	
	DataProcessingStart = ExecutionStatistics["DataProcessingStart"];
	DataProcessingCompletion = ExecutionStatistics["DataProcessingCompletion"];
	ExecutionDuration = ExecutionStatistics["ExecutionDuration"];
	ExecutionProgress = ExecutionStatistics["ExecutionProgress"];
	
	MaximumProductionDurationDays = 0;
	If ValueIsFilled(DataProcessingCompletion) And ValueIsFilled(DataProcessingStart) Then
		MaximumProductionDurationDays = (DataProcessingCompletion - DataProcessingStart) * 1000;
	EndIf;
	
	Progress = Undefined;
	If ExecutionProgress <> Undefined
		And ExecutionProgress.TotalObjectCount <> 0 
		And ExecutionProgress.ProcessedObjectsCount1 <> 0 Then
		Progress = ExecutionProgress.ProcessedObjectsCount1 / ExecutionProgress.TotalObjectCount * 100;
		Progress = Int(Progress);
		Progress = ?(Progress > 100, 99, Progress);
	EndIf;
	
	ListLine.Queue       = HandlerRow.DeferredProcessingQueue;
	ListLine.Id = HandlerRow.HandlerName;
	ListLine.Handler    = ?(ValueIsFilled(HandlerRow.Comment),
		                           HandlerRow.Comment,
		                           DataProcessingProcedure(HandlerRow.HandlerName));
	
	ExecutionPeriodTemplate =
		NStr("en = '%1 -
		           |%2';");
	
	UpdateProcedureInformationTemplate = NStr("en = 'Data processing procedure %1 %2.';");
	
	ListLine.Status = HandlerRow.Status;
	If HandlerRow.Status = Enums.UpdateHandlersStatuses.Completed Then
		
		HandlersNotExecuted = False;
		ExecutionStatusPresentation = NStr("en = 'is completed';");
		ListLine.StatusPresentation = NStr("en = 'Completed';");
		ListLine.ExecutionDuration = UpdateProcedureDuration(ExecutionDuration, MaximumProductionDurationDays);
	ElsIf HandlerRow.Status = Enums.UpdateHandlersStatuses.Running Then
		
		HandlersNotExecuted = False;
		AllHandlersExecuted        = False;
		ExecutionStatusPresentation = NStr("en = 'is running';");
		If Progress <> Undefined Then
			StatusTemplate = NStr("en = 'Running (%1%)';");
			ListLine.StatusPresentation = StringFunctionsClientServer.SubstituteParametersToString(StatusTemplate, Progress)
		Else
			ListLine.StatusPresentation = NStr("en = 'Running';");
		EndIf;
	ElsIf HandlerRow.Status = Enums.UpdateHandlersStatuses.Error Then
		
		HandlersNotExecuted = False;
		AllHandlersExecuted        = False;
		ExecutionStatusPresentation = NStr("en = 'Data processing procedure ""%1"" completed with error:';") + Chars.LF + Chars.LF;
		ExecutionStatusPresentation = StringFunctionsClientServer.SubstituteParametersToString(ExecutionStatusPresentation, HandlerRow.HandlerName);
		ListLine.UpdateProcessInformation = ExecutionStatusPresentation + HandlerRow.ErrorInfo;
		ListLine.StatusPresentation = NStr("en = 'Error';");
		ListLine.ExecutionDuration = UpdateProcedureDuration(ExecutionDuration, MaximumProductionDurationDays);
	ElsIf HandlerRow.Status = Enums.UpdateHandlersStatuses.Paused Then
		
		HandlersNotExecuted = False;
		AllHandlersExecuted        = False;
		ExecutionStatusPresentation = NStr("en = 'is paused by administrator';");
		ListLine.StatusPresentation = NStr("en = 'Paused';");
	Else
		
		AllHandlersExecuted        = False;
		ExecutionStatusPresentation = NStr("en = 'has not started yet';");
		ListLine.StatusPresentation = NStr("en = 'Not started';");
	EndIf;
	
	If Not IsBlankString(HandlerRow.Comment) Then
		Indent = Chars.LF + Chars.LF;
	Else
		Indent = "";
	EndIf;
	
	If ChangingPriority And ListLine.Priority = "Undefined" Then
		// The priority for this string does not change.
	ElsIf HandlerRow.Priority = "HighPriority" Then
		ListLine.PriorityPicture = PictureLib.ExclamationPointRed;
		ListLine.Priority = HandlerRow.Priority;
	Else
		ListLine.PriorityPicture = New Picture;
		ListLine.Priority = "OnSchedule";
	EndIf;
	
	If HandlerRow.Status <> Enums.UpdateHandlersStatuses.Error Then
		ListLine.UpdateProcessInformation = HandlerRow.Comment
			+ Indent
			+ StringFunctionsClientServer.SubstituteParametersToString(
				UpdateProcedureInformationTemplate,
				HandlerRow.HandlerName,
				ExecutionStatusPresentation);
	EndIf;
	
	ListLine.ExecutionInterval = StringFunctionsClientServer.SubstituteParametersToString(
		ExecutionPeriodTemplate,
		String(DataProcessingStart),
		String(DataProcessingCompletion));
	
EndProcedure

&AtServer
Function DataProcessingProcedure(HandlerName)
	HandlerNameArray = StrSplit(HandlerName, ".");
	ArrayItemCount = HandlerNameArray.Count();
	Return HandlerNameArray[ArrayItemCount-1];
EndFunction

&AtServer
Function UpdateProcedureDuration(ExecutionDuration, MaximumProductionDurationDays)
	
	If ExecutionDuration = Undefined Then
		Return "";
	EndIf;
	
	If ValueIsFilled(MaximumProductionDurationDays)
		And ExecutionDuration > MaximumProductionDurationDays Then
		ExecutionDuration = MaximumProductionDurationDays;
	EndIf;
	
	SecondsTemplate = NStr("en = '%1 sec';");
	MinutesTemplate = NStr("en = '%1 min %2 sec';");
	HoursTemplate = NStr("en = '%1 h %2 min';");
	
	DurationInSeconds = ExecutionDuration/1000;
	DurationInSeconds = Round(DurationInSeconds);
	If DurationInSeconds < 1 Then
		Return NStr("en = 'less than a second';")
	ElsIf DurationInSeconds < 60 Then
		Return StringFunctionsClientServer.SubstituteParametersToString(SecondsTemplate, DurationInSeconds);
	ElsIf DurationInSeconds < 3600 Then
		Minutes1 = DurationInSeconds/60;
		Seconds = (Minutes1 - Int(Minutes1))*60;
		Return StringFunctionsClientServer.SubstituteParametersToString(MinutesTemplate, Int(Minutes1), Int(Seconds));
	Else
		Hours1 = DurationInSeconds/60/60;
		Minutes1 = (Hours1 - Int(Hours1))*60;
		Return StringFunctionsClientServer.SubstituteParametersToString(HoursTemplate, Int(Hours1), Int(Minutes1));
	EndIf;
	
EndFunction

&AtServer
Function HandlersToChange(Handler, ProcessedDataTable, Queue, SpeedPriority, ListOfObjects = Undefined)
	
	HandlerObjects1 = GetFromTempStorage(HandlerObjectsAddress);
	If ListOfObjects = Undefined Then
		ListOfObjects = HandlerObjects1[Handler];
		If ListOfObjects = Undefined Then
			Return Undefined;
		EndIf;
	EndIf;
	
	HandlersToChange = New Array;
	HandlersToChange.Add(Handler);
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ttObjectsToProcess.Handler,
		|	ttObjectsToProcess.ObjectName,
		|	ttObjectsToProcess.Queue
		|INTO Table
		|FROM
		|	&ttObjectsToProcess AS ttObjectsToProcess
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.Handler,
		|	Table.ObjectName,
		|	Table.Queue
		|FROM
		|	Table AS Table
		|WHERE
		|	Table.ObjectName IN(&ListOfObjects)
		|	AND Table.Queue < &QueueNumber";
	If Not SpeedPriority Then
		Query.Text = StrReplace(Query.Text, "AND Table.Queue < &QueueNumber", "AND Table.Queue > &QueueNumber");
	EndIf;
	Query.SetParameter("ListOfObjects", ListOfObjects);
	Query.SetParameter("QueueNumber", Queue);
	Query.SetParameter("ttObjectsToProcess", ProcessedDataTable);
	
	Result = Query.Execute().Unload();
	
	CurrentHandler = Undefined;
	For Each String In Result Do
		If CurrentHandler = String.Handler Then
			Continue;
		EndIf;
		
		If String.Queue = 1 Then
			HandlersToChange.Add(String.Handler);
			CurrentHandler = String.Handler;
			Continue;
		EndIf;
		NewObjectList = New ValueList;
		CurrentHandlerObjectList = HandlerObjects1[String.Handler];
		For Each CurrentHandlerObject In CurrentHandlerObjectList Do
			If ListOfObjects.FindByValue(CurrentHandlerObject) = Undefined Then
				NewObjectList.Add(CurrentHandlerObject);
			EndIf;
		EndDo;
		
		If NewObjectList.Count() = 0 Then
			HandlersToChange.Add(String.Handler);
			CurrentHandler = String.Handler;
			Continue;
		EndIf;
		NewArrayOfHandlersToChange = HandlersToChange(String.Handler, // 
			ProcessedDataTable,
			String.Queue,
			SpeedPriority,
			NewObjectList);
		
		For Each ArrayElement In NewArrayOfHandlersToChange Do
			If HandlersToChange.Find(ArrayElement) = Undefined Then
				HandlersToChange.Add(ArrayElement);
			EndIf;
		EndDo;
		
		CurrentHandler = String.Handler;
	EndDo;
	
	Return HandlersToChange;
	
EndFunction

&AtServer
Procedure ChangePriority(Priority, Handler, Queue)
	
	ProcessedDataTable = FormAttributeToValue("DataToProcess");
	If Queue > 1 Then
		HandlersToChange = HandlersToChange(Handler,
			ProcessedDataTable,
			Queue,
			Priority = "SpeedPriority");
		If HandlersToChange = Undefined Then
			HandlersToChange = New Array;
			HandlersToChange.Add(Handler);
		EndIf;
	Else
		HandlersToChange = New Array;
		HandlersToChange.Add(Handler);
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.IBUpdateInfo");
		Block.Lock();
		
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		
		If UpdateInfo.DeferredUpdateManagement.Property(Priority)
			And TypeOf(UpdateInfo.DeferredUpdateManagement[Priority]) = Type("Array") Then
			Collection = UpdateInfo.DeferredUpdateManagement[Priority];
			For Each HandlerToChange In HandlersToChange Do
				If Collection.Find(HandlerToChange) = Undefined Then
					Collection.Add(HandlerToChange);
				EndIf;
			EndDo;
		Else
			UpdateInfo.DeferredUpdateManagement.Insert(Priority, HandlersToChange);
		EndIf;
		
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Function AvailableFixesOnServer()
	Return InfobaseUpdateInternal.PatchesAvailableForInstall();
EndFunction

&AtClient
Procedure CheckAvailableFixesContinued(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Value = DialogReturnCode.No Then
		Return;
	EndIf;
	
	TimeConsumingOperation    = StartingPatchInstallation();
	IdleParameters     = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	CallbackOnCompletion = New NotifyDescription("ProcessManualPatchInstallationResult", InfobaseUpdateClient, AdditionalParameters);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function StartingPatchInstallation()
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Install patches following an update error.';");
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "GetApplicationUpdates.DownloadAndInstallFixes");
	
EndFunction

#EndRegion