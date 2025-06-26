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
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.CashAccount AS CashAccount,
	|	CashVoucherPaymentDetails.PaymentAmount AS PaymentAmount
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
	|	DocumentPaymentDetails.CashAccount";
	
	Query.SetParameter("Ref", CashVoucherRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashBalance", QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#EndIf