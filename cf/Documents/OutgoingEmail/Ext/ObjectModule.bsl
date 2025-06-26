///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.Interactions

// It is called when filling a document on the basis.
//
// Parameters:
//  Contacts  - Array - an array containing interaction participants.
//
Procedure FillContacts(Contacts) Export
	
	If Not Interactions.ContactsFilled(Contacts) Then
		Return;
	EndIf;
	
	For Each TableRow In Contacts Do
		
		Address = Undefined;
		
		If TypeOf(TableRow) = Type("Structure") Then
			// Only those contacts which have their email addresses specified will get to the document.
			AddressesArray = StrSplit(TableRow.Address, ",");
			For Each AddressesArrayElement In AddressesArray Do
				Try
					Result = CommonClientServer.ParseStringWithEmailAddresses(AddressesArrayElement);
				Except
					// The row with email addresses is entered incorrectly.
					Continue;
				EndTry;
				If Result.Count() > 0 And Not IsBlankString(Result[0]) Then
					Address = Result[0];
				EndIf;
				If Address <> Undefined Then
					Break;
				EndIf;
			EndDo;
			
			If Address = Undefined And ValueIsFilled(TableRow.Contact) Then
				DSAddressesArray = InteractionsServerCall.GetContactEmailAddresses(TableRow.Contact);
				If DSAddressesArray.Count() > 0 Then
					Address = New Structure("Address",DSAddressesArray[0].EMAddress);
				EndIf;
			EndIf;
			
			If Not Address = Undefined Then
				
				NewRow = EmailRecipients.Add();
				
				NewRow.Contact = TableRow.Contact;
				NewRow.Presentation = TableRow.Presentation;
				NewRow.Address = Address.Address;
			Else
				Continue;
			EndIf;
			
		Else
			NewRow = EmailRecipients.Add();
			NewRow.Contact = TableRow;
		EndIf;
		
		Interactions.FinishFillingContactsFields(NewRow.Contact, NewRow.Presentation,
			NewRow.Address, Enums.ContactInformationTypes.Email);
			
	EndDo;
	
	GenerateContactsPresentation();
	
EndProcedure

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// Parameters:
//   Table - See AccessManagement.AccessValuesSetsTable
//
Procedure FillAccessValuesSets(Table) Export
	
	InteractionsEvents.FillAccessValuesSets(ThisObject, Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
	TheDataObjectToWrite = TheDataObjectToWrite();
	
	AdditionalProperties.Insert("DeletionMark", TheDataObjectToWrite.DeletionMark);
	AdditionalProperties.Insert("EmailStatus",    TheDataObjectToWrite.EmailStatus);
	
	If DeletionMark <> TheDataObjectToWrite.DeletionMark Then
		HasAttachments = ?(DeletionMark, False, FilesOperationsInternalServerCall.AttachedFilesCount(Ref) > 0);
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Interactions.OnWriteDocument(ThisObject);
	Interactions.ProcessDeletionMarkChangeFlagOnWriteEmail(ThisObject);
	
	PreviousStatus = AdditionalProperties.EmailStatus;
	
	If ValueIsFilled(Account)
		And (EmailStatus = Enums.OutgoingEmailStatuses.Outgoing
		  Or EmailStatus = Enums.OutgoingEmailStatuses.Sent)
		And (PreviousStatus <> Enums.OutgoingEmailStatuses.Outgoing
		  And PreviousStatus <> Enums.OutgoingEmailStatuses.Sent) Then
		
		InformationRegisters.EmailAccountSettings.UpdateTheAccountUsageDate(Account);
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	EmailManagement.DeleteEmailAttachments(Ref);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
		IsTemplate1 = ModuleMessageTemplates.IsTemplate1(FillingData);
	Else
		IsTemplate1 = False;
	EndIf;
		
	If IsTemplate1 Then
		
		FillBasedOnTemplate(FillingData);
		
	ElsIf (TypeOf(FillingData) = Type("Structure")) And (FillingData.Property("Basis")) 
		 And (TypeOf(FillingData.Basis) = Type("DocumentRef.IncomingEmail") 
		 Or TypeOf(FillingData.Basis) = Type("DocumentRef.OutgoingEmail")) Then
		
		Interactions.FillDefaultAttributes(ThisObject, Undefined);
		FillBasedOnEmail(FillingData.Basis, FillingData.Command);
		
	Else
		Interactions.FillDefaultAttributes(ThisObject, FillingData);
		
	EndIf;
	
	Importance = Enums.InteractionImportanceOptions.Ordinary;
	EmailStatus = Enums.OutgoingEmailStatuses.Draft;
	If IsBlankString(Encoding) Then
		Encoding = "utf-8";
	EndIf;
	
	If Not ValueIsFilled(Account) Then
		Account = EmailManagement.GetAccountForDefaultSending();
	EndIf;
	SenderPresentation = GetPresentationForAccount(Account);
	
EndProcedure

#EndRegion

#Region Private

Procedure GenerateContactsPresentation()
	
	EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(EmailRecipients, False);
	CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(CCRecipients, False);
	BccRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(BccRecipients, False);
	
EndProcedure

Procedure FillBasedOnEmail(Basis, ReplyType)
	
	MoveSender = True;
	MoveAllRecipients = False;
	MoveAttachments = False;
	AddToSubject = "RE: ";
	
	If ReplyType = "ReplyToAll" Then
		MoveAllRecipients = True;
	ElsIf ReplyType = "ForwardMail" Then
		AddToSubject = "FW: ";
		MoveSender = False;
		MoveAttachments = True;
	ElsIf ReplyType = "ForwardAsAttachment" Then
		AddToSubject = "";
		MoveSender = False;
	EndIf;
	
	FillParametersFromEmail(Basis, MoveSender, MoveAllRecipients,
		AddToSubject, MoveAttachments,ReplyType);
	
EndProcedure

Procedure FillBasedOnTemplate(TemplateRef1)
	
	ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
	Message = ModuleMessageTemplates.GenerateMessage(TemplateRef1, Undefined, New UUID);
	
	If TypeOf(Message.Text) = Type("Structure") Then
		
		ResultText = Message.Text.HTMLText;
		AttachmentsStructure = Message.Text.AttachmentsStructure;
		HTMLEmail             = True;
		
	Else
		
		AttachmentsStructure = New Structure();
		ResultText = Message.Text;
		HTMLEmail = StrStartsWith(ResultText, "<!DOCTYPE html") Or StrStartsWith(ResultText, "<html");
		
	EndIf;
	
	If TypeOf(Message.Attachments) <> Undefined Then
		For Each Attachment In Message.Attachments Do
			
			If ValueIsFilled(Attachment.Id) Then
				Image = New Picture(GetFromTempStorage(Attachment.AddressInTempStorage));
				AttachmentsStructure.Insert(Attachment.Presentation, Image);
				ResultText = StrReplace(ResultText, "cid:" + Attachment.Id, Attachment.Presentation);
			EndIf;
		EndDo;
		
	EndIf;
	
	If HTMLEmail Then
		If AttachmentsStructure.Count() > 0 Then
			EmailBody = New Structure();
			EmailBody.Insert("HTMLText",         ResultText);
			EmailBody.Insert("AttachmentsStructure", AttachmentsStructure);
			HTMLText = PutToTempStorage(EmailBody);
		Else
			HTMLText = ResultText;
		EndIf;
		TextType = Enums.EmailTextTypes.HTML;
	Else
		Text     = ResultText;
		TextType = Enums.EmailTextTypes.PlainText;
	EndIf;
	Subject = Message.Subject;
	
EndProcedure

Function GetPresentationForAccount(Account)

	If Not ValueIsFilled(Account) Then
		Return "";
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT
	|	EmailAccounts.UserName,
	|	EmailAccounts.Email
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.Ref = &Account";
	Query.SetParameter("Account", Account);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Presentation = Selection.UserName;
	If IsBlankString(Presentation) Then
		Return Selection.Email;
	Else
		Return Presentation + " <" + Selection.Email + ">";
	EndIf;

EndFunction

Procedure AddRecipient(Address, Presentation, Contact)
	
	NewRow = EmailRecipients.Add();
	NewRow.Address = Address;
	NewRow.Contact = Contact;
	NewRow.Presentation = Presentation;
	
EndProcedure

Procedure AddRecipientsFromTable(Table)
	
	For Each TableRow In Table Do
		NewRow = EmailRecipients.Add();
		FillPropertyValues(NewRow, TableRow);
	EndDo;
	
EndProcedure

// Fills in the new email parameters from the base email.
// 
// Parameters:
//   MailMessage                                      - DocumentRef.IncomingEmail
//                                               - DocumentRef.OutgoingEmail - Parent email message.
//  MoveSenderToRecipients           - Boolean - indicates whether it is necessary to move the base email sender to
//                                                        an email message being created.
//  MoveAllEmailRecipientsToRecipients - Boolean - indicates whether it is necessary to move the base email recipients to
//                                                        an email message being created.
//  AddToSubject                             - String - the prefix to be added to the base email subject.
//  MoveAttachments                         - Boolean - indicates whether it is necessary to transfer attachments.
//  ReplyType                                  - String - a base email option.
//
Procedure FillParametersFromEmail(MailMessage, MoveSenderToRecipients,
	MoveAllEmailRecipientsToRecipients, AddToSubject, MoveAttachments, ReplyType)
	
	MetadataObjectName = MailMessage.Metadata().Name;
	TableName           = "Document." + MetadataObjectName;
	
	Query = New Query;
	Query.Text ="SELECT
	|	EmailMessage.MessageID,
	|	EmailMessage.BasisIDs,
	|	EmailMessage.Encoding,
	|	ISNULL(InteractionsFolderSubjects.SubjectOf, UNDEFINED) AS SubjectOf,
	|	EmailMessage.Subject,
	|	EmailMessage.Account,
	|	EmailMessage.TextType,
	|	EmailMessage.Ref
	|FROM
	|	&TableName AS EmailMessage
	|	LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON EmailMessage.Ref =  InteractionsFolderSubjects.Interaction
	|WHERE
	|	EmailMessage.Ref = &Ref";
	
	
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Ref", MailMessage);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	BasisID       = Selection.MessageID;
	BasisIDs      = TrimAll(Selection.BasisIDs + " <" + BasisID + ">");
	Encoding                    = Selection.Encoding;
	Subject                         = AddToSubject + Selection.Subject;
	Account                = Selection.Account;
	InteractionBasis      = Selection.Ref;
	IncludeOriginalEmailBody  = True;
	TextType                    = Selection.TextType;
	
	If MoveSenderToRecipients Then
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	IncomingEmail.SenderAddress         AS SenderAddress,
		|	IncomingEmail.SenderContact       AS SenderContact,
		|	IncomingEmail.SenderPresentation AS SenderPresentation
		|FROM
		|	Document.IncomingEmail AS IncomingEmail
		|WHERE
		|	IncomingEmail.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	EmailIncomingReplyRecipients.Address         AS Address,
		|	EmailIncomingReplyRecipients.Presentation AS Presentation,
		|	EmailIncomingReplyRecipients.Contact       AS Contact
		|FROM
		|	Document.IncomingEmail.ReplyRecipients AS EmailIncomingReplyRecipients
		|WHERE
		|	EmailIncomingReplyRecipients.Ref = &Ref";
		
		Query.SetParameter("Ref", MailMessage);
		
		Result = Query.ExecuteBatch();
		
		ThereAreRecipientsOfTheResponse = Not Result[1].IsEmpty();
		
		If ThereAreRecipientsOfTheResponse Then
			
			SampleRecipients = Result[1].Select();
			While SampleRecipients.Next() Do
				AddRecipient(SampleRecipients.Address, 
				                   SampleRecipients.Presentation, 
				                   SampleRecipients.Contact);
			EndDo;
			
		Else
			
			SelectionSender = Result[0].Select();
			SelectionSender.Next();
			
			AddRecipient(SelectionSender.SenderAddress,
			                   SelectionSender.SenderPresentation,
			                   SelectionSender.SenderContact);
			
		EndIf;

	EndIf;
	
	If MoveAllEmailRecipientsToRecipients Then
		
		Query.Text = "SELECT ALLOWED
		|	EmailAccounts.Email
		|INTO CurrentRecipientAddress
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref IN
		|			(SELECT
		|				EmailMessage.Account
		|			FROM
		|				&TheTableNameOfTheDocument AS EmailMessage
		|			WHERE
		|				EmailMessage.Ref = &Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EmailMessageMessageRecipients.Address,
		|	EmailMessageMessageRecipients.Presentation,
		|	EmailMessageMessageRecipients.Contact
		|FROM
		|	&NameOfTheMessageRecipientsTable AS EmailMessageMessageRecipients
		|WHERE
		|	EmailMessageMessageRecipients.Ref = &Ref
		|	AND (NOT EmailMessageMessageRecipients.Address IN
		|				(SELECT
		|					CurrentRecipientAddress.Email
		|				FROM
		|					CurrentRecipientAddress AS CurrentRecipientAddress))
		|
		|UNION ALL
		|
		|SELECT
		|	EmailMessageCCRecipients.Address,
		|	EmailMessageCCRecipients.Presentation,
		|	EmailMessageCCRecipients.Contact
		|FROM
		|	&NameOfTheCopyRecipientsTable AS EmailMessageCCRecipients
		|WHERE
		|	EmailMessageCCRecipients.Ref = &Ref
		|	AND (NOT EmailMessageCCRecipients.Address IN
		|				(SELECT
		|					CurrentRecipientAddress.Email
		|				FROM
		|					CurrentRecipientAddress AS CurrentRecipientAddress))";
		
		
		Query.Text = StrReplace(Query.Text, "&TheTableNameOfTheDocument",        "Document." + MetadataObjectName);
		Query.Text = StrReplace(Query.Text, "&NameOfTheMessageRecipientsTable", "Document." + MetadataObjectName + ".EmailRecipients");
		Query.Text = StrReplace(Query.Text, "&NameOfTheCopyRecipientsTable",  "Document." + MetadataObjectName + ".CCRecipients");

		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			AddRecipientsFromTable(QueryResult.Unload());
		EndIf;
		
	EndIf;
	
	EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(EmailRecipients, False);
	
EndProcedure

Function TheDataObjectToWrite()
	
	ObjectData = New Structure;
	ObjectData.Insert("DeletionMark", False);
	ObjectData.Insert("EmailStatus",    Enums.OutgoingEmailStatuses.EmptyRef());
	
	If Not IsNew() Then
		
		Query = New Query;
		Query.Text = "
		|SELECT
		|	OutgoingEmail.DeletionMark AS DeletionMark,
		|	OutgoingEmail.EmailStatus    AS EmailStatus
		|FROM
		|	Document.OutgoingEmail AS OutgoingEmail
		|WHERE
		|	OutgoingEmail.Ref = &Ref";
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			FillPropertyValues(ObjectData, Selection);
			
		EndIf;
		
	EndIf;
	
	Return ObjectData;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf