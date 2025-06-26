
#Region Public

// Fills in the currency and exchange rate in the structure
// by date and bank or cash account.
//
// Parameters:
//  DataStructure - Structure - date and account in the structure.
//
Procedure CurrencyExchangeRateData(DataStructure) Export
	
	PresentationCurrency = JetServer.GetPresentationCurrency();
	
	If ValueIsFilled(DataStructure.CashBankAccount) Then
		
		Currency = Common.ObjectAttributeValue(DataStructure.CashBankAccount, "Currency");
		
		If Currency <> PresentationCurrency Then
			ExchRateStructure = CurrencyRateOperations.GetCurrencyRate(Currency, DataStructure.Date);
			DataStructure.Insert("Currency", Currency);
			DataStructure.Insert("ExchangeRate", ExchRateStructure.Rate);
			DataStructure.Insert("Multiplier", ExchRateStructure.Repetition);
		Else
			DataStructure.Insert("Currency", PresentationCurrency);
			DataStructure.Insert("ExchangeRate", 1);
			DataStructure.Insert("Multiplier", 1);
		EndIf;
		
	Else
		DataStructure.Insert("Currency", PresentationCurrency);
		DataStructure.Insert("ExchangeRate", 1);
		DataStructure.Insert("Multiplier", 1);
	EndIf;
	
EndProcedure

#EndRegion