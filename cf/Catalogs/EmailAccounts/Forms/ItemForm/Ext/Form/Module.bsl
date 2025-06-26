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
	
	If Parameters.LockOwner Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.UseForSending = True;
		Object.UseForReceiving = CanReceiveEmails;
		FillSettings();
	EndIf;
	
	Items.UseAccount.ShowTitle = CanReceiveEmails;
	Items.ForReceiving.Visible = CanReceiveEmails;
	
	If Not CanReceiveEmails Then
		Items.ForSending.Title = NStr("en = 'Use this account to send mail';");
	EndIf;
	
	Items.AccountAvailabilityGroup.Enabled = Users.IsFullUser();
	
	AttributesRequiringPasswordToChange = Catalogs.EmailAccounts.AttributesRequiringPasswordToChange();
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	
	HighlightColor = StyleColors.ErrorNoteText;
	PatchID = Parameters.PatchID;
	
	If Common.IsMobileClient() Then
		Items.AuthenticationMethodMailService.Visible = False;
		
		Items.AuthenticationPassword.ChoiceList.Clear();
		Items.AuthenticationPassword.ChoiceList.Add("OAuth", NStr("en = 'Authorize in the email service';"));
		Items.AuthenticationPassword.ChoiceList.Add("Password", NStr("en = 'Use password';"));
		
		Items.Password.HorizontalStretch = True;
		Items.Password.TitleLocation = FormItemTitleLocation.Auto;
		
		Items.Password.Visible = Not Object.EmailServiceAuthorization;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PasswordChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password, "SMTPPassword");
		SetPrivilegedMode(False);
	EndIf;
	
	EmailOperationsInternal.UpdateMailRecoveryServerSettings(CurrentObject.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If UserAccountKind = "Personal1" And Not ValueIsFilled(Object.AccountOwner) Then 
		Cancel = True;
		MessageText = NStr("en = 'Select the account owner.';");
		Common.MessageToUser(MessageText, , "Object.AccountOwner");
	EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	CurrentObject.SMTPUser = ?(CurrentObject.AuthorizationRequiredOnSendEmails And Not Object.SignInBeforeSendingRequired, CurrentObject.User, "");
	CurrentObject.SignInBeforeSendingRequired = CurrentObject.SignInBeforeSendingRequired And CurrentObject.AuthorizationRequiredOnSendEmails;
	CurrentObject.AdditionalProperties.Insert("Password", PasswordCheck);
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	NotifyDescription = New NotifyDescription("BeforeCloseConfirmationReceived", ThisObject);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit);
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	FillObjectAttributes();
	
	HandlersBeforeWrite = New Array;
	HandlersBeforeWrite.Add(New NotifyDescription("CheckFillingBeforeWrite", ThisObject, WriteParameters));
	HandlersBeforeWrite.Add(New NotifyDescription("ValidatePermissionsBeforeWrite", ThisObject, WriteParameters));
	HandlersBeforeWrite.Add(New NotifyDescription("CheckPasswordBeforeWrite", ThisObject, WriteParameters));
	
	AttachHandlersBeforeWrite(HandlersBeforeWrite, ThisObject, Cancel, WriteParameters);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	CommonClient.NotifyObjectChanged(Object.Ref);
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
	If WriteParameters.Property("CheckSettings") Then
		AttachIdleHandler("ExecuteSettingsCheck", 0.1, True);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetKeepEmailsAtServerSettingKind();
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;

	If ValueIsFilled(PatchID) Then
		ShowCorrectionMethod(PatchID);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	FillSettings();
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure ShowCorrectionMethod(WayFix, AdditionalParameters = Undefined) Export

	If WayFix = "EnableUseAuthorizationSMTP" Then
		CommonClient.MessageToUser(NStr("en = 'Enable authorization on the outgoing mail server.';"),
			Object.Ref, , "Object.AuthorizationRequiredOnSendEmails");
	ElsIf WayFix = "Readjust" Then
		CommonClient.MessageToUser(NStr("en = 'To reconfigure your account, click ""Reconfigure"".';"),
			Object.Ref);
	ElsIf WayFix = "UseSTARTTLSForIncomingMail" Then
		CommonClient.MessageToUser(NStr("en = 'Switch encryption to STARTTLS (for incoming emails).';"),
			Object.Ref, "EncryptOnReceiveMail");
	ElsIf WayFix = "RefillLoginPassword" Then
		CommonClient.MessageToUser(NStr("en = 'Try clearing and entering a username again.';"),
			Object.Ref, , "Object.User");
	ElsIf WayFix = "RefillPassword" Then
		CommonClient.MessageToUser(NStr("en = 'Enter your password';"),
			Object.Ref, "Password");
	ElsIf WayFix = "FillinMailAddress" Then
		CommonClient.MessageToUser(NStr("en = 'Check email address.';"),
			Object.Ref, "Object.Email");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProtocolOnChange(Item)
	
	If IsBlankString(Object.ProtocolForIncomingMail) Then
		Object.ProtocolForIncomingMail = "IMAP";
	EndIf;
	
	If Object.ProtocolForIncomingMail = "IMAP" Then
		If StrStartsWith(Object.IncomingMailServer, "pop.") Then
			Object.IncomingMailServer = "imap." + Mid(Object.IncomingMailServer, 5);
		EndIf
	Else
		If StrStartsWith(Object.IncomingMailServer, "imap.") Then
			Object.IncomingMailServer = "pop." + Mid(Object.IncomingMailServer, 6);
		EndIf;
	EndIf;
	
	Items.IncomingMailServer.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 server';"), Object.ProtocolForIncomingMail);
		
	POPIsUsed = Object.ProtocolForIncomingMail = "POP";
	Items.KeepMessagesOnServer.Visible = POPIsUsed And CanReceiveEmails;
	
	SetGroupTypeAuthorizationRequired(ThisObject, POPIsUsed);
	
	ConnectIncomingMailPort();
	SetKeepEmailsAtServerSettingKind();
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetGroupTypeAuthorizationRequired(Form, POPIsUsed)
	
	If POPIsUsed Then
		Form.Items.AuthorizationRequiredOnSendMail.Title = NStr("en = 'Outgoing server (POP) requires authentication';");
	Else
		Form.Items.AuthorizationRequiredOnSendMail.Title = NStr("en = 'Outgoing server (SMTP) requires authentication';");
	EndIf;

	Form.Items.AuthorizationOnSendMail.Visible = POPIsUsed;
	
EndProcedure

&AtClient
Procedure IncomingMailServerOnChange(Item)
	Object.IncomingMailServer = TrimAll(Lower(Object.IncomingMailServer));
EndProcedure

&AtClient
Procedure OutgoingMailServerOnChange(Item)
	Object.OutgoingMailServer = TrimAll(Lower(Object.OutgoingMailServer));
EndProcedure

&AtClient
Procedure EmailOnChange(Item)
	Object.Email = TrimAll(Object.Email);
EndProcedure

&AtClient
Procedure KeepEmailCopiesOnServerOnChange(Item)
	SetKeepEmailsAtServerSettingKind();
EndProcedure

&AtClient
Procedure DeleteMailFromServerOnChange(Item)
	SetKeepEmailsAtServerSettingKind();
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	PasswordChanged = True;
EndProcedure

&AtClient
Procedure PasswordEditTextChange(Item, Text, StandardProcessing)
	Items.Password.ChoiceButton = True;
EndProcedure

&AtClient
Procedure PasswordStartChoice(Item, ChoiceData, StandardProcessing)
	EmailOperationsClient.PasswordFieldStartChoice(Item, Password, StandardProcessing);
EndProcedure

&AtClient
Procedure AccountAvailabilityOnChange(Item)
	Items.AccountUser.Enabled = UserAccountKind = "Personal1";
	NotifyOfChangesAccountOwner();
EndProcedure

&AtClient
Procedure AccountUserOnChange(Item)
	NotifyOfChangesAccountOwner();
EndProcedure

&AtClient
Procedure AuthorizationRequiredOnSendMailOnChange(Item)
	Items.AuthorizationOnSendMail.Enabled = Object.AuthorizationRequiredOnSendEmails;
	Items.AuthorizationOnSendMail.Visible = Object.ProtocolForIncomingMail = "POP";
EndProcedure

&AtClient
Procedure EncryptOnSendMailOnChange(Item)
	Object.UseSecureConnectionForOutgoingMail = EncryptOnSendMail = "SSL";
	ConnectOutgoingMailPort();
EndProcedure

&AtClient
Procedure EncryptOnReceiveMailOnChange(Item)
	Object.UseSecureConnectionForIncomingMail = EncryptOnReceiveMail = "SSL";
	ConnectIncomingMailPort();
EndProcedure

&AtClient
Procedure AuthorizationMethodOnSendMailOnChange(Item)
	Object.SignInBeforeSendingRequired = ?(AuthorizationMethodOnSendMail = "POP", True, False);
	SetKeepEmailsAtServerSettingKind();
EndProcedure

&AtClient
Procedure NeedHelpClick(Item)
	
	EmailOperationsClient.GoToEmailAccountInputDocumentation();
	
EndProcedure

&AtClient
Procedure UseOnChange(Item)
	Items.FormCheckSettings.Enabled = Object.UseForSending Or Object.UseForReceiving;
EndProcedure

&AtClient
Procedure AuthenticationModeOnChange(Item)
	
	Object.EmailServiceAuthorization = AuthenticationOption = "OAuth";
	
#If MobileClient Then
	Items.Password.Visible = Not Object.EmailServiceAuthorization;
#Else
	Items.Password.Enabled = Not Object.EmailServiceAuthorization;
#EndIf

	If Object.EmailServiceAuthorization Then
		OpenHelpFormSettings(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Attachable_UpdateCommands()
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtClient
Procedure Attachable_ExecuteCommand(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
	EndIf;
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure CheckSettings(Command)
	ExecuteSettingsCheck();
EndProcedure

&AtClient
Procedure OpenSetupWizard(Command)
	
	OpenHelpFormSettings();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetKeepEmailsAtServerSettingKind()
	
	POPIsUsed = Object.ProtocolForIncomingMail = "POP";
	Items.KeepMessagesOnServer.Visible = POPIsUsed And CanReceiveEmails;
	Items.MailRetentionPeriodSetup.Enabled = Object.KeepMessageCopiesAtServer;
	Items.KeepMailAtServerPeriod.Enabled = DeleteMailFromServer;
	
EndProcedure

&AtClient
Procedure ConnectIncomingMailPort()
	If Object.ProtocolForIncomingMail = "IMAP" Then
		If Object.IncomingMailServerPort = 995 Then
			Object.IncomingMailServerPort = 993;
		EndIf;
	Else
		If Object.IncomingMailServerPort = 993 Then
			Object.IncomingMailServerPort = 995;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ConnectOutgoingMailPort()
	If Object.UseSecureConnectionForOutgoingMail Then
		If Object.OutgoingMailServerPort = 587 Then
			Object.OutgoingMailServerPort = 465;
		EndIf;
	Else
		If Object.OutgoingMailServerPort = 465 Then
			Object.OutgoingMailServerPort = 587;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure BeforeCloseConfirmationReceived(QuestionResult, AdditionalParameters) Export
	Write(New Structure("WriteAndClose"));
EndProcedure

&AtClient
Procedure NotifyOfChangesAccountOwner()
	Notify("OnChangeEmailAccountKind", UserAccountKind = "Personal1", ThisObject);
EndProcedure

&AtClient
Procedure FillObjectAttributes()
	
	If Not DeleteMailFromServer Then
		Object.KeepMailAtServerPeriod = 0;
	EndIf;
	
	If Object.ProtocolForIncomingMail = "IMAP" Then
		Object.KeepMessageCopiesAtServer = True;
		Object.KeepMailAtServerPeriod = 0;
	EndIf;
	
	If UserAccountKind = "Shared3" And ValueIsFilled(Object.AccountOwner) Then
		Object.AccountOwner = Undefined;
	EndIf;

EndProcedure

&AtClient
Procedure CheckFillingBeforeWrite(Cancel, WriteParameters) Export
	
	If Not CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidatePermissionsBeforeWrite(Cancel, WriteParameters) Export
	
	Cancel = True;
	NotifyDescription = New NotifyDescription("AfterCheckPermissions", ThisObject, WriteParameters);
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(
			RequestsForPermissionToUseExternalResources(), ThisObject, NotifyDescription);
	Else
		ExecuteNotifyProcessing(NotifyDescription, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckPasswordBeforeWrite(Cancel, WriteParameters) Export
	
	If Not PasswordCheckExecuted(WriteParameters) Then
		Cancel = True;
		PasswordCheck = "";
		NotifyDescription = New NotifyDescription("AfterPasswordEnter", ThisObject, WriteParameters);
		OpenForm("Catalog.EmailAccounts.Form.CheckAccountAccess", , ThisObject, , , , NotifyDescription);
	EndIf;
	
EndProcedure

&AtServer
Function RequestsForPermissionToUseExternalResources()
	
	Query = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		Query = ModuleSafeModeManager.RequestToUseExternalResources(Permissions(), Object.Ref);
	EndIf;
	
	Return CommonClientServer.ValueInArray(Query);
	
EndFunction

&AtServer
Function Permissions()
	
	Result = New Array;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If Object.UseForSending Then
		Result.Add(
			ModuleSafeModeManager.PermissionToUseInternetResource(
				"SMTP",
				Object.OutgoingMailServer,
				Object.OutgoingMailServerPort,
				NStr("en = 'Email.';")));
	EndIf;
	
	If Object.UseForReceiving Then
		Result.Add(
			ModuleSafeModeManager.PermissionToUseInternetResource(
				Object.ProtocolForIncomingMail,
				Object.IncomingMailServer,
				Object.IncomingMailServerPort,
				NStr("en = 'Email.';")));
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AfterCheckPermissions(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters.Insert("PermissionsGranted");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Function PasswordCheckExecuted(WriteParameters)
	
	If Not WriteParameters.Property("PasswordEntered") Then
		AttributesValuesBeforeWrite = New Structure(AttributesRequiringPasswordToChange);
		FillPropertyValues(AttributesValuesBeforeWrite, Object);
		Return Not PasswordCheckIsRequired(Object.Ref, AttributesValuesBeforeWrite);
	EndIf;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function PasswordCheckIsRequired(Ref, AttributesValues)
	Return Catalogs.EmailAccounts.PasswordCheckIsRequired(Ref, AttributesValues);
EndFunction

&AtClient
Procedure AfterPasswordEnter(Password, WriteParameters) Export
	
	If TypeOf(Password) = Type("String") Then
		PasswordCheck = Password;
		WriteParameters.Insert("PasswordEntered");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteSettingsCheck()
	If Modified Then
		Write(New Structure("CheckSettings"));
	Else
		NotifyDescription = New NotifyDescription("ShowCorrectionMethod", ThisObject);
		OpeningParameters = New Structure("Account", Object.Ref);
		OpenForm("Catalog.EmailAccounts.Form.ValidatingAccountSettings",
			OpeningParameters, ThisObject, , , , NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure OnCompleteSetup(Result, OnlyAuthorization) Export
		
	If OnlyAuthorization Then
		If Result <> True Then
			Object.EmailServiceAuthorization = False;
			AuthenticationOption = "Password";
#If MobileClient Then
			Items.Password.Visible = Not Object.EmailServiceAuthorization;
#Else
			Items.Password.Enabled = Not Object.EmailServiceAuthorization;
#EndIf
			WarningText = NStr("en = 'Authorization in the email service failed.';");
			If TypeOf(Result) = Type("String") Then
				WarningText = WarningText + Chars.LF + Result;
			EndIf;
			ShowMessageBox(Undefined, WarningText);
		EndIf;
		Return;
	EndIf;
	
	Read();
	
EndProcedure

&AtServer
Procedure FillSettings()
	
	CanReceiveEmails = EmailOperationsInternal.SubsystemSettings().CanReceiveEmails;
	ShouldUsePOP3Protocol = EmailOperationsInternal.SubsystemSettings().ShouldUsePOP3Protocol;
	If Not ShouldUsePOP3Protocol And (Object.ProtocolForIncomingMail = "IMAP" Or Object.Ref.IsEmpty()) Then
		Object.ProtocolForIncomingMail = "IMAP";
		Items.Protocol.Visible = False;
	EndIf;
	Items.KeepMessagesOnServer.Visible = Object.ProtocolForIncomingMail = "POP" And CanReceiveEmails;
	
	Items.IncomingMailServer.Title = StringFunctionsClientServer.SubstituteParametersToString(
	NStr("en = '%1 server';"), Object.ProtocolForIncomingMail);
	
	DeleteMailFromServer = Object.KeepMailAtServerPeriod > 0;
	If Not DeleteMailFromServer Then
		Object.KeepMailAtServerPeriod = 10;
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		SetPrivilegedMode(True);
		PasswordIsSet = Common.ReadDataFromSecureStorage(Object.Ref) <> "";
		SetPrivilegedMode(False);
		Password = ?(PasswordIsSet, UUID, "");
		PasswordChanged = False;
		EmailOperationsInternal.CheckoutPasswordField(Items.Password);
		
		If Not Catalogs.EmailAccounts.EditionAllowed(Object.Ref) Then
			ReadOnly = True;
		EndIf;
	EndIf;
	
	Items.FormWriteAndClose.Enabled = Not ReadOnly;
	
	IsPersonalAccount = ValueIsFilled(Object.AccountOwner);
	Items.AccountUser.Enabled = IsPersonalAccount;
	UserAccountKind = ?(IsPersonalAccount, "Personal1", "Shared3");
	
	POPIsUsed = Object.ProtocolForIncomingMail = "POP";
	Items.AuthorizationOnSendMail.Enabled = Object.AuthorizationRequiredOnSendEmails;
	SetGroupTypeAuthorizationRequired(ThisObject, POPIsUsed);
	
	EncryptOnSendMail = ?(Object.UseSecureConnectionForOutgoingMail, "SSL", "Auto");
	EncryptOnReceiveMail = ?(Object.UseSecureConnectionForIncomingMail, "SSL", "Auto");
	
	AuthorizationMethodOnSendMail = ?(Object.SignInBeforeSendingRequired, "POP", "SMTP");
	Items.FormCheckSettings.Enabled = Object.UseForSending Or Object.UseForReceiving;
	Items.FormOpenSetupWizard.Enabled = Not Object.Ref.IsEmpty() And Not ReadOnly;
	
	If Object.EmailServiceAuthorization Then
		AuthenticationOption = "OAuth";
	Else
		AuthenticationOption = "Password";
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.Password.Visible = Not Object.EmailServiceAuthorization;
	Else
		Items.Password.Enabled = Not Object.EmailServiceAuthorization;
	EndIf;
	
EndProcedure

// Sequentially calls the specified handlers in the BeforeWrite event via the idle handler.
&AtClient
Procedure AttachHandlersBeforeWrite(Handlers, Form, Cancel, WriteParameters)
	
	If Not WriteParameters.Property("HandlersBeforeWrite") Then
		WriteParameters.Insert("HandlersBeforeWrite", New Structure)
	EndIf;
	
	For Each Handler In Handlers Do
		If Not WriteParameters.HandlersBeforeWrite.Property(Handler.ProcedureName) Then
			WriteParameters.HandlersBeforeWrite.Insert(Handler.ProcedureName, False);
		EndIf;
	EndDo;
	
	For Each Validation In WriteParameters.HandlersBeforeWrite Do
		If Validation.Value = False Then
			Cancel = True;
			NotifyDescription = New NotifyDescription(Validation.Key, Form, WriteParameters);
			
			ParameterName = "StandardSubsystems.IdleHandlerBeforeWriteInForm";
			If ApplicationParameters[ParameterName] = Undefined Then
				ApplicationParameters.Insert(ParameterName, New Array);
			EndIf;
			IdleHandlerBeforeWriteInForm = ApplicationParameters[ParameterName]; // Array
			IdleHandlerBeforeWriteInForm.Add(NotifyDescription);
			
			AttachIdleHandler("ExecuteCheckBeforeWriteInForm", 0.1, True);
			Return;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteCheckBeforeWriteInForm()
	
	ParameterName = "StandardSubsystems.IdleHandlerBeforeWriteInForm";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Array);
	EndIf;
	IdleHandlers = ApplicationParameters[ParameterName];
	
	If IdleHandlers.Count() > 0 Then
		NotifyDescription = IdleHandlers[0];
		ProcedureName = IdleHandlers[0].ProcedureName;
		Form = IdleHandlers[0].Module; // ManagedFormExtensionForCatalogs
		WriteParameters = IdleHandlers[0].AdditionalParameters;
		IdleHandlers.Delete(0);
		WriteParameters.HandlersBeforeWrite[ProcedureName] = True;
		Cancel = False;
		ExecuteNotifyProcessing(NotifyDescription, Cancel);
		If Not Cancel Then
			Form.Write(WriteParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenHelpFormSettings(OnlyAuthorization = False)
	
	NotifyDescription = New NotifyDescription("OnCompleteSetup", ThisObject, OnlyAuthorization);
	OpeningParameters = New Structure;
	OpeningParameters.Insert("Key", Object.Ref);
	If OnlyAuthorization Then
		OpeningParameters.Insert("OnlyAuthorization", True);
	Else
		OpeningParameters.Insert("Reconfigure", True);
	EndIf;
	
	OpenForm("Catalog.EmailAccounts.Form.AccountSetupWizard", 
		OpeningParameters, , , , , NotifyDescription);
		
EndProcedure
#EndRegion
