#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  SupplierInvoiceRef - DocumentRef.SupplierInvoice - ref to Supplier invoice.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(SupplierInvoiceRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.Supplier AS Supplier,
	|	SupplierInvoice.Warehouse AS Warehouse,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplier AS Multiplier
	|INTO DocumentHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Supplier AS Counterparty,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	DocumentHeader.Ref AS Document,
	|	SupplierInvoiceInventory.Product AS Product,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.Amount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Amount,
	|	SupplierInvoiceInventory.VATAmount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS VATAmount,
	|	SupplierInvoiceInventory.Total * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Total
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON DocumentHeader.Ref = SupplierInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity,
	|	SUM(DocumentInventory.Amount) AS Amount
	|INTO ProductTable
	|FROM
	|	DocumentInventory AS DocumentInventory
	|		INNER JOIN Catalog.Products AS Products
	|		ON DocumentInventory.Product = Products.Ref
	|			AND (Products.ProductType = VALUE(Enum.ProductTypes.Inventory))
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Period,
	|	DocumentInventory.Warehouse
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Supplier AS Counterparty,
	|	DocumentHeader.Ref AS InvoiceDocument,
	|	AdvanceClearing.Document AS Document,
	|	AdvanceClearing.Amount AS Amount
	|INTO DocumentAdvanceClearing
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SupplierInvoice.AdvanceClearing AS AdvanceClearing
	|		ON DocumentHeader.Ref = AdvanceClearing.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.Document AS PurchaseDocument,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity,
	|	SUM(DocumentInventory.Amount) AS Amount,
	|	SUM(DocumentInventory.VATAmount) AS VATAmount
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Counterparty,
	|	DocumentInventory.Period,
	|	DocumentInventory.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductTable.Period AS Period,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.Product AS Product,
	|	ProductTable.Quantity AS Quantity
	|FROM
	|	ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentInventory.Period AS Period,
	|	VALUE(Enum.LiabilityTypes.Liability) AS LiabilityType,
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.Document AS Document,
	|	SUM(DocumentInventory.Total) AS Amount
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Document,
	|	DocumentInventory.Period,
	|	DocumentInventory.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentAdvanceClearing.Period,
	|	VALUE(Enum.LiabilityTypes.Advance),
	|	DocumentAdvanceClearing.Counterparty,
	|	DocumentAdvanceClearing.Document,
	|	SUM(DocumentAdvanceClearing.Amount)
	|FROM
	|	DocumentAdvanceClearing AS DocumentAdvanceClearing
	|
	|GROUP BY
	|	DocumentAdvanceClearing.Document,
	|	DocumentAdvanceClearing.Period,
	|	DocumentAdvanceClearing.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentAdvanceClearing.Period,
	|	VALUE(Enum.LiabilityTypes.Liability),
	|	DocumentAdvanceClearing.Counterparty,
	|	DocumentAdvanceClearing.InvoiceDocument,
	|	SUM(DocumentAdvanceClearing.Amount)
	|FROM
	|	DocumentAdvanceClearing AS DocumentAdvanceClearing
	|
	|GROUP BY
	|	DocumentAdvanceClearing.Period,
	|	DocumentAdvanceClearing.InvoiceDocument,
	|	DocumentAdvanceClearing.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductTable.Period AS Period,
	|	ProductTable.Product AS Product,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.Quantity AS Quantity,
	|	ProductTable.Amount AS Amount
	|FROM
	|	ProductTable AS ProductTable";
	
	Query.SetParameter("Ref", SupplierInvoiceRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult[4].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[5].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableSupplierBalance", QueryResult[6].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[7].Unload());
	
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.PrintManager = "PrintManagement";
	PrintCommand.Id = "Document.SupplierInvoice.PF_MXL_GoodsReceivedNote";
	PrintCommand.Presentation = NStr("en = 'Goods received note'");
	
EndProcedure

// End StandardSubsystems.Print

#EndRegion

#EndIf