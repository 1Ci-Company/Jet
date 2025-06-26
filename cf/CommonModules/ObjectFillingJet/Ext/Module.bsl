
#Region Public

// Fills document.
//
// Parameters:
//  DocumentObject - DocumentObject - object of any document
//  FillingData - Structure - filling data
//
Procedure FillDocument(DocumentObject, Val FillingData) Export
	
	If TypeOf(FillingData) <> Type("Structure") Then
		FillingData = New Structure;
	EndIf;
	
	AddCurrency(DocumentObject, FillingData);
	FillingData.Insert("Author", Users.AuthorizedUser());
	FillPropertyValues(DocumentObject, FillingData);
	
EndProcedure

#EndRegion

#Region Private

Procedure AddCurrency(DocumentObject, FillingData)
	
	If Not Common.HasObjectAttribute("Currency", DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	DocumentDate = DocumentObject.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	If Not FillingData.Property("Currency") Or Not ValueIsFilled(FillingData.Currency) Then
		FillingData.Insert("Currency", JetServer.GetPresentationCurrency());
		FillingData.Insert("ExchangeRate", 1);
		FillingData.Insert("Multiplier", 1);
	Else
		ExchRateData = CurrencyRateOperations.GetCurrencyRate(FillingData.Currency, DocumentDate);
		FillingData.Insert("ExchangeRate", ExchRateData.Rate);
		FillingData.Insert("Multiplier", ExchRateData.Repetition);
	EndIf;
	
EndProcedure

#EndRegion