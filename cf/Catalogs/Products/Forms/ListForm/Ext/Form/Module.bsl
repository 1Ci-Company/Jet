
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	LabelsDisplayParameters = PropertyManager.LabelsDisplayParameters();
	LabelsDisplayParameters.LabelsDestinationElementName = Items.GroupLabels.Name;
	LabelsDisplayParameters.LabelsLegendDestinationElementName = Items.GroupLegendLabels.Name;
	LabelsDisplayParameters.FilterLabelsCount = True;
	LabelsDisplayParameters.ObjectsKind = Metadata.Catalogs.Products.FullName();
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("LabelsDisplayParameters", LabelsDisplayParameters);
	AdditionalParameters.Insert("ArbitraryObject", True);
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServerNoContext
Procedure ListOnGetDataAtServer(ItemName, Settings, Rows)
	
	// StandardSubsystems.Properties
	PropertyManager.OnGetDataAtServer(Settings, Rows);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.StartCommandExecution(ThisObject, Command, Items.List);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	AttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Items.List);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_SetLabelsLegendVisibility(Command)
	SetLabelsLegendVisibility();
EndProcedure

&AtServer
Procedure SetLabelsLegendVisibility()
	PropertyManager.SetLabelsLegendVisibility(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_FilterByLabelsHandler(Command)
	PropertyManagerClient.ApplyFilterByLabel(ThisObject, Command.Name);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion
