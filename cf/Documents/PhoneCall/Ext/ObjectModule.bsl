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

// The procedure generates participant list rows.
//
// Parameters:
//  Contacts  - Array - an array containing interaction participants.
//
Procedure FillContacts(Contacts) Export
	
	If Not Interactions.ContactsFilled(Contacts) Then
		Return;
	EndIf;
	
	// Moving the first contact to the phone call.
	Parameter = Contacts[0];
	If TypeOf(Parameter) = Type("Structure") Then
		SubscriberContact       = Parameter.Contact;
		HowToContactSubscriber  = Parameter.Address;
		SubscriberPresentation = Parameter.Presentation;
	Else
		SubscriberContact = Parameter;
	EndIf;
	
	Interactions.FinishFillingContactsFields(SubscriberContact, SubscriberPresentation, 
		HowToContactSubscriber, Enums.ContactInformationTypes.Phone);
	
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

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	Interactions.FillDefaultAttributes(ThisObject, FillingData);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	EmployeeResponsible    = Users.CurrentUser();
	Author            = Users.CurrentUser();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Interactions.OnWriteDocument(ThisObject);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf