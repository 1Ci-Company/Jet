///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Open the standard form for waiting the long-running operation completion or use a custom form
// with an attached handler notifying about the procedure progress and completion.
// 
//  For a better UI responsiveness, use it with TimeConsumingOperations.ExecuteInBackground,
// which replaces long server calls with a background job.
// 
// Parameters:
//  TimeConsumingOperation     - See TimeConsumingOperations.ExecuteInBackground
//  CallbackOnCompletion  - NotifyDescription - Notification that is called upon the completion of a long-running operation
//                           (including cases when the idle dialog is closed).
//                           Notification handler parameters: 
//   * Result - See NewResultLongOperation
//               - Undefined - In case the job is canceled.
//   * AdditionalParameters - Arbitrary data passed in the notification. 
//  IdleParameters      - See TimeConsumingOperationsClient.IdleParameters
//
Procedure WaitCompletion(Val TimeConsumingOperation, Val CallbackOnCompletion = Undefined, 
	Val IdleParameters = Undefined) Export
	
	CheckParametersWaitForCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
	AdvancedOptions_ = IdleParameters(Undefined);
	If IdleParameters <> Undefined Then
		FillPropertyValues(AdvancedOptions_, IdleParameters);
	EndIf;
	If TimeConsumingOperation.Property("ResultAddress") Then
		AdvancedOptions_.Insert("ResultAddress", TimeConsumingOperation.ResultAddress);
	EndIf;
	If TimeConsumingOperation.Property("AdditionalResultAddress") Then
		AdvancedOptions_.Insert("AdditionalResultAddress", TimeConsumingOperation.AdditionalResultAddress);
	EndIf;
	AdvancedOptions_.Insert("JobID", TimeConsumingOperation.JobID);
	
	If TimeConsumingOperation.Status <> "Running" Then
		AdvancedOptions_.Insert("AccumulatedMessages", New Array);
		AdvancedOptions_.Insert("CallbackOnCompletion", CallbackOnCompletion);
		If AdvancedOptions_.OutputIdleWindow Then
			ProcessMessagesToUser(TimeConsumingOperation.Messages,
				AdvancedOptions_.AccumulatedMessages,
				AdvancedOptions_.OutputMessages,
				AdvancedOptions_.OwnerForm);
			FinishLongRunningOperation(AdvancedOptions_, TimeConsumingOperation);
		Else
			Operation = New Structure(New FixedStructure(TimeConsumingOperation));
			Operation.Insert("Progress");
			Operation.Insert("IsBackgroundJobCompleted");
			ProcessActiveOperationResult(AdvancedOptions_, Operation);
		EndIf;
		Return;
	EndIf;
	
	If AdvancedOptions_.OutputIdleWindow Then
		AdvancedOptions_.Delete("OwnerForm");
		
		Context = New Structure;
		Context.Insert("Result");
		Context.Insert("JobID", AdvancedOptions_.JobID);
		Context.Insert("CallbackOnCompletion", CallbackOnCompletion);
		ClosingNotification1 = New NotifyDescription("OnFormClosureLongRunningOperation",
			ThisObject, Context);
		
		OpenForm("CommonForm.TimeConsumingOperation", AdvancedOptions_, 
			?(IdleParameters <> Undefined, IdleParameters.OwnerForm, Undefined),
			,,,ClosingNotification1, AdvancedOptions_.OpeningModeForWaitDialog);
	Else
		AdvancedOptions_.Insert("AccumulatedMessages", New Array);
		AdvancedOptions_.Insert("CallbackOnCompletion", CallbackOnCompletion);
		AdvancedOptions_.Insert("CurrentInterval", ?(AdvancedOptions_.Interval <> 0, AdvancedOptions_.Interval, 1));
		AdvancedOptions_.Insert("Control", CurrentDate() + AdvancedOptions_.CurrentInterval); // ACC:143 - Session date is not used in interval checks
		AdvancedOptions_.Insert("LastProgressSendTime", 0);
		
		Operations = TimeConsumingOperationsInProgress();
		Operations.List.Insert(AdvancedOptions_.JobID, AdvancedOptions_);
		ServerNotificationsClient.AttachServerNotificationReceiptCheckHandler();
	EndIf;
	
EndProcedure

// Returns a blank structure for the IdleParameters parameter of TimeConsumingOperationsClient.WaitForCompletion procedure.
//
// Parameters:
//  OwnerForm - ClientApplicationForm
//                - Undefined - the form used to call the long-running operation.
//
// Returns:
//  Structure              - Job runtime parameters: 
//   * OwnerForm          - ClientApplicationForm
//                            - Undefined - the form used to call the long-running operation.
//   * Title              - String - Title displayed on the wait form. If empty, the title is hidden. 
//   * MessageText         - String - the message text that is displayed in the idle form.
//                                       The default value is "Please wait…".
//   * OutputIdleWindow   - Boolean - If True, open the idle window with visual indication of a long-running operation. 
//                                       Set the value to False if you use your own indication engine.
//   * OpeningModeForWaitDialog - FormWindowOpeningMode - The idle form's "WindowOpenMode" parameter.
//                               - Undefined - Default value.
//   * OutputProgressBar - Boolean - show execution progress as percentage in the idle form.
//                                      The handler procedure of a long-running operation can report the progress of its execution
//                                      by calling the TimeConsumingOperations.ReportProgress procedure.
//   * OutputMessages          - Boolean - Flag indicating whether to output messages generated in long-running operation handler
//                                       from the wait form to the message's OwnerForm.
//   * CancelButtonTitle  - String - Title of the "Cancel" button. If not specified, "Canceled".
//   * ExecutionProgressNotification - NotifyDescription - The notification called repeatedly to check if the background job is completed. 
//                                      Applies if "OutputIdleWindow" is set to "False".
//                                      The parameters of the event handler are::
//      ** Result - See LongRunningOperationNewState
//      ** AdditionalParameters - Arbitrary - arbitrary data that was passed in the notification details. 
//
//   * Interval               - Number  - Interval between long-running operation completion checks, in seconds.
//                                       The default value is 0. After each check, the value increases from 1 to 15 seconds
//                                       with increment 1.4.
//   * UserNotification - Structure:
//     ** Show            - Boolean - show user notification upon completion of the long-running operation if True.
//     ** Text               - String - the user notification text.
//     ** URL - String - the user notification URL.
//     ** Explanation           - String - the user notification note.
//     ** Picture            - Picture - Picture to show in the notification dialog.
//                                         If Undefined, don't show the picture.
//     ** Important              - Boolean - If True, after being closed automatically, add the notification to the notification center.
//                                       
//   
//   * ShouldCancelWhenOwnerFormClosed - Boolean - By default, OwnerForm.IsOpen(). False if no form is specified.
//       If False, the long-running operation won't be canceled when the owner form or wait form is closed.
//   
//   * MustReceiveResult - Boolean - For internal use only.
//
Function IdleParameters(OwnerForm) Export
	
	Result = New Structure;
	Result.Insert("OwnerForm", OwnerForm);
	Result.Insert("MessageText", "");
	Result.Insert("Title", ""); 
	Result.Insert("AttemptNumber", 1);
	Result.Insert("OutputIdleWindow", True);
	Result.Insert("OpeningModeForWaitDialog", Undefined);
	Result.Insert("OutputProgressBar", False);
	Result.Insert("ExecutionProgressNotification", Undefined);
	Result.Insert("OutputMessages", False);
	Result.Insert("CancelButtonTitle", "");
	Result.Insert("Interval", 0);
	Result.Insert("MustReceiveResult", False);
	Result.Insert("ShouldCancelWhenOwnerFormClosed",
		TypeOf(OwnerForm) = Type("ClientApplicationForm") And OwnerForm.IsOpen());
	
	UserNotification = New Structure;
	UserNotification.Insert("Show", False);
	UserNotification.Insert("Text", Undefined);
	UserNotification.Insert("URL", Undefined);
	UserNotification.Insert("Explanation", Undefined);
	UserNotification.Insert("Picture", Undefined);
	UserNotification.Insert("Important", Undefined);
	Result.Insert("UserNotification", UserNotification);
	
	Return Result;
	
EndFunction

// Returns the result of the notification specified in the "CompletionNotification2" parameter 
// of "TimeConsumingOperationsClient.WaitForCompletion".
//
// Returns:
//  Undefined - Passed in the result of "NotificationOfCompletion" if the user canceled the job.
//  Structure:
//   * Status - String - "Completed " if the job has completed.
//                       "Error" if the job has completed with error.
//
//   * ResultAddress  - String - Address of the temporary storage where the result
//                         of the long-running operation should be (or already is) stored.
//
//   * AdditionalResultAddress - String - If "AdditionalResult" is specified, 
//                         it contains the address of the additional temporary storage
//                         where the procedure's additional result should be (or already is) stored.
//
//   * ErrorInfo - ErrorInfo - If Status = "Error".
//                        - Undefined - If Status <> "Error".
//
//   * Messages - FixedArray - Array of MessageToUser objects, 
//                   generated in the long-running operation handler.
//                   The array is empty if in the "TimeConsumingOperationsClient.WaitCompletion" procedure,
//                   the OutputIdleWindow property of "IdleParameters" is set to "False"
//                   and the "ExecutionProgressNotification" property is assigned a value.
//                   
//
//   * JobID - UUID - Background job id (if it was started).
//                          - Undefined - If the job wasn't started (foreground execution).
//
//   * BriefErrorDescription   - String - Obsolete.
//   * DetailErrorDescription - String - Obsolete.
//
Function NewResultLongOperation() Export
	
	Result = New Structure;
	Result.Insert("Status", "");
	Result.Insert("ResultAddress", "");
	Result.Insert("AdditionalResultAddress", "");
	Result.Insert("ErrorInfo", Undefined);
	Result.Insert("Messages", New FixedArray(New Array));
	Result.Insert("JobID", Undefined);
	Result.Insert("BriefErrorDescription", "");
	Result.Insert("DetailErrorDescription", "");
	
	Return Result;
	
EndFunction

// Returns an empty structure to be passed as the result of the notification
// specified in the property "LongRunningOperationNewState" of the parameter "IdleParameters"
// in the procedure "TimeConsumingOperationsClient.WaitCompletion".
//
// Returns:
//  Structure:
//   * Status - String - "Running" if the job is running.
//                       "Completed " if the job is completed.
//                       "Error" if the job is completed with error.
//
//   * Progress   - See TimeConsumingOperations.ReadProgress
//   * Messages  - Undefined - No messages
//                - FixedArray - An array of "UserMessage" objects. 
//                    A batch of messages sent from the long-running operation.
//
//   * JobID - UUID - Background job id (if it was started).
//                          - Undefined - If the job wasn't started (foreground execution).
//
Function LongRunningOperationNewState() Export
	
	Result = New Structure;
	Result.Insert("Status", "");
	Result.Insert("Progress", Undefined);
	Result.Insert("Messages", Undefined);
	Result.Insert("JobID", Undefined);
	
	Return Result;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Fills the parameter structure with default values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - the structure to be filled with default values. 
//
// 
Procedure InitIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters = New Structure;
	IdleHandlerParameters.Insert("MinInterval", 1);
	IdleHandlerParameters.Insert("MaxInterval", 15);
	IdleHandlerParameters.Insert("CurrentInterval", 1);
	IdleHandlerParameters.Insert("IntervalIncreaseCoefficient", 1.4);
	
EndProcedure

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Fills the parameter structure with new calculated values.
// 
// Parameters:
//  IdleHandlerParameters - Structure - the structure to be filled with calculated values. 
//
// 
Procedure UpdateIdleHandlerParameters(IdleHandlerParameters) Export
	
	IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.CurrentInterval * IdleHandlerParameters.IntervalIncreaseCoefficient;
	If IdleHandlerParameters.CurrentInterval > IdleHandlerParameters.MaxInterval Then
		IdleHandlerParameters.CurrentInterval = IdleHandlerParameters.MaxInterval;
	EndIf;
		
EndProcedure

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Opens the long-running operation progress form.
// 
// Parameters:
//  FormOwner        - ClientApplicationForm - the form used to open the long-running operation progress form. 
//  JobID - UUID - a background job ID.
//
// Returns:
//  ClientApplicationForm     - the reference to the opened form.
// 
Function OpenTimeConsumingOperationForm(Val FormOwner, Val JobID) Export
	
	Return OpenForm("CommonForm.TimeConsumingOperation",
		New Structure("JobID", JobID), 
		FormOwner);
	
EndFunction

// Deprecated. Instead, use WaitForCompletion with the IdleParameters.OutputIdleWindow = True parameter.
// Closes the long-running operation progress form.
// 
// Parameters:
//  TimeConsumingOperationForm - ClientApplicationForm - the reference to the long-running operation indication form. 
//
Procedure CloseTimeConsumingOperationForm(TimeConsumingOperationForm) Export
	
	If TypeOf(TimeConsumingOperationForm) = Type("ClientApplicationForm") Then
		If TimeConsumingOperationForm.IsOpen() Then
			TimeConsumingOperationForm.Close();
		EndIf;
	EndIf;
	TimeConsumingOperationForm = Undefined;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// Parameters:
//  Parameters - 
//  AreChatsActive - Boolean - Flag indicating whether the Business interactions subsystem delivers messages.
//  Interval - Number - Timeout in seconds before the next check.
//
Procedure BeforeRecurringClientDataSendToServer(Parameters, AreChatsActive, Interval) Export
	
	Result = LongRunningOperationCheckParameters(AreChatsActive, Interval);
	If Result = Undefined Then
		Return;
	EndIf;
	
	Parameters.Insert("StandardSubsystems.Core.LongRunningOperationCheckParameters", Result)
	
EndProcedure

// Parameters:
//  Results - See CommonOverridable.OnReceiptRecurringClientDataOnServer.Results
//  AreChatsActive - Boolean - Flag indicating whether the Business interactions subsystem delivers messages.
//  Interval - Number - Timeout in seconds before the next check.
//
Procedure AfterRecurringReceiptOfClientDataOnServer(Results, AreChatsActive, Interval) Export
	
	OperationsResult = Results.Get( // See TimeConsumingOperations.LongRunningOperationCheckResult
		"StandardSubsystems.Core.LongRunningOperationCheckResult");
	
	If OperationsResult = Undefined Then
		Return;
	EndIf;
	
	CurrentLongRunningOperations = TimeConsumingOperationsInProgress();
	TimeConsumingOperationsInProgress = CurrentLongRunningOperations.List;
	ActionsUnderControl     = CurrentLongRunningOperations.ActionsUnderControl;
	
	For Each OperationResult In OperationsResult Do
		Operation = ActionsUnderControl[OperationResult.Key];
		Result = OperationResult.Value; // Structure
		Result.Insert("IsBackgroundJobCompleted");
		Result.Insert("LongRunningOperationsControlWithoutInteractionSystem");
		ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result);
	EndDo;
	
	CurrentLongRunningOperations.ActionsUnderControl = New Map;

	If TimeConsumingOperationsInProgress.Count() = 0 Then
		Return;
	EndIf;
	
	ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive);
	
EndProcedure

// Parameters:
//  Result - Undefined
//  Context - Structure:
//   * Result - Structure
//               - Undefined
//   * JobID  - UUID
//                           - Undefined
//   * CallbackOnCompletion - NotifyDescription
//                           - Undefined
//
Procedure OnFormClosureLongRunningOperation(Result, Context) Export
	
	If Context.CallbackOnCompletion = Undefined
	 Or Context.Result <> Undefined
	   And Context.Result.Status = "Running" Then
		
		Return;
	EndIf;
	
	NotifyOfLongRunningOperationEnd(Context.CallbackOnCompletion,
		Context.Result, Context.JobID);
	
EndProcedure

// Parameters:
//  AreChatsActive - Boolean - Flag indicating whether the Business interactions subsystem delivers messages.
//  Interval - Number - Timeout in seconds before the next check.
//
// Returns:
//  Undefined - Check is not required.
//  Structure:
//   * JobsToCheck - Array of UUID
//   * JobsToCancel - Array of UUID
//
Function LongRunningOperationCheckParameters(AreChatsActive, Interval)
	
	CurrentDate = CurrentDate(); // ACC:143 - Session date is not used in interval checks
	
	ActionsUnderControl = New Map;
	JobsToCheck = New Array;
	JobsToCancel = New Array;
	
	CurrentLongRunningOperations = TimeConsumingOperationsInProgress();
	TimeConsumingOperationsInProgress = CurrentLongRunningOperations.List;
	CurrentLongRunningOperations.ActionsUnderControl = ActionsUnderControl;
	
	If Not ValueIsFilled(TimeConsumingOperationsInProgress) Then
		Return Undefined;
	EndIf;
	
	For Each TimeConsumingOperation In TimeConsumingOperationsInProgress Do
		
		TimeConsumingOperation = TimeConsumingOperation.Value;
		
		If IsLongRunningOperationCanceled(TimeConsumingOperation) Then
			ActionsUnderControl.Insert(TimeConsumingOperation.JobID, TimeConsumingOperation);
			JobsToCancel.Add(TimeConsumingOperation.JobID);
		Else
			ChatsControlInterval = ChatsControlInterval();
			DateOfControl = TimeConsumingOperation.Control
				+ ?(Not AreChatsActive Or TimeConsumingOperation.CurrentInterval > ChatsControlInterval,
					0, ChatsControlInterval - TimeConsumingOperation.CurrentInterval);
			
			If DateOfControl <= CurrentDate Then
				ActionsUnderControl.Insert(TimeConsumingOperation.JobID, TimeConsumingOperation);
				JobsToCheck.Add(TimeConsumingOperation.JobID);
			EndIf;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(JobsToCheck)
	   And Not ValueIsFilled(JobsToCancel) Then
		
		ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive);
		Return Undefined;
	EndIf;
	
	Result = New Structure;
	Result.Insert("JobsToCheck", JobsToCheck);
	Result.Insert("JobsToCancel",   JobsToCancel);
	
	Return Result;
	
EndFunction

Function IsLongRunningOperationCanceled(TimeConsumingOperation)
	
	Return TimeConsumingOperation.ShouldCancelWhenOwnerFormClosed
	    And TimeConsumingOperation.OwnerForm <> Undefined
		And Not TimeConsumingOperation.OwnerForm.IsOpen();
	
EndFunction

Procedure ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result)
	
	If TimeConsumingOperationsInProgress.Get(Operation.JobID) = Undefined Then
		Return;
	EndIf;
	
	Try
		If ProcessActiveOperationResult(Operation, Result) Then
			TimeConsumingOperationsInProgress.Delete(Operation.JobID);
		EndIf;
	Except
		// Do not track anymore.
		TimeConsumingOperationsInProgress.Delete(Operation.JobID);
		Raise;
	EndTry;
	
EndProcedure

Procedure ReviseIdleHandlerInterval(Interval, TimeConsumingOperationsInProgress, AreChatsActive)
	
	CurrentDate = CurrentDate(); // ACC:143 - Session date is not used in interval checks
	NewInterval = 120; 
	For Each Operation In TimeConsumingOperationsInProgress Do
		NewInterval = Max(Min(NewInterval, Operation.Value.Control - CurrentDate), 1);
	EndDo;
	
	ChatsControlInterval = ChatsControlInterval();
	If AreChatsActive And NewInterval < ChatsControlInterval Then
		NewInterval = ChatsControlInterval;
	EndIf;
	
	If Interval > NewInterval Then
		Interval = NewInterval;
	EndIf;
	
EndProcedure

// Returns:
//  Number - Time in seconds when a long-running operation is controlled
//          by the server call when chats are active but new messages weren't sent.
//          For example, if the operation is running longer than the specified time or
//          when the background job crashed and the message wasn't sent via Business interactions.
//          
//          
//
Function ChatsControlInterval()
	
	Return 30;
	
EndFunction

// See StandardSubsystemsClient.OnReceiptServerNotification
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	TimeConsumingOperationsInProgress = TimeConsumingOperationsInProgress().List;
	Operation = TimeConsumingOperationsInProgress.Get(Result.JobID);
	If Operation = Undefined
	 Or IsLongRunningOperationCanceled(Operation) Then
		Return;
	EndIf;
	
	If Result.NotificationKind = "Progress" Then
		If Operation.LastProgressSendTime < Result.TimeSentOn Then
			Operation.LastProgressSendTime = Result.TimeSentOn;
		Else
			Return; // Skip the obsolete progress message.
		EndIf;
	EndIf;
	
	ProcessOperationResult(TimeConsumingOperationsInProgress, Operation, Result.Result);
	
EndProcedure

// Parameters:
//  AdvancedOptions_ - Structure:
//   * OwnerForm          - ClientApplicationForm
//                            - Undefined
//   * Title              - String
//   * MessageText         - String
//   * OutputIdleWindow   - Boolean
//   * OutputProgressBar - Boolean
//   * ExecutionProgressNotification - NotifyDescription
//                                    - Undefined
//   * OutputMessages      - Boolean
//   * Interval               - Number
//   * UserNotification - Structure:
//     ** Show            - Boolean
//     ** Text               - String
//     ** URL - String
//     ** Explanation           - String
//     ** Picture            - Picture
//     ** Important              - Boolean
//    
//   * ShouldCancelWhenOwnerFormClosed - Boolean
//   * MustReceiveResult
//   
//   * JobID  - UUID
//   * AccumulatedMessages  - Array
//   * CallbackOnCompletion - NotifyDescription
//                           - Undefined
//   * CurrentInterval       - Number
//   * Control              - Date
//    
//   * LastProgressSendTime - Number - Universal date in milliseconds
//
//  TimeConsumingOperation - See TimeConsumingOperations.OperationNewRuntimeResult
//
Function ProcessActiveOperationResult(AdvancedOptions_, TimeConsumingOperation)
	
	If TimeConsumingOperation.Status <> "Canceled" Then
		If AdvancedOptions_.ExecutionProgressNotification <> Undefined Then
			State = LongRunningOperationNewState();
			State.Status    = TimeConsumingOperation.Status;
			State.Progress  = TimeConsumingOperation.Progress;
			State.Messages = TimeConsumingOperation.Messages;
			State.JobID = AdvancedOptions_.JobID;
			Try
				ExecuteNotifyProcessing(AdvancedOptions_.ExecutionProgressNotification, State);
			Except
				ErrorInfo = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'An error occurred when calling a notification about the progress of
					           |the ""%1"" long-running operation:
					           |%2';"),
					String(AdvancedOptions_.JobID),
					ErrorProcessing.DetailErrorDescription(ErrorInfo));
				EventLogClient.AddMessageForEventLog(
					NStr("en = 'Long-running operations.Error calling the event handler';",
						CommonClient.DefaultLanguageCode()),
					"Error",
					ErrorText);
			EndTry;
		ElsIf TimeConsumingOperation.Messages <> Undefined Then
			For Each Message In TimeConsumingOperation.Messages Do
				AdvancedOptions_.AccumulatedMessages.Add(Message);
			EndDo;
		EndIf;
	EndIf;
	
	If TimeConsumingOperation.Status <> "Running" Then
		If TimeConsumingOperation.Status <> "Completed2"
		 Or TimeConsumingOperation.Property("IsBackgroundJobCompleted")
		 Or Not (  AdvancedOptions_.Property("ResultAddress")
		         And ValueIsFilled(AdvancedOptions_.ResultAddress)
		       Or AdvancedOptions_.Property("AdditionalResultAddress")
		         And ValueIsFilled(AdvancedOptions_.AdditionalResultAddress))
		 // The check is required as the notification is sent before the background job is over,
		 // and the outcome data cannot be accessed by address in the temp storage.
		 Or TimeConsumingOperationsServerCall.IsBackgroundJobCompleted(AdvancedOptions_.JobID) Then
		 
			FinishLongRunningOperation(AdvancedOptions_, TimeConsumingOperation);
			Return True;
		EndIf;
	EndIf;
	
	IdleInterval = AdvancedOptions_.CurrentInterval;
	If AdvancedOptions_.Interval = 0
	   And TimeConsumingOperation.Property("LongRunningOperationsControlWithoutInteractionSystem") Then
		IdleInterval = IdleInterval * 1.4;
		If IdleInterval > 15 Then
			IdleInterval = 15;
		EndIf;
		AdvancedOptions_.CurrentInterval = IdleInterval;
	EndIf;
	AdvancedOptions_.Control = CurrentDate() + IdleInterval; // ACC:143 - Session date is not used in interval checks
	Return False;
	
EndFunction

Procedure ProcessMessagesToUser(Messages, AccumulatedMessages, OutputMessages, FormOwner) Export
	
	TargetID = ?(OutputMessages And FormOwner <> Undefined,
		FormOwner.UUID, Undefined);
	
	For Each UserMessage In Messages Do
		AccumulatedMessages.Add(UserMessage);
		If TargetID <> Undefined Then
			NewMessage = New UserMessage;
			FillPropertyValues(NewMessage, UserMessage);
			NewMessage.TargetID = TargetID;
			NewMessage.Message();
		EndIf;
	EndDo;
	
EndProcedure

Procedure FinishLongRunningOperation(AdvancedOptions_, TimeConsumingOperation)
	
	If TimeConsumingOperation.Status = "Completed2" Then
		ShowNotification(AdvancedOptions_.UserNotification);
	EndIf;
	
	If AdvancedOptions_.CallbackOnCompletion = Undefined Then
		Return;
	EndIf;
	
	If TimeConsumingOperation.Status = "Canceled" Then
		Result = Undefined;
	Else
		Result = NewResultLongOperation();
		Result.Status = TimeConsumingOperation.Status;
		If AdvancedOptions_.Property("ResultAddress") Then
			Result.ResultAddress = AdvancedOptions_.ResultAddress;
		EndIf;
		If AdvancedOptions_.Property("AdditionalResultAddress") Then
			Result.AdditionalResultAddress = AdvancedOptions_.AdditionalResultAddress;
		EndIf;
		Result.Insert("ErrorInfo",           TimeConsumingOperation.ErrorInfo);
		Result.Insert("BriefErrorDescription",   TimeConsumingOperation.BriefErrorDescription);
		Result.Insert("DetailErrorDescription", TimeConsumingOperation.DetailErrorDescription);
		Result.Insert("Messages", New FixedArray(AdvancedOptions_.AccumulatedMessages));
		Result.JobID = AdvancedOptions_.JobID;
	EndIf;
	
	NotifyOfLongRunningOperationEnd(AdvancedOptions_.CallbackOnCompletion,
		Result, AdvancedOptions_.JobID);
	
EndProcedure

Procedure NotifyOfLongRunningOperationEnd(CallbackOnCompletion, Result, JobID)
	
	Try
		ExecuteNotifyProcessing(CallbackOnCompletion, Result);
	Except
		ErrorInfo = ErrorInfo();
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred when calling a notification about the completion of
			           |the ""%1"" long-running operation:
			           |%2';"),
			String(JobID),
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EventLogClient.AddMessageForEventLog(
			NStr("en = 'Long-running operations.Error calling the event handler';",
				CommonClient.DefaultLanguageCode()),
			"Error", ErrorText,, True);
		StandardSubsystemsClient.OutputErrorInfo(ErrorInfo)
	EndTry;
	
EndProcedure

// Returns:
//   Structure:
//    * List - Map of KeyAndValue:
//       ** Key - UUID - a background job ID.
//       ** Value - See ProcessActiveOperationResult.TimeConsumingOperation
//    * ActionsUnderControl - Map of KeyAndValue:
//       ** Key - UUID - a background job ID.
//       ** Value - See ProcessActiveOperationResult.TimeConsumingOperation
//
Function TimeConsumingOperationsInProgress()
	
	ParameterName = "StandardSubsystems.TimeConsumingOperationsInProgress";
	If ApplicationParameters[ParameterName] = Undefined Then
		Operations = New Structure;
		Operations.Insert("List", New Map);
		Operations.Insert("ActionsUnderControl", New Map);
		ApplicationParameters.Insert(ParameterName, Operations);
	EndIf;
	
	Return ApplicationParameters[ParameterName];

EndFunction

Procedure CheckParametersWaitForCompletion(Val TimeConsumingOperation, Val CallbackOnCompletion, Val IdleParameters)
	
	CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
		"TimeConsumingOperation", TimeConsumingOperation, Type("Structure"));
	
	If CallbackOnCompletion <> Undefined Then
		CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
			"CallbackOnCompletion", CallbackOnCompletion, Type("NotifyDescription"));
	EndIf;
	
	If IdleParameters <> Undefined Then
		
		PropertyTypes = New Structure;
		If IdleParameters.OwnerForm <> Undefined Then
			PropertyTypes.Insert("OwnerForm", Type("ClientApplicationForm"));
		EndIf;
		PropertyTypes.Insert("MessageText", Type("String"));
		PropertyTypes.Insert("Title",      Type("String"));
		PropertyTypes.Insert("OutputIdleWindow", Type("Boolean"));
		PropertyTypes.Insert("OutputProgressBar", Type("Boolean"));
		PropertyTypes.Insert("OutputMessages", Type("Boolean"));
		PropertyTypes.Insert("Interval", Type("Number"));
		PropertyTypes.Insert("UserNotification", Type("Structure"));
		PropertyTypes.Insert("MustReceiveResult", Type("Boolean"));
		
		CommonClientServer.CheckParameter("TimeConsumingOperationsClient.WaitCompletion",
			"IdleParameters", IdleParameters, Type("Structure"), PropertyTypes);
			
		VerificationMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Parameter %1 must be equal to or greater than 1';"), "IdleParameters.Interval");
		
		CommonClientServer.Validate(IdleParameters.Interval = 0 Or IdleParameters.Interval >= 1,
			VerificationMessage, "TimeConsumingOperationsClient.WaitCompletion");
			
		VerificationMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'If parameter %1 is set to %2, parameter %3 is not supported';"),
			"IdleParameters.OutputIdleWindow",
			"True",
			"IdleParameters.ExecutionProgressNotification");
			
		CommonClientServer.Validate(Not (IdleParameters.ExecutionProgressNotification <> Undefined And IdleParameters.OutputIdleWindow), 
			VerificationMessage, "TimeConsumingOperationsClient.WaitCompletion");
			
	EndIf;

EndProcedure

Procedure ShowNotification(UserNotification, FormOwner = Undefined) Export
	
	Notification = UserNotification;
	If Not Notification.Show Then
		Return;
	EndIf;
	
	NotificationURL = Notification.URL;
	NotificationComment = Notification.Explanation;
	
	If FormOwner <> Undefined And FormOwner.Window <> Undefined Then
		If NotificationURL = Undefined Then
			NotificationURL = FormOwner.Window.GetURL();
		EndIf;
		If NotificationComment = Undefined Then
			NotificationComment = FormOwner.Window.Title;
		EndIf;
	EndIf;
	
	AlertStatus = Undefined;
	If TypeOf(Notification.Important) = Type("Boolean") Then
		AlertStatus = ?(Notification.Important, UserNotificationStatus.Important, UserNotificationStatus.Information);
	EndIf;
	
	ShowUserNotification(?(Notification.Text <> Undefined, Notification.Text, NStr("en = 'Operation completed.';")), 
		NotificationURL, NotificationComment, Notification.Picture, AlertStatus);

EndProcedure

#EndRegion