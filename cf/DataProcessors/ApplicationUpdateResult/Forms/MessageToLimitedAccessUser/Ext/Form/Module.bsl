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
	Items.FormExitApplication.Visible = False;
	
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "RefreshEnabled");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("StartUpdate", 0.1, True);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If Not Exit Then
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExitApplication(Command)
	Exit = True;
	Terminate(False);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure StartUpdate()
	Result = UpdateStartAtServer();
	
	If Result = "LockError" Then
		StartUpdateCompletion(Undefined, Undefined);
		Return;
	ElsIf Result.Status = "Completed2" Then
		StartUpdateCompletion(Result, Undefined);
		Return;
	EndIf;
	
	CallbackOnCompletion = New NotifyDescription("StartUpdateCompletion", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	IdleParameters.OutputProgressBar = False;
	IdleParameters.OutputMessages = False;
	TimeConsumingOperationsClient.WaitCompletion(Result, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtServer
Function UpdateStartAtServer()
	
	Try
		SetPrivilegedMode(True);
		InfobaseUpdateInternal.LockIB(IBLock, False);
		SetPrivilegedMode(False);
	Except
		ErrorInfo = ErrorInfo();
		WriteLogEvent(InfobaseUpdateInternal.EventLogEvent(),
			EventLogLevel.Error,,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		Return "LockError";
	EndTry;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Update infobase in background with restricted rights';");
	
	Result = TimeConsumingOperations.ExecuteFunction(ExecutionParameters,
		"InfobaseUpdateInternal.UpdateUnderRestrictedRights", IBLock);
	
	Return Result;
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure StartUpdateCompletion(Result, AdditionalParameters) Export
	
	UpdateResult = Undefined;
	If Result <> Undefined And Result.Status = "Completed2" Then
		UpdateResult = GetFromTempStorage(Result.ResultAddress);
	EndIf;
	
	UnlockIB();
	
	If UpdateResult = True Then
		Exit = True;
		Terminate(True);
	Else
		CustomizeForm();
		TimeoutCounter = 60;
		ContinueCountdown();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueCountdown()
	TimeoutCounter = TimeoutCounter - 1;
	
	If TimeoutCounter <= 0 Then
		Exit = True;
		Terminate(False);
	Else
		NewTitle = (
			NStr("en = 'End session';")
			+ " ("
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 seconds remaining';"), String(TimeoutCounter))
			+ ")");
			
		Items.FormExitApplication.Title = NewTitle;
		
		AttachIdleHandler("ContinueCountdown", 1, True);
	EndIf;
EndProcedure

&AtServer
Procedure CustomizeForm()
	Items.GroupPages.CurrentPage = Items.PreparationErrorGroup;
	Items.FormExitApplication.Visible = True;
	
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "UpdateError");
EndProcedure

&AtServer
Procedure UnlockIB()
	
	SetPrivilegedMode(True);
	InfobaseUpdateInternal.UnlockIB(IBLock);
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion