#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  SalesInvoiceRef - DocumentRef.SalesInvoice - ref to sales invoice.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(SalesInvoiceRef, AdditionalProperties) Export
	
	DocumentObject = SalesInvoiceRef.GetObject();
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("AccumulationRegister.InventoryCost");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = DocumentObject.Inventory;
	LockItem.UseFromDataSource("Product", "Product");
	LockItem.SetValue("Warehouse", DocumentObject.Warehouse);
	DataLock.Lock();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Customer AS Customer,
	|	SalesInvoice.Warehouse AS Warehouse,
	|	SalesInvoice.ExchangeRate AS ExchangeRate,
	|	SalesInvoice.Multiplier AS Multiplier
	|INTO DocumentHeader
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Customer AS Counterparty,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	DocumentHeader.Ref AS Document,
	|	SalesInvoiceInventory.Product AS Product,
	|	SalesInvoiceInventory.Quantity AS Quantity,
	|	SalesInvoiceInventory.Amount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Amount,
	|	SalesInvoiceInventory.VATAmount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS VATAmount,
	|	SalesInvoiceInventory.Total * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Total
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON DocumentHeader.Ref = SalesInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity
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
	|	DocumentHeader.Customer AS Counterparty,
	|	DocumentHeader.Ref AS InvoiceDocument,
	|	AdvanceClearing.Document AS Document,
	|	AdvanceClearing.Amount AS Amount
	|INTO DocumentAdvanceClearing
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SalesInvoice.AdvanceClearing AS AdvanceClearing
	|		ON DocumentHeader.Ref = AdvanceClearing.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostBalance.Product AS Product,
	|	InventoryCostBalance.Warehouse AS Warehouse,
	|	InventoryCostBalance.QuantityBalance AS Quantity,
	|	InventoryCostBalance.AmountBalance AS Amount
	|INTO InventoryCostBalance
	|FROM
	|	AccumulationRegister.InventoryCost.Balance(
	|			&PointInTime,
	|			(Product, Warehouse) IN
	|				(SELECT
	|					ProductTable.Product,
	|					ProductTable.Warehouse
	|				FROM
	|					ProductTable AS ProductTable)) AS InventoryCostBalance
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryCost.Product,
	|	InventoryCost.Warehouse,
	|	InventoryCost.Quantity,
	|	InventoryCost.Amount
	|FROM
	|	AccumulationRegister.InventoryCost AS InventoryCost
	|WHERE
	|	InventoryCost.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostBalance.Product AS Product,
	|	InventoryCostBalance.Warehouse AS Warehouse,
	|	SUM(InventoryCostBalance.Quantity) AS Quantity,
	|	SUM(InventoryCostBalance.Amount) AS Amount
	|INTO InventoryCostTable
	|FROM
	|	InventoryCostBalance AS InventoryCostBalance
	|
	|GROUP BY
	|	InventoryCostBalance.Product,
	|	InventoryCostBalance.Warehouse
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.Document AS SalesDocument,
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
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ProductTable.Period AS Period,
	|	ProductTable.Product AS Product,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.Quantity AS Quantity,
	|	CASE
	|		WHEN ISNULL(InventoryCostTable.Quantity, 0) = 0
	|			THEN 0
	|		WHEN ProductTable.Quantity = InventoryCostTable.Quantity
	|			THEN InventoryCostTable.Amount
	|		ELSE CAST(InventoryCostTable.Amount * ProductTable.Quantity / InventoryCostTable.Quantity AS NUMBER(15, 2))
	|	END AS Amount
	|FROM
	|	ProductTable AS ProductTable
	|		LEFT JOIN InventoryCostTable AS InventoryCostTable
	|		ON ProductTable.Product = InventoryCostTable.Product
	|			AND ProductTable.Warehouse = InventoryCostTable.Warehouse";
	
	Query.SetParameter("Ref", SalesInvoiceRef);
	Query.SetParameter("PointInTime", New Boundary(DocumentObject.PointInTime(), BoundaryType.Including));
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult[6].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[7].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableCustomerBalance", QueryResult[8].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[9].Unload());
	
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
	PrintCommand.Id = "Document.SalesInvoice.PF_MXL_SalesInvoice";
	PrintCommand.Presentation = NStr("en = 'Sales invoice'");
	
EndProcedure

// End StandardSubsystems.Print

#EndRegion

#EndIf