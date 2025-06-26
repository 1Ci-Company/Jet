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
Var ChoiceContext;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Disable creation of new mail messages.
	If Not ValueIsFilled(Object.Ref) Then
		Cancel = True;
		Return;
	EndIf;
	
	Object.HTMLText = CommonClientServer.ReplaceProhibitedXMLChars(Object.HTMLText);
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	Interactions.SetEmailFormHeader(ThisObject);
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	DoDisplayImportance();
	
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	If Reviewed Then
		Items.ReviewAfter.Enabled = False;
	EndIf;
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	If Object.Ref.IsEmpty() Then
		Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	EndIf;
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	EnableUnsafeContent = False;
	
	Object.HTMLText = CommonClientServer.ReplaceProhibitedXMLChars(Object.HTMLText);
	
	Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	
	Attachments.Clear();
	AttachmentTable = EmailManagement.GetEmailAttachments(Object.Ref, True);
	
	If AttachmentTable.Count() > 0 Then
		
		FoundRows = AttachmentTable.FindRows(New Structure("EmailFileID", ""));
		CommonClientServer.SupplementTable(FoundRows, Attachments);
		
	EndIf;
	
	For Each DeletedAttachment In CurrentObject.PendingAttachments Do
		
		NewAttachment = Attachments.Add();
		NewAttachment.FileName = DeletedAttachment.NameAttachment;
		NewAttachment.PictureIndex = FilesOperationsInternalClientServer.IndexOfFileIcon(".msg") + 1;
		
	EndDo;
	
	If Attachments.Count() = 0 Then
		
		Items.Attachments.Visible = False;
		
	EndIf;
	
	If Object.TextType = Enums.EmailTextTypes.HTML Then
		ReadHTMLEmailText();
		Items.EmailText.Type = FormFieldType.HTMLDocumentField;
		Items.EmailText.ReadOnly = False;
	Else
		EmailText = Object.Text;
		Items.EmailText.Type = FormFieldType.TextDocumentField;
	EndIf;
	SetSecurityWarningVisiblity();
	
	SenderPresentation = InteractionsClientServer.GetAddresseePresentation(
		Object.SenderPresentation, Object.SenderAddress,"");
	
	// Generating the To and CC presentation.
	RecipientsPresentation =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	CCRecipientsPresentation =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	ReplyRecipientsPresentation = 
		InteractionsClientServer.GetAddressesListPresentation(Object.ReplyRecipients, False);
		
	If IsBlankString(CCRecipientsPresentation) Then
		Items.CCRecipientsPresentation.Visible = False;
	EndIf;

	FillAdditionalInformation();
	
	ProcessReadReceiptNecessity();
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "IncomingEmail");
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	InteractionsClient.DoProcessNotification(ThisObject, EventName, Parameter, Source);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.ContactsClarification") Then
		
		If TypeOf(ValueSelected) <> Type("Array") Then
			Return;
		EndIf;
		
		FillClarifiedContacts(ValueSelected);
		ContactsChanged = True;
		Modified = True;
		
	Else
		
		InteractionsClient.ChoiceProcessingForm(ThisObject, ValueSelected, ChoiceSource, ChoiceContext);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode, PostingMode)
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
	If Reviewed And ReceiptSendingFlagRequired Then
		SetNotificationSendingFlag(Object.Ref, True);
	EndIf;
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DetailsPagesAdditionalOnCurrentPageChange(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		And CurrentPage.Name = "AdditionalAttributesPage"
		And Not PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ReviewAfterChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(ReviewAfter,
	                                                          ValueSelected,
	                                                          StandardProcessing,
	                                                          Modified);
	
EndProcedure

&AtClient
Procedure ReviewedOnChange(Item)
	
	Items.ReviewAfter.Enabled = Not Reviewed;
	If Reviewed And ReadReceiptRequestRequired Then
		
		OnCloseNotifyHandler = New NotifyDescription("PromptForSendingReadReceiptAfterCompletion", ThisObject);
		ShowQueryBox(OnCloseNotifyHandler,
		       NStr("en = 'Sender has requested a read receipt. Do you want to send a receipt?';"),
		       QuestionDialogMode.YesNo,
		       ,
		       DialogReturnCode.Yes,
		       NStr("en = 'Read receipt request';"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditRecipients()
	
	SendersArray = New Array;
	SendersArray.Add(New Structure("Address,Presentation,Contact",
		Object.SenderAddress,
		Object.SenderPresentation, 
		Object.SenderContact));
	
	RecipientsList = New ValueList;
	RecipientsList.Add(SendersArray, "Sender");
	RecipientsList.Add(
		EmailManagementClient.ContactsTableToArray(Object.EmailRecipients), "Recipients");
	RecipientsList.Add(
		EmailManagementClient.ContactsTableToArray(Object.CCRecipients),  "Cc");
	RecipientsList.Add(
		EmailManagementClient.ContactsTableToArray(Object.ReplyRecipients), "Response");
	
	FormParameters = New Structure;
	FormParameters.Insert("Account", Object.Account);
	FormParameters.Insert("SelectedItemsList", RecipientsList);
	FormParameters.Insert("SubjectOf", SubjectOf);
	FormParameters.Insert("MailMessage", Object.Ref);
	
	OpenForm("CommonForm.ContactsClarification", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillClarifiedContacts(Result)
	
	Object.CCRecipients.Clear();
	Object.ReplyRecipients.Clear();
	Object.EmailRecipients.Clear();
	
	For Each ArrayElement In Result Do
	
		If ArrayElement.Group = "Recipients" Then
			TableOfRecipients = Object.EmailRecipients;
		ElsIf ArrayElement.Group = "Cc" Then
			TableOfRecipients = Object.CCRecipients;
		ElsIf ArrayElement.Group = "Response" Then
			TableOfRecipients = Object.ReplyRecipients;
		ElsIf ArrayElement.Group = "Sender" Then
			Object.SenderAddress = ArrayElement.Address;
			Object.SenderContact = ArrayElement.Contact;
			Continue;
		Else
			Continue;
		EndIf;
		
		RowRecipients = TableOfRecipients.Add();
		FillPropertyValues(RowRecipients,ArrayElement);
	
	EndDo;
	
	SenderPresentation = InteractionsClientServer.GetAddresseePresentation(
		Object.SenderPresentation, Object.SenderAddress, "");
	
	// Generating the To and CC presentation.
	RecipientsPresentation       =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	CCRecipientsPresentation  =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	ReplyRecipientsPresentation = 
		InteractionsClientServer.GetAddressesListPresentation(Object.ReplyRecipients, False);
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "IncomingEmail");

EndProcedure

&AtClient
Procedure SenderPresentationOpening(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Object.SenderContact) Then
		ShowValue(, Object.SenderContact);
	Else
		EditRecipients();
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure SubjectOfStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectOfStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		ReadHTMLEmailText();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAttachments

&AtClient
Procedure AttachmentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure AttachmentsOnActivateRow(Item)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	AttachmentExists = ValueIsFilled(CurrentData.Ref);
	Items.AttachmentsContextMenuAttachmentProperties.Enabled = AttachmentExists;
	Items.OpenAttachment.Enabled = AttachmentExists;
	Items.SaveAttachment.Enabled = AttachmentExists;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenAttachmentExecute()
	
	OpenAttachment();
	
EndProcedure

&AtClient
Procedure SaveAttachmentExecute()
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
		
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
		
	FileData = FilesOperationsClient.FileData(CurrentData.Ref, UUID);
	FilesOperationsClient.SaveFileAs(FileData);
	
EndProcedure

&AtClient
Procedure SpecifyContacts(Command)
	
	EditRecipients();
	
EndProcedure

&AtClient
Procedure EmailParameters(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("CreatedOn",             Object.Date);
	FormParameters.Insert("ReceivedEmails",            Object.DateReceived);
	FormParameters.Insert("RequestDeliveryReceipt",  Object.RequestDeliveryReceipt);
	FormParameters.Insert("RequestReadReceipt", Object.RequestReadReceipt);
	FormParameters.Insert("InternetTitles",  Object.InternalTitle);
	FormParameters.Insert("MailMessage",              Object.Ref);
	FormParameters.Insert("EmailType",           "IncomingEmail");
	FormParameters.Insert("Encoding",           Object.Encoding);
	FormParameters.Insert("InternalNumber",     Object.Number);
	FormParameters.Insert("Account",       Object.Account);
	
	OpenForm("DocumentJournal.Interactions.Form.EmailMessageParameters", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure LinkedInteractionsExecute()
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterObject", Object.SubjectOf);
	
	OpenForm("DocumentJournal.Interactions.ListForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeEncoding(Command)
	
	EncodingsList = EncodingsList();
	OnCloseNotifyHandler = New NotifyDescription("SelectEncodingAfterCompletion", ThisObject);
	EncodingsList.ShowChooseItem(OnCloseNotifyHandler,
		NStr("en = 'Select encoding';"), EncodingsList.FindByValue(Lower(Object.Encoding)));
	
EndProcedure 

&AtClient
Procedure AttachmentProperties(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
	
	FormParameters = New Structure("ReadOnly", True);
	FilesOperationsClient.OpenFileForm(CurrentData.Ref, );
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure OpenAttachment()
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Ref) Then
		Return;
	EndIf;
		
	If InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
		AttachmentParameters = InteractionsClient.EmailAttachmentParameters();
		AttachmentParameters.BaseEmailDate = Object.DateReceived;
		AttachmentParameters.EmailBasis     = Object.Ref;
		AttachmentParameters.BaseEmailSubject = Object.Subject;
		InteractionsClient.OpenAttachmentEmail(CurrentData.Ref, AttachmentParameters, ThisObject);
	Else
		EmailManagementClient.OpenAttachment(CurrentData.Ref, ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure TransformEmailEncoding(SelectedEncoding)
	
	TempFileName = GetTempFileName();
	TextWriter = New TextWriter(TempFileName, Object.Encoding);
	TextWriter.Write(
		?(Object.TextType = Enums.EmailTextTypes.HTML, Object.HTMLText, Object.Text));
	TextWriter.Close();
	
	TextReader = New TextReader(TempFileName, SelectedEncoding);
	If Object.TextType = Enums.EmailTextTypes.HTML Then
		Object.HTMLText = TextReader.Read();
		EmailText = Object.HTMLText;
		Interactions.FilterHTMLTextContent(EmailText, SelectedEncoding, Not EnableUnsafeContent, HasUnsafeContent);
	Else
		Object.Text = TextReader.Read();
		EmailText = Object.Text;
	EndIf;
	TextReader.Close();
	DeleteFiles(TempFileName);
	
	TempFileName = GetTempFileName();
	TextWriter = New TextWriter(TempFileName, Object.Encoding);
	TextWriter.WriteLine(SenderPresentation);
	TextWriter.WriteLine(CCRecipientsPresentation);
	TextWriter.WriteLine(ReplyRecipientsPresentation);
	TextWriter.WriteLine(RecipientsPresentation);
	TextWriter.WriteLine(Object.Subject);
	TextWriter.Close();
	
	TextReader = New TextReader(TempFileName, SelectedEncoding);
	SenderPresentation = TextReader.ReadLine();
	CCRecipientsPresentation = TextReader.ReadLine();
	ReplyRecipientsPresentation = TextReader.ReadLine();
	RecipientsPresentation = TextReader.ReadLine();
	Object.Subject = TextReader.ReadLine();
	TextReader.Close();
	DeleteFiles(TempFileName);
	
	Object.Encoding = SelectedEncoding;
	
EndProcedure

&AtServer
Procedure FillAdditionalInformation()
	
	AdditionalInformationAboutEmail = NStr("en = 'Created on:';") + "   " + Object.Date 
	+ Chars.LF + NStr("en = 'Received';") + ":  " + Object.DateReceived 
	+ Chars.LF + NStr("en = 'Importance';") + ":  " + Object.Importance
	+ Chars.LF + NStr("en = 'Encoding';") + ": " + Object.Encoding;
	
EndProcedure

&AtServer
Procedure DoDisplayImportance()

	Items.DecorationImportance.Visible = True;

	If Object.Importance = Enums.InteractionImportanceOptions.High Then
		Items.DecorationImportance.Picture = PictureLib.ImportanceHigh;
		Items.DecorationImportance.ToolTip = NStr("en = 'High importance';");
		
	ElsIf Object.Importance = Enums.InteractionImportanceOptions.Low Then
		Items.DecorationImportance.Picture = PictureLib.ImportanceLow;
		Items.DecorationImportance.ToolTip = NStr("en = 'Low importance';");
		
	Else
		Items.DecorationImportance.Picture = PictureLib.ImportanceNotSpecified;
		Items.DecorationImportance.ToolTip = NStr("en = 'Normal importance';");
		Items.DecorationImportance.Visible = False;
	EndIf;

EndProcedure

&AtServer
Procedure ProcessReadReceiptNecessity()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReadReceipts.MailMessage
	|FROM
	|	InformationRegister.ReadReceipts AS ReadReceipts
	|WHERE
	|	ReadReceipts.MailMessage = &MailMessage
	|	AND (NOT ReadReceipts.SendingRequired)";
	
	Query.SetParameter("MailMessage",Object.Ref);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	NecessaryAction = Interactions.GetUserParametersForIncomingEmail();
	
	If NecessaryAction = Enums.ReplyToReadReceiptPolicies.AlwaysSendReadReceipt Then
		
		ReceiptSendingFlagRequired = True;
		
	ElsIf NecessaryAction = 
		Enums.ReplyToReadReceiptPolicies.NeverSendReadReceipt Then
		
		EmailManagement.SetNotificationSendingFlag(Object.Ref,False);
		
	ElsIf NecessaryAction = 
		Enums.ReplyToReadReceiptPolicies.AskBeforeSendReadReceipt Then
		
		ReadReceiptRequestRequired = True;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetNotificationSendingFlag(Ref, Flag)

	EmailManagement.SetNotificationSendingFlag(Ref, Flag)

EndProcedure

&AtClient
Procedure PromptForSendingReadReceiptAfterCompletion(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		SetNotificationSendingFlag(Object.Ref, True);
	ElsIf QuestionResult = DialogReturnCode.No Then
		SetNotificationSendingFlag(Object.Ref, False);
	EndIf;
	ReadReceiptRequestRequired = False;
	
EndProcedure

&AtClient
Procedure SelectEncodingAfterCompletion(SelectedElement, AdditionalParameters) Export

	If SelectedElement <> Undefined Then
		TransformEmailEncoding(SelectedElement.Value);
	EndIf;

EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

&AtClient
Function EncodingsList()
	
	EncodingsList = New ValueList;
	
	EncodingsList.Add("ibm852",       NStr("en = 'IBM852 (DOS Central European)';"));
	EncodingsList.Add("ibm866",       NStr("en = 'IBM866 (DOS Cyrillic Russian)';"));
	EncodingsList.Add("iso-8859-1",   NStr("en = 'ISO-8859-1 (ISO Western Europe)';"));
	EncodingsList.Add("iso-8859-2",   NStr("en = 'ISO-8859-2 (ISO Central European)';"));
	EncodingsList.Add("iso-8859-3",   NStr("en = 'ISO-8859-3 (ISO Latin 3)';"));
	EncodingsList.Add("iso-8859-4",   NStr("en = 'ISO-8859-4 (ISO Baltic)';"));
	EncodingsList.Add("iso-8859-5",   NStr("en = 'ISO-8859-5 (ISO Cyrillic)';"));
	EncodingsList.Add("iso-8859-7",   NStr("en = 'ISO-8859-7 (ISO Greek)';"));
	EncodingsList.Add("iso-8859-9",   NStr("en = 'ISO-8859-9 (ISO Turkish)';"));
	EncodingsList.Add("iso-8859-15",  NStr("en = 'ISO-8859-15 (ISO Latin 9)';"));
	EncodingsList.Add("koi8-r",       NStr("en = 'KOI8-R (KOI8-R Cyrillic)';"));
	EncodingsList.Add("koi8-u",       NStr("en = 'KOI8-U (KOI8-U Cyrillic)';"));
	EncodingsList.Add("us-ascii",     NStr("en = 'US-ASCII (USA)';"));
	EncodingsList.Add("utf-8",        NStr("en = 'UTF-8 (Unicode UTF-8)';"));
	EncodingsList.Add("windows-1250", NStr("en = 'Windows-1250 (Central European)';"));
	EncodingsList.Add("windows-1251", NStr("en = 'Windows-1251 (Windows Cyrillic)';"));
	EncodingsList.Add("windows-1252", NStr("en = 'Windows-1252 (Western European)';"));
	EncodingsList.Add("windows-1253", NStr("en = 'Windows-1253 (Windows Greek)';"));
	EncodingsList.Add("windows-1254", NStr("en = 'Windows-1254 (Windows Turkish)';"));
	EncodingsList.Add("windows-1257", NStr("en = 'Windows-1257 (Windows Baltic)';"));
	
	Return EncodingsList;

EndFunction

&AtServer
Procedure SetSecurityWarningVisiblity()
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	Items.SecurityWarning.Visible = Not UnsafeContentDisplayInEmailsProhibited
		And HasUnsafeContent And Not EnableUnsafeContent;
EndProcedure

&AtServer
Procedure ReadHTMLEmailText()
	EmailText = Interactions.ProcessHTMLText(Object.Ref, Not EnableUnsafeContent, HasUnsafeContent);
	SetSecurityWarningVisiblity();
EndProcedure

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure

// End StandardSubsystems.AttachableCommands

#EndRegion
