#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Or Not AdditionalProperties.Property("ForPosting") Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryInWarehouses.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.TempTablesManager;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT
	|	InventoryInWarehouses.Warehouse AS Warehouse,
	|	InventoryInWarehouses.Product AS Product,
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN InventoryInWarehouses.Quantity
	|		ELSE -InventoryInWarehouses.Quantity
	|	END AS Quantity
	|INTO InventoryInWarehousesBeforeWrite
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	InventoryInWarehouses.Recorder = &Recorder";
	
	Query.Execute();
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Or Not AdditionalProperties.Property("ForPosting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.TempTablesManager;
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.Text =
	"SELECT
	|	InventoryInWarehousesBeforeWrite.Warehouse AS Warehouse,
	|	InventoryInWarehousesBeforeWrite.Product AS Product,
	|	InventoryInWarehousesBeforeWrite.Quantity AS QuantityChange
	|INTO PrevInventoryInWarehousesChange
	|FROM
	|	InventoryInWarehousesBeforeWrite AS InventoryInWarehousesBeforeWrite
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryInWarehouses.Warehouse,
	|	InventoryInWarehouses.Product,
	|	CASE
	|		WHEN InventoryInWarehouses.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -InventoryInWarehouses.Quantity
	|		ELSE InventoryInWarehouses.Quantity
	|	END
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	InventoryInWarehouses.Recorder = &Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrevInventoryInWarehousesChange.Warehouse AS Warehouse,
	|	PrevInventoryInWarehousesChange.Product AS Product,
	|	SUM(PrevInventoryInWarehousesChange.QuantityChange) AS QuantityChange
	|INTO InventoryInWarehousesChange
	|FROM
	|	PrevInventoryInWarehousesChange AS PrevInventoryInWarehousesChange
	|
	|GROUP BY
	|	PrevInventoryInWarehousesChange.Warehouse,
	|	PrevInventoryInWarehousesChange.Product
	|
	|HAVING
	|	SUM(PrevInventoryInWarehousesChange.QuantityChange) <> 0
	|
	|INDEX BY
	|	Warehouse,
	|	Product
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(*) AS ChangeCount
	|FROM
	|	InventoryInWarehousesChange AS InventoryInWarehousesChange
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP PrevInventoryInWarehousesChange
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP InventoryInWarehousesBeforeWrite";
	
	QueryResult = Query.ExecuteBatch();
	
	Selection = QueryResult[2].Select();
	Selection.Next();
	
	AdditionalProperties.ForPosting.Insert("IsInventoryInWarehousesChange", Selection.ChangeCount > 0);
	
EndProcedure

#EndRegion

#EndIf