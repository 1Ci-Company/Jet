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

// Toggles the email client.
//
// Parameters:
//   Value - Boolean
//
Procedure SetEmailClientUsage(Val Value) Export

	Constants.UseEmailClient.Set(Value);

EndProcedure

// Checks whether the users can use the email client.
// 
// Returns:
//   Boolean
//
Function EmailClientUsed() Export
	
	Return GetFunctionalOption("UseEmailClient");
	
EndFunction

// Toggles the support of sending HTML messages.
// If disabled, the users can send only plain-text messages.
//
// Parameters:
//   Value - Boolean
//
Procedure EnableSendingHTMLEmailMessages(Val Value) Export

	Constants.SendEmailsInHTMLFormat.Set(Value);

EndProcedure

// Checks whether email messages can be sent as HTML.
//
// Returns:
//   Boolean
//
Function IsSendingHTMLEmailMessagesEnabled() Export

	Return GetFunctionalOption("SendEmailsInHTMLFormat");

EndFunction

// Toggles the support of tracking phone calls, text messages,
// appointments, and interaction planning.
//
// Parameters:
//   Value - Boolean
//
Procedure SetUsageOfOtherInteraction(Val Value) Export

	Constants.UseOtherInteractions.Set(Value);

EndProcedure

// Checks whether the users can track phone calls, text messages, appointments, and interaction planning.
//
// Returns:
//   Boolean
//
Function AreOtherInteractionsUsed() Export
	
	Return GetFunctionalOption("UseOtherInteractions");
	
EndFunction

// The procedure is called from document filling data handlers - interactions and filling objects.
// Fills in attributes with default values.
//
// Parameters:
//  Object - DocumentObject - a document to be filled.
//  FillingData  - Arbitrary - a value used as a filling base.
//
Procedure FillDefaultAttributes(Object, FillingData) Export
	
	IsInteraction = InteractionsClientServer.IsInteraction(Object.Ref);
	
	// The current user is the author and the person responsible for the interaction being created.
	If IsInteraction Then
		Object.Author = Users.CurrentUser();
		Object.EmployeeResponsible = Object.Author;
	EndIf;
	
	If FillingData = Undefined Then
		Return;
	EndIf;
	
	Contacts = Undefined;
	
	If IsContact(FillingData) And Not FillingData.IsFolder Then
		Contacts = New Array;
		Contacts.Add(FillingData);
		
	ElsIf InteractionsClientServer.IsSubject(FillingData) 
		Or InteractionsClientServer.IsInteraction(FillingData) Then
		ObjectManager = Common.ObjectManagerByRef(FillingData);
		Contacts = ObjectManager.GetContacts(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		If FillingData.Property("Contact") And ValueIsFilled(FillingData.Contact) Then
			Contacts = New Array;
			Contacts.Add(FillingData.Contact);
		EndIf;
		If FillingData.Property("SubjectOf") And ValueIsFilled(FillingData.SubjectOf) Then
			ObjectManager = Common.ObjectManagerByRef(FillingData.SubjectOf);
			If Not (FillingData.Property("Contact") And ValueIsFilled(FillingData.Contact)) Then
				Contacts = ObjectManager.GetContacts(FillingData.SubjectOf);
			EndIf;
		EndIf;
		If FillingData.Property("Account") And ValueIsFilled(FillingData.Account) Then
			Object.Account = FillingData.Account;
		EndIf;
		If FillingData.Property("MeetingPlace") And ValueIsFilled(FillingData.MeetingPlace) Then
			Object.MeetingPlace = FillingData.MeetingPlace;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Contacts) And (Contacts.Count() > 0) Then
		
		If TypeOf(Object) = Type("DocumentObject.PhoneCall")
			Or TypeOf(Object) = Type("DocumentObject.SMSMessage") Then
			
			ClearAddressRequired = False;
			
			If (TypeOf(FillingData) = Type("DocumentRef.IncomingEmail")
				Or TypeOf(FillingData) = Type("DocumentRef.OutgoingEmail")) Then
				ClearAddressRequired = True;
			EndIf;
			
			If TypeOf(FillingData) = Type("Structure")
				And FillingData.Property("SubjectOf")
				And (TypeOf(FillingData.SubjectOf) = Type("DocumentRef.IncomingEmail")
					Or TypeOf(FillingData.SubjectOf) = Type("DocumentRef.OutgoingEmail")) Then
				ClearAddressRequired = True;
			EndIf;
			
			If ClearAddressRequired Then
				For Each RowContact In Contacts Do
					If TypeOf(RowContact) = Type("Structure") Then
						If Not ValueIsFilled(RowContact.Contact) Then
							RowContact.Address = "";
						EndIf;
					EndIf;
				EndDo;
			EndIf;
			
		EndIf;
		
		Object.FillContacts(Contacts);
		
	EndIf;
	
EndProcedure

// Sets the created object as a subject in the interaction chain.
//
// Parameters:
//  SubjectOf        - DefinedType.InteractionSubject - a created interaction subject.
//  Interaction - DocumentRef - an interaction the subject is created by.
//  Cancel          - Boolean         - an interaction the subject is created by.
//
Procedure OnWriteSubjectFromForm(SubjectOf, Interaction, Cancel) Export
	
	If Not ValueIsFilled(Interaction)
		Or Not InteractionsClientServer.IsInteraction(Interaction) Then
		Return;
	EndIf;
	
	OldSubject = GetSubjectValue(Interaction);
	If SubjectOf = OldSubject Then
		// The subject has already been set
		Return;
	EndIf;
	
	// Getting the list of interactions whose subject requires changing.
	If ValueIsFilled(OldSubject)
		And InteractionsClientServer.IsInteraction(OldSubject) Then
		InteractionsForReplacement = InteractionsFromChain(OldSubject, Interaction);
	Else
		InteractionsForReplacement = New Array;
	EndIf;
	InteractionsForReplacement.Insert(0, Interaction);
	
	// Replacing a subject in all interactions.
	Block = New DataLock;
	InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, InteractionsForReplacement);
	Block.Lock();
	
	For Each InteractionHyperlink In InteractionsForReplacement Do
		SetSubject(InteractionHyperlink, SubjectOf);
	EndDo;
	
EndProcedure

// Prepares a notification upon creating an interaction document on the server.
//
// Parameters:
//  Form                                - ClientApplicationForm - a form the notification will be sent from.
//  Parameters                            - Structure        - parameters of creating an interaction document form.
//  UseInteractionBase  - Boolean           - indicates whether a base document is to be considered.
//
Procedure PrepareNotifications(Form, Parameters, UseInteractionBase = True) Export
	
	If Parameters.Property("Basis") And Parameters.Basis <> Undefined Then
		
		If InteractionsClientServer.IsInteraction(Parameters.Basis) Then
			
			Form.NotificationRequired = True;
			If UseInteractionBase  Then
				Form.InteractionBasis = Parameters.Basis;
			Else
				Form.BasisObject = Parameters.Basis;
			EndIf;
			
		ElsIf TypeOf(Parameters.Basis) = Type("Structure") 
			And Parameters.Basis.Property("Object") 
			And InteractionsClientServer.IsInteraction(Parameters.Basis.Object) Then
			
			Form.NotificationRequired = True;
			If UseInteractionBase  Then
				Form.InteractionBasis = Parameters.Basis.Object;
			Else
				Form.BasisObject = Parameters.Basis.Object;
			EndIf;
			
		ElsIf TypeOf(Parameters.Basis) = Type("Structure") 
			And (Parameters.Basis.Property("Basis") 
			And InteractionsClientServer.IsInteraction(Parameters.Basis.Basis)) Then

			Form.NotificationRequired = True;
			If UseInteractionBase  Then
				Form.InteractionBasis = Parameters.Basis.Basis;
			Else
				Form.BasisObject = Parameters.Basis.Basis;
			EndIf;
			
		EndIf;
		
	ElsIf Parameters.Property("FillingValues") And Parameters.FillingValues.Property("SubjectOf") Then
		Form.NotificationRequired = True;
	EndIf;
	
EndProcedure

// Sets an active subject flag.
//
// Parameters:
//  SubjectOf  - DocumentRef
//           - CatalogRef - Topic being recorded.
//  Running  - Boolean - indicates that the subject is active.
//
Procedure SetActiveFlag(SubjectOf, Running) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
	|	InteractionsSubjectsStates.LastInteractionDate,
	|	InteractionsSubjectsStates.Running
	|FROM
	|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
	|WHERE
	|	InteractionsSubjectsStates.SubjectOf = &SubjectOf";
	
	Query.SetParameter("SubjectOf",SubjectOf);
	
	RecordManager = InformationRegisters.InteractionsSubjectsStates.CreateRecordManager();
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		If Running = False Then
			Return;
		EndIf;
		
		RecordManager.LastInteractionDate = Date(1,1,1);
		RecordManager.NotReviewedInteractionsCount      = 0;
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		If Selection.Running = Running Then
			Return;
		EndIf;
		
		RecordManager.LastInteractionDate = Selection.LastInteractionDate;
		RecordManager.NotReviewedInteractionsCount      = Selection.NotReviewedInteractionsCount;
		
	EndIf;
	
	RecordManager.Running = Running;
	RecordManager.SubjectOf = SubjectOf;
	
	RecordManager.Write();

EndProcedure

// Fills in the sets of subsystem document access values with the default values. 
// To use in the InteractionsOverridable.OnFillingAccessValuesSets procedure.
// Using it, you can combine the applied set of subsystem document access values 
// with the default filling.
// 
// Parameters:
//  Object - DocumentObject.Meeting
//         - DocumentObject.PlannedInteraction
//         - DocumentObject.SMSMessage
//         - DocumentObject.PhoneCall
//         - DocumentObject.IncomingEmail
//         - DocumentObject.OutgoingEmail - Object whose sets will be populated.
//  Table - See AccessManagement.AccessValuesSetsTable
//
Procedure FillDefaultAccessValuesSets(Object, Table) Export

	If TypeOf(Object) = Type("DocumentObject.Meeting") 
		Or TypeOf(Object) = Type("DocumentObject.PlannedInteraction") 
		Or TypeOf(Object) = Type("DocumentObject.SMSMessage") 
		Or TypeOf(Object) = Type("DocumentObject.PhoneCall") Then
		
		// The default access restriction logic: The object is available if "Author" or "Assignee" is available.
		// Restriction by "EmailAccounts".
		
		SetNumber = 1;

		TabRow = Table.Add();
		TabRow.SetNumber     = SetNumber;
		TabRow.AccessValue = Object.Author;

		// Restrict by PersonResponsible.
		SetNumber = SetNumber + 1;

		TabRow = Table.Add();
		TabRow.SetNumber     = SetNumber;
		TabRow.AccessValue = Object.EmployeeResponsible;
		
	ElsIf TypeOf(Object) = Type("DocumentObject.IncomingEmail") Then
		
		// The default access restriction logic: The object is available if "Account" or "Assignee" is available.
		// Restriction by "EmailAccounts".
		
		SetNumber = 1;

		TabRow = Table.Add();
		TabRow.SetNumber     = SetNumber;
		TabRow.AccessValue = Object.Account;

		// Restrict by PersonResponsible.
		SetNumber = SetNumber + 1;

		TabRow = Table.Add();
		TabRow.SetNumber     = SetNumber;
		TabRow.AccessValue = Object.EmployeeResponsible;
		
	ElsIf TypeOf(Object) = Type("DocumentObject.OutgoingEmail") Then
		
		// The default access restriction logic: The object is available if "Account", "Assignee", or "Author" is available.
		// 

		SetNumber = 1;

		TableRow = Table.Add();
		TableRow.SetNumber     = SetNumber;
		TableRow.AccessValue = Object.Account;

		SetNumber = SetNumber + 1;

		TableRow = Table.Add();
		TableRow.SetNumber     = SetNumber;
		TableRow.AccessValue = Object.Author;

		SetNumber = SetNumber + 1;

		TableRow = Table.Add();
		TableRow.SetNumber     = SetNumber;
		TableRow.AccessValue = Object.EmployeeResponsible;
		
	EndIf;
	
EndProcedure

// Returns a topic.
// 
// Parameters:
//  Interaction - DocumentRef.Meeting,
//                 - DocumentRef.PlannedInteraction,
//                 - DocumentRef.PhoneCall,
//                 - DocumentRef.SMSMessage,
//                 - DocumentRef.IncomingEmail,
//                 - DocumentRef.OutgoingEmail
//
// Returns:
//  DefinedType.InteractionSubject
//
Function InteractionSubject(Interaction) Export
	
	Query = New Query;
	Query.SetParameter("Interaction", Interaction);
	Query.Text = 
		"SELECT
		|	InteractionsFolderSubjects.SubjectOf AS SubjectOf
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	InteractionsFolderSubjects.Interaction = &Interaction";
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	Return ?(QueryResult.IsEmpty(), Undefined, QueryResult.Unload().UnloadColumn("SubjectOf")[0]);
	
EndFunction

#EndRegion

#Region Internal

// Recalculates states of folders, contacts, and subjects.
//
Procedure PerformCompleteStatesRecalculation() Export
	
	CalculateReviewedByFolders(Undefined);
	CalculateReviewedByContacts(Undefined);
	CalculateReviewedBySubjects(Undefined);
	
EndProcedure

// Returns a list of topic participants by the specified contact information type.
// 
// Parameters:
//  SubjectOf - DefinedType.InteractionSubject - Topic whose contacts should be obtained.
//  ContactInformationTypes - Array of EnumRef.ContactInformationTypes - Contact information types that 
//                             should be obtained with the contacts.
// 
// Returns:
//  Array of Structure:
//    * Contact - DefinedType.InteractionContact
//    * Presentation - String
//    * Address - String
//
Function GetContactsBySubject(SubjectOf, ContactInformationTypes) Export
	
	EmailRecipients = New Array;
	If InteractionsClientServer.IsSubject(SubjectOf)
		Or InteractionsClientServer.IsInteraction(SubjectOf) Then
		
		ObjectManager = Common.ObjectManagerByRef(SubjectOf);
		Contacts = ObjectManager.GetContacts(SubjectOf);
		
		If Contacts <> Undefined Then
			For Each TableRow In Contacts Do
				
				Recipient = New Structure("Contact, Presentation, Address");
				Recipient.Contact = ?(TypeOf(TableRow) = Type("Structure"), TableRow.Contact, TableRow);
				
				FinishFillingContactsFields(Recipient.Contact, Recipient.Presentation,
					Recipient.Address, ContactInformationTypes);
				
				EmailRecipients.Add(Recipient);
				
			EndDo;
		EndIf;
		
	EndIf;
	
	Return EmailRecipients;
	
EndFunction

Procedure RegisterEmailAccountsToProcessingToMigrateToNewVersion(Parameters) Export
	
	QueryText =
	"SELECT
	|	EmailAccounts.Ref AS EmailAccount
	|FROM
	|	InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON EmailAccountSettings.EmailAccount = EmailAccounts.Ref
	|WHERE
	|	EmailAccountSettings.DeletePersonalAccount
	|	AND EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)";
	
	Query = New Query(QueryText);
	
	Result = Query.Execute().Unload();
	ReferencesArrray = Result.UnloadColumn("EmailAccount");
	
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.FullRegisterName = "InformationRegister.EmailAccountSettings";
	AdditionalParameters.IsIndependentInformationRegister = True;
	
	InfobaseUpdate.MarkForProcessing(Parameters, Result, AdditionalParameters);
	
EndProcedure

Function EmailAccountsOwners(Accounts_) Export
	
	Result = New Map;
	
	QueryText =
	"SELECT
	|	EmailAccounts.Ref AS Ref,
	|	EmailAccountSettings.EmployeeResponsibleForProcessingEmails AS AccountOwner
	|FROM
	|	InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON EmailAccountSettings.EmailAccount = EmailAccounts.Ref
	|WHERE
	|	EmailAccounts.Ref IN(&Accounts_)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Accounts_", Accounts_);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result.Insert(Selection.Ref, Selection.AccountOwner);
	EndDo;
	
	Return Result;
	
EndFunction

Procedure ClearPersonalAccountFlag(Account) Export
	
	RecordSet = InformationRegisters.EmailAccountSettings.CreateRecordSet();
	RecordSet.Filter.EmailAccount.Set(Account);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		For Each Record In RecordSet Do
			Record.DeletePersonalAccount = False;
		EndDo;
		InfobaseUpdate.WriteRecordSet(RecordSet); // ACC:1327 Call the procedure as a transaction with a lock.
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Message templates.

// Creates and sends an email message.
// 
// Parameters:
//  Message - See EmailParameters
//  Account - CatalogRef.EmailAccounts - an account to be used to send the email.
//  SendImmediately - Boolean - if False, the email message will be placed in the Outbox folder and sent with other email messages.
//
// Returns:
//   See EmailSendingResult
//
Function CreateEmail(Message, Account, SendImmediately = True) Export
	
	EmailSendingResult = EmailSendingResult();
	
	HTMLEmail = (Message.AdditionalParameters.EmailFormat1 = Enums.EmailEditingMethods.HTML);
	
	BeginTransaction();
	Try
		
		MailMessage = Documents.OutgoingEmail.CreateDocument();
		
		MailMessage.Author                    = Users.CurrentUser();
		MailMessage.EmployeeResponsible            = Users.CurrentUser();
		MailMessage.Date                     = CurrentSessionDate();
		
		If Message.Importance = InternetMailMessageImportance.High Then
			MailMessage.Importance = Enums.InteractionImportanceOptions.High;
		ElsIf Message.Importance = InternetMailMessageImportance.Low Then
			MailMessage.Importance = Enums.InteractionImportanceOptions.Low;
		Else	
			MailMessage.Importance = Enums.InteractionImportanceOptions.Ordinary;
		EndIf;
		MailMessage.Encoding                = "UTF-8";
		MailMessage.SenderPresentation = String(Account);
		
		If HTMLEmail Then
			
			MailMessage.HTMLText = Message.Text;
			MailMessage.Text     = GetPlainTextFromHTML(Message.Text);
			
		Else
			
			MailMessage.Text = Message.Text;
			
		EndIf;
		
		MailMessage.Subject = Message.Subject;
		MailMessage.TextType = ?(HTMLEmail, Enums.EmailTextTypes.HTML, Enums.EmailTextTypes.PlainText);
		MailMessage.Account = Account;
		MailMessage.InteractionBasis = Undefined;
		
		// Filling in the IncludeOriginalEmailBody, DisplaySourceEmailBody, RequestDeliveryReceipt, and RequestReadReceipt attributes.
		UserSettings = GetUserParametersForOutgoingEmail(
		                           Account, Message.AdditionalParameters.EmailFormat1, True);
		FillPropertyValues(MailMessage, UserSettings);    
		
		MailMessage.RequestDeliveryReceipt  = Max(Message.AdditionalParameters.RequestDeliveryReceipt, MailMessage.RequestDeliveryReceipt);   
		MailMessage.RequestReadReceipt = Max(Message.AdditionalParameters.RequestReadReceipt, MailMessage.RequestReadReceipt);

		
		MailMessage.DeleteAfterSend = False;
		
		MailMessage.Comment = Message.AdditionalParameters.Comment;
		
		For Each EmailRecipient In Message.Recipients Do
			NewRow = MailMessage["EmailRecipients"].Add();
			NewRow.Address         = EmailRecipient.Address;
			NewRow.Presentation = EmailRecipient.Presentation;
			NewRow.Contact       = EmailRecipient.ContactInformationSource;
		EndDo;
		
		For Each ReplyRecipient In Message.ReplyRecipients Do
			NewRow = MailMessage["ReplyRecipients"].Add();
			NewRow.Address         = ReplyRecipient.Address;
			NewRow.Presentation = ReplyRecipient.Presentation;
			NewRow.Contact       = ReplyRecipient.ContactInformationSource;
		EndDo;
		
		For Each BccRecipient In Message.BccRecipients Do
			NewRow = MailMessage["BccRecipients"].Add();
			NewRow.Address         = BccRecipient.Address;
			NewRow.Presentation = BccRecipient.Presentation;
			NewRow.Contact       = BccRecipient.ContactInformationSource;
		EndDo;
		
		MailMessage.EmailRecipientsList    = InteractionsClientServer.GetAddressesListPresentation(MailMessage.EmailRecipients, False);
		MailMessage.EmailStatus = ?(Common.FileInfobase(),
			Enums.OutgoingEmailStatuses.Draft,
			Enums.OutgoingEmailStatuses.Outgoing);
		
		MailMessage.HasAttachments = (Message.Attachments.Count() > 0);
		AttachmentsSize  = 0;
		AttachmentsSizes = New Map;
		For Each Attachment In Message.Attachments Do
			
			Size = GetFromTempStorage(Attachment.AddressInTempStorage).Size() * 1.5;
			AttachmentsSize = AttachmentsSize + Size;
			AttachmentsSizes.Insert(Attachment.AddressInTempStorage, Size);
			
			// If ID characters are not English, the email may be processed incorrectly.
			If ValueIsFilled(Attachment.Id) Then
				Id = StringFunctions.LatinString(Attachment.Id);
				If StrFind(MailMessage.HTMLText, "cid:" + Attachment.Id) > 0 Then
					MailMessage.HTMLText = StrReplace(MailMessage.HTMLText, "cid:" + Attachment.Id, "cid:" + Id);
				Else
					MailMessage.HTMLText = StrReplace(MailMessage.HTMLText, Attachment.Id, "cid:" + Id);
				EndIf;
				Attachment.Id = Id;
			EndIf;
			
		EndDo;
		
		MailMessage.Size = AttachmentsSize + StrLen(MailMessage.Subject) * 2
			+ ?(HTMLEmail, StrLen(MailMessage.HTMLText), StrLen(MailMessage.Text)) * 2;
		MailMessage.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing;
		
		MailMessage.Write();
		
		For Each Attachment In Message.Attachments Do
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", Attachment.Presentation);
			AttachmentParameters.Insert("Size", AttachmentsSizes[Attachment.AddressInTempStorage]);
			
			ModuleEmailManager = Common.CommonModule("EmailManagement");
			If IsBlankString(Attachment.Id) Then
				
				ModuleEmailManager.WriteEmailAttachmentFromTempStorage(MailMessage.Ref,
					Attachment.AddressInTempStorage, AttachmentParameters);
					
			ElsIf HTMLEmail Then
				
				AttachmentParameters.Insert("EmailFileID", Attachment.Id);
				ModuleEmailManager.WriteEmailAttachmentFromTempStorage(MailMessage.Ref,
					Attachment.AddressInTempStorage, AttachmentParameters);
				
			EndIf;
			
		EndDo;
		
		If ValueIsFilled(Message.AdditionalParameters.SubjectOf) Then
			SubjectOf = Message.AdditionalParameters.SubjectOf;
		Else
			SubjectOf = MailMessage.Ref;
		EndIf;
	
		Attributes       = InteractionAttributesStructureForWrite(SubjectOf, True);
		Attributes.Folder = DefineFolderForEmail(MailMessage.Ref);
		
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(MailMessage.Ref, Attributes);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		ErrorInfo = ErrorInfo();
		MessageTextTemplate = NStr("en = 'Cannot generate a mail. Reason:
			|%1';");
		
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,, MailMessage,
			StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorProcessing.DetailErrorDescription(ErrorInfo)));
			
		EmailSendingResult.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return EmailSendingResult;
		
	EndTry;
	
	EmailSendingResult.LinkToTheEmail = MailMessage.Ref;
	
	If Not SendImmediately Then
		Return EmailSendingResult;
	EndIf;
		
	Try
		SendingResult = ExecuteEmailSending(MailMessage);
		EmailID =  SendingResult.SMTPEmailID;
		EmailSendingResult.WrongRecipients = SendingResult.WrongRecipients;
		EmailSendingResult.EmailID = EmailID;
	Except
		
		ErrorInfo = ErrorInfo();
		MessageTextTemplate = NStr("en = 'Cannot send the mail. Reason:
				|%1';");
		
		ErrorText = EmailOperations.ExtendedErrorPresentation(ErrorInfo, Common.DefaultLanguageCode());
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Error,, MailMessage,
			StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorText));
		
		EmailSendingResult.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
		Return EmailSendingResult;
		
	EndTry;
	
	If Not MailMessage.DeleteAfterSend Then
		
		Try
			
			MessageIDIMAPSending = MailMessage.MessageIDIMAPSending;
			
			MailMessage.Read();
			MailMessage.MessageID             = EmailID;
			MailMessage.MessageIDIMAPSending = MessageIDIMAPSending;
			MailMessage.EmailStatus                       = Enums.OutgoingEmailStatuses.Sent;
			MailMessage.PostingDate                    = CurrentSessionDate();
			MailMessage.Write(DocumentWriteMode.Write);
			
			SetEmailFolder(MailMessage.Ref, DefineFolderForEmail(MailMessage.Ref));
		Except
				
			ErrorInfo = ErrorInfo();
			MessageTextTemplate = NStr("en = 'Couldn''t save outgoing mail. Reason:
				|%1';");
				
			WriteLogEvent(InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,, MailMessage,
				StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorProcessing.DetailErrorDescription(ErrorInfo)));
				
			EmailSendingResult.Sent     = False;
			EmailSendingResult.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, ErrorProcessing.BriefErrorDescription(ErrorInfo));
			Return EmailSendingResult;

		EndTry;
		
	Else
		
		MailMessage.Read();
		MailMessage.Delete();
		
	EndIf;
	
	EmailSendingResult.Sent = True;
	Return EmailSendingResult;
	
EndFunction

// A function creating message parameters.
// 
// Returns:
//  Structure:
//    * Subject - String
//    * Text - String
//    * UserMessages - FixedArray
//    * Importance - InternetMailMessageImportance
//    * Recipients - ValueTable:
//      ** Presentation - String
//      ** Address - String - Address in the temp storage.
//      ** ContactInformationSource - DefinedType.InteractionContact
//    * ReplyRecipients
//      ** Address - String - Address in temporary storage.
//      ** Address - String - Address in temporary storage.
//      ** Address - String - Address in temporary storage.
//    * BccRecipients
//      ** Address - String - Address in temporary storage.
//      ** Address - String - Address in temporary storage.
//      ** Address - String - Address in temporary storage.
//    * Attachments - ValueTable:
//      ** Presentation - String
//      ** AddressInTempStorage - String
//      ** Encoding - String
//      ** Id - String
//   * AdditionalParameters - Structure:
//      ** Comment - String
//      ** SubjectOf - DefinedType.InteractionSubject
//      ** EmailFormat1 - EnumRef.EmailEditingMethods
//      ** RequestDeliveryReceipt - Boolean
//      ** RequestReadReceipt - Boolean
//
Function EmailParameters() Export

	Message = New Structure;
	Message.Insert("Subject", "");
	Message.Insert("Text", "");
	Message.Insert("Importance", InternetMailMessageImportance.Normal);
	Message.Insert("UserMessages", New FixedArray(New Array));

	StringType = New TypeDescription("String");

	Recipients = New ValueTable;
	Recipients.Columns.Add("Address", StringType);
	Recipients.Columns.Add("Presentation", StringType);
	Recipients.Columns.Add("ContactInformationSource", Metadata.DefinedTypes.InteractionContact.Type);

	Message.Insert("Recipients", Recipients);
	
	ReplyRecipients = New ValueTable;
	ReplyRecipients.Columns.Add("Address", StringType);
	ReplyRecipients.Columns.Add("Presentation", StringType);
	ReplyRecipients.Columns.Add("ContactInformationSource", Metadata.DefinedTypes.InteractionContact.Type);

	Message.Insert("ReplyRecipients", ReplyRecipients); 
	
	BccRecipients = New ValueTable;
	BccRecipients.Columns.Add("Address", StringType);
	BccRecipients.Columns.Add("Presentation", StringType);
	BccRecipients.Columns.Add("ContactInformationSource", Metadata.DefinedTypes.InteractionContact.Type);
	
	Message.Insert("BccRecipients", BccRecipients);

	Attachments = New ValueTable;
	Attachments.Columns.Add("Presentation", StringType);
	Attachments.Columns.Add("AddressInTempStorage", StringType);
	Attachments.Columns.Add("Encoding", StringType);
	Attachments.Columns.Add("Id", StringType);
	Message.Insert("Attachments", Attachments);

	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Comment", "");
	AdditionalParameters.Insert("SubjectOf", "");
	AdditionalParameters.Insert("EmailFormat1", Enums.EmailEditingMethods.HTML);
	AdditionalParameters.Insert("RequestDeliveryReceipt", False);
	AdditionalParameters.Insert("RequestReadReceipt", False);
	
	Message.Insert("AdditionalParameters", AdditionalParameters);

	Return Message;

EndFunction

// Creates the Text message document and sends it.
// 
// Parameters:
//  Message - See MessageTemplatesInternal.GenerateMessage
//
Procedure CreateAndSendSMSMessage(Message) Export

	SMSMessage = Documents.SMSMessage.CreateDocument();
	
	SMSMessage.Date                    = CurrentSessionDate();
	SMSMessage.Author                   = Users.CurrentUser();

	SMSMessage.EmployeeResponsible           = Users.CurrentUser();
	SMSMessage.Importance                = Enums.InteractionImportanceOptions.Ordinary;

	SMSMessage.InteractionBasis = Undefined;
	SMSMessage.MessageText          = Message.Text;
	SMSMessage.Subject                    = SubjectByMessageText(Message.Text);
	SMSMessage.SendInTransliteration    = Message.AdditionalParameters.Transliterate;
	SMSMessage.Comment = NStr("en = 'Created from template and sent';") + " - " + Message.AdditionalParameters.Description;
	
	For Each SMSMessageAddressee In Message.Recipient Do
		
		NewRow = SMSMessage.SMSMessageRecipients.Add();
		If TypeOf(SMSMessageAddressee) = Type("Structure") Then
			NewRow.Contact                = SMSMessageAddressee.ContactInformationSource;
			NewRow.ContactPresentation  = SMSMessageAddressee.Presentation;
			NewRow.HowToContact           = SMSMessageAddressee.PhoneNumber;
			NewRow.SendingNumber       = SMSMessageAddressee.PhoneNumber;
		Else
			NewRow.Contact                = "";
			NewRow.ContactPresentation  = SMSMessageAddressee.Presentation;
			NewRow.HowToContact           = SMSMessageAddressee.Value;
			NewRow.SendingNumber       = SMSMessageAddressee.Value;
		EndIf;
		NewRow.MessageID = "";
		NewRow.ErrorText            = "";
		NewRow.MessageState = Enums.SMSMessagesState.Draft;
	
	EndDo;
	
	If Common.FileInfobase() Then
		SendSMSMessageByDocument(SMSMessage);
	Else
		SetStateOutgoingDocumentSMSMessage(SMSMessage);
	EndIf;
	
	SMSMessage.Write();
	
	If Message.AdditionalParameters.Property("SubjectOf") And ValueIsFilled(Message.AdditionalParameters.SubjectOf) Then
		SubjectOf = Message.AdditionalParameters.SubjectOf;
	Else
		SubjectOf = SMSMessage.Ref;
	EndIf;
	Attributes = InteractionAttributesStructureForWrite(SubjectOf, True);
	InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(SMSMessage.Ref, Attributes);
	
EndProcedure

// Sets the "Outgoing" status for the SMS message document and all messages that it includes.
//
// Parameters:
//  Object - DocumentObject.SMSMessage, FormDataStructure
//
Procedure SetStateOutgoingDocumentSMSMessage(Object) Export
	
	For Each Addressee In Object.SMSMessageRecipients Do
		Addressee.MessageState = PredefinedValue("Enum.SMSMessagesState.Outgoing");
	EndDo;
	Object.State = PredefinedValue("Enum.SMSDocumentStatuses.Outgoing");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport.
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the StringContactInteractions catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.StringContactInteractions.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Documents.Meeting.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.PhoneCall.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.PlannedInteraction.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.IncomingEmail.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.OutgoingEmail.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Documents.SMSMessage.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.MeetingAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.InteractionsTabs.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PlannedInteractionAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.EmailMessageFolders.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.EmailProcessingRules.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.SMSMessageAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.StringContactInteractions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PhoneCallAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.IncomingEmailAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.OutgoingEmailAttachedFiles.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// Called after the marked objects are deleted.
//
// Parameters:
//   ExecutionParameters - Structure - a context of marked object deletion:
//       * Trash - Array - references of deleted objects.
//       * NotTrash - Array - references to the objects that cannot be deleted.
//
Procedure AfterDeleteMarkedObjects(ExecutionParameters) Export
	
	StatesRecalculationRequired = False;
	
	For Each RemovedRef In ExecutionParameters.Trash Do
		
		If InteractionsClientServer.IsInteraction(RemovedRef) Then
			StatesRecalculationRequired = True;
			Break;
		EndIf;
		
	EndDo;
	
	If StatesRecalculationRequired Then
		
		PerformCompleteStatesRecalculation();
		
	EndIf;
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.SMSDeliveryStatusUpdate;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseOtherInteractions;
	Dependence.UseExternalResources = True;
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.SendSMSMessage;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseOtherInteractions;
	Dependence.UseExternalResources = True;
	
	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.SendReceiveEmails;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseEmailClient;
	Dependence.UseExternalResources = True;

EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	Types.Add(Metadata.InformationRegisters.AccountsLockedForReceipt);
EndProcedure

// See CommonOverridable.OnAddClientParameters.
Procedure OnAddClientParameters(Parameters) Export
	
	UseEmailClient = GetFunctionalOption("UseEmailClient");
	HasRightToCreateOutgoingEmails = AccessRight("Insert", Metadata.Documents.OutgoingEmail);
	
	Parameters.Insert("UseEmailClient", UseEmailClient);
	Parameters.Insert("UseOtherInteractions", GetFunctionalOption("UseOtherInteractions"));
	Parameters.Insert("OutgoingEmailsCreationAvailable", UseEmailClient And HasRightToCreateOutgoingEmails);
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.MeetingAttachedFiles, True);
	Lists.Insert(Metadata.Catalogs.PlannedInteractionAttachedFiles, True);
	Lists.Insert(Metadata.Catalogs.EmailMessageFolders, True);
	Lists.Insert(Metadata.Catalogs.EmailProcessingRules, True);
	Lists.Insert(Metadata.Catalogs.SMSMessageAttachedFiles, True);
	Lists.Insert(Metadata.Catalogs.PhoneCallAttachedFiles, True);
	Lists.Insert(Metadata.Catalogs.IncomingEmailAttachedFiles, True);
	Lists.Insert(Metadata.Catalogs.OutgoingEmailAttachedFiles, True);
	Lists.Insert(Metadata.Documents.Meeting, True);
	Lists.Insert(Metadata.Documents.PlannedInteraction, True);
	Lists.Insert(Metadata.Documents.SMSMessage, True);
	Lists.Insert(Metadata.Documents.PhoneCall, True);
	Lists.Insert(Metadata.Documents.IncomingEmail, True);
	Lists.Insert(Metadata.Documents.OutgoingEmail, True);
	Lists.Insert(Metadata.DocumentJournals.Interactions, True);
	Lists.Insert(Metadata.InformationRegisters.EmailAccountSettings, True);
	Lists.Insert(Metadata.InformationRegisters.InteractionsFolderSubjects, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionKinds.
Procedure OnFillMetadataObjectsAccessRestrictionKinds(LongDesc) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	
	If ModuleAccessManagementInternal.AccessKindExists("EmailAccounts") Then
		
		LongDesc = LongDesc + "
		|Catalog.EmailMessageFolders.Read.EmailAccounts
		|Catalog.EmailMessageFolders.Update.EmailAccounts
		|Catalog.EmailProcessingRules.Read.EmailAccounts
		|Catalog.EmailProcessingRules.Update.EmailAccounts
		|InformationRegister.EmailAccountSettings.Read.EmailAccounts
		|";
		
	EndIf;
	
	LongDesc = LongDesc + "
	|Document.Meeting.Read.Object.Document.Meeting
	|Document.Meeting.Update.Object.Document.Meeting
	|Document.PlannedInteraction.Read.Object.Document.PlannedInteraction
	|Document.PlannedInteraction.Update.Object.Document.PlannedInteraction
	|Document.SMSMessage.Read.Object.Document.SMSMessage
	|Document.SMSMessage.Update.Object.Document.SMSMessage
	|Document.PhoneCall.Read.Object.Document.PhoneCall
	|Document.PhoneCall.Update.Object.Document.PhoneCall
	|Document.IncomingEmail.Read.Object.Document.IncomingEmail
	|Document.IncomingEmail.Update.Object.Document.IncomingEmail
	|Document.OutgoingEmail.Read.Object.Document.OutgoingEmail
	|Document.OutgoingEmail.Update.Object.Document.OutgoingEmail
	|DocumentJournal.Interactions.Read.Object.Document.Meeting
	|DocumentJournal.Interactions.Read.Object.Document.PlannedInteraction
	|DocumentJournal.Interactions.Read.Object.Document.SMSMessage
	|DocumentJournal.Interactions.Read.Object.Document.PhoneCall
	|DocumentJournal.Interactions.Read.Object.Document.IncomingEmail
	|DocumentJournal.Interactions.Read.Object.Document.OutgoingEmail
	|InformationRegister.EmailAccountSettings.Read.Users
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.Meeting
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.PlannedInteraction
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.SMSMessage
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.PhoneCall
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.IncomingEmail
	|InformationRegister.InteractionsFolderSubjects.Update.Object.Document.OutgoingEmail
	|Catalog.EmailMessageFolders.Read.Users
	|Catalog.EmailMessageFolders.Update.Users
	|Catalog.EmailProcessingRules.Read.Users
	|Catalog.EmailProcessingRules.Update.Users
	|";
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		LongDesc = LongDesc + "
		|Catalog.MeetingAttachedFiles.Read.Object.Document.Meeting
		|Catalog.MeetingAttachedFiles.Update.Object.Document.Meeting
		|Catalog.PlannedInteractionAttachedFiles.Read.Object.Document.PlannedInteraction
		|Catalog.PlannedInteractionAttachedFiles.Update.Object.Document.PlannedInteraction
		|Catalog.SMSMessageAttachedFiles.Read.Object.Document.SMSMessage
		|Catalog.SMSMessageAttachedFiles.Update.Object.Document.SMSMessage
		|Catalog.PhoneCallAttachedFiles.Read.Object.Document.PhoneCall
		|Catalog.PhoneCallAttachedFiles.Update.Object.Document.PhoneCall
		|Catalog.IncomingEmailAttachedFiles.Read.Object.Document.IncomingEmail
		|Catalog.IncomingEmailAttachedFiles.Update.Object.Document.IncomingEmail
		|Catalog.OutgoingEmailAttachedFiles.Read.Object.Document.OutgoingEmail
		|Catalog.OutgoingEmailAttachedFiles.Update.Object.Document.OutgoingEmail
		|";
		
	EndIf;
	
EndProcedure

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.SMSDeliveryStatusUpdate.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.SendSMSMessage.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.SendReceiveEmails.Name);
	
EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not GetFunctionalOption("UseEmailClient")
		Or (Not Users.IsFullUser()
		And Not (AccessRight("Read", Metadata.DocumentJournals.Interactions) 
		And AccessRight("Read", Metadata.Catalogs.EmailAccounts)))
		Or ModuleToDoListServer.UserTaskDisabled("InteractionsMail") Then
		Return;
	EndIf;
	
	NewEmailsByAccounts = NewEmailsByAccounts();
	
	// The procedure can be called only if the "To-do list" subsystem is integrated.
	// Therefore, don't check if the subsystem is integrated.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.DocumentJournals.Interactions.FullName());
	
	For Each Section In Sections Do
		
		InteractionID = "Interactions" + StrReplace(Section.FullName(), ".", "");
		UserTaskParent = ToDoList.Add();
		UserTaskParent.Id  = InteractionID;
		UserTaskParent.Presentation  = NStr("en = 'Mailbox';");
		UserTaskParent.Form          = "DocumentJournal.Interactions.ListForm";
		UserTaskParent.Owner       = Section;
		
		IndexOf = 1;
		EmailsCount = 0;
		For Each NewEmailsByAccount In NewEmailsByAccounts Do
		
			EmailsIDByAccount = InteractionID + "Account" + IndexOf;
			ToDoItem = ToDoList.Add();
			ToDoItem.Id  = EmailsIDByAccount;
			ToDoItem.HasToDoItems       = NewEmailsByAccount.EmailsCount > 0;
			ToDoItem.Count     = NewEmailsByAccount.EmailsCount;
			ToDoItem.Presentation  = NewEmailsByAccount.Account;
			ToDoItem.Owner       = InteractionID;
			
			IndexOf = IndexOf + 1;
			EmailsCount = EmailsCount + NewEmailsByAccount.EmailsCount;
		EndDo;
		
		UserTaskParent.Count = EmailsCount;
		UserTaskParent.HasToDoItems   = EmailsCount > 0;
	EndDo;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "Interactions.DisableSubsystemSaaS";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.5.108";
	Handler.Id = New UUID("35e85460-7125-4079-b5df-5a71dbb43a49");
	Handler.Procedure = "Catalogs.EmailMessageFolders.ProcessDataForMigrationToNewVersion";
	Handler.Comment =
		NStr("en = 'Fills in the predefined folder type in the ""Email folders"" catalog';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.EmailMessageFolders.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToRead      = "Catalog.EmailMessageFolders";
	Handler.ObjectsToChange    = "Catalog.EmailMessageFolders";
	Handler.ObjectsToLock   = "Catalog.EmailMessageFolders";
	
	Handler = Handlers.Add();
	Handler.Version = "3.1.5.147";
	Handler.Id = New UUID("35e85660-7125-4079-b5df-5a71dbb43a48");
	Handler.Procedure = "Documents.OutgoingEmail.ProcessDataForMigrationToNewVersion";
	Handler.Comment =
		NStr("en = 'Filling in the ""Text"" attribute of the ""Outbox e-mail"" document for HTML messages which were not previously filled in with it by mistake';");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Documents.OutgoingEmail.RegisterDataToProcessForMigrationToNewVersion";
	Handler.CheckProcedure    = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToRead      = "Document.OutgoingEmail";
	Handler.ObjectsToChange    = "Document.OutgoingEmail";
	Handler.ObjectsToLock   = "Document.OutgoingEmail";	
	
EndProcedure

// Parameters:
//   Objects - Array of MetadataObject
//
Procedure OnDefineFileSynchronizationExceptionObjects(Objects) Export
	
	Objects.Add(Metadata.Documents.SMSMessage);
	Objects.Add(Metadata.Documents.IncomingEmail);
	Objects.Add(Metadata.Documents.OutgoingEmail);
	
EndProcedure

// See FilesOperationsOverridable.OnCreateFilesItemForm
Procedure OnCreateFilesItemForm(Form) Export
	
	Types = New Array;
	Types.Add(Type("CatalogRef.IncomingEmailAttachedFiles"));
	
	If Types.Find(TypeOf(Form.Object.Ref)) <> Undefined Then
		Form.OnlyFileDataReader = True;
	EndIf;
EndProcedure

//  Receives the objects to read upon the execution of the email account update handler.
// 
// Parameters:
//  ObjectsToRead - Array of String - the objects to read upon the handler execution.
//
Procedure OnReceiveObjectsToReadOfEmailAccountsUpdateHandler(ObjectsToRead) Export
	
	ObjectsToRead.Add("InformationRegister.EmailAccountSettings");
	
EndProcedure

//  Receives the objects to change upon the execution of the email account update handler.
// 
// Parameters:
//  ObjectsToChange - Array of String - the objects to read upon the handler execution.
//
Procedure OnGetEmailAccountsUpdateHandlerObjectsToChange(ObjectsToChange) Export
	
	ObjectsToChange.Add("InformationRegister.EmailAccountSettings");
	
EndProcedure

// Prepares the lock parameters.
// 
// Parameters:
//  Block - DataLock - a set lock.
//
Procedure BeforeSetLockInEmailAccountsUpdateHandler(Block) Export
	
	Block.Add("InformationRegister.EmailAccountSettings");
	
EndProcedure

// See PropertyManagerOverridable.OnGetPredefinedPropertiesSets
Procedure OnGetPredefinedPropertiesSets(Sets) Export
	Set = Sets.Rows.Add();
	Set.Name = "Document_Meeting";
	Set.Id = New UUID("26c5b310-f6a7-47b0-b85a-6052216965e2");
	
	Set = Sets.Rows.Add();
	Set.Name = "Document_PlannedInteraction";
	Set.Id = New UUID("70425541-23e3-4e5a-8bd3-9587cc949dfa");
	
	Set = Sets.Rows.Add();
	Set.Name = "Document_SMSMessage";
	Set.Id = New UUID("e9c48775-2727-46e1-bdb8-e9a0a68358a1");
	
	Set = Sets.Rows.Add();
	Set.Name = "Document_PhoneCall";
	Set.Id = New UUID("da617a73-992a-42b9-8d20-e65e043c46bc");
	
	Set = Sets.Rows.Add();
	Set.Name = "Document_IncomingEmail";
	Set.Id = New UUID("0467d0fe-1bf6-480d-ae0d-f2e36449d1df");
	
	Set = Sets.Rows.Add();
	Set.Name = "Document_OutgoingEmail";
	Set.Id = New UUID("123329af-4b94-4f47-9d39-e503190487bd");
EndProcedure

// See GenerateFromOverridable.OnDefineObjectsWithCreationBasedOnCommands.
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	Objects.Add(Metadata.Documents.Meeting);
	Objects.Add(Metadata.Documents.PlannedInteraction);
	Objects.Add(Metadata.Documents.SMSMessage);
	Objects.Add(Metadata.Documents.PhoneCall);
	Objects.Add(Metadata.Documents.IncomingEmail);
	Objects.Add(Metadata.Documents.OutgoingEmail);
	
EndProcedure

// See CommonOverridable.OnDefineSubordinateObjects
Procedure OnDefineSubordinateObjects(SubordinateObjects) Export

	SubordinateObject = SubordinateObjects.Add();
	SubordinateObject.SubordinateObject = Metadata.Catalogs.EmailMessageFolders;
	SubordinateObject.LinksFields = "Owner, Description";
	SubordinateObject.OnSearchForReferenceReplacement = "Interactions";
	SubordinateObject.RunReferenceReplacementsAutoSearch = True;	

EndProcedure

// ACC:299-off - Procedure that is called programmatically

// Runs when replacing duplicates in the item attributes.
//
// Parameters:
//  ReplacementPairs - Map - contains the value pairs original and duplicate.
//  UnprocessedOriginalsValues - Array of Structure:
//    * ValueToReplace - AnyRef - The original value of a replaceable object.
//    * UsedLinks - See Common.SubordinateObjectsLinksByTypes.
//    * KeyAttributesValue - Structure - Key is the attribute name. Value is the attribute value.
//
Procedure OnSearchForReferenceReplacement(ReplacementPairs, UnprocessedOriginalsValues) Export

	For Each UnprocessedDuplicate In UnprocessedOriginalsValues Do
		
		BeginTransaction();
		Try
		
			Block = New DataLock;
			Item = Block.Add(UnprocessedDuplicate.ValueToReplace.Metadata().FullName());
			Item.SetValue("Ref",  UnprocessedDuplicate.ValueToReplace);
			Block.Lock();
			
			FolderObject1 = UnprocessedDuplicate.ValueToReplace.GetObject();
			FolderObject1.DataExchange.Load = True;
			FolderObject1.Owner = UnprocessedDuplicate.KeyAttributesValue.Owner;
			FolderObject1.Write();
			CommitTransaction();
		
		Except
			RollbackTransaction();
			WriteLogEvent(NStr("en = 'Find and replace references';", Common.DefaultLanguageCode()),
				EventLogLevel.Error,
				UnprocessedDuplicate.ValueToReplace.Metadata(),,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndDo;	

EndProcedure
// ACC:299-on

// Checks whether the background job on sending and receiving messages is being performed.
//
// Returns:
//   Boolean   - True if running. Otherwise, False.
//
Function BackgroundJobReceivingSendingMailInProgress() Export
	
	ScheduledJob = Metadata.ScheduledJobs.SendReceiveEmails;
	
	Filter = New Structure;
	Filter.Insert("MethodName", ScheduledJob.MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	CurrentBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return CurrentBackgroundJobs.Count() > 0;
	
EndFunction

#EndRegion

#Region Private

// Returns fields for getting an owner description (if the owner exists).
//
// Parameters:
//  TableName - String - a name of the main table, for which the query is generated.
//
// Returns:
//  String - The string to be inserted into the query.
//
Function FieldNameForOwnerDescription(TableName) Export
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		If ContactDescription.Name = TableName And ContactDescription.HasOwner Then
			Return "CatalogContact.Owner.Description";
		EndIf;
	EndDo;
	
	Return """""";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions of contact search.

// Returns a list of available kinds of contact search.
//
// Parameters:
//  FTSEnabled        - Boolean - indicates whether a full-text search is available.
//  Parameters         - Structure - parameters containing contact Presentation and Address.
//  FormItems     - FormItems 
//  ForAddressBook  - Boolean - true if the list is generated for an address book.
//
// Returns:
//   Structure        - Structure containing search kinds and search values.
//
Function AvailableSearchesList(FTSEnabled, Parameters, FormItems, ForAddressBook) Export
	
	AllSearchLists = New Structure;
	
	If ForAddressBook Then
		Address = "";
		DomainAddress = "";
		SearchByStringOptions = "";
		Presentation = "";
	Else
		Address = Parameters.Address;
		DomainAddress = GetDomainAddressForSearch(Parameters.Address);
		SearchByStringOptions = SearchByStringOptions(Parameters.Presentation, Parameters.Address);
		Presentation = Parameters.Presentation;
	EndIf;
	
	AddSearchOption(AllSearchLists, FormItems.SearchOptions, "ByEmail", NStr("en = 'In email address';"), Address);
	AddSearchOption(AllSearchLists, FormItems.SearchOptions, "ByDomain", NStr("en = 'In domain name';"), DomainAddress);
	
	If Not ForAddressBook And (Parameters.Property("EmailOnly") And Not Parameters.EmailOnly) Then
		AddSearchOption(AllSearchLists, FormItems.SearchOptions, "ByPhone", NStr("en = 'In phone number';"), Address);
	EndIf;
	
	If Not FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Disable Then
		FTSEnabled = True;
	EndIf;
	
	If FTSEnabled Then
		AddSearchOption(AllSearchLists, FormItems.SearchOptions, "ByLine",
			NStr("en = 'In description';"), SearchByStringOptions);
	EndIf;
	
	AddSearchOption(AllSearchLists, FormItems.SearchOptions, "BeginsWith", NStr("en = 'Begins with';"), Presentation);
	
	Return AllSearchLists;
	
EndFunction

// Parameters:
//  AllSearchLists - Structure - a search option and this option values are added to it.
//  FormField       - TextBox - FormItem for the choice list of which an option is added.
//  VariantName     - String - a search option name.
//  Presentation   - String - a search option presentation.
//  Value        - String - a value for searching this search option.
//
Procedure AddSearchOption(AllSearchLists, FormField, VariantName, Presentation, Value)
	
	FormField.ChoiceList.Add(VariantName, Presentation);
	AllSearchLists.Insert(VariantName, Value);
	
EndProcedure

// Sets a contact as the current one in the "Address book" and "Select contact" forms.
//
// Parameters:
//  Contact - CatalogRef - Contact on which the cursor must be positioned.
//  Form   - ClientApplicationForm - Form where the actions are triggered.:
//   * Items - FormAllItems:
//    ** UsersList - FormTable - the form item containing the user list.
//
Procedure SetContactAsCurrent(Contact, Form) Export
	
	If TypeOf(Contact) = Type("CatalogRef.Users") Then
		Form.Items.PagesLists.CurrentPage = Form.Items.UsersPage;
		Form.Items.UsersList.CurrentRow = Contact;
		Return;
	EndIf;
		
	PrefixTable = InteractionsClientServer.PrefixTable();
	ContactMetadataName = Contact.Metadata().Name;
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		If ContactDescription.Name = ContactMetadataName Then
			Form.Items.PagesLists.CurrentPage = 
				Form.Items["Page_" + ?(ContactDescription.HasOwner,
					ContactDescription.OwnerName, ContactDescription.Name)];
			FormTable = FormTableByName(Form, PrefixTable + ContactDescription.Name);
			FormTable.CurrentRow = Contact;
			If ContactDescription.HasOwner Then
				ContactOwner = Common.ObjectAttributeValue(Contact, "Owner");
				FormTable = FormTableByName(Form, PrefixTable + ContactDescription.OwnerName);
				FormTable.CurrentRow = ContactOwner;
				CommonClientServer.SetDynamicListFilterItem(
					Form["List_" + ContactDescription.Name],"Owner",ContactOwner,,, True);
			EndIf;
		ElsIf ContactDescription.OwnerName = ContactMetadataName Then
			Form.Items.PagesLists.CurrentPage = 
				Form.Items["Page_" + ContactDescription.OwnerName];
			CommonClientServer.SetDynamicListFilterItem(
				Form["List_" + ContactDescription.Name],"Owner",Contact,,, True);
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  Form       - ClientApplicationForm - the form for which a table is determined.
//  TagName - String - a form item name.
// Returns:
//  FormTable
//
Function FormTableByName(Form, TagName) 
	
	Return Form.Items[TagName];
	
EndFunction

// Parameters:
//  Address  - String - contains an email address, from which a domain address is retrieved.
//
// Returns:
//   String   - Received domain address.
//
Function GetDomainAddressForSearch(Address)
	
	String = Address;
	Position = StrFind(String, "@");
	Return ?(Position = 0, "", Mid(String, Position+1));
	
EndFunction

// Parameters:
//  Presentation - String - contact presentation.
//  Address         - String - a contact address.
//
// Returns:
//   ValueList
//
Function SearchByStringOptions(Presentation, Address)
	
	If IsBlankString(Presentation) Then
		Return Address;
	ElsIf IsBlankString(Address) Then
		Return Presentation;
	ElsIf TrimAll(Presentation) = TrimAll(Address) Then
		Return Address;
	EndIf;
	
	SearchOptions = New ValueList;
	Presentation = AddQuotationMarksToString(Presentation);
	Address         = AddQuotationMarksToString(Address);
	SearchOptions.Add(Presentation + " And " + Address);
	SearchOptions.Add(Presentation + " OR " + Address);
	
	Return SearchOptions;
	
EndFunction

Function AddQuotationMarksToString(InitialString)
	
	
	StringToReturn = TrimAll(InitialString);
	
	If CharCode(Left(TrimAll(StringToReturn), 1)) <> 34 Then
		StringToReturn = """" + StringToReturn;
	EndIf;
	
	If CharCode(Right(TrimAll(StringToReturn), 1)) <> 34 Then
		StringToReturn = StringToReturn + """";
	EndIf;
	
	Return StringToReturn;
	
EndFunction

// Returns an array that contains structures with information about interaction contacts
// or interaction subject participants.
//
// Parameters:
//  TableOfContacts - TabularSection - contains descriptions and references to interaction contacts
//                     or interaction subject participants.
//
// Returns:
//   Array of Structure:
//    * Address - String
//    * Presentation - String
//    * Contact - AnyRef
//
Function ConvertContactsTableToArray(TableOfContacts) Export
	
	Result = New Array;
	For Each ArrayElement In TableOfContacts Do
		Contact = ?(TypeOf(ArrayElement.Contact) = Type("String"), Undefined, ArrayElement.Contact);
		Record = New Structure(
		  "Address, Presentation, Contact", ArrayElement.Address, ArrayElement.Presentation, Contact);
		Result.Add(Record);
	EndDo;
	
	Return Result;
	
EndFunction

// Fills in the "Found contacts" value table of the "Address book" and "Select contact" common forms
// based on the passed value table.
//
// Parameters:
//  TableOfContacts   - ValueTable - Source value table. Has the following columns:
//   * Contact              - DefinedType.InteractionContact - a reference to the interaction contact.
//   * Presentation        - String - contact presentation.
//   * Description         - String - contact name.
//   * CatalogName       - String - a contact metadata object name.
//  FoundContacts - ValueTable - a destination value table contains the following columns:
//   * Ref               - DefinedType.InteractionContact - a reference to the interaction contact.
//   * Presentation        - String - contact presentation.
//   * ContactName - String - contact name.
//   * CatalogName       - String - a contact metadata object name.
//
Procedure FillFoundContacts(TableOfContacts, FoundContacts) Export
	
	For Each Page1 In TableOfContacts Do
		NewRow = FoundContacts.Add();
		NewRow.Ref                 = Page1.Contact;
		NewRow.Presentation          = Page1.Presentation;
		NewRow.ContactName   = Page1.Description + ?(IsBlankString(Page1.OwnerDescription1), "", " (" + Page1.OwnerDescription1 + ")");
		NewRow.CatalogName         = Page1.Contact.Metadata().Name;
		NewRow.PresentationFilled = ?(IsBlankString(Page1.Presentation), False, True);
	EndDo;
	
EndProcedure

// Returns:
//   Array   - Array of metadata with valid contact types.
//
Function ContactsMetadata()
	
	Result = New Array;
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		Result.Add(Metadata.Catalogs[ContactDescription.Name]);
	EndDo;
	Return Result;
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
//  Main procedures and functions of contact search.

// Returns a table of all contacts related to the interaction subject.
//
// Parameters:
//   SubjectOf - DefinedType.InteractionSubject - interaction topic.
//   IncludeEmail - Boolean - indicates whether it is necessary to return email addresses even if the contact is not defined.
//
// Returns:
//   ValueTable  - Value table that contains information about contacts:
//    * Ref - DefinedType.InteractionSubject - contact.
//    * Description - String - contact name.
//    * OwnerDescription1 - String - a contact owner name.
//
Function ContactsBySubjectOrChain(SubjectOf, IncludeEmail)
	
	If Not ValueIsFilled(SubjectOf) Then
		Return Undefined;
	EndIf;
	
	QueryText = SearchForContactsByInteractionsChainQueryText(True);
	If Not InteractionsClientServer.IsInteraction(SubjectOf) Then
		ContactsTableName = SubjectOf.Metadata().FullName();
		
		QueryTextForSearch = "";
		InteractionsOverridable.OnSearchForContacts(ContactsTableName, QueryTextForSearch);
		
		If IsBlankString(QueryTextForSearch) Then
			// ACC:223-off For backward compatibility.
			QueryTextForSearch = InteractionsOverridable.QueryTextContactsSearchBySubject(False, 
				ContactsTableName, True);
			// ACC:223-on
		EndIf;
		
		QueryText = QueryText + QueryTextForSearch;
	EndIf;
	
	QueryText = QueryText + Chars.LF + ";" + Chars.LF
		+ QueryTextToGetContactsInformation(IncludeEmail);
	
	Query = New Query(QueryText);
	Query.SetParameter("SubjectOf", SubjectOf);
	TableOfContacts = Query.Execute().Unload();
	
	TableOfContacts.Columns.Add("DescriptionPresentation");
	
	For Each TableRow In TableOfContacts Do
		TableRow = ContactsTableRow1(TableRow);
		TableRow.DescriptionPresentation = TableRow.Description
		    + ?(IsBlankString(TableRow.OwnerDescription1),
		        "",
		        " (" + TableRow.OwnerDescription1 + ")");
	EndDo;
	
	Return TableOfContacts;
	
EndFunction

// Parameters:
//  TableRow - FormDataCollectionItem
//
// Returns:
//  Structure:
//    * Description          - String
//    * OwnerDescription1 - String
//
Function ContactsTableRow1(TableRow)
	
	Return TableRow;
	
EndFunction

// Parameters:
//  PutInTempTable - Boolean
//
Function SearchForContactsByInteractionsChainQueryText(PutInTempTable)
	
	SearchResultsList = New ValueList;
	SearchResultsList.Add("Meeting.Attendees",                                 "Contact");
	SearchResultsList.Add("PlannedInteraction.Attendees",           "Contact");
	SearchResultsList.Add("PhoneCall",                                  "SubscriberContact");
	SearchResultsList.Add("IncomingEmail",                         "SenderContact");
	SearchResultsList.Add("IncomingEmail.EmailRecipients",        "Contact");
	SearchResultsList.Add("IncomingEmail.CCRecipients",         "Contact");
	SearchResultsList.Add("IncomingEmail.ReplyRecipients",        "Contact");
	SearchResultsList.Add("OutgoingEmail.EmailRecipients",       "Contact");
	SearchResultsList.Add("OutgoingEmail.CCRecipients",        "Contact");
	SearchResultsList.Add("OutgoingEmail.ReplyRecipients",       "Contact");
	SearchResultsList.Add("OutgoingEmail.BccRecipients", "Contact");
	
	// @query-part-1
	TextTempTable = ?(PutInTempTable, "INTO TableOfContacts
		|",
		"");
		
	RefsConditionTemplate = ConditionTemplateForRefsToContactsForQuery();
	QueryTexts = New Array; 
	
	For Each ListItem In SearchResultsList Do
		TableName = ListItem.Value;
		FieldName    = ListItem.Presentation;
		RefsCondition = StrReplace(RefsConditionTemplate, "%FieldName%", FieldName);
		
		QueryText = 
		"SELECT DISTINCT ALLOWED
		|	&ContactFieldName
		|	,&TheTextToPut
		|FROM
		|	&TableName AS InteractionContacts
		|	INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
		|	ON InteractionContacts.Ref = InteractionsSubjects.Interaction
		|	WHERE
		|		InteractionsSubjects.SubjectOf = &SubjectOf
		|	AND (&RefsCondition)";
		
		If QueryTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT DISTINCT ALLOWED", "SELECT DISTINCT"); // @query-part-1, @query-part-2
		EndIf;
		QueryText = StrReplace(QueryText, ",&TheTextToPut", TextTempTable);
		QueryText = StrReplace(QueryText, "&TableName", "Document." + TableName);
		QueryText = StrReplace(QueryText, "&RefsCondition", RefsCondition);
		QueryText = StrReplace(QueryText, "&ContactFieldName", "InteractionContacts." + FieldName);
		
		TextTempTable = "";
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	Return StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF);
	
EndFunction

// Parameters:
//  Address - String - an email address to search.
//
// Returns:
//  ValueTable - Value table that contains information about contacts.
//
Function ContactsByEmail(Address)
	
	If IsBlankString(Address) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text = GenerateQueryTextForSearchByEmail(False);
	
	Query.SetParameter("Address", Address);
	Return Query.Execute().Unload();
	
EndFunction

// Parameters:
//  Address - String - an email address to search.
//
// Returns:
//  QueryResultSelection  - Query result that contains information about contacts.
//
Function GetAllContactsByEmailList(AddressesList) Export
	
	If AddressesList.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	QueryText = GenerateQueryTextForSearchByEmail(True, True);	
	Query = New Query(QueryText);	
	Query.SetParameter("Address", AddressesList);
	Return Query.Execute().Unload(QueryResultIteration.ByGroups);
	
EndFunction

// Parameters:
//  IncludeEmail  - Boolean - indicates whether email information is included in the query result.
//  CatalogName - String - a name of the catalog, for which the query is being generated.
//
// Returns:
//  String - Complement to the query.
//
Function ConnectionStringForContactsInformationQuery(IncludeEmail, CatalogName)
	
	If (Not IncludeEmail) Or (Not CatalogHasTabularSection(CatalogName,"ContactInformation")) Then
		
		Return "";
		
	Else
		
		Return "
		|			LEFT JOIN Catalog."  + CatalogName + ".ContactInformation AS ContactInformationTable
		|			On CatalogContact.Ref = ContactInformationTable.Ref
		|				AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))";
		
	EndIf;
	
EndFunction

// Generates a field selection row to receive in the email address query.
//
// Parameters:
//  IncludeEmail  - Boolean - indicates whether it is necessary to get an email
//                            address in this query.
//  CatalogName - Boolean - a name of the catalog, for which the query is being executed.
//  NameField  - Boolean - indicates that the query field must be named.
//
// Returns:
//  String
//
Function QueryFragmentContactInformation(IncludeEmail, CatalogName, NameField = False)
	
	If Not IncludeEmail Then
		Return "";
	EndIf;
		
	If CatalogHasTabularSection(CatalogName, "ContactInformation") Then
		Return ",
		|	ContactInformationTable.EMAddress";
	Else
		Return ",
		|	""""" + ?(NameField," AS EMAddress","");
	EndIf;
	
EndFunction

// Parameters:
//  IncludeEmail - Boolean - indicates whether it is necessary to get information about email.
//
// Returns:
//   String
//
Function QueryTextToGetContactsInformation(IncludeEmail)
	
	QueryText = 
	"SELECT DISTINCT ALLOWED
	|	CatalogContact.Ref       AS Ref,
	|	CatalogContact.Description AS Description,
	|	"""" AS OwnerDescription1
	|	,&EmailAddressField
	|FROM
	|	TableOfContacts AS TableOfContacts
	|		INNER JOIN Catalog.Users AS CatalogContact
	|		ON TableOfContacts.Contact = CatalogContact.Ref
	|	AND &ConnectionTextByEmailAddress
	|WHERE
	|	(NOT CatalogContact.DeletionMark)
	|";
	
	QueryText = StrReplace(QueryText, ",&EmailAddressField",
		QueryFragmentContactInformation(IncludeEmail, "Users"));
	QueryText = StrReplace(QueryText, "AND &ConnectionTextByEmailAddress",
		ConnectionStringForContactsInformationQuery(IncludeEmail, "Users"));
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		QueryText = "SELECT DISTINCT
		|	CatalogContact.Ref,
		|	CatalogContact.Description,
		|	""""
		|	,&EmailAddressField
		|FROM
		|	TableOfContacts AS TableOfContacts
		|		INNER JOIN ContactReferenceTable AS CatalogContact
		|		ON TableOfContacts.Contact = CatalogContact.Ref
		|	AND &ConnectionTextByEmailAddress
		|WHERE
		|	(NOT CatalogContact.DeletionMark)
		|	AND &TheConditionForTheGroup";
		
		QueryText = StrReplace(QueryText, ",&EmailAddressField", 
			QueryFragmentContactInformation(IncludeEmail, ContactDescription.Name));
		QueryText = StrReplace(QueryText, "AND &ConnectionTextByEmailAddress", 
			ConnectionStringForContactsInformationQuery(IncludeEmail, ContactDescription.Name));
		QueryText = StrReplace(QueryText, "ContactReferenceTable", "Catalog." + ContactDescription.Name);
		QueryText = StrReplace(QueryText, "AND &TheConditionForTheGroup", 
			?(ContactDescription.Hierarchical, " AND (NOT CatalogContact.Ref.IsFolder)", ""));
		QueryTexts.Add(QueryText); 
			
	EndDo;
	
	// @query-part-1
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|ORDER BY
		|	Description"; // @query-part-1
	
	Return QueryText;
	
EndFunction

// Parameters:
//  SearchByList - Boolean - indicates that a value array is passed as a parameter.
//
// Returns:
//  String
//
Function GenerateQueryTextForSearchByEmail(SearchByList, TotalsByEmail = False)
	
	QueryText =
	"SELECT DISTINCT ALLOWED
	|	ContactInformationTable1.Ref AS Contact,
	|	ContactInformationTable1.Presentation,
	|	"""" AS OwnerDescription1,
	|	ContactInformationTable1.Ref.Description AS Description
	|FROM
	|	Catalog.Users.ContactInformation AS ContactInformationTable1
	|WHERE
	|	ContactInformationTable1.EMAddress = &Address
	|	AND (NOT ContactInformationTable1.Ref.DeletionMark)
	|	AND ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Email)";
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
			
		QueryText = 
		"SELECT DISTINCT
		|	ContactInformationTable1.Ref,
		|	ContactInformationTable1.Presentation,
		|	&TheNameFieldOfTheOwner,
		|	&TheNameField AS Description
		|FROM
		|	&CatalogTable AS ContactInformationTable1
		|WHERE
		|	ContactInformationTable1.EMAddress = &Address
		|  AND (NOT ContactInformationTable1.Ref.DeletionMark)
		|	AND ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Email)
		|  AND &ConditionGroup";
		
		QueryText = StrReplace(QueryText, "&TheNameFieldOfTheOwner", 
			?(ContactDescription.HasOwner," ContactInformationTable1.Ref.Owner.Description", """"""));
		QueryText = StrReplace(QueryText, "&TheNameField", 
			"ContactInformationTable1.Ref." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&CatalogTable", 
			"Catalog." + ContactDescription.Name + ".ContactInformation");
		QueryText = StrReplace(QueryText, "AND &ConditionGroup", 
			?(ContactDescription.Hierarchical," AND (NOT ContactInformationTable1.Ref.IsFolder)",""));
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF) // @query-part
		+ "
		|ORDER BY
		|	Description"; // @query-part
	If TotalsByEmail Then
		QueryText = QueryText + "
		|TOTALS BY
		|	Presentation"; // @query-part
	EndIf;
	
	If SearchByList Then
		QueryText = StrReplace(QueryText, "= &Address", "IN (&Address)"); // @query-part-2
	EndIf;
	
	Return QueryText;
	
EndFunction

// Searching by a description of contacts that contain email addresses.
//
// Parameters:
//  Description — String — contains the contact description beginning.
//  FoundContacts - ValueTable
//
// Returns:
//  Boolean - True if at least one contact is found.
//
Function FindContactsWithAddressesByDescription(Val SearchString, FoundContacts) Export
	
	TableOfContacts = FindContactsWithAddresses(SearchString);
	If TableOfContacts = Undefined Or TableOfContacts.Count() = 0 Then
		Return False;
	EndIf;
	
	FillFoundContacts(TableOfContacts, FoundContacts);
	Return True;
	
EndFunction

// Searches for contacts with email addresses.
// 
// Parameters:
//  SearchString - String - search text
//
// Returns:
//   See ContactsManagerInternal.FindContactsWithEmailAddresses
//
Function FindContactsWithAddresses(SearchString) Export
	
	ContactsDetails = InteractionsClientServer.ContactsDetails();
	
	Contacts = New Array;
	For Each ContactDescriptions In ContactsDetails Do
		NewContact = ContactsManagerInternal.NewContactDescription();
		FillPropertyValues(NewContact, ContactDescriptions);
		Contacts.Add(NewContact);
	EndDo;
	
	Result = ContactsManagerInternal.FindContactsWithEmailAddresses(SearchString, Contacts);
	Return Result;
	
EndFunction

// Generates a condition template for the query whether the field to be received in the query matches a possible contact type.
//
// Returns:
//  String
//
Function ConditionTemplateForRefsToContactsForQuery()
	
	Result =  "InteractionContacts.FieldName REFS Catalog.Users"; // @query-part
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		ConditionTemplate = "OR InteractionContacts.FieldName REFS Catalog.Users"; // @query-part
		ConditionTemplate = StrReplace(ConditionTemplate, "Users", ContactDescription.Name);
		
		Result = Result + Chars.LF + ConditionTemplate;
	EndDo;
	
	Result = StrReplace(Result, "FieldName", "%FieldName%");
	Return Result;
	
EndFunction

Function FindContacts(Val SearchString, Val ForAddressBook, FoundContacts) Export
	
	If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Disable
		Or Not GetFunctionalOption("UseFullTextSearch") Then
		FindContactsWithAddressesByDescription(SearchString, FoundContacts);
		Return "";
	EndIf;

	Result = FullTextContactsSearchByRow(SearchString, FoundContacts, ForAddressBook);
	If IsBlankString(Result) Then
		FindByEmail(SearchString, False, FoundContacts);
	EndIf;
	Return Result;
	
EndFunction

// Searches for contacts by an email or an email domain.
//
// Parameters:
//  SearchString - String - a basis for search.
//  ByDomain     - Boolean - indicates that the search must be carried out by a domain.
//  FoundContacts - ValueTable	
//
// Returns:
//  Boolean - True if at least one contact is found.
//
Function FindByEmail(Val SearchString, Val ByDomain, FoundContacts) Export
	
	If ByDomain Then
		TableOfContacts = ContactsByDomainAddress(SearchString);
	Else
		TableOfContacts = ContactsByEmail(SearchString);
	EndIf;
	
	If TableOfContacts = Undefined Or TableOfContacts.Count() = 0 Then
		Return False;
	EndIf;
	
	FillFoundContacts(TableOfContacts, FoundContacts);
	Return True;
	
EndFunction

// Parameters:
//  DomainName - String - a domain name, by which a search is being carried out.
//
// Returns:
//  ValueTable - Table that contains information about the found contacts.
//
Function ContactsByDomainAddress(Val DomainName)
	
	If IsBlankString(DomainName) Then
		Return Undefined;
	EndIf;
	
	QueryTexts = New Array;	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If Not ContactDescription.SearchByDomain Then
			Continue;
		EndIf;
			
		QueryText = 
		"SELECT DISTINCT ALLOWED
		|	ContactInformationTable.Ref  AS Contact,
		|	&TheNameField                   AS Description,
		|	ContactInformationTable.EMAddress AS Presentation,
		|	&TheNameFieldOfTheOwner          AS OwnerDescription1
		|FROM
		|	&TableName AS ContactInformationTable
		|WHERE
		|	ContactInformationTable.EMAddress LIKE &SearchString ESCAPE ""~""";
		
		If QueryTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT DISTINCT ALLOWED", "SELECT DISTINCT"); // @query-part-1, @query-part-2
		EndIf;	
		QueryText = StrReplace(QueryText, "&TheNameFieldOfTheOwner", 
			?(ContactDescription.HasOwner, "ContactInformationTable.Ref.Owner.Description ", """"""));
		QueryText = StrReplace(QueryText, "&TheNameField", 
			"ContactInformationTable.Ref." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&TableName", "Catalog." + ContactDescription.Name + ".ContactInformation");
		QueryTexts.Add(QueryText);

	EndDo;
	
	If QueryTexts.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF) + "
		|ORDER BY
		|	Ref,
		|	EMAddress"; // @query-part
	
	Query = New Query(QueryText);
	Query.SetParameter("SearchString", "%@" + Common.GenerateSearchQueryString(DomainName) + "%");	
	Return Query.Execute().Unload();
	
EndFunction

// Parameters:
//  Form            - ClientApplicationForm - a form for which search is performed.
//  ForAddressBook - Boolean - indicates whether the search is carried out for the address book.
//
// Returns:
//  String           - User message with the search result.
//
Function FullTextContactsSearchByRow(Val SearchString, FoundContacts, Val ForAddressBook = False) Export
	
	FoundContacts.Clear();
	
	If IsBlankString(SearchString) Then
		Return "";
	EndIf;
	
	If FullTextSearch.GetFullTextSearchMode() = FullTextSearchMode.Disable
		Or Not GetFunctionalOption("UseFullTextSearch") Then
		Return NStr("en = 'Full-text search is not available.';");
	EndIf;
	
	MetadataArray = ContactsMetadata();
	
	If StrFind(SearchString, "*") = 0 Then
		SearchString = "*" + SearchString + "*";
	EndIf;	
	SearchResultsList = FullTextSearch.CreateList(SearchString, 101);
	SearchResultsList.SearchArea = MetadataArray;

	Try
		SearchResultsList.FirstPart();
	Except
		Return NStr("en = 'Nothing was found. Please try another search expression.
		              |Hint: use asterisk to search by a part of a word. Search for ""ment"" will return nothing, while search for ""*ment"" will return ""agreement"", ""document"", and so on.
		              |See Help for search syntax.';");
	EndTry;
	
	FoundItemsCount1 = SearchResultsList.Count();
	If FoundItemsCount1 = 0 Then
		Return "";
	EndIf;
	
	ReferencesArrray = New Array;
	DetailsMap = New Map;
	For Indus = 0 To Min(FoundItemsCount1, 100) - 1 Do
		ListItem = SearchResultsList.Get(Indus);
		ReferencesArrray.Add(ListItem.Value);
		DetailsMap[ListItem.Value] = ListItem.Description;
	EndDo;
	
	If ForAddressBook Then
		QueryText = GetSearchForContactsQueryTextByEmailString();
	Else	
		QueryText = QueryTextSearchForContactsByString();
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ReferencesArrray", ReferencesArrray);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		NewRow = FoundContacts.Add();
		NewRow.Ref = Selection.Contact;
		NewRow.Presentation = ?(ForAddressBook, Selection.Presentation, DetailsMap[Selection.Contact]);
		NewRow.ContactName = Selection.Description 
			+ ?(IsBlankString(Selection.OwnerDescription1), "", " (" + Selection.OwnerDescription1 + ")");
		NewRow.PresentationFilled = ?(IsBlankString(NewRow.Presentation), False, True);
	EndDo;
	
	Return ?(FoundItemsCount1 < 101, "", NStr("en = 'Refine the search parameters. The search result is too big to accommodate in the list.';"));
	
EndFunction

// Returns:
//  String
//
Function QueryTextSearchForContactsByString()
	
	QueryText =
	"SELECT DISTINCT ALLOWED
	|	CatalogTable.Ref AS Contact,
	|	CatalogTable.Description AS Description,
	|	"""" AS OwnerDescription1,
	|	"""" AS Presentation
	|FROM
	|	Catalog.Users AS CatalogTable
	|WHERE
	|	CatalogTable.Ref IN(&ReferencesArrray)
	|	AND (NOT CatalogTable.DeletionMark)";	
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		QueryText = 
		"SELECT DISTINCT
		|	CatalogTable.Ref,
		|	&NameOfTheFieldName AS Description,
		|	&FieldNameTheNameOfTheOwner,
		|	""""
		|FROM
		|	&CatalogTable AS CatalogTable
		|WHERE
		|	CatalogTable.Ref IN(&ReferencesArrray) 
		|	AND &HierarchicalCondition
		|	AND (NOT CatalogTable.DeletionMark)";
		
		QueryText = StrReplace(QueryText, "&FieldNameTheNameOfTheOwner", 
			?(ContactDescription.HasOwner," CatalogTable.Owner.Description", """"""));
		QueryText = StrReplace(QueryText, "&NameOfTheFieldName", 
			"CatalogTable." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&CatalogTable", "Catalog." + ContactDescription.Name);
		QueryText = StrReplace(QueryText, "AND &HierarchicalCondition", 
			?(ContactDescription.Hierarchical," AND (NOT CatalogTable.IsFolder)", ""));
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|ORDER BY
		|	Description"; // @query-part
	
	Return QueryText;
	
EndFunction

// Returns:
//  String - Query text.
//
Function GetSearchForContactsQueryTextByEmailString()
	
	QueryText =
	"SELECT DISTINCT ALLOWED
	|	CatalogTable.Ref AS Contact,
	|	CatalogTable.Description AS Description,
	|	"""" AS OwnerDescription1,
	|	ContactInformationTable.EMAddress AS Presentation
	|FROM
	|	Catalog.Users AS CatalogTable
	|		LEFT JOIN Catalog.Users.ContactInformation AS ContactInformationTable
	|		ON (ContactInformationTable.Ref = CatalogTable.Ref)
	|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))
	|WHERE
	|	CatalogTable.Ref IN(&ReferencesArrray)
	|	AND (NOT CatalogTable.DeletionMark)";	
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		QueryText =
		"SELECT DISTINCT
		|	CatalogTable.Ref,
		|	&NameOfTheFieldName AS Description,
		|	&FieldNameTheNameOfTheOwner,
		|	ContactInformationTable.EMAddress
		|FROM
		|	&CatalogTable AS CatalogTable
		|		LEFT JOIN TheNameOfTheTableContactInformation AS ContactInformationTable
		|		ON (ContactInformationTable.Ref = CatalogTable.Ref)
		|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))
		|WHERE
		|	CatalogTable.Ref IN(&ReferencesArrray) 
		|	AND &HierarchicalCondition
		|	AND (NOT CatalogTable.DeletionMark)";
		
		QueryText = StrReplace(QueryText, "&FieldNameTheNameOfTheOwner", 
			?(ContactDescription.HasOwner," CatalogTable.Owner.Description",""""""));
		QueryText = StrReplace(QueryText, "&NameOfTheFieldName", 
			"CatalogTable." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&CatalogTable", "Catalog." + ContactDescription.Name);
		QueryText = StrReplace(QueryText, "AND &HierarchicalCondition", 
			?(ContactDescription.Hierarchical," AND (NOT CatalogTable.IsFolder)",""));
		QueryText = StrReplace(QueryText, "TheNameOfTheTableContactInformation",
			"Catalog." + ContactDescription.Name + ".ContactInformation");
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|ORDER BY
		|	Description"; // @query-part
	
	Return QueryText;
	
EndFunction

// Gets contacts by an interaction subject, sets a contact search page by the subject
// as the current page of the search form.
//
// Parameters:
//  FormItems      - FormAllItems - grants access to form items.
//  SubjectOf            - DefinedType.InteractionSubject - interaction topic.
//  ContactsBySubject - ValueTable - a form attribute, in which found contacts are placed.
//  IncludeEmail      - Boolean - indicates whether it is necessary to get data on a contact email address.
//
Procedure FillContactsBySubject(FormItems, SubjectOf, ContactsBySubject, IncludeEmail) Export
	
	If Not ValueIsFilled(SubjectOf) Then
		FormItems.AllContactsBySubjectPage.Visible = False;
		Return;
	EndIf;
	
	TableOfContacts = ContactsBySubjectOrChain(SubjectOf, IncludeEmail);
	If (TableOfContacts = Undefined) Or (TableOfContacts.Count() = 0) Then
		FormItems.AllContactsBySubjectPage.Visible = False;
		Return;
	EndIf;
	
	For Each TableRow In TableOfContacts Do
		NewRow = ContactsBySubject.Add();
		NewRow.Ref = TableRow.Ref;
		NewRow.Description = TableRow.Description;
		NewRow.CatalogName = TableRow.Ref.Metadata().Name;
		NewRow.DescriptionPresentation = TableRow.DescriptionPresentation;
		If IncludeEmail Then
			NewRow.Address = TableRow.EMAddress;
			If Not IsBlankString(NewRow.Address) Then
				NewRow.AddressFilled = True;
			EndIf;
		EndIf;
	EndDo;
	
	FormItems.PagesLists.CurrentPage = FormItems.AllContactsBySubjectPage;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////
//  Procedures and functions for getting contact data, interactions, and interaction subjects.

// Parameters:
//  Ref - Reference to the interaction.
//
// Returns:
//   DefinedType.InteractionSubject - Interaction topic.
//   Undefined
//
Function GetSubjectValue(Ref) Export

	Attributes = InteractionAttributesStructure(Ref);
	Return ?(Attributes = Undefined, Undefined, Attributes.SubjectOf);
	
EndFunction

// Returns information records on interaction's additional attributes
//
// Parameters:
//  Ref - Reference to the interaction.
//
// Returns:
//   See InformationRegisters.InteractionsFolderSubjects.InteractionAttributes
//
Function InteractionAttributesStructure(Ref) Export
	
	ReturnStructure = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	InteractionsFolderSubjects.SubjectOf,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder,
	|	InteractionsFolderSubjects.Reviewed,
	|	InteractionsFolderSubjects.ReviewAfter
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|WHERE
	|	InteractionsFolderSubjects.Interaction = &Interaction";
	
	Query.SetParameter("Interaction", Ref);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		FillPropertyValues(ReturnStructure, Selection);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Parameters:
//  MailMessage - DocumentRef.Meeting
//         - DocumentRef.PlannedInteraction
//         - DocumentRef.SMSMessage
//         - DocumentRef.PhoneCall
//         - DocumentRef.IncomingEmail
//         - DocumentRef.OutgoingEmail - Reference to the interaction.
//
// Returns:
//  CatalogRef.EmailMessageFolders
//
Function GetEmailFolder(MailMessage) Export
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	InteractionsSubjects.EmailMessageFolder
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
	|WHERE
	|	InteractionsSubjects.Interaction = &Interaction";
	
	Query.SetParameter("Interaction",MailMessage);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Catalogs.EmailMessageFolders.EmptyRef();
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.EmailMessageFolder;
	EndIf;
	
EndFunction

// Receives values of interaction document attributes stored in the register 
//  and sets them to the corresponding form attributes.
//
// Parameters:
//  Form - ClientApplicationForm - an interaction document form contains:
//   * Object - DocumentObject.PhoneCall
//            - DocumentObject.PlannedInteraction
//            - DocumentObject.SMSMessage
//            - DocumentObject.Meeting
//            - DocumentObject.IncomingEmail
//            - DocumentObject.OutgoingEmail - Reference to the object being written.
//
Procedure SetInteractionFormAttributesByRegisterData(Form) Export
	
	AttributesStructure1 = InteractionAttributesStructure(Form.Object.Ref);
	FillPropertyValues(Form, AttributesStructure1, "SubjectOf, Reviewed, ReviewAfter");
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
//  Procedures and functions for handling interactions.

// Returns:
//  ValueList - Value list containing contacts that can be created manually.
//
Function CreateValueListOfInteractivelyCreatedContacts() Export
	
	PossibleContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	ListOfContactsThatCanBeCreated = New ValueList;
	
	For Each ArrayElement In PossibleContactsTypesDetailsArray Do
		
		If ArrayElement.InteractiveCreationPossibility And AccessRight("Insert", Metadata.Catalogs[ArrayElement.Name])Then
			
			ListOfContactsThatCanBeCreated.Add(ArrayElement.Name, ArrayElement.Presentation);
			
		EndIf;
		
	EndDo;
	
	Return ListOfContactsThatCanBeCreated;
	
EndFunction

// Parameters:
//  Parameters  - Structure - parameters passed upon an interaction document creation.
//  SubjectOf    - DocumentRef
//             - CatalogRef - This procedure takes the interaction topic from autofill data.
//                                  
//
Procedure SetSubjectByFillingData(Parameters, SubjectOf) Export
	
	If Parameters.Property("SubjectOf")
		And ValueIsFilled(Parameters.SubjectOf)
		And (InteractionsClientServer.IsSubject(Parameters.SubjectOf)
		  Or InteractionsClientServer.IsInteraction(Parameters.Basis)) Then
		
		SubjectOf = Parameters.SubjectOf;
		
	ElsIf InteractionsClientServer.IsSubject(Parameters.Basis) Then
		
		SubjectOf = Parameters.Basis;
		
	ElsIf InteractionsClientServer.IsInteraction(Parameters.Basis) Then
		
		SubjectOf = GetSubjectValue(Parameters.Basis);
		
	ElsIf TypeOf(Parameters.Basis) = Type("Structure") And Parameters.Basis.Property("Basis") 
		And InteractionsClientServer.IsInteraction(Parameters.Basis.Basis) Then
		
		SubjectOf = GetSubjectValue(Parameters.Basis.Basis);
		
	ElsIf Parameters.FillingValues.Property("SubjectOf") Then
		
		SubjectOf = Parameters.FillingValues.SubjectOf;
		
	ElsIf Not Parameters.CopyingValue.IsEmpty() Then
		
		SubjectOf = GetSubjectValue(Parameters.CopyingValue);
		
	EndIf;
	
EndProcedure

// Parameters:
//  Ref - DocumentRef - a reference to the interaction document.
//
// Returns:
//  Array of Structure
//
Function GetParticipantsByTable(Ref) Export
	
	FullObjectName = Ref.Metadata().FullName();
	TableName = ?(TypeOf(Ref) = Type("DocumentRef.SMSMessage"), "SMSMessageRecipients", "Attendees");
	
	QueryText =
	"SELECT
	|	Attendees.Contact,
	|	Attendees.ContactPresentation AS Presentation,
	|	Attendees.HowToContact AS Address
	|FROM
	|	&NameOfTheInteractionTable AS Attendees
	|WHERE
	|	Attendees.Ref = &Ref";
	
	QueryText = StrReplace(QueryText, "&NameOfTheInteractionTable", FullObjectName + "." + TableName);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	
	Return ConvertContactsTableToArray(Query.Execute().Unload());
	
EndFunction

// Generates an array of interaction participant containing one structure by the passed fields.
//
// Parameters:
//  Ref - DocumentRef - a reference to the interaction document.
//
// Returns:
//  Array - Array of structures containing information about contacts.
//
Function GetParticipantByFields(Contact, Address, Presentation) Export
	
	ContactStructure = New Structure("Contact, Address, Presentation", Contact, Address, Presentation);
	ArrayToGenerate = New Array;
	ArrayToGenerate.Add(ContactStructure);
	Return ArrayToGenerate;
	
EndFunction

// Parameters:
//  Contacts - Array 
//
// Returns:
//  Boolean
//
Function ContactsFilled(Contacts) Export
	
	Return (ValueIsFilled(Contacts) And (Contacts.Count() > 0));
	
EndFunction

// Fills the participants tabular section for the Meeting and Planned interaction documents.
//
// Parameters:
//  Contacts                     - Array - an array containing interaction participants.
//  Attendees                    - TabularSection - a tabular section of a document
//                                 to be filled in based on the array.
//  ContactInformationType      - EnumRef.ContactInformationTypes - if given, 
//                                 then this type of contact information will be filtered.
//  SeparateByNumberOfAddresses - Boolean - If True, then there will be added as many rows in the "Participants" tabular section
//                                 of the contact as there were received various types of filled in contact information.
//
Procedure FillContactsForMeeting(Contacts, Attendees, ContactInformationType = Undefined, SeparateByNumberOfAddresses = False) Export
	
	If Not ContactsFilled(Contacts) Then
		Return;
	EndIf;
	
	For Each ArrayElement In Contacts Do
		
		NewRow = Attendees.Add();
		If TypeOf(ArrayElement) = Type("Structure") Then
			NewRow.Contact = ArrayElement.Contact;
			NewRow.ContactPresentation = ArrayElement.Presentation;
			NewRow.HowToContact = ConvertAddressByInformationType(ArrayElement.Address, ContactInformationType);
		Else
			NewRow.Contact = ArrayElement;
		EndIf;
		
		FinishFillingContactsFields(NewRow.Contact, NewRow.ContactPresentation, NewRow.HowToContact, ContactInformationType);
		
		If SeparateByNumberOfAddresses Then
			
			AddressesArray = StrSplit(NewRow.HowToContact, ";", False);
			
			If AddressesArray.Count() > 1 Then
				
				NewRow.HowToContact = AddressesArray[0];
				
				For Indus = 1 To AddressesArray.Count() - 1 Do
					
					AdditionalString1 = Attendees.Add();
					AdditionalString1.Contact               = NewRow.Contact;
					AdditionalString1.ContactPresentation = NewRow.ContactPresentation;
					AdditionalString1.HowToContact          = AddressesArray[Indus];
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ConvertAddressByInformationType(Address, ContactInformationType = Undefined)
	
	If ContactInformationType = Undefined Or IsBlankString(Address) Then
		Return Address;
	EndIf;
	
	If ContactInformationType <> Enums.ContactInformationTypes.Phone Then
		Return Address
	EndIf;
		
	RowsArrayWithPhones = New Array;
	For Each ArrayElement In StrSplit(Address, ";", False) Do
		If PhoneNumberSpecifiedCorrectly(ArrayElement) Then
			RowsArrayWithPhones.Add(ArrayElement);
		EndIf;
	EndDo;
	
	If RowsArrayWithPhones.Count() > 0 Then
		Return StrConcat(RowsArrayWithPhones, ";");
	EndIf;
	
EndFunction

// Fills in other field values in rows of the interaction document participants tabular section.
//
// Parameters:
//  Contact                 - CatalogRef - a contact based on whose data other fields will be filled in.
//  Presentation           - String - contact presentation.
//  Address                   - String - contact’s contact information.
//  ContactInformationType - EnumRef.ContactInformationTypes - contact’s contact information.
//
Procedure FinishFillingContactsFields(Contact, Presentation, Address, ContactInformationType = Undefined) Export
	
	If Not ValueIsFilled(Contact) 
		Or (Not IsBlankString(Presentation) And Not IsBlankString(Address)) Then
		Return;
	EndIf;
	
	If ContactInformationType <> Enums.ContactInformationTypes.Email Then
		
		If IsBlankString(Address) Then
			InteractionsServerCall.PresentationAndAllContactInformationOfContact(
				Contact, Presentation, Address, ContactInformationType);
		EndIf;
	
	Else
		
		If StrFind(Address, "@") <> 0 Then
			Return;
		EndIf;
	
		Addresses = InteractionsServerCall.ContactDescriptionAndEmailAddresses(Contact);
		If Addresses <> Undefined And Addresses.Addresses.Count() > 0 Then
			Item = Addresses.Addresses.Get(0);
			Address         = Item.Value;
			Presentation = Addresses.Description;
		EndIf;
		
	EndIf;
	
EndProcedure

// Generates a presentation string of the interaction participant list.
//
// Parameters:
//  Object - DocumentObject - a string is generated based on the participants tabular section of this document.
//
Procedure GenerateParticipantsList(Object) Export
	
	If  TypeOf(Object) = Type("DocumentObject.SMSMessage") Then
		TableName = "SMSMessageRecipients";
	Else 
		TableName = "Attendees";
	EndIf;
	
	Object.ParticipantsList = "";
	For Each Member In Object[TableName] Do
		Object.ParticipantsList = Object.ParticipantsList + ?(Object.ParticipantsList = "", "", "; ") + Member.ContactPresentation;
	EndDo;
	
EndProcedure

// Generates a selection list for quick filter by an interaction type using the email client only.
//
// Parameters:
//  Item - FormField - an item, for which the selection list is being generated.
//
Procedure GenerateChoiceListInteractionTypeEmailOnly(Item)
	
	Item.ChoiceList.Clear();
	Item.ChoiceList.Add("AllEmails", NStr("en = 'All mail';"));
	Item.ChoiceList.Add("IncomingMessages", NStr("en = 'Inbox';"));
	Item.ChoiceList.Add("MessageDrafts", NStr("en = 'Drafts';"));
	Item.ChoiceList.Add("OutgoingMessages", NStr("en = 'Outbox';"));
	Item.ChoiceList.Add("SentMessages", NStr("en = 'Sent';"));
	Item.ChoiceList.Add("DeletedMessages", NStr("en = 'Trash';"));
	
EndProcedure

// Parameters:
//  Contacts - Array of DefinedType.InteractionContact
//  RecipientsGroup - String - Name of the group to search email addresses for. For example, "Recipients", "CC".
//
// Returns:
//   ValueTable:
//     * Contact - DefinedType.InteractionContact
//     * Presentation - String
//     * Address - String
//     * AddressesList - String
//   Undefined
//
Function ContactsEmailAddresses(Contacts, RecipientsGroup = "") Export
	
	If Contacts.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	// ACC:96-off - The JOIN keyword (as the same user might belong to multiple user groups).
	QueryText = 
		"SELECT ALLOWED
		|	ContactInformationTable.EMAddress AS Address,
		|	ContactTable.Ref AS Contact
		|INTO AddressContacts
		|FROM
		|	Catalog.Users AS ContactTable
		|		LEFT JOIN Catalog.Users.ContactInformation AS ContactInformationTable
		|		ON (ContactInformationTable.Ref = ContactTable.Ref)
		|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))
		|WHERE
		|	ContactTable.Ref IN(&ContactsArray)
		|	AND NOT ContactTable.IsInternal
		|	AND NOT ContactTable.Invalid
		|	AND NOT ContactTable.DeletionMark
		|
		|UNION
		|
		|SELECT
		|	ContactInformationTable.EMAddress,
		|	ContactTable.Ref
		|FROM
		|	Catalog.Users AS ContactTable
		|		LEFT JOIN Catalog.Users.ContactInformation AS ContactInformationTable
		|		ON (ContactInformationTable.Ref = ContactTable.Ref)
		|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))
		|WHERE
		|	NOT ContactTable.IsInternal
		|	AND NOT ContactTable.Invalid
		|	AND NOT ContactTable.DeletionMark
		|	AND TRUE IN
		|			(SELECT
		|				TRUE
		|			FROM
		|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
		|			WHERE
		|				UserGroupCompositions.User = ContactTable.Ref
		|				AND UserGroupCompositions.UsersGroup IN (&ContactsArray))";	
	// ACC:96-on
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;

		QueryText = 
		"SELECT DISTINCT
		|	ContactInformationTable.EMAddress,
		|	ContactTable.Ref
		|FROM
		|	&CatalogTable AS ContactTable
		|		LEFT JOIN TheNameOfTheTableContactInformation AS ContactInformationTable
		|		ON (ContactInformationTable.Ref = ContactTable.Ref)
		|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.Email))
		|WHERE
		|	NOT ContactTable.DeletionMark
		|	AND ContactTable.Ref IN(&ContactsArray)
		|	AND &HierarchicalCondition";
		
		QueryText = StrReplace(QueryText, "&CatalogTable", "Catalog." + ContactDescription.Name);
		QueryText = StrReplace(QueryText, "AND &HierarchicalCondition", 
			?(ContactDescription.Hierarchical, " AND (NOT ContactTable.IsFolder)",""));
		QueryText = StrReplace(QueryText, "TheNameOfTheTableContactInformation", 
			"Catalog." + ContactDescription.Name + ".ContactInformation");
		QueryTexts.Add(QueryText); 
			
	EndDo;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AddressContacts.Contact,
		|	PRESENTATION(AddressContacts.Contact) AS Presentation,
		|	&Group
		|FROM
		|	AddressContacts AS AddressContacts
		|ORDER BY
		|	Contact
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AddressContacts.Contact AS Contact,
		|	AddressContacts.Address AS Address
		|FROM
		|	AddressContacts AS AddressContacts
		|ORDER BY
		|	Contact
		|TOTALS
		|BY
		|	Contact
		|"; // @query-part-1
	
	Query = New Query(QueryText);
	Query.SetParameter("ContactsArray", Contacts);
	Query.SetParameter("Group", RecipientsGroup);
	Result = Query.ExecuteBatch();
	
	ResultTable1 = Result[1].Unload(); // ValueTable
	
	TypesArray = New Array;
	TypesArray.Add(Type("String"));
	
	ResultTable1.Columns.Add("Address", New TypeDescription(TypesArray, , New StringQualifiers(100)));
	ResultTable1.Columns.Add("AddressesList", New TypeDescription(TypesArray));
	ContactsSelection = Result[2].Select(QueryResultIteration.ByGroups);
	
	For Each TableRow In ResultTable1 Do
		ContactsSelection.Next();
		AddressesSelection = ContactsSelection.Select();
		While AddressesSelection.Next() Do
			If IsBlankString(TableRow.Address) Then
				TableRow.Address = AddressesSelection.Address;
			EndIf;
			TableRow.AddressesList = TableRow.AddressesList 
				+ ?(IsBlankString(TableRow.AddressesList), "", ";") + AddressesSelection.Address;
		EndDo;
	EndDo;
	
	Return ResultTable1;
	
EndFunction

// Parameters:
//  UserAccount - CatalogRef.EmailAccounts - an account to be used to send the email.
//  MessageFormat - EnumRef.EmailEditingMethods - an email format.
//  ForNewEmail - Boolean - indicates whether an outgoing email is being created.
//
// Returns:
//   Structure   - Structure containing user session parameters for an outgoing email.
//
Function GetUserParametersForOutgoingEmail(EmailAccount,MessageFormat,ForNewEmail) Export
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("Signature", Undefined);
	ReturnStructure.Insert("RequestDeliveryReceipt", False);
	ReturnStructure.Insert("RequestReadReceipt", False);
	ReturnStructure.Insert("DisplaySourceEmailBody", False);
	ReturnStructure.Insert("IncludeOriginalEmailBody", False);
	
	EmailOperationSettings = EmailOperationSettings();
	EnableSignature = False;

	If ForNewEmail Then
		
		Query = New Query;
		Query.Text = "SELECT
		|	EmailAccountSignatures.AddSignatureForNewMessages,
		|	EmailAccountSignatures.NewMessageSignatureFormat,
		|	EmailAccountSignatures.SignatureForNewMessagesFormattedDocument,
		|	EmailAccountSignatures.SignatureForNewMessagesPlainText
		|FROM
		|	InformationRegister.EmailAccountSettings AS EmailAccountSignatures
		|WHERE
		|	EmailAccountSignatures.EmailAccount = &EmailAccount";
		
		Query.SetParameter("EmailAccount",EmailAccount);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			Selection = Result.Select();
			Selection.Next();
			
			EnableSignature = Selection.AddSignatureForNewMessages;
			If EnableSignature Then
				SignatureFormat                  = Selection.NewMessageSignatureFormat;
				SignaturePlainText            = Selection.SignatureForNewMessagesPlainText;
				SignatureFormattedDocument = Selection.SignatureForNewMessagesFormattedDocument.Get();
			EndIf;
			
		EndIf;
		
		If Not EnableSignature Then
			EnableSignature = ?(EmailOperationSettings.Property("AddSignatureForNewMessages"),
			                    EmailOperationSettings.AddSignatureForNewMessages,
			                    False);
			
			If EnableSignature Then
			
				SignatureFormat                  = EmailOperationSettings.NewMessageSignatureFormat;
				SignaturePlainText            = EmailOperationSettings.SignatureForNewMessagesPlainText;
				SignatureFormattedDocument = EmailOperationSettings.NewMessageFormattedDocument;
			
			EndIf;
		EndIf;
		
	Else
		
		Query = New Query;
		Query.Text = "SELECT
		|	EmailAccountSignatures.AddSignatureOnReplyForward,
		|	EmailAccountSignatures.ReplyForwardSignatureFormat,
		|	EmailAccountSignatures.ReplyForwardSignaturePlainText,
		|	EmailAccountSignatures.ReplyForwardSignatureFormattedDocument
		|FROM
		|	InformationRegister.EmailAccountSettings AS EmailAccountSignatures
		|WHERE
		|	EmailAccountSignatures.EmailAccount = &EmailAccount";
		
		Query.SetParameter("EmailAccount", EmailAccount);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			EnableSignature = Selection.AddSignatureOnReplyForward;
			If EnableSignature Then
				SignatureFormat                  = Selection.ReplyForwardSignatureFormat;
				SignaturePlainText            = Selection.ReplyForwardSignaturePlainText;
				SignatureFormattedDocument = Selection.ReplyForwardSignatureFormattedDocument.Get();
			EndIf;
			
		EndIf;
		
		If Not EnableSignature Then
			
			EnableSignature = ?(EmailOperationSettings.Property("AddSignatureOnReplyForward"),
			                    EmailOperationSettings.AddSignatureOnReplyForward,
			                    False);
			
			If EnableSignature Then
				SignatureFormat                  = EmailOperationSettings.ReplyForwardSignatureFormat;
				SignaturePlainText            = EmailOperationSettings.ReplyForwardSignaturePlainText;
				SignatureFormattedDocument = EmailOperationSettings.OnReplyForwardFormattedDocument;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ReturnStructure.RequestDeliveryReceipt = 
		?(EmailOperationSettings.Property("AlwaysRequestDeliveryReceipt"),
	                                       EmailOperationSettings.AlwaysRequestDeliveryReceipt, False);
	ReturnStructure.RequestReadReceipt = 
		?(EmailOperationSettings.Property("AlwaysRequestReadReceipt"),
	                                        EmailOperationSettings.AlwaysRequestReadReceipt, False);
	ReturnStructure.DisplaySourceEmailBody = 
		?(EmailOperationSettings.Property("DisplaySourceEmailBody"),
	                                       EmailOperationSettings.DisplaySourceEmailBody, False);
	ReturnStructure.IncludeOriginalEmailBody = 
		?(EmailOperationSettings.Property("IncludeOriginalEmailBody"),
	                                       EmailOperationSettings.IncludeOriginalEmailBody, False);
	
	If EnableSignature Then
		
		If MessageFormat = Enums.EmailEditingMethods.NormalText Then
			
			ReturnStructure.Signature = Chars.LF + Chars.LF + SignaturePlainText;
			
		Else
			
			If SignatureFormat = Enums.EmailEditingMethods.NormalText Then
				
				FormattedDocument = New FormattedDocument;
				FormattedDocument.Add(Chars.LF + Chars.LF + SignaturePlainText);
				ReturnStructure.Signature = FormattedDocument;
				
			Else
				
				If SignatureFormattedDocument <> Undefined Then

					FormattedDocument = SignatureFormattedDocument;
					FormattedDocument.Insert(FormattedDocument.GetBeginBookmark(),,
					                                 FormattedDocumentItemType.Linefeed);
					FormattedDocument.Insert(FormattedDocument.GetBeginBookmark(),,
					                                 FormattedDocumentItemType.Linefeed);
					ReturnStructure.Signature = FormattedDocument;
				
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

// Returns:
//   EnumRef.ReplyToReadReceiptPolicies - How to respond to read receipt requests.
//
Function GetUserParametersForIncomingEmail() Export

	EmailOperationSettings = EmailOperationSettings();
	Return ?(EmailOperationSettings.Property("ReplyToReadReceiptPolicies"),
	          EmailOperationSettings.ReplyToReadReceiptPolicies,
	          Enums.ReplyToReadReceiptPolicies.AskBeforeSendReadReceipt);

EndFunction

Procedure AddToAddresseesParameter(Source, EmailParameters, ParameterName, TableName) Export
	
	If TypeOf(Source) = Type("FormDataStructure") Or TypeOf(Source) = Type("DocumentObject.OutgoingEmail")
		Or TypeOf(Source) = Type("ValueTableRow") Then
		Table = Source[TableName];
	ElsIf TypeOf(Source) = Type("QueryResultSelection") Then
		Table = Source[TableName].Unload();
	Else
		Return;
	EndIf;
	
	If Table.Count() = 0 Then
		Return;
	EndIf;
	
	SMSMessageRecipients = New Array;
	For Each TableRow In Table Do
		SMSMessageRecipients.Add(New Structure("Address,Presentation", TableRow.Address, TableRow.Presentation));
	EndDo;
	
	EmailParameters.Insert(ParameterName, SMSMessageRecipients);
	
EndProcedure

// Parameters:
//  Object - DocumentObject.OutgoingEmail - an email to be sent.
//
// Returns:
//   See EmailOperations.SendMail
//
Function ExecuteEmailSending(Object, Join = Undefined, EmailParameters = Undefined, MailProtocol = "")
	
	EmailParameters = EmailSendingParameters(Object);
	MailMessage = EmailOperations.PrepareEmail(Object.Account, EmailParameters);
	SendingResult = EmailOperations.SendMail(Object.Account, MailMessage);
	Object.MessageID = SendingResult.SMTPEmailID;
	Object.MessageIDIMAPSending = SendingResult.IMAPEmailID;
	EmailParameters.Insert("MessageID", SendingResult.SMTPEmailID);
	EmailParameters.Insert("WrongRecipients", SendingResult.WrongRecipients);
	
	Return SendingResult;
	
EndFunction

Function EmailObjectAttachedFilesData(EmailObject)
	
	Result = New Structure;
	Result.Insert("FilesOwner", EmailObject.Ref);
	Result.Insert("AttachedFilesCatalogName", 
		EmailManagement.MetadataObjectNameOfAttachedEmailFiles(EmailObject.Ref));
		
	InteractionsOverridable.OnReceiveAttachedFiles(EmailObject.Ref, Result);
	
	// ACC:223-off For backward compatibility.
	AttachedEmailFilesData = InteractionsOverridable.AttachedEmailFilesMetadataObjectData(EmailObject);
	// ACC:223-on
	If AttachedEmailFilesData <> Undefined Then
		Result.AttachedFilesCatalogName = AttachedEmailFilesData.CatalogNameAttachedFiles;
		Result.FilesOwner = AttachedEmailFilesData.Owner;
	EndIf;
	Return Result;
	
EndFunction

Function AttachedEmailFilesData(EmailRef) Export
	
	Result = New Structure;
	Result.Insert("FilesOwner", EmailRef);
	Result.Insert("AttachedFilesCatalogName", 
		EmailManagement.MetadataObjectNameOfAttachedEmailFiles(EmailRef));
		
	InteractionsOverridable.OnReceiveAttachedFiles(EmailRef, Result);
	
	// ACC:223-off For backward compatibility.
	AttachedEmailFilesData = InteractionsOverridable.AttachedEmailFilesMetadataObjectData(EmailRef);
	// ACC:223-on
	If AttachedEmailFilesData <> Undefined Then
		Result.AttachedFilesCatalogName = AttachedEmailFilesData.CatalogNameAttachedFiles;
		Result.FilesOwner = AttachedEmailFilesData.Owner;
	EndIf;
	Return Result;
	
EndFunction

Function EmailSendingParameters(Object) Export
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		SignatureFilesExtension = ModuleDigitalSignature.PersonalSettings().SignatureFilesExtension;
	Else
		SignatureFilesExtension = "p7s";
	EndIf;
	
	EmailParameters = New Structure;

	AddToAddresseesParameter(Object, EmailParameters,"Whom",         "EmailRecipients");
	AddToAddresseesParameter(Object, EmailParameters,"Cc",        "CCRecipients");
	AddToAddresseesParameter(Object, EmailParameters,"BCCs", "BccRecipients");
	AddToAddresseesParameter(Object, EmailParameters,"ReplyToAddress",  "ReplyRecipients");
	EmailParameters.Insert("Subject", Object.Subject);
	EmailParameters.Insert("Body", ?(Object.TextType = Enums.EmailTextTypes.PlainText,
	                                   Object.Text, Object.HTMLText));
	EmailParameters.Insert("Encoding", Object.Encoding);
	EmailParameters.Insert("Importance",  EmailManagement.GetImportance(Object.Importance));
	EmailParameters.Insert("TextType", Object.TextType);
	
	If Not IsBlankString(Object.BasisID) Then
		EmailParameters.Insert("BasisID", Object.BasisID);
	EndIf;
	
	If Not IsBlankString(Object.BasisIDs) Then
		EmailParameters.Insert("BasisIDs", Object.BasisIDs);
	EndIf;
	
	AttachmentsArray = New Array;
	
	AttachedEmailFilesData = EmailObjectAttachedFilesData(Object);
	MetadataObjectName = AttachedEmailFilesData.AttachedFilesCatalogName;
	FilesOwner       = AttachedEmailFilesData.FilesOwner;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Files.Description               AS FullDescr,
	|	Files.Extension                 AS Extension,
	|	Files.Ref                     AS Ref,
	|	&Encrypted,
	|	Files.EmailFileID  AS EmailFileID
	|FROM
	|	&NameOfTheReferenceTable AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner
	|;
	|
	|//////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	EmailOutgoingEmailsAttachments.MailMessage                     AS MailMessage,
	|	EmailOutgoingEmailsAttachments.SequenceNumberInAttachments AS SequenceNumberInAttachments
	|FROM
	|	Document.OutgoingEmail.EmailAttachments AS EmailOutgoingEmailsAttachments
	|WHERE
	|	EmailOutgoingEmailsAttachments.Ref = &FileOwner
	|
	|ORDER BY SequenceNumberInAttachments ASC";
	
	Query.Text = StrReplace(Query.Text, "&NameOfTheReferenceTable", "Catalog." + MetadataObjectName);
	
	If Metadata.Catalogs[MetadataObjectName].Attributes.Find("Encrypted") <> Undefined Then 
		Query.Text = StrReplace(Query.Text, "&Encrypted", "Files.Encrypted                 AS Encrypted");
	Else
		Query.Text = StrReplace(Query.Text, "&Encrypted", "FALSE                 AS Encrypted");
	EndIf;
	
	Query.SetParameter("FileOwner", FilesOwner);
	QueryResult = Query.ExecuteBatch();
	
	AttachmentsSelection = QueryResult[0].Select();
	AttachmentEmailTable = QueryResult[1].Unload();
	
	AttachmentsCount = AttachmentEmailTable.Count() + AttachmentsSelection.Count();
	
	DisplayedAttachmentNumber = 1;
	While AttachmentsSelection.Next() Do
		
		AddAttachmentEmailIfRequired(AttachmentEmailTable, AttachmentsArray, DisplayedAttachmentNumber);
		FileName = AttachmentsSelection.FullDescr + ?(AttachmentsSelection.Extension = "", "", "." + AttachmentsSelection.Extension)
			+ ?(AttachmentsSelection.Encrypted, "." + EncryptedFilesExtension(), "");
		
		If IsBlankString(AttachmentsSelection.EmailFileID) Then
			AddAttachment(AttachmentsArray, FileName, FilesOperations.FileBinaryData(AttachmentsSelection.Ref));
			DisplayedAttachmentNumber = DisplayedAttachmentNumber + 1;
		Else
			AddAttachment(AttachmentsArray,
			                 FileName, 
			                 FilesOperations.FileBinaryData(AttachmentsSelection.Ref), 
			                 AttachmentsSelection.EmailFileID);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			OwnerDigitalSignatures = ModuleDigitalSignature.SetSignatures(AttachmentsSelection.Ref);
			LineNumber = 1;
			For Each DS In OwnerDigitalSignatures Do
				FileName = AttachmentsSelection.FullDescr + "-DS("+ LineNumber + ")." + SignatureFilesExtension;
				AddAttachment(AttachmentsArray, FileName, DS.Signature);
				LineNumber = LineNumber + 1;
			EndDo;
			
		EndIf;
		
	EndDo;
	
	While DisplayedAttachmentNumber <= AttachmentsCount Do
		
		AddAttachmentEmailIfRequired(AttachmentEmailTable, AttachmentsArray, DisplayedAttachmentNumber);
		DisplayedAttachmentNumber = DisplayedAttachmentNumber + 1;
		
	EndDo;
	
	EmailParameters.Insert("Attachments", AttachmentsArray);
	EmailParameters.Insert("ProcessTexts", False);
	
	If Object.RequestDeliveryReceipt Then
		EmailParameters.Insert("RequestDeliveryReceipt", True);
	EndIf;
	
	If Object.RequestReadReceipt Then
		EmailParameters.Insert("RequestReadReceipt", True);
	EndIf;
	
	Return EmailParameters;
	
EndFunction

Procedure AddAttachmentEmailIfRequired(AttachmentEmailTable, AttachmentsArray, DisplayedAttachmentNumber)
	
	FoundRow = AttachmentEmailTable.Find(DisplayedAttachmentNumber, "SequenceNumberInAttachments");
	While FoundRow <> Undefined Do
		AddAttachmentEmailOutgoingEmail(AttachmentsArray, FoundRow.MailMessage);
		DisplayedAttachmentNumber = DisplayedAttachmentNumber + 1;
		FoundRow = AttachmentEmailTable.Find(DisplayedAttachmentNumber, "SequenceNumberInAttachments");
	EndDo
	
EndProcedure

Procedure AddAttachmentEmailOutgoingEmail(AttachmentsArray, MailMessage); 

	AttachmentStructure = New Structure;
	
	DataEmailMessageInternet = InternetEmailMessageFromEmail(MailMessage);
	
	If DataEmailMessageInternet.InternetMailMessage = Undefined Then
		Return;
	EndIf;
	
	Presentation = EmailPresentation(DataEmailMessageInternet.InternetMailMessage.Subject,
	                                    DataEmailMessageInternet.EmailDate);
	FileName = Presentation + ".eml";
	
	AttachmentStructure.Insert("Encoding", MailMessage.Encoding);
	AttachmentStructure.Insert("AddressInTempStorage",
	                           PutToTempStorage(DataEmailMessageInternet.InternetMailMessage, 
	                                                         New UUID()));
	AttachmentStructure.Insert("MIMEType","message/rfc822");
	AttachmentStructure.Insert("Presentation", FileName);
	
	AttachmentsArray.Add(AttachmentStructure);
	
EndProcedure 

Procedure AddAttachment(AttachmentsArray, FileName, FileData, Id = Undefined, Encoding = Undefined)
	
	AttachmentData = New Structure;
	AttachmentData.Insert("Presentation", FileName);
	AttachmentData.Insert("AddressInTempStorage", FileData);
	
	If ValueIsFilled(Id) Then
		AttachmentData.Insert("Id", Id);
	EndIf;
	If ValueIsFilled(Encoding) Then
		AttachmentData.Insert("Encoding", Encoding);
	EndIf;
	
	AttachmentsArray.Add(AttachmentData);
	
EndProcedure

Function InternetEmailMessageFromEmail(MailMessage) Export
	
	If TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		
		Return InternetEmailMessageFromIncomingEmail(MailMessage);
		
	ElsIf TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		Return InternetEmailMessageFromOutgoingEmail(MailMessage);
		
	Else
		Return Undefined;
	EndIf;

EndFunction

Function InternetEmailMessageFromIncomingEmail(MailMessage)
	
	ReturnStructure = New Structure("InternetMailMessage, EmailDate");
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	IncomingEmail.Importance                 AS Importance,
	|	IncomingEmail.IDAtServer   AS Id,
	|	IncomingEmail.DateReceived            AS DateReceived,
	|	IncomingEmail.Text                    AS Text,
	|	IncomingEmail.HTMLText                AS HTMLText,
	|	IncomingEmail.Encoding                AS Encoding,
	|	IncomingEmail.SenderAddress         AS SenderAddress,
	|	IncomingEmail.SenderPresentation AS SenderPresentation,
	|	IncomingEmail.Subject                     AS Subject,
	|	IncomingEmail.RequestDeliveryReceipt       AS RequestDeliveryReceipt,
	|	IncomingEmail.RequestReadReceipt      AS RequestReadReceipt
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|WHERE
	|	IncomingEmail.Ref = &MailMessage
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////1
	|SELECT
	|	EmailIncomingEmailRecipients.Address,
	|	EmailIncomingEmailRecipients.Presentation,
	|	EmailIncomingEmailRecipients.Contact
	|FROM
	|	Document.IncomingEmail.EmailRecipients AS EmailIncomingEmailRecipients
	|WHERE
	|	EmailIncomingEmailRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailIncomingEmailRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////2
	|SELECT
	|	EmailIncomingCopyRecipients.Address,
	|	EmailIncomingCopyRecipients.Presentation,
	|	EmailIncomingCopyRecipients.Contact
	|FROM
	|	Document.IncomingEmail.CCRecipients AS EmailIncomingCopyRecipients
	|WHERE
	|	EmailIncomingCopyRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailIncomingCopyRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////3
	|SELECT
	|	EmailIncomingReplyRecipients.Address,
	|	EmailIncomingReplyRecipients.Presentation,
	|	EmailIncomingReplyRecipients.Contact
	|FROM
	|	Document.IncomingEmail.ReplyRecipients AS EmailIncomingReplyRecipients
	|WHERE
	|	EmailIncomingReplyRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailIncomingReplyRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////4
	|SELECT
	|	EmailIncomingReadNotificationAddresses.Address,
	|	EmailIncomingReadNotificationAddresses.Presentation,
	|	EmailIncomingReadNotificationAddresses.Contact
	|FROM
	|	Document.IncomingEmail.ReadReceiptAddresses AS EmailIncomingReadNotificationAddresses
	|WHERE
	|	EmailIncomingReadNotificationAddresses.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailIncomingReadNotificationAddresses.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////5
	|SELECT
	|	Files.Description AS FullDescr,
	|	Files.Extension AS Extension,
	|	Files.Ref AS Ref,
	|	Files.EmailFileID
	|FROM
	|	Catalog.IncomingEmailAttachedFiles AS Files
	|WHERE
	|	Files.FileOwner = &MailMessage";
	
	Query.SetParameter("MailMessage", MailMessage);
	
	QueryResult = Query.ExecuteBatch();
	
	QueryResultHeader = QueryResult[0]; // QueryResult
	HeaderSelection = QueryResultHeader.Select();
	
	If HeaderSelection.Next() Then
		
		ObjectInternetEmailMessage = New InternetMailMessage;
		ObjectInternetEmailMessage.Importance               = EmailManagement.GetImportance(HeaderSelection.Importance);
		ObjectInternetEmailMessage.UID.Add(HeaderSelection.Id);
		ObjectInternetEmailMessage.Encoding              = HeaderSelection.Encoding;
		ObjectInternetEmailMessage.Subject                   = HeaderSelection.Subject;
		ObjectInternetEmailMessage.RequestDeliveryReceipt     = HeaderSelection.RequestDeliveryReceipt;
		ObjectInternetEmailMessage.RequestReadReceipt    = HeaderSelection.RequestReadReceipt;
		ObjectInternetEmailMessage.From            = HeaderSelection.SenderAddress;
		
		SenderData = CommonClientServer.ParseStringWithEmailAddresses(HeaderSelection.SenderPresentation, False);
		If TypeOf(SenderData) = Type("Array") And SenderData.Count() > 0 Then
			ObjectInternetEmailMessage.SenderName = SenderData[0].Presentation;
			ObjectInternetEmailMessage.From    = SenderData[0].Address;
		EndIf;
		
		If IsBlankString(HeaderSelection.HTMLText) Then
		
			AddTextToInternetEmailMessageTexts(ObjectInternetEmailMessage.Texts,
			                                               HeaderSelection.Text, 
			                                               InternetMailTextType.PlainText,
			                                               HeaderSelection.Encoding);
		
		EndIf;
		
		AddTextToInternetEmailMessageTexts(ObjectInternetEmailMessage.Texts,
		                                               HeaderSelection.HTMLText, 
		                                               InternetMailTextType.HTML,
		                                               HeaderSelection.Encoding);
		
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	QueryResultRecipients                  = QueryResult[1]; // QueryResult
	QueryResultCopies                       = QueryResult[2]; // QueryResult
	QueryResultReturnAddress               = QueryResult[3]; // QueryResult
	AddressRequestResultReadReceipts = QueryResult[4]; // QueryResult
	QueryResultAttachments                    = QueryResult[5]; // QueryResult
	
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.To, QueryResultRecipients.Select());
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.Cc, QueryResultCopies.Select());
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.ReplyTo, QueryResultReturnAddress.Select());
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.ReadReceiptAddresses, AddressRequestResultReadReceipts.Select());
	AddEmailAttachmentsToEmailMessage(ObjectInternetEmailMessage, QueryResultAttachments.Select());
	
	ReturnStructure.InternetMailMessage = ObjectInternetEmailMessage;
	ReturnStructure.EmailDate                = HeaderSelection.DateReceived;

	Return ReturnStructure;

EndFunction 

Function InternetEmailMessageFromOutgoingEmail(MailMessage)
	
	ReturnStructure = New Structure("InternetMailMessage, EmailDate");
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.PostingDate           AS PostingDate,
	|	OutgoingEmail.Importance                  AS Importance,
	|	OutgoingEmail.IDAtServer    AS Id,
	|	OutgoingEmail.SenderPresentation  AS SenderPresentation,
	|	OutgoingEmail.Encoding                 AS Encoding,
	|	OutgoingEmail.Text                     AS Text,
	|	OutgoingEmail.HTMLText                 AS HTMLText,
	|	OutgoingEmail.TextType                 AS TextType,
	|	OutgoingEmail.Subject                      AS Subject,
	|	OutgoingEmail.RequestDeliveryReceipt        AS RequestDeliveryReceipt,
	|	OutgoingEmail.RequestReadReceipt       AS RequestReadReceipt
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Ref = &MailMessage
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////1
	|SELECT
	|	EmailOutgoingEmailRecipients.Address,
	|	EmailOutgoingEmailRecipients.Presentation
	|FROM
	|	Document.OutgoingEmail.EmailRecipients AS EmailOutgoingEmailRecipients
	|WHERE
	|	EmailOutgoingEmailRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailOutgoingEmailRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////2
	|SELECT
	|	EmailOutgoingReplyRecipients.Address,
	|	EmailOutgoingReplyRecipients.Presentation
	|FROM
	|	Document.OutgoingEmail.ReplyRecipients AS EmailOutgoingReplyRecipients
	|WHERE
	|	EmailOutgoingReplyRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailOutgoingReplyRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////3
	|SELECT
	|	EMailOutgoingCopyRecipients.Address,
	|	EMailOutgoingCopyRecipients.Presentation
	|FROM
	|	Document.OutgoingEmail.CCRecipients AS EMailOutgoingCopyRecipients
	|WHERE
	|	EMailOutgoingCopyRecipients.Ref = &MailMessage
	|
	|ORDER BY
	|	EMailOutgoingCopyRecipients.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////4
	|SELECT
	|	EmailOutgoingEmailsAttachments.MailMessage
	|FROM
	|	Document.OutgoingEmail.EmailAttachments AS EmailOutgoingEmailsAttachments
	|WHERE
	|	EmailOutgoingEmailsAttachments.Ref = &MailMessage
	|
	|ORDER BY
	|	EmailOutgoingEmailsAttachments.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////5
	|SELECT
	|	Files.Description AS FullDescr,
	|	Files.Extension AS Extension,
	|	Files.Ref AS Ref,
	|	Files.EmailFileID
	|FROM
	|	Catalog.OutgoingEmailAttachedFiles AS Files
	|WHERE
	|	Files.FileOwner = &MailMessage";
	
	Query.SetParameter("MailMessage", MailMessage);
	
	QueryResult = Query.ExecuteBatch();
	
	QueryResultHeader = QueryResult[0]; // QueryResult
	HeaderSelection = QueryResultHeader.Select();
	If HeaderSelection.Next() Then
		
		ObjectInternetEmailMessage = New InternetMailMessage;
		ObjectInternetEmailMessage.Importance               = EmailManagement.GetImportance(HeaderSelection.Importance);
		ObjectInternetEmailMessage.UID.Add(HeaderSelection.Id);
		ObjectInternetEmailMessage.Encoding              = HeaderSelection.Encoding;
		ObjectInternetEmailMessage.Subject                   = HeaderSelection.Subject;
		ObjectInternetEmailMessage.RequestDeliveryReceipt     = HeaderSelection.RequestDeliveryReceipt;
		ObjectInternetEmailMessage.RequestReadReceipt    = HeaderSelection.RequestReadReceipt;
		
		SenderData = CommonClientServer.ParseStringWithEmailAddresses(HeaderSelection.SenderPresentation, False);
		
		If TypeOf(SenderData) = Type("Array") And SenderData.Count() > 0 Then
			ObjectInternetEmailMessage.SenderName = SenderData[0].Presentation;
			ObjectInternetEmailMessage.From    = SenderData[0].Address;
		EndIf;
		
		If IsBlankString(HeaderSelection.HTMLText) Then
		
			AddTextToInternetEmailMessageTexts(ObjectInternetEmailMessage.Texts,
			                                               HeaderSelection.Text, 
			                                               InternetMailTextType.PlainText,
			                                               HeaderSelection.Encoding);
		
		EndIf;
		
		AddTextToInternetEmailMessageTexts(ObjectInternetEmailMessage.Texts,
		                                               HeaderSelection.HTMLText, 
		                                               InternetMailTextType.HTML,
		                                               HeaderSelection.Encoding);
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	QueryResultRecipients                  = QueryResult[1]; // QueryResult
	QueryResultReturnAddress               = QueryResult[2]; // QueryResult
	QueryResultCopies                       = QueryResult[3]; // QueryResult
	QueryResultAttachments                    = QueryResult[5]; // QueryResult

	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.To, QueryResultRecipients.Select());
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.ReplyTo, QueryResultReturnAddress.Select());
	AddRecipientsToEmailMessageBySelection(ObjectInternetEmailMessage.Cc, QueryResultCopies.Select());
	AddEmailAttachmentsToEmailMessage(ObjectInternetEmailMessage,       QueryResultAttachments.Select());
	
	ReturnStructure.InternetMailMessage = ObjectInternetEmailMessage;
	ReturnStructure.EmailDate                = HeaderSelection.PostingDate;

	Return ReturnStructure;
	
EndFunction

Procedure AddTextToInternetEmailMessageTexts(MessageTexts, MessageText, TextType, Encoding)
	
	If Not IsBlankString(MessageText) Then
		
		NewText = MessageTexts.Add(MessageText, TextType);
		NewText.Encoding = Encoding;
		
	EndIf;
	
EndProcedure

Procedure AddRecipientsToEmailMessageBySelection(AddresseesTable, Selection)
	
	While Selection.Next() Do
		
		AddRecipientToEmailMessage(AddresseesTable, Selection.Address, Selection.Presentation)
		
	EndDo;
	
EndProcedure

Procedure AddRecipientToEmailMessage(AddresseesTable, Address, Presentation)
	
	EmailRecipient                 = AddresseesTable.Add(Address);
	EmailRecipient.DisplayName = Presentation;
	
EndProcedure

Procedure AddEmailAttachmentsToEmailMessage(Message, AttachmentsSelection)
	
	While AttachmentsSelection.Next() Do
		
		Name   = AttachmentsSelection.FullDescr 
		        + ?(AttachmentsSelection.Extension = "", "", "." + AttachmentsSelection.Extension);
		Data = FilesOperations.FileBinaryData(AttachmentsSelection.Ref);
		
		EmailAttachment = Message.Attachments.Add(Data, Name);

		If Not IsBlankString(AttachmentsSelection.EmailFileID) Then
			EmailAttachment.CID = AttachmentsSelection.EmailFileID;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
			AttachmentSignatures = ModuleDigitalSignature.SetSignatures(AttachmentsSelection.Ref);
			LineNumber = 1;
			For Each DS In AttachmentSignatures Do
				Name = AttachmentsSelection.FullDescr + "-DS("+ LineNumber + ")." + SignatureFilesExtension();
				Data = DS.Signature;
				
				EmailAttachment = Message.Attachments.Add(Data, Name);
				LineNumber = LineNumber + 1;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  MailMessage - DocumentRef.OutgoingEmail - Email message whose attachment info needs to be received.
// 
// Returns:
//  ValueTable:
//   * MailMessage - DocumentRef.OutgoingEmail - Attached email message.
//   * Size - Number - the attachment size.
//   * Subject   - String - a subject of the attached email message.
//   * Date   - Date - the attached email message date.
//
Function DataStoredInAttachmentsEmailsDatabase(MailMessage) Export

	// ACC:96-off - The JOIN keyword (as the same email message might be attached to multiple email messages).
	Query = New Query(
		"SELECT
		|	EmailOutgoingEmailsAttachments.MailMessage AS MailMessage,
		|	IncomingEmail.Size AS Size,
		|	IncomingEmail.Subject AS Subject,
		|	IncomingEmail.DateReceived AS Date
		|FROM
		|	Document.OutgoingEmail.EmailAttachments AS EmailOutgoingEmailsAttachments
		|		INNER JOIN Document.IncomingEmail AS IncomingEmail
		|		ON EmailOutgoingEmailsAttachments.MailMessage = IncomingEmail.Ref
		|WHERE
		|	EmailOutgoingEmailsAttachments.Ref = &MailMessage
		|
		|UNION
		|
		|SELECT
		|	EmailOutgoingEmailsAttachments.MailMessage,
		|	OutgoingEmail.Size,
		|	OutgoingEmail.Subject,
		|	CASE
		|		WHEN OutgoingEmail.PostingDate = DATETIME(1, 1, 1, 1, 1, 1)
		|			THEN OutgoingEmail.Date
		|		ELSE OutgoingEmail.PostingDate
		|	END
		|FROM
		|	Document.OutgoingEmail.EmailAttachments AS EmailOutgoingEmailsAttachments
		|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
		|		ON EmailOutgoingEmailsAttachments.MailMessage = OutgoingEmail.Ref
		|WHERE
		|	EmailOutgoingEmailsAttachments.Ref = &MailMessage");
	// ACC:96-on
	
	Query.SetParameter("MailMessage", MailMessage);
	Return Query.Execute().Unload();
	
EndFunction 

// Parameters:
//  Form - ClientApplicationForm - a form for which a procedure is performed:
//   * Object - DocumentObject.IncomingEmail
//           - DocumentObject.OutgoingEmail - Email message to set the header for.
//
Procedure SetEmailFormHeader(Form) Export

	ObjectEmail = Form.Object;
	If Not ObjectEmail.Ref.IsEmpty() Then
		Form.AutoTitle = False;
		
		FormCaption = ?(IsBlankString(ObjectEmail.Subject), NStr("en = 'No-subject email (%1)';"), ObjectEmail.Subject + " (%1)");
		Form.Title  = StringFunctionsClientServer.SubstituteParametersToString(FormCaption,
			?(TypeOf(ObjectEmail.Ref) = Type("DocumentRef.IncomingEmail"), NStr("en = 'Incoming';"), NStr("en = 'Outgoing';")));
			
	Else
		If TypeOf(ObjectEmail.Ref) = Type("DocumentRef.OutgoingEmail") Then
			Form.AutoTitle = False;
			Form.Title = NStr("en = 'Mail message (Create)';");
		EndIf;
	EndIf;

EndProcedure

Function SendEmailsInHTMLFormat() 
	Return GetFunctionalOption("SendEmailsInHTMLFormat");
EndFunction

#Region UpdateHandlers

Procedure DisableSubsystemSaaS() Export

	If Common.DataSeparationEnabled() Then
		
		Constants.UseEmailClient.Set(False);
		Constants.UseReviewedFlag.Set(False);
		Constants.UseOtherInteractions.Set(False);
		Constants.SendEmailsInHTMLFormat.Set(False);
		
	EndIf;

EndProcedure

#EndRegion 

//////////////////////////////////////////////////////////////////////////////////
//   Managing items and attributes of list forms and document forms.

// Dynamically generates the "Address book" and "Pick contacts" common forms according to the possible contact types.
//
// Parameters:
//  Form - See CommonForm.SelectContactPerson
//
Procedure AddContactsPickupFormPages(Form) Export
	
	DynamicListTypeDetails = New TypeDescription("DynamicList");
	
	AttributesToBeAdded = New Array;
	ContactsDetails = InteractionsClientServer.ContactsDetails();
	PrefixTable    = InteractionsClientServer.PrefixTable();
	
	// Create dynamic lists.
	For Each ContactDescription In ContactsDetails Do
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		ListName = "List_" + ContactDescription.Name;
		AttributesToBeAdded.Add(
			New FormAttribute(ListName, DynamicListTypeDetails));
			
	EndDo;
	
	Form.ChangeAttributes(AttributesToBeAdded);
	
	// Setting main tables and required use of the IsFolder attribute in dynamic lists.
	HasAddressColumns = New Map;
	For Each ContactDescription In ContactsDetails Do
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		ListName = "List_" + ContactDescription.Name;
		HasAddressColumn = SetContactQueryText(Form[ListName], ContactDescription);
		HasAddressColumns[ContactDescription.Name] = HasAddressColumn;
		If HasAddressColumn Then
			Form.AddedTablesNames.Add(ListName);
		EndIf;
	EndDo;
	
	For Each ContactDescription In ContactsDetails Do
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
		
		If Not ContactDescription.HasOwner  Then
			
			PageItem = Form.Items.Add(
				"Page_" + ContactDescription.Name,Type("FormGroup"), Form.Items.PagesLists); // FormGroup
			PageItem.Type                  = FormGroupType.Page;
			PageItem.ShowTitle  = True;
			PageItem.Title            = ContactDescription.Presentation;
			PageItem.Group          = ChildFormItemsGroup.Vertical;
			
		EndIf;
		
		ItemTable = Form.Items.Add(PrefixTable + ContactDescription.Name,	Type("FormTable"),
			Form.Items[?(ContactDescription.HasOwner, 
				"Page_" + ContactDescription.OwnerName,
				"Page_" + ContactDescription.Name)]);
		ItemTable.DataPath = "List_" + ContactDescription.Name;
		ItemTable.SetAction("Selection", "Attachable_CatalogListChoice");
		ItemTable.AutoMaxHeight = False;
		ItemTable.AutoMaxWidth = False;
		If Form.FormName = "CommonForm.SelectContactPerson" Then
			ItemTable.SelectionMode = TableSelectionMode.SingleRow;
			ItemTable.SetAction("OnActivateRow", "Attachable_ListContactsOnActivateRow");
		EndIf;
		If ContactDescription.HasOwner Then
			Form.Items[PrefixTable + ContactDescription.OwnerName].SetAction(
				"OnActivateRow", "Attachable_ListOwnerOnActivateRow");
			CommonClientServer.SetDynamicListFilterItem(
				Form["List_" + ContactDescription.Name], "Owner", Undefined, , , True);
			ItemTable.Height = 5;
			Form.Items[PrefixTable + ContactDescription.OwnerName].Height = 5;
		Else
			ItemTable.Height = 10;
		EndIf;
		
		ColumnRef = Form.Items.Add(
			"Column_" + ContactDescription.Name + "_Ref", Type("FormField"), ItemTable);
		ColumnRef.Type = FormFieldType.InputField;
		ColumnRef.DataPath = "List_" + ContactDescription.Name + ".Ref";
		ContactMetadata = Metadata.FindByType(ContactDescription.Type);
		ColumnRef.Title = Common.ObjectPresentation(ContactMetadata);
		
		If HasAddressColumns[ContactDescription.Name] Then
			AddressColumn = Form.Items.Add(
				"Column_" + ContactDescription.Name + "_Address", Type("FormField"), ItemTable);
			AddressColumn.Type = FormFieldType.InputField;
			AddressColumn.DataPath = "List_" + ContactDescription.Name + ".Address";
			AddressColumn.Title = NStr("en = 'Email';");
		EndIf;
		
	EndDo;
	
EndProcedure

Function SetContactQueryText(List, ContactDescription)
	
	ContactMetadata = Metadata.FindByType(ContactDescription.Type);
	HasKindForList = ContactMetadata.TabularSections.ContactInformation.Attributes.Find("KindForList") <> Undefined;
	
	If HasKindForList Then
		QueryText = 
		"SELECT ALLOWED
		|	CatalogContact.Ref,
		|	CatalogContact.DeletionMark,
		|	CatalogContact.Predefined,
		|	PRESENTATION(CatalogContact.Ref) AS Description,
		|	CatalogContactInformation.Presentation AS Address
		|FROM
		|	#Table AS CatalogContact
		|	LEFT JOIN #Table.ContactInformation AS CatalogContactInformation
		|	ON (CatalogContactInformation.Ref = CatalogContact.Ref)
		|		AND (CatalogContactInformation.KindForList = &Email)
		|WHERE
		|	CatalogContact.DeletionMark = FALSE";
	Else
		QueryText = 
		"SELECT ALLOWED
		|	CatalogContact.Ref,
		|	CatalogContact.DeletionMark,
		|	CatalogContact.Predefined,
		|	PRESENTATION(CatalogContact.Ref) AS Description
		|FROM
		|	#Table AS CatalogContact
		|WHERE
		|	CatalogContact.DeletionMark = FALSE";
	EndIf;	
	QueryText = StrReplace(QueryText, "#Table", "Catalog." + ContactDescription.Name);
	
	List.QueryText = QueryText;
	List.MainTable = "Catalog." + ContactDescription.Name;
	List.DynamicDataRead = True;
	
	If HasKindForList Then
		ObjectManager = Common.ObjectManagerByFullName("Catalog." + ContactDescription.Name);
		ContactInformationKinds = ContactsManager.ObjectContactInformationKinds(
			ObjectManager.EmptyRef(), Enums.ContactInformationTypes.Email);
		If ContactInformationKinds.Count() > 0 Then
			KindEmail = ContactInformationKinds[0].Ref;
		Else
			KindEmail = Undefined;
		EndIf;	
		List.Parameters.SetParameterValue("Email", KindEmail);
	EndIf;
	
	Return HasKindForList;
	
EndFunction	

// Sets a filter for a dynamic list of interaction documents, excluding documents that do not belong to mail.
//
// Parameters:
//  List - DynamicList - a dynamic list, for which the filter is being set.
//
Procedure CreateFilterByTypeAccordingToFR(List)
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		InteractionsClientServer.DynamicListFilter(List).Items, "FIlterByTypeAccordingToFO",
		DataCompositionFilterItemsGroupType.AndGroup);
	
	FieldName                    = "Type";
	FilterItemCompareType = DataCompositionComparisonType.NotInList;
	TypesList = New ValueList;
	TypesList.Add(Type("DocumentRef.Meeting"));
	TypesList.Add(Type("DocumentRef.PlannedInteraction"));
	TypesList.Add(Type("DocumentRef.PhoneCall"));
	TypesList.Add(Type("DocumentRef.SMSMessage"));
	RightValue             = TypesList;
	CommonClientServer.AddCompositionItem(
		FilterGroup, FieldName, FilterItemCompareType, RightValue);

EndProcedure

// Parameters:
//  Form     - ClientApplicationForm - the form for which attributes are initialized contains:
//   * Commands - FormCommands - also contain:
//    ** SubjectList - FormCommand - changes the topic.
//    ** SubjectOf       - FormCommand - changes the topic.
//  Parameters - Structure  - parameters of initializing commands.
//
Procedure InitializeInteractionsListForm(Form, Parameters) Export

	If Parameters.Property("OnlyEmail") And Parameters.OnlyEmail Then
		Form.OnlyEmail = True;
	Else
		Form.OnlyEmail = Not GetFunctionalOption("UseOtherInteractions");
	EndIf;
	
	Form.Items.CreateEmailSpecialButtonList.Visible = Form.OnlyEmail;
	Form.Items.GroupCreate.Visible = Not Form.OnlyEmail;
	If Form.OnlyEmail Then
		Form.Title = NStr("en = 'Email';");
		Form.Items.InteractionType.ChoiceListHeight = 6;
		CreateFilterByTypeAccordingToFR(Form.List);
		GenerateChoiceListInteractionTypeEmailOnly(Form.Items.InteractionType);
		Form.Commands.SubjectOf.Title = NStr("en = 'Choose topic';");
		Form.Commands.SubjectOf.ToolTip = NStr("en = 'Choose topic';");
		Form.Items.Copy.Visible = False;
		If Form.Items.Find("InteractionsTreeCopy") <> Undefined Then
			Form.Items.InteractionsTreeCopy.Visible = False;
		EndIf;
		If Form.Items.Find("InteractionsTreeContextMenuCopy") <> Undefined Then
			Form.Items.InteractionsTreeContextMenuCopy.Visible = False;
		EndIf;
		If Form.Items.Find("ListContextMenuCopy") <> Undefined Then
			Form.Items.ListContextMenuCopy.Visible = False;
		EndIf;
		If Form.Commands.Find("SubjectList") <> Undefined Then
			Form.Commands.SubjectList.Title = NStr("en = 'Choose topic';");
			Form.Commands.SubjectList.ToolTip = NStr("en = 'Choose topic';");
		EndIf;
	EndIf;
	Form.UseReviewedFlag = GetFunctionalOption("UseReviewedFlag");

EndProcedure

// Determines whether it is necessary to display an address book and forms of choosing user group contact.
//
// Parameters:
//  Form  - ClientApplicationForm - a form for which the procedure will be executed.
//
Procedure ProcessUserGroupsDisplayNecessity(Form) Export
	
	Form.UseUserGroups = GetFunctionalOption("UseUserGroups");
	If Not Form.UseUserGroups Then
		Form.UsersList.CustomQuery = False;
	Else
		Form.UsersList.Parameters.SetParameterValue("UsersGroup", Catalogs.UserGroups.EmptyRef());
	EndIf;
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////
// Handling interaction subjects.

// Parameters:
//  Ref  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail
//          - DocumentRef.Meeting
//          - DocumentRef.PlannedInteraction
//          - DocumentRef.PhoneCall - Interaction to set the topic for.
//  SubjectOf - AnyRef - a reference to the object to set.
//
Procedure SetSubject(Ref, SubjectOf, CalculateReviewedItems = True) Export
	
	StructureForWrite = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	StructureForWrite.SubjectOf                 = SubjectOf;
	StructureForWrite.CalculateReviewedItems = CalculateReviewedItems;
	InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Ref, StructureForWrite);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////////
// Generate an email.

// Generates an HTML text for an incoming email.
//
// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//  ForPrint  - Boolean - indicates that HTML text is generated for an email print form.
//  ProcessPictures - Boolean - indicates that pictures will be nested in HTML.
//
// Returns:
//   String   - HTML text generated for the incoming email message.
//
Function GenerateHTMLTextForIncomingEmail(MailMessage, ForPrint, ProcessPictures,
	DisableExternalResources = True, HasExternalResources = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "
	|SELECT 
	|	IncomingEmail.Ref AS MailMessage,
	|	IncomingEmail.Date,
	|	IncomingEmail.DateReceived,
	|	IncomingEmail.SenderAddress,
	|	IncomingEmail.SenderPresentation,
	|	IncomingEmail.Text,
	|	IncomingEmail.HTMLText,
	|	IncomingEmail.Subject,
	|	IncomingEmail.TextType AS TextType,
	|	IncomingEmail.TextType AS TextTypeConversion,
	|	IncomingEmail.EmailRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	),
	|	IncomingEmail.CCRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	),
	|	ISNULL(EmailAccounts.UserName, """") AS UserAccountUsername,
	|	IncomingEmail.Encoding
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON IncomingEmail.Account = EmailAccounts.Ref
	|WHERE
	|	IncomingEmail.Ref = &MailMessage";
	
	Query.SetParameter("MailMessage",MailMessage);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	GenerationParameters = HTMLDocumentGenerationParametersOnEmailBasis(Selection);
	GenerationParameters.ProcessPictures = ProcessPictures;
	GenerationParameters.DisableExternalResources = DisableExternalResources;
	
	HTMLDocument = GenerateHTMLDocumentBasedOnEmail(GenerationParameters, HasExternalResources);
	
	If ForPrint Then
		GenerateHeaderAndFooterOfEmailPrintForm(MailMessage, HTMLDocument, Selection);
	EndIf;
	
	Return GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
	
EndFunction

// Parameters:
//  MailMessage  - DocumentRef.OutgoingEmail
//  ForPrint  - Boolean - indicates that HTML text is generated for an email print form.
//  ProcessPictures - Boolean - indicates that pictures will be nested in HTML.
//
// Returns:
//   String   - HTML text generated for the outgoing email message.
//
Function GenerateHTMLTextForOutgoingEmail(MailMessage, ForPrint, ProcessPictures,
	DisableExternalResources = True, HasExternalResources = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.Ref AS MailMessage,
	|	OutgoingEmail.Date,
	|	OutgoingEmail.EmailStatus,
	|	OutgoingEmail.SenderPresentation,
	|	OutgoingEmail.Text,
	|	OutgoingEmail.HTMLText,
	|	OutgoingEmail.Subject,
	|	OutgoingEmail.TextType AS TextType,
	|	OutgoingEmail.TextType AS TextTypeConversion,
	|	OutgoingEmail.InteractionBasis,
	|	OutgoingEmail.IncludeOriginalEmailBody,
	|	OutgoingEmail.EmailRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	),
	|	OutgoingEmail.CCRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	),
	|	ISNULL(EmailAccounts.UserName, """") AS UserAccountUsername
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON OutgoingEmail.Account = EmailAccounts.Ref
	|WHERE
	|	OutgoingEmail.Ref = &MailMessage";
	
	Query.SetParameter("MailMessage",MailMessage);
	
	EmailHeader1 = Query.Execute().Select();
	EmailHeader1.Next();
	
	GenerationParameters = HTMLDocumentGenerationParametersOnEmailBasis(EmailHeader1);
	GenerationParameters.ProcessPictures = ProcessPictures;
	GenerationParameters.DisableExternalResources = DisableExternalResources;
	
	HTMLDocument = GenerateHTMLDocumentBasedOnEmail(GenerationParameters, HasExternalResources);
	
	If EmailHeader1.EmailStatus = Enums.OutgoingEmailStatuses.Draft 
		And EmailHeader1.IncludeOriginalEmailBody 
		And EmailHeader1.InteractionBasis <> Undefined 
		And (TypeOf(EmailHeader1.InteractionBasis) = Type("DocumentRef.IncomingEmail") 
		Or TypeOf(EmailHeader1.InteractionBasis) = Type("DocumentRef.OutgoingEmail")) Then
		
		BaseEmailHeader = GetBaseEmailData(EmailHeader1.InteractionBasis);
		
		GenerationParameters = HTMLDocumentGenerationParametersOnEmailBasis();
		GenerationParameters.MailMessage = EmailHeader1.InteractionBasis;
		GenerationParameters.TextType = BaseEmailHeader.TextType;
		GenerationParameters.Text = BaseEmailHeader.Text;
		GenerationParameters.HTMLText = BaseEmailHeader.HTMLText;
		GenerationParameters.TextTypeConversion = EmailHeader1.TextType;
		GenerationParameters.DisableExternalResources = DisableExternalResources;
		HTMLDocumentBase = GenerateHTMLDocumentBasedOnEmail(GenerationParameters, HasExternalResources);
		
		HTMLDocument = MergeEmails(HTMLDocument, HTMLDocumentBase, BaseEmailHeader);
		
	EndIf;
	
	If ForPrint Then
		GenerateHeaderAndFooterOfEmailPrintForm(MailMessage, HTMLDocument, EmailHeader1);
	EndIf;
	
	Return GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
	
EndFunction

// Parameters:
//  GenerationParameters - Structure - parameters of generating an HTML document:
//   * MailMessage  - DocumentRef.IncomingEmail
//             - DocumentRef.OutgoingEmail - Email message to be analyzed.
//   * TextType  - EnumRef.EmailTextTypes - email text type.
//   * Text  - String - an email text.
//   * HTMLText  - String - an email text in HTML format.
//   * TextTypeConversion  - EnumRef.EmailTextTypes - a text type to convert
//                                                                                 the email to.
//   * Encoding  - String - an email encoding.
//   * ProcessPictures - Boolean - indicates that pictures will be nested in HTML.
//  HasExternalResources - Boolean - a return value, True if a letter contains items imported from the Internet.
//
// Returns:
//   String   - Processed email body.
//
Function GenerateHTMLDocumentBasedOnEmail(GenerationParameters, HasExternalResources = Undefined) Export
	
	MailMessage = GenerationParameters.MailMessage;
	TextType = GenerationParameters.TextType;
	Text = GenerationParameters.Text;
	HTMLText = GenerationParameters.HTMLText;
	TextTypeConversion = ?(GenerationParameters.TextTypeConversion = Undefined,
		GenerationParameters.TextType, GenerationParameters.TextTypeConversion);
	Encoding = GenerationParameters.Encoding;
	ProcessPictures = GenerationParameters.ProcessPictures;
	DisableExternalResources = GenerationParameters.DisableExternalResources;
		
	If TextType <> TextTypeConversion 
		And TextType <> Enums.EmailTextTypes.PlainText Then
		
		IncomingEmailText = GetPlainTextFromHTML(HTMLText);
		HTMLDocument = GetHTMLDocumentFromPlainText(IncomingEmailText);
		
	ElsIf TextType = Enums.EmailTextTypes.PlainText 
		Or (TextType.IsEmpty() And TrimAll(HTMLText) = "") Then
		
		HTMLDocument = GetHTMLDocumentFromPlainText(Text);
		
	Else
		
		EmailEncoding = Encoding;
		If IsBlankString(EmailEncoding) Then
			EncodingAttributePosition = StrFind(HTMLText, "charset");
			If EncodingAttributePosition <> 0 Then
				Indus = 0;
				While CharCode(Mid(HTMLText,EncodingAttributePosition + 8 + Indus,1)) <> 34 Do
					EmailEncoding = EmailEncoding + Mid(HTMLText,EncodingAttributePosition + 8 + Indus,1);
					Indus = Indus + 1;
				EndDo
			Else
				EmailEncoding = "utf8";
			EndIf;
		EndIf;
		
		If TypeOf(MailMessage) = Type("Structure") Then
			TableOfFiles = MailMessage.Attachments;
		Else
			TableOfFiles = GetEmailAttachmentsWithNonBlankIDs(MailMessage);
		EndIf;
		
		TextToProcess1 = HTMLText;
		
		NoBody = (StrOccurrenceCount(Lower(TextToProcess1), "<body") = 0);
		NoHeader = (StrOccurrenceCount(Lower(TextToProcess1), "<html") = 0);
		If NoBody And NoHeader Then
			TextToProcess1 = "<body>" + TextToProcess1 + "</body>"
		EndIf;
		If NoHeader Then
			TextToProcess1 = "<html>" + TextToProcess1 + "</html>"
		EndIf;
		
		AttemptNumber = 1;
		EmailText = HTMLTagContent(TextToProcess1, "html", True, AttemptNumber);
		While StrFind(Lower(EmailText), "<body") = 0 
			And Not IsBlankString(EmailText) Do
			AttemptNumber = AttemptNumber + 1;
			EmailText = HTMLTagContent(TextToProcess1, "html", True, AttemptNumber);
		EndDo;
		
		If TableOfFiles.Count() Then
			HTMLDocument = ReplacePicturesIDsWithPathToFiles(EmailText, TableOfFiles, EmailEncoding, ProcessPictures);
		Else
			HTMLDocument = GetHTMLDocumentObjectFromHTMLText(EmailText, EmailEncoding);
		EndIf;
		
	EndIf;
	
	HasExternalResources = EmailOperations.HasExternalResources(HTMLDocument);
	EmailOperations.DisableUnsafeContent(HTMLDocument, HasExternalResources And DisableExternalResources);
	
	Return HTMLDocument;
	
EndFunction
	
// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - Email message to be analyzed.
//
// Returns:
//   String   - Processed email body.
//
Function ProcessHTMLText(MailMessage, DisableExternalResources = True, HasExternalResources = Undefined) Export
	
	AttributesStructure2 = Common.ObjectAttributesValues(MailMessage,"HTMLText,Encoding");
	HTMLText = AttributesStructure2.HTMLText;
	Encoding = AttributesStructure2.Encoding;
	
	If Not IsBlankString(HTMLText) Then
		
		// Add the HTML tag (if missing). Such email messages can be sent from, for example, Gmail. 
		// Intended for displaying it properly in the form item.
		If StrOccurrenceCount(HTMLText,"<html") = 0 Then
			HTMLText = "<html>" + HTMLText + "</html>"
		EndIf;
		
		FilterHTMLTextContent(HTMLText, Encoding, DisableExternalResources, HasExternalResources);
		
		TableOfFiles = GetEmailAttachmentsWithNonBlankIDs(MailMessage);
		
		If TableOfFiles.Count() Then
			HTMLText = HTMLTagContent(HTMLText, "html", True);
			HTMLDocument = ReplacePicturesIDsWithPathToFiles(HTMLText, TableOfFiles, Encoding);
			
			Return GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
		EndIf;
	EndIf;
	
	Return HTMLText;
	
EndFunction

// Finds a tag content in HTML.
//
// Parameters:
//  Text                             - String - a searched XML text.
//  NameTag                           - String - a tag whose content is to be found.
//  IncludeStartEndTag - Boolean - indicates that the found item includes start and end tags, the default
//                                               value is False.
//  SerialNumber                    - Number  - a position, from which the search starts, the default value is 1.
// 
// Returns:
//   String - String with removed new line characters and a carriage return.
//
Function HTMLTagContent(Text, NameTag, IncludeStartEndTag = False, SerialNumber = 1) Export
	
	Result = Undefined;
	
	Begin    = "<"  + NameTag;
	Ending = "</" + NameTag + ">";
	
	FoundPositionStart = StrFind(Lower(Text), Lower(Begin), SearchDirection.FromBegin, 1, SerialNumber);
	FoundPositionEnd = StrFind(Lower(Text), Lower(Ending), SearchDirection.FromBegin, 1, SerialNumber);
	If FoundPositionStart = 0
		Or FoundPositionEnd = 0 Then
		Return "";
	EndIf;
	
	Content = Mid(Text,
	                  FoundPositionStart,
	                  FoundPositionEnd - FoundPositionStart + StrLen(Ending));
	
	If IncludeStartEndTag Then
		
		Result = TrimAll(Content);
		
	Else
		
		StartTag = Left(Content, StrFind(Content, ">"));
		Content = StrReplace(Content, StartTag, "");
		
		EndTag1 = Right(Content, StrLen(Content) - StrFind(Content, "<", SearchDirection.FromEnd) + 1);
		Content = StrReplace(Content, EndTag1, "");
		
		Result = TrimAll(Content);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns outgoing mail format by default for the user, 
// based on the system settings and the format of the last letter sent by the user.
// 
// Parameters:
//   User - CatalogRef.Users - User.
//
// Returns:
//   EnumRef.EmailEditingMethods
// 
Function DefaultMessageFormat(User) Export
	
	If Not SendEmailsInHTMLFormat() Then
		Return Enums.EmailEditingMethods.NormalText;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	CASE
	|		WHEN OutgoingEmail.TextType = VALUE(Enum.EmailTextTypes.PlainText)
	|			THEN VALUE(Enum.EmailEditingMethods.NormalText)
	|		ELSE VALUE(Enum.EmailEditingMethods.HTML)
	|	END AS MessageFormat,
	|	OutgoingEmail.Date
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Author = &User
	|	AND (NOT OutgoingEmail.DeletionMark)
	|
	|ORDER BY
	|	OutgoingEmail.Date DESC";
	
	Query.SetParameter("User",User);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Enums.EmailEditingMethods.NormalText;
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.MessageFormat;
	EndIf;
	
EndFunction

// Replaces attachment picture IDs with file path in the HTML text and creates an HTML document object.
//
// Parameters:
//  HTMLText     - String - an HTML text to process.
//  TableOfFiles - ValueTable - a table containing information about attached files.
//  Encoding     - String - HTML text encoding.
//
// Returns:
//  HTMLDocument   - Created HTML document.
//
Function ReplacePicturesIDsWithPathToFiles(HTMLText,TableOfFiles,Encoding = Undefined, ProcessPictures = False)
	
	HTMLDocument = GetHTMLDocumentObjectFromHTMLText(HTMLText,Encoding);
	
	For Each AttachedFile In TableOfFiles Do
		
		For Each Picture In HTMLDocument.Images Do
			
			AttributePictureSource = Picture.Attributes.GetNamedItem("src");
			If AttributePictureSource = Undefined Then
				Continue;
			EndIf;
			
			If StrOccurrenceCount(AttributePictureSource.Value, AttachedFile.EmailFileID) > 0 Then
				
				NewAttributePicture = AttributePictureSource.CloneNode(False);
				If ProcessPictures Then
					If IsTempStorageURL(AttachedFile.Ref) Then
						BinaryData = GetFromTempStorage(AttachedFile.Ref);
						Extension     =  AttachedFile.Extension;
					Else
						FileData = FilesOperations.FileData(AttachedFile.Ref);
						BinaryData = GetFromTempStorage(FileData.RefToBinaryFileData);
						Extension     = FileData.Extension;
					EndIf;
					TextContent = Base64String(BinaryData);
					TextContent = "data:image/" + Mid(Extension,2) + ";base64," + Chars.LF + TextContent;
				Else
					// If cannot get picture data, don't display the picture and don't display a user message.
					
					If IsTempStorageURL(AttachedFile.Ref) Then
						TextContent = AttachedFile.Ref;
					Else
						Try
							TextContent = FilesOperations.FileData(AttachedFile.Ref).RefToBinaryFileData;
						Except
							TextContent = "";
						EndTry;
					EndIf;
					
				EndIf;
				
				NewAttributePicture.TextContent = TextContent;
				Picture.Attributes.SetNamedItem(NewAttributePicture);
				
				Break;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return HTMLDocument;
	
EndFunction

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - Email message to be analyzed.
//
// Returns:
//   ValueTable:
//     * Ref                    - CatalogRef.IncomingEmailAttachedFiles
//                                 - CatalogRef.OutgoingEmailAttachedFiles - 
//                                   Reference to the attachment.
//     * Description              - String - file name.
//     * Size                    - Number - file size.
//     * EmailFileID - String - an ID of the picture displayed in the message body.
//
Function GetEmailAttachmentsWithNonBlankIDs(MailMessage) Export
	
	AttachedEmailFilesData = AttachedEmailFilesData(MailMessage);
	MetadataObjectName = AttachedEmailFilesData.AttachedFilesCatalogName;
	FilesOwner       = AttachedEmailFilesData.FilesOwner;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	AttachedFilesInMessage.Ref,
	|	AttachedFilesInMessage.Description,
	|	AttachedFilesInMessage.Size,
	|	AttachedFilesInMessage.EmailFileID
	|FROM
	|	&NameOfTheReferenceTable AS AttachedFilesInMessage
	|WHERE
	|	AttachedFilesInMessage.FileOwner = &FilesOwner
	|	AND (NOT AttachedFilesInMessage.DeletionMark)
	|	AND AttachedFilesInMessage.EmailFileID <> &IsBlankString";
	
	Query.Text = StrReplace(Query.Text , "&NameOfTheReferenceTable", "Catalog." + MetadataObjectName);
	
	Query.SetParameter("IsBlankString","");
	Query.SetParameter("FilesOwner",FilesOwner);
	
	Return Query.Execute().Unload();
	
EndFunction 

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - Email message to be analyzed.
//
// Returns:
//   QueryResultSelection - Parent email message data.
//
Function GetBaseEmailData(MailMessage) Export
	
	MetadataObjectName = MailMessage.Metadata().Name;
	
	Query = New Query;
	Query.Text = "
	|SELECT 
	|	EmailMessageBasis.TextType           AS TextType,
	|	EmailMessageBasis.Subject                     AS Subject,
	|	EmailMessageBasis.HTMLText                AS HTMLText,
	|	EmailMessageBasis.Text                    AS Text,
	|	&AccountNameSenderAddress                       AS SenderAddress,
	|	EmailMessageBasis.SenderPresentation AS SenderPresentation,
	|	EmailMessageBasis.Date                     AS Date,
	|	&MetadataObjectName                               AS MetadataObjectName,
	|	EmailMessageBasis.CCRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	) AS CCRecipients,
	|	EmailMessageBasis.EmailRecipients.(
	|		Ref,
	|		LineNumber,
	|		Address,
	|		Presentation,
	|		Contact
	|	) AS EmailRecipients
	|FROM #TheTableNameOfTheDocument AS EmailMessageBasis
	|WHERE
	|	EmailMessageBasis.Ref = &MailMessage";
	
	Query.Text = StrReplace(Query.Text , "#TheTableNameOfTheDocument", "Document." + MetadataObjectName);
	Query.Text = StrReplace(Query.Text , "&AccountNameSenderAddress", ?(MetadataObjectName = "IncomingEmail","EmailMessageBasis.SenderAddress","&IsBlankString"));
	
	Query.SetParameter("MailMessage",MailMessage);
	Query.SetParameter("IsBlankString","");
	Query.SetParameter("MetadataObjectName",MetadataObjectName);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection;
	
EndFunction

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - Email message to be analyzed.
//  HTMLText - String - an HTML text to process.
//  AttachmentsStructure - Structure - a structure, where pictures attached to an email are placed.
//
// Returns:
//   Number - Estimated message size in bytes.
//
Function ProcessHTMLTextForFormattedDocument(MailMessage,HTMLText,AttachmentsStructure) Export
	
	If Not IsBlankString(HTMLText) Then
		
		HTMLDocument = GetHTMLDocumentObjectFromHTMLText(HTMLText);
		
		TableOfFiles = GetEmailAttachmentsWithNonBlankIDs(MailMessage);
		
		If TableOfFiles.Count() Then
			
			For Each AttachedFile In TableOfFiles Do
				
				For Each Picture In HTMLDocument.Images Do
					
					AttributePictureSource = Picture.Attributes.GetNamedItem("src");
					
					If StrOccurrenceCount(AttributePictureSource.Value, AttachedFile.EmailFileID) > 0 Then
						
						NewAttributePicture = AttributePictureSource.CloneNode(False);
						NewAttributePicture.TextContent = AttachedFile.Description;
						Picture.Attributes.SetNamedItem(NewAttributePicture);
						
						AttachmentsStructure.Insert(
							AttachedFile.Description,
							New Picture(GetFromTempStorage(
								FilesOperations.FileData(AttachedFile.Ref).RefToBinaryFileData)));
						
						Break;
						
					EndIf;
					
				EndDo;
				
			EndDo;
			
			Return GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
			
		Else
			
			Return HTMLText;
			
		EndIf;
		
	Else
		
		Return HTMLText;
		
	EndIf;
	
EndFunction

// Parameters:
//  TableOfRecipients - TabularSection - a tabular section, for which the function is executed.
//
// Returns:
//   String - String containing a presentation of all table recipients.
//
Function GetIncomingEmailRecipientsPresentations(TableOfRecipients) Export

	StringToReturn = "";
	
	For Each Recipient In TableOfRecipients Do
		
		StringToReturn = StringToReturn + "'" 
		         + ?(IsBlankString(Recipient.Presentation), Recipient.Address, Recipient.Presentation + "<"+ Recipient.Address+">") + "'"+ ", ";
		
	EndDo;
	
	If Not IsBlankString(StringToReturn) Then
		
		StringToReturn = Left(StringToReturn,StrLen(StringToReturn) - 2);
		
	EndIf;
	
	Return StringToReturn;

EndFunction

// Generates an HTML item of outgoing email header.
//
// Parameters:
//  ParentElement - HTMLElement - a parent HTML element, for which a header data item will be added.
//  EmailHeader1 - Structure - a selection by the email data.
//  OnlyBySenderPresentation - Boolean - determines whether it is necessary to include the sender address or his presentation
//                                              is enough.
//
Function GenerateEmailHeaderDataItem(ParentElement, EmailHeader1, OnlyBySenderPresentation = False)
	
	OwnerDocument = ParentElement.OwnerDocument;
	
	ItemTable = OwnerDocument.CreateElement("table");
	SetHTMLElementAttribute(ItemTable,"border", "0");
	
	SenderPresentation = EmailHeader1.SenderPresentation 
		+ ?(OnlyBySenderPresentation Or IsBlankString(EmailHeader1.SenderAddress),
	    	"",
	    	"[" + EmailHeader1.SenderAddress +"]");
	
	AddRowToTable(ItemTable, "From: ", SenderPresentation);
	AddRowToTable(ItemTable, "Sent: ", Format(EmailHeader1.Date,"DLF=D'"));
	
	EmailRecipientsTable = ?(TypeOf(EmailHeader1.EmailRecipients) = Type("ValueTable"),
		EmailHeader1.EmailRecipients, EmailHeader1.EmailRecipients.Unload());
	AddRowToTable(ItemTable, "To: ", GetIncomingEmailRecipientsPresentations(EmailRecipientsTable));
	
	CCRecipientsTable = ?(TypeOf(EmailHeader1.CCRecipients) = Type("ValueTable"),
		EmailHeader1.CCRecipients, EmailHeader1.CCRecipients.Unload());
	If CCRecipientsTable.Count() > 0 Then
		AddRowToTable(ItemTable, "cc: ", GetIncomingEmailRecipientsPresentations(CCRecipientsTable));
	EndIf;
	
	Subject = ?(IsBlankString(EmailHeader1.Subject), NStr("en = '<No Subject>';"), EmailHeader1.Subject);
	AddRowToTable(ItemTable, "Subject: ", Subject);
	
	Return ItemTable;
	
EndFunction

// Parameters:
//  HTMLDocument - HTMLDocument - an HTML document whose header will be complemented.
//  Selection - QueryResultSelection - a selection by the email data.
//  IsOutgoingEmail - Boolean - True if the message is outgoing.
//
Procedure AddPrintFormHeaderToEmailBody(HTMLDocument, Selection, IsOutgoingEmail) Export
	
	EmailBodyItem = EmailBodyItem(HTMLDocument);
	BodyChildNodesArray = ChildNodesWithHTML(EmailBodyItem);
	
	// Name of the email account user.
	UserItem = GenerateAccountUsernameItem(EmailBodyItem, Selection);
	InsertHTMLElementAsFirstChildElement(EmailBodyItem,UserItem, BodyChildNodesArray);
	
	InsertHTMLElementAsFirstChildElement(EmailBodyItem,
	                                           HorizontalSeparatorItem(EmailBodyItem),
	                                           BodyChildNodesArray);
	
	EmailHeaderDataItem = GenerateEmailHeaderDataItem(EmailBodyItem, Selection, IsOutgoingEmail);
	InsertHTMLElementAsFirstChildElement(EmailBodyItem,EmailHeaderDataItem,BodyChildNodesArray);
	BRItem = HTMLDocument.CreateElement("br");
	InsertHTMLElementAsFirstChildElement(EmailBodyItem, BRItem, BodyChildNodesArray);
	
EndProcedure

// Parameters:
//  HTMLDocument - HTMLDocument - an HTML document, where replacement will be executed.
//  MapsTable - ValueTable - a table of mapping file names to IDs.
//
Procedure ChangePicturesNamesToMailAttachmentsIDsInHTML(HTMLDocument, MapsTable) Export
	
	MapsTable.Indexes.Add("FileName");
	For Each Picture In HTMLDocument.Images Do
		AttributePictureSource = Picture.Attributes.GetNamedItem("src");
		
		FoundRow = MapsTable.Find(AttributePictureSource.TextContent,"FileName");
		If FoundRow <> Undefined Then
			NewAttributePicture = AttributePictureSource.CloneNode(False);
			NewAttributePicture.TextContent = "cid:" + FoundRow.FileIDForHTML;
			Picture.Attributes.SetNamedItem(NewAttributePicture);
		EndIf;
	EndDo;
	
EndProcedure

Function GenerateAccountUsernameItem(ParentElement,Selection)
	
	FontItem = AddElementWithAttributes(ParentElement, "Font", New Structure("size,face", "3", "Tahoma"));
	AddTextNode(FontItem,Selection.UserAccountUsername, True);
	
	Return FontItem;
	
EndFunction

Procedure GenerateHeaderAndFooterOfEmailPrintForm(MailMessage, HTMLDocument, Selection)
	
	AddPrintFormHeaderToEmailBody(HTMLDocument,Selection,True);
	
	AttachmentTable = EmailManagement.GetEmailAttachments(MailMessage, True,  True);
	If TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		AttachmentEmailsTable = DataStoredInAttachmentsEmailsDatabase(MailMessage);
		
		For Each AttachmentEmail In AttachmentEmailsTable Do
		
			NewRow = AttachmentTable.Add();
			NewRow.FileName                  = EmailPresentation(AttachmentEmail.Subject, AttachmentEmail.Date) + ".eml";
			NewRow.PictureIndex            = 0;
			NewRow.SignedWithDS                = False;
			NewRow.EmailFileID = "";
			NewRow.Size                    = AttachmentEmail.Size;
			NewRow.SizePresentation       = InteractionsClientServer.GetFileSizeStringPresentation(AttachmentEmail.Size)
		
		EndDo
		
	EndIf;
	
	If AttachmentTable.Count() > 0 Then
		AddAttachmentFooterToEmailBody(HTMLDocument, AttachmentTable);
	EndIf;
	
EndProcedure

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - Email message to be analyzed.
//
// Returns:
//   Number - Estimated message size in bytes.
//
Function EvaluateOutgoingEmailSize(MailMessage) Export
	
	Size = 0;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	SUM(ISNULL(OutgoingEmailAttachedFiles.Size, 0) * 1.5) AS Size
	|FROM
	|	Catalog.OutgoingEmailAttachedFiles AS OutgoingEmailAttachedFiles
	|WHERE
	|	OutgoingEmailAttachedFiles.FileOwner = &MailMessage
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN OutgoingEmail.TextType = VALUE(Enum.EmailTextTypes.PlainText)
	|			THEN OutgoingEmail.Text
	|		ELSE OutgoingEmail.HTMLText
	|	END AS Text,
	|	OutgoingEmail.Subject
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Ref = &MailMessage";
	
	Query.SetParameter("MailMessage",MailMessage);
	
	Result = Query.ExecuteBatch();
	If Not Result[0].IsEmpty() Then
		Selection = Result[0].Select();
		Selection.Next();
		Size = Size + ?(Selection.Size = Null, 0, Selection.Size);
	EndIf;
	
	If Not Result[1].IsEmpty() Then
		Selection = Result[1].Select();
		Selection.Next();
		Size = Size + StrLen(Selection.Text) + StrLen(Selection.Subject);
		
	EndIf;
	
	Return Size;

EndFunction

// Parameters:
//  HTMLText  - String
//
// Returns:
//   HTMLDocument   - Created HTML document.
//
Function GetHTMLDocumentObjectFromHTMLText(HTMLText, Encoding = Undefined) Export
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	
	NewHTMLText = HTMLText;
	PositionOpenXML = StrFind(NewHTMLText,"<?xml");
	
	If PositionOpenXML > 0 Then
		
		PositionCloseXML = StrFind(NewHTMLText,"?>");
		If PositionCloseXML > 0 Then
			
			NewHTMLText = Left(NewHTMLText,PositionOpenXML - 1) + Right(NewHTMLText,StrLen(NewHTMLText) - PositionCloseXML -1);
			
		EndIf;
		
	EndIf;
	
	If Encoding = Undefined Then
		
		HTMLReader.SetString(HTMLText);
		
	Else
		
		Try
		
			HTMLReader.SetString(HTMLText, Encoding);
		
		Except
			
			HTMLReader.SetString(HTMLText);
			
		EndTry;
		
	EndIf;
	
	Return Builder.Read(HTMLReader);
	
EndFunction

// Parameters:
//  Text  - String - a text, from which an HTML document will be created.
//
// Returns:
//   HTMLDocument   - Created HTML document.
//
Function GetHTMLDocumentFromPlainText(Text) Export
	
	HTMLDocument = New HTMLDocument;
	
	ItemBody = HTMLDocument.CreateElement("body");
	HTMLDocument.Body = ItemBody;
	
	ItemBlock = HTMLDocument.CreateElement("p");
	ItemBody.AppendChild(ItemBlock);
	
	FontItem = FontItem(HTMLDocument, "2", "Tahoma");
	
	RowsCount = StrLineCount(Text);
	For Indus = 1 To RowsCount Do
		AddTextNode(FontItem, StrGetLine(Text, Indus), False, ?(Indus = RowsCount, False, True));
	EndDo;
	
	ItemBlock.AppendChild(FontItem);
	
	Return HTMLDocument;
	
EndFunction

// Parameters:
//  HTMLDocument  - HTMLDocument - a document, from which the text will be extracted.
//
// Returns:
//   String - HTML text.
//
Function GetHTMLTextFromHTMLDocumentObject(HTMLDocument) Export
	
	Try
		DOMWriter = New DOMWriter;
		HTMLWriter = New HTMLWriter;
		HTMLWriter.SetString();
		DOMWriter.Write(HTMLDocument,HTMLWriter);
		Return HTMLWriter.Close();
	Except
		Return "";
	EndTry;
	
EndFunction

// Creates an HTML element attribute and sets its text content.
//
// Parameters:
//  HTMLElement  - HTMLElement - an element, for which an attribute is set.
//  Name  - String - an HTML attribute name.
//  TextContent  - String - text content of an attribute.
//
Procedure SetHTMLElementAttribute(HTMLElement, Name, TextContent)
	
	HTMLAttribute = HTMLElement.OwnerDocument.CreateAttribute(Name);
	HTMLAttribute.TextContent = TextContent;
	HTMLElement.Attributes.SetNamedItem(HTMLAttribute);
	
EndProcedure

// Parameters:
//  ParentElement - HTMLElement - an element, to which a child element will be added.
//  Name  - String - an HTML element name.
//  Attributes  - Map of KeyAndValue:
//    * Key - String - attribute name;
//    * Value - String - a text content.
//
// Returns:
//   HTMLElement - Added element.
//
Function AddElementWithAttributes(ParentElement, Name, Attributes)
	
	HTMLElement = ParentElement.OwnerDocument.CreateElement(Name);
	For Each Attribute In Attributes Do
		SetHTMLElementAttribute(HTMLElement, Attribute.Key, Attribute.Value);
	EndDo;
	ParentElement.AppendChild(HTMLElement);
	Return HTMLElement;
	
EndFunction

// Parameters:
//  HTMLText  - String - hTML text.
//
// Returns:
//   String   - Plain text.
//
Function GetPlainTextFromHTML(HTMLText) Export
	
	FormattedDocument = New FormattedDocument;
	FormattedDocument.SetHTML(HTMLText, New Structure);
	Return FormattedDocument.GetText();
	
EndFunction

Procedure AddTextNode(ParentElement, Text, HighlightWithBold = False, AddLineBreak = False)
	
	OwnerDocument = ParentElement.OwnerDocument;
	
	TextNode = OwnerDocument.CreateTextNode(Text);
	
	If HighlightWithBold Then
		BoldItem = OwnerDocument.CreateElement("b");
		BoldItem.AppendChild(TextNode);
		ParentElement.AppendChild(BoldItem);
	Else
		
		ParentElement.AppendChild(TextNode);
		
	EndIf;
	
	If AddLineBreak Then
		ParentElement.AppendChild(OwnerDocument.CreateElement("br"));
	EndIf;
	
EndProcedure

// Parameters:
//  ParentElement  - HTMLElement - an element, to which a child element will be added.
//  ElementToInsert  - HTMLElement - an HTML element to be inserted.
//  ChildElementsArrayOfParent  - Array - a child element array of a parent element.
//
Procedure InsertHTMLElementAsFirstChildElement(ParentElement, ElementToInsert, ChildElementsArrayOfParent)
	
	If ChildElementsArrayOfParent.Count() > 0 Then
		ParentElement.InsertBefore(ElementToInsert, ChildElementsArrayOfParent[0]);
	Else
		ParentElement.AppendChild(ElementToInsert);
	EndIf;
	
EndProcedure

Procedure AddRowToTable(ParentElement, ColumnValue1 = Undefined, ColumnValue2 = Undefined, ColumnValue3 = Undefined)

	OwnerDocument = ParentElement.OwnerDocument;
	TableRowItem = OwnerDocument.CreateElement("tr");
	If ColumnValue1 <> Undefined Then
		AddCellToTable(TableRowItem, ColumnValue1, True);
	EndIf;
	If ColumnValue2 <> Undefined Then
		AddCellToTable(TableRowItem, ColumnValue2);
	EndIf;
	If ColumnValue3 <> Undefined Then
		AddCellToTable(TableRowItem, ColumnValue3);
	EndIf;
	
	ParentElement.AppendChild(TableRowItem);

EndProcedure

Procedure AddCellToTable(RowItem, CellValue, HighlightWithBold = False)
	
	CellItem = RowItem.OwnerDocument.CreateElement("td");
	FontItem = FontItem(RowItem.OwnerDocument, "2", "Tahoma"); 
	
	If HighlightWithBold Then
		BoldItem = FontItem.OwnerDocument.CreateElement("b");
		BoldItem.TextContent = CellValue;
		FontItem.AppendChild(BoldItem);
	Else 
		FontItem.TextContent = CellValue;
	EndIf;
	
	CellItem.AppendChild(FontItem);
	RowItem.AppendChild(CellItem);
	
EndProcedure

Procedure AddAttachmentFooterToEmailBody(HTMLDocument, Attachments) Export

	EmailBodyItem = EmailBodyItem(HTMLDocument);
	EmailBodyItem.AppendChild(HorizontalSeparatorItem(EmailBodyItem));
	
	FontItem = AddElementWithAttributes(EmailBodyItem,
	                                          "Font",
	                                          New Structure("size,face","2", "Tahoma"));
	
	AttachmentsCountString = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 attachments.';"), Attachments.Count());
	AddTextNode(FontItem, AttachmentsCountString, True, True);
	
	For Each Attachment In Attachments Do 
		
		AttachmentPresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (%2).';"), Attachment.FileName, Attachment.SizePresentation);
		AddTextNode(FontItem, AttachmentPresentation, , True);
		
	EndDo;
	
	EmailBodyItem.AppendChild(FontItem);
	
EndProcedure

Function HorizontalSeparatorItem(ParentElement)
	
	AttributesStructure = New Structure;
	AttributesStructure.Insert("size", "2");
	AttributesStructure.Insert("width", "100%");
	AttributesStructure.Insert("align", "center");
	AttributesStructure.Insert("tabindex", "-1");
	
	Return  AddElementWithAttributes(ParentElement, "hr", AttributesStructure);
	
EndFunction

Function EmailBodyItem(HTMLDocument)
	
	If HTMLDocument.Body = Undefined Then
		EmailBodyItem = HTMLDocument.CreateElement("body");
		HTMLDocument.Body = EmailBodyItem;
	Else
		EmailBodyItem = HTMLDocument.Body;
	EndIf;
	
	Return EmailBodyItem;
	
EndFunction

Function FontItem(HTMLDocument, Size, FontName)
	
	FontItem = HTMLDocument.CreateElement("Font");
	SetHTMLElementAttribute(FontItem,"size", Size);
	SetHTMLElementAttribute(FontItem,"face", FontName);
	
	Return FontItem;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////////
// Settings management.

// Returns current user setting.
// If setting is not specified,
// it returns the ValueIfNotSpecified parameter after passing it.
//
Function GetCurrentUserSetting(ObjectKey,
	SettingsKey = Undefined,
	ValueIfNotSpecified = Undefined)
	
	Result = Common.CommonSettingsStorageLoad(
		ObjectKey,
		SettingsKey,
		ValueIfNotSpecified);
	
	Return Result;
	
EndFunction

Procedure SaveCurrentUserSetting(ObjectKey, Value, SettingsKey = Undefined)
	
	Common.CommonSettingsStorageSave(
		ObjectKey,
		SettingsKey,
		Value);
		
EndProcedure

Function EmailOperationSettings() Export
	
	Setting = GetCurrentUserSetting("MailOperations", "UserSettings", New Structure);
	If TypeOf(Setting) <> Type("Structure") Then
		Setting = New Structure;
	EndIf;
	Return Setting;
	
EndFunction

Procedure SaveEmailManagementSettings(Value) Export
	
	SaveCurrentUserSetting("MailOperations", Value, "UserSettings");
	
EndProcedure 

////////////////////////////////////////////////////////////////////
// Text messages.

// Parameters:
//  SMSMessage  - DocumentObject.SMSMessage - a document, for which an SMS message delivery status is checked.
//  Modified  - Boolean - indicates that the document was modified.
//
Procedure CheckSMSMessagesDeliveryStatuses(SMSMessage, Modified) Export
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	MessageSMSAddressees.LineNumber,
	|	MessageSMSAddressees.MessageID,
	|	MessageSMSAddressees.MessageState
	|FROM
	|	Document.SMSMessage.SMSMessageRecipients AS MessageSMSAddressees
	|WHERE
	|	MessageSMSAddressees.Ref = &SMSMessage
	|	AND MessageSMSAddressees.MessageID <> """"
	|	AND (MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.BeingSentByProvider)
	|			OR MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.SentByProvider)
	|			OR MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.ErrorOnGetStatusFromProvider))";
	
	Query.SetParameter("SMSMessage", SMSMessage.Ref);
	
	HasChanges = False;
	SMSMessageRecipients = Query.Execute().Unload();
	MessagesIDs = SMSMessageRecipients.UnloadColumn("MessageID");
	DeliveryStatuses = SendSMSMessage.DeliveryStatuses(MessagesIDs);
	
	For Each Addressee In SMSMessageRecipients Do
		
		MessageState = SMSMessageStateAccordingToDeliveryStatus(DeliveryStatuses[Addressee.MessageID]);
		
		If MessageState <> Addressee.MessageState Then
			SMSMessage.SMSMessageRecipients[Addressee.LineNumber - 1].MessageState = MessageState;
			HasChanges = True;
		EndIf;
		
	EndDo;
	
	If HasChanges Then
		SMSMessage.State = SMSMessageDocumentState(SMSMessage);
		Modified = True;
	EndIf;
	
EndProcedure

// Determines a status of the "SMS message" document by the status of its incoming SMS messages.
//
// Parameters:
//  SMSMessage - DocumentObject.SMSMessage
//
// Returns:
//   EnumRef.SMSDocumentStatuses
//
Function SMSMessageDocumentState(SMSMessage)
	
	StatusesOfMessagesToAddressees = SMSMessage.SMSMessageRecipients.Unload(, "MessageState").UnloadColumn("MessageState");
	If StatusesOfMessagesToAddressees.Count() = 0 Then
		Return Enums.SMSDocumentStatuses.Draft;
	EndIf;
	
	DifferentStates = New Map;
	For Each MessageState In StatusesOfMessagesToAddressees Do
		DifferentStates[MessageState] = True;
	EndDo;
		
	CurrentStatus = Undefined;	
	For Each KeyValue In DifferentStates Do
	
		MessageState = KeyValue.Key; // EnumRef.SMSDocumentStatuses
		If MessageState = Enums.SMSMessagesState.Outgoing Then
			Return Enums.SMSDocumentStatuses.Outgoing;
		ElsIf MessageState = Enums.SMSMessagesState.Draft Then
			Return Enums.SMSMessagesState.Draft;
		ElsIf MessageState = Enums.SMSMessagesState.CannotPassToProvider Then
			If CurrentStatus = Enums.SMSDocumentStatuses.Delivered Then
				CurrentStatus = Enums.SMSDocumentStatuses.PartiallyDelivered;
			Else
				CurrentStatus = Enums.SMSDocumentStatuses.NotDelivered;
			EndIf;
		ElsIf MessageState = Enums.SMSMessagesState.BeingSentByProvider 
			Or MessageState = Enums.SMSMessagesState.SentByProvider
			Or MessageState = Enums.SMSMessagesState.ErrorOnGetStatusFromProvider
			Or MessageState = Enums.SMSMessagesState.NotSentByProvider Then
			Return Enums.SMSDocumentStatuses.DeliveryInProgress;
		ElsIf MessageState = Enums.SMSMessagesState.Delivered Then
			If CurrentStatus = Enums.SMSDocumentStatuses.Delivered
				Or CurrentStatus = Undefined Then
				CurrentStatus = Enums.SMSDocumentStatuses.Delivered;
			Else
				CurrentStatus = Enums.SMSDocumentStatuses.PartiallyDelivered;
			EndIf;
		ElsIf MessageState = Enums.SMSMessagesState.NotDelivered Then
			If CurrentStatus = Enums.SMSDocumentStatuses.Delivered Then
				CurrentStatus = Enums.SMSDocumentStatuses.PartiallyDelivered;
			Else
				CurrentStatus = Enums.SMSDocumentStatuses.NotDelivered;
			EndIf;
		ElsIf MessageState = Enums.SMSMessagesState.UnidentifiedByProvider Then
			If CurrentStatus = Enums.SMSDocumentStatuses.Delivered Then
				CurrentStatus = Enums.SMSDocumentStatuses.PartiallyDelivered;
			Else
				CurrentStatus = Enums.SMSDocumentStatuses.NotDelivered;
			EndIf;
		EndIf;
	
	EndDo;
	
	Return CurrentStatus;

EndFunction

// Transforms SMS delivery statuses of the SendSMSMessage subsystem 
// to SMS message statuses of the Interactions subsystem.
//
// Parameters:
//  DeliveryStatus  - String
//
// Returns:
//   EnumRef.SMSMessagesState
//
Function SMSMessageStateAccordingToDeliveryStatus(DeliveryStatus);
	
	If DeliveryStatus = "NotSent" Then
		Return Enums.SMSMessagesState.NotSentByProvider;
	ElsIf DeliveryStatus = "Sending2" Then
		Return Enums.SMSMessagesState.BeingSentByProvider;
	ElsIf DeliveryStatus = "Sent" Then
		Return Enums.SMSMessagesState.SentByProvider;
	ElsIf DeliveryStatus = "NotDelivered" Then
		Return Enums.SMSMessagesState.NotDelivered;
	ElsIf DeliveryStatus = "Delivered" Then
		Return Enums.SMSMessagesState.Delivered;
	ElsIf DeliveryStatus = "Pending" Then
		Return Enums.SMSMessagesState.UnidentifiedByProvider;
	ElsIf DeliveryStatus = "Error" Then
		Return Enums.SMSMessagesState.ErrorOnGetStatusFromProvider;
	Else
		Return Enums.SMSMessagesState.ErrorOnGetStatusFromProvider;
	EndIf;
	
EndFunction

// Parameters:
//  Document - DocumentObject.SMSMessage
//           - FormDataStructure
//
// Returns:
//   Number - Sent message count.
//
Function SendSMSMessageByDocument(Document) Export
	
	SetPrivilegedMode(True);
	
	If Not SendSMSMessage.SMSMessageSendingSetupCompleted() Then
		Common.MessageToUser(NStr("en = 'SMS settings not configured.';"),, "Object");
		SetStateOutgoingDocumentSMSMessage(Document);
		Return 0;
	EndIf;
	
	NumbersForSend = Document.SMSMessageRecipients.Unload(,"SendingNumber").UnloadColumn("SendingNumber");
	SendingResult = SendSMSMessage.SendSMS(NumbersForSend, Document.MessageText, Undefined, 
		Document.SendInTransliteration);
	
	ReportSMSMessageSendingResultsInDocument(Document, SendingResult);
		
	If Not IsBlankString(SendingResult.ErrorDescription) Then 
		Common.MessageToUser(SendingResult.ErrorDescription,, "Document");
	EndIf;

	Return SendingResult.SentMessages.Count();
	
EndFunction

Function SMSMessagesToSend()
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	SMSMessage.Ref AS Ref,
	|	SMSMessage.MessageText,
	|	SMSMessage.SendInTransliteration,
	|	MessageSMSAddressees.LineNumber,
	|	MessageSMSAddressees.SendingNumber,
	|	MessageSMSAddressees.HowToContact
	|FROM
	|	Document.SMSMessage.SMSMessageRecipients AS MessageSMSAddressees
	|		INNER JOIN Document.SMSMessage AS SMSMessage
	|		ON MessageSMSAddressees.Ref = SMSMessage.Ref
	|WHERE
	|	MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.Outgoing)
	|	AND NOT SMSMessage.DeletionMark
	|	AND MessageSMSAddressees.MessageID = """"
	|	AND CASE
	|			WHEN SMSMessage.DateToSendEmail = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE SMSMessage.DateToSendEmail < &CurrentDate
	|		END
	|	AND CASE
	|			WHEN SMSMessage.EmailSendingRelevanceDate = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE SMSMessage.EmailSendingRelevanceDate > &CurrentDate
	|		END
	|TOTALS BY
	|	Ref";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Result = Query.Execute();
	
	Return Result;
	
EndFunction

Procedure SendSMS() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.SendSMSMessage);
	
	SetPrivilegedMode(True);
	
	Result = SMSMessagesToSend();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	If Not SendSMSMessage.SMSMessageSendingSetupCompleted() Then
		WriteLogEvent(EmailManagement.EventLogEvent(), 
			EventLogLevel.Error, , ,
			NStr("en = 'SMS settings not configured.';", Common.DefaultLanguageCode()));
		Return;
	EndIf;
	
	MetadataOfDocument = Metadata.Documents.SMSMessage;
	
	MessageAddresseesTable = New ValueTable;
	MessageAddresseesTable.Columns.Add("LineNumber");
	MessageAddresseesTable.Columns.Add("SendingNumber");
	MessageAddresseesTable.Columns.Add("HowToContact");

	DocumentsSelection = Result.Select(QueryResultIteration.ByGroups);
	While DocumentsSelection.Next() Do
		
		MessageAddresseesTable.Clear();
		AddresseesSelection = DocumentsSelection.Select();
		While AddresseesSelection.Next() Do
			MessageText       = AddresseesSelection.MessageText;
			SendInTransliteration = AddresseesSelection.SendInTransliteration;
			NewRow = MessageAddresseesTable.Add();
			FillPropertyValues(NewRow, AddresseesSelection);
		EndDo;
		
		If MessageAddresseesTable.Count() = 0 Then
			Continue;
		EndIf;
		
		// Send outside of transaction.
		NumbersForSend = MessageAddresseesTable.UnloadColumn("SendingNumber");
		Try
			SendingResult = SendSMSMessage.SendSMS(NumbersForSend, MessageText, "", SendInTransliteration);
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot send %1 due to: 
				|%2';"),
				DocumentsSelection.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Error, MetadataOfDocument, DocumentsSelection.Ref,
				MessageText);
			Continue;
		EndTry;
		
		If ValueIsFilled(SendingResult.ErrorDescription) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot send %1 due to: 
				|%2';"),
				SendingResult.ErrorDescription);
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Error, MetadataOfDocument, DocumentsSelection.Ref,
				MessageText);
		EndIf;
		
		DocumentPresentation_ = String(DocumentsSelection.Ref);
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(MetadataOfDocument.FullName());
			LockItem.SetValue("Ref", DocumentsSelection.Ref);
			Block.Lock();
		
			DocumentObject = DocumentsSelection.Ref.GetObject();
			// @skip-check query-in-loop - Query for item-by-item data writing. 
			ReportSMSMessageSendingResultsInDocument(DocumentObject, SendingResult);
			DocumentObject.AdditionalProperties.Insert("DoNotSaveContacts", True);
			DocumentObject.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, 
				NStr("en = 'Cannot record sending of %1 due to: 
				|%2';"),
				DocumentPresentation_, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Error, MetadataOfDocument, DocumentsSelection.Ref,
				MessageText);
		EndTry;
		
	EndDo;

EndProcedure

Function SMSMessagesForStatusCheck()
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	MessageSMSAddressees.Ref AS Ref,
	|	MessageSMSAddressees.LineNumber,
	|	MessageSMSAddressees.MessageID,
	|	MessageSMSAddressees.MessageState
	|FROM
	|	Document.SMSMessage.SMSMessageRecipients AS MessageSMSAddressees
	|WHERE
	|	MessageSMSAddressees.MessageID <> """"
	|	AND (MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.BeingSentByProvider)
	|			OR MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.SentByProvider)
	|			OR MessageSMSAddressees.MessageState = VALUE(Enum.SMSMessagesState.ErrorOnGetStatusFromProvider))
	|	AND NOT MessageSMSAddressees.Ref.DeletionMark
	|TOTALS BY
	|	Ref";
	
	Return Query.Execute();
	
EndFunction

// Scheduled job handler.
// Updates SMS delivery statuses on schedule.
//
Procedure SMSDeliveryStatusUpdate() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.SMSDeliveryStatusUpdate);
	
	SetPrivilegedMode(True);
	
	MetadataOfDocument = Metadata.Documents.SMSMessage;
	
	ChangedStatusesTable = New ValueTable;
	ChangedStatusesTable.Columns.Add("LineNumber");
	ChangedStatusesTable.Columns.Add("MessageState");
	
	Result = SMSMessagesForStatusCheck();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	If Not SendSMSMessage.SMSMessageSendingSetupCompleted() Then
		WriteLogEvent(EmailManagement.EventLogEvent(), 
			EventLogLevel.Error, , ,
			NStr("en = 'SMS settings not configured.';", Common.DefaultLanguageCode()));
		Return;
	EndIf;
	
	ProcessedDocuments_ = New Map;
	MessagesIDs = New Array;
	
	DocumentsSelection = Result.Select(QueryResultIteration.ByGroups);
	While DocumentsSelection.Next() Do
		ProcessedDocuments_[DocumentsSelection.Ref] = New Array;
		IDsSelection = DocumentsSelection.Select();
		While IDsSelection.Next() Do
			SMSMessageRecipients = New Structure;
			SMSMessageRecipients.Insert("LineNumber");
			SMSMessageRecipients.Insert("MessageID");
			SMSMessageRecipients.Insert("MessageState");
			FillPropertyValues(SMSMessageRecipients, IDsSelection);
			ProcessedDocuments_[DocumentsSelection.Ref].Add(SMSMessageRecipients);
			MessagesIDs.Add(SMSMessageRecipients.MessageID);
		EndDo;
	EndDo;
	
	DeliveryStatuses = SendSMSMessage.DeliveryStatuses(MessagesIDs);
	
	For Each DocumentToProcess In ProcessedDocuments_ Do
		Ref = DocumentToProcess.Key;
		SMSMessageRecipients = DocumentToProcess.Value;
		
		ChangedStatusesTable.Clear();
		DocumentPresentation_ = Common.SubjectString(Ref);
		
		BeginTransaction();
		Try
			
			Block = New DataLock;
			LockItem = Block.Add(MetadataOfDocument.FullName());
			LockItem.SetValue("Ref", Ref);
			Block.Lock();
		
			For Each Addressee In SMSMessageRecipients Do
				
				MessageState = SMSMessageStateAccordingToDeliveryStatus(DeliveryStatuses[Addressee.MessageID]);
				
				If MessageState <> Addressee.MessageState Then
					NewRow = ChangedStatusesTable.Add();
					NewRow.LineNumber        = Addressee.LineNumber;
					NewRow.MessageState = MessageState;
				EndIf;
				
			EndDo;
			
			If ChangedStatusesTable.Count() = 0 Then
				RollbackTransaction();
				Continue;
			EndIf;
			
			DocumentObject = Ref.GetObject();
			
			For Each ChangedStatus In ChangedStatusesTable Do
				DocumentObject.SMSMessageRecipients[ChangedStatus.LineNumber - 1].MessageState = ChangedStatus.MessageState;
			EndDo;
			
			DocumentObject.State = SMSMessageDocumentState(DocumentObject);
			DocumentObject.AdditionalProperties.Insert("DoNotSaveContacts", True);
			DocumentObject.Write();
			
			CommitTransaction();
		
		Except
			
			RollbackTransaction();
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to update delivery status: %1. Reason: %2';"),
				DocumentPresentation_, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Warning, MetadataOfDocument, Ref,
				MessageText);
			
		EndTry;
		
	EndDo;
	
EndProcedure

// Sets statuses of the "SMS message" document depending on statuses of separate messages to different contacts.
//
// Parameters:
//  DocumentObject     - DocumentObject.SMSMessage, FormDataStructure
//  SendingResult  - Structure - the result of sending an SMS message.
//
Procedure ReportSMSMessageSendingResultsInDocument(DocumentObject, SendingResult)
	
	SentMessages = New Map;
	For Each SentMessage In SendingResult.SentMessages Do
		SentMessages[SentMessage.RecipientNumber] = SentMessage.MessageID;
	EndDo;
	
	For Each Addressee In DocumentObject.SMSMessageRecipients Do
		Addressee.MessageID = SentMessages[Addressee.SendingNumber];
		If ValueIsFilled(Addressee.MessageID) Then
			Addressee.MessageState = Enums.SMSMessagesState.BeingSentByProvider;
		Else
			Addressee.MessageState = Enums.SMSMessagesState.NotDelivered;
		EndIf;
	EndDo;
	
	DocumentObject.State = SMSMessageDocumentState(DocumentObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////
// Operations with email folders.

// Parameters:
//  Account  - CatalogRef.EmailAccounts - Account where the check is running.
//
// Returns:
//   Boolean   - True is the user is responsible for folder management. Otherwise, False.
//
Function UserIsResponsibleForMaintainingFolders(Account) Export
	
	If Users.IsFullUser() Then
		Return True;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			THEN EmailAccountSettings.EmployeeResponsibleForFoldersMaintenance
	|		ELSE EmailAccounts.AccountOwner
	|	END AS EmployeeResponsibleForFoldersMaintenance
	|FROM
	|	InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON EmailAccountSettings.EmailAccount = EmailAccounts.Ref
	|WHERE
	|	EmailAccountSettings.EmailAccount = &EmailAccount
	|	AND EmailAccountSettings.EmployeeResponsibleForFoldersMaintenance = &EmployeeResponsibleForFoldersMaintenance";
	
	Query.SetParameter("EmailAccount", Account);
	Query.SetParameter("EmployeeResponsibleForFoldersMaintenance", Users.AuthorizedUser());
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction 

// Parameters:
//  Folder  - CatalogRef.EmailMessageFolders - a folder, for which a parent is set.
//  NewParent  - CatalogRef.EmailMessageFolders - a folder that will be set as a parent.
//  DoNotWriteFolder  - Boolean - indicates whether it is necessary to write folder in this procedure.
//
Procedure SetFolderParent(Folder, NewParent, DoNotWriteFolder = False) Export
	
	CatalogMetadata = Metadata.Catalogs.EmailMessageFolders;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	EmailMessageFolders.Ref
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.Ref IN HIERARCHY(&FolderToMove)
	|	AND EmailMessageFolders.Ref = &NewParent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	COUNT(DISTINCT EmailMessageFolders.Ref) AS Ref
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.Ref IN HIERARCHY
	|			(SELECT
	|				EmailMessageFolders.Ref
	|			FROM
	|				Catalog.EmailMessageFolders AS EmailMessageFolders
	|			WHERE
	|				EmailMessageFolders.PredefinedFolder
	|				AND EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.Trash))
	|	AND EmailMessageFolders.Ref = &NewParent";
	
	Query.SetParameter("FolderToMove", Folder);
	Query.SetParameter("NewParent", NewParent);
	
	Result = Query.ExecuteBatch();
	If Not Result[0].IsEmpty() Then
		Return;
	EndIf;
	
	If Result[1].IsEmpty() Then
		MoveToDeletedItemsFolder = False;
	Else
		MoveToDeletedItemsFolder = True;
	EndIf;
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add(CatalogMetadata.FullName());
		LockItem.SetValue("Ref", Folder);
		Block.Lock();
		
		FolderObject1          = Folder.GetObject();
		FolderObject1.AdditionalProperties.Insert("ParentChangeProcessed", True);
		
		If Not DoNotWriteFolder Then
			FolderObject1.Parent = NewParent;
			FolderObject1.Write();
		EndIf;
		
		MoveToDeletedItemsFolder = False;
		
		If Not NewParent.IsEmpty()Then
			FolderAttributesValues = Common.ObjectAttributesValues(
				NewParent, "PredefinedFolder,PredefinedFolderType");
			If FolderAttributesValues <> Undefined 
				And FolderAttributesValues.PredefinedFolder 
				And FolderAttributesValues.PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Trash Then
				
				MoveToDeletedItemsFolder = True;
				
			EndIf;
		EndIf;
		
		If MoveToDeletedItemsFolder And Not FolderObject1.DeletionMark Then
			FolderObject1.SetDeletionMark(True);
			SetDeletionMarkForFolderEmails(Folder);
		ElsIf FolderObject1.DeletionMark And Not MoveToDeletedItemsFolder Then
			FolderObject1.SetDeletionMark(False);
			SetDeletionMarkForFolderEmails(Folder);
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Parameters:
//  Folder  - CatalogRef.EmailMessageFolders - a folder whose emails will be marked for deletion.
//
Procedure SetDeletionMarkForFolderEmails(Folder)
	
	Query = New Query;
	Query.Text = "SELECT
	|	IncomingEmail.Ref,
	|	InteractionsFolderSubjects.EmailMessageFolder.DeletionMark AS DeletionMark
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON (InteractionsFolderSubjects.Interaction = IncomingEmail.Ref)
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder IN HIERARCHY(&Folder)
	|	AND InteractionsFolderSubjects.EmailMessageFolder.DeletionMark <> IncomingEmail.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref,
	|	InteractionsFolderSubjects.EmailMessageFolder.DeletionMark
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder IN HIERARCHY(&Folder)
	|	AND OutgoingEmail.DeletionMark <> InteractionsFolderSubjects.EmailMessageFolder.DeletionMark";
	
	Query.SetParameter("Folder",Folder);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		EmailObject = Selection.Ref.GetObject();
		EmailObject.AdditionalProperties.Insert("DeletionMarkChangeProcessed",True);
		EmailObject.SetDeletionMark(Selection.DeletionMark);
		
	EndDo;

EndProcedure

// Parameters:
//  EmailsArray  - Array - an array of emails, for which a folder will be set.
//  Folder  - CatalogRef.EmailMessageFolders - a folder whose emails will be marked for deletion.
//
Procedure SetFolderForEmailsArray(EmailsArray, Folder) Export
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.DeletionMark,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON IncomingEmail.Ref = InteractionsFolderSubjects.Interaction
	|WHERE
	|	IncomingEmail.Ref IN(&EmailsArray)
	|	AND InteractionsFolderSubjects.EmailMessageFolder <> &Folder
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref,
	|	OutgoingEmail.DeletionMark,
	|	InteractionsFolderSubjects.EmailMessageFolder
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|WHERE
	|	OutgoingEmail.Ref IN(&EmailsArray)
	|	AND InteractionsFolderSubjects.EmailMessageFolder <> &Folder";
	
	Query.SetParameter("EmailsArray", EmailsArray);
	Query.SetParameter("Folder", Folder);
	
	FolderAttributesValues = Common.ObjectAttributesValues(Folder, "PredefinedFolder,PredefinedFolderType");
	If FolderAttributesValues <> Undefined 
		And FolderAttributesValues.PredefinedFolder 
		And FolderAttributesValues.PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Trash Then
		MoveToDeletedItemsFolder = True;
	Else
		MoveToDeletedItemsFolder = False;
	EndIf;
		
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(Selection.Ref.Metadata().FullName());
			LockItem.SetValue("Ref", Selection.Ref);
			InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, Selection.Ref);
			Block.Lock();
			
			SetEmailFolder(Selection.Ref, Folder, False);
			If MoveToDeletedItemsFolder And Not Selection.DeletionMark Then
				DeletionMark = True;
			ElsIf Not MoveToDeletedItemsFolder And Selection.DeletionMark Then
				DeletionMark = False;
			Else
				DeletionMark = Undefined;
			EndIf;	
			If DeletionMark <> Undefined Then
				EmailObject = Selection.Ref.GetObject();
				EmailObject.AdditionalProperties.Insert("DeletionMarkChangeProcessed", True);
				EmailObject.SetDeletionMark(DeletionMark);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	Selection.Reset();
	TableForCalculation = TableOfDataForReviewedCalculation(Selection, "Folder");
	If TableForCalculation.Find(Folder, "CalculateBy") = Undefined Then
		NewRow = TableForCalculation.Add();
		NewRow.CalculateBy = Folder;
	EndIf;
	CalculateReviewedByFolders(TableForCalculation);
	
EndProcedure

// Sets deletion mark for a folder and letters that it includes.
//
// Parameters:
//  Folder  - CatalogRef.EmailMessageFolders - a folder whose emails will be marked for deletion.
//  ErrorDescription  - String - an error description.
//
Procedure ExecuteEmailsFolderDeletion(Folder, ErrorDescription = "") Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	EmailMessageFolders.Ref
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.PredefinedFolder
	|	AND EmailMessageFolders.PredefinedFolderType = VALUE(Enum.PredefinedEmailsFoldersTypes.Trash)
	|	AND EmailMessageFolders.Owner IN
	|			(SELECT
	|				EmailMessageFolders.Owner
	|			FROM
	|				Catalog.EmailMessageFolders AS EmailMessageFolders
	|			WHERE
	|				EmailMessageFolders.Ref = &Folder)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EmailMessageFolders.Ref AS Folder
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.Ref IN HIERARCHY(&Folder)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.DeletionMark AS DeletionMark
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		INNER JOIN Document.IncomingEmail AS IncomingEmail
	|		ON InteractionsFolderSubjects.Interaction = IncomingEmail.Ref
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder IN HIERARCHY(&Folder)
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref,
	|	OutgoingEmail.DeletionMark
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref
	|WHERE
	|	InteractionsFolderSubjects.EmailMessageFolder IN HIERARCHY(&Folder)";
	
	Query.SetParameter("Folder", Folder);
	
	QueryResults = Query.ExecuteBatch();
	If QueryResults[0].IsEmpty() Then
		Return;
	EndIf;
	
	DeletedItemsFolderSelection = QueryResults[0].Select();
	DeletedItemsFolderSelection.Next();
	DeletedItemsFolder = DeletedItemsFolderSelection.Ref;
	
	Emails = QueryResults[2].Unload();
	MailFolders  = QueryResults[1].Unload();
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		For Each MailMessage In Emails Do
			LockItem = Block.Add(MailMessage.Ref.Metadata().FullName());
			LockItem.SetValue("Ref", MailMessage.Ref);
		EndDo;	
		LockItem = Block.Add("Catalog.EmailMessageFolders");
		LockItem.DataSource = MailFolders;
		LockItem.UseFromDataSource("Ref", "Folder");
		InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, Emails.UnloadColumn("Ref"));
		Block.Lock();
			
		For Each MailMessage In Emails Do
			
			SetEmailFolder(MailMessage.Ref, DeletedItemsFolder, False);
			If Not MailMessage.DeletionMark Then
				EmailObject = MailMessage.Ref.GetObject();
				EmailObject.SetDeletionMark(True);
			EndIf;
			
		EndDo;
		
		For Each EmailsFolder In MailFolders Do
			FolderObject1 =  EmailsFolder.Folder.GetObject();
			FolderObject1.SetDeletionMark(True);
		EndDo;
		
		TableForCalculation = TableOfDataForReviewedCalculation(MailFolders, "Folder");
		If TableForCalculation.Find(DeletedItemsFolder, "CalculateBy") = Undefined Then
			NewRow = TableForCalculation.Add();
			NewRow.CalculateBy = DeletedItemsFolder;
		EndIf;
		CalculateReviewedByFolders(TableForCalculation);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The folder was not deleted due to:
			|%1';"), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
		Return;
		
	EndTry;
	
EndProcedure

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - A message that needs to be assigned a folder.
//
// Returns:
//   CatalogRef.EmailMessageFolders - Folder assigned for the message.
//
Function DefineFolderForEmail(MailMessage) Export
	
	SetPrivilegedMode(True);
	
	Folder = DefineDefaultFolderForEmail(MailMessage, True);
	If ValueIsFilled(Folder) And Not Folder.PredefinedFolder Then
		Return Folder;
	EndIf;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	EmailProcessingRules.Ref              AS Ref,
	|	EmailProcessingRules.Owner            AS Account,
	|	EmailProcessingRules.Description        AS RuleDescription,
	|	EmailProcessingRules.SettingsComposer AS SettingsComposer,
	|	EmailProcessingRules.PutInFolder      AS PutInFolder
	|FROM
	|	Catalog.EmailProcessingRules AS EmailProcessingRules
	|WHERE
	|	EmailProcessingRules.Owner IN
	|			(SELECT
	|				Interactions.Account
	|			FROM
	|				DocumentJournal.Interactions AS Interactions
	|			WHERE
	|				Interactions.Ref = &MailMessage)
	|	AND NOT EmailProcessingRules.DeletionMark
	|
	|ORDER BY
	|	EmailProcessingRules.AddlOrderingAttribute";
	
	Query.SetParameter("MailMessage", MailMessage);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Folder;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		
		Try
			ProcessingRulesSchema = 
				Catalogs.EmailProcessingRules.GetTemplate("EmailProcessingRuleScheme");
			
			TemplateComposer = New DataCompositionTemplateComposer();
			SettingsComposer = New DataCompositionSettingsComposer;
			SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProcessingRulesSchema));
			SettingsComposer.LoadSettings(Selection.SettingsComposer.Get());
			SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
			CommonClientServer.SetFilterItem(
				SettingsComposer.Settings.Filter, "Ref", MailMessage, DataCompositionComparisonType.Equal);
			
			DataCompositionTemplate = TemplateComposer.Execute(
				ProcessingRulesSchema, SettingsComposer.GetSettings(),,,
				Type("DataCompositionValueCollectionTemplateGenerator"));
			
			If DataCompositionTemplate.ParameterValues.Count() = 0 Then
				Continue;
			EndIf;
			
			QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
			QueryRule = New Query(QueryText);
			For Each Parameter In DataCompositionTemplate.ParameterValues Do
				QueryRule.Parameters.Insert(Parameter.Name, Parameter.Value);
			EndDo;
			
			// @skip-check query-in-loop - Run mailbox rules until it finds the first message that meets the rule condition.
			Result = QueryRule.Execute();

		Except
			
			ErrorMessageTemplate = NStr("en = 'Cannot apply the ""%1"" mailbox rule to the ""%2"" account due to: 
			                                |%3
			                                |Correct the mailbox rule.';", Common.DefaultLanguageCode());
		
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorMessageTemplate, 
				Selection.RuleDescription,
				Selection.Account,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EmailManagement.EventLogEvent(), 
				EventLogLevel.Error, , Selection.Ref, ErrorMessageText);
			Continue;
			
		EndTry;
		
		If Not Result.IsEmpty() Then
			Return Selection.PutInFolder;
		EndIf;
		
	EndDo;
	
	Return Folder;
	
EndFunction

// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail
//          - DocumentRef.OutgoingEmail - A message that needs to be assigned a folder.
//  IncludingBaseEmailChecks  - Boolean - indicates that it is necessary to check if a folder is determined to the base email
//                                             folder.
//
// Returns:
//   CatalogRef.EmailMessageFolders - Folder assigned for the message.
//
Function DefineDefaultFolderForEmail(MailMessage, IncludingBaseEmailChecks = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If IncludingBaseEmailChecks Then
		Query.Text = "
		|SELECT
		|	EmailMessageFolders.Ref AS Folder,
		|	Interactions.Ref AS MailMessage
		|INTO FoldersByBasis
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|		INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|			INNER JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
		|			ON InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref
		|				AND ((NOT EmailMessageFolders.PredefinedFolder))
		|		ON (InteractionsFolderSubjects.Interaction = Interactions.InteractionBasis)
		|		INNER JOIN Catalog.EmailAccounts AS EmailAccounts
		|			INNER JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
		|			ON EmailAccounts.Ref = EmailAccountSettings.EmailAccount
		|		ON Interactions.Account = EmailAccounts.Ref
		|WHERE
		|	Interactions.Ref = &MailMessage
		|	AND VALUETYPE(Interactions.InteractionBasis) IN (TYPE(Document.OutgoingEmail), TYPE(Document.IncomingEmail))
		|	AND EmailMessageFolders.Owner = Interactions.Account
		|	AND EmailAccountSettings.PutEmailInBaseEmailFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EmailMessageFolders.Ref,
		|	EmailMessageFolders.PredefinedFolderType
		|INTO MailFolders
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|WHERE
		|	EmailMessageFolders.PredefinedFolder
		|	AND EmailMessageFolders.Owner IN
		|			(SELECT
		|				Interactions.Account
		|			FROM
		|				DocumentJournal.Interactions AS Interactions
		|			WHERE
		|				Interactions.Ref = &MailMessage)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Interactions.Ref,
		|	CASE
		|		WHEN Interactions.DeletionMark
		|			THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Trash)
		|		WHEN Interactions.Type = TYPE(Document.IncomingEmail)
		|			THEN Interactions.Type = TYPE(Document.IncomingEmail)
		|		WHEN Interactions.Type = TYPE(Document.OutgoingEmail)
		|			THEN CASE
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Draft)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Drafts)
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Sent)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.SentMessages)
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Outbox)
		|				END
		|		ELSE VALUE(Enum.PredefinedEmailsFoldersTypes.JunkMail)
		|	END AS FolderType
		|INTO TypesOfDestinationFolders
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|WHERE
		|	Interactions.Ref = &MailMessage
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TypesOfDestinationFolders.Ref AS MailMessage,
		|	CASE
		|		WHEN FoldersByBasis.Folder IS NULL 
		|			THEN MailFolders.Ref
		|		ELSE FoldersByBasis.Folder
		|	END AS Folder
		|FROM
		|	TypesOfDestinationFolders AS TypesOfDestinationFolders
		|		INNER JOIN MailFolders AS MailFolders
		|		ON TypesOfDestinationFolders.FolderType = MailFolders.PredefinedFolderType
		|		LEFT JOIN FoldersByBasis AS FoldersByBasis
		|		ON TypesOfDestinationFolders.Ref = FoldersByBasis.MailMessage";
		
	Else
		
		Query.Text = "
		|SELECT
		|	EmailMessageFolders.Ref,
		|	EmailMessageFolders.PredefinedFolderType
		|INTO MailFolders
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|WHERE
		|	EmailMessageFolders.PredefinedFolder
		|	AND EmailMessageFolders.Owner IN
		|			(SELECT
		|				Interactions.Account
		|			FROM
		|				DocumentJournal.Interactions AS Interactions
		|			WHERE
		|				Interactions.Ref = &MailMessage)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Interactions.Ref,
		|	CASE
		|		WHEN Interactions.DeletionMark
		|			THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Trash)
		|		WHEN Interactions.Type = TYPE(Document.IncomingEmail)
		|			THEN VALUE(Enum.PredefinedEmailsFoldersTypes.IncomingMessages)
		|		WHEN Interactions.Type = TYPE(Document.OutgoingEmail)
		|			THEN CASE
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Draft)
		|						THEN  VALUE(Enum.PredefinedEmailsFoldersTypes.Drafts)
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Sent)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.SentMessages)
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Outbox)
		|				END
		|		ELSE VALUE(Enum.PredefinedEmailsFoldersTypes.JunkMail)
		|	END AS FolderType
		|INTO TypesOfDestinationFolders
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|WHERE
		|	Interactions.Ref = &MailMessage
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TypesOfDestinationFolders.Ref AS MailMessage,
		|	MailFolders.Ref          AS Folder
		|FROM
		|	TypesOfDestinationFolders AS TypesOfDestinationFolders
		|		INNER JOIN MailFolders AS MailFolders
		|		ON TypesOfDestinationFolders.FolderType = MailFolders.PredefinedFolderType";
		
	EndIf;
	
	Query.SetParameter("MailMessage", MailMessage);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		Return Selection.Folder;
		
	EndIf;
	
EndFunction

// Parameters:
//  EmailsArray  - Array - an email array, for which folders will be set.
//
Procedure SetFoldersForEmailsArray(EmailsArray) Export
	
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|WHERE
	|	InteractionsFolderSubjects.Interaction IN(&EmailsArray)";
	
	Query.SetParameter("EmailsArray", EmailsArray);
	
	FoldersForCalculation = Query.Execute().Unload().UnloadColumn("Folder");
	FoldersTable = DefineEmailFolders(EmailsArray);
	
	If FoldersTable.Count() = 0 Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Block = New DataLock;
		InformationRegisters.InteractionsFolderSubjects.BlochFoldersSubjects(Block, FoldersTable, "MailMessage");
		Block.Lock();
		
		For Each TableRow In FoldersTable Do
			SetEmailFolder(TableRow.MailMessage, TableRow.Folder, False);
			If ValueIsFilled(TableRow.Folder) And FoldersForCalculation.Find(TableRow.Folder) = Undefined Then
				FoldersForCalculation.Add(TableRow.Folder);
			EndIf;
		EndDo;
			
		CalculateReviewedByFolders(TableOfDataForReviewedCalculation(FoldersForCalculation, "Folder"));
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Determines folders for sent email messages.
//
// Parameters:
//  Emails  - Array of DocumentRef.IncomingEmail
//          - Array of DocumentRef.OutgoingEmail
//
// Returns:
//   ValueTable - Maps email messages with folders:
//    * Folder - CatalogRef.EmailMessageFolders
//    * MailMessage - DocumentRef.IncomingEmail, DocumentRef.OutgoingEmail
//
Function DefineEmailFolders(Emails)
	
	MapsTable = New ValueTable;
	MapsTable.Columns.Add("Folder");
	MapsTable.Columns.Add("MailMessage");
	
	If Emails.Count() = 0 Then
		Return MapsTable;
	EndIf;
	
	Query = New Query(
		"SELECT
		|	EmailProcessingRules.Owner            AS Account,
		|	EmailProcessingRules.SettingsComposer AS SettingsComposer,
		|	EmailProcessingRules.PutInFolder      AS PutInFolder,
		|	EmailProcessingRules.Ref              AS Ref,
		|	EmailProcessingRules.Description        AS RuleDescription
		|FROM
		|	Catalog.EmailProcessingRules AS EmailProcessingRules
		|WHERE
		|	EmailProcessingRules.Owner IN
		|			(SELECT
		|				Interactions.Account
		|			FROM
		|				DocumentJournal.Interactions AS Interactions
		|			WHERE
		|				Interactions.Ref IN (&EmailsArray))
		|	AND (NOT EmailProcessingRules.DeletionMark)
		|
		|ORDER BY
		|	EmailProcessingRules.AddlOrderingAttribute
		|TOTALS BY
		|	Account");
	
	Query.SetParameter("EmailsArray", Emails);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		SelectionAccount = Result.Select(QueryResultIteration.ByGroups);
		While SelectionAccount.Next() Do
			Selection = SelectionAccount.Select();
			While Selection.Next() Do
				
				Try
				
					ProcessingRulesSchema = 
						Catalogs.EmailProcessingRules.GetTemplate("EmailProcessingRuleScheme");
					
					TemplateComposer = New DataCompositionTemplateComposer();
					SettingsComposer = New DataCompositionSettingsComposer;
					SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ProcessingRulesSchema));
					SettingsComposer.LoadSettings(Selection.SettingsComposer.Get());
					SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
					CommonClientServer.SetFilterItem(
						SettingsComposer.Settings.Filter, "Ref", Emails, DataCompositionComparisonType.InList);
					CommonClientServer.SetFilterItem(
						SettingsComposer.Settings.Filter,
						"Ref.Account",
						SelectionAccount.Account,
						DataCompositionComparisonType.Equal);
					
					DataCompositionTemplate = TemplateComposer.Execute(
						ProcessingRulesSchema,
						SettingsComposer.GetSettings(),
						,,
						Type("DataCompositionValueCollectionTemplateGenerator"));
					
					QueryText = DataCompositionTemplate.DataSets.MainDataSet.Query;
					QueryRule = New Query(QueryText);
					For Each Parameter In DataCompositionTemplate.ParameterValues Do
						QueryRule.Parameters.Insert(Parameter.Name, Parameter.Value);
					EndDo;
					
					// @skip-check query-in-loop - Batch processing of email messages by user accounts.
					EmailResult = QueryRule.Execute();
					
				Except
					
					ErrorMessageTemplate = NStr("en = 'Cannot apply the ""%1"" mailbox rule to the ""%2"" account due to: 
					                                |%3
					                                |Correct the mailbox rule.';", Common.DefaultLanguageCode());
				
					ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
						ErrorMessageTemplate, 
						Selection.RuleDescription,
						Selection.Account,
						ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					WriteLogEvent(EmailManagement.EventLogEvent(), 
						EventLogLevel.Error, , Selection.Ref, ErrorMessageText);
					Continue;
					
				EndTry;

				If Not EmailResult.IsEmpty() Then
					EmailSelection = EmailResult.Select();
					While EmailSelection.Next() Do
						
						NewTableRow = MapsTable.Add();
						NewTableRow.Folder = Selection.PutInFolder;
						NewTableRow.MailMessage = EmailSelection.Ref;
						
						ArrayElementIndexForDeletion = Emails.Find(EmailSelection.Ref);
						If ArrayElementIndexForDeletion <> Undefined Then
							Emails.Delete(ArrayElementIndexForDeletion);
						EndIf;
					EndDo;
				EndIf;
				
				If Emails.Count() = 0 Then
					Return MapsTable;
				EndIf;

			EndDo;
			
		EndDo;
	EndIf;
	
	If Emails.Count() > 0 Then
		DefineDefaultEmailFolders(Emails, MapsTable);
	EndIf;
	
	Return MapsTable;
	
EndFunction

// Parameters:
//  Emails  - Array of DocumentRef.IncomingEmail
//          - Array of DocumentRef.OutgoingEmail
//  EmailsTable  - See DefineEmailFolders
//
Procedure DefineDefaultEmailFolders(Emails, EmailsTable)
	
	Query = New Query(
		"SELECT
		|	EmailMessageFolders.Ref                    AS Ref,
		|	EmailMessageFolders.PredefinedFolderType  AS PredefinedFolderType,
		|	EmailMessageFolders.Owner                  AS Account
		|INTO MailFolders
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|WHERE
		|	EmailMessageFolders.PredefinedFolder
		|	AND EmailMessageFolders.Owner IN
		|			(SELECT DISTINCT
		|				Interactions.Account
		|			FROM
		|				DocumentJournal.Interactions AS Interactions
		|			WHERE
		|				Interactions.Ref IN (&EmailsArray))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Interactions.Ref,
		|	CASE
		|		WHEN Interactions.DeletionMark
		|			THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Trash)
		|		WHEN Interactions.Type = TYPE(Document.IncomingEmail)
		|			THEN VALUE(Enum.PredefinedEmailsFoldersTypes.IncomingMessages)
		|		WHEN Interactions.Type = TYPE(Document.OutgoingEmail)
		|			THEN CASE
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Draft)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Drafts) 
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Sent)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.SentMessages)
		|					WHEN Interactions.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
		|						THEN VALUE(Enum.PredefinedEmailsFoldersTypes.Outbox)
		|				END
		|		ELSE VALUE(Enum.PredefinedEmailsFoldersTypes.JunkMail) 
		|	END AS FolderType,
		|	Interactions.Account
		|INTO TypesOfDestinationFolders
		|FROM
		|	DocumentJournal.Interactions AS Interactions
		|WHERE
		|	Interactions.Ref IN(&EmailsArray)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MailFolders.Ref AS Folder,
		|	TypesOfDestinationFolders.Ref AS MailMessage
		|FROM
		|	TypesOfDestinationFolders AS TypesOfDestinationFolders
		|		INNER JOIN MailFolders AS MailFolders
		|		ON TypesOfDestinationFolders.FolderType = MailFolders.PredefinedFolderType
		|			AND TypesOfDestinationFolders.Account = MailFolders.Account");
	
	Query.SetParameter("EmailsArray", Emails);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		CommonClientServer.SupplementTable(Result.Unload(), EmailsTable);
	EndIf;
	
EndProcedure

// Parameters:
//  EmailObject - DocumentObject.OutgoingEmail
//               - DocumentObject.IncomingEmail
//
Procedure ProcessDeletionMarkChangeFlagOnWriteEmail(EmailObject) Export
	
	If EmailObject.DeletionMark = EmailObject.AdditionalProperties.DeletionMark Then
		Return;
	EndIf;
		
	SetPrivilegedMode(True);
	If Not EmailObject.AdditionalProperties.Property("DeletionMarkChangeProcessed") Then
		If EmailObject.DeletionMark = True Then
			Folder = DefineDefaultFolderForEmail(EmailObject.Ref);
		Else
			Folder = DefineFolderForEmail(EmailObject.Ref);
		EndIf;
		SetEmailFolder(EmailObject.Ref, Folder);
	EndIf;
	
EndProcedure

// Parameters:
//  MailFolders - ValueTable:
//    * MailMessage - DocumentRef.OutgoingEmail
//    * Folder - CatalogRef.EmailMessageFolders
//  CalculateReviewedItems - Boolean
//
Procedure SetEmailFolders(MailFolders, CalculateReviewedItems = True) Export
	
	BeginTransaction();
	Try
		Block = New DataLock();
		InformationRegisters.InteractionsFolderSubjects.BlochFoldersSubjects(Block, MailFolders, "MailMessage");
		Block.Lock();
		For Each MessageFolder In MailFolders Do
			SetEmailFolder(MessageFolder.MailMessage, MessageFolder.Folder, CalculateReviewedItems);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Parameters:
//  Ref - DocumentRef.OutgoingEmail
//  Folder - CatalogRef.EmailMessageFolders
//  CalculateReviewedItems - Boolean
//
Procedure SetEmailFolder(Ref, Folder, CalculateReviewedItems = True) Export
	
	Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	Attributes.Folder                   = Folder;
	Attributes.CalculateReviewedItems = CalculateReviewedItems;
	InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Ref, Attributes);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////
//  Compute states.

// Calculates interaction subject states.
//
// Parameters:
//  FoldersTable  - ValueTable
//                - Undefined - Table of folders whose states must be calculated.
//             If Undefined, calculate states of all folders.
//
Procedure CalculateReviewedByFolders(FoldersTable) Export

	SetPrivilegedMode(True);
	Query = New Query;
	
	If FoldersTable = Undefined Then
		
		InformationRegisters.EmailFolderStates.DeleteRecordFromRegister(Undefined);
		
		Query.Text = "
		|SELECT DISTINCT
		|	InteractionsFolderSubjects.EmailMessageFolder AS EmailMessageFolder,
		|	SUM(CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END) AS NotReviewedInteractionsCount
		|INTO FoldersToUse
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	InteractionsFolderSubjects.EmailMessageFolder <> VALUE(Catalog.EmailMessageFolders.EmptyRef)
		|
		|GROUP BY
		|	InteractionsFolderSubjects.EmailMessageFolder
		|
		|INDEX BY
		|	EmailMessageFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EmailMessageFolders.Ref AS Folder,
		|	ISNULL(FoldersToUse.NotReviewedInteractionsCount, 0) AS NotReviewed
		|FROM
		|	Catalog.EmailMessageFolders AS EmailMessageFolders
		|		LEFT JOIN FoldersToUse AS FoldersToUse
		|		ON (FoldersToUse.EmailMessageFolder = EmailMessageFolders.Ref)";
		
	Else
		
		If FoldersTable.Count() = 0 Then
			Return;
		EndIf;
		
		Query.Text = "
		|SELECT
		|	FoldersForCalculation.CalculateBy AS Folder
		|INTO FoldersForCalculation
		|FROM
		|	&FoldersForCalculation AS FoldersForCalculation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM(CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END) AS NotReviewedInteractionsCount,
		|	InteractionsFolderSubjects.EmailMessageFolder AS Folder
		|INTO CalculatedFolders
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	InteractionsFolderSubjects.EmailMessageFolder IN
		|			(SELECT
		|				FoldersForCalculation.Folder
		|			FROM
		|				FoldersForCalculation AS FoldersForCalculation)
		|
		|GROUP BY
		|	InteractionsFolderSubjects.EmailMessageFolder
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FoldersForCalculation.Folder,
		|	ISNULL(CalculatedFolders.NotReviewedInteractionsCount, 0) AS NotReviewed
		|FROM
		|	FoldersForCalculation AS FoldersForCalculation
		|		LEFT JOIN CalculatedFolders AS CalculatedFolders
		|		ON FoldersForCalculation.Folder = CalculatedFolders.Folder";
		
		Query.SetParameter("FoldersForCalculation", FoldersTable);
		
	EndIf;
	
	MailFolders = Query.Execute().Unload();
	BeginTransaction();
	Try
		Block = New DataLock;
		InformationRegisters.EmailFolderStates.BlockEmailsFoldersStatus(Block, MailFolders, "Folder");
		Block.Lock();
		
		For Each EmailsFolder In MailFolders Do
			InformationRegisters.EmailFolderStates.ExecuteRecordToRegister(EmailsFolder.Folder, EmailsFolder.NotReviewed);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	

EndProcedure

// Calculates interaction contact states.
//
// Parameters:
//  ObjectsTable - ValueTable
//                    - Undefined - a table of contacts that must be calculated.
//                      If Undefined, states of all contacts are calculated.
//
Procedure CalculateReviewedByContacts(DataForCalculation) Export

	SetPrivilegedMode(True);
	
	If DataForCalculation = Undefined Then
		
		InformationRegisters.InteractionsContactStates.DeleteRecordFromRegister(Undefined);
		
		While True Do
		
			Query = New Query;
			Query.Text = "
			|SELECT DISTINCT TOP 1000
			|	InteractionsContacts.Contact
			|INTO ContactsForSettlement
			|FROM
			|	InformationRegister.InteractionsContacts AS InteractionsContacts
			|		LEFT JOIN InformationRegister.InteractionsContactStates AS InteractionsContactStates
			|		ON InteractionsContacts.Contact = InteractionsContactStates.Contact
			|WHERE
			|	InteractionsContactStates.Contact IS NULL 
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT DISTINCT
			|	InteractionsContacts.Contact,
			|	MAX(Interactions.Date) AS LastInteractionDate,
			|	SUM(CASE
			|			WHEN InteractionsFolderSubjects.Reviewed
			|				THEN 0
			|			ELSE 1
			|		END) AS NotReviewedInteractionsCount
			|FROM
			|	ContactsForSettlement AS ContactsForSettlement
			|		INNER JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
			|			INNER JOIN DocumentJournal.Interactions AS Interactions
			|			ON InteractionsContacts.Interaction = Interactions.Ref
			|			INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
			|			ON InteractionsContacts.Interaction = InteractionsFolderSubjects.Interaction
			|		ON ContactsForSettlement.Contact = InteractionsContacts.Contact
			|
			|GROUP BY
			|	InteractionsContacts.Contact";
			
			Result = Query.Execute();
			If Result.IsEmpty() Then
				Return;
			EndIf;
			
			RefreshInteractionContactsStates(Result.Unload());
			
		EndDo;
		Return;
		
	EndIf;
		
	Query = New Query;
	If TypeOf(DataForCalculation) = Type("ValueTable") Then
		
		TextContactsForCalculation = 
		"SELECT
		|	ContactsForSettlement.CalculateBy AS Contact
		|INTO ContactsForSettlement
		|FROM
		|	&ContactsForSettlement AS ContactsForSettlement
		|
		|INDEX BY
		|	Contact
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////";
		
		Query.SetParameter("ContactsForSettlement", DataForCalculation);
		
	ElsIf TypeOf(DataForCalculation) = Type("QueryResultSelection") Then
		
		InteractionsArray = New Array;
		While DataForCalculation.Next() Do
			InteractionsArray.Add(DataForCalculation.Interaction);
		EndDo;
		
		TextContactsForCalculation = 
		"SELECT DISTINCT
		|	InteractionsContacts.Contact
		|INTO ContactsForSettlement
		|FROM
		|	InformationRegister.InteractionsContacts AS InteractionsContacts
		|WHERE
		|	InteractionsContacts.Interaction IN(&InteractionsArray)
		|
		|INDEX BY
		|	Contact
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////";
		
		Query.SetParameter("InteractionsArray", InteractionsArray);
		
	ElsIf TypeOf(DataForCalculation) = Type("Array") Then
		
		TextContactsForCalculation = 
		"SELECT DISTINCT
		|	InteractionsContacts.Contact
		|INTO ContactsForSettlement
		|FROM
		|	InformationRegister.InteractionsContacts AS InteractionsContacts
		|WHERE
		|	InteractionsContacts.Interaction IN(&InteractionsArray)
		|
		|INDEX BY
		|	Contact
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////";
		
		Query.SetParameter("InteractionsArray", DataForCalculation);
		
	Else 
		Return;
	EndIf;
	
	Query.Text = TextContactsForCalculation + "
	|SELECT
	|	NestedQuery.Contact                                AS Contact,
	|	MAX(NestedQuery.LastInteractionDate) AS LastInteractionDate,
	|	SUM(NestedQuery.NotReviewedInteractionsCount)         AS NotReviewedInteractionsCount
	|FROM
	|	(SELECT DISTINCT
	|		ContactsForSettlement.Contact AS Contact,
	|		Interactions.Ref AS Ref,
	|		ISNULL(Interactions.Date, DATETIME(1, 1, 1)) AS LastInteractionDate,
	|		CASE
	|			WHEN ISNULL(InteractionsFolderSubjects.Reviewed, TRUE)
	|				THEN 0
	|			ELSE 1
	|		END AS NotReviewedInteractionsCount
	|	FROM
	|		ContactsForSettlement AS ContactsForSettlement
	|			LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|			ON ContactsForSettlement.Contact = InteractionsContacts.Contact
	|			LEFT JOIN DocumentJournal.Interactions AS Interactions
	|			ON InteractionsContacts.Interaction = Interactions.Ref
	|			LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			ON InteractionsContacts.Interaction = InteractionsFolderSubjects.Interaction) AS NestedQuery
	|
	|GROUP BY
	|	NestedQuery.Contact";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	RefreshInteractionContactsStates(Result.Unload());

EndProcedure

Procedure RefreshInteractionContactsStates(InteractionsContactStates)
	
	BeginTransaction();
	Try
		Block = New DataLock;
		InformationRegisters.InteractionsContactStates.BlockInteractionContactsStates(Block,
			InteractionsContactStates, "Contact");
		Block.Lock();	
		
		For Each Selection In InteractionsContactStates Do
			If Selection.LastInteractionDate = Date(1, 1, 1) Then
				InformationRegisters.InteractionsContactStates.DeleteRecordFromRegister(Selection.Contact);
			Else
				InformationRegisters.InteractionsContactStates.ExecuteRecordToRegister(Selection.Contact,
				Selection.NotReviewedInteractionsCount, Selection.LastInteractionDate);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure

// Calculates interaction subject states.
//
// Parameters:
//  ObjectsTable - ValueTable
//                    - Undefined - a table of objects that must be calculated.
//                      If Undefined, states of all subjects are calculated.
//
Procedure CalculateReviewedBySubjects(DataForCalculation) Export

	SetPrivilegedMode(True);
	Query = New Query;
	
	If DataForCalculation = Undefined Then
		
		InformationRegisters.InteractionsSubjectsStates.DeleteRecordFromRegister(Undefined);
		
		Query.Text = "
		|SELECT
		|	InteractionsFolderSubjects.SubjectOf,
		|	SUM(CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END) AS NotReviewedInteractionsCount,
		|	MAX(Interactions.Date) AS LastInteractionDate,
		|	MAX(ISNULL(InteractionsSubjectsStates.Running, FALSE)) AS Running
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		LEFT JOIN DocumentJournal.Interactions AS Interactions
		|		ON InteractionsFolderSubjects.Interaction = Interactions.Ref
		|		LEFT JOIN InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|		ON InteractionsFolderSubjects.SubjectOf = InteractionsSubjectsStates.SubjectOf
		|
		|GROUP BY
		|	InteractionsFolderSubjects.SubjectOf";
		
	Else
		
		If DataForCalculation.Count() = 0 Then
			Return;
		EndIf;
		
		If TypeOf(DataForCalculation) = Type("ValueTable") Then
			
			TextSubjectsForCalculation = "
			|SELECT
			|	SubjectsForCalculation.CalculateBy AS SubjectOf
			|INTO SubjectsForCalculation
			|FROM
			|	&SubjectsForCalculation AS SubjectsForCalculation
			|
			|INDEX BY
			|	SubjectOf
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////";
			
			Query.SetParameter("SubjectsForCalculation", DataForCalculation);
			
		ElsIf TypeOf(DataForCalculation) = Type("Array") Then
			
			TextSubjectsForCalculation = "
			|SELECT DISTINCT
			|	InteractionsFolderSubjects.SubjectOf AS SubjectOf
			|INTO SubjectsForCalculation
			|FROM
			|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
			|WHERE
			|	InteractionsFolderSubjects.Interaction IN(&InteractionsArray)
			|
			|INDEX BY
			|	SubjectOf
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////";
			
			Query.SetParameter("InteractionsArray", DataForCalculation);
			
		Else
			
			Return;
			
		EndIf;
		
		Query.Text = TextSubjectsForCalculation + "
		|SELECT
		|	InteractionsFolderSubjects.SubjectOf AS SubjectOf,
		|	SUM(CASE
		|			WHEN InteractionsFolderSubjects.Reviewed
		|				THEN 0
		|			ELSE 1
		|		END) AS NotReviewedInteractionsCount,
		|	MAX(Interactions.Date) AS LastInteractionDate,
		|	MAX(ISNULL(InteractionsSubjectsStates.Running, FALSE)) AS Running
		|INTO CalculatedSubjects
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|		LEFT JOIN DocumentJournal.Interactions AS Interactions
		|		ON InteractionsFolderSubjects.Interaction = Interactions.Ref
		|		LEFT JOIN InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|		ON InteractionsFolderSubjects.SubjectOf = InteractionsSubjectsStates.SubjectOf
		|WHERE
		|	InteractionsFolderSubjects.SubjectOf IN
		|			(SELECT
		|				SubjectsForCalculation.SubjectOf
		|			FROM
		|				SubjectsForCalculation)
		|
		|GROUP BY
		|	InteractionsFolderSubjects.SubjectOf
		|
		|INDEX BY
		|	SubjectOf
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SubjectsForCalculation.SubjectOf,
		|	ISNULL(CalculatedSubjects.NotReviewedInteractionsCount, 0) AS NotReviewedInteractionsCount,
		|	ISNULL(CalculatedSubjects.LastInteractionDate, DATETIME(1, 1, 1)) AS LastInteractionDate,
		|	CASE
		|		WHEN CalculatedSubjects.Running IS NULL 
		|			THEN ISNULL(InteractionsSubjectsStates.Running, FALSE)
		|		ELSE CalculatedSubjects.Running
		|	END AS Running
		|FROM
		|	SubjectsForCalculation AS SubjectsForCalculation
		|		LEFT JOIN CalculatedSubjects AS CalculatedSubjects
		|		ON SubjectsForCalculation.SubjectOf = CalculatedSubjects.SubjectOf
		|		LEFT JOIN InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|		ON SubjectsForCalculation.SubjectOf = InteractionsSubjectsStates.SubjectOf";
		
		
	EndIf;
	
	InteractionsSubjectsStates = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		Block = New DataLock;
		InformationRegisters.InteractionsSubjectsStates.BlockInteractionObjectsStatus(Block,
			InteractionsSubjectsStates, "SubjectOf");
		Block.Lock();

		For Each Selection In InteractionsSubjectsStates Do
			If Selection.LastInteractionDate <> Date(1,1,1) Or Selection.Running = True  Then
				InformationRegisters.InteractionsSubjectsStates.ExecuteRecordToRegister(Selection.SubjectOf, 
					Selection.NotReviewedInteractionsCount, Selection.LastInteractionDate, Selection.Running);
			Else
				InformationRegisters.InteractionsSubjectsStates.DeleteRecordFromRegister(Selection.SubjectOf);
			EndIf;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
EndProcedure

// Generates a data table to calculate folder states and interaction subjects.
//
// Parameters:
//  DataForCalculation  - Structure
//                    - QueryResultSelection
//                    - Array of CatalogRef.EmailMessageFolders
//                    - Array of DefinedType.InteractionSubject
//                    - Array of DefinedType.InteractionContact - Data to be used to generate 
//                      a table.
//  AttributeName  - String - Has the following valid values: "Topic", "Folder" or "Contact".
//
// Returns:
//   ValueTable:
//    * CalculateBy - CatalogRef.EmailMessageFolders
//                         - DefinedType.InteractionSubject
//                         - DefinedType.InteractionContact
//
Function TableOfDataForReviewedCalculation(DataForCalculation, AttributeName) Export

	GeneratedTable = New ValueTable;
	If AttributeName = "Folder" Then
		ColumnTypesDetails = New TypeDescription("CatalogRef.EmailMessageFolders");
	ElsIf AttributeName = "SubjectOf" Then
		ColumnTypesDetails = New TypeDescription(New TypeDescription(Metadata.InformationRegisters.InteractionsSubjectsStates.Dimensions.SubjectOf.Type.Types()));
	ElsIf AttributeName = "Contact" Then
		ColumnTypesDetails = New TypeDescription(New TypeDescription(Metadata.InformationRegisters.InteractionsContacts.Dimensions.Contact.Type.Types()));
	EndIf;
	
	GeneratedTable.Columns.Add("CalculateBy", ColumnTypesDetails);
	
	If TypeOf(DataForCalculation) = Type("Structure") Then
		
		NewRecord  = DataForCalculation.NewRecord;
		OldRecord = DataForCalculation.OldRecord;
		
		If ValueIsFilled(NewRecord[AttributeName]) Then
			NewRow = GeneratedTable.Add();
			NewRow.CalculateBy = NewRecord[AttributeName];
		EndIf;
		
		If ValueIsFilled(OldRecord[AttributeName]) And NewRecord[AttributeName] <> OldRecord[AttributeName] Then
			
			NewRow = GeneratedTable.Add();
			NewRow.CalculateBy = OldRecord[AttributeName];
			
		EndIf;
		
	ElsIf TypeOf(DataForCalculation) = Type("QueryResultSelection") Then
		
		While DataForCalculation.Next() Do
			If ValueIsFilled(DataForCalculation[AttributeName]) And GeneratedTable.Find(DataForCalculation[AttributeName], "CalculateBy") = Undefined Then
				NewRow = GeneratedTable.Add();
				NewRow.CalculateBy = DataForCalculation[AttributeName];
			EndIf;
		EndDo;
		
	ElsIf TypeOf(DataForCalculation) = Type("Array") Then
		
		For Each ArrayElement In DataForCalculation Do
			If ValueIsFilled(ArrayElement) And GeneratedTable.Find(ArrayElement, "CalculateBy") = Undefined Then
				NewRow = GeneratedTable.Add();
				NewRow.CalculateBy = ArrayElement;
			EndIf;
		EndDo;
		
	EndIf;
	
	GeneratedTable.Indexes.Add("CalculateBy");
	
	Return GeneratedTable;

EndFunction

// Determines if it is necessary to calculate states of folders, subjects or interaction contacts.
//
// Parameters:
//  AdditionalProperties  - Structure - additional properties of a record set or an interaction document.
//
// Returns:
//   Boolean   - Flag indicating whether to calculate states of folders, subjects, or interaction contacts.
//
Function CalculateReviewedItems(AdditionalProperties) Export
	Var CalculateReviewedItems;

	Return AdditionalProperties.Property("CalculateReviewedItems", CalculateReviewedItems)
		And CalculateReviewedItems;

EndFunction

// Specifies whether it is necessary to write interaction contacts to an auxiliary information register 
//  "Interaction contacts".
//
// Parameters:
//  AdditionalProperties  - Structure - additional properties of the interaction document.
//
// Returns:
//   Boolean   - Flag indicating whether to save interaction contacts to the auxiliary information register "Interaction contacts". 
//    
//
Function DoNotSaveContacts(AdditionalProperties)
	Var DoNotSaveContacts;
	
	Return AdditionalProperties.Property("DoNotSaveContacts", DoNotSaveContacts) 
		And DoNotSaveContacts;

EndFunction

// Parameters:
//  InteractionsArray  - Array - an array, to which a flag is being set.
//  FlagValue      - Boolean - the Reviewed flag value.
//  HasChanges         - Boolean - indicates that at least one interaction had his value changed
//                                   Reviewed.
//
Procedure MarkAsReviewed(InteractionsArray, FlagValue, HasChanges) Export

	If InteractionsArray.Count() = 0 Then
		Return;
	EndIf;
		
	Query = New Query;
	Query.Text = "
	|SELECT
	|	InteractionsFolderSubjects.Interaction,
	|	InteractionsFolderSubjects.EmailMessageFolder AS Folder,
	|	InteractionsFolderSubjects.SubjectOf
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|WHERE
	|	InteractionsFolderSubjects.Reviewed <> &FlagValue
	|	AND InteractionsFolderSubjects.Interaction IN(&InteractionsArray)";
	
	Query.SetParameter("InteractionsArray", InteractionsArray);
	Query.SetParameter("FlagValue", FlagValue);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		StructureForWrite = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
		StructureForWrite.Reviewed             = FlagValue;
		StructureForWrite.CalculateReviewedItems = False;

		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Selection.Interaction, StructureForWrite);
		HasChanges = True;
		
	EndDo;
	
	Selection.Reset();
	CalculateReviewedByFolders(TableOfDataForReviewedCalculation(Selection, "Folder"));
	
	Selection.Reset();
	CalculateReviewedBySubjects(TableOfDataForReviewedCalculation(Selection, "SubjectOf"));
	
	Selection.Reset();
	CalculateReviewedByContacts(Selection);

EndProcedure

// Checks an array of interactions and keeps only those ones whose review date must be changed.
//
// Parameters:
//  InteractionsArray  - Array - an array of interactions whose review date is proposed to be changed.
//  ReviewDate  - Date - a new review date.
//
// Returns:
//   Array - Array of interactions whose review date needs to be changed.
//
Function InteractionsArrayForReviewDateChange(InteractionsArray, ReviewDate) Export

	If InteractionsArray.Count() > 0 Then
		Query = New Query;
		Query.Text = "
		|SELECT
		|	InteractionsFolderSubjects.Interaction AS Interaction
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	NOT InteractionsFolderSubjects.Reviewed
		|	AND InteractionsFolderSubjects.ReviewAfter <> &ReviewDate
		|	AND InteractionsFolderSubjects.Interaction IN(&InteractionsArray)";
		
		Query.SetParameter("ReviewDate", ReviewDate);
		Query.SetParameter("InteractionsArray", InteractionsArray);
		
		Return Query.Execute().Unload().UnloadColumn("Interaction");
	Else
		
		Return InteractionsArray;
		
	EndIf;

EndFunction

///////////////////////////////////////////////////////////////////////////////////
//  Miscellaneous.

// Parameters:
//  FormInputField  - FormField - the form item the choice list belongs to.
//  Interval        - Number - an interval in seconds, with which the list is to be filled, is an hour by default.
//
Procedure FillTimeSelectionList(FormInputField, Interval = 3600) Export

	WorkdayBeginning      = '00010101000000';
	WorkdayEnd   = '00010101235959';

	TimesList = FormInputField.ChoiceList;
	TimesList.Clear();

	ListTime = WorkdayBeginning;
	While BegOfHour(ListTime) <= BegOfHour(WorkdayEnd) Do
		If Not ValueIsFilled(ListTime) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(ListTime, NStr("en = 'DF=HH:mm';"));
		EndIf;

		TimesList.Add(ListTime, TimePresentation);

		ListTime = ListTime + Interval;
	EndDo;

EndProcedure

// Generates a query text of dynamic interaction list depending on navigation panel kind
// and passed parameter type.
//
// Parameters:
//  FilterValue  - CatalogRef
//                  - DocumentRef - Filter value in the navigation panel.
//
// Returns:
//   String   - Query text in a dynamic list.
//
Function InteractionsListQueryText(FilterValue = Undefined) Export
	
	QueryText ="
	|SELECT
	|	CASE
	|		WHEN InteractionDocumentsLog.Ref REFS Document.Meeting
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 10
	|					ELSE 0
	|				END
	|		WHEN InteractionDocumentsLog.Ref REFS Document.PlannedInteraction
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 11
	|					ELSE 1
	|				END
	|		WHEN InteractionDocumentsLog.Ref REFS Document.PhoneCall
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 12
	|					ELSE 2
	|				END
	|		WHEN InteractionDocumentsLog.Ref REFS Document.IncomingEmail
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 13
	|					ELSE 3
	|				END
	|		WHEN InteractionDocumentsLog.Ref REFS Document.OutgoingEmail
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 14
	|					ELSE CASE
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Draft)
	|								THEN 15
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
	|								THEN 16
	|							ELSE 4
	|						END
	|				END
	|		WHEN InteractionDocumentsLog.Ref REFS Document.SMSMessage
	|			THEN CASE
	|					WHEN InteractionDocumentsLog.DeletionMark
	|						THEN 22
	|					ELSE CASE
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.Draft)
	|								THEN 17
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.Outgoing)
	|								THEN 18
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.DeliveryInProgress)
	|								THEN 19
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.PartiallyDelivered)
	|								THEN 21
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.NotDelivered)
	|								THEN 23
	|							WHEN InteractionDocumentsLog.OutgoingEmailStatus = VALUE(Enum.SMSDocumentStatuses.Delivered)
	|								THEN 24
	|							ELSE 17
	|						END
	|				END
	|	END AS PictureNumber,
	|	InteractionDocumentsLog.Ref,
	|	InteractionDocumentsLog.Date,
	|	InteractionDocumentsLog.DeletionMark AS DeletionMark,
	|	InteractionDocumentsLog.Number,
	|	InteractionDocumentsLog.Posted,
	|	InteractionDocumentsLog.Author,
	|	InteractionDocumentsLog.InteractionBasis,
	|	InteractionDocumentsLog.Incoming,
	|	InteractionDocumentsLog.Subject,
	|	InteractionDocumentsLog.EmployeeResponsible AS EmployeeResponsible,
	|	ISNULL(InteractionsSubjects.Reviewed, FALSE) AS Reviewed,
	|	ISNULL(InteractionsSubjects.ReviewAfter, DATETIME(1, 1, 1)) AS ReviewAfter,
	|	InteractionDocumentsLog.Attendees,
	|	InteractionDocumentsLog.Type,
	|	InteractionDocumentsLog.Account,
	|	CASE
	|		WHEN ISNULL(InteractionDocumentsLog.HasAttachments, FilesExist.HasFiles) IS NULL
	|			THEN FALSE
	|		WHEN ISNULL(InteractionDocumentsLog.HasAttachments, FilesExist.HasFiles)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS HasAttachments,
	|	InteractionDocumentsLog.Importance,
	|	CASE
	|		WHEN InteractionDocumentsLog.Importance = VALUE(Enum.InteractionImportanceOptions.High)
	|			THEN 2
	|		WHEN InteractionDocumentsLog.Importance = VALUE(Enum.InteractionImportanceOptions.Low)
	|			THEN 0
	|		ELSE 1
	|	END AS ImportancePictureNumber,
	|	&SubjectAttribute AS SubjectOf,
	|	VALUETYPE(InteractionsSubjects.SubjectOf) AS SubjectType,
	|	ISNULL(InteractionsSubjects.EmailMessageFolder, VALUE(Catalog.EmailMessageFolders.EmptyRef)) AS Folder,
	|	CASE
	|		WHEN InteractionDocumentsLog.Ref REFS Document.IncomingEmail
	|			THEN InteractionDocumentsLog.Date
	|		ELSE InteractionDocumentsLog.SentReceived
	|	END AS SentReceived,
	|	InteractionDocumentsLog.Size,
	|	InteractionDocumentsLog.OutgoingEmailStatus
	|FROM
	|	DocumentJournal.Interactions AS InteractionDocumentsLog
	|		INNER JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
	|		ON InteractionDocumentsLog.Ref = InteractionsSubjects.Interaction
	|		AND &ConnectionTextContactsTable
	|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
	|		ON InteractionDocumentsLog.Ref = FilesExist.ObjectWithFiles
	|{WHERE
	|	InteractionDocumentsLog.Ref AS Search
	|	,&FilterContact}";
	
	If FilterValue = Undefined Then
		TextSubject                    = "ISNULL(InteractionsSubjects.SubjectOf, UNDEFINED)";
		TextFilterContact               = "";
		TextJoinContactsTable = "";
	ElsIf InteractionsClientServer.IsSubject(FilterValue) Or InteractionsClientServer.IsInteraction(FilterValue) Then
		TextSubject                    = "ISNULL(CAST(InteractionsSubjects.SubjectOf AS " + FilterValue.Metadata().FullName() + "), UNDEFINED)";
		TextFilterContact               = "";
		TextJoinContactsTable = "";
	Else
		TextSubject                    = "ISNULL(InteractionsSubjects.SubjectOf, UNDEFINED)";
		TextFilterContact               = ",
		                                   |InteractionsContacts.Contact";
		TextJoinContactsTable = "{INNER JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
		                                   |ON InteractionDocumentsLog.Ref = InteractionsContacts.Interaction}";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&SubjectAttribute", TextSubject);
	QueryText = StrReplace(QueryText, ",&FilterContact", TextFilterContact);
	QueryText = StrReplace(QueryText, "AND &ConnectionTextContactsTable", TextJoinContactsTable);

	Return QueryText; 

EndFunction

// Fills data of the InteractionsContacts information register for the passed interaction array.
//
// Parameters:
//  DocumentObject - DocumentObject.OutgoingEmail
//                 - DocumentObject.IncomingEmail
//                 - DocumentObject.SMSMessage
//                 - DocumentObject.PhoneCall
//                 - DocumentObject.PlannedInteraction
//                 - DocumentObject.Meeting - a document to be recorded.
//
Procedure OnWriteDocument(DocumentObject) Export

	SetPrivilegedMode(True);
	
	If DoNotSaveContacts(DocumentObject.AdditionalProperties) Then
		Return;
	EndIf;
	
	DataLock = New DataLock;
	DataLockItem = DataLock.Add("InformationRegister.InteractionsContacts");
	DataLockItem.SetValue("Interaction", DocumentObject.Ref);
	DataLock.Lock();
	
	RecordSet = InformationRegisters.InteractionsContacts.CreateRecordSet();
	RecordSet.Filter.Interaction.Set(DocumentObject.Ref);
	
	Table = New ValueTable;
	ContactsTypesDetails = New TypeDescription(ContactsTypes());
	Table.Columns.Add("Contact", ContactsTypesDetails);
	Table.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(100, AllowedLength.Variable)));

	If TypeOf(DocumentObject) = Type("DocumentObject.Meeting") Then
		
		For Each Member In DocumentObject.Attendees Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Member.Contact;
			NewRow.Presentation  = Member.ContactPresentation;
			
		EndDo;
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.PlannedInteraction") Then
		
		For Each Member In DocumentObject.Attendees Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Member.Contact;
			NewRow.Presentation  = Member.ContactPresentation;
			
		EndDo;
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.PhoneCall") Then
		
		NewRow = Table.Add();
		NewRow.Contact        = DocumentObject.SubscriberContact;
		NewRow.Presentation  = DocumentObject.SubscriberPresentation;
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.SMSMessage") Then
		
		For Each Subscriber In DocumentObject.SMSMessageRecipients Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Subscriber.Contact;
			NewRow.Presentation  = Subscriber.ContactPresentation;
			
		EndDo;
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.IncomingEmail") Then
		
		NewRow = Table.Add();
		NewRow.Contact        = DocumentObject.SenderContact;
		NewRow.Presentation  = DocumentObject.SenderPresentation;
		
	ElsIf TypeOf(DocumentObject) = Type("DocumentObject.OutgoingEmail") Then
		
		For Each Addressee In DocumentObject.EmailRecipients Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Addressee.Contact;
			NewRow.Presentation  = Addressee.Presentation;
			
		EndDo;
		
		For Each Addressee In DocumentObject.CCRecipients Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Addressee.Contact;
			NewRow.Presentation  = Addressee.Presentation;
			
		EndDo;
		
		For Each Addressee In DocumentObject.BccRecipients Do
			
			NewRow = Table.Add();
			NewRow.Contact        = Addressee.Contact;
			NewRow.Presentation  = Addressee.Presentation;
			
		EndDo;
		
	EndIf;
	
	For Each TableRow In Table Do
		If Not ValueIsFilled(TableRow.Contact) Then
			TableRow.Contact = Catalogs.Users.EmptyRef();
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	TableOfContacts.Contact,
	|	TableOfContacts.Presentation
	|INTO TableOfContacts
	|FROM
	|	&TableOfContacts AS TableOfContacts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	CASE
	|		WHEN TableOfContacts.Contact = VALUE(Catalog.Users.EmptyRef)
	|			THEN ISNULL(StringContactInteractions.Ref, UNDEFINED)
	|		ELSE TableOfContacts.Contact
	|	END AS Contact,
	|	TableOfContacts.Presentation
	|FROM
	|	TableOfContacts AS TableOfContacts
	|		LEFT JOIN Catalog.StringContactInteractions AS StringContactInteractions
	|		ON TableOfContacts.Presentation = StringContactInteractions.Description
	|			AND (NOT StringContactInteractions.DeletionMark)";
	
	Query.SetParameter("TableOfContacts", Table);
	
	Table = Query.Execute().Unload();
	
	For Each TableRow In Table Do
		If TableRow.Contact = Undefined Then
			StringInteractionsContact              = Catalogs.StringContactInteractions.CreateItem();
			StringInteractionsContact.Description = TableRow.Presentation;
			StringInteractionsContact.Write();
			TableRow.Contact                        = StringInteractionsContact.Ref;
		EndIf;
	EndDo;
	
	Table.GroupBy("Contact");
	
	Table.Columns.Add("Interaction");
	Table.FillValues(DocumentObject.Ref, "Interaction");
	RecordSet.AdditionalProperties.Insert("CalculateReviewedItems", True);
	RecordSet.Load(Table);
	
	RecordSet.Write();
	
EndProcedure

// Fills data of the InteractionsContacts information register for the passed interaction array.
//
// Parameters:
//  InteractionsArray    - Array - an array, for which the contact data will be filled.
//  CalculateReviewedItems - Boolean - indicates whether it is necessary to calculate interaction contact states.
//
Procedure FillInteractionsArrayContacts(InteractionsArray, CalculateReviewedItems = False) Export

	SetPrivilegedMode(True);
	
	// ACC:96-off - The JOIN keyword (as the same contact might participate in multiple interactions).
	Query = New Query;
	Query.Text = "
	|SELECT DISTINCT
	|	MeetingParticipants.Ref                AS Interaction,
	|	MeetingParticipants.Contact               AS Contact,
	|	MeetingParticipants.ContactPresentation AS ContactPresentation
	|INTO InformationAboutContacts
	|FROM
	|	Document.Meeting.Attendees AS MeetingParticipants
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON MeetingParticipants.Ref = InteractionsContacts.Interaction
	|WHERE
	|	MeetingParticipants.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	PlannedInteractionParticipants.Ref,
	|	PlannedInteractionParticipants.Contact,
	|	PlannedInteractionParticipants.ContactPresentation
	|FROM
	|	Document.PlannedInteraction.Attendees AS PlannedInteractionParticipants
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON PlannedInteractionParticipants.Ref = InteractionsContacts.Interaction
	|WHERE
	|	PlannedInteractionParticipants.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	PhoneCall.Ref,
	|	PhoneCall.SubscriberContact,
	|	PhoneCall.SubscriberPresentation
	|FROM
	|	Document.PhoneCall AS PhoneCall
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON (InteractionsContacts.Interaction = PhoneCall.Ref)
	|WHERE
	|	PhoneCall.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	MessageSMSAddressees.Ref,
	|	MessageSMSAddressees.Contact,
	|	MessageSMSAddressees.ContactPresentation
	|FROM
	|	Document.SMSMessage.SMSMessageRecipients AS MessageSMSAddressees
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON MessageSMSAddressees.Ref = InteractionsContacts.Interaction
	|WHERE
	|	MessageSMSAddressees.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	IncomingEmail.Ref,
	|	IncomingEmail.SenderContact,
	|	IncomingEmail.SenderPresentation
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON (InteractionsContacts.Interaction = IncomingEmail.Ref)
	|WHERE
	|	IncomingEmail.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	EmailOutgoingEmailRecipients.Ref,
	|	EmailOutgoingEmailRecipients.Contact,
	|	EmailOutgoingEmailRecipients.Presentation
	|FROM
	|	Document.OutgoingEmail.EmailRecipients AS EmailOutgoingEmailRecipients,
	|	InformationRegister.InteractionsContacts AS InteractionsContacts
	|WHERE
	|	EmailOutgoingEmailRecipients.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	EMailOutgoingCopyRecipients.Ref,
	|	EMailOutgoingCopyRecipients.Contact,
	|	EMailOutgoingCopyRecipients.Presentation
	|FROM
	|	Document.OutgoingEmail.CCRecipients AS EMailOutgoingCopyRecipients
	|WHERE
	|	EMailOutgoingCopyRecipients.Ref IN
	|			(&InteractionsArray)
	|
	|UNION
	|
	|SELECT DISTINCT
	|	EmailOutgoingRecipientsOfHiddenCopies.Ref,
	|	EmailOutgoingRecipientsOfHiddenCopies.Contact,
	|	EmailOutgoingRecipientsOfHiddenCopies.Presentation
	|FROM
	|	Document.OutgoingEmail.BccRecipients AS EmailOutgoingRecipientsOfHiddenCopies
	|		LEFT JOIN InformationRegister.InteractionsContacts AS InteractionsContacts
	|		ON EmailOutgoingRecipientsOfHiddenCopies.Ref = InteractionsContacts.Interaction
	|WHERE
	|	EmailOutgoingRecipientsOfHiddenCopies.Ref IN
	|			(&InteractionsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT DISTINCT
	|	InformationAboutContacts.Interaction AS Interaction,
	|	InformationAboutContacts.Contact        AS Contact
	|INTO UniqueInteractionContacts
	|FROM
	|	InformationAboutContacts AS InformationAboutContacts
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT 
	|	UniqueInteractionContacts.Interaction                      AS Interaction,
	|	UniqueInteractionContacts.Contact                             AS Contact,
	|	MAX(ISNULL(InformationAboutContacts.ContactPresentation, """")) AS ContactPresentation
	|INTO UniqueContactsOfInteractionOfRepresentation
	|FROM
	|	UniqueInteractionContacts AS UniqueInteractionContacts
	|	LEFT JOIN InformationAboutContacts AS InformationAboutContacts
	|		ON UniqueInteractionContacts.Interaction = InformationAboutContacts.Interaction
	|		AND UniqueInteractionContacts.Contact = InformationAboutContacts.Contact
	|GROUP BY
	|	UniqueInteractionContacts.Interaction,
	|	UniqueInteractionContacts.Contact
	|
	|INDEX BY
	|	ContactPresentation
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	UniqueContactsOfInteractionOfRepresentation.Interaction AS Interaction,
	|	CASE
	|		WHEN UniqueContactsOfInteractionOfRepresentation.Contact = UNDEFINED
	|			THEN ISNULL(StringContactInteractions.Ref, UNDEFINED)
	|		ELSE UniqueContactsOfInteractionOfRepresentation.Contact
	|	END AS Contact,
	|	UniqueContactsOfInteractionOfRepresentation.ContactPresentation
	|FROM
	|	UniqueContactsOfInteractionOfRepresentation AS UniqueContactsOfInteractionOfRepresentation
	|		LEFT JOIN Catalog.StringContactInteractions AS StringContactInteractions
	|		ON UniqueContactsOfInteractionOfRepresentation.ContactPresentation = StringContactInteractions.Description
	|TOTALS BY
	|	Interaction";
	// ACC:96-on
	Query.SetParameter("InteractionsArray", InteractionsArray);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionInteraction = QueryResult.Select(QueryResultIteration.ByGroups);
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.InteractionsContacts");
		LockAreasTable = New ValueTable;
		LockAreasTable.Columns.Add("Interaction");
		For Each ArrayElement In InteractionsArray Do
			NewRow = LockAreasTable.Add();
			NewRow.Interaction = ArrayElement;
		EndDo;
		LockItem.DataSource = LockAreasTable;
		Block.Lock();
		
		While SelectionInteraction.Next() Do
			DetailsSelection = SelectionInteraction.Select();
			
			RecordSet = InformationRegisters.InteractionsContacts.CreateRecordSet();
			RecordSet.Filter.Interaction.Set(SelectionInteraction.Interaction);
			
			While DetailsSelection.Next() Do
				
				NewRecord = RecordSet.Add();
				NewRecord.Interaction = SelectionInteraction.Interaction;
				If DetailsSelection.Contact <> Undefined Then
					NewRecord.Contact = DetailsSelection.Contact;
				Else
					StringInteractionsContact              = Catalogs.StringContactInteractions.CreateItem();
					StringInteractionsContact.Description = DetailsSelection.ContactPresentation;
					StringInteractionsContact.Write();
					NewRecord.Contact                         = StringInteractionsContact.Ref;
				EndIf;
				
			EndDo;
			
			If CalculateReviewedItems Then
				RecordSet.AdditionalProperties.Insert("CalculateReviewedItems", True);
			EndIf;
			
			RecordSet.Write();
			
		EndDo;
		
		CommitTransaction();
	
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Fills in the quick filter submenu by interaction category.
// 
// Parameters:
//  SubmenuGroup - FormGroup - added items will be placed in this group.
//  Form - ClientApplicationForm - a form, for which items are added.
//
Procedure FillStatusSubmenu(SubmenuGroup, Form) Export
	
	If Not GetFunctionalOption("UseReviewedFlag") Then
		Return;
	EndIf;
	
	For Each Status In StatusesList() Do
		
		Value = Status.Value;
		
		NewCommand = Form.Commands.Add("SetTheSelectionStatus" + "_" +  Value);
		NewCommand.Action = "Attachable_ChangeFilterStatus";
		
		ItemButtonSubmenu = Form.Items.Add("SetTheSelectionStatus" + "_" + Value, Type("FormButton"), 
			SubmenuGroup);
		ItemButtonSubmenu.Type                   = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName            = NewCommand.Name;
		ItemButtonSubmenu.Title             = Status.Presentation;
	
	EndDo;
	
EndProcedure

// Fills in the quick filter submenu by interaction category.
// 
// Parameters:
//  SubmenuGroup - FormGroup - added items will be placed in this group.
//  Form - ClientApplicationForm - a form, for which items are added.
//
Procedure FillSubmenuByInteractionType(SubmenuGroup, Form) Export
	
	FiltersList = FiltersListByInteractionsType(Form.OnlyEmail);
	For Each Filter In FiltersList Do
		
		Value = Filter.Value;
		
		CommandName = "SetTheSelectedInteractionType" + "_" +  Value;
		FoundCommand = Form.Commands.Find(CommandName);
		
		If FoundCommand = Undefined Then
			NewCommand = Form.Commands.Add("SetTheSelectedInteractionType" + "_" + Value);
			NewCommand.Action = "Attachable_ChangeFilterInteractionType";
		Else
			NewCommand = FoundCommand;
		EndIf;
		
		ItemButtonSubmenu = Form.Items.Add("SetTheSelectedInteractionType" + "_" + SubmenuGroup.Name + "_"+ Value, Type("FormButton"), SubmenuGroup);
		ItemButtonSubmenu.Type = FormButtonType.CommandBarButton;
		ItemButtonSubmenu.CommandName = NewCommand.Name;
		ItemButtonSubmenu.Title = Filter.Presentation;
		
	EndDo;
	
EndProcedure

// Manages the display of marks in the quick filter submenu.
// 
// Parameters:
//  Form - ClientApplicationForm - the form for which marks are set in the submenu.
//
Procedure ProcessFilterByInteractionsTypeSubmenu(Form) Export

	TitleTemplate1 = NStr("en = 'Show %1';");
	TypePresentation = FiltersListByInteractionsType(Form.OnlyEmail).FindByValue(Form.InteractionType).Presentation;
	Form.Items.InteractionTypeList.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, TypePresentation);
	For Each SubmenuItem In Form.Items.InteractionTypeList.ChildItems Do
		If SubmenuItem.Name = ("SetFilterInteractionTypeListInteractionType" + Form.InteractionType) Then
			SubmenuItem.Check = True;
		Else
			SubmenuItem.Check = False;
		EndIf;
	EndDo	

EndProcedure

Function NewEmailsByAccounts()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(Interactions.Ref) AS EmailsCount,
	|	Interactions.Account AS Account
	|FROM
	|	DocumentJournal.Interactions AS Interactions
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
	|		ON Interactions.Ref = InteractionsSubjects.Interaction
	|		LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON Interactions.Account = EmailAccounts.Ref
	|WHERE
	|	VALUETYPE(Interactions.Ref) = TYPE(Document.IncomingEmail)
	|	AND InteractionsSubjects.Reviewed = FALSE
	|	AND NOT EmailAccounts.Ref IS NULL
	|
	|GROUP BY
	|	Interactions.Account";
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

Function ListOfAvailableSubjectsTypes() Export
	
	SubjectTypeChoiceList = New ValueList;

	For Each SubjectType In Metadata.DefinedTypes.InteractionSubject.Type.Types() Do
		
		SubjectTypeMetadata = Metadata.FindByType(SubjectType);
		If SubjectTypeMetadata = Undefined Then
			Continue;
		EndIf;
		
		If Not Common.MetadataObjectAvailableByFunctionalOptions(SubjectTypeMetadata) Then
			Continue;
		EndIf;
		
		IsInteraction = InteractionsClientServer.IsInteraction(SubjectType);
		SubjectTypeChoiceList.Add(Metadata.FindByType(SubjectType).FullName(), String(SubjectType), IsInteraction);
		
	EndDo;
	
	Return SubjectTypeChoiceList;

EndFunction

Function SignatureFilesExtension()
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		Return ModuleDigitalSignature.PersonalSettings().SignatureFilesExtension;
	Else
		Return "p7s";
	EndIf;
	
EndFunction

Function EncryptedFilesExtension()
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		Return ModuleDigitalSignature.PersonalSettings().EncryptedFilesExtension;
	Else
		Return "p7m";
	EndIf;
	
EndFunction

Procedure ReplaceEmployeeResponsibleInDocument(Interaction, EmployeeResponsible) Export
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		LockItem = Block.Add(Metadata.FindByType(TypeOf(Interaction)).FullName());
		LockItem.SetValue("Ref", Interaction);
		Block.Lock();
		
		Object = Interaction.GetObject();
		Object.EmployeeResponsible = EmployeeResponsible;
		Object.AdditionalProperties.Insert("DoNotSaveContacts", True);
		Object.Write();
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Parameters:
//  CatalogName    - String - a name of the catalog to be checked.
//  TabularSectionName - String - a name of the tabular section whose existence is being checked.
//
// Returns:
//  Boolean - True if the catalog has a table.
//
// Example:
//  If Not CatalogHasTabularSection(CatalogName,"ContactInformation") Then
//  	Return;
//  EndIf;
//
Function CatalogHasTabularSection(CatalogName, TabularSectionName)
	
	Return (Metadata.Catalogs[CatalogName].TabularSections.Find(TabularSectionName) <> Undefined);
	
EndFunction 

///////////////////////////////////////////////////////////////////////////////////
//  Message templates.

// Parameters:
//  Folder — CatalogRef.EmailMessageFolders — the folder makes sense for the "Incoming mail"
//                                                         and "Outgoing mail" documents.
//  SubjectOf          - CatalogRef, DocumentRef - indicates an interaction subject.
//  Reviewed      - Boolean - indicates that interaction is reviewed.
//  ReviewAfter - Date - a date, until which the interaction is deferred.
//  CalculateReviewedItems - Boolean - indicates that it is necessary to calculate states of a folder and a subject.
//
// Returns:
//   See InformationRegisters.InteractionsFolderSubjects.InteractionAttributes
//
Function InteractionAttributesStructureForWrite(SubjectOf, Reviewed)
	
	ReturnStructure = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	If SubjectOf <> Undefined Then
		ReturnStructure.SubjectOf = SubjectOf;
	EndIf;
	If Reviewed <> Undefined Then
		ReturnStructure.Reviewed = Reviewed;
	EndIf;
	ReturnStructure.CalculateReviewedItems = True;
	
	Return ReturnStructure;
	
EndFunction

// Returns:
//  Structure:
//   * Sent - Boolean - indicates whether the email message is sent.
//   * ErrorDescription - String - contains the error details when cannot send an email message.
//   * LinkToTheEmail - Undefined - email message was not created.
//                    - DocumentRef.OutgoingEmail - Reference to the created outgoing email.
//   * EmailID - String
//   * WrongRecipients - Map of KeyAndValue - Recipient's email addresses with errors.:
//     ** Key     - String - a recipient address.
//     ** Value - String - Error text.
//
Function EmailSendingResult()
	
	EmailSendingResult = New Structure;
	
	EmailSendingResult.Insert("Sent", False);
	EmailSendingResult.Insert("ErrorDescription", "");
	EmailSendingResult.Insert("LinkToTheEmail", Undefined);
	EmailSendingResult.Insert("EmailID", "");
	EmailSendingResult.Insert("WrongRecipients", New Map);
	
	
	Return EmailSendingResult;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Define the reference type.

// Parameters:
//  ObjectRef  - AnyRef - a reference, to which a check is being executed.
//
// Returns:
//   Boolean  - True if it is a contact. Otherwise, False.
//
Function IsContact(ObjectRef)
	
	PossibleContactsTypesDetails =  New TypeDescription(ContactsTypes());
	Return PossibleContactsTypesDetails.ContainsType(TypeOf(ObjectRef));
	
EndFunction

// Returns:
//   Array of Type
//
Function ContactsTypes() 
	
	ContactsDetails = InteractionsClientServer.ContactsDetails();
	Result = New Array;
	For Each ContactDescription In ContactsDetails Do
		Result.Add(ContactDescription.Type);
	EndDo;
	
	Return Result;
	
EndFunction

Function FiltersListByInteractionsType(OnlyEmail) Export
	
	FiltersList = New ValueList;
	
	FiltersList.Add("All", NStr("en = 'All';"));
	FiltersList.Add("AllEmails", NStr("en = 'All mail';"));
	If Not OnlyEmail Then
		FiltersList.Add("Meetings", NStr("en = 'Appointments';"));
		FiltersList.Add("PhoneCalls", NStr("en = 'Phone calls';"));
		FiltersList.Add("PlannedInteractions", NStr("en = 'Scheduled interactions';"));
		FiltersList.Add("SMSMessages", NStr("en = 'Text messages';"));
	EndIf;
	FiltersList.Add("IncomingMessages", NStr("en = 'Inbox';"));
	FiltersList.Add("MessageDrafts", NStr("en = 'Drafts';"));
	FiltersList.Add("OutgoingMessages", NStr("en = 'Outbox';"));
	FiltersList.Add("SentMessages", NStr("en = 'Sent';"));
	FiltersList.Add("DeletedMessages", NStr("en = 'Trash';"));
	If Not OnlyEmail Then
		FiltersList.Add("OutgoingCalls", NStr("en = 'Outgoing calls';"));
		FiltersList.Add("IncomingCalls", NStr("en = 'Incoming calls';"));
	EndIf;
	
	Return FiltersList;
	
EndFunction

Function InteractionTypeByCommandName(CommandName, OnlyEmail) Export
	
	FoundPosition = StrFind(CommandName, "_");
	If FoundPosition = 0 Then
		Return "All";
	EndIf;
	
	InteractionTypeString = Right(CommandName, StrLen(CommandName) - FoundPosition);
	If FiltersListByInteractionsType(OnlyEmail).FindByValue(InteractionTypeString) = Undefined Then
		Return "All";
	EndIf;
	
	Return InteractionTypeString;
	
EndFunction

Function HTMLDocumentGenerationParametersOnEmailBasis(FillingData = Undefined) Export
	
	Result = New Structure;
	Result.Insert("MailMessage");
	Result.Insert("TextType");
	Result.Insert("Text");
	Result.Insert("HTMLText");
	Result.Insert("TextTypeConversion");
	Result.Insert("Encoding", "");
	Result.Insert("ProcessPictures", False);
	Result.Insert("DisableExternalResources", True);
	
	If ValueIsFilled(FillingData) Then
		FillPropertyValues(Result, FillingData);
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//  PhoneNumber - String - a string with a phone number.
//
// Returns:
//   Boolean   - True if the entered phone number is valid. Otherwise, False.
//
Function PhoneNumberSpecifiedCorrectly(PhoneNumber) Export
	
	PhoneNumberChars = "+1234567890";
	SeparatorsChars = "()- ";
	
	FormattedNumber = "";
	For Position = 1 To StrLen(PhoneNumber) Do
		Char = Mid(PhoneNumber, Position, 1);
		If Char = "+" And Not IsBlankString(FormattedNumber) Then
			Return False;
		EndIf;
		If StrFind(PhoneNumberChars, Char) > 0 Then
			FormattedNumber = FormattedNumber + Char;
		ElsIf StrFind(SeparatorsChars, Char) = 0 Then
			Return False;
		EndIf;
	EndDo;
	
	If IsBlankString(FormattedNumber) Then
		Return False;
	EndIf;
	
	If StrLen(FormattedNumber) < 3 Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Generates a subject by a message text based on the first three words.
//
// Parameters:
//  MessageText  - String - a message text, on whose basis a subject is generated.
//
// Returns:
//   String   - Generated message subject.
//
Function SubjectByMessageText(Val MessageText) Export
	
	MessageText = StrReplace(MessageText, Chars.LF, " ");
	RowsArray = StrSplit(MessageText," ", False);
	Subject = "";
	For Indus = 0 To RowsArray.Count() - 1 Do
		If Indus > 2 Then
			Break;
		EndIf;
		Subject = Subject + RowsArray[Indus] + " ";
	EndDo;
	
	Return Left(Subject, StrLen(Subject) - 1);

EndFunction

Function StatusesList() Export
	
	StatusesList = New ValueList;
	StatusesList.Add("All", NStr("en = 'All';"));
	StatusesList.Add("ToReview", NStr("en = 'Pending review';"));
	StatusesList.Add("Deferred3", NStr("en = 'Deferred';"));
	StatusesList.Add("ReviewedItems", NStr("en = 'Reviewed';"));
	
	Return StatusesList;
	
EndFunction

// Receives chain interactions by an interaction subject.
//
// Parameters:
//  Chain	  - AnyRef - an interaction subject to get interactions for.
//  Exclude - AnyRef - an interaction that should not be included in the resulting array.
//
// Returns:
//  Array - Found interactions.
//
Function InteractionsFromChain(Chain, Exclude)
	
	Query = New Query;
	Query.Text = "SELECT
	|	InteractionsSubjects.Interaction AS Ref
	|FROM
	|	InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
	|WHERE
	|	InteractionsSubjects.SubjectOf = &SubjectOf
	|	AND &ConditionToExclude";
	
	Query.Text = StrReplace(Query.Text, "AND &ConditionToExclude", ?(Exclude = Undefined,"","  AND InteractionsSubjects.Interaction <> &Exclude"));
	
	Query.SetParameter("SubjectOf", Chain);
	Query.SetParameter("Exclude", Exclude);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

Function SignaturePagesPIcture(ShowPicture) Export

	Return ?(ShowPicture, PictureLib.ReviewedItemCount, New Picture);

EndFunction 

Function EmailPresentation(EmailSubject, EmailDate) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1, %2';"), 
		InteractionsClientServer.InteractionSubject1(EmailSubject), Format(EmailDate, "DLF=D"));
	
EndFunction

Procedure FilterHTMLTextContent(HTMLText, Encoding = Undefined,
	DisableExternalResources = True, HasExternalResources = Undefined) Export
	
	HTMLDocument = GetHTMLDocumentObjectFromHTMLText(HTMLText, Encoding);
	HasExternalResources = EmailOperations.HasExternalResources(HTMLDocument);
	EmailOperations.DisableUnsafeContent(HTMLDocument, HasExternalResources And DisableExternalResources);
	HTMLText = GetHTMLTextFromHTMLDocumentObject(HTMLDocument);
	
EndProcedure

Function UnsafeContentDisplayInEmailsProhibited() Export
	Return Constants.DenyDisplayingUnsafeContentInEmails.Get();
EndFunction

// Parameters:
//  Phone - String
//  FoundContacts - ValueTable
//
// Returns:
//  Boolean - True if at least one contact is found.
//
Function FindContactsByPhone(Val Phone, FoundContacts) Export
	
	QueryText =
	"SELECT DISTINCT ALLOWED
	|	ContactInformationTable1.Ref AS Contact,
	|	SUBSTRING(ContactInformationTable1.Presentation, 1, 1000)AS Presentation,
	|	ContactInformationTable1.Ref.Description AS Description,
	|	"""" AS OwnerDescription1
	|FROM
	|	Catalog.Users.ContactInformation AS ContactInformationTable1
	|WHERE
	|	SUBSTRING(ContactInformationTable1.Presentation, 1, 100) = &Phone
	|	AND (ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Phone)
	|			OR ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Fax))
	|  AND (NOT ContactInformationTable1.Ref.DeletionMark)
	|";	
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
			
		QueryText = 
		"SELECT DISTINCT
		|	ContactInformationTable1.Ref,
		|	SUBSTRING(ContactInformationTable1.Presentation, 1, 1000),
		|	&NameOfTheItemName AS Description,
		|	&NameOfTheAccountDetailsOwnerSName
		|FROM
		|	&CatalogTable AS ContactInformationTable1
		|WHERE
		|	SUBSTRING(ContactInformationTable1.Presentation, 1, 100) = &Phone
		|	AND (ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			OR ContactInformationTable1.Type = VALUE(Enum.ContactInformationTypes.Fax))
		|  AND (NOT ContactInformationTable1.Ref.DeletionMark)
		|  AND &HierarchicalCondition";
		
		QueryText = StrReplace(QueryText, "&NameOfTheAccountDetailsOwnerSName", 
			?(ContactDescription.HasOwner," ContactInformationTable1.Ref.Owner.Description", """"""));
		QueryText = StrReplace(QueryText, "&NameOfTheItemName", 
			"ContactInformationTable1.Ref." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&CatalogTable", 
			"Catalog." + ContactDescription.Name + ".ContactInformation");
		QueryText = StrReplace(QueryText, "AND &HierarchicalCondition", 
			?(ContactDescription.Hierarchical, " AND (NOT ContactInformationTable1.Ref.IsFolder)", ""));
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|ORDER BY
		|	Description"; // @query-part
	
	Query = New Query(QueryText);
	Query.SetParameter("Phone", Phone);
	TableOfContacts = Query.Execute().Unload();
	If TableOfContacts = Undefined Or TableOfContacts.Count() = 0 Then
		Return False;
	EndIf;
	
	FillFoundContacts(TableOfContacts, FoundContacts);
	Return True;
	
EndFunction

// Parameters:
//  Description - String - Start of the contact description.
//
// Returns:
//  ValueTable
//
Function FindContactsByDescriptionBeginning(Val SearchString) Export
	
	QueryText =
	"SELECT DISTINCT ALLOWED
	|	CatalogContact.Ref       AS Contact,
	|	CatalogContact.Description AS Description,
	|	""""                           AS OwnerDescription1,
	|	""""                           AS Presentation
	|FROM
	|	Catalog.Users AS CatalogContact
	|WHERE
	|	CatalogContact.Description LIKE &Description ESCAPE ""~""
	|	AND (NOT CatalogContact.DeletionMark)
	|";
	QueryTexts = CommonClientServer.ValueInArray(QueryText);
	
	For Each ContactDescription In InteractionsClientServer.ContactsDetails() Do
		
		If ContactDescription.Name = "Users" Then
			Continue;
		EndIf;
			
		QueryText =
		"SELECT DISTINCT
		|	CatalogTable.Ref,
		|	&NameOfTheItemName AS Description,
		|	&NameOfTheAccountDetailsOwnerSName,
		|	""""
		|FROM
		|	&CatalogTable AS CatalogTable
		|WHERE
		|	CatalogTable.Description LIKE &Description ESCAPE ""~""
		|	AND &HierarchicalCondition
		|	AND (NOT CatalogTable.DeletionMark)";
		
		QueryText = StrReplace(QueryText, "&NameOfTheAccountDetailsOwnerSName", 
			?(ContactDescription.HasOwner, " CatalogTable.Owner.Description", """"""));
		QueryText = StrReplace(QueryText, "&NameOfTheItemName", 
			"CatalogTable." + ContactDescription.ContactPresentationAttributeName);
		QueryText = StrReplace(QueryText, "&CatalogTable", "Catalog." + ContactDescription.Name);
		QueryText = StrReplace(QueryText, "AND &HierarchicalCondition", 
			?(ContactDescription.Hierarchical, " AND (NOT CatalogTable.IsFolder)", ""));
		QueryTexts.Add(QueryText);
		
	EndDo;
	
	// @query-part
	QueryText = StrConcat(QueryTexts, Chars.LF + "UNION ALL" + Chars.LF)
		+ "
		|ORDER BY
		|	Description"; // @query-part
	
	Query = New Query(QueryText);
	Query.SetParameter("Description", Common.GenerateSearchQueryString(SearchString) + "%");
	Return Query.Execute().Unload();
	
EndFunction

Function ContactsAutoSelection(Val SearchString) Export
	
	Result = New ValueList;
	FoundContacts = New ValueTable;
	FoundContacts.Columns.Add("Ref",                 Metadata.DefinedTypes.InteractionContact.Type);
	FoundContacts.Columns.Add("Presentation",          New TypeDescription("String"));
	FoundContacts.Columns.Add("CatalogName",         New TypeDescription("String"));
	FoundContacts.Columns.Add("ContactName",   New TypeDescription("String"));
	FoundContacts.Columns.Add("PresentationFilled", New TypeDescription("Boolean"));
	
	SearchResult = FindContacts(SearchString, False, FoundContacts);
	If Not IsBlankString(SearchResult) Then
		Return Result;
	EndIf;
	
	For Each Selection In FoundContacts Do
		SelectionValue = New Structure;
		SelectionValue.Insert("Contact", Selection.Ref);
		SelectionValue.Insert("ContactPresentation", Selection.ContactName);
		Result.Add(SelectionValue, Selection.ContactName + " [" + Selection.Presentation + "]");
	EndDo;
	Return Result;
	
EndFunction

Function SendingPaused() Export
	
	Return Not Common.DataSeparationEnabled() And Not Common.FileInfobase() 
		And (Not ScheduledJobOfReceivingAndSendingEmailsEnabled() Or HasDelayInExecutionOfJobOfReceivingAndSendingEmails());
	
EndFunction

Function SendingPausedWarningText() Export
	
	If Not SendingPaused() Then
		Return "";
	EndIf;
	
	If Not Users.IsFullUser() Then
		Return NStr("en = 'Mail sync is paused. Contact the Administrator.';");
	EndIf;

	If ScheduledJobOfReceivingAndSendingEmailsEnabled() Then
		If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
			Return StringFunctions.FormattedString(NStr(
				"en = 'Scheduled job <b>Mail sync</b> failed to run. <a href = ""%1"">View details</a>.';"), 
				"GoToScheduledJobsSetup");
		Else
			Return StringFunctions.FormattedString(NStr(
				"en = 'Scheduled job <b>Mail sync</b> failed to run.';"));
		EndIf;
	Else
		Return StringFunctions.FormattedString(NStr(
			"en = 'Scheduled job <b>Mail sync</b> is disabled. <a href =  ""%1"">Click to enable</a>.';"),
			 "EnableReceivingAndSendingEmails");
	EndIf;
	
EndFunction

Function ScheduledJobOfReceivingAndSendingEmailsEnabled()
	
	Return ScheduledJobsServer.ScheduledJobParameter(
		Metadata.ScheduledJobs.SendReceiveEmails, "Use", False);
	
EndFunction

Procedure EnableSendingAndReceivingEmails() Export
	
	ScheduledJobsServer.SetScheduledJobParameters(
		Metadata.ScheduledJobs.SendReceiveEmails, New Structure("Use", True));
	
EndProcedure

Function HasDelayInExecutionOfJobOfReceivingAndSendingEmails()
	
	If Common.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	JobsList = ScheduledJobsServer.FindJobs(New Structure("Metadata", 
		Metadata.ScheduledJobs.SendReceiveEmails));
	
	If JobsList.Count() = 0 Then
		Return False;
	EndIf;
	
	ScheduledJob = JobsList[0];
	BackgroundJob = ScheduledJob.LastJob;
	If BackgroundJob = Undefined Then
		Return False;
	EndIf;
	
	Schedule = ScheduledJob.Schedule;
	
	If CurrentDate() - Schedule.RepeatPeriodInDay < BackgroundJob.Begin Then // ACC:143 Do not localize.
		Return False;
	EndIf;
	
	Return Schedule.ExecutionRequired(CurrentDate() - Schedule.RepeatPeriodInDay, // ACC:143 Do not localize.
		BackgroundJob.Begin, BackgroundJob.End);
	
EndFunction

//////////////////////////////////////////////////////////////////////////////////
// Interaction form element and attribute management.

// Parameters:
//  Form - ClientApplicationForm - the form for which a conditional appearance is set.
//
Procedure SetConditionalInteractionAppearance(Form) Export

	Item = Form.ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("ContactPresentation");

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Attendees.Contact");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.FieldSelectionBackColor);

EndProcedure

// Parameters:
//  ChoiceList - ValueList - a list that will be filled in with choice values.
//
Procedure FillChoiceListForReviewAfter(ChoiceList) Export
	
	ChoiceList.Clear();
	ChoiceList.Add(15*60,    NStr("en = 'Snooze for 15 min';"));
	ChoiceList.Add(30*60,    NStr("en = 'Snooze for 30 min';"));
	ChoiceList.Add(60*60,    NStr("en = 'Snooze for 1 hour';"));
	ChoiceList.Add(3*60*60,  NStr("en = 'Snooze for 3 hours';"));
	ChoiceList.Add(24*60*60, NStr("en = 'Snooze for 24 hours';"));
	
EndProcedure

// An event handler when writing for interactions that occur in document forms.
//
// Parameters:
//  CurrentObject - DocumentObject - a document, in which the event occurred.
//  Form         - ClientApplicationForm - a form where a record to be done: 
//   * Object - DocumentObject.PhoneCall
//             - DocumentObject.PlannedInteraction
//             - DocumentObject.SMSMessage
//             - DocumentObject.Meeting
//             - DocumentObject.IncomingEmail
//             - DocumentObject.OutgoingEmail - Reference to the object being written.
//
Procedure OnWriteInteractionFromForm(CurrentObject, Form) Export
	
	If Form.Reviewed Then
		Form.ReviewAfter = Date(1,1,1);
	EndIf;
	
	InteractionHyperlink = CurrentObject.Ref;
	
	Block = New DataLock();
	InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, InteractionHyperlink);
	Block.Lock();
	
	OldAttributesValues = InteractionAttributesStructure(InteractionHyperlink);
	If OldAttributesValues.SubjectOf           = Form.SubjectOf And ValueIsFilled(Form.SubjectOf)
		And OldAttributesValues.Reviewed      = Form.Reviewed
		And OldAttributesValues.ReviewAfter = Form.ReviewAfter Then
		Return;
	EndIf;
	
	CalculateReviewedItems = (OldAttributesValues.Reviewed <> Form.Reviewed)
	                        Or (OldAttributesValues.SubjectOf <> Form.SubjectOf And ValueIsFilled(Form.SubjectOf));
	
	StructureForWrite = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	StructureForWrite.SubjectOf                 = Form.SubjectOf;
	StructureForWrite.Reviewed             = Form.Reviewed;
	StructureForWrite.ReviewAfter        = Form.ReviewAfter;
	StructureForWrite.CalculateReviewedItems = CalculateReviewedItems;
	
	// If the interaction itself is set as a subject, nothing needs to be done.
	If Form.SubjectOf = InteractionHyperlink Then
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(InteractionHyperlink, StructureForWrite);
		CalculateReviewedByContactsOnWriteFromForm(CurrentObject, Form.Reviewed, Form.Object.Ref, OldAttributesValues);
		Return;
	EndIf;
	
	// If the interaction is set as a new subject, a subject of the new subject is to be checked.
	If ValueIsFilled(Form.SubjectOf) Then
		
		If InteractionsClientServer.IsInteraction(Form.SubjectOf) Then
			
			SubjectOfSubject = GetSubjectValue(Form.SubjectOf);
			If Not ValueIsFilled(SubjectOfSubject) Then
				
				StructureForWrite.SubjectOf                 = Form.SubjectOf;
				StructureForWrite.CalculateReviewedItems = True;
				InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(InteractionHyperlink, StructureForWrite);
			Else
				StructureForWrite.SubjectOf                 = SubjectOfSubject;
				StructureForWrite.CalculateReviewedItems = True;
				Form.SubjectOf = SubjectOfSubject;
				InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(InteractionHyperlink, StructureForWrite);
			EndIf;
			
		Else
			InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(InteractionHyperlink, StructureForWrite);
		EndIf;
		
	Else
		
		StructureForWrite.SubjectOf                 = InteractionHyperlink;
		StructureForWrite.CalculateReviewedItems = True;
		Form.SubjectOf                              = InteractionHyperlink;
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(InteractionHyperlink, StructureForWrite);
		
	EndIf;
	
	// If a previous subject is an interaction, you might need to change the subject in the whole chain.
	If ValueIsFilled(OldAttributesValues.SubjectOf) And InteractionsClientServer.IsInteraction(OldAttributesValues.SubjectOf) Then
		
		If Not (InteractionHyperlink <> OldAttributesValues.SubjectOf 
			And (Not ValueIsFilled(Form.SubjectOf) 
			Or InteractionsClientServer.IsInteraction(Form.SubjectOf))) Then
			
			ReplaceSubjectInInteractionsChain(OldAttributesValues.SubjectOf, Form.SubjectOf, InteractionHyperlink);
			
		EndIf;
		
	EndIf;
	
	CalculateReviewedByContactsOnWriteFromForm(CurrentObject, Form.Reviewed, Form.Object.Ref, OldAttributesValues);
	
EndProcedure

// Calls the calculation of the flag reviewed by contacts on writing from the form.
//
// Parameters:
//  CurrentObject            - DocumentObject - the object in whose form the record was done.
//  Reviewed              - Boolean         - indicates that interaction is reviewed.
//  Ref                   - DocumentRef - a reference to the interaction document.
//  OldAttributesValues - Structure      - contains the previously saved values.
//
Procedure CalculateReviewedByContactsOnWriteFromForm(CurrentObject, Reviewed, Ref, OldAttributesValues)
	
	If (DoNotSaveContacts(CurrentObject.AdditionalProperties) 
		And OldAttributesValues.Reviewed <> Reviewed)
		Or Ref.IsEmpty() Then
		
		InteractionsArray = New Array;
		InteractionsArray.Add(CurrentObject.Ref);
		CalculateReviewedByContacts(InteractionsArray);
		
	EndIf;
	
EndProcedure

// An event handler before writing for interactions that occur in document forms.
//
// Parameters:
//  Form         - ClientApplicationForm - a form in which the event occurred.
//  CurrentObject - DocumentObject - a document, in which the event occurred.
//  ContactsChanged - Boolean - indicates that interaction contact changes must be saved.
//
Procedure BeforeWriteInteractionFromForm(Form, CurrentObject, ContactsChanged = False) Export
	
	CurrentObject.AdditionalProperties.Insert("SubjectOf", Form.SubjectOf);
	
	If Not ContactsChanged Then
		CurrentObject.AdditionalProperties.Insert("DoNotSaveContacts", True);
	EndIf;
	
	If CurrentObject.Ref.IsEmpty() Then
		CurrentObject.InteractionBasis = Form.InteractionBasis;
	EndIf;

EndProcedure

// Fills in a list of interactions available for creation.
//
// Parameters:
//  DocumentsAvailableForCreation - ValueList - a value list to be filled in.
//
Procedure FillListOfDocumentsAvailableForCreation(DocumentsAvailableForCreation) Export
	
	For Each DocumentToRegister In Metadata.DocumentJournals.Interactions.RegisteredDocuments Do
		
		If Not DocumentToRegister.Name = "IncomingEmail" Then
			
			DocumentsAvailableForCreation.Add(DocumentToRegister.Name,DocumentToRegister.Synonym);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Executed when importing saved user settings of the InteractionType quick filter 
// in the interaction document list forms.
//
// Parameters:
//  Form - ClientApplicationForm - a form for which a procedure is performed.
//  Settings - Map - settings to import.
//
Procedure OnImportInteractionsTypeFromSettings(Form, Settings) Export

	InteractionType = Settings.Get("InteractionType");
	If InteractionType <> Undefined Then
		Settings.Delete("InteractionType");
	EndIf;
	
	If Form.OnlyEmail Then
		If InteractionType = Undefined 
			Or Form.Items.InteractionType.ChoiceList.FindByValue(InteractionType) = Undefined Then
			InteractionType = "AllEmails";
			Settings.Delete("InteractionType");
		EndIf;
	Else
		If InteractionType = Undefined Then
			InteractionType = "All";
			Settings.Delete("InteractionType");
		EndIf;
	EndIf;
	
	Form.InteractionType = InteractionType;

EndProcedure

// Replaces a subject in interaction chain.
//
// Parameters:
//  Chain   - AnyRef - an interaction subject that will be replaced.
//  SubjectOf	  - AnyRef - a subject that will replace the previous one.
//  Exclude - AnyRef - an interaction, where a subject will not be replaced.
//
Procedure ReplaceSubjectInInteractionsChain(Chain, SubjectOf, Exclude = Undefined)
	
	SetPrivilegedMode(True);
	InteractionsArray = InteractionsFromChain(Chain, Exclude);
	InteractionsServerCall.SetSubjectForInteractionsArray(InteractionsArray, SubjectOf);
	
EndProcedure

Function MergeEmails(FirstEmailHTMLDocument, SecondEmailHTMLDocument, SecondEmailHeader) Export
	
	SecondEmailBody = SecondEmailHTMLDocument.Body;
	SecondEmailHTMLNodes = ChildNodesWithHTML(SecondEmailBody);
	
	DIVElement = AddElementWithAttributes(SecondEmailBody, "div", 
		New Structure("style", "border:none;border-left:solid blue 1.5pt;padding:0cm 0cm 0cm 4.0pt"));
	
	For Each ChildNode In SecondEmailHTMLNodes Do
		DIVElement.AppendChild(ChildNode);
	EndDo;
	
	SeparatorAttributes = New Structure;
	SeparatorAttributes.Insert("size", "2");
	SeparatorAttributes.Insert("width", "100%");
	SeparatorAttributes.Insert("align", "center");
	SeparatorAttributes.Insert("tabindex", "-1");
	
	SeparatorItem = AddElementWithAttributes(DIVElement, "hr", SeparatorAttributes);
	InsertHTMLElementAsFirstChildElement(DIVElement, SeparatorItem, SecondEmailHTMLNodes);
	
	EmailHeader1 = GenerateEmailHeaderDataItem(DIVElement, SecondEmailHeader, 
		SecondEmailHeader.MetadataObjectName = "OutgoingEmail");
	InsertHTMLElementAsFirstChildElement(DIVElement, EmailHeader1, SecondEmailHTMLNodes);
	
	EmailBodyNodes = ChildNodesWithHTML(FirstEmailHTMLDocument.Body);
	For Each ChildNode In EmailBodyNodes Do
		SecondEmailBody.InsertBefore(SecondEmailHTMLDocument.ImportNode(ChildNode, True), DIVElement);
	EndDo;
	
	CSSStyles = FirstEmailHTMLDocument.GetElementByTagName("style");
	For Each CSSStyle In CSSStyles Do
		TitleItems = SecondEmailHTMLDocument.GetElementByTagName("head");
		If TitleItems.Count() = 0 Then
			TitleItem = SecondEmailHTMLDocument.CreateElement("head");
			SecondEmailHTMLDocument.GetElementByTagName("html")[0].InsertBefore(TitleItem, SecondEmailBody);
		Else
			TitleItem = TitleItems[0];
		EndIf;	
		TitleItem.AppendChild(SecondEmailHTMLDocument.ImportNode(CSSStyle, True));
	EndDo;	
	
	Return SecondEmailHTMLDocument;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////////
// Operations with the HTML Document object.

// Gets an array of HTML element child nodes that contain HTML.
//
// Parameters:
//  Item  - HTMLElement
//
// Returns:
//   Array
//
Function ChildNodesWithHTML(Item)

	Result = New Array;
	For Each ChildNode In Item.ChildNodes Do
		If TypeOf(ChildNode) = Type("HTMLDivElement")
			Or TypeOf(ChildNode) = Type("HTMLElement")
			Or TypeOf(ChildNode) = Type("DOMText")
			Or TypeOf(ChildNode) = Type("DOMComment")
			Or TypeOf(ChildNode) = Type("HTMLTableElement")
			Or TypeOf(ChildNode) = Type("HTMLPreElement") Then
			
			Result.Add(ChildNode);
		EndIf;
	EndDo;
	Return Result;

EndFunction

#EndRegion
