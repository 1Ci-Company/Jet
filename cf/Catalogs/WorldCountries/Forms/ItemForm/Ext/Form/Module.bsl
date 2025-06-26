///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties

EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Predefined Then
		Items.DescriptionGroup.ReadOnly = True;
	EndIf;
	
	If ValueIsFilled(Parameters.Title) Then
		Title     = Parameters.Title;
		AutoTitle = False;
	EndIf;
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Catalog.WorldCountries.Update", Object.Ref, ThisObject);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, Var_URL = Undefined, StandardProcessing = Undefined)
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#Region Private

// StandardSubsystems.Properties 

&AtServer
Procedure UpdateAdditionalAttributesItems()
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
EndProcedure

// End StandardSubsystems.Properties

#EndRegion
