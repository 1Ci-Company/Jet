
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
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

#Region FormTableItemsEventHandlersInventory

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmount();
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmount();
	
EndProcedure

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabSectionRow = Items.Inventory.CurrentData;
	
	If TabSectionRow.Quantity <> 0 Then
		TabSectionRow.Price = Round(TabSectionRow.Amount / TabSectionRow.Quantity, 2);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.ImportDataFromFile
&AtClient
Procedure ImportInventoryFromFile(Command)
	
	ImportParameters = ImportDataFromFileClient.DataImportParameters();
	ImportParameters.FullTabularSectionName = "InventoryIncrease.Inventory";
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

&AtClient
Procedure CalculateAmount()
	
	TabSectionRow = Items.Inventory.CurrentData;
	
	If TabSectionRow <> Undefined Then
		TabSectionRow.Amount = TabSectionRow.Quantity * TabSectionRow.Price;
	EndIf;
	
EndProcedure

&AtClient
Procedure FormManagement()

#If MobileClient Then
	Items.InventoryImportInventoryFromFile.Visible = False;
#EndIf

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
		
		NewRow.Amount = NewRow.Quantity * NewRow.Price;
		
		Modified = True;
		
	EndDo;
	
EndProcedure

// End StandardSubsystems.ImportDataFromFile

#EndRegion
