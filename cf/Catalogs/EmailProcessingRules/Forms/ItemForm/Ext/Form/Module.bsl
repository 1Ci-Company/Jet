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
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		
		If Not Interactions.UserIsResponsibleForMaintainingFolders(Object.Owner) Then
			Cancel = True;
			Return;
		EndIf;

		If Parameters.CopyingValue.IsEmpty() Then
			InitializeComposerServer(Undefined);
		Else
			InitializeComposerServer(Parameters.CopyingValue.SettingsComposer.Get());
		EndIf;
		
	Else
		
		If Not Interactions.UserIsResponsibleForMaintainingFolders(Object.Owner) Then
			ReadOnly = True;
			Items.SettingsComposerSettingsFilter.ReadOnly = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SavedSettingsComposer = CurrentObject.SettingsComposer.Get();
	InitializeComposerServer(SavedSettingsComposer);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.FilterPresentation  = String(SettingsComposer.Settings.Filter);
	CurrentObject.SettingsComposer = New ValueStorage(SettingsComposer.GetSettings());
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GenerateDescriptionChoiceList();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SettingsComposerSettingsFilterOnChange(Item)
	
	GenerateDescriptionChoiceList();
	
EndProcedure

&AtClient
Procedure DescriptionOnChange(Item)
	
	GenerateDescriptionChoiceList();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeComposerServer(CompositionSetup)
	
	CompositionSchema = Catalogs.EmailProcessingRules.GetTemplate("EmailProcessingRuleScheme");
	SchemaURL = PutToTempStorage(CompositionSchema,UUID);
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	
	If CompositionSetup = Undefined Then
		SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	Else
		SettingsComposer.LoadSettings(CompositionSetup);
		SettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateDescriptionChoiceList()
	
	Items.Description.ChoiceList.Clear();
	If Not IsBlankString(Object.Description) Then
		Items.Description.ChoiceList.Add(Object.Description);
	EndIf;
	FilterPresentation = String(SettingsComposer.Settings.Filter);
	If StrLen(FilterPresentation) > 150 Then
		FilterPresentation = Left(FilterPresentation,147) + "...";
	EndIf;
	If FilterPresentation <> Object.Description Then
		Items.Description.ChoiceList.Add(FilterPresentation);
	EndIf;
	
EndProcedure

#EndRegion
