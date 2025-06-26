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

// Open the form to send a new text message.
//
// Parameters:
//  RecipientsNumbers - Array of Structure:
//   * Phone - String - Recipient's number in the format: +<CountryCode><LocalCode><Number>.
//   * Presentation - String - Phone number presentation.
//   * ContactInformationSource - CatalogRef - Phone number owner.
//  
//  Text - String - Message text with the max length of 1,000 characters.
//  
//  AdditionalParameters - Structure - additional text message sending parameters:
//   * SenderName - String - Sender's name that recipients will see instead of the phone number.
//   * Transliterate - Boolean - If True, transliterate the outgoing message.
//
Procedure SendSMS(RecipientsNumbers, Text, AdditionalParameters) Export
	
	StandardProcessing = True;
	SendSMSMessageClientOverridable.OnSendSMSMessage(RecipientsNumbers, Text, AdditionalParameters, StandardProcessing);
	If StandardProcessing Then
		
		SendOptions = SendOptions();
		SendOptions.RecipientsNumbers = RecipientsNumbers;
		SendOptions.Text             = Text;
		
		If TypeOf(AdditionalParameters) = Type("Structure") Then
			FillPropertyValues(SendOptions, AdditionalParameters);
		EndIf;
		
		NotifyDescription = New NotifyDescription("CreateNewSMSMessageSettingsCheckCompleted", ThisObject, SendOptions);
		CheckForSMSMessageSendingSettings(NotifyDescription);
		
	EndIf;
	
EndProcedure

// Opens the form for setting up text message sending.
// 
// Parameters:
//  OnCloseNotifyDescription - NotifyDescription - The procedure to be executed after the form is closed.
//
Procedure OpenSettingsForm(OnCloseNotifyDescription = Undefined) Export
	
	OpenForm("CommonForm.OutboundSMSSettings", , , , , , OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

// If the user hasn't configured the SMS gateway, depending on the user rights:
// Open the SMS gateway settings form; Or display a user message saying that the message cannot be sent.
//
// Parameters:
//  ResultHandler - NotifyDescription - a procedure to be executed after the check is completed.
//
Procedure CheckForSMSMessageSendingSettings(ResultHandler)
	
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If ClientRunParameters.CanSendSMSMessage Then
		ExecuteNotifyProcessing(ResultHandler, True);
	Else
		If UsersClient.IsFullUser() Then
			NotifyDescription = New NotifyDescription("AfterSetUpSMSMessage", ThisObject, ResultHandler);
			OpenSettingsForm(NotifyDescription);
		Else
			MessageText = NStr("en = 'SMS settings are not configured.
				|Please contact the administrator.';");
			ShowMessageBox(, MessageText);
		EndIf;
	EndIf;
	
EndProcedure

Procedure AfterSetUpSMSMessage(Result, ResultHandler) Export
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If ClientRunParameters.CanSendSMSMessage Then
		ExecuteNotifyProcessing(ResultHandler, True);
	EndIf;
EndProcedure

// Continues the SendSMS procedure.
Procedure CreateNewSMSMessageSettingsCheckCompleted(SMSMessageSendingIsSetUp, SendOptions) Export
	
	If Not SMSMessageSendingIsSetUp Then
		Return;
	EndIf;
		
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If CommonClient.SubsystemExists("StandardSubsystems.Interactions")
		And ClientRunParameters.UseOtherInteractions Then
		
		ModuleInteractionsClient = CommonClient.CommonModule("InteractionsClient");
		FormParameters = ModuleInteractionsClient.SMSMessageSendingFormParameters();
		FormParameters.SMSMessageRecipients = SendOptions.RecipientsNumbers;
		FillPropertyValues(FormParameters, SendOptions);
		ModuleInteractionsClient.OpenSMSMessageSendingForm(FormParameters);
	Else
		OpenForm("CommonForm.SendSMSMessage", SendOptions);
	EndIf;
	
EndProcedure

// Returns:
//  Structure - Additional text message sending parameters:
//   * SenderName - String - Sender's name that recipients will see instead of the phone number.
//   * Transliterate - Boolean - If True, transliterate the outgoing message.
//   * SubjectOf - AnyRef - Topic the outgoing message is associated with.
//
Function SendOptions()
	
	Result = New Structure;
	Result.Insert("RecipientsNumbers", "");
	Result.Insert("Text", "");
	Result.Insert("SenderName", "");
	Result.Insert("Transliterate", False);
	Result.Insert("SubjectOf", Undefined);
	
	Return Result;
	
EndFunction















#EndRegion