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
	
	If Not ValueIsFilled(Parameters.Account) Or Parameters.Account.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
		
	Account = Parameters.Account;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	EmailProcessingRules.Ref AS Rule,
	|	FALSE AS Apply,
	|	EmailProcessingRules.FilterPresentation,
	|	EmailProcessingRules.PutInFolder
	|FROM
	|	Catalog.EmailProcessingRules AS EmailProcessingRules
	|WHERE
	|	EmailProcessingRules.Owner = &Owner
	|	AND (NOT EmailProcessingRules.DeletionMark)
	|
	|ORDER BY
	|	EmailProcessingRules.AddlOrderingAttribute";
	
	Query.SetParameter("Owner", Parameters.Account);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		EmailRules.Load(Result.Unload());
	EndIf;
	
	If ValueIsFilled(Parameters.ForEmailsInFolder) Then
		ForEmailsInFolder = Parameters.ForEmailsInFolder;
	Else 
		
		Query.Text = "
		|SELECT
		|	EmailMessageFolders.Ref
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|WHERE
		|	EmailMessageFolders.PredefinedFolder
		|	AND EmailMessageFolders.Owner = &Owner
		|	AND EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.IncomingMessages)";
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			Selection = Result.Select();
			Selection.Next();
			ForEmailsInFolder = Selection.Ref;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Apply(Command)
	
	ClearMessages();
	MessageToUserText = "";
	
	AtLeastOneRuleSelected = False;
	Cancel = False;
	
	For Each Rule In EmailRules Do
		
		If Rule.Apply Then
			AtLeastOneRuleSelected = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Not AtLeastOneRuleSelected Then
		CommonClient.MessageToUser(
			NStr("en = 'Select at least one rule to apply';"),,"List");
		Cancel = True;
	EndIf;
	
	If ForEmailsInFolder.IsEmpty() Then
		CommonClient.MessageToUser(
			NStr("en = 'Please select a folder.';"),,"ForEmailsInFolder");
		Cancel = True;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	TimeConsumingOperation = ApplyRulesAtServer();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	CallbackOnCompletion = New NotifyDescription("ApplyRulesCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitCompletion(TimeConsumingOperation, CallbackOnCompletion, IdleParameters);
	
EndProcedure

&AtClient
Procedure ApplyAllRules(Command)
	
	For Each ProcessingRule In EmailRules Do
		ProcessingRule.Apply = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure DontApplyAllRules(Command)
	
	For Each ProcessingRule In EmailRules Do
		ProcessingRule.Apply = False;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ApplyRulesAtServer()
	
	ProcedureParameters = New Structure;
	
	ProcedureParameters.Insert("RulesTable", EmailRules.Unload());
	ProcedureParameters.Insert("ForEmailsInFolder", ForEmailsInFolder);
	ProcedureParameters.Insert("IncludingSubordinates", IncludingSubordinates);
	ProcedureParameters.Insert("Account", Account);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Running mailbox rules';") + " ";
	
	Return TimeConsumingOperations.ExecuteInBackground("Catalogs.EmailProcessingRules.ApplyRules",
		ProcedureParameters, 	ExecutionParameters);
			
EndFunction

// Parameters:
//  Result - See TimeConsumingOperationsClient.NewResultLongOperation
//  AdditionalParameters - Undefined
//
&AtClient
Procedure ApplyRulesCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	ElsIf Result.Status = "Error" Then
		StandardSubsystemsClient.OutputErrorInfo(
			Result.ErrorInfo);
	ElsIf Result.Status = "Completed2" Then
		ImportResult(Result.ResultAddress);
		Notify("MessageProcessingRulesApplied");
		If Not IsBlankString(MessageToUserText) Then
			ShowUserNotification(NStr("en = 'Running mailbox rules';"),,
				MessageToUserText, PictureLib.DialogInformation);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportResult(ResultAddress)
	
	Result = GetFromTempStorage(ResultAddress);
	If TypeOf(Result) = Type("String")
		And ValueIsFilled(Result) Then
			MessageToUserText = Result;
	EndIf;
	
EndProcedure

#EndRegion
