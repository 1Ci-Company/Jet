///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Sends a text message via a configured SMS provider.
//
// Parameters:
//  SendOptions - Structure:
//   * Provider          - EnumRef.SMSProviders - SMS provider.
//   * RecipientsNumbers  - Array - Array of recipient numbers in the format +XXXXXXXXXX.
//   * Text              - String - Message text. The max length varies depending on the SMS provider.
//   * SenderName     - String - Sender's name that recipients will see instead of the phone number.
//   * Login              - String - Username to authenticate to an SMS service.
//   * Password             - String - Password to authenticate to an SMS service.
//   
//  Result - Structure - return value. A sending result:
//    * SentMessages - Array of Structure:
//     ** RecipientNumber - String - a recipient number from the RecipientsNumbers array.
//     ** MessageID - String - a text message ID by which delivery status can be requested.
//    ErrorDetails - String - a user presentation of an error. If the string is empty, there is no error.
//
Procedure SendSMS(SendOptions, Result) Export
	
	
	
EndProcedure

// This procedure requests for text message delivery status from service provider.
//
// Parameters:
//  MessageID - String - ID assigned to a text message upon sending.
//  Provider - EnumRef.SMSProviders - SMS provider.
//  Login              - String - Username to authenticate to an SMS service.
//  Password             - String - Password to authenticate to an SMS service.
//  Result          - See SendSMSMessage.DeliveryStatus.
//
Procedure DeliveryStatus(MessageID, Provider, Login, Password, Result) Export 
	
	
	
EndProcedure

// This function checks whether saved text message sending settings are correct.
//
// Parameters:
//  SMSMessageSendingSettings - Structure - Details of the current send settings:
//   * Provider - EnumRef.SMSProviders
//   * Login - String
//   * Password - String
//   * SenderName - String
//  Cancel - Boolean - set this parameter to True if the settings are not filled in or filled in incorrectly.
//
Procedure OnCheckSMSMessageSendingSettings(SMSMessageSendingSettings, Cancel) Export

EndProcedure

// This procedure supplements the list of permissions required for sending text messages.
//
// Parameters:
//  Permissions - Array - Array of objects returned by one of the functions that match the mask SafeModeManager.Permission*().
//
Procedure OnGetPermissions(Permissions) Export
	
EndProcedure

#EndRegion
