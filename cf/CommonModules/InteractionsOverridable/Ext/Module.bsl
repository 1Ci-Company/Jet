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

// It is called to get contacts (members) by the specified interaction subject.
// It is used if at least one interaction subject is determined in the configuration.
//
// Parameters:
//  ContactsTableName   - String - an interaction subject table name, where search is required.
//                                   For example, "Documents.CustomerOrder".
//  QueryTextForSearch - String - a query fragment for the search is specified to this parameter. When performing 
//                                   a query, a reference to an interaction subject is inserted in the &Subject query parameter.
//
Procedure OnSearchForContacts(Val ContactsTableName, QueryTextForSearch) Export
	
	
	
EndProcedure	

// Allows to override an attachment owner for writing.
// This can be required, for example, in case of bulk mail, when it makes sense 
// to store all attachments together and not to replicate them to all bulk emails.
//
// Parameters:
//  MailMessage - DocumentRef.IncomingEmail
//         - DocumentRef.OutgoingEmail - Email message whose attachments must be received. 
//           
//  AttachedFiles - Structure - specify information on files attached to an email:
//    * FilesOwner                     - DefinedType.AttachedFile - Attachment owner.
//    * AttachedFilesCatalogName - String - an attached file metadata object name.
//
Procedure OnReceiveAttachedFiles(MailMessage, AttachedFiles) Export

EndProcedure

// It is called to set logic of interaction access restriction.
// For the example of filling access value sets, see comments
// to AccessManagement.FillAccessValuesSets.
//
// Parameters:
//  Object - DocumentObject.Meeting
//         - DocumentObject.PlannedInteraction
//         - DocumentObject.SMSMessage
//         - DocumentObject.PhoneCall
//         - DocumentObject.IncomingEmail
//         - DocumentObject.OutgoingEmail - Object whose sets must be populated.
//  Table - See AccessManagement.AccessValuesSetsTable
//
Procedure OnFillingAccessValuesSets(Object, Table) Export
	
	
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Deprecated. Obsolete. Use InteractionsOverridable.OnSearchForContacts.
// Returns a query text that filters interaction subject contacts (members).
// It is used if at least one interaction subject is determined in the configuration.
//
// Parameters:
//  DeletePutInTempTable - Boolean - always False.
//  TableName                        - String - an interaction subject table name, where search will be performed.
//  DeleteMerge                 - Boolean - always True.
//
// Returns:
//  String - Query text.
//
Function QueryTextContactsSearchBySubject(DeletePutInTempTable, TableName, DeleteMerge = False) Export
	
	Return "";
	
EndFunction

// Deprecated. Obsolete. Use InteractionsOverridable.OnGetAttachedFiles.
// The ability to override an attachment owner for writing.
// This can be required, for example, in case of bulk mail. Here it makes sense 
// to store all attachments together and not to replicate them to all bulk emails.
//
// Parameters:
//  MailMessage  - DocumentRef
//          - DocumentObject - Email message whose attachments must be received.
//
// Returns:
//  Structure, Undefined  - - Undefined if the attachments are stored in the message.
//                             Otherwise, Structure:
//                              * Owner - DefinedType.AttachedFile - Attachment owner.
//                              * CatalogNameAttachedFiles - String - an attached file metadata object name.
//
Function AttachedEmailFilesMetadataObjectData(MailMessage) Export
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion
