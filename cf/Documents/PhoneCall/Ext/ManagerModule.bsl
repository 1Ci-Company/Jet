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
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Incoming");
	Result.Add("Comment");
	Result.Add("SubscriberContact");
	Result.Add("SubscriberPresentation");
	Result.Add("HowToContactSubscriber");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.Interactions

// Gets a phone call subscriber.
//
// Parameters:
//  Ref  - DocumentRef.PhoneCall - a document whose subscriber is to be received.
//
// Returns:
//   ValueTable   - Table containing the columns Contact, Presentation, and Address.
//
Function GetContacts(Ref) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PhoneCall.SubscriberContact AS Contact,
	|	PhoneCall.HowToContactSubscriber AS Address,
	|	PhoneCall.SubscriberPresentation AS Presentation
	|FROM
	|	Document.PhoneCall AS PhoneCall
	|WHERE
	|	PhoneCall.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Interactions.GetParticipantByFields(Selection.Contact, Selection.Address, Selection.Presentation);
	Else
		Return Undefined;
	EndIf;
	
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
	|	OR ValueAllowed(Author, Disabled AS FALSE)";
	
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
	AddGenerateCommand(GenerationCommands);
	Documents.OutgoingEmail.AddGenerateCommand(GenerationCommands);
	
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
	
	Command = GenerateFrom.AddGenerationCommand(GenerationCommands, Metadata.Documents.PhoneCall);
	If Command <> Undefined Then
		Command.FunctionalOptions = "UseOtherInteractions";
		Command.Importance = "SeeAlso";
	EndIf;
	
	Return Command;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.PhoneCall.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf