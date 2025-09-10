#Region Public

Function Login(Company, HasErrors) Export
	
	Return LoginRequest(Company, HasErrors);
	
EndFunction

Procedure SendDocument(DocumentsArray, ResultStructure) Export
	
	Provider = Enums.EDIProviders.EDM;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDocumentsStatusesSliceLast.ElectronicDocument AS ElectronicDocument,
	|	EDocumentsStatusesSliceLast.Status AS Status,
	|	EDocumentsStatusesSliceLast.Provider AS Provider,
	|	MetadataObjectIDs.Ref AS MetadataObjectID,
	|	VALUE(Catalog.Companies.MainCompany) AS Company,
	|	EDocumentStatuses.IsRejected AS IsRejected
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(
	|			,
	|			ElectronicDocument IN (&DocumentsArray)
	|				AND Provider = &Provider) AS EDocumentsStatusesSliceLast
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (VALUETYPE(EDocumentsStatusesSliceLast.ElectronicDocument) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|		LEFT JOIN Catalog.EDocumentStatuses AS EDocumentStatuses
	|		ON EDocumentsStatusesSliceLast.Status = EDocumentStatuses.Ref";
	
	Query.SetParameter("DocumentsArray", DocumentsArray);
	Query.SetParameter("Provider", Provider);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		ResultStructure.ErrorsToShow = True;
		ErrorDescription =
			NStr("en = 'To exchange document the company should have filled EDI profile. Check it before sending.'; tr = 'Belge değişimi için iş yerinin EDI profili girmesi gerekli. Gönderimden önce kontrol edin.'");
		ResultStructure.ListOfErrorsToShow.Add(ErrorDescription);
		
	Else
		
		Selection = QueryResult.Select(QueryResultIteration.ByGroups);
		
		While Selection.Next() Do
			
			If Selection.Status = Catalogs.EDocumentStatuses.EmptyRef()
				Or Selection.IsRejected Then
				
				ElectronicDocument = Selection.ElectronicDocument;
				ErrorsInDocument = False;
				
				If TypeOf(ElectronicDocument) = Type("DocumentRef.SalesInvoice") Then
					CheckSalesInvoiceIsReadyForExchange(ElectronicDocument, ErrorsInDocument, ResultStructure.ListOfErrorsToShow);
				EndIf;
				
				If Not ErrorsInDocument Then
					
					ErrorsInCounterparty = False;
					
					If TypeOf(ElectronicDocument) = Type("DocumentRef.SalesInvoice") Then
						
						Counterparty = Common.ObjectAttributeValue(ElectronicDocument, "Customer");
						EDIClientServer.CheckCounterpartyIsReadyForExchange(Counterparty,
							ErrorsInCounterparty,
							ResultStructure.ListOfErrorsToShow);
						
					EndIf;
					
					If Not ErrorsInCounterparty Then
						
						LoadingStructure = LoadEDocumentRequest(Selection.Company, Selection.ElectronicDocument, ResultStructure);
						
						If IsBlankString(LoadingStructure.ErrorText) Then
							
							NewState = InformationRegisters.EDocumentsStatuses.CreateRecordManager();
							NewState.ElectronicDocument = ElectronicDocument;
							NewState.Period = CurrentSessionDate();
							NewState.Provider = Provider;
							NewState.Status = LoadingStructure.Status;
							NewState.StatusDescription = LoadingStructure.StatusDescription;
							NewState.ResponseStatus = LoadingStructure.ResponseStatus;
							NewState.SendStatus = LoadingStructure.SendStatus;
							NewState.SendStatusResponseCode = LoadingStructure.SendResponseCode;
							NewState.SendStatusResponse = LoadingStructure.SendStatusResponse;
							NewState.Write();
							
						Else
							
							ResultStructure.ErrorsToShow = True;
							ResultStructure.ListOfErrorsToShow.Add(LoadingStructure.ErrorText);
							
						EndIf;
						
					Else
						ResultStructure.ErrorsInEventLog = True;
					EndIf;
					
				Else
					ResultStructure.ErrorsToShow = True;
				EndIf;
				
			Else
				ResultStructure.ErrorsToShow = True;
			EndIf;
			
			If Not ResultStructure.ErrorsToShow Then
				
				WarningText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Document %1 has been sent to EDI system. You can update document state via ''Refresh status''.'; tr = '%1 belgesi EDI sistemine gönderildi. Durumu yenile''ye tıklayarak belge durumunu güncelleyebilirsiniz.'"),
					Selection.ElectronicDocument);
				
				ResultStructure.WarningsToShow = True;
				ResultStructure.ListOfErrorsToShow.Add(WarningText);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CheckTaxpayerList(Company, EDocumentType) Export
	
	ConnectionData = EDIServer.ConnectionData("GetUserListRequest", Company, EDocumentType,
		Enums.EDIProviders.EDM);
		
	SessionID = LoginRequest(Company, False);
	RequestTemplate = SOAPRequestTemplate("GetUserListRequest");
	RequestHeader = SOAPRequestHeaderTemplate(SessionID);
	
	XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader);
	
	HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
	HTTPRequest.SetBodyFromString(XMLRequest);
	HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
	
	If HTTPResponse.StatusCode = 200 Then
		
		XMLReader = New XMLReader;
		XMLReader.SetString(HTTPResponse.GetBodyAsString());
		ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
		ResponseBody = ObjectResponse.Body.GetUserListResponse.Items.Items;
		
		For Each CrrData In ResponseBody Do
			
			If TypeOf(CrrData.IDENTIFIER) = Type("String") Then
				
				If CrrData.UNIT = "PK" Then
					
					IsTaxpayer = EDIServer.IsTaxpayer(CrrData.IDENTIFIER, EDocumentType);
					
					If Not IsTaxpayer.Result
						And Not IsBlankString(CrrData.TITLE) Then
						
						Record = InformationRegisters.TaxpayerList.CreateRecordManager();
						Record.Identifier = CrrData.ALIAS;
						Record.Title = CrrData.TITLE;
						Record.RegisterDate = GetDateTimeFromString(CrrData.REGISTER_TIME);
						Record.TIN = CrrData.IDENTIFIER;
						Record.EDocumentType = EDocumentType;
						
						If CrrData.TYPE = "KAMU" Then
							IsPublicEstablishment = True;
						Else
							IsPublicEstablishment = False;
						EndIf;
						
						Record.IsPublicEstablishment = IsPublicEstablishment;
						Record.Write();
						
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		Result = True;
		
	Else
		
		ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(HTTPResponse.GetBodyAsString());
		
		HasErrors = True;
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to login:
			|%1'; 
			|tr = 'Giriş başarısız:
			|%1'", CommonClientServer.DefaultLanguageCode()),
			ErrorText);
		WriteLogEvent(
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
		
	EndIf;
	
EndProcedure

Procedure GetInvoiceStatus(DocumentsArray, ResultStructure) Export
	
	Provider = Enums.EDIProviders.EDM;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EDocumentsStatusesSliceLast.ElectronicDocument AS ElectronicDocument,
	|	EDocumentsStatusesSliceLast.Status AS Status,
	|	VALUE(Catalog.Companies.MainCompany) AS Company,
	|	EDIUUIDs.EDocumentType AS EDocumentType,
	|	EDIUUIDs.UUID AS ETTN,
	|	EDIUUIDs.ID AS DocumentNumber
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(
	|			,
	|			ElectronicDocument IN (&DocumentsArray)
	|				AND Provider = &Provider) AS EDocumentsStatusesSliceLast
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (VALUETYPE(EDocumentsStatusesSliceLast.ElectronicDocument) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|		INNER JOIN Catalog.EDocumentStatuses AS EDocumentStatuses
	|		ON EDocumentsStatusesSliceLast.Status = EDocumentStatuses.Ref
	|			AND (NOT EDocumentStatuses.IsFinal)
	|		INNER JOIN InformationRegister.EDIUUIDs AS EDIUUIDs
	|		ON EDocumentsStatusesSliceLast.ElectronicDocument = EDIUUIDs.ElectronicDocument
	|WHERE
	|	NOT EDocumentStatuses.IsFinal";
	
	Query.SetParameter("DocumentsArray", DocumentsArray);
	Query.SetParameter("Provider", Provider);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		
		StatusStructure = EDIServer.StatusDataStructure();
		SessionID = ?(IsBlankString(SessionID), LoginRequest(Selection.Company, False), SessionID);
		StatusStructure = GetInvoiceStatusRequest(Selection.ETTN,
			Selection.Company,
			Selection.EDocumentType,
			StatusStructure,
			SessionID,
			Selection.DocumentNumber);
		
		If IsBlankString(StatusStructure.ErrorText) Then
			
			DescriptionStructure = CheckStatus(StatusStructure);
			If Not IsBlankString(DescriptionStructure.StatusDescription) Then
				
				StatusStructure.Final = DescriptionStructure.Final;
				StatusStructure.ResponseStatus = ?(DescriptionStructure.Rejected, 1, 0);
				
				StatusRef = EDIServer.UpdateStatusCatalog(DescriptionStructure.StatusDescription,
					Catalogs.EDocumentStatuses.EDM,
					StatusStructure);
				StatusStructure.Status = StatusRef.Status;
				StatusStructure.StatusDescription = StatusRef.StatusDescription;
				
				If ValueIsFilled(Selection.ElectronicDocument) Then
					
					If StatusStructure.Status = Selection.Status Then
						
						Filter = New Structure("ElectronicDocument", Selection.ElectronicDocument);
						Register = InformationRegisters.EDocumentsStatuses.Select(,, Filter, "Desc");
						Register.Next();
						NewState = Register.GetRecordManager();
						NewState.Read();
						
					Else
						NewState = InformationRegisters.EDocumentsStatuses.CreateRecordManager();
					EndIf;
					
					NewState.ElectronicDocument = Selection.ElectronicDocument;
					NewState.Period = CurrentSessionDate();
					NewState.Provider = Provider;
					NewState.Status = StatusStructure.Status;
					NewState.StatusDescription = StatusStructure.StatusDescription;
					NewState.ResponseStatus = StatusStructure.ResponseStatus;
					NewState.ResponseDescription = StatusStructure.ResponseDescription;
					NewState.SendStatus = StatusStructure.SendStatus;
					NewState.SendStatusResponseCode = StatusStructure.SendResponseCode;
					NewState.SendStatusResponse = StatusStructure.SendStatusResponse;
					NewState.Write();
					
					Filter = New Structure("ElectronicDocument", Selection.ElectronicDocument);
					Record = InformationRegisters.EDIUUIDs.Select(Filter, "Desc");
					Record.Next();
					NewState = Record.GetRecordManager();
					NewState.Read();
					NewState.Status = StatusStructure.Status;
					NewState.Write();
					
				EndIf;
				
			EndIf;
			
		Else
			
			ResultStructure.ErrorsToShow = True;
			ResultStructure.ListOfErrorsToShow.Add(StatusStructure.ErrorText);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CancelDocument(Document, EDocumentType, ResultStructure) Export
	
	Company = Catalogs.Companies.MainCompany;
	StatusStructure = EDIServer.StatusDataStructure();
	ConnectionData = EDIServer.ConnectionData("CancelInvoiceRequest",
		Company,
		EDocumentType,
		Enums.EDIProviders.EDM,,
		Document);
	ResultStructure.Insert("Canceled", False);
	
	SessionID = Login(Company, False);
	RequestTemplate = SOAPRequestTemplate("CancelInvoiceRequest");
	RequestHeader = SOAPRequestHeaderTemplate(SessionID);
	RequestBody =  GetCancelInvoiceRequestBody(Document.EDocumentNumber);
	XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader, RequestBody);
	
	HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
	HTTPRequest.SetBodyFromString(XMLRequest);
	HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
	
	If HTTPResponse.StatusCode = 200 Then
		
		XMLReader = New XMLReader;
		XMLReader.SetString(HTTPResponse.GetBodyAsString());
		ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
		SuccessFlag = False;
		
		ResponseBody = ObjectResponse.Body.CancelInvoiceResponse.REQUEST_RETURN.RETURN_CODE;
		
		If ResponseBody = "0" Then
			ResultStructure.Canceled = True;
		Else
			
			ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(HTTPResponse.GetBodyAsString());
			ResultStructure.ErrorsToShow = True;
			ResultStructure.ListOfErrorsToShow.Add(ErrorText);
			StatusStructure.ErrorText = ErrorText;
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to cancel document:
					|%1'; 
					|tr = 'Belge iptal edilemedi:
					|%1'", CommonClientServer.DefaultLanguageCode()),
				ErrorText);
			WriteLogEvent(
				NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
				
		EndIf;
		
	Else
		
		XMLReader = New XMLReader;
		XMLReader.SetString(HTTPResponse.GetBodyAsString());
		ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
		ErrorText = ObjectResponse.Body.Fault.detail.RequestFault.ERROR_LONG_DES;
		StatusStructure.ErrorText = ErrorText;
		ResultStructure.ErrorsToShow = True;
		ResultStructure.ListOfErrorsToShow.Add(ErrorText);
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to cancel document as a draft:
				|%1'; 
				|tr = 'Belge iptali başarısız. taslak: 
				|%1'", CommonClientServer.DefaultLanguageCode()),
			ErrorText);
		WriteLogEvent(
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
		
	EndIf;
	
EndProcedure

Procedure CheckCounterpartyIsTaxpayer(Company, CounterpartyTIN, ResultStructure, HasError) Export
	
	EDocumentType = Enums.EDocumentType.EInvoice;
	ConnectionData = EDIServer.ConnectionData("CheckUserRequest",
		Company,
		EDocumentType,
		Enums.EDIProviders.EDM);
	
	If IsBlankString(ConnectionData.Error) Then
		
		SessionID = LoginRequest(Company, False);
		If Not IsBlankString(SessionID) Then
			
			RequestTemplate = SOAPRequestTemplate("CheckUserRequest");
			RequestHeader = SOAPRequestHeaderTemplate(SessionID);
			RequestBody = CheckUserRequestBody(CounterpartyTIN);
			
			XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader, RequestBody);
			
			HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
			HTTPRequest.SetBodyFromString(XMLRequest);
			HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
			
			If HTTPResponse.StatusCode = 200 Then
				
				XMLReader = New XMLReader;
				XMLReader.SetString(HTTPResponse.GetBodyAsString());
				ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
				ResponseStructure = UBLServer.PrepareDataFromNode(ObjectResponse);
				
				If ResponseStructure.Body.CheckUserResponse.Property("USER") Then
					
					UserInformartion = ResponseStructure.Body.CheckUserResponse.USER;
					If TypeOf(UserInformartion) = Type("Structure") Then
						
						CrrData = UserInformartion;
						
						If CrrData.UNIT = "PK"
							And TypeOf(CrrData.ALIAS) = Type("String") Then
							
							ResultStructure.Description = CrrData.TITLE;
							ResultStructure.IsTaxpayer = True;
							IsTaxpayer = EDIServer.IsTaxpayer(CrrData.IDENTIFIER, EDocumentType, CrrData.TITLE);
							
							If Not IsTaxpayer.Result
								And Not IsBlankString(CrrData.TITLE)
								And Not IsBlankString(CrrData.IDENTIFIER) Then
								
								CreateTaxpayerRecord(CrrData, EDocumentType);
								
							EndIf;
							
						EndIf;
						
					ElsIf TypeOf(UserInformartion) = Type("Array") Then
						
						For Each CrrData In UserInformartion Do
							
							If CrrData.UNIT = "PK"
								And TypeOf(CrrData.ALIAS) = Type("String") Then
								
								ResultStructure.Description = CrrData.TITLE;
								ResultStructure.IsTaxpayer = True;
								IsTaxpayer = EDIServer.IsTaxpayer(CrrData.IDENTIFIER, EDocumentType, CrrData.TITLE);
								
								If Not IsTaxpayer.Result
									And Not IsBlankString(CrrData.TITLE)
									And Not IsBlankString(CrrData.IDENTIFIER) Then
									
									CreateTaxpayerRecord(CrrData, EDocumentType);
									
								EndIf;
								
							EndIf;
							
						EndDo;
						
					EndIf;
					
				EndIf;
				
			Else
				
				ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(HTTPResponse.GetBodyAsString());
				
				HasErrors = True;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Failed to get data:
					|%1'; 
					|tr = 'Veriler alınamadı:
					|%1'", CommonClientServer.DefaultLanguageCode()),
					ErrorText);
				WriteLogEvent(
					NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					ErrorDescription);
				
			EndIf;
			
		Else
			
			HasErrors = True;
			ErrorDescription = NStr("en = 'Failed to login EDI provider:
				|Username and Password is empty.'; 
				|tr = 'EDI sağlayıcısına giriş yapılamadı:
				|Kullanıcı adı ve Parola boş.'", CommonClientServer.DefaultLanguageCode());
			WriteLogEvent(
				NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				,
				,
				ErrorDescription);
				
			ResultStructure.Error = ErrorDescription;
			
		EndIf;
		
	Else
		
		HasErrors = True;
		WriteLogEvent(
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ConnectionData.Error);
		
		ResultStructure.Error = ConnectionData.Error;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region SendDocumentsHandlers

Function LoadEDocumentRequest(Company, Document, ResultStructure)
	
	StatusStructure = EDIServer.StatusDataStructure();
	
	If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
		
		DocumentAttributes = UBLServer.AttributesForLoadingInvoice(Document, False, ResultStructure);
		EDocumentType = ?(DocumentAttributes.IsEInvoice, Enums.EDocumentType.EInvoice, Enums.EDocumentType.EArchive);
		ConnectionData = EDIServer.ConnectionData("SendInvoiceRequest", Company, EDocumentType, Enums.EDIProviders.EDM, , Document);
		
	EndIf;
	
	If DocumentAttributes.IsEmpty Then
		
		ErrorText = NStr("en = 'The inventory table is empty. Please ensure it is filled before sending the document to EDI.'; tr = 'Stok tablosu boş. Belgeyi EDI''ye göndermeden önce doldurulduğundan emin olun.'");
		StatusStructure.ErrorText = ErrorText;
		Return StatusStructure;
		
	EndIf;
	
	If Not IsBlankString(ConnectionData.Error) Then
		
		ErrorTitle = NStr("en = 'Failed to connection'; tr = 'Bağlantı başarısız oldu'");
		StatusStructure.ErrorText = ErrorTitle;
		EDIServer.WriteEventLog(ErrorTitle, ConnectionData.Error);
		
		Return StatusStructure;
		
	EndIf;
	
	DocumentAttributes.Insert("XSLT", ConnectionData.XSLT);
	SessionID = LoginRequest(Company, False);
	
	If Not IsBlankString(SessionID) Then
		
		If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
			
			UBL = UBLServer.GenerateUBL(DocumentAttributes);
			RequestTemplate = SOAPRequestTemplate("SendInvoiceRequest");
			RequestHeader = SOAPRequestHeaderTemplate(SessionID);
			RequestBody = LoadInvoiceRequestBody(DocumentAttributes, UBL);
			
		EndIf;
		
		XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader, RequestBody);
		
		HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
		HTTPRequest.SetBodyFromString(XMLRequest);
		HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
		
		If HTTPResponse.StatusCode = 200 Then
			
			XMLReader = New XMLReader;
			XMLReader.SetString(HTTPResponse.GetBodyAsString());
			ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
			
			If TypeOf(Document) = Type("DocumentRef.SalesInvoice") Then
				
				StatusDesc = ObjectResponse.Body.SendInvoiceResponse.INVOICE.HEADER.STATUS_DESCRIPTION;
				Status = ObjectResponse.Body.SendInvoiceResponse.INVOICE.HEADER.STATUS;
				
			EndIf;
			
			If NOT DocumentAttributes.IsEInvoice Then
				
				DescriptionStructure = CheckStatus(New Structure("Status, StatusDescription", Status, StatusDesc));
				StatusStructure.Final = DescriptionStructure.Final;
				StatusStructure.ResponseStatus = ?(DescriptionStructure.Rejected, 1, 0);
				StatusRef = EDIServer.UpdateStatusCatalog(DescriptionStructure.StatusDescription, Catalogs.EDocumentStatuses.EDM, StatusStructure);
				StatusStructure.Status = StatusRef.Status;
				StatusStructure.StatusDescription = StatusRef.StatusDescription;
				SuccessFlag = True;
				
			Else
				
				StatusStructure = GetInvoiceStatusRequest(DocumentAttributes.DocumentUUID, Company,
					EDocumentType,
					StatusStructure,
					SessionID,
					DocumentAttributes.DocumentID);
				
				DescriptionStructure = CheckStatus(StatusStructure);
				
				If DescriptionStructure.StatusDescription = "FAILED"
					Or DescriptionStructure.StatusDescription = "FAIL" Then
					
					ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(HTTPResponse.GetBodyAsString());
					StatusStructure.ErrorText = ErrorText;
					
				Else
					
					StatusStructure.Final = DescriptionStructure.Final;
					StatusStructure.ResponseStatus = ?(DescriptionStructure.Rejected, 1, 0);
					StatusRef = EDIServer.UpdateStatusCatalog(DescriptionStructure.StatusDescription, Catalogs.EDocumentStatuses.EDM, StatusStructure);
					StatusStructure.Status = StatusRef.Status;
					StatusStructure.StatusDescription = StatusRef.StatusDescription;
					SuccessFlag = True;
					
				EndIf;
				
			EndIf;
			
			If SuccessFlag Then
				UpdateEDIUUIDsRecord(UBL, DocumentAttributes, EDocumentType, StatusStructure.Status);
			EndIf;
			
		Else
			
			ResponseBody = HTTPResponse.GetBodyAsString();
			If Not IsBlankString(ResponseBody) Then
				
				XMLReader = New XMLReader;
				XMLReader.SetString(HTTPResponse.GetBodyAsString());
				ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
				ErrorText = ObjectResponse.Body.Fault.detail.RequestFault.ERROR_LONG_DES;
				
				// The provider indicates the document is already sent (Error code: 11048).
				// https://docs.edmbilisim.com.tr/api/api-documentation/ws-error-codes-and-description.html
				// Update the status of the sent document in the system.
				If ObjectResponse.Body.Fault.detail.RequestFault.ERROR_CODE = "11048" Then
					
					DescriptionStructure = CheckStatus(StatusStructure, True);
					StatusRef = EDIServer.UpdateStatusCatalog(DescriptionStructure.StatusDescription, Catalogs.EDocumentStatuses.EDM, StatusStructure);
					StatusStructure.Final = DescriptionStructure.Final;
					StatusStructure.ResponseStatus = ?(DescriptionStructure.Rejected, 1, 0);
					StatusStructure.Status = StatusRef.Status;
					StatusStructure.StatusDescription = StatusRef.StatusDescription;
					
					// Synchronize EDI UUIDs for the record to reflect the provider's status
					UpdateEDIUUIDsRecord(UBL, DocumentAttributes, EDocumentType, StatusRef.Status);
					
					// Clear any previous error messages
					ErrorText = "";
					
				EndIf;
				
			Else
				ErrorText = ResponseBody;
			EndIf;
			
			If Not IsBlankString(ErrorText) Then
				ErrorTitle = NStr("en = 'Failed to send document:'; tr = 'Belge gönderilemedi:'");
				StatusStructure.ErrorText = EDIServer.WriteEventLog(ErrorTitle, ErrorText);
			EndIf;
			
		EndIf;
		
	Else
		
		HasErrors = True;
		ErrorTitle = NStr("en = 'Failed to login EDI provider:'; tr = 'EDI sağlayıcısına giriş yapılamadı:'");
		ErrorText = NStr("en = 'Active session not found. Check login credentials.'; tr = 'Aktif oturum bulunamadı. Giriş kimlik bilgilerini kontrol edin.'");
		StatusStructure.ErrorText = EDIServer.WriteEventLog(ErrorTitle, ErrorText);
		
	EndIf;
	
	Return StatusStructure;
	
EndFunction

Procedure UpdateEDIUUIDsRecord(UBL, DocumentAttributes, EDocumentType, StatusStructureStatus = Undefined)
	
	BinaryData = GetBinaryDataFromString(UBL, TextEncoding.UTF8);
	Base64Value = Base64String(BinaryData);
	
	Record = InformationRegisters.EDIUUIDs.CreateRecordManager();
	Record.ElectronicDocument = DocumentAttributes.Document;
	Record.EDocumentType = EDocumentType;
	Record.Read();
	Record.EDocumentScenario = DocumentAttributes.EDocumentScenario;
	
	If StatusStructureStatus <> Undefined Then
		Record.Status = StatusStructureStatus;
	EndIf;
	
	Record.Date = CurrentSessionDate();
	Record.QueryID = DocumentAttributes.DocumentUUID;
	Record.UBLData = New ValueStorage(Base64Value, New Deflation(9));
	Record.Write();
	
EndProcedure

Function GetInvoiceStatusRequest(DocumentID, Company, EDocumentType, StatusData, SessionID, DocumentNumber)
	
	ConnectionData = EDIServer.ConnectionData("GetInvoiceStatusRequest", Company, EDocumentType, Enums.EDIProviders.EDM);
	RequestTemplate = SOAPRequestTemplate("GetInvoiceStatusRequest");
	RequestHeader = SOAPRequestHeaderTemplate(SessionID);
	RequestBody = CheckStatusInvoiceRequestBody(DocumentID);
	
	If Not IsBlankString(ConnectionData.Error) Then
		
		StatusData.ErrorText = ConnectionData.Error;
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to login
				|%1'; 
				|tr = 'Giriş başarısız:
				|%1'", CommonClientServer.DefaultLanguageCode()),
			ConnectionData.Error);
		WriteLogEvent(
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
		
		Return StatusData;
		
	EndIf;

	XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader, RequestBody);
	
	HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
	HTTPRequest.SetBodyFromString(XMLRequest);
	
	HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
	
	If HTTPResponse.StatusCode = 200 Then
		
		XMLReader = New XMLReader;
		XMLReader.SetString(HTTPResponse.GetBodyAsString());
		ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
		
		ResponseBody = ObjectResponse.Body.GetInvoiceStatusResponse.INVOICE_STATUS;
		
		ResponseCode = 2;
		If ResponseBody.STATUS = "REJECT - SUCCEED"
			Or ResponseBody.STATUS = "REJECTED - SUCCEED"
			Or ResponseBody.STATUS_DESCRIPTION = "SUCCEED" Then
			ResponseCode = 1;
		EndIf;
		
		ResponseDesc = ?(TypeOf(ResponseBody.RESPONSE_DESCRIPTION) = Type("String"), ResponseBody.RESPONSE_DESCRIPTION, "");
		GIB_STATUS_CODE = ?(ResponseBody.Properties().Get("GIB_STATUS_CODE") <> Undefined, ResponseBody.GIB_STATUS_CODE, 0);
		GIB_STATUS_DESCRIPTION = ?(ResponseBody.Properties().Get("GIB_STATUS_DESCRIPTION") <> Undefined,
			ResponseBody.GIB_STATUS_DESCRIPTION, "");
		
		StatusData.Status = ResponseBody.STATUS;
		StatusData.Date = GetDateTimeFromString(ResponseBody.CDATE);
		StatusData.StatusDescription = "";
		StatusData.ResponseStatus = ResponseCode;
		StatusData.ResponseDescription = ResponseDesc;
		StatusData.SendStatus = "";
		StatusData.SendStatusResponse = GIB_STATUS_DESCRIPTION;
		StatusData.SendResponseCode = GIB_STATUS_CODE;
		
	Else
		
		ErrorText = HTTPResponse.GetBodyAsString();
		If Not IsBlankString(ResponseBody) Then
			
			XMLReader = New XMLReader;
			XMLReader.SetString(ResponseBody);
			ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
			ErrorText = ObjectResponse.Body.Fault.detail.RequestFault.ERROR_LONG_DES;
			
		EndIf;
		
		StatusData.ErrorText = ErrorText;
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Failed to login'; tr = 'Giriş başarısız'", CommonClientServer.DefaultLanguageCode()),
			ErrorText);
		WriteLogEvent(
			NStr("en = 'EDI exchange'; tr = 'EDI değişimi'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			,
			,
			ErrorDescription);
		
	EndIf;
	
	Return StatusData;
	
EndFunction

Procedure CheckSalesInvoiceIsReadyForExchange(Document, HasErrors, ArrayToSaveMessages)
	
	DocumentInfo = Common.ObjectAttributesValues(Document, "ExemptFromVAT, Inventory");
	
	If DocumentInfo.ExemptFromVAT Then
		
		InventoryTable = DocumentInfo.Inventory.Select();
		
		While InventoryTable.Next() Do
			
			If InventoryTable.TaxExemptionReason.IsEmpty() Then
				
				MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'To submit document %1, please fill in the tax exemption reason in each line of the document.'; tr = '%1 belgesini göndermek için lütfen vergi muafiyeti sebebini belgenin her satırında doldurun.'"),
					Document);
				ArrayToSaveMessages.Add(MessageToUserText);
				HasErrors = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function CheckStatus(StatusData, AlreadySent = False)
	
	StatusStructure = New Structure;
	StatusStructure.Insert("StatusDescription");
	StatusStructure.Insert("Final", False);
	StatusStructure.Insert("Rejected", False);
	
	If StatusData.Status = "PACKAGE - PROCESSING"
		Or StatusData.Status = "SEND - PROCESSING"
		Or StatusData.Status = "UNKNOWN - UNKNOWN"
		Or StatusData.Status = "ACCEPT - PROCESSING"
		Or StatusData.Status = "REJECT - PROCESSING"
		Or AlreadySent Then // Processing
		
		StatusStructure.StatusDescription = NStr("en = 'Sent - Processing'; tr = 'Gönderildi - İşleniyor'", CommonClientServer.DefaultLanguageCode());
		StatusStructure.Rejected = (StatusData.StatusDescription = "REJECT - PROCESSING");
		
	ElsIf StatusData.Status = "SEND - WAIT_APPLICATION_RESPONSE"
		Or StatusData.Status = "SEND - WAIT_GIB_RESPONSE"
		Or StatusData.Status = "SEND - WAIT_SYSTEM_RESPONSE"
		Or StatusData.Status = "PROCESSING - WAIT_GIB_RESPONSE"
		Or StatusData.Status = "RECEIVE - WAIT_APPLICATION_RESPONSE"
		Or StatusData.Status = "ACCEPT - WAIT_GIB_RESPONSE"
		Or StatusData.Status = "RECEIVE - WAIT_SYSTEM_RESPONSE"
		Or StatusData.Status = "ACCEPT - WAIT_SYSTEM_RESPONSE" Then
		
		StatusStructure.StatusDescription = NStr("en = 'Sent - Waiting Response'; tr = 'Gönderildi - Yanıt Bekleniyor'", CommonClientServer.DefaultLanguageCode());
		
	ElsIf StatusData.Status = "REJECT - WAIT_GIB_RESPONSE"
		Or StatusData.Status = "REJECT - WAIT_SYSTEM_RESPONSE" Then // Waiting response
		
		StatusStructure.StatusDescription = NStr("en = 'Sent - Waiting Response'; tr = 'Gönderildi - Yanıt Bekleniyor'", CommonClientServer.DefaultLanguageCode());
		StatusStructure.Rejected = True;
		
	ElsIf StatusData.Status = "SEND - FAILED"
		Or StatusData.Status = "PACKAGE - FAIL"
		Or StatusData.Status = "ACCEPT - FAILED"
		Or StatusData.Status = "REJECT - FAILED" Then // Operation failed
		
		StatusStructure.StatusDescription = NStr("en = 'Operation failed'; tr = 'İşlem yapılamadı'", CommonClientServer.DefaultLanguageCode());
		StatusStructure.Rejected = (StatusData.Status = "REJECT - FAILED");
		
	ElsIf StatusData.Status = "SEND - SUCCEED"
		Or StatusData.Status = "RECEIVE - SUCCEED"
		Or StatusData.Status = "REJECT - SUCCEED"
		Or StatusData.Status = "ACCEPTED - SUCCEED"
		Or StatusData.Status = "PARTIALACCEPTED - SUCCEED" 
		Or StatusData.Status = "ACCEPT - SUCCEED" Then // Successed
		
		StatusStructure.StatusDescription = NStr("en = 'Sent successfully'; tr = 'Başarıyla gönderildi'", CommonClientServer.DefaultLanguageCode());
		StatusStructure.Final = True;
		StatusStructure.Rejected = (StatusData.Status = "REJECT - SUCCEED");
		
	ElsIf StatusData.Status = "CANCELLED - SUCCEED" Then // Cancelled
		StatusStructure.StatusDescription = NStr("en = 'Cancel successfully'; tr = 'İptal başarılı'", CommonClientServer.DefaultLanguageCode());
	Else
		StatusStructure.StatusDescription = NStr("en = 'Operation failed'; tr = 'İşlem yapılamadı'", CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	Return StatusStructure;
	
EndFunction

#Region SendDocumentsRequestBodies

#Region SendEInvoiceSendDocumentsRequestBodies

Function LoadInvoiceRequestBody(DocumentAttributes, UBL)
	
	HashedData = HashUBLData(UBL);
	
	IsEArchive = EDIServer.IsTaxPayer(DocumentAttributes.CounterpartyVKN, Enums.EDocumentType.EInvoice);
	
	Parameters = New Array;
	// %1
	Parameters.Add(DocumentAttributes.DocumentUUID);
	// %2
	Parameters.Add(DocumentAttributes.DocumentID);
	// %3
	Parameters.Add(DocumentAttributes.CompanyLegalName);
	// %4
	Parameters.Add(DocumentAttributes.CounterpartyLegalName);
	// %5
	Parameters.Add(DocumentAttributes.InvoiceDate);
	// %6
	Parameters.Add(DocumentAttributes.Company.TIN);
	// %7
	Parameters.Add(DocumentAttributes.CounterpartyVKN);
	// %8
	Parameters.Add(DocumentAttributes.CompanyEmailGB);
	// %9
	Parameters.Add(DocumentAttributes.CounterpartyGIBPK);
	// %10
	Parameters.Add(HashedData.Base64);
	// %11
	Parameters.Add(?(IsEArchive.Result, "false", "true"));
	// %12
	Parameters.Add("false");
	
	ResultTemplate = 
	"<RECEIVER vkn=""%7"" alias=""%9"" />
	|<INVOICE UUID='%1' ID='%2'>
	|	<HEADER>
	|		<SUPPLIER>%3</SUPPLIER>
	|		<CUSTOMER>%4</CUSTOMER>
	|		<ISSUE_DATE>%5</ISSUE_DATE>
	|		<SENDER>%6</SENDER>
	|		<RECEIVER>%7</RECEIVER>
	|		<FROM>%8</FROM>
	|		<INTERNETSALES>%12</INTERNETSALES>
	|		<EARCHIVE>%11</EARCHIVE>
	|		<EARCHIVE_REPORT_SENDDATE>0001-01-01</EARCHIVE_REPORT_SENDDATE>
	|		<CANCEL_EARCHIVE_REPORT_SENDDATE>0001-01-01</CANCEL_EARCHIVE_REPORT_SENDDATE>
	|		<DIRECTION>Out</DIRECTION>
	|	</HEADER>
	|	<CONTENT xm:contentType=""application/xml"">
	|		 %10
	|	</CONTENT>
	|</INVOICE>";
	
	Result = JetClientServer.SubstituteParametersToStringFromArray(ResultTemplate, Parameters);
	
	Return Result;
	
EndFunction

Function CheckStatusInvoiceRequestBody(DocumentID)
	
	RequestBody = "<INVOICE UUID='" + DocumentID + "' />";
	
	Return RequestBody;
	
EndFunction

#EndRegion

Function CheckUserRequestBody(TIN)
	
	RequestBody = "
	|<USER>
	|	<IDENTIFIER>" + TIN + "</IDENTIFIER>
	|</USER>";
	
	Return RequestBody;
	
EndFunction

#EndRegion

#EndRegion

#Region CancelInvoice

Function GetCancelInvoiceRequestBody(DocumentID)
	
	RequestBody = "<INVOICE ID='" + DocumentID + "' />";
	
	Return RequestBody;
	
EndFunction

#EndRegion 

#Region CommonHandlers

Function LoginRequest(Company, HasErrors)
	
	SessionID = "";
	ConnectionData = EDIServer.ConnectionData("LoginRequest", Company, Enums.EDocumentType.EInvoice, Enums.EDIProviders.EDM);
	
	If Not IsBlankString(ConnectionData.Error) Then
		
		ErrorTitle = NStr("en = 'Failed to connection'; tr = 'Bağlantı başarısız oldu'");
		ErrorDescription = EDIServer.WriteEventLog(ErrorTitle, ConnectionData.Error);
		HasErrors = True;
		
		Return SessionID;
		
	EndIf;
	
	RequestTemplate = SOAPRequestTemplate("LoginRequest");
	RequestHeader = SOAPRequestHeaderTemplate(SessionID);
	RequestBody = LoginRequestBody(ConnectionData);
	
	XMLRequest = StringFunctionsClientServer.SubstituteParametersToString(RequestTemplate, RequestHeader, RequestBody);
	
	HTTPRequest = New HTTPRequest("", ConnectionData.Headers);
	HTTPRequest.SetBodyFromString(XMLRequest);
	
	HTTPResponse = ConnectionData.HTTPConnection.Post(HTTPRequest);
	
	If HTTPResponse.StatusCode = 200 Then
		
		XMLReader = New XMLReader;
		XMLReader.SetString(HTTPResponse.GetBodyAsString());
		ObjectResponse = ConnectionData.EDIXDTOFactory.ReadXML(XMLReader);
		SessionID = ObjectResponse.Body.LoginResponse.SESSION_ID;
		
	Else
		
		ErrorText = StringFunctionsClientServer.ExtractTextFromHTML(HTTPResponse.GetBodyAsString());
		ErrorTitle = NStr("en = 'Failed to login:'; tr = 'Giriş yapılamadı:'");
		ErrorDescription = EDIServer.WriteEventLog(ErrorTitle, ErrorText);
		HasErrors = True;
		
	EndIf;
	
	Return SessionID;
	
EndFunction

Function LoginRequestBody(ConnectionData)
	
	LoginRequest = "
	|<USER_NAME>" + ConnectionData.UserName + "</USER_NAME>
	|<PASSWORD>" + ConnectionData.Password + "</PASSWORD>
	|<SECRET_KEY>7CA243EA-72BA-40FD-B8AE-2794D3B7BDEC</SECRET_KEY>";
	
	Return LoginRequest;
	
EndFunction

Function SOAPRequestHeaderTemplate(SessionID)
	
	Parameters = New Array;
	// %1
	Parameters.Add(SessionID);
	// %2
	Parameters.Add(UBLServer.GetDate(CurrentSessionDate()));
	// %3
	Parameters.Add("");
	// %4
	Parameters.Add(?(Not IsBlankString(SessionID), "<SESSION_ID>%1</SESSION_ID>", "%3"));
	// %5
	Parameters.Add(Constants.EDIApplicationNameEDM.Get());
	
	RequestHeader =
	"<REQUEST_HEADER>
	|	%4
	|	<ACTION_DATE>%2</ACTION_DATE>
	|	<REASON>1C:JetTurkey</REASON>
	|	<APPLICATION_NAME>%5</APPLICATION_NAME>
	|	<HOSTNAME>1C:JetTurkey</HOSTNAME>
	|	<CHANNEL_NAME>1Ci</CHANNEL_NAME>
	|</REQUEST_HEADER>";
	
	RequestHeader = JetClientServer.SubstituteParametersToStringFromArray(RequestHeader, Parameters);
	
	Return RequestHeader;
	
EndFunction

Function SOAPRequestTemplate(Method)
	
	XML = 
	"<soapenv:Envelope xmlns:soapenv=""http://schemas.xmlsoap.org/soap/envelope/"" xmlns:tem=""http://tempuri.org/""
	|	xmlns:xm=""http://www.w3.org/2005/05/xmlmime""
	|	xmlns:urn=""urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2""
	|	xmlns:urn1=""urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"">
	|	<soapenv:Header/>
	|	<soapenv:Body>
	|	<tem:" + Method + ">
	|		%1
	|		%2
	|	</tem:" + Method + ">
	| </soapenv:Body>
	|</soapenv:Envelope>";
	
	Return XML;
	
EndFunction

Function GetDateTimeFromString(pDateTime) Export
	
	DateTimeStr = StrSplit(pDateTime,"T");
	
	pDateStr = DateTimeStr.Get(0);
	pDate = StrSplit(pDateStr, "-");
	pTimeAll = DateTimeStr.Get(1);
	pTimeStr = Left(pTimeAll, 8);
	pTime = StrSplit(pTimeStr,":");
	
	Result = Date(pDate.Get(0), pDate.Get(1), pDate.Get(2), pTime.Get(0), pTime.Get(1), Left(pTime.Get(2), 2));
	
	Return Result;
	
EndFunction

Function HashUBLData(UBL)
	
	TempFile = GetTempFileName();
	Writer = New TextWriter(TempFile, TextEncoding.UTF8);
	Writer.Write(UBL);
	Writer.Close();
	
	MD5Encrypt = New DataHashing(HashFunction.MD5);
	MD5Encrypt.AppendFile(TempFile);
	BinaryHash = Lower(MD5Encrypt.HashSum);
	BinaryHashStr = StrReplace(String(BinaryHash), " ", "");
	
	BinaryData = New BinaryData(TempFile);
	Base64Value = Base64String(BinaryData);
	
	Hashdata = New Structure;
	Hashdata.Insert("MD5", BinaryHashStr);
	Hashdata.Insert("Base64", Base64Value);
	
	File = New File(TempFile);
	If File.Exists() Then
		DeleteFiles(TempFile);
	EndIf;
	
	Return Hashdata;
	
EndFunction

Procedure CreateTaxpayerRecord(RecordInfo, EDocumentType)
	
	Record = InformationRegisters.TaxpayerList.CreateRecordManager();
	Record.Identifier = RecordInfo.ALIAS;
	Record.Title = RecordInfo.TITLE;
	Record.RegisterDate = GetDateTimeFromString(RecordInfo.REGISTER_TIME);
	Record.TIN = RecordInfo.IDENTIFIER;
	Record.EDocumentType = EDocumentType;
	
	If RecordInfo.TYPE = "KAMU" Then
		IsPublicEstablishment = True;
	Else
		IsPublicEstablishment = False;
	EndIf;
	
	Record.IsPublicEstablishment = IsPublicEstablishment;
	Record.Write();
	
EndProcedure

#EndRegion

#EndRegion
