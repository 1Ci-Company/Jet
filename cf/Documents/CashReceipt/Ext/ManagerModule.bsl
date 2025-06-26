#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  CashReceiptRef - DocumentRef.CashReceipt - ref to Bank receipt.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(CashReceiptRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashReceipt.Ref AS Ref,
	|	CashReceipt.Date AS Date,
	|	CashReceipt.Operation AS Operation,
	|	CashReceipt.Counterparty AS Counterparty,
	|	CashReceipt.CashAccount AS CashAccount
	|INTO DocumentHeader
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|WHERE
	|	CashReceipt.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Operation AS Operation,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashAccount AS CashAccount,
	|	CashReceiptPaymentDetails.Document AS Document,
	|	CashReceiptPaymentDetails.PaymentAmount AS PaymentAmount,
	|	CashReceiptPaymentDetails.Amount AS Amount
	|INTO DocumentPaymentDetails
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
	|		ON DocumentHeader.Ref = CashReceiptPaymentDetails.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.CashTypes.Cash) AS CashType,
	|	DocumentPaymentDetails.Period AS Period,
	|	DocumentPaymentDetails.CashAccount AS BankCashAccount,
	|	SUM(DocumentPaymentDetails.PaymentAmount) AS AmountCur
	|FROM
	|	DocumentPaymentDetails AS DocumentPaymentDetails
	|
	|GROUP BY
	|	DocumentPaymentDetails.Period,
	|	DocumentPaymentDetails.CashAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentPaymentDetails.Period AS Period,
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SalesInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN VALUE(Enum.LiabilityTypes.Advance)
	|		ELSE VALUE(Enum.LiabilityTypes.Liability)
	|	END AS LiabilityType,
	|	DocumentPaymentDetails.Counterparty AS Counterparty,
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SalesInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN DocumentPaymentDetails.Ref
	|		ELSE DocumentPaymentDetails.Document
	|	END AS Document,
	|	SUM(DocumentPaymentDetails.Amount) AS Amount
	|FROM
	|	DocumentPaymentDetails AS DocumentPaymentDetails
	|WHERE
	|	DocumentPaymentDetails.Operation = VALUE(Enum.CashReceiptOperations.Customer)
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SalesInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN VALUE(Enum.LiabilityTypes.Advance)
	|		ELSE VALUE(Enum.LiabilityTypes.Liability)
	|	END,
	|	DocumentPaymentDetails.Counterparty,
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SalesInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN DocumentPaymentDetails.Ref
	|		ELSE DocumentPaymentDetails.Document
	|	END,
	|	DocumentPaymentDetails.Period";
	
	Query.SetParameter("Ref", CashReceiptRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashBalance", QueryResult[2].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableCustomerBalance", QueryResult[3].Unload());
	
EndProcedure

#EndRegion

#EndIf