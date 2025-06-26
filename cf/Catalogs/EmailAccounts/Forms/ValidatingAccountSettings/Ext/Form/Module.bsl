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
	
	ErrorsMessages = Parameters.ErrorText;
	If ValueIsFilled(ErrorsMessages) Then
		Title = Parameters.Title;
		AutoTitle = False;
		Items.Pages.CurrentPage = Items.ErrorsFoundOnCheck;
		FillinExplanations();
		SetKeyToSaveWindowPosition();
	Else
		Items.Pages.CurrentPage = Items.SettingsCheckInProgress;
		Items.FormClose.Title = NStr("en = 'Cancel';");
		Items.FormGoToSettings.Visible = False;
	EndIf;
	
	Items.FormBack.Visible = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not ValueIsFilled(ErrorsMessages) Then
		AttachIdleHandler("ExecuteSettingsCheck", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToSettings(Command)
	
	GotoMailSettings();
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	Items.Pages.CurrentPage = Items.ErrorsFoundOnCheck;
	Title = Parameters.Title;
	AutoTitle = False;
	Items.FormBack.Visible = False;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NeedHelpClick(Item)
	EmailOperationsClient.GoToEmailAccountInputDocumentation();
EndProcedure

&AtClient
Procedure MethodsToFixErrorURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If CommonClientServer.URIStructure(FormattedStringURL).Schema = "" Then
		StandardProcessing = False;
		PatchID = FormattedStringURL;
		GotoMailSettings();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ExecuteSettingsCheck()
	TimeConsumingOperation = StartExecutionAtServer();
	CallbackOnCompletion = New NotifyDescription("ProcessResult", ThisObject);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
EndProcedure

&AtClient
Procedure RefInformationForTechnicalSupportClick(Item)
	
	If ValueIsFilled(InformationForTechSupport) Then
		Items.Pages.CurrentPage = Items.PageInformationForSupport;
		Items.FormBack.Visible = True;
	Else
		Items.Pages.CurrentPage = Items.SettingsCheckInProgress;
		Title = "";
		AutoTitle = True;
		AttachIdleHandler("ExecuteSettingsCheck", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Function StartExecutionAtServer()
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(UUID);
	Return TimeConsumingOperations.ExecuteFunction(ExecutionParameters, "Catalogs.EmailAccounts.ValidateAccountSettings",
		Parameters.Account);
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
	
	Items.FormClose.Title = NStr("en = 'Close';");
	
	If Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
		Return;
	EndIf;
	
	CheckResult = GetFromTempStorage(Result.ResultAddress);
	
	InformationForTechSupport = CheckResult.ConnectionErrors;
	ExecutedChecks = CheckResult.ExecutedChecks;
	
	If ValueIsFilled(InformationForTechSupport) Then
		If ValueIsFilled(ErrorsMessages) Then
			Items.Pages.CurrentPage = Items.PageInformationForSupport;
			Items.FormBack.Visible = True;
		Else
			ErrorsMessages = StrConcat(CheckResult.ErrorsTexts, Chars.LF);
			FillinExplanations();
			Items.Pages.CurrentPage = Items.ErrorsFoundOnCheck;
		EndIf;
	Else
		Items.Pages.CurrentPage = Items.CheckCompletedSuccessfully;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillinExplanations()
	
	ExplanationOnError = EmailOperationsInternal.ExplanationOnError(ErrorsMessages);
	
	PossibleReasons = EmailOperationsInternal.FormattedList(ExplanationOnError.PossibleReasons);
	MethodsToFixError = EmailOperationsInternal.FormattedList(ExplanationOnError.MethodsToFixError);
	
	Items.DecorationPossibleReasons.Title = PossibleReasons;
	Items.DecorationWaystoEliminate.Title = MethodsToFixError;
	
EndProcedure

&AtServer
Procedure SetKeyToSaveWindowPosition()
	
	WindowOptionsKey = Common.CheckSumString(String(PossibleReasons) + String(MethodsToFixError));
	
EndProcedure

&AtClient
Procedure GotoMailSettings()
	
	If FormOwner <> Undefined And FormOwner.FormName = "Catalog.EmailAccounts.Form.ItemForm" Then
		Close(PatchID);
	Else
		OpeningParameters = New Structure;
		OpeningParameters.Insert("Key", Parameters.Account);
		OpeningParameters.Insert("PatchID", PatchID);
		
		OpenForm("Catalog.EmailAccounts.ObjectForm", OpeningParameters, ThisObject);
	EndIf;
	
EndProcedure

#EndRegion
