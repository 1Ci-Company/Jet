#If Server Or ExternalConnection Then

#Region Public

// Controls the occurrence of negative balances.
//
// Parameters:
//  Ref - DocumentRef - ref to the posting document;
//  AdditionalProperties - Structure - additional properties;
//  Cancel - boolean - if this parameter is set to True, the document will not be posted.
//
Procedure NegativeBalanceControl(Ref, AdditionalProperties, Cancel) Export
	
	If AdditionalProperties.ForPosting.IsInventoryInWarehousesChange Then
		
		Query = New Query;
		Query.TempTablesManager = AdditionalProperties.ForPosting.TempTablesManager;
		Query.Text =
		"SELECT
		|	InventoryInWarehousesChange.Warehouse AS Warehouse,
		|	InventoryInWarehousesChange.Product AS Product,
		|	Products.Unit AS Unit,
		|	-InventoryInWarehousesBalance.QuantityBalance AS Shortage
		|FROM
		|	InventoryInWarehousesChange AS InventoryInWarehousesChange
		|		INNER JOIN Catalog.Products AS Products
		|		ON InventoryInWarehousesChange.Product = Products.Ref
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(, ) AS InventoryInWarehousesBalance
		|		ON InventoryInWarehousesChange.Warehouse = InventoryInWarehousesBalance.Warehouse
		|			AND InventoryInWarehousesChange.Product = InventoryInWarehousesBalance.Product
		|			AND (InventoryInWarehousesBalance.QuantityBalance < 0)
		|TOTALS BY
		|	Warehouse";
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			
			WarehouseSelection = Result.Select(QueryResultIteration.ByGroups);
			While WarehouseSelection.Next() Do
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Insufficient quantity on %1'"),
					WarehouseSelection.Warehouse);
				Common.MessageToUser(MessageText, Ref, , , Cancel);
				
				Selection = WarehouseSelection.Select();
				While Selection.Next() Do
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Product: %1, shortage %2 %3'"),
						Selection.Product,
						Selection.Shortage,
						Selection.Unit);
					Common.MessageToUser(MessageText, Ref, , , Cancel);
				EndDo;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf