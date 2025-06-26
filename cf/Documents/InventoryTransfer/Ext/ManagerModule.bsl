#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  InventoryTransferRef - DocumentRef.InventoryTransfer - ref to Inventory transfer.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(InventoryTransferRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryTransfer.Ref AS Ref,
	|	InventoryTransfer.Date AS Date,
	|	InventoryTransfer.Warehouse AS Warehouse,
	|	InventoryTransfer.WarehouseReceiver AS WarehouseReceiver
	|INTO DocumentHeader
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	DocumentHeader.WarehouseReceiver AS WarehouseReceiver,
	|	InventoryTransferInventory.Product AS Product,
	|	InventoryTransferInventory.Quantity AS Quantity
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|		ON DocumentHeader.Ref = InventoryTransferInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
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
	|	DocumentInventory.Warehouse
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentInventory.Period,
	|	DocumentInventory.WarehouseReceiver,
	|	DocumentInventory.Product,
	|	SUM(DocumentInventory.Quantity)
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.Product,
	|	DocumentInventory.Period,
	|	DocumentInventory.WarehouseReceiver";
	
	Query.SetParameter("Ref", InventoryTransferRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#EndIf