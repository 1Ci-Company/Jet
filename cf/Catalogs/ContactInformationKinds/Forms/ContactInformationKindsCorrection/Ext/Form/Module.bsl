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
	
	CheckID = Parameters.CheckID;
	SetCurrentPage(ThisObject, "DoQueryBox");
	
	If Common.IsMobileClient() Then 
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ResolveIssue(Command)
	
	TimeConsumingOperation = ResolveIssueInBackground(CheckID);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	CallbackOnCompletion = New NotifyDescription("ResolveIssueInBackgroundCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure SetCurrentPage(Form, PageName)
	
	FormItems = Form.Items;
	If PageName = "TroubleshootingInProgress" Then
		FormItems.TroubleshootingIndicatorGroup.Visible         = True;
		FormItems.TroubleshootingStartIndicatorGroup.Visible   = False;
		FormItems.TroubleshootingSuccessIndicatorGroup.Visible = False;
		FormItems.ResolveIssue.Visible                  = False;
	ElsIf PageName = "FixedSuccessfully" Then
		FormItems.TroubleshootingIndicatorGroup.Visible         = False;
		FormItems.TroubleshootingStartIndicatorGroup.Visible   = False;
		FormItems.TroubleshootingSuccessIndicatorGroup.Visible = True;
		FormItems.ResolveIssue.Visible                  = False;
		FormItems.Close.DefaultButton                    = True;
	Else // "Question"
		FormItems.TroubleshootingIndicatorGroup.Visible         = False;
		FormItems.TroubleshootingStartIndicatorGroup.Visible   = True;
		FormItems.TroubleshootingSuccessIndicatorGroup.Visible = False;
		FormItems.ResolveIssue.Visible                  = True;
	EndIf;
	
EndProcedure

&AtServer
Function ResolveIssueInBackground(CheckID)
	
	If TimeConsumingOperation <> Undefined Then
		TimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	SetCurrentPage(ThisObject, "TroubleshootingInProgress");
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Correction of contact information kinds';");
	
	Return TimeConsumingOperations.ExecuteInBackground("ContactsManagerInternal.CorrectContactInformationKindsInBackground",
		New Structure("CheckID", CheckID), ExecutionParameters);
	
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ResolveIssueInBackgroundCompletion(Result, AdditionalParameters) Export
	
	TimeConsumingOperation = Undefined;
	
	If Result = Undefined Then
		SetCurrentPage(ThisObject, "TroubleshootingInProgress");
		Return;
	ElsIf Result.Status = "Error" Then
		SetCurrentPage(ThisObject, "DoQueryBox");
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	ElsIf Result.Status = "Completed2" Then
		Result = GetFromTempStorage(Result.ResultAddress);
		If TypeOf(Result) = Type("Structure") Then
			Items.TextCorrectionTotals.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Items.TextCorrectionTotals.Title, Result.TotalObjectsCorrected, Result.TotalObjectCount);
		EndIf;
		SetCurrentPage(ThisObject, "FixedSuccessfully");
		
	EndIf;
	
EndProcedure

#EndRegion