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
	
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	FillPropertyValues(ThisObject,Parameters,, "CloseOnChoice, CloseOnOwnerClose, ReadOnly");
	MailMessage = Parameters.MailMessage;
	Items.BaseEmailPrintGroup.Visible = DoNotCallPrintCommand;
	
	SetHTMLEmailText(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	GenerateFormTitle(MailMessage);
	GenerateBaseEmailString();
	
	If Attachments.Count() > 0 And DisplayEmailAttachments Then
		Items.Attachments.Visible = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure HTMLTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure HTMLTextDocumentComplete(Item)
	
	If Not DoNotCallPrintCommand 
		And Not PrintDialogFormOnOpenOpened Then
		Items.HTMLText.Document.execCommand("Print");
		PrintDialogFormOnOpenOpened = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure BaseEmailDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	If FormattedStringURL = "OpenAttachment"
		And EmailBasis <> Undefined Then
		
		ShowValue(, EmailBasis);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		SetHTMLEmailText();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAttachments

&AtClient
Procedure AttachmentsSelection(Item, RowSelected, Field, StandardProcessing)
	
	OpenEmailAttachment();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Print(Command)
	
	Items.HTMLText.Document.execCommand("Print");
	
EndProcedure

&AtClient
Procedure OpenAttachment(Command)
	
	OpenEmailAttachment();
	
EndProcedure

&AtClient
Procedure SaveAttachment(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	
	If CurrentData = Undefined Then
		
		Return;
		
	EndIf;
	
	FileNameParts = FileDescriptionAndExtensionByFileName(CurrentData.FileName);
	
	FileData = New Structure;
	FileData.Insert("RefToBinaryFileData",        CurrentData.AddressInTempStorage);
	FileData.Insert("RelativePath",                  "");
	FileData.Insert("UniversalModificationDate",       "");
	FileData.Insert("FileName",                           CurrentData.FileName);
	FileData.Insert("Description",                       FileNameParts.Description);
	FileData.Insert("Extension",                         FileNameParts.Extension);
	FileData.Insert("Size",                             CurrentData.Size);
	FileData.Insert("BeingEditedBy",                        Undefined);
	FileData.Insert("SignedWithDS",                         False);
	FileData.Insert("Encrypted",                         False);
	FileData.Insert("FileBeingEdited",                  False);
	FileData.Insert("CurrentUserEditsFile", False);
	
	FilesOperationsClient.SaveFileAs(FileData);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenEmailAttachment()
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.IsAttachmentEmail Then
		InteractionsClient.OpenAttachmentEmail(CurrentData.AddressInTempStorage, EmailAttachmentOpenParameters(), ThisObject);
		
	ElsIf ValueIsFilled(CurrentData.Ref) Then
		
		If InteractionsClient.IsEmail(CurrentData.Ref)
			Or InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
			InteractionsClient.OpenAttachmentEmail(CurrentData.Ref, EmailAttachmentOpenParameters(), ThisObject);
		Else
			EmailManagementClient.OpenAttachment(CurrentData.Ref, ThisObject);
		EndIf;
		
	Else
		FileSystemClient.OpenFile(CurrentData.AddressInTempStorage);
	EndIf;

EndProcedure

&AtServer
Function EmptyTableRecipients()

	RowTypeDetails = New TypeDescription("String",,New StringQualifiers(100));
	
	TableRecipients = New ValueTable();
	TableRecipients.Columns.Add("Address", RowTypeDetails);
	TableRecipients.Columns.Add("Presentation", RowTypeDetails);
	
	Return TableRecipients;
	
EndFunction

&AtServer
Procedure FillAttachmentsAndGenerateHTMLTextBasedOnAttachmentEmail(AttachmentEmail)
	
	Attachments.Clear();
	AttachmentsWithIDs.Clear();
	
	NewMailMessage = New InternetMailMessage;
	
	If IsTempStorageURL(AttachmentEmail) Then
		RawData = GetFromTempStorage(AttachmentEmail);
	Else
		RawData = FilesOperations.FileBinaryData(AttachmentEmail);
	EndIf;
	
	NewMailMessage.SetSourceData(RawData);
	
	If NewMailMessage.ParseStatus = InternetMailMessageParseStatus.ErrorsDetected Then
		Common.MessageToUser(NStr("en = 'Cannot parse the message.';"));
		Return;
	EndIf;
	
	EmailRecipients = EmptyTableRecipients();
	EmailManagement.FillInternetEmailAddresses(EmailRecipients, NewMailMessage.To);
	CCRecipients  = EmptyTableRecipients();
	EmailManagement.FillInternetEmailAddresses(CCRecipients, NewMailMessage.To);
	
	EmailStructure = New Structure("TextType, HTMLText, Text");
	EmailStructure.Insert("Encoding",                    NewMailMessage.Encoding);
	EmailStructure.Insert("SenderPresentation",     NewMailMessage.SenderName);
	EmailStructure.Insert("SenderAddress",             NewMailMessage.From.Address);
	EmailStructure.Insert("Date",                         NewMailMessage.PostingDate);
	EmailStructure.Insert("Subject",                         NewMailMessage.Subject);
	EmailStructure.Insert("EmailRecipients",             EmailRecipients);
	EmailStructure.Insert("CCRecipients",              CCRecipients);
	UserAccountUsername = ?(IsBlankString(UserAccountUsername),
	                                 UserAccountUserNameOfEmailByAttachment(AttachmentEmail),
	                                 UserAccountUsername);
	EmailStructure.Insert("UserAccountUsername", UserAccountUsername);
	
	EmailSubject = NewMailMessage.Subject;
	EmailDate = NewMailMessage.PostingDate;
	
	For Each Attachment In NewMailMessage.Attachments Do
		
		If Not IsBlankString(Attachment.CID) 
			And StrFind(EmailStructure.HTMLText, Attachment.Name) = 0 Then
			
			NewRow = AttachmentsWithIDs.Add();
			NewRow.Description              = Attachment.FileName;
			NewRow.Ref                    = PutToTempStorage(Attachment.Data, UUID);
			NewRow.EmailFileID = Attachment.CID;
			NewRow.Extension                = CommonClientServer.GetFileNameExtension(Attachment.FileName);
			
			Continue;
			
		EndIf;
		
		NewRow = Attachments.Add();
		NewRow.FileName = Attachment.FileName;
		Extension = CommonClientServer.GetFileNameExtension(NewRow.FileName);
		If TypeOf(Attachment.Data) = Type("BinaryData") Then
			
			NewRow.PictureIndex    = FilesOperationsInternalClientServer.IndexOfFileIcon(Extension);
			AttachmentData                = Attachment.Data;
			NewRow.IsAttachmentEmail = EmailManagement.FileIsEmail(NewRow.FileName, AttachmentData);
			
		Else
			
			AttachmentData                = Attachment.Data.GetSourceData();
			NewRow.FileName          = Attachment.Data.Subject + ".eml";
			NewRow.PictureIndex    = FilesOperationsInternalClientServer.IndexOfFileIcon("eml");
			NewRow.IsAttachmentEmail = True;
			
		EndIf;
		
		NewRow.AddressInTempStorage = PutToTempStorage(AttachmentData, UUID);
		NewRow.SizePresentation       = InteractionsClientServer.GetFileSizeStringPresentation(AttachmentData.Size());
		
	EndDo;
	
	EmailStructure.Insert("Attachments", AttachmentsWithIDs);
	
	EmailManagement.SetEmailText(EmailStructure, NewMailMessage);
	
	GenerationParameters = Interactions.HTMLDocumentGenerationParametersOnEmailBasis(EmailStructure);
	GenerationParameters.MailMessage = EmailStructure;
	GenerationParameters.DisableExternalResources = Not EnableUnsafeContent;
	
	HTMLDocument = Interactions.GenerateHTMLDocumentBasedOnEmail(GenerationParameters, HasUnsafeContent);
	
	Interactions.AddPrintFormHeaderToEmailBody(HTMLDocument, EmailStructure, True);
	
	If Attachments.Count() > 0 Then
		Interactions.AddAttachmentFooterToEmailBody(HTMLDocument, Attachments);
	EndIf;
	
	HTMLText = Interactions.GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
	
EndProcedure

&AtServer
Function UserAccountUserNameOfEmailByAttachment(AttachmentEmail)
	
	Query = New Query;
	Query.Text = "
	|SELECT ALLOWED
	|	EmailAccounts.UserName AS UserName,
	|	EmailAccounts.Description
	|FROM
	|	Catalog.IncomingEmailAttachedFiles AS AttachedFilesInMessage
	|		INNER JOIN Document.IncomingEmail AS EmailMessage
	|			INNER JOIN Catalog.EmailAccounts AS EmailAccounts
	|			ON EmailMessage.Account = EmailAccounts.Ref
	|		ON AttachedFilesInMessage.FileOwner = EmailMessage.Ref
	|WHERE
	|	AttachedFilesInMessage.Ref = &Attachment";
	
	If TypeOf(AttachmentEmail) = Type("CatalogRef.OutgoingEmailAttachedFiles") Then
		
		Query.Text = StrReplace(Query.Text,
		                           "Catalog.IncomingEmailAttachedFiles",
		                           "Catalog.OutgoingEmailAttachedFiles");
		Query.Text = StrReplace(Query.Text,
		                           "Document.IncomingEmail", 
		                           "Document.OutgoingEmail");
		
	ElsIf  TypeOf(AttachmentEmail) <> Type("CatalogRef.IncomingEmailAttachedFiles") Then
		Return "";
	EndIf;
	
	Query.SetParameter("Attachment", AttachmentEmail);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return ?(IsBlankString(Selection.UserName), Selection.Description, Selection.UserName);
	EndIf;
	
	Return "";
	
EndFunction

&AtServer
Procedure GenerateAttachmensTableForStoredEmail(MailMessage)

	If Not DisplayEmailAttachments Then
		Return;
	EndIf;
	
	AttachmentTable = EmailManagement.GetEmailAttachments(MailMessage, True, True);
	For Each AttachmentsTableRow In AttachmentTable Do
		If IsBlankString(AttachmentsTableRow.EmailFileID) Then
			NewRow = Attachments.Add();
			NewRow.Ref              = AttachmentsTableRow.Ref;
			NewRow.FileName            = AttachmentsTableRow.FileName;
			NewRow.PictureIndex      = AttachmentsTableRow.PictureIndex;
			NewRow.Size              = AttachmentsTableRow.Size;
			NewRow.SizePresentation = AttachmentsTableRow.SizePresentation;
		EndIf;
	EndDo;
	
	If TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		AttachmentEmailsTable = Interactions.DataStoredInAttachmentsEmailsDatabase(MailMessage);
		
		For Each AttachmentEmail In AttachmentEmailsTable Do
			
			EmailPresentation = Interactions.EmailPresentation(AttachmentEmail.Subject, AttachmentEmail.Date);
			
			NewRow = Attachments.Add();
			NewRow.Ref               = AttachmentEmail.MailMessage;
			NewRow.FileName             = EmailPresentation;
			NewRow.PictureIndex       = FilesOperationsInternalClientServer.IndexOfFileIcon("eml");
			NewRow.SignedWithDS           = False;
			NewRow.Size               = AttachmentEmail.Size;
			NewRow.SizePresentation  = InteractionsClientServer.GetFileSizeStringPresentation(NewRow.Size)
			
		EndDo;
		
	EndIf;

	
	Attachments.Sort("FileName");

EndProcedure

&AtServer
Procedure GenerateFormTitle(MailMessage)

	If Not DoNotCallPrintCommand Then
		Return;
	EndIf;
	
	If TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		
		EmailAttributes = Common.ObjectAttributesValues(MailMessage, "DateReceived, Subject");
		EmailSubject = EmailAttributes.Subject;
		EmailDate = EmailAttributes.DateReceived;
		
	ElsIf TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		EmailAttributes = Common.ObjectAttributesValues(MailMessage, "PostingDate, Date , Subject");
		EmailSubject = EmailAttributes.Subject;
		EmailDate = ?(ValueIsFilled(EmailAttributes.PostingDate), EmailAttributes.PostingDate, EmailAttributes.Date);
		
	EndIf;
	
	Title = Interactions.EmailPresentation(EmailSubject, EmailDate);
	
EndProcedure

&AtClient
Function EmailAttachmentOpenParameters()

	AttachmentParameters = InteractionsClient.EmailAttachmentParameters();
	AttachmentParameters.BaseEmailDate = EmailDate;
	AttachmentParameters.BaseEmailSubject = EmailSubject;
	
	Return AttachmentParameters;

EndFunction

&AtServer
Procedure GenerateBaseEmailString();

	If Not DoNotCallPrintCommand Then
		
		Return;
		
	EndIf;
	
	StringHeader = New FormattedString(NStr("en = 'Mail attachment:';"));
	EmailPresentation = Interactions.EmailPresentation( BaseEmailSubject, BaseEmailDate);
	If EmailBasis = Undefined Then
		StringText = New FormattedString(EmailPresentation);
	Else
		StringText = New FormattedString(EmailPresentation, ,
			StyleColors.HyperlinkColor, , "OpenAttachment");
	EndIf;

	Items.BaseEmailDecoration.Title = New FormattedString(StringHeader, " ", StringText);
	
EndProcedure

&AtClient
Function FileDescriptionAndExtensionByFileName(Val FileName)
	
	Result = New Structure;
	Result.Insert("Extension",   "");
	Result.Insert("Description", "");
	
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		
		Result.Extension   = RowsArray[RowsArray.Count() - 1];
		Result.Description = Left(FileName, StrLen(FileName) - StrLen(Result.Extension) - 1);
	Else
		Result.Description = FileName;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetSecurityWarningVisiblity()
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	Items.SecurityWarning.Visible = Not UnsafeContentDisplayInEmailsProhibited
		And HasUnsafeContent And Not EnableUnsafeContent;
EndProcedure

&AtServer
Procedure SetHTMLEmailText(Cancel = Undefined)
	
	If TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		
		HTMLText = Interactions.GenerateHTMLTextForIncomingEmail(MailMessage, True, False, Not EnableUnsafeContent, HasUnsafeContent);
		GenerateAttachmensTableForStoredEmail(MailMessage);
		
	ElsIf TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		HTMLText = Interactions.GenerateHTMLTextForOutgoingEmail(MailMessage, True, False, Not EnableUnsafeContent, HasUnsafeContent);
		GenerateAttachmensTableForStoredEmail(MailMessage);
		
	ElsIf TypeOf(MailMessage) = Type("CatalogRef.IncomingEmailAttachedFiles")
		     Or TypeOf(MailMessage) = Type("CatalogRef.OutgoingEmailAttachedFiles")
		     Or IsTempStorageURL(MailMessage) Then
		
		FillAttachmentsAndGenerateHTMLTextBasedOnAttachmentEmail(MailMessage);
		
	Else
		
		Cancel = True;
		
	EndIf;
	
	SetSecurityWarningVisiblity();
	
EndProcedure

#EndRegion
