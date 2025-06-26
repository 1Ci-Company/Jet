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

#Region Variables

Var PreviousSettings1; // Filled "BeforeWrite" to use "OnWrite".

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// ACC:75-off - "DataExchange.Import" check must follow the change records in the Event log.
	PrepareChangesForLogging(PreviousSettings1);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	// ACC:75-off - "DataExchange.Import" check must follow the change records in the Event log.
	DoLogChanges(PreviousSettings1);
	// ACC:75-on
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Returns:
//  Structure:
//   * AreSeparateSettingsForExternalUsers - Boolean
//   * InactivityPeriodBeforeDenyingAuthorization - Number
//   * InactivityPeriodBeforeDenyingAuthorizationForExternalUsers - Number
//   * ShowInList - String
//   * NotificationLeadTimeBeforeAccessExpire - Number
//
Function SettingsToRegister(LogonSettings)
	
	Result = New Structure;
	Result.Insert("DataStructureVersion", 1);
	
	Result.Insert("AreSeparateSettingsForExternalUsers",
		LogonSettings.Overall.AreSeparateSettingsForExternalUsers);
	
	Result.Insert("InactivityPeriodBeforeDenyingAuthorization",
		LogonSettings.Users.InactivityPeriodBeforeDenyingAuthorization);
	
	Result.Insert("InactivityPeriodBeforeDenyingAuthorizationForExternalUsers",
		LogonSettings.ExternalUsers.InactivityPeriodBeforeDenyingAuthorization);
	
	Result.Insert("ShowInList",
		LogonSettings.Overall.ShowInList);
	
	Result.Insert("NotificationLeadTimeBeforeAccessExpire",
		LogonSettings.Overall.NotificationLeadTimeBeforeAccessExpire);
	
	Return Result;
	
EndFunction

Procedure PrepareChangesForLogging(PreviousSettings1)
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	PreviousSettings1 = SettingsToRegister(UsersInternal.LogonSettings());
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

Procedure DoLogChanges(PreviousSettings1)
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	NewSettings1 = SettingsToRegister(UsersInternal.LogonSettings());
	
	HasChanges = False;
	For Each KeyAndValue In NewSettings1 Do
		If PreviousSettings1[KeyAndValue.Key] <> KeyAndValue.Value Then
			HasChanges = True;
			Break;
		EndIf;
	EndDo;
	
	If Not HasChanges Then
		Return;
	EndIf;
	
	WriteLogEvent(
		UsersInternal.EventNameChangeLoginSettingsAdditionalForLogging(),
		EventLogLevel.Information,
		Metadata.InformationRegisters.UsersInfo,
		Common.ValueToXMLString(NewSettings1),
		,
		EventLogEntryTransactionMode.Transactional);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf