///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#Region Public

// Determines the national alphabet letters.
//
// Parameters:
//   NationalAlphabetChars - String
//   AdditionalValidChars - String
//
Procedure OnDefineNationalAlphabetChars(NationalAlphabetChars, AdditionalValidChars) Export
EndProcedure

// Determine the codes of the characters that are not considered separators.
// (Unless a separator is specified explicitly.)
//
// Parameters:
//   Ranges - Array of Structure:
//    * Min - Number - The code of the range's start character.
//    * Max - Number - The code of the range's final character.
//
Procedure OnDefineWordChars(Ranges) Export
EndProcedure

#EndRegion



















