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
	
	FileInfobase = Common.FileInfobase();
	
	SendEmailsInHTMLFormat = GetFunctionalOption("SendEmailsInHTMLFormat");
	SettingsStorage = Interactions.EmailOperationSettings();
	
	AddSignatureForNewMessages             = ?(SettingsStorage.Property("AddSignatureForNewMessages"),
		SettingsStorage.AddSignatureForNewMessages,True);
	NewMessageSignatureFormat               = ?(SettingsStorage.Property("NewMessageSignatureFormat") And SendEmailsInHTMLFormat,
		SettingsStorage.NewMessageSignatureFormat,
		Enums.EmailEditingMethods.NormalText);
	AddSignatureOnReplyForward            = ?(SettingsStorage.Property("AddSignatureOnReplyForward"),
		SettingsStorage.AddSignatureOnReplyForward,True);
	ReplyForwardSignatureFormat              = ?(SettingsStorage.Property("ReplyForwardSignatureFormat") And SendEmailsInHTMLFormat,
		SettingsStorage.ReplyForwardSignatureFormat,
		Enums.EmailEditingMethods.NormalText);
	ReplyToReadReceiptPolicies = ?(SettingsStorage.Property("ReplyToReadReceiptPolicies"),
		SettingsStorage.ReplyToReadReceiptPolicies,
		Enums.ReplyToReadReceiptPolicies.AskBeforeSendReadReceipt);
	AlwaysRequestReadReceipt       = ?(SettingsStorage.Property("AlwaysRequestReadReceipt"),
		SettingsStorage.AlwaysRequestReadReceipt,False);
	AlwaysRequestDeliveryReceipt        = ?(SettingsStorage.Property("AlwaysRequestDeliveryReceipt"),
		SettingsStorage.AlwaysRequestDeliveryReceipt,False);
	NewMessageFormattedDocument        = ?(SettingsStorage.Property("NewMessageFormattedDocument"),
		SettingsStorage.NewMessageFormattedDocument,Undefined);
	SignatureForNewMessagesPlainText         = ?(SettingsStorage.Property("SignatureForNewMessagesPlainText"),
		SettingsStorage.SignatureForNewMessagesPlainText,Undefined);
	ReplyForwardSignaturePlainText        = ?(SettingsStorage.Property("ReplyForwardSignaturePlainText"),
		SettingsStorage.ReplyForwardSignaturePlainText,Undefined);
	OnReplyForwardFormattedDocument    = ?(SettingsStorage.Property("OnReplyForwardFormattedDocument"),
		SettingsStorage.OnReplyForwardFormattedDocument,Undefined);
	DisplaySourceEmailBody                = ?(SettingsStorage.Property("DisplaySourceEmailBody"),
		SettingsStorage.DisplaySourceEmailBody,False);
	IncludeOriginalEmailBody                  = ?(SettingsStorage.Property("IncludeOriginalEmailBody"),
		SettingsStorage.IncludeOriginalEmailBody,False);
	SendMessagesImmediately                     = ?(SettingsStorage.Property("SendMessagesImmediately"),
		SettingsStorage.SendMessagesImmediately,False) And FileInfobase;
		
	Items.SendMessagesImmediately.Visible = FileInfobase;
	
	Items.SignatureOnReply.Picture = Interactions.SignaturePagesPIcture(AddSignatureOnReplyForward);
	Items.SignatureForNewMessage.Picture = Interactions.SignaturePagesPIcture(AddSignatureForNewMessages);
	AvailabilityControl(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EnableSignatureForNewMessagesOnChange(Item)
	
	AvailabilityControl(ThisObject);
	
EndProcedure

&AtClient
Procedure AddSignatureOnReplyForwardOnChange(Item)
	
	AvailabilityControl(ThisObject);
	
EndProcedure

&AtClient
Procedure NewMessageSignatureFormatOnChange(Item)
	
	If NewMessageSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.HTML") 
			And Items.PagesSignatureForNewMessages.CurrentPage = Items.NewMessageFormattedTextPage Then
		
		Return;
		
	EndIf;
	
	If NewMessageSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.NormalText") 
			And Items.PagesSignatureForNewMessages.CurrentPage = Items.NewMessagePlainTextPage Then
		
		Return;
		
	EndIf;
	
	If NewMessageSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		If Not IsBlankString(SignatureForNewMessagesPlainText) Then
			NewMessageFormattedDocument.Delete();
			NewMessageFormattedDocument.Add(SignatureForNewMessagesPlainText);
		EndIf;
		
		AvailabilityControl(ThisObject);
		
	Else
		
		AdditionalParameters = New Structure("CallContext", "ForNewMessages");
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject, AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReplyForwardSignatureFormatOnChange(Item)
	
	If ReplyForwardSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.HTML") 
			And Items.PagesSignatureOnReplyForward.CurrentPage = Items.PageOnReplyForwardFormattedDocument Then
		
		Return;
		
	EndIf;
	
	If ReplyForwardSignatureFormat =
			PredefinedValue("Enum.EmailEditingMethods.NormalText") 
			And Items.PagesSignatureOnReplyForward.CurrentPage = Items.PageOnReplyForwardPlainText Then
		
		Return;
		
	EndIf;
	
	If ReplyForwardSignatureFormat = PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		If Not IsBlankString(ReplyForwardSignaturePlainText) Then
			OnReplyForwardFormattedDocument.Delete();
			OnReplyForwardFormattedDocument.Add(ReplyForwardSignaturePlainText);
		EndIf;
		
		AvailabilityControl(ThisObject);
		
	Else
		
		AdditionalParameters = New Structure("CallContext", "OnReplyForward");
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject, AdditionalParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ShouldSaveSettings();
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure AvailabilityControl(Form)

	If Form.NewMessageSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		Form.Items.PagesSignatureForNewMessages.CurrentPage = Form.Items.NewMessageFormattedTextPage;
		Form.Items.NewMessageFormattedDocument.Enabled = Form.AddSignatureForNewMessages;
		
	Else
		
		Form.Items.PagesSignatureForNewMessages.CurrentPage = Form.Items.NewMessagePlainTextPage;
		Form.Items.SignatureForNewMessagesPlainText.Enabled = Form.AddSignatureForNewMessages;
		
	EndIf;
	
	If Form.ReplyForwardSignatureFormat = 
			PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		Form.Items.PagesSignatureOnReplyForward.CurrentPage = 
			Form.Items.PageOnReplyForwardFormattedDocument;
		Form.Items.OnReplyForwardFormattedDocument.Enabled  = Form.AddSignatureOnReplyForward;
		
	Else
		
		Form.Items.PagesSignatureOnReplyForward.CurrentPage = Form.Items.PageOnReplyForwardPlainText;
		Form.Items.ReplyForwardSignaturePlainText.Enabled = Form.AddSignatureOnReplyForward;
		
	EndIf;

EndProcedure

&AtServer
Procedure ShouldSaveSettings()
	
	If NewMessageSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		SignatureForNewMessagesPlainText = NewMessageFormattedDocument.GetText();
		
	EndIf;
	
	If ReplyForwardSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		ReplyForwardSignaturePlainText = OnReplyForwardFormattedDocument.GetText();
		
	EndIf;
	
	SettingStructure = New Structure;
	SettingStructure.Insert("AddSignatureForNewMessages", AddSignatureForNewMessages);
	SettingStructure.Insert("AddSignatureOnReplyForward", AddSignatureOnReplyForward);
	SettingStructure.Insert("AlwaysRequestReadReceipt", AlwaysRequestReadReceipt);
	SettingStructure.Insert("AlwaysRequestDeliveryReceipt", AlwaysRequestDeliveryReceipt);
	SettingStructure.Insert("NewMessageFormattedDocument", NewMessageFormattedDocument);
	SettingStructure.Insert("SignatureForNewMessagesPlainText", SignatureForNewMessagesPlainText);
	SettingStructure.Insert("ReplyForwardSignaturePlainText", ReplyForwardSignaturePlainText);
	SettingStructure.Insert("ReplyToReadReceiptPolicies", ReplyToReadReceiptPolicies);
	SettingStructure.Insert("OnReplyForwardFormattedDocument", OnReplyForwardFormattedDocument);
	SettingStructure.Insert("NewMessageSignatureFormat", NewMessageSignatureFormat);
	SettingStructure.Insert("ReplyForwardSignatureFormat", ReplyForwardSignatureFormat);
	SettingStructure.Insert("DisplaySourceEmailBody", DisplaySourceEmailBody);
	SettingStructure.Insert("IncludeOriginalEmailBody", IncludeOriginalEmailBody);
	SettingStructure.Insert("SendMessagesImmediately", SendMessagesImmediately);

	Interactions.SaveEmailManagementSettings(SettingStructure);

EndProcedure

&AtClient
Procedure PromptOnChangeFormatOnClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		If AdditionalParameters.CallContext = "ForNewMessages" Then
			NewMessageSignatureFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		ElsIf AdditionalParameters.CallContext = "OnReplyForward" Then
			ReplyForwardSignatureFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		EndIf;
		NewMessageSignatureFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		Return;
	EndIf;
	
	If AdditionalParameters.CallContext = "ForNewMessages" Then
		
		SignatureForNewMessagesPlainText = NewMessageFormattedDocument.GetText();
		NewMessageFormattedDocument.Delete();
		
	ElsIf AdditionalParameters.CallContext = "OnReplyForward" Then
		
		ReplyForwardSignaturePlainText = OnReplyForwardFormattedDocument.GetText();
		OnReplyForwardFormattedDocument.Delete();
	
	EndIf;
	
	AvailabilityControl(ThisObject);
	
EndProcedure

#EndRegion
