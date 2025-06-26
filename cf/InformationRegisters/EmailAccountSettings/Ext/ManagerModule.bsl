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

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmailAccount)
	|	OR ValueAllowed(EmailAccount.AccountOwner, EmptyRef AS FALSE)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Internal

// Updates email's last usage date.
//
// Parameters:
//  Account     - CatalogRef.EmailAccounts - Email account being updated.
//  DateOfUse - Date - Email's last usage date. If nothing is passed, set to the current date.
//
Procedure UpdateTheAccountUsageDate(Account, DateOfUse = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.EmailAccountSettings");
	LockItem.SetValue("EmailAccount", Account);
	
	RecordSet = InformationRegisters.EmailAccountSettings.CreateRecordSet();
	RecordSet.Filter.EmailAccount.Set(Account);
	
	If DateOfUse = Undefined Then
		DateOfUse = BegOfDay(CurrentSessionDate());
	EndIf;
	
	WritingRequired = False;
	
	BeginTransaction();
	Try
		
		Block.Lock();
		
		RecordSet.Read();
		
		If RecordSet.Count() > 0 Then
			
			If RecordSet[0].DateOfLastUse <> DateOfUse Then
				
				RecordSet[0].DateOfLastUse = DateOfUse;
				WritingRequired = True;
				
			EndIf;
			
		Else
			
			SetRecord = RecordSet.Add();
			SetRecord.DateOfLastUse   = DateOfUse;
			SetRecord.EmailAccount = Account;
			
			WritingRequired = True;
		
		EndIf;
		
		If WritingRequired Then
			RecordSet.Write();
		EndIf;
		
		CommitTransaction();
	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
