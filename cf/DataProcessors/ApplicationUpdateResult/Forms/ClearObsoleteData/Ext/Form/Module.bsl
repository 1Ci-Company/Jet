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
	
	ClearAndClose = Parameters.ClearAndClose;
	Items.DialogCommandPanel.Visible = False;
	
	UpdateVisibilityAvailability(ThisObject, True);
	
	If ClearAndClose Then
		CleanUpDeleteable = False;
		Items.AttentionLabel.Title =
			NStr("en = 'The deferred update is <a href = %1>not completed</a>. We recommend that you complete the update and clear data before the configuration update.';");
		StandardSubsystemsServer.ResetWindowLocationAndSize(ThisObject);
		Items.GroupRemark.Visible = False;
		Items.ShouldProcessDataAreas.Visible = False;
		Items.CommandBarForm.Visible = False;
		If DeferredUpdateCompleted Then
			LongRunningCleaningOperation = StartCleanUpAtServer();
		Else
			LongRunningUpdateOperation = StartUpdateAtServer();
			Items.WarningGroup.Visible = False;
		EndIf;
	Else
		URL = "e1cib/app/DataProcessor.ApplicationUpdateResult.Form.ClearObsoleteData";
		LongRunningUpdateOperation = StartUpdateAtServer();
		Items.ObsoleteDataDataArea.Format = "NZ=0";
	EndIf;
	
	Items.AttentionLabel.Title = StringFunctions.FormattedString(
		Items.AttentionLabel.Title, "OpenUpdateResults");
	
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		UpdateProgressReport = ModuleInfobaseUpdateInternalSaaS.UpdateProgressReport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ClearAndClose
	 Or Not DeferredUpdateCompleted Then
		Refresh(Undefined);
	Else
		Clear(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	CancelLongRunningOperations();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "LoggedOffFromDataArea"
	 Or EventName = "LoggedOnToDataArea" Then
		
		AttachIdleHandler("OnChangeDataArea", 0.1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AttentionLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If FormattedStringURL <> "OpenUpdateResults" Then
		Return;
	EndIf;
	
	If SharedMode And ValueIsFilled(UpdateProgressReport) Then
		OpenForm(UpdateProgressReport);
	Else
		OpenForm("DataProcessor.ApplicationUpdateResult.Form");
	EndIf;
	
EndProcedure

&AtClient
Procedure ShouldProcessDataAreasOnChange(Item)
	
	ObsoleteData.Clear();
	UpdateVisibilityAvailability(ThisObject, True);
	Refresh("");
	
EndProcedure

&AtClient
Procedure DisplayQuantityOnChange(Item)
	
	If DisplayQuantity Then
		ObsoleteData.Clear();
	EndIf;
	
	UpdateVisibilityAvailability(ThisObject);
	Refresh("");
	
EndProcedure

&AtClient
Procedure CleanUpDeleteableOnChange(Item)
	
	ObsoleteData.Clear();
	Refresh("");
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ResumeWithoutCleaning(Command)
	Close(True);
EndProcedure

&AtClient
Procedure CancelConfigurationUpdate(Command)
	Close(False);
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	Items.ShouldProcessDataAreas.Enabled = True;
	Items.DisplayQuantity.Enabled = True;
	Items.CleanUpDeleteable.Enabled = True;
	
	If Command <> Undefined Then
		LongRunningUpdateOperation = StartUpdateAtServer();
	EndIf;
	
	SetProgress(0);
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.ExecutionProgressNotification =
		New NotifyDescription("UpdateOnGettingProgress",
			ThisObject, LongRunningUpdateOperation);
	
	CallbackOnCompletion = New NotifyDescription("RefreshCompletion",
		ThisObject, LongRunningUpdateOperation);
	
	TimeConsumingOperationsClient.WaitCompletion(LongRunningUpdateOperation,
		CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtClient
Procedure Clear(Command)
	
	If DeferredUpdateCompleted Then
		CearAfterConfirmation(New Structure("Value", "Continue"), Command);
		Return;
	EndIf;
	
	CompletionProcessing = New NotifyDescription(
		"CearAfterConfirmation", ThisObject, Command);
	
	QueryText =
		NStr("en = 'The deferred update is not completed.
		           |The cleanup might delete data required to complete the update.
		           |
		           |Create a backup if you have not done it yet.';");
	
	Buttons = New ValueList;
	Buttons.Add("Continue", NStr("en = 'Continue';"));
	Buttons.Add("Cancel",     NStr("en = 'Cancel';"));
	
	AdditionalParameters = StandardSubsystemsClient.QuestionToUserParameters();
	AdditionalParameters.Title = NStr("en = 'Clear obsolete data';");
	AdditionalParameters.PromptDontAskAgain = False;
	AdditionalParameters.DefaultButton = "Cancel";
	
	StandardSubsystemsClient.ShowQuestionToUser(CompletionProcessing,
		QueryText, Buttons, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure CleanUpPlan(Command)
	
	TextDocument = New TextDocument;
	TextDocument.SetText(CleanUpPlanAtServer(CleanUpDeleteable, ShouldProcessDataAreas));
	TextDocument.Show(NStr("en = 'Obsolete data cleanup plan';"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObsoleteDataDataArea.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObsoleteData.DataArea");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = -1;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Shared data';"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateVisibilityAvailability(Form, DoUpdateDeferredUpdateResult = False)

	Items = Form.Items;
	
	If DoUpdateDeferredUpdateResult Then
		Form.DeferredUpdateCompleted = DeferredUpdateCompleted(Form.SharedMode);
	EndIf;
	Items.WarningGroup.Visible = Not Form.DeferredUpdateCompleted;
	
	Items.ShouldProcessDataAreas.Visible = Form.SharedMode;
	Items.ObsoleteDataDataArea.Visible =
		Form.SharedMode And Form.ShouldProcessDataAreas;
	
	Items.ObsoleteDataCount.Visible = Form.DisplayQuantity;
	Items.ObsoleteData.Header =
		    Items.ObsoleteDataCount.Visible
		Or Items.ObsoleteDataDataArea.Visible;
	
	Items.ObsoleteData.HeaderHeight =
		?(Items.ObsoleteDataCount.Visible, 2, 1);
	
	Items.FormClear.Enabled = Form.ObsoleteData.Count() > 0;
	
EndProcedure

&AtServerNoContext
Function DeferredUpdateCompleted(SharedMode)
	
	SharedMode = Not Common.SeparatedDataUsageAvailable();
	
	Return InfobaseUpdateInternal.DeferredUpdateCompleted();
	
EndFunction

&AtClient
Procedure OnChangeDataArea()
	
	Refresh("");
	
EndProcedure

&AtServer
Procedure CancelLongRunningOperations()
	
	If LongRunningUpdateOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(
			LongRunningUpdateOperation.JobID);
		LongRunningUpdateOperation = Undefined;
	EndIf;
	
	If LongRunningCleaningOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(
			LongRunningCleaningOperation.JobID);
		LongRunningCleaningOperation = Undefined;
	EndIf;
	
	If ValueIsFilled(AddressOfUpdateResult) Then
		DeleteFromTempStorage(AddressOfUpdateResult);
		AddressOfUpdateResult = "";
	EndIf;
	
	If ValueIsFilled(AddressOfCleaningResult) Then
		DeleteFromTempStorage(AddressOfCleaningResult);
		AddressOfCleaningResult = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure SetProgress(Percent)
	
	Items.LongRunningOperationPercentage.Title = 
		Format(Percent, "NZ=0") + "%";
	
EndProcedure


&AtServer
Function StartUpdateAtServer()
	
	UpdateVisibilityAvailability(ThisObject, True);
	
	ObsoleteData.Clear();
	
	Items.Pages.CurrentPage = Items.TimeConsumingOperationPage;
	Items.LongRunningOperationText.Title =
		NStr("en = 'Updating the obsolete data list...';");
	
	CancelLongRunningOperations();
	
	AddressOfUpdateResult = PutToTempStorage(Undefined, UUID);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update the obsolete data list';");
	ExecutionParameters.ResultAddress = AddressOfUpdateResult;
	ExecutionParameters.WithDatabaseExtensions = True;
	
	JobParameters = New Structure;
	JobParameters.Insert("DisplayQuantity", DisplayQuantity);
	JobParameters.Insert("CleanUpDeleteable", CleanUpDeleteable);
	JobParameters.Insert("ShouldProcessDataAreas", ShouldProcessDataAreas);
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		"InfobaseUpdateInternal.GenerateObsoleteDataListInBackground",
		JobParameters, ExecutionParameters);
		
	Return Result;
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.LongRunningOperationNewState
//  AdditionalParameters - Undefined
//
&AtClient
Procedure UpdateOnGettingProgress(Result, AdditionalParameters) Export
	
	If AdditionalParameters <> LongRunningUpdateOperation Then
		Return;
	EndIf;
	
	If Result.Progress <> Undefined Then
		SetProgress(Result.Progress.Percent);
	EndIf;
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure RefreshCompletion(Result, AdditionalParameters) Export
	
	If AdditionalParameters <> LongRunningUpdateOperation Then
		Return;
	EndIf;
	
	ErrorInfo = Undefined;
	HasError = False;
	FinishUpdateAtServer(Result, HasError);
	
	If ErrorInfo <> Undefined Then
		StandardSubsystemsClient.OutputErrorInfo(ErrorInfo);
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		ShowMessageBox(, ErrorText);
	EndIf;
	
	If Not ClearAndClose Then
		UpdateVisibilityAvailability(ThisObject);
		Return;
	EndIf;
	
	If HasError Or ObsoleteData.Count() > 0 Then
		UpdateVisibilityAvailability(ThisObject);
		Items.Pages.Visible = False;
		Items.DialogCommandPanel.Visible = True;
		Items.CancelConfigurationUpdate.DefaultButton = True;
		Return;
	EndIf;
	
	Close(True);
	
EndProcedure

&AtServer
Procedure FinishUpdateAtServer(Val Result, HasError)
	
	LongRunningUpdateOperation = Undefined;
	Items.Pages.CurrentPage = Items.PageObsoleteData;
	
	If ValueIsFilled(AddressOfUpdateResult) Then
		Data = GetFromTempStorage(AddressOfUpdateResult);
		DeleteFromTempStorage(AddressOfUpdateResult);
		AddressOfUpdateResult = "";
	Else
		Data = Undefined;
	EndIf;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	ErrorText = "";
	
	If Result.Status = "Error" Then
		ErrorInfo = Result.ErrorInfo;
	ElsIf TypeOf(Data) = Type("ErrorInfo") Then
		ErrorInfo = Data;
	ElsIf Data = Undefined Then
		ErrorText = NStr("en = 'Background job returned nothing.
			|Click ""Refresh"" to try again.';");
	EndIf;
	
	If ErrorInfo <> Undefined Then
		HasError = True;
		Return;
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		HasError = True;
		Return;
	EndIf;
	
	For Each String In Data Do
		FillPropertyValues(ObsoleteData.Add(), String);
	EndDo;
	
EndProcedure


&AtClient
Procedure CearAfterConfirmation(Response, Command) Export
	
	If Not ValueIsFilled(Response)
	 Or Response.Value <> "Continue" Then
		Return;
	EndIf;
	
	If Command <> Undefined Then
		LongRunningCleaningOperation = StartCleanUpAtServer();
	EndIf;
	
	SetProgress(0);
	
	Items.ShouldProcessDataAreas.Enabled = False;
	Items.DisplayQuantity.Enabled = False;
	Items.CleanUpDeleteable.Enabled = False;
	Items.FormClear.Enabled = False;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.ExecutionProgressNotification =
		New NotifyDescription("ClearUpOnGetProgress",
			ThisObject, LongRunningCleaningOperation);
	
	CallbackOnCompletion = New NotifyDescription("ClearCompletion",
		ThisObject, LongRunningCleaningOperation);
	
	TimeConsumingOperationsClient.WaitCompletion(LongRunningCleaningOperation,
		CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function StartCleanUpAtServer()
	
	InfobaseUpdateInternal.CancelObsoleteDataPurgeJob();
	
	Items.Pages.CurrentPage = Items.TimeConsumingOperationPage;
	Items.LongRunningOperationText.Title =
		NStr("en = 'Clearing obsolete data...';");
	
	CancelLongRunningOperations();
	
	AddressOfCleaningResult = PutToTempStorage(Undefined, UUID);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Clear obsolete data';");
	ExecutionParameters.ResultAddress = AddressOfCleaningResult;
	ExecutionParameters.WithDatabaseExtensions = True;
	ExecutionParameters.BackgroundJobKey = InfobaseUpdateInternal.ObsoleteDataPurgeJobKey();
	
	If Common.DataSeparationEnabled() Then
		JobParameters = New Structure;
		JobParameters.Insert("CleanUpDeleteable", CleanUpDeleteable);
		JobParameters.Insert("ShouldProcessDataAreas", ShouldProcessDataAreas);
		
		Result = TimeConsumingOperations.ExecuteInBackground(
			"InfobaseUpdateInternal.PurgeObsoleteDataInBackground",
			JobParameters, ExecutionParameters);
	Else
		ProcedureSettings = New Structure;
		ProcedureSettings.Insert("Context", New Structure("CleanUpDeleteable", CleanUpDeleteable));
		ProcedureSettings.Insert("NameOfBatchAcquisitionMethod",
			"InfobaseUpdateInternal.ObsoleteDataOnRequestChunksInBackground");
		
		Result = TimeConsumingOperations.ExecuteProcedureinMultipleThreads(
			"InfobaseUpdateInternal.ObsoleteDataOnCleaningBatchInBackground",
			ExecutionParameters, ProcedureSettings);
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.LongRunningOperationNewState
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ClearUpOnGetProgress(Result, AdditionalParameters) Export
	
	If AdditionalParameters <> LongRunningCleaningOperation Then
		Return;
	EndIf;
	
	If Result.Progress <> Undefined Then
		SetProgress(Result.Progress.Percent);
	EndIf;
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ClearCompletion(Result, AdditionalParameters) Export
	
	If AdditionalParameters <> LongRunningCleaningOperation Then
		Return;
	EndIf;
	
	ErrorInfo = Undefined;
	HasError = False;
	FinishCleanUpAtServer(Result, HasError);
	
	If ErrorInfo <> Undefined Then
		StandardSubsystemsClient.OutputErrorInfo(ErrorInfo);
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		ShowMessageBox(, ErrorText);
	EndIf;
	
	If HasError Then
		Return;
	EndIf;
	
	If ClearAndClose Then
		Close(True);
	Else
		Refresh("");
	EndIf;
	
EndProcedure

&AtServer
Procedure FinishCleanUpAtServer(Val Result, HasError)
	
	LongRunningCleaningOperation = Undefined;
	Items.Pages.CurrentPage = Items.PageObsoleteData;
	
	If ValueIsFilled(AddressOfCleaningResult) Then
		Results = GetFromTempStorage(AddressOfCleaningResult);
		DeleteFromTempStorage(AddressOfCleaningResult);
		AddressOfCleaningResult = "";
	Else
		Results = Undefined;
	EndIf;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(Results) = Type("ErrorInfo") Then
		ErrorInfo = Results;
		HasError = True;
		Return;
	EndIf;
	
	ErrorText = "";
	
	If Result.Status = "Error" Then
		ErrorInfo = Result.ErrorInfo;
	Else
		ErrorText = InfobaseUpdateInternal.ObsoleteDataPurgeJobErrorText(Results);
	EndIf;
	
	If ErrorInfo <> Undefined Or ValueIsFilled(ErrorText) Then
		HasError = True;
		Return;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CleanUpPlanAtServer(CleanUpDeleteable, ShouldProcessDataAreas)
	
	Return InfobaseUpdateInternal.ObsoleteDataPurgePlan(
		CleanUpDeleteable,, Not ShouldProcessDataAreas);
	
EndFunction

#EndRegion
