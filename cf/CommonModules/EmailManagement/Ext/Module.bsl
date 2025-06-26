///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add(Metadata.ScheduledJobs.SendReceiveEmails.Name);
	
EndProcedure

Function EmailAttachments2(MailMessage, FormIdentifier) Export
	
	Result = New ValueTable;
	Result.Columns.Add("Description", Common.StringTypeDetails(256));
	Result.Columns.Add("EmailFileID", Common.StringTypeDetails(32));
	Result.Columns.Add("Ref");
	
	Attachments = GetEmailAttachments(MailMessage, False);
	For Each Attachments In Attachments Do
		
		NewAttachments                           = Result.Add();
		NewAttachments.Description              = Attachments.FileName;
		NewAttachments.EmailFileID = Attachments.EmailFileID;
		NewAttachments.Ref                    = Attachments.Ref;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function IsEmailOrMessage(Ref) Export
	
	ObjectType = TypeOf(Ref);
	
	Return ObjectType = Type("DocumentRef.IncomingEmail")
		Or ObjectType = Type("DocumentRef.OutgoingEmail")
		Or ObjectType = Type("DocumentRef.SMSMessage");
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Receiving and sending emails

Procedure SendReceiveEmails() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.SendReceiveEmails);
	
	If Not GetFunctionalOption("UseEmailClient") Then
		Return;
	EndIf;
		
	SetPrivilegedMode(True);
	
	WriteLogEvent(EventLogEvent(), 
		EventLogLevel.Information, , ,
		NStr("en = 'Mail synchronization started';", Common.DefaultLanguageCode()));
		
	EmailsReceived = EmailsReceived();
	LoadEmails(EmailsReceived);
	SendEmails(EmailsReceived.EmailsToDefineFolders, EmailsReceived.AllRecievedEmails);
	
	Interactions.FillInteractionsArrayContacts(EmailsReceived.AllRecievedEmails);
	Interactions.SetFoldersForEmailsArray(EmailsReceived.EmailsToDefineFolders);
	Interactions.CalculateReviewedBySubjects(EmailsReceived.AllRecievedEmails);
	Interactions.CalculateReviewedByContacts(EmailsReceived.AllRecievedEmails);

	SendNotoficationsOnReading(False);
	
	WriteLogEvent(EventLogEvent(), 
		EventLogLevel.Information, , ,
		NStr("en = 'Mail synchronization completed';", Common.DefaultLanguageCode()));
	
EndProcedure

Function LoadEmails(EmailsReceived)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EmailAccounts.Ref                                                        AS Ref,
	|	EmailAccounts.Email                                         AS Email,
	|	EmailAccounts.Description                                                  AS Description,
	|	ISNULL(EmailAccountSettings.PutEmailInBaseEmailFolder, FALSE) AS PutEmailInBaseEmailFolder,
	|	CASE
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			THEN ISNULL(EmailAccountSettings.EmployeeResponsibleForProcessingEmails, VALUE(Catalog.Users.EmptyRef))
	|		ELSE EmailAccounts.AccountOwner
	|	END                                                                                       AS EmployeeResponsibleForProcessingEmails,
	|	EmailAccounts.KeepMessageCopiesAtServer                              AS KeepCopies,
	|	EmailAccounts.KeepMailAtServerPeriod                              AS KeepDays,
	|	EmailAccounts.UserName                                               AS UserName,
	|	EmailAccounts.ProtocolForIncomingMail                                         AS ProtocolForIncomingMail,
	|	ISNULL(LastEmailImportDate.EmailsImportDate, DATETIME(1, 1, 1))      AS EmailsImportDate,
	|	CASE
	|		WHEN EmailAccounts.ProtocolForIncomingMail = ""IMAP""
	|			THEN ISNULL(EmailAccountSettings.MailHandlingInOtherMailClient, FALSE)
	|		ELSE FALSE
	|	END                                                                                        AS MailHandledInOtherMailClient
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.LastEmailImportDate AS LastEmailImportDate
	|		ON (LastEmailImportDate.Account = EmailAccounts.Ref)
	|WHERE
	|	EmailAccounts.UseForReceiving
	|	AND NOT ISNULL(EmailAccountSettings.NotUseInDefaultEmailClient, FALSE)
	|	AND EmailAccounts.Email <> """"
	|	AND EmailAccounts.IncomingMailServer <> """"
	|	AND NOT EmailAccounts.DeletionMark
	|	AND CASE
	|		WHEN &DataSeparationEnabled
	|			THEN CASE 
	|				WHEN ISNULL(EmailAccountSettings.DateOfLastUse, DATETIME(1,1,1)) > &DateAMonthAgo 
	|					THEN TRUE
	|			ELSE FALSE
	|		END
	|		ELSE TRUE
	|	END";
	
	Query.SetParameter("DateAMonthAgo",     AddMonth(BegOfDay(CurrentSessionDate()), - 1));
	Query.SetParameter("DataSeparationEnabled", Common.DataSeparationEnabled());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ReceivedEmails = 0;
		EmailsReceived.EmailsReceivedByAccount.Clear();
		// @skip-check query-in-loop - Batch receipt of email messages from mailboxes.
		GetEmails(Selection, False, ReceivedEmails, EmailsReceived);
		// @skip-check query-in-loop - Batch receipt of email messages from mailboxes.
		DeterminePreviouslyImportedSubordinateEmails(Selection.Ref, EmailsReceived.EmailsReceivedByAccount);
	EndDo;

	Return Selection.Ref;
	
EndFunction

Procedure SendEmails(EmailsToDefineFolders, AllRecievedEmails)
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.Ref                                                  AS Ref,
	|	PRESENTATION(OutgoingEmail.Ref)                                   AS EmailPresentation,
	|	OutgoingEmail.DeleteAfterSend                                    AS DeleteAfterSend,
	|	OutgoingEmail.Account                                           AS Account,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, TRUE)                      AS FolderDefinitionRequired,
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0) AS AttemptsNumber
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		INNER JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON OutgoingEmail.Account = EmailAccounts.Ref
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|			ON InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|		LEFT JOIN InformationRegister.OutgoingMailNotAcceptedByMailServer AS OutgoingMailNotAcceptedByMailServer
	|		ON (OutgoingMailNotAcceptedByMailServer.MailMessage = OutgoingEmail.Ref)
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|WHERE
	|	NOT OutgoingEmail.DeletionMark
	|	AND EmailAccounts.Email <> """"
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND EmailAccounts.UseForSending
	|	AND OutgoingEmail.EmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
	|	AND CASE
	|			WHEN OutgoingEmail.DateToSendEmail = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.DateToSendEmail < &CurrentDate
	|		END
	|	AND CASE
	|			WHEN OutgoingEmail.EmailSendingRelevanceDate = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.EmailSendingRelevanceDate > &CurrentDate
	|		END
	|	AND ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0) < 5
	|	AND CASE
	|		WHEN &DataSeparationEnabled
	|			THEN CASE 
	|				WHEN ISNULL(EmailAccountSettings.DateOfLastUse, DATETIME(1,1,1)) > &DateAMonthAgo 
	|					THEN TRUE
	|			ELSE FALSE
	|		END
	|		ELSE TRUE
	|	END 
	|ORDER BY
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0)
	|TOTALS BY
	|	Account";
	
	Query.SetParameter("CurrentDate",        CurrentSessionDate());
	Query.SetParameter("DateAMonthAgo",     AddMonth(BegOfDay(CurrentSessionDate()), - 1));
	Query.SetParameter("DataSeparationEnabled", Common.DataSeparationEnabled());
	
	SendEmailsInternal(Query, AllRecievedEmails, EmailsToDefineFolders);
	
EndProcedure

Procedure SendEmailsInternal(Query, AllRecievedEmails, EmailsToDefineFolders, SentEmails1 = 0, HasErrors = False, Interactively = False)
	
	AccountsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	SetPrivilegedMode(True);
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	While AccountsSelection.Next() Do
		Account = AccountsSelection.Account;
		// @skip-check query-in-loop - Batch receipt of email messages from mailboxes.
		If Not LockAccount(Account) Then
			Continue;
		EndIf;
		
		If Not DataSeparationEnabled Then
			InformationRegisters.EmailAccountSettings.UpdateTheAccountUsageDate(Account);
		EndIf;
		
		Emails      = New Array;
		EmailsData = New Map;
		
		EmailSelection = AccountsSelection.Select();
		While EmailSelection.Next() Do
			
			EmailObject = EmailSelection.Ref.GetObject();
			EmailParameters = Interactions.EmailSendingParameters(EmailObject);
			Try
				MailMessage = EmailOperations.PrepareEmail(Account, EmailParameters);
			Except
				
				ErrorMessageTemplate = NStr("en = 'The %1 email is not prepared for sending due to:
					|%2';", Common.DefaultLanguageCode());
				
				ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
					ErrorMessageTemplate, 
					Interactions.EmailPresentation(EmailObject.Subject, EmailObject.Date),
					ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(EventLogEvent(), EventLogLevel.Error, , , ErrorMessageText);
				
				RecordManager = InformationRegisters.OutgoingMailNotAcceptedByMailServer.CreateRecordManager();
				RecordManager.MailMessage            = EmailSelection.Ref;
				RecordManager.AttemptsNumber = 5;
				RecordManager.ErrorInformation = ErrorMessageText;
				RecordManager.Write();
				
				Continue;
				
			EndTry;
			
			Emails.Add(MailMessage);
			
			EmailData = New Structure;
			EmailData.Insert("MailMessage",              MailMessage);
			EmailData.Insert("AttemptsNumber",   EmailSelection.AttemptsNumber);
			EmailData.Insert("EmailPresentation", EmailSelection.EmailPresentation);
			
			EmailsData.Insert(EmailSelection.Ref, EmailData);
			
		EndDo;
		
		ErrorText = Undefined;
		Try
			SendingResult = EmailOperations.SendEmails(Account, Emails, ErrorText);
			UnlockAccountForReceiving(Account);
		Except
			UnlockAccountForReceiving(Account);
			
			ErrorMessageTemplate = NStr("en = 'Cannot connect to the %1 account due to:
				|%2';", Common.DefaultLanguageCode());
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, 
				Account, EmailOperations.ExtendedErrorPresentation(ErrorInfo(), Common.DefaultLanguageCode()));
			WriteLogEvent(EventLogEvent(), EventLogLevel.Error, , , ErrorMessageText);
			
			If Not ValueIsFilled(SendingResult) Then 
				
				If Emails.Count() <> 0 Then
					FirstEmailData = RefToEmailByOutgoingMailMessage(EmailsData, Emails[0]); 
					
					If FirstEmailData <> Undefined Then
						
						ErrorProcessingParameters = SendErrorProcessingParameters();
						ErrorProcessingParameters.EmailObject                      = FirstEmailData.Key.GetObject();
						ErrorProcessingParameters.Ref                            = FirstEmailData.Key;
						ErrorProcessingParameters.EmailPresentation               = FirstEmailData.Value.EmailPresentation;
						ErrorProcessingParameters.AttemptsNumber                 = FirstEmailData.Value.AttemptsNumber;
						ErrorProcessingParameters.IncrementAttemptsCount = True;
						ErrorProcessingParameters.InformUser              = Interactively;
						ErrorProcessingParameters.ErrorText                       = ErrorProcessing.BriefErrorDescription(ErrorInfo());
						
						ErrorProcessingResult = ProcessEmailSendingError(ErrorProcessingParameters, New Array);
						
					EndIf;
					
					Continue;
					
				EndIf;
			EndIf; 
			
		EndTry;
		
		ErrorsTexts = New Array;
		EmailSelection = AccountsSelection.Select();
		While EmailSelection.Next() Do
			EmailRef = EmailSelection.Ref;
			EmailSendingResult = SendingResult[EmailsData[EmailRef].MailMessage];
			WrongRecipients = Undefined;
			If EmailSendingResult <> Undefined Then
				WrongRecipients = EmailSendingResult.WrongRecipients;
				If ValueIsFilled(WrongRecipients) Then 
					
					ErrorProcessingParameters = SendErrorProcessingParameters();
					ErrorProcessingParameters.EmailObject                      = EmailSelection.Ref.GetObject();
					ErrorProcessingParameters.Ref                            = EmailSelection.Ref;
					ErrorProcessingParameters.EmailPresentation               = EmailSelection.EmailPresentation;
					ErrorProcessingParameters.AttemptsNumber                 = EmailSelection.AttemptsNumber;
					ErrorProcessingParameters.IncrementAttemptsCount = True;
					ErrorProcessingParameters.InformUser              = Interactively;
					
					ErrorProcessingResult = ProcessEmailSendingError(ErrorProcessingParameters, WrongRecipients);
					If Not ErrorProcessingResult.EmailSent Then
						Continue;
					EndIf; 
					
				EndIf;
				
				SentEmails1 = SentEmails1 + 1;
				DeleteAfterSend = EmailSelection.DeleteAfterSend;
				
				ErrorText = AfterExecuteSendEmail(EmailRef, EmailSendingResult.SMTPEmailID, 
				EmailSendingResult.IMAPEmailID, DeleteAfterSend, False);
				
				If ValueIsFilled(ErrorText) Then
					ErrorsTexts.Add(ErrorText);
					Continue;
				EndIf;
				
				If Not EmailSelection.DeleteAfterSend Then
					If EmailSelection.FolderDefinitionRequired Then
						EmailsToDefineFolders.Add(EmailSelection.Ref);
					EndIf;
					AllRecievedEmails.Add(EmailSelection.Ref);
				EndIf;
			EndIf;
		EndDo; 
		
		If SendingResult.Count() <> Emails.Count() Then
			
			For Each EmailToSend In Emails Do
				
				If SendingResult[EmailToSend] = Undefined Then
					
					DataFromFirstUnsentEmail = RefToEmailByOutgoingMailMessage(EmailsData, EmailToSend);
					
					If DataFromFirstUnsentEmail <> Undefined Then
						
						ErrorProcessingParameters = SendErrorProcessingParameters();
						ErrorProcessingParameters.EmailObject                      = DataFromFirstUnsentEmail.Key.GetObject();
						ErrorProcessingParameters.Ref                            = DataFromFirstUnsentEmail.Key;
						ErrorProcessingParameters.EmailPresentation               = DataFromFirstUnsentEmail.Value.EmailPresentation;
						ErrorProcessingParameters.AttemptsNumber                 = DataFromFirstUnsentEmail.Value.AttemptsNumber;
						ErrorProcessingParameters.IncrementAttemptsCount = True;
						ErrorProcessingParameters.InformUser              = Interactively;
						ErrorProcessingParameters.ErrorText                       = NStr("en = 'Unknown error when sending the email message';");
						ErrorProcessingParameters.ShouldLogEvents = False;
						
						ErrorProcessingResult = ProcessEmailSendingError(ErrorProcessingParameters, New Array);
						
					EndIf;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If ValueIsFilled(ErrorsTexts) Then
			Raise StrConcat(ErrorsTexts, Chars.LF);
		EndIf;
		
	EndDo;
	
EndProcedure

Function RefToEmailByOutgoingMailMessage(EmailsData, EmailToSend)
	
	For Each EmailData In EmailsData Do
		
		If EmailData.Value.MailMessage = EmailToSend Then
			
			Return EmailData;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function EncryptedFilesExtension()
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		Return ModuleDigitalSignature.PersonalSettings().EncryptedFilesExtension;
	Else
		Return "p7m";
	EndIf;
	
EndFunction

Function AfterExecuteSendEmail(Ref, MessageID, MessageIDIMAPSending, DeleteAfterSend, RaiseException1 = True)

	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Document.OutgoingEmail");
		LockItem.SetValue("Ref", Ref);
		Block.Lock();
		
		If DeleteAfterSend Then
			EmailObject = Ref.GetObject();
			EmailObject.Delete();
		Else
			EmailObject = Ref.GetObject(); // DocumentObject.OutgoingEmail
			EmailObject.MessageID             = MessageID;
			EmailObject.MessageIDIMAPSending = MessageIDIMAPSending;
			
			EmailObject.EmailStatus                       = Enums.OutgoingEmailStatuses.Sent;
			EmailObject.Size                             = Interactions.EvaluateOutgoingEmailSize(EmailObject.Ref);
			EmailObject.PostingDate                    = CurrentSessionDate();
			EmailObject.AdditionalProperties.Insert("DoNotSaveContacts", True);
			EmailObject.Write(DocumentWriteMode.Write);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		If RaiseException1 Then
			Raise;
		EndIf;
		ErrorInfo = ErrorInfo();
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error, Ref.Metadata(),
			EmailObject, ErrorProcessing.DetailErrorDescription(ErrorInfo));
		Return ErrorProcessing.BriefErrorDescription(ErrorInfo);
	EndTry;
	
	Return "";
	
EndFunction

// Returns:
//   Structure:
//     * EmailObject                      - DocumentObject.OutgoingEmail - an email to be sent.
//     * Ref                            - DocumentRef.OutgoingEmail - a reference to the mail message to be sent.
//     * EmailPresentation               - String
//     * AttemptsNumber                 - Number - the number of attempts to send a mail message.
//     * IncrementAttemptsCount - Boolean
//     * InformUser              - Boolean - indicates whether to display a message to the user.
//
Function SendErrorProcessingParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("EmailObject",                       Undefined);
	Parameters.Insert("Ref",                             Undefined);
	Parameters.Insert("EmailPresentation",                "");
	Parameters.Insert("AttemptsNumber",                  0);
	Parameters.Insert("IncrementAttemptsCount" , False);
	Parameters.Insert("InformUser",               False);
	Parameters.Insert("ErrorText",                        "");
	Parameters.Insert("ShouldLogEvents",  True);
	
	Return Parameters;
	
EndFunction

// Parameters:
//  ErrorProcessingParameters - See SendErrorProcessingParameters
//  WrongRecipients      - Array 
// 
// Returns:
//  Structure:
//    * MessageText - String - an error message text
//    * EmailSent - Boolean - indicates whether the email message was sent
//
Function ProcessEmailSendingError(ErrorProcessingParameters, Val WrongRecipients) Export
	
	Result = New Structure;
	Result.Insert("MessageText", "");
	Result.Insert("EmailSent", False);
	
	AnalysisResult = WrongRecipientsAnalysisResult(ErrorProcessingParameters.EmailObject, WrongRecipients);
	AllEmailAddresseesRejectedByServer           = AnalysisResult.AllEmailAddresseesRejectedByServer;
	WrongAddresseesPresentation               = AnalysisResult.WrongAddresseesPresentation;
	IsIssueOfEmailAddressesServerRejection = AnalysisResult.IsIssueOfEmailAddressesServerRejection;
	
	If IsIssueOfEmailAddressesServerRejection Then
		
		If Not AllEmailAddresseesRejectedByServer Then
			ErrorMessageTemplate = NStr("en = 'Some recipients of the message ""%1"" were rejected by the server:
				|%2. The message was sent to other recipients.';", Common.DefaultLanguageCode());
		Else
			ErrorMessageTemplate = NStr("en = 'Cannot send message ""%1"".
				|The following recipients were rejected by the server:
				|%2.';", Common.DefaultLanguageCode());
		EndIf;
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate,
		                                                                                 ErrorProcessingParameters.EmailPresentation,
		                                                                                 WrongAddresseesPresentation);
		
	Else
		
		ErrorMessageTemplate = NStr("en = 'Cannot send the email message ""%1"".
			|Reason: %2.';", Common.DefaultLanguageCode());
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate,
		                                                                                 ErrorProcessingParameters.EmailPresentation,
		                                                                                 ErrorProcessingParameters.ErrorText)
		
	EndIf;
	
	If ErrorProcessingParameters.ShouldLogEvents Then
	
		WriteLogEvent(EventLogEvent(),
		                        EventLogLevel.Error, 
		                        ErrorProcessingParameters.Ref.Metadata(), 
		                        ErrorProcessingParameters.Ref, 
		                        ErrorMessageText);
		
	EndIf;
	
	Result.MessageText = ErrorMessageText;
	
	If ErrorProcessingParameters.InformUser Then
		Common.MessageToUser(ErrorMessageText, ErrorProcessingParameters.Ref);
	EndIf;
	
	If AllEmailAddresseesRejectedByServer
		Or Not IsIssueOfEmailAddressesServerRejection Then
		
		If ErrorProcessingParameters.IncrementAttemptsCount Then
			
			RecordManager = InformationRegisters.OutgoingMailNotAcceptedByMailServer.CreateRecordManager();
			RecordManager.MailMessage = ErrorProcessingParameters.Ref;
			RecordManager.AttemptsNumber = ?(AllEmailAddresseesRejectedByServer, 5, ErrorProcessingParameters.AttemptsNumber + 1);
			RecordManager.ErrorInformation = ErrorMessageText;
			RecordManager.Write();
		
		EndIf;
		Return Result;
		
	EndIf;
	
	Result.EmailSent = True;
	
	Return Result;

EndFunction

Procedure SendNotoficationsOnReading(ForCurrentUser)
	
	QueryText = 
		"SELECT
		|	ReadReceipts.MailMessage AS MailMessage,
		|	PRESENTATION(ReadReceipts.MailMessage) AS EmailPresentation,
		|	ReadReceipts.ReadDate AS ReadDate,
		|	IncomingEmail.ReadReceiptAddresses.(
		|		Address AS Address,
		|		Presentation AS Presentation,
		|		Contact AS Contact
		|	) AS ReadReceiptAddresses,
		|	IncomingEmail.Account AS Account,
		|	IncomingEmail.SenderPresentation AS SenderPresentation,
		|	IncomingEmail.SenderAddress AS SenderAddress,
		|	IncomingEmail.Date AS Date,
		|	EmailAccounts.UserName AS UserName,
		|	EmailAccounts.Email AS Email,
		|	IncomingEmail.Subject AS Subject,
		|	ReadReceipts.User AS User
		|FROM
		|	InformationRegister.ReadReceipts AS ReadReceipts
		|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
		|			LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
		|			ON IncomingEmail.Account = EmailAccounts.Ref
		|		ON ReadReceipts.MailMessage = IncomingEmail.Ref
		|WHERE
		|	ReadReceipts.SendingRequired
		|	AND &ForCurrentUser
		|TOTALS BY
		|	Account";
	
	QueryText = StrReplace(QueryText, "&ForCurrentUser", 
		?(ForCurrentUser, "ReadReceipts.User = &User", "TRUE"));
	Query = New Query(QueryText);
	If ForCurrentUser Then
		Query.SetParameter("User", Users.CurrentUser());
	EndIf;
	
	AccountsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While AccountsSelection.Next() Do
		
		Account = AccountsSelection.Account;
		Emails = New Array;
		EmailsHyperlinks = New Map;
		
		EmailSelection = AccountsSelection.Select();
		While EmailSelection.Next() Do
			EmailParameters = New Structure;
			
			Interactions.AddToAddresseesParameter(EmailSelection, EmailParameters, "Whom", "ReadReceiptAddresses");
			
			EmailParameters.Insert("Subject",NStr("en = 'Read receipt';") + " / " +"Reading Confirmation");
			EmailParameters.Insert("Body",GenerateReadReceiptText(EmailSelection));
			EmailParameters.Insert("Encoding","UTF-8");
			EmailParameters.Insert("Importance", InternetMailMessageImportance.Normal);
			EmailParameters.Insert("TextType", Enums.EmailTextTypes.PlainText);
			EmailParameters.Insert("ProcessTexts", False);
			
			MailMessage = EmailOperations.PrepareEmail(Account, EmailParameters);
			Emails.Add(MailMessage);
			
			EmailsHyperlinks.Insert(MailMessage, EmailSelection.MailMessage);
		EndDo;
		
		SentEmails = EmailOperations.SendEmails(Account, Emails);
		For Each MailMessage In EmailsHyperlinks Do
			If SentEmails[MailMessage.Key] = Undefined Then
				Continue;
			EndIf;
			Ref = MailMessage.Value;
			SetNotificationSendingFlag(Ref, False);
		EndDo;
		
	EndDo;

EndProcedure

// Receives email by accounts available to the user.
//
// Parameters:
//   Result - Structure:
//   * ReceivedEmails               - Number - The parameter takes the number of received email messages.
//   * UserAccountsAvailable - Number - The parameter takes the number of the email accounts available to the user.
//                                   
//   * HasErrors             - Boolean - Flag indicating whether errors occurred when receiving email messages.
//
Procedure LoadUserEmail(Result)
	
	TimeConsumingOperations.ReportProgress(, NStr("en = 'Receive mail';"));
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EmailAccounts.Ref                                                        AS Ref,
	|	EmailAccounts.Email                                         AS Email,
	|	EmailAccounts.Description                                                  AS Description,
	|	ISNULL(EmailAccountSettings.PutEmailInBaseEmailFolder, FALSE) AS PutEmailInBaseEmailFolder,
	|	CASE
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			THEN ISNULL(EmailAccountSettings.EmployeeResponsibleForProcessingEmails, VALUE(Catalog.Users.EmptyRef))
	|		ELSE EmailAccounts.AccountOwner
	|	END AS EmployeeResponsibleForProcessingEmails,
	|	EmailAccounts.KeepMessageCopiesAtServer AS KeepCopies,
	|	EmailAccounts.KeepMailAtServerPeriod AS KeepDays,
	|	EmailAccounts.ProtocolForIncomingMail AS ProtocolForIncomingMail,
	|	EmailAccounts.UserName AS UserName,
	|	ISNULL(LastEmailImportDate.EmailsImportDate, DATETIME(1, 1, 1)) AS EmailsImportDate,
	|	CASE
	|		WHEN EmailAccounts.ProtocolForIncomingMail = ""IMAP""
	|			THEN ISNULL(EmailAccountSettings.MailHandlingInOtherMailClient, FALSE)
	|		ELSE FALSE
	|	END AS MailHandledInOtherMailClient
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.LastEmailImportDate AS LastEmailImportDate
	|		ON (LastEmailImportDate.Account = EmailAccounts.Ref)
	|WHERE
	|	EmailAccounts.UseForReceiving
	|	AND NOT EmailAccounts.DeletionMark
	|	AND NOT ISNULL(EmailAccountSettings.NotUseInDefaultEmailClient, FALSE)";
	
	Selection = Query.Execute().Select();

	Result.EmailsReceived1 = 0;
	Result.UserAccountsAvailable = Selection.Count();
	If Result.UserAccountsAvailable = 0 Then
		Common.MessageToUser(NStr("en = 'No available email accounts to receive mail.';"));
		Result.HasErrors = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	While Selection.Next() Do
		
		If DataSeparationEnabled Then
			InformationRegisters.EmailAccountSettings.UpdateTheAccountUsageDate(Selection.Ref);
		EndIf;
		
		ReceivedEmails = 0;
		EmailsReceived = EmailsReceived();
		
		// @skip-check query-in-loop - Batch receipt of email messages from mailboxes.
		GetEmails(Selection, Result.HasErrors, ReceivedEmails, EmailsReceived);
		Result.EmailsReceived1 = Result.EmailsReceived1 + ReceivedEmails;
		
		// @skip-check query-in-loop - Batch receipt of email messages from mailboxes.
		DeterminePreviouslyImportedSubordinateEmails(Selection.Ref, EmailsReceived.EmailsReceivedByAccount);
		Interactions.FillInteractionsArrayContacts(EmailsReceived.AllRecievedEmails);
		Interactions.SetFoldersForEmailsArray(EmailsReceived.EmailsToDefineFolders);
		Interactions.CalculateReviewedBySubjects(EmailsReceived.AllRecievedEmails);
		Interactions.CalculateReviewedByContacts(EmailsReceived.AllRecievedEmails);
		
	EndDo;
	
EndProcedure

Procedure SendUserEmail(Result)
	
	TimeConsumingOperations.ReportProgress(, NStr("en = 'Send mail';"));
	
	Query = New Query;
	Query.Text = "
	|SELECT ALLOWED
	|	EmailAccounts.Ref                                               AS Account,
	|	OutgoingEmail.Ref                                                  AS Ref,
	|	PRESENTATION(OutgoingEmail.Ref)                                   AS EmailPresentation,
	|	OutgoingEmail.DeleteAfterSend                                    AS DeleteAfterSend,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, TRUE)                      AS FolderDefinitionRequired,
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0) AS AttemptsNumber
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON OutgoingEmail.Account = EmailAccounts.Ref
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|			ON InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON OutgoingEmail.Account = EmailAccountSettings.EmailAccount
	|		LEFT JOIN InformationRegister.OutgoingMailNotAcceptedByMailServer AS OutgoingMailNotAcceptedByMailServer
	|		ON OutgoingMailNotAcceptedByMailServer.MailMessage = OutgoingEmail.Ref
	|WHERE
	|	NOT OutgoingEmail.DeletionMark
	|	AND NOT EmailAccounts.DeletionMark
	|	AND OutgoingEmail.EmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
	|	AND EmailAccounts.UseForSending
	|	AND NOT ISNULL(EmailAccountSettings.NotUseInDefaultEmailClient, FALSE)
	|	AND CASE
	|			WHEN OutgoingEmail.DateToSendEmail = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.DateToSendEmail < &CurrentDate
	|		END
	|	AND CASE
	|			WHEN OutgoingEmail.EmailSendingRelevanceDate = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.EmailSendingRelevanceDate > &CurrentDate
	|		END
	|	AND ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0) < 5 
	|ORDER BY
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptsNumber, 0)
	|TOTALS BY
	|	Account";
	
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	EmailsToDefineFolders = New Array;
	AllRecievedEmails = New Array;
	Result.SentEmails1 = 0;
	
	SendEmailsInternal(Query, AllRecievedEmails, EmailsToDefineFolders, Result.SentEmails1, Result.HasErrors, True);
	
	Interactions.SetFoldersForEmailsArray(EmailsToDefineFolders);
	SendNotoficationsOnReading(True);
	
EndProcedure

Procedure SendReceiveUserEmail(ExportingParameters, StorageAddress) Export
	
	Result = New Structure;
	Result.Insert("SentEmails1",        0);
	Result.Insert("EmailsReceived1",          0);
	Result.Insert("UserAccountsAvailable", 0);
	Result.Insert("HasErrors",             False);
	
	SendUserEmail(Result);
	LoadUserEmail(Result);
	
	PutToTempStorage(Result, StorageAddress);
	
EndProcedure

Function WrongRecipientsAnalysisResult(EmailObject, WrongRecipients)

	Result = New Structure;
	Result.Insert("IsIssueOfEmailAddressesServerRejection",False);
	Result.Insert("AllEmailAddresseesRejectedByServer",False);
	Result.Insert("WrongAddresseesPresentation","");
	
	WrongRecipientsCount = WrongRecipients.Count();
	
	If WrongRecipientsCount > 0 Then
		
		Result.IsIssueOfEmailAddressesServerRejection = True;
		
		EmailRecipientsArray = New Array;
		For Each RecipientString In EmailObject.EmailRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		For Each RecipientString In EmailObject.CCRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		For Each RecipientString In EmailObject.BccRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		
		EmailRecipientsCount = EmailRecipientsArray.Count();
		
		If EmailRecipientsCount = WrongRecipientsCount Then
			Result.AllEmailAddresseesRejectedByServer = True;
		EndIf;
		
		WrongAddresseesPresentation = "";
		For Each WrongAddressee In WrongRecipients Do
			If Not IsBlankString(WrongAddresseesPresentation) Then
				WrongAddresseesPresentation = WrongAddresseesPresentation + ", ";
			EndIf;
			WrongAddresseesPresentation = WrongAddresseesPresentation + WrongAddressee.Key;
		EndDo;
		
		Result.WrongAddresseesPresentation = WrongAddresseesPresentation;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Fills InternetMailAddresses in the InternetMailMessage object by the passed address table.
//
// Parameters:
//  TabularSection  - InternetMailAddresses - addresses that will be filled in the email.
//  Addresses          - ValueTable - a table that contains addresses to specify in the email.
//
Procedure FillInternetEmailAddresses(TabularSection, Addresses) Export
	
	For Each Address In Addresses Do
		NewRow = TabularSection.Add();
		NewRow.Address         = CommonClientServer.ReplaceProhibitedXMLChars(Address.Address, "");
		NewRow.Presentation = CommonClientServer.ReplaceProhibitedXMLChars(Address.DisplayName, "");
	EndDo;
	
EndProcedure

Procedure GetEmails(Val AccountData, HasErrors, ReceivedEmails, EmailsReceived)
	
	If Not LockAccount(AccountData.Ref) Then
		Return;
	EndIf;
	
	Protocol = InternetMailProtocol.POP3;
	If AccountData.ProtocolForIncomingMail = "IMAP" Then
		Protocol = InternetMailProtocol.IMAP;
	EndIf;
	
	Try
		Mail = EmailOperations.ConnectToEmailAccount(AccountData.Ref, True);
	Except
		UnlockAccountForReceiving(AccountData.Ref);
		
		HasErrors = True;
		ErrorMessageText = EmailOperations.ExtendedErrorPresentation(
			ErrorInfo(), Common.DefaultLanguageCode());
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot connect to the %1 account due to:
				|%2';", Common.DefaultLanguageCode()),
				AccountData.Ref,
				ErrorMessageText);
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error, , , ErrorMessageText);
		Return;
		
	EndTry;
	
	If Protocol = InternetMailProtocol.POP3 Then
		GetEmailByPOP3Protocol(AccountData, Mail, ReceivedEmails, EmailsReceived);
	Else
		GetEmailByIMAPProtocol(AccountData, Mail, ReceivedEmails, EmailsReceived);
		SynchronizeReviewedFlagWithServer(Mail, AccountData, EmailsReceived.AllRecievedEmails);
	EndIf;
	
	Mail.Logoff();
	
	UnlockAccountForReceiving(AccountData.Ref);

EndProcedure

// Parameters:
//  Mail - InternetMail
//  AccountData - QueryResultSelection
//  MessagesToImportIDs - Array of String
//  EmailsReceived - See EmailsReceived
//  AllIDs - Array of String
//
// Returns:
//  Number - Incoming message count.
//
Function GetEmailMessagesByIDs(Mail, AccountData, MessagesToImportIDs, 
	EmailsReceived, AllIDs = Undefined)
	
	EmailsReceived1 = 0;
	
	If MessagesToImportIDs.Count() <> 0 Then
		
		EmployeeResponsibleForProcessingEmails = AccountData.EmployeeResponsibleForProcessingEmails;
		ErrorsCountOnWrite = 0;
		ObsoleteMessagesCount = 0;
		
		While MessagesToImportIDs.Count() > (EmailsReceived1 + ErrorsCountOnWrite + ObsoleteMessagesCount) Do
			
			CountInBatch = 0;
			ImportableBatchIDs = New Array;
			
			For IndexOf = (EmailsReceived1 + ErrorsCountOnWrite) To MessagesToImportIDs.Count() - 1 Do
				
				ImportableBatchIDs.Add(MessagesToImportIDs.Get(IndexOf));
				CountInBatch = CountInBatch + 1;
				If CountInBatch = 5 Then
					Break;
				EndIf;
				
			EndDo;
			
			Try
				Messages = Mail.Get(False, ImportableBatchIDs,
					?(AccountData.ProtocolForIncomingMail = "IMAP", False, True)); // Array of InternetMailMessage.
			Except
				
				ErrorTextForLog_ = EmailOperations.ExtendedErrorPresentation(
					ErrorInfo(), Common.DefaultLanguageCode());
									
				ErrorTextForLog_ = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot connect to the ""%1"" account due to:
						|%2';", Common.DefaultLanguageCode()),
						AccountData.Ref,
						ErrorTextForLog_);
					
				WriteLogEvent(EventLogEvent(),
					EventLogLevel.Error, , , ErrorTextForLog_);
				
				ErrorTextForUser = EmailOperations.ExtendedErrorPresentation(
					ErrorInfo(), , False);
					
				ErrorTextForUser = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot connect to the ""%1"" account due to:
						 |%2';"),
						AccountData.Ref,
						ErrorTextForUser);	
				
				Raise ErrorTextForUser;
				
			EndTry;
			
			ObsoleteMessagesCount = ObsoleteMessagesCount + (CountInBatch - Messages.Count());
			
			For Each Message In Messages Do
				
				AddToEmailsArrayToGetFolder = False;
				
				Block = New DataLock;
				If Common.FileInfobase() Then
					LockItem = Block.Add("Catalog.EmailAccounts");
					LockItem.Mode = DataLockMode.Shared;
					LockItem = Block.Add("Catalog.EmailMessageFolders");
					LockItem.Mode = DataLockMode.Shared;
					Block.Add("InformationRegister.ReceivedEmailIDs");
					Block.Add("InformationRegister.ReadReceipts");
					Block.Add("Document.OutgoingEmail");
					Block.Add("Document.IncomingEmail");
				EndIf;
				
				BeginTransaction();
				Try
					Block.Lock();
					
					IsOutgoingEmail1 = EmailAddressesEqual(AccountData.Email,
						InternetEmailMessageSenderAddress(Message.From));
					// @skip-check query-in-loop - Save data object-by-object.
					CreatedEmail = WriteEmail(AccountData, Message, 
						EmployeeResponsibleForProcessingEmails, AccountData.PutEmailInBaseEmailFolder,
						AddToEmailsArrayToGetFolder, IsOutgoingEmail1);
					
					EmailsReceived1 = EmailsReceived1 + 1;
					CommitTransaction();
					
				Except
					
					RollbackTransaction();
					ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot receive the %1 email dated %2 from %3. Reason:
						|%4';", Common.DefaultLanguageCode()),
							Message.Subject, Message.PostingDate, Message.From.Address,
							ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					WriteLogEvent(EventLogEvent(), EventLogLevel.Error, , ,
						ErrorMessageText);
					
					ErrorsCountOnWrite = ErrorsCountOnWrite + 1;
					
					If AllIDs <> Undefined Then
						For Each MessageID In Message.UID Do
							IDArrayInIndex = AllIDs.Find(MessageID);
							If IDArrayInIndex <> Undefined Then
								AllIDs.Delete(IDArrayInIndex);
							EndIf;
							Continue;
						EndDo;
					EndIf;
					
				EndTry;
				
				EmailsReceived.AllRecievedEmails.Add(CreatedEmail);
				EmailsReceived.EmailsReceivedByAccount.Add(CreatedEmail);
				If AddToEmailsArrayToGetFolder Then
					EmailsReceived.EmailsToDefineFolders.Add(CreatedEmail);
				EndIf;
				
			EndDo;
		
		EndDo;
		
	EndIf;
	Return EmailsReceived1;
	
EndFunction

Function DateOfSelectionOfIMAPMessageUpload(EmailsImportDate)
	
	Return Min(EmailsImportDate, ToUniversalTime(EmailsImportDate, TimeZone())); 
	
EndFunction

Procedure DetermineIncomingMessageIDs(EmailHeader, IDsTable)
	
	RowTableIdentifiers = IDsTable.Add();
	RowTableIdentifiers.IDAtServer = ?(EmailHeader.UID.Count() = 0,
		"", 
		CommonClientServer.ReplaceProhibitedXMLChars(EmailHeader.UID[0], ""));
	RowTableIdentifiers.EmailID =
		CommonClientServer.ReplaceProhibitedXMLChars(EmailHeader.MessageID, "");
	
	If StrFind(Lower(EmailHeader.MessageID), "outlook.com") = 0 Then
		Return;
	EndIf;
	
	PositionIDOriginalMessage = StrFind(EmailHeader.Header, "X-Microsoft-Original-Message-ID");
	If PositionIDOriginalMessage = 0 Then
		Return;
	EndIf;
	
	Begin = StrFind(EmailHeader.Header, "<", SearchDirection.FromBegin, PositionIDOriginalMessage);
	End = StrFind(EmailHeader.Header, ">", SearchDirection.FromBegin, PositionIDOriginalMessage);
	OriginalIDMessageMicrosoft = Mid(EmailHeader.Header, Begin + 1, End - Begin - 1);	
	RowTableIdentifiers.MicrosoftOriginalLetterId =
		CommonClientServer.ReplaceProhibitedXMLChars(OriginalIDMessageMicrosoft, "");
	
EndProcedure

// Parameters:
//  AccountData - QueryResultSelection
//  Mail - InternetMail
//  EmailsReceived1 - Number
//  EmailsReceived - See EmailsReceived
//
Procedure GetEmailByIMAPProtocol(AccountData, Mail, EmailsReceived1, EmailsReceived)
	
	ActiveFoldersNames = ActiveFoldersNames(Mail);
	
	String255Qualifier =  New TypeDescription("String",,,,New StringQualifiers(255,AllowedLength.Variable));
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("IDAtServer",                    String255Qualifier);
	IDsTable.Columns.Add("EmailID",                       String255Qualifier);
	IDsTable.Columns.Add("MicrosoftOriginalLetterId", String255Qualifier);
	
	BlankIDsTable  = New ValueTable;
	BlankIDsTable.Columns.Add("IDAtServer", String255Qualifier);
	BlankIDsTable.Columns.Add("HashSum", Common.StringTypeDetails(32));
	
	EmailsImportDate = CurrentSessionDate();
	
	For Each ActiveFolderName In ActiveFoldersNames Do
			
		Try
			Mail.CurrentMailbox = ActiveFolderName;
		Except
			Continue;
		EndTry;
		
		FilterParameters = New Structure;
		If Not AccountData.EmailsImportDate = Date(1,1,1) Then 
			FilterParameters.Insert("AfterDateOfPosting", 
				DateOfSelectionOfIMAPMessageUpload(AccountData.EmailsImportDate));
		Else
			FilterParameters.Insert("Deleted", False);
		EndIf;
		
		Try
			EmailsHeadersForImport = Mail.GetHeaders(FilterParameters);
		Except
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t get the email headers. Folder: %1. Account: %2. Reason: %3';"),
				ActiveFolderName, AccountData.Email, 
				EmailOperations.ExtendedErrorPresentation(ErrorInfo(), Common.DefaultLanguageCode(), False)); 
			WriteLogEvent(EventLogEvent(), EventLogLevel.Error,
				Metadata.Catalogs.EmailMessageFolders,, MessageText);
			Continue;
		EndTry;
		
		ReceivableEmailsCount = EmailsHeadersForImport.Count();
		If ReceivableEmailsCount = 0 Then
			Continue;
		EndIf;
		
		MessageText = StrTemplate(NStr("en = 'Receiving emails from folder ""%1"" for %2. Pending messages: %3';"),
		                ActiveFolderName, AccountData.Email, ReceivableEmailsCount); 
		WriteLogEvent(EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.EmailMessageFolders,, MessageText);
		
		TitlesWithEmptyIDs = New Array;
		IDsTable.Clear();
		BlankIDsTable.Clear();
		
		For Each EmailHeader In EmailsHeadersForImport Do
			If IsBlankString(EmailHeader.MessageID) Then
				TitlesWithEmptyIDs.Add(EmailHeader);
				Continue;
			EndIf;
			DetermineIncomingMessageIDs(EmailHeader, IDsTable);
		EndDo;
		
		If TitlesWithEmptyIDs.Count() > 0 Then
			For Each EmailHeader In TitlesWithEmptyIDs Do
				NewRow = BlankIDsTable.Add();
				NewRow.IDAtServer = CommonClientServer.ReplaceProhibitedXMLChars(
					EmailHeader.Id[0], "");
				NewRow.HashSum = EmailMessageHashSum(EmailHeader);
			EndDo;
		EndIf;

		If IDsTable.Count() > 0 Or TitlesWithEmptyIDs.Count() > 0 Then
		
			// ACC:96-off - The JOIN keyword (as a single email message might meet the conditions of two queries).
			Query = New Query;
			Query.Text = "
			|SELECT
			|	MessagesToImportIDs.EmailID                       AS EmailID,
			|	MessagesToImportIDs.IDAtServer                    AS IDAtServer,
			|	MessagesToImportIDs.MicrosoftOriginalLetterId AS MicrosoftOriginalLetterId
			|INTO MessagesToImportIDs
			|FROM
			|	&MessagesToImportIDs AS MessagesToImportIDs
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	EmptyIDsOfEmailMessagesToImport.HashSum,
			|	EmptyIDsOfEmailMessagesToImport.IDAtServer
			|INTO EmptyIDsOfEmailMessagesToImport
			|FROM
			|	&EmptyIDsOfEmailMessagesToImport AS EmptyIDsOfEmailMessagesToImport
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	MessagesToImportIDs.IDAtServer AS IDAtServer
			|FROM
			|	MessagesToImportIDs AS MessagesToImportIDs
			|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
			|		ON MessagesToImportIDs.EmailID = IncomingEmail.MessageID
			|			AND (IncomingEmail.Account = &Account)
			|		LEFT JOIN Document.OutgoingEmail AS OutgoingEmail
			|		ON (OutgoingEmail.Account = &Account)
			|			AND (MessagesToImportIDs.EmailID = OutgoingEmail.MessageID
			|				OR MessagesToImportIDs.EmailID = OutgoingEmail.MessageIDIMAPSending
			|				OR MessagesToImportIDs.MicrosoftOriginalLetterId = OutgoingEmail.MessageID
			|					AND OutgoingEmail.EmailStatus = VALUE(Enum.OutgoingEmailStatuses.Sent)
			|					AND OutgoingEmail.MessageID <> """")
			|WHERE
			|	IncomingEmail.Ref IS NULL
			|	AND OutgoingEmail.Ref IS NULL
			|
			|UNION
			|
			|SELECT
			|	MessagesToImportIDs.IDAtServer
			|FROM
			|	EmptyIDsOfEmailMessagesToImport AS MessagesToImportIDs
			|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
			|		ON MessagesToImportIDs.HashSum = IncomingEmail.HashSum
			|			AND (IncomingEmail.Account = &Account)
			|		LEFT JOIN Document.OutgoingEmail AS OutgoingEmail
			|		ON (OutgoingEmail.Account = &Account)
			|			AND (MessagesToImportIDs.HashSum = OutgoingEmail.HashSum)
			|WHERE
			|	IncomingEmail.Ref IS NULL
			|	AND OutgoingEmail.Ref IS NULL";
			// ACC:96-on
			
			Query.SetParameter("MessagesToImportIDs", IDsTable);
			Query.SetParameter("EmptyIDsOfEmailMessagesToImport", BlankIDsTable);
			Query.SetParameter("Account", AccountData.Ref);
			
			// @skip-check query-in-loop - Batch receipt of email messages from mail folders.
			MessagesToImportIDs = Query.Execute().Unload().UnloadColumn("IDAtServer");
			
			EmailsImportedByIDCount = GetEmailMessagesByIDs(Mail, AccountData, 
			                                                                MessagesToImportIDs, EmailsReceived);
			
			EmailsReceived1 = EmailsReceived1 + EmailsImportedByIDCount;
			
			MessageText = StrTemplate(NStr("en = 'Messages received from folder ""%1"" for %2: %3';"),
			                ActiveFolderName, AccountData.Email, EmailsImportedByIDCount); 
		
			WriteLogEvent(EventLogEvent(),
			                         EventLogLevel.Information,
			                         Metadata.Catalogs.EmailMessageFolders,
			                         ,
			                         MessageText);
		
		EndIf;
	EndDo;
	
	SetLastEmailsImportDate(AccountData.Ref, EmailsImportDate);
	
EndProcedure

Procedure GetEmailByPOP3Protocol(AccountData, Mail, EmailsReceived1, EmailsReceived)

	IDs = Mail.GetUIDL();
	If IDs.Count() = 0 And (Not AccountData.KeepCopies) Then
		// If there are no messages on the server, delete all account records from
		// the information register "ReceivedEmailIDs".
		DeleteIDsOfAllPreviouslyReceivedEmails(AccountData.Ref);
		Return;
	EndIf;

	// Define what messages must be received.
	MessagesToImportIDs = GetEmailsIDsForImport(IDs, AccountData.Ref);
	EmailsReceived1 = EmailsReceived1 + GetEmailMessagesByIDs(Mail, AccountData,
		MessagesToImportIDs, EmailsReceived, IDs);
	
	// Delete the unwanted messages from the server.
	RemoveAll = Not AccountData.KeepCopies;
	If RemoveAll Then
		MessagesToDelete = IDs;
	Else
		If AccountData.KeepDays > 0 Then
			MessagesToDelete = GetEmailsIDsToDeleteAtServer(IDs, 
				AccountData.Ref, 
				CurrentSessionDate() - AccountData.KeepDays * 24 * 60 * 60);
		Else
			MessagesToDelete = New Array;
		EndIf;
	EndIf;
	
	If MessagesToDelete.Count() <> 0 Then
		Mail.DeleteMessages(MessagesToDelete);
	EndIf;
	
	If RemoveAll Then
		DeleteIDsOfAllPreviouslyReceivedEmails(AccountData.Ref);
	Else
		DeleteIDsOfPreviouslyReceivedEmails(AccountData.Ref, IDs, MessagesToDelete);
	EndIf;

EndProcedure

Function EmailAddressesEqual(FirstAddress, SecondAddress)

	ProcessedFirstAddress = Lower(TrimAll(FirstAddress));
	ProcessedSecondAddress = Lower(TrimAll(SecondAddress));
	
	ChangeDomainInEmailAddressIfRequired(ProcessedFirstAddress);
	ChangeDomainInEmailAddressIfRequired(ProcessedSecondAddress);
	
	Return (ProcessedFirstAddress = ProcessedSecondAddress);
	
EndFunction

Function EmailAddressStructure(Email)
	
	AddressArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Email,"@");
	
	If AddressArray.Count() = 2 Then
		
		AddressStructure1 = New Structure;
		AddressStructure1.Insert("MailboxName", AddressArray[0]);
		AddressStructure1.Insert("Domain"            , AddressArray[1]);
		
		Return AddressStructure1;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns:
//  Structure:
//   * AllRecievedEmails - Array of DocumentRef.IncomingEmail
//                         - Array of DocumentRef.OutgoingEmail
//   * EmailsToDefineFolders - Array of DocumentRef.IncomingEmail
//                               - Array of DocumentRef.OutgoingEmail
//   * EmailsReceivedByAccount - Array of DocumentRef.IncomingEmail
//                                     - Array of DocumentRef.OutgoingEmail
//
Function EmailsReceived()
	
	Result = New Structure;
	Result.Insert("AllRecievedEmails",             New Array);
	Result.Insert("EmailsToDefineFolders",       New Array);
	Result.Insert("EmailsReceivedByAccount", New Array);
	Return Result;
	
EndFunction

Procedure SetLastEmailsImportDate(Account, ImportDate)

	RecordManager = InformationRegisters.LastEmailImportDate.CreateRecordManager();
	RecordManager.Account     = Account;
	RecordManager.EmailsImportDate = ImportDate;
	RecordManager.Write();

EndProcedure

Procedure SynchronizeReviewedFlagWithServer(Mail, AccountData, ImportedEmailsArray)

	If Not AccountData.MailHandledInOtherMailClient Then
		Return;
	EndIf;
	
	ArrayOfActiveFoldersNames = ActiveFoldersNames(Mail);
	
	UnreadEmailsArray = New Array;
	
	For Each ActiveFolderName In ArrayOfActiveFoldersNames Do
			
		Try
			Mail.CurrentMailbox = ActiveFolderName;
		Except
			Continue;
		EndTry;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Seen", False);
		
		Try
			ReadEmailsHeaders = Mail.GetHeaders(FilterParameters);
		Except
			Continue;
		EndTry;
		
		
		For Each EmailHeader In ReadEmailsHeaders Do
			
			UnreadEmailsArray.Add(EmailHeader.MessageID);
			
		EndDo;
			
	EndDo;
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("Id", 
	                                        New TypeDescription("String",,,,New StringQualifiers(150,AllowedLength.Variable)));
	
	CommonClientServer.SupplementTableFromArray(IDsTable,
	                                                       UnreadEmailsArray,
	                                                       "Id");
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	ReadMessageIDs.Id
	|INTO ReadMessageIDs
	|FROM
	|	&ReadMessageIDs AS ReadMessageIDs
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Interactions.Ref AS Ref,
	|	FALSE AS Reviewed
	|FROM
	|	ReadMessageIDs AS ReadMessageIDs
	|		LEFT JOIN DocumentJournal.Interactions AS Interactions
	|		ON ReadMessageIDs.Id = Interactions.MessageID
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON (Interactions.Ref = InteractionsFolderSubjects.Interaction)
	|WHERE
	|	Interactions.Account = &Account
	|	AND ISNULL(InteractionsFolderSubjects.Reviewed, FALSE) = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	Interactions.Ref,
	|	TRUE
	|FROM
	|	DocumentJournal.Interactions AS Interactions
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON Interactions.Ref = InteractionsFolderSubjects.Interaction
	|		LEFT JOIN ReadMessageIDs AS ReadMessageIDs
	|		ON ReadMessageIDs.Id = Interactions.MessageID
	|WHERE
	|	ISNULL(InteractionsFolderSubjects.Reviewed, FALSE) = FALSE
	|	AND Interactions.Account = &Account
	|	AND ReadMessageIDs.Id IS NULL";
	
	Query.SetParameter("ReadMessageIDs", IDsTable);
	Query.SetParameter("Account", AccountData.Ref);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	EmailsArrayReviewed   = New Array;
	EmailsArrayNotReviewed = New Array;
	
	Selection = Result.Select();
	
	BeginTransaction();
	Try
		
		LockAreasTable = New ValueTable;
		LockAreasTable.Columns.Add("Interaction");
		
		While Selection.Next() Do
			If Selection.Reviewed Then
				EmailsArrayReviewed.Add(Selection.Ref);
			Else
				EmailsArrayNotReviewed.Add(Selection.Ref);
			EndIf;
			NewRow = LockAreasTable.Add();
			NewRow.Interaction = Selection.Ref;
		EndDo;
		
		Block = New DataLock;
		
		LockItem = Block.Add("InformationRegister.InteractionsFolderSubjects");
		LockItem.DataSource = LockAreasTable;
		Block.Lock();
	
		HasChanges = False;
		
		Interactions.MarkAsReviewed(EmailsArrayReviewed, True, HasChanges);
		Interactions.MarkAsReviewed(EmailsArrayNotReviewed, False, HasChanges);
		
		CommonClientServer.SupplementArray(ImportedEmailsArray, EmailsArrayReviewed, False);
		CommonClientServer.SupplementArray(ImportedEmailsArray, EmailsArrayNotReviewed, False);
		
		CommitTransaction();
	
	Except
		
		RollbackTransaction();
		MessageText = NStr("en = 'Couldn''t change the message status due to: %Cause%.';");
		MessageText = StrReplace(MessageText, "%Cause%", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,
			Metadata.InformationRegisters.InteractionsFolderSubjects,
			,
			MessageText);
		
	EndTry;
	
EndProcedure

Procedure DeleteIDsOfAllPreviouslyReceivedEmails(Account)
	
	BeginTransaction();
	Try
		Block = New DataLock();
		LockItem = Block.Add("InformationRegister.ReceivedEmailIDs");
		LockItem.SetValue("Account", Account);
		Block.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	ReceivedEmailIDs.Id
		|FROM
		|	InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
		|WHERE
		|	ReceivedEmailIDs.Account = &Account";
		Query.SetParameter("Account", Account);
		
		If Not Query.Execute().IsEmpty() Then
			Set = InformationRegisters.ReceivedEmailIDs.CreateRecordSet();
			Set.Filter.Account.Set(Account);
			Set.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteIDsOfPreviouslyReceivedEmails(Account, IDsAtServer, IDsDelete)
	
	// Getting a list of IDs that do not need to be deleted.
	IDsToDelete = New Map;
	For Each Item In IDsDelete Do
		IDsToDelete.Insert(Item, True);
	EndDo;
	
	IDsKeep = New Array;
	For Each Item In IDsAtServer Do
		If IDsToDelete.Get(Item) = Undefined Then
			IDsKeep.Add(Item);
		EndIf;
	EndDo;
	
	// Getting IDs that are located in the register but have to be deleted.
	IDsTable = CreateTableWithIDs(IDsKeep);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.Text =
	"SELECT
	|	IDsTable.Id
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Account                                         AS Account,
	|	ReceivedEmailIDs.Id AS Id
	|FROM
	|	InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		LEFT JOIN IDsTable AS IDsTable
	|		ON IDsTable.Id = ReceivedEmailIDs.Id
	|WHERE
	|	IDsTable.Id IS NULL
	|	 AND ReceivedEmailIDs.Account = &Account";
	
	UUIDsTable = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ReceivedEmailIDs");
		LockItem.DataSource = UUIDsTable;
		Block.Lock();
		
		For Each TableRow In UUIDsTable Do
			Set = InformationRegisters.ReceivedEmailIDs.CreateRecordSet();
			Set.Filter.Account.Set(TableRow["Account"]);
			Set.Filter.Id.Set(TableRow["Id"]);
			Set.Write();
		EndDo;
		
		CommitTransaction();
	
	Except
		
		RollbackTransaction();
		MessageText = NStr("en = 'Could not clean up ID data due to: %Cause%.';");
		MessageText = StrReplace(MessageText, "%Cause%", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,
			Metadata.InformationRegisters.ReceivedEmailIDs,
			TableRow.Account,
			MessageText);
	
	EndTry;
	
EndProcedure

Function CreateTableWithIDs(IDs)
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("Id", New TypeDescription("String",,, New StringQualifiers(100)));
	For Each Id In IDs Do
		NewRow = IDsTable.Add();
		NewRow.Id = CommonClientServer.ReplaceProhibitedXMLChars(Id, "");
	EndDo;
	
	Return IDsTable;
	
EndFunction

Function GetEmailsIDsForImport(IDs, Account)

	// Getting the list of messages that have not been received earlier.
	IDsTable = CreateTableWithIDs(IDs);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account",          Account);
	Query.Text =
	"SELECT
	|	IDsTable.Id
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IDsTable.Id
	|FROM
	|	IDsTable AS IDsTable
	|		LEFT JOIN InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		ON IDsTable.Id = ReceivedEmailIDs.Id
	|			AND (ReceivedEmailIDs.Account = &Account)
	|WHERE
	|	ReceivedEmailIDs.Account IS NULL ";

	Return Query.Execute().Unload().UnloadColumn("Id");

EndFunction

Function GetEmailsIDsToDeleteAtServer(IDs, Account, DateToWhichToDelete)

	IDsTable = CreateTableWithIDs(IDs);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.SetParameter("DateReceived", DateToWhichToDelete);
	Query.Text =
	"SELECT
	|	IDsTable.Id
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IDsTable.Id
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		ON IDsTable.Id = ReceivedEmailIDs.Id
	|			AND (ReceivedEmailIDs.Account = &Account)
	|WHERE
	|	ReceivedEmailIDs.DateReceived <= &DateReceived";

	Return Query.Execute().Unload().UnloadColumn("Id");

EndFunction

Function WriteEmail(AccountData, Message, EmployeeResponsibleForProcessingEmails,
	PutEmailInBaseEmailFolder, AddToEmailsArrayToGetFolder, IsOutgoingEmail1);
	
	BeginTransaction();
	Try
		If IsOutgoingEmail1 Then
			MailMessage = Documents.OutgoingEmail.CreateDocument();
		Else
			MailMessage = Documents.IncomingEmail.CreateDocument();
		EndIf;
			
		FillEmailDocument(MailMessage, Message, IsOutgoingEmail1);
		MailMessage.Account = AccountData.Ref;
		SubjectAndFolder = ImportedEmailSubjectAndFolder(MailMessage, AccountData.Ref,
		                                                IsOutgoingEmail1, PutEmailInBaseEmailFolder);
		FillContactsInImportedEmail(MailMessage, IsOutgoingEmail1);
		MailMessage.EmployeeResponsible = EmployeeResponsibleForProcessingEmails;
		MailMessage.Write();
	
		If AccountData.MailHandledInOtherMailClient Then 
			ReviewedFlag = True;
		Else
			ReviewedFlag = ?(IsOutgoingEmail1, True, False);
		EndIf;
		
		Attributes = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
		Attributes.Folder                   = SubjectAndFolder.Folder;
		Attributes.SubjectOf                 = SubjectAndFolder.SubjectOf;
		Attributes.Reviewed             = ReviewedFlag;
		Attributes.CalculateReviewedItems = False;
		InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(MailMessage.Ref, Attributes);
		
		If Not AccountData.ProtocolForIncomingMail = "IMAP" Then
			WriteReceivedEmailID(AccountData.Ref, MailMessage.IDAtServer,
				Message.DateReceived);
		EndIf;
		
		If Not IsOutgoingEmail1 And MailMessage.RequestReadReceipt Then
			WriteReadReceiptProcessingRequest(MailMessage.Ref);
		EndIf;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// Write the attachment outside of the email message writing transaction
	UniqueAttachmentNames = New Map;
	For Each Attachment In Message.Attachments Do
		UniqueAttachmentNames[Attachment.FileName] = ?(UniqueAttachmentNames[Attachment.FileName] = Undefined,
			True, False);
	EndDo;
	
	NamesOfAttachments = New Array;
	For Each Attachment In Message.Attachments Do
		If UniqueAttachmentNames[Attachment.FileName] = True Then 
			NamesOfAttachments.Add(Attachment.FileName);
		EndIf;
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		AttachmentsAndSignatures = ModuleDigitalSignatureInternal.SignaturesFilesNamesOfDataFilesNames(NamesOfAttachments);
	Else
		AttachmentsAndSignatures = New Map;
		For Each AttachmentFileName In NamesOfAttachments Do
			AttachmentsAndSignatures.Insert(AttachmentFileName, New Array);
		EndDo;
	EndIf;
	
	CountOfBlankNamesInAttachments = 0;
	For Each MapItem In AttachmentsAndSignatures Do
		
		AttachmentFound = Undefined;
		SignaturesOfFile    = New Array;
		
		For Each Attachment In Message.Attachments Do
			If Attachment.FileName = MapItem.Key Then
				AttachmentFound = Attachment;
				Break;
			EndIf
		EndDo;
		
		If AttachmentFound <> Undefined And MapItem.Value.Count() > 0 Then
			For Each Attachment In Message.Attachments Do
				If MapItem.Value.Find(Attachment.FileName) <> Undefined Then
					SignaturesOfFile.Add(Attachment);
				EndIf;
			EndDo;
		EndIf;
		
		If AttachmentFound <> Undefined Then
			WriteEmailAttachment(MailMessage, AttachmentFound, SignaturesOfFile, CountOfBlankNamesInAttachments);
		EndIf;
		
	EndDo;
	
	For Each Attachment In Message.Attachments Do
		If UniqueAttachmentNames[Attachment.FileName] = False Then // Duplicated names of attachments
			WriteEmailAttachment(MailMessage, Attachment, New Array, CountOfBlankNamesInAttachments);
		EndIf;
	EndDo;
	
	If (Not PutEmailInBaseEmailFolder) Or Not ValueIsFilled(SubjectAndFolder.Folder) Then
		AddToEmailsArrayToGetFolder = True;
	EndIf;
	
	Return MailMessage.Ref;
	
EndFunction

// Fills the email message document from the Internet mail message data.
// 
// Parameters:
//  MailMessage             - DocumentObject.IncomingEmail
//                     - DocumentObject.OutgoingEmail -
//                       Email message being created.
//  Message          - InternetMailMessage - a received mail message.
//  IsOutgoingEmail1 - Boolean - indicates that the mail message is an incoming one.
//
Procedure FillEmailDocument(MailMessage, Message, IsOutgoingEmail1)
	
	SenderAddress = InternetEmailMessageSenderAddress(Message.From);
	
	If Not IsOutgoingEmail1 Then
		MailMessage.DateReceived    = Message.DateReceived;
		MailMessage.SenderAddress = SenderAddress; 
	Else
		MailMessage.EmailStatus = Enums.OutgoingEmailStatuses.Sent;
		MailMessage.PostingDate = Message.PostingDate;
	EndIf;
	
	SenderName = CommonClientServer.ReplaceProhibitedXMLChars(Message.SenderName, "");
	MailMessage.SenderPresentation = ?(IsBlankString(Message.SenderName),
		SenderAddress,
		SenderName + " <"+ SenderAddress +">");
	
	MailMessage.Importance = GetEmailImportance(Message.Importance);
	MailMessage.Date = ?(Message.PostingDate = Date(1,1,1), CurrentSessionDate(), Message.PostingDate);
	MailMessage.InternalTitle = CommonClientServer.ReplaceProhibitedXMLChars(Message.Header, "");
	MailMessage.IDAtServer = ?(Message.UID.Count() = 0, "", 
		CommonClientServer.ReplaceProhibitedXMLChars(Message.UID[0], ""));
	MailMessage.MessageID = CommonClientServer.ReplaceProhibitedXMLChars(Message.MessageID, "");
	MailMessage.Encoding = Message.Encoding;
	MailMessage.RequestDeliveryReceipt = Message.RequestDeliveryReceipt;
	MailMessage.RequestReadReceipt = Message.RequestReadReceipt;
	
	MailMessage.Size = Message.Size;
	MailMessage.Subject = CommonClientServer.ReplaceProhibitedXMLChars(Message.Subject);
	
	SetEmailText(MailMessage, Message);

	EmailOperationsInternal.DecodeAddressesInEmail(Message);
	
	FillInternetEmailAddresses(MailMessage.CCRecipients, Message.Cc);
	FillInternetEmailAddresses(MailMessage.ReplyRecipients, Message.ReplyTo);
	FillInternetEmailAddresses(MailMessage.EmailRecipients, Message.To);
	
	If IsOutgoingEmail1 Then
		FillInternetEmailAddresses(MailMessage.BccRecipients, Message.Bcc);
	Else
		FillInternetEmailAddresses(MailMessage.ReadReceiptAddresses, Message.ReadReceiptAddresses);
	EndIf;
	
	MailMessage.BasisID    = StringFieldFromEmailHeader(Message, "In-Reply-To");
	MailMessage.BasisIDs   = StringFieldFromEmailHeader(Message, "References");
	MailMessage.HashSum                  = EmailMessageHashSum(Message);
	
	For Each Attachment In Message.Attachments Do
		If IsBlankString(Attachment.CID) Or StrFind(MailMessage.HTMLText, Attachment.CID) = 0 Then
			MailMessage.HasAttachments = True;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

Function EmailMessageHashSum(Message)
	
	Return Common.CheckSumString(TrimAll(Message.Header), HashFunction.CRC32);
	
EndFunction

Function ImportedEmailSubjectAndFolder(MailMessage, Account, IsOutgoingEmail1, PutEmailInBaseEmailFolder)
	
	Result = New Structure("SubjectOf,Folder", MailMessage.Ref, Undefined);
	
	// Get the IDs of the base messages.
	ArrayOfIdentifiers = New Array;
	IDsString = MailMessage.BasisIDs;
	While Not IsBlankString(IDsString) Do
		Position = StrFind(IDsString, "<");
		If Position = 0 Then
			Break;
		EndIf;
		IDsString = Mid(IDsString, Position+1);
		
		Position = StrFind(IDsString, ">");
		If Position = 0 Then
			Break;
		EndIf;
		
		CurrentID = TrimAll(Left(IDsString, Position-1));
		IDsString = TrimAll(Mid(IDsString, Position+1));
		
		If Not IsBlankString(CurrentID) Then
			ArrayOfIdentifiers.Add(CurrentID);
		EndIf;
	EndDo;
	
	If (ArrayOfIdentifiers.Find(MailMessage.BasisID) = Undefined) 
		And (Not IsBlankString(MailMessage.BasisID)) Then
		ArrayOfIdentifiers.Add(MailMessage.BasisID);
	EndIf;
	
	If ArrayOfIdentifiers.Find(MailMessage.MessageID) = Undefined 
		And Not IsBlankString(MailMessage.MessageID) Then
		ArrayOfIdentifiers.Add(MailMessage.MessageID);
	EndIf; 
	
	If ArrayOfIdentifiers.Count() = 0 Then
		Return Result;
	EndIf;
	
	IDsTable = CreateTableWithIDs(ArrayOfIdentifiers);
	
	// Get all the base messages
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDsTable.Id
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|INDEX BY
	|	Id
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncomingEmail.Ref AS Ref,
	|	IncomingEmail.Date   AS Date,
	|	0                                AS Priority
	|INTO AllEmailMessages
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN Document.IncomingEmail AS IncomingEmail
	|		ON IDsTable.Id = IncomingEmail.MessageID
	|WHERE
	|	IncomingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref AS Ref,
	|	OutgoingEmail.Date   AS Date,
	|	0                                 AS Priority
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON IDsTable.Id = OutgoingEmail.MessageID
	|WHERE
	|	OutgoingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref AS Ref,
	|	IncomingEmail.Date   AS Date,
	|	1                                AS Priority
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|WHERE
	|	IncomingEmail.Account = &Account
	|	AND IncomingEmail.BasisID = &MessageID
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref AS Ref,
	|	OutgoingEmail.Date   AS Date,
	|	1                                 AS Priority
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Account = &Account
	|	AND OutgoingEmail.BasisID = &MessageID
	|
	|INDEX BY
	|Ref
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AllEmailMessages.Ref,
	|	AllEmailMessages.Priority,
	|	AllEmailMessages.Date AS Date,
	|	ISNULL(InteractionsFolderSubjects.SubjectOf, UNDEFINED) AS SubjectOf,
	|	ISNULL(InteractionsFolderSubjects.EmailMessageFolder, VALUE(Catalog.EmailMessageFolders.EmptyRef)) AS Folder,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, FALSE) AS PredefinedFolder
	|FROM
	|	AllEmailMessages AS AllEmailMessages
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON AllEmailMessages.Ref = InteractionsFolderSubjects.Interaction
	|		LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|		ON (InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref)
	|
	|ORDER BY
	|	AllEmailMessages.Priority ASC,
	|	Date DESC";
	
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.SetParameter("MessageID", MailMessage.MessageID);
	
	RequestExecutionStarts = CurrentUniversalDateInMilliseconds();
	Selection = Query.Execute().Select();
	QueryExecutionTime =  Round((CurrentUniversalDateInMilliseconds() - RequestExecutionStarts)/1000, 2);
	
	If QueryExecutionTime > 1 Then
		
		LogRecordText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The request to retrieve parent email data for the loaded email took more than %1 seconds, which is longer than expected.';"),
			QueryExecutionTime);
		WriteLogEvent(EventLogEvent(), EventLogLevel.Information,
			MailMessage, LogRecordText);
		
	EndIf;
	
	If Selection.Next() Then
		
		Result.SubjectOf = Selection.SubjectOf;
		If Selection.Priority = 0 Then
			MailMessage.InteractionBasis = Selection.Ref;
			If PutEmailInBaseEmailFolder And Not Selection.PredefinedFolder Then
				Result.Folder = Selection.Folder;
			EndIf;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillContactsInImportedEmail(MailMessage, IsOutgoingEmail1)
	
	ContactsMap = ContactsInEmailMap(MailMessage.InteractionBasis);

	UndefinedAddresses = New Array;
	SetContactInEmail(MailMessage, ContactsMap, UndefinedAddresses, IsOutgoingEmail1);

	// If some of the addresses are undefined, search them in the contact information.
	ContactsMap = FindEmailsInContactInformation(UndefinedAddresses);
	If ContactsMap.Count() > 0 Then
		SetContactInEmail(MailMessage, ContactsMap, UndefinedAddresses, IsOutgoingEmail1);
	EndIf;
	
	MailMessage.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(MailMessage.EmailRecipients, False);
	MailMessage.CcRecipientsList  = InteractionsClientServer.GetAddressesListPresentation(MailMessage.CCRecipients, False);
	If TypeOf(MailMessage) = Type("DocumentObject.OutgoingEmail") Then
		MailMessage.BccRecipientsList  = InteractionsClientServer.GetAddressesListPresentation(MailMessage.CCRecipients, False);
	EndIf;
	
EndProcedure

Function FindEmailsInContactInformation(AddressesArray)

	ContactsMap = New Map;

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Contacts.Ref,
	|	Contacts.EMAddress AS EMAddress
	|FROM
	|	(SELECT
	|		ContactInformation.Ref AS Ref,
	|		ContactInformation.EMAddress AS EMAddress
	|	FROM
	|		Catalog.Users.ContactInformation AS ContactInformation
	|	WHERE
	|		ContactInformation.EMAddress IN(&AddressesArray)
	|		AND ContactInformation.Type = &Type
	|		AND NOT(ContactInformation.Ref.DeletionMark)
	|		AND &TheTextOfTheQueryTheOtherTypesOfContacts)AS Contacts
	|TOTALS BY
	|	EMAddress
	|";
	
	TheTextOfTheQueryTheOtherTypesOfContacts = "";
	ContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	For Each DetailsArrayElement In ContactsTypesDetailsArray Do
		
		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;	
		
		TheTextOfTheQueryTheOtherTypesOfContacts = TheTextOfTheQueryTheOtherTypesOfContacts + "
		|UNION ALL
		|";
		
		TheTextOfTheQueryTheOtherTypesOfContacts = TheTextOfTheQueryTheOtherTypesOfContacts + "
		|SELECT
		|		ContactInformation.Ref AS Ref,
		|		ContactInformation.EMAddress AS EMAddress
		|FROM
		|	&ContactInformationTable AS ContactInformation
		|WHERE
		|	ContactInformation.EMAddress IN(&AddressesArray)
		|	AND ContactInformation.Type = &Type
		|	AND (NOT ContactInformation.Ref.DeletionMark)
		|";
		
		TheTextOfTheQueryTheOtherTypesOfContacts = StrReplace(TheTextOfTheQueryTheOtherTypesOfContacts, "&ContactInformationTable", "Catalog." + DetailsArrayElement.Name + ".ContactInformation");
		
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "AND &TheTextOfTheQueryTheOtherTypesOfContacts", TheTextOfTheQueryTheOtherTypesOfContacts);

	Query.SetParameter("AddressesArray", AddressesArray);
	Query.SetParameter("Type", Enums.ContactInformationTypes.Email);
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		SelectionByRefs = Selection.Select(QueryResultIteration.ByGroups);
		If (SelectionByRefs.Next()) Then
			ContactsMap.Insert(Upper(Selection.EMAddress), SelectionByRefs.Ref);
		EndIf;
	EndDo;

	Return ContactsMap;

EndFunction

Procedure SetContactInEmail(MailMessage, ContactsMap, UndefinedAddresses, IsOutgoingEmail1)
	
	For Each TableRow In MailMessage.EmailRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	For Each TableRow In MailMessage.CCRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	For Each TableRow In MailMessage.ReplyRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	If IsOutgoingEmail1 Then
		For Each TableRow In MailMessage.BccRecipients Do
			ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
		EndDo;
	Else
		ProcessContactAndAddressFields(MailMessage.SenderAddress, MailMessage.SenderContact, ContactsMap, UndefinedAddresses);
	EndIf;

EndProcedure

Procedure ProcessContactAndAddressFields(Address, Contact, ContactsMap, UndefinedAddresses)
	
	If ValueIsFilled(Contact) And TypeOf(Contact) <> Type("String") Then
		Return;
	EndIf;
	
	FoundContact = ContactsMap.Get(Upper(Address));
	If FoundContact <> Undefined And TypeOf(FoundContact) <> Type("String") Then
		Contact = FoundContact;
		Return;
	EndIf;
	
	If UndefinedAddresses.Find(Address) = Undefined Then
		UndefinedAddresses.Add(Address);
	EndIf;
	
EndProcedure

Function ContactsInEmailMap(MailMessage)
	
	ContactsMap = New Map;
	If Not ValueIsFilled(MailMessage) Then
		Return ContactsMap;
	EndIf;
	
	If TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		QueryTextSender = "
		|	
		|	UNION ALL
		|	
		|";
		
		QueryTextSender = QueryTextSender + "
		|SELECT
		|		IncomingEmail.SenderAddress   AS Address,
		|		IncomingEmail.SenderContact AS Contact
		|	FROM
		|		Document.IncomingEmail AS IncomingEmail
		|	WHERE
		|		IncomingEmail.Ref = &MailMessage";
		
	Else
		
		QueryTextSender = "";
		
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Addresses.Address,
	|	Addresses.Contact
	|FROM
	|	(SELECT
	|		Recipients.Address    AS Address,
	|		Recipients.Contact  AS Contact
	|	FROM
	|		&NameOfTheMessageRecipientsTable AS Recipients
	|	WHERE
	|		Recipients.Ref = &MailMessage
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Recipients.Address,
	|		Recipients.Contact
	|	FROM
	|		&NameOfTheCopyRecipientsTable  AS Recipients
	|	WHERE
	|		Recipients.Ref = &MailMessage
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Recipients.Address,
	|		Recipients.Contact
	|	FROM
	|		&TheNameOfTheTableRecipientsResponse AS Recipients
	|	WHERE
	|		Recipients.Ref = &MailMessage AND &QueryTextSender) AS Addresses";
	
	Query.Text = StrReplace(Query.Text, "AND &QueryTextSender", QueryTextSender);
	Query.SetParameter("MailMessage", MailMessage);
	
	If TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		Query.Text = StrReplace(Query.Text, "&NameOfTheMessageRecipientsTable", "Document.OutgoingEmail.EmailRecipients");
		Query.Text = StrReplace(Query.Text, "&NameOfTheCopyRecipientsTable", "Document.OutgoingEmail.CCRecipients");
		Query.Text = StrReplace(Query.Text, "&TheNameOfTheTableRecipientsResponse", "Document.OutgoingEmail.ReplyRecipients");
	Else
		Query.Text = StrReplace(Query.Text, "&NameOfTheMessageRecipientsTable", "Document.IncomingEmail.EmailRecipients");
		Query.Text = StrReplace(Query.Text, "&NameOfTheCopyRecipientsTable", "Document.IncomingEmail.CCRecipients");
		Query.Text = StrReplace(Query.Text, "&TheNameOfTheTableRecipientsResponse", "Document.IncomingEmail.ReplyRecipients");
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If TypeOf(Selection.Contact) <> Type("String") Then
			ContactsMap.Insert(Selection.Address, Selection.Contact);
		EndIf;
	EndDo;

	Return ContactsMap;
	
EndFunction

Procedure WriteReceivedEmailID(Account, Id, DateReceived)

	Record = InformationRegisters.ReceivedEmailIDs.CreateRecordManager();
	Record.Account = Account;
	Record.Id = Id;
	Record.DateReceived = DateReceived;
	Record.Write();

EndProcedure

Function StringFieldFromEmailHeader(Message, TitleName)
	
	IDsString = TrimAll(Message.GetField(TitleName, "String"));
	
	If IsBlankString(IDsString) Then 
		
		IDsString = EmailHeaderField(Message.Header, TitleName); 
		
	EndIf;

	Position = StrFind(IDsString, "<");
	If Position <> 0 Then
		IDsString = Mid(IDsString, Position+1);
	EndIf;
	
	Position = StrFind(IDsString, ">");
	If Position <> 0 Then
		IDsString = Left(IDsString, Position-1);
	EndIf;
	
	Return IDsString;
	
EndFunction

Function EmailHeaderField(MessageTitle, TitleField)
	
	TitleField = TitleField + ":";
	
	RowsArray = StrSplit(MessageTitle, Chars.LF);
	
	For Each TitleLine In RowsArray Do
		
		If StrStartsWith(TitleLine, TitleField) Then
			Return TrimAll(Right(TitleLine, StrLen(TitleLine) - StrLen(TitleField))); 
		EndIf;
		
	EndDo;
	
EndFunction

Procedure SetEmailText(MailMessage, Message) Export
	
	HTMLText = "";
	PlainText = "";
	RichText = "";

	For Each EmailText1 In Message.Texts Do
		If EmailText1.TextType = InternetMailTextType.HTML Then
			
			HTMLText = HTMLText + CommonClientServer.ReplaceProhibitedXMLChars(EmailText1.Text);
			
		ElsIf EmailText1.TextType = InternetMailTextType.PlainText Then
			
			PlainText = PlainText + CommonClientServer.ReplaceProhibitedXMLChars(EmailText1.Text);
			
		ElsIf EmailText1.TextType = InternetMailTextType.RichText Then
			RichText = CommonClientServer.ReplaceProhibitedXMLChars(EmailText1.Text);
			
		EndIf;
	EndDo;
	
	If HTMLText <> "" Then
		MailMessage.TextType = Enums.EmailTextTypes.HTML;
		MailMessage.HTMLText = HTMLText;
		MailMessage.Text = ?(PlainText <> "", PlainText, GetPlainTextFromHTML1(HTMLText));
		
	ElsIf RichText <> "" Then
		MailMessage.TextType = Enums.EmailTextTypes.RichText;
		MailMessage.Text = RichText;
		
	Else
		MailMessage.TextType = Enums.EmailTextTypes.PlainText;
		MailMessage.Text = PlainText;
		
	EndIf;
	
EndProcedure

Function InternetEmailMessageSenderAddress(Sender)
	
	If TypeOf(Sender) = Type("InternetMailAddress") Then
		SenderAddress = Sender.Address;
	Else
		SenderAddress = Sender;
	EndIf;
	
	Return CommonClientServer.ReplaceProhibitedXMLChars(SenderAddress, "");
	
EndFunction

Procedure ChangeDomainInEmailAddressIfRequired(MailAddress)
	
	EmailDomainsSynonyms = New Map;
	
	InteractionsLocalization.OnDefineEmailDomainSynonyms(EmailDomainsSynonyms);
	
	If EmailDomainsSynonyms.Count() = 0 Then
		Return;
	EndIf;
	
	AddressStructure1 =  EmailAddressStructure(MailAddress);
	If AddressStructure1 = Undefined Then
		Return;
	EndIf;
	
	DomainToReplaceWith = EmailDomainsSynonyms[AddressStructure1.Domain];
	If DomainToReplaceWith <> Undefined Then
		MailAddress = AddressStructure1.MailboxName + "@" + DomainToReplaceWith;
	EndIf;

EndProcedure

Function ActiveFoldersNames(Mail)

	Result = New Array;
	 
	ActiveFoldersNames     = Mail.GetMailboxesBySubscription();
	If ActiveFoldersNames.Count() = 0 Then
		ActiveFoldersNames = Mail.GetMailboxes();
	EndIf;
	
	Separator = ""; 
	Try
		Separator = Mail.DelimeterChar;
	Except
		// ACC:280 - Some email servers do not support this command.
	EndTry;
	
	IgnorableNamesArray  = FolderNamesIgnoredOnEmailsReceipt();
	
	For Each ActiveFolderName In ActiveFoldersNames Do
		
		If Not IsBlankString(Separator) Then
			
			FolderNameStringsArray = StringFunctionsClientServer.SplitStringIntoWordArray(ActiveFolderName,Separator);
			If FolderNameStringsArray.Count() = 0 Then
				Continue;
			EndIf;
			FolderNameWithoutSeparator = FolderNameStringsArray[FolderNameStringsArray.Count()-1];
			If IsBlankString(FolderNameWithoutSeparator) Then
				Continue;
			EndIf;
			If Left(FolderNameWithoutSeparator,1) = "[" And Right(FolderNameWithoutSeparator,1) = "]" Then
				Continue;
			EndIf;
			
			If IgnorableNamesArray.Find(Lower(FolderNameWithoutSeparator)) <> Undefined Then
				Continue;
			EndIf;
			
		Else
			
			If Left(ActiveFolderName,1) = "[" And Right(ActiveFolderName,1) = "]" Then
				Continue;
			EndIf;
			
			If IgnorableNamesArray.Find(Lower(ActiveFolderName)) <> Undefined Then
				Continue;
			EndIf;
			
		EndIf;
		
		Result.Add(ActiveFolderName);
		
	EndDo;

	Return Result;
	
EndFunction

Function FolderNamesIgnoredOnEmailsReceipt()

	FoldersNames = New Array;
	FoldersNames.Add("spam");
	FoldersNames.Add("trash");
	FoldersNames.Add("drafts");
	FoldersNames.Add("draftBox");
	FoldersNames.Add("deleted");
	FoldersNames.Add("junk");
	FoldersNames.Add("bulk mail");
	
	InteractionsLocalization.OnDefineFolderNamesIgnoredOnEmailsReceipt(FoldersNames); 
	
	Return FoldersNames;

EndFunction

Procedure DeterminePreviouslyImportedSubordinateEmails(Account, EmailsReceived);
	
	If EmailsReceived.Count() = 0 Then
		Return;
	EndIf;
	
	ArrayOfEmailsToAddToProcessing = New Array;
	OutgoingEmailMetadata = Metadata.Documents.OutgoingEmail;
	IncomingEmailMetadata = Metadata.Documents.IncomingEmail;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.Ref,
	|	OutgoingEmail.MessageID
	|INTO ReceivedMessagesIDs
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Ref IN(&EmailsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.MessageID
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|WHERE
	|	IncomingEmail.Ref IN(&EmailsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OutgoingEmail.Ref                                      AS MailMessage,
	|	OutgoingEmail.InteractionBasis                     AS CurrentBasis,
	|	ReceivedMessagesIDs.Ref                                  AS BaseEmailRef,
	|	ISNULL(InteractionFolderSubjectsBasis.SubjectOf, UNDEFINED)   AS BasisEmailSubject,
	|	ISNULL(InteractionFolderSubjectsSubordinate.SubjectOf, UNDEFINED) AS EmailSubjectSubordinate
	|FROM
	|	ReceivedMessagesIDs AS ReceivedMessagesIDs
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON ReceivedMessagesIDs.MessageID = OutgoingEmail.BasisID
	|			AND (OutgoingEmail.InteractionBasis <> ReceivedMessagesIDs.Ref)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsSubordinate
	|		ON (OutgoingEmail.Ref = InteractionFolderSubjectsSubordinate.Interaction)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsBasis
	|		ON ReceivedMessagesIDs.Ref = InteractionFolderSubjectsBasis.Interaction
	|WHERE
	|	OutgoingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.InteractionBasis,
	|	ReceivedMessagesIDs.Ref,
	|	ISNULL(InteractionFolderSubjectsBasis.SubjectOf, UNDEFINED),
	|	ISNULL(InteractionFolderSubjectsSubordinate.SubjectOf, UNDEFINED) 
	|FROM
	|	ReceivedMessagesIDs AS ReceivedMessagesIDs
	|		INNER JOIN Document.IncomingEmail AS IncomingEmail
	|		ON ReceivedMessagesIDs.MessageID = IncomingEmail.BasisID
	|			AND (IncomingEmail.InteractionBasis <> ReceivedMessagesIDs.Ref)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsSubordinate
	|		ON (IncomingEmail.Ref = InteractionFolderSubjectsSubordinate.Interaction)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsBasis
	|		ON ReceivedMessagesIDs.Ref = InteractionFolderSubjectsBasis.Interaction
	|WHERE
	|	IncomingEmail.Account = &Account";
	
	Query.SetParameter("Account", Account);
	Query.SetParameter("EmailsArray", EmailsReceived);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		
		Try
			
			MetadataOfDocument = ?(TypeOf(Selection.MailMessage) = Type("DocumentRef.IncomingEmail"),
			                        IncomingEmailMetadata, OutgoingEmailMetadata);
			
			Block = New DataLock;
			LockItem = Block.Add(MetadataOfDocument.FullName());
			LockItem.SetValue("Ref", Selection.MailMessage);
			InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, Selection.MailMessage);
			InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Block, Selection.BaseEmailRef);
			Block.Lock();
			
			EmailObject = Selection.MailMessage.GetObject(); // DocumentObject.IncomingEmail, DocumentObject.OutgoingEmail - 
				EmailObject.InteractionBasis = Selection.BaseEmailRef;
			EmailObject.Write();
			
			If Selection.BasisEmailSubject <> Selection.EmailSubjectSubordinate Then
				
				If Selection.EmailSubjectSubordinate = Selection.MailMessage Then
					
					Interactions.SetSubject(Selection.MailMessage, Selection.BasisEmailSubject, False);
					
				ElsIf Not InteractionsClientServer.IsSubject(Selection.EmailSubjectSubordinate) Then
					
					If InteractionsClientServer.IsSubject(Selection.BasisEmailSubject) Then
						Interactions.SetSubject(Selection.MailMessage, Selection.BasisEmailSubject, False);
						ArrayOfEmailsToAddToProcessing.Add(Selection.MailMessage);
					Else 
						Interactions.SetSubject(Selection.BaseEmailRef, Selection.EmailSubjectSubordinate, False);
					EndIf;
					
				EndIf;
				
			EndIf;
			
			CommitTransaction();
		
		Except
			RollbackTransaction();
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Could not identify the original message for %1 due to: %2';"), 
				Selection.MailMessage, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
				MetadataOfDocument, Selection.MailMessage, MessageText);
		EndTry;
	
	EndDo;
	 
	CommonClientServer.SupplementArray(EmailsReceived, ArrayOfEmailsToAddToProcessing, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with email attachments.

Function InternetEmailMessageFromBinaryData(BinaryData) 
	
	MailMessage = New InternetMailMessage;
	MailMessage.SetSourceData(BinaryData);
	
	Return MailMessage;
	
EndFunction

Procedure WriteEmailAttachment(Object, Attachment, AttachmentSignatures, CountOfBlankNamesInAttachments)
	
	EmailRef = Object.Ref;
	Size = 0;
	IsAttachmentEmail = False;
	
	If TypeOf(Attachment.Data) = Type("BinaryData") Then
		
		AttachmentData = Attachment.Data;
		FileName = CommonClientServer.ReplaceProhibitedXMLChars(Attachment.FileName, "");
		IsAttachmentEmail = FileIsEmail(FileName, AttachmentData);
		
	Else
		
		AttachmentData = Attachment.Data.GetSourceData();
		FileName = Interactions.EmailPresentation(Attachment.Data.Subject, Attachment.Data.DateReceived) + ".eml";
		IsAttachmentEmail = True;
		
	EndIf;
	
	Size = AttachmentData.Size();
	Address = PutToTempStorage(AttachmentData, "");
	
	If Not IsBlankString(Attachment.CID) Then
		
		If StrFind(Object.HTMLText, Attachment.CID) = 0 
			Or (StrFind(Object.HTMLText, Attachment.Name) > 0 
			And StrFind(Attachment.CID, Attachment.Name + "@") = 0
			And StrFind(Object.HTMLText, "alt=" + """" + Attachment.Name + """") = 0) Then
			
			Attachment.CID = "";
			
		EndIf;
		
	EndIf;
	
	HasSignatures = (AttachmentSignatures.Count() > 0)
		And Common.SubsystemExists("StandardSubsystems.DigitalSignature");
		
	IsDisplayedFile = Not IsBlankString(Attachment.CID);
	
	AttachmentParameters = New Structure;
	AttachmentParameters.Insert("FileName", FileName);
	AttachmentParameters.Insert("Size", Size);
	If IsDisplayedFile Then
		AttachmentParameters.Insert("EmailFileID", Attachment.CID);
	EndIf;
	If IsAttachmentEmail Then
		AttachmentParameters.Insert("IsAttachmentEmail", True);
	EndIf;
	If HasSignatures Then
		AttachmentParameters.Insert("SignedWithDS", True);
	EndIf;
	
	If StrEndsWith(Lower(FileName), "." + Lower(EncryptedFilesExtension())) Then
		
		Encrypted = True;
		If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
			ModuleDigitalSignatureInternalClientServer = Common.CommonModule("DigitalSignatureInternalClientServer");
			DataType = ModuleDigitalSignatureInternalClientServer.DefineDataType(AttachmentData);
			If DataType <> "EncryptedData" Then
				Encrypted = False;
			EndIf;
		EndIf;
		
		If Encrypted Then
			AttachmentParameters.Insert("Encrypted", Encrypted);
			AttachmentParameters.Insert("FileName", Left(FileName, StrLen(FileName) - 4));
		EndIf;
		
	EndIf;
	
	EmailAttachmentRef = WriteEmailAttachmentFromTempStorage(
		EmailRef, Address, AttachmentParameters, CountOfBlankNamesInAttachments);
	
	If HasSignatures Then

		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		ModuleDigitalSignatureClientServer= Common.CommonModule("DigitalSignatureClientServer");
		
		For Each AttachmentsSignature In AttachmentSignatures Do
			
			Try
				AttachmentSignatureData = ModuleDigitalSignature.DERSignature(AttachmentsSignature.Data);
			Except
				EventText = NStr("en = 'Cannot read the %1 attachment signature data: %2';");
				ErrorSignatureDataCouldNotBeRead = StringFunctionsClientServer.SubstituteParametersToString(
					EventText, EmailAttachmentRef, ErrorProcessing.BriefErrorDescription(ErrorInfo()));
				WriteLogEvent(EventLogEvent(), EventLogLevel.Information, , , ErrorSignatureDataCouldNotBeRead);
				Continue;
			EndTry;
			
			SignatureData = ModuleDigitalSignatureClientServer.NewSignatureProperties();
			SignatureData.Signature = AttachmentSignatureData;
			ResultOfReadSignatureProperties = ModuleDigitalSignature.SignatureProperties(AttachmentSignatureData);
			
			If ResultOfReadSignatureProperties.Success <> False Then
				FillPropertyValues(SignatureData, ResultOfReadSignatureProperties);
				SignatureData.Insert("DateSignedFromLabels", ResultOfReadSignatureProperties.DateSignedFromLabels);
				SignatureData.Insert("UnverifiedSignatureDate", ResultOfReadSignatureProperties.UnverifiedSignatureDate);
			Else
				EventText = NStr("en = 'Cannot read the %1 attachment signature data: %2';");
				ErrorSignatureDataCouldNotBeRead = StringFunctionsClientServer.SubstituteParametersToString(
					EventText, EmailAttachmentRef, ResultOfReadSignatureProperties.ErrorText);
				WriteLogEvent(EventLogEvent(), EventLogLevel.Information, , , ErrorSignatureDataCouldNotBeRead);
				Continue;
			EndIf;
			
			SignatureData.Comment = NStr("en = 'Email attachment';");
			
			FilesOperations.AddSignatureToFile(EmailAttachmentRef, SignatureData);
			
		EndDo;
	
	EndIf;
	
	DeleteFromTempStorage(Address);
	
EndProcedure

// Parameters:
//  MailMessage                         - DocumentRef - an email document, whose attachments need to be received.
//  GenerateSizePresentation - Boolean - indicates that the blank SizePresentation string column will be the query result.
//  OnlyWithBlankID                - Boolean - if True, only attachments without EmailFileID will be got.
//
// Returns:
//  ValueTable:
//     * Ref                    - CatalogRef.IncomingEmailAttachedFiles
//                                 - CatalogRef.OutgoingEmailAttachedFiles - 
//                                   Reference to the attachment.
//     * PictureIndex            - Number  - the displayed picture number.
//     * SignedWithDS                - Boolean - indicates whether the file is signed with a digital signature.
//     * Size                    - Number  - file size.
//     * EmailFileID - String - an ID of the picture displayed in the message body.
//     * FileName                  - String - file name.
//     * SizePresentation       - String - size presentation.
//
Function GetEmailAttachments(MailMessage,GenerateSizePresentation = False, OnlyWithBlankID = False) Export
	
	SetPrivilegedMode(True);
	
	AttachedEmailFilesData = Interactions.AttachedEmailFilesData(MailMessage);
	MetadataObjectName = AttachedEmailFilesData.AttachedFilesCatalogName;
	FilesOwner       = AttachedEmailFilesData.FilesOwner;
	
	If MetadataObjectName = Undefined Then
		Return New ValueTable;
	EndIf;
	
	If GenerateSizePresentation Then
		TextSizePresentation = ",
		|CAST("""" AS STRING(20)) AS SizePresentation";
	Else
		TextSizePresentation = "";
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref                    AS Ref,
	|	Files.PictureIndex            AS PictureIndex,
	|	Files.Size                    AS Size,
	|	Files.EmailFileID AS EmailFileID,
	|	&SignedWithDS                     AS SignedWithDS,
	|	CASE
	|		WHEN Files.Extension = &IsBlankString
	|			THEN Files.Description
	|		ELSE Files.Description + ""."" + Files.Extension
	|	END AS FileName" + TextSizePresentation + "
	|FROM
	|	Catalog." + MetadataObjectName + " AS Files
	|WHERE
	|	Files.FileOwner = &MailMessage
	|	AND NOT Files.DeletionMark";
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		DigitallySignedString = "Files.SignedWithDS";
	Else
		DigitallySignedString = "FALSE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SignedWithDS", DigitallySignedString);
	
	If OnlyWithBlankID Then
		Query.Text = Query.Text + "
		| AND Files.EmailFileID = """""; 
	EndIf;
	
	Query.SetParameter("MailMessage", FilesOwner);
	Query.SetParameter("IsBlankString","");
	
	TableForReturn =  Query.Execute().Unload(); // See GetEmailAttachments
	
	If GenerateSizePresentation Then
		For Each TableRow In TableForReturn Do
		
			TableRow.SizePresentation = 
				InteractionsClientServer.GetFileSizeStringPresentation(TableRow.Size);
		
		EndDo;
	EndIf;
	
	TableForReturn.Indexes.Add("EmailFileID");
	
	Return TableForReturn;
	
EndFunction

// Parameters:
//  MailMessage                          - DocumentRef.IncomingEmail
//                                  - DocumentRef.OutgoingEmail -
//                                       Email message whose attachment is being written.
//  AddressInTempStorage       - String - the address of the temporary storage where the attachment is placed.
//  AttachmentParameters               - Structure:
//     * FileName                  - String - an attachment file name.
//     * EmailFileID - String - an attachment ID.
//     * IsAttachmentEmail         - Boolean - determines whether the attachment is a mail message.
//     * SignedWithDS                - Boolean - determines whether the attachment is signed with a digital signature.
//  CountOfBlankNamesInAttachments - Number - the amount of mail attachments with no name.
//
// Returns:
//  CatalogRef.IncomingEmailAttachedFiles
//  CatalogRef.OutgoingEmailAttachedFiles
//
Function WriteEmailAttachmentFromTempStorage(MailMessage, AddressInTempStorage,
	AttachmentParameters, CountOfBlankNamesInAttachments = 0) Export
	
	FileNameToParse = AttachmentParameters.FileName;
	BaseName   = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
	ExtensionWithoutPoint = CommonClientServer.GetFileNameExtension(BaseName);
	
	If IsBlankString(BaseName) Then
		
		BaseName = NStr("en = 'Untitled attachment';") 
			+ ?(CountOfBlankNamesInAttachments = 0, ""," " + String(CountOfBlankNamesInAttachments + 1));
		CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
		
	Else
		BaseName = ?(ExtensionWithoutPoint = "", BaseName,
			Left(BaseName, StrLen(BaseName) - StrLen(ExtensionWithoutPoint) - 1));
	EndIf;
	
	AdditionalParameters = New Array;
	If AttachmentParameters.Property("EmailFileID") Then
		AdditionalParameters.Add("EmailFileID");
	EndIf;
	If AttachmentParameters.Property("IsAttachmentEmail") Then
		AdditionalParameters.Add("IsAttachmentEmail");
	EndIf;
	If AttachmentParameters.Property("SignedWithDS") Then
		AdditionalParameters.Add("SignedWithDS");
	EndIf;
	If AttachmentParameters.Property("Encrypted") Then
		AdditionalParameters.Add("Encrypted");
	Else
		If StrEndsWith(Lower(FileNameToParse), "." + Lower(EncryptedFilesExtension())) Then
			
			Encrypted = True;
			If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
				ModuleDigitalSignatureInternalClientServer = Common.CommonModule("DigitalSignatureInternalClientServer");
				DataType = ModuleDigitalSignatureInternalClientServer.DefineDataType(AddressInTempStorage);
				If DataType <> "EncryptedData" Then
					Encrypted = False;
				EndIf;
			EndIf;
			
			If Encrypted Then
				AdditionalParameters.Add("Encrypted");
				AttachmentParameters.Insert("Encrypted", Encrypted);
				
				ExtensionWithoutPoint = CommonClientServer.GetFileNameExtension(BaseName);
				BaseName = ?(ExtensionWithoutPoint = "", BaseName,
					Left(BaseName, StrLen(BaseName) - StrLen(ExtensionWithoutPoint) - 1));

			EndIf;
			
		EndIf;
	EndIf;
	
	FileParameters = FilesOperations.FileAddingOptions(AdditionalParameters);
	FileParameters.FilesOwner = MailMessage;
	FileParameters.BaseName = BaseName;
	FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
	FileParameters.ModificationTimeUniversal = Undefined;
	
	If AttachmentParameters.Property("EmailFileID") Then
		FileParameters.EmailFileID = AttachmentParameters.EmailFileID;
	EndIf;
	If AttachmentParameters.Property("IsAttachmentEmail") Then
		FileParameters.IsAttachmentEmail = AttachmentParameters.IsAttachmentEmail;
	EndIf;
	If AttachmentParameters.Property("SignedWithDS") Then
		FileParameters.SignedWithDS = AttachmentParameters.SignedWithDS;
	EndIf;
	If AttachmentParameters.Property("Encrypted") Then
		FileParameters.Encrypted = AttachmentParameters.Encrypted;
	EndIf;
	
	Return FilesOperations.AppendFile(
		FileParameters,
		AddressInTempStorage,
		"");

EndFunction

Function WriteEmailAttachmentByCopyOtherEmailAttachment(
	MailMessage,
	FileRef,
	FormUniqueID) Export
	
	FileData = FilesOperations.FileData(
		FileRef, FormUniqueID, True);
	
	FileParameters = FilesOperations.FileAddingOptions();
	FileParameters.FilesOwner = MailMessage;
	FileParameters.BaseName = FileData.Description;
	FileParameters.ExtensionWithoutPoint = FileData.Extension;
	FileParameters.ModificationTimeUniversal = FileData.UniversalModificationDate;
	
	Return FilesOperations.AppendFile(
		FileParameters,
		FileData.RefToBinaryFileData,
		"");
	
EndFunction

// Parameters:
//  MailMessage - DocumentRef - an email, whose attachments will be deleted.
//
Procedure DeleteEmailAttachments(MailMessage) Export

	MetadataObjectName = MetadataObjectNameOfAttachedEmailFiles(MailMessage);
	If MetadataObjectName = Undefined Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog." + MetadataObjectName);
	LockItem.SetValue("FileOwner", MailMessage);
	Block.Lock();

	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	&CatalogName AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	
	Query.Text = StrReplace(Query.Text, "&CatalogName", "Catalog." + MetadataObjectName);
	
	Query.SetParameter("FileOwner", MailMessage);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.Delete();
	EndDo;
	
EndProcedure

// Checks if binary data upon deserialization is InternetMailMessage.
//
// Parameters:
//  BinaryData - BinaryData - binary data to be checked.
//
// Returns:
//   Boolean   - True if binary data can be deserialized into InternetMailMessage.
//
Function BinaryDataCorrectInternetMailMessage(BinaryData)
	
	MailMessage = InternetEmailMessageFromBinaryData(BinaryData);
	Return MailMessage.ParseStatus = InternetMailMessageParseStatus.ErrorsNotDetected;
	
EndFunction

Function FileIsEmail(FileName, BinaryData) Export
	
	If InteractionsClientServer.IsFileEmail(FileName)
		And BinaryDataCorrectInternetMailMessage(BinaryData) Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Read receipts

// Returns:
//  CatalogRef.EmailAccounts - Default email account.
//
Function GetAccountForDefaultSending() Export
	
	Query = New Query;
	Query.Text = AvailableAccountsQueryText();
	
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Catalogs.EmailAccounts.EmptyRef();
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	Return Selection.Account;
	
EndFunction

Procedure WriteReadReceiptProcessingRequest(MailMessage)
	
	Record = InformationRegisters.ReadReceipts.CreateRecordManager();
	Record.MailMessage = MailMessage;
	Record.Write();
	
EndProcedure

// Sets a flag indicating that a notification of reading an email is sent.
//
// Parameters:
//  MailMessage  - DocumentRef.IncomingEmail - an email for which the flag is set.
//  Send  - Boolean - if True, the flag will be set, if False, it will be removed.
//
Procedure SetNotificationSendingFlag(MailMessage, Send) Export

	SetPrivilegedMode(True);
	
	If Send Then
		
		Record = InformationRegisters.ReadReceipts.CreateRecordManager();
		Record.MailMessage = MailMessage;
		Record.SendingRequired = True;
		Record.ReadDate     = GetDateAsStringWithGMTOffset(CurrentSessionDate());
		Record.User      = Users.CurrentUser();
		Record.Write();
		
	Else
		
		RecordSet = InformationRegisters.ReadReceipts.CreateRecordSet();
		RecordSet.Filter.MailMessage.Set(MailMessage);
		RecordSet.Write();
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

Function GetEmailImportance(Importance)
	
	If (Importance = InternetMailMessageImportance.High)
		Or (Importance = InternetMailMessageImportance.Highest) Then
		
		Return Enums.InteractionImportanceOptions.High;

	ElsIf (Importance = InternetMailMessageImportance.Lowest)
		Or (Importance = InternetMailMessageImportance.Low) Then
		
		Return Enums.InteractionImportanceOptions.Low;

	Else
		
		Return Enums.InteractionImportanceOptions.Ordinary;
		
	EndIf;
	
EndFunction

Function GetPlainTextFromHTML1(HTMLText)
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLText);
	HTMLDocument = Builder.Read(HTMLReader);
	
	Return HTMLDocument.Body.TextContent;
	
EndFunction

Function GenerateReadReceiptText(Selection)

	ReceiptTextEnglish = "
		|Your message from " + Selection.SenderPresentation + "<" + Selection.SenderAddress + ">
		|Subject: " + Selection.Subject + "
		|Sent " + Selection.Date + "
		|Has been read " +  Selection.ReadDate + "
		|By Recipient " +Selection.UserName + "<" + Selection.Email + ">";
	
	LocalizedReceipt = Chars.LF + NStr("en = 'Message from %1 <%2>
		|Subject: %3
		|Sent on %4
		|Has been opened on %5
		|By %6 <%7>';");
	
	LocalizedReceipt = StringFunctionsClientServer.SubstituteParametersToString(LocalizedReceipt,
		Selection.SenderPresentation,
		Selection.SenderAddress,
		Selection.Subject,
		Selection.Date,
		Selection.ReadDate,
		Selection.UserName,
		Selection.Email);
	
	Return LocalizedReceipt + Chars.LF + Chars.LF + ReceiptTextEnglish;

EndFunction

Function GetDateAsStringWithGMTOffset(Date)
	
	TimeOffsetInSeconds = ToUniversalTime(Date) - Date; 
	OffsetHours = Int(TimeOffsetInSeconds/3600); 
	OffsetHoursString = ?(OffsetHours > 0,"+","") + Format(OffsetHours,"ND=2; NFD=0; NZ=00; NLZ=");
	OffsetMinutes = TimeOffsetInSeconds%3600;
	If OffsetMinutes < 0 Then
		OffsetMinutes = - OffsetMinutes;
	EndIf;
	OffsetMinutesString = Format(OffsetMinutes,"ND=2; NFD=0; NZ=00; NLZ=");
	
	Return Format(Date,"DLF=DT") + " GMT " + OffsetHoursString + OffsetMinutesString;

EndFunction

Procedure CreatePredefinedEmailsFolder(PredefinedFolderType,Owner)

	Folder = Catalogs.EmailMessageFolders.CreateItem();
	Folder.SetNewCode();
	Folder.DataExchange.Load = True;
	Folder.PredefinedFolder = True;
	Folder.Description = TheNameOfThePredefinedFolderByType(PredefinedFolderType);
	Folder.PredefinedFolderType = PredefinedFolderType;
	Folder.Owner = Owner;
	Folder.Write();

EndProcedure

Function TheNameOfThePredefinedFolderByType(PredefinedFolderType)
	
	PredefinedFolderName = "";
	
	If PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.IncomingMessages Then
		PredefinedFolderName = NStr("en = 'Inbox';");
	ElsIf PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Outbox Then
		PredefinedFolderName = NStr("en = 'Outbox';");
	ElsIf PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Trash Then
		PredefinedFolderName = NStr("en = 'Deleted';");
	ElsIf PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Drafts Then
		PredefinedFolderName = NStr("en = 'Drafts';");
	ElsIf PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.SentMessages Then
		PredefinedFolderName = NStr("en = 'Sent';");
	ElsIf PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.JunkMail Then
		PredefinedFolderName = NStr("en = 'Junk mail';");
	EndIf;
	
	Return PredefinedFolderName;
	
EndFunction

// ACC:1391-off For the update handler that fills the "PredefinedFolderType" attribute.

// Parameters:
//  PredefinedFolderName - String
// 
// Returns:
//  EnumRef.PredefinedEmailsFoldersTypes
//
Function TheTypeOfThePredefinedFolderByName(PredefinedFolderName) Export
		
	PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.EmptyRef();
	
	If PredefinedFolderName = NStr("en = 'Inbox';") Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.IncomingMessages;
	ElsIf PredefinedFolderName = NStr("en = 'Outbox';")  Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Outbox;
	ElsIf PredefinedFolderName = NStr("en = 'Deleted';") Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Trash;
	ElsIf PredefinedFolderName = NStr("en = 'Drafts';") Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.Drafts;
	ElsIf PredefinedFolderName = NStr("en = 'Sent';")  Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.SentMessages;
	ElsIf PredefinedFolderName = NStr("en = 'Junk mail';") Then
		PredefinedFolderType = Enums.PredefinedEmailsFoldersTypes.JunkMail;
	EndIf;
	
	Return PredefinedFolderType;
	
EndFunction
// ACC:1391-on

// Parameters:
//  InteractionImportance - EnumRef.InteractionImportanceOptions
//
// Returns:
//  InternetMailMessageImportance
//
Function GetImportance(InteractionImportance) Export
	
	If InteractionImportance = Enums.InteractionImportanceOptions.High Then
		Return InternetMailMessageImportance.High;
	ElsIf InteractionImportance = Enums.InteractionImportanceOptions.Low Then
		Return InternetMailMessageImportance.Low;
	Else
		Return InternetMailMessageImportance.Normal;
	EndIf;
	
EndFunction

Function EventLogEvent() Export
	
	Return NStr("en = 'Business interactions';", Common.DefaultLanguageCode());
	
EndFunction

// Gets and adds to the value list available to user email accounts.
//
// Parameters:
//  ChoiceList  - ValueList - all email accounts available to user will be added here.
//
Procedure GetAvailableAccountsForSending(ChoiceList,AccountDataTable) Export
	
	ChoiceList.Clear();
	
	Query = New Query;
	Query.Text = AvailableAccountsQueryText();
	
	Query.SetParameter("CurrentUser", Users.CurrentUser());
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		ChoiceList.Add(Selection.Account, 
			InteractionsClientServer.GetAddresseePresentation(Selection.UserName,
			                                                         Selection.Email,
			                                                         ""));
	EndDo;
	
	CommonClientServer.SupplementTable(Result.Unload(), AccountDataTable);
	
EndProcedure

Function AvailableAccountsQueryText()
	
	Return "
	|SELECT ALLOWED TOP 1
	|	OutgoingEmail.Account AS Account
	|INTO LastUsedAccount
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.EmailStatus <> VALUE(Enum.OutgoingEmailStatuses.Draft)
	|	AND NOT OutgoingEmail.DeletionMark
	|	AND OutgoingEmail.Author = &CurrentUser
	|
	|ORDER BY
	|	OutgoingEmail.Date DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	EmailAccounts.Ref AS Account,
	|	EmailAccounts.UserName AS UserName,
	|	EmailAccounts.Email AS Email,
	|	ISNULL(EmailAccountSettings.DeleteEmailsAfterSend, FALSE) AS DeleteAfterSend,
	|	CASE
	|		WHEN NOT LastUsedAccount.Account IS NULL
	|			THEN 0
	|		WHEN EmailAccounts.AccountOwner <> VALUE(Catalog.Users.EmptyRef)
	|				AND EmailAccounts.AccountOwner = &CurrentUser
	|			THEN 1
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|				AND EmailAccountSettings.EmployeeResponsibleForProcessingEmails = &CurrentUser
	|			THEN 2
	|		ELSE 2
	|	END AS OrderingValue
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN LastUsedAccount AS LastUsedAccount
	|		ON LastUsedAccount.Account = EmailAccounts.Ref
	|WHERE
	|	EmailAccounts.UseForSending
	|	AND NOT EmailAccounts.DeletionMark
	|	AND NOT ISNULL(EmailAccountSettings.NotUseInDefaultEmailClient, FALSE)
	|	AND (EmailAccounts.AccountOwner = &CurrentUser
	|			OR EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef))
	|
	|ORDER BY
	|	OrderingValue";
	
EndFunction

// Parameters:
//  Account - CatalogRef.EmailAccounts - Email account where the predefined folders
//                                                                   will be created.
//
Procedure CreatePredefinedEmailsFoldersForAccount(Account) Export
	
	ArrayOfPredefinedFolderTypes = New Array;
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.IncomingMessages);
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.Outbox);
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.Trash);
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.Drafts);
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.SentMessages);
	ArrayOfPredefinedFolderTypes.Add(Enums.PredefinedEmailsFoldersTypes.JunkMail);
	
	Query = New Query;
	Query.Text = "SELECT
	|	EmailMessageFolders.PredefinedFolderType
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.PredefinedFolder
	|	AND EmailMessageFolders.Owner = &Owner";
	
	Query.SetParameter("Owner", Account);
	
	ExistingFoldersArray = Query.Execute().Unload().UnloadColumn("PredefinedFolderType");
	
	For Each PredefinedFolderType In ArrayOfPredefinedFolderTypes Do
		If ExistingFoldersArray.Find(PredefinedFolderType) = Undefined Then
			
			CreatePredefinedEmailsFolder(PredefinedFolderType, Account);
			
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  MailMessage - DocumentRef - an email whose name is defined.
//
// Returns:
//  String - Name of the metadata object of the email attachments.
//  Undefined
//
Function MetadataObjectNameOfAttachedEmailFiles(MailMessage) Export

	 If TypeOf(MailMessage) = Type("DocumentRef.OutgoingEmail") Then
		
		Return "OutgoingEmailAttachedFiles";
		
	ElsIf TypeOf(MailMessage) = Type("DocumentRef.IncomingEmail") Then
		
		Return "IncomingEmailAttachedFiles";
		
	Else
		
		Return Undefined;
		
	EndIf;

EndFunction

Procedure UnlockAccountForReceiving(Account)
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.AccountsLockedForReceipt");
		LockItem.SetValue("Account", Account);
		Block.Lock();
	
		RecordSet = InformationRegisters.AccountsLockedForReceipt.CreateRecordSet();
		RecordSet.Filter.Account.Set(Account);
		RecordSet.Write();

		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

Function LockAccount(Account)

	BeginTransaction();
	Try
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.AccountsLockedForReceipt");
		LockItem.SetValue("Account", Account);
		Block.Lock();
		
		// Checking an account lock and setting it if it is available.
		Query = New Query;
		Query.Text = "
		|SELECT
		|	AccountsLockedForReceipt.LockDate
		|FROM
		|	InformationRegister.AccountsLockedForReceipt AS AccountsLockedForReceipt
		|WHERE
		|	AccountsLockedForReceipt.Account = &Account";
		
		Query.SetParameter("Account", Account);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			If Selection.LockDate + 60 * 60 > CurrentSessionDate() Then
				CommitTransaction();
				Return False;
			EndIf;
		EndIf;
		
		RecordManager = InformationRegisters.AccountsLockedForReceipt.CreateRecordManager();
		RecordManager.Account  = Account;
		RecordManager.LockDate = CurrentSessionDate();
		RecordManager.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion
