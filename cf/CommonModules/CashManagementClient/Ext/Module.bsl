
#Region Public

// Recalculates the amount at the currency exchange rate.
//
// Parameters:
//  Object - FormDataStructure - the document form object;
//  TabSectionName - String - the tabular section name to be recalculated.
//
Procedure RecalculateAmountAtExchangeRate(Object, TabSectionName = "PaymentDetails") Export
	
	If Object[TabSectionName].Count() = 0 Then
		Return;
	EndIf;
	
	ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
	Multiplier = ?(Object.Multiplier = 0, 1, Object.Multiplier);
	
	For Each Row In Object[TabSectionName] Do
		Row.Amount = Round(Row.PaymentAmount * ExchangeRate / Multiplier, 2);
	EndDo;
	
EndProcedure

#EndRegion