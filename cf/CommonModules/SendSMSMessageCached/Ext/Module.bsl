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

Function DeliveryStatuses(MessagesIDs) Export
	
	SendSMSMessage.CheckRights();
	IDsList = StrSplit(MessagesIDs, ",", False);
	DeliveryStatuses = New Map();
	
	For Each MessageID In IDsList Do
		DeliveryStatuses[MessageID] = "Error";
	EndDo;
	
	If Not ValueIsFilled(IDsList) Then
		Return New FixedMap(DeliveryStatuses);
	EndIf;
	
	SetPrivilegedMode(True);
	SMSMessageSendingSettings = SendSMSMessage.SMSMessageSendingSettings();
	SetPrivilegedMode(False);
	
	ModuleSMSMessageSendingViaProvider = SendSMSMessage.ModuleSMSMessageSendingViaProvider(SMSMessageSendingSettings.Provider);
	If ModuleSMSMessageSendingViaProvider <> Undefined Then
		ProviderSettings = SendSMSMessage.ProviderSettings(SMSMessageSendingSettings.Provider);
		
		If ProviderSettings.DeliveryStatusesInOneRequest Then
			DeliveryStatuses = ModuleSMSMessageSendingViaProvider.DeliveryStatuses(IDsList, SMSMessageSendingSettings);
		Else
			For Each MessageID In IDsList Do
				DeliveryStatuses[MessageID] = ModuleSMSMessageSendingViaProvider.DeliveryStatus(MessageID, SMSMessageSendingSettings);
			EndDo;
		EndIf;
		
	ElsIf ValueIsFilled(SMSMessageSendingSettings.Provider) Then
		For Each MessageID In IDsList Do
			Result = Undefined;
			SendSMSMessageOverridable.DeliveryStatus(MessageID, SMSMessageSendingSettings.Provider,
				SMSMessageSendingSettings.Login, SMSMessageSendingSettings.Password, Result);
			
			DeliveryStatuses[MessageID] = Result;
		EndDo;
	EndIf;
	
	Return New FixedMap(DeliveryStatuses);
	
EndFunction

Function CanSendSMSMessage() Export
	
	Return AccessRight("View", Metadata.CommonForms.SendSMSMessage) And SendSMSMessage.SMSMessageSendingSetupCompleted()
		Or Users.IsFullUser();
	
EndFunction

#EndRegion