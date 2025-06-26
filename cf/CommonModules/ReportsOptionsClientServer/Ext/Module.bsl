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

// ID that is used for the home page in the ReportsOptionsOverridable module.
//
// Returns:
//   String - ID used for the home page in the ReportsOptionsOverridable module.
//
Function HomePageID() Export
	
	Return "Subsystems";
	
EndFunction

#EndRegion

#Region Internal

// Adds Key to Structure if it is missing.
//
// Parameters:
//   Structure - Structure    - Structure to be complemented.
//   Var_Key      - String       - Property name.
//   Value  - Arbitrary - Property value if it is missing from the structure.
//
Procedure AddKeyToStructure(Structure, Var_Key, Value = Undefined) Export
	If Not Structure.Property(Var_Key) Then
		Structure.Insert(Var_Key, Value);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Full subsystem name.
Function FullSubsystemName() Export
	Return "StandardSubsystems.ReportsOptions";
EndFunction

// Converts a search string to an array of words with unique values sorted by length descending.
Function ParseSearchStringIntoWordArray(SearchString) Export
	WordsAndTheirLength = New ValueList;
	StringLength = StrLen(SearchString);
	
	Word = "";
	WordLength = 0;
	QuotationMarkOpened = False;
	For CharacterNumber = 1 To StringLength Do
		CharCode = CharCode(SearchString, CharacterNumber);
		If CharCode = 34 Then // 34 - Double quotation mark (").
			QuotationMarkOpened = Not QuotationMarkOpened;
		ElsIf QuotationMarkOpened
			Or (CharCode >= 48 And CharCode <= 57) // Numerics.
			Or (CharCode >= 65 And CharCode <= 90) // Uppercase Latin characters
			Or (CharCode >= 97 And CharCode <= 122) // Lowercase Latin characters
			Or (CharCode >= 1040 And CharCode <= 1103) // Cyrillic characters.
			Or CharCode = 95 Then // Underline ( _ ) character.
			Word = Word + Char(CharCode);
			WordLength = WordLength + 1;
		ElsIf Word <> "" Then
			If WordsAndTheirLength.FindByValue(Word) = Undefined Then
				WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
			EndIf;
			Word = "";
			WordLength = 0;
		EndIf;
	EndDo;
	
	If Word <> "" And WordsAndTheirLength.FindByValue(Word) = Undefined Then
		WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
	EndIf;
	
	WordsAndTheirLength.SortByPresentation(SortDirection.Desc);
	
	Return WordsAndTheirLength.UnloadValues();
EndFunction

// The function converts a report type into a string ID.
Function ReportByStringType(Val ReportType, Val Report = Undefined) Export
	TypeOfReportType = TypeOf(ReportType);
	If TypeOfReportType = Type("String") Then
		Return ReportType;
	ElsIf TypeOfReportType = Type("EnumRef.ReportsTypes") Then
		If ReportType = PredefinedValue("Enum.ReportsTypes.BuiltIn") Then
			Return "BuiltIn";
		ElsIf ReportType = PredefinedValue("Enum.ReportsTypes.Extension") Then
			Return "Extension";
		ElsIf ReportType = PredefinedValue("Enum.ReportsTypes.Additional") Then
			Return "Additional";
		ElsIf ReportType = PredefinedValue("Enum.ReportsTypes.External") Then
			Return "External";
		Else
			Return Undefined;
		EndIf;
	Else
		If TypeOfReportType <> Type("Type") Then
			ReportType = TypeOf(Report);
		EndIf;
		If ReportType = Type("CatalogRef.MetadataObjectIDs") Then
			Return "BuiltIn";
		ElsIf ReportType = Type("CatalogRef.ExtensionObjectIDs") Then
			Return "Extension";
		ElsIf ReportType = Type("String") Then
			Return "External";
		Else
			Return "Additional";
		EndIf;
	EndIf;
EndFunction

#Region UserSettingsExchange

Function ApplyPassedSettingsActionName() Export 
	
	Return "ApplyPassedSettings";
	
EndFunction

#EndRegion

#EndRegion
