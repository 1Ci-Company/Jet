///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// The settings of a common report form in the "ReportsOptions" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - A report form or a report settings form.
//       "Undefined" for non-contextual calls.
//   VariantKey - String, Undefined - Either the name of a predefined report option or UUID of a custom report.
//       "Undefined" when calling for a drill-down option or without context.
//       
//   Settings - See ReportsClientServer.GetDefaultReportSettings.
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.BeforeLoadVariantAtServer    = True;
	Settings.GenerateImmediately = True;
EndProcedure

// Runs in the same-name event handler of a report form after executing the form code.
//  See "ManagedForm.OnCreateAtServer" in Syntax Assistant.
//
// Parameters:
//   Form - ClientApplicationForm - Report form
//   Cancel - Boolean - The value is passed "as is" from the handler parameters.
//   StandardProcessing - Boolean - The value is passed "as is" from the handler parameters.
//
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	Volume = CommonClientServer.StructureProperty(Form.Parameters, "CommandParameter");
	If ValueIsFilled(Volume) Then
		DataParametersStructure = New Structure("Volume", Volume);
		SetDataParameters(SettingsComposer.Settings, DataParametersStructure);
	EndIf;
EndProcedure

// See ReportsOverridable.BeforeLoadVariantAtServer.
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("Volume");
	If FoundParameter = Undefined Then
		Return;
	EndIf;
	
	Volume = FoundParameter.Value;
	If Not ValueIsFilled(Volume) Then 
		Return;
	EndIf;
	
	DataParametersStructure = New Structure("Volume", Volume);
	SetDataParameters(NewDCSettings, DataParametersStructure);
	
EndProcedure

// Called before importing new settings. Used for modifying DCS reports.
//
// Parameters:
//   Context - Arbitrary
//   SchemaKey - String
//   VariantKey - String
//                - Undefined
//   NewDCSettings - DataCompositionSettings
//                    - Undefined
//   NewDCUserSettings - DataCompositionUserSettings
//                                    - Undefined
//
Procedure BeforeImportSettingsToComposer(Context, SchemaKey, VariantKey, NewDCSettings, NewDCUserSettings) Export
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("Volume");
	If FoundParameter = Undefined Then
		Return;
	EndIf;
	
	Volume = FoundParameter.Value;
	If Not ValueIsFilled(Volume) Then
		Return;
	EndIf;
	
	DataParametersStructure = New Structure("Volume", Volume);
	SetDataParameters(NewDCSettings, DataParametersStructure, NewDCUserSettings);
	
EndProcedure

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	Settings = SettingsComposer.GetSettings();
	ParameterVolume = Settings.DataParameters.Items.Find("Volume");
	If ParameterVolume <> Undefined Then
		Volume = ParameterVolume.Value;
	EndIf;
	
	FilesTableOnHardDrive = Reports.VolumeIntegrityCheck.FilesOnHardDrive(Volume);
		
	StandardProcessing = False;
		
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("VolumeCheckTable", FilesTableOnHardDrive);
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	ResultDocument.Clear();
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	OutputProcessor.Output(CompositionProcessor);
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions")
		And FilesTableOnHardDrive.Find("FixingPossible", "CheckStatus") <> Undefined Then 
		Cell = ResultDocument.Area(ResultDocument.TableHeight + 2, 1, ResultDocument.TableHeight + 2, 2);
		Cell.Merge();
		ModuleReportsServer = Common.CommonModule("ReportsServer");
		ModuleReportsServer.OutputHyperlink(Cell, "VolumeIntegrityCheck.RecoverFiles", NStr("en = 'Restore';"));
	EndIf;
	
	SettingsComposer.UserSettings.AdditionalProperties.Insert("ReportIsBlank", FilesTableOnHardDrive.Count() = 0);
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ReportSettings = SettingsComposer.GetSettings();
	Volume = ReportSettings.DataParameters.Items.Find("Volume").Value;
	
	If Not ValueIsFilled(Volume) Then
		Common.MessageToUser(
			NStr("en = 'Please fill the ""Volume"" parameter.';"), , );
		Cancel = True;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetDataParameters(Settings, ParameterValues, UserSettings = Undefined)
	
	DataParameters = Settings.DataParameters.Items;
	
	For Each ParameterValue In ParameterValues Do 
		
		DataParameter = DataParameters.Find(ParameterValue.Key);
		
		If DataParameter = Undefined Then
			Continue;
		EndIf;
		
		DataParameter.Value = ParameterValue.Value;
		
		If Not ValueIsFilled(DataParameter.UserSettingID)
			Or TypeOf(UserSettings) <> Type("DataCompositionUserSettings") Then 
			Continue;
		EndIf;
		
		MatchingParameter = UserSettings.Items.Find(
			DataParameter.UserSettingID);
		
		If MatchingParameter <> Undefined Then 
			FillPropertyValues(MatchingParameter, DataParameter, "Value");
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf