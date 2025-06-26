///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("PopulateOSUsers", 0.1, True);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDomainsTable

&AtClient
Procedure DomainsTableOnActivateRow(Item)
	
	CurrentDomainUsersList.Clear();
	
	If Item.CurrentData <> Undefined Then
		DomainName = Item.CurrentData.DomainName;
		
		For Each Record In DomainsAndUsersTable Do
			If Record.DomainName = DomainName Then
				
				For Each User In Record.Users Do
					DomainUser = CurrentDomainUsersList.Add();
					DomainUser.UserName = User;
				EndDo;
				Break;
				
			EndIf;
		EndDo;
		
		CurrentDomainUsersList.Sort("UserName");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersUsersTable

&AtClient
Procedure DomainUsersTableSelection(Item, RowSelected, Field, StandardProcessing)
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	If Items.DomainsTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a domain.';"));
		Return;
	EndIf;
	
	If Items.DomainUsersTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en = 'Select a domain user.';"));
		Return;
	EndIf;
	
	ComposeResultAndCloseForm();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure PopulateOSUsers()
	
#If ThickClientOrdinaryApplication Or ThickClientManagedApplication Then
	DomainsAndUsersTable = OSUsers();
#ElsIf ThinClient Then
	DomainsAndUsersTable = New FixedArray (OSUsers());
#EndIf
	
	DomainsList.Clear();
	
	For Each Record In DomainsAndUsersTable Do
		Domain = DomainsList.Add();
		Domain.DomainName = Record.DomainName;
	EndDo;
	
	DomainsList.Sort("DomainName");
	
	Items.Pages.CurrentPage = Items.PageChoice;
	
EndProcedure

&AtClient
Procedure ComposeResultAndCloseForm()
	
	DomainName = Items.DomainsTable.CurrentData.DomainName;
	UserName = Items.DomainUsersTable.CurrentData.UserName;
	
	SelectionResult = "\\" + DomainName + "\" + UserName;
	NotifyChoice(SelectionResult);
	
EndProcedure

#EndRegion
