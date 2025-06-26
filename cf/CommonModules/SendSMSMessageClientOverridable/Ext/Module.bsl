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

// Called before opening a text messaging form.
//
// Parameters:
//  RecipientsNumbers - Array of Structure:
//   * Phone - String - Recipient's number in the format: +<CountryCode><LocalCode><Number>.
//   * Presentation - String - Phone number presentation.
//   * ContactInformationSource - CatalogRef - Phone number owner.
//  
//  Text - String - Message text with the max length of 1,000 characters.
//  
//  AdditionalParameters - Structure - Additional text message send parameters:
//   * SenderName - String - Sender's name that recipients will see instead of the phone number.
//   * Transliterate - Boolean - If True, transliterate the outgoing message.
//
//  StandardProcessing - Boolean -  a flag showing whether the standard processing of text message sending is to be executed.
//
Procedure OnSendSMSMessage(RecipientsNumbers, Text, AdditionalParameters, StandardProcessing) Export
	
EndProcedure

// This procedure defines the provider's page URL.
//
// Parameters:
//  Provider - EnumRef.SMSProviders - SMS provider.
//  InternetAddress - String - Provider's page URL.
//
Procedure OnGetProviderInternetAddress(Provider, InternetAddress) Export
	
	
	
EndProcedure

#EndRegion
