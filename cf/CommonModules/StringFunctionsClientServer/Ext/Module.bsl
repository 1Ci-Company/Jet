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

// Splits the string into several strings by the specified separator. The separator can be any length.
// If the separator is a single-character string and the TrimNonprintableChars parameter is not used,
// we recommend that you use the StrSplit platform function.
//
// Parameters:
//  Value               - String - delimited text.
//  Separator            - String - a text separator, at least 1 character.
//  SkipEmptyStrings - Boolean - Indicates whether empty strings must be included in the result.
//    If this parameter is not set, the function executes in compatibility with its earlier version:
//     > if space is used as a separator, blank strings are not included in the result, for other separators blank strings
//       are included in the result;
//     > if String parameter does not contain significant characters (or it is an empty string) and space is used as a separator,
//       the function returns an array with a single empty string value (""). - if the String parameter does not contain significant characters (or it is an empty string) and
//       any character except space is used as a separator, the function returns an empty array.
//  TrimNonprintableChars - Boolean - a flag that shows whether nonprintable characters in the beginning and in the end of the found substrings are trimmed.
//
// Returns:
//  Array of String
//
// Example:
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray(",one,,two", ",")
//  - returns an array of 5 items, three of which are empty: "", "one", "", "two", "";
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray(",one,,two,", ",", True)
//  - returns an array of two items: "one", "two";
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray(" one   two  ", " ")
//  - returns an array of two items: "one", "two";
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray("")
//  - Returns an empty array;
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray("",,False)
//  - returns an array with one item ""(empty string);
//  StringFunctionsClientServer.SplitStringIntoSubstringsArray("", " ")
//  - returns an array with one item "" (empty string).
//
Function SplitStringIntoSubstringsArray(Val Value, Val Separator = ",", Val SkipEmptyStrings = Undefined, 
	TrimNonprintableChars = False) Export
	
	If StrLen(Separator) = 1 
		And SkipEmptyStrings = Undefined 
		And TrimNonprintableChars Then 
		
		Result = StrSplit(Value, Separator, False);
		For IndexOf = 0 To Result.UBound() Do
			Result[IndexOf] = TrimAll(Result[IndexOf])
		EndDo;
		Return Result;
		
	EndIf;
	
	Result = New Array;
	
	// For backward compatibility purposes.
	If SkipEmptyStrings = Undefined Then
		SkipEmptyStrings = ?(Separator = " ", True, False);
		If IsBlankString(Value) Then 
			If Separator = " " Then
				Result.Add("");
			EndIf;
			Return Result;
		EndIf;
	EndIf;
	//
	
	Position = StrFind(Value, Separator);
	While Position > 0 Do
		Substring = Left(Value, Position - 1);
		If Not SkipEmptyStrings Or Not IsBlankString(Substring) Then
			If TrimNonprintableChars Then
				Result.Add(TrimAll(Substring));
			Else
				Result.Add(Substring);
			EndIf;
		EndIf;
		Value = Mid(Value, Position + StrLen(Separator));
		Position = StrFind(Value, Separator);
	EndDo;
	
	If Not SkipEmptyStrings Or Not IsBlankString(Value) Then
		If TrimNonprintableChars Then
			Result.Add(TrimAll(Value));
		Else
			Result.Add(Value);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction 

// Determines whether the character is a separator.
//
// Parameters:
//  CharCode      - Number  - code of the char to check;
//  WordSeparators - String - string consisting of chars treated as separators. If the parameter is not specified, 
//                             all characters that are not digits, 
//                             Latin and Cyrillic letters, and an underscore, are considered as separators.
//
// Returns:
//  Boolean - True if a character with the CharCode code is a separator.
//
Function IsWordSeparator(CharCode, WordSeparators = Undefined) Export
	
	If WordSeparators <> Undefined Then
		Return StrFind(WordSeparators, Char(CharCode)) > 0;
	EndIf;
		
	Ranges = New Array;
	StringFunctionsClientServerLocalization.OnDefineWordChars(Ranges);
	Ranges.Add(New Structure("Min,Max", 48, 57)); 	// Digits.
	Ranges.Add(New Structure("Min,Max", 65, 90)); 	// Uppercase Latin characters.
	Ranges.Add(New Structure("Min,Max", 97, 122)); 	// Lowercase Latin characters.
	Ranges.Add(New Structure("Min,Max", 95, 95)); 	// Underline ( _ ) character.
	
	For Each Span In Ranges Do
		If CharCode >= Span.Min And CharCode <= Span.Max Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Splits the string into several strings using a specified separator set.
// If the WordSeparators parameter is not specified, any of the characters 
// that are not Latin characters, numeric characters, or the underscore character (_) are considered separators.
//
// Parameters:
//  Value        - String - a source string to be split into words.
//  WordSeparators - String - a list of separator characters. For example, ".,;".
//
// Returns:
//  Array - a words list.
//
// Example:
//  StringFunctionsClientServer.SplitStringIntoWordsArray("one-@#two2_!three") will return an array of values: "one",
//  "two2_", "three"; StringFunctionsClientServer.SplitStringIntoWordsArray("one-@#two2_!three", "#@!_") will return an array of
//  values: "one-", "two2", "three".
//
Function SplitStringIntoWordArray(Val Value, WordSeparators = Undefined) Export
	
	Words = New Array;
	
	TextSize = StrLen(Value);
	WordBeginning = 1;
	For Position = 1 To TextSize Do
		CharCode = CharCode(Value, Position);
		If IsWordSeparator(CharCode, WordSeparators) Then
			If Position <> WordBeginning Then
				Words.Add(Mid(Value, WordBeginning, Position - WordBeginning));
			EndIf;
			WordBeginning = Position + 1;
		EndIf;
	EndDo;
	
	If Position <> WordBeginning Then
		Words.Add(Mid(Value, WordBeginning, Position - WordBeginning));
	EndIf;
	
	Return Words;
	
EndFunction

// Substitutes parameters in a string. The maximum number of parameters is 9.
// Parameters in the string have the following format: %<parameter number>. The parameter numbering starts from 1.
//
// Parameters:
//  StringPattern  - String - string pattern with parameters formatted as "%<parameter number>", 
//                           for example, "%1 went to %2");
//  Parameter1   - String - parameter value to insert.
//  Parameter2   - String
//  Parameter3   - String
//  Parameter4   - String
//  Parameter5   - String
//  Parameter6   - String
//  Parameter7   - String
//  Parameter8   - String
//  Parameter9   - String
//
// Returns:
//  String   - text string with parameters inserted.
//
// Example:
//  StringFunctionsClientServer.SubstituteParametersToString(NStr("en='%1 went to %2'"), "Jane", "the zoo") = "Jane went
//  to the zoo".
//
Function SubstituteParametersToString(Val StringPattern,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	
	HasParametersWithPercentageChar = StrFind(Parameter1, "%")
		Or StrFind(Parameter2, "%")
		Or StrFind(Parameter3, "%")
		Or StrFind(Parameter4, "%")
		Or StrFind(Parameter5, "%")
		Or StrFind(Parameter6, "%")
		Or StrFind(Parameter7, "%")
		Or StrFind(Parameter8, "%")
		Or StrFind(Parameter9, "%");
		
	If HasParametersWithPercentageChar Then
		Return SubstituteParametersWithPercentageChar(StringPattern, Parameter1,
			Parameter2, Parameter3, Parameter4, Parameter5, Parameter6, Parameter7, Parameter8, Parameter9);
	EndIf;
	
	StringPattern = StrReplace(StringPattern, "%1", Parameter1);
	StringPattern = StrReplace(StringPattern, "%2", Parameter2);
	StringPattern = StrReplace(StringPattern, "%3", Parameter3);
	StringPattern = StrReplace(StringPattern, "%4", Parameter4);
	StringPattern = StrReplace(StringPattern, "%5", Parameter5);
	StringPattern = StrReplace(StringPattern, "%6", Parameter6);
	StringPattern = StrReplace(StringPattern, "%7", Parameter7);
	StringPattern = StrReplace(StringPattern, "%8", Parameter8);
	StringPattern = StrReplace(StringPattern, "%9", Parameter9);
	Return StringPattern;
	
EndFunction

// Substitutes parameters in a string. The number of the parameters in the string is unlimited.
// Parameters in the string have the following format: %<parameter number>. The parameter numbering
// starts from 1.
//
// Parameters:
//  StringPattern  - String - string pattern with parameters formatted as "%<parameter number>", 
//                           for example, "%1 went to %2");
//  Parameters     - Array - parameters values in the StringPattern string.
//
// Returns:
//   String - a string with inserted values of parameters.
//
// Example:
//  ParametersValues = New Array;
//  ParametersValues.Add("John");
//  ParametersValues.Add("Zoo");
//  Result = StringFunctionsClientServer.SubstituteParametersToStringFromArray(NStr("en='%1 went to %2'"), ParametersValues);
//  - returns the "John went to the Zoo" string.
//
Function SubstituteParametersToStringFromArray(Val StringPattern, Val Parameters) Export
	
	ResultString1 = StringPattern;
	
	IndexOf = Parameters.Count();
	While IndexOf > 0 Do
		Value = Parameters[IndexOf-1];
		If Not IsBlankString(Value) Then
			ResultString1 = StrReplace(ResultString1, "%" + Format(IndexOf, "NG="), Value);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return ResultString1;
	
EndFunction

// Substitutes parameter values for their names in the string pattern. Parameters in the string are enclosed in square
// brackets.
//
// Parameters:
//  StringPattern - String    - a string to insert values into.
//  Parameters    - Structure - Inserted values of parameters, where the key is the name of the parameter without special characters,
//                             the value is the inserted value.
//
// Returns:
//  String - a string with inserted values.
//
// Example:
//  Values = New Structure("LastName,Name", "Smith", "John");
//  Result = StringFunctionsClientServer.InsertParametersIntoString("Hello, [Имя] [Фамилия].", Values);
//  - Returns: "Hello, John Doe".
//
Function InsertParametersIntoString(Val StringPattern, Val Parameters) Export
	Result = StringPattern;
	For Each Parameter In Parameters Do
		Result = StrReplace(Result, "[" + Parameter.Key + "]", Parameter.Value);
	EndDo;
	Return Result;
EndFunction

// Gets parameter values from the string.
//
// Parameters:
//  ParametersString1 - String - String containing parameters. Each of the parameters is a key-value pair:
//                              <Parameter name>=<Value>:
//                                Substrings are separated from each other by the semicolon ( ; ). 
//                                Values with whitespaces must be enclosed in double quotation marks ( " ). 
//                              For example:
//                              "File=""c:\InfoBases\Trade""; Usr=""Director"";"
//                              
//                              
//                               
//  Separator - String - Separation character.
//
// Returns:
//  Structure - parameters values, where the key is the name of the parameter, the value is the parameter value.
//
// Example:
//  Result = StringFunctionsClientServer.ParametersFromString("File=""c:\InfoBases\Trade""; Usr=""Director"";""", ";");
//  - returns the structure:
//     the File key and the c:\InfoBases\Trade"
//     the Usr key and the Director value.
//
Function ParametersFromString(Val ParametersString1, Val Separator = ";") Export
	Result = New Structure;
	
	ParameterDetails = "";
	StringBeginningFound = False;
	LastCharNumber = StrLen(ParametersString1);
	For CharacterNumber = 1 To LastCharNumber Do
		Char =Mid(ParametersString1, CharacterNumber, 1);
		If Char = """" Then
			StringBeginningFound = Not StringBeginningFound;
		EndIf;
		If Char <> Separator Or StringBeginningFound Then
			ParameterDetails = ParameterDetails + Char;
		EndIf;
		If Char = Separator And Not StringBeginningFound Or CharacterNumber = LastCharNumber Then
			Position = StrFind(ParameterDetails, "=");
			If Position > 0 Then
				ParameterName = TrimAll(Left(ParameterDetails, Position - 1));
				ParameterValue = TrimAll(Mid(ParameterDetails, Position + 1));
				ParameterValue = RemoveDoubleQuotationMarks(ParameterValue);
				Result.Insert(ParameterName, ParameterValue);
			EndIf;
			ParameterDetails = "";
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Checks whether the string contains numeric characters only.
//
// Parameters:
//  Value         - String - a string to check.
//  Obsolete1       - Boolean - an obsolete parameter, not used.
//  SpacesProhibited - Boolean - If False spaces are allowed in the string.
//
// Returns:
//   Boolean - True - the string contains only numbers or is empty, False - the string contains other characters.
//
// Example:
//  Result = StringFunctionsClientServer.OnlyDigitsInString("0123"); // True
//  Result = StringFunctionsClientServer.OnlyDigitsInString("0123abc"); // False
//  Result = StringFunctionsClientServer.OnlyDigitsInString("01 2 3",, False); // True
//
Function OnlyNumbersInString(Val Value, Val Obsolete1 = True, Val SpacesProhibited = True) Export
	
	If TypeOf(Value) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not SpacesProhibited Then
		Value = StrReplace(Value, " ", "");
	EndIf;
		
	If StrLen(Value) = 0 Then
		Return True;
	EndIf;
	
	// If it contains only digits, its replacement will result in an empty string.
	// However, it cannot be validated using "IsBlankString" since the source string may contain whitespaces.
	Return StrLen(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace(
		StrReplace( StrReplace( StrReplace( StrReplace( StrReplace( 
			Value, "0", ""), "1", ""), "2", ""), "3", ""), "4", ""), "5", ""), "6", ""), "7", ""), "8", ""), "9", "")) = 0;
	
EndFunction

// Checks whether the string contains Latin characters only.
//
// Parameters:
//  CheckString - String - a string to check.
//  WithWordSeparators - Boolean - If True, treat word separators as legit characters.
//  AllowedChars - String - additional allowed characters except Latin.
//
// Returns:
//  Boolean - True if the string contains Latin or allowed chars only;
//           False otherwise.
//
Function OnlyRomanInString(Val CheckString, Val WithWordSeparators = True, AllowedChars = "") Export
	
	If TypeOf(CheckString) <> Type("String") Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(CheckString) Then
		Return True;
	EndIf;
	
	ValidCharCodes = New Array;
	
	For IndexOf = 1 To StrLen(AllowedChars) Do
		ValidCharCodes.Add(CharCode(Mid(AllowedChars, IndexOf, 1)));
	EndDo;
	
	For IndexOf = 1 To StrLen(CheckString) Do
		CharCode = CharCode(Mid(CheckString, IndexOf, 1));
		If ((CharCode < 65) Or (CharCode > 90 And CharCode < 97) Or (CharCode > 122))
			And (ValidCharCodes.Find(CharCode) = Undefined) 
			And Not (Not WithWordSeparators And IsWordSeparator(CharCode)) Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Validates strings by finding invalid characters.
//
// Parameters:
//  RowToValidate - String - String to validate.
//  AdditionalValidChars - Undefined, String - Additional valid characters.
//                                                           If left blank, only non-printing characters are valid:
//  	whitespace, non-breaking space, tab, line feed, and form feed. 
//  	
//
// Returns:
//  Boolean - "True" if the string contains only the valid characters.
//           Otherwise, "False".
//
Function IsStringContainsOnlyNationalAlphabetChars(Val RowToValidate, Val AdditionalValidChars = Undefined) Export
	
	NationalAlphabetChars = "abcdefghijklmnopqrstuvwxyz";
	StringFunctionsClientServerLocalization.OnDefineNationalAlphabetChars(NationalAlphabetChars, AdditionalValidChars);
	
	If AdditionalValidChars = Undefined Then
		AllowedChars = " " + Chars.Tab + Chars.LF + Chars.CR + Chars.VTab + Chars.NBSp + Chars.FF;
	EndIf;
	
	Return StrSplit(Lower(RowToValidate), NationalAlphabetChars + AdditionalValidChars, False).Count() = 0;
	
EndFunction

// Deletes double quotation marks from the beginning and the end of the string, if any.
//
// Parameters:
//  Value - String - a source string.
//
// Returns:
//  String - a string without double quotation marks.
// 
Function RemoveDoubleQuotationMarks(Val Value) Export
	
	While StrStartsWith(Value, """") Do
		Value = Mid(Value, 2); 
	EndDo; 
	
	While StrEndsWith(Value, """") Do
		Value = Left(Value, StrLen(Value) - 1);
	EndDo;
	
	Return Value;
	
EndFunction 

// Deletes the specified number of characters from the end of the string.
//
// Parameters:
//  Text         - String - a string where last characters need to be deleted;
//  CountOfCharacters - Number  - a number of characters to be deleted.
//
Procedure DeleteLastCharInString(Text, CountOfCharacters = 1) Export
	
	Text = Left(Text, StrLen(Text) - CountOfCharacters);
	
EndProcedure 

// Checks whether a string is a UUID.
// UUID is a string of the following kind
// "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", where X = [0..9,a..f].
//
// Parameters:
//  Value - String - a string to check.
//
// Returns:
//  Boolean - True if the passed string is a UUID.
//
Function IsUUID(Val Value) Export
	
	Template = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
	
	If StrLen(Template) <> StrLen(Value) Then
		Return False;
	EndIf;
	For Position = 1 To StrLen(Value) Do
		If CharCode(Template, Position) = 88 // X
			And ((CharCode(Value, Position) < 48 Or CharCode(Value, Position) > 57) // 0..9
			And (CharCode(Value, Position) < 97 Or CharCode(Value, Position) > 102) // a..f
			And (CharCode(Value, Position) < 65 Or CharCode(Value, Position) > 70)) // a..f
			Or CharCode(Template, Position) = 45 And CharCode(Value, Position) <> 45 Then // -
				Return False;
		EndIf;
	EndDo;
	
	Return True;

EndFunction

// Generates a string of the specified length filled with the specified character.
//
// Parameters:
//  Char      - String - a character used to generated a string.
//  StringLength - Number  - required length of a resulting row. 
//
// Returns:
//  String
//
Function GenerateCharacterString(Val Char, Val StringLength) Export
	
	If StringLength <= 0 Then
		Return "";
	EndIf;
	Return StrConcat(New Array(StringLength + 1), Char);
	
EndFunction

// Adds trailing or leading characters to a string if it is less than the given length.
// Prior to that, the function removes insignificant leading and trailing characters 
// (for more details, see the 1C:Enterprise method TrimAll in Syntax Assistant). 
// By default, the function adds leading zeros.
//
// Parameters:
//  Value    - String - a source string to be supplemented with characters;
//  StringLength - Number  - required resulting length of a row;
//  Char      - String - a character used for supplementing the string;
//  Mode       - String - "Left" or "Right" - an option to add characters to the source string.
// 
// Returns:
//  String - a string supplemented with characters.
//
// Example:
//  1. Result = StringFunctionsClientServer.SupplementString("1234", 10, "0", "Left");
//  Returns: "0000001234".
//
//  2. Result = StringFunctionsClientServer.SupplementString(" 1234  ", 10, "#", "Right");
//  String = " 1234  "; StringLength = 10; Char = "#"; Mode = "Right"
//  Returns: "1234######".
//
Function SupplementString(Val Value, Val StringLength, Val Char = "0", Val Mode = "Left") Export
	
	// The parameter must be a single character.
	Char = Left(Char, 1);
	
	// Deleting spaces on the left and on the right of the string.
	Value = TrimAll(Value);
	CharsToAddCount = StringLength - StrLen(Value);
	
	If CharsToAddCount > 0 Then
		
		StringToAdd = GenerateCharacterString(Char, CharsToAddCount);
		If Upper(Mode) = "LEFT" Then
			Value = StringToAdd + Value;
		ElsIf Upper(Mode) = "RIGHT" Then
			Value = Value + StringToAdd;
		EndIf;
		
	EndIf;
	
	Return Value;
	
EndFunction

// Deletes repeating characters on the left or on the right of the string.
//
// Parameters:
//  Value        - String - a source string where repeating characters on the left or on the right should be deleted;
//  CharToDelete - String - a required character to be deleted;
//  Mode           - String - "Left" or "Right" - a mode of character deletion in the source string.
//
// Returns:
//  String - a cut string.
//
Function DeleteDuplicateChars(Val Value, Val CharToDelete, Val Mode = "Left") Export
	
	If Upper(Mode) = "LEFT" Then
		While Left(Value, 1) = CharToDelete Do
			Value = Mid(Value, 2);
		EndDo;
	ElsIf Upper(Mode) = "RIGHT" Then
		While Right(Value, 1) = CharToDelete Do
			Value = Left(Value, StrLen(Value) - 1);
		EndDo;
	EndIf;
	
	Return Value;
	
EndFunction

// Replaces characters in the string.
// The function is designed for simple replacement scenarios, for example, for replacing the Ä character with the A character.
//
// Parameters:
//  CharsToReplace - String - a string of characters to be replaced;
//  Value          - String - a source string in which character replacement is required;
//  ReplacementChars     - String - a string of characters to be replaced by the characters of the
//                               CharsToReplace.
// 
// Returns:
//  String - a string after characters replacement.
//
Function ReplaceCharsWithOther(CharsToReplace, Value, ReplacementChars) Export
	
	Result = Value;
	
	For CharacterNumber = 1 To StrLen(CharsToReplace) Do
		Result = StrReplace(Result, Mid(CharsToReplace, CharacterNumber, 1), Mid(ReplacementChars, CharacterNumber, 1));
	EndDo;
	
	Return Result;
	
EndFunction

// Converts the Arabic number into a Roman one.
//
// Parameters:
//  ArabicNumber - Number - a number, integer from 0 to 999;
//  UseLatinChars - Boolean - use Cyrillic or Latin alphabet as a Roman digits.
//
// Returns:
//  String - a number in Latin notation.
//
// Example:
//  StringFunctionsClientServer.ConvertNumberIntoRomanNotation("XVII") = 17.
//
Function ConvertNumberIntoRomanNotation(ArabicNumber, UseLatinChars = True) Export
	
	RomanNumber = "";
	ArabicNumber = SupplementString(ArabicNumber, 3);
	
	If UseLatinChars Then
		c1 = "1"; c5 = "U"; c10 = "X"; c50 = "L"; c100 ="From1"; c500 = "D"; c1000 = "M";
		
	Else
		c1 = "I"; c5 = "V"; c10 = "X"; c50 = "L"; c100 ="C"; c500 = "D"; c1000 = "M";
		
	EndIf;
	
	Units	= Number(Mid(ArabicNumber, 3, 1));
	Tens	= Number(Mid(ArabicNumber, 2, 1));
	Hundreds	= Number(Mid(ArabicNumber, 1, 1));
	
	RomanNumber = RomanNumber + ConvertFigureIntoRomanNotation(Hundreds, c100, c500, c1000);
	RomanNumber = RomanNumber + ConvertFigureIntoRomanNotation(Tens, c10, c50, c100);
	RomanNumber = RomanNumber + ConvertFigureIntoRomanNotation(Units, c1, c5, c10);
	
	Return RomanNumber;
	
EndFunction 

// Converts the Roman number into an Arabic one.
//
// Parameters:
//  RomanNumber - String - a number written in roman numerals;
//  UseLatinChars - Boolean - use Cyrillic or Latin alphabet as a Roman digits.
//
// Returns:
//  Number - Converted number.
//
// Example:
//  StringFunctionsClientServer.ConvertNumberIntoArabicNotation("XVII") = 17.
//
Function ConvertNumberIntoArabicNotation(RomanNumber, UseLatinChars = True) Export
	
	ArabicNumber = 0;
	
	If UseLatinChars Then
		c1 = "1"; c5 = "U"; c10 = "X"; c50 = "L"; c100 ="From1"; c500 = "D"; c1000 = "M";
	Else
		c1 = "I"; c5 = "V"; c10 = "X"; c50 = "L"; c100 ="C"; c500 = "D"; c1000 = "M";
	EndIf;
	
	RomanNumber = TrimAll(RomanNumber);
	CountOfCharacters = StrLen(RomanNumber);
	
	For Cnt = 1 To CountOfCharacters Do
		If Mid(RomanNumber,Cnt,1) = c1000 Then
			ArabicNumber = ArabicNumber+1000;
		ElsIf Mid(RomanNumber,Cnt,1) = c500 Then
			ArabicNumber = ArabicNumber+500;
		ElsIf Mid(RomanNumber,Cnt,1) = c100 Then
			If (Cnt < CountOfCharacters) And ((Mid(RomanNumber,Cnt+1,1) = c500) Or (Mid(RomanNumber,Cnt+1,1) = c1000)) Then
				ArabicNumber = ArabicNumber-100;
			Else
				ArabicNumber = ArabicNumber+100;
			EndIf;
		ElsIf Mid(RomanNumber,Cnt,1) = c50 Then
			ArabicNumber = ArabicNumber+50;
		ElsIf Mid(RomanNumber,Cnt,1) = c10 Then
			If (Cnt < CountOfCharacters) And ((Mid(RomanNumber,Cnt+1,1) = c50) Or (Mid(RomanNumber,Cnt+1,1) = c100)) Then
				ArabicNumber = ArabicNumber-10;
			Else
				ArabicNumber = ArabicNumber+10;
			EndIf;
		ElsIf Mid(RomanNumber,Cnt,1) = c5 Then
			ArabicNumber = ArabicNumber+5;
		ElsIf Mid(RomanNumber,Cnt,1) = c1 Then
			If (Cnt < CountOfCharacters) And ((Mid(RomanNumber,Cnt+1,1) = c5) Or (Mid(RomanNumber,Cnt+1,1) = c10)) Then
				ArabicNumber = ArabicNumber-1;
			Else
				ArabicNumber = ArabicNumber+1;
			EndIf;
		EndIf;
	EndDo;
	
	Return ArabicNumber;
	
EndFunction 

// Deletes HTML tags from the text and returns an unformatted text. 
//
// Parameters:
//  SourceText - String - Text in the HTML format.
//
// Returns:
//  String - Text with removed tags, scripts, and headers.
//
Function ExtractTextFromHTML(Val SourceText) Export
	Result = "";
	
	Text = Lower(SourceText);
	
	// Remove everything but the body.
	Position = StrFind(Text, "<body");
	If Position > 0 Then
		Text = Mid(Text, Position + 5);
		SourceText = Mid(SourceText, Position + 5);
		Position = StrFind(Text, ">");
		If Position > 0 Then
			Text = Mid(Text, Position + 1);
			SourceText = Mid(SourceText, Position + 1);
		EndIf;
	EndIf;
	
	Position = StrFind(Text, "</body>");
	If Position > 0 Then
		Text = Left(Text, Position - 1);
		SourceText = Left(SourceText, Position - 1);
	EndIf;
	
	// Remove scripts.
	Position = StrFind(Text, "<script");
	While Position > 0 Do
		ClosingTagPosition = StrFind(Text, "</script>");
		If ClosingTagPosition = 0 Then
			// The closing tag is not found, cut out the remaining text.
			ClosingTagPosition = StrLen(Text);
		EndIf;
		Text = Left(Text, Position - 1) + Mid(Text, ClosingTagPosition + 9);
		SourceText = Left(SourceText, Position - 1) + Mid(SourceText, ClosingTagPosition + 9);
		Position = StrFind(Text, "<script");
	EndDo;
	
	// Remove styles.
	Position = StrFind(Text, "<style");
	While Position > 0 Do
		ClosingTagPosition = StrFind(Text, "</style>");
		If ClosingTagPosition = 0 Then
			// The closing tag is not found, cut out the remaining text.
			ClosingTagPosition = StrLen(Text);
		EndIf;
		Text = Left(Text, Position - 1) + Mid(Text, ClosingTagPosition + 8);
		SourceText = Left(SourceText, Position - 1) + Mid(SourceText, ClosingTagPosition + 8);
		Position = StrFind(Text, "<style");
	EndDo;
	
	// Remove tags.	
	Position = StrFind(Text, "<");
	While Position > 0 Do
		Result = Result + Left(SourceText, Position-1);
		Text = Mid(Text, Position + 1);
		SourceText = Mid(SourceText, Position + 1);
		Position = StrFind(Text, ">");
		If Position > 0 Then
			Text = Mid(Text, Position + 1);
			SourceText = Mid(SourceText, Position + 1);
		EndIf;
		Position = StrFind(Text, "<");
	EndDo;
	Result = Result + SourceText;
	RowsArray = SplitStringIntoSubstringsArray(Result, Chars.LF, True, True);
	Return TrimAll(StrConcat(RowsArray, Chars.LF));
EndFunction

// Converts the source string into a number without calling exceptions.
//
// Parameters:
//   Value - String - a string to be transformed into a number.
//                       For example, "10", "+10", "010", will return 10;
//                                 "(10)", "-10", will return -10;
//                                 "10,2", "10.2", will return 10.2;
//                                 "000", " ", "",will return 0;
//                                 "10text", will return Undefined.
//
// Returns:
//   Number, Undefined - received number or Undefined if the string is not a number.
//
Function StringToNumber(Val Value) Export
	
	Value  = StrReplace(Value, " ", "");
	If StrStartsWith(Value, "(") Then
		Value = StrReplace(Value, "(", "-");
		Value = StrReplace(Value, ")", "");
	EndIf;
	
	StringWithoutZeroes = StrReplace(Value, "0", "");
	If IsBlankString(StringWithoutZeroes) Or StringWithoutZeroes = "-" Then
		Return 0;
	EndIf;
	
	NumberType  = New TypeDescription("Number");
	Result = NumberType.AdjustValue(Value);
	
	Return ?(Result <> 0 And Not IsBlankString(StringWithoutZeroes), Result, Undefined);
	
EndFunction

// Converts a source string into a date. 
// If the date can not be recognized, a blank date is returned (01.01.01 00:00:00).
//
// Parameters:
//  Value - String - a string to be transformed into a date.
//                      Date format must look like DD.MM.YYYY, DD/MM/YY, or DD-MM-YY HH:MM:SS,
//                      For example, "23.02.1980" or "23/02/80 09:15:45".
//  DatePart - DateFractions - determines the allowed date parts. The default value is DateParts.Date.
// 
// Returns:
//  Date
//
Function StringToDate(Val Value, DatePart = Undefined) Export
	
	NumbersSet = "1234567890";
	
	If TypeOf(DatePart) <> Type("DateFractions") Then
		DatePart = DateFractions.Date;
	EndIf;
	
	DateParameters = New DateQualifiers(DatePart);
	DateTypeDetails = New TypeDescription("Date",,, DateParameters);
	
	Value = Upper(StrConcat(StrSplit(TrimAll(Value), Chars.NBSp + Chars.LF + Chars.Tab), " "));
	Result = DateTypeDetails.AdjustValue(Value);
	
	For MonthNumber = 1 To 12 Do
		Value = StrReplace(Value, Upper(Format(Date(1, MonthNumber, 2), "DF=MMMM")), Format(MonthNumber, "ND=2; NLZ="));
		Value = StrReplace(Value, Upper(Format(Date(1, MonthNumber, 2), "DF=MMM")), Format(MonthNumber, "ND=2; NLZ="));
	EndDo;
	
	NonNumericArray = StrSplit(Value, NumbersSet);
	If NonNumericArray.Count() < 2 Then
		Return Result;
	EndIf;
	
	FirstNumberPosition = StrLen(NonNumericArray[0]);
	LastNumberPosition = StrLen(Value) - StrLen(NonNumericArray[NonNumericArray.UBound()]);
	Value = Mid(Value, FirstNumberPosition, LastNumberPosition - FirstNumberPosition);
	If IsBlankString(Value) Then
		Return Result;
	EndIf;
	
	ValueAsArray = StrSplit(Value, " ");
	Item = ValueAsArray[ValueAsArray.UBound()];
	If ValueAsArray.Count() > 1 Then
		If StrLen(Item) = 2 Or StrLen(Item) = 4 Then
			
			IsOnlyNumbers = StrSplit(Item, NumbersSet, False).Count() = 0;
			If IsOnlyNumbers Then
				DateValue = Value;
				TimeValue = "";
			Else
				TimeValue = Item;
				ValueAsArray.Delete(ValueAsArray.UBound());
				DateValue = StrConcat(ValueAsArray, " ");
			EndIf;
		Else
			
			TimeValue = Item;
			ValueAsArray.Delete(ValueAsArray.UBound());
			DateValue = StrConcat(ValueAsArray, " ");
		EndIf;
	Else
		
		IsOnlyNumbers = StrSplit(Item, NumbersSet, False).Count() = 0;
		If IsOnlyNumbers Then
			
			Result = DateTypeDetails.AdjustValue(Item);
			If Not ValueIsFilled(Result) Then
				
				If StrLen(Item) = 6 Then
				
					ReverseDate  = Mid(Item, 5) + Mid(Item, 3, 2) + Left(Item, 2);
					Year = StringToNumber(Left(ReverseDate, 2));
					If Year <> Undefined Then
						ReverseDate = ?(Year > 29, "19", "20") + ReverseDate;
						Result = DateTypeDetails.AdjustValue(ReverseDate);
					EndIf;
					
				ElsIf StrLen(Item) > 7 Then
					
					ReverseDate  = Mid(Item, 5) + Mid(Item, 3, 2) + Left(Item, 2);
					Result = DateTypeDetails.AdjustValue(ReverseDate);
					
				EndIf;
				
			EndIf;
			
			Return Result;
			
		ElsIf StrFind(Item, ":") > 0 Then
			
			DateValue = "";
			TimeValue = Item;
		Else
			DateValue = Item;
			TimeValue = "";
		EndIf;
	EndIf;
	
	TypeDescriptionNumber = New TypeDescription("Number");
	
	If ValueIsFilled(DateValue) And DatePart <> DateFractions.Time Then
		
		SeparatorsSet = StrConcat(StrSplit(DateValue, NumbersSet, False), "");
		DateValueAsArray = StrSplit(DateValue, SeparatorsSet, False);
		
		IsOnlyNumbers = StrSplit(DateValue, NumbersSet, False).Count() = 0;
		If Not IsOnlyNumbers Then
			
			Year   = 1;
			Month = 1;
			Day  = 1;
			
			If StrLen(DateValueAsArray[0]) = 4 Then
				Year = TypeDescriptionNumber.AdjustValue(DateValueAsArray[0]);
				YearInBeginning = True;
			Else
				Day = TypeDescriptionNumber.AdjustValue(DateValueAsArray[0]);
				YearInBeginning = False;
			EndIf;
			
			If DateValueAsArray.Count() = 2 Then
				Month = TypeDescriptionNumber.AdjustValue(DateValueAsArray[1]);
			ElsIf DateValueAsArray.Count() > 2 Then
				Month = TypeDescriptionNumber.AdjustValue(DateValueAsArray[1]);
				If YearInBeginning Then
					Day = TypeDescriptionNumber.AdjustValue(DateValueAsArray[2]);
				Else
					Year = TypeDescriptionNumber.AdjustValue(DateValueAsArray[2]);
				EndIf;
			EndIf;
			
			If StrLen(Year) < 3 Then
				YearAsNumber = TypeDescriptionNumber.AdjustValue(Year);
				Year = ?(YearAsNumber < 30, 2000, 1900) + YearAsNumber;
			Else
				Year = TypeDescriptionNumber.AdjustValue(Year);
			EndIf;
			
			DateValue = Format(Year, "ND=4; NZ=0001; NLZ=; NG=0")
				+ Format(Month, "ND=2; NZ=01; NLZ=; NG=0")
				+ Format(Day, "ND=2; NZ=01; NLZ=; NG=0");
		Else
			
			If StrLen(DateValue) = 6 Then
				
				Year = Right(DateValue, 2);
				YearAsNumber = TypeDescriptionNumber.AdjustValue(Year);
				DateValue = ?(YearAsNumber < 30, 2000, 1900) + Year + Mid(DateValue, 3, 2) + Left(DateValue, 2) ;
				
			ElsIf StrLen(DateValue) = 8 Then
				
				Result = DateTypeDetails.AdjustValue(DateValue);
				
				If Not ValueIsFilled(Result) Then
					ReverseDate  = Mid(DateValue, 5) + Mid(DateValue, 3, 2) + Left(DateValue, 2);
					Result = DateTypeDetails.AdjustValue(ReverseDate);
					If ValueIsFilled(Result) Then
						DateValue = ReverseDate;
					EndIf;
				EndIf;
			
			EndIf;
		EndIf;
		
	Else
		DateValue = "00010101";
	EndIf;
	
	If ValueIsFilled(TimeValue) And DatePart <> DateFractions.Date Then
		
		IsOnlyNumbers = StrSplit(TimeValue, NumbersSet, False).Count() = 0;
		If Not IsOnlyNumbers Then
			
			SeparatorsSet = StrConcat(StrSplit(TimeValue, NumbersSet, False), "");
			TimeValueAsArray = StrSplit(TimeValue, SeparatorsSet, False);
			
			Hour     = TypeDescriptionNumber.AdjustValue(TimeValueAsArray[0]);
			Minute  = 0;
			Second = 0;
			
			If TimeValueAsArray.Count() = 2 Then
				Minute = TypeDescriptionNumber.AdjustValue(TimeValueAsArray[1]);
			ElsIf TimeValueAsArray.Count() > 2 Then
				Minute = TypeDescriptionNumber.AdjustValue(TimeValueAsArray[1]);
				Second = TypeDescriptionNumber.AdjustValue(TimeValueAsArray[2]);
			EndIf;
			
			FormatTemplate = "ND=2; NZ=00; NLZ=; NG=0";
			TimeValue = Format(Hour, FormatTemplate)
				+ Format(Minute, FormatTemplate)
				+ Format(Second, FormatTemplate);
				
		EndIf;
		
	Else
		TimeValue = "000000";
	EndIf;
	
	Result = DateTypeDetails.AdjustValue(DateValue + TimeValue);
	
	Return Result;
	
EndFunction

// Generates the presentation of a number for a certain language and number parameters.
//  Parameter presentation:
//  ┌──────┬──────┬─────────────────┬────────────────┬───────────────────┬───────────────────────┬────────────────┐
//  │ Lang │ Zero │ One             │ Two            │ Few               │ Many                  │ Other          │
//  ├──────┼──────┼─────────────────┼────────────────┼───────────────────┼───────────────────────┼────────────────┤
//  │ ru   │      │ XX1 / X11       │                │ XX2─XX4 / X12─X14 │ XX0, XX5─XX9, X11─X14 │ fractional        │
//  │ Card.│      │ %1 day left │                │ %1 days left   │ %1 days left      │ %1 days left│
//  │      │      │ see %1 fish    │                │ see %1 fish     │ see %5 fish           │ see %1 fish  │
//  ├──────┼──────┼─────────────────┼────────────────┼───────────────────┼───────────────────────┼────────────────┤
//  │ ru   │      │                 │                │                   │                       │ других нет     │
//  │ Ord. │      │                 │                │                   │                       │ %1th day      │
//  ├──────┼──────┼─────────────────┼────────────────┼───────────────────┼───────────────────────┼────────────────┤
//  │ en   │      │ for 1           │                │                   │                       │ the rest      │
//  │ Card.│      │ left %1 day     │                │                   │                       │ left %1 days   │
//  ├──────┼──────┼─────────────────┼────────────────┼───────────────────┼───────────────────────┼────────────────┤
//  │ en   │      │ XX1 / X11       │ XX2 / X12      │ XX3 / X13         │                       │ the rest      │
//  │ Ord. │      │ %1st day        │ %1nd day       │ %1rd day          │                       │ %1th day.      │
//  └──────┴──────┴─────────────────┴────────────────┴───────────────────┴───────────────────────┴────────────────┘
//  ┌──────┬───────────────────────────┐
//  │Card. │ Cardinal ─ cardinal;│
//  │ Ord. │ Ordinal  - ordinal;    │
//  ├──────┼───────────────────────────┤
//  │   X  │ any number;              │
//  │   /  │ except for.                    │
//  └──────┴───────────────────────────┘
//
// Parameters:
//  Template          - String - contains semicolon-separated 6 string forms
//                             for each numeral category: 
//                             %1 denotes the number position;
//  Number           - Number - a number to be inserted instead of the "%1" parameter.
//  Kind             - NumericValueType - defines a kind of the numeric value for which a presentation is formed. 
//                                           Cardinal (default) or Ordinal.
//  FormatString - String - a string of formatting parameters. See similar example for StringWithNumber. 
//
// Returns:
//  String - presentation of the number string in the requested format.
//
// Example:
//
//  String = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
//		NStr("ru=';%1 day left;;%1 days left;%1 days left;1 days left';
//		     |en=';%1 day left;;;;%1 days left'"), 
//		0.05,,"NFD=1);
// 
Function StringWithNumberForAnyLanguage(Template, Number, Kind = Undefined, FormatString = "NZ=0;") Export
	
	If IsBlankString(Template) Then
		Return Format(Number, FormatString); 
	EndIf;

	If Kind = Undefined Then
		Kind = NumericValueType.Cardinal;
	EndIf;

	Return StringWithNumber(Template, Number, Kind, FormatString);

EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Instead, use See StringFunctions.FormattedString
// or See StringFunctionsClient.FormattedString.
//
// Generates a string according to the specified pattern.
// The possible tag values in the template:
// - String - Applies the bold formatting.
// - String - Adds a hyperlink.
// For example, "Lowest supported version is 1.1. Update the app."
//
// Parameters:
//  StringWithTags - String - a string containing formatting tags.
//
// Returns:
//  FormattedString - a converted string.
//
Function FormattedString(Val StringWithTags) Export
	
	BoldStrings = New ValueList;
	While StrFind(StringWithTags, "<b>") <> 0 Do
		BoldBeginning = StrFind(StringWithTags, "<b>");
		StringBeforeOpeningTag = Left(StringWithTags, BoldBeginning - 1);
		BoldStrings.Add(StringBeforeOpeningTag);
		StringAfterOpeningTag = Mid(StringWithTags, BoldBeginning + 3);
		BoldEnd = StrFind(StringAfterOpeningTag, "</b>");
		SelectedFragment = Left(StringAfterOpeningTag, BoldEnd - 1);
		BoldStrings.Add(SelectedFragment,, True);
		StringAfterBold = Mid(StringAfterOpeningTag, BoldEnd + 4);
		StringWithTags = StringAfterBold;
	EndDo;
	BoldStrings.Add(StringWithTags);
	
	StringsWithLinks = New ValueList;
	For Each RowPart In BoldStrings Do
		
		StringWithTags = RowPart.Value;
		
		If RowPart.Check Then
			StringsWithLinks.Add(StringWithTags,, True);
			Continue;
		EndIf;
		
		BoldBeginning = StrFind(StringWithTags, "<a href = ");
		While BoldBeginning <> 0 Do
			StringBeforeOpeningTag = Left(StringWithTags, BoldBeginning - 1);
			StringsWithLinks.Add(StringBeforeOpeningTag, );
			
			StringAfterOpeningTag = Mid(StringWithTags, BoldBeginning + 9);
			EndTag1 = StrFind(StringAfterOpeningTag, ">");
			
			Ref = TrimAll(Left(StringAfterOpeningTag, EndTag1 - 2));
			If StrStartsWith(Ref, """") Then
				Ref = Mid(Ref, 2, StrLen(Ref) - 1);
			EndIf;
			If StrEndsWith(Ref, """") Then
				Ref = Mid(Ref, 1, StrLen(Ref) - 1);
			EndIf;
			
			StringAfterLink = Mid(StringAfterOpeningTag, EndTag1 + 1);
			BoldEnd = StrFind(StringAfterLink, "</a>");
			HyperlinkAnchorText = Left(StringAfterLink, BoldEnd - 1);
			StringsWithLinks.Add(HyperlinkAnchorText, Ref);
			
			StringAfterBold = Mid(StringAfterLink, BoldEnd + 4);
			StringWithTags = StringAfterBold;
			
			BoldBeginning = StrFind(StringWithTags, "<a href = ");
		EndDo;
		StringsWithLinks.Add(StringWithTags);
		
	EndDo;
	
	RowArray = New Array;
	For Each RowPart In StringsWithLinks Do
		
		If RowPart.Check Then
			RowArray.Add(New FormattedString(RowPart.Value, New Font(,,True))); // ACC:1345 - Obsolete code.
		ElsIf Not IsBlankString(RowPart.Presentation) Then
			RowArray.Add(New FormattedString(RowPart.Value,,,, RowPart.Presentation));
		Else
			RowArray.Add(RowPart.Value);
		EndIf;
		
	EndDo;
	
	Return New FormattedString(RowArray);	// ACC:1356 - A compound format string can be used as the string array consists of the passed text.
														// 
	
EndFunction

// Deprecated. Instead, use See StringFunctionsClientServer.StringWithNumberForAnyLanguage.
//
// NumberInDigitsUnitOfMeasurementInWords(1.5, "minute,minutes,minutes");
// ->StringWithNumberForAnyLanguage(";%1 minute;;%1 minutes;%1 minutes;%1 minutes ", Value);
//
// NumberInDigitsUnitOfMeasurementInWords(1.5, "minute,minutes,minutes ", False);
// ->StringWithNumberForAnyLanguage(";minute;;minutes;minutes;minutes", Value);
//
// Returns a text presentation of the number with a unit of measurement in the correct form (singular or plural).
//
// Parameters:
//  Value                    - Number  - any integer number.
//  NumerationItemOptions - String - variants of writing units of measure for one,
//                                         for two and for five units, the separator is a comma.
//  AddNumberToResult   - Boolean - when passing False the number will not be added to string.
//
// Returns:
//  String - text presentation of unit count, the number is written in numbers.
//
// Example:
//  NumberInDigitsUnitOfMeasurementInWords(23,  "minute,minutes,minutes") = "23 minutes";
//  NumberInDigitsUnitOfMeasurementInWords(15,  "minute,minutes,minutes") = "15 minutes".
//
Function NumberInDigitsUnitOfMeasurementInWords(Val Value, Val NumerationItemOptions,
	Val AddNumberToResult = True) Export
	
	Result = ?(AddNumberToResult, Format(Value, "NZ=0") + " ", "");
	SubjectPresentations = New Array;
	
	NumerationItemOptions = StrSplit(NumerationItemOptions, ",");
	For Each Parameter In NumerationItemOptions Do
		SubjectPresentations.Add(TrimAll(Parameter));
	EndDo;
	
	Value = Value % 100;
	If Value > 20 Then
		Value = Value % 10;
	EndIf;
	
	IndexOf = ?(Value = 1, 0, ?(Value > 1 And Value < 5, 1, 2));
	Result = Result + SubjectPresentations[IndexOf];
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use See StringFunctionsClientServer.StringWithNumberForAnyLanguage.
//
// PluralForm("minute", "minutes", "minutes", 1.5);
// -> StringWithNumberForAnyLanguage(";minute;;minutes;minutes;minutes", Value);
//
// Returns the correct declension of the unit considering the preceding number.
//
// Parameters: 
//  FormFor1 - String - word form for one unit;
//  FormFor2 - String - word form for two units;
//  FormFor5 - String - word form for five units;
//  Value  - Number  - any integer number.
//
// Returns:
//  String - unit of measure in the right form.
//
// Example:
//  StringFunctionsClientServer.PluralForm("cupboard", "cupboard", "cupboards", 3); returns "cupboard".
//
Function InPlural(FormFor1, FormFor2, FormFor5, Val Value) Export
	Return NumberInDigitsUnitOfMeasurementInWords(Value, FormFor1 + "," + FormFor2 + "," + FormFor5, False);
EndFunction


// Deprecated. Instead, use See StringFunctions.LatinString
// or See StringFunctionsClient.LatinString.
// 
// Transliterates the passed string into Latin.
// Intended for sending the transliterated string as a text message or
// for naming files and directories for compatibility in different operating systems.
// Backward transliteration (from Latin letters) is not supported.
//
// Parameters:
//  Value - String - arbitrary string.
//
// Returns:
//  String - a string where Cyrillic is replaced by transliteration.
//
Function LatinString(Val Value) Export
	
	Result = "";
	
	Map = New Map;
	StandardSubsystemsClientServerLocalization.OnFillTransliterationRules(Map);
	
	OnlyUppercaseInString = OnlyUppercaseInString(Value);
	
	For Position = 1 To StrLen(Value) Do
		Char = Mid(Value, Position, 1);
		LatinChar = Map[Lower(Char)]; // Search the map regardless the register.
		If LatinChar = Undefined Then
			// Keep the other characters as is.
			LatinChar = Char;
		Else
			If OnlyUppercaseInString Then 
				LatinChar = Upper(LatinChar); // Restore the register
			ElsIf Char = Upper(Char) Then
				LatinChar = Title(LatinChar); // Restore the register
			EndIf;
		EndIf;
		Result = Result + LatinChar;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region FormattedString

Function GenerateFormattedString(StringPattern, StyleItems,
		Val Parameter1, Val Parameter2, Val Parameter3, Val Parameter4, Val Parameter5) Export
	
	RowParameters = New Array;
	RowParameters.Add(Parameter1);
	RowParameters.Add(Parameter2);
	RowParameters.Add(Parameter3);
	RowParameters.Add(Parameter4);
	RowParameters.Add(Parameter5);
	
	HTMLString = ?(RowParameters.Count() > 0,
		SubstituteParametersToStringFromArray(StringPattern, RowParameters), StringPattern);
	
	RowsSet = New Array;
	
	CurrentFont  = Undefined;
	CurrentColor   = Undefined;
	CurrentBackground    = Undefined;
	CurrentRef = Undefined;
	
	ParticlesStrings = StrSplit(HTMLString, "<", True);
	
	NamesOfTags = New Map;
	NamesOfTags.Insert("SPAN", True);
	NamesOfTags.Insert("IMG",  True);
	NamesOfTags.Insert("B",    True);
	NamesOfTags.Insert("A",    True);
	
	FragmentFirstChar = "";
	For Each Particle In ParticlesStrings Do
		
		StringBody = "";
		PositionTagEnd = StrFind(Particle, ">");
		
		If PositionTagEnd = 0 Then
			StringBody = FragmentFirstChar + Particle;
			
		ElsIf StrStartsWith(Particle, "/") Then
			
			NameTag = Mid(Particle, 2, PositionTagEnd - 2);
			
			If NamesOfTags.Get(Upper(NameTag)) = True Then 
				StringBody    = Mid(Particle, PositionTagEnd + 1);
				CurrentFont  = Undefined;
				CurrentColor   = Undefined;
				CurrentBackground    = Undefined;
				CurrentRef = Undefined;
			Else
				StringBody = FragmentFirstChar + Particle;
			EndIf;
			
		Else
			
			TagDetails = Left(Particle, PositionTagEnd - 1);
			FirstSpase = StrFind(TagDetails, " ");
			
			If FirstSpase > 0 Then
				NameTag = TrimAll(Left(TagDetails, FirstSpase));
				
				AttributesDetails = Mid(TagDetails, FirstSpase + 1);
				AttributesDetails = StrReplace(AttributesDetails , """", "'");
				
				PositionEqual = StrFind(AttributesDetails, "=");
				While PositionEqual > 0 Do
					
					AttributeName = TrimAll(Left(AttributesDetails, PositionEqual - 1));
					PositionFirstQuote = StrFind(AttributesDetails, "'",, PositionEqual + 1);
					If PositionFirstQuote = 0 Then
						PositionFirstQuote = PositionEqual;
					EndIf;
					PositionSecondQuote = StrFind(AttributesDetails, "'",, PositionFirstQuote + 1);
					If PositionSecondQuote = 0 Then
						PositionSecondQuote = StrLen(AttributesDetails) + 1;
					EndIf;
					AttributeValue = TrimAll(Mid(AttributesDetails, PositionFirstQuote + 1,  PositionSecondQuote - PositionFirstQuote - 1));
					
					If StrCompare(AttributeName, "style") = 0 And ValueIsFilled(AttributeValue) Then
						SetStylesByAttributeValue(AttributeValue, StyleItems, CurrentBackground, CurrentColor, CurrentFont);
					ElsIf StrCompare(AttributeName, "href") = 0 And StrCompare(NameTag, "a") = 0 Then
						CurrentRef = AttributeValue;
					ElsIf StrCompare(AttributeName, "src") = 0 And StrCompare(NameTag, "img") = 0 Then
						RowsSet.Add(New FormattedString(PictureLib[AttributeValue], CurrentFont, CurrentColor, CurrentBackground, CurrentRef));
					EndIf;
					
					AttributesDetails = Mid(AttributesDetails, PositionSecondQuote + 1);
					PositionEqual = StrFind(AttributesDetails, "=");
					
				EndDo;
			Else
				NameTag = TagDetails;
			EndIf;
			
			If NamesOfTags.Get(Upper(NameTag)) = True Then
				
				If Upper(NameTag) = "B" Then
					CurrentFont = StyleItems["ImportantLabelFont"];
				EndIf;
				
				StringBody = Mid(Particle, PositionTagEnd + 1);
			Else
				StringBody = FragmentFirstChar + Particle;
			EndIf;
			
		EndIf;
		
		StringBody = StrReplace(StringBody, "&lt;", "<");
		If StrLen(StringBody) > 0 Then
			RowsSet.Add(New FormattedString(StringBody, CurrentFont, CurrentColor, CurrentBackground, CurrentRef));
		EndIf; 
		
		FragmentFirstChar = "<" ;
		
	EndDo;
	
	Return New FormattedString(RowsSet);	// ACC:1356 - A compound format string can be used as the string array consists of the passed text.
														// 

EndFunction

Procedure SetStylesByAttributeValue(Val StyleDetails, StyleItems, CurrentBackground, CurrentColor, CurrentFont)
	
	Styles = StrSplit(StyleDetails, ";");
	
	For Each Style In Styles Do
		
		StyleValues = StrSplit(Style, ":");
		StyleName      = TrimAll(StyleValues[0]);
		StyleValue = TrimAll(StyleValues[1]);
		
		If StrCompare(StyleName, "color") = 0  Then
			CurrentColor = StyleItems[StyleValue];
		ElsIf StrCompare(StyleName, "background-color") = 0 Then
			CurrentBackground = StyleItems[StyleValue];
		ElsIf StrCompare(StyleName, "font") = 0 Then
			CurrentFont = StyleItems[StyleValue];
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ConvertNumberIntoRomanNotation

// Converts the Arabic numerals into Roman numerals. 
//
// Parameters:
//  Figure - Number - RomanOne, RomanFive, RomanTen - String - Symbols of Roman numerals.
//                  Returns:
//                  String - Digit in Roman numerical notation.
//  RomanOne, RomanFive, RomanTen - String - Symbols of Roman numerals.
//
// Returns:
//  String - Digit in Roman numerical notation.
//
// Example: 
//	StringFunctionsClientServer.ConvertDigitIntoRomanNotation(7,"I","V","X") = "VII".
//
Function ConvertFigureIntoRomanNotation(Figure, RomanOne, RomanFive, RomanTen)
	
	RomanFigure="";
	If Figure = 1 Then
		RomanFigure = RomanOne
	ElsIf Figure = 2 Then
		RomanFigure = RomanOne + RomanOne;
	ElsIf Figure = 3 Then
		RomanFigure = RomanOne + RomanOne + RomanOne;
	ElsIf Figure = 4 Then
		RomanFigure = RomanOne + RomanFive;
	ElsIf Figure = 5 Then
		RomanFigure = RomanFive;
	ElsIf Figure = 6 Then
		RomanFigure = RomanFive + RomanOne;
	ElsIf Figure = 7 Then
		RomanFigure = RomanFive + RomanOne + RomanOne;
	ElsIf Figure = 8 Then
		RomanFigure = RomanFive + RomanOne + RomanOne + RomanOne;
	ElsIf Figure = 9 Then
		RomanFigure = RomanOne + RomanTen;
	EndIf;
	Return RomanFigure;
	
EndFunction

#EndRegion

#Region SubstituteParametersToString

// Substitutes parameters in the string for %1, %2, and so on.
Function SubstituteParametersWithPercentageChar(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined)
	
	Result = "";
	Position = StrFind(SubstitutionString, "%");
	While Position > 0 Do 
		Result = Result + Left(SubstitutionString, Position - 1);
		CharAfterPercentage = Mid(SubstitutionString, Position + 1, 1);
		ParameterToSubstitute = Undefined;
		If CharAfterPercentage = "1" Then
			ParameterToSubstitute = Parameter1;
		ElsIf CharAfterPercentage = "2" Then
			ParameterToSubstitute = Parameter2;
		ElsIf CharAfterPercentage = "3" Then
			ParameterToSubstitute = Parameter3;
		ElsIf CharAfterPercentage = "4" Then
			ParameterToSubstitute = Parameter4;
		ElsIf CharAfterPercentage = "5" Then
			ParameterToSubstitute = Parameter5;
		ElsIf CharAfterPercentage = "6" Then
			ParameterToSubstitute = Parameter6;
		ElsIf CharAfterPercentage = "7" Then
			ParameterToSubstitute = Parameter7
		ElsIf CharAfterPercentage = "8" Then
			ParameterToSubstitute = Parameter8;
		ElsIf CharAfterPercentage = "9" Then
			ParameterToSubstitute = Parameter9;
		EndIf;
		If ParameterToSubstitute = Undefined Then
			Result = Result + "%";
			SubstitutionString = Mid(SubstitutionString, Position + 1);
		Else
			Result = Result + ParameterToSubstitute;
			SubstitutionString = Mid(SubstitutionString, Position + 2);
		EndIf;
		Position = StrFind(SubstitutionString, "%");
	EndDo;
	Result = Result + SubstitutionString;
	
	Return Result;
EndFunction

#EndRegion

#Region LatinString

Function OnlyUppercaseInString(Value)
	
	For Position = 1 To StrLen(Value) Do
		Char = Mid(Value, Position, 1);
		If Char <> Upper(Char) Then 
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

#EndRegion

#EndRegion
