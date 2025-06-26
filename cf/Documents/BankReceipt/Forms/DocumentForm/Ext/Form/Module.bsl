
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
Procedure BankAccountOnChange(Item)
	
	DataStructure = New Structure("CashBankAccount, Date", Object.BankAccount, Object.Date);
	CashManagementServerCall.CurrencyExchangeRateData(DataStructure);
	FillPropertyValues(Object, DataStructure, "Currency, ExchangeRate, Multiplier");
	
	CashManagementClient.RecalculateAmountAtExchangeRate(Object);
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure ExchangeRateOnChange(Item)
	
	CashManagementClient.RecalculateAmountAtExchangeRate(Object);
	
EndProcedure

&AtClient
Procedure MultiplierOnChange(Item)
	
	CashManagementClient.RecalculateAmountAtExchangeRate(Object);
	
EndProcedure

&AtClient
Procedure OperationOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPaymentDetails

&AtClient
Procedure PaymentDetailsPaymentAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	
	ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
	Multiplier = ?(Object.Multiplier = 0, 1, Object.Multiplier);
	
	CurrentData.Amount = Round(CurrentData.PaymentAmount * ExchangeRate / Multiplier, 2);
	
EndProcedure

&AtClient
Procedure PaymentDetailsAmountOnChange(Item)
	
	CurrentData = Items.PaymentDetails.CurrentData;
	
	ExchangeRate = ?(Object.ExchangeRate = 0, 1, Object.ExchangeRate);
	Multiplier = ?(Object.Multiplier = 0, 1, Object.Multiplier);
	
	CurrentData.PaymentAmount = Round(CurrentData.Amount * Multiplier / ExchangeRate, 2);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

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

&AtClient
Procedure FormManagement()
	
	If Object.Currency = PresentationCurrency Then
		Items.ExchangeRate.ReadOnly = True;
		Items.Multiplier.ReadOnly = True;
	Else
		Items.ExchangeRate.ReadOnly = False;
		Items.Multiplier.ReadOnly = False;
	EndIf;
	
	If Object.Operation = PredefinedValue("Enum.BankReceiptOperations.Other") Then
		Items.Counterparty.Visible = False;
		Items.PaymentDetailsDocument.Visible = False;
	Else
		Items.Counterparty.Visible = True;
		Items.PaymentDetailsDocument.Visible = True;
	EndIf;
	
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

#EndRegion