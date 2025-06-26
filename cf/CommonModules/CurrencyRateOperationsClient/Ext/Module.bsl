///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Procedure ShowExchangeRatesImport(FormParameters = Undefined) Export
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParameters.Property("Currencies") And ClientParameters.Currencies.ExchangeRatesUpdateRequired Then
		AttachIdleHandler("CurrencyRateOperationsOutputObsoleteDataNotification", 180, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Update currency rates.

Function SettingsOnClient()
	
	ParameterName = "StandardSubsystems.Currencies";
	Settings = ApplicationParameters[ParameterName];
	
	If Settings = Undefined Then
		Settings = New Structure;
		Settings.Insert("LastNotificationDayStart", '00010101');
		ApplicationParameters[ParameterName] = Settings;
	EndIf;
	
	Return Settings;
	
EndFunction

Procedure NotifyRatesObsolete(Val ShouldCheckValidity = False) Export
	
	If ShouldCheckValidity And CurrenciesExchangeRatesServerCall.RatesUpToDate() Then
		Return;
	EndIf;
	
	DateStartOfDay = BegOfDay(CommonClient.SessionDate());
	Settings = SettingsOnClient();
	
	If Settings.LastNotificationDayStart >= DateStartOfDay Then
		Return;
	EndIf;
	Settings.LastNotificationDayStart = DateStartOfDay;
	
	ShowNotification(
		NStr("en = 'Outdated exchange rates';"),
		DataProcessorURL(),
		NStr("en = 'Update exchange rates';"),
		PictureLib.DialogExclamation,
		UserNotificationStatus.Important,
		"ExchangeRatesAreOutdated");
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyRatesAreUpdated() Export
	
	ShowUserNotification(
		NStr("en = 'Exchange rates updated';"),
		,
		NStr("en = 'The exchange rates are updated.';"),
		PictureLib.DialogInformation);
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyRatesUpToDate() Export
	
	ShowMessageBox(,NStr("en = 'Up-to-date exchange rates are imported.';"));
	
EndProcedure

// Returns a notification URL.
//
Function DataProcessorURL()
	Return "e1cib/app/DataProcessor.CurrenciesRatesImport";
EndFunction

Procedure ShowNotification(Text, ActionOnClick, Explanation, Picture, Var_UserNotificationStatus, UniqueKey)
	
	ShowUserNotification(
		Text,
		ActionOnClick,
		Explanation,
		Picture,
		Var_UserNotificationStatus,
		UniqueKey);
		
EndProcedure

#EndRegion
