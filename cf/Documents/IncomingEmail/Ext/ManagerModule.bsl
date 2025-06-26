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

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Importance");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Comment");
	Result.Add("SenderContact");
	Result.Add("SenderPresentation");
	Result.Add("EmailRecipients.Presentation");
	Result.Add("EmailRecipients.Contact");
	Result.Add("CCRecipients.Presentation");
	Result.Add("CCRecipients.Contact");
	Result.Add("ReplyRecipients.Presentation");
	Result.Add("ReplyRecipients.Contact");
	Result.Add("ReadReceiptAddresses.Presentation");
	Result.Add("ReadReceiptAddresses.Contact");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.Interactions

// Receives a sender and addressees of an email.
//
// Parameters:
//  Ref  - DocumentRef.IncomingEmail - a document whose subscriber is to be received.
//
// Returns:
//   ValueTable   - Table containing the columns Contact, Presentation, and Address.
//
Function GetContacts(Ref) Export

	QueryText = 
		"SELECT
		|	IncomingEmail.Account.Email AS AccountEmailAddress
		|INTO OurAddress
		|FROM
		|	Document.IncomingEmail AS IncomingEmail
		|WHERE
		|	IncomingEmail.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IncomingEmail.SenderAddress AS Address,
		|	SUBSTRING(IncomingEmail.SenderPresentation, 1, 1000) AS Presentation,
		|	IncomingEmail.SenderContact AS Contact
		|INTO AllContacts
		|FROM
		|	Document.IncomingEmail AS IncomingEmail
		|WHERE
		|	IncomingEmail.Ref = &Ref
		|
		|UNION
		|
		|SELECT
		|	EmailIncomingEmailRecipients.Address,
		|	EmailIncomingEmailRecipients.Presentation,
		|	EmailIncomingEmailRecipients.Contact
		|FROM
		|	Document.IncomingEmail.EmailRecipients AS EmailIncomingEmailRecipients
		|WHERE
		|	EmailIncomingEmailRecipients.Ref = &Ref
		|
		|UNION
		|
		|SELECT
		|	EmailIncomingCopyRecipients.Address,
		|	EmailIncomingCopyRecipients.Presentation,
		|	EmailIncomingCopyRecipients.Contact
		|FROM
		|	Document.IncomingEmail.CCRecipients AS EmailIncomingCopyRecipients
		|WHERE
		|	EmailIncomingCopyRecipients.Ref = &Ref
		|
		|UNION
		|
		|SELECT
		|	EmailIncomingReplyRecipients.Address,
		|	EmailIncomingReplyRecipients.Presentation,
		|	EmailIncomingReplyRecipients.Contact
		|FROM
		|	Document.IncomingEmail.ReplyRecipients AS EmailIncomingReplyRecipients
		|WHERE
		|	EmailIncomingReplyRecipients.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllContacts.Address AS Address,
		|	MAX(AllContacts.Presentation) AS Presentation,
		|	MAX(AllContacts.Contact) AS Contact
		|FROM
		|	AllContacts AS AllContacts
		|		LEFT JOIN OurAddress AS OurAddress
		|		ON AllContacts.Address = OurAddress.AccountEmailAddress
		|WHERE
		|	OurAddress.AccountEmailAddress IS NULL
		|
		|GROUP BY
		|	AllContacts.Address";

	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	TableOfContacts = Query.Execute().Unload();

	Return Interactions.ConvertContactsTableToArray(TableOfContacts);
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmployeeResponsible, Disabled AS FALSE)
	|	OR CASE WHEN Account.AccountOwner = VALUE(Catalog.Users.EmptyRef) THEN
	|			ValueAllowed(Account, Disabled AS FALSE)
	|		ELSE
	|			IsAuthorizedUser(Account.AccountOwner)
	|		END";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defines the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	Documents.Meeting.AddGenerateCommand(GenerationCommands);
	Documents.PlannedInteraction.AddGenerateCommand(GenerationCommands);
	Documents.SMSMessage.AddGenerateCommand(GenerationCommands);
	Documents.PhoneCall.AddGenerateCommand(GenerationCommands);
	
EndProcedure

// Intended for use by the AddGenerationCommands procedure in other object manager modules.
// Adds this object to the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	Command = GenerateFrom.AddGenerationCommand(GenerationCommands, Metadata.Documents.IncomingEmail);
	If Command <> Undefined Then
		Command.Importance = "SeeAlso";
	EndIf;
	
	Return Command;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.IncomingEmail.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf



