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
			
			Query = New Query;
			Query.SetParameter("References", Context.Parameters.CommandParameter);
			Query.Text =
			"SELECT
			|	TRUE AS TrueValue
			|FROM
			|	Catalog.AccessGroups AS AccessGroups
			|WHERE
			|	AccessGroups.Ref IN (&References)
			|	AND AccessGroups.IsFolder";
			InHierarchy = Not Query.Execute().IsEmpty();
			
			AccessGroupsList = New ValueList;
			AccessGroupsList.LoadValues(Context.Parameters.CommandParameter);
			UsersInternal.SetFilterOnField("AccessGroup",
				AccessGroupsList, NewDCSettings, NewDCUserSettings, InHierarchy);
		EndIf;
	EndIf;
	
	AttachSchema = False;
	
	If Not GetFunctionalOption("UseUserGroups") Then
		Field = DataCompositionSchema.CalculatedFields.Find("IncludedAsGroupMember");
		If Field <> Undefined Then
			Field.UseRestriction.Group = True;
			Field.UseRestriction.Field = True;
			Field.UseRestriction.Order = True;
			Field.UseRestriction.Condition = True;
			AttachSchema = True;
			DeleteFieldUsageFromGroupings(NewDCSettings.Structure, "IncludedAsGroupMember");
		EndIf;
	EndIf;
	
	If AttachSchema Then
		ModuleReportsServer = Common.CommonModule("ReportsServer");
		ModuleReportsServer.AttachSchema(ThisObject, Context, DataCompositionSchema, SchemaKey);
	EndIf;
	
EndProcedure

// Parameters:
//   VariantKey - String
//                - Undefined
//   TablesToUse - Array of String
//
Procedure OnDefineUsedTables(VariantKey, TablesToUse) Export
	
	TablesToUse.Add(Metadata.Catalogs.AccessGroupProfiles.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroups.FullName());
	TablesToUse.Add(Metadata.Catalogs.Users.FullName());
	TablesToUse.Add(Metadata.Catalogs.UserGroups.FullName());
	TablesToUse.Add(Metadata.Catalogs.ExternalUsers.FullName());
	TablesToUse.Add(Metadata.Catalogs.ExternalUsersGroups.FullName());
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

#Region Private

// Parameters:
//  Structure - DataCompositionSettingStructureItemCollection
//  FieldName - String
//
Procedure DeleteFieldUsageFromGroupings(Structure, FieldName);
	
	For Each Group In Structure Do
		If TypeOf(Group) <> Type("DataCompositionGroup") Then
			Continue;
		EndIf;
		DeleteFieldUsageFromSelected(Group.Selection, FieldName);
		DeleteFieldUsageFromGroupings(Group.Structure, FieldName);
	EndDo;
	
EndProcedure

// Parameters:
//  Structure - DataCompositionSelectedFields
//            - DataCompositionSelectedFieldGroup
//  FieldName - String
//
Procedure DeleteFieldUsageFromSelected(SelectedFields, FieldName)
	
	FoundField = Undefined;
	SearchField = New DataCompositionField(FieldName);
	For Each SelectedField In SelectedFields.Items Do
		
		If TypeOf(SelectedField) = Type("DataCompositionSelectedFieldGroup") Then
			DeleteFieldUsageFromSelected(SelectedField, FieldName);
		
		ElsIf TypeOf(SelectedField) = Type("DataCompositionSelectedField")
		        And SelectedField.Field = SearchField Then
			
			FoundField = SelectedField;
			Break;
		EndIf;
	EndDo;
	
	If FoundField <> Undefined Then
		SelectedFields.Items.Delete(FoundField);
	EndIf;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf