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
	
	If Not Users.IsFullUser() Then
		Raise(NStr("en = 'Insufficient rights to perform the operation.';"),
			ErrorCategory.AccessViolation);
	EndIf;
	
	ReadPasswordRestorationSettings();
	
	If ShowHelpHyperlink And IsBlankString(HelpURL) Then
		Items.HelpURL.MarkIncomplete = True;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		AccountEmail                      = Undefined;
		Items.GroupMailSettings.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		Items.GroupMailSettings.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	SetItemsAvailability();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PasswordRecoveryOptionOnChange(Item)
	
	If PasswordRecoveryOption = "ViaEmail" Then
		Items.RecoveryOptions.CurrentPage = Items.Email;
	Else
		Items.RecoveryOptions.CurrentPage = Items.LinkAction;
	EndIf;
	
EndProcedure

&AtClient
Procedure RestorePasswordOnChange(Item)
	
	If RestorePassword Then
		Items.PasswordRecoveryOption.Enabled = True;
		Items.RecoveryOptions.Enabled      = True;
	Else
		Items.PasswordRecoveryOption.Enabled = False;
		Items.RecoveryOptions.Enabled      = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NeedHelpOnChange(Item)
	
	Items.HelpURL.Enabled = ShowHelpHyperlink;
	
EndProcedure

&AtClient
Procedure SendByEmailOptionOnChange(Item)
	
	SetItemsAvailability();
	
EndProcedure

&AtClient
Procedure SendingOptionByEmailSettingOnChange(Item)
	
	SetItemsAvailability();
	
EndProcedure

&AtClient
Procedure SendingOptionStandardServiceOnChange(Item)
	
	SetItemsAvailability();
	
EndProcedure

&AtClient
Procedure EncryptOnReceiveMailOnChange(Item)
	
	If EncryptOnSendMail = "Auto" Then
		SMTPPort = 25;
	Else
		SMTPPort = 465
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	If PasswordRecoverySettingsAreCorrect() Then
		SavePasswordRecoverySettings();
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	If PasswordRecoverySettingsAreCorrect() Then
		SavePasswordRecoverySettings();
	EndIf;
	
EndProcedure

&AtClient
Procedure HelpURLOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	FileSystemClient.OpenURL(HelpURL);
	
EndProcedure

&AtClient
Procedure ConfirmationCode(Command)
	
	InsertAParameterInATemplate("&VerificationCode");
	
EndProcedure

&AtClient
Procedure ParameterUsername(Command)
	
	InsertAParameterInATemplate("&UserPresentation");
	
EndProcedure

&AtClient
Procedure ConfigurationDescription(Command)
	
	InsertAParameterInATemplate("&ApplicationPresentation");
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export
	
	If PasswordRecoverySettingsAreCorrect() Then
		SavePasswordRecoverySettings();
		Modified = False;
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetItemsAvailability()
	
	Flag = SendByEmailOption = "ManualSetting";
	Items.SMTPServerGroup.Enabled       = Flag;
	Items.GroupSMTPUser.Enabled = Flag;
	Items.SenderName.Enabled         = Flag;
	
	If Flag Then
		Items.GroupManualMailSettings.Show();	
	EndIf;
	
	Flag = SendByEmailOption <> "StandardService";
	Items.EmailSubject.Enabled                            = Flag;
	Items.GroupFormattedDocumentButtons.Enabled = Flag;
	Items.MessageText.Enabled                        = Flag;
	
	If Flag Then
		Items.MessageTextGroup.Show();
	Else
		Items.MessageTextGroup.Hide();
	EndIf;
	
EndProcedure

&AtClient
Function PasswordRecoverySettingsAreCorrect()
	
	ClearMessages();
	
	TheSettingsAreCorrect = True;
	
	If ShowHelpHyperlink And IsBlankString(HelpURL) Then
		
		CommonClient.MessageToUser(NStr("en = 'Help page address is required';"),,
					"HelpURL");
		TheSettingsAreCorrect = False;
		
	EndIf;
	
	If PasswordRecoveryOption <> "ViaEmail" Then
		
		If IsBlankString(PasswordRecoveryURL) Then
			
			CommonClient.MessageToUser(NStr("en = 'Password recovery page address is required';"),,
					"PasswordRecoveryURL");
				TheSettingsAreCorrect = False;
				
		EndIf;
		
		Return TheSettingsAreCorrect;
		
	EndIf;
	
	If SendByEmailOption = "ExternalMailServer" Then
		
		If Not ValueIsFilled(AccountEmail) Then
		
			CommonClient.MessageToUser(NStr("en = 'Email account is required';"),,
				"AccountEmail");
			TheSettingsAreCorrect = False;
			
		ElsIf Not AccountSetUp(AccountEmail) Then
			
			CommonClient.MessageToUser(NStr("en = 'The email account is not configured to send mail';"),,
				"AccountEmail");
			TheSettingsAreCorrect = False;
			
		EndIf;
		
	ElsIf SendByEmailOption = "ManualSetting" Then
		
		If IsBlankString(SMTPServerAddress) Then
		
			CommonClient.MessageToUser(NStr("en = 'SMTP server address is required';"),,
				"SMTPServerAddress");
			TheSettingsAreCorrect = False;
			
		EndIf;
		
		If IsBlankString(SMTPUser) Then
		
			CommonClient.MessageToUser(NStr("en = 'SMTP user is required';"),,
				"SMTPUser");
			TheSettingsAreCorrect = False;
			
		EndIf;
		
		If IsBlankString(SMTPPassword) Then
		
			CommonClient.MessageToUser(NStr("en = 'SMTP password is required';"),,
				"SMTPPassword");
			TheSettingsAreCorrect = False;
			
		EndIf;
		
		If IsBlankString(SenderName) Then
		
			CommonClient.MessageToUser(NStr("en = 'Sender name is required';"),,
				"SenderName");
			TheSettingsAreCorrect = False;
			
		EndIf;

		
	EndIf;
	
	Return TheSettingsAreCorrect;
	
EndFunction

&AtServerNoContext
Function AccountSetUp(Account)
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		
		ModuleEmailOperations = Common.CommonModule("EmailOperations");
		Return ModuleEmailOperations.AccountSetUp(Account, True, False);
		
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure InsertAParameterInATemplate(ParameterName)
	
	If CurrentItem.Name = Items.EmailSubject.Name Then
		EmailSubject = EmailSubject + " " + ParameterName;
	Else
		BookmarkToInsertStart = Undefined;
		BookmarkToInsertEnd  = Undefined;
		Items.MessageText.GetTextSelectionBounds(BookmarkToInsertStart, BookmarkToInsertEnd);
		MessageText.Insert(BookmarkToInsertEnd, ParameterName);
	EndIf;
	
EndProcedure

&AtServer
Procedure StartBackgroundFillingOfUsersMail()
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Fill in user email for password recovery';");
	
	TimeConsumingOperations.ExecuteInBackground("UsersInternal.FillInTheEmailForPasswordRecoveryFromUsersInTheBackground",
		New Structure, ExecutionParameters);
	
EndProcedure

&AtServer
Function YouNeedToStartFillingInTheUsersMail()
	
	If Not RestorePassword Then
		Return False;
	EndIf;
	
	Settings = AdditionalAuthenticationSettings.GetPasswordRecoverySettings(); // PasswordRecoverySettings
	
	// Previous values.
	If Settings.PasswordRecoveryMethod
			<> InfoBaseUserPasswordRecoveryMethod.None Then
		Return False;
	EndIf;
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each IBUser In IBUsers Do
		If IBUser.CannotRecoveryPassword = False Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

&AtServer
Procedure SavePasswordRecoverySettings()
	
	StartBackgroundFillingOfUsersMail = YouNeedToStartFillingInTheUsersMail();
	
	If PasswordChanged Then
		CurrentSMTPPassword = SMTPPassword;
	Else
		CurrentSettings = AdditionalAuthenticationSettings.GetPasswordRecoverySettings(); // PasswordRecoverySettings
		CurrentSMTPPassword = CurrentSettings.SMTPPassword;
	EndIf;
	
	Attachments = New Structure;
	MessageText.GetHTML(HTMLMessageText, Attachments);
	
	For Each Attachment In Attachments Do
		
		ImageFormat = ?(Attachment.Value.Format() <> PictureFormat.UnknownFormat,
			Lower(Attachment.Value.Format()), Lower(PictureFormat.PNG));
			
		PictureText = "src=""data:image/" + ImageFormat + ";base64," + Base64String(Attachment.Value.GetBinaryData()) + """";
		HTMLMessageText = StrReplace(HTMLMessageText,
			"src=""" + Attachment.Key + """", 
			PictureText);
			
	EndDo;
	
	Settings = AdditionalAuthenticationSettings.GetPasswordRecoverySettings(); // PasswordRecoverySettings
	FillPropertyValues(Settings, ThisObject, ListOfSettingsFields());
	
	Settings.Header  = EmailSubject;
	Settings.SMTPPassword = CurrentSMTPPassword;
	
	If RestorePassword Then
		
		If PasswordRecoveryOption = "LinkAction" Then
			Settings.PasswordRecoveryMethod =
				InfoBaseUserPasswordRecoveryMethod.GotoURL;
		
		ElsIf SendByEmailOption = "StandardService" Then
			Settings.PasswordRecoveryMethod =
				InfoBaseUserPasswordRecoveryMethod.SendVerificationCodeByStandardService;
		
		ElsIf SendByEmailOption = "ExternalMailServer" Then
			Settings.PasswordRecoveryMethod =
				InfoBaseUserPasswordRecoveryMethod.SendVerificationCodeBySetParameters;
			
			If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
				ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
				AccountSettingsForSendingMail = ModuleEmailOperationsInternal.AccountSettingsForSendingMail(AccountEmail);
				FillPropertyValues(Settings, AccountSettingsForSendingMail);
			EndIf;
		Else
			Settings.PasswordRecoveryMethod = 
				InfoBaseUserPasswordRecoveryMethod.SendVerificationCodeBySetParameters;
			FillPropertyValues(Settings, ThisObject, "SMTPServerAddress, SMTPPassword, SMTPUser, SMTPPort,SenderName");
			Settings.UseSSL = EncryptOnSendMail = "SSL";
			
		EndIf;
	Else
		Settings.PasswordRecoveryMethod = InfoBaseUserPasswordRecoveryMethod.None;
	EndIf;
	
	SetUpAPasswordRecoveryAccount(AccountEmail, SendByEmailOption = "ExternalMailServer");
	AdditionalAuthenticationSettings.SetPasswordRecoverySettings(Settings);
	Modified = False;
	
	If StartBackgroundFillingOfUsersMail Then
		StartBackgroundFillingOfUsersMail();
	EndIf;
	
EndProcedure

&AtServer
Procedure ReadPasswordRestorationSettings()
	
	SendByEmailOption      = "StandardService";
	PasswordRecoveryOption = "ViaEmail";
	
	AccountInformation = AccountSettingsForPasswordRecovery();
	
	If TypeOf(AccountInformation) = Type("Structure") Then
		AccountEmail = AccountInformation.AccountEmail;
	EndIf;
	
	Settings = AdditionalAuthenticationSettings.GetPasswordRecoverySettings(); // PasswordRecoverySettings 
	FillPropertyValues(ThisObject, Settings, ListOfSettingsFields());
	
	If ValueIsFilled(Settings.SMTPPassword) Then
		SMTPPassword = String(New UUID);
	EndIf;
	
	EncryptOnSendMail = ?(Settings.UseSSL, "SSL", "Auto");
	
	If IsBlankString(HTMLMessageText) Then
		HTMLMessageText = DefaultText();
	EndIf;
	MessageText.SetHTML(HTMLMessageText, New Structure);
	
	EmailSubject = ?(ValueIsFilled(Settings.Header),
		Settings.Header, NStr("en = 'Password recovery';"));
	
	If Settings.PasswordRecoveryMethod = InfoBaseUserPasswordRecoveryMethod.None Then
		RestorePassword = False;
		
	Else
		RestorePassword = True;
		If Settings.PasswordRecoveryMethod = InfoBaseUserPasswordRecoveryMethod.SendVerificationCodeByStandardService Then
			SendByEmailOption = "StandardService";
			
		ElsIf Settings.PasswordRecoveryMethod
					= InfoBaseUserPasswordRecoveryMethod.SendVerificationCodeBySetParameters Then
				
			Items.RecoveryOptions.CurrentPage = Items.Email;
			PasswordRecoveryOption = "ViaEmail";
			If AccountInformation.Used Then
				SendByEmailOption = "ExternalMailServer";
			Else
				SendByEmailOption = "ManualSetting";
				Items.GroupManualMailSettings.Show();
			EndIf;
		Else
			Items.RecoveryOptions.CurrentPage = Items.LinkAction;
			PasswordRecoveryOption = "LinkAction";
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ListOfSettingsFields()
	
	Return "VerificationCodeRefreshRequestLockDuration,
	|MaxUnsuccessfulVerificationCodeValidationAttemptsCount,PasswordRecoveryURL,
	|ShowHelpHyperlink,HelpURL,VerificationCodeLength,HTMLMessageText,
	|SMTPServerAddress,SMTPPort,UseSSL,SMTPUser,SenderName";
	
EndFunction

&AtServerNoContext
Function DefaultText()
	
	TemplateMessageHTML = NStr("en = 'Dear %1,
	|
	|We have received a request to recover your password from %2.
	|
	|To reset the password, enter the code: %3.
	|
	|If you didn''t send the request, please contact the technical support.';");
	
	HTMLMessageText = StringFunctionsClientServer.SubstituteParametersToString(TemplateMessageHTML,
		"&UserPresentation", "&ApplicationPresentation", "&VerificationCode");
	
	Return HTMLMessageText;
	
EndFunction

&AtServerNoContext
Procedure SetUpAPasswordRecoveryAccount(AccountEmail, Used)
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		
		AccountInformation = ModuleEmailOperationsInternal.DescriptionOfAccountSettingsForPasswordRecovery();
		AccountInformation.AccountEmail = AccountEmail;
		AccountInformation.Used       = Used;
		
		ModuleEmailOperationsInternal.SaveYourAccountSettingsForPasswordRecovery(AccountInformation);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function AccountSettingsForPasswordRecovery()
	
	AccountInformation = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
		AccountInformation = ModuleEmailOperationsInternal.AccountSettingsForPasswordRecovery();
	EndIf;
	
	Return AccountInformation;
	
EndFunction

#EndRegion