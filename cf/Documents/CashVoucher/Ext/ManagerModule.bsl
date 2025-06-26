#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  CashVoucherRef - DocumentRef.CashVoucher - ref to Bank receipt.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(CashVoucherRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CashVoucher.Ref AS Ref,
	|	CashVoucher.Date AS Date,
	|	CashVoucher.Operation AS Operation,
	|	CashVoucher.Counterparty AS Counterparty,
	|	CashVoucher.CashAccount AS CashAccount
	|INTO DocumentHeader
	|FROM
	|	Document.CashVoucher AS CashVoucher
	|WHERE
	|	CashVoucher.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Operation AS Operation,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashAccount AS CashAccount,
	|	CashVoucherPaymentDetails.Document AS Document,
	|	CashVoucherPaymentDetails.PaymentAmount AS PaymentAmount,
	|	CashVoucherPaymentDetails.Amount AS Amount
	|INTO DocumentPaymentDetails
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
	|		ON DocumentHeader.Ref = CashVoucherPaymentDetails.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SupplierInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN VALUE(Enum.LiabilityTypes.Advance)
	|		ELSE VALUE(Enum.LiabilityTypes.Liability)
	|	END AS LiabilityType,
	|	DocumentPaymentDetails.Counterparty AS Counterparty,
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SupplierInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN DocumentPaymentDetails.Ref
	|		ELSE DocumentPaymentDetails.Document
	|	END AS Document,
	|	SUM(DocumentPaymentDetails.Amount) AS Amount
	|FROM
	|	DocumentPaymentDetails AS DocumentPaymentDetails
	|WHERE
	|	DocumentPaymentDetails.Operation = VALUE(Enum.CashVoucherOperations.Supplier)
	|
	|GROUP BY
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SupplierInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN VALUE(Enum.LiabilityTypes.Advance)
	|		ELSE VALUE(Enum.LiabilityTypes.Liability)
	|	END,
	|	DocumentPaymentDetails.Counterparty,
	|	CASE
	|		WHEN DocumentPaymentDetails.Document = VALUE(Document.SupplierInvoice.EmptyRef)
	|				OR DocumentPaymentDetails.Document = UNDEFINED
	|			THEN DocumentPaymentDetails.Ref
	|		ELSE DocumentPaymentDetails.Document
	|	END,
	|	DocumentPaymentDetails.Period";
	
	Query.SetParameter("Ref", CashVoucherRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashBalance", QueryResult[2].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableSupplierBalance", QueryResult[3].Unload());
	
EndProcedure

#EndRegion

#EndIf