
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PresentationCurrency = JetServer.GetPresentationCurrency();
	Company = Catalogs.Companies.MainCompany;
	
	// EDI
	EDIProfile = Catalogs.EDIProfiles.GetEDIProfile(Company);
	UseEDIExchange = ValueIsFilled(EDIProfile.Ref);
	
	EDIParametersOnCreate = EDIServer.EDIParameters();
	EDIParametersOnCreate.Form = ThisObject;
	EDIParametersOnCreate.Ref = Object.Ref;
	EDIParametersOnCreate.StateDecoration = Items.EDIStateDecoration;
	EDIParametersOnCreate.StateGroup = Items.EDIStateGroup;
	EDIParametersOnCreate.ResponseStatusDecoration = Items.EDIResponseStatusDecoration;
	EDIParametersOnCreate.ResponseStatusGroup = Items.EDIResponseStatusGroup;
	EDIServer.OnCreateAtServer_DocumentForm(EDIParametersOnCreate);
	// End EDI
	
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
	
	// EDI
	If UseEDIExchange Then
		If ValueIsFilled(Object.Ref) Then
			FillIdentifier();
		Else
			SetTaxpayer();
		EndIf;
	EndIf;
	// End EDI
	
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
	
	// EDI
	EDINotificationParameters = EDIClient.ParametersNotificationProcessing();
	EDINotificationParameters.Form = ThisObject;
	EDINotificationParameters.Ref = Object.Ref;
	EDINotificationParameters.StateDecoration = Items.EDIStateDecoration;
	EDINotificationParameters.StateGroup = Items.EDIStateGroup;
	EDINotificationParameters.ResponseStatusDecoration = Items.EDIResponseStatusDecoration;
	EDINotificationParameters.ResponseStatusGroup = Items.EDIResponseStatusGroup;
	EDIClient.NotificationProcessing_DocumentForm(EventName, Parameter, Source, EDINotificationParameters);
	// End EDI
	
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
		MessageText = NStr("en = 'The invoice amount is less than the clearing amount.'; tr = 'Fatura tutarı, mahsup tutarından düşük.'");
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

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// EDI
	EDIAfterWriteParameters = EDIServer.EDIParameters();
	EDIAfterWriteParameters.Form = ThisObject;
	EDIAfterWriteParameters.Ref = Object.Ref;
	EDIAfterWriteParameters.StateDecoration = Items.EDIStateDecoration;
	EDIAfterWriteParameters.StateGroup = Items.EDIStateGroup;
	EDIAfterWriteParameters.ResponseStatusDecoration = Items.EDIResponseStatusDecoration;
	EDIAfterWriteParameters.ResponseStatusGroup = Items.EDIResponseStatusGroup;
	EDIServer.AfterWriteAtServer_DocumentForm(CurrentObject, EDIAfterWriteParameters);
	// End EDI
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// EDI
	If Modified Or WriteParameters.WriteMode = DocumentWriteMode.UndoPosting Then
		EDIClient.DocumentWasChanged(Object.Ref);
	EndIf;
	// End EDI
	
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
	
	// EDI
	If UseEDIExchange Then
		SetTaxpayer();
	EndIf;
	// End EDI
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure PriceTypeOnChange(Item)
	
	If ValueIsFilled(Object.PriceType) Then
		PriceManagementClient.RefillTabularSectionPricesByPriceType(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExemptFromVATOnChange(Item)
	
	If Object.ExemptFromVAT Then
		Object.VATWithholding = False;
	EndIf;
	
	FillVATRateByVATExemption();
	FormManagement();
	
EndProcedure

&AtClient
Procedure VATWithholdingOnChange(Item)
	
	If Object.VATWithholding Then
		FillInventoryByVATWithholding();
	Else
		FillVATRateByVATExemption();
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure UseTaxExemptionReasonOnChange(Item)
	
	If Not Object.UseTaxExemptionReason Then
		For Each Row In Object.Inventory Do
			Row.TaxExemptionReason = Undefined;
		EndDo;
	EndIf;
	
	FormManagement();
	
EndProcedure

// EDI
&AtClient
Procedure EDIStateDecorationClick(Item)
	
	EDIClient.EDIStateDecorationClick(ThisObject, Item);
	
EndProcedure
// End EDI

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
	DataStructure.Insert("ExemptFromVAT", Object.ExemptFromVAT);
	DataStructure.Insert("VATWithholding", Object.VATWithholding);
	DataStructure.Insert("TaxExemptionReason", CurrentData.TaxExemptionReason);
	
	GetProductData(DataStructure);
	
	FillPropertyValues(CurrentData, DataStructure);
	
	InventoryTabularSectionClientServer.CalculateAmount(CurrentData, Object.VATWithholding);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryTabularSectionClientServer.CalculateAmount(Items.Inventory.CurrentData, Object.VATWithholding);
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	InventoryTabularSectionClientServer.CalculateAmount(Items.Inventory.CurrentData, Object.VATWithholding);
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabSectionRow = Items.Inventory.CurrentData;
	
	If TabSectionRow.Quantity <> 0 Then
		TabSectionRow.Price = Round(TabSectionRow.Amount / TabSectionRow.Quantity, 2);
	EndIf;
	
	InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(TabSectionRow, Object.VATWithholding);
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(CurrentData, Object.VATWithholding);
	
	If ValueIsFilled(CurrentData.TaxExemptionReason) And JetServerCall.GetVATRateValue(CurrentData.VATRate) <> 0 Then
		CurrentData.TaxExemptionReason = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryVATWithholdingCodeOnChange(Item)
	
	TabSectionRow = Items.Inventory.CurrentData;
	TabSectionRow.VATWithholdingRate = VATWithholdingServerCall.GetVATWithholdingRate(TabSectionRow.VATWithholdingCode);
	InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(TabSectionRow, Object.VATWithholding);
	
EndProcedure

&AtClient
Procedure InventoryTaxExemptionReasonStartChoice(Item, ChoiceData, ChoiceByAdding, StandardProcessing)
	
	CurrentData = Items.Inventory.CurrentData;
	
	Rate = JetServerCall.GetVATRateValue(CurrentData.VATRate);
	If Rate <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Tax exemption reason is inapplicable for VAT rate %1.'; tr = '%1 KDV oranı için vergi muafiyeti sebebi uygulanamaz.'"),
			CurrentData.VATRate);
		CommonClient.MessageToUser(MessageText);
		StandardProcessing = False;
	EndIf;
	
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
		ShowMessageBox(, NStr("en = 'Please specify the customer.'; tr = 'Lütfen, müşteri belirtin.'"));
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
	ImportParameters.Title = NStr("en = 'Import inventory from file'; tr = 'Stoğu dosyadan içe aktar'");
	
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

// EDI
&AtClient
Procedure EInvoiceCreate(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.CreateDocument");
	CommandParameters.Insert("Title", Items.FormEInvoiceCreate.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoicePrint(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.PrintDocument");
	CommandParameters.Insert("Title", Items.FormEInvoicePrint.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoiceSubmit(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.SendDocument");
	CommandParameters.Insert("Title", Items.FormEInvoiceSubmit.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoiceRefreshStatus(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.GetInvoiceStatus");
	CommandParameters.Insert("Title", Items.FormEInvoiceRefreshStatus.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoiceDelete(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.DeleteEDocument");
	CommandParameters.Insert("Title", Items.FormEInvoiceDelete.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoiceCancel(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.CancelEDocument");
	CommandParameters.Insert("Title", Items.FormEInvoiceCancel.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure

&AtClient
Procedure EInvoiceDownload(Command)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("CommandID", Command.Name);
	CommandParameters.Insert("Handler", "EDIServer.DownloadDocument");
	CommandParameters.Insert("Title", Items.FormEInvoiceDownload.Title);
	CommandParameters.Insert("Form", ThisObject);
	CommandParameters.Insert("Ref", Object.Ref);
	
	EDIClient.EDIExecuteCommand(CommandParameters);
	
EndProcedure
// End EDI

&AtClient
Procedure FillInTaxExemptionReasons(Command)
	
	FillInReasonsProcessing();
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure GetProductData(DataStructure)
	
	ProductAttributes = New Structure;
	ProductAttributes.Insert("VATRate", Catalogs.VATRates.EmptyRef());
	ProductAttributes.Insert("VATWithholdingCode", Catalogs.VATWithholdingCodes.EmptyRef());
	ProductAttributes.Insert("VATWithholdingRate", Catalogs.VATWithholdingRates.EmptyRef());
	
	If ValueIsFilled(DataStructure.Product) Then
		ProductAttributes = Common.ObjectAttributesValues(DataStructure.Product, "VATRate,VATWithholdingCode,VATWithholdingRate");
	EndIf;
	
	If DataStructure.Property("ExemptFromVAT") And DataStructure.ExemptFromVAT Then
		DataStructure.Insert("VATRate", Catalogs.VATRates.GetExemptFromVATRate());
	Else
		DataStructure.Insert("VATRate", ProductAttributes.VATRate);
	EndIf;
	
	DataStructure.Insert("Quantity", 1);
	
	Price = PriceManagementServerCall.GetProductPriceByPriceType(DataStructure);
	DataStructure.Insert("Price", Price);
	
	If DataStructure.Property("VATWithholding") And DataStructure.VATWithholding Then
		DataStructure.Insert("VATWithholdingCode", ProductAttributes.VATWithholdingCode);
		DataStructure.Insert("VATWithholdingRate", ProductAttributes.VATWithholdingRate);
	EndIf;
	
	If ValueIsFilled(DataStructure.TaxExemptionReason) And JetServerCall.GetVATRateValue(DataStructure.VATRate) <> 0 Then
		DataStructure.Insert("TaxExemptionReason", Catalogs.TaxExemptionReasons.EmptyRef());
	EndIf;
	
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
				NStr("en = 'Amount (%1)'; tr = 'Tutar (%1)'"),
				Object.Currency);
	EndIf;
	
	SubjectToVAT = Not Object.ExemptFromVAT;
	
	Items.InventoryVATRate.Visible		= SubjectToVAT;
	Items.InventoryVATAmount.Visible	= SubjectToVAT;
	Items.InventoryTotal.Visible		= SubjectToVAT;
	Items.TotalVATAmount.Visible		= SubjectToVAT;
	Items.TotalTotal.Visible			= SubjectToVAT;
	
#If MobileClient Then
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "Title", NStr("en = 'Totals'; tr = 'Toplamlar'"));
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "Behavior", UsualGroupBehavior.Collapsible);
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "ShowTitle", True);
	CommonClientServer.SetFormItemProperty(Items, "GroupTotal", "ControlRepresentation", UsualGroupControlRepresentation.TitleHyperlink);
	Items.GroupTotal.Hide();
	
	Items.InventoryImportInventoryFromFile.Visible = False;
#EndIf
	
	// VATWithholding
	Items.VATWithholding.Visible = SubjectToVAT;
	
	Items.InventoryVATWithholdingGroup.Visible = Object.VATWithholding;
	Items.InventoryVATTotal.Visible = Object.VATWithholding;
	Items.TotalVATWithholdingAmount.Visible = Object.VATWithholding;
	
	If Object.VATWithholding Then
		VATTitle = NStr("en = 'VAT invoiced'; tr = 'Faturalanmış KDV'");
	Else
		VATTitle = NStr("en = 'VAT amount'; tr = 'KDV tutarı'");
	EndIf;
	
	Items.InventoryVATAmount.Title = VATTitle;
	Items.TotalVATAmount.Title = VATTitle;
	
	// TaxExemptionReason
	Items.InventoryTaxExemptionReason.Visible = Object.UseTaxExemptionReason;
	Items.InventoryFillInTaxExemptionReasons.Visible = Object.UseTaxExemptionReason;
	
	// EDI
	CommonClientServer.SetFormItemProperty(Items, "GroupEInvoiceInfo", "Visible", UseEDIExchange);
	CommonClientServer.SetFormItemProperty(Items, "EDISubmenu", "Visible", UseEDIExchange);
	CommonClientServer.SetFormItemProperty(Items, "GroupEInvoice", "Visible", Object.IsEInvoice);
	// End EDI
	
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

&AtServer
Procedure FillVATRateByVATExemption()
	
	If Object.ExemptFromVAT Then
		
		ExemptFromVATRate = Catalogs.VATRates.GetExemptFromVATRate();
		
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.VATRate = ExemptFromVATRate;
			InventoryRow.VATAmount = 0;
			InventoryRow.VATWithholdingAmount = 0;
			InventoryRow.VATTotal = 0;
			InventoryRow.Total = InventoryRow.Amount;
		EndDo;
	Else
		For Each InventoryRow In Object.Inventory Do
			InventoryRow.VATRate = InventoryRow.Product.VATRate;
			InventoryTabularSectionClientServer.CalculateVATAmountAndTotal(InventoryRow, Object.VATWithholding);
			If ValueIsFilled(InventoryRow.TaxExemptionReason) And JetServerCall.GetVATRateValue(InventoryRow.VATRate) <> 0 Then
				InventoryRow.TaxExemptionReason = Catalogs.TaxExemptionReasons.EmptyRef();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInventoryByVATWithholding()
	
	If Not Object.VATWithholding Then
		Return;
	EndIf;
	
	ProductTable = Object.Inventory.Unload(, "Product,VATAmount");
	
	Query = New Query;
	Query.SetParameter("ProductTable", ProductTable);
	Query.Text =
	"SELECT DISTINCT
	|	ProductTable.Product AS Product,
	|	ProductTable.VATAmount AS VATAmount
	|INTO TempProductTable
	|FROM
	|	&ProductTable AS ProductTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductTable.Product AS Product,
	|	ProductTable.VATAmount AS VATAmount,
	|	Products.VATWithholdingCode AS VATWithholdingCode,
	|	Products.VATWithholdingRate AS VATWithholdingRate,
	|	CASE
	|		WHEN ISNULL(VATWithholdingRates.RateDenominator, 0) = 0
	|			THEN 0
	|		ELSE ProductTable.VATAmount * VATWithholdingRates.RateNumerator / VATWithholdingRates.RateDenominator
	|	END AS VATWithholdingAmount
	|FROM
	|	TempProductTable AS ProductTable
	|		INNER JOIN Catalog.Products AS Products
	|		ON ProductTable.Product = Products.Ref
	|		LEFT JOIN Catalog.VATWithholdingRates AS VATWithholdingRates
	|		ON (Products.VATWithholdingRate = VATWithholdingRates.Ref)";
	
	ProductVATWithholding = Query.Execute().Unload();
	For Each Row In ProductVATWithholding Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Product", Row.Product);
		SearchStructure.Insert("VATAmount", Row.VATAmount);
		
		InventoryRows = Object.Inventory.FindRows(SearchStructure);
		For Each InventoryRow In InventoryRows Do
			
			InventoryRow.VATWithholdingCode = Row.VATWithholdingCode;
			InventoryRow.VATWithholdingRate = Row.VATWithholdingRate;
			InventoryRow.VATWithholdingAmount = Row.VATWithholdingAmount;
			InventoryRow.VATAmount = Row.VATAmount - Row.VATWithholdingAmount;
			InventoryRow.VATTotal = InventoryRow.VATAmount + InventoryRow.VATWithholdingAmount;
			InventoryRow.Total = InventoryRow.Amount + InventoryRow.VATAmount;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Async Procedure FillInReasonsProcessing()
	
	If Object.Inventory.Count() > 0 Then
		Reason = PredefinedValue("Catalog.TaxExemptionReasons.EmptyRef");
		Reason = Await InputValueAsync(Reason, NStr("en = 'Select the tax exemption reason'; tr = 'Vergi muafiyeti sebebini seçin'"));
		If ValueIsFilled(Reason) Then
			FillInReasonsAtServer(Reason)
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInReasonsAtServer(Reason)
	
	For Each Row In Object.Inventory Do
		If JetServerCall.GetVATRateValue(Row.VATRate) = 0 Then
			Row.TaxExemptionReason = Reason;
		Else
			Row.TaxExemptionReason = Catalogs.TaxExemptionReasons.EmptyRef();
		EndIf;
	EndDo;
	
EndProcedure

// EDI
&AtClient
Procedure SetTaxpayer()
	
	If UseEDIExchange And ValueIsFilled(Object.Customer) Then
		
		CustomerAttributes = GetCustomerAttributes(Object.Customer, "TIN,EDocumentScenario");
		
		TaxpayerStructure = EDIClientServer.IsTaxpayer(CustomerAttributes.TIN, PredefinedValue("Enum.EDocumentType.EInvoice"));
		
		If Not TaxpayerStructure.Result And ValueIsFilled(CustomerAttributes.TIN) Then
			
			CheckTaxpayer = EDIClient.CheckCounterpartyIsTaxpayer(Company, CustomerAttributes.TIN);
			TaxpayerStructure.Result = CheckTaxpayer.IsTaxpayer;
			TaxpayerStructure.IsPublicEstablishment = CheckTaxpayer.IsPublicEstablishment;
			
		EndIf;
		
		Object.IsEInvoice = TaxpayerStructure.Result;
		
		If Object.IsEInvoice Then
			
			FillIdentifier();
			
			If TaxpayerStructure.IsPublicEstablishment Then
				Object.EDocumentScenario = PredefinedValue("Enum.EDocumentScenario.KAMU");
			ElsIf EDIProfile.UseEInvoice
				And CommonClient.SessionDate() > EDIProfile.EInvoiceStartDate
				And IsBlankString(Object.EDocumentNumber) Then
				Object.EDocumentScenario = ?(ValueIsFilled(CustomerAttributes.EDocumentScenario),
					CustomerAttributes.EDocumentScenario,
					EDIProfile.EDocumentScenario);
			EndIf;
			
		Else
			Object.EDocumentScenario = PredefinedValue("Enum.EDocumentScenario.EmptyRef");
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillIdentifier()
	
	If Object.IsEInvoice Then
		
		Items.Identifier.ChoiceList.Clear();
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	TaxpayerList.Identifier AS Identifier,
		|	TaxpayerList.RegisterDate AS RegisterDate
		|FROM
		|	InformationRegister.TaxpayerList AS TaxpayerList
		|WHERE
		|	TaxpayerList.TIN = &TIN
		|	AND TaxpayerList.EDocumentType = &EDocumentType
		|
		|ORDER BY
		|	TaxpayerList.RegisterDate";
		
		Query.SetParameter("EDocumentType", Enums.EDocumentType.EInvoice);
		Query.SetParameter("TIN", Object.Customer.TIN);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ItemTitle = String((Selection.Identifier)) + " <" + String(Selection.RegisterDate) + ">";
			Items.Identifier.ChoiceList.Add(Selection.Identifier, ItemTitle);
		EndDo;
		
		If Not ValueIsFilled(Object.Ref) Or IsBlankString(Object.Identifier) Then
			Object.Identifier = Selection.Identifier;
		EndIf;
		
	EndIf;
	
EndProcedure
// End EDI

&AtServerNoContext
Function GetCustomerAttributes(Customer, Attributes)
	
	If ValueIsFilled(Customer) Then
		Return Common.ObjectAttributesValues(Customer, Attributes);
	Else
		CustomerAttributes = New Structure(Attributes);
		FillPropertyValues(CustomerAttributes, Catalogs.Counterparties.EmptyRef());
		Return CustomerAttributes;
	EndIf;
	
EndFunction

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
		
		InventoryTabularSectionClientServer.CalculateAmount(NewRow, Object.VATWithholding);
		
		Modified = True;
		
	EndDo;
	
EndProcedure

// End StandardSubsystems.ImportDataFromFile

#EndRegion
