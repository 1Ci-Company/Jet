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
//  Contacts  - Array - an array of structures describing interaction participants.
//
Procedure FillContacts(Contacts) Export
	
	Interactions.FillContactsForMeeting(Contacts, SMSMessageRecipients, Enums.ContactInformationTypes.Phone, True);
	
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
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
		If ModuleMessageTemplates.IsTemplate1(FillingData) Then
			FillBasedOnTemplate(FillingData);
			Return;
		EndIf;
	EndIf;
	
	Interactions.FillDefaultAttributes(ThisObject, FillingData);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Subject = Interactions.SubjectByMessageText(MessageText);
	Interactions.GenerateParticipantsList(ThisObject);
	
	For Each AddresseesRow In SMSMessageRecipients Do
		InteractionsLocalization.OnFormatPhoneNumberToSend(AddresseesRow.HowToContact, AddresseesRow.SendingNumber);
	EndDo;
	
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

#Region Private

Procedure FillBasedOnTemplate(TemplateRef1)
	
	ModuleMessageTemplates = Common.CommonModule("MessageTemplates");
	Message = ModuleMessageTemplates.GenerateMessage(TemplateRef1, Undefined, New UUID);
	
	MessageText  = Message.Text;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf