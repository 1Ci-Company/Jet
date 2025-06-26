#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  InventoryWriteOffRef - DocumentRef.InventoryWriteOff - ref to Inventory write-off.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(InventoryWriteOffRef, AdditionalProperties) Export
	
	DocumentObject = InventoryWriteOffRef.GetObject();
	
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
	|	InventoryWriteOff.Ref AS Ref,
	|	InventoryWriteOff.Date AS Date,
	|	InventoryWriteOff.Warehouse AS Warehouse
	|INTO DocumentHeader
	|FROM
	|	Document.InventoryWriteOff AS InventoryWriteOff
	|WHERE
	|	InventoryWriteOff.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	InventoryWriteOffInventory.Product AS Product,
	|	InventoryWriteOffInventory.Quantity AS Quantity
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|		ON DocumentHeader.Ref = InventoryWriteOffInventory.Ref
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
	|
	|GROUP BY
	|	DocumentInventory.Warehouse,
	|	DocumentInventory.Period,
	|	DocumentInventory.Product
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
	
	Query.SetParameter("Ref", InventoryWriteOffRef);
	Query.SetParameter("PointInTime", New Boundary(DocumentObject.PointInTime(), BoundaryType.Including));
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[5].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCost", QueryResult[6].Unload());
	
EndProcedure

#EndRegion

#EndIf