
#Region Public

Function EDIParameters() Export
	
	ParametersOnCreateAtServer = New Structure("
		|Form,
		|Ref,
		|StateDecoration,
		|StateGroup,
		|ResponseStatusDecoration,
		|ResponseStatusGroup");
	
	Return ParametersOnCreateAtServer;
	
EndFunction

Procedure OnCreateAtServer_DocumentForm(Parameters) Export
	
	Parameters.StateGroup.Visible = False;
	
	If ValueIsFilled(Parameters.Ref) Then
		
		EDIProfile = EDIProfileForDocument(Parameters.Ref);
		If EDIProfile.UsingEDI And ValueIsFilled(EDIProfile.ProfileRef) Then
			EDIState = GetEDIState(Parameters.Ref);
			Parameters.Insert("EDIState", EDIState);
			FillEDIState(Parameters);
		EndIf;
		
		Parameters.StateGroup.Visible = EDIProfile.UsingEDI;
		
	EndIf;
	
EndProcedure

Procedure AfterWriteAtServer_DocumentForm(DocumentObject, Parameters) Export
	
	EDIProfile = EDIProfileForDocument(Parameters.Ref);
	
	If EDIProfile.UsingEDI Then
		
		WriteEDIState(Parameters.Ref, EDIProfile);
		
		EDIState = GetEDIState(Parameters.Ref);
		Parameters.Insert("EDIState", EDIState);
		FillEDIState(Parameters);
		
		Parameters.StateGroup.Visible = True;
		
	Else
		Parameters.StateGroup.Visible = False;
	EndIf;
	
EndProcedure

Procedure CheckConnection(Company, EDIProvider, HasErrors) Export
	
	If EDIProvider = Enums.EDIProviders.EDM Then
		
		EDMServer.Login(Company, HasErrors);
		
	EndIf;
	
EndProcedure

Procedure GetInvoiceStatus(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteGetInvoiceStatus(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure CreateDocument(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteCreateDocument(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure SendDocument(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteSendDocument(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);

EndProcedure

Procedure SendEMail(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteSendEMail(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure PrintDocument(DocumentArray, DecodedString, HasError) Export
	
	If DocumentArray.Count() > 0 Then
		
		Document = DocumentArray[0];
		ResultStructure = ResultStructure();
		
		If DocumentCreated(Document) Then
			
			EDIProfile = EDIProfileForDocument(DocumentArray[0]);
			
			Try
				
				If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
					
					DocumentAttributes = UBLServer.AttributesForLoadingInvoice(DocumentArray[0], False, ResultStructure);
					If DocumentAttributes.IsEInvoice Then
						EDocumentType = Enums.EDocumentType.EInvoice;
					Else
						EDocumentType = Enums.EDocumentType.EArchive;
					EndIf;
					
				EndIf;
				
				If ResultStructure.ErrorsToShow Then
				
					HasError = True;
					ErrorText = ?(ResultStructure.ListOfErrorsToShow.Count() > 0,
						ResultStructure.ListOfErrorsToShow[0], ErrorDescription());
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Failed to print:
						|%1'; 
						|tr = 'Yazdırma başarısız:
						|%1'", CommonClientServer.DefaultLanguageCode()),
						ErrorText);
					WriteLogEvent(
						NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						,
						,
						ErrorDescription);
				
				EndIf;
			
			Except
				
				HasError = True;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Failed to print:
					|%1'; 
					|tr = 'Yazdırma başarısız:
					|%1'", CommonClientServer.DefaultLanguageCode()),
					ErrorDescription());
				WriteLogEvent(
					NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					ErrorDescription);
				
			EndTry;
			
			If Not HasError Then
				
				ConnectionData = ConnectionData("", DocumentAttributes.Company, EDocumentType, EDIProfile.Provider, "Print", Document);
				DocumentAttributes.Insert("XSLT", ConnectionData.XSLT);
				
				UBL = GetEDIUUIDsUBLData(EDocumentType, Document).UBL;
				
				If UBL <> Undefined Then
					
					Base64String = Base64Value(UBL);
					DocumentUBL = GetStringFromBinaryData(Base64String);
					XMLReader = New XMLReader;
					
					XMLReader.SetString(DocumentUBL);
					XdtoTypeSchema = XDTOFactory.Type("urn:oasis:names:specification:ubl:schema:xsd:Invoice-2", "InvoiceType");
					UBLXdto = XDTOFactory.ReadXML(XMLReader, XdtoTypeSchema);
					
					AdditionalDocumentReferences = UBLXDTO.AdditionalDocumentReference;
					If TypeOf(AdditionalDocumentReferences) = Type("XDTODataObject") Then
						XSLTBase64 = AdditionalDocumentReferences.Attachment.EmbeddedDocumentBinaryObject.Sequence().GetText(0);
					Else
						
						For Each Line In AdditionalDocumentReferences Do
							If Line.Properties().Get("Attachment") <> Undefined Then
								If Line.DocumentType = "XSLT" Then
									XSLTBase64 = Line.Attachment.EmbeddedDocumentBinaryObject.Sequence().GetText(0);
								EndIf;
							EndIf;
						EndDo;
						
					EndIf;
				Else
					
					DocumentUBL = UBLServer.GenerateUBL(DocumentAttributes);
					XSLTBase64 = ConnectionData.XSLT;
					
				EndIf;
				
				Try
					
					XMLSource  = New COMObject("MSXML2.DOMDocument.6.0");
					XSLTSource = New COMObject("MSXML2.DOMDocument.6.0");
					
					XMLSource.async = False;
					XMLSource.LoadXML(DocumentUBL);
					XSLTSource.async = False;
					
					TmpFile = GetTempFileName();
					X64Data = Base64Value(XSLTBase64);
					X64Data.Write(TmpFile);
					
					TxReader = New TextReader(TmpFile, TextEncoding.UTF8);
					XSLT = TxReader.Read();
					TxReader.Close();
					DeleteFiles(TmpFile);
					
					XSLTSource.LoadXML(XSLT);
					DecodedString = XMLSource.transformNode(XSLTSource);
					
				Except
					
					HasError = True;
					If XSLTBase64 = Undefined Or XSLTBase64 = Null Then
						ErrorText = NStr("en = 'XSLT file not found. Please upload XSLT file and try again.'; tr = 'XSLT dosyası bulunamadı. Lütfen, XSLT dosyası yükleyip tekrar deneyin.'");
					Else
						ErrorText = ErrorDescription();
					EndIf;
					
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Failed to print:
						|%1'; 
						|tr = 'Yazdırma başarısız:
						|%1'", CommonClientServer.DefaultLanguageCode()),
						ErrorText);
					WriteLogEvent(
						NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
						EventLogLevel.Error,
						,
						,
						ErrorDescription);
					
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteEDocument(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteDeleteEDocument(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure CancelEDocument(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteCancelEDocument(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Function DownloadDocument(DocumentArray, Path) Export
	
	If DocumentArray.Count() > 0 Then
		
		Result = New Structure("UBL, UUID, Error, Encoded");
		
		For Each Document In DocumentArray Do
			
			If DocumentCreated(Document) Then
				
				EDIProfile = EDIProfileForDocument(Document);
				
				If DocumentSent(Document) Then
					
					UBLDataStr = GetEDIUUIDsUBLData(EDIProfile.EDocumentType, Document);
					
					Try
						
						If UBLDataStr.UBL <> Undefined Then
							
							Result.UBL = UBLDataStr.UBL;
							Result.UUID = UBLDataStr.UUID;
							Result.Error = False;
							Result.Encoded = True;
							
						EndIf;
						
					Except
						Result.Error = True;
					EndTry;
					
				Else
					
					If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
						
						DocumentAttributes = UBLServer.AttributesForLoadingInvoice(DocumentArray[0], False);
						If DocumentAttributes.IsEInvoice Then
							EDocumentType = Enums.EDocumentType.EInvoice;
						Else
							EDocumentType = Enums.EDocumentType.EArchive;
						EndIf;
						
					EndIf;
					
					ConnectionData = ConnectionData("", DocumentAttributes.Company, EDocumentType, EDIProfile.Provider, "Print", Document);
					DocumentAttributes.Insert("XSLT", ConnectionData.XSLT);
					DocumentUBL = UBLServer.GenerateUBL(DocumentAttributes);
					
					Result.UBL = DocumentUBL;
					Result.UUID = DocumentAttributes.DocumentUUID;
					Result.Error = False;
					Result.Encoded = False;
					
				EndIf;
				
			Else
				
				Result.Error = True;
				ErrorText = NStr("en = 'Before downloading to your computer, make sure to create the electronic document.'; tr = 'Bilgisayarınıza indirmeden önce elektronik belgeyi oluşturun.'");
				CommonClientServer.MessageToUser(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetEDIState(Ref) Export
	
	Result = New Structure("StatusRef, Status, StatusDescription, SendStatusResponse");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDocumentsStatusesSliceLast.Provider AS Provider,
	|	EDocumentsStatusesSliceLast.Status AS Status,
	|	EDocumentsStatusesSliceLast.StatusDescription AS StatusDescription,
	|	EDocumentsStatusesSliceLast.SendStatusResponse AS SendStatusResponse
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(, ElectronicDocument = &ElectronicDocument) AS EDocumentsStatusesSliceLast";
	
	Query.SetParameter("ElectronicDocument", Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		ResultTemplate = "%1: %2";
		
		If ValueIsFilled(SelectionDetailRecords.Status) Then
			
			Result.StatusRef = SelectionDetailRecords.Status;
			Result.Status = StringFunctionsClientServer.SubstituteParametersToString(
				ResultTemplate,
				SelectionDetailRecords.Provider,
				SelectionDetailRecords.Status);
			Result.StatusDescription = SelectionDetailRecords.StatusDescription;
			Result.SendStatusResponse = SelectionDetailRecords.SendStatusResponse;
			
		Else
			Result.StatusRef = Catalogs.EDocumentStatuses.EmptyRef();
			Result.Status = StringFunctionsClientServer.SubstituteParametersToString(
				ResultTemplate,
				SelectionDetailRecords.Provider,
				NStr("en = 'ready for exchange'; tr = 'değişim için hazır'"));
			Result.StatusDescription = "";
			
		EndIf;
		
	Else
		
		Result.Status = NStr("en = 'not ready for exchange'; tr = 'değişim için hazır değil'");
		Result.StatusDescription = NStr("en = 'You can submit document after reposting it.'; tr = 'Belgeyi yeniden yayınladıktan sonra gönderebilirsiniz.'");
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetDocumentID(Document) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDIUUIDs.ID AS DocumentID
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|WHERE
	|	EDIUUIDs.ElectronicDocument = &ElectronicDocument";
	
	Query.SetParameter("ElectronicDocument", Document);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		Return SelectionDetailRecords.DocumentID;
		
	EndIf;
	
	Return "";
	
EndFunction

Function DocumentSent(DocumentRef) Export
	
	Result = False;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	EDIStatuses.Status AS Status
		|FROM
		|	InformationRegister.EDocumentsStatuses.SliceLast(, ElectronicDocument = &DocumentRef) AS EDIStatuses
		|		INNER JOIN Catalog.EDocumentStatuses AS EDocumentStatuses
		|		ON EDIStatuses.Status = EDocumentStatuses.Ref
		|WHERE
		|	NOT EDocumentStatuses.IsRejected";
		
		Query.SetParameter("DocumentRef", DocumentRef);
		
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		If Selection.Next() Then
			Result = ValueIsFilled(Selection.Status);
		EndIf;
	
	Return Result;
	
EndFunction

Function CounterpartyInfoToCheck(Counterparty) Export
	
	Result = New Structure;
	
	Attributes = Common.ObjectAttributesValues(Counterparty, "TIN, IsIndividual, Description, TaxOffice");
	
	Result.Insert("CounterpartyTIN", Attributes.TIN);
	Result.Insert("CounterpartyEmail",
		ContactsManager.ObjectContactInformation(Counterparty, ContactsManager.ContactInformationKindByName("CounterpartyEmail")));
	Result.Insert("CounterpartyPostalAddress",
		ContactsManager.ObjectContactInformation(Counterparty, ContactsManager.ContactInformationKindByName("CounterpartyLegalAddress")));
	Result.Insert("IsIndividual", Attributes.IsIndividual);
	Result.Insert("NameParts", StrSplit(Attributes.Description, " "));
	Result.Insert("TaxOffice", Attributes.TaxOffice);
	
	Return Result;

EndFunction

Procedure ImportTaxpayerList() Export
	
	ImportEInvoiceTaxpayerList();
	
EndProcedure

Function ConnectionData(SOAPAction, Company, EDocumentType, Provider, Operation = Undefined, Document = Undefined) Export
	
	DocumentType = Undefined;
	
	If Document <> Undefined Then
		DocumentType = Common.MetadataObjectID(TypeOf(Document));
	EndIf;
	
	LoginData = GetLoginData(Company, EDocumentType, Provider, DocumentType);
	
	ConnectionStructure = New Structure;
	ConnectionStructure.Insert("Error");
	ConnectionStructure.Insert("LoginData", LoginData);
	
	If Not IsBlankString(LoginData.URL)
		And Not IsBlankString(LoginData.UserName)
		And Not IsBlankString(LoginData.Password) Then
		
		If Operation = Undefined Then
			
			If SOAPAction = "wsLogin" Then
				WSDL = StrReplace(LoginData.URL, "connectorService", "userService");
				LoginData.Host = StrReplace(LoginData.Host, "connectorService", "userService");
			Else
				WSDL = LoginData.URL;
			EndIf;
			
			SSL = New OpenSSLSecureConnection();
			
			Try
				
				Headers = New Map;
				Headers.Insert("Content-Type", "text/xml;charset=UTF-8");
				Headers.Insert("SOAPAction", SOAPAction);
				Headers.Insert("Host", StrSplit(LoginData.Host, "/").Get(0));
				
				WSDefinitions = New WSDefinitions(WSDL,,,, 7, SSL);
				EDIXDTOFactory = WSDefinitions.XDTOFactory;
				HTTPConnection = New HTTPConnection(LoginData.Host,,,,, 60, SSL);
				
				ConnectionStructure.Insert("HTTPConnection", HTTPConnection);
				ConnectionStructure.Insert("Headers", Headers);
				ConnectionStructure.Insert("EDIXDTOFactory", EDIXDTOFactory);
				
			Except
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The web-site %1 isn''t available.
						|Please, check your internet settings/connections and try again'; 
						|tr = '%1 web sitesine ulaşılamıyor.
						|Lütfen, internet ayarlarınızı/bağlantınızı kontrol edip tekrar deneyin'"), WSDL);
				ConnectionStructure.Error = ErrorText;
				CommonClientServer.MessageToUser(ErrorText);
				
			EndTry;
			
		EndIf;
		
	Else
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The EDI Profile of %1 has missing data.
				|Please, check your credentials and try again'; 
				|tr = '%1 EDI profilinde eksik veriler var.
				|Lütfen, kimlik bilgilerini kontrol edip tekrar deneyin.'"), Company);
		ConnectionStructure.Error = ErrorText;
		
	EndIf;
	
	ConnectionStructure.Insert("UserName", LoginData.UserName);
	ConnectionStructure.Insert("Password", LoginData.Password);
	ConnectionStructure.Insert("Provider", Provider);
	ConnectionStructure.Insert("XSLT", LoginData.XSLT);
	ConnectionStructure.Insert("EDocumentType", EDocumentType);
	
	Return ConnectionStructure;
	
EndFunction

Function IsTaxpayer(TIN, EDocumentType, Identifier = Undefined) Export
	
	StrTaxpayerList = New Structure;
	StrTaxpayerList.Insert("Result", False);
	StrTaxpayerList.Insert("Identifier");
	StrTaxpayerList.Insert("Title");
	StrTaxpayerList.Insert("RegisterDate");
	StrTaxpayerList.Insert("EDocumentType");
	StrTaxpayerList.Insert("IsPublicEstablishment");
	
	Query = New Query;
	Query.SetParameter("TIN", TIN);
	Query.SetParameter("EDocumentType", EDocumentType);
	
	Query.Text = 
	"SELECT
	|	TaxpayerList.TIN AS TIN,
	|	TaxpayerList.EDocumentType AS EDocumentType,
	|	TaxpayerList.Identifier AS Identifier,
	|	TaxpayerList.Title AS Title,
	|	TaxpayerList.RegisterDate AS RegisterDate,
	|	TaxpayerList.IsPublicEstablishment AS IsPublicEstablishment,
	|	TRUE AS Result
	|FROM
	|	InformationRegister.TaxpayerList AS TaxpayerList
	|WHERE
	|	TaxpayerList.TIN = &TIN
	|	AND TaxpayerList.EDocumentType = &EDocumentType";
	
	If Identifier <> Undefined Then
		
		Query.Text = Query.Text + "
			|	AND TaxpayerList.Identifier = &Identifier";
		Query.SetParameter("Identifier", Identifier);
		
	EndIf;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			FillPropertyValues(StrTaxpayerList, Selection);
		EndDo;
		
	EndIf;
	
	Return StrTaxpayerList;
	
EndFunction

Function UpdateStatusCatalog(Status, Provider, StatusStructure = Undefined) Export
	
	ResultStructure = New Structure("Status, StatusDescription");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDocumentStatuses.Ref AS Ref
	|FROM
	|	Catalog.EDocumentStatuses AS EDocumentStatuses
	|WHERE
	|	EDocumentStatuses.Description = &Description
	|	AND EDocumentStatuses.Parent = &Provider";
	
	Query.SetParameter("Description", Status);
	Query.SetParameter("Provider", Provider);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		EDocumentStatus = SelectionDetailRecords.Ref.GetObject();
	ElsIf Not IsBlankString(Status) Then
		
		EDocumentStatus = Catalogs.EDocumentStatuses.CreateItem();
		EDocumentStatus.Parent = Provider;
		EDocumentStatus.Description = Status;
		EDocumentStatus.IsFinal = StatusStructure.Final;
		EDocumentStatus.IsRejected = StatusStructure.ResponseStatus = 1;
		EDocumentStatus.Write();
		
	EndIf;
	
	ResultStructure.Status = EDocumentStatus.Ref;
	ResultStructure.StatusDescription = Status;
	
	Return ResultStructure;
	
EndFunction

Procedure ExecuteGetInvoiceStatusScheduledJob() Export
	
	ResultStructure = ResultStructure();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDocumentsStatusesSliceLast.ElectronicDocument AS Document
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|		INNER JOIN InformationRegister.EDocumentsStatuses.SliceLast(, ) AS EDocumentsStatusesSliceLast
	|		ON (EDocumentsStatusesSliceLast.ElectronicDocument.Ref = EDIUUIDs.ElectronicDocument.Ref)
	|		INNER JOIN Catalog.EDocumentStatuses AS EDocumentStatuses
	|		ON (EDocumentsStatusesSliceLast.Status = EDocumentStatuses.Ref)
	|			AND (NOT EDocumentStatuses.IsFinal)
	|WHERE
	|	EDIUUIDs.Date >= &Last15Day";
	
	Query.SetParameter("Last15Day", (CurrentSessionDate() - 1296000));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DocumentsArray = CommonClientServer.ArrayOfValues(Selection.Document);
		ExecuteGetInvoiceStatus(DocumentsArray, ResultStructure);
	EndDo;
	
EndProcedure

Function StatusDataStructure() Export
	
	StatusData = New Structure;
	StatusData.Insert("Status");
	StatusData.Insert("StatusDescription");
	StatusData.Insert("Date");
	StatusData.Insert("ResponseStatus");
	StatusData.Insert("ResponseCode");
	StatusData.Insert("ResponseDescription");
	StatusData.Insert("SendStatus");
	StatusData.Insert("SendStatusResponse");
	StatusData.Insert("SendResponseCode");
	StatusData.Insert("Final", False);
	StatusData.Insert("ErrorText");
	
	Return StatusData;
	
EndFunction

Function DocumentCreated(ElectronicDocument) Export
	
	If Not ValueIsFilled(ElectronicDocument) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIUUIDs.ElectronicDocument AS ElectronicDocument
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|WHERE
	|	EDIUUIDs.ElectronicDocument = &ElectronicDocument";
	
	Query.SetParameter("ElectronicDocument", ElectronicDocument);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	Return Selection.Next();
	
EndFunction

Function DocumentCanceled(ElectronicDocument) Export
	
	If Not ValueIsFilled(ElectronicDocument) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDIUUIDs.IsCancelled AS IsCancelled
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|WHERE
	|	EDIUUIDs.ElectronicDocument = &ElectronicDocument";
	
	Query.SetParameter("ElectronicDocument", ElectronicDocument);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.IsCancelled;
		
	Else
		Return False;
	EndIf;
	
EndFunction

Function DocumentRejected(ElectronicDocument) Export
	
	If Not ValueIsFilled(ElectronicDocument) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDocumentsStatusesSliceLast.ResponseStatus AS ResponseStatus
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(, ) AS EDocumentsStatusesSliceLast
	|WHERE
	|	EDocumentsStatusesSliceLast.ElectronicDocument = &ElectronicDocument";
	
	Query.SetParameter("ElectronicDocument", ElectronicDocument);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.ResponseStatus;
		
	Else
		Return 0;
	EndIf;
	
EndFunction

Procedure CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError) Export
	
	Provider = Catalogs.EDIProfiles.GetProvider(Company, Enums.EDocumentType.EInvoice);
	
	If ValueIsFilled(Provider) Then
		
		If Provider = Enums.EDIProviders.EDM Then
			EDMServer.CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError);
		EndIf;
		
	EndIf;
	
EndProcedure

Function LoginDataStructure() Export

	Result = New Structure;
	Result.Insert("UserName", "");
	Result.Insert("Password", "");
	Result.Insert("Company", "");
	Result.Insert("DocumentType", "");
	Result.Insert("XSLT", Null);
	Result.Insert("URL", "");
	Result.Insert("Host", "");
	Result.Insert("UseEInvoice", False);
	Result.Insert("EInvoiceStartDate");
	Result.Insert("EDocumentScenario", Enums.EDocumentScenario.EmptyRef());
	Result.Insert("SenderTagEInvoice", "");
	
	Return Result;

EndFunction

Function WriteEventLog(ErrorTitle, ErrorText) Export
	
	ErrorTemplate = "%1
		|%2";
	
	ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
		ErrorTemplate,
		ErrorTitle,
		ErrorText);
		
	WriteLogEvent(
		NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Error,
		,
		,
		ErrorDescription);
	
	Return ErrorText;
	
EndFunction

Function AddressNotValidErrorText(AddressType) Export
	
	If AddressType = 0 Then
		AddressTypeString = NStr("en = 'Company legal address is not valid. Please check legal address and try again.'; tr = 'İş yerinin yasal adresi geçerli değil. Lütfen, yasal adresi kontrol edip tekrar deneyin.'");
	ElsIf AddressType = 1 Then
		AddressTypeString = NStr("en = 'Counterparty legal address is not valid. Please check legal address and try again.'; tr = 'Cari hesabın yasal adresi geçerli değil. Lütfen, yasal adresi kontrol edip tekrar deneyin.'");
	ElsIf AddressType = 2 Then
		AddressTypeString = NStr("en = 'Warehouse actual address is not valid. Please check Warehouse actual address and try again.'; tr = 'Ambarın fiziki adresi geçerli değil. Lütfen, Ambarın fiziki adresini kontrol edip tekrar deneyin.'");
	Else
		AddressTypeString = NStr("en = 'Address is not valid. Please check address and try again.'; tr = 'Adres geçerli değil. Lütfen, adresi kontrol edip tekrar deneyin.'");
	EndIf;
	
	Return AddressTypeString;
	
EndFunction

Function TINNotValidErrorText(ErrorIndex) Export
	
	If ErrorIndex = 0 Then
		ErrorString = NStr("en = 'Company TIN is required. Specify it in the company""'""s card.'");
	ElsIf ErrorIndex = 1 Then
		ErrorString = NStr("en = 'Counterparty TIN is required. Specify it in the counterparty""'""s card.'");
	ElsIf ErrorIndex = 2 Then
		ErrorString = NStr("en = 'Conterparty TIN must contain 11 digits. Please enter correctly the TIN.'; tr = 'Cari hesabın VKN''si 11 basamaklı olmalıdır. Lütfen VKN''yi doğru girin.'");
	Else
		ErrorString = NStr("en = 'TIN is required. Please check the TIN.'; tr = 'VKN gerekli. Lütfen VKN''yi kontrol edin.'");
	EndIf;
	
	ErrorString = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot perform the action. %1 Then, try again.'; tr = 'İşlem gerçekleştirilemiyor. %1 Ardından tekrar deneyin.'"),
		ErrorString);
	
	Return ErrorString;
	
EndFunction

#EndRegion

#Region Private

Function GetLoginData(Company, EDocumentType, Provider, DocumentType)
	
	Result = LoginDataStructure();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	EDIProfiles.Company AS Company,
	|	EDIProfilesDocumentsForExchange.DocumentType AS DocumentType,
	|	EDIProfilesDocumentsForExchange.EDocumentType AS EDocumentType,
	|	EDIProfilesHosts.Password AS Password,
	|	EDIProfilesHosts.UserName AS UserName,
	|	EDIProfilesHosts.URL AS URL,
	|	EDIProfiles.UseEInvoice AS UseEInvoice,
	|	EDIProfilesHosts.Provider AS Provider,
	|	XSLTRef.XSLT AS XSLT,
	|	EDIProfiles.EInvoiceStartDate AS EInvoiceStartDate,
	|	EDIProfiles.EDocumentScenario AS EDocumentScenario
	|FROM
	|	Catalog.EDIProfiles AS EDIProfiles
	|		INNER JOIN Catalog.EDIProfiles.Hosts AS EDIProfilesHosts
	|			INNER JOIN Catalog.EDIProfiles.DocumentsForExchange AS EDIProfilesDocumentsForExchange
	|				LEFT JOIN Catalog.XSLT AS XSLTRef
	|				ON EDIProfilesDocumentsForExchange.XSLT = XSLTRef.Ref
	|			ON EDIProfilesHosts.LineID = EDIProfilesDocumentsForExchange.SourceID
	|				AND (EDIProfilesDocumentsForExchange.EDocumentType = &EDocumentType)
	|		ON (EDIProfilesHosts.Ref = EDIProfiles.Ref)
	|			AND (EDIProfilesHosts.Provider = &Provider)
	|WHERE
	|	&ConditionCompany
	|	AND NOT EDIProfiles.DeletionMark
	|	AND &ConditionDocumentType";
	
	If ValueIsFilled(Company) Then
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "EDIProfiles.Company = &Company");
		Query.SetParameter("Company", Company);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionCompany", "TRUE");
	EndIf;
	
	If DocumentType <> Undefined Then
		Query.Text = StrReplace(Query.Text, "&ConditionDocumentType", "EDIProfilesDocumentsForExchange.DocumentType = &DocumentType");
		Query.SetParameter("DocumentType", DocumentType);
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionDocumentType", "TRUE");
	EndIf;
	
	Query.SetParameter("EDocumentType", EDocumentType);
	Query.SetParameter("Provider", Provider);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		FillPropertyValues(Result, Selection);
		Result.Host = HostFromURL(Selection.URL);
		Result.XSLT = ?(ValueIsFilled(Selection.XSLT), Selection.XSLT.Get(), Null);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function HostFromURL(WSDL)
	
	Host = StrReplace(WSDL, "?wsdl", "");
	Host = StrReplace(Host, "https://", "");
	Host = StrReplace(Host, "http://", "");
	
	Return Host;

EndFunction

Procedure ExecuteCreateDocument(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		For Each Document In DocumentsArray Do
			
			If Not Document.Posted Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Please post document %1.'; tr = 'Lütfen belgeyi kaydedin %1.'"),
					Document);
				ResultStructure.ErrorsToShow = True;
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				Continue;
			EndIf;
			
			If Not DocumentCreated(Document) Then
				
				Try
					
					If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
						
						DocumentAttributes = UBLServer.AttributesForLoadingInvoice(Document, True, ResultStructure);
						EDocumentType = ?(DocumentAttributes.IsEInvoice,
							Enums.EDocumentType.EInvoice,
							Enums.EDocumentType.EArchive);
						
					EndIf;
					
					If Not ResultStructure.ErrorsToShow Then
						
						Record = InformationRegisters.EDIUUIDs.CreateRecordManager();
						Record.ElectronicDocument = Document;
						Record.UUID = DocumentAttributes.DocumentUUID;
						Record.ID = DocumentAttributes.DocumentID;
						Record.EDocumentType = EDocumentType;
						Record.Write();
						
						DocObject = Document.GetObject();
						DocObject.EDocumentNumber =DocumentAttributes.DocumentID;
						DocObject.Write(DocumentWriteMode.Posting);
						
						If DocumentAttributes.IsEmpty Then
							
							WarningText = NStr("en = 'Fill in the Products tab first. Then try again.'; tr = 'Ürünler sekmesini doldurup tekrar deneyin.'");
							ResultStructure.WarningsToShow = True;
							ResultStructure.ListOfErrorsToShow.Add(WarningText);
							
						EndIf;
						
					EndIf;
					
				Except
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Failed to create document
							|%1'; 
							|tr = 'Belge oluşturulamadı
							|%1'"),
						ErrorDescription());
					ResultStructure.ErrorsToShow = True;
					ResultStructure.ListOfErrorsToShow.Add(ErrorText);
					
				EndTry;
				
			Else
				
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Document %1 has already been created. You can submit document.'; tr = '%1 belgesi zaten oluşturulmuş. Belgeyi gönderebilirsiniz.'"),
					Document);
				ResultStructure.ErrorsToShow = True;
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteGetInvoiceStatus(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		If TypeOf(DocumentsArray[0]) = Type("Structure") Then
			EDIProfile = New Structure("Provider");
			EDIProfile.Provider = Catalogs.EDIProfiles.GetProvider(Catalogs.Companies.MainCompany,
				DocumentsArray[0].EDocumentType);
		Else
			EDIProfile = EDIProfileForDocument(DocumentsArray[0]);
		EndIf;
		
		If EDIProfile.Provider = Enums.EDIProviders.EDM Then
			EDMServer.GetInvoiceStatus(DocumentsArray, ResultStructure);
		EndIf;
		
	EndIf;

EndProcedure

Procedure ExecuteSendDocument(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		For Each Document In DocumentsArray Do
			
			If DocumentCreated(Document) Then
				
				EDIProfile = EDIProfileForDocument(Document);
				
				If ValueIsFilled(EDIProfile.Provider) Then
					
					If EDIProfile.Provider = Enums.EDIProviders.EDM Then
						
						EDMServer.SendDocument(Document, ResultStructure);
						
					EndIf;
					
				Else
					
					ResultStructure.ErrorsToShow = True;
					ErrorMessage = NStr("en = 'Please fill EDI Profile for %1'; tr = 'Lütfen %1 için EDI Profilini doldurun'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, Catalogs.Companies.MainCompany);
					ResultStructure.ListOfErrorsToShow.Add(ErrorText);
					
				EndIf;
				
			Else
				
				ResultStructure.ErrorsToShow = True;
				ErrorText = NStr("en = 'Please create e-document before you submit.'; tr = 'Lütfen göndermeden önce e-belge oluşturun.'");
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteSendEMail(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		For Each Document In DocumentsArray Do
			
			If DocumentCreated(Document) Then
				
				EDIProfile = EDIProfileForDocument(Document);
				
				If ValueIsFilled(EDIProfile.Provider) Then
					
					If EDIProfile.Provider = Enums.EDIProviders.EDM Then
						
						ResultStructure.ErrorsToShow = True;
						ErrorMessage = NStr("en = 'There is not e-mail service for %1'; tr = '%1 için e-posta servisi yok'");
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, EDIProfile.Provider);
						ResultStructure.ListOfErrorsToShow.Add(ErrorText);
						
					EndIf;
					
				Else
					
					ResultStructure.ErrorsToShow = True;
					ErrorMessage = NStr("en = 'Please fill EDI Profile for %1'; tr = 'Lütfen %1 için EDI Profilini doldurun'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, Catalogs.Companies.MainCompany);
					ResultStructure.ListOfErrorsToShow.Add(ErrorText);
					
				EndIf;
				
			Else
				
				ResultStructure.ErrorsToShow = True;
				ErrorText = NStr("en = 'Please create e-document before you submit.'; tr = 'Lütfen göndermeden önce e-belge oluşturun.'");
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteDeleteEDocument(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		For Each Document In DocumentsArray Do
			
			If DocumentCreated(Document) Then
				
				If Not DocumentSent(Document) Then
					
					EDIProfile = EDIProfileForDocument(Document);
					Prefix = Left(Document.EDocumentNumber, 7);
					
					LastDocument = UBLServer.GetEndNumber(Prefix, "Structure");
					SelectedEndNumber = Number(Right(Document.EDocumentNumber, 9));
					
					If SelectedEndNumber = LastDocument.LastNumber Then
						
						Try
							Record = InformationRegisters.EDIUUIDs.CreateRecordManager();
							Record.ElectronicDocument = Document;
							Record.EDocumentType = EDIProfile.EDocumentType;
							Record.Read();
							Record.Delete();
							
							DocObject = Document.GetObject();
							DocObject.EDocumentNumber = "";
							DocObject.Write(DocumentWriteMode.UndoPosting);
							
						Except
							
							ResultStructure.ErrorsToShow = True;
							ErrorText = NStr("en = 'Unexpected error occured while deleting the document.'; tr = 'Belge silinirken hata oluştu.'");
							ResultStructure.ListOfErrorsToShow.Add(ErrorText);
							WriteLogEvent(
								NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
								EventLogLevel.Error,
								,
								,
								ErrorDescription());
								
						EndTry;
						
					Else
						
						ResultStructure.ErrorsToShow = True;
						ErrorText = NStr("en = 'To delete this document, please delete the document with number ""%1""'; tr = 'Bu belgeyi silmek için önce ""%1"" numaralı belgeyi silmelisiniz.'");
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, LastDocument.ID);
						ResultStructure.ListOfErrorsToShow.Add(ErrorText);
						
					EndIf;
					
				Else
					
					ResultStructure.ErrorsToShow = True;
					ErrorText = NStr("en = 'The document that has been sent cannot be deleted.'; tr = 'Belge gönderilmiştir, silinemez.'");
					ResultStructure.ListOfErrorsToShow.Add(ErrorText);
					
				EndIf;
				
			Else
				
				ResultStructure.ErrorsToShow = True;
				ErrorText = NStr("en = 'Please create e-document before you delete.'; tr = 'Lütfen silmeden önce e-belge oluşturun.'");
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteCancelEDocument(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		For Each Document In DocumentsArray Do
			
			If DocumentCreated(Document) Then
				
				EDIProfile = EDIProfileForDocument(Document);
				
				If DocumentSent(Document) Then
					
					If EDIProfile.EDocumentType = Enums.EDocumentType.EArchive Then
						
						If Not DocumentCanceled(Document) Then
							
							If EDIProfile.Provider = Enums.EDIProviders.EDM Then
								EDMServer.CancelDocument(Document, EDIProfile.EDocumentType, ResultStructure);
							EndIf;
							
							If ResultStructure.Canceled Then
								
								Record = InformationRegisters.EDIUUIDs.CreateRecordManager();
								Record.ElectronicDocument = Document;
								Record.EDocumentType = EDIProfile.EDocumentType;
								Record.Read();
								Record.CancelledDate = CurrentSessionDate();
								Record.IsCancelled = True;
								Record.Write();
								
								DocObject = Document.GetObject();
								DocObject.Write(DocumentWriteMode.UndoPosting);
								
							EndIf;
							
						Else
							
							ResultStructure.ErrorsToShow = True;
							ErrorText = NStr("en = 'The e-document has already been canceled'; tr = 'E-belge zaten iptal edildi'");
							ResultStructure.ListOfErrorsToShow.Add(ErrorText);
							
						EndIf;
						
					Else
						
						ResultStructure.ErrorsToShow = True;
						ErrorText = NStr("en = 'Only E-Archive documents can be canceled.'; tr = 'Sadece E-Arşiv faturalar iptal edilebilir.'");
						ResultStructure.ListOfErrorsToShow.Add(ErrorText);
						
					EndIf;
					
				Else
					
					ResultStructure.ErrorsToShow = True;
					ErrorText = NStr("en = 'Please submit e-document before you cancel.'; tr = 'Lütfen iptal etmeden önce e-belgeyi gönderin.'");
					ResultStructure.ListOfErrorsToShow.Add(ErrorText);
					
				EndIf;
				
			Else
				
				ResultStructure.ErrorsToShow = True;
				ErrorText = NStr("en = 'Please create e-document before you cancel.'; tr = 'Lütfen iptal etmeden önce e-belge oluşturun.'");
				ResultStructure.ListOfErrorsToShow.Add(ErrorText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure WriteEDIState(DocumentRef, EDIProfile)
	
	Provider = EDIProfile.Provider;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDocumentsStatusesSliceLast.Status AS Status
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(
	|			,
	|			Provider = &Provider
	|				AND ElectronicDocument = &DocumentRef) AS EDocumentsStatusesSliceLast";
	
	Query.SetParameter("DocumentRef", DocumentRef);
	Query.SetParameter("Provider", Provider);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		If ValueIsFilled(Provider) Then
			
			EmptyStateRecord = InformationRegisters.EDocumentsStatuses.CreateRecordManager();
			EmptyStateRecord.Period = CurrentSessionDate();
			EmptyStateRecord.ElectronicDocument = DocumentRef;
			EmptyStateRecord.Provider = Provider;
			EmptyStateRecord.Status = Catalogs.EDocumentStatuses.EmptyRef();
			EmptyStateRecord.Write();
			
		EndIf;
	EndIf;
	
EndProcedure

Function EDIProfileForDocument(DocumentRef)
	
	EDIProfile = Catalogs.EDIProfiles.EmptyRef();
	UsingEDI = False;
	
	If AccessRight("Edit", Metadata.InformationRegisters.EDocumentsStatuses) Then
		
		Company = Catalogs.Companies.MainCompany;
		DocumentType = Catalogs.MetadataObjectIDs.FindByAttribute("FullName", "Document." + DocumentRef.Metadata().Name);
		IsTaxpayer = IsTaxpayer(DocumentRef.Customer.TIN, Enums.EDocumentType.EInvoice);
		EDocumentType = ?(IsTaxpayer.Result, Enums.EDocumentType.EInvoice, Enums.EDocumentType.EArchive);
		Provider = Catalogs.EDIProfiles.GetProvider(Company, EDocumentType);
		EDIProfile = Catalogs.EDIProfiles.GetProviderByDocumentType(Company,
			Common.MetadataObjectID(DocumentRef.Metadata()));
		UsingEDI = (ValueIsFilled(EDIProfile.Ref) And ValueIsFilled(EDIProfile));
		
	EndIf;
	
	Str = New Structure();
	Str.Insert("UsingEDI", UsingEDI);
	Str.Insert("Provider",Provider);
	Str.Insert("EDocumentType", EDocumentType);
	Str.Insert("DocumentType", DocumentType);
	Str.Insert("ProfileRef", EDIProfile);
	
	Return Str;
	
EndFunction

Procedure FillEDIState(Parameters)
	
	// StatusDescription
	EDI_StatusDescription = "EDI_StatusDescription";
	
	// SendStatusResponse
	EDI_SendStatusResponse = "EDI_SendStatusResponse";
	
	Form = Parameters.Form;
	FormAttributeList = Form.GetAttributes();
	CreateStatusDescription = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = EDI_StatusDescription Then
			CreateStatusDescription = False;
			Break;
		EndIf;
		If Attribute.Name = EDI_SendStatusResponse Then
			CreateStatusDescription = False;
			Break;
		EndIf;
	EndDo;
	
	If CreateStatusDescription Then
		AttributesToAdd = New Array;
		String1500 = New TypeDescription("String", , New StringQualifiers(1500));
		AttributesToAdd.Add(New FormAttribute(EDI_StatusDescription, String1500));
		AttributesToAdd.Add(New FormAttribute(EDI_SendStatusResponse, String1500));
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;
	
	Ref = Parameters.Ref;
	StateDecoration = Parameters.StateDecoration;
	ResponseStatusDecoration = Parameters.ResponseStatusDecoration;
	
	EDIState = Undefined;
	If Not Parameters.Property("EDIState", EDIState) Then
		EDIState = GetEDIState(Ref);
	EndIf;
	
	StateDecoration.Title = EDIState.Status;
	Form[EDI_StatusDescription] = EDIState.StatusDescription;
	
	ResponseStatusDecoration.Title = EDIState.SendStatusResponse;
	Form[EDI_SendStatusResponse] = EDIState.SendStatusResponse;
	
	
EndProcedure

Function ResultStructure()
	
	Result = New Structure;
	Result.Insert("ErrorsInEventLog", False);
	Result.Insert("ErrorsToShow", False);
	Result.Insert("WarningsToShow", False);
	Result.Insert("ListOfErrorsToShow", New Array);
	
	Return Result;
	
EndFunction

Procedure ImportEInvoiceTaxpayerList()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	EDIProfilesHosts.Provider AS Provider,
	|	EDIProfiles.Company AS Company
	|FROM
	|	Catalog.EDIProfiles.Hosts AS EDIProfilesHosts
	|		INNER JOIN Catalog.EDIProfiles.DocumentsForExchange AS EDIProfilesDocumentsForExchange
	|		ON EDIProfilesHosts.Ref = EDIProfilesDocumentsForExchange.Ref
	|			AND EDIProfilesHosts.LineID = EDIProfilesDocumentsForExchange.SourceID
	|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
	|		ON EDIProfilesHosts.Ref = EDIProfiles.Ref
	|WHERE
	|	EDIProfilesDocumentsForExchange.EDocumentType = &EDocumentType
	|	AND NOT EDIProfiles.DeletionMark";
	
	Query.SetParameter("EDocumentType", Enums.EDocumentType.EInvoice);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		
		If Selection.Provider = Enums.EDIProviders.EDM Then
			
			EDMServer.CheckTaxpayerList(Selection.Company, Enums.EDocumentType.EInvoice);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetEDIUUIDsUBLData(EDocumentType, ElectronicDocument)
	
	Result = New Structure("UBL, UUID");
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDIUUIDs.UBLData AS UBLData,
	|	EDIUUIDs.UUID AS UUID
	|FROM
	|	InformationRegister.EDIUUIDs AS EDIUUIDs
	|WHERE
	|	EDIUUIDs.EDocumentType = &EDocumentType
	|	AND EDIUUIDs.ElectronicDocument = &ElectronicDocument";
	
	Query.SetParameter("EDocumentType", EDocumentType);
	Query.SetParameter("ElectronicDocument", ElectronicDocument);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next()Then
		
		Try
			Result.Insert("UBL", Selection.UBLData.Get());
		Except
			Result.Insert("UBL", Undefined);
		EndTry;
		
		Result.Insert("UUID", Selection.UUID);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion