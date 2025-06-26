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
	|	BankPayment.Operation AS Operation,
	|	BankPayment.Counterparty AS Counterparty,
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
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.PaymentDate AS Period,
	|	DocumentHeader.Operation AS Operation,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	BankPaymentPaymentDetails.Document AS Document,
	|	BankPaymentPaymentDetails.PaymentAmount AS PaymentAmount,
	|	BankPaymentPaymentDetails.Amount AS Amount
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
	|	DocumentPaymentDetails.BankAccount
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
	|	DocumentPaymentDetails.Operation = VALUE(Enum.BankPaymentOperations.Supplier)
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
	
	Query.SetParameter("Ref", BankPaymentRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableCashBalance", QueryResult[2].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableSupplierBalance", QueryResult[3].Unload());
	
EndProcedure

// StandardSubsystems.Print

// Overrides object's print settings.
//
// Parameters:
//  Settings - See PrintManagement.ObjectPrintingSettings.
//
Procedure OnDefinePrintSettings(Settings) Export
	
	Settings.OnAddPrintCommands = True;
	
EndProcedure

// Populates a list of print commands.
// 
// Parameters:
//  PrintCommands - See PrintManagement.CreatePrintCommandsCollection
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
EndProcedure

// End StandardSubsystems.Print

#EndRegion

#EndIf