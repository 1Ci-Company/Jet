
#Region Public

// Fills prices in the document tabular section
//
// Parameters:
//  Form - ClientApplicationForm - document form
//  TabularSectionName - String - name of tabular section
//
Procedure RefillTabularSectionPricesByPriceType(Form, TabularSectionName = "Inventory") Export
	
	Object = Form.Object;
	ProductArray = New Array;
	
	DataStructure = New Structure;
	DataStructure.Insert("Date",			Object.Date);
	DataStructure.Insert("PriceType",		Object.PriceType);
	DataStructure.Insert("ExchangeRate",	Object.ExchangeRate);
	DataStructure.Insert("Multiplier",		Object.Multiplier);
	
	For Each Row In Object[TabularSectionName] Do
		
		If Not ValueIsFilled(Row.Product) Then
			Continue;
		EndIf;
		
		If ProductArray.Find(Row.Product) = Undefined Then
			ProductArray.Add(Row.Product);
		EndIf;
		
	EndDo;
	
	DataStructure.Insert("ProductArray", ProductArray);
	
	ProductPriceMap = PriceManagementServerCall.GetTabularSectionPricesByPriceType(DataStructure);
	
	For Each ProductPriceItem In ProductPriceMap Do
		
		FilterStructure = New Structure("Product", ProductPriceItem.Key);
		RowArray = Object[TabularSectionName].FindRows(FilterStructure);
		For Each Row In RowArray Do
			Row.Price = ProductPriceItem.Value;
			InventoryTabularSectionClient.CalculateAmount(Row);
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion