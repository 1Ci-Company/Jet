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
	|	DocumentInventory.Warehouse";
	
	Query.SetParameter("Ref", InventoryWriteOffRef);
	
	QueryResult = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#EndIf