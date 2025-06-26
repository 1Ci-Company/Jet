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
Var FormClosing, ShouldCompleteAfterClose, AccumulatedMessages;

&AtClient
Var StandardCloseAlert;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	MessageText = NStr("en = 'Please wait…';");
	If Not IsBlankString(Parameters.MessageText) Then
		MessageText = Parameters.MessageText + Chars.LF + MessageText;
		Items.TimeConsumingOperationNoteTextDecoration.Title = MessageText;
	EndIf;
	
	If Not ValueIsFilled(Parameters.Title) Then
		Items.MessageOperation.ShowTitle = False;
		
	ElsIf Parameters.OpeningModeForWaitDialog = FormWindowOpeningMode.Independent Then
		Title = Parameters.Title;
		Items.MessageOperation.ShowTitle = False;
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		CommandBar.HorizontalAlign = ItemHorizontalLocation.Left;
	Else
		Items.MessageOperation.Title = Parameters.Title;
		Items.MessageOperation.ShowTitle = True;
	EndIf;
	
	If TypeOf(Parameters.ShouldCancelWhenOwnerFormClosed) = Type("Boolean") Then
		ShouldCancelOnClose = Parameters.ShouldCancelWhenOwnerFormClosed;
	Else
		ShouldCancelOnClose = True;
	EndIf;
	
	If ValueIsFilled(Parameters.JobID) Then
		JobID = Parameters.JobID;
	EndIf;
	
	If ValueIsFilled(Parameters.CancelButtonTitle) Then
		Items.FormClose.Title = Parameters.CancelButtonTitle;
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ModuleTimeConsumingOperationsClient = CommonClient.CommonModule("TimeConsumingOperationsClient");
	StandardCloseAlert = OnCloseNotifyDescription <> Undefined
	   And OnCloseNotifyDescription.Module = ModuleTimeConsumingOperationsClient;
	
	If Parameters.OutputIdleWindow Then
		FormClosing = False;
		ShouldCompleteAfterClose = False;
		Status = "Running";
		AccumulatedMessages = New Array;
		
		TimeConsumingOperation = New Structure;
		TimeConsumingOperation.Insert("Status", Status);
		TimeConsumingOperation.Insert("JobID", Parameters.JobID);
		TimeConsumingOperation.Insert("Messages", New FixedArray(New Array));
		TimeConsumingOperation.Insert("ResultAddress", Parameters.ResultAddress);
		TimeConsumingOperation.Insert("AdditionalResultAddress", Parameters.AdditionalResultAddress);
		
		CallbackOnCompletion = New NotifyDescription("OnCompleteTimeConsumingOperation", ThisObject);
		NotificationAboutProgress  = New NotifyDescription("OnGetLongRunningOperationProgress", ThisObject);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(FormOwner);
		IdleParameters.OutputIdleWindow = False;
		IdleParameters.Interval = Parameters.Interval;
		IdleParameters.ExecutionProgressNotification = NotificationAboutProgress;
		IdleParameters.ShouldCancelWhenOwnerFormClosed = ShouldCancelOnClose;
		
		TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Status <> "Running"
	 Or StandardCloseAlert Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_CancelJob", 0.1, True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	FormClosing = True;
	DetachIdleHandler("Attachable_CancelJob");
	
	If Exit Then
		Return;
	EndIf;
	
	If Status <> "Running" Then
		Return;
	EndIf;
	
	If StandardCloseAlert Then
		TimeConsumingOperation = CheckJobAndCancelIfRunning(JobID, ShouldCancelOnClose);
		FinishLongRunningOperationAndCloseForm(TimeConsumingOperation);
	Else
		CancelJobExecution(JobID);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CancelAndClose(Command)
	
	ShouldCancelOnClose = True;
	Close();
	
EndProcedure

#EndRegion

#Region Private

// Parameters:
//  Result - See TimeConsumingOperationsClient.LongRunningOperationNewState
//  AdditionalParameters - Undefined
//
&AtClient
Procedure OnGetLongRunningOperationProgress(Result, AdditionalParameters) Export
	
	If FormClosing Or Not IsOpen() Then
		Return;
	EndIf;
	
	If Parameters.OutputProgressBar
	   And Result.Progress <> Undefined Then
		
		Percent = 0;
		If Result.Progress.Property("Percent", Percent) Then
			Items.DecorationPercent.Visible = True;
			Items.DecorationPercent.Title = String(Percent) + "%";
		EndIf;
		
		Text = "";
		If Result.Progress.Property("Text", Text) Then
			Items.TimeConsumingOperationNoteTextDecoration.Title = TrimAll(Text);
		EndIf;
		
	EndIf;
	
	If Result.Messages = Undefined Then
		Return;
	EndIf;
	
	TimeConsumingOperationsClient.ProcessMessagesToUser(Result.Messages,
		AccumulatedMessages, Parameters.OutputMessages, FormOwner);
	
EndProcedure

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure OnCompleteTimeConsumingOperation(Result, AdditionalParameters) Export
	
	If (FormClosing Or Not IsOpen())
	   And Not ShouldCompleteAfterClose Then
		
		Return;
	EndIf;
	
	FinishLongRunningOperationAndCloseForm(Result);
	
EndProcedure

&AtClient
Procedure FinishLongRunningOperationAndCloseForm(TimeConsumingOperation)
	
	If TimeConsumingOperation = Undefined Then
		Status = "Canceled";
	Else
		Status = TimeConsumingOperation.Status;
	EndIf;
	
	If Status = "Canceled" Then
		If StandardCloseAlert Then
			RunStandardCloseAlert(Undefined);
		Else
			Close(Undefined);
		EndIf;
		Return;
	EndIf;
	
	If Parameters.MustReceiveResult Then
		If Status = "Completed2" Then
			TimeConsumingOperation.Insert("Result", GetFromTempStorage(Parameters.ResultAddress));
		Else
			TimeConsumingOperation.Insert("Result", Undefined);
		EndIf;
	EndIf;
	
	If Status = "Completed2" Then
		
		ShowNotification();
		If ReturnResultToChoiceProcessing() Then
			NotifyChoice(TimeConsumingOperation.Result);
			Return;
		EndIf;
		Result = ExecutionResult(TimeConsumingOperation);
		If StandardCloseAlert Then
			RunStandardCloseAlert(Result);
		Else
			Close(Result);
		EndIf;
		
	ElsIf Status = "Error" Then
		
		Result = ExecutionResult(TimeConsumingOperation);
		If StandardCloseAlert Then
			RunStandardCloseAlert(Result);
		Else
			Close(Result);
		EndIf;
		If ReturnResultToChoiceProcessing() Then
			Raise TimeConsumingOperation.BriefErrorDescription;
		EndIf;
		
	ElsIf Status = "Running"
	        And FormClosing
	        And Not ShouldCancelOnClose
	        And StandardCloseAlert Then
		
		Result = ExecutionResult(TimeConsumingOperation);
		OnCloseNotifyDescription.AdditionalParameters.Result = Result;
		If ShouldCompleteAfterClose <> Undefined Then
			ShouldCompleteAfterClose = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RunStandardCloseAlert(Result)
	
	OnCloseNotifyDescription.AdditionalParameters.Result = Result;
	
	If Not FormClosing Then
		Close();
		
	ElsIf ShouldCompleteAfterClose Then
		ShouldCompleteAfterClose = Undefined;
		ExecuteNotifyProcessing(OnCloseNotifyDescription, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CancelJob()
	
	FormClosing = True;
	
	TimeConsumingOperation = CheckJobAndCancelIfRunning(JobID, ShouldCancelOnClose);
	FinishLongRunningOperationAndCloseForm(TimeConsumingOperation);
	
EndProcedure

&AtClient
Procedure ShowNotification()
	
	If Parameters.UserNotification = Undefined Then
		Return;
	EndIf;
	
	TimeConsumingOperationsClient.ShowNotification(Parameters.UserNotification, FormOwner);
	
EndProcedure

&AtServerNoContext
Function CheckJobAndCancelIfRunning(JobID, ShouldCancelOnClose)
	
	TimeConsumingOperation = TimeConsumingOperations.ActionCompleted(JobID);
	
	If TimeConsumingOperation.Status = "Running" And ShouldCancelOnClose Then
		CancelJobExecution(JobID);
		TimeConsumingOperation.Status = "Canceled";
	EndIf;
	
	Return TimeConsumingOperation;
	
EndFunction

&AtServerNoContext
Procedure CancelJobExecution(JobID)
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
EndProcedure

&AtClient
Function ExecutionResult(TimeConsumingOperation)
	
	Result = TimeConsumingOperationsClient.NewResultLongOperation();
	Result.ResultAddress                = Parameters.ResultAddress;
	Result.AdditionalResultAddress = Parameters.AdditionalResultAddress;
	Result.Status                         = TimeConsumingOperation.Status;
	Result.ErrorInfo             = TimeConsumingOperation.ErrorInfo;
	Result.BriefErrorDescription     = TimeConsumingOperation.BriefErrorDescription;
	Result.DetailErrorDescription   = TimeConsumingOperation.DetailErrorDescription;
	Result.Messages = New FixedArray(
		?(AccumulatedMessages = Undefined, New Array, AccumulatedMessages));
	
	If Parameters.MustReceiveResult Then
		Result.Insert("Result", TimeConsumingOperation.Result);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function ReturnResultToChoiceProcessing()
	
	CallbackOnCompletion = ?(StandardCloseAlert,
		OnCloseNotifyDescription.AdditionalParameters.CallbackOnCompletion,
		OnCloseNotifyDescription);
	
	Return CallbackOnCompletion = Undefined
		And Parameters.MustReceiveResult
		And TypeOf(FormOwner) = Type("ClientApplicationForm");
	
EndFunction

#EndRegion