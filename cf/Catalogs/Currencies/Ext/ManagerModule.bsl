///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("RateSource");
	Result.Add("Markup");
	Result.Add("MainCurrency");
	Result.Add("RateCalculationFormula");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

#EndRegion

#EndRegion

#Region Private

Function CurrencyCodes() Export
	
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS AlphabeticCode,
	|	Currencies.DescriptionFull AS Presentation
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource <> VALUE(Enum.RateSources.MarkupForOtherCurrencyRate)
	|	AND Currencies.RateSource <> VALUE(Enum.RateSources.CalculationByFormula)";
	
	Query = New Query(QueryText);
	
	Currencies = Query.Execute().Unload();
	CopiedLines = New Array;
	
	For Each Currency In Currencies Do
		// A currency is included in the formula if its char code contains letters.
		If ValueIsFilled(StrConcat(StrSplit(Currency.AlphabeticCode, "0123456789", False), "")) Then
			CopiedLines.Add(Currency);
		EndIf;
	EndDo;
	
	Result = Currencies.Copy(CopiedLines);
	Result.Indexes.Add("Ref");
	
	Return Result;
	
EndFunction

Function CurrencyRateByFormula(Formula, Period, CurrencyCodes = Undefined) Export
	
	If CurrencyCodes = Undefined Then
		CurrencyCodes = Catalogs.Currencies.CurrencyCodes();
	EndIf;
	
	QueryText = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.AlphabeticCode AS AlphabeticCode
	|INTO Currencies
	|FROM
	|	&CurrencyCodes AS Currencies
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Currencies.AlphabeticCode AS AlphabeticCode,
	|	ISNULL(CurrencyRatesCut.Rate, 1) / ISNULL(CurrencyRatesCut.Repetition, 1) AS Rate
	|FROM
	|	Currencies AS Currencies
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS CurrencyRatesCut
	|		ON (CurrencyRatesCut.Currency = Currencies.Ref)";
	
	Query = New Query(QueryText);
	Query.SetParameter("CurrencyCodes", CurrencyCodes);
	Query.SetParameter("Period", Period);

	Expression = FormatNumbers(Formula);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Expression = StrReplace(Expression, Selection.AlphabeticCode, Format(Selection.Rate, "NDS=.; NG=0"));
	EndDo;
	
	Return Common.CalculateInSafeMode(Expression);
	
EndFunction

Function FormatNumbers(String) Export
	
	Result = "";
	Number = "";
	IsDelimiterInNumber = False;
	PreviousChar = "";
	
	StringLength = StrLen(String);
	For IndexOf = 1 To StringLength Do
		If IndexOf < StringLength Then
			NextChar = Mid(String, IndexOf + 1, 1);
		Else
			NextChar = "";
		EndIf;
		Char = Mid(String, IndexOf, 1);
		
		PreviousCharacterThisDelimiter = PreviousChar = "" Or StrFind("()[]/*-+%=<>, ", PreviousChar) > 0;
		
		If IsDigit(Char) And (PreviousCharacterThisDelimiter Or IsDigit(PreviousChar) And ValueIsFilled(Number)) Then
			Number = Number + Char;
		ElsIf Not IsDelimiterInNumber And (Char = "," Or Char = ".") And IsDigit(NextChar)
			And (IsDigit(PreviousChar) Or PreviousCharacterThisDelimiter) And ValueIsFilled(Number) Then
			Number = Number + ".";
			IsDelimiterInNumber = True;
		Else
			Result = Result + Number + Char;
			Number = "";
			IsDelimiterInNumber = False;
		EndIf;
		
		PreviousChar = Char;
		Char = "";
	EndDo;
	
	Result = Result + Number + Char;
	Return Result;
	
EndFunction

Function IsDigit(Char)
	
	Return StrFind("1234567890", Char) > 0;
	
EndFunction

#EndRegion

#EndIf