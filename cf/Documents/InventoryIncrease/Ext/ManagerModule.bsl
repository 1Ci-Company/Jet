#If Server Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document tabular sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
// Parameters:
//  InventoryIncreaseRef - DocumentRef.InventoryIncrease - ref to Inventory increase.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeDocumentData(InventoryIncreaseRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	InventoryIncrease.Ref AS Ref,
	|	InventoryIncrease.Date AS Date,
	|	InventoryIncrease.Warehouse AS Warehouse
	|INTO DocumentHeader
	|FROM
	|	Document.InventoryIncrease AS InventoryIncrease
	|WHERE
	|	InventoryIncrease.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Warehouse AS Warehouse,
	|	InventoryIncreaseInventory.Product AS Product,
	|	InventoryIncreaseInventory.Quantity AS Quantity
	|INTO DocumentInventory
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|		ON DocumentHeader.Ref = InventoryIncreaseInventory.Ref
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
	
	Query.SetParameter("Ref", InventoryIncreaseRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#EndIf