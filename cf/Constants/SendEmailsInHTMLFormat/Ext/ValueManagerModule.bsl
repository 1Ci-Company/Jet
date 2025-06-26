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

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Block = New DataLock;
		Block.Add("InformationRegister.EmailAccountSettings");
		Block.Lock();
		
		// Switching signatures of all email accounts to plain text.
		AccountsSettings = InformationRegisters.EmailAccountSettings.CreateRecordSet();
		AccountsSettings.Read();
		For Each Setting In AccountsSettings Do
			Setting.NewMessageSignatureFormat = Enums.EmailEditingMethods.NormalText;
			Setting.ReplyForwardSignatureFormat = Enums.EmailEditingMethods.NormalText;
		EndDo;
		If AccountsSettings.Modified() Then
			AccountsSettings.Write();
		EndIf;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf