///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Returns True if the current user has at least one account available for sending.
Function HasAvailableAccountsForSending() Export
	Return EmailOperations.AvailableEmailAccounts(True).Count() > 0;
EndFunction

// Checks whether a user can add new accounts.
Function CanAddNewAccounts() Export 
	Return AccessRight("Insert", Metadata.Catalogs.EmailAccounts);
EndFunction

Function InfoForSending(SendOptions) Export
	Var Attachments;
	
	SendOptions.Property("Attachments", Attachments);
	SendOptions.Attachments = EmailOperationsInternal.AttachmentsDetails(Attachments);
	
	Result = New Structure;
	Result.Insert("HasAvailableAccountsForSending", HasAvailableAccountsForSending());
	Result.Insert("CanAddNewAccounts", CanAddNewAccounts());
	Result.Insert("ShowAttachmentSaveFormatSelectionDialog", AttachmentsContainSpreadsheetDocuments(SendOptions.Attachments));
	
	Return Result;
EndFunction

Function AttachmentsContainSpreadsheetDocuments(Attachments)
	If Attachments = Undefined Then
		Return False;
	EndIf;
	
	For Each AttachmentDetails In Attachments Do
		If TypeOf(GetFromTempStorage(AttachmentDetails.AddressInTempStorage)) = Type("SpreadsheetDocument") Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

Procedure PrepareAttachments(Attachments, SettingsForSaving) Export
	EmailOperationsInternal.PrepareAttachments(Attachments, SettingsForSaving);
EndProcedure

#EndRegion
