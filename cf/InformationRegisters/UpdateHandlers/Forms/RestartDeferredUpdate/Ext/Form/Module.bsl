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
	Title = NStr("en = 'Restart deferred update';");
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HyperlinkSelectionHandlersURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure HyperlinkSelectionHandlersClick(Item)
	CompletionProcessing = New NotifyDescription("AfterSelectHandlers", ThisObject);
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("SelectedHandlers", SelectedHandlers);
	OpenForm("InformationRegister.UpdateHandlers.Form.ChoiceForm", ChoiceParameters,,,,, CompletionProcessing);
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
Procedure Restart(Command)
	Items.FormRestart.Enabled = False;
	
	TimeConsumingOperation = TimeConsumingOperation();
	
	CallbackOnCompletion = New NotifyDescription("ProcessResult", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterSelectHandlers(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	SelectedHandlers.LoadValues(Result);
	
	If SelectedHandlers.Count() = 0 Then
		Items.HyperlinkSelectionHandlers.Title = NStr("en = 'Select handlers';");
	Else
		Items.HyperlinkSelectionHandlers.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Handlers selected: %1';"),
			SelectedHandlers.Count());
	EndIf;
	
EndProcedure

&AtServer
Function TimeConsumingOperation()
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitCompletion = 0;
	
	Result = TimeConsumingOperations.ExecuteProcedure(ExecutionParameters, "InfobaseUpdate.RelaunchDeferredUpdate",
		SelectedHandlers.UnloadValues());
	
	Return Result;
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ProcessResult(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	Notify("DeferredUpdateRestarted");
	Close();
EndProcedure

#EndRegion