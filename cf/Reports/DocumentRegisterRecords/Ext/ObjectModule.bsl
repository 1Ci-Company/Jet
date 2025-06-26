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

#Region Variables

Var CurrentVariantKey; // String
                            // 
                            // 
Var ParentOptionKey; // String
Var RegistersProperties; // See NewRegisterProperties
Var Remarks; // See NotesPropertiesPalette

#EndRegion

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

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
	
	Settings.ControlItemsPlacementParameters = ControlItemsPlacementParameters();
	
	Settings.Events.OnCreateAtServer               = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.BeforeLoadVariantAtServer    = True;
	Settings.Events.OnDefineSelectionParameters     = True;
	
	Settings.GenerateImmediately = True;
	
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
	
	CurrentVariantKey = VariantKey;
	
	If TypeOf(NewDCSettings) <> Type("DataCompositionSettings") Then
		NewDCSettings = SettingsComposer.Settings;
	EndIf;
	
	If TypeOf(NewDCUserSettings) <> Type("DataCompositionUserSettings") Then
		NewDCUserSettings = SettingsComposer.UserSettings;
	EndIf;
	
	ReportParameters = ReportParameters(NewDCSettings, NewDCUserSettings);
	
	If ReportParameters.OwnerDocument = Undefined Then
		Raise NStr("en = 'You can open the document record history from the document form.';");
	EndIf;
	
	ParentOptionKey = ParentOptionKey(Context, VariantKey, NewDCSettings);
	
	If SchemaKey = VariantKey Then
		Return;
	EndIf;
	
	SchemaKey = VariantKey;
	
	GetRegistersProperties(Context, ReportParameters.OwnerDocument);
	
	AddRecordsCountResource(DataCompositionSchema);
	
	RegistersList = RegistersList();
	SelectedRegistersList = SelectedRegistersList(RegistersList, NewDCSettings, NewDCUserSettings);
	
	FoundParameter = DataCompositionSchema.Parameters.Find("RegistersList");
	FoundParameter.SetAvailableValues(RegistersList);
	
	ParameterValues = New Structure;
	ParameterValues.Insert("OwnerDocument", ReportParameters.OwnerDocument);
	ParameterValues.Insert("RegistersList", SelectedRegistersList);
	
	RestrictOwnerType(ReportParameters.OwnerDocument);
	SetDataParameters(NewDCSettings, ParameterValues, NewDCUserSettings);
	
	IsPredefinedOption = (ParentOptionKey = VariantKey);
	
	If ParentOptionKey = "Main" Then
		PrepareHorizontalOption(ReportParameters.OwnerDocument, NewDCSettings, IsPredefinedOption);
	ElsIf ParentOptionKey = "Additional" Then
		PrepareVerticalOption(ReportParameters.OwnerDocument, NewDCSettings, IsPredefinedOption);
	EndIf;
	
	AdditionalProperties = NewDCSettings.AdditionalProperties;
	AdditionalProperties.Insert("SettingsPropertiesIDs", New Array);
	AdditionalProperties.Insert("ParentOptionKey", ParentOptionKey);
	
	ReportsServer.AttachSchema(ThisObject, Context, DataCompositionSchema, SchemaKey);
	
	SetConditionalAppearance(NewDCSettings);
	DetermineUsedTables(Context);
	
EndProcedure

// See ReportsOverridable.OnCreateAtServer.
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	If Form.Parameters.VariantPresentation = "Details" Then
		Raise NStr("en = 'The selected action is unavailable in this report.';");
	EndIf;
	
	OwnerDocument = Undefined;
	
	If Not Form.Parameters.Property("OwnerDocument", OwnerDocument)
		And Not Form.Parameters.Property("CommandParameter", OwnerDocument)
		And Not ValueIsFilled(OwnerDocument) Then 
		
		Return;
	EndIf;
	
	DataParametersStructure = New Structure("OwnerDocument", OwnerDocument);
	SetDataParameters(SettingsComposer.Settings, DataParametersStructure);
	
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters.
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
	If RegistersProperties = Undefined
		Or RegistersProperties.Count() = 0
		Or SettingProperties.DCField <> New DataCompositionField("DataParameters.RegistersList") Then
		Return;
	EndIf;
	
	SettingProperties.RestrictSelectionBySpecifiedValues = True;
	SettingProperties.ValuesForSelection = RegistersList();
	
EndProcedure

// See ReportsOverridable.BeforeLoadVariantAtServer.
Procedure BeforeLoadVariantAtServer(Form, NewDCSettings) Export
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerDocument");
	If FoundParameter = Undefined Then
		Return;
	EndIf;
	
	OwnerDocument = FoundParameter.Value;
	If Not ValueIsFilled(OwnerDocument) Then 
		Return;
	EndIf;
	
	If ValueIsFilled(Form.OptionContext) Then 
		NewDCSettings.AdditionalProperties.Insert("TheOriginalDocumentOwner", OwnerDocument);
	EndIf;
	
	SetDataParameters(NewDCSettings, New Structure("OwnerDocument", OwnerDocument));
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	FoundParameter = SettingsComposer.Settings.DataParameters.Items.Find("OwnerDocument");
	If FoundParameter = Undefined
		Or Not ValueIsFilled(FoundParameter.Value) Then
		Return;
	EndIf;
	
	OwnerDocument = FoundParameter.Value;
	
	Header_Template                              = GetTemplate("Title");
	TitleArea                            = Header_Template.GetArea("HeaderArea_");
	TitleArea.Parameters.DocumentReference = String(OwnerDocument);
	EmptyArea                               = Header_Template.GetArea("EmptyArea");
	
	TitleArea.CurrentArea.Details = OwnerDocument;
	
	ResultDocument.Put(EmptyArea);
	ResultDocument.Put(TitleArea);
	ResultDocument.Put(EmptyArea);
	
	Settings = SettingsComposer.GetSettings();
	
	GetRegistersProperties(Settings, OwnerDocument);
	
	FoundParameter = Settings.DataParameters.Items.Find("RegistersList");
	If FoundParameter <> Undefined
		And Not FoundParameter.Use Then 
		
		FoundParameter.Use = True;
		FoundParameter.Value = RegistersList();
		
	EndIf;
	
	RestoreFilterByRegistersGroups(Settings);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate   = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
	
	RegisterResult(Settings, ResultDocument, OwnerDocument);
	
EndProcedure

#EndRegion

#Region Private

#Region DCSGeneration

#Region DataPreparation

Procedure RestrictOwnerType(Owner)
	
	OwnerTypes = New Array;
	OwnerTypes.Add(TypeOf(Owner));
	
	FoundParameter = DataCompositionSchema.Parameters.Find("OwnerDocument");
	FoundParameter.ValueType = New TypeDescription(OwnerTypes);
	
EndProcedure

Function ReportDataSets(OwnerDocument, AdditionalNumbering = False)
	
	DataSets = New Array;
	
	For Each RegisterProperties In RegistersProperties Do
		
		DataSet = Undefined;
		RegisterMetadata = Common.MetadataObjectByFullName(RegisterProperties.FullRegisterName);
		
		If RegisterProperties.RegisterType = "AccumulationRegister"
			Or RegisterProperties.RegisterType = "InformationRegister" Then
			
			DataSet = DataSetForInfoAccumulationRegister(RegisterProperties, RegisterMetadata, AdditionalNumbering);
			
		ElsIf RegisterProperties.RegisterType = "AccountingRegister" Then
			
			DataSet = DataSetForAccountingRegister(RegisterProperties, RegisterMetadata);
			
		ElsIf RegisterProperties.RegisterType = "CalculationRegister" Then
			
			DataSet = DataSetForCalculationRegister(RegisterProperties, RegisterMetadata, AdditionalNumbering);
			
		EndIf;
		
		If DataSet <> Undefined Then
			DataSets.Add(DataSet);
		EndIf;
		
	EndDo;
	
	DocumentRecordsReportOverridable.OnPrepareDataSet(OwnerDocument, DataSets);
	
	Return DataSets;
	
EndFunction

Function DataSetForInfoAccumulationRegister(RegisterProperties, RegisterMetadata, AdditionalNumbering)
	
	DataSet = New Structure;
	DataSet.Insert("Dimensions",              New Structure);
	DataSet.Insert("Resources",                New Structure);
	DataSet.Insert("Attributes",              New Structure);
	DataSet.Insert("StandardAttributes",   New Structure);
	DataSet.Insert("FullRegisterName",      RegisterProperties.GroupName);
	DataSet.Insert("RegisterName",            RegisterProperties.RegisterName);
	DataSet.Insert("RegisterType",            RegisterProperties.RegisterType);
	DataSet.Insert("RegisterKindPresentation", RegisterProperties.RegisterKindPresentation);
	DataSet.Insert("RegisterPresentation",  RegisterProperties.RegisterPresentation);
	
	If AdditionalNumbering Then
		DataSet.Insert("Numerator", New Structure);
	EndIf;
	
	ExceptionAttributes = CommonClientServer.ArrayOfValues("LineNumber", "Recorder");
	DataSet.StandardAttributes = FieldsPresentationNames(RegisterMetadata.StandardAttributes, ExceptionAttributes);
	DataSet.Dimensions            = FieldsPresentationNames(RegisterMetadata.Dimensions);
	DataSet.Resources              = FieldsPresentationNames(RegisterMetadata.Resources);
	DataSet.Attributes            = FieldsPresentationNames(RegisterMetadata.Attributes);
	
	SelectionFields = New Array;
	AddFields(SelectionFields, DataSet.StandardAttributes, RegisterMetadata);
	AddFields(SelectionFields, DataSet.Dimensions, RegisterMetadata, "Dimensions");
	AddFields(SelectionFields, DataSet.Resources, RegisterMetadata, "Resources");
	AddFields(SelectionFields, DataSet.Attributes, RegisterMetadata, "Attributes");
	
	If AdditionalNumbering Then
		DataSet.Numerator = FieldsNumbers(DataSet);
		AddFieldsNumbers(SelectionFields, DataSet.Numerator);
	EndIf;
	
	QueryText =
	"SELECT ALLOWED
	|	1 AS RegisterRecordCount1,
	|	""&RegisterName"" AS RegisterName,
	|	&Fields
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&RecorderFieldName = &OwnerDocument
	|{WHERE
	|	""&GroupName"" IN (&RegistersList)}";
	
	QueryText = StrReplace(QueryText, "&RegisterName", RegisterProperties.GroupName);
	QueryText = StrReplace(QueryText, "&Fields", StrConcat(SelectionFields, "," + Chars.LF + Chars.Tab));
	QueryText = StrReplace(QueryText, "&CurrentTable", RegisterProperties.FullRegisterName);
	QueryText = StrReplace(QueryText, "&RecorderFieldName", RegisterProperties.RecorderFieldName);
	QueryText = StrReplace(QueryText, "&GroupName", RegisterProperties.GroupName);
	
	DataSet.Insert("QueryText", QueryText);
	
	Return DataSet;
	
EndFunction

Function DataSetForAccountingRegister(RegisterProperties, RegisterMetadata)
	
	DataSet = New Structure;
	DataSet.Insert("StandardAttributes",   New Structure);
	DataSet.Insert("Dimensions",              New Structure);
	DataSet.Insert("Resources",                New Structure);
	DataSet.Insert("ResourcesDr",              New Structure);
	DataSet.Insert("ResourcesCr",              New Structure);
	DataSet.Insert("ExtDimension",               New Structure);
	DataSet.Insert("ExtDimensionDr",             New Structure);
	DataSet.Insert("ExtDimensionCr",             New Structure);
	DataSet.Insert("DimensionsDr",            New Structure);
	DataSet.Insert("DimensionsCr",            New Structure);
	DataSet.Insert("Attributes",              New Structure);
	DataSet.Insert("FullRegisterName",      RegisterProperties.GroupName);
	DataSet.Insert("RegisterName",            RegisterProperties.RegisterName);
	DataSet.Insert("RegisterType",            RegisterProperties.RegisterType);
	DataSet.Insert("RegisterKindPresentation", RegisterProperties.RegisterKindPresentation);
	DataSet.Insert("RegisterPresentation",  RegisterProperties.RegisterPresentation);
	
	MaxExtDimensionCount = RegisterMetadata.ChartOfAccounts.MaxExtDimensionCount;
	
	DebitSubmission    = NStr("en = 'Dr';");
	SubmissionCredit   = NStr("en = 'Cr';");
	RepresentationOfSubconto = NStr("en = 'Extra dimension';");
	AccountSubmission     = NStr("en = 'Account';");
	
	ExceptionAttributes = CommonClientServer.ArrayOfValues(
		"LineNumber", "Recorder", "Account");
	For ExtDimensionIndex = 1 To MaxExtDimensionCount Do
		ExtDimensionIndexRow =  Format(ExtDimensionIndex, "NG=0");
		ExceptionAttributes.Add("ExtDimensionType" + ExtDimensionIndexRow);
		ExceptionAttributes.Add("ExtDimension" + ExtDimensionIndexRow);
	EndDo;
	DataSet.StandardAttributes = FieldsPresentationNames(RegisterMetadata.StandardAttributes, ExceptionAttributes);
	DataSet.Attributes            = FieldsPresentationNames(RegisterMetadata.Attributes, ExceptionAttributes);
	
	For Each Resource In RegisterMetadata.Resources Do
	
		If Resource.Balance Or Not RegisterMetadata.Correspondence Then
			DataSet.Resources.Insert(Resource.Name, Resource.Presentation());
		Else
			DataSet.ResourcesDr.Insert(Resource.Name + "Dr", Resource.Presentation() + " " + DebitSubmission);
			DataSet.ResourcesCr.Insert(Resource.Name + "Cr", Resource.Presentation() + " " + SubmissionCredit);
		EndIf;
	
	EndDo;
	
	For ExtDimensionIndex = 1 To MaxExtDimensionCount Do
	    IndexAsString = Format(ExtDimensionIndex, "NG=0");
		If RegisterMetadata.Correspondence Then
			DataSet.ExtDimensionDr.Insert("ExtDimensionDr" + IndexAsString,
				RepresentationOfSubconto + " " + DebitSubmission + " " + IndexAsString);
			DataSet.ExtDimensionCr.Insert("ExtDimensionCr" + IndexAsString,
				RepresentationOfSubconto + " " + SubmissionCredit + " " + IndexAsString);
		Else
			DataSet.ExtDimension.Insert("ExtDimension" + IndexAsString, RepresentationOfSubconto + " " + IndexAsString);
		EndIf;
		
	EndDo;
	
	If RegisterMetadata.Correspondence Then
		DataSet.DimensionsDr.Insert("AccountDr", AccountSubmission + " " + DebitSubmission);
		DataSet.DimensionsCr.Insert("AccountCr", AccountSubmission + " " + SubmissionCredit);
	Else
		DataSet.DimensionsDr.Insert("Account", AccountSubmission);
	EndIf;
	
	Dimensions = RegisterMetadata.Dimensions;
	For Each Dimension In Dimensions Do
	
		If Dimension.Balance Or Not RegisterMetadata.Correspondence Then
			DataSet.Dimensions.Insert(Dimension.Name, Dimension.Presentation());
		Else
			DataSet.DimensionsDr.Insert(Dimension.Name + "Dr", Dimension.Presentation() + " " + DebitSubmission);
			DataSet.DimensionsCr.Insert(Dimension.Name + "Cr", Dimension.Presentation() + " " + SubmissionCredit);
		EndIf;
	
	EndDo;
	
	SelectionFields = New Array;
	AddFields(SelectionFields, DataSet.StandardAttributes, RegisterMetadata);
	AddFields(SelectionFields, DataSet.Attributes, RegisterMetadata, "Attributes");
	AddFields(SelectionFields, DataSet.Dimensions, RegisterMetadata, "Dimensions");
	AddFields(SelectionFields, DataSet.DimensionsDr, RegisterMetadata);
	AddFields(SelectionFields, DataSet.DimensionsCr, RegisterMetadata);
	AddFields(SelectionFields, DataSet.Resources, RegisterMetadata, "Resources");
	AddFields(SelectionFields, DataSet.ResourcesDr, RegisterMetadata);
	AddFields(SelectionFields, DataSet.ResourcesCr, RegisterMetadata);
	If Not RegisterMetadata.Correspondence Then  	
		AddFields(SelectionFields, DataSet.ExtDimension, RegisterMetadata);
	EndIf;
	AddFields(SelectionFields, DataSet.ExtDimensionDr, RegisterMetadata);
	AddFields(SelectionFields, DataSet.ExtDimensionCr, RegisterMetadata);
	
	QueryText =
	"SELECT ALLOWED
	|	1 AS RegisterRecordCount1,
	|	""&RegisterName"" AS RegisterName,
	|	&Fields
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&RecorderFieldName = &OwnerDocument
	|{WHERE
	|	(""&GroupName"" IN (&RegistersList))}";
	
	QueryText = StrReplace(QueryText, "&RegisterName", RegisterProperties.GroupName);
	QueryText = StrReplace(QueryText, "&Fields", StrConcat(SelectionFields, "," + Chars.LF + Chars.Tab));
	QueryText = StrReplace(QueryText, "&CurrentTable", 
		StrTemplate("AccountingRegister.%1.RecordsWithExtDimensions(, , %2 = &OwnerDocument)", 
			RegisterProperties.RegisterName, RegisterProperties.RecorderFieldName));
	QueryText = StrReplace(QueryText, "&RecorderFieldName", RegisterProperties.RecorderFieldName);
	QueryText = StrReplace(QueryText, "&GroupName", RegisterProperties.GroupName);
	
	DataSet.Insert("QueryText", QueryText);
	
	Return DataSet;
	
EndFunction

Function DataSetForCalculationRegister(RegisterProperties, RegisterMetadata, AdditionalNumbering)
	
	DataSet = New Structure;
	DataSet.Insert("Dimensions",              New Structure);
	DataSet.Insert("Resources",                New Structure);
	DataSet.Insert("Attributes",              New Structure);
	DataSet.Insert("StandardAttributes",   New Structure);
	DataSet.Insert("FullRegisterName",      RegisterProperties.GroupName);
	DataSet.Insert("RegisterName",            RegisterProperties.RegisterName);
	DataSet.Insert("RegisterType",            RegisterProperties.RegisterType);
	DataSet.Insert("RegisterKindPresentation", RegisterProperties.RegisterKindPresentation);
	DataSet.Insert("RegisterPresentation",  RegisterProperties.RegisterPresentation);
	
	If AdditionalNumbering Then
		DataSet.Insert("Numerator", New Structure);
	EndIf;
	
	For Each Attribute In RegisterMetadata.StandardAttributes Do
		DataSet.StandardAttributes.Insert(Attribute.Name, Attribute.Presentation());
	EndDo;
	
	DataSet.Dimensions = FieldsPresentationNames(RegisterMetadata.Dimensions);
	DataSet.Resources   = FieldsPresentationNames(RegisterMetadata.Resources);
	DataSet.Attributes = FieldsPresentationNames(RegisterMetadata.Attributes);
	
	SelectionFields = New Array;
	AddFields(SelectionFields, DataSet.StandardAttributes, RegisterMetadata);
	AddFields(SelectionFields, DataSet.Dimensions, RegisterMetadata, "Dimensions");
	AddFields(SelectionFields, DataSet.Resources, RegisterMetadata, "Resources");
	AddFields(SelectionFields, DataSet.Attributes, RegisterMetadata, "Attributes");
	
	If AdditionalNumbering Then
		DataSet.Numerator = FieldsNumbers(DataSet);
		AddFieldsNumbers(SelectionFields, DataSet.Numerator);
	EndIf;
	
	QueryText =
	"SELECT ALLOWED
	|	1 AS RegisterRecordCount1,
	|	""&RegisterName"" AS RegisterName,
	|	&Fields
	|FROM
	|	&CurrentTable AS CurrentTable
	|WHERE
	|	&RecorderFieldName = &OwnerDocument
	|{WHERE
	|	""&GroupName"" IN (&RegistersList)}";
	
	QueryText = StrReplace(QueryText, "&RegisterName", RegisterProperties.GroupName);
	QueryText = StrReplace(QueryText, "&Fields", StrConcat(SelectionFields, "," + Chars.LF + Chars.Tab));
	QueryText = StrReplace(QueryText, "&CurrentTable", RegisterProperties.FullRegisterName);
	QueryText = StrReplace(QueryText, "&RecorderFieldName", RegisterProperties.RecorderFieldName);
	QueryText = StrReplace(QueryText, "&GroupName", RegisterProperties.GroupName);
	
	DataSet.Insert("QueryText", QueryText);
	
	Return DataSet;
	
EndFunction

Procedure AddFieldsNumbers(FieldList, Numerators)
	
	For Each Numerator In Numerators Do
		FieldList.Add(Numerator.Value + " AS " + Numerator.Key); // @query-part
	EndDo;
	
EndProcedure

#EndRegion

#Region HorizontalOption

Procedure PrepareHorizontalOption(OwnerDocument, Settings, IsPredefinedOption)
	
	If RegistersProperties.Count() = 0 Then 
		Return;
	EndIf;
	
	DataSets = ReportDataSets(OwnerDocument);
	
	MainDataSet = DataCompositionSchema.DataSets["Main"]; // DataCompositionSchemaDataSetUnion
	DataSetsItems = MainDataSet.Items;
	
	SetIndex = 0;
	For Each DataSet In DataSets Do
	
		SetIndex = SetIndex + 1;
		SetName = "RequestBy" + DataSet.FullRegisterName;
		DataSetItem = DataSetsItems.Find(SetName);
	
		If DataSetItem = Undefined Then
	
			DataSetItem = DataSetsItems.Add(Type("DataCompositionSchemaDataSetQuery"));
			DataSetItem.Name = SetName;
			DataSetItem.DataSource = "DataSource1";
			DataSetItem.Query = DataSet.QueryText;
	
			RedefineDSCTemplate(DataCompositionSchema, SetIndex, DataSet.RegisterType,
				DataSet.RegisterKindPresentation, DataSet.RegisterName);
	
		EndIf;
		
		If IsPredefinedOption Then 
			PrepareHorizontalOptionOfDataSet(Settings, DataSet, DataSetItem);
		EndIf;
		
	EndDo;
	
	HideParametersAndFilters(Settings);
	
EndProcedure

Procedure PrepareHorizontalOptionOfDataSet(DCSettings, DataElement, DCDataSet)
	
	If DataElement.RegisterType = "AccumulationRegister" Or DataElement.RegisterType = "InformationRegister" Then
		
		PrepareAHorizontalVersionOfTheAccumulationAndDataRegisters(DCSettings, DCDataSet, DataElement);
		
	ElsIf DataElement.RegisterType = "AccountingRegister" Then
		
		PrepareHorizontalOptionOfAccountingRegisters(DCSettings, DCDataSet, DataElement);
		
	ElsIf DataElement.RegisterType = "CalculationRegister" Then
		
		PrepareHorizontalOptionOfCalculationRegisters(DCSettings, DCDataSet, DataElement);
		
	EndIf;
	
EndProcedure

Procedure PrepareAHorizontalVersionOfTheAccumulationAndDataRegisters(DCSettings, DCDataSet, DataElement)
	
	RegisterType            = DataElement.RegisterType;
	RegisterKindPresentation = DataElement.RegisterKindPresentation;
	RegisterName            = DataElement.RegisterName;
	RegisterPresentation  = DataElement.RegisterPresentation;
	
	StandardAttributesStructure = DataElement.StandardAttributes;
	DimensionStructure             = DataElement.Dimensions;
	ResourcesStructure              = DataElement.Resources;
	AttributesStructure1            = DataElement.Attributes;
	
	UserHeader = RegisterKindPresentation + " " + RegisterPresentation;
	DetailedRecordsGroup = DetailedRecordsByRegister(DCSettings, RegisterType + "_" + RegisterName, UserHeader);
	
	If StandardAttributesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "StandardAttributes");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Standard attributes.';"));
		
		PlaceDSCFieldsGroup(StandardAttributesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Dimensions");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Dimensions';"));
		
		PlaceDSCFieldsGroup(DimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ResourcesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Resources");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Resources';"));
		
		PlaceDSCFieldsGroup(ResourcesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If AttributesStructure1.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Attributes");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Attributes';"));
		
		PlaceDSCFieldsGroup(AttributesStructure1, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;

EndProcedure

Procedure PrepareHorizontalOptionOfCalculationRegisters(DCSettings, DCDataSet, DataElement)
	
	RegisterType            = "CalculationRegister";
	RegisterName            = DataElement.RegisterName;
	RegisterPresentation  = DataElement.RegisterPresentation;
	
	StandardAttributesStructure = DataElement.StandardAttributes;
	DimensionStructure             = DataElement.Dimensions;
	ResourcesStructure              = DataElement.Resources;
	AttributesStructure1            = DataElement.Attributes;
	
	UserHeader = NStr("en = 'Calculation register';") + " " + RegisterPresentation;
	
	DetailedRecordsGroup = DetailedRecordsByRegister(DCSettings,
		RegisterType + "_" + RegisterName, UserHeader);
	
	If StandardAttributesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "StandardAttributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Horizontally);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(StandardAttributesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Dimensions");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Dimensions';"));
		
		PlaceDSCFieldsGroup(DimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If ResourcesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Resources");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Resources';"));
		
		PlaceDSCFieldsGroup(ResourcesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If AttributesStructure1.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Attributes");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Attributes';"));
		
		PlaceDSCFieldsGroup(AttributesStructure1, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region VerticalOption

Procedure PrepareVerticalOption(OwnerDocument, Settings, IsPredefinedOption)
	
	If RegistersProperties.Count() = 0 Then 
		Return;
	EndIf;
	
	DataSets = ReportDataSets(OwnerDocument, True);
	
	MainDataSet = DataCompositionSchema.DataSets["Main"]; // DataCompositionSchemaDataSetUnion
	DataSetsItems = MainDataSet.Items;
	
	SetIndex = 0;
	For Each DataSet In DataSets Do
	
		SetIndex = SetIndex + 1;
		SetName = "RequestBy" + DataSet.FullRegisterName;
		DataSetItem = DataSetsItems.Find(SetName);
	
		If DataSetItem = Undefined Then
	
			DataSetItem = DataSetsItems.Add(Type("DataCompositionSchemaDataSetQuery"));
			DataSetItem.Name = SetName;
			DataSetItem.DataSource = "DataSource1";
	
			DataSetItem.Query = DataSet.QueryText;
	
			RedefineDSCTemplate(DataCompositionSchema, SetIndex, DataSet.RegisterType,
				DataSet.RegisterKindPresentation, DataSet.RegisterName);
	
		EndIf;
		
		If IsPredefinedOption Then 
			PrepareVerticalOptionOfDataSet(Settings, DataSet, DataSetItem);
		EndIf;
	
	EndDo;
	
	HideParametersAndFilters(Settings);
	
EndProcedure

Procedure PrepareVerticalOptionOfDataSet(DCSettings, DataSet, DCDataSet)
	
	If DataSet.RegisterType = "AccumulationRegister" Or DataSet.RegisterType = "InformationRegister" Then
	
		PrepareVerticalOptionOfAccumulationAndInfoRegisters(DCSettings, DCDataSet, DataSet);
	
	ElsIf DataSet.RegisterType = "AccountingRegister" Then
	
		PrepareHorizontalOptionOfAccountingRegisters(DCSettings, DCDataSet, DataSet);
	
	ElsIf DataSet.RegisterType = "CalculationRegister" Then
	
		PrepareVerticalOptionOfCalculationRegisters(DCSettings, DCDataSet, DataSet);
	
	EndIf;
	
EndProcedure

Procedure PrepareVerticalOptionOfAccumulationAndInfoRegisters(DCSettings, DCDataSet, DataElement)
	
	RegisterType            = DataElement.RegisterType;
	RegisterKindPresentation = DataElement.RegisterKindPresentation;
	RegisterName            = DataElement.RegisterName;
	RegisterPresentation  = DataElement.RegisterPresentation;
	
	StandardAttributesStructure = DataElement.StandardAttributes;
	DimensionStructure             = DataElement.Dimensions;
	ResourcesStructure              = DataElement.Resources;
	AttributesStructure1            = DataElement.Attributes;
	NumeratorStructure            = DataElement.Numerator; 
	
	Title = RegisterKindPresentation + " " + RegisterPresentation;
	DetailedRecordsGroup = DetailedRecordsByRegister(DCSettings, RegisterType + "_" + RegisterName, Title);
	
	If NumeratorStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Numerator");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", "№CurrentDocumentDCSOutputItemGroup");
		
		PlaceDSCFieldsGroup(NumeratorStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If StandardAttributesStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "StandardAttributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Standard attributes.';"));
		
		PlaceDSCFieldsGroup(StandardAttributesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Dimensions");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Dimensions';"));
		
		PlaceDSCFieldsGroup(DimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ResourcesStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Resources");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Resources';"));
		
		PlaceDSCFieldsGroup(ResourcesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If AttributesStructure1.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Attributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Attributes';"));
		
		PlaceDSCFieldsGroup(AttributesStructure1, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
EndProcedure

Procedure PrepareVerticalOptionOfCalculationRegisters(DCSettings, DCDataSet, DataElement)
	
	RegisterType            = "CalculationRegister";
	RegisterName            = DataElement.RegisterName;
	RegisterPresentation  = DataElement.RegisterPresentation;
	
	StandardAttributesStructure = DataElement.StandardAttributes;
	DimensionStructure             = DataElement.Dimensions;
	ResourcesStructure              = DataElement.Resources;
	AttributesStructure1            = DataElement.Attributes;
	NumeratorStructure            = DataElement.Numerator;
	
	UserHeader = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Calculation register %1';"),
		RegisterPresentation);
	
	DetailedRecordsGroup = DetailedRecordsByRegister(DCSettings, RegisterType + "_" + RegisterName,
		UserHeader);
	
	If NumeratorStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Numerator");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", "№CurrentDocumentDCSOutputItemGroup");
		
		PlaceDSCFieldsGroup(NumeratorStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If StandardAttributesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "StandardAttributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Standard attributes.';"));
		
		PlaceDSCFieldsGroup(StandardAttributesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If DimensionStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Dimensions");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Dimensions';"));
		
		PlaceDSCFieldsGroup(DimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If ResourcesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Resources");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Resources';"));
		
		PlaceDSCFieldsGroup(ResourcesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
	If AttributesStructure1.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Attributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         False);
		GroupParameters.Insert("SelectedGroupPresentation", NStr("en = 'Attributes';"));
		
		PlaceDSCFieldsGroup(AttributesStructure1, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ReportStructureGeneration

Procedure PrepareHorizontalOptionOfAccountingRegisters(DCSettings, DCDataSet, DataElement)
	
	RegisterType            = "AccountingRegister";
	RegisterName            = DataElement.RegisterName;
	RegisterPresentation  = DataElement.RegisterPresentation;
	
	StandardAttributesStructure = DataElement.StandardAttributes;
	DimensionStructure             = DataElement.Dimensions;
	DimensionStructureDr           = DataElement.DimensionsDr;
	DimensionStructureCr           = DataElement.DimensionsCr;
	ResourcesStructure              = DataElement.Resources;
	ResourcesStructureDr            = DataElement.ResourcesDr;
	ResourcesStructureCr            = DataElement.ResourcesCr;
	ExtDimensionStructure              = DataElement.ExtDimension;
	ExtDimensionStructureDr            = DataElement.ExtDimensionDr;
	ExtDimensionStructureCr            = DataElement.ExtDimensionCr;
	AttributesStructure1            = DataElement.Attributes;
	
	UserHeader = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Accounting register %1';"),
		RegisterPresentation);
	
	DetailedRecordsGroup = DetailedRecordsByRegister(DCSettings,
		RegisterType + "_" + RegisterName, UserHeader);
	
	If StandardAttributesStructure.Count() > 0 Then
		
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "StandardAttributes");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(StandardAttributesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Dimensions");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(DimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructureDr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "DimensionsDr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(DimensionStructureDr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ExtDimensionStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "ExtDimension");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ExtDimensionStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ExtDimensionStructureDr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "ExtDimensionDr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ExtDimensionStructureDr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ResourcesStructureDr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "ResourcesDr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ResourcesStructureDr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If DimensionStructureCr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "DimensionsCr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(DimensionStructureCr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ExtDimensionStructureCr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "ExtDimensionCr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ExtDimensionStructureCr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ResourcesStructureCr.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "ResourcesCr");
		GroupParameters.Insert("SelectedGroupLocation",  DataCompositionFieldPlacement.Vertically);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ResourcesStructureCr, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If ResourcesStructure.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Resources");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(ResourcesStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
	If AttributesStructure1.Count() > 0 Then
	
		GroupParameters = New Structure;
		GroupParameters.Insert("GroupName",                    "Attributes");
		GroupParameters.Insert("SelectedGroupLocation",  Undefined);
		GroupParameters.Insert("SelectedGroupEmpty",         True);
		GroupParameters.Insert("SelectedGroupPresentation", "");
		
		PlaceDSCFieldsGroup(AttributesStructure1, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName);
	
	EndIf;
	
EndProcedure

// Adds the data set field.
// 
// Parameters:
//   DataSet - DataCompositionSchemaDataSetUnion,
//               - DataCompositionSchemaDataSetQuery,
//               - DataCompositionSchemaDataSetObject,
//               - Undefined
//   Field - String
//   Title - String
//   DataPath - Undefined
//               - String
//
// Returns:
//   DataCompositionSchemaDataSetField, DataCompositionSchemaDataSetFieldFolder - Details
//
Function AddDataSetField(DataSet, Field, Title, DataPath = Undefined)
	
	If DataPath = Undefined Then
		DataPath = Field;
	EndIf;
	
	DataSetField             = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	DataSetField.Field        = Field;
	DataSetField.Title   = Title;
	DataSetField.DataPath = DataPath;
	Return DataSetField;
	
EndFunction

Function AddSelectedField(Where, DCNameOrField, Title = "") Export
	
	If TypeOf(Where) = Type("DataCompositionSettingsComposer") Then
		SelectedDCFields = Where.Settings.Selection;
	ElsIf TypeOf(Where) = Type("DataCompositionSettings") Or TypeOf(Where) = Type("DataCompositionGroup") Then
		SelectedDCFields = Where.Selection;
	Else
		SelectedDCFields = Where;
	EndIf;
	
	If TypeOf(DCNameOrField) = Type("String") Then
		DCField = New DataCompositionField(DCNameOrField);
	Else
		DCField = DCNameOrField;
	EndIf;
	
	SelectedDCField      = SelectedDCFields.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = DCField;
	
	If Title <> "" Then
		SelectedDCField.Title = Title;
	EndIf;
	
	Return SelectedDCField;
	
EndFunction

Function AddSelectedFieldGroup(Where, DCNameOrField, Title = "", Placement = Undefined)
	
	If TypeOf(Where) = Type("DataCompositionSettingsComposer") Then
		SelectedDCFields = Where.Settings.Selection;
	ElsIf TypeOf(Where) = Type("DataCompositionSettings") Or TypeOf(Where) = Type("DataCompositionGroup") Then
		SelectedDCFields = Where.Selection;
	Else
		SelectedDCFields = Where;
	EndIf;
	
	If TypeOf(DCNameOrField) = Type("String") Then
		DCField = New DataCompositionField(DCNameOrField);
	Else
		DCField = DCNameOrField;
	EndIf;
	
	SelectedDCField      = SelectedDCFields.Items.Add(Type("DataCompositionSelectedFieldGroup"));
	SelectedDCField.Field = DCField;
	
	If Placement <> Undefined Then
		SelectedDCField.Placement = Placement;
	EndIf;
	
	If Title <> "" Then
		SelectedDCField.Title = Title;
	EndIf;
	
	Return SelectedDCField;
	
EndFunction

Procedure AddRecordsCountResource(Schema)
	
	RecordsCountField = Schema.TotalFields.Find("RegisterRecordCount1");
	If RecordsCountField <> Undefined Then
		Return;
	EndIf;
	
	TotalField = Schema.TotalFields.Add();
	TotalField.Groups.Add("RegisterName");
	TotalField.DataPath = "RegisterRecordCount1";
	TotalField.Expression = "Sum(RegisterRecordCount1)";
	
EndProcedure

#EndRegion

#Region Other

Procedure SetSettings(Group, Settings)

	For Each SettingItem In Settings Do
	
		Setting = Group.OutputParameters.Items.Find(SettingItem.Key);
		If Setting <> Undefined Then
			SetOutputParameter(Group, SettingItem.Key, SettingItem.Value);
		EndIf;
	
	EndDo;
	
EndProcedure

Function DetailedRecordsByRegister(DCSettings, GroupName, UserHeader)
	
	GroupByRegister = DCSettings.Structure.Add(Type("DataCompositionGroup"));
	GroupByRegister.Name                                    = GroupName;
	GroupByRegister.UserSettingPresentation = UserHeader;
	GroupByRegister.Use                          = True;
	
	GroupByRegister.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	GroupByRegister.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	HiseFilerInRegisterRecordsTable(GroupByRegister);
	
	GroupFieldByRegister = GroupByRegister.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupFieldByRegister.Use  = True;
	GroupFieldByRegister.Field           = New DataCompositionField("RegisterName");
	GroupFieldByRegister.GroupType = DataCompositionGroupType.Items;
	GroupFieldByRegister.AdditionType  = DataCompositionPeriodAdditionType.None;
	
	DetailedRecordsByRegister = GroupByRegister.Structure.Add(Type("DataCompositionGroup"));
	DetailedRecordsByRegister.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	DetailedRecordsByRegister.Use = True;
	
	Return DetailedRecordsByRegister;
	
EndFunction

Procedure PlaceDSCFieldsGroup(FieldsStructure, DCDataSet, DetailedRecordsGroup, GroupParameters, RegisterType, RegisterName)
	
	If GroupParameters.SelectedGroupEmpty Then
		LocalNameOfGroup     = New DataCompositionField("");
		LocalPresentationOfGroup = "";
	Else
		LocalNameOfGroup           = GroupParameters.GroupName;
		LocalPresentationOfGroup = GroupParameters.SelectedGroupPresentation;
	EndIf;
	
	Group = AddSelectedFieldGroup(DetailedRecordsGroup, LocalNameOfGroup, LocalPresentationOfGroup,
		GroupParameters.SelectedGroupLocation);
	
	For Each StructureItem In FieldsStructure Do
	
		Name           = StructureItem.Key;
		Presentation = StructureItem.Value;
		GroupName     = GroupParameters.GroupName;
		
		If GroupName <> "StandardAttributes" And GroupName <> "Numerator" And GroupName <> "DimensionsDr"
			And GroupName <> "DimensionsCr" And GroupName <> "ResourcesDr" And GroupName <> "ResourcesCr" And GroupName <> "ExtDimensionDr"
			And GroupName <> "ExtDimensionCr" And GroupName <> "ExtDimension" Then
			
			If RegisterType = "AccumulationRegister" Then
				MetadataObject = Metadata.AccumulationRegisters[RegisterName][GroupName][Name];
			ElsIf RegisterType = "InformationRegister" Then
				MetadataObject = Metadata.InformationRegisters[RegisterName][GroupName][Name];
			ElsIf RegisterType = "CalculationRegister" Then
				MetadataObject = Metadata.CalculationRegisters[RegisterName][GroupName][Name];
			ElsIf RegisterType = "AccountingRegister" Then
				MetadataObject = Metadata.AccountingRegisters[RegisterName][GroupName][Name];
			EndIf;
			
			If Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
				Continue;
			EndIf;
			
		EndIf;
	
		AddDataSetField(DCDataSet, Name, Presentation);
		AddSelectedField(Group, Name, Presentation);
	
	EndDo;
	
EndProcedure

Procedure AddFields(FieldList, Val FieldsPresentationNames, Val RegisterMetadata, Val CollectionName = "")
	
	For Each Field In FieldsPresentationNames Do
		If Not ValueIsFilled(CollectionName) 
			Or Common.MetadataObjectAvailableByFunctionalOptions(RegisterMetadata[CollectionName][Field.Key]) Then
			FieldList.Add(Field.Key);
		EndIf;
	EndDo;
	
EndProcedure

Function FieldsPresentationNames(RegisterFields, Val ExcludedFields = Undefined)
	
	If ExcludedFields = Undefined Then
		ExcludedFields = New Array;
	EndIf;
	
	IsExcludableType = Type("ValueStorage");
	
	Result = New Structure;
	For Each RegisterField In RegisterFields Do
	
		If ExcludedFields.Find(RegisterField.Name) = Undefined
			And Not RegisterField.Type.ContainsType(IsExcludableType) Then 
			
			Result.Insert(RegisterField.Name, RegisterField.Presentation());
		EndIf;
	
	EndDo;
	
	Return Result;
	
EndFunction

Function FieldsNumbers(DataSet)
	
	Result = New Structure;
	
	MaxNumber = Max(DataSet.StandardAttributes.Count(),
		DataSet.Dimensions.Count(),
		DataSet.Resources.Count(),
		DataSet.Attributes.Count());
			
	For IndexOf = 1 To MaxNumber Do
		IndexAsString = Format(IndexOf, "NG=0");
		Result.Insert("CurrentDocumentDCSOutputItemGroup" + IndexAsString, IndexAsString);
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region ShowDCS

Procedure RegisterResult(Settings, ResultDocument, DocumentRecorder)
	
	FillNotes(Settings);
	
 	FullRegisterName = Undefined;
	
	For LineNumber = 1 To ResultDocument.TableHeight Do
		
		For ColumnNumber = 1 To 2 Do // table header search in the first two columns
	
			Area = ResultDocument.Area(LineNumber, ColumnNumber);
			
			RegisterProperties = RegisterProperties(Area.Text);
			If RegisterProperties = Undefined Then
				Continue;
			EndIf;
			
			FullRegisterName = RegisterProperties.FullRegisterName;
			
			HeaderDetails = New Structure;
			HeaderDetails.Insert("RegisterType", RegisterProperties.RegisterType);
			HeaderDetails.Insert("RegisterName", RegisterProperties.RegisterName);
			HeaderDetails.Insert("Recorder", DocumentRecorder);
			HeaderDetails.Insert("RecorderFieldName", RegisterProperties.RecorderFieldName);
			
			Area.Details  = HeaderDetails;
			ReportsServer.OutputHyperlink(Area, HeaderDetails, Area.Text);
			
			NotesBorder = 1;
			
			Break;
		EndDo;
		
		NumeratorArea = ResultDocument.Area(LineNumber, 1);
	
		If Not IsNumber(NumeratorArea.Text) Then
			
			If StrFind(NumeratorArea.Text, "№CurrentDocumentDCSOutputItemGroup") > 0 Then
				NumeratorArea.Text = "№";
				NumeratorArea.ColumnWidth = 5;
			EndIf;
			
			Continue;
		EndIf;
	
		NumeratorArea.Indent = 0;
		NumeratorArea.HorizontalAlign = HorizontalAlign.Left;

		If FullRegisterName = Undefined
			Or Remarks = Undefined Then 
			
			Continue;
		EndIf;
		
		Search = New Structure("FullRegisterName, Floor", FullRegisterName, NumeratorArea.Text);
		FoundNotes = Remarks.FindRows(Search); // Array of ValueTableRow
		
		If FoundNotes.Count() = 0 Then 
			Continue;
		EndIf;
		
		NoteProperties = FoundNotes[0];
		
		StringHeight = NoteProperties.NumberOfStoreys + 1;
		If NotesBorder = StringHeight Then
			
			NoteText2 = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'In this line: %1';"), NoteProperties.Note + ".");
			
			NumeratorArea.Comment.Text = NoteText2;
		Else
			NotesBorder = NotesBorder + 1;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region AppearanceSection

Procedure HideParametersAndFilters(DCSettings)
	
	Settings = New Structure;
	Settings.Insert("FilterOutput",           DataCompositionTextOutputType.DontOutput);
	Settings.Insert("DataParametersOutput", DataCompositionTextOutputType.DontOutput);
	SetSettings(DCSettings, Settings);
	
EndProcedure

Procedure HiseFilerInRegisterRecordsTable(GroupByRegister)
	
	Settings = New Structure;
	Settings.Insert("FilterOutput", DataCompositionTextOutputType.DontOutput);
	SetSettings(GroupByRegister, Settings);
	
EndProcedure

Procedure SetConditionalAppearance(Settings)
	
	AppearanceItems = Settings.ConditionalAppearance.Items;
	
	ApplyAppearanceNegativeNumbers(AppearanceItems);
	ArrangeResources(Settings);
	
	If RegistersProperties.Find("Balance", "AccumulationRegisterType") = Undefined Then 
		Return;
	EndIf;
	
	ApplyAppearanceRegisterRecordType(AppearanceItems, AccumulationRecordType.Receipt);
	ApplyAppearanceRegisterRecordType(AppearanceItems, AccumulationRecordType.Expense);
	
EndProcedure

Procedure ApplyAppearanceNegativeNumbers(AppearanceItems)
	
	Item = AppearanceItems.Add();
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DataParameters.NegativeInRed");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	Item.Appearance.SetParameterValue("MarkNegatives", True);
	
	Item.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Item.Use = True;
	
EndProcedure

Procedure ApplyAppearanceRegisterRecordType(AppearanceItems, RecordType)
	
	RegisterRecordTypeField = New DataCompositionField("RecordType");
	
	Item = AppearanceItems.Add();
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("DataParameters.HighlightAccumulationRecordKind");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = RegisterRecordTypeField;
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = RecordType;
	
	FormattedFields = Item.Fields.Items;
	FormattedField = FormattedFields.Add();
	FormattedField.Field = RegisterRecordTypeField;
	
	Item.UseInHeader = DataCompositionConditionalAppearanceUse.DontUse;
	Item.UseInFieldsHeader = DataCompositionConditionalAppearanceUse.DontUse;
	
	If RecordType = AccumulationRecordType.Receipt Then 
		RegisterRecordKindColor = Metadata.StyleItems.SuccessResultColor.Value;
	Else
		RegisterRecordKindColor = StyleColors.NegativeTextColor;
	EndIf;
	
	Item.Appearance.SetParameterValue("TextColor", RegisterRecordKindColor);
	Item.Use = True;
	
EndProcedure

Procedure ArrangeResources(Settings)
	
	For Each RegisterProperties In RegistersProperties Do 
		
		ResourceFormats = RegisterProperties.ResourceFormats;
		
		If ResourceFormats.Count() = 0 Then 
			Continue;
		EndIf;
		
		DetailedRegisterEntries = DetailedRegisterEntries(Settings, RegisterProperties);
		
		If DetailedRegisterEntries = Undefined Then 
			Continue;
		EndIf;
		
		AppearanceItems = DetailedRegisterEntries.ConditionalAppearance.Items;
		
		For Each ResourceFormat In ResourceFormats Do 
			
			Item = AppearanceItems.Add();
			
			For Each Resource In ResourceFormat.Value Do 
				
				FormattedField = Item.Fields.Items.Add();
				FormattedField.Field = New DataCompositionField(Resource);
				
			EndDo;
			
			Item.Appearance.SetParameterValue("Format", ResourceFormat.Key);
			
			Item.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
			Item.Use = True;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function DetailedRegisterEntries(Settings, RegisterProperties, StructureItems = Undefined, DetailedRegisterEntries = Undefined)
	
	If StructureItems = Undefined Then 
		
		GroupingARegister = GroupingARegister(Settings.Structure, RegisterProperties);
		
		If GroupingARegister = Undefined Then 
			Return Undefined;
		EndIf;
		
		StructureItems = GroupingARegister.Structure;
		
	EndIf;
	
	For Each StructureItem In StructureItems Do 
		
		If TypeOf(StructureItem) <> Type("DataCompositionGroup") Then 
			Continue;
		EndIf;
		
		If StructureItem.GroupFields.Items.Count() = 0 Then 
			DetailedRegisterEntries = StructureItem;
		Else
			DetailedRegisterEntries(Settings, RegisterProperties, StructureItem.Structure, DetailedRegisterEntries);
		EndIf;
		
	EndDo;
	
	Return DetailedRegisterEntries;
	
EndFunction

Function GroupingARegister(StructureItems, RegisterProperties)
	
	For Each StructureItem In StructureItems Do 
		
		If TypeOf(StructureItem) <> Type("DataCompositionGroup") Then 
			Continue;
		EndIf;
		
		If StructureItem.Name = RegisterProperties.GroupName Then 
			Return StructureItem;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region RegistersPropertiesGet

Procedure GetRegistersProperties(Context, OwnerDocument = Undefined)
	
	RegistersProperties(Context);
	
	If RegistersProperties.Count() > 0
		Or OwnerDocument = Undefined Then 
		
		CacheRegistersProperties(RegistersProperties, Context);
		Return;
	EndIf;
	
	DocumentRegisterRecords = RegistersWithDocumentRecords(OwnerDocument);
	RecordsCount = RecordsCountByRecorder(OwnerDocument, DocumentRegisterRecords);
	
	For Each Movement In DocumentRegisterRecords Do
		
		RegisterMetadata = Movement.Key; // MetadataObjectInformationRegister, MetadataObjectAccumulationRegister, MetadataObjectCalculationRegister
		
		RegisterProperties = RegistersProperties.Add();
		RegisterProperties.RecorderFieldName = Movement.Value;
		RegisterProperties.FullRegisterName = RegisterMetadata.FullName();
		RegisterProperties.GroupName = StrReplace(RegisterProperties.FullRegisterName, ".", "_");
		RegisterProperties.RegisterName = RegisterMetadata.Name;
		RegisterProperties.RegisterPresentation = RegisterMetadata.Presentation();
		RegisterProperties.RecordsCount = RecordsCount[RegisterProperties.GroupName];
		
		If Common.IsAccumulationRegister(RegisterMetadata) Then
			
			RegisterProperties.RegisterType = "AccumulationRegister";
			RegisterProperties.RegisterKindPresentation = NStr("en = 'Accumulation register';");
			RegisterProperties.AccumulationRegisterType = RegisterMetadata.RegisterType;
			RegisterProperties.Priority = 1;
			
		ElsIf Common.IsInformationRegister(RegisterMetadata) Then
			
			RegisterProperties.RegisterType = "InformationRegister";
			RegisterProperties.RegisterKindPresentation = NStr("en = 'Information register';");
			RegisterProperties.InformationRegisterPeriodicity = RegisterMetadata.InformationRegisterPeriodicity;
			RegisterProperties.InformationRegisterWriteMode = RegisterMetadata.WriteMode;
			RegisterProperties.Priority  = 2;
			
		ElsIf Common.IsAccountingRegister(RegisterMetadata) Then
			
			RegisterProperties.RegisterType = "AccountingRegister";
			RegisterProperties.RegisterKindPresentation = NStr("en = 'Accounting register';");
			RegisterProperties.Priority = 3;
			
		ElsIf Common.IsCalculationRegister(RegisterMetadata) Then
			
			RegisterProperties.RegisterType = "CalculationRegister";
			RegisterProperties.RegisterKindPresentation = NStr("en = 'Calculation register';");
			RegisterProperties.CalculationRegisterPeriodicity = RegisterMetadata.Periodicity;
			RegisterProperties.Priority = 4;
			
		EndIf;
		
		TableHeading = RegisterProperties.RegisterKindPresentation + " """ + RegisterProperties.RegisterPresentation + """";
		RegisterProperties.TableHeading = Upper(TableHeading);
		
		DefineResourceFormats(RegisterMetadata, RegisterProperties);
		
	EndDo;
	
	RegistersProperties.Sort("Priority, RegisterPresentation");
	RegistersProperties.Indexes.Add("GroupName, RegisterName, RegisterType, AccumulationRegisterType, TableHeading");
	
	CacheRegistersProperties(RegistersProperties, Context);
	
EndProcedure

Procedure RegistersProperties(Context)
	
	RegistersProperties = NewRegisterProperties();
	
	If TypeOf(Context) = Type("ClientApplicationForm") Then 
		
		RegistriesPropertiesAddress = CommonClientServer.StructureProperty(
			Context.ReportSettings, "RegistriesPropertiesAddress");
		
	ElsIf TypeOf(Context) = Type("DataCompositionSettings") Then 
		
		RegistriesPropertiesAddress = CommonClientServer.StructureProperty(
			Context.AdditionalProperties, "RegistriesPropertiesAddress");
	Else
		Return;
	EndIf;
	
	If Not IsTempStorageURL(RegistriesPropertiesAddress) Then 
		Return;
	EndIf;
	
	RegistersPropertiesFromCache = GetFromTempStorage(RegistriesPropertiesAddress);
	If TypeOf(RegistersPropertiesFromCache) = Type("ValueTable") Then 
		RegistersProperties = RegistersPropertiesFromCache;
	EndIf;
	
EndProcedure

Procedure CacheRegistersProperties(RegistersProperties, Context)
	
	RegistriesPropertiesAddress = PutToTempStorage(RegistersProperties);
	If TypeOf(Context) = Type("ClientApplicationForm") Then 
		Context.ReportSettings.Insert("RegistriesPropertiesAddress", RegistriesPropertiesAddress);
	ElsIf TypeOf(Context) = Type("DataCompositionSettings") Then
		Context.AdditionalProperties.Insert("RegistriesPropertiesAddress", RegistriesPropertiesAddress);
	EndIf;
	
EndProcedure

// The constructor of a document register record collection, each element of which stores information on the register
//  whose recorder is an owner document.
//
// Returns:
//   ValueTable:
//     * Priority - Number
//     * FullRegisterName - String
//     * GroupName - String
//     * RegisterName - String
//     * RegisterPresentation - String
//     * RegisterType - String
//     * AccumulationRegisterType - String
//     * RegisterKindPresentation - String
//     * CalculationRegisterPeriodicity - String
//     * InformationRegisterPeriodicity - String
//     * InformationRegisterWriteMode - String
//     * RecorderFieldName - String
//     * RecordsCount - Number
//     * TableHeading - String
//     * ResourceFormats - Map
//
Function NewRegisterProperties()
	
	RegistersPropertiesPalette = New ValueTable;
	
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	MapDetails = New TypeDescription("Map");
	
	RegistersPropertiesPalette.Columns.Add("Priority", NumberDetails);
	RegistersPropertiesPalette.Columns.Add("FullRegisterName", RowDescription);
	RegistersPropertiesPalette.Columns.Add("GroupName", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RegisterName", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RegisterPresentation", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RegisterType", RowDescription);
	RegistersPropertiesPalette.Columns.Add("AccumulationRegisterType", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RegisterKindPresentation", RowDescription);
	RegistersPropertiesPalette.Columns.Add("CalculationRegisterPeriodicity", RowDescription);
	RegistersPropertiesPalette.Columns.Add("InformationRegisterPeriodicity", RowDescription);
	RegistersPropertiesPalette.Columns.Add("InformationRegisterWriteMode", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RecorderFieldName", RowDescription);
	RegistersPropertiesPalette.Columns.Add("RecordsCount", NumberDetails);
	RegistersPropertiesPalette.Columns.Add("TableHeading", RowDescription);
	RegistersPropertiesPalette.Columns.Add("ResourceFormats", MapDetails);
	
	Return RegistersPropertiesPalette;
	
EndFunction

Procedure DefineResourceFormats(RegisterMetadata, RegisterProperties)
	
	ResourceFormatTemplate = "ND=%1; NFD=%2; NGS=' '";
	IsAccountingRegister = Common.IsAccountingRegister(RegisterMetadata);
	
	For Each Resource In RegisterMetadata.Resources Do 
		
		ResourceType = Resource.Type;
		
		If Not ResourceType.ContainsType(Type("Number")) Then 
			Continue;
		EndIf;
		
		ResourceQualifiers = ResourceType.NumberQualifiers;
		
		ResourceFormat = StringFunctionsClientServer.SubstituteParametersToString(
			ResourceFormatTemplate, ResourceQualifiers.Digits, ResourceQualifiers.FractionDigits);
		
		FormatResources = RegisterProperties.ResourceFormats[ResourceFormat];
		
		If FormatResources = Undefined Then 
			FormatResources = New Array;
		EndIf;
		
		If IsAccountingRegister
			And RegisterMetadata.Correspondence
			And Not Resource.Balance Then 
			
			FormatResources.Add(Resource.Name + "Dr");
			FormatResources.Add(Resource.Name + "Cr");
		Else
			FormatResources.Add(Resource.Name);
		EndIf;
		
		RegisterProperties.ResourceFormats.Insert(ResourceFormat, FormatResources);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region NotesGeneration

Procedure FillNotes(Settings)
	
	If ParentOptionKey <> "Additional" Then 
		Return;
	EndIf;
	
	Remarks = NotesPropertiesPalette();
	
	For Each RegisterProperties In RegistersProperties Do 
	
		SelectedFieldsGroups = New Array;
		Groups = Settings.Structure;
		FindSelectedFieldsGroups(Groups, SelectedFieldsGroups, RegisterProperties.GroupName);
		
		NumeratorField  = New DataCompositionField("Numerator");
		StringHeight = StringHeight(NumeratorField, SelectedFieldsGroups);
		
		For IndexOf = 0 To StringHeight - 1 Do
		
			NoteText2 = "";
		
			For Each GroupOfFields In SelectedFieldsGroups Do
				If GroupOfFields.Field = NumeratorField Then
					Continue;
				EndIf;
		
				Title = "";
				HeaderOfStandardBankDetails = NStr("en = 'Standard attributes.';");
				MeasurementHeader = NStr("en = 'Dimensions';");
				ResourceHeader = NStr("en = 'Resources';");
				TitleOfTheBankDetails = NStr("en = 'Attributes';");
				TitleOfTheCalculationData = NStr("en = 'Calculation data';");
				
				If GroupOfFields.Title = HeaderOfStandardBankDetails Then
					Title = NStr("en = 'Standard attribute';");
				ElsIf GroupOfFields.Title = MeasurementHeader Then
					Title = NStr("en = 'Dimension';");
				ElsIf GroupOfFields.Title = ResourceHeader Then
					Title = NStr("en = 'Resource';");
				ElsIf GroupOfFields.Title = TitleOfTheBankDetails Then
					Title = NStr("en = 'Attribute';");
				ElsIf GroupOfFields.Title = TitleOfTheCalculationData Then
					Title = NStr("en = 'Calculation data';");
				EndIf;

				Items = GroupOfFields.Items; // DataCompositionSelectedFieldCollection

				If IndexOf <= Items.Count() - 1 Then
					SelectedField = Items[IndexOf]; // DataCompositionSelectedField
					FieldTitle = SelectedField.Title;
					 
					If SelectedField.Use Then
						NoteText2 = NoteText2
							+ ?(ValueIsFilled(NoteText2), ", ", "")
							+ FieldTitle + " (" + Title + ")";
					EndIf;
				EndIf;
			EndDo;
			
			Note = Remarks.Add();
			Note.FullRegisterName = RegisterProperties.FullRegisterName;
			Note.Note = NoteText2;
			Note.Floor = Format(IndexOf + 1, "NG=0");
			Note.NumberOfStoreys = StringHeight;
		
		EndDo;
	
	EndDo;
	
	Remarks.Indexes.Add("FullRegisterName, Floor");
	
EndProcedure

// The constructor of a note collection, each element of which stores a note text,
//   for numbered rows of the vertical report option.
//
// Returns:
//   ValueTable:
//     * FullRegisterName - String
//     * Note - String
//     * Floor - String
//     * NumberOfStoreys - Number
//
Function NotesPropertiesPalette()
	
	NotesPropertiesPalette = New ValueTable;
	
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	
	NotesPropertiesPalette.Columns.Add("FullRegisterName", RowDescription);
	NotesPropertiesPalette.Columns.Add("Note", RowDescription);
	NotesPropertiesPalette.Columns.Add("Floor", RowDescription);
	NotesPropertiesPalette.Columns.Add("NumberOfStoreys", NumberDetails);
	
	Return NotesPropertiesPalette;
	
EndFunction

Function StringHeight(NumeratorField, SelectedFieldsArray)
	
	StringHeight = 0;
	For Each SelectedGroup In SelectedFieldsArray Do
		If SelectedGroup.Field = NumeratorField Then
			Items = SelectedGroup.Items;
			For Each Item In Items Do
				If Item.Use Then
					StringHeight = StringHeight + 1;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return StringHeight;
	
EndFunction

#EndRegion

#Region Other

Function ParentOptionKey(Context, VariantKey, Settings)
	
	ParentOptionKey = CommonClientServer.StructureProperty(
		Settings.AdditionalProperties, "ParentOptionKey");
	
	If ParentOptionKey <> Undefined Then 
		Return ParentOptionKey;
	EndIf;
	
	PredefinedOptionKey = PredefinedOptionKey(VariantKey);
	
	ReportVariant = Undefined;
	If TypeOf(Context) = Type("ClientApplicationForm") Then 
		ReportVariant = Context.ReportSettings.OptionRef;
	ElsIf TypeOf(Context) = Type("Structure") Then 
		ReportVariant = CommonClientServer.StructureProperty(Context, "OptionRef1");
	EndIf;
	
	If Not ValueIsFilled(ReportVariant) Then 
		Return PredefinedOptionKey;
	EndIf;
	
	ReportOptionParent = Common.ObjectAttributeValue(ReportVariant, "Parent");
	
	If Not ValueIsFilled(ReportOptionParent) Then 
		Return PredefinedOptionKey;
	EndIf;
	
	Return Common.ObjectAttributeValue(ReportOptionParent, "VariantKey");
	
EndFunction

Function PredefinedOptionKey(VariantKey)
	
	PredefinedOptionKey = Undefined;
	
	SettingVariants = DataCompositionSchema.SettingVariants;
	
	For Each SettingsOption In SettingVariants Do 
		
		If SettingsOption.Name = VariantKey Then 
			PredefinedOptionKey = VariantKey;
			Break;
		EndIf;
		
	EndDo;
	
	If PredefinedOptionKey <> Undefined Then 
		Return PredefinedOptionKey;
	EndIf;
	
	Return SettingVariants[0].Name;
	
EndFunction

// Returns a collection of registers for which the current user has the access right.
//
// Parameters:
//   Recorder - DocumentRef
//   RegisterRecords - RegisterRecordsCollection
//            - Undefined
//
// Returns:
//   Map of KeyAndValue:
//     * Key - MetadataObjectInformationRegister
//            - MetadataObjectAccumulationRegister
//            - MetadataObjectCalculationRegister
//     * Value - String
//
Function RegistersWithDocumentRecords(Recorder, RegisterRecords = Undefined)
	
	If RegisterRecords = Undefined Then 
		RegisterRecords = Recorder.Metadata().RegisterRecords;
	EndIf;
	
	Result = New Map;
	For Each RegisterMetadata In RegisterRecords Do
		If Not AccessRight("View", RegisterMetadata)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(RegisterMetadata) Then
			Continue;
		EndIf;
		
		Result.Insert(RegisterMetadata, "Recorder");
	EndDo;
	
	AdditionalRegisters = New Map;
	DocumentRecordsReportOverridable.OnDetermineRegistersWithRecords(Recorder, AdditionalRegisters);
	
	For Each AdditionalRegister In AdditionalRegisters Do
		RegisterMetadata = AdditionalRegister.Key;
		If Not AccessRight("View", RegisterMetadata)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(RegisterMetadata) Then
			Continue;
		EndIf;
		Result.Insert(RegisterMetadata, AdditionalRegister.Value);
	EndDo;
	
	Return Result;
	
EndFunction

Function RecordsCountByRecorder(Recorder, DocumentRegisterRecords)
	
	CalculatedCount = New Map;
	If DocumentRegisterRecords.Count() = 0 Then
		Return CalculatedCount;
	EndIf;
	
	QueryText = "";
	For Each Movement In DocumentRegisterRecords Do
		
		RegisterMetadata = Movement.Key;
		
		If Not Common.MetadataObjectAvailableByFunctionalOptions(RegisterMetadata) Then
			Continue;
		EndIf;
		
		FullRegisterName = RegisterMetadata.FullName();
		
		QueryTextTemplate =
		"SELECT ALLOWED
		|	""&FullRegisterName"" AS FullRegisterName,
		|	COUNT(*) AS Count
		|FROM
		|	&CurrentTable AS CurrentTable
		|WHERE
		|	&Condition";
		
		ConditionText = StringFunctionsClientServer.SubstituteParametersToString("%1 = &OwnerDocument", Movement.Value);
		QueryTextTemplate = StrReplace(QueryTextTemplate, "&FullRegisterName", StrReplace(FullRegisterName, ".", "_"));
		QueryTextTemplate = StrReplace(QueryTextTemplate, "&Condition", ConditionText);
		QueryTextTemplate = StrReplace(QueryTextTemplate, "&CurrentTable", FullRegisterName);
		
		If ValueIsFilled(QueryText) Then
			
			QueryText = StringFunctionsClientServer.SubstituteParametersToString(
				"%1 UNION ALL  %2", QueryText, StrReplace(QueryTextTemplate, "SELECT ALLOWED", "SELECT")); // @query-part-2 @query-part-3 for this case.
			
		Else
			QueryText = QueryTextTemplate;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("OwnerDocument", Recorder);
	Result = Query.Execute().Unload();
	
	For Each ResultString1 In Result Do
		CalculatedCount.Insert(ResultString1.FullRegisterName, ResultString1.Count);
	EndDo;
	
	DocumentRecordsReportOverridable.OnCalculateRecordsCount(Recorder, CalculatedCount);
	
	Return CalculatedCount;
	
EndFunction

Procedure RedefineDSCTemplate(DCSchema, SetIndex, RegisterType, RegisterKindPresentation, RegisterName)
	
	TheStructureOfTheSearch = New Structure("RegisterType, RegisterName", RegisterType, RegisterName);
	RegisterSettings = RegistersProperties.FindRows(TheStructureOfTheSearch);
	If RegisterSettings.Count() = 0 Then
		Return;
	EndIf;
		
	RegisterPresentation = RegisterSettings[0].RegisterPresentation;
	GroupHeader = StringFunctionsClientServer.SubstituteParametersToString("%1 ""%2""",
		RegisterKindPresentation, RegisterPresentation);
	
	Template       = DCSchema.Templates.Add();
	Template.Name   = "Template" + Format(SetIndex + 1, "NG=0");
	Template.Template = New DataCompositionAreaTemplate;
	
	Parameter           = Template.Parameters.Add(Type("DataCompositionExpressionAreaParameter"));
	Parameter.Name       = "RecordsCount";
	Parameter.Expression = "RegisterRecordCount1";
	
	GroupTemplate                = DCSchema.GroupTemplates.Add();
	GroupTemplate.GroupName = RegisterType + "_" + RegisterName;
	GroupTemplate.TemplateType      = DataCompositionAreaTemplateType.Header;
	GroupTemplate.Template          = "Template" + Format(SetIndex + 1, "NG=0");
	
	AreaTemplate = Template.Template;
	TemplateString = AreaTemplate.Add(Type("DataCompositionAreaTemplateTableRow"));
	Cell       = TemplateString.Cells.Add();
	
	CellAppearance = Cell.Appearance.Items;
	
	Font = CellAppearance.Find("Font");
	
	If Font <> Undefined Then
		GroupHeaderFont = Metadata.StyleItems.DocumentRecordsReportGroupHeadingFont;
		Font.Value      = GroupHeaderFont.Value;
		Font.Use = True;
	EndIf;
	
	Location = CellAppearance.Find("Location");
	
	If Location <> Undefined Then
		Location.Value      = DataCompositionTextPlacementType.Wrap;
		Location.Use = True;
	EndIf;
	
	DCArea          = Cell.Items.Add(Type("DataCompositionAreaTemplateField"));
	DCArea.Value = GroupHeader + " (";
	
	DCArea          = Cell.Items.Add(Type("DataCompositionAreaTemplateField"));
	DCArea.Value = New DataCompositionParameter(Parameter.Name);
	
	DCArea          = Cell.Items.Add(Type("DataCompositionAreaTemplateField"));
	DCArea.Value = ")";
	
EndProcedure

Function RegistersList()
	
	RegistersList = New ValueList;
	For Each RegisterProperties In RegistersProperties Do
		ItemPresentation = RegisterProperties.RegisterKindPresentation + " " + RegisterProperties.RegisterPresentation;
		RegistersList.Add(RegisterProperties.GroupName, ItemPresentation);
	EndDo;
	Return RegistersList;
	
EndFunction

Function SelectedRegistersList(RegistersList, Settings, UserSettings)
	
	SettingItem = Settings.DataParameters.Items.Find("RegistersList");
	
	If SettingItem = Undefined Then 
		Return RegistersList;
	EndIf;
	
	UserSettingItem = UserSettings.Items.Find(
		SettingItem.UserSettingID);
	
	If UserSettingItem = Undefined Then 
		Return RegistersList;
	EndIf;
	
	If TypeOf(UserSettingItem.Value) = Type("ValueList")
		And UserSettingItem.Value.Count() > 0 Then 
		Return UserSettingItem.Value;
	EndIf;
	
	If TypeOf(UserSettingItem.Value) <> Type("String")
		Or Not ValueIsFilled(UserSettingItem.Value) Then 
		Return RegistersList;
	EndIf;
	
	SelectedRegistersList = New ValueList;
	SelectedRegistersList.Add(UserSettingItem.Value);
	
	Return SelectedRegistersList;
	
EndFunction

Procedure SetDataParameters(Settings, ParameterValues, UserSettings = Undefined)
	
	DataParameters = Settings.DataParameters.Items;
	
	For Each ParameterValue In ParameterValues Do 
		
		DataParameter = DataParameters.Find(ParameterValue.Key);
		
		If DataParameter = Undefined Then
			DataParameter = DataParameters.Add();
			DataParameter.Parameter = New DataCompositionParameter(ParameterValue.Key);
		EndIf;
		
		DataParameter.Use = True;
		DataParameter.Value = ParameterValue.Value;
		
		If Not ValueIsFilled(DataParameter.UserSettingID)
			Or TypeOf(UserSettings) <> Type("DataCompositionUserSettings") Then 
			Continue;
		EndIf;
		
		MatchingParameter = UserSettings.Items.Find(
			DataParameter.UserSettingID);
		
		If MatchingParameter <> Undefined Then 
			FillPropertyValues(MatchingParameter, DataParameter, "Use, Value");
		EndIf;
		
	EndDo;
	
EndProcedure

Function IsNumber(Val ValueToCheck)
	
	If ValueToCheck = "0" Then
		Return True;
	EndIf;
	
	NumberDetails = New TypeDescription("Number");
	
	Return NumberDetails.AdjustValue(ValueToCheck) <> 0;
	
EndFunction

Function ControlItemsPlacementParameters()
	
	Settings         = New Array;
	Control = New Structure;
	
	Control.Insert("Field",                     "RegistersList");
	Control.Insert("HorizontalStretch", False);
	Control.Insert("AutoMaxWidth",   True);
	Control.Insert("Width",                   40);
	
	Settings.Add(Control);
	
	Result = New Structure();
	Result.Insert("DataParameters", Settings);
	
	Return Result;
	
EndFunction

Function SetOutputParameter(GroupSettingsComposer, ParameterName, Value)
	
	DSCParameter = New DataCompositionParameter(ParameterName);
	If TypeOf(GroupSettingsComposer) = Type("DataCompositionSettingsComposer") Then	
		ParameterValue = GroupSettingsComposer.Settings.OutputParameters.FindParameterValue(DSCParameter);
	Else
		ParameterValue = GroupSettingsComposer.OutputParameters.FindParameterValue(DSCParameter);
	EndIf;
	
	If ParameterValue <> Undefined Then
		ParameterValue.Use = True;
		ParameterValue.Value = Value;
	EndIf;
	
	Return ParameterValue;
	
EndFunction

// Parameters:
//  StructureItems - DataCompositionSettingStructureItemCollection
//                    - DataCompositionTableStructureItemCollection
//                    - DataCompositionChartStructureItemCollection
//  SelectedGroupingsFields - an Array from DataCompositionSelectedField
//  SearchValue - String
//
Procedure FindSelectedFieldsGroups(StructureItems, SelectedFieldsGroups, SearchValue)
	
	For Each Item In StructureItems Do
		If TypeOf(Item) = Type("DataCompositionGroup") Then
			If Item.Name = SearchValue Then
				FindSelectedRegisterFieldsGroups(Item.Structure, SelectedFieldsGroups);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  StructureItems - DataCompositionSettingStructureItemCollection
//                    - DataCompositionTableStructureItemCollection
//                    - DataCompositionChartStructureItemCollection
//  SelectedGroupingsFields - an Array from DataCompositionSelectedField
//
Procedure FindSelectedRegisterFieldsGroups(StructureItems, SelectedFieldsGroups)
	
	For Each StructureItem In StructureItems Do
		If TypeOf(StructureItem) = Type("DataCompositionGroup") Then
			For Each ChoiceItem In StructureItem.Selection.Items Do 
				If TypeOf(ChoiceItem) = Type("DataCompositionSelectedFieldGroup") Then 
					SelectedFieldsGroups.Add(ChoiceItem);
				EndIf;
			EndDo;
			
			FindSelectedRegisterFieldsGroups(StructureItem.Structure, SelectedFieldsGroups);
		EndIf;
	EndDo;
	
EndProcedure

Function ReportParameters(Settings, UserSettings)
	
	Result = New Structure("OwnerDocument");
	
	If Settings.AdditionalProperties.Property("TheOriginalDocumentOwner", Result.OwnerDocument)
		And ValueIsFilled(Result.OwnerDocument) Then 
		
		Settings.AdditionalProperties.Delete("TheOriginalDocumentOwner");
		Return Result;
		
	EndIf;
	
	FoundParameter = Undefined;
	
	If TypeOf(UserSettings) = Type("DataCompositionUserSettings") Then
		For Each Item In UserSettings.Items Do
			If TypeOf(Item) = Type("DataCompositionSettingsParameterValue") Then
				ParameterName = String(Item.Parameter);
				If ParameterName = "OwnerDocument" Then
					 FoundParameter = Item;
					 Break;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If FoundParameter = Undefined
		Or Not ValueIsFilled(FoundParameter.Value) Then
		
		FoundParameter = Settings.DataParameters.Items.Find("OwnerDocument");
	EndIf;
	
	If FoundParameter <> Undefined Then
		Result.OwnerDocument = FoundParameter.Value;
	EndIf;
	
	Return Result;
	
EndFunction

Function RegisterProperties(Val AreaText)
	
	AreaText = Upper(TrimAll(AreaText));
	If Not ValueIsFilled(AreaText) Then
		Return Undefined;
	EndIf;
		
	CountPosition = StrFind(AreaText, "(", SearchDirection.FromEnd);
	If CountPosition = 0 Then
		Return Undefined;
	EndIf;
	
	TableHeading = Left(AreaText, CountPosition - 2);
	
	Return RegistersProperties.Find(TableHeading, "TableHeading");
	
EndFunction

Procedure RestoreFilterByRegistersGroups(Settings)
	
	RegistersList = New ValueList;
	
	FoundParameter = Settings.DataParameters.Items.Find("RegistersList");
	If FoundParameter <> Undefined Then 
		
		If TypeOf(FoundParameter.Value) = Type("ValueList") Then 
			RegistersList = FoundParameter.Value;
		ElsIf FoundParameter.Value <> Undefined Then 
			RegistersList.Add(FoundParameter.Value);
		EndIf;
		
	EndIf;
	
	ReportStructure = Settings.Structure;
	For Each StructureItem In ReportStructure Do
		
		RegisterProperties = RegistersProperties.Find(StructureItem.Name, "GroupName");
		If RegisterProperties = Undefined Then 
			StructureItem.Use = False;
			Continue;
		EndIf;
		
		StructureItem.Use =
			RegistersList.FindByValue(StructureItem.Name) <> Undefined
			And RegisterProperties.RecordsCount > 0;
		
		CommonClientServer.SetFilterItem(
			StructureItem.Filter,
			"RegisterName",
			StructureItem.Name,
			DataCompositionComparisonType.Equal,
			NStr("en = 'Service filter';"),
			True,
			DataCompositionSettingsItemViewMode.Inaccessible);
		
	EndDo;
	
EndProcedure

Procedure DetermineUsedTables(Form)
	
	If TypeOf(Form) <> Type("ClientApplicationForm") Then 
		Return;
	EndIf;
	
	TablesToUse = CommonClientServer.StructureProperty(Form.ReportSettings, "TablesToUse");
	If TablesToUse <> Undefined Then 
		Return;
	EndIf;
	
	TablesToUse = ReportsOptions.UsedReportTables(ThisObject);
	Form.ReportSettings.Insert("TablesToUse", TablesToUse);
	
EndProcedure

#EndRegion

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf