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

// Sends one email.
// The function might throw an exception which must be handled.
//
// Parameters:
//  UserAccountOrConnection - CatalogRef.EmailAccounts - Sender's email account.
//                                                                   
//                             - InternetMail - Connection established with the email server.
//                
//  MailMessage - InternetMailMessage - an email to be sent.
//
// Returns:
//  Structure - an email sending result:
//   * WrongRecipients - Map of KeyAndValue - recipient addresses with errors:
//    ** Key     - String - a recipient address.
//    ** Value - String - an error text.
//   * SMTPEmailID - String - an email UUID assigned upon sending using SMTP.
//   * IMAPEmailID - String - an email UUID assigned upon sending using IMAP.
//
Function SendMail(UserAccountOrConnection, MailMessage) Export
	
	Return EmailOperationsInternal.SendMail(UserAccountOrConnection, MailMessage);
	
EndFunction

// Sends multiple emails.
// The function might throw an exception which must be handled.
// If at least one email was successfully sent before an error occurred, an exception is not thrown.
// On function result processing, check which emails were not sent.
//
// Parameters:
//  UserAccountOrConnection - CatalogRef.EmailAccounts - Sender's email account.
//                                                                   
//                             - InternetMail - Connection established with the email server.
//  
//  Emails - Array of InternetMailMessage - a collection of email messages. Collection item - InternetMailMessage.
//  ErrorText - String - an error massage if not all emails are sent.
//
// Returns:
//  Map of KeyAndValue:
//   * Key     - InternetMailMessage - an email to be sent.
//   * Value - Structure - an email sending result:
//    ** WrongRecipients - Map of KeyAndValue - recipient addresses with errors:
//     *** Key     - String - a recipient address.
//     *** Value - String - an error text.
//    ** SMTPEmailID - String - an email UUID assigned upon sending using SMTP.
//    ** IMAPEmailID - String - an email UUID assigned upon sending using IMAP.
//
Function SendEmails(UserAccountOrConnection, Emails, ErrorText = Undefined) Export
	
	Return EmailOperationsInternal.SendEmails(UserAccountOrConnection, Emails, ErrorText);
	
EndFunction

// Loads messages from the server for the specified email.
// Before loading, checks if email settings are filled correctly.
// The function might throw an exception which must be handled.
//
// Parameters:
//   UserAccountOrConnection - CatalogRef.EmailAccounts - Source email account.
//                              
//                              - InternetMail - Connection established with the email server
//   ImportParameters - Structure:
//     * Columns - Array - array of strings
//                          of column names. The column names must match the fields
//                          of the InternetMailMessage object.
//     * TestMode - Boolean - used to check server connection.
//     * GetHeaders - Boolean - if True, the returned set only
//                                       includes message headers.
//     * Filter - Structure - corresponds to the FilterParameters parameter of the InternetMail.GetHeaders built-in function.
//     * HeadersIDs - Array - headers or IDs of the messages whose full
//                                    texts are to be retrieved.
//     * CastMessagesToType - Boolean - return a set of received email messages
//                                    as a value table with simple types. The default value is True.
//
// Returns:
//  ValueTable, Boolean - list of emails with the following columns:
//   * Importance - InternetMailMessageImportance
//   * Attachments - InternetMailAttachments - if any of the attachments are email messages,
//                 they are not returned but their attachments, binary
//                 data and texts, are recursively returned as binary data.
//   * PostingDate - Date
//   * DateReceived - Date
//   * Title - String
//   * SenderName - String
//   * Id - Array of String
//   * Cc - InternetMailAddresses
//   * ReplyTo - InternetMailAddresses
//   * Sender - String
//                 - InternetMailAddress
//   * Recipients - InternetMailAddresses
//   * Size - Number
//   * Texts - InternetMailTexts
//   * Encoding - String
//   * NonASCIISymbolsEncodingMode - InternetMailMessageNonASCIISymbolsEncodingMode
//   * Partial - Boolean - is filled in if the status is True. In test mode, True is returned.
//
Function DownloadEmailMessages(Val UserAccountOrConnection, Val ImportParameters = Undefined) Export
	
	Var Account;
	
	If TypeOf(UserAccountOrConnection) <> Type("InternetMail") Then
		Account = UserAccountOrConnection;
	EndIf;
	
	If Account <> Undefined Then
		UseForReceiving = Common.ObjectAttributeValue(Account, "UseForReceiving");
		If Not UseForReceiving Then
			Raise NStr("en = 'The account is not intended to receive messages.';");
		EndIf;
	EndIf;
	
	If ImportParameters = Undefined Then
		ImportParameters = New Structure;
	EndIf;
	
	Result = EmailOperationsInternal.DownloadMessages(UserAccountOrConnection, ImportParameters);
	Return Result;
	
EndFunction

// Get available email accounts.
//
//  Parameters:
//   ForSending  - Boolean - select only accounts configured for sending emails.
//   ForReceiving - Boolean - choose only accounts that are configured to receive mail.
//   IncludingSystemEmailAccount - Boolean - include the system account if it is configured for sending and receiving emails.
//
// Returns:
//  ValueTable - description of accounts:
//   * Ref       - CatalogRef.EmailAccounts - an account.
//   * Description - String - email name.
//   * Address        - String - an email address.
//
Function AvailableEmailAccounts(Val ForSending = Undefined,
								Val ForReceiving  = Undefined,
								Val IncludingSystemEmailAccount = True) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return New ValueTable;
	EndIf;
	
	QueryText = 
	"SELECT ALLOWED
	|	EmailAccounts.Ref AS Ref,
	|	EmailAccounts.Description AS Description,
	|	EmailAccounts.Email AS Address,
	|	CASE
	|		WHEN EmailAccounts.Ref = VALUE(Catalog.EmailAccounts.SystemEmailAccount)
	|			THEN 0
	|		ELSE 1
	|	END AS Priority
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND CASE
	|			WHEN &ForSending = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForSending = &ForSending
	|		END
	|	AND CASE
	|			WHEN &ForReceiving = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForReceiving = &ForReceiving
	|		END
	|	AND CASE
	|			WHEN &IncludingSystemEmailAccount
	|				THEN TRUE
	|			ELSE EmailAccounts.Ref <> VALUE(Catalog.EmailAccounts.SystemEmailAccount)
	|		END
	|	AND EmailAccounts.Email <> """"
	|	AND CASE
	|			WHEN EmailAccounts.UseForReceiving
	|				THEN EmailAccounts.IncomingMailServer <> """"
	|			ELSE TRUE
	|		END
	|	AND CASE
	|			WHEN EmailAccounts.UseForSending
	|				THEN EmailAccounts.OutgoingMailServer <> """"
	|			ELSE TRUE
	|		END
	|	AND (EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			OR EmailAccounts.AccountOwner = &CurrentUser)
	|
	|ORDER BY
	|	Priority,
	|	Description";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ForSending", ForSending);
	Query.Parameters.Insert("ForReceiving", ForReceiving);
	Query.Parameters.Insert("IncludingSystemEmailAccount", IncludingSystemEmailAccount);
	Query.Parameters.Insert("CurrentUser", Users.CurrentUser());
	
	Return Query.Execute().Unload();
	
EndFunction

// Receives email settings for mass notification from the program.
//
// Returns:
//  CatalogRef.EmailAccounts
//
Function SystemAccount() Export
	
	Return Catalogs.EmailAccounts.SystemEmailAccount;
	
EndFunction

// Checks whether the email is available for mass notification.
//
// Returns:
//  Boolean
//
Function CheckSystemAccountAvailable() Export
	
	Return EmailOperationsInternal.CheckSystemAccountAvailable();
	
EndFunction

// Returns True if at least one configured email account is available
// or user has sufficient access rights to configure the email.
//
// Returns:
//  Boolean
//
Function CanSendEmails() Export
	
	If AccessRight("Update", Metadata.Catalogs.EmailAccounts) Then
		Return True;
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return False;
	EndIf;
		
	QueryText = 
	"SELECT ALLOWED TOP 1
	|	1 AS Count
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	NOT EmailAccounts.DeletionMark
	|	AND EmailAccounts.UseForSending
	|	AND EmailAccounts.Email <> """"
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND (EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			OR EmailAccounts.AccountOwner = &CurrentUser)";
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("CurrentUser", Users.CurrentUser());
	Selection = Query.Execute().Select();
	
	Return Selection.Next();
	
EndFunction

// Checks whether the account is configured for sending or receiving email.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - an account to be checked.
//  ForSending  - Boolean - check parameters used to send email.
//  ForReceiving - Boolean - check parameters used to receive email.
// 
// Returns:
//  Boolean - True if the account is configured.
//
Function AccountSetUp(Account, Val ForSending = Undefined, Val ForReceiving = Undefined) Export
	
	Parameters = Common.ObjectAttributesValues(Account, "Email,IncomingMailServer,OutgoingMailServer,UseForReceiving,UseForSending,ProtocolForIncomingMail");
	If ForSending = Undefined Then
		ForSending = Parameters.UseForSending;
	EndIf;
	If ForReceiving = Undefined Then
		ForReceiving = Parameters.UseForReceiving;
	EndIf;
	
	Return Not (IsBlankString(Parameters.Email) 
		Or ForReceiving And IsBlankString(Parameters.IncomingMailServer)
		Or ForSending And (IsBlankString(Parameters.OutgoingMailServer)
			Or (Parameters.ProtocolForIncomingMail = "IMAP" And IsBlankString(Parameters.IncomingMailServer))));
		
EndFunction

// Checks email settings.
//
// Parameters:
//  Account     - CatalogRef.EmailAccounts - email to check.
//  ErrorMessage - String - an error message text or an empty string if no errors occurred.
//  AdditionalMessage - String - messages that contain information on the checks made for the email.
//
Procedure CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage) Export
	
	EmailOperationsInternal.CheckSendReceiveEmailAvailability(Account, 
		ErrorMessage, AdditionalMessage);
	
EndProcedure

// Checks whether a document has HTML links to resources downloaded using HTTP(S).
//
// Parameters:
//  HTMLDocument - HTMLDocument - an HTML document to be checked.
//
// Returns:
//  Boolean - True if an HTML document has external resources.
//
Function HasExternalResources(HTMLDocument) Export
	
	Return EmailOperationsInternal.HasExternalResources(HTMLDocument);
	
EndFunction

// Deletes scripts and event handlers from an HTML document, and clears links to resources downloaded using HTTP(S).
//
// Parameters:
//  HTMLDocument - HTMLDocument - HTMLDocument - an HTML document to clear unsafe content from.
//  DisableExternalResources - Boolean - indicates whether is is necessary to clear links to resources downloaded using HTTP(S).
// 
Procedure DisableUnsafeContent(HTMLDocument, DisableExternalResources = True) Export
	
	EmailOperationsInternal.DisableUnsafeContent(HTMLDocument, DisableExternalResources);
	
EndProcedure

// Gets from ITS troubleshooting tips on how to fix a email server connection error.
// 
// Parameters:
//   ErrorText - String - Original error text.
// 	
// Returns:
//  Structure:
//   * PossibleReasons - Array of FormattedString
//   * MethodsToFixError - Array of FormattedString
//
Function ExplanationOnError(ErrorText) Export
	
	Return EmailOperationsInternal.ExplanationOnError(ErrorText);
	
EndFunction

// Prepares an extended description of the email server connection error.
// 
// Parameters:
//  ErrorInfo - ErrorInfo
//  LanguageCode - String - attribute language code. For example, "en".
//  EnableVerboseRepresentationErrors - Boolean - Adds a stack to an error text.
//  
// Returns:
//  String
//
Function ExtendedErrorPresentation(ErrorInfo, LanguageCode, EnableVerboseRepresentationErrors = True) Export
	
	Return EmailOperationsInternal.ExtendedErrorPresentation(
		ErrorInfo, LanguageCode, EnableVerboseRepresentationErrors);
	
EndFunction

// Returns the list of field names of the InternetMailMessage object.
//
// Returns:
//  Structure:
//    * DeliveryReceiptAddresses - String
//    * ReadReceiptAddresses - String
//    * Importance - String
//    * Attachments - String
//    * PostingDate - String
//    * DateReceived - String
//    * Header - String
//    * UID - String
//    * MessageID - String
//    * SenderName - String
//    * Categories - String
//    * Encoding - String
//    * Cc - String
//    * ReplyTo - String
//    * From - String
//    * To - String
//    * Size - String
//    * Bcc - String
//    * PostingDateOffset - String
//    * ParseStatus - String
//    * Subject - String
//    * Texts - String
//    * NonASCIISymbolsEncodingMode - String
//    * RequestDeliveryReceipt - String
//    * RequestReadReceipt - String
//    * Partial - String
//
Function InternetMailMessageFields() Export
	
	MessageFields = New Structure;

	MessageFields.Insert("DeliveryReceiptAddresses", "DeliveryReceiptAddresses"); 
	MessageFields.Insert("ReadReceiptAddresses", "ReadReceiptAddresses");
	MessageFields.Insert("Importance", "Importance");
	MessageFields.Insert("Attachments", "Attachments");
	MessageFields.Insert("PostingDate", "PostingDate");
	MessageFields.Insert("DateReceived", "DateReceived");
	MessageFields.Insert("Header", "Header");
	MessageFields.Insert("SenderName", "SenderName");
	MessageFields.Insert("UID", "UID");
	MessageFields.Insert("MessageID", "MessageID");
	MessageFields.Insert("Categories", "Categories");
	MessageFields.Insert("Encoding", "Encoding");
	MessageFields.Insert("Cc", "Cc");
	MessageFields.Insert("ReplyTo", "ReplyTo");
	MessageFields.Insert("From", "From");
	MessageFields.Insert("To", "To");
	MessageFields.Insert("Size", "Size");
	MessageFields.Insert("Bcc", "Bcc");
	MessageFields.Insert("PostingDateOffset", "PostingDateOffset");
	MessageFields.Insert("ParseStatus", "ParseStatus");
	MessageFields.Insert("Subject", "Subject");
	MessageFields.Insert("Texts", "Texts");
	MessageFields.Insert("NonASCIISymbolsEncodingMode", "NonASCIISymbolsEncodingMode");
	MessageFields.Insert("RequestDeliveryReceipt", "RequestDeliveryReceipt");
	MessageFields.Insert("RequestReadReceipt", "RequestReadReceipt");
	MessageFields.Insert("Partial", "Partial");
	
	Return MessageFields;
	
EndFunction

// Generates an email based on passed parameters.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - reference to
//                 an email account.
//  EmailParameters - Structure - contains all email data:
//
//   * Whom - Array
//          - String - an email address of the email recipient.
//          - Array - Collection of address structures:
//              * Address         - String - an email address (required).
//              * Presentation - String - a recipient's name.
//          - String - recipient email addresses, separator - ";".
//
//   * MessageRecipients - Array - array of structures describing recipients:
//      ** Address - String - an email recipient address.
//      ** Presentation - String - an addressee presentation.
//
//   * Cc        - Array
//                  - String - email addresses of copy recipients. See the "To" field description.
//
//   * BCCs - Array
//                  - String - email addresses of BCC recipients. See the "To" field description.
//
//   * Subject       - String - (mandatory) email subject.
//   * Body       - String - (mandatory) email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance
//
//   * Attachments - Array - files to be attached (described as structures):
//     ** Presentation - String - an attachment file name.
//     ** AddressInTempStorage - String - a binary data address of an attachment in a temporary storage.
//     ** Encoding - String - an attachment encoding (used if it differs from the message encoding).
//     ** Id - String - (optional) used to store images displayed in the message body.
//
//   * ReplyToAddress - Map
//                 - String - see the "To" field description.
//   * BasisIDs - String - IDs of the message basis objects.
//   * ProcessTexts  - Boolean - shows whether message text processing is required on sending.
//   * RequestDeliveryReceipt  - Boolean - shows whether a delivery notification is required.
//   * RequestReadReceipt - Boolean - shows whether a read notification is required.
//   * TextType   - String
//                 - EnumRef.EmailTextTypes
//                 - InternetMailTextType - specifies the type
//                  of the passed text, possible values::
//                  HTML/EmailTextTypes.HTML. Email text in HTML format.
//                  PlainText/EmailTextTypes.PlainText. Plain text of an email message.
//                                                 Displayed "as is" (default
//                                                 value).
//                  MarkedUpText/EmailTextTypes.MarkedUpText. Email message in
//                                                 Rich Text format.
//
// Returns:
//  InternetMailMessage - a prepared email.
//
Function PrepareEmail(Account, EmailParameters) Export
	
	If TypeOf(Account) <> Type("CatalogRef.EmailAccounts")
		Or Not ValueIsFilled(Account) Then
		Raise NStr("en = 'The account is not specified or specified incorrectly.';");
	EndIf;
	
	If EmailParameters = Undefined Then
		Raise NStr("en = 'The mail sending parameters are not specified.';");
	EndIf;
	
	RecipientValType = ?(EmailParameters.Property("Whom"), TypeOf(EmailParameters.Whom), Undefined);
	CcType = ?(EmailParameters.Property("Cc"), TypeOf(EmailParameters.Cc), Undefined);
	BCCs = CommonClientServer.StructureProperty(EmailParameters, "BCCs");
	
	If RecipientValType = Undefined And CcType = Undefined And BCCs = Undefined Then
		Raise NStr("en = 'No recipient is selected.';");
	EndIf;
	
	If RecipientValType = Type("String") Then
		EmailParameters.Whom = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Whom);
	ElsIf RecipientValType <> Type("Array") Then
		EmailParameters.Insert("Whom", New Array);
	EndIf;
	
	If CcType = Type("String") Then
		EmailParameters.Cc = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Cc);
	ElsIf CcType <> Type("Array") Then
		EmailParameters.Insert("Cc", New Array);
	EndIf;
	
	If TypeOf(BCCs) = Type("String") Then
		EmailParameters.BCCs = CommonClientServer.ParseStringWithEmailAddresses(BCCs);
	ElsIf TypeOf(BCCs) <> Type("Array") Then
		EmailParameters.Insert("BCCs", New Array);
	EndIf;
	
	If EmailParameters.Property("ReplyToAddress") And TypeOf(EmailParameters.ReplyToAddress) = Type("String") Then
		EmailParameters.ReplyToAddress = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.ReplyToAddress);
	EndIf;
	
	Return EmailOperationsInternal.PrepareEmail(Account, EmailParameters);
	
EndFunction

// Establishes an open connection to the email server. If an exception is thrown, handle it.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - Email connection settings.
//  ForReceiving - Boolean - If set to "True", connect to the incoming email server.
//                          Otherwise, connect to the outgoing email server.
//  
// Returns:
//   InternetMail
//
Function ConnectToEmailAccount(Val Account, Val ForReceiving = False) Export
	
	Return EmailOperationsInternal.ConnectToEmailAccount(Account, ForReceiving);
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Sends emails.
// The function might throw an exception which must be handled.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - reference to
//                 an email account.
//  SendOptions - Structure - contains all email data:
//
//   * Whom - Array
//          - String - an email address of the email recipient.
//          - Array - Collection of address structures:
//              * Address         - String - an email address (required).
//              * Presentation - String - a recipient's name.
//          - String - recipient email addresses, separator - ";".
//
//   * MessageRecipients - Array - array of structures describing recipients:
//      ** Address - String - an email recipient address.
//      ** Presentation - String - an addressee presentation.
//
//   * Cc        - Array
//                  - String - email addresses of copy recipients. See the "To" field description.
//
//   * BCCs - Array
//                  - String - email addresses of BCC recipients. See the "To" field description.
//
//   * Subject       - String - (mandatory) email subject.
//   * Body       - String - (mandatory) email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance
//
//   * Attachments - Array - files to be attached (described as structures):
//     ** Presentation - String - an attachment file name;
//     ** AddressInTempStorage - String - a binary data address of an attachment in a temporary storage.
//     ** Encoding - String - an attachment encoding (used if it differs from the message encoding).
//     ** Id - String - (optional) used to store images displayed in the message body.
//
//   * ReplyToAddress - Map
//                 - String - see the "To" field description.
//   * BasisID  - String - ID of the message basis object.
//   * BasisIDs - String - IDs of the message basis objects.
//   * ProcessTexts  - Boolean - shows whether message text processing is required on sending.
//   * RequestDeliveryReceipt  - Boolean - shows whether a delivery notification is required.
//   * RequestReadReceipt - Boolean - shows whether a read notification is required.
//   * TextType   - String
//                 - EnumRef.EmailTextTypes
//                 - InternetMailTextType - specifies the type
//                  of the passed text, possible values::
//                  HTML/EmailTextTypes.HTML. Email text in HTML format.
//                  PlainText/EmailTextTypes.PlainText. Plain text of an email message.
//                                                 Displayed "as is" (default
//                                                 value).
//                  MarkedUpText/EmailTextTypes.MarkedUpText. Email message in
//                                                 Rich Text format.
//   * Join - InternetMail - an existing connection to a mail server. If not specified, a new one is created.
//   * MailProtocol - String - if "IMAP" is specified, IMAP is used.
//                              If "All" is specified, both SMTP and IMAP are used. If nothing is specified,
//                              SMTP is used. The parameter has relevance only when there is an active connection
//                              specified in the Connection parameter. Otherwise, the protocol will be determined
//                              automatically upon establishing connection.
//   * MessageID - String - - (return parameter) ID of the sent email on SMTP server.
//   * MessageIDIMAPSending - String - (return parameter) ID of the sent
//                                         email on IMAP server.
//   * WrongRecipients - Map - (return parameter) list of addresses that sending was failed to. 
//                                          (See return value of the InternetMail.Send() method in the Syntax Assistant.
//
//  DeleteConnection - InternetMail - obsolete, see parameter SendingParameters.Connection.
//  DeleteMailProtocol - String     - obsolete, see parameter SendingParameters.MailProtocol.
//
// Returns:
//  String - sent message ID.
//
Function SendEmailMessage(Val Account, Val SendOptions,
	Val DeleteConnection = Undefined, DeleteMailProtocol = "") Export
	
	If DeleteConnection <> Undefined Then
		SendOptions.Insert("Join", DeleteConnection);
	EndIf;
	
	If Not IsBlankString(DeleteMailProtocol) Then
		SendOptions.Insert("MailProtocol", DeleteMailProtocol);
	EndIf;
	
	If TypeOf(Account) <> Type("CatalogRef.EmailAccounts")
		Or Not ValueIsFilled(Account) Then
		Raise NStr("en = 'The account is not specified or specified incorrectly.';");
	EndIf;
	
	If SendOptions = Undefined Then
		Raise NStr("en = 'The mail sending parameters are not specified.';");
	EndIf;
	
	RecipientValType = ?(SendOptions.Property("Whom"), TypeOf(SendOptions.Whom), Undefined);
	CcType = ?(SendOptions.Property("Cc"), TypeOf(SendOptions.Cc), Undefined);
	BCCs = CommonClientServer.StructureProperty(SendOptions, "BCCs");
	
	If RecipientValType = Undefined And CcType = Undefined And BCCs = Undefined Then
		Raise NStr("en = 'No recipient is selected.';");
	EndIf;
	
	If RecipientValType = Type("String") Then
		SendOptions.Whom = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.Whom);
	ElsIf RecipientValType <> Type("Array") Then
		SendOptions.Insert("Whom", New Array);
	EndIf;
	
	If CcType = Type("String") Then
		SendOptions.Cc = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.Cc);
	ElsIf CcType <> Type("Array") Then
		SendOptions.Insert("Cc", New Array);
	EndIf;
	
	If TypeOf(BCCs) = Type("String") Then
		SendOptions.BCCs = CommonClientServer.ParseStringWithEmailAddresses(BCCs);
	ElsIf TypeOf(BCCs) <> Type("Array") Then
		SendOptions.Insert("BCCs", New Array);
	EndIf;
	
	If SendOptions.Property("ReplyToAddress") And TypeOf(SendOptions.ReplyToAddress) = Type("String") Then
		SendOptions.ReplyToAddress = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.ReplyToAddress);
	EndIf;
	
	EmailOperationsInternal.SendMessage(Account, SendOptions);
	EmailOperationsOverridable.AfterEmailSending(SendOptions);
	
	If SendOptions.WrongRecipients.Count() > 0 Then
		ErrorText = NStr("en = 'The following email addresses were declined by mail server:';");
		For Each WrongRecipient In SendOptions.WrongRecipients Do
			ErrorText = ErrorText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString("%1: %2",
				WrongRecipient.Key, WrongRecipient.Value);
		EndDo;
		Raise ErrorText;
	EndIf;
	
	Return SendOptions.MessageID;
	
EndFunction

#EndRegion

#EndRegion
