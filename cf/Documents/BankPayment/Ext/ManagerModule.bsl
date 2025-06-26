#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  BankPaymentRef - DocumentRef.BankPayment - ref to Bank receipt.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(BankPaymentRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BankPayment.Ref AS Ref,
	|	BankPayment.PaymentDate AS PaymentDate,
	|	BankPayment.BankAccount AS BankAccount
	|INTO DocumentHeader
	|FROM
	|	Document.BankPayment AS BankPayment
	|WHERE
	|	BankPayment.Ref = &Ref
	|	AND BankPayment.Paid
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.PaymentDate AS Period,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	BankPaymentPaymentDetails.PaymentAmount AS PaymentAmount
	|INTO DocumentPaymentDetails
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.BankPayment.PaymentDetails AS BankPaymentPaymentDetails
	|		ON DocumentHeader.Ref = BankPaymentPaymentDetails.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.CashTypes.NonCash) AS CashType,
	|	DocumentPaymentDetails.Period AS Period,
	|	DocumentPaymentDetails.BankAccount AS BankCashAccount,
	|	SUM(DocumentPaymentDetails.PaymentAmount) AS AmountCur
	|FROM
	|	DocumentPaymentDetails AS DocumentPaymentDetails
	|
	|GROUP BY
	|	DocumentPaymentDetails.Period,
	|	DocumentPaymentDetails.BankAccount";
	
	Query.SetParameter("Ref", BankPaymentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashBalance", QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#EndIf