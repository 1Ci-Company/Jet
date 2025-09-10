
#Region Public

// Converts the amount from the source currency to the new currency.
//
// Parameters:
//  Amount - Number - the amount to be converted.
//  SourceRate - Number - the exchange rate for the currency being converted.
//  SourceMultiplier - Number - the multiplier for the currency being converted.
//  NewRate - Number - the exchange rate for a currency, into which calculation is being made.
//  NewMultiplier - Number - the multiplier of a currency, into which calculation is being made.
//
// Returns:
//  Number - the amount converted at the new rate.
//
Function CalculateFromCurrencyToCurrency(Amount, SourceRate, SourceMultiplier, NewRate = 1, NewMultiplier = 1) Export
	
	If SourceRate = NewRate And SourceMultiplier = NewMultiplier Then
		Return Amount;
	EndIf;
	
	If SourceRate = 0 Or NewRate = 0 Or SourceMultiplier = 0 Or NewMultiplier = 0 Then
		Return Amount;
	EndIf;
	
	Return Round((Amount * SourceRate * NewMultiplier) / (NewRate * SourceMultiplier), 2);
	
EndFunction

// Substitutes parameters in a string. The number of the parameters in the string is unlimited.
// Parameters in the string have the following format: %<parameter number>. The parameter numbering
// starts from 1.
//
// Parameters:
//  StringPattern  - String - string pattern with parameters formatted as "%<parameter number>";
//  Parameters     - Array - parameters values in the StringPattern string.
//
// Returns:
//   String - 
//
Function SubstituteParametersToStringFromArray(Val StringPattern, Val Parameters) Export
	
	ResultString = StringPattern;
	
	Index = Parameters.Count();
	While Index > 0 Do
		Value = Parameters[Index-1];
		ResultString = StrReplace(ResultString, "%" + Format(Index, "NG="), Value);
		Index = Index - 1;
	EndDo;
	
	Return ResultString;
	
EndFunction

#EndRegion