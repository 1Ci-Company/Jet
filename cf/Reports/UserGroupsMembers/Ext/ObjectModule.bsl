///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// Set report form settings.
//
// Parameters:
//   Form - ClientApplicationForm
//         - Undefined
//   VariantKey - String
//                - Undefined
//   Settings - See ReportsClientServer.DefaultReportSettings
//
Procedure DefineFormSettings(Form, VariantKey, Settings) Export
	
	Settings.GenerateImmediately = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.OnDefineUsedTables = True;
	
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
	
	If SchemaKey <> "1" Then
		SchemaKey = "1";
		
		If TypeOf(Context) = Type("ClientApplicationForm")
		   And NewDCSettings <> Undefined
		   And Context.Parameters.Property("CommandParameter") Then
			
			Values = Context.Parameters.CommandParameter;
			ParameterName = ?(ValueIsFilled(Values) And TypeOf(Values[0]) = Type("CatalogRef.Users"),
				"User", "UsersGroup");
			
			ValueList = New ValueList;
			ValueList.LoadValues(Values);
			UsersInternal.SetFilterOnParameter(ParameterName,
				ValueList, NewDCSettings, NewDCUserSettings);
		EndIf;
	EndIf;
	
EndProcedure

// Parameters:
//   VariantKey - String
//                - Undefined
//   TablesToUse - Array of String
//
Procedure OnDefineUsedTables(VariantKey, TablesToUse) Export
	
	TablesToUse.Add(Metadata.Catalogs.Users.FullName());
	TablesToUse.Add(Metadata.Catalogs.UserGroups.FullName());
	TablesToUse.Add(Metadata.InformationRegisters.UserGroupCompositions.FullName());
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Parameters:
//  ResultDocument - SpreadsheetDocument
//  DetailsData - DataCompositionDetailsData
//  StandardProcessing - Boolean
//
Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	Settings = SettingsComposer.GetSettings();
	
	ParameterShouldShowInvalidMembers = Settings.DataParameters.Items.Find(
		"ShouldShowInvalidMembers");
	ParameterShouldIncludeValidMembersOnly = Settings.DataParameters.Items.Find(
		"ShouldIncludeValidMembersOnly");
	
	ParameterShouldIncludeValidMembersOnly.Use = True;
	ParameterShouldIncludeValidMembersOnly.Value =
		Not ParameterShouldShowInvalidMembers.Use
		Or Not ParameterShouldShowInvalidMembers.Value;
	
	ParameterUsersGroup = Settings.DataParameters.Items.Find("UsersGroup");
	ParameterUsersGroupInList = Settings.DataParameters.Items.Find("UsersGroupInList");
	ParameterUsersGroupInHierarchy = Settings.DataParameters.Items.Find("UsersGroupInHierarchy");
	ParameterShouldHideUsersThatBelongToLowerLevelGroups = Settings.DataParameters.Items.Find(
		"ShouldHideUsersThatBelongToLowerLevelGroups");
	
	Hide_2 = ParameterShouldHideUsersThatBelongToLowerLevelGroups.Use
		And ParameterShouldHideUsersThatBelongToLowerLevelGroups.Value;
	
	If Not ParameterUsersGroup.Use And Hide_2 Then
		ParameterShouldHideUsersThatBelongToLowerLevelGroups.Use = False;
		Hide_2 = False;
	EndIf;
	
	ParameterUsersGroupInList.Value = ParameterUsersGroup.Value;
	ParameterUsersGroupInList.Use =
		ParameterUsersGroup.Use And Hide_2;
	
	ParameterUsersGroupInHierarchy.Value = ParameterUsersGroup.Value;
	ParameterUsersGroupInHierarchy.Use =
		ParameterUsersGroup.Use And Not Hide_2;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf