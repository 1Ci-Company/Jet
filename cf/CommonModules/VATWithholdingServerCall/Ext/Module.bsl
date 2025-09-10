
#Region Public

// Gets percent of VATWithholdingRate catalog item
//
// Parameters:
//  VATWithholdingRate - CatalogRef.VATWithholdingRates - ref to VATWithholdingRate catalog item
//
// Returns:
//  Number - percent
//
Function GetVATWithholdingPercent(VATWithholdingRate) Export
	
	RatesAttributes = New Structure("RateNumerator,RateDenominator", 0, 0);
	If ValueIsFilled(VATWithholdingRate) Then
		RatesAttributes = Common.ObjectAttributesValues(VATWithholdingRate, "RateNumerator,RateDenominator");
	EndIf;
	
	Return ?(RatesAttributes.RateDenominator = 0, 0, RatesAttributes.RateNumerator / RatesAttributes.RateDenominator);
	
EndFunction

// Gets VATWithholdingRate catalog item
//
// Parameters:
//  VATWithholdingCode - CatalogRef.VATWithholdingCodes - ref to VATWithholdingCode catalog item
//
// Returns:
//  CatalogRef.VATWithholdingRates - rate of VATWithholdingCode
//
Function GetVATWithholdingRate(VATWithholdingCode) Export
	
	Rate = Catalogs.VATWithholdingRates.EmptyRef();
	If ValueIsFilled(VATWithholdingCode) Then
		Rate = Common.ObjectAttributeValue(VATWithholdingCode, "Rate");
	EndIf;
	
	Return Rate;
	
EndFunction

#EndRegion