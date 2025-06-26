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

#If Not MobileStandaloneServer Then

#Region RunExternalApplications

// Parameters:
//  StartupCommand - String
// 
// Returns:
//  String
//
Function SafeCommandString(StartupCommand) Export
	
	Result = "";
	
	If TypeOf(StartupCommand) = Type("String") Then 
		
		CheckContainsUnsafeActions(StartupCommand);
		Result = StartupCommand;
		
	ElsIf TypeOf(StartupCommand) = Type("Array") Then
		
		If StartupCommand.Count() > 0 Then
			CheckContainsUnsafeActions(StartupCommand[0]);
			Result = ArrayToCommandString(StartupCommand);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The first element of array %1 must be either a command or a path to a file to be executed.';"),
				"StartupCommand");
		EndIf;
		
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Expected type of value %1: %2 or %3.';"), 
			"StartupCommand", "String", "Array");
	EndIf;
		
	Return Result
	
EndFunction

#EndRegion

#Region Other

// Calculates indicators of numeric cells in a spreadsheet document.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - Spreadsheet document whose indicators are being computed.
//   SelectedAreas - Array of See CommonClientServer.CellsIndicatorsCalculationParameters.
//
// Returns:
//   Structure - Outcome of the selected cell.:
//       * Count         - Number - selected cells count.
//       * NumericCellsCount - Number - numeric cells count.
//       * Sum      - Number - a sum of the selected cells with numbers.
//       * Mean    - Number - a sum of the selected cells with numbers.
//       * Minimum    - Number - a sum of the selected cells with numbers.
//       * Maximum   - Number - a sum of the selected cells with numbers.
//
Function CalculationCellsIndicators(Val SpreadsheetDocument, SelectedAreas) Export 
	
#Region ResultConstructor
	
	CalculationIndicators = New Structure;
	CalculationIndicators.Insert("Count", 0);
	CalculationIndicators.Insert("FilledCellsCount", 0);
	CalculationIndicators.Insert("NumericCellsCount", 0);
	CalculationIndicators.Insert("Sum", 0);
	CalculationIndicators.Insert("Mean", 0);
	CalculationIndicators.Insert("Minimum", 0);
	CalculationIndicators.Insert("Maximum", 0);
	
#EndRegion
	
	CheckedCells = New Map;
	
	For Each SelectedArea1 In SelectedAreas Do
		
		If TypeOf(SelectedArea1) <> Type("SpreadsheetDocumentRange")
			And TypeOf(SelectedArea1) <> Type("Structure") Then
			Continue;
		EndIf;
		
#Region SelectedAreaBoundariesDetermination
		
		SelectedAreaTop  = SelectedArea1.Top;
		SelectedAreaBottom   = SelectedArea1.Bottom;
		SelectedAreaLeft  = SelectedArea1.Left;
		SelectedAreaRight = SelectedArea1.Right;
		
		If SelectedAreaTop = 0 Then
			SelectedAreaTop = 1;
		EndIf;
		
		If SelectedAreaBottom = 0 Then
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If SelectedAreaLeft = 0 Then
			SelectedAreaLeft = 1;
		EndIf;
		
		If SelectedAreaRight = 0 Then
			SelectedAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If SelectedArea1.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			SelectedAreaTop = SelectedArea1.Bottom;
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		SelectedAreaHeight = SelectedAreaBottom   - SelectedAreaTop + 1;
		SelectedAreaWidth = SelectedAreaRight - SelectedAreaLeft + 1;
		
#EndRegion
		
		CalculationIndicators.Count = CalculationIndicators.Count + SelectedAreaWidth * SelectedAreaHeight;
		
		For ColumnNumber = SelectedAreaLeft To SelectedAreaRight Do
			
			For LineNumber = SelectedAreaTop To SelectedAreaBottom Do
				
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				
				If CheckedCells.Get(Cell.Name) = Undefined Then
					CheckedCells.Insert(Cell.Name, True);
				Else
					Continue;
				EndIf;
				
				If Cell.Visible = True Then
					
#Region CellValueDetermination
					
					If Cell.AreaType <> SpreadsheetDocumentCellAreaType.Columns
						And Cell.ContainsValue And TypeOf(Cell.Value) = Type("Number") Then
						
						Number = Cell.Value;
						
					ElsIf ValueIsFilled(Cell.Text) Then
						
						CellText = StrReplace(Cell.Text, " ", "");
						
						If TheTextOfACellOfTheFormForScientificNotation(CellText) Then 
							Number = 0;
						Else
							TypeDescriptionNumber = New TypeDescription("Number");
							
							If StrStartsWith(CellText, "(")
								And StrEndsWith(CellText, ")") Then 
								
								CellText = StrReplace(CellText, "(", "");
								CellText = StrReplace(CellText, ")", "");
								
								Number = TypeDescriptionNumber.AdjustValue(CellText);
								If Number > 0 Then 
									Number = -Number;
								EndIf;
							Else
								Number = TypeDescriptionNumber.AdjustValue(CellText);
							EndIf;
						EndIf;
						
					Else
						Continue;
					EndIf;
					
#EndRegion
					
					CalculationIndicators.FilledCellsCount = CalculationIndicators.FilledCellsCount + 1;
					
#Region IndicatorsCalculation
					
					If TypeOf(Number) = Type("Number") Then
						
						CalculationIndicators.NumericCellsCount = CalculationIndicators.NumericCellsCount + 1;
						CalculationIndicators.Sum = CalculationIndicators.Sum + Number;
						
						If CalculationIndicators.NumericCellsCount = 1 Then
							CalculationIndicators.Minimum  = Number;
							CalculationIndicators.Maximum = Number;
						Else
							CalculationIndicators.Minimum  = Min(Number,  CalculationIndicators.Minimum);
							CalculationIndicators.Maximum = Max(Number, CalculationIndicators.Maximum);
						EndIf;
						
					EndIf;
					
#EndRegion
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
	If CalculationIndicators.NumericCellsCount > 0 Then
		CalculationIndicators.Mean = CalculationIndicators.Sum / CalculationIndicators.NumericCellsCount;
	EndIf;
	
	Return CalculationIndicators;
	
EndFunction

Function AddInAttachType(Isolated) Export
	
	If Isolated = Undefined Then
		Return Undefined;
	EndIf;
	
#If Not WebClient And Not MobileClient Then
		
	If Isolated Then
		Return AddInAttachmentType.Isolated;
	EndIf;
	
	Return AddInAttachmentType.NotIsolated;
	
#Else
	
	Return Undefined;
	
#EndIf
	
EndFunction

#EndRegion

#EndIf

#EndRegion

#Region Private

#Region UserNotification

Function UserMessage(
		Val MessageToUserText,
		Val DataKey,
		Val Field,
		Val DataPath = "",
		Cancel = False,
		IsObject = False) Export
	
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	If IsObject Then
		Message.SetData(DataKey);
	Else
		Message.DataKey = DataKey;
	EndIf;
	
	If Not IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
	
	Cancel = True;
	
	Return Message;
	
EndFunction

#EndRegion

#If Not MobileStandaloneServer Then

#Region InfobaseData

#Region PredefinedItem

Function UseStandardGettingPredefinedItemFunction(FullPredefinedItemName) Export
	
	// A standard 1C:Enterprise function is used to obtain:
	//  - Empty references 
	//  - Enumeration members
	//  - Business process route points
	
	Return StrEndsWith(Upper(FullPredefinedItemName), ".EMPTYREF")
		Or StrStartsWith(Upper(FullPredefinedItemName), "ENUM.")
		Or StrStartsWith(Upper(FullPredefinedItemName), "BUSINESSPROCESS.");
	
EndFunction

Function PredefinedItemNameByFields(FullPredefinedItemName) Export
	
	FullNameParts1 = StrSplit(FullPredefinedItemName, ".");
	If FullNameParts1.Count() <> 3 Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;
	
	FullMetadataObjectName = Upper(FullNameParts1[0] + "." + FullNameParts1[1]);
	PredefinedItemName = FullNameParts1[2];
	
	Result = New Structure;
	Result.Insert("FullMetadataObjectName", FullMetadataObjectName);
	Result.Insert("PredefinedItemName", PredefinedItemName);
	
	Return Result;
	
EndFunction

Function PredefinedItem(FullPredefinedItemName, PredefinedItemFields, PredefinedValues) Export
	
	// In case of error in metadata name.
	If PredefinedValues = Undefined Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;
	
	// Getting result from cache.
	Result = PredefinedValues.Get(PredefinedItemFields.PredefinedItemName);
	
	// If the predefined item does not exist in metadata.
	If Result = Undefined Then 
		Raise PredefinedValueNotFoundErrorText(FullPredefinedItemName);
	EndIf;
	
	// If the predefined item exists in metadata but not in the infobase.
	If Result = Null Then 
		Return Undefined;
	EndIf;
	
	Return Result;
	
EndFunction

Function PredefinedValueNotFoundErrorText(FullPredefinedItemName) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Predefined value ""%1"" does not exist.';"), FullPredefinedItemName);
	
EndFunction

#EndRegion

#EndRegion

#Region Dates

Function LocalDatePresentationWithOffset(LocalDate, Offset) Export
	
	OffsetPresentation = "Z";
	
	If Offset > 0 Then
		OffsetPresentation = "+";
	ElsIf Offset < 0 Then
		OffsetPresentation = "-";
		Offset = -Offset;
	EndIf;
	
	If Offset <> 0 Then
		OffsetPresentation = OffsetPresentation + Format('00010101' + Offset, "DF=HH:mm");
	EndIf;
	
	Return Format(LocalDate, "DF=yyyy-MM-ddTHH:mm:ss; DE=0001-01-01T00:00:00") + OffsetPresentation;
	
EndFunction

#EndRegion

#Region ExternalConnection

Function EstablishExternalConnectionWithInfobase(Parameters, ConnectionNotAvailable, BriefErrorDetails) Export
	
	Result = New Structure;
	Result.Insert("Join");
	Result.Insert("BriefErrorDetails", "");
	Result.Insert("DetailedErrorDetails", "");
	Result.Insert("AddInAttachmentError", False);
	
#If MobileClient Then
	
	ErrorMessageString = NStr("en = 'Mobile client does not support connecting other apps.';");
	
	Result.AddInAttachmentError = True;
	Result.DetailedErrorDetails = ErrorMessageString;
	Result.BriefErrorDetails = ErrorMessageString;
	
	Return Result;
	
#Else
	
	If ConnectionNotAvailable Then
		Result.Join = Undefined;
		Result.BriefErrorDetails = BriefErrorDetails;
		Result.DetailedErrorDetails = BriefErrorDetails;
		Return Result;
	EndIf;
	
	Try
		COMConnector = New COMObject(CommonClientServer.COMConnectorName()); // "V83.COMConnector"
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("en = 'Failed to connect to another app: %1';");
		
		Result.AddInAttachmentError = True;
		Result.DetailedErrorDetails = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.DetailErrorDescription(Information));
		Result.BriefErrorDetails = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.BriefErrorDescription(Information));
		
		Return Result;
	EndTry;
	
	FileRunMode = Parameters.InfobaseOperatingMode = 0;
	
	// Checking parameter correctness.
	FillingCheckError = False;
	If FileRunMode Then
		
		If IsBlankString(Parameters.InfobaseDirectory) Then
			ErrorMessageString = NStr("en = 'The infobase directory location is not specified.';");
			FillingCheckError = True;
		EndIf;
		
	Else
		
		If IsBlankString(Parameters.NameOf1CEnterpriseServer) Or IsBlankString(Parameters.NameOfInfobaseOn1CEnterpriseServer) Then
			ErrorMessageString = NStr("en = 'Required connection parameters are not specified: server name and infobase name.';");
			FillingCheckError = True;
		EndIf;
		
	EndIf;
	
	If FillingCheckError Then
		
		Result.DetailedErrorDetails = ErrorMessageString;
		Result.BriefErrorDetails   = ErrorMessageString;
		Return Result;
		
	EndIf;
	
	// Generate the connection string.
	ConnectionStringPattern = "[InfobaseString][AuthenticationString]";
	
	If FileRunMode Then
		InfobaseString = "File = ""&InfobaseDirectory""";
		InfobaseString = StrReplace(InfobaseString, "&InfobaseDirectory", Parameters.InfobaseDirectory);
	Else
		InfobaseString = "Srvr = ""&NameOf1CEnterpriseServer""; Ref = ""&NameOfInfobaseOn1CEnterpriseServer""";
		InfobaseString = StrReplace(InfobaseString, "&NameOf1CEnterpriseServer",                     Parameters.NameOf1CEnterpriseServer);
		InfobaseString = StrReplace(InfobaseString, "&NameOfInfobaseOn1CEnterpriseServer", Parameters.NameOfInfobaseOn1CEnterpriseServer);
	EndIf;
	
	If Parameters.OperatingSystemAuthentication Then
		AuthenticationString = "";
	Else
		
		If StrFind(Parameters.UserName, """") Then
			Parameters.UserName = StrReplace(Parameters.UserName, """", """""");
		EndIf;
		
		If StrFind(Parameters.UserPassword, """") Then
			Parameters.UserPassword = StrReplace(Parameters.UserPassword, """", """""");
		EndIf;
		
		AuthenticationString = "; Usr = ""&UserName""; Pwd = ""&UserPassword""";
		AuthenticationString = StrReplace(AuthenticationString, "&UserName",    Parameters.UserName);
		AuthenticationString = StrReplace(AuthenticationString, "&UserPassword", Parameters.UserPassword);
	EndIf;
	
	ConnectionString = StrReplace(ConnectionStringPattern, "[InfobaseString]", InfobaseString);
	ConnectionString = StrReplace(ConnectionString, "[AuthenticationString]", AuthenticationString);
	
	Try
		Result.Join = COMConnector.Connect(ConnectionString);
	Except
		Information = ErrorInfo();
		ErrorMessageString = NStr("en = 'Failed to connect to another app: %1';");
		
		Result.AddInAttachmentError = True;
		Result.DetailedErrorDetails     = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.DetailErrorDescription(Information));
		Result.BriefErrorDetails       = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, ErrorProcessing.BriefErrorDescription(Information));
	EndTry;
	
	Return Result;
	
#EndIf
	
EndFunction

#EndRegion

#Region RunExternalApplications

#Region SafeCommandString

Function ContainsUnsafeActions(Val CommandString)
	
	Return StrFind(CommandString, "${") <> 0
		Or StrFind(CommandString, "$(") <> 0
		Or StrFind(CommandString, "`") <> 0
		Or StrFind(CommandString, "|") <> 0
		Or StrFind(CommandString, ";") <> 0
		Or StrFind(CommandString, "&") <> 0;
	
EndFunction

Procedure CheckContainsUnsafeActions(Val StartupCommand)
	If ContainsUnsafeActions(StartupCommand) Then 
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot start the app. Invalid command line:
			           |%1
			           |
			           |The following characters are not allowed: ""${"", ""$("", ""`"", ""|"", "";"", ""&"".';"),
			StartupCommand);
	EndIf;
EndProcedure

Function ArrayToCommandString(StartupCommand)
	
	Result = New Array;
	QuotesRequired = False;
	For Each Argument In StartupCommand Do
		
		If Result.Count() > 0 Then 
			Result.Add(" ")
		EndIf;
		
		QuotesRequired = Argument = Undefined
			Or IsBlankString(Argument)
			Or StrFind(Argument, " ")
			Or StrFind(Argument, Chars.Tab)
			Or StrFind(Argument, "&")
			Or StrFind(Argument, "(")
			Or StrFind(Argument, ")")
			Or StrFind(Argument, "[")
			Or StrFind(Argument, "]")
			Or StrFind(Argument, "{")
			Or StrFind(Argument, "}")
			Or StrFind(Argument, "^")
			Or StrFind(Argument, "=")
			Or StrFind(Argument, ";")
			Or StrFind(Argument, "!")
			Or StrFind(Argument, "'")
			Or StrFind(Argument, "+")
			Or StrFind(Argument, ",")
			Or StrFind(Argument, "`")
			Or StrFind(Argument, "~")
			Or StrFind(Argument, "$")
			Or StrFind(Argument, "|");
		
		If QuotesRequired Then 
			Result.Add("""");
		EndIf;
		
		Result.Add(StrReplace(Argument, """", """"""));
		
		If QuotesRequired Then 
			Result.Add("""");
		EndIf;
		
	EndDo;
	
	Return StrConcat(Result);
	
EndFunction

#EndRegion

#If Not WebClient And Not MobileClient Then

Function TheWindowsCommandStartLine(CommandString, CurrentDirectory, WaitForCompletion, ExecutionEncoding) Export
	
	CommandsSet = "";
	
	If ValueIsFilled(ExecutionEncoding) Then 
		
		If ExecutionEncoding = "OEM" Then
			ExecutionEncoding = 437;
		ElsIf ExecutionEncoding = "CP866" Then
			ExecutionEncoding = 866;
		ElsIf ExecutionEncoding = "UTF8" Then
			ExecutionEncoding = 65001;
		EndIf;
		
		CommandsSet = "(chcp " + Format(ExecutionEncoding, "NG=") + ")";
	EndIf;
	
	If Not IsBlankString(CurrentDirectory) Then 
		CommandsSet = CommandsSet + ?(ValueIsFilled(CommandsSet), "&&", "") + "(cd /D """ + CurrentDirectory + """)";
	EndIf;
	CommandsSet = CommandsSet + ?(ValueIsFilled(CommandsSet), "&&", "") + "(" + TrimAll(CommandString) + ")";
	
	Return "cmd /S /C """ + CommandsSet + """";
	
EndFunction

#EndIf

#EndRegion

#Region StringFunctions

Function LatinString(Val Value, TransliterationRules) Export
	
	Result = "";
	OnlyUppercaseInString = OnlyUppercaseInString(Value);
	
	For Position = 1 To StrLen(Value) Do
		Char = Mid(Value, Position, 1);
		LatinChar = TransliterationRules[Lower(Char)]; // Search the map regardless the register.
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

Function OnlyUppercaseInString(Value)
	
	For Position = 1 To StrLen(Value) Do
		Char = Mid(Value, Position, 1);
		If Char <> Upper(Char) Then 
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
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
Function PeriodPresentationInText(StartDate, EndDate, FormatString, Capitalize) Export 
	
	If StartDate > EndDate Then 
		Return "";
	EndIf;
	
	PeriodPresentation = Lower(PeriodPresentation(StartDate, EndDate, FormatString));
	
	FormatThePeriodView(PeriodPresentation, StartDate, EndDate, FormatString);
	
	If Capitalize Then 
		PeriodPresentation = Upper(Mid(PeriodPresentation, 1, 1)) + Mid(PeriodPresentation, 2);
	EndIf;
	
	Return PeriodPresentation;
	
EndFunction

Procedure FormatThePeriodView(PeriodPresentation, StartDate, EndDate, FormatString)
	
	If ValueIsFilled(FormatString) Then 
		Return;
	EndIf;
	
	If Not ValueIsFilled(PeriodPresentation) Then 
		
		PeriodPresentation = NStr("en = 'all time';");
		Return;
		
	EndIf;
	
	If Month(StartDate) > 1
		Or Year(StartDate) <> Year(EndDate)
		Or StartDate <> BegOfMonth(StartDate)
		Or EndDate <> EndOfMonth(EndDate) Then 
		
		Return;
	EndIf;
		
	If Month(EndDate) = 6 Then 
		
		PeriodPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '1st half year of %1';"), Format(Year(StartDate), "NG=0"));
		
	ElsIf Month(EndDate) = 9 Then 
		
		PeriodPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '9 months of %1';"), Format(Year(StartDate), "NG=0"));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SpreadsheetDocument

// Returns the flag indicating whether the cell text matches the scientific notation format.
//  It allows to decide whether to calculate the value by the AdjustValue method or
//  cancel the calculation. Casting to a number might require significant
//  computing processor resources.
//
// Parameters:
//  CellText - String - the value of the selected cell.
//
// Returns: 
//   Boolean - if True, the text looks like a scientific notation.
//
Function TheTextOfACellOfTheFormForScientificNotation(Val CellText)
	
	NumberOfOccurrences = 0;
	CellText = StrReplace(Upper(CellText), Chars.NBSp, "");
	
	// Replace decimal separator characters.
	CellText = StrReplace(CellText, Char(44), ""); // Comma ( , ).
	CellText = StrReplace(CellText, Char(46), ""); // Dot ( . ).
	
	ExponentCharacterCodes = New Array;
	ExponentCharacterCodes.Add(1045); // Cyrillic "Е".
	ExponentCharacterCodes.Add(69);   // Latin "E".
	
	For Each Code In ExponentCharacterCodes Do 
		
		TheExponentSymbol = Char(Code);
		NumberOfOccurrences = NumberOfOccurrences + StrOccurrenceCount(CellText, TheExponentSymbol);
		CellText = StrReplace(CellText, TheExponentSymbol, "");
		
	EndDo;
	
	Return NumberOfOccurrences = 1 And StringFunctionsClientServer.OnlyNumbersInString(CellText);
	
EndFunction

#EndRegion

#EndIf

#EndRegion
