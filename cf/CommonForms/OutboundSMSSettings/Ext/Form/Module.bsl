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
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SendSMSMessage.SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	ProviderSettings = SendSMSMessage.ProviderSettings(SMSMessageSendingSettings.Provider);
	FillAuthorizationMethods(ThisObject);
	
	AuthorizationMethod = "ByUsernameAndPassword";
	If SMSMessageSendingSettings.Property("AuthorizationMethod")
		And ValueIsFilled(SMSMessageSendingSettings.AuthorizationMethod)
		And Items.AuthorizationMethod.ChoiceList.FindByValue(SMSMessageSendingSettings.AuthorizationMethod) <> Undefined Then
		
		AuthorizationMethod = SMSMessageSendingSettings.AuthorizationMethod;
	EndIf;
	
	SetAuthorizationFields(ThisObject);
	DisplayAdditionalInformation(ThisObject);
	
	SMSMessageSenderUsername = SMSMessageSendingSettings.Login;
	SenderName = SMSMessageSendingSettings.SenderName;
	SMSMessageSenderPassword = SMSMessageSendingSettings.Password;
	
	If Items.Password.PasswordMode Then
		SMSMessageSenderPassword = ?(ValueIsFilled(SMSMessageSendingSettings.Password), UUID, "");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetServiceActivationInstructionText();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	RefreshReusableValues();
	Notify("Write_SMSMessageSendingSettings", WriteParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	SetPrivilegedMode(True);
	Owner = Common.MetadataObjectID("Constant.SMSProvider");
	If SMSMessageSenderPassword <> String(UUID) Then
		Common.WriteDataToSecureStorage(Owner, SMSMessageSenderPassword);
	EndIf;
	Common.WriteDataToSecureStorage(Owner, SMSMessageSenderUsername, "Login");
	Common.WriteDataToSecureStorage(Owner, SenderName, "SenderName");
	Common.WriteDataToSecureStorage(Owner, AuthorizationMethod, "AuthorizationMethod");
	SetPrivilegedMode(False);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SMSProviderOnChange(Item)
	
	ProviderSettings = ProviderSettings(ConstantsSet.SMSProvider);
	
	FillAuthorizationMethods(ThisObject);
	SetAuthorizationFields(ThisObject);
	DisplayAdditionalInformation(ThisObject);
	
	SMSMessageSenderUsername = "";
	SMSMessageSenderPassword = "";
	SenderName = "";
	
	SetServiceActivationInstructionText();
	
EndProcedure

&AtClient
Procedure AuthorizationMethodOnChange(Item)
	
	SMSMessageSenderUsername = "";
	SMSMessageSenderPassword = "";
	
	SetAuthorizationFields(ThisObject);
	DisplayAdditionalInformation(ThisObject);
	
EndProcedure

&AtServerNoContext
Function ProviderSettings(Provider)
	
	Return SendSMSMessage.ProviderSettings(Provider);
	
EndFunction

&AtClientAtServerNoContext
Procedure SetAuthorizationFields(Form)

	AuthorizationFields = Form.ProviderSettings.AuthorizationFields[Form.AuthorizationMethod];
	
	For Each FieldName In StrSplit("Login,Password", ",") Do
		Field = AuthorizationFields.FindByValue(FieldName);
		If Field <> Undefined Then
			Item = Form.Items[FieldName]; // FormField
			Item.Title = Field.Presentation;
		EndIf;
		
		Form.Items[FieldName].Visible = Field <> Undefined;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillAuthorizationMethods(Form)
	
	Form.Items.AuthorizationMethod.ChoiceList.Clear();
	
	DefaultAuthorizationMethods = Form.ProviderSettings.AuthorizationMethods;
	
	For Each Item In DefaultAuthorizationMethods Do
		If Form.ProviderSettings.AuthorizationFields.Property(Item.Value) Then
			Form.Items.AuthorizationMethod.ChoiceList.Add(Item.Value, Item.Presentation);
		EndIf;
	EndDo;
	
	Form.AuthorizationMethod = Form.Items.AuthorizationMethod.ChoiceList[0].Value;
	Form.Items.AuthorizationMethod.Visible = Form.Items.AuthorizationMethod.ChoiceList.Count() > 1;
	
EndProcedure

&AtClientAtServerNoContext
Procedure DisplayAdditionalInformation(Form)
	
	Form.Items.AdditionalInformation.Title = "";
	
	AdditionalInformation = Form.ProviderSettings.InformationOnAuthorizationMethods;
	If AdditionalInformation.Property(Form.AuthorizationMethod) Then
		Form.Items.AdditionalInformation.Title = AdditionalInformation[Form.AuthorizationMethod];
	EndIf;
	
	Form.Items.AdditionalInformationGroup.Visible = ValueIsFilled(Form.Items.AdditionalInformation.Title);
	
EndProcedure

&AtClient
Function ServiceDetailsInternetAddress()
	
	InternetAddress = ProviderSettings.ServiceDetailsInternetAddress;
	SendSMSMessageClientOverridable.OnGetProviderInternetAddress(ConstantsSet.SMSProvider, InternetAddress);
	Return InternetAddress;
	
EndFunction

&AtClient
Procedure SetServiceActivationInstructionText()
	
	InstructionTemplate = NStr("en = 'To start sending text messages, you need to sign an agreement with <a href = ""%1"">%2</a>.
	|Enter the sender''s name only if it is provided by the agreement.
	|For payment details and authorization issues, contact the SMS service provider.';");
	
	Items.ServiceActivationInstruction.Title = StringFunctionsClient.FormattedString(
	StringFunctionsClientServer.SubstituteParametersToString(InstructionTemplate, ServiceDetailsInternetAddress(), ConstantsSet.SMSProvider));
	
EndProcedure

#EndRegion
