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
				"User", "Department");
			
			ValueList = New ValueList;
			ValueList.LoadValues(Values);
			UsersInternal.SetFilterOnParameter(ParameterName,
				ValueList, NewDCSettings, NewDCUserSettings);
		EndIf;
	EndIf;
	
	If Not Users.IsDepartmentUsed() Then
		Return;
	EndIf;
	
	DepartmentsHierarchy = False;
	
	For Each Type In Metadata.Catalogs.Users.Attributes.Department.Type.Types() Do
		If Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined
		 Or Not Common.IsCatalog(MetadataObject)
		 Or Not MetadataObject.Hierarchical Then
			Continue;
		EndIf;
		DepartmentsHierarchy = True;
		Break;
	EndDo;
	
	If DepartmentsHierarchy Then
		FieldToEval = DataCompositionSchema.CalculatedFields.Find("DepartmentParent");
		FieldToEval.Expression = "Department.Parent";
	Else
		Parameter = DataCompositionSchema.Parameters.Find("ShouldHideUsersThatBelongToLowerLevelDepartments");
		If Parameter <> Undefined Then
			Parameter.UseRestriction = True;
		EndIf;
	EndIf;
	
	ModuleReportsServer = Common.CommonModule("ReportsServer");
	ModuleReportsServer.AttachSchema(ThisObject, Context, DataCompositionSchema, SchemaKey);
	
EndProcedure

// Parameters:
//   VariantKey - String
//                - Undefined
//   TablesToUse - Array of String
//
Procedure OnDefineUsedTables(VariantKey, TablesToUse) Export
	
	TablesToUse.Add(Metadata.Catalogs.Users.FullName());
	
	If Not Users.IsDepartmentUsed() Then
		Return;
	EndIf;
	
	For Each Type In Metadata.Catalogs.Users.Attributes.Department.Type.Types() Do
		If Not Common.IsReference(Type) Then
			Continue;
		EndIf;
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject <> Undefined Then
			TablesToUse.Add(MetadataObject.FullName());
		EndIf;
	EndDo;
	
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
	
	UnitParameter = Settings.DataParameters.Items.Find("Department");
	ParameterDepartmentInList = Settings.DataParameters.Items.Find("DepartmentInList");
	ParameterDepartmentInHierarchy = Settings.DataParameters.Items.Find("DepartmentInHierarchy");
	ParameterShouldHideUsersThatBelongToLowerLevelDepartments = Settings.DataParameters.Items.Find(
		"ShouldHideUsersThatBelongToLowerLevelDepartments");
	
	Hide_2 = ParameterShouldHideUsersThatBelongToLowerLevelDepartments.Use
		And ParameterShouldHideUsersThatBelongToLowerLevelDepartments.Value;
	
	If Not UnitParameter.Use And Hide_2 Then
		ParameterShouldHideUsersThatBelongToLowerLevelDepartments.Use = False;
		Hide_2 = False;
	EndIf;
	
	ParameterDepartmentInList.Value = UnitParameter.Value;
	ParameterDepartmentInList.Use =
		UnitParameter.Use And Hide_2;
	
	ParameterDepartmentInHierarchy.Value = UnitParameter.Value;
	ParameterDepartmentInHierarchy.Use =
		UnitParameter.Use And Not Hide_2;
	
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