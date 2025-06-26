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

// Generates a string according to the specified pattern.
// The possible tag values in the template:
// - String  - formats text with style items described
//      in the style attribute.
// -  String  - highlights the line with an ImportantLabelFont style item
//      that matches the bold font.
// - String - adds a hyperlink.
// -  - adds a picture from the picture library.
// The style attribute is used to arrange the text. The attribute can be used for the span and a tags.
// First goes a style property name, then a style item name through the colon.
// Style properties:
//  - color - defines text color. For example, color: HyperlinkColor;
//  - background-color - defines color of the text background. For example, background-color: TotalsGroupBackground;
//  - font - defines text font. For example, font: MainListItem.
// Style properties are separated by semicolon. For example, style="color: HyperlinkColor; font: MainListItem"
// Nested tags are not supported.
//
// Parameters:
//  StringPattern - String - a string containing formatting tags.
//  Parameter<n>  - String - parameter value to insert.
//
// Returns:
//  FormattedString - a converted string.
//
// Example:
//  1. StringFunctionsClient.FormattedString(NStr("en='
//       Minimum version 1.1. 
//       Update the app.'"));
//  2. StringFunctionsClient.FormattedString(NStr("en='Mode: 
//       Edit'"));
//       3. StringFunctionsClient.FormattedString(NStr("en='Current date 
//  %1'"), CurrentSessionDate());
//       
//
Function FormattedString(Val StringPattern, Val Parameter1 = Undefined, Val Parameter2 = Undefined,
	Val Parameter3 = Undefined, Val Parameter4 = Undefined, Val Parameter5 = Undefined) Export
	
	StyleItems = StandardSubsystemsServer.StyleItems();
	Return StringFunctionsClientServer.GenerateFormattedString(StringPattern, StyleItems, Parameter1, Parameter2, Parameter3, Parameter4, Parameter5);
	
EndFunction

// Transliterates the source string.
// It can be used to send text messages in Latin characters or to save
// files and folders to ensure that they can be transferred between different operating systems.
// Reverse conversion from the Latin character is not available.
//
// Parameters:
//  Value - String - arbitrary string.
//
// Returns:
//  String - a string where Cyrillic is replaced by transliteration.
//
Function LatinString(Val Value) Export
	
	TransliterationRules = New Map;
	StandardSubsystemsClientServerLocalization.OnFillTransliterationRules(TransliterationRules);
	Return CommonInternalClientServer.LatinString(Value, TransliterationRules);
	
EndFunction

// Returns a lowercase period presentation, or uppercase
//  if a phrase or a sentence starts with the period.
//  For example, if the period must be displayed in the report heading
//  as "Sales for [StartDate] - [EndDate]",
//  the result will look like this: "Sales for February 2020 - March 2020".
//  
//
// Parameters:
//  StartDate - Date - Period start.
//  EndDate - Date - Period end.
//  FormatString - String - determines a period formatting method.
//  Capitalize - Boolean - True if the period presentation is the beginning of a sentence.
//                    The default value is False.
//
// Returns:
//   String - a period presentation in the required format and register.
//
Function PeriodPresentationInText(StartDate, EndDate, FormatString = "", Capitalize = False) Export 
	
	Return CommonInternalClientServer.PeriodPresentationInText(
		StartDate, EndDate, FormatString, Capitalize);
	
EndFunction

#EndRegion

