
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = JetServer.GetPresentationCurrency();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CurrencyOnChange(Item)
	
	DataStructure = New Structure;
	DataStructure.Insert("Currency", Object.Currency);
	DataStructure.Insert("PresentationCurrency", PresentationCurrency);
	DataStructure.Insert("Date", Object.Date);
	
	GetExchangeRateData(DataStructure);
	FillPropertyValues(Object, DataStructure, "ExchangeRate, Multiplier");
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryProductOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	DataStructure = New Structure("Product", CurrentData.Product);
	GetProductData(DataStructure);
	FillPropertyValues(CurrentData, DataStructure);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryTabularSectionClient.CalculateAmount(Items.Inventory.CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	InventoryTabularSectionClient.CalculateAmount(Items.Inventory.CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabSectionRow = Items.Inventory.CurrentData;
	
	If TabSectionRow.Quantity <> 0 Then
		TabSectionRow.Price = Round(TabSectionRow.Amount / TabSectionRow.Quantity, 2);
	EndIf;
	
	InventoryTabularSectionClient.CalculateVATAmountAndTotal(TabSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	InventoryTabularSectionClient.CalculateVATAmountAndTotal(Items.Inventory.CurrentData);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure GetProductData(DataStructure)
	
	If ValueIsFilled(DataStructure.Product) Then
		VATRate = Common.ObjectAttributeValue(DataStructure.Product, "VATRate");
	Else
		VATRate = Catalogs.VATRates.EmptyRef();
	EndIf;
	
	DataStructure.Insert("VATRate", VATRate);
	DataStructure.Insert("Quantity", 1);
	
EndProcedure

&AtServerNoContext
Procedure GetExchangeRateData(DataStructure)
	
	If ValueIsFilled(DataStructure.Currency) And DataStructure.Currency <> DataStructure.PresentationCurrency Then
		ExchRateStructure = CurrencyRateOperations.GetCurrencyRate(DataStructure.Currency, DataStructure.Date);
		DataStructure.Insert("ExchangeRate", ExchRateStructure.Rate);
		DataStructure.Insert("Multiplier", ExchRateStructure.Repetition);
	Else
		DataStructure.Insert("ExchangeRate", 1);
		DataStructure.Insert("Multiplier", 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	If Object.Currency = PresentationCurrency Then
		Items.ExchangeRate.ReadOnly = True;
		Items.Multiplier.ReadOnly = True;
	Else
		Items.ExchangeRate.ReadOnly = False;
		Items.Multiplier.ReadOnly = False;
	EndIf;
	
EndProcedure

#EndRegion
