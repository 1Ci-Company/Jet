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
	
	Settings.DisableStandardContextMenu = True;
	Settings.EditStructureAllowed = False;
	Settings.GenerateImmediately = True;
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.OnDefineUsedTables = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.AfterLoadSettingsInLinker = True;
	Settings.Events.BeforeFormationReport = True;
	Settings.Events.OnDefineSelectionParameters = True;
	
EndProcedure

// See ReportsOverridable.OnCreateAtServer
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	FormAttributes = New Structure("OptionContext");
	FillPropertyValues(FormAttributes, Form);
	
	If ValueIsFilled(FormAttributes.OptionContext) Then
		Variant             = Form.CurrentVariantKey;
		FormParametersSelection = Form.ParametersForm.Filter;
		
		If Variant = "RightsRolesOnMetadataObject" Then
			FormParametersSelection.Insert("MetadataObject", FormAttributes.OptionContext);
			
		ElsIf Form.Parameters.Property("CommandParameter") Then
			ParameterName = "";
			If Variant = "RightsRolesOnMetadataObjects" Then
				ParameterName = "Profile";
				ParameterValue = ProfileListWithoutGroups(Form.Parameters.CommandParameter);
				
			ElsIf Variant = "RolesRights" Then
				ParameterName = "Role";
				ParameterValue = ListRoleNamesProfiles(Form.Parameters.CommandParameter);
			EndIf;
			If ValueIsFilled(ParameterName) Then
				If FormParametersSelection.Property("InitialSelection") Then
					InitialSelection = FormParametersSelection.InitialSelection;
				Else
					InitialSelection = New Structure;
					FormParametersSelection.Insert("InitialSelection", InitialSelection);
				EndIf;
				InitialSelection.Insert(ParameterName, ParameterValue);
			EndIf;
		EndIf;
	EndIf;
	
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
	
	If TypeOf(Context) <> Type("ClientApplicationForm")
	 Or TypeOf(NewDCUserSettings) <> Type("DataCompositionUserSettings") Then
		Return;
	EndIf;
	
	Form = Context;
	AdditionalProperties = SettingsComposer.Settings.AdditionalProperties;
	Variant             = AdditionalProperties.PredefinedOptionKey;
	FormParametersSelection = AdditionalProperties.FormParametersSelection;
	
	If Variant = "RolesRights"
	   And Not FormParametersSelection.Property("InitialSelection") Then
		
		If Not ParameterUsed(NewDCUserSettings, "MetadataObject")
		   And Not ParameterUsed(NewDCUserSettings, "Role") Then
			
			Form.ReportSettings.GenerateImmediately = False;
		EndIf;
		Return;
	EndIf;
	
	If Not FormParametersSelection.Property("InitialSelection") Then
		FormParametersSelection.Insert("InitialSelection", New Structure);
	EndIf;
	If TypeOf(FormParametersSelection.InitialSelection) <> Type("Structure") Then
		FormParametersSelection.InitialSelection = New Structure;
	EndIf;
	If Not FormParametersSelection.InitialSelection.Property("InitialSelectionSet") Then
		FormParametersSelection.InitialSelection.Insert("InitialSelectionSet",
			Not ValueIsFilled(FormParametersSelection.InitialSelection)
			And FormParametersSelection.Count() = 1);
	EndIf;
	
	UnavailableOptions = New Structure;
	If Variant = "DetailedPermissionsRolesOnMetadataObject" Then
		UnavailableOptions = New Structure("AccessLevel,
			|RightsOnDetails, ShowPermissionsofNonInterfaceSubsystems,
			|DontWarnAboutLargeReportSize");
		If SetSelectionByProfile(FormParametersSelection, SettingsComposer.Settings) Then
			UnavailableOptions.Insert("Role");
			UnavailableOptions.Insert("ShowObjectsAndRolesWithoutPermissions");
			If TypeOf(NewDCSettings) = Type("DataCompositionSettings") Then
				NewDCSettings.AdditionalProperties.Insert("SetSelectionByProfile");
			EndIf;
		Else
			UnavailableOptions.Insert("Profile");
		EndIf;
		
	ElsIf Variant = "RightsRolesOnMetadataObject" Then
		UnavailableOptions = New Structure("RightsOnDetails,Right,
			|DontWarnAboutLargeReportSize");
		
	ElsIf Variant = "RightsRolesOnMetadataObjects" Then
		UnavailableOptions = New Structure("Right");
	EndIf;
	
	If Not FormParametersSelection.InitialSelection.InitialSelectionSet Then
		AllParameters = New Structure("MetadataObject, Role, RightsOnDetails, Profile,
			|AccessLevel, Right, ShowObjectsAndRolesWithoutPermissions, NameFormat,
			|ShowPermissionsofNonInterfaceSubsystems, DontWarnAboutLargeReportSize");
	Else
		AllParameters = UnavailableOptions;
	EndIf;
	
	For Each ParameterDetails In AllParameters Do
		If Not FormParametersSelection.Property(ParameterDetails.Key) Then
			If TypeOf(NewDCSettings) = Type("DataCompositionSettings") Then
				DisableOption(NewDCSettings.DataParameters, ParameterDetails.Key,
					UnavailableOptions.Property(ParameterDetails.Key));
			EndIf;
			DisableOption(NewDCUserSettings, ParameterDetails.Key,
				UnavailableOptions.Property(ParameterDetails.Key));
		EndIf;
	EndDo;
	
	If FormParametersSelection.InitialSelection.InitialSelectionSet Then
		Return;
	EndIf;
	FormParametersSelection.InitialSelection.InitialSelectionSet = True;
	
	If Variant = "RightsRolesOnMetadataObjects"
	   And FormParametersSelection.InitialSelection.Property("Profile") Then
		
		SetDisplayMode("Profile", DataCompositionSettingsItemViewMode.QuickAccess,
			NewDCSettings, NewDCUserSettings);
		
		SetDisplayMode("Role", DataCompositionSettingsItemViewMode.Normal,
			NewDCSettings, NewDCUserSettings);
	EndIf;
	
	If TypeOf(FormParametersSelection.InitialSelection) = Type("Structure") Then
		For Each KeyAndValue In FormParametersSelection.InitialSelection Do
			If KeyAndValue.Key = "InitialSelectionSet" Then
				Continue;
			EndIf;
			EnableParameter(NewDCUserSettings,
				KeyAndValue.Key, KeyAndValue.Value,
				Form.ReportSettings.GenerateImmediately);
		EndDo;
	EndIf;
	
EndProcedure

//  Parameters:
//    AdditionalParameters - Structure
//
Procedure AfterLoadSettingsInLinker(AdditionalParameters) Export
	
	AdditionalProperties = SettingsComposer.Settings.AdditionalProperties;
	Variant             = AdditionalProperties.PredefinedOptionKey;
	FormParametersSelection = AdditionalProperties.FormParametersSelection;
	
	ConfigureParameterAccessLevel(SettingsComposer.Settings);
	ConfigureParameterRight(Variant, SettingsComposer.Settings);
	
	If Variant = "RolesRights" Then
		DescriptionOption = NStr("en = 'Role rights';");
		
	ElsIf Variant = "RightsRolesOnMetadataObjects" Then
		If SetSelectionByProfile(FormParametersSelection, SettingsComposer.Settings)
		 Or Not ParameterUsed(SettingsComposer.UserSettings, "Role") Then
			DescriptionOption = NStr("en = 'Profile rights that apply to metadata objects';");
		Else
			DescriptionOption = NStr("en = 'Role rights that apply to metadata objects';");
		EndIf;
		
	ElsIf Variant = "RightsRolesOnMetadataObject" Then
		DescriptionOption = NStr("en = 'Role rights that apply to metadata object';");
	
	ElsIf Variant = "DetailedPermissionsRolesOnMetadataObject" Then
		If SetSelectionByProfile(FormParametersSelection, SettingsComposer.Settings) Then
			DescriptionOption = NStr("en = 'Detailed role rights that apply to metadata object';");
		Else
			DescriptionOption = NStr("en = 'Detailed role rights that apply to metadata object';");
		EndIf;
	EndIf;
	
	If ValueIsFilled(DescriptionOption) Then
		AdditionalProperties.Insert("DescriptionOption", DescriptionOption);
	EndIf;
	
EndProcedure

// Parameters:
//   VariantKey - String
//                - Undefined
//   TablesToUse - Array of String
//
Procedure OnDefineUsedTables(VariantKey, TablesToUse) Export
	
	TablesToUse.Add(Metadata.InformationRegisters.RolesRights.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroupProfiles.FullName());
	
EndProcedure

// Parameters:
//   ReportForm - ClientApplicationForm
//   AdditionalParameters - Structure:
//     * WarningText - String
//     * StorageParameterNameWarningDisclaimer - String
//
Procedure BeforeFormationReport(ReportForm, AdditionalParameters) Export
	
	Variant = SettingsComposer.Settings.AdditionalProperties.PredefinedOptionKey;
	
	If Variant <> "RolesRights"
	   And Variant <> "RightsRolesOnMetadataObjects" Then
		Return;
	EndIf;
	
	Values = ValuesofSelectedParameter("DontWarnAboutLargeReportSize", True);
	If TypeOf(Values) = Type("ValueList")
	   And Values[0].Value = True Then
		Return;
	EndIf;
	
	Result = RolesRights(True, Variant = "RightsRolesOnMetadataObjects", True);
	
	RowsCount   = Result.Hierarchy.Count();
	ColumnsCount = Result.Roles.Count();
	
	NumberOfBins = RowsCount * ColumnsCount;
	
	If NumberOfBins < 1000000 Then
		Return;
	EndIf;
	
	GigabyteTo = Round(NumberOfBins / 1500000 + RowsCount / 6000, 1) + 0.4;
	
	AdditionalParameters.StorageParameterNameWarningDisclaimer =
		"DontWarnAboutLargeReportSize";
	AdditionalParameters.WarningText =
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'With the current filters, the report might be too large:
			           |up to %1 rows and %2 columns (%3 cells).
			           |
			           |Its generation might take a long time.
			           |It might require up to %4 GB.
			           |
			           |Consider narrowing down the filter.';"),
			Format(RowsCount, ""),
			Format(ColumnsCount, ""),
			Format(NumberOfBins, ""),
			Format(GigabyteTo, "NFD=1"));
	
EndProcedure

// See ReportsOverridable.OnDefineSelectionParameters.
Procedure OnDefineSelectionParameters(Form, SettingProperties) Export
	
	If SettingProperties.DCField = New DataCompositionField("DataParameters.Role") Then
		If TypeOf(SettingProperties.DCUserSetting.Value) = Type("ValueList") Then
			For Each Item In SettingProperties.DCUserSetting.Value Do
				MetadataObject = Metadata.Roles.Find(Item.Value);
				If MetadataObject = Undefined Then
					Continue;
				EndIf;
				Item.Presentation = MetadataObject.Presentation();
			EndDo;
		ElsIf TypeOf(SettingProperties.DCUserSetting.Value) = Type("String") Then
			MetadataObject = Metadata.Roles.Find(SettingProperties.DCUserSetting.Value);
			If MetadataObject = Undefined Then
				Return;
			EndIf;
			ValueList = New ValueList;
			ValueList.Add(SettingProperties.DCUserSetting.Value, MetadataObject.Presentation());
			SettingProperties.DCUserSetting.Value = ValueList;
		EndIf;
	EndIf;

	If SettingProperties.DCField = New DataCompositionField("DataParameters.MetadataObject") Then
		If TypeOf(SettingProperties.DCUserSetting.Value) = Type("ValueList") Then
			For Each Item In SettingProperties.DCUserSetting.Value Do
				MetadataObject = Common.MetadataObjectByFullName(Item.Value);
				If MetadataObject = Undefined Then
					Continue;
				EndIf;
				Item.Presentation = MetadataObject.Presentation();
			EndDo;
		ElsIf TypeOf(SettingProperties.DCUserSetting.Value) = Type("String") Then
			MetadataObject = Common.MetadataObjectByFullName(SettingProperties.DCUserSetting.Value);
			If MetadataObject = Undefined Then
				Return;
			EndIf;
			ValueList = New ValueList;
			ValueList.Add(SettingProperties.DCUserSetting.Value, MetadataObject.Presentation());
			SettingProperties.DCUserSetting.Value = ValueList;
		EndIf;
	EndIf;
	
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
	
	ComposerSettings = SettingsComposer.GetSettings();
	
	ParameterFormatName          = ComposerSettings.DataParameters.Items.Find("NameFormat");
	ParameterFormatNameSelected = ComposerSettings.DataParameters.Items.Find("NameFormatSelected");
	If ParameterFormatName.Use Then
		ParameterFormatNameSelected.Value = ParameterFormatName.Value;
	Else
		ParameterFormatNameSelected.Value = 0;
	EndIf;
	ParameterHeightCaps = ComposerSettings.DataParameters.Items.Find("HeaderHeight");
	HeaderHeight = 0;
	If ParameterHeightCaps.Use Then
		HeaderHeight = ParameterHeightCaps.Value;
		If TypeOf(HeaderHeight) = Type("Number") Then
			If HeaderHeight < 30 Then
				HeaderHeight = 30;
			ElsIf HeaderHeight > 350 Then
				HeaderHeight = 250;
			EndIf;
		EndIf;
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ComposerSettings, DetailsData);
	
	ExternalDataSets = New Structure;
	Variant = ComposerSettings.AdditionalProperties.PredefinedOptionKey;
	
	RolesRights = RolesRights(Variant = "RolesRights" Or Variant = "RightsRolesOnMetadataObjects",
		Variant = "RightsRolesOnMetadataObjects");
	ExternalDataSets.Insert("Hierarchy", RolesRights.Hierarchy);
	ExternalDataSets.Insert("Rights",    RolesRights.Rights);
	ExternalDataSets.Insert("Roles",     RolesRights.Roles);
	
	ProfilesInsteadofRoles = ComposerSettings.AdditionalProperties.Property("SetSelectionByProfile");
	ExternalDataSets.Insert("DetailedObjectPermissions", DetailedObjectPermissions(
		Variant = "DetailedPermissionsRolesOnMetadataObject",
		ProfilesInsteadofRoles));
	
	ExternalDataSets.Insert("RightsRolesOnObject", RightsRolesOnObject(
		Variant = "RightsRolesOnMetadataObject"));
	
	ExternalDataSets.Insert("FilterRoles", FilterRoles(
		Variant = "RightsRolesOnMetadataObjects"));
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets , DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
	
	FinishOutput(ResultDocument, DetailsData, Variant, ProfilesInsteadofRoles, HeaderHeight);
	
EndProcedure

Procedure FinishOutput(ResultDocument, DetailsData, Variant, ProfilesInsteadofRoles, HeaderHeight)
	
	Images = Images();
	None = New Line(SpreadsheetDocumentCellLineType.None);
	// ACC:163-off - #598.1. The use is acceptable, as it affects the meaning.
	TextIsRestriction = NStr("en = 'Not everything is available';");
	// ACC:163-on
	
	If Variant = "RolesRights"
	 Or Variant = "RightsRolesOnMetadataObjects" Then
		FirstTableHeader = NStr("en = 'Metadata object kind';");
		
	ElsIf Variant = "DetailedPermissionsRolesOnMetadataObject" Then
		FirstTableHeader = ?(ProfilesInsteadofRoles, NStr("en = 'Profile';"), NStr("en = 'Role';"));
	Else
		FirstTableHeader = NStr("en = 'Role';");
	EndIf;
	
	TableHeight = ResultDocument.TableHeight;
	TableWidth = ResultDocument.TableWidth;
	DataCompositionDecryptionIdentifierType = Type("DataCompositionDetailsID");
	InitialValueIsRightWithRestriction =
		Variant = "DetailedPermissionsRolesOnMetadataObject";
	TextRightAllowed = NStr("en = '✔';");
	
	For LineNumber = 1 To TableHeight Do
		YesRightWithRestriction = InitialValueIsRightWithRestriction;
		For ColumnNumber = 1 To TableWidth Do
			Area = ResultDocument.Area(LineNumber, ColumnNumber);
			
			Details = Area.Details;
			If TypeOf(Details) <> DataCompositionDecryptionIdentifierType Then
				If Area.Text = "*" Then
					Area.Text = "";
					Area.Comment.Text = TextIsRestriction;
				ElsIf Area.Text = "+" Then
					Area.Text = TextRightAllowed;
					Area.Comment.Text = TextIsRestriction;
				ElsIf Area.Text = "***" Then
					Area.Text = FirstTableHeader;
					If ValueIsFilled(HeaderHeight) Then
						If Variant = "RolesRights"
						 Or Variant = "RightsRolesOnMetadataObjects" Then
							RegionLower = ResultDocument.Area(LineNumber + 1, ColumnNumber);
							If ValueIsFilled(Area.RowHeight)
							   And ValueIsFilled(RegionLower.RowHeight) Then
								CurrentHeight = Area.RowHeight + RegionLower.RowHeight;
								Area.RowHeight     = HeaderHeight * (Area.RowHeight     / CurrentHeight);
								RegionLower.RowHeight = HeaderHeight * (RegionLower.RowHeight / CurrentHeight);
								If Area.RowHeight < 13 Then
									Area.RowHeight = 13;
									RegionLower.RowHeight = HeaderHeight - Area.RowHeight;
								EndIf;
							EndIf;
						Else
							Area.RowHeight = HeaderHeight;
						EndIf;
					EndIf;
				EndIf;
				If Not YesRightWithRestriction And ColumnNumber >= 2 Then
					Break;
				EndIf;
				Continue;
			EndIf;
			
			FieldValues = DetailsData.Items[Details].GetFields();
			FieldIsRestriction = FieldValues.Find("HasLimit");
			
			If FieldIsRestriction <> Undefined Then
				If FieldIsRestriction.Value = True Then
					Area.Comment.Text = TextIsRestriction;
				EndIf;
				Continue;
				
			ElsIf FieldValues.Find("PictureIndex") <> Undefined Then
				Indent = (FieldValues.Find("Level").Value - 1) * 2;
				RowArea = ResultDocument.Area(LineNumber, , LineNumber);
				RowArea.CreateFormatOfRows();
				AreaOnRight = ResultDocument.Area(LineNumber, ColumnNumber);
				AreaLeft  = ResultDocument.Area(LineNumber, ColumnNumber - 1);
				AreaOnRight.LeftBorder = None;
				AreaLeft.RightBorder = None;
				AreaOnRight.ColumnWidth = Area.ColumnWidth + AreaLeft.ColumnWidth - Indent;
				AreaLeft.ColumnWidth = Indent;
				AreaOnRight.Picture = Images.Get(FieldValues.Find("PictureIndex").Value).Picture;
				If FieldValues.Find("YesRightWithRestriction").Value = True Then
					YesRightWithRestriction = True;
				EndIf;
			EndIf;
			
			If Not YesRightWithRestriction And ColumnNumber >= 2 Then
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

// For procedure AfterImportSettingsToComposer.
Procedure ConfigureParameterAccessLevel(Settings)
	
	Parameter = New DataCompositionParameter("AccessLevel");
	AvailableParameter = Settings.DataParameters.AvailableParameters.FindParameter(Parameter);
	If AvailableParameter = Undefined Then
		Return;
	EndIf;
	
	List = New ValueList;
	List.Add(01, NStr("en = 'Right exists';"));
	List.Add(02, NStr("en = 'Use';"));
	List.Add(03, NStr("en = 'Read';"));
	List.Add(04, NStr("en = 'View';"));
	List.Add(05, NStr("en = 'Modify';"));
	List.Add(06, NStr("en = 'Edit';"));
	List.Add(07, NStr("en = 'Add';"));
	List.Add(08, NStr("en = 'Add interactively';"));
	List.Add(09, NStr("en = 'Get';"));
	List.Add(10, NStr("en = 'Set';"));
	List.Add(11, NStr("en = 'Get and Set';"));
	List.Add(12, NStr("en = 'External data source: Use';"));
	List.Add(13, NStr("en = 'External data source: Administration';"));
	List.Add(14, NStr("en = 'External data source: Use and Administration';"));
	
	AvailableParameter.AvailableValues = List;
	
EndProcedure

// For procedure AfterImportSettingsToComposer.
Procedure ConfigureParameterRight(Variant, Settings)
	
	If Variant <> "DetailedPermissionsRolesOnMetadataObject" Then
		Return;
	EndIf;
	
	Parameter = New DataCompositionParameter("Right");
	AvailableParameter = Settings.DataParameters.AvailableParameters.FindParameter(Parameter);
	If AvailableParameter = Undefined Then
		Return;
	EndIf;
	
	Context = ReportContextByObject(True);
	If Context = Undefined Then
		Return;
	EndIf;
	
	AvailableParameter.AvailableValues = Context.RightsDetails.RightsList;
	
EndProcedure

// For procedure BeforeImportSettingsToComposer.
Procedure EnableParameter(UserSettings, ParameterName, Value, GenerateImmediately)
	
	SettingItem = ParameterSetting(UserSettings, ParameterName);
	If SettingItem = Undefined Then
		GenerateImmediately = False;
	Else
		SettingItem.Value = Value;
		SettingItem.Use = True;
	EndIf;
	
EndProcedure

// For procedure BeforeImportSettingsToComposer.
Procedure DisableOption(UserSettings, ParameterName, Inaccessible = False)
	
	SettingItem = ParameterSetting(UserSettings, ParameterName);
	If SettingItem = Undefined Then
		Return;
	EndIf;
	
	If SettingItem.Use Then
		SettingItem.Use = False;
	EndIf;
	
	If SettingItem.Value = True Then
		SettingItem.Value = False;
	EndIf;
	
	If Inaccessible Then
		SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	
EndProcedure

Procedure SetDisplayMode(ParameterName, Mode, DCSettings, UserSettings)
	
	SettingItem = ParameterSetting(DCSettings.DataParameters, ParameterName);
	
	If SettingItem <> Undefined Then
		SettingItem.ViewMode = Mode;
	EndIf;
	
	SettingItem = ParameterSetting(UserSettings, ParameterName);
	
	If SettingItem <> Undefined Then
		SettingItem.ViewMode = Mode;
	EndIf;
	
EndProcedure

// For procedure AfterImportSettingsToComposer.
Function ParameterSetting(UserSettings, ParameterName)
	
	Parameter = New DataCompositionParameter(ParameterName);
	
	For Each SettingItem In UserSettings.Items Do
		Properties = New Structure("Parameter");
		FillPropertyValues(Properties, SettingItem);
		If Properties.Parameter = Parameter Then
			Return SettingItem;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

// For procedure BeforeImportSettingsToComposer.
Function ParameterUsed(UserSettings, ParameterName)
	
	LayoutParameter = New DataCompositionParameter(ParameterName);
	
	For Each SettingItem In UserSettings.Items Do
		Properties = New Structure("Parameter");
		FillPropertyValues(Properties, SettingItem);
		If Properties.Parameter = LayoutParameter Then
			Return SettingItem.Use
				And ValueIsFilled(SettingItem.Value);
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function SetSelectionByProfile(FormParametersSelection, Settings)
	
	Return FormParametersSelection.Property("InitialSelection")
	      And FormParametersSelection.InitialSelection.Property("Profile")
	    Or Settings.AdditionalProperties.Property("SetSelectionByProfile");
	
EndFunction

Function DetailedObjectPermissions(Fill, ProfilesInsteadofRoles)
	
	Rights = New ValueTable;
	Rights.Columns.Add("ObjectName",           StringType(430));
	Rights.Columns.Add("ObjectPresentation", StringType(1000));
	Rights.Columns.Add("NameOfRole",              StringType(255));
	Rights.Columns.Add("RolePresentation",    StringType(255));
	Rights.Columns.Add("NameOfRight",             StringType(255));
	Rights.Columns.Add("RightPresentation",   StringType(255));
	Rights.Columns.Add("OrderRight",         NumberType(2));
	Rights.Columns.Add("RightsValue",        New TypeDescription("Boolean"));
	Rights.Columns.Add("YesRestrictionPermission", New TypeDescription("Boolean"));
	Rights.Columns.Add("Profile",              New TypeDescription("CatalogRef.AccessGroupProfiles"));
	
	If Not Fill Then
		Return Rights;
	EndIf;
	
	Context = ReportContextByObject();
	If Context = Undefined Then
		Return Rights;
	EndIf;
	FullObjectName         = Context.FullObjectName;
	ObjectPresentation     = Context.ObjectPresentation;
	RightsList               = Context.RightsDetails.RightsList;
	MetadataObject         = Context.MetadataObject;
	StandardAttributeName = Context.StandardAttributeName;
	
	FoundPermissions = New Map;
	SelectedPermissions = ValuesofSelectedParameter("Right");
	
	If ProfilesInsteadofRoles Then
		RoleProfiles = RoleProfiles();
	EndIf;
	
	RolesDetails = RolesDetails(, ProfilesInsteadofRoles);
	ObjectsFields = New Map;
	For Each RightDetails In RightsList Do
		If ProfilesInsteadofRoles Then
			ProfileRightsStrings = New Map;
		EndIf;
		For Each RoleDetails In RolesDetails Do
			HasRight = AccessRight(RightDetails.Value, MetadataObject, RoleDetails.Metadata, StandardAttributeName);
			If Not HasRight Then
				Continue;
			EndIf;
			If SelectedPermissions <> Undefined
			   And SelectedPermissions.FindByValue(RightDetails.Value) = Undefined Then
				Continue;
			EndIf;
			FoundPermissions.Insert(RightDetails, True);
			RoleDetails.HavePermissionsRoles = True;
			HasLimit = False;
			If RightDetails.Check Then
				HasLimit = HasLimit(RightDetails.Value,
					MetadataObject, ObjectsFields, RoleDetails.Metadata);
			EndIf;
			If ProfilesInsteadofRoles Then
				IsProfilesRoles = RoleProfiles.Get(RoleDetails.Ref);
				If Not ValueIsFilled(IsProfilesRoles) Then
					Continue;
				EndIf;
				For Each Profile In IsProfilesRoles Do
					StringRight = ProfileRightsStrings.Get(Profile);
					If StringRight = Undefined Then
						Filter = New Structure("Profile", Profile);
						StringRight = Rights.Add();
						StringRight.ObjectName           = FullObjectName;
						StringRight.ObjectPresentation = ObjectPresentation;
						StringRight.NameOfRole              = String(Profile);
						StringRight.RolePresentation    = StringRight.NameOfRole;
						StringRight.Profile              = Profile;
						StringRight.NameOfRight             = RightDetails.Value;
						StringRight.RightPresentation   = RightDetails.Presentation;
						StringRight.OrderRight         = RightsList.IndexOf(RightDetails) + 1;
						StringRight.RightsValue        = True;
						StringRight.YesRestrictionPermission = HasLimit;
						ProfileRightsStrings.Insert(Profile, StringRight);
					Else
						If Not HasLimit And StringRight.YesRestrictionPermission Then
							StringRight.YesRestrictionPermission = False;
						EndIf;
					EndIf;
				EndDo;
			Else
				StringRight = Rights.Add();
				StringRight.ObjectName           = FullObjectName;
				StringRight.ObjectPresentation = ObjectPresentation;
				StringRight.NameOfRole              = RoleDetails.NameOfRole;
				StringRight.RolePresentation    = RoleDetails.RolePresentation;
				StringRight.NameOfRight             = RightDetails.Value;
				StringRight.RightPresentation   = RightDetails.Presentation;
				StringRight.OrderRight         = RightsList.IndexOf(RightDetails) + 1;
				StringRight.RightsValue        = True;
				StringRight.YesRestrictionPermission = HasLimit;
			EndIf;
		EndDo;
	EndDo;
	
	If ShowObjectsAndRolesWithoutPermissions() And Not ProfilesInsteadofRoles Then
		Filter = New Structure("HavePermissionsRoles", False);
		DescriptionRolesWithoutPermissions = RolesDetails.FindRows(Filter);
		If Rights.Count() = 0 Then
			NameOfRight = "";
			RightPresentation = "";
			OrderRight = 0;
			If RightsList.Count() > 0 Then
				FirstRight = Undefined;
				For Each RightDetails In RightsList Do
					If SelectedPermissions = Undefined
					 Or SelectedPermissions.FindByValue(FirstRight.Value) <> Undefined Then
						FirstRight = RightDetails;
						Break;
					EndIf;
				EndDo;
				If FirstRight <> Undefined Then
					NameOfRight           = FirstRight.Value;
					RightPresentation = FirstRight.Presentation;
					FoundPermissions.Insert(FirstRight, True);
					OrderRight = 1;
				EndIf;
			EndIf;
		Else
			NameOfRight           = Rights[0].NameOfRight;
			RightPresentation = Rights[0].RightPresentation;
			OrderRight       = Rights[0].OrderRight;
		EndIf;
		For Each RoleDetails In DescriptionRolesWithoutPermissions Do
			NewRow = Rights.Add();
			NewRow.ObjectName           = FullObjectName;
			NewRow.ObjectPresentation = ObjectPresentation;
			NewRow.NameOfRole              = RoleDetails.NameOfRole;
			NewRow.RolePresentation    = RoleDetails.RolePresentation;
			NewRow.NameOfRight             = NameOfRight;
			NewRow.RightPresentation   = RightPresentation;
			NewRow.OrderRight         = OrderRight;
		EndDo;
	EndIf;
	
	If Rights.Count() = 0 Then
		NameOfRole = "";
		RolePresentation = "";
		Profile = Undefined;
	Else
		NameOfRole           = Rights[0].NameOfRole;
		RolePresentation = Rights[0].RolePresentation;
		Profile           = Rights[0].Profile;
	EndIf;
	
	For Each RightDetails In RightsList Do
		If FoundPermissions.Get(RightDetails) <> Undefined
		 Or SelectedPermissions <> Undefined
		   And SelectedPermissions.FindByValue(RightDetails.Value) = Undefined Then
			Continue;
		EndIf;
		NewRow = Rights.Add();
		NewRow.ObjectName           = FullObjectName;
		NewRow.ObjectPresentation = ObjectPresentation;
		NewRow.NameOfRole              = NameOfRole;
		NewRow.RolePresentation    = RolePresentation;
		NewRow.Profile              = Profile;
		NewRow.NameOfRight             = RightDetails.Value;
		NewRow.RightPresentation   = RightDetails.Presentation;
		NewRow.OrderRight         = RightsList.IndexOf(RightDetails) + 1;
	EndDo;
	
	Return Rights;
	
EndFunction

// Parameters:
//  FillOnlyDescriptionPermissions - Boolean
//
// Returns:
//  Structure:
//    * FullObjectName         - String
//    * RightsDetails             - See RightsDetails
//    * MetadataObject         - MetadataObject
//    * StandardAttributeName - String
//    * ObjectPresentation     - String
//  Undefined.
//
Function ReportContextByObject(FillOnlyDescriptionPermissions = False)
	
	SelectedObjects = ValuesofSelectedParameter("MetadataObject");
	If Not ValueIsFilled(SelectedObjects)
	 Or SelectedObjects.Count() <> 1 Then
		Return Undefined;
	EndIf;
	FullObjectName = SelectedObjects[0].Value;
	
	Context = New Structure;
	Context.Insert("FullObjectName", FullObjectName);
	
	If FullObjectName = "Configuration" Then
		MetadataObject = Metadata;
		PathToObject = "Configuration";
	Else
		PartsPathToObject = StrSplit(FullObjectName, ".");
		If PartsPathToObject[0] = "Subsystem" Then
			PathToObject = "Subsystem.*";
		Else
			ThisPartPath = True;
			For IndexOf = 0 To PartsPathToObject.UBound() Do
				If Not ThisPartPath Then
					PartsPathToObject[IndexOf] = "*";
				EndIf;
				ThisPartPath = Not ThisPartPath;
			EndDo;
			PathToObject = StrConcat(PartsPathToObject, ".");
		EndIf;
	EndIf;
	
	Tree = MetadataTree(True);
	TreeRow = Tree.Rows.Find(PathToObject, "PathToObject", True);
	If TreeRow = Undefined
	 Or TreeRow.RightsDetails = Undefined Then
		Return Undefined;
	EndIf;
	Context.Insert("RightsDetails", TreeRow.RightsDetails);
	
	If FillOnlyDescriptionPermissions Then
		Return Context;
	EndIf;
	
	If FullObjectName = "Configuration" Then
		ObjectPresentation = TreeRow.ObjectPresentation;
	Else
		StandardAttributeName = Undefined;
		ObjectPresentation      = "";
		ObjectsKindPresentation = "";
		NameParts = StrSplit(FullObjectName, ".");
		NumberofNames = Int(NameParts.Count() / 2);
		If NameParts.Count() <> NumberofNames * 2 Then
			Return Undefined;
		EndIf;
		CurrentFullName    = "";
		CurrentPathToObject = "";
		StandardTabularSection = Undefined;
		For NameNumber = 1 To NumberofNames Do
			IndexOf = (NameNumber - 1) * 2;
			If NameParts[IndexOf] = "StandardTabularSection" Then
				StandardAttributeName = NameParts[IndexOf + 1];
				StandardTabularSection = StandardTabularSection(MetadataObject, NameParts[IndexOf + 1]);
				If StandardTabularSection = Undefined Then
					Return Undefined;
				EndIf;
				CurrentObjectRepresentation = StandardTabularSection.Presentation();
				
			ElsIf NameParts[IndexOf] = "StandardAttribute" Then
				StandardAttributeName = ?(ValueIsFilled(StandardAttributeName),
					StandardAttributeName + ".", "") + NameParts[IndexOf + 1];
				StandardAttribute = StandardAttribute(?(StandardTabularSection = Undefined,
					MetadataObject, StandardTabularSection), NameParts[IndexOf + 1]);
				If StandardAttribute = Undefined Then
					Return Undefined;
				EndIf;
				CurrentObjectRepresentation = StandardAttribute.Presentation();
			Else
				CurrentFullName = ?(ValueIsFilled(CurrentFullName), CurrentFullName + ".", "")
					+ NameParts[IndexOf] + "." + NameParts[IndexOf + 1];
				MetadataObject = Common.MetadataObjectByFullName(CurrentFullName);
				If MetadataObject = Undefined Then
					Return Undefined;
				EndIf;
				CurrentObjectRepresentation = MetadataObject.Presentation();
			EndIf;
			ObjectPresentation = ?(ValueIsFilled(ObjectPresentation),
				ObjectPresentation + ".", "") + CurrentObjectRepresentation;
			If PartsPathToObject[0] = "Subsystem" Then
				CurrentTreeRow = TreeRow;
			Else
				CurrentPathToObject = ?(ValueIsFilled(CurrentPathToObject), CurrentPathToObject + ".", "")
					+ PartsPathToObject[IndexOf] + "." + PartsPathToObject[IndexOf + 1];
				CurrentTreeRow = Tree.Rows.Find(CurrentPathToObject, "PathToObject", True);
				If CurrentTreeRow = Undefined Then
					Return Undefined;
				EndIf;
			EndIf;
			ObjectsKindPresentation = ?(ValueIsFilled(ObjectsKindPresentation),
				ObjectsKindPresentation + ".", "") + CurrentTreeRow.ObjectPresentation;
		EndDo;
		ObjectPresentation = ObjectPresentation + " (" + ObjectsKindPresentation + ")";
	EndIf;
	
	Context.Insert("MetadataObject",         MetadataObject);
	Context.Insert("StandardAttributeName", StandardAttributeName);
	Context.Insert("ObjectPresentation",     ObjectPresentation);

	Return Context;
	
EndFunction

Function StandardTabularSection(MetadataObject, StandardTabularSectionName)
	
	ObjectProperties = New Structure("StandardTabularSections");
	FillPropertyValues(ObjectProperties, MetadataObject);
	
	If TypeOf(ObjectProperties.StandardTabularSections) <> Type("StandardTabularSectionDescriptions") Then
		Return Undefined;
	EndIf;
	
	For Each StandardTabularSection In ObjectProperties.StandardTabularSections Do
		StandardTabularSection = StandardTabularSection; // StandardTabularSectionDescription
		If StandardTabularSection.Name = StandardTabularSectionName Then
			Return StandardTabularSection;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function StandardAttribute(MetadataObject, StandardAttributeName)
	
	ObjectProperties = New Structure("StandardAttributes");
	FillPropertyValues(ObjectProperties, MetadataObject);
	
	If TypeOf(ObjectProperties.StandardAttributes) <> Type("StandardAttributeDescriptions") Then
		Return Undefined;
	EndIf;
	
	For Each StandardAttribute In ObjectProperties.StandardAttributes Do
		StandardAttribute = StandardAttribute; // StandardAttributeDescription
		If StandardAttribute.Name = StandardAttributeName Then
			Return StandardAttribute;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function FilterRoles(Fill)
	
	FilterRoles = New ValueTable;
	FilterRoles.Columns.Add("NameOfRole",              StringType(255));
	FilterRoles.Columns.Add("RolePresentation",    StringType(255));
	
	If Not Fill Then
		Return FilterRoles;
	EndIf;
	
	SelectedRoles = ValuesofSelectedParameter("Role");
	If Not ValueIsFilled(SelectedRoles)
	 Or SelectedRoles.Count() <> 1 Then
		Return FilterRoles;
	EndIf;
	
	NameOfRole = SelectedRoles[0].Value;
	RoleMetadata = Metadata.Roles.Find(NameOfRole);
	If RoleMetadata = Undefined Then
		Return FilterRoles;
	EndIf;
	
	NewRow = FilterRoles.Add();
	NewRow.NameOfRole = RoleMetadata.Name;
	NewRow.RolePresentation = RoleMetadata.Presentation();
	
	Return FilterRoles;
	
EndFunction

Function RightsRolesOnObject(Fill)
	
	Rights = New ValueTable;
	Rights.Columns.Add("ObjectName",           StringType(430));
	Rights.Columns.Add("ObjectPresentation", StringType(1000));
	Rights.Columns.Add("NameOfRole",              StringType(255));
	Rights.Columns.Add("RolePresentation",    StringType(255));
	Rights.Columns.Add("WithoutProfile",           New TypeDescription("Boolean"));
	Rights.Columns.Add("Profile",              New TypeDescription("CatalogRef.AccessGroupProfiles"));
	Rights.Columns.Add("AccessLevel",       NumberType(2));
	Rights.Columns.Add("HasLimit",      New TypeDescription("Boolean"));
	
	If Not Fill Then
		Return Rights;
	EndIf;
	
	ShowObjectsAndRolesWithoutPermissions = ShowObjectsAndRolesWithoutPermissions();
	
	Context = ReportContextByObject();
	If Context = Undefined Then
		Return Rights;
	EndIf;
	AccessLevels            = Context.RightsDetails.AccessLevels;
	MetadataObject         = Context.MetadataObject;
	StandardAttributeName = Context.StandardAttributeName;
	
	Context.Insert("Rights", Rights);
	Context.Insert("RoleProfiles", RoleProfiles());
	
	SelectedLevels = ValuesofSelectedParameter("AccessLevel");
	RolesDetails = RolesDetails(, True);
	
	ObjectsFields = New Map;
	For Each RoleDetails In RolesDetails Do
		For Each LevelDescription In AccessLevels Do
			If LevelDescription.ThisPermissionSet Then
				HasRight = ValueIsFilled(LevelDescription.Right);
				RightsSet = StrSplit(LevelDescription.Right, ",", False);
				For Each Right In RightsSet Do
					If Not AccessRight(Right, MetadataObject, RoleDetails.Metadata) Then
						HasRight = False;
						Break;
					EndIf;
				EndDo;
			Else
				HasRight = AccessRight(LevelDescription.Right, MetadataObject, RoleDetails.Metadata, StandardAttributeName);
			EndIf;
			If Not HasRight Then
				Continue;
			EndIf;
			If SelectedLevels <> Undefined
			   And SelectedLevels.FindByValue(LevelDescription.Level) = Undefined Then
				Break;
			EndIf;
			RoleDetails.HavePermissionsRoles = True;
			HasLimit = False;
			If ValueIsFilled(LevelDescription.RightWithRestriction) Then
				HasLimit = HasLimit(LevelDescription.RightWithRestriction,
					MetadataObject, ObjectsFields, RoleDetails.Metadata);
			EndIf;
			AddPermissionsProfileRoles(Context, RoleDetails, LevelDescription.Level, HasLimit);
			Break;
		EndDo;
		If Not RoleDetails.HavePermissionsRoles And ShowObjectsAndRolesWithoutPermissions Then
			AddPermissionsProfileRoles(Context, RoleDetails, 0, False);
		EndIf;
	EndDo;
	
	Return Rights;
	
EndFunction

// Returns:
//  Map of KeyAndValue:
//   * Key - CatalogRef.MetadataObjectIDs,
//          - CatalogRef.ExtensionObjectIDs
//   * Value - Array of CatalogRef.AccessGroupProfiles
//
Function RoleProfiles()
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	ProfilesRoles.Role AS Role,
	|	ProfilesRoles.Ref AS Profile
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|WHERE
	|	&FilterProfiles
	|TOTALS BY
	|	Role";
	
	SelectedProfiles = ValuesofSelectedParameter("Profile");
	If SelectedProfiles = Undefined Then
		Query.Text = StrReplace(Query.Text, "&FilterProfiles", "TRUE");
	Else
		Query.Text = StrReplace(Query.Text, "&FilterProfiles",
			"ProfilesRoles.Ref IN(&Profiles)");
		Query.SetParameter("Profiles", SelectedProfiles.UnloadValues());
	EndIf;
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	RoleProfiles = New Map;
	While Selection.Next() Do
		ProfileSelectionig = Selection.Select();
		Profiles = New Array;
		RoleProfiles.Insert(Selection.Role, Profiles);
		While ProfileSelectionig.Next() Do
			Profiles.Add(ProfileSelectionig.Profile);
		EndDo;
	EndDo;
	
	Return RoleProfiles;
	
EndFunction

// Parameters:
//  Profiles - Array of CatalogRef.AccessGroupProfiles
//
// Returns:
//  Array of String - Role names.
//
Function ListRoleNamesProfiles(Profiles)
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	Query.Text =
	"SELECT DISTINCT
	|	ProfilesRoles.Role AS Role
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|WHERE
	|	ProfilesRoles.Ref.IsFolder = FALSE
	|	AND ProfilesRoles.Ref IN(&Profiles)";
	
	RoleIDs = Query.Execute().Unload().UnloadColumn("Role");
	
	RoleMetadataObjects = Common.MetadataObjectsByIDs(
		RoleIDs, False);
	
	RolesList = New ValueList;
	For Each KeyAndValue In RoleMetadataObjects Do
		MetadataObjectRole = KeyAndValue.Value;
		If TypeOf(MetadataObjectRole) <> Type("MetadataObject") Then
			Continue;
		EndIf;
		RolesList.Add(MetadataObjectRole.Name, MetadataObjectRole.Synonym);
	EndDo;
	
	RolesList.SortByPresentation();
	
	Return RolesList;
	
EndFunction

// Parameters:
//  Profiles - Array of CatalogRef.AccessGroupProfiles
//
// Returns:
//  Array of CatalogRef.AccessGroupProfiles - Profiles without a group.
//
Function ProfileListWithoutGroups(Profiles)
	
	Query = New Query;
	Query.SetParameter("Profiles", Profiles);
	Query.Text =
	"SELECT
	|	Profiles.Ref AS Profile
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|WHERE
	|	Profiles.IsFolder = FALSE
	|	AND Profiles.Ref IN(&Profiles)
	|
	|ORDER BY
	|	Profiles.Description";
	
	Profiles = Query.Execute().Unload().UnloadColumn("Profile");
	
	ProfileList = New ValueList;
	ProfileList.LoadValues(Profiles);
	
	Return ProfileList;
	
EndFunction


Function DescriptionProfiles()
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Profiles.Ref AS Ref,
	|	Profiles.Description AS Description
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|
	|ORDER BY
	|	Description";
	
	DescriptionProfiles = RolesDetails(False).Copy(New Array,
			"RoleCode, NameOfRole, RolePresentation, HavePermissionsRoles");
	DescriptionProfiles.Columns.Add("Profile",
		New TypeDescription("CatalogRef.AccessGroupProfiles"));
	
	CurrentNumber = 1;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = DescriptionProfiles.Add();
		NewRow.RoleCode           = CurrentNumber;
		NewRow.NameOfRole           = Selection.Description;
		NewRow.RolePresentation = NewRow.NameOfRole;
		NewRow.Profile           = Selection.Ref;
		CurrentNumber = CurrentNumber + 1;
	EndDo;
	
	NewRow = DescriptionProfiles.Add();
	NewRow.RoleCode           = CurrentNumber;
	NewRow.NameOfRole           = NStr("en = '<Without a profile>';");
	NewRow.RolePresentation = NewRow.NameOfRole;
	NewRow.Profile           = Catalogs.AccessGroupProfiles.EmptyRef();
	
	DescriptionProfiles.Indexes.Add("Profile");
	
	Return DescriptionProfiles;
	
EndFunction

Procedure AddPermissionsProfileRoles(Context, RoleDetails, AccessLevel, HasLimit)
	
	IsProfilesRoles = Context.RoleProfiles.Get(RoleDetails.Ref);
	EmptyProfile = Catalogs.AccessGroupProfiles.EmptyRef();
	
	If Not ValueIsFilled(IsProfilesRoles) Then
		IsProfilesRoles = CommonClientServer.ValueInArray(EmptyProfile);
	EndIf;
	
	For Each Profile In IsProfilesRoles Do
		NewRow = Context.Rights.Add();
		NewRow.ObjectName           = Context.FullObjectName;
		NewRow.ObjectPresentation = Context.ObjectPresentation;
		NewRow.NameOfRole              = RoleDetails.NameOfRole;
		NewRow.RolePresentation    = RoleDetails.RolePresentation;
		NewRow.WithoutProfile           = Profile = EmptyProfile;
		NewRow.Profile              = Profile;
		NewRow.AccessLevel       = AccessLevel;
		NewRow.HasLimit      = HasLimit;
	EndDo;
	
EndProcedure

Function ShowPermissionsOnDetails()
	
	FilterField = SettingsComposer.GetSettings().DataParameters.Items.Find("RightsOnDetails");
	
	Return FilterField.Value = True;
	
EndFunction

Function ShowObjectsAndRolesWithoutPermissions()
	
	FilterField = SettingsComposer.GetSettings().DataParameters.Items.Find("ShowObjectsAndRolesWithoutPermissions");
	
	Return FilterField.Value = True;
	
EndFunction

Function ShowPermissionsofNonInterfaceSubsystems()
	
	FilterField = SettingsComposer.GetSettings().DataParameters.Items.Find("ShowPermissionsofNonInterfaceSubsystems");
	
	Return FilterField.Value = True;
	
EndFunction

Function ValuesofSelectedParameter(ParameterName, UsedAlways = False)
	
	Settings = SettingsComposer.GetSettings();
	FilterField = Settings.DataParameters.Items.Find(ParameterName);
	
	If Not FilterField.Use And Not UsedAlways Then
		Return Undefined;
	EndIf;
	
	If TypeOf(FilterField.Value) = Type("ValueList") Then
		Return FilterField.Value;
	EndIf;
	
	List = New ValueList;
	List.Add(FilterField.Value);
	
	Return List;
	
EndFunction

Function RolesRights(Fill, ProfilesInsteadofRoles, HierarchyOnly = False)
	
	Hierarchy = New ValueTable;
	Hierarchy.Columns.Add("ParentCode",            StringType(50));
	Hierarchy.Columns.Add("ElementCode",            StringType(50));
	Hierarchy.Columns.Add("PictureIndex",         NumberType(2));
	Hierarchy.Columns.Add("TagName",            StringType(255));
	Hierarchy.Columns.Add("ItemPresentation",  StringType(1000));
	Hierarchy.Columns.Add("HaveElementRights",      New TypeDescription("Boolean"));
	Hierarchy.Columns.Add("YesRightWithRestriction", New TypeDescription("Boolean"));
	Hierarchy.Columns.Add("FullObjectName",       StringType(430));
	
	Rights = New ValueTable;
	Rights.Columns.Add("ElementCode",     StringType(50));
	Rights.Columns.Add("RoleCode",         NumberType(4));
	Rights.Columns.Add("AccessLevel",  NumberType(2));
	Rights.Columns.Add("HasLimit", New TypeDescription("Boolean"));
	
	RolesDetails = RolesDetails(Fill, ProfilesInsteadofRoles);
	
	Result = New Structure;
	Result.Insert("Hierarchy", Hierarchy);
	Result.Insert("Rights",    Rights);
	Result.Insert("Roles",     RolesDetails);
	
	If Not Fill Then
		Return Result;
	EndIf;

	Context = New Structure;
	Context.Insert("ProfilesInsteadofRoles", ProfilesInsteadofRoles);
	Context.Insert("RolesDetails",      RolesDetails);
	Context.Insert("RolesMetadata",    RolesDetails.UnloadColumn("Metadata"));
	Context.Insert("Hierarchy",           Hierarchy);
	Context.Insert("Rights",              Rights);
	Context.Insert("Images",           Images());
	Context.Insert("ObjectsFields",       New Map);
	Context.Insert("ObjectsWithoutRights",     ShowObjectsAndRolesWithoutPermissions() Or HierarchyOnly);
	Context.Insert("SelectedOMD",       ValuesofSelectedParameter("MetadataObject"));
	Context.Insert("SelectedLevels",    ValuesofSelectedParameter("AccessLevel"));
	Context.Insert("AllSubsystems",      ShowPermissionsofNonInterfaceSubsystems());
	
	If ProfilesInsteadofRoles Then
		Context.Insert("DescriptionProfiles", DescriptionProfiles());
		Context.Insert("RoleProfiles",     RoleProfiles());
		Result.Roles = Context.DescriptionProfiles;
	EndIf;
	
	Tree = MetadataTree(ShowPermissionsOnDetails());
	If HierarchyOnly Then
		ClearDescriptionRights(Tree.Rows);
	EndIf;
	ProcessTreeRows(Context, Tree.Rows, "", False);
	
	If HierarchyOnly Then
		Return Result;
	EndIf;
	
	If Context.ObjectsWithoutRights Then
		Filter = New Structure("HavePermissionsRoles", False);
		Rows = Result.Roles.FindRows(Filter);
		ItemCodeConfig = Hierarchy[0].ElementCode;
		For Each RoleDetails In Rows Do
			StringRight = Rights.Add();
			StringRight.ElementCode = ItemCodeConfig;
			StringRight.RoleCode     = RoleDetails.RoleCode;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

Function StringType(StringLength)
	
	Return New TypeDescription("String",,,, New StringQualifiers(StringLength))
	
EndFunction

Function NumberType(NumberOfDigits)
	
	Return New TypeDescription("Number",,,
		New NumberQualifiers(NumberOfDigits, 0, AllowedSign.Nonnegative));
	
EndFunction

Function TypeMetadataObjectId()
	
	Return New TypeDescription("CatalogRef.MetadataObjectIDs,
		|CatalogRef.ExtensionObjectIDs");
	
EndFunction

Function RolesDetails(Fill = True, withidentifiers = False)
	
	RolesDetails = New ValueTable;
	RolesDetails.Columns.Add("Metadata",        New TypeDescription("MetadataObject"));
	RolesDetails.Columns.Add("RoleCode",           NumberType(4));
	RolesDetails.Columns.Add("NameOfRole",           StringType(255));
	RolesDetails.Columns.Add("RolePresentation", StringType(255));
	RolesDetails.Columns.Add("HavePermissionsRoles",     New TypeDescription("Boolean"));
	RolesDetails.Columns.Add("Ref",            TypeMetadataObjectId());
	
	If Not Fill Then
		Return RolesDetails;
	EndIf;
	
	SelectedRoles = ValuesofSelectedParameter("Role");
	
	CurrentNumber = 1;
	For Each Role In Metadata.Roles Do
		If SelectedRoles <> Undefined
		   And SelectedRoles.FindByValue(Role.Name) = Undefined Then
			Continue;
		EndIf;
		NewRow = RolesDetails.Add();
		NewRow.RoleCode           = CurrentNumber;
		NewRow.Metadata        = Role;
		NewRow.NameOfRole           = Role.Name;
		NewRow.RolePresentation = Role.Presentation();
		CurrentNumber = CurrentNumber + 1;
	EndDo;
	
	If withidentifiers Then
		RolesofSelectedProfiles = RolesofSelectedProfiles();
		IDs = Common.MetadataObjectIDs(
			RolesDetails.UnloadColumn("Metadata"));
		IndexOf = RolesDetails.Count() - 1;
		While IndexOf >= 0 Do
			RoleDetails = RolesDetails[IndexOf];
			RoleRef = IDs.Get(RoleDetails.Metadata.FullName());
			If RolesofSelectedProfiles <> Undefined
			   And RolesofSelectedProfiles.Get(RoleRef) = Undefined Then
				RolesDetails.Delete(RoleDetails);
			Else
				RoleDetails.Ref = RoleRef;
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
	EndIf;
	
	RolesDetails.Indexes.Add("Metadata");
	
	Return RolesDetails;
	
EndFunction

Function RolesofSelectedProfiles()
	
	SelectedProfiles = ValuesofSelectedParameter("Profile");
	If SelectedProfiles = Undefined Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Profiles", SelectedProfiles.UnloadValues());
	Query.Text =
	"SELECT DISTINCT
	|	ProfilesRoles.Role AS Role
	|FROM
	|	Catalog.AccessGroupProfiles.Roles AS ProfilesRoles
	|WHERE
	|	ProfilesRoles.Ref IN(&Profiles)";
	
	Selection = Query.Execute().Select();
	
	Roles = New Map;
	While Selection.Next() Do
		Roles.Insert(Selection.Role, True);
	EndDo;
	
	Return Roles;
	
EndFunction

Procedure ProcessTreeRows(Context, TreeRows, ParentCode, RowsIsPermissions)
	
	Counter = 0;
	PropertyIncludeInCommandInterface = New Structure("IncludeInCommandInterface", True);
	
	Count = TreeRows.Count();
	For Each TreeRow In TreeRows Do
		If TreeRow.NoGroup Then
			Count = Count - 1 + ItemCount(TreeRow.Metadata);
		EndIf;
	EndDo;
	NumberDigits = StrLen(Count);
	
	For Each TreeRow In TreeRows Do
		Counter = Counter + 1;
		PictureIndex = PictureIndex(Context, TreeRow.Name);
		StringHierarchyIsRights = False;
		If TreeRow.NoGroup Then
			RowCode = ParentCode;
		Else
			RowCode = ParentCode + Right("00000000" + Format(Counter, "NG="), NumberDigits);
			HierarchyLine = Context.Hierarchy.Add();
			HierarchyLine.ParentCode           = ParentCode;
			HierarchyLine.ElementCode           = RowCode;
			HierarchyLine.PictureIndex        = PictureIndex;
			HierarchyLine.TagName           = TreeRow.Presentation;
			HierarchyLine.ItemPresentation = TreeRow.Presentation;
		EndIf;
		
		StringsAttachments = Undefined;
		If TypeOf(TreeRow.Metadata) = Type("MetadataObjectCollection")
		 Or TypeOf(TreeRow.Metadata) = Type("StandardAttributeDescriptions")
		 Or TypeOf(TreeRow.Metadata) = Type("StandardTabularSectionDescriptions") Then
			
			ObjectNumber = ?(TreeRow.NoGroup, Counter, 0);
			If TreeRow.Rows.Count() > 0 Then
				StringsAttachments = TreeRow.Rows;
			EndIf;
			If TypeOf(TreeRow.Metadata) = Type("MetadataObjectCollection") Then
				SelectedMetadataObjects = Context.SelectedOMD;
				If SelectedMetadataObjects <> Undefined
				   And SelectedMetadataObjects.FindByValue(TreeRow.Name) <> Undefined Then
					SelectedMetadataObjects = Undefined;
				EndIf;
			Else
				SelectedMetadataObjects = Undefined;
			EndIf;
			NumberDigitsForObjects = ?(TreeRow.NoGroup, NumberDigits,
				StrLen(ItemCount(TreeRow.Metadata)));
			For Each MetadataObject In TreeRow.Metadata Do
				HierarchyOnly = False;
				If SelectedMetadataObjects <> Undefined Then
					FullName = MetadataObject.FullName();
					If SelectedMetadataObjects.FindByValue(FullName) = Undefined
					   And (TreeRow.Name <> "Subsystems"
					        And StrSplit(FullName, ".", False).Count() < 3
					      Or TreeRow.Name = "Subsystems"
					        And Not ThisParentSubsystem(SelectedMetadataObjects, FullName, HierarchyOnly)) Then
						Continue;
					EndIf;
				EndIf;
				If Not Context.AllSubsystems Then
					PropertyIncludeInCommandInterface.IncludeInCommandInterface = True;
					FillPropertyValues(PropertyIncludeInCommandInterface, MetadataObject);
					If Not PropertyIncludeInCommandInterface.IncludeInCommandInterface Then
						HierarchyOnly = True;
					EndIf;
				EndIf;
				ObjectNumber = ObjectNumber + 1;
				ElementCode = RowCode + Right("00000000" + Format(ObjectNumber, "NG="), NumberDigitsForObjects);
				ExtraStringHierarchy = Context.Hierarchy.Add();
				ExtraStringHierarchy.ParentCode           = RowCode;
				ExtraStringHierarchy.ElementCode           = ElementCode;
				ExtraStringHierarchy.PictureIndex        = PictureIndex;
				ExtraStringHierarchy.TagName           = MetadataObject.Name;
				ExtraStringHierarchy.ItemPresentation = MetadataObject.Presentation();
				HasRights = False;
				If Not HierarchyOnly Then
					If Not TreeRow.WithoutDecryption Then
						If TypeOf(MetadataObject) = Type("StandardTabularSectionDescription") Then
							ExtraStringHierarchy.FullObjectName = TreeRow.ParentMetadataAttachments.FullName()
								+ ".StandardTabularSection." + MetadataObject.Name;
						ElsIf TypeOf(MetadataObject) = Type("StandardAttributeDescription") Then
							If TypeOf(TreeRow.ParentMetadataAttachments) = Type("StandardTabularSectionDescription") Then
								ExtraStringHierarchy.FullObjectName = TreeRow.Parent.ParentMetadataAttachments.FullName()
									+ ".StandardTabularSection." + TreeRow.ParentMetadataAttachments.Name
									+ ".StandardAttribute." + MetadataObject.Name;
							Else
								ExtraStringHierarchy.FullObjectName = TreeRow.ParentMetadataAttachments.FullName()
									+ ".StandardAttribute." + MetadataObject.Name;
							EndIf;
						Else
							ExtraStringHierarchy.FullObjectName = MetadataObject.FullName();
						EndIf;
					EndIf;
					withlimit = False;
					If TypeOf(TreeRow.Metadata) = Type("MetadataObjectCollection") Then
						AddRights(Context, MetadataObject, TreeRow, ElementCode, HasRights, withlimit);
					ElsIf TypeOf(TreeRow.ParentMetadataAttachments) = Type("StandardTabularSectionDescription") Then
						AddRights(Context, TreeRow.Parent.ParentMetadataAttachments, TreeRow, ElementCode,
							HasRights, withlimit, TreeRow.ParentMetadataAttachments.Name + "." + MetadataObject.Name);
					Else
						AddRights(Context, TreeRow.ParentMetadataAttachments, TreeRow, ElementCode,
							HasRights, withlimit, MetadataObject.Name);
					EndIf;
					ExtraStringHierarchy.YesRightWithRestriction = withlimit;
				EndIf;
				If StringsAttachments <> Undefined Then
					For Each StringAttachments In StringsAttachments Do
						StringAttachments.ParentMetadataAttachments = MetadataObject;
						StringAttachments.Metadata = MetadataObject[StringAttachments.AttachmentName];
					EndDo;
					ProcessTreeRows(Context, TreeRow.Rows, ElementCode, HasRights);
				ElsIf TreeRow.HasHierarchy Then
					RowDescription = New Structure("Rows, Name,Metadata,RightsDetails,Presentation,
						|AttachmentName,NoGroup,WithoutDecryption,HasHierarchy");
					FillPropertyValues(RowDescription, TreeRow);
					RowDescription.Metadata = MetadataObject[TreeRow.AttachmentName];
					DescriptionStrings = New Array;
					DescriptionStrings.Add(RowDescription);
					ProcessTreeRows(Context, DescriptionStrings, ElementCode, HasRights);
				EndIf;
				If HasRights Then
					StringHierarchyIsRights = True;
					ExtraStringHierarchy.HaveElementRights = True;
				ElsIf Not Context.ObjectsWithoutRights Then
					ObjectNumber = ObjectNumber - 1;
					Context.Hierarchy.Delete(ExtraStringHierarchy);
				EndIf;
			EndDo;
			If TreeRow.NoGroup Then
				Counter = ObjectNumber;
			EndIf;
		ElsIf TypeOf(TreeRow.Metadata) = Type("ConfigurationMetadataObject") Then
			If Context.SelectedOMD = Undefined
			 Or Context.SelectedOMD.FindByValue("Configuration") <> Undefined Then
				AddRights(Context, TreeRow.Metadata, TreeRow, RowCode, StringHierarchyIsRights);
			EndIf;
			HierarchyLine.FullObjectName = "Configuration";
		EndIf;
		If StringsAttachments = Undefined Then
			ProcessTreeRows(Context, TreeRow.Rows, RowCode, StringHierarchyIsRights);
		EndIf;
		If StringHierarchyIsRights Then
			RowsIsPermissions = True;
			If Not TreeRow.NoGroup Then
				HierarchyLine.HaveElementRights = True;
			EndIf;
		ElsIf Not Context.ObjectsWithoutRights And Not TreeRow.NoGroup Then
			Counter = Counter - 1;
			Context.Hierarchy.Delete(HierarchyLine);
		EndIf;
	EndDo;
	
EndProcedure

Function ItemCount(Collection)
	
	If TypeOf(Collection) = Type("MetadataObjectCollection")
	 Or TypeOf(Collection) = Type("StandardAttributeDescriptions") Then
		Return Collection.Count();
		
	ElsIf TypeOf(Collection) = Type("StandardTabularSectionDescriptions") Then
		Count = 0;
		//@skip-check module-unused-local-variable
		For Each CollectionItem In Collection Do
			Count = Count + 1;
		EndDo;
		Return Count;
	EndIf;
	
	Return 1;
	
EndFunction

Function ThisParentSubsystem(SelectedMetadataObjects, FullSubsystemName, AddWIerarchy)
	
	For Each ListItem In SelectedMetadataObjects Do
		If StrStartsWith(ListItem.Value, FullSubsystemName) Then
			AddWIerarchy = True;
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddRights(Context, MetadataObject, TreeRow, ElementCode, HasRights,
			withlimit = False, StandardAttributeName = Undefined)
	
	If Not ValueIsFilled(TreeRow.RightsDetails) Then
		Return;
	EndIf;
	
	SelectedLevels = Context.SelectedLevels;
	If SelectedLevels <> Undefined Then
		HaveAccessLevel = False;
		For Each LevelDescription In TreeRow.RightsDetails.AccessLevels Do
			If SelectedLevels.FindByValue(LevelDescription.Level) <> Undefined Then
				HaveAccessLevel = True;
				Break;
			EndIf;
		EndDo;
		If Not HaveAccessLevel Then
			Return;
		EndIf;
	EndIf;
	
	HaveRightSet = False;
	RightsLevels = New Array;
	For Each LevelDescription In TreeRow.RightsDetails.AccessLevels Do
		RightsLevels.Add(LevelDescription.Right);
		If LevelDescription.ThisPermissionSet Then
			HaveRightSet = True;
		EndIf;
	EndDo;
	
	If Context.ProfilesInsteadofRoles Then
		Context.Insert("EmptyProfile", Catalogs.AccessGroupProfiles.EmptyRef());
		Context.Insert("ProfileRightsStrings", New Map);
	EndIf;
	Context.Insert("ElementCode", ElementCode);
	RolesMetadata = Context.RolesMetadata;
	AccessLevels   = TreeRow.RightsDetails.AccessLevels;
	
	If HaveRightSet Then
		For Each Role In RolesMetadata Do
			For Each LevelDescription In AccessLevels Do
				If LevelDescription.ThisPermissionSet Then
					HasRight = ValueIsFilled(LevelDescription.Right);
					RightsSet = StrSplit(LevelDescription.Right, ",", False);
					For Each Right In RightsSet Do
						If Not AccessRight(Right, MetadataObject, Role) Then
							HasRight = False;
							Break;
						EndIf;
					EndDo;
				Else
					HasRight = AccessRight(LevelDescription.Right, MetadataObject, Role, StandardAttributeName);
				EndIf;
				If Not HasRight Then
					Continue;
				EndIf;
				HasRights = True;
				If ValueIsFilled(LevelDescription.RightWithRestriction) Then
					withlimit = True;
				EndIf;
				SetRight(Context, LevelDescription, MetadataObject, Role);
			EndDo;
		EndDo;
	Else
		For Each Role In RolesMetadata Do
			For Each Right In RightsLevels Do
				If AccessRight(Right, MetadataObject, Role, StandardAttributeName) Then
					LevelDescription = AccessLevels[RightsLevels.Find(Right)];
					HasRights = True;
					If ValueIsFilled(LevelDescription.RightWithRestriction) Then
						withlimit = True;
					EndIf;
					SetRight(Context, LevelDescription, MetadataObject, Role);
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
EndProcedure

Procedure SetRight(Context, LevelDescription, MetadataObject, Role)
	
	If Context.SelectedLevels <> Undefined
	   And Context.SelectedLevels.FindByValue(LevelDescription.Level) = Undefined Then
		Return;
	EndIf;
	RoleDetails = Context.RolesDetails.Find(Role, "Metadata");
	RoleDetails.HavePermissionsRoles = True;
	HasLimit = False;
	If ValueIsFilled(LevelDescription.RightWithRestriction) Then
		HasLimit = HasLimit(LevelDescription.RightWithRestriction,
			MetadataObject, Context.ObjectsFields, RoleDetails.Metadata);
	EndIf;
	If Context.ProfilesInsteadofRoles Then
		DescriptionProfiles   = Context.DescriptionProfiles;
		ProfileRightsStrings = Context.ProfileRightsStrings;
		IsProfilesRoles = Context.RoleProfiles.Get(RoleDetails.Ref);
		If Not ValueIsFilled(IsProfilesRoles) Then
			IsProfilesRoles = CommonClientServer.ValueInArray(Context.EmptyProfile);
		EndIf;
		For Each Profile In IsProfilesRoles Do
			StringRight = ProfileRightsStrings.Get(Profile);
			If StringRight = Undefined Then
				Filter = New Structure("Profile", Profile);
				FoundRows = DescriptionProfiles.FindRows(Filter);
				If FoundRows.Count() <> 1 Then
					Continue;
				EndIf;
				ProfileDetails = FoundRows[0];
				ProfileDetails.HavePermissionsRoles = True;
				StringRight = Context.Rights.Add();
				StringRight.ElementCode     = Context.ElementCode;
				StringRight.RoleCode         = ProfileDetails.RoleCode;
				StringRight.AccessLevel  = LevelDescription.Level;
				StringRight.HasLimit = HasLimit;
				ProfileRightsStrings.Insert(Profile, StringRight);
			Else
				If StringRight.AccessLevel < LevelDescription.Level Then
					StringRight.AccessLevel = LevelDescription.Level;
				EndIf;
				If Not HasLimit And StringRight.HasLimit Then
					StringRight.HasLimit = False;
				EndIf;
			EndIf;
		EndDo;
	Else
		StringRight = Context.Rights.Add();
		StringRight.ElementCode     = Context.ElementCode;
		StringRight.RoleCode         = RoleDetails.RoleCode;
		StringRight.AccessLevel  = LevelDescription.Level;
		StringRight.HasLimit = HasLimit;
	EndIf;
	
EndProcedure

Function HasLimit(NameOfRight, MetadataObject, ObjectsFields, Role);
	
	Fields = ObjectsFields.Get(MetadataObject);
	
	If Fields = Undefined Then
		Fields = InformationRegisters.RolesRights.AllFieldsOfMetadataObjectAccessRestriction(
			MetadataObject, MetadataObject.FullName());
		ObjectsFields.Insert(MetadataObject, Fields);
	EndIf;
	
	Return AccessParameters(NameOfRight, MetadataObject, Fields, Role).RestrictionByCondition;
	
EndFunction

Procedure ClearDescriptionRights(TreeRows)
	
	For Each String In TreeRows Do
		String.RightsDetails = Undefined;
		ClearDescriptionRights(String.Rows);
	EndDo;
	
EndProcedure

// Returns:
//  ValueTree:
//   * Name                  - String
//   * Metadata           - MetadataObject
//                          - Undefined
//   * RightsDetails         - See RightsDetails
//   * Presentation        - String
//   * ObjectPresentation - String
//   * AttachmentName          - String
//   * NoGroup            - Boolean
//   * HasHierarchy         - Boolean
//   * WithoutDecryption       - Boolean
//   * PathToObject         - String
//   * ParentMetadataAttachments - MetadataObject
//                                - Undefined
//
Function MetadataTree(WithFields)
	
	Tree = New ValueTree;
	Tree.Columns.Add("Name",                  StringType(150));
	Tree.Columns.Add("Metadata");
	Tree.Columns.Add("RightsDetails",         New TypeDescription("Structure"));
	Tree.Columns.Add("Presentation",        StringType(150));
	Tree.Columns.Add("ObjectPresentation", StringType(150));
	Tree.Columns.Add("AttachmentName",          StringType(100));
	Tree.Columns.Add("NoGroup",            New TypeDescription("Boolean"));
	Tree.Columns.Add("HasHierarchy",         New TypeDescription("Boolean"));
	Tree.Columns.Add("WithoutDecryption",       New TypeDescription("Boolean"));
	Tree.Columns.Add("PathToObject",         StringType(255));
	Tree.Columns.Add("ParentMetadataAttachments"); // Populated automatically.
	
	// Configuration
	ConfigurationString = Tree.Rows.Add();
	ConfigurationString.Name                  = "Configuration";
	ConfigurationString.Metadata           = Metadata;
	ConfigurationString.RightsDetails         = ConfigRights();
	ConfigurationString.PathToObject         = "Configuration";
	ConfigurationString.Presentation        = NStr("en = 'Configuration';");
	ConfigurationString.ObjectPresentation = NStr("en = 'Configuration';");
	
	// Configuration.Common
	StringGeneral = ConfigurationString.Rows.Add();
	StringGeneral.Name           = "Overall";
	StringGeneral.Presentation = NStr("en = 'Common';");
	
	// Configuration.Common.FilterCriteria.Subsystems
	SubsystemRow = StringGeneral.Rows.Add();
	SubsystemRow.Name                  = "Subsystems";
	SubsystemRow.Metadata           = Metadata.Subsystems;
	SubsystemRow.RightsDetails         = ViewRight();
	SubsystemRow.PathToObject         = "Subsystem.*";
	SubsystemRow.Presentation        = NStr("en = 'Subsystems';");
	SubsystemRow.ObjectPresentation = NStr("en = 'Subsystem';");
	
	// Configuration.Common.FilterCriteria.Subsystems.Subsystems.*
	StringNestedSubsystems = SubsystemRow.Rows.Add();
	StringNestedSubsystems.Name                  = "Subsystems";
	StringNestedSubsystems.Metadata           = "Subsystems";
	StringNestedSubsystems.PathToObject         = "Subsystem.*.Subsystem.*";
	StringNestedSubsystems.RightsDetails         = ViewRight();
	StringNestedSubsystems.Presentation        = NStr("en = 'Subsystems';");
	StringNestedSubsystems.ObjectPresentation = NStr("en = 'Subsystem';");
	StringNestedSubsystems.AttachmentName          = "Subsystems";
	StringNestedSubsystems.NoGroup            = True;
	StringNestedSubsystems.HasHierarchy         = True;
	
	// Configuration.Common.FilterCriteria.SessionParameters
	StringSessionParameters = StringGeneral.Rows.Add();
	StringSessionParameters.Name                  = "SessionParameters";
	StringSessionParameters.Metadata           = Metadata.SessionParameters;
	StringSessionParameters.PathToObject         = "SessionParameter.*";
	StringSessionParameters.RightsDetails         = SessionSettingRights();
	StringSessionParameters.Presentation        = NStr("en = 'Session parameters';");
	StringSessionParameters.ObjectPresentation = NStr("en = 'Session parameter';");
	
	// Configuration.Common.FilterCriteria.CommonAttributes
	StringGeneralRequisites = StringGeneral.Rows.Add();
	StringGeneralRequisites.Name                  = "CommonAttributes";
	StringGeneralRequisites.Metadata           = Metadata.CommonAttributes;
	StringGeneralRequisites.PathToObject         = "CommonAttribute.*";
	StringGeneralRequisites.RightsDetails         = RightsAttributes();
	StringGeneralRequisites.Presentation        = NStr("en = 'Common attributes';");
	StringGeneralRequisites.ObjectPresentation = NStr("en = 'Common attribute';");
	
	// Configuration.Common.FilterCriteria.ExchangePlans
	StringExchangePlans = StringGeneral.Rows.Add();
	StringExchangePlans.Name                  = "ExchangePlans";
	StringExchangePlans.Metadata           = Metadata.ExchangePlans;
	StringExchangePlans.PathToObject         = "ExchangePlan.*";
	StringExchangePlans.RightsDetails         = ExchangePlanRights();
	StringExchangePlans.Presentation        = NStr("en = 'Exchange plans';");
	StringExchangePlans.ObjectPresentation = NStr("en = 'Exchange plan';");
	AddCommandsFields(WithFields, StringExchangePlans);
	
	// Configuration.Common.FilterCriteria
	StringSelectionCriteria = StringGeneral.Rows.Add();
	StringSelectionCriteria.Name                  = "FilterCriteria";
	StringSelectionCriteria.Metadata           = Metadata.FilterCriteria;
	StringSelectionCriteria.PathToObject         = "FilterCriterion.*";
	StringSelectionCriteria.RightsDetails         = ViewRight();
	StringSelectionCriteria.Presentation        = NStr("en = 'Filter criteria';");
	StringSelectionCriteria.ObjectPresentation = NStr("en = 'Filter criterion';");
	AddCommandsFields(False, StringSelectionCriteria);
	
	// Configuration.Common.FilterCriteria.CommonForms
	StringGeneralForms = StringGeneral.Rows.Add();
	StringGeneralForms.Name                  = "CommonForms";
	StringGeneralForms.Metadata           = Metadata.CommonForms;
	StringGeneralForms.PathToObject         = "CommonForm.*";
	StringGeneralForms.RightsDetails         = ViewRight();
	StringGeneralForms.Presentation        = NStr("en = 'Common forms';");
	StringGeneralForms.ObjectPresentation = NStr("en = 'Common form';");
	
	// Configuration.Common.FilterCriteria.CommonCommands
	StringCommonCommands = StringGeneral.Rows.Add();
	StringCommonCommands.Name                  = "CommonCommands";
	StringCommonCommands.Metadata           = Metadata.CommonCommands;
	StringCommonCommands.PathToObject         = "CommonCommand.*";
	StringCommonCommands.RightsDetails         = ViewRight();
	StringCommonCommands.Presentation        = NStr("en = 'Common commands';");
	StringCommonCommands.ObjectPresentation = NStr("en = 'Common command';");
	
	// Configuration.Common.WebServices
	StringWebServices = StringGeneral.Rows.Add();
	StringWebServices.Name                  = "WebServices";
	StringWebServices.Metadata           = Metadata.WebServices;
	StringWebServices.PathToObject         = "WebService.*";
	StringWebServices.Presentation        = NStr("en = 'Web services';");
	StringWebServices.ObjectPresentation = NStr("en = 'Web service';");
	
	// Configuration.Common.WebServices.Operations
	OperationString = StringWebServices.Rows.Add();
	OperationString.Name                  = "Operations";
	OperationString.AttachmentName          = "Operations";
	OperationString.PathToObject         = "WebService.*.Operation.*";
	OperationString.RightsDetails         = RightUse();
	OperationString.NoGroup            = True;
	OperationString.ObjectPresentation = NStr("en = 'Operation';");
	
	// Configuration.Common.HTTPServices
	StringHTTPServices = StringGeneral.Rows.Add();
	StringHTTPServices.Name                  = "HTTPServices";
	StringHTTPServices.Metadata           = Metadata.HTTPServices;
	StringHTTPServices.PathToObject         = "HTTPService.*";
	StringHTTPServices.Presentation        = NStr("en = 'HTTP services';");
	StringHTTPServices.ObjectPresentation = NStr("en = 'HTTP service';");
	
	// Configuration.Common.HTTPServices.URLTemplates
	StringTemplatesURL = StringHTTPServices.Rows.Add();
	StringTemplatesURL.Name                  = "URLTemplates";
	StringTemplatesURL.AttachmentName          = "URLTemplates";
	StringTemplatesURL.PathToObject         = "HTTPService.*.URLTemplate.*";
	StringTemplatesURL.NoGroup            = True;
	StringTemplatesURL.ObjectPresentation = NStr("en = 'URL template';");
	
	// Configuration.Common.HTTPService.URLTemplates.Methods
	StringMethods = StringTemplatesURL.Rows.Add();
	StringMethods.Name                  = "Methods";
	StringMethods.AttachmentName          = "Methods";
	StringMethods.PathToObject         = "HTTPService.*.URLTemplate.*.Method.*";
	StringMethods.RightsDetails         = RightUse();
	StringMethods.NoGroup            = True;
	StringMethods.ObjectPresentation = NStr("en = 'Method';");
	
	// Configuration.Constants
	StringConsts = ConfigurationString.Rows.Add();
	StringConsts.Name                  = "Constants";
	StringConsts.Metadata           = Metadata.Constants;
	StringConsts.PathToObject         = "Constant.*";
	StringConsts.RightsDetails         = RightsConsts();
	StringConsts.Presentation        = NStr("en = 'Constants';");
	StringConsts.ObjectPresentation = NStr("en = 'Constant';");
	
	// Configuration.Catalogs
	StringCatalogs = ConfigurationString.Rows.Add();
	StringCatalogs.Name                  = "Catalogs";
	StringCatalogs.Metadata           = Metadata.Catalogs;
	StringCatalogs.PathToObject         = "Catalog.*";
	StringCatalogs.RightsDetails         = RightsofDirectoryandPlans();
	StringCatalogs.Presentation        = NStr("en = 'Catalogs';");
	StringCatalogs.ObjectPresentation = NStr("en = 'Catalog';");
	AddCommandsFields(WithFields, StringCatalogs);
	
	// Configuration.Documents (group)
	StringGroupDocuments = ConfigurationString.Rows.Add();
	StringGroupDocuments.Name           = "Documents";
	StringGroupDocuments.Presentation = NStr("en = 'Documents';");
	
	// Configuration.Documents.Sequence
	StringSequence = StringGroupDocuments.Rows.Add();
	StringSequence.Name                  = "Sequences";
	StringSequence.Metadata           = Metadata.Sequences;
	StringSequence.PathToObject         = "Sequence.*";
	StringSequence.RightsDetails         = SequenceAndRecalculationRights();
	StringSequence.Presentation        = NStr("en = 'Sequences';");
	StringSequence.ObjectPresentation = NStr("en = 'Sequence';");
	
	// Configuration.Documents (elements)
	StringDocuments = StringGroupDocuments.Rows.Add();
	StringDocuments.Name                  = "Documents";
	StringDocuments.Metadata           = Metadata.Documents;
	StringDocuments.PathToObject         = "Document.*";
	StringDocuments.RightsDetails         = DocumentPermissions();
	StringDocuments.NoGroup            = True;
	StringDocuments.ObjectPresentation = NStr("en = 'Document';");
	AddCommandsFields(WithFields, StringDocuments);
	
	// Configuration.DocumentJournals
	StringDocumentLogs = ConfigurationString.Rows.Add();
	StringDocumentLogs.Name                  = "DocumentJournals";
	StringDocumentLogs.Metadata           = Metadata.DocumentJournals;
	StringDocumentLogs.PathToObject         = "DocumentJournal.*";
	StringDocumentLogs.RightsDetails         = PermissionsJournalDocuments();
	StringDocumentLogs.Presentation        = NStr("en = 'Document journals';");
	StringDocumentLogs.ObjectPresentation = NStr("en = 'Document journal';");
	AddCommandsFields(WithFields, StringDocumentLogs, "StandardAttributes", True);
	
	// Configuration.Enumerations
	EnumString = ConfigurationString.Rows.Add();
	EnumString.Name                  = "Enums";
	EnumString.Metadata           = Metadata.Enums;
	EnumString.PathToObject         = "Enum.*";
	EnumString.Presentation        = NStr("en = 'Enumerations';");
	EnumString.ObjectPresentation = NStr("en = 'Enumeration';");
	EnumString.WithoutDecryption       = True;
	AddCommandsFields(False, EnumString);
	
	// Configuration.Reports
	ReportsRow = ConfigurationString.Rows.Add();
	ReportsRow.Name                  = "Reports";
	ReportsRow.Metadata           = Metadata.Reports;
	ReportsRow.PathToObject         = "Report.*";
	ReportsRow.RightsDetails         = RightsReportProcessingFunctions();
	ReportsRow.Presentation        = NStr("en = 'Reports';");
	ReportsRow.ObjectPresentation = NStr("en = 'Report';");
	AddCommandsFields(WithFields, ReportsRow, "Attributes, TabularSections");
	
	// Configuration.DataProcessors
	ProcessingString = ConfigurationString.Rows.Add();
	ProcessingString.Name                  = "DataProcessors";
	ProcessingString.Metadata           = Metadata.DataProcessors;
	ProcessingString.PathToObject         = "DataProcessor.*";
	ProcessingString.RightsDetails         = RightsReportProcessingFunctions();
	ProcessingString.Presentation        = NStr("en = 'Data processors';");
	ProcessingString.ObjectPresentation = NStr("en = 'Data processor';");
	AddCommandsFields(WithFields, ProcessingString, "Attributes, TabularSections");
	
	// Configuration.ChartsOfCharacteristicTypes
	StringPlansViewsCharacteristics = ConfigurationString.Rows.Add();
	StringPlansViewsCharacteristics.Name                  = "ChartsOfCharacteristicTypes";
	StringPlansViewsCharacteristics.Metadata           = Metadata.ChartsOfCharacteristicTypes;
	StringPlansViewsCharacteristics.PathToObject         = "ChartOfCharacteristicTypes.*";
	StringPlansViewsCharacteristics.RightsDetails         = RightsofDirectoryandPlans();
	StringPlansViewsCharacteristics.Presentation        = NStr("en = 'Charts of characteristic types';");
	StringPlansViewsCharacteristics.ObjectPresentation = NStr("en = 'Chart of characteristic types';");
	AddCommandsFields(WithFields, StringPlansViewsCharacteristics);
	
	// Configuration.ChartsOfAccounts
	LineOfAccountPlans = ConfigurationString.Rows.Add();
	LineOfAccountPlans.Name                  = "ChartsOfAccounts";
	LineOfAccountPlans.Metadata           = Metadata.ChartsOfAccounts;
	LineOfAccountPlans.PathToObject         = "ChartOfAccounts.*";
	LineOfAccountPlans.RightsDetails         = RightsofDirectoryandPlans();
	LineOfAccountPlans.Presentation        = NStr("en = 'Charts of accounts';");
	LineOfAccountPlans.ObjectPresentation = NStr("en = 'Chart of accounts.';");
	AddCommandsFields(WithFields, LineOfAccountPlans, "Attributes, AccountingFlags,
	|ExtDimensionAccountingFlags, TabularSections, StandardAttributes, StandardTabularSections");
	
	// Configuration.ChartsOfCalculationTypes
	StringPlansViewsCalculation = ConfigurationString.Rows.Add();
	StringPlansViewsCalculation.Name                  = "ChartsOfCalculationTypes";
	StringPlansViewsCalculation.Metadata           = Metadata.ChartsOfCalculationTypes;
	StringPlansViewsCalculation.PathToObject         = "ChartOfCalculationTypes.*";
	StringPlansViewsCalculation.RightsDetails         = RightsofDirectoryandPlans();
	StringPlansViewsCalculation.Presentation        = NStr("en = 'Charts of calculation types';");
	StringPlansViewsCalculation.ObjectPresentation = NStr("en = 'Chart of calculation types.';");
	AddCommandsFields(WithFields, StringPlansViewsCalculation, "Attributes, TabularSections,
	|StandardAttributes, StandardTabularSections");
	
	// Configuration.InformationRegisters
	StringRegistersDetails = ConfigurationString.Rows.Add();
	StringRegistersDetails.Name                  = "InformationRegisters";
	StringRegistersDetails.Metadata           = Metadata.InformationRegisters;
	StringRegistersDetails.PathToObject         = "InformationRegister.*";
	StringRegistersDetails.RightsDetails         = RightsRegisterInformation();
	StringRegistersDetails.Presentation        = NStr("en = 'Information registers';");
	StringRegistersDetails.ObjectPresentation = NStr("en = 'Information register';");
	AddCommandsFields(WithFields, StringRegistersDetails, "Dimensions, Resources,
	|Attributes, StandardAttributes");
	
	// Configuration.AccumulationRegisters
	StringRegistersAccumulation = ConfigurationString.Rows.Add();
	StringRegistersAccumulation.Name                  = "AccumulationRegisters";
	StringRegistersAccumulation.Metadata           = Metadata.AccumulationRegisters;
	StringRegistersAccumulation.PathToObject         = "AccumulationRegister.*";
	StringRegistersAccumulation.RightsDetails         = RightsRegisterAccumulationAndAccounting();
	StringRegistersAccumulation.Presentation        = NStr("en = 'Accumulation registers';");
	StringRegistersAccumulation.ObjectPresentation = NStr("en = 'Accumulation register';");
	AddCommandsFields(WithFields, StringRegistersAccumulation, "Dimensions, Resources,
	|Attributes, StandardAttributes");
	
	// Configuration.AccountingRegisters
	StringRegistersAccounting = ConfigurationString.Rows.Add();
	StringRegistersAccounting.Name                  = "AccountingRegisters";
	StringRegistersAccounting.Metadata           = Metadata.AccountingRegisters;
	StringRegistersAccounting.PathToObject         = "AccountingRegister.*";
	StringRegistersAccounting.RightsDetails         = RightsRegisterAccumulationAndAccounting();
	StringRegistersAccounting.Presentation        = NStr("en = 'Accounting registers';");
	StringRegistersAccounting.ObjectPresentation = NStr("en = 'Accounting register';");
	AddCommandsFields(WithFields, StringRegistersAccounting, "Dimensions, Resources,
	|Attributes, StandardAttributes");
	
	// Configuration.CalculationRegisters
	StringRegistersCalculation = ConfigurationString.Rows.Add();
	StringRegistersCalculation.Name                  = "CalculationRegisters";
	StringRegistersCalculation.Metadata           = Metadata.CalculationRegisters;
	StringRegistersCalculation.PathToObject         = "CalculationRegister.*";
	StringRegistersCalculation.RightsDetails         = RightsRegisterCalculation();
	StringRegistersCalculation.Presentation        = NStr("en = 'Calculation registers';");
	StringRegistersCalculation.ObjectPresentation = NStr("en = 'Calculation register';");
	AddCommandsFields(WithFields, StringRegistersCalculation, "Dimensions, Resources,
	|Attributes, StandardAttributes, Recalculations");
	
	// Configuration.BusinessProcesses
	StringBusinessProcesses = ConfigurationString.Rows.Add();
	StringBusinessProcesses.Name                  = "BusinessProcesses";
	StringBusinessProcesses.Metadata           = Metadata.BusinessProcesses;
	StringBusinessProcesses.PathToObject         = "BusinessProcess.*";
	StringBusinessProcesses.RightsDetails         = RightsBusinessProcess();
	StringBusinessProcesses.Presentation        = NStr("en = 'Business processes';");
	StringBusinessProcesses.ObjectPresentation = NStr("en = 'Business process';");
	AddCommandsFields(WithFields, StringBusinessProcesses);
	
	// Configuration.Tasks
	TaskLine = ConfigurationString.Rows.Add();
	TaskLine.Name                  = "Tasks";
	TaskLine.Metadata           = Metadata.Tasks;
	TaskLine.PathToObject         = "Task.*";
	TaskLine.RightsDetails         = RightsTasks();
	TaskLine.Presentation        = NStr("en = 'Tasks';");
	TaskLine.ObjectPresentation = NStr("en = 'Task';");
	AddCommandsFields(WithFields, TaskLine, "AddressingAttributes,
	|Attributes, TabularSections, StandardAttributes");
	
	// Configuration.ExternalDataSources
	StringExternalDataSources = ConfigurationString.Rows.Add();
	StringExternalDataSources.Name                  = "ExternalDataSources";
	StringExternalDataSources.Metadata           = Metadata.ExternalDataSources;
	StringExternalDataSources.PathToObject         = "ExternalDataSource.*";
	StringExternalDataSources.RightsDetails         = RightsExternalDataSource();
	StringExternalDataSources.Presentation        = NStr("en = 'External data sources';");
	StringExternalDataSources.ObjectPresentation = NStr("en = 'External data source';");
	
	// Configuration.ExternalDataSources.Tables
	TableRow = StringExternalDataSources.Rows.Add();
	TableRow.Name                  = "Tables";
	TableRow.AttachmentName          = "Tables";
	TableRow.PathToObject         = "ExternalDataSource.*.Table.*";
	TableRow.RightsDetails         = RightsTableExternalDataSource();
	TableRow.Presentation        = NStr("en = 'Tables';");
	TableRow.ObjectPresentation = NStr("en = 'Table';");
	AddCommandsFields(WithFields, TableRow, "Fields");
	
	// Configuration.ExternalDataSources.Cubes
	StringCube = StringExternalDataSources.Rows.Add();
	StringCube.Name                  = "Cubes";
	StringCube.AttachmentName          = "Cubes";
	StringCube.PathToObject         = "ExternalDataSource.*.Cube.*";
	StringCube.RightsDetails         = PermissionsCubeAndDimensionTables();
	StringCube.Presentation        = NStr("en = 'Cubes';");
	StringCube.ObjectPresentation = NStr("en = 'Cube';");
	
	// Configuration.ExternalDataSources.Cubes.DimensionTables
	RowTableDimensions = StringCube.Rows.Add();
	RowTableDimensions.Name                  = "DimensionTables";
	RowTableDimensions.AttachmentName          = "DimensionTables";
	RowTableDimensions.PathToObject         = "ExternalDataSource.*.Cube.*.DimensionTable.*";
	RowTableDimensions.RightsDetails         = PermissionsCubeAndDimensionTables();
	RowTableDimensions.Presentation        = NStr("en = 'Dimension tables';");
	RowTableDimensions.ObjectPresentation = NStr("en = 'Dimension table';");
	AddCommandsFields(WithFields, RowTableDimensions, "Fields");
	AddCommandsFields(WithFields, StringCube, "Dimensions, Resources", True);
	
	// Configuration.ExternalDataSources.Functions
	FunctionString = StringExternalDataSources.Rows.Add();
	FunctionString.Name                  = "Functions";
	FunctionString.AttachmentName          = "Functions";
	FunctionString.PathToObject         = "ExternalDataSource.*.Function.*";
	FunctionString.RightsDetails         = RightsReportProcessingFunctions();
	FunctionString.Presentation        = NStr("en = 'Functions';");
	FunctionString.ObjectPresentation = NStr("en = 'Function';");
	
	Return Tree;
	
EndFunction

Procedure AddCommandsFields(WithFields, TreeRow, Fields = "Attributes, TabularSections, StandardAttributes", NoEdit = False)
	
	FieldsStructure = New Structure(Fields);
	
	If WithFields And FieldsStructure.Property("Dimensions") Then
		// Dimensions
		MeasurementString_ = TreeRow.Rows.Add();
		MeasurementString_.Name                  = "Dimensions";
		MeasurementString_.AttachmentName          = "Dimensions";
		MeasurementString_.PathToObject         = TreeRow.PathToObject + ".Dimension.*";
		MeasurementString_.RightsDetails         = RightsAttributes(NoEdit);
		MeasurementString_.Presentation        = NStr("en = 'Dimensions';");
		MeasurementString_.ObjectPresentation = NStr("en = 'Dimension';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("Resources") Then
		// Resources
		LineResources = TreeRow.Rows.Add();
		LineResources.Name                  = "Resources";
		LineResources.AttachmentName          = "Resources";
		LineResources.PathToObject         = TreeRow.PathToObject + ".Resource.*";
		LineResources.RightsDetails         = RightsAttributes(NoEdit);
		LineResources.Presentation        = NStr("en = 'Resources';");
		LineResources.ObjectPresentation = NStr("en = 'Resource';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("AddressingAttributes") Then
		// AddressingAttributes
		StringRequisitesAddresses = TreeRow.Rows.Add();
		StringRequisitesAddresses.Name                  = "AddressingAttributes";
		StringRequisitesAddresses.AttachmentName          = "AddressingAttributes";
		StringRequisitesAddresses.PathToObject         = TreeRow.PathToObject + ".AddressingAttribute.*";
		StringRequisitesAddresses.RightsDetails         = RightsAttributes(NoEdit);
		StringRequisitesAddresses.Presentation        = NStr("en = 'Addressing attributes.';");
		StringRequisitesAddresses.ObjectPresentation = NStr("en = 'Addressing attribute';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("Attributes") Then
		// Attributes
		AttributesString = TreeRow.Rows.Add();
		AttributesString.Name                  = "Attributes";
		AttributesString.AttachmentName          = "Attributes";
		AttributesString.PathToObject         = TreeRow.PathToObject + ".Attribute.*";
		AttributesString.RightsDetails         = RightsAttributes(NoEdit);
		AttributesString.Presentation        = NStr("en = 'Attributes';");
		AttributesString.ObjectPresentation = NStr("en = 'Attribute';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("Fields") Then
		// Fields
		FieldString = TreeRow.Rows.Add();
		FieldString.Name                  = "Fields";
		FieldString.AttachmentName          = "Fields";
		FieldString.PathToObject         = TreeRow.PathToObject + ".Field.*";
		FieldString.RightsDetails         = RightsAttributes(NoEdit);
		FieldString.Presentation        = NStr("en = 'Fields';");
		FieldString.ObjectPresentation = NStr("en = 'Field';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("AccountingFlags") Then
		// AccountingFlags
		StringAccountingAttributes = TreeRow.Rows.Add();
		StringAccountingAttributes.Name                  = "AccountingFlags";
		StringAccountingAttributes.AttachmentName          = "AccountingFlags";
		StringAccountingAttributes.PathToObject         = TreeRow.PathToObject + ".AccountingFlag.*";
		StringAccountingAttributes.RightsDetails         = RightsAttributes(NoEdit);
		StringAccountingAttributes.Presentation        = NStr("en = 'Accounting flags.';");
		StringAccountingAttributes.ObjectPresentation = NStr("en = 'Accounting flag';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("ExtDimensionAccountingFlags") Then
		// ExtDimensionAccountingFlags
		LineAccountingAttributesSubconto = TreeRow.Rows.Add();
		LineAccountingAttributesSubconto.Name                  = "ExtDimensionAccountingFlags";
		LineAccountingAttributesSubconto.AttachmentName          = "ExtDimensionAccountingFlags";
		LineAccountingAttributesSubconto.PathToObject         = TreeRow.PathToObject + ".ExtDimensionAccountingFlag.*";
		LineAccountingAttributesSubconto.RightsDetails         = RightsAttributes(NoEdit);
		LineAccountingAttributesSubconto.Presentation        = NStr("en = 'Extra dimension accounting flags.';");
		LineAccountingAttributesSubconto.ObjectPresentation = NStr("en = 'Extra dimension accounting flag';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("TabularSections") Then
		// TabularSections
		RowTableParts = TreeRow.Rows.Add();
		RowTableParts.Name                  = "TabularSections";
		RowTableParts.AttachmentName          = "TabularSections";
		RowTableParts.PathToObject         = TreeRow.PathToObject + ".TabularSection.*";
		RowTableParts.RightsDetails         = RightsAttributes(NoEdit);
		RowTableParts.Presentation        = NStr("en = 'Tables.';");
		RowTableParts.ObjectPresentation = NStr("en = 'Table';");
		
		// TabularSections.Attributes
		RowTablePartsAttributes = RowTableParts.Rows.Add();
		RowTablePartsAttributes.Name                  = "Attributes";
		RowTablePartsAttributes.AttachmentName          = "Attributes";
		RowTablePartsAttributes.PathToObject         = RowTableParts.PathToObject + ".Attribute.*";
		RowTablePartsAttributes.RightsDetails         = RightsAttributes(NoEdit);
		RowTablePartsAttributes.Presentation        = NStr("en = 'Attributes';");
		RowTablePartsAttributes.ObjectPresentation = NStr("en = 'Attribute';");
		RowTablePartsAttributes.NoGroup            = True;
	EndIf;
	
	If WithFields And FieldsStructure.Property("StandardAttributes") Then
		// StandardAttributes
		StringStandardAttributes = TreeRow.Rows.Add();
		StringStandardAttributes.Name                  = "StandardAttributes";
		StringStandardAttributes.AttachmentName          = "StandardAttributes";
		StringStandardAttributes.PathToObject         = TreeRow.PathToObject + ".StandardAttribute.*";
		StringStandardAttributes.RightsDetails         = RightsAttributes(NoEdit);
		StringStandardAttributes.Presentation        = NStr("en = 'Standard attributes.';");
		StringStandardAttributes.ObjectPresentation = NStr("en = 'Standard attribute';");
	EndIf;
	
	If WithFields And FieldsStructure.Property("StandardTabularSections") Then
		// StandardTabularSections
		RowStandardTableParts = TreeRow.Rows.Add();
		RowStandardTableParts.Name                  = "StandardTabularSections";
		RowStandardTableParts.AttachmentName          = "StandardTabularSections";
		RowStandardTableParts.PathToObject         = TreeRow.PathToObject + ".StandardTabularSection.*";
		RowStandardTableParts.RightsDetails         = RightsAttributes(NoEdit);
		RowStandardTableParts.Presentation        = NStr("en = 'Standard tables.';");
		RowStandardTableParts.ObjectPresentation = NStr("en = 'Standard table';");
		
		// StandardTabularSections.StandardAttributes
		RowStandardTablePartsStandardAttributes = RowStandardTableParts.Rows.Add();
		RowStandardTablePartsStandardAttributes.Name                  = "StandardAttributes";
		RowStandardTablePartsStandardAttributes.AttachmentName          = "StandardAttributes";
		RowStandardTablePartsStandardAttributes.PathToObject         = RowStandardTableParts.PathToObject + ".StandardAttribute.*";
		RowStandardTablePartsStandardAttributes.RightsDetails         = RightsAttributes(NoEdit);
		RowStandardTablePartsStandardAttributes.Presentation        = NStr("en = 'Standard attributes.';");
		RowStandardTablePartsStandardAttributes.ObjectPresentation = NStr("en = 'Standard attribute';");
		RowStandardTablePartsStandardAttributes.NoGroup            = True;
	EndIf;
	
	If FieldsStructure.Property("Recalculations") Then
		// Recalculations
		StringRecalculations = TreeRow.Rows.Add();
		StringRecalculations.Name                  = "Recalculations";
		StringRecalculations.AttachmentName          = "Recalculations";
		StringRecalculations.PathToObject         = TreeRow.PathToObject + ".Recalculation.*";
		StringRecalculations.RightsDetails         = SequenceAndRecalculationRights();
		StringRecalculations.Presentation        = NStr("en = 'Recalculations';");
		StringRecalculations.ObjectPresentation = NStr("en = 'Recalculation';");
	EndIf;
	
	// Commands
	CommandString = TreeRow.Rows.Add();
	CommandString.Name                  = "Commands";
	CommandString.AttachmentName          = "Commands";
	CommandString.PathToObject         = TreeRow.PathToObject + ".Command.*";
	CommandString.RightsDetails         = ViewRight();
	CommandString.Presentation        = NStr("en = 'Commands';");
	CommandString.ObjectPresentation = NStr("en = 'Command';");
	
EndProcedure

// Returns:
//  Structure:
//   * RightsList - ValueList
//   * AccessLevels - ValueTable:
//      ** Right              - String
//      ** ThisPermissionSet       - Boolean
//      ** Level            - Number
//      ** RightWithRestriction - String
//
Function RightsDetails()
	
	AccessLevels = New ValueTable;
	AccessLevels.Columns.Add("Right",              StringType(1000));
	AccessLevels.Columns.Add("ThisPermissionSet",       New TypeDescription("Boolean"));
	AccessLevels.Columns.Add("Level",            NumberType(2));
	AccessLevels.Columns.Add("RightWithRestriction", StringType(1000));
	
	RightsDetails = New Structure;
	RightsDetails.Insert("RightsList",    New ValueList);
	RightsDetails.Insert("AccessLevels", AccessLevels);
	
	Return RightsDetails;
	
EndFunction

Function ConfigRights()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("Administration",
		NStr("en = 'Administration';"));
	
	RightsList.Add("DataAdministration",
		NStr("en = 'Data administration';"));
	
	RightsList.Add("UpdateDataBaseConfiguration",
		NStr("en = 'Update database configuration';"));
	
	RightsList.Add("ExclusiveMode",
		NStr("en = 'Exclusive mode';"));
	
	RightsList.Add("ActiveUsers",
		NStr("en = 'Active users';"));
	
	RightsList.Add("EventLog",
		NStr("en = 'Event log';"));
	
	RightsList.Add("ThinClient",
		NStr("en = 'Thin client';"));
	
	RightsList.Add("WebClient",
		NStr("en = 'Web client';"));
	
	RightsList.Add("MobileClient",
		NStr("en = 'Mobile client';"));
	
	RightsList.Add("ThickClient",
		NStr("en = 'Thick client';"));
	
	RightsList.Add("ExternalConnection",
		NStr("en = 'External connection';"));
	
	RightsList.Add("Automation",
		NStr("en = 'Automation';"));
	
	RightsList.Add("AllFunctionsMode",
		NStr("en = '""All functions"" mode';"));
	
	RightsList.Add("CollaborationSystemInfoBaseRegistration",
		NStr("en = 'Collaboration system registration';"));
	
	RightsList.Add("MainWindowModeNormal",
		NStr("en = 'Main window ""Standard"" mode';"));
	
	RightsList.Add("MainWindowModeWorkplace",
		NStr("en = 'Main window ""Workspace"" mode';"));
	
	RightsList.Add("MainWindowModeEmbeddedWorkplace",
		NStr("en = 'Main window ""Embedded workspace"" mode';"));
	
	RightsList.Add("MainWindowModeFullscreenWorkplace",
		NStr("en = 'Main window ""Fullscreen workspace"" mode';"));
	
	RightsList.Add("MainWindowModeKiosk",
		NStr("en = 'Main window ""Kiosk"" mode';"));
	
	RightsList.Add("SaveUserData",
		NStr("en = 'Save user data';"));
	
	RightsList.Add("ConfigurationExtensionsAdministration",
		NStr("en = 'Administer configuration extensions';"));
	
	RightsList.Add("InteractiveOpenExtDataProcessors",
		NStr("en = 'Open external data processors interactively';"));
	
	RightsList.Add("InteractiveOpenExtReports",
		NStr("en = 'Open external reports interactively';"));
	
	RightsList.Add("Output",
		NStr("en = 'Output';"));
	
	AccessLevels = RightsDetails.AccessLevels;
	For Each ListItem In RightsList Do
		NewRow = AccessLevels.Add();
		NewRow.Right   = ListItem.Value;
		NewRow.Level = 1;
	EndDo;
	
	Return RightsDetails;
	
EndFunction

Function ViewRight()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("View",
		NStr("en = 'View';"));
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "View";
	NewRow.Level = 4;
	
	Return RightsDetails;
	
EndFunction

Function RightUse()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("Use",
		NStr("en = 'Use';"));
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Use";
	NewRow.Level = 2;
	
	Return RightsDetails;
	
EndFunction

Function SessionSettingRights()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	// @Access-right-1
	RightsList.Add("Get",
		NStr("en = 'Get';"));
	
	// @Access-right-1
	RightsList.Add("Set",
		NStr("en = 'Install';"));
	
	NewRow = RightsDetails.AccessLevels.Add();
	// @Access-right-1, @Access-right-2
	NewRow.Right   = "Get" + "," + "Set";
	NewRow.Level = 11;
	NewRow.ThisPermissionSet = True;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Set"; // @Access-right-1
	NewRow.Level = 10;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Get"; // @Access-right-1
	NewRow.Level = 9;
	
	Return RightsDetails;
	
EndFunction

Function RightsAttributes(NoEdit = False)
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("View",
		NStr("en = 'View';"));
	
	If Not NoEdit Then
		RightsList.Add("Edit",
			NStr("en = 'Edit';"));
		
		NewRow = RightsDetails.AccessLevels.Add();
		NewRow.Right   = "Edit";
		NewRow.Level = 6;
	EndIf;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "View";
	NewRow.Level = 4;
	
	Return RightsDetails;
	
EndFunction

Function ExchangePlanRights()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	AddPermissionsInteractiveWorkWithObjects(RightsList);
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function RightsConsts()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList, , False, False);
	AddPermissionsInteractiveWorkWithObjects(RightsList, , False);
	AddJobPermissionsWithHistory(RightsList, False);
	
	FillAccessLevels(RightsDetails, , False, False);
	
	Return RightsDetails;
	
EndFunction

Function RightsofDirectoryandPlans()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	AddPermissionsInteractiveWorkWithObjects(RightsList);
	AddJobPermissionsWithPredefinedData(RightsList);
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function SequenceAndRecalculationRights()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList,, False);
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Update";
	NewRow.Level = 5;
	NewRow.RightWithRestriction = "Update";
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Read";
	NewRow.Level = 3;
	NewRow.RightWithRestriction = "Read";
	
	Return RightsDetails;
	
EndFunction

Function DocumentPermissions()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	
	RightsList.Add("Posting",
		NStr("en = 'Post';"));
	
	RightsList.Add("UndoPosting",
		NStr("en = 'Unpost';"));
	
	AddPermissionsInteractiveWorkWithObjects(RightsList);
	
	RightsList.Add("InteractivePosting",
		NStr("en = 'Post interactively';"));
	
	RightsList.Add("InteractivePostingRegular",
		NStr("en = 'Backdate post interactively';"));
	
	RightsList.Add("InteractiveUndoPosting",
		NStr("en = 'Unpost interactively';"));
	
	RightsList.Add("InteractiveChangeOfPosted",
		NStr("en = 'Modify posted items interactively';"));
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function PermissionsJournalDocuments()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList, True);
	AddPermissionsInteractiveWorkWithObjects(RightsList, True);
	
	FillAccessLevels(RightsDetails, True);
	
	Return RightsDetails;
	
EndFunction

Function RightsReportProcessingFunctions()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("Use",
		NStr("en = 'Use';"));
	
	RightsList.Add("View",
		NStr("en = 'View';"));
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "View";
	NewRow.Level = 4;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Use";
	NewRow.Level = 2;
	
	Return RightsDetails;
	
EndFunction

Function RightsRegisterInformation()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList,, False);
	AddPermissionsInteractiveWorkWithObjects(RightsList,, False);
	
	RightsList.Add("TotalsControl",
		NStr("en = 'Totals management';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails,, False);
	
	Return RightsDetails;
	
EndFunction

Function RightsRegisterAccumulationAndAccounting()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList,, False);
	AddPermissionsInteractiveWorkWithObjects(RightsList,, False);
	
	RightsList.Add("TotalsControl",
		NStr("en = 'Totals management';"));
	
	FillAccessLevels(RightsDetails,, False);
	
	Return RightsDetails;
	
EndFunction

Function RightsRegisterCalculation()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList,, False);
	AddPermissionsInteractiveWorkWithObjects(RightsList,, False);
	
	FillAccessLevels(RightsDetails,, False);
	
	Return RightsDetails;
	
EndFunction

Function RightsBusinessProcess()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	
	RightsList.Add("Start",
		NStr("en = 'Start';"));
	
	AddPermissionsInteractiveWorkWithObjects(RightsList);
	
	RightsList.Add("InteractiveStart",
		NStr("en = 'Start interactively';"));
	
	RightsList.Add("InteractiveActivate",
		NStr("en = 'Activate interactively';"));
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function RightsTasks()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	
	RightsList.Add("Perform",
		NStr("en = 'Execute';"));
	
	AddPermissionsInteractiveWorkWithObjects(RightsList);
	
	RightsList.Add("InteractiveExecute",
		NStr("en = 'Execution interactively';"));
	
	RightsList.Add("InteractiveActivate",
		NStr("en = 'Activate interactively';"));
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	AddJobPermissionsWithHistory(RightsList);
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function RightsExternalDataSource()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	RightsList.Add("Use",
		NStr("en = 'Use';"));
	
	RightsList.Add("Administration",
		NStr("en = 'Administration';"));
	
	RightsList.Add("StandardAuthenticationChange",
		NStr("en = 'Change standard authentication for current user';"));
	
	RightsList.Add("SessionStandardAuthenticationChange",
		NStr("en = 'Change standard authentication for current session';"));
	
	RightsList.Add("SessionOSAuthenticationChange",
		NStr("en = 'Change standard authentication for current session OS';"));
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Use,Administration";
	NewRow.Level = 14;
	NewRow.ThisPermissionSet = True;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Administration";
	NewRow.Level = 13;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "Use";
	NewRow.Level = 12;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "StandardAuthenticationChange";
	NewRow.Level = 1;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "SessionStandardAuthenticationChange";
	NewRow.Level = 1;
	
	NewRow = RightsDetails.AccessLevels.Add();
	NewRow.Right   = "SessionOSAuthenticationChange";
	NewRow.Level = 1;
	
	Return RightsDetails;
	
EndFunction

Function RightsTableExternalDataSource()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList);
	AddPermissionsInteractiveWorkWithObjects(RightsList,,, False);
	
	RightsList.Add("InputByString",
		NStr("en = 'Input by string';"));
	
	FillAccessLevels(RightsDetails);
	
	Return RightsDetails;
	
EndFunction

Function PermissionsCubeAndDimensionTables()
	
	RightsDetails = RightsDetails();
	RightsList = RightsDetails.RightsList;
	
	AddPermissionsProgrammingWorkWithObjects(RightsList, True,, False);
	AddPermissionsInteractiveWorkWithObjects(RightsList, True);
	
	FillAccessLevels(RightsDetails, True,, False);
	
	Return RightsDetails;
	
EndFunction

Procedure AddPermissionsProgrammingWorkWithObjects(RightsList, Un_changed = False, ReferenceItems = True, withlimit = True)
	
	RightsList.Add("Read",
		NStr("en = 'Read';"), withlimit);
	
	If Un_changed Then
		Return;
	EndIf;
	
	RightsList.Add("Update",
		NStr("en = 'Modify';"), withlimit);
	
	If Not ReferenceItems Then
		Return;
	EndIf;
	
	// @Access-right-1
	RightsList.Add("Insert",
		NStr("en = 'Add';"), withlimit);
	
	RightsList.Add("Delete",
		NStr("en = 'Delete';"), withlimit);
	
EndProcedure

Procedure AddPermissionsInteractiveWorkWithObjects(RightsList, Un_changed = False, ReferenceItems = True, WithDeletionTagged = True)
	
	RightsList.Add("View",
		NStr("en = 'View';"));
	
	If Un_changed Then
		Return;
	EndIf;
	
	RightsList.Add("Edit",
		NStr("en = 'Edit';"));
	
	If Not ReferenceItems Then
		Return;
	EndIf;
	
	RightsList.Add("InteractiveInsert",
		NStr("en = 'Add interactively';"));
	
	RightsList.Add("InteractiveDelete",
		NStr("en = 'Delete interactively';"));
	
	If Not WithDeletionTagged Then
		Return;
	EndIf;
	
	RightsList.Add("InteractiveDeletionMark",
		NStr("en = 'Mark for deletion interactively';"));
	
	RightsList.Add("InteractiveClearDeletionMark",
		NStr("en = 'Unmark for deletion interactively';"));
	
	RightsList.Add("InteractiveDeleteMarked",
		NStr("en = 'Delete items marked for deletion interactively';"));
	
EndProcedure

Procedure AddJobPermissionsWithPredefinedData(RightsList)
	
	RightsList.Add("InteractiveDeletePredefinedData",
		NStr("en = 'Delete predefined items interactively';"));
	
	RightsList.Add("InteractiveSetDeletionMarkPredefinedData",
		NStr("en = 'Mark predefined items for deletion interactively';"));
	
	RightsList.Add("InteractiveClearDeletionMarkPredefinedData",
		NStr("en = 'Unmark predefined items for deletion interactively';"));
	
	RightsList.Add("InteractiveDeleteMarkedPredefinedData",
		NStr("en = 'Delete predefined items marked for deletion interactively';"));
	
EndProcedure

Procedure AddJobPermissionsWithHistory(RightsList, RightsOnMissingData = True)
	
	RightsList.Add("ReadDataHistory",
		NStr("en = 'Read data history';"));
	
	If RightsOnMissingData Then
		RightsList.Add("ReadDataHistoryOfMissingData",
			NStr("en = 'Read data history of missing data';"));
	EndIf;
	
	RightsList.Add("UpdateDataHistory",
		NStr("en = 'Modify data history';"));
	
	If RightsOnMissingData Then
		RightsList.Add("UpdateDataHistoryOfMissingData",
			NStr("en = 'Modify data history of missing data';"));
	EndIf;
	
	RightsList.Add("UpdateDataHistorySettings",
		NStr("en = 'Change data history settings';"));
	
	RightsList.Add("UpdateDataHistoryVersionComment",
		NStr("en = 'Change data history version comment';"));
	
	RightsList.Add("ViewDataHistory",
		NStr("en = 'View data history';"));
	
	RightsList.Add("EditDataHistoryVersionComment",
		NStr("en = 'Edit data history version comment';"));
	
	RightsList.Add("SwitchToDataHistoryVersion",
		NStr("en = 'Rollback to data history version';"));

EndProcedure

Procedure FillAccessLevels(RightsDetails, Un_changed = False, Referential = True, withlimit = True)
	
	AccessLevels = RightsDetails.AccessLevels;
	
	If Referential And Not Un_changed Then
		NewRow = AccessLevels.Add();
		NewRow.Right   = "InteractiveInsert";
		NewRow.Level = 8;
		If withlimit Then
			NewRow.RightWithRestriction = "Insert"; // @Access-right-1
		EndIf;
		
		NewRow = AccessLevels.Add();
		NewRow.Right   = "Insert"; // @Access-right-1
		NewRow.Level = 7;
		If withlimit Then
			NewRow.RightWithRestriction = "Insert"; // @Access-right-1
		EndIf;
	EndIf;
	
	If Not Un_changed Then
		NewRow = AccessLevels.Add();
		NewRow.Right   = "Edit";
		NewRow.Level = 6;
		If withlimit Then
			NewRow.RightWithRestriction = "Update";
		EndIf;
		
		NewRow = AccessLevels.Add();
		NewRow.Right   = "Update";
		NewRow.Level = 5;
		If withlimit Then
			NewRow.RightWithRestriction = "Update";
		EndIf;
	EndIf;
	
	NewRow = AccessLevels.Add();
	NewRow.Right   = "View";
	NewRow.Level = 4;
	If withlimit Then
		NewRow.RightWithRestriction = "Read";
	EndIf;
	
	NewRow = AccessLevels.Add();
	NewRow.Right   = "Read";
	NewRow.Level = 3;
	If withlimit Then
		NewRow.RightWithRestriction = "Read";
	EndIf;
	
EndProcedure

Function Images()
	
	Images = New ValueList;
	Images.Add(""); // No picture.
	Images.Add("Configuration",,,              PictureLib.MetadataConfiguration);
	Images.Add("Overall",,,                     PictureLib.MetadataCommon);
	Images.Add("Subsystems",,,                PictureLib.MetadataSubsystems);
	Images.Add("SessionParameters",,,           PictureLib.MetadataSessionParameters);
	Images.Add("CommonAttributes",,,            PictureLib.MetadataCommonAttributes);
	Images.Add("ExchangePlans",,,               PictureLib.MetadataExchangePlans);
	Images.Add("Attributes",,,                 PictureLib.MetadataAttributes);
	Images.Add("TabularSections",,,            PictureLib.MetadataTabularSections);
	Images.Add("StandardAttributes",,,      PictureLib.MetadataStandardAttributes);
	Images.Add("Commands",,,                   PictureLib.MetadataCommands);
	Images.Add("FilterCriteria",,,            PictureLib.MetadataFilterCriteria);
	Images.Add("CommonForms",,,                PictureLib.MetadataCommonForms);
	Images.Add("CommonCommands",,,              PictureLib.MetadataCommonCommands);
	Images.Add("WebServices",,,                PictureLib.MetadataWebServices);
	Images.Add("Operations",,,                  PictureLib.MetadataWebServicesOperations);
	Images.Add("HTTPServices",,,               PictureLib.MetadataHTTPServices);
	Images.Add("URLTemplates",,,                PictureLib.MetadataHTTPServicesURLTemplates);
	Images.Add("Methods",,,                    PictureLib.MetadataHTTPServicesURLTemplatesMethods);
	Images.Add("Constants",,,                 PictureLib.MetadataConstants);
	Images.Add("Catalogs",,,               PictureLib.MetadataCatalogs);
	Images.Add("Documents",,,                 PictureLib.MetadataDocuments);
	Images.Add("Sequences",,,        PictureLib.MetadataSequences);
	Images.Add("DocumentJournals",,,         PictureLib.MetadataDocumentJournals);
	Images.Add("Enums",,,              PictureLib.EnumerationMetadata);
	Images.Add("Reports",,,                    PictureLib.MetadataReports);
	Images.Add("DataProcessors",,,                 PictureLib.MetadataDataProcessors);
	Images.Add("ChartsOfCharacteristicTypes",,,   PictureLib.MetadataChartsOfCharacteristicTypes);
	Images.Add("ChartsOfAccounts",,,               PictureLib.MetadataChartsOfAccounts);
	Images.Add("AccountingFlags",,,             PictureLib.MetadataAccountingFlags);
	Images.Add("ExtDimensionAccountingFlags",,,     PictureLib.MetadataAccountingFlagsExtraDimension);
	Images.Add("StandardTabularSections",,, PictureLib.MetadataStandardTabularSections);
	Images.Add("ChartsOfCalculationTypes",,,         PictureLib.MetadataChartsOfCalculationTypes);
	Images.Add("InformationRegisters",,,          PictureLib.MetadataInformationRegisters);
	Images.Add("Dimensions",,,                 PictureLib.MetadataDimensions);
	Images.Add("Resources",,,                   PictureLib.MetadataResources);
	Images.Add("AccumulationRegisters",,,        PictureLib.MetadataAccumulationRegisters);
	Images.Add("AccountingRegisters",,,       PictureLib.MetadataAccountingRegisters);
	Images.Add("CalculationRegisters",,,           PictureLib.MetadataCalculationRegisters);
	Images.Add("Recalculations",,,               PictureLib.MetadataRecalculations);
	Images.Add("BusinessProcesses",,,            PictureLib.MetadataBusinessProcesses);
	Images.Add("Tasks",,,                    PictureLib.MetadataTasks);
	Images.Add("AddressingAttributes",,,        PictureLib.MetadataAddressingAttributes);
	Images.Add("ExternalDataSources",,,    PictureLib.MetadataExternalDataSources);
	Images.Add("Tables",,,                   PictureLib.MetadataExternalSourcesTables);
	Images.Add("Fields",,,                      PictureLib.MetadataAttributes);
	Images.Add("Cubes",,,                      PictureLib.MetadataExternalSourcesCubes);
	Images.Add("DimensionTables",,,          PictureLib.MetadataExternalSourcesDimensionTables);
	Images.Add("Functions",,,                   PictureLib.MetadataExternalSourcesFunctions);
	
	Return Images;
	
EndFunction

Function PictureIndex(Context, Name)
	
	ListItem = Context.Images.FindByValue(Name);
	If ListItem = Undefined Then
		Return 0;
	EndIf;
	
	Return Context.Images.IndexOf(ListItem);
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf