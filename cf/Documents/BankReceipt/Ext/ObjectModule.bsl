#If Server Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingJet.FillDocument(ThisObject, FillingData);
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SalesInvoice.Ref AS Ref,
		|	SalesInvoice.Customer AS Customer,
		|	SalesInvoice.Currency AS Currency,
		|	SalesInvoice.ExchangeRate AS ExchangeRate,
		|	SalesInvoice.Multiplier AS Multiplier,
		|	SalesInvoice.Total AS Total
		|INTO DocumentHeader
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	BankAccounts.Ref AS Ref,
		|	BankAccounts.Currency AS Currency
		|INTO BankAccount
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|		INNER JOIN DocumentHeader AS DocumentHeader
		|		ON BankAccounts.Currency = DocumentHeader.Currency
		|WHERE
		|	NOT BankAccounts.DeletionMark
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(Enum.BankReceiptOperations.Customer) AS Operation,
		|	DocumentHeader.Customer AS Counterparty,
		|	ISNULL(BankAccount.Ref, VALUE(Catalog.BankAccounts.EmptyRef)) AS BankAccount,
		|	DocumentHeader.Currency AS Currency,
		|	DocumentHeader.ExchangeRate AS ExchangeRate,
		|	DocumentHeader.Multiplier AS Multiplier,
		|	DocumentHeader.Ref AS Document,
		|	DocumentHeader.Total AS PaymentAmount,
		|	CASE
		|		WHEN DocumentHeader.Multiplier = 0
		|			THEN 0
		|		ELSE CAST(DocumentHeader.Total * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS NUMBER(15, 2))
		|	END AS Amount
		|FROM
		|	DocumentHeader AS DocumentHeader
		|		LEFT JOIN BankAccount AS BankAccount
		|		ON DocumentHeader.Currency = BankAccount.Currency";
		
		Query.SetParameter("Ref", FillingData);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			Selection.Next();
			
			FillPropertyValues(ThisObject, Selection);
			
			PaymentDetails.Clear();
			FillPropertyValues(PaymentDetails.Add(), Selection);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.BankReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Movements on the CashBalance register
	PostingManagement.ReflectCashBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Movements on the CustomerBalance register
	PostingManagement.ReflectCustomerBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf