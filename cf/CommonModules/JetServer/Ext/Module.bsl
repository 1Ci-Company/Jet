
#Region Public

// Gets presentation currency of the company.
//
// Returns:
//  CatalogRef.Currencies
//
Function GetPresentationCurrency() Export
	
	Return Common.ObjectAttributeValue(Catalogs.Companies.MainCompany, "PresentationCurrency");
	
EndFunction

#Region WorkWithQuery

// Gets "UNION" string for query text.
//
// Returns:
//  String -
//
Function GetQueryUnion() Export
	
	Return "
	|
	|UNION ALL
	|
	|";
	
EndFunction

// Gets query batch delimiter string for query text.
//
// Returns:
//  String -
//
Function GetQueryDelimeter() Export
	
	Return "
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
EndFunction

#EndRegion

#EndRegion