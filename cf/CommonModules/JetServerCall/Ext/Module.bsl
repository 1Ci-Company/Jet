
#Region Public

// Gets value of VAT rate.
//
// Parameters:
//  VATRate - CatalogRef.VATRates - ref to VAT rates catalog
// Returns:
//  Number - rate of VAT
//
Function GetVATRateValue(VATRate) Export
	
	Return JetCached.GetVATRateValue(VATRate);
	
EndFunction

#EndRegion