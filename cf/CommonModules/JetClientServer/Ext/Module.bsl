
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

#EndRegion