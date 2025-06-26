///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2023, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Open the form to send a new text message.
//
// Parameters:
//  RecipientsNumbers - Array of Structure:
//   * Phone - String - Recipient's number in the format: +<CountryCode><LocalCode><Number>.
//   * Presentation - String - Phone number presentation.
//   * ContactInformationSource - CatalogRef - Phone number owner.
//  
//  Text - String - Message text with the max length of 1,000 characters.
//  
//  AdditionalParameters - Structure - additional text message sending parameters:
//   * SenderName - String - Sender's name that recipients will see instead of the phone number.
//   * Transliterate - Boolean - If True, transliterate the outgoing message.
//
Procedure SendSMS(RecipientsNumbers, Text, AdditionalParameters) Export

	SendSMSMessageClient.SendSMS(RecipientsNumbers, Text, AdditionalParameters);

EndProcedure

#EndRegion