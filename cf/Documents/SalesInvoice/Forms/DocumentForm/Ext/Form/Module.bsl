
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = JetServer.GetPresentationCurrency();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.AfterWrite(ThisObject, Object, WriteParameters);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.Inventory.Total("Total") < Object.AdvanceClearing.Total("AmountCur") Then
		MessageText = NStr("en = 'The invoice amount is less than the clearing amount.'");
		Common.MessageToUser(MessageText,,,, Cancel);
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
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

&AtClient
Procedure CustomerOnChange(Item)
	
	PriceType = GetCustomerPriceType(Object.Customer);
	If ValueIsFilled(PriceType) Then
		Object.PriceType = PriceType;
		PriceManagementClient.RefillTabularSectionPricesByPriceType(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure PriceTypeOnChange(Item)
	
	If ValueIsFilled(Object.PriceType) Then
		PriceManagementClient.RefillTabularSectionPricesByPriceType(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryProductOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	DataStructure = New Structure;
	DataStructure.Insert("Product", CurrentData.Product);
	DataStructure.Insert("PriceType", Object.PriceType);
	DataStructure.Insert("Date", Object.Date);
	DataStructure.Insert("ExchangeRate", Object.ExchangeRate);
	DataStructure.Insert("Multiplier", Object.Multiplier);
	
	GetProductData(DataStructure);
	
	FillPropertyValues(CurrentData, DataStructure);
	
	InventoryTabularSectionClientServer.CalculateAmount(CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryTabularSectionClientServer.CalculateAmount(Items.Inventory.CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	InventoryTabularSectionClientServer.CalculateAmount(Items.Inventory.CurrentData);
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabSectionRow = Items.Inventory.CurrentData;
	
	If TabSectionRow.Quantity <> 0 Then
		TabSectionRow.Price = Round(TabSectionRow.Amount / TabSectionRow.Quantity, 2);
	EndIf;
	
	InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(TabSectionRow);
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(Items.Inventory.CurrentData);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAdvanceClearing

&AtClient
Procedure AdvanceClearingAmountOnChange(Item)
	
	CurrentData = Items.AdvanceClearing.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.AmountCur = JetClientServer.CalculateFromCurrencyToCurrency(CurrentData.Amount,
			1,
			1,
			Object.ExchangeRate,
			Object.Multiplier);
	EndIf;
	
EndProcedure

&AtClient
Procedure AdvanceClearingAmountCurOnChange(Item)
	
	CurrentData = Items.AdvanceClearing.CurrentData;
	If CurrentData <> Undefined Then
		CurrentData.Amount = JetClientServer.CalculateFromCurrencyToCurrency(CurrentData.AmountCur,
			Object.ExchangeRate,
			Object.Multiplier);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectAdvances(Command)
	
	If Not ValueIsFilled(Object.Customer) Then
		ShowMessageBox(, NStr("en = 'Please specify the customer.'"));
		Return;
	EndIf;
	
	AddressInStorage = PutAdvanceClearingToStorage();
	
	FormParameters = New Structure;
	FormParameters.Insert("AddressInStorage", AddressInStorage);
	FormParameters.Insert("InvoiceRef", Object.Ref);
	FormParameters.Insert("Counterparty", Object.Customer);
	FormParameters.Insert("Currency", Object.Currency);
	FormParameters.Insert("ExchangeRate", Object.ExchangeRate);
	FormParameters.Insert("Multiplier", Object.Multiplier);
	FormParameters.Insert("InvoiceAmount", Object.Inventory.Total("Total"));
	FormParameters.Insert("IsCustomerAdvance", True);
	
	SelectAdvancesOnClose = New CallbackDescription("SelectAdvancesOnClose",
		ThisObject,
		New Structure("AddressInStorage", AddressInStorage));
	
	OpenForm("CommonForm.SelectAdvances", FormParameters,,,,, SelectAdvancesOnClose);
	
EndProcedure

// StandardSubsystems.ImportDataFromFile
&AtClient
Procedure ImportInventoryFromFile(Command)
	
	ImportParameters = ImportDataFromFileClient.DataImportParameters();
	ImportParameters.FullTabularSectionName = "SalesInvoice.Inventory";
	ImportParameters.Title = NStr("en = 'Import inventory from file'");
	
	CallbackDescription = New CallbackDescription("ImportInventoryFromFileEnd", ThisObject);
	
	ImportDataFromFileClient.ShowImportForm(ImportParameters, CallbackDescription);
	
EndProcedure
// End StandardSubsystems.ImportDataFromFile

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure
// End StandardSubsystems.Properties

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
	
	Price = PriceManagementServerCall.GetProductPriceByPriceType(DataStructure);
	DataStructure.Insert("Price", Price);
	
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

&AtServerNoContext
Function GetCustomerPriceType(Customer)
	
	If ValueIsFilled(Customer) Then
		PriceType = Common.ObjectAttributeValue(Customer, "PriceType");
	Else
		PriceType = Catalogs.PriceTypes.EmptyRef();
	EndIf;
	
	Return PriceType;
	
EndFunction

&AtClient
Procedure FormManagement()
	
	If Object.Currency = PresentationCurrency Then
		Items.ExchangeRate.ReadOnly = True;
		Items.Multiplier.ReadOnly = True;
		Items.AdvanceClearingAmountCur.Visible = False;
	Else
		Items.ExchangeRate.ReadOnly = False;
		Items.Multiplier.ReadOnly = False;
		Items.AdvanceClearingAmountCur.Visible = True;
		Items.AdvanceClearingAmountCur.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Amount (%1)'"),
				Object.Currency);
	EndIf;
	
#If MobileClient Then
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "Title", NStr("en = 'Totals'"));
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "Behavior", UsualGroupBehavior.Collapsible);
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "ShowTitle", True);
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "ControlRepresentation", UsualGroupControlRepresentation.TitleHyperlink);
	Items.GroupTotal.Hide();
	
	Items.InventoryImportInventoryFromFile.Visible = False;
#EndIf

EndProcedure

&AtClient
Procedure SelectAdvancesOnClose(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		AddressInStorage = AdditionalParameters.AddressInStorage;
		GetAdvanceClearingFromStorage(AddressInStorage);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Function PutAdvanceClearingToStorage()
	
	Return PutToTempStorage(Object.AdvanceClearing.Unload(), UUID);
	
EndFunction

&AtServer
Procedure GetAdvanceClearingFromStorage(AddressInStorage)
	
	AdvanceTable = GetFromTempStorage(AddressInStorage);
	Object.AdvanceClearing.Load(AdvanceTable);
	
EndProcedure

// StandardSubsystems.Properties
&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure
// End StandardSubsystems.Properties

// StandardSubsystems.ImportDataFromFile

&AtClient
Procedure ImportInventoryFromFileEnd(ImportedDataAddress, AdditionalParameters) Export
	
	If ImportedDataAddress = Undefined Then
		Return;
	EndIf;
	
	ImportInventoryFromFileAtServer(ImportedDataAddress);
	
EndProcedure

&AtServer
Procedure ImportInventoryFromFileAtServer(ImportedDataAddress)
	
	ImportedData = GetFromTempStorage(ImportedDataAddress);
	
	For Each TableRow In ImportedData Do
		
		If Not ValueIsFilled(TableRow.Product) Then 
			Continue;
		EndIf;
		
		NewRow = Object.Inventory.Add();
		NewRow.Product = TableRow.Product;
		NewRow.Quantity = TableRow.Quantity;
		NewRow.Price = TableRow.Price;
		NewRow.VATRate = TableRow.VATRate;
		
		InventoryTabularSectionClientServer.CalculateAmount(NewRow);
		
		Modified = True;
		
	EndDo;
	
EndProcedure

// End StandardSubsystems.ImportDataFromFile

#EndRegion
