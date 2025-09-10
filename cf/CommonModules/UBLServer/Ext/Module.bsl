
#Region Public

Function PostalAddressTemplate(SourceObject, AddressType, ErrorIndex, ResultStructure) Export
	
	PostalAddress = "";
	HasErrors = False;
	ErrorText = "";
	MissingFields = New Array;
	
	// Default XML template
	Template =
	"<cac:PostalAddress>
	|	<cbc:StreetName>%1</cbc:StreetName>
	|	<cbc:BuildingName></cbc:BuildingName>
	|	<cbc:CitySubdivisionName>%4</cbc:CitySubdivisionName>
	|	<cbc:CityName>%2</cbc:CityName>
	|	<cac:Country>
	|		%3
	|	</cac:Country>
	|</cac:PostalAddress>";
	
	// Fetch address information
	CI = ContactsManager.ObjectContactInformation(
		SourceObject,
		ContactsManager.ContactInformationKindByName(AddressType),,
		False);
	HasErrors = (CI.Count() = 0);
	
	If Not HasErrors Then
		
		JSONData = CI[0].Value;
		AddressStruct = ContactsManagerInternal.JSONStringToStructure1(ReplaceObject(JSONData));
		
		AddressLine = "";
		City = "";
		State = "";
		
		// Fill address line
		If AddressStruct.Property("AddressLine1") Then
			AddressLine = ReplaceObject(AddressStruct.AddressLine1);
			If IsBlankString(AddressLine) Then
				MissingFields.Add(NStr("en = 'Street (AddressLine1)'; tr = 'Sokak (Adres satırı 1)'"));
				HasErrors = True;
			EndIf;
		Else
			HasErrors = True;
			MissingFields.Add(NStr("en = 'Street (AddressLine1)'; tr = 'Sokak (Adres satırı 1)'"));
		EndIf;
		
		// Add second address line if available
		If AddressStruct.Property("AddressLine2") Then
			AddressLine = AddressLine + Chars.NBSp + ReplaceObject(AddressStruct.AddressLine2);
		EndIf;
		
		// Fill city
		If AddressStruct.Property("City") Then
			City = AddressStruct.City;
			If IsBlankString(City) Then
				HasErrors = True;
				MissingFields.Add(NStr("en = 'City'; tr = 'Şehir'"));
			EndIf;
		Else
			HasErrors = True;
			MissingFields.Add(NStr("en = 'City'; tr = 'Şehir'"));
		EndIf;
		
		// Fill state (district)
		If AddressStruct.Property("State") Then
			State = AddressStruct.State;
			If IsBlankString(State) Then
				HasErrors = True;
				MissingFields.Add(NStr("en = 'State'; tr = 'Bölge'"));
			EndIf;
		Else
			HasErrors = True;
			MissingFields.Add(NStr("en = 'State'; tr = 'Bölge'"));
		EndIf;
		
		CountryBlock = 
		"<cbc:IdentificationCode>TR</cbc:IdentificationCode>
		|<cbc:Name>Türkiye</cbc:Name>";
		// Fill country if available
		If AddressStruct.Property("Country") Then
			Country = Catalogs.WorldCountries.FindByDescription(ReplaceObject(AddressStruct.Country));
			If ValueIsFilled(Country) Then
				CountryBlock = StringFunctionsClientServer.SubstituteParametersToString(
					"<cbc:IdentificationCode>%1</cbc:IdentificationCode>
					|<cbc:Name>%2</cbc:Name>",
					Country.CodeAlpha2,
					Country.Description);
			EndIf;
		EndIf;
		
		// Merge template with parameters
		Parameters = New Array;
		Parameters.Add(AddressLine);
		Parameters.Add(City);
		Parameters.Add(CountryBlock);
		Parameters.Add(State);
		
		PostalAddress = JetClientServer.SubstituteParametersToStringFromArray(Template, Parameters);
		
	EndIf;
	
	// If there is any error, return empty
	If HasErrors Then
		
		ErrorText = EDIServer.AddressNotValidErrorText(ErrorIndex);
		If MissingFields.Count() > 0 Then
			
			For Each FieldName In MissingFields Do
				ErrorText = ErrorText + "
				|- " + FieldName;
			EndDo;
			
		EndIf;
		
		ResultStructure.ErrorsToShow = True;
		ResultStructure.ListOfErrorsToShow.Add(ErrorText);
		
		Return "";
		
	EndIf;
	
	Return PostalAddress;
	
EndFunction

Function WarehousePostalAddress(StructuralUnit, ResultStructure) Export
	
	ErrorText = "";
	WarehousePostalAddressAddressStructure = New Structure;
	WarehousePostalAddressAddressStructure.Insert("CounterpartyAddress", "");
	WarehousePostalAddressAddressStructure.Insert("AddressString", "");
	WarehousePostalAddressAddressStructure.Insert("City", "");
	WarehousePostalAddressAddressStructure.Insert("Country", "");
	WarehousePostalAddressAddressStructure.Insert("State", "");
	WarehousePostalAddressAddressStructure.Insert("HasErrors", False);
	CITable = ContactsManager.ObjectContactInformation(
		StructuralUnit,
		ContactsManager.ContactInformationKindByName("BusinessUnitsActualAddress"),
		,
		False);
	
	If CITable.Count() Then
		
		PostalAddressStructure = ContactsManagerInternal.JSONStringToStructure1(ReplaceObject(CITable[0].Value));
		
		AddressString = "";
		If PostalAddressStructure.Property("value") Then
			AddressString = ReplaceObject(PostalAddressStructure.value);
			HasErrors = IsBlankString(PostalAddressStructure.value); 
			WarehousePostalAddressAddressStructure.AddressString = AddressString;
		Else
			HasErrors = True;
		EndIf;
		
		CityName = "";
		If PostalAddressStructure.Property("City") Then
			CityName = PostalAddressStructure.City;
			HasErrors = IsBlankString(PostalAddressStructure.City);
			WarehousePostalAddressAddressStructure.City = CityName;
		Else
			HasErrors = True;
		EndIf; 
		
		PostalCode = "";
		If PostalAddressStructure.Property("PostalCode") Then
			PostalCode = PostalAddressStructure.PostalCode;
			HasErrors = IsBlankString(PostalAddressStructure.PostalCode);
		Else
			HasErrors = True;
		EndIf;
		
		State = "";
		If PostalAddressStructure.Property("State") Then
			State = PostalAddressStructure.State;
			HasErrors = IsBlankString(PostalAddressStructure.State);
			WarehousePostalAddressAddressStructure.State = State;
		Else
			HasErrors = True;
		EndIf;
		
		CountryStr = 
		"<cbc:IdentificationCode>TR</cbc:IdentificationCode>
		|<cbc:Name>Türkiye</cbc:Name>";
		If PostalAddressStructure.Property("Country") Then
			
			County = Catalogs.WorldCountries.FindByDescription(PostalAddressStructure.Country);
			If ValueIsFilled(County) Then
				CountryStr = StringFunctionsClientServer.SubstituteParametersToString(
					"<cbc:IdentificationCode>%1</cbc:IdentificationCode>
					|<cbc:Name>%2</cbc:Name>",
					County.CodeAlpha2,
					County.Description);
			EndIf;
				
		EndIf;
		WarehousePostalAddressAddressStructure.Country = CountryStr;
		
		WarehousePostalAddress = 
		"<cbc:ID></cbc:ID>
		|<cac:Address>
		|	<cbc:ID></cbc:ID>
		|	<cbc:StreetName>%1</cbc:StreetName>
		|	<cbc:BuildingNumber></cbc:BuildingNumber>
		|	<cbc:CitySubdivisionName>%5</cbc:CitySubdivisionName>
		|	<cbc:CityName>%2</cbc:CityName>
		|	<cbc:PostalZone>%4</cbc:PostalZone>
		|	<cac:Country>
		|		%3
		|	</cac:Country>
		|</cac:Address>";
		
		Parameters = New Array;
		// %1
		Parameters.Add(AddressString);
		// %2
		Parameters.Add(CityName);
		// %3
		Parameters.Add(CountryStr);
		// %4
		Parameters.Add(PostalCode);
		// %5
		Parameters.Add(State);
		
		WarehousePostalAddress = JetClientServer.SubstituteParametersToStringFromArray(WarehousePostalAddress, Parameters);
		WarehousePostalAddressAddressStructure.CounterpartyAddress = WarehousePostalAddress;
		
	Else
		HasErrors = True;
	EndIf;
	
	If HasErrors Then
		
		ErrorText = EDIServer.AddressNotValidErrorText(2);
		ResultStructure.ErrorsToShow = True;
		ResultStructure.ListOfErrorsToShow.Add(ErrorText);
		WarehousePostalAddressAddressStructure.HasErrors = True;
		
		Return WarehousePostalAddressAddressStructure;
		
	EndIf;
	
	Return WarehousePostalAddressAddressStructure;
	
EndFunction

Function CounterpartyObjectByTIN(TIN) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Counterparties.Ref AS Ref
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Counterparties.TIN = &TIN";
	
	Query.SetParameter("TIN", TIN);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	Return Catalogs.Counterparties.EmptyRef();
	
EndFunction

Function GetEndNumber(Prefix, Type = Undefined) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIUUIDs.ID AS ID
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|WHERE
	|	EDIUUIDs.ID LIKE &Prefix
	|
	|ORDER BY
	|	ID DESC";
	
	Query.SetParameter("Prefix", Prefix + "%");
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Count() = 0 Then
		Result = "00000000";
	Else
		
		Selection.Next();
		LastNumber = Number(Right(Selection[0], 9));
		Result = LastNumber;
		If Type <> Undefined Then
			Result = New Structure("ID, LastNumber", Selection.ID, LastNumber)
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

#Region EInvoice

Function AttributesForLoadingInvoice(Document, GenereateDocumentNumber = False, ResultStructure = Undefined) Export
	
	Result = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Currency AS DocumentCurrency,
	|	SalesInvoice.Customer AS Counterparty,
	|	CAST(Counterparties.LegalName AS STRING(200)) AS CounterpartyLegalName,
	|	Companies.Ref AS Company,
	|	CAST(Companies.LegalName AS STRING(200)) AS CompanyLegalName,
	|	SalesInvoice.Total AS DocumentAmount,
	|	Counterparties.TIN AS CounterpartyTIN,
	|	SalesInvoice.VATWithholding AS VATWithholding,
	|	SalesInvoice.ExemptFromVAT AS ExemptFromVAT,
	|	Counterparties.IsIndividual AS IsIndividual,
	|	Counterparties.TaxOffice AS CounterpartyTaxOffice,
	|	SalesInvoice.UseTaxExemptionReason AS UseTaxExemptionReason,
	|	SalesInvoice.IsEInvoice AS IsEInvoice,
	|	SalesInvoice.EDocumentScenario AS EDocumentScenario,
	|	SalesInvoice.Comment AS Comment,
	|	EDIUUIDs.ID AS EDocumentNumber,
	|	EDIUUIDs.UUID AS EDocumentUUID,
	|	EDIUUIDs.QueryID AS QueryID,
	|	SalesInvoice.BankAccount AS BankAccount,
	|	SalesInvoice.ExchangeRate / SalesInvoice.Multiplier AS CurrencyExchangeRate,
	|	SalesInvoice.Identifier AS Identifier,
	|	SalesInvoice.EDocumentDeliveryType AS EDocumentDeliveryType,
	|	Companies.IsIndividual AS CompanyIsIndividual,
	|	Companies.TIN AS CompanyTIN,
	|	SalesInvoice.Ref AS Ref,
	|	FALSE AS AmountIncludesVAT
	|INTO TT_DocumentHeader
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Customer = Counterparties.Ref
	|		LEFT JOIN InformationRegister.EDIUUIDs AS EDIUUIDs
	|		ON SalesInvoice.Ref = EDIUUIDs.ElectronicDocument,
	|	Catalog.Companies AS Companies
	|WHERE
	|	SalesInvoice.Ref = &Document
	|	AND SalesInvoice.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DocumentHeader.Number AS Number,
	|	TT_DocumentHeader.Date AS Date,
	|	TT_DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_DocumentHeader.Counterparty AS Counterparty,
	|	TT_DocumentHeader.CounterpartyLegalName AS CounterpartyLegalName,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.CompanyLegalName AS CompanyLegalName,
	|	TT_DocumentHeader.DocumentAmount AS DocumentAmount,
	|	TT_DocumentHeader.CounterpartyTIN AS CounterpartyTIN,
	|	TT_DocumentHeader.VATWithholding AS VATWithholding,
	|	TT_DocumentHeader.ExemptFromVAT AS ExemptFromVAT,
	|	TT_DocumentHeader.IsIndividual AS IsIndividual,
	|	TT_DocumentHeader.CounterpartyTaxOffice AS CounterpartyTaxOffice,
	|	TT_DocumentHeader.UseTaxExemptionReason AS UseTaxExemptionReason,
	|	TT_DocumentHeader.IsEInvoice AS IsEInvoice,
	|	TT_DocumentHeader.EDocumentScenario AS EDocumentScenario,
	|	TT_DocumentHeader.Comment AS Comment,
	|	TT_DocumentHeader.EDocumentNumber AS EDocumentNumber,
	|	TT_DocumentHeader.EDocumentUUID AS EDocumentUUID,
	|	TT_DocumentHeader.QueryID AS QueryID,
	|	TT_DocumentHeader.BankAccount AS BankAccount,
	|	TT_DocumentHeader.CurrencyExchangeRate AS CurrencyExchangeRate,
	|	TT_DocumentHeader.Identifier AS Identifier,
	|	TT_DocumentHeader.EDocumentDeliveryType AS EDocumentDeliveryType,
	|	TT_DocumentHeader.CompanyIsIndividual AS CompanyIsIndividual,
	|	TT_DocumentHeader.CompanyTIN AS CompanyTIN
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Quantity AS Quantity,
	|	Products.Unit AS MeasurementUnit,
	|	DocumentTable.Amount AS TaxableAmount,
	|	DocumentTable.VATRate.Rate AS Percent,
	|	DocumentTable.VATAmount AS TaxAmount,
	|	Products.Description AS Products,
	|	DocumentTable.Price AS Price,
	|	DocumentTable.Amount AS LegalMonetary,
	|	DocumentTable.Amount AS LineExtensionAmount,
	|	CASE
	|		WHEN DocumentTable.VATWithholdingRate.RateDenominator = 0
	|			THEN 0
	|		ELSE 100 * DocumentTable.VATWithholdingRate.RateNumerator / DocumentTable.VATWithholdingRate.RateDenominator
	|	END AS WithholdingPercent,
	|	DocumentTable.VATWithholdingAmount AS WithholdingAmount,
	|	TaxExemptionReasons.Code AS TaxExemptionReasonCode,
	|	TaxExemptionReasons.DescriptionFull AS TaxExemptionReasonDescription
	|FROM
	|	Document.SalesInvoice.Inventory AS DocumentTable
	|		INNER JOIN TT_DocumentHeader AS TT_DocumentHeader
	|		ON DocumentTable.Ref = TT_DocumentHeader.Ref
	|		INNER JOIN Catalog.Products AS Products
	|		ON DocumentTable.Product = Products.Ref
	|		LEFT JOIN Catalog.TaxExemptionReasons AS TaxExemptionReasons
	|		ON DocumentTable.TaxExemptionReason = TaxExemptionReasons.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.VATRate.Rate AS Percent,
	|	CASE
	|		WHEN TT_DocumentHeader.AmountIncludesVAT
	|			THEN SUM(DocumentTable.Amount) - SUM(DocumentTable.VATAmount + DocumentTable.VATWithholdingAmount)
	|		ELSE SUM(DocumentTable.Amount)
	|	END AS TaxableAmount,
	|	SUM(DocumentTable.VATAmount + DocumentTable.VATWithholdingAmount) AS TaxAmount,
	|	TaxExemptionReasons.Code AS TaxExemptionReasonCode,
	|	TaxExemptionReasons.DescriptionFull AS TaxExemptionReasonDescription
	|FROM
	|	Document.SalesInvoice.Inventory AS DocumentTable
	|		INNER JOIN TT_DocumentHeader AS TT_DocumentHeader
	|		ON DocumentTable.Ref = TT_DocumentHeader.Ref
	|		LEFT JOIN Catalog.TaxExemptionReasons AS TaxExemptionReasons
	|		ON DocumentTable.TaxExemptionReason = TaxExemptionReasons.Ref
	|
	|GROUP BY
	|	DocumentTable.VATRate.Rate,
	|	TaxExemptionReasons.Code,
	|	TT_DocumentHeader.AmountIncludesVAT,
	|	TaxExemptionReasons.DescriptionFull
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN DocumentTable.VATWithholdingRate.RateDenominator = 0
	|			THEN 0
	|		ELSE 100 * DocumentTable.VATWithholdingRate.RateNumerator / DocumentTable.VATWithholdingRate.RateDenominator
	|	END AS Percent,
	|	SUM(DocumentTable.VATWithholdingAmount) AS TaxAmount,
	|	SUM(DocumentTable.VATAmount + DocumentTable.VATWithholdingAmount) AS TaxableAmount,
	|	VATWithholdingCodesTable.Code AS VATWithholdingCode,
	|	VATWithholdingCodesTable.Description AS VATWithholdingName,
	|	DocumentTable.LineNumber AS LineNumber
	|FROM
	|	Document.SalesInvoice.Inventory AS DocumentTable
	|		LEFT JOIN Catalog.VATWithholdingCodes AS VATWithholdingCodesTable
	|		ON DocumentTable.VATWithholdingCode = VATWithholdingCodesTable.Ref
	|WHERE
	|	DocumentTable.Ref = &Document
	|	AND DocumentTable.VATWithholdingAmount > 0
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentTable.VATWithholdingRate.RateDenominator = 0
	|			THEN 0
	|		ELSE 100 * DocumentTable.VATWithholdingRate.RateNumerator / DocumentTable.VATWithholdingRate.RateDenominator
	|	END,
	|	VATWithholdingCodesTable.Code,
	|	VATWithholdingCodesTable.Description,
	|	DocumentTable.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN DocumentTable.VATWithholdingRate.RateDenominator = 0
	|			THEN 0
	|		ELSE 100 * DocumentTable.VATWithholdingRate.RateNumerator / DocumentTable.VATWithholdingRate.RateDenominator
	|	END AS Percent,
	|	SUM(DocumentTable.VATWithholdingAmount) AS TaxAmount,
	|	SUM(DocumentTable.VATAmount + DocumentTable.VATWithholdingAmount) AS TaxableAmount,
	|	VATWithholdingCodesTable.Code AS VATWithholdingCode,
	|	VATWithholdingCodesTable.Description AS VATWithholdingName
	|FROM
	|	Document.SalesInvoice.Inventory AS DocumentTable
	|		LEFT JOIN Catalog.VATWithholdingCodes AS VATWithholdingCodesTable
	|		ON DocumentTable.VATWithholdingCode = VATWithholdingCodesTable.Ref
	|WHERE
	|	DocumentTable.Ref = &Document
	|	AND DocumentTable.VATWithholdingAmount > 0
	|
	|GROUP BY
	|	VATWithholdingCodesTable.Code,
	|	VATWithholdingCodesTable.Description,
	|	DocumentTable.VATWithholdingRate,
	|	CASE
	|		WHEN DocumentTable.VATWithholdingRate.RateDenominator = 0
	|			THEN 0
	|		ELSE 100 * DocumentTable.VATWithholdingRate.RateNumerator / DocumentTable.VATWithholdingRate.RateDenominator
	|	END";
	
	Query.SetParameter("Document", Document);
	QueryResult = Query.ExecuteBatch();
	
	// Header
	SelectionDocument = QueryResult[1].Select();
	
	If SelectionDocument.Next() Then
		
		DocumentDateTime = StrSplit(XMLString(SelectionDocument.Date), "T");
		EDocumentType = ?(SelectionDocument.IsEInvoice, Enums.EDocumentType.EInvoice, Enums.EDocumentType.EArchive);
		
		If GenereateDocumentNumber Then
			Result.Insert("DocumentUUID", New UUID);
			Result.Insert("DocumentID", GenerateUniqueNumber(Document, EDocumentType));
		Else
			Result.Insert("DocumentUUID", SelectionDocument.EDocumentUUID);
			Result.Insert("DocumentID", SelectionDocument.EDocumentNumber);
		EndIf;
		
		Result.Insert("IsEInvoice", SelectionDocument.IsEInvoice);
		Result.Insert("Company", SelectionDocument.Company);
		Result.Insert("CompanyTIN", TrimAll(SelectionDocument.CompanyTIN));
		If IsBlankString(SelectionDocument.CompanyTIN) Then
			
			ErrorText = EDIServer.TINNotValidErrorText(0);
			ResultStructure.ErrorsToShow = True;
			ResultStructure.ListOfErrorsToShow.Add(ErrorText);
			
			Return Result;
			
		EndIf;
		
		Result.Insert("CompanyLegalName", TrimAll(SelectionDocument.CompanyLegalName));
		Result.Insert("CompanyEmailGB", Catalogs.EDIProfiles.GetEDIProfile(SelectionDocument.Company).SenderTagEInvoice);
		Result.Insert("CompanyEmail",
			ContactsManager.ObjectContactInformation(SelectionDocument.Company,
			ContactsManager.ContactInformationKindByName("CompanyEmail")));
		Result.Insert("CompanyWebpage",
			ContactsManager.ObjectContactInformation(SelectionDocument.Company,
			ContactsManager.ContactInformationKindByName("CompanyWebpage")));
		Result.Insert("CompanyFax",
			ContactsManager.ObjectContactInformation(SelectionDocument.Company,
			ContactsManager.ContactInformationKindByName("CompanyFax")));
		
		Result.Insert("Counterparty", SelectionDocument.Counterparty);
		
		If IsBlankString(SelectionDocument.CounterpartyTIN) Then
			
			ErrorText = EDIServer.TINNotValidErrorText(1);
			ResultStructure.ErrorsToShow = True;
			ResultStructure.ListOfErrorsToShow.Add(ErrorText);
			
			Return Result;
			
		EndIf;
		
		Result.Insert("CounterpartyLegalName", TrimAll(SelectionDocument.CounterpartyLegalName));
		Result.Insert("CounterpartyVKN", TrimAll(SelectionDocument.CounterpartyTIN));
		Result.Insert("EDocumentDeliveryType", SelectionDocument.EDocumentDeliveryType);
		
		IsTaxpayer = EDIServer.IsTaxpayer(SelectionDocument.Company.TIN, EDocumentType);
		Result.Insert("IsPublicEstablishment", IsTaxpayer.IsPublicEstablishment);
		
		If SelectionDocument.VATWithholding Then
			EInvoiceTypeCode = Enums.EInvoiceTypeCode.TEVKIFAT;
		ElsIf SelectionDocument.ExemptFromVAT Or SelectionDocument.UseTaxExemptionReason Then
			EInvoiceTypeCode = Enums.EInvoiceTypeCode.ISTISNA;
		Else
			EInvoiceTypeCode = Enums.EInvoiceTypeCode.SATIS;
		EndIf;
		
		Result.Insert("EDocumentScenario", SelectionDocument.EDocumentScenario);
		Result.Insert("EInvoiceTypeCode", EInvoiceTypeCode);
		Result.Insert("InvoiceDate", DocumentDateTime[0]);
		Result.Insert("InvoiceTime", DocumentDateTime[1]);
		Result.Insert("PaymentDate", SelectionDocument.Date);
		Result.Insert("CounterpartyEmail",
			ContactsManager.ObjectContactInformation(SelectionDocument.Counterparty,
			ContactsManager.ContactInformationKindByName("CounterpartyEmail")));
		Result.Insert("CounterpartyWebpage",
			ContactsManager.ObjectContactInformation(SelectionDocument.Counterparty,
			ContactsManager.ContactInformationKindByName("CounterpartyWebpage")));
		Result.Insert("CounterpartyTaxOffice", SelectionDocument.CounterpartyTaxOffice);
		Result.Insert("CounterpartyGIBPK", SelectionDocument.Identifier);
		Result.Insert("CounterpartyPhone",
			ContactsManager.ObjectContactInformation(SelectionDocument.Counterparty,
			ContactsManager.ContactInformationKindByName("CounterpartyPhone")));
		Result.Insert("Document", Document);
		Result.Insert("BankAccount", SelectionDocument.BankAccount);
		Result.Insert("CurrencyExchangeRate", SelectionDocument.CurrencyExchangeRate);
		
		CompanyPerson = "";
		If SelectionDocument.CompanyIsIndividual Then
			
			NameParts = StrSplit(String(SelectionDocument.Company), " ");
			If NameParts.Count() > 1 Then
				
				CompanyPerson = 
				"<cac:Person>
				|   <cbc:FirstName>" + NameParts[0] + "</cbc:FirstName>
				|   <cbc:FamilyName>" + NameParts[1] + "</cbc:FamilyName>
				|</cac:Person>";
				
			EndIf;
			
		EndIf;
		
		Result.Insert("CompanyPerson", CompanyPerson);
		Result.Insert("CompanyIsIndividual", SelectionDocument.CompanyIsIndividual);
		
		CounterpartyPerson = "";
		If SelectionDocument.IsIndividual Then
			
			If StrLen(Result.CounterpartyVKN) <> 11 Then
				
				ErrorText = EDIServer.TINNotValidErrorText(2);
				ResultStructure.ErrorsToShow = True;
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
				Return Result;
				
			EndIf;
			
			NameParts = StrSplit(String(SelectionDocument.Counterparty), " ");
			If NameParts.Count() > 1 Then
				
				CounterpartyPerson = 
				"<cac:Person>
				|   <cbc:FirstName>" + NameParts[0] + "</cbc:FirstName>
				|   <cbc:FamilyName>" + NameParts[1] + "</cbc:FamilyName>
				|</cac:Person>";
				
			EndIf;
			
		EndIf;
		
		Result.Insert("CounterpartyPerson", CounterpartyPerson);
		Result.Insert("IsIndividual", SelectionDocument.IsIndividual);
		Result.Insert("DocumentCurrency", SelectionDocument.DocumentCurrency);
		Result.Insert("DocumentCurrencyCode", Left(SelectionDocument.DocumentCurrency, 3));
		Result.Insert("DocumentAmount", SelectionDocument.DocumentAmount);
		Result.Insert("ExemptFromVAT", SelectionDocument.ExemptFromVAT);
		
		// Company postal adress
		CompanyPostalAddress = PostalAddressTemplate(SelectionDocument.Company, "CompanyLegalAddress", 0, ResultStructure);
		Result.Insert("CompanyPostalAddress", CompanyPostalAddress);
		
		Result.Insert("CompanyPhone",
			ContactsManager.ObjectContactInformation(SelectionDocument.Company,
			ContactsManager.ContactInformationKindByName("CompanyPhone")));
		
		// Counterparty postal address
		CounterpartyPostalAddress = PostalAddressTemplate(SelectionDocument.Counterparty, "CounterpartyLegalAddress", 1, ResultStructure);
		If IsBlankString(CounterpartyPostalAddress)
			Or IsBlankString(CompanyPostalAddress) Then
			Return Result;
		EndIf;
		
		Result.Insert("CounterpartyPostalAddress", CounterpartyPostalAddress);
		Result.Insert("CounterpartyFax",
			ContactsManager.ObjectContactInformation(SelectionDocument.Counterparty, ContactsManager.ContactInformationKindByName("CounterpartyFax")));
		Result.Insert("Address", "");
		Result.Insert("Notes", SelectionDocument.Comment);
		
		// Inventory Table
		Result.Insert("InventoryTable", QueryResult[2].Unload());
		
		Result.Insert("DocumentDiscount", 0);
		Result.Insert("DocumentWithholding", Result.InventoryTable.Total("WithholdingAmount"));
		Result.Insert("DocumentTax", Result.InventoryTable.Total("TaxAmount"));
		Result.Insert("LegalMonetaryTotal", Result.InventoryTable.Total("LegalMonetary"));
		Result.Insert("LineExtensionAmount", Result.InventoryTable.Total("LineExtensionAmount"));
		Result.Insert("IsEmpty", (Result.InventoryTable.Count() = 0));
		
		// Taxes
		Result.Insert("TaxesTable", QueryResult[3].Unload());
		Result.Insert("TaxExclusiveAmount", Result.TaxesTable.Total("TaxableAmount"));
		// Withholding Taxes
		Result.Insert("WithholdingTable", QueryResult[4].Unload());
		Result.Insert("WithholdingTotal", QueryResult[5].Unload());
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GenerateUBL(DocumentAttributes) Export
	
	FormatString = "NFD=2; NDS=.; NZ=0; NG=0";
	PercentFormatString = "NFD=0; NZ=0; NG=0";
	
	Parameters = New Array;
	// %1
	Parameters.Add(DocumentAttributes.DocumentID);
	// %2
	Parameters.Add(Upper(DocumentAttributes.DocumentUUID));
	// %3
	Parameters.Add(DocumentAttributes.InvoiceDate);
	// %4
	Parameters.Add(DocumentAttributes.InvoiceTime);
	// %5
	Parameters.Add(DocumentAttributes.EInvoiceTypeCode);
	// %6
	Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
	// %7
	Parameters.Add(DocumentAttributes.InventoryTable.Count());
	// %8 - company info
	Parameters.Add(PartyDescription(True, DocumentAttributes));
	// %9 - counterparty info
	Parameters.Add(PartyDescription(False, DocumentAttributes));
	
	// %10 - tax info
	Parameters.Add(DocumentTaxLines(DocumentAttributes, FormatString, PercentFormatString));
	// %11 - withholding
	Parameters.Add(?(TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice"),
		DocumentWithholdingTaxLines(DocumentAttributes, FormatString, PercentFormatString),
		""));
	// %12 - totals info
	Parameters.Add(LegalMonetaryTotal(DocumentAttributes, FormatString));
	// %13 - invoice lines
	Parameters.Add(DocumentLines(DocumentAttributes, FormatString, PercentFormatString));
	// %14 - EDocumentType
	Parameters.Add(?(DocumentAttributes.IsEInvoice, DocumentAttributes.EDocumentScenario, "EARSIVFATURA"));
	// %15  - additional document xslt
	Parameters.Add(AdditionalDocumentReference(DocumentAttributes.XSLT, DocumentAttributes.InvoiceDate, DocumentAttributes));
	// %16
	Parameters.Add("");
	// %17
	Parameters.Add(?(TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice"),
		PaymentMeans(DocumentAttributes), ""));
	// %18
	Parameters.Add(AddFreightAndInsuranceCharges(DocumentAttributes, FormatString));
	// %19 - notes and comments
	Parameters.Add(AddNotes(DocumentAttributes));
	// %20 - freight & insurance items
	Parameters.Add(AddFreightAndInsuranceItems(DocumentAttributes, FormatString));
	// %21 - DespatchDocumentReference
	Parameters.Add(?(TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice"),
		DespatchDocumentReference(DocumentAttributes), ""));
	// %22 - ExchangeRateSubtotal
	Parameters.Add(ExchangeRateSubtotal(DocumentAttributes));
	
	UBL = 
	"<?xml version=""1.0"" encoding=""UTF-8""?>
	|<?xml-stylesheet type=""text/xsl"" href=""%1.xslt""?>
	|<Invoice
	| xmlns:cac=""urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2""
	| xmlns:cbc=""urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2""
	| xmlns:udt=""urn:un:unece:uncefact:data:specification:UnqualifiedDataTypesSchemaModule:2""
	| xmlns:ccts=""urn:un:unece:uncefact:documentation:2""
	| xmlns:ext=""urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2""
	| xmlns:qdt=""urn:oasis:names:specification:ubl:schema:xsd:QualifiedDatatypes-2""
	| xmlns:ubltr=""urn:oasis:names:specification:ubl:schema:xsd:TurkishCustomizationExtensionComponents""
	| xmlns:ds=""http://www.w3.org/2000/09/xmldsig#"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance""
	| xsi:schemaLocation=""urn:oasis:names:specification:ubl:schema:xsd:Invoice-2 UBL-Invoice-2.1.xsd""
	| xmlns:xades=""http://uri.etsi.org/01903/v1.3.2#"" xmlns=""urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"">
	|	<cbc:UBLVersionID>2.1</cbc:UBLVersionID>
	|	<cbc:CustomizationID>TR1.2</cbc:CustomizationID>
	|	<cbc:ProfileID>%14</cbc:ProfileID>
	|	<cbc:ID>%1</cbc:ID>
	|	<cbc:CopyIndicator>false</cbc:CopyIndicator>
	|	<cbc:UUID>%2</cbc:UUID>
	|	<cbc:IssueDate>%3</cbc:IssueDate>
	|	<cbc:IssueTime>%4</cbc:IssueTime>
	|	<cbc:InvoiceTypeCode>%5</cbc:InvoiceTypeCode>
	|	%19
	|	<cbc:DocumentCurrencyCode>%6</cbc:DocumentCurrencyCode>
	|	<cbc:LineCountNumeric>%7</cbc:LineCountNumeric>
	|	%21
	|	%15
	|	<cac:AccountingSupplierParty>
	|		%8
	|	</cac:AccountingSupplierParty>
	|	<cac:AccountingCustomerParty>
	|		%9
	|	</cac:AccountingCustomerParty>
	|	%16
	|	%20
	|	%17
	|	%18
	|	%22
	|	<cac:TaxTotal>
	|		%10
	|	</cac:TaxTotal>
	|		%11
	|	<cac:LegalMonetaryTotal>
	|		%12
	|	</cac:LegalMonetaryTotal>
	|	%13
	|</Invoice>";
	
	UBL = JetClientServer.SubstituteParametersToStringFromArray(UBL, Parameters);
	
	Return UBL;
	
EndFunction

// Converts UBL XDTO object to structure
//
// Parameters:
//  XDTOData - UBL XDTO object 
// 
// Return value: Structure - Invoice Structure
//
Function PrepareDataFromNode(XDTOData) Export
	
	Result = New Structure;
	RegExp = "^\d{1,20}(\.\d{1,8})";
	
	Try
		
		Data = TrimAll(XDTOData.Sequence().GetText(0));
		If StrLikeByRegularExpression(Data, RegExp) Then
			Result.Insert("__content", XMLStringToNumber(Data));
		Else
			Result.Insert("__content", Data);
		EndIf;
		
	Except
		Result.Insert("__TextError", ErrorProcessing.DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	DataCollection = XDTOData.Properties();
	
	For Each Property In DataCollection Do
		
		CurrentData = XDTOData[Property.Name];
		
		If TypeOf(CurrentData) = Type("String") Then
			
			CurrentData = TrimAll(CurrentData);
			If StrLikeByRegularExpression(CurrentData, RegExp) Then
				Result.Insert(Property.Name, XMLStringToNumber(CurrentData));
			Else
				Result.Insert(Property.Name, CurrentData);
			EndIf;
			
		ElsIf TypeOf(CurrentData) = Type("XDTODataObject") Then
			Result.Insert(Property.Name, PrepareDataFromNode(CurrentData));
		ElsIf TypeOf(CurrentData) = Type("XDTOList") Then
			
			TagsList = New Array;
			
			For Each Tag In CurrentData Do
				If TypeOf(Tag) = Type("String") Then
					TagsList.Add(Tag);
				ElsIf TypeOf(Tag) = Type("XDTODataObject") Then
					TagsList.Add(PrepareDataFromNode(Tag));
				EndIf;
			EndDo;
			
			Result.Insert(Property.Name, TagsList);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function FindTIN(XDTODataStructure) Export
	
	Result = "";
	
	If TypeOf(XDTODataStructure.PartyIdentification) = Type("Array") Then
		
		For Each Rec In XDTODataStructure.PartyIdentification Do
			RecID = Rec.ID;
			If RecID.schemeID = "VKN" Then
				
				If RecID.Property("__content") Then
					Result = RecID.__content;
				EndIf;
				
				Break;
				
			ElsIf RecID.schemeID = "TCKN" And RecID.Property("__content") Then
				
				If RecID.Property("__content") Then
					Result = RecID.__content;
				EndIf;
				
				Break;
				
			EndIf;
		EndDo;
		
	ElsIf TypeOf(XDTODataStructure.PartyIdentification) = Type("Structure") Then
		
		Rec = XDTODataStructure.PartyIdentification.ID;
		If Rec.schemeID = "VKN" And Rec.Property("__content") Then
			Result = Rec.__content;
		ElsIf Rec.schemeID = "TCKN" And Rec.Property("__content") Then
			Result = Rec.__content;
		Else
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetDateFromString(IssueDate, IssueTime = Undefined) Export
	
	IssuedDate = StrSplit(IssueDate, "-");
	
	If IssueTime <> Undefined Then
		IssuedTime = StrSplit(IssueTime, ":");
		Return Date(IssuedDate.Get(0), IssuedDate.Get(1), IssuedDate.Get(2), IssuedTime.Get(0), IssuedTime.Get(1), 0);
	EndIf;
	
	Return Date(IssuedDate.Get(0), IssuedDate.Get(1), IssuedDate.Get(2));
	
EndFunction

#EndRegion

Function XMLStringToNumber(Data) Export
	
	DataNumber = Number(Data);
	If InfoBaseLocaleCode() = "en_US" Then
		Return DataNumber;
	EndIf;
	
	If Format(DataNumber, "NFD=2; NZ=0") = Data Then
		Return DataNumber;
	ElsIf Data = "0" Then
		Return 0;
	Else
		Return StrReplace(Data, ".", ",");
	EndIf;
	
EndFunction

Function GetVATRateFromNumber(Rate) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	VATRates.Ref AS Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = &Rate";
	
	Query.SetParameter("Rate", Rate);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		Return Selection.Ref;
	EndDo;
	
	Return Catalogs.VATRates.EmptyRef();
	
EndFunction

#EndRegion

#Region Private

#Region GeneratingUBL

#Region EInvoice

Function PartyDescription(IsCompany, DocumentAttributes)
	
	PartyName = 
	"<cac:PartyName>
	|	<cbc:Name>%3</cbc:Name>
	|</cac:PartyName>";
	
	CompanyPerson = ?(DocumentAttributes.CompanyIsIndividual, DocumentAttributes.CompanyPerson, "");
	CounterpartyPerson = ?(DocumentAttributes.IsIndividual, DocumentAttributes.CounterpartyPerson, "");
	CompanyVKNTCKN = ?(DocumentAttributes.CompanyIsIndividual, "TCKN", "VKN");
	CounterpartyVKNTCKN = ?(DocumentAttributes.IsIndividual, "TCKN", "VKN");
	TIN = DocumentAttributes.CounterpartyVKN;
	
	If IsCompany Then
		TIN = DocumentAttributes.CompanyTIN;
	EndIf;
	
	Parameters = New Array;
	// %1
	Parameters.Add(?(IsCompany, CompanyVKNTCKN, CounterpartyVKNTCKN));
	// %2
	Parameters.Add(TIN);
	// %3
	Parameters.Add(?(IsCompany, ReplaceObject(DocumentAttributes.CompanyLegalName), ReplaceObject(DocumentAttributes.CounterpartyLegalName)));
	// %4
	Parameters.Add(?(IsCompany, PartyName, ?(DocumentAttributes.IsIndividual, "", PartyName)));
	// %5
	Parameters.Add(?(IsCompany, DocumentAttributes.CompanyPostalAddress, DocumentAttributes.CounterpartyPostalAddress));
	// %6
	Parameters.Add(?(IsCompany, DocumentAttributes.Company.TaxOffice, DocumentAttributes.CounterpartyTaxOffice));
	// %7
	Parameters.Add(?(IsCompany, DocumentAttributes.CompanyEmail, DocumentAttributes.CounterpartyEmail));
	// %8
	Parameters.Add(?(IsCompany, CompanyPerson, CounterpartyPerson));
	// %9
	Parameters.Add(?(IsCompany, FillMersisNo(DocumentAttributes.Company), ""));
	// %10
	Parameters.Add(?(IsCompany,DocumentAttributes.CompanyWebpage, DocumentAttributes.CounterpartyWebpage));
	// %11
	Parameters.Add(?(IsCompany, DocumentAttributes.CompanyPhone, DocumentAttributes.CounterpartyPhone));
	// %12
	Parameters.Add(?(IsCompany, DocumentAttributes.CompanyFax, DocumentAttributes.CounterpartyFax));
	
	ResultTemplate =
	"<cac:Party>
	|	<cac:PartyIdentification>
	|		<cbc:ID schemeID=""%1"">%2</cbc:ID>
	|	</cac:PartyIdentification>
	|	%9
	|	%4
	|	%5
	|	<cac:PartyTaxScheme>
	|		<cac:TaxScheme>
	|			<cbc:Name>%6</cbc:Name>
	|		</cac:TaxScheme>
	|	</cac:PartyTaxScheme>
	|	<cac:Contact>
	|		<cbc:Telephone>%11</cbc:Telephone>
	|		<cbc:Telefax>%12</cbc:Telefax>
	|		<cbc:ElectronicMail>%7</cbc:ElectronicMail>
	|	</cac:Contact>
	|	%8
	|</cac:Party>";
	
	Result = JetClientServer.SubstituteParametersToStringFromArray(ResultTemplate, Parameters);
	
	Return Result;
	
EndFunction

Function DocumentTaxLines(DocumentAttributes, FormatString, PercentFormatString)
	
	// total tax amount
	XMLData = "<cbc:TaxAmount currencyID=""%1"">%2</cbc:TaxAmount>";
	
	XMLData = StringFunctionsClientServer.SubstituteParametersToString(XMLData,
		DocumentAttributes.DocumentCurrencyCode,
		Format(DocumentAttributes.DocumentTax, FormatString));
	
	// line for each percentage
	For Each TaxLine In DocumentAttributes.TaxesTable Do
		
		Parameters = New Array;
		// %1
		Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
		// %2
		Parameters.Add(Format(TaxLine.TaxableAmount, FormatString));
		// %3
		Parameters.Add(Format(TaxLine.TaxAmount, FormatString));
		// %4
		Parameters.Add(Format(TaxLine.Percent, PercentFormatString));
		// %5
		Parameters.Add(TaxExemptionLine(TaxLine));
		
		TaxLineXMLData = "
		|<cac:TaxSubtotal>
		| <cbc:TaxableAmount currencyID=""%1"">%2</cbc:TaxableAmount>
		| <cbc:TaxAmount currencyID=""%1"">%3</cbc:TaxAmount>
		| <cbc:Percent>%4</cbc:Percent>
		| <cac:TaxCategory>
		|  %5
		|  <cac:TaxScheme>
		|   <cbc:Name>KDV</cbc:Name>
		|   <cbc:TaxTypeCode>0015</cbc:TaxTypeCode>
		|  </cac:TaxScheme>
		| </cac:TaxCategory>
		|</cac:TaxSubtotal>";
		
		TaxLineXMLData = JetClientServer.SubstituteParametersToStringFromArray(TaxLineXMLData, Parameters);
		
		XMLData = XMLData + TaxLineXMLData;
		
	EndDo;
	
	Return XMLData;
	
EndFunction

Function DocumentWithholdingTaxLines(DocumentAttributes, FormatString, PercentFormatString)
	
	XMLData = "";
	
	If DocumentAttributes.WithholdingTotal.Count() Then
		
		Lines = "";
		For Each TaxLine In DocumentAttributes.WithholdingTotal Do
			
			Parameters = New Array;
			// %1
			Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
			// %2
			Parameters.Add(Format(TaxLine.TaxableAmount, FormatString));
			// %3
			Parameters.Add(Format(TaxLine.TaxAmount, FormatString));
			// %4
			Parameters.Add(Format(TaxLine.Percent, PercentFormatString));
			// %5
			Parameters.Add(Format(TaxLine.VATWithholdingCode, FormatString));
			// %6
			Parameters.Add(TaxLine.VATWithholdingName);
			
			TaxLineXMLData = 
			"	<cac:TaxSubtotal>
			|		<cbc:TaxableAmount currencyID=""%1"">%2</cbc:TaxableAmount>
			|		<cbc:TaxAmount currencyID=""%1"">%3</cbc:TaxAmount>
			|		<cbc:Percent>%4</cbc:Percent>
			|		<cac:TaxCategory>
			|			<cac:TaxScheme>
			|				<cbc:Name>%6</cbc:Name>
			|				<cbc:TaxTypeCode>%5</cbc:TaxTypeCode>
			|			</cac:TaxScheme>
			|		</cac:TaxCategory>
			|	</cac:TaxSubtotal>";
			
			TaxLineXMLData = JetClientServer.SubstituteParametersToStringFromArray(TaxLineXMLData, Parameters);
			Lines = Lines + Chars.LF + TaxLineXMLData;
			
		EndDo;
		
		XMLData = "
		|	<cac:WithholdingTaxTotal>
		|		<cbc:TaxAmount currencyID=""%1"">%2</cbc:TaxAmount>
		|		%3
		|	</cac:WithholdingTaxTotal>";
		
		XMLData = StringFunctionsClientServer.SubstituteParametersToString(
			XMLData,
			DocumentAttributes.DocumentCurrencyCode,
			Format(DocumentAttributes.DocumentWithholding, FormatString),
			Lines);
			
	EndIf;
	
	Return XMLData;
	
EndFunction

Function LegalMonetaryTotal(DocumentAttributes, FormatString)
	
	Parameters = New Array;
	// %1
	Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
	// %2
	Parameters.Add(Format(DocumentAttributes.LineExtensionAmount, FormatString));
	// %3
	Parameters.Add(Format(DocumentAttributes.TaxExclusiveAmount, FormatString));
	
	If TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice") Then
		TaxInclusiveAmount = Format(DocumentAttributes.TaxExclusiveAmount + DocumentAttributes.DocumentTax + 
			DocumentAttributes.DocumentWithholding, FormatString);
	EndIf;
	
	// %4
	Parameters.Add(TaxInclusiveAmount);
	// %5
	Parameters.Add(Format(DocumentAttributes.DocumentDiscount, FormatString));
	// %6
	Parameters.Add(Format(DocumentAttributes.DocumentAmount, FormatString));
	
	XMLData =
	"<cbc:LineExtensionAmount currencyID=""%1"">%2</cbc:LineExtensionAmount>
	|<cbc:TaxExclusiveAmount currencyID=""%1"">%3</cbc:TaxExclusiveAmount>
	|<cbc:TaxInclusiveAmount currencyID=""%1"">%4</cbc:TaxInclusiveAmount>
	|<cbc:AllowanceTotalAmount currencyID=""%1"">%5</cbc:AllowanceTotalAmount>
	|<cbc:PayableAmount currencyID=""%1"">%6</cbc:PayableAmount>";
	
	XMLData = JetClientServer.SubstituteParametersToStringFromArray(XMLData, Parameters);
	
	Return XMLData;
	
EndFunction

Function DocumentLines(DocumentAttributes, FormatString, PercentFormatString)
	
	XMLData = "";
	
	LineNumber = 1;
	
	For Each InvoiceLine In DocumentAttributes.InventoryTable Do
		
		Parameters = New Array;
		// %1
		Parameters.Add(InvoiceLine.LineNumber);
		// %2
		Parameters.Add(InvoiceLine.MeasurementUnit.Code);
		// %3
		Parameters.Add(Format(InvoiceLine.Quantity, FormatString));
		// %4
		Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
		// %5
		Parameters.Add(Format(InvoiceLine.TaxableAmount, FormatString));
		// %6
		Parameters.Add("0.0");
		// %7
		Parameters.Add("0.0");
		// %8
		Parameters.Add(?(TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice"),
			Format(InvoiceLine.TaxAmount + InvoiceLine.WithholdingAmount, FormatString),
			Format(InvoiceLine.TaxAmount, FormatString)));
		// %9
		Parameters.Add(Format(InvoiceLine.Percent, PercentFormatString));
		// %10
		Parameters.Add(TaxExemptionLine(InvoiceLine));
		// %11
		Parameters.Add(?(TypeOf(DocumentAttributes.Document) = Type("DocumentRef.SalesInvoice"),
			WithholdingLine(DocumentAttributes, InvoiceLine, FormatString, PercentFormatString),
			""));
		// %12
		Parameters.Add(XMLString(ReplaceObject(InvoiceLine.Products)));
		// %13
		Parameters.Add(Format(InvoiceLine.Price, "NFD=2; NDS=.; NZ=0; NG=0"));
		
		DocumentLineXMLData = "
		|	<cac:InvoiceLine>
		|		<cbc:ID>%1</cbc:ID>
		|		<cbc:InvoicedQuantity unitCode=""%2"">%3</cbc:InvoicedQuantity>
		|		<cbc:LineExtensionAmount currencyID=""%4"">%5</cbc:LineExtensionAmount>
		|		<cac:AllowanceCharge>
		|			<cbc:ChargeIndicator>false</cbc:ChargeIndicator>
		|			<cbc:MultiplierFactorNumeric>%6</cbc:MultiplierFactorNumeric>
		|			<cbc:Amount  currencyID=""%4"">%7</cbc:Amount>
		|		</cac:AllowanceCharge>
		|		<cac:TaxTotal>
		|			<cbc:TaxAmount currencyID=""%4"">%8</cbc:TaxAmount>
		|			<cac:TaxSubtotal>
		|				<cbc:TaxableAmount currencyID=""%4"">%5</cbc:TaxableAmount>
		|				<cbc:TaxAmount currencyID=""%4"">%8</cbc:TaxAmount>
		|				<cbc:CalculationSequenceNumeric>1</cbc:CalculationSequenceNumeric>
		|				<cbc:Percent>%9</cbc:Percent>
		|				<cac:TaxCategory>
		|					%10
		|					<cac:TaxScheme>
		|						<cbc:Name>KDV</cbc:Name>
		|						<cbc:TaxTypeCode>0015</cbc:TaxTypeCode>
		|					</cac:TaxScheme>
		|				</cac:TaxCategory>
		|			</cac:TaxSubtotal>
		|		</cac:TaxTotal>
		|		%11
		|		<cac:Item>
		|			<cbc:Name>%12</cbc:Name>
		|		</cac:Item>
		|		<cac:Price>
		|			<cbc:PriceAmount currencyID=""%4"">%13</cbc:PriceAmount>
		|		</cac:Price>
		|	</cac:InvoiceLine>";
		
		DocumentLineXMLData = JetClientServer.SubstituteParametersToStringFromArray(DocumentLineXMLData, Parameters);
		XMLData = XMLData + DocumentLineXMLData;
		LineNumber = LineNumber + 1;
		
	EndDo;
	
	Return XMLData;
	
EndFunction

Function TaxExemptionLine(TaxLine)
	
	Result = "";
	
	If Not IsBlankString(TaxLine.TaxExemptionReasonCode) Then
			
		XMLData = 
		"<cbc:TaxExemptionReasonCode>%1</cbc:TaxExemptionReasonCode>
		|<cbc:TaxExemptionReason>%2</cbc:TaxExemptionReason>";
		
		Result = StringFunctionsClientServer.SubstituteParametersToString(XMLData,
			TaxLine.TaxExemptionReasonCode,
			TaxLine.TaxExemptionReasonDescription);
			
	EndIf;
	
	Return Result;
	
EndFunction

Function WithholdingLine(DocumentAttributes, InvoiceLine, FormatString, PercentFormatString)
	
	XMLData = "";
	
	If InvoiceLine.WithholdingAmount <> 0 Then
		
		Parameters = New Array;
		FilterTaxLine = New Structure("LineNumber", InvoiceLine.LineNumber);
		Taxlines = DocumentAttributes.WithholdingTable.FindRows(FilterTaxLine);
		
		If ValueIsFilled(Taxlines) Then
			
			Taxline = Taxlines[0];
			// %1
			Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
			// %2
			Parameters.Add(Format(InvoiceLine.WithholdingAmount, FormatString));
			// %3
			Parameters.Add(Format(InvoiceLine.WithholdingAmount + InvoiceLine.TaxAmount, FormatString));
			// %4
			Parameters.Add(Format(InvoiceLine.WithholdingAmount, FormatString));
			// %5
			Parameters.Add(Format(InvoiceLine.WithholdingPercent, PercentFormatString));
			// %6
			Parameters.Add(Format(TaxLine.VATWithholdingCode, FormatString));
			// %7
			Parameters.Add(TaxLine.VATWithholdingName);
			
			XMLData = "
			|	<cac:WithholdingTaxTotal>
			|		<cbc:TaxAmount currencyID=""%1"">%2</cbc:TaxAmount>
			|		<cac:TaxSubtotal>
			|			<cbc:TaxableAmount currencyID=""%1"">%3</cbc:TaxableAmount>
			|			<cbc:TaxAmount currencyID=""%1"">%4</cbc:TaxAmount>
			|			<cbc:Percent>%5</cbc:Percent>
			|			<cac:TaxCategory>
			|				<cac:TaxScheme>
			|					<cbc:Name>%7</cbc:Name>
			|					<cbc:TaxTypeCode>%6</cbc:TaxTypeCode>
			|				</cac:TaxScheme>
			|			</cac:TaxCategory>
			|		</cac:TaxSubtotal>
			|	</cac:WithholdingTaxTotal>";
			
			XMLData = JetClientServer.SubstituteParametersToStringFromArray(XMLData, Parameters);
			
		EndIf;
		
	EndIf;
	
	Return XMLData;
	
EndFunction

Function GenerateUniqueNumber(Document, EDocumentType)
	
	Prefix = GetDocumentPrefix(Catalogs.Companies.MainCompany, Document.Warehouse, EDocumentType);
	
	If IsBlankString(Prefix) Then
		
		FirstLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		Letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
		RandomNumberGenerator = New RandomNumberGenerator;
		Random1 = RandomNumberGenerator.RandomNumber(1, 26);
		Random2 = RandomNumberGenerator.RandomNumber(1, 26);
		Random3 = RandomNumberGenerator.RandomNumber(1, 26);
		Prefix = Mid(FirstLetters, Random1, 1) + Mid(Letters, Random2, 1) + Mid(Letters, Random3, 1);
		
	EndIf;
	
	Year = Format(Year(Document.Date), "NFD=0; NG=");
	
	QueryPrefix = String(Prefix) + Year;
	EndNumber = GetEndNumber(QueryPrefix);
	
	EndNumber = EndNumber + 1;
	EndNumber = StrReplace(String(EndNumber), ".", "");
		
	Temp = Prefix + Year + String(EndNumber);
	MissingChar = 16 - StrLen(Temp);
	
	For i = 1 to MissingChar Do
		Year = Year + "0";
	EndDo;
	
	Return Prefix + Year + StrReplace(String(EndNumber), ".", "");
	
EndFunction

Function GetDocumentPrefix(Company, Owner, EDocumentType)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIProfilesDocumentPrefixes.Prefix AS Prefix
	|FROM
	|	Catalog.EDIProfiles.DocumentPrefixes AS EDIProfilesDocumentPrefixes
	|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
	|		ON EDIProfilesDocumentPrefixes.Ref = EDIProfiles.Ref
	|WHERE
	|	EDIProfilesDocumentPrefixes.EDocumentType = &EDocumentType
	|	AND EDIProfilesDocumentPrefixes.Owner = &Owner
	|	AND EDIProfiles.Company = &Company";
	
	Query.SetParameter("EDocumentType", EDocumentType);
	Query.SetParameter("Owner", Owner);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Query.Text = 
		"SELECT ALLOWED
		|	EDIProfilesDocumentPrefixes.Prefix AS Prefix
		|FROM
		|	Catalog.EDIProfiles.DocumentPrefixes AS EDIProfilesDocumentPrefixes
		|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
		|		ON EDIProfilesDocumentPrefixes.Ref = EDIProfiles.Ref
		|WHERE
		|	EDIProfilesDocumentPrefixes.EDocumentType = &EDocumentType
		|	AND EDIProfiles.Company = &Company";
		
		Query.SetParameter("EDocumentType", EDocumentType);
		Query.SetParameter("Company", Company);
		
		QueryResult = Query.Execute();
		
		
	EndIf;
	
	Selection = QueryResult.Select();
	
	Selection.Next();
	
	Return Selection.Prefix;
	
EndFunction

Function GetDate(pDate, WithTime = True, Seperator = "-") Export
	
	Day = Day(pDate);
	Day = ?(StrLen(Day) = 1, "0" + Day, Day);
	Month = Month(pDate);
	Month = ?(StrLen(Month) = 1, "0" + Month, Month);
	Year = Format(Year(pDate),"ND=4; NG=0");
	Hour = Hour(pDate);
	Hour = ?(StrLen(Hour) = 1, "0" + Hour, Hour);
	Min = Minute(pDate);
	Min = ?(StrLen(Min) = 1, "0" + Min, Min);
	
	Date = Year + Seperator + Month + Seperator + Day;
	
	If WithTime Then
		
		Date = Date + "T" + Hour + ":" + Min + ":00";
		
	EndIf;
	
	Return Date;
	
EndFunction

Function AdditionalDocumentReference(XSLT, InvoiceDate, DocumentAttributes)
	
	AdditionalDocument = "";
	
	If ValueIsFilled(XSLT) Then
		
		Parameters = New Array;
		// %1
		Parameters.Add(XSLT);
		// %2
		Parameters.Add(DocumentAttributes.InvoiceDate);
		
		AdditionalDocument = 
		"<cac:AdditionalDocumentReference>
		|	<cbc:ID></cbc:ID>
		|	<cbc:IssueDate>%2</cbc:IssueDate>
		|	<cbc:DocumentType>XSLT</cbc:DocumentType>
		|	<cac:Attachment>
		|		<cbc:EmbeddedDocumentBinaryObject characterSetCode=""UTF-8"" encodingCode=""Base64"" mimeCode=""application/xml"" filename=""tempFile.XSLT"">%1</cbc:EmbeddedDocumentBinaryObject>
		|	</cac:Attachment>
		|</cac:AdditionalDocumentReference>";
		
		AdditionalDocument = JetClientServer.SubstituteParametersToStringFromArray(AdditionalDocument, Parameters);
		
	EndIf;
	
	Return AdditionalDocument;
	
EndFunction

Function TaxpayerIdentifier(TIN, EDocumentType)
	
	Result = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	TaxpayerList.Identifier AS Identifier
	|FROM
	|	InformationRegister.TaxpayerList AS TaxpayerList
	|WHERE
	|	TaxpayerList.TIN = &TIN
	|	AND TaxpayerList.EDocumentType = &EDocumentType";
	
	Query.SetParameter("TIN", TIN);
	Query.SetParameter("EDocumentType", EDocumentType);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Result = Selection.Identifier;
	EndIf;
	
	Return Result;
	
EndFunction

Function PaymentMeans(DocumentAttributes)
	
	XML = "";
	
	Parameters = New Array;
	// %1
	Parameters.Add(GetDate(DocumentAttributes.PaymentDate, False));
	
	XML =
	"<cac:PaymentMeans>
	|	<cbc:PaymentMeansCode>ZZZ</cbc:PaymentMeansCode>
	|	<cbc:PaymentDueDate>%1</cbc:PaymentDueDate>";
	
	If ValueIsFilled(DocumentAttributes.BankAccount) Then
		// %2
		Parameters.Add(DocumentAttributes.BankAccount.IBAN);
		// %3
		Parameters.Add(DocumentAttributes.BankAccount.Bank);
		// %4
		Parameters.Add(DocumentAttributes.BankAccount.Currency);
		
		XML = XML + "
		|	<cac:PayeeFinancialAccount>
		|		<cbc:ID>%2</cbc:ID>
		|		<cbc:CurrencyCode>%4</cbc:CurrencyCode>
		|		<cbc:PaymentNote>%3</cbc:PaymentNote>
		|	</cac:PayeeFinancialAccount>";
		
	EndIf;
	
	XML = XML + "
	|</cac:PaymentMeans>";
	
	XML = JetClientServer.SubstituteParametersToStringFromArray(XML, Parameters);
	
	Return XML;
	
EndFunction

Function AddFreightAndInsuranceCharges(DocumentAttributes, FormatString)
	
	XML = "";
	
	Return XML;
	
EndFunction

Function AddFreightAndInsuranceItems(DocumentAttributes, FormatString)
	
	XML = "";
	
	Return XML;
	
EndFunction

Function DespatchDocumentReference(DocumentAttributes)
	
	XML = "";
	
	Return XML;
	
EndFunction

Function AddNotes(DocumentAttributes)
	
	If DocumentAttributes.EDocumentDeliveryType = Enums.EDocumentDeliveryType.ELEKTRONIK Then
		XML = "<cbc:Note>Gönderim Şekli: ELEKTRONIK</cbc:Note>";
	Else
		XML = "<cbc:Note>Gönderim Şekli:KAGIT</cbc:Note>";
	EndIf;
	
	DocumentInWords = CurrencyRateOperations.GenerateAmountInWords(DocumentAttributes.DocumentAmount, DocumentAttributes.DocumentCurrency, True);
	
	XML = XML + "<cbc:Note>Yalnız " + DocumentInWords + ".</cbc:Note>";
	
	BankAccount = GetEDIProfilesBankInfo(DocumentAttributes);
	
	If ValueIsFilled(BankAccount) Then
		XML = XML +  "<cbc:Note>BANKA BİLGİLERİ: "+ BankAccount + "</cbc:Note>";
	EndIf;
	
	Note = NStr("en = 'Supersedes E-Despatch'; tr = 'İrsaliye yerine geçer'");
	XML = XML + "<cbc:Note>" + Note + "</cbc:Note>";
	
	If Not IsBlankString(DocumentAttributes.Notes) Then
		
		DocumentNotes = StrSplit(DocumentAttributes.Notes, "|");
		Note = "";
		For Each NoteLine In DocumentNotes Do
			Note = Note + "
				|<cbc:Note>" + TrimAll(NoteLine) + "</cbc:Note>";
		EndDo;
		
		XML = XML + Note;
	
	EndIf;
	
	Return XML;
	
EndFunction

Function GetEDIProfilesBankInfo(DocumentAttributes)
	
	Result = "";
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIProfilesBankInfo.Bank AS Bank
	|FROM
	|	Catalog.EDIProfiles.BankInfo AS EDIProfilesBankInfo
	|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
	|		ON EDIProfilesBankInfo.Ref = EDIProfiles.Ref
	|WHERE
	|	EDIProfilesBankInfo.Counterparty = &Counterparty
	|	AND EDIProfiles.Company = &Company
	|	AND EDIProfilesBankInfo.EDocumentScenario = &EDocumentScenario";
	
	Query.SetParameter("Company", DocumentAttributes.Company);
	Query.SetParameter("Counterparty", DocumentAttributes.Counterparty);
	Query.SetParameter("EDocumentScenario", DocumentAttributes.EDocumentScenario);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	EDIProfilesBankInfo.Bank AS Bank
		|FROM
		|	Catalog.EDIProfiles.BankInfo AS EDIProfilesBankInfo
		|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
		|		ON EDIProfilesBankInfo.Ref = EDIProfiles.Ref
		|WHERE
		|	EDIProfiles.Company = &Company
		|	AND EDIProfilesBankInfo.Counterparty = &Counterparty";
		
		Query.SetParameter("Company", DocumentAttributes.Company);
		Query.SetParameter("Counterparty", DocumentAttributes.Counterparty);
		
		QueryResult = Query.Execute();
		
	EndIf;
	
	If QueryResult.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	EDIProfilesBankInfo.Bank AS Bank
		|FROM
		|	Catalog.EDIProfiles.BankInfo AS EDIProfilesBankInfo
		|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
		|		ON EDIProfilesBankInfo.Ref = EDIProfiles.Ref
		|WHERE
		|	EDIProfiles.Company = &Company
		|	AND EDIProfilesBankInfo.EDocumentScenario = &EDocumentScenario";
		
		Query.SetParameter("Company", DocumentAttributes.Company);
		Query.SetParameter("EDocumentScenario", DocumentAttributes.EDocumentScenario);
		
		QueryResult = Query.Execute();
		
	EndIf;
	
	If QueryResult.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	EDIProfilesBankInfo.Bank AS Bank
		|FROM
		|	Catalog.EDIProfiles.BankInfo AS EDIProfilesBankInfo
		|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
		|		ON EDIProfilesBankInfo.Ref = EDIProfiles.Ref
		|WHERE
		|	EDIProfiles.Company = &Company";
		
		Query.SetParameter("Company", DocumentAttributes.Company);
		
		QueryResult = Query.Execute();
		
	EndIf;
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		Result = Result + Chars.LF + Selection.Bank;
	EndDo;
	
	Return Result;
	
EndFunction

Function ExchangeRateSubtotal(DocumentAttributes)
	
	XML = "";
	
	If DocumentAttributes.Company.PresentationCurrency <> DocumentAttributes.DocumentCurrency Then
		
		Parameters = new Array;
		// %1
		Parameters.Add(DocumentAttributes.DocumentCurrencyCode);
		// %2
		Parameters.Add(DocumentAttributes.Company.PresentationCurrency);
		// %3
		Parameters.Add(StrReplace(DocumentAttributes.CurrencyExchangeRate, ",", "."));
		
		XML = 
		"<cac:PricingExchangeRate>
		|	<cbc:SourceCurrencyCode>%1</cbc:SourceCurrencyCode>
		|	<cbc:TargetCurrencyCode>%2</cbc:TargetCurrencyCode>
		|	<cbc:CalculationRate>%3</cbc:CalculationRate>
		|</cac:PricingExchangeRate>";
		
		XML = JetClientServer.SubstituteParametersToStringFromArray(XML, Parameters);
		
	EndIf;
	
	Return XML;
	
EndFunction

Function FillMersisNo(Company)
	
	XML = "
	|<cac:PartyIdentification>
	|	<cbc:ID schemeID=""MERSISNO"">" + TrimAll(Company.MersisNumber) + "</cbc:ID>
	|</cac:PartyIdentification>
	|<cac:PartyIdentification>
	|	<cbc:ID schemeID=""TICARETSICILNO"">" + TrimAll(Company.RegistrationNumber) + "</cbc:ID>
	|</cac:PartyIdentification>";
	
	Return XML;
	
EndFunction

#EndRegion

#EndRegion

Function ReplaceObject(Value)
	
	Result = StrReplace(Value, "&", "&amp;");
	Result = StrReplace(Result, "<", "&lt;");
	Result = StrReplace(Result, ">", "&gt;");
	Result = StrReplace(Result, "'", "&apos;");
	Result = StrReplace(Result, "¢", "&cent;");
	Result = StrReplace(Result, "£", "&pound;");
	Result = StrReplace(Result, "¥", "&yen;");
	Result = StrReplace(Result, "€", "&euro;");
	Result = StrReplace(Result, "©", "&copy;");
	Result = StrReplace(Result, "®", "&reg;");
	
	Return Result;
	
EndFunction

#EndRegion