///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var RecipientsHistory;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Common.SetChoiceListConditionalAppearance(ThisObject, 
		"RecipientsEmailAddressSendingOption", "RecipientsMailAddresses.SendingOption");
	
	SuccessResultColor = StyleColors.SuccessResultColor;
	
	AttachmentsForEmail = New Structure;
	
	If TypeOf(Parameters.Attachments) = Type("ValueList") Or TypeOf(Parameters.Attachments) = Type("Array") Then
		For Each Attachment In Parameters.Attachments Do
			DetermineEmailAttachmentPurpose(Attachment, AttachmentsForEmail);
		EndDo;
	EndIf;
	
	EmailSubject = Parameters.Subject;
	EmailBody.SetHTML(HTMLWrappedText(Parameters.Text), AttachmentsForEmail);
	ReplyToAddress = Parameters.ReplyToAddress;
	SubjectOf = Parameters.SubjectOf;
	EmailImportance = "Ordinary";
	
	If Not ValueIsFilled(Parameters.Sender) Then
		// Account is not passed. Selecting the first available account.
		AvailableEmailAccounts = EmailOperations.AvailableEmailAccounts(True);
		If AvailableEmailAccounts.Count() = 0 Then
			MessageText = NStr("en = 'There are no email accounts available. Please contact your system administrator.';");
			Common.MessageToUser(MessageText,,,,Cancel);
			Return;
		EndIf;
		
		Account = AvailableEmailAccounts[0].Ref;
		
	ElsIf TypeOf(Parameters.Sender) = Type("CatalogRef.EmailAccounts") Then
		Account = Parameters.Sender;
	ElsIf TypeOf(Parameters.Sender) = Type("ValueList") Then
		EmailAccountList = Parameters.Sender;
		
		If EmailAccountList.Count() = 0 Then
			MessageText = NStr("en = 'No accounts for sending mail are specified. Please contact your system administrator.';");
			Common.MessageToUser(MessageText,,,, Cancel);
			Return;
		EndIf;
		
		For Each ItemAccount In EmailAccountList Do
			Items.Account.ChoiceList.Add(
										ItemAccount.Value,
										ItemAccount.Presentation);
			If ItemAccount.Value.UseForReceiving Then
				ReplyToAddressesByAccounts.Add(ItemAccount.Value,
														GetEmailAddressByAccount(ItemAccount.Value));
			EndIf;
		EndDo;
		
		Items.Account.ChoiceList.SortByPresentation();
		Account = EmailAccountList[0].Value;
		
		// Selecting accounts from the passed account list.
		Items.Account.DropListButton = True;
	EndIf;
	
	If TypeOf(Parameters.Recipient) = Type("ValueList") Then
		
		For Each ItemEmailAddress In Parameters.Recipient Do
			NewRecipient = RecipientsMailAddresses.Add();
			NewRecipient.SendingOption = "Whom";
			If ValueIsFilled(ItemEmailAddress.Presentation) Then
				NewRecipient.Presentation = ItemEmailAddress.Presentation
										+ " <"
										+ ItemEmailAddress.Value
										+ ">"
			Else
				NewRecipient.Presentation = ItemEmailAddress.Value;
			EndIf;
		EndDo;
		
	ElsIf TypeOf(Parameters.Recipient) = Type("String") Then
		NewRecipient                 = RecipientsMailAddresses.Add();
		NewRecipient.SendingOption = "Whom";
		NewRecipient.Presentation   = Parameters.Recipient;
	ElsIf TypeOf(Parameters.Recipient) = Type("Array") Then
		For Each RecipientStructure1 In Parameters.Recipient Do
			HasPropertySelected = RecipientStructure1.Property("Selected");
			AddressesArray      = StrSplit(RecipientStructure1.Address, ";");
			SendingOption = ?(RecipientStructure1.Property("SendingOption"), RecipientStructure1.SendingOption, "Whom");
			
			If SendingOption = "ReplyTo" Then
				ReplyToAddress = ?(IsBlankString(ReplyToAddress), RecipientStructure1.Address, 
					ReplyToAddress + ";" + RecipientStructure1.Address);
				Continue;
			EndIf;
			
			If Items.RecipientsEmailAddressSendingOption.ChoiceList.FindByValue(SendingOption) = Undefined Then
				SendingOption = "Whom";
			EndIf;
			
			For Each Address In AddressesArray Do
				If IsBlankString(Address) Then
					Continue;
				EndIf;
				If (HasPropertySelected And RecipientStructure1.Selected) Or (Not HasPropertySelected) Then
					NewRecipient                 = RecipientsMailAddresses.Add();
					NewRecipient.SendingOption = SendingOption;
					NewRecipient.Presentation   = RecipientStructure1.Presentation + " <" + TrimAll(Address) + ">";
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If TypeOf(Parameters.Recipient) = Type("Array") Then
		If TypeOf(Parameters.Recipient) = Type("String") Then
			FillRecipientsTableFromRow(Parameters.Recipient);
		ElsIf TypeOf(Parameters.Recipient) = Type("ValueList") Then
			MessageRecipients = (Parameters.Recipient);
		ElsIf TypeOf(Parameters.Recipient) = Type("Array") Then
			FillRecipientsTableFromStructuresArray(Parameters.Recipient);
		EndIf;
		
		RecipientDetailsInTempStorage = PutToTempStorage(Parameters.Recipient, UUID);
	Else
		RecipientDetailsInTempStorage = PutToTempStorage(New Array, UUID);
	EndIf;
	
	If RecipientsMailAddresses.Count() = 0 Then
		NewRow                 = RecipientsMailAddresses.Add();
		NewRow.SendingOption = "Whom";
		NewRow.Presentation   = "";
	EndIf;
	
	// Getting the list of addresses that the user previously used.
	ReplyToList = Common.CommonSettingsStorageLoad(
		"EditNewEmailMessage", "ReplyToList");
	
	If ReplyToList <> Undefined And ReplyToList.Count() > 0 Then
		For Each ReplyToItem In ReplyToList Do
			Items.ReplyToAddress.ChoiceList.Add(ReplyToItem.Value, ReplyToItem.Presentation);
		EndDo;
		
		Items.ReplyToAddress.DropListButton = True;
	EndIf;
	
	If ValueIsFilled(ReplyToAddress) Then
		FillReplyToAddressAutomatically = False;
	Else
		UserAccountAttributes = Common.ObjectAttributesValues(Account,
			"UseForReceiving,UserName,Email");
		
		If UserAccountAttributes.UseForReceiving Then
			// Setting default email address
			If ValueIsFilled(UserAccountAttributes.UserName) Then 
				ReplyToAddress = UserAccountAttributes.UserName + " <" + UserAccountAttributes.Email + ">";
			Else
				ReplyToAddress = UserAccountAttributes.Email;
			EndIf;
		EndIf;
		
		FillReplyToAddressAutomatically = True;
	EndIf;
	
	// StandardSubsystems.MessagesTemplates
	
	Items.FormGenerateFromTemplate.Visible = False;
	Items.FormSaveAsTemplate.Visible    = False;
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates")Then
		ModuleMessageTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		
		If ModuleMessageTemplatesInternal.MessageTemplatesUsed() Then
			Items.FormGenerateFromTemplate.Visible = ModuleMessageTemplatesInternal.HasAvailableTemplates("MailMessage", SubjectOf);
			Items.FormSaveAsTemplate.Visible    = True;
		EndIf;
		
	EndIf;
	
	// End StandardSubsystems.MessagesTemplates
	
	If Common.IsMobileClient() Then
		Items.Attachment2.Visible = False;
		Items.EmailBodyMainGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.EmailSubject.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ImportAttachmentsFromFiles();
	RefreshAttachmentPresentation();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	If Not FormClosingConfirmationRequired Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	AttachIdleHandler("ShowQueryBoxBeforeCloseForm", 0.1, True);
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Not Exit Then
		AttachmentAddresses = New Array;
		For Each Attachment In Attachments Do
			AttachmentAddresses.Add(Attachment.AddressInTempStorage);
		EndDo;
		ClearAttachments(AttachmentAddresses);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Populating the reply address if the flag of automatic reply address substitution is set.
//
&AtClient
Procedure AccountChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If IsBlankString(ReplyToAddress) Then
		FillReplyToAddressAutomatically = True;
	EndIf;
	
	If FillReplyToAddressAutomatically Then
		If ReplyToAddressesByAccounts.FindByValue(ValueSelected) <> Undefined Then
			ReplyToAddress = ReplyToAddressesByAccounts.FindByValue(ValueSelected).Presentation;
		Else
			ReplyToAddress = GetEmailAddressByAccount(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFormModificationFlag(Item)
	FormClosingConfirmationRequired = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersRecipientsMailAddresses

&AtClient
Procedure RecipientPostalAddressesBeforeDelete(Item, Cancel)
	
	If RecipientsMailAddresses.Count() = 1 Then
		Cancel = True;
		RecipientsMailAddresses[0].Presentation = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientPostalAddressesOnStartEdit(Item, NewRow, Copy)
	If NewRow Then
		Item.CurrentData.SendingOption = "Whom";
		Item.CurrentItem                = Items.RecipientsEmailAddressPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure RecipientsEmailAddressPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	
	If MessageRecipients.Count() = 0 Then
		ChoiceData = SimilarRecipientsFromHistory(Text);
	Else
		ChoiceData = SimilarRecipientsFromPassedRecipients(Text);
	EndIf;
	
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientPostalAddressesBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	RowData = Item.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	Address = EmailAddressFromPresentation(RowData.Presentation);
	
	If IsBlankString(Address) Then
		Address = RowData.Presentation;
	EndIf;
	
	If IsBlankString(Address) Then
		Return;
	EndIf;
	
	If Not CommonClientServer.EmailAddressMeetsRequirements(Address, True) Then
		ShowMessageBox(, NStr("en = 'Please specify a correct email address.';"));
		Cancel = True;
		Return;
	EndIf;
	
	Duplicates = New Map;
	For Each EmailRecipient In RecipientsMailAddresses Do
		MailAddr = EmailAddressFromPresentation(EmailRecipient.Presentation);
		If Duplicates[Upper(MailAddr)] = Undefined Then
			Duplicates.Insert(Upper(MailAddr), True);
		Else
			ShowMessageBox(, NStr("en = 'This email address already exists.';"));
			Cancel = True;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion


#Region FormTableItemsEventHandlersAttachments

// Removes an attachment from the list and also calls the function
// that updates the table of attachment presentations.
//
&AtClient
Procedure AttachmentsBeforeDeleteRow(Item, Cancel)
	
	AttachmentDescription = Item.CurrentData[Item.CurrentItem.Name];
	
	For Position = -Attachments.Count() + 1 To 0 Do
		If Attachments.Get(-Position).Presentation = AttachmentDescription Then
			Attachments.Delete(-Position);
		EndIf;
	EndDo;
	
	RefreshAttachmentPresentation();
	
EndProcedure

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	
	Cancel = True;
	AddFileToAttachments();
	
EndProcedure

&AtClient
Procedure AttachmentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ValueCollection = DragParameters.Value;
	If TypeOf(ValueCollection) <> Type("Array") Then
		ValueCollection = CommonClientServer.ValueInArray(DragParameters.Value);
	EndIf;
	
	FilesToUpload = New Array;
	For Each File In ValueCollection Do
		If TypeOf(File) = Type("FileRef") Then
			FilesToUpload.Add(File);
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(FilesToUpload) Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("OnImportAttachments", ThisObject);
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	ImportParameters.Interactively = False;
	FileSystemClient.ImportFiles(NotifyDescription, ImportParameters, FilesToUpload);
	
EndProcedure

&AtClient
Procedure ReplyToAddressTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	FillReplyToAddressAutomatically = False;
	ReplyToAddress = GetNormalizedEmailInFormat(Text);
	
EndProcedure

&AtClient
Procedure ReplyToAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	FillReplyToAddressAutomatically = False;
	
EndProcedure

&AtClient
Procedure ReplyToAddressClearing(Item, StandardProcessing)

	StandardProcessing = False;
	SaveReplyTo(ReplyToAddress, False);
	
	For Position = -Items.ReplyToAddress.ChoiceList.Count() + 1 To 0 Do
		ReplyToItem = Items.ReplyToAddress.ChoiceList.Get(-Position);
		If ReplyToItem.Value = ReplyToAddress
		   And ReplyToItem.Presentation = ReplyToAddress Then
			Items.ReplyToAddress.ChoiceList.Delete(-Position);
		EndIf;
	EndDo;
	
	ReplyToAddress = "";
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenFile(Command)
	OpenAttachment();
EndProcedure

&AtClient
Procedure SendMail()
	
	ClearMessages();
	HasWrongRecipients = False;
	MessageSent = False;
	
	If Not FieldsFilledCorrectly() Then
		Return;
	EndIf;
	
	Try
		MessageSent = SendEmailMessage(HasWrongRecipients);
	Except
		ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		ErrorTitle = NStr("en = 'The message is not sent';");
		EmailOperationsClient.ReportConnectionError(Account, ErrorTitle, ErrorText);
		Return;
	EndTry;
	
	If MessageSent Then
		SaveReplyTo(ReplyToAddress);
		FormClosingConfirmationRequired = False;
		
		ShowUserNotification(NStr("en = 'Message sent:';"), ,
			?(IsBlankString(EmailSubject), NStr("en = '<No subject>';"), EmailSubject), PictureLib.DialogInformation);
		
		If HasWrongRecipients Then
			ShowMessageBox(, NStr("en = 'The message is not sent to some recipients.';"));
		Else
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Function FieldsFilledCorrectly()
	Result = True;
	
	If RecipientsMailAddresses.Count() = 0 Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify at least one recipient.';"), , "RecipientsMailAddresses");
		Result = False;
	EndIf;
	For Each EmailRecipient1 In RecipientsMailAddresses Do
		Address = EmailAddressFromPresentation(EmailRecipient1.Presentation);
		If IsBlankString(Address) Then
			CommonClient.MessageToUser(
				NStr("en = 'Please specify at least one recipient.';"),, "RecipientsMailAddresses[" + Format(RecipientsMailAddresses.IndexOf(EmailRecipient1), "NG=0") + "].Presentation");
			Result = False;
		ElsIf Not CommonClientServer.EmailAddressMeetsRequirements(Address, False) Then
			CommonClient.MessageToUser(
				NStr("en = 'Invalid email address.';"),, "RecipientsMailAddresses[" + Format(RecipientsMailAddresses.IndexOf(EmailRecipient1), "NG=0") + "].Presentation");
			Result = False;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure AttachFileExecute()
	
	AddFileToAttachments();
	
EndProcedure

&AtClient
Procedure ImportanceHigh(Command)
	EmailImportance = EmailOperationsInternalClientServer.InternetMailMessageImportanceHigh();
	Items.SeverityGroup.Picture = PictureLib.ImportanceHigh;
	Items.SeverityGroup.ToolTip = NStr("en = 'High importance';");
	Modified = True;
EndProcedure

&AtClient
Procedure ImportanceNormal(Command)
	EmailImportance = EmailOperationsInternalClientServer.InternetMailMessageImportanceStandard();
	Items.SeverityGroup.Picture = PictureLib.ImportanceNotSpecified;
	Items.SeverityGroup.ToolTip = NStr("en = 'Normal importance';");
	Modified = True;
EndProcedure

&AtClient
Procedure ImportanceLow(Command)
	EmailImportance = EmailOperationsInternalClientServer.InternetMailMessageImportanceLow();
	Items.SeverityGroup.Picture = PictureLib.ImportanceLow;
	Items.SeverityGroup.ToolTip = NStr("en = 'Low importance';");
	Modified = True;
EndProcedure

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure GenerateFromTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		Notification = New NotifyDescription("FillByTemplateAfterTemplateChoice", ThisObject);
		MessageSubject = ?(ValueIsFilled(SubjectOf), SubjectOf, "Shared");
		ModuleMessageTemplatesClient.PrepareMessageFromTemplate(MessageSubject, "MailMessage", Notification);
	EndIf
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#Region Private

&AtServer
Function SendEmailMessage(HasWrongRecipients)
	
	EmailParameters = GenerateEmailParameters();
	If EmailParameters = Undefined Then
		Return False;
	EndIf;
	
	MailMessage = EmailOperations.PrepareEmail(Account, EmailParameters);
	SendingResult = EmailOperations.SendMail(Account, MailMessage);
	EmailOperationsOverridable.AfterEmailSending(EmailParameters);
	
	AddRecipientsToHistory(EmailParameters.Whom);
	
	WrongRecipients = SendingResult.WrongRecipients;
	If WrongRecipients.Count() > 0 Then
		For Each WrongRecipient In WrongRecipients Do
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1: %2';"),
				WrongRecipient.Key, WrongRecipient.Value);
				
			Field = "RecipientsMailAddresses";
			For Each RecipientAddress In RecipientsMailAddresses Do
				If StrFind(RecipientAddress.Presentation, WrongRecipient.Key) > 0 Then
					Field = Field + "[" + XMLString(RecipientsMailAddresses.IndexOf(RecipientAddress)) + "].Presentation";
					Break;
				EndIf;
			EndDo;
				
			Common.MessageToUser(ErrorText, , Field);
		EndDo;
		
		HasWrongRecipients = True;
		Return RecipientsMailAddresses.Count() > WrongRecipients.Count();
	EndIf;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function GetEmailAddressByAccount(Val Account)
	
	Return TrimAll(Account.UserName)
			+ ? (IsBlankString(TrimAll(Account.UserName)),
					Account.Email,
					" <" + Account.Email + ">");
	
EndFunction

&AtClient
Procedure OpenAttachment()
	
	SelectedAttachment = SelectedAttachment();
	If SelectedAttachment = Undefined Then
		Return;
	EndIf;
	
#If Not WebClient Then
	If StrEndsWith(SelectedAttachment.Presentation, ".mxl") Then
		NotifyDescription = New NotifyDescription("ContinueOpeningMXLFileAfterCreateDirectory", ThisObject, SelectedAttachment);
		FileSystemClient.CreateTemporaryDirectory(NotifyDescription);
		Return;
	EndIf;
#EndIf
	
	FileSystemClient.OpenFile(SelectedAttachment.AddressInTempStorage, , SelectedAttachment.Presentation);
	
EndProcedure

&AtClient
Procedure ContinueOpeningMXLFileAfterCreateDirectory(TempDirectoryName, SelectedAttachment) Export
	
#If Not WebClient Then
	TempFileName = CommonClientServer.AddLastPathSeparator(TempDirectoryName) 
		+ SelectedAttachment.Presentation;
	SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(SelectedAttachment.AddressInTempStorage);
	
	BinaryData = GetFromTempStorage(SelectedAttachment.AddressInTempStorage); // BinaryData
	BinaryData.Write(TempFileName);
	File = New File(TempFileName);
	File.SetReadOnly(True);
	
	FormParameters = StandardSubsystemsClient.SpreadsheetEditorParameters();
	FormParameters.DocumentName = SelectedAttachment.Presentation;
	FormParameters.PathToFile = TempFileName;
	
	StandardSubsystemsClient.ShowSpreadsheetEditor(SpreadsheetDocument, FormParameters);
#EndIf
	
EndProcedure

&AtClient
Function SelectedAttachment()
	
	Result = Undefined;
	If Items.Attachments.CurrentData <> Undefined Then
		AttachmentDescription = Items.Attachments.CurrentData[Items.Attachments.CurrentItem.Name];
		For Each Attachment In Attachments Do
			If Attachment.Presentation = AttachmentDescription Then
				Result = New Structure("Presentation, AddressInTempStorage");
				FillPropertyValues(Result, Attachment);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetSpreadsheetDocumentByBinaryData(Val BinaryData)
	
	If TypeOf(BinaryData) = Type("String") Then
		// Transferring binary data address to temporary storage.
		BinaryData = GetFromTempStorage(BinaryData); // BinaryData
	EndIf;
	
	FileName = GetTempFileName("mxl");
	BinaryData.Write(FileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(FileName);
	
	Try
		DeleteFiles(FileName);
	Except
		WriteLogEvent(NStr("en = 'Get spreadsheet document';", Common.DefaultLanguageCode()), EventLogLevel.Error, , , 
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return SpreadsheetDocument;
	
EndFunction

&AtClient
Procedure AddFileToAttachments()
	
	NotifyDescription = New NotifyDescription("AddFileToAttachmentsOnPutFiles", ThisObject);
	
	ImportParameters = FileSystemClient.FileImportParameters();
	ImportParameters.FormIdentifier = UUID;
	FileSystemClient.ImportFiles(NotifyDescription, ImportParameters);
	
EndProcedure

&AtClient
Procedure AddFileToAttachmentsOnPutFiles(PlacedFiles, AdditionalParameters) Export
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		Return;
	EndIf;
	AddFilesToList(PlacedFiles);
	RefreshAttachmentPresentation();
	FormClosingConfirmationRequired = True;
EndProcedure

&AtServer
Procedure AddFilesToList(PlacedFiles)
	
	For Each FileDetails In PlacedFiles Do
		File = New File(FileDetails.Name);
		Attachment = Attachments.Add();
		Attachment.Presentation = File.Name;
		Attachment.AddressInTempStorage = PutToTempStorage(GetFromTempStorage(FileDetails.Location), UUID);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshAttachmentPresentation()
	
	AttachmentsPresentation.Clear();
	
	IndexOf = 0;
	
	For Each Attachment In Attachments Do
		If IndexOf = 0 Then
			PresentationRow = AttachmentsPresentation.Add();
		EndIf;
		
		PresentationRow["Attachment" + Format(IndexOf + 1, "NG=0")] = Attachment.Presentation;
		If Items.Attachment2.Visible Then // For mobile client.
			IndexOf = IndexOf + 1;
			If IndexOf = 2 Then 
				IndexOf = 0;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Checks whether it is possible to send the email.
// If it is possible, sending parameters are generated.
//
&AtServer
Function GenerateEmailParameters()
	
	EmailParameters = New Structure;
	Whom = New Array;
	Cc = New Array;
	BCCs = New Array;
	
	For Each Recipient In RecipientsMailAddresses Do
		RecipientsEmailAddr = CommonClientServer.EmailsFromString(Recipient.Presentation);
		For Each RecipientEmailAddr In RecipientsEmailAddr Do
			If Recipient.SendingOption = "HiddenCopy" Then
				BCCs.Add(New Structure("Address, Presentation", RecipientEmailAddr.Address, RecipientEmailAddr.Alias));
			ElsIf Recipient.SendingOption = "Copy" Then
				Cc.Add(New Structure("Address, Presentation", RecipientEmailAddr.Address, RecipientEmailAddr.Alias));
			Else
				Whom.Add(New Structure("Address, Presentation", RecipientEmailAddr.Address, RecipientEmailAddr.Alias));
			EndIf;
		EndDo;
	EndDo;
	
	If Whom.Count() > 0 Then
		EmailParameters.Insert("Whom", Whom);
	EndIf;
	If Cc.Count() > 0 Then
		EmailParameters.Insert("Cc", Cc);
	EndIf;
	If BCCs.Count() > 0 Then
		EmailParameters.Insert("BCCs", BCCs);
	EndIf;
	
	RecipientsList = CommonClientServer.EmailsFromString(ReplyToAddress);
	Whom = New Array;
	For Each Recipient In RecipientsList Do
		If Not IsBlankString(Recipient.ErrorDescription) Then
			Common.MessageToUser(
				Recipient.ErrorDescription, , "ReplyToAddress");
			Return Undefined;
		EndIf;
		Whom.Add(New Structure("Address, Presentation", Recipient.Address, Recipient.Alias));
	EndDo;
	
	If ValueIsFilled(ReplyToAddress) Then
		EmailParameters.Insert("ReplyToAddress", ReplyToAddress);
	EndIf;
	
	If ValueIsFilled(EmailSubject) Then
		EmailParameters.Insert("Subject", EmailSubject);
	EndIf;
	
	If ValueIsFilled(RecipientDetailsInTempStorage) Then
		EmailParameters.Insert("MessageRecipients", GetFromTempStorage(RecipientDetailsInTempStorage));
	EndIf;
	
	EmailParameters.Insert("Body", EmailBody);
	EmailParameters.Insert("Attachments", Attachments());
	EmailParameters.Insert("Importance", ?(ValueIsFilled(EmailImportance),
		EmailOperationsInternal.InternetMailMessageImportanceFromString(EmailImportance), InternetMailMessageImportance.Normal));
	
	Return EmailParameters;
	
EndFunction

&AtServer
Function HTMLWrappedText(Text)
	
	If StrFind(Lower(Text), "</html>", SearchDirection.FromEnd) > 0 Then
		Return Text;
	EndIf;
	
	HTMLDocument = New HTMLDocument;
	
	ItemBody = HTMLDocument.CreateElement("body");
	HTMLDocument.Body = ItemBody;
	
	For LineNumber = 1 To StrLineCount(Text) Do
		String = StrGetLine(Text, LineNumber);
		
		ItemBlock = HTMLDocument.CreateElement("p");
		ItemBody.AppendChild(ItemBlock);
		
		Item_Text = HTMLDocument.CreateTextNode(String);
		ItemBlock.AppendChild(Item_Text);
	EndDo;
	
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(HTMLDocument, HTMLWriter);
	Result = HTMLWriter.Close();
	
	Return Result;
	
EndFunction

&AtServer
Function Attachments()
	
	Result = New Array;
	For Each Attachment In Attachments Do
		AttachmentDetails = New Structure;
		AttachmentDetails.Insert("Presentation", Attachment.Presentation);
		AttachmentDetails.Insert("AddressInTempStorage", Attachment.AddressInTempStorage);
		AttachmentDetails.Insert("Encoding", Attachment.Encoding);
		AttachmentDetails.Insert("Id", Attachment.Id);
		Result.Add(AttachmentDetails);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure DetermineEmailAttachmentPurpose(Attachment, AttachmentsForEmail)
	
	If Attachment.Property("Id") And ValueIsFilled(Attachment.Id) Then
		PictureAttachment = New Picture(GetFromTempStorage(Attachment.AddressInTempStorage));
		AttachmentsForEmail.Insert(Attachment.Presentation, PictureAttachment);
	Else
		AttachmentDetails = Attachments.Add();
		FillPropertyValues(AttachmentDetails, Attachment);
		If Not IsBlankString(AttachmentDetails.AddressInTempStorage) Then
			AttachmentDetails.AddressInTempStorage = PutToTempStorage(
			GetFromTempStorage(AttachmentDetails.AddressInTempStorage), UUID);
		EndIf;
	EndIf;

EndProcedure

&AtServerNoContext
Procedure SaveReplyTo(Val ReplyToAddress, Val AddAddressToList = True)
	
	// Getting the list of addresses that the user previously used.
	ReplyToList = Common.CommonSettingsStorageLoad(
		"EditNewEmailMessage",
		"ReplyToList");
	
	If ReplyToList = Undefined Then
		ReplyToList = New ValueList();
	EndIf;
	
	For Position = -ReplyToList.Count() + 1 To 0 Do
		ItemReplyTo = ReplyToList.Get(-Position);
		If ItemReplyTo.Value = ReplyToAddress
		   And ItemReplyTo.Presentation = ReplyToAddress Then
			ReplyToList.Delete(-Position);
		EndIf;
	EndDo;
	
	If AddAddressToList
	   And ValueIsFilled(ReplyToAddress) Then
		ReplyToList.Insert(0, ReplyToAddress, ReplyToAddress);
	EndIf;
	
	Common.CommonSettingsStorageSave(
		"EditNewEmailMessage",
		"ReplyToList",
		ReplyToList);
	
EndProcedure

&AtClient
Function GetNormalizedEmailInFormat(Text)
	AddressesAsString = "";
	Addresses = CommonClientServer.EmailsFromString(Text);
	
	If Addresses.Count() > 1 Then
		CommonClient.MessageToUser(
			NStr("en = 'Please specify a single reply-to address.';"), , "ReplyToAddress");
		Return Text;
	EndIf;
	
	For Each AddrDetails In Addresses Do
		If Not IsBlankString(AddrDetails.ErrorDescription) Then
			CommonClient.MessageToUser(AddrDetails.ErrorDescription, , "ReplyToAddress");
		EndIf;
		
		If Not IsBlankString(AddressesAsString) Then
			AddressesAsString = AddressesAsString + "; ";
		EndIf;
		AddressesAsString = AddressesAsString + AddressAsString(AddrDetails);
	EndDo;
	
	Return AddressesAsString;
EndFunction

&AtClient
Function AddressAsString(AddrDetails)
	Result = "";
	If IsBlankString(AddrDetails.Alias) Then
		Result = AddrDetails.Address;
	Else
		If IsBlankString(AddrDetails.Address) Then
			Result = AddrDetails.Alias;
		Else
			Result = StringFunctionsClientServer.SubstituteParametersToString(
				"%1 <%2>", AddrDetails.Alias, AddrDetails.Address);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Procedure OnImportAttachments(Files, AdditionalParameters) Export
	
	If Files = Undefined Then
		Return;
	EndIf;
	
	AddFilesToList(Files);
	RefreshAttachmentPresentation();
	FormClosingConfirmationRequired = True;
	
EndProcedure

&AtClient
Procedure ImportAttachmentsFromFiles()
	
	For Each Attachment In Attachments Do
		If Not IsBlankString(Attachment.PathToFile) Then
			BinaryData = New BinaryData(Attachment.PathToFile);
			Attachment.AddressInTempStorage = PutToTempStorage(BinaryData, UUID);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowQueryBoxBeforeCloseForm()
	QueryText = NStr("en = 'The message is not yet sent. Do you want to close the window?';");
	NotifyDescription = New NotifyDescription("CloseFormConfirmed", ThisObject);
	Buttons = New ValueList;
	Buttons.Add("Close", NStr("en = 'Close';"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en = 'Do not close';"));
	ShowQueryBox(NotifyDescription, QueryText, Buttons,,
		DialogReturnCode.Cancel, NStr("en = 'Send message';"));
EndProcedure

&AtClient
Procedure CloseFormConfirmed(QuestionResult, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	FormClosingConfirmationRequired = False;
	Close();
	
EndProcedure

&AtClient
Procedure SaveAsTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplatesClientServer = CommonClient.CommonModule("MessageTemplatesClientServer");
		TemplateParameters = ModuleMessageTemplatesClientServer.TemplateParametersDetails();
		ModuleMessageTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		TemplateParameters.Subject = EmailSubject;
		TemplateParameters.Text = EmailBody.GetText();
		TemplateParameters.TemplateType = "MailMessage";
		ModuleMessageTemplatesClient.ShowTemplateForm(TemplateParameters);
	EndIf;
	
EndProcedure

// Parameters:
//  Result - See MessageTemplatesInternal.GenerateMessage
//  AdditionalParameters - Arbitrary
//
&AtClient
Procedure FillByTemplateAfterTemplateChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		EmailSubject = Result.Subject;
		SetEmailTextAndAttachments(Result.Text, Result.Attachments);
		RefreshAttachmentPresentation();
		
		If TypeOf(Result.Recipient) = Type("ValueList") Then
			For Each Recipient In Result.Recipient Do
				RecipientAddress                 = RecipientsMailAddresses.Add();
				RecipientAddress.SendingOption = "Whom";
				RecipientAddress.Presentation   = Recipient.Presentation;
			EndDo;
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetEmailTextAndAttachments(Text, AttachmentsStructure)
	
	HTMLAttachments = New Structure();
	If TypeOf(AttachmentsStructure) = Type("Array") Then
		For Each Attachment In AttachmentsStructure Do
			DetermineEmailAttachmentPurpose(Attachment, HTMLAttachments);
		EndDo;
	EndIf;
		
	EmailBody.SetHTML(Text, HTMLAttachments);
	
EndProcedure

&AtClient
Function EmailAddressFromPresentation(Val Presentation)
	
	Address = Presentation;
	PositionStart = StrFind(Presentation, "<");
	If PositionStart > 0 Then
		PositionEnd1 = StrFind(Presentation, ">", SearchDirection.FromBegin, PositionStart);
		If PositionEnd1 > 0 Then
			Address = Mid(Presentation, PositionStart + 1, PositionEnd1 - PositionStart - 1);
		EndIf;
	EndIf;
	
	Return TrimAll(Address);

EndFunction

&AtServer
Procedure FillRecipientsTableFromStructuresArray(MessageRecipientParameters)
	
	For Each RecipientParameters In MessageRecipientParameters Do
		If ValueIsFilled(RecipientParameters.Address) Then
			Address = StrReplace(RecipientParameters.Presentation, ",", " ") + " < "+ RecipientParameters.Address + ">";
			
			If RecipientParameters.Property("EmailAddressKind") 
				And ValueIsFilled(RecipientParameters.EmailAddressKind) Then
				Presentation = Address + " (" + RecipientParameters.EmailAddressKind + ")";
			ElsIf RecipientParameters.Property("ContactInformationSource")
				And ValueIsFilled(RecipientParameters.ContactInformationSource) Then
				Presentation = Address + " (" + String(RecipientParameters.ContactInformationSource) + ")";
			Else
				Presentation = Address;
			EndIf;
			MessageRecipients.Add(Address, Presentation);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillRecipientsTableFromRow(Val MessageRecipientParameters)
	
	MessageRecipientParameters = CommonClientServer.EmailsFromString(MessageRecipientParameters);
	
	For Each RecipientParameters In MessageRecipientParameters Do
		If ValueIsFilled(RecipientParameters.Address) Then
			MessageRecipients.Add(RecipientParameters.Address, RecipientParameters.Alias);
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure ClearAttachments(AttachmentAddresses)
	For Each AttachmentAddress In AttachmentAddresses Do
		DeleteFromTempStorage(AttachmentAddress);
	EndDo;
EndProcedure

&AtServerNoContext
Procedure AddRecipientsToHistory(EmailRecipients)
	
	RecipientsHistory = RecipientsHistory();
	For Each Recipient In EmailRecipients Do
		RecipientsHistory.Insert(Recipient.Address, Recipient.Presentation);
	EndDo;
	
	Common.CommonSettingsStorageSave("EditNewEmailMessage", "RecipientsHistory", RecipientsHistory);
	
EndProcedure

&AtServerNoContext
Function RecipientsHistory()
	
	Return Common.CommonSettingsStorageLoad("EditNewEmailMessage", "RecipientsHistory", New Map);
	
EndFunction

&AtClient
Function AddressPresentation(Address, RecipientPresentation1)
	Result = Address;
	If Not IsBlankString(RecipientPresentation1) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString("%1 <%2>", RecipientPresentation1, Address);
	EndIf;
	Return Result;
EndFunction

&AtClient
Function SimilarRecipientsFromHistory(String)
	
	Result = New ValueList;
	If StrLen(String) = 0 Then
		Return Result;
	EndIf;
	
	If RecipientsHistory = Undefined Then
		RecipientsHistory = RecipientsHistory();
	EndIf;
	
	For Each Recipient In RecipientsHistory Do
		AddressPresentation = AddressPresentation(Recipient.Key, Recipient.Value);
		Position = StrFind(Lower(AddressPresentation), Lower(String));
		If Position > 0 Then
			SubstringBeforeOccurence = Left(AddressPresentation, Position - 1);
			OccurenceSubstring = Mid(AddressPresentation, Position, StrLen(String));
			SubstringAfterOccurence = Mid(AddressPresentation, Position + StrLen(String));
			HighlightedString = New FormattedString(
				SubstringBeforeOccurence,
				New FormattedString(OccurenceSubstring, StyleFontImportantLabelFont(), SuccessResultColor),
				SubstringAfterOccurence);
			Result.Add(AddressPresentation, HighlightedString);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Function SimilarRecipientsFromPassedRecipients(Val Text)
	
	Result = New ValueList;
	
	AddressesList = New Array;
	For Each TableRow In RecipientsMailAddresses Do
		Address = EmailAddressFromPresentation(TableRow.Presentation);
		If ValueIsFilled(Address) Then
			AddressesList.Add(Upper(Address));
		EndIf;
	EndDo;
	
	PresentationSelect = New FormattedString(Text, StyleFontImportantLabelFont(), SuccessResultColor);
	TextLength = StrLen(Text);
	For Each Mail In MessageRecipients Do
		Address = EmailAddressFromPresentation(Mail.Value);
		If AddressesList.Find(Upper(Address)) = Undefined Then
			Position = StrFind(Mail.Value, Text);
			If Position > 0 Then
				Presentation= New FormattedString(Left(Mail.Presentation, Position - 1), PresentationSelect, Mid(Mail.Presentation, Position + TextLength));
				Result.Add(Mail.Value, Presentation);
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Function StyleFontImportantLabelFont()
	Return CommonClient.StyleFont("ImportantLabelFont");
EndFunction
	

#EndRegion
