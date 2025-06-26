
#Region Public

// Gets price by price type and product
//
// Parameters:
//  DataStructure - Structure - parameters of getting
//
// Returns:
//  Number - price
//
Function GetProductPriceByPriceType(DataStructure) Export
	
	Price = 0;
	
	If Not (ValueIsFilled(DataStructure.Product) And ValueIsFilled(DataStructure.PriceType)) Then
		Return Price;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PricesSliceLast.Price * &DocumentRepetition / &DocumentRate AS Price
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&PriceDate,
	|			PriceType = &PriceType
	|				AND Product = &Product) AS PricesSliceLast";
	
	Query.SetParameter("PriceDate",				BegOfDay(DataStructure.Date));
	Query.SetParameter("Product",				DataStructure.Product);
	Query.SetParameter("PriceType",				DataStructure.PriceType);
	Query.SetParameter("DocumentRate",			?(DataStructure.ExchangeRate = 0, 1, DataStructure.ExchangeRate));
	Query.SetParameter("DocumentRepetition",	?(DataStructure.Multiplier = 0, 1, DataStructure.Multiplier));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Price = Selection.Price;
	EndIf;
	
	Return Price;
	
EndFunction

// Gets price by price type and product array
//
// Parameters:
//  DataStructure - Structure - parameters of getting
//
// Returns:
//  Map - key and value collection (Product and Price)
//
Function GetTabularSectionPricesByPriceType(DataStructure) Export
	
	ProductPriceMap = New Map;
	
	If Not ValueIsFilled(DataStructure.PriceType) Then
		Return ProductPriceMap;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PricesSliceLast.Product AS Product,
	|	PricesSliceLast.Price * &DocumentRepetition / &DocumentRate AS Price
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&PriceDate,
	|			PriceType = &PriceType
	|				AND Product IN (&ProductArray)) AS PricesSliceLast";
	
	Query.SetParameter("PriceDate",				BegOfDay(DataStructure.Date));
	Query.SetParameter("PriceType",				DataStructure.PriceType);
	Query.SetParameter("DocumentRate",			?(DataStructure.ExchangeRate = 0, 1, DataStructure.ExchangeRate));
	Query.SetParameter("DocumentRepetition",	?(DataStructure.Multiplier = 0, 1, DataStructure.Multiplier));
	Query.SetParameter("ProductArray",			DataStructure.ProductArray);
	
	PriceTable = Query.Execute().Unload();
	PriceTable.Indexes.Add("Product");
	
	For Each Product In DataStructure.ProductArray Do
		
		If ProductPriceMap.Get(Product) = Undefined Then
			
			PriceRow = PriceTable.Find(Product, "Product");
			If PriceRow = Undefined Then
				Price = 0;
			Else
				Price = PriceRow.Price;
			EndIf;
			
			ProductPriceMap.Insert(Product, Price);
			
		EndIf;
		
	EndDo;
	
	Return ProductPriceMap;
	
EndFunction

#EndRegion