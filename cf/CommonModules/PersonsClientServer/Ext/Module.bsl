///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Parses a person's name into components (first name, middle name, and last name).
//
// Parameters:
//  FullName - See PersonsClientServerLocalization.OnDefineFullNameComponents.FullName
//  NameFormat - See PersonsClientServerLocalization.OnDefineFullNameComponents.NameFormat
//	
// Returns:
//   See PersonsClientServerLocalization.OnDefineFullNameComponents.Result
//
Function NameParts(FullName, Val NameFormat = "") Export
	
	Result = New Structure;
	
	PersonsClientServerLocalization.OnDefineFullNameComponents(FullName, NameFormat, Result);
	If ValueIsFilled(Result) Then
		Return Result;
	EndIf;
	
	Result = New Structure;
	Result.Insert("LastName", "");
	Result.Insert("Name", "");

	If Not ValueIsFilled(FullName) Then
		Return Result;
	EndIf;
	
	If Not ValueIsFilled(FullName) Then
		Return Result;
	EndIf;

	IsNameComesFirst = NameFormat = "Name,LastName" Or NameFormat = "";
	NameParts = StrSplit(FullName, " ", False); 
	
	If IsNameComesFirst Then
		If NameParts.Count() > 1 Then
			Result.LastName = NameParts[NameParts.UBound()];
			NameParts.Delete(NameParts.UBound());
		EndIf;
	
		Result.Name = StrConcat(NameParts, " ");
	Else
		If NameParts.Count() >= 1 Then
			Result.LastName = NameParts[0];
			NameParts.Delete(0);
		EndIf;
	
		Result.Name = StrConcat(NameParts, " ");
	EndIf;
	
	Return Result;
	
EndFunction

// Generates a presentation from a person's name.
//
// Parameters:
//  FullName - See PersonsClientServerLocalization.OnDefineSurnameAndInitials.FullName
//  FullNameFormat - See PersonsClientServerLocalization.OnDefineSurnameAndInitials.FullNameFormat
//  IsInitialsComeFirst - See PersonsClientServerLocalization.OnDefineSurnameAndInitials.IsInitialsComeFirst
//
// Returns:
//   See PersonsClientServerLocalization.OnDefineSurnameAndInitials.Result
//
Function InitialsAndLastName(Val FullName, Val FullNameFormat = "", Val IsInitialsComeFirst = False) Export
	
	Result = "";
	
	PersonsClientServerLocalization.OnDefineSurnameAndInitials(FullName, FullNameFormat, IsInitialsComeFirst, Result);
	If ValueIsFilled(Result) Or Not ValueIsFilled(FullName) Then
		Return Result;
	EndIf;
	
	If TypeOf(FullName) = Type("String") Then
		FullName = NameParts(FullName);
	EndIf;
	
	LastName = FullName.LastName;
	Name = FullName.Name;
	
	If IsBlankString(Name) Then
		Return LastName;
	EndIf;
	
	If FullNameFormat = "Name,LastName" Then
		Template = "%2. %1";
	Else
		Template = "%1 %2.";
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(Template, LastName, Left(Name, 1));
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use "StringFunctionsClientServer.IsStringContainsOnlyNationalAlphabetChars".
// 
// The function validates persons' names.
// A name is considered valid if it contains either only national alphabet letters or only Latin letters.
//
// Parameters:
//  LastFirstName - String - A person's name.
//  IsOnlyNationalScriptLetters - Boolean - Flag indicating that valid names should contain only national alphabet letters.
//
// Returns:
//  Boolean - "True" if the name is valid.
//
Function FullNameWrittenCorrectly(Val LastFirstName, IsOnlyNationalScriptLetters = False) Export
	
	CheckResult = True;
	PersonsClientServerLocalization.FullNameWrittenCorrectly(LastFirstName, IsOnlyNationalScriptLetters, CheckResult);
	
	Return CheckResult;
	
EndFunction

#EndRegion

#EndRegion
