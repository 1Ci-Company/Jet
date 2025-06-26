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

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure:
//   * CanReceiveEmails - Boolean - show email receiving settings in accounts.
//                                       Default value: False - for basic configuration versions,
//                                       True - for other versions.
//   * ShouldUsePOP3Protocol - Boolean - Toggles POP3 settings for new email settings.
//                                         By default, "True".
//
Procedure OnDefineSettings(Settings) Export

EndProcedure

// Allows executing additional operations after sending email.
//
// Parameters:
//  EmailParameters - Structure - contains all email data:
//   * Whom      - Array - (required) an email address of the recipient.
//                 Address - String - email address.
//                 Presentation - String - recipient's name.
//
//   * MessageRecipients - Array - array of structures describing recipients:
//                            * ContactInformationSource - CatalogRef - a contact information owner.
//                            * Address - String - an email address (required).
//                            * Presentation - String - an addressee presentation.
//
//   * Cc      - Array - a collection of address structures:
//                   * Address         - String - an email address (required).
//                   * Presentation - String - a recipient's name.
//                  
//                - String - recipient email addresses, separator - ";".
//
//   * BCCs - Array
//                  - String - see the "Cc" field description.
//
//   * Subject       - String - (mandatory) an email subject.
//   * Body       - String - (mandatory) an email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance
//   * Attachments   - Map of KeyAndValue:
//                   * Key     - String - an attachment description.
//                   * Value - BinaryData
//                              - String -  a binary data address of an attachment in a temporary storage.
//                              - Structure:
//                                 * BinaryData - BinaryData - attachment binary data.
//                                 * Id  - String - an attachment ID, used to store pictures
//                                                             displayed in the email body.
//
//   * ReplyToAddress - Map - see the "To" field description.
//   * Password      - String - email password.
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
Procedure AfterEmailSending(EmailParameters) Export
	
	
	
EndProcedure

// Specifies a list of emails to receive the delivered/read status for.
// For the email list determination example, see ReportsDistribution.BeforeGetEmailMessagesStatuses
//
//   Parameters:
//  EmailMessagesIDs - ValueTable:
//   * Sender - CatalogRef.EmailAccounts
//   * EmailID - String
//   * RecipientAddress - String - recipient email
//
Procedure BeforeGetEmailMessagesStatuses(EmailMessagesIDs) Export
	
EndProcedure

// Returns information only about known delivery statuses (if corresponding emails were received).
// For an example of processing received email statuses, see ReportsMailing.AfterGetEmailMessagesStatuses
//
// Parameters:
//  DeliveryStatuses - ValueTable:
//   * Sender - CatalogRef.EmailAccounts
//   * EmailID - String 
//   * RecipientAddress - String - recipient email
//   * Status - EnumRef.EmailMessagesStatuses 
//   * StatusChangeDate - Date
//   * Cause - String - reason for email non-delivery
//
Procedure AfterGetEmailMessagesStatuses(DeliveryStatuses) Export
	
EndProcedure

#EndRegion
