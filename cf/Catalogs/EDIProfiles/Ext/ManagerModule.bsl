#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Method returns all EDI profile for taxpayer companies
Function AllEDIProfiles() Export
	
	Query = New Query("
	|SELECT ALLOWED
	|	EDIProfiles.Ref AS EDIProfile
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|WHERE
	|	EDIProfiles.UseEInvoice");
	
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("EDIProfile");
	
EndFunction

Function GetProvider(Company, EDocumentType) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIProfilesDocumentsForExchange.SourceID AS SourceID
	|INTO TT_DocumentType
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|		INNER JOIN Catalog.EDIProfiles.DocumentsForExchange AS EDIProfilesDocumentsForExchange
	|		ON (EDIProfilesDocumentsForExchange.Ref = EDIProfiles.Ref)
	|			AND (EDIProfilesDocumentsForExchange.EDocumentType = &EDocumentType)
	|WHERE
	|	NOT EDIProfiles.DeletionMark
	|	AND &ConditionCompany
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EDIProfilesHosts.Provider AS Provider
	|FROM
	|	TT_DocumentType AS TT_DocumentType
	|		INNER JOIN Catalog.EDIProfiles.Hosts AS EDIProfilesHosts
	|		ON TT_DocumentType.SourceID = EDIProfilesHosts.LineID";
	
	If ValueIsFilled(Company) Then
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "EDIProfiles.Company = &Company");
		Query.SetParameter("Company", Company);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "TRUE");
	EndIf;
	
	Query.SetParameter("EDocumentType", EDocumentType);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.Provider;
	EndIf;
	
	Return Enums.EDIProviders.EmptyRef();
	
EndFunction

Function GetProviderByDocumentType(Company, DocumentType = Undefined, EDocumentType = Undefined) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIProfilesDocumentsForExchange.SourceID AS SourceID
	|INTO TT_DocumentType
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|		INNER JOIN Catalog.EDIProfiles.DocumentsForExchange AS EDIProfilesDocumentsForExchange
	|		ON (EDIProfilesDocumentsForExchange.Ref = EDIProfiles.Ref)
	|			AND (&ConditionDocumentType)
	|			AND (&ConditionEDocumentType)
	|WHERE
	|	NOT EDIProfiles.DeletionMark
	|	AND &ConditionCompany
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	EDIProfilesHosts.Ref AS EDIProfile
	|FROM
	|	TT_DocumentType AS TT_DocumentType
	|		INNER JOIN Catalog.EDIProfiles.Hosts AS EDIProfilesHosts
	|		ON TT_DocumentType.SourceID = EDIProfilesHosts.LineID";
	
	If ValueIsFilled(Company) Then
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "EDIProfiles.Company = &Company");
		Query.SetParameter("Company", Company);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "TRUE");
	EndIf;
	
	If ValueIsFilled(EDocumentType) Then
		Query.Text = StrReplace(Query.Text, "&ConditionEDocumentType", "EDIProfilesDocumentsForExchange.EDocumentType = &EDocumentType");
		Query.SetParameter("EDocumentType", EDocumentType);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionEDocumentType", "TRUE");
	EndIf;
	
	If ValueIsFilled(DocumentType) Then
		Query.Text = StrReplace(Query.Text, "&ConditionDocumentType", "EDIProfilesDocumentsForExchange.DocumentType = &DocumentType");
		Query.SetParameter("DocumentType", DocumentType);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionDocumentType", "TRUE");
	EndIf;
	
	Query.SetParameter("DocumentType", DocumentType);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return Selection.EDIProfile;
	EndIf;
	
	Return Catalogs.EDIProfiles.EmptyRef();
	
EndFunction

Function GetEDIProfile(Company) Export
	
	Query = New Query(
	"SELECT ALLOWED
	|	EDIProfiles.Ref AS Ref,
	|	EDIProfiles.Code AS Code,
	|	EDIProfiles.Description AS Description,
	|	EDIProfiles.Company AS Company,
	|	EDIProfiles.SenderTagEInvoice AS SenderTagEInvoice,
	|	EDIProfiles.UseEInvoice AS UseEInvoice,
	|	EDIProfiles.EInvoiceStartDate AS EInvoiceStartDate,
	|	EDIProfiles.EDocumentScenario AS EDocumentScenario
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|WHERE
	|	EDIProfiles.Company = &Company
	|	AND NOT EDIProfiles.DeletionMark");
	
	Query.SetParameter("Company", Company);
	
	Result = LoginDataStructure();
	Result.Insert("Ref", Catalogs.EDIProfiles.EmptyRef());
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		FillPropertyValues(Result, QueryResult.Unload()[0]);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function LoginDataStructure()
	
	Result = New Structure;
	Result.Insert("UserName", "");
	Result.Insert("Password", "");
	Result.Insert("Company", "");
	Result.Insert("DocumentType", "");
	Result.Insert("XSLT", Null);
	Result.Insert("URL", "");
	Result.Insert("Host", "");
	Result.Insert("UseTest", False);
	Result.Insert("UseEInvoice", False);
	Result.Insert("EInvoiceStartDate");
	Result.Insert("EDocumentScenario", Enums.EDocumentScenario.EmptyRef());
	Result.Insert("SenderTagEInvoice", "");
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf