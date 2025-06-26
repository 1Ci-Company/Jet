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

// Converts the amount from the source currency to the new currency according to their rate parameters. 
// To get currency rate parameters, use the CurrenciesExchangeRates.GetCurrencyRate function.
//
// Parameters:
//   Sum                  - Number     - the amount to be converted.
//
//   SourceRateParameters - Structure - the rate parameters for the source currency:
//    * Currency    - CatalogRef.Currencies - the reference to the currency being converted.
//    * Rate      - Number - the exchange rate for the currency being converted.
//    * Repetition - Number - the multiplier for the currency being converted.
//
//   NewRateParameters   - Structure - rate parameters for a new currency:
//    * Currency    - CatalogRef.Currencies - the reference to the currency, into which calculation is being made.
//    * Rate      - Number - the exchange rate for a currency, into which calculation is being made.
//    * Repetition - Number - the multiplier of a currency, into which calculation is being made.
//
// Returns: 
//   Number - the amount converted at the new rate.
//
Function ConvertAtRate(Sum, SourceRateParameters, NewRateParameters) Export
	If SourceRateParameters.Currency = NewRateParameters.Currency
		Or (SourceRateParameters.Rate = NewRateParameters.Rate 
			And SourceRateParameters.Repetition = NewRateParameters.Repetition) Then
		
		Return Sum;
	EndIf;
	
	If SourceRateParameters.Rate = 0
		Or SourceRateParameters.Repetition = 0
		Or NewRateParameters.Rate = 0
		Or NewRateParameters.Repetition = 0 Then
		
		Return 0;
	EndIf;
	
	Return Round((Sum * SourceRateParameters.Rate * NewRateParameters.Repetition) 
		/ (NewRateParameters.Rate * SourceRateParameters.Repetition), 2);
EndFunction

#EndRegion
