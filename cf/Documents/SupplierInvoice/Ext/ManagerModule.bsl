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
	|	DocumentHeader.Ref AS PurchaseDocument,
	|	SupplierInvoiceInventory.Product AS Product,
	|	SupplierInvoiceInventory.Quantity AS Quantity,
	|	SupplierInvoiceInventory.Amount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS Amount,
	|	SupplierInvoiceInventory.VATAmount * DocumentHeader.ExchangeRate / DocumentHeader.Multiplier AS VATAmount
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
	|	DocumentInventory.Counterparty AS Counterparty,
	|	DocumentInventory.PurchaseDocument AS PurchaseDocument,
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
	|	DocumentInventory.PurchaseDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Period,
	|	DocumentInventory.Warehouse";
	
	Query.SetParameter("Ref", SupplierInvoiceRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult[2].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[3].Unload());
	
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