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
	
	DocumentObject = InventoryTransferRef.GetObject();
	
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
	|	DocumentInventory.Period AS Period,
	|	DocumentInventory.Warehouse AS Warehouse,
	|	DocumentInventory.WarehouseReceiver AS WarehouseReceiver,
	|	DocumentInventory.Product AS Product,
	|	SUM(DocumentInventory.Quantity) AS Quantity
	|INTO ProductTable
	|FROM
	|	DocumentInventory AS DocumentInventory
	|
	|GROUP BY
	|	DocumentInventory.WarehouseReceiver,
	|	DocumentInventory.Warehouse,
	|	DocumentInventory.Product,
	|	DocumentInventory.Period
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
	|	AND InventoryCost.RecordType = VALUE(AccumulationRecordType.Expense)
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
	|	ProductTable.Period AS Period,
	|	ProductTable.Product AS Product,
	|	ProductTable.Warehouse AS Warehouse,
	|	ProductTable.WarehouseReceiver AS WarehouseReceiver,
	|	ProductTable.Quantity AS Quantity,
	|	CASE
	|		WHEN ISNULL(InventoryCostTable.Quantity, 0) = 0
	|			THEN 0
	|		WHEN ProductTable.Quantity = InventoryCostTable.Quantity
	|			THEN InventoryCostTable.Amount
	|		ELSE CAST(InventoryCostTable.Amount * ProductTable.Quantity / InventoryCostTable.Quantity AS NUMBER(15, 2))
	|	END AS Amount
	|INTO ProductTransferTable
	|FROM
	|	ProductTable AS ProductTable
	|		LEFT JOIN InventoryCostTable AS InventoryCostTable
	|		ON ProductTable.Product = InventoryCostTable.Product
	|			AND ProductTable.Warehouse = InventoryCostTable.Warehouse
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
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	ProductTable.Period,
	|	ProductTable.WarehouseReceiver,
	|	ProductTable.Product,
	|	ProductTable.Quantity
	|FROM
	|	ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ProductTransferTable.Period AS Period,
	|	ProductTransferTable.Warehouse AS Warehouse,
	|	ProductTransferTable.Product AS Product,
	|	ProductTransferTable.Quantity AS Quantity,
	|	ProductTransferTable.Amount AS Amount
	|FROM
	|	ProductTransferTable AS ProductTransferTable
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	ProductTransferTable.Period,
	|	ProductTransferTable.WarehouseReceiver,
	|	ProductTransferTable.Product,
	|	ProductTransferTable.Quantity,
	|	ProductTransferTable.Amount
	|FROM
	|	ProductTransferTable AS ProductTransferTable";
	
	Query.SetParameter("Ref", InventoryTransferRef);
	Query.SetParameter("PointInTime", New Boundary(DocumentObject.PointInTime(), BoundaryType.Including));
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[6].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[7].Unload());
	
EndProcedure

#EndRegion

#EndIf