///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Internal

// Converts the user-provided phone number into the format supported by the SMS service provider.
//
// Parameters:
//  Number             - String - User-provided phone number.
//  SendingNumber  - String - Takes the conversion result.
//
Procedure OnFormatPhoneNumberToSend(Number, SendingNumber) Export
	
	
EndProcedure

// The ability to add to the array of folder names that will be ignored when importing
// emails from the mail server via the IMAP protocol.
//
// Parameters:
//  FoldersNames        - Array of String - An array of folders excluded from import.
//  
Procedure OnDefineFolderNamesIgnoredOnEmailsReceipt(FoldersNames) Export
	
	
EndProcedure

// Completes the map of identical (interchangeable) email domains.
// It is used to determine if an email was sent to the sender's mailbox.
// It may be needed when downloading outgoing mail via the IMAP protocol.
// When sending such an email, the mail server might specify a different domain in the sender's address.
// 
// Parameters:
//  EmailDomainsSynonyms - Map - "Key" is the name to be replaced.
//    "Value" is the target domain name.
//
Procedure OnDefineEmailDomainSynonyms(EmailDomainsSynonyms) Export
	
	
EndProcedure

#EndRegion

