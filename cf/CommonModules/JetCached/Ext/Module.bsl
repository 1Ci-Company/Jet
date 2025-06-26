
#Region Public

// Gets value of VAT rate.
//
// Parameters:
//  VATRate - CatalogRef.VATRates - ref to VAT rates catalog
// Returns:
//  Number - rate of VAT
//
Function GetVATRateValue(VATRate) Export
	
	Return ?(ValueIsFilled(VATRate), Common.ObjectAttributeValue(VATRate, "Rate"), 0);
	
EndFunction

#EndRegion