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
	
	If VariantKey = "UserRightsToTable" Then
		Settings.EditStructureAllowed = False;
	EndIf;
	Settings.GenerateImmediately = True;
	Settings.Events.BeforeImportSettingsToComposer = True;
	Settings.Events.OnCreateAtServer = True;
	Settings.Events.OnDefineUsedTables = True;
	
EndProcedure

// See ReportsOverridable.OnCreateAtServer
Procedure OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	If ValueIsFilled(Form.ReportSettings.OptionRef) Then
		Form.ReportSettings.Description = Form.ReportSettings.OptionRef;
	EndIf;
	
	If Form.OptionContext = Metadata.Catalogs.Users.FullName()
	   And Form.Parameters.Property("CommandParameter") Then
		If Form.Parameters.CommandParameter.Count() > 1 Then
			Form.CurrentVariantKey = "UsersRightsToTables";
			Form.Parameters.VariantKey = "UsersRightsToTables";
		Else
			Form.CurrentVariantKey = "UserRightsToTables";
			Form.Parameters.VariantKey = "UserRightsToTables";
		EndIf;
		Form.ContextOptions.Clear();
		Form.ContextOptions.Add(Form.CurrentVariantKey);
	EndIf;
	If ValueIsFilled(Form.OptionContext) Then
		Form.ParametersForm.InitialOptionKey = Form.CurrentVariantKey;
		Form.ParametersForm.Filter.Insert("InitialSelection");
	EndIf;
	
	If AccessManagementInternal.SimplifiedAccessRightsSetupInterface() Then
		Form.ReportSettings.SchemaModified = True;
		Schema = GetFromTempStorage(Form.ReportSettings.SchemaURL);
		Field = Schema.DataSets.UsersRights.Fields.Find("AccessGroup");
		Field.Title = NStr("en = 'User profile';");
		Field.ValueType = New TypeDescription("CatalogRef.AccessGroupProfiles");
		Form.ReportSettings.SchemaURL = PutToTempStorage(Schema, Form.UUID);
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
	
	If SchemaKey <> "1" Then
		SchemaKey = "1";
		If TypeOf(Context) = Type("ClientApplicationForm") And NewDCSettings <> Undefined Then
			FormAttributes = New Structure("OptionContext");
			FillPropertyValues(FormAttributes, Context);
			Variant = NewDCSettings.AdditionalProperties.PredefinedOptionKey;
			
			If ValueIsFilled(FormAttributes.OptionContext) Then
				If Variant = "UsersRightsToTable"
				 Or Variant = "UserRightsToTable" Then
					MetadataObject = Common.MetadataObjectID(Context.OptionContext, False);
					If ValueIsFilled(MetadataObject) Then
						CommonClientServer.SetFilterItem(NewDCSettings.Filter, "MetadataObject", MetadataObject,
							DataCompositionComparisonType.Equal, , True);
					EndIf;
				ElsIf Variant = "UsersRightsToTables" Or Variant = "UserRightsToTables" Then
					If Context.Parameters.Property("CommandParameter") Then
						UsersList = New ValueList;
						UsersList.LoadValues(Context.Parameters.CommandParameter);
						UsersInternal.SetFilterOnParameter("User", UsersList,
							NewDCSettings, NewDCUserSettings);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	SchemeHasBeenChanged = False;
	
	If Not Users.IsFullUser() Then
		DataCompositionSchema.Parameters.User.UseRestriction = True;
		DataCompositionSchema.Parameters.UsersKind.UseRestriction = True;
		SchemeHasBeenChanged = True;
	EndIf;
	
	If Not Constants.UseExternalUsers.Get() Then
		DataCompositionSchema.Parameters.UsersKind.UseRestriction = True;
		SchemeHasBeenChanged = True;
	EndIf;
	
	If SchemeHasBeenChanged
	   And Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		
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
	
	TablesToUse.Add(Metadata.InformationRegisters.RolesRights.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroupProfiles.FullName());
	TablesToUse.Add(Metadata.Catalogs.AccessGroups.FullName());
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
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ErrorText = NStr("en = 'To use the report, deploy the Report options subsystem.';");
		Raise ErrorText;
	EndIf;
	
	ComposerSettings = SettingsComposer.GetSettings();
	
	ParameterUserType = ComposerSettings.DataParameters.Items.Find("UsersKind");
	ParameterUser     = ComposerSettings.DataParameters.Items.Find("User");
	
	If ParameterUser.Use
	   And Not ValueIsFilled(ParameterUser.Value) Then
		
		ParameterUser.Use = False;
	EndIf;
	
	If ParameterUser.Use Then
		ParameterUserType.Use = False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	RightsSettings = RightsSettingsOnObjects();
	
	If Not ValueIsFilled(RightsSettings.SettingsRightsLegend) Then
		DisableGroups(ComposerSettings,
			"RightsSettings,LegendSettingsRights,OptionalTableTitle");
	EndIf;
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, ComposerSettings, DetailsData);
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("UsersRights",      UsersRights());
	ExternalDataSets.Insert("RightsSettingsOnObjects", RightsSettings.RightsSettingsOnObjects);
	ExternalDataSets.Insert("SettingsRightsHierarchy",   RightsSettings.SettingsRightsHierarchy);
	ExternalDataSets.Insert("SettingsRightsLegend",    RightsSettings.SettingsRightsLegend);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.Output(CompositionProcessor);
	
	FinishOutput(ResultDocument, DetailsData, RightsSettings);
	
EndProcedure

Procedure FinishOutput(ResultDocument, DetailsData, RightsSettings)
	
	AccessGroupTitle = NStr("en = 'Access group';");
	If AccessManagementInternal.SimplifiedAccessRightsSetupInterface() Then
		AccessGroupTitle = NStr("en = 'User profile';");
	EndIf;
	
	// ACC:163-off - #598.1. The use is permissible, as it affects the meaning.
	TextIsRestriction  = NStr("en = 'Not everything is available';");
	// ACC:163-on
	TextRightNotAssigned = NStr("en = '●';");
	TextRightAllowed   = NStr("en = '✔';");
	TextRightForbidden   = NStr("en = '✘';");
	FontRightNotAssigned = Undefined;
	FontRightAllowed   = Undefined;
	FontRightForbidden   = Undefined;
	ColorRightNotAssigned  = Metadata.StyleItems.UnassignedAccessRightColor.Value;
	ColorRightAllowed    = Metadata.StyleItems.AllowedAccessRightColor.Value;
	ColorRightForbidden    = Metadata.StyleItems.DeniedAccessRightColor.Value;
	ColorRightComputed  = Metadata.StyleItems.CalculatedAccessRightColor.Value;
	StringExplanations   = New Map;
	TranscribeColumns = New Map;
	SetRightForSubfolders = DescriptionColumnsForSubfolders().Title;
	None = New Line(SpreadsheetDocumentCellLineType.None);
	DataCompositionDecryptionIdentifierType = Type("DataCompositionDetailsID");
	TableHeight = ResultDocument.TableHeight;
	TableWidth = ResultDocument.TableWidth;
	
	For LineNumber = 1 To TableHeight Do
		For ColumnNumber = 1 To TableWidth Do
			Area = ResultDocument.Area(LineNumber, ColumnNumber);
			
			Details = Area.Details;
			If TypeOf(Details) <> DataCompositionDecryptionIdentifierType Then
				AreaText = Area.Text;
				
				If AreaText = "*" Then
					Area.Text = "";
					Area.Comment.Text = TextIsRestriction;
					
				ElsIf AreaText = "&AccessGroupTitle" Then
					Area.Text = AccessGroupTitle;
					
				ElsIf AreaText = "&OwnerSettingsHeader" Then
					Area.Text = RightsSettings.OwnerSettingsHeader;
				EndIf;
				
				Continue;
			EndIf;
			
			FieldValues = DetailsData.Items[Details].GetFields();
			
			If FieldValues.Find("Right") <> Undefined
			   And FieldValues.Find("Right").Value > 0
			   And FieldValues.Find("RightUnlimited") <> Undefined
			   And FieldValues.Find("Right").Value
			     > FieldValues.Find("RightUnlimited").Value
			 Or FieldValues.Find("ViewRight") <> Undefined
			   And FieldValues.Find("ViewRight").Value = True
			   And FieldValues.Find("UnrestrictedReadRight").Value = False
			 Or FieldValues.Find("EditRight") <> Undefined
			   And FieldValues.Find("EditRight").Value = True
			   And FieldValues.Find("UnrestrictedUpdateRight").Value = False
			 Or FieldValues.Find("InteractiveAddRight") <> Undefined
			   And FieldValues.Find("InteractiveAddRight").Value = True
			   And FieldValues.Find("UnrestrictedAddRight").Value = False Then
				
				Area.Comment.Text = TextIsRestriction;
				
			ElsIf FieldValues.Find("RightsValue") <> Undefined Then
				RightsValue = FieldValues.Find("RightsValue").Value;
				If RightsValue = Null Then
					RightsValue = 0;
					ThisSettingsOwner = StringExplanations.Get(LineNumber).Find("ThisSettingsOwner").Value;
					CustomizedRight = TranscribeColumns.Get(ColumnNumber).Find("CustomizedRight").Value;
				Else
					ThisSettingsOwner = FieldValues.Find("ThisSettingsOwner").Value;
					If RightsValue = 0 Then
						CustomizedRight = FieldValues.Find("CustomizedRight").Value;
					EndIf;
				EndIf;
				If RightsValue = 0 Then
					If ThisSettingsOwner And CustomizedRight <> SetRightForSubfolders Then
						RightsValue = 2;
					ElsIf CustomizedRight <> SetRightForSubfolders Then
						Area.Text      = TextRightNotAssigned;
						Area.Font      = FontRightNotAssigned;
						Area.TextColor = ColorRightNotAssigned;
					EndIf;
				EndIf;
				If RightsValue = 1 Then
					Area.Text      = TextRightAllowed;
					Area.Font      = FontRightAllowed;
					Area.TextColor = ?(ThisSettingsOwner, ColorRightComputed, ColorRightAllowed);
					
				ElsIf RightsValue = 2 Then
					Area.Text      = TextRightForbidden;
					Area.Font      = FontRightForbidden;
					Area.TextColor = ?(ThisSettingsOwner, ColorRightComputed, ColorRightForbidden);
				EndIf;
				
			ElsIf FieldValues.Find("OwnerOrUserSettings") <> Undefined Then
				StringExplanations.Insert(LineNumber, FieldValues);
				If FontRightNotAssigned = Undefined Then
					FontRightNotAssigned = Area.Font;
					//@skip-check new-font - Standard fond enlarged to 120% with an italic style.
					FontRightAllowed   = New Font(FontRightNotAssigned,,, True,,,, 120);
					FontRightForbidden   = FontRightAllowed;
				EndIf;
				Indent = (FieldValues.Find("Level").Value - 1) * 2;
				RowArea = ResultDocument.Area(LineNumber, , LineNumber);
				RowArea.CreateFormatOfRows();
				AreaOnRight = ResultDocument.Area(LineNumber, ColumnNumber);
				AreaLeft  = ResultDocument.Area(LineNumber, ColumnNumber - 1);
				AreaOnRight.LeftBorder = None;
				AreaLeft.RightBorder = None;
				AreaOnRight.ColumnWidth = Area.ColumnWidth + AreaLeft.ColumnWidth - Indent;
				AreaLeft.ColumnWidth = Indent;
				
			ElsIf FieldValues.Find("CustomizedRight") <> Undefined Then
				TranscribeColumns.Insert(ColumnNumber, FieldValues);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function ReportsTables()
	
	Result = BlankReportsTablesCollection();
	DescriptionOfIDTypes = DescriptionOfIDTypes();
	
	SelectedReport = SelectedReport();
	TablesToUse = Undefined;
	
	If ValueIsFilled(SelectedReport)
		And SettingsComposer.UserSettings.AdditionalProperties.Property("TablesToUse", TablesToUse)
		And TablesToUse <> Undefined Then 
		
		MetadataObjectIDs =
			Common.MetadataObjectIDs(TablesToUse, False);
		
		For Each Table In TablesToUse Do
			TableID = MetadataObjectIDs[Table];
			TableRow = Result.Add();
			TableRow.Report = SelectedReport;
			TableRow.MetadataObject = TableID;
		EndDo;
		
		If Not ValueIsFilled(Result) Then
			TableRow = Result.Add();
			TableRow.Report = SelectedReport;
			TableRow.MetadataObject = Undefined;
		EndIf;
		
		Return Result;
		
	EndIf;
	
	If ValueIsFilled(SelectedReport)
	   And DescriptionOfIDTypes.ContainsType(TypeOf(SelectedReport)) Then
		
		TheMetadataObjectOfTheSelectedReport =
			Common.MetadataObjectByID(SelectedReport, False);
	EndIf;
	
	ReportsTables = New ValueTable;
	ReportsTables.Columns.Add("Report");
	ReportsTables.Columns.Add("MetadataObject");
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		TablesOwners = New Map;
		For Each MetadataObjectReport In Metadata.Reports Do
			If TypeOf(TheMetadataObjectOfTheSelectedReport) = Type("MetadataObject")
			   And MetadataObjectReport <> TheMetadataObjectOfTheSelectedReport Then
				Continue;
			EndIf;
			If Not AccessRight("View", MetadataObjectReport) Then
				Continue;
			EndIf;
			TablesToUse = ModuleReportsOptions.UsedReportTables(MetadataObjectReport);
			
			For Each TableName In TablesToUse Do
				AssociatedTable = TablesOwners[TableName];
				If AssociatedTable = Undefined Then
					TableOwner = TableName;
					StringParts1 = StrSplit(TableOwner, ".", True);
					If StringParts1.Count() = 1 Then
						Continue;
					EndIf;
					If StringParts1.Count() > 2 Then
						TableOwner = StringParts1[0] + "." + StringParts1[1];
					EndIf;
					TablesOwners.Insert(TableName, TableOwner);
					AssociatedTable = TableOwner;
				EndIf;
				
				TableRow = ReportsTables.Add();
				TableRow.Report = MetadataObjectReport.FullName();
				TableRow.MetadataObject = AssociatedTable;
			EndDo;
		EndDo;
		ReportsTables.GroupBy("Report, MetadataObject");
	EndIf;
	
	MetadataObjectNames = ReportsTables.UnloadColumn("MetadataObject");
	ReportsWithTables = New Map;
	For Each MetadataObjectReport In Metadata.Reports Do
		If TypeOf(TheMetadataObjectOfTheSelectedReport) = Type("MetadataObject")
		   And MetadataObjectReport <> TheMetadataObjectOfTheSelectedReport Then
			Continue;
		EndIf;
		FullReportName = MetadataObjectReport.FullName();
		ReportsWithTables.Insert(FullReportName, False);
		MetadataObjectNames.Add(FullReportName);
	EndDo;
	
	MetadataObjectIDs =
		Common.MetadataObjectIDs(MetadataObjectNames, False);
	
	For Each TableRow In ReportsTables Do
		TableID = MetadataObjectIDs[TableRow.MetadataObject];
		If Not ValueIsFilled(TableID) Then
			Continue;
		EndIf;
		NewRow = Result.Add();
		NewRow.Report            = MetadataObjectIDs[TableRow.Report];
		NewRow.MetadataObject = TableID;
		ReportsWithTables.Insert(TableRow.Report, True);
	EndDo;
	
	For Each KeyAndValue In ReportsWithTables Do
		If KeyAndValue.Value Then
			Continue;
		EndIf;
		NewRow = Result.Add();
		NewRow.Report = MetadataObjectIDs[KeyAndValue.Key];
		NewRow.MetadataObject = Undefined;
	EndDo;
	
	Return Result;
	
EndFunction

Function DescriptionOfIDTypes()
	
	Return New TypeDescription("CatalogRef.MetadataObjectIDs,
		|CatalogRef.ExtensionObjectIDs");
	
EndFunction

Function BlankReportsTablesCollection()
	
	DescriptionOfIDTypes = DescriptionOfIDTypes();
	
	Result = New ValueTable;
	Result.Columns.Add("Report", DescriptionOfIDTypes);
	Result.Columns.Add("MetadataObject", DescriptionOfIDTypes);
	
	Return Result;
	
EndFunction

Function RolesRightsToReports()
	
	Result = EmptyCollectionOfRoleRightsToReports();
	DescriptionOfIDTypes = DescriptionOfIDTypes();
	
	SelectedReport = SelectedReport();
	
	If ValueIsFilled(SelectedReport)
	   And DescriptionOfIDTypes.ContainsType(TypeOf(SelectedReport)) Then
		
		TheMetadataObjectOfTheSelectedReport =
			Common.MetadataObjectByID(SelectedReport, False);
	EndIf;
	
	MetadataObjectNames = New Array;
	For Each MetadataObjectRole In Metadata.Roles Do
		MetadataObjectNames.Add(MetadataObjectRole.FullName());
	EndDo;
	For Each MetadataObjectReport In Metadata.Reports Do
		If TypeOf(TheMetadataObjectOfTheSelectedReport) = Type("MetadataObject")
		   And MetadataObjectReport <> TheMetadataObjectOfTheSelectedReport Then
			Continue;
		EndIf;
		MetadataObjectNames.Add(MetadataObjectReport.FullName());
	EndDo;
	
	MetadataObjectIDs =
		Common.MetadataObjectIDs(MetadataObjectNames, False);
	
	For Each MetadataObjectReport In Metadata.Reports Do
		If TypeOf(TheMetadataObjectOfTheSelectedReport) = Type("MetadataObject")
		   And MetadataObjectReport <> TheMetadataObjectOfTheSelectedReport Then
			Continue;
		EndIf;
		For Each MetadataObjectRole In Metadata.Roles Do
			If AccessRight("View", MetadataObjectReport, MetadataObjectRole) Then
				TableRow = Result.Add();
				TableRow.Report = MetadataObjectIDs[MetadataObjectReport.FullName()];
				TableRow.Role  = MetadataObjectIDs[MetadataObjectRole.FullName()];
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Function EmptyCollectionOfRoleRightsToReports()
	
	DescriptionOfIDTypes = DescriptionOfIDTypes();
	
	Result = New ValueTable;
	Result.Columns.Add("Report", DescriptionOfIDTypes);
	Result.Columns.Add("Role", DescriptionOfIDTypes);
	
	Return Result;
	
EndFunction

Function UsersRights()
	
	QueryTextShared =
	"SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.EditRight AS EditRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight,
	|	ExtensionsRolesRights.LineChangeType AS LineChangeType
	|INTO ExtensionsRolesRights
	|FROM
	|	&ExtensionsRolesRights AS ExtensionsRolesRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExtensionsRolesRights.MetadataObject AS MetadataObject,
	|	ExtensionsRolesRights.Role AS Role,
	|	ExtensionsRolesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ExtensionsRolesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ExtensionsRolesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ExtensionsRolesRights.ViewRight AS ViewRight,
	|	ExtensionsRolesRights.EditRight AS EditRight,
	|	ExtensionsRolesRights.InteractiveAddRight AS InteractiveAddRight
	|INTO RolesRights
	|FROM
	|	ExtensionsRolesRights AS ExtensionsRolesRights
	|WHERE
	|	ExtensionsRolesRights.LineChangeType = 1
	|
	|UNION ALL
	|
	|SELECT
	|	RolesRights.MetadataObject,
	|	RolesRights.Role,
	|	RolesRights.UnrestrictedReadRight,
	|	RolesRights.UnrestrictedUpdateRight,
	|	RolesRights.UnrestrictedAddRight,
	|	RolesRights.ViewRight,
	|	RolesRights.EditRight,
	|	RolesRights.InteractiveAddRight
	|FROM
	|	InformationRegister.RolesRights AS RolesRights
	|		LEFT JOIN ExtensionsRolesRights AS ExtensionsRolesRights
	|		ON RolesRights.MetadataObject = ExtensionsRolesRights.MetadataObject
	|			AND RolesRights.Role = ExtensionsRolesRights.Role
	|WHERE
	|	ExtensionsRolesRights.MetadataObject IS NULL
	|
	|INDEX BY
	|	Role
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupProfilesRoles.Ref AS Profile,
	|	RolesRights.MetadataObject AS Table,
	|	MAX(RolesRights.UnrestrictedReadRight) AS UnrestrictedReadRight,
	|	MAX(RolesRights.UnrestrictedUpdateRight) AS UnrestrictedUpdateRight,
	|	MAX(RolesRights.UnrestrictedAddRight) AS UnrestrictedAddRight,
	|	MAX(RolesRights.ViewRight) AS ViewRight,
	|	MAX(RolesRights.EditRight) AS EditRight,
	|	MAX(RolesRights.InteractiveAddRight) AS InteractiveAddRight
	|INTO RightsOfProfilesToTables
	|FROM
	|	RolesRights AS RolesRights
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON RolesRights.Role = AccessGroupProfilesRoles.Role
	|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)
	|WHERE
	|	&SelectingRightsByTables
	|
	|GROUP BY
	|	AccessGroupProfilesRoles.Ref,
	|	RolesRights.MetadataObject
	|
	|HAVING
	|	MAX(RolesRights.ViewRight) = TRUE
	|
	|INDEX BY
	|	Table";
	
	RequestTextWithoutGroupingByReports =
	"SELECT DISTINCT
	|	ProfilesRights.Table AS MetadataObject,
	|	CASE
	|		WHEN &SimplifiedAccessRightsSetupInterface
	|			THEN AccessGroups.Profile
	|		ELSE AccessGroups.Ref
	|	END AS AccessGroup,
	|	ProfilesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ProfilesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ProfilesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	CASE
	|		WHEN ProfilesRights.InteractiveAddRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedAddRight
	|						THEN 3
	|					ELSE 0
	|				END
	|		WHEN ProfilesRights.EditRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedUpdateRight
	|						THEN 2
	|					ELSE 0
	|				END
	|		WHEN ProfilesRights.ViewRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedReadRight
	|						THEN 1
	|					ELSE 0
	|				END
	|		ELSE 0
	|	END AS RightUnlimited,
	|	ProfilesRights.ViewRight AS ViewRight,
	|	ProfilesRights.EditRight AS EditRight,
	|	ProfilesRights.InteractiveAddRight AS InteractiveAddRight,
	|	CASE
	|		WHEN ProfilesRights.InteractiveAddRight
	|			THEN 3
	|		WHEN ProfilesRights.EditRight
	|			THEN 2
	|		WHEN ProfilesRights.ViewRight
	|			THEN 1
	|		ELSE 0
	|	END AS Right,
	|	UserGroupCompositions.User AS User,
	|	ISNULL(UsersInfo.CanSignIn, FALSE) AS CanSignIn
	|FROM
	|	RightsOfProfilesToTables AS ProfilesRights
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (AccessGroups.Profile = ProfilesRights.Profile)
	|			AND (NOT AccessGroups.DeletionMark)
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsMembers
	|		ON (AccessGroupsMembers.Ref = AccessGroups.Ref)
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = AccessGroupsMembers.User)
	|			AND (ISNULL(UserGroupCompositions.User.IsInternal, FALSE) <> TRUE)
	|			AND (&SelectionCriteriaForUsers)
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = UserGroupCompositions.User)";
	
	QueryTextWithoutGroupingByReportsWithAccessRestrictionsStart =
	"SELECT
	|	AccessGroups.Profile AS Profile,
	|	AccessGroups.Ref AS AccessGroup
	|INTO UserAccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsMembers
	|		ON (AccessGroupsMembers.Ref = AccessGroups.Ref)
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (AccessGroups.Profile IN
	|				(SELECT DISTINCT
	|					ProfilesRights.Profile
	|				FROM
	|					RightsOfProfilesToTables AS ProfilesRights))
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = AccessGroupsMembers.User)
	|			AND (ISNULL(UserGroupCompositions.User.IsInternal, FALSE) <> TRUE)
	|			AND (&SelectionCriteriaForUsers)";
	
	QueryTextWithoutGroupingByReportsWithAccessRestrictions =
	"SELECT
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation,
	|	AccessRestrictionKinds.Right AS Right
	|INTO TypesRestrictionsRightsInitial
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation AS AccessKindPresentation,
	|	MAX(AccessRestrictionKinds.Right = ""Read"") AS ReadRight,
	|	MAX(AccessRestrictionKinds.Right = ""Update"") AS RightUpdate
	|INTO RightsRestrictionTypesTransformed
	|FROM
	|	TypesRestrictionsRightsInitial AS AccessRestrictionKinds
	|
	|GROUP BY
	|	AccessRestrictionKinds.Table,
	|	AccessRestrictionKinds.AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FALSE AS ForExternalUsers,
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation AS AccessKindPresentation,
	|	AccessRestrictionKinds.ReadRight AS ReadRight,
	|	AccessRestrictionKinds.RightUpdate AS RightUpdate
	|INTO AccessRestrictionKinds
	|FROM
	|	RightsRestrictionTypesTransformed AS AccessRestrictionKinds
	|WHERE
	|	VALUETYPE(AccessRestrictionKinds.AccessKind) <> TYPE(Catalog.ExternalUsers)
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	AccessRestrictionKinds.Table,
	|	AccessRestrictionKinds.AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation,
	|	AccessRestrictionKinds.ReadRight,
	|	AccessRestrictionKinds.RightUpdate
	|FROM
	|	RightsRestrictionTypesTransformed AS AccessRestrictionKinds
	|WHERE
	|	VALUETYPE(AccessRestrictionKinds.AccessKind) <> TYPE(Catalog.Users)";
	
	QueryTextWithoutGroupingByReportsWithAccessRestrictionsRestrictionTypesNew =
	"SELECT
	|	AccessRestrictionKinds.ForExternalUsers AS ForExternalUsers,
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.Presentation AS AccessKindPresentation,
	|	AccessRestrictionKinds.Right AS Right
	|INTO TypesRestrictionsRightsInitial
	|FROM
	|	&AccessRestrictionKinds AS AccessRestrictionKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessRestrictionKinds.ForExternalUsers AS ForExternalUsers,
	|	AccessRestrictionKinds.Table AS Table,
	|	AccessRestrictionKinds.AccessKind AS AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation AS AccessKindPresentation,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|			THEN FALSE
	|		WHEN AccessRestrictionKinds.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|			THEN TRUE
	|		ELSE MAX(AccessRestrictionKinds.Right = ""Read"")
	|	END AS ReadRight,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|			THEN FALSE
	|		WHEN AccessRestrictionKinds.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessDenied)
	|			THEN TRUE
	|		ELSE MAX(AccessRestrictionKinds.Right = ""Update"")
	|	END AS RightUpdate
	|INTO AccessRestrictionKinds
	|FROM
	|	TypesRestrictionsRightsInitial AS AccessRestrictionKinds
	|
	|GROUP BY
	|	AccessRestrictionKinds.ForExternalUsers,
	|	AccessRestrictionKinds.Table,
	|	AccessRestrictionKinds.AccessKind,
	|	AccessRestrictionKinds.AccessKindPresentation";
	
	QueryTextWithoutGroupingByReportsWithAccessRestrictionsEnd =
	"SELECT DISTINCT
	|	AccessKindsAndValues.AccessGroup AS AccessGroup,
	|	AccessKindsAndValues.AccessKind AS AccessKind,
	|	AccessKindsAndValues.AllAllowed AS AllAllowed,
	|	AccessKindsAndValues.AccessValue AS AccessValue
	|INTO AccessKindsAndValues
	|FROM
	|	(SELECT
	|		UserAccessGroups.AccessGroup AS AccessGroup,
	|		AccessGroupsTypesOfAccess.AccessKind AS AccessKind,
	|		AccessGroupsTypesOfAccess.AllAllowed AS AllAllowed,
	|		ISNULL(AccessGroupsAccessValues.AccessValue, UNDEFINED) AS AccessValue
	|	FROM
	|		UserAccessGroups AS UserAccessGroups
	|			INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsTypesOfAccess
	|			ON (AccessGroupsTypesOfAccess.Ref = UserAccessGroups.AccessGroup)
	|			LEFT JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|			ON (AccessGroupsAccessValues.Ref = AccessGroupsTypesOfAccess.Ref)
	|				AND (AccessGroupsAccessValues.AccessKind = AccessGroupsTypesOfAccess.AccessKind)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		UserAccessGroups.AccessGroup,
	|		AccessGroupProfilesAccessTypes.AccessKind,
	|		AccessGroupProfilesAccessTypes.AllAllowed,
	|		ISNULL(AccessGroupProfilesAccessValues.AccessValue, UNDEFINED)
	|	FROM
	|		UserAccessGroups AS UserAccessGroups
	|			INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS AccessGroupProfilesAccessTypes
	|			ON (AccessGroupProfilesAccessTypes.Ref = UserAccessGroups.Profile)
	|			LEFT JOIN Catalog.AccessGroupProfiles.AccessValues AS AccessGroupProfilesAccessValues
	|			ON (AccessGroupProfilesAccessValues.Ref = AccessGroupProfilesAccessTypes.Ref)
	|				AND (AccessGroupProfilesAccessValues.AccessKind = AccessGroupProfilesAccessTypes.AccessKind)
	|	WHERE
	|		AccessGroupProfilesAccessTypes.Predefined) AS AccessKindsAndValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	EmptyAccessValueReferences.EmptyRef AS EmptyRef,
	|	EmptyAccessValueReferences.Presentation AS Presentation
	|INTO EmptyAccessValueReferences
	|FROM
	|	&EmptyAccessValueReferences AS EmptyAccessValueReferences
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ProfilesRights.Table AS MetadataObject,
	|	CASE
	|		WHEN &SimplifiedAccessRightsSetupInterface
	|			THEN AccessGroups.Profile
	|		ELSE AccessGroups.Ref
	|	END AS AccessGroup,
	|	ProfilesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ProfilesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ProfilesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	ProfilesRights.ViewRight AS ViewRight,
	|	ProfilesRights.EditRight AS EditRight,
	|	ProfilesRights.InteractiveAddRight AS InteractiveAddRight,
	|	CASE
	|		WHEN ProfilesRights.UnrestrictedReadRight
	|			THEN TRUE
	|		WHEN NOT ProfilesRights.ViewRight
	|			THEN FALSE
	|		WHEN NOT AccessRestrictionKinds.AccessKind IS NULL
	|			THEN NOT AccessRestrictionKinds.ReadRight
	|		WHEN NOT TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN NOT TypesRestrictionsPermissionsUnconditional.ReadRight
	|		ELSE FALSE
	|	END AS AccessTypeRightReadUnlimited,
	|	CASE
	|		WHEN ProfilesRights.UnrestrictedUpdateRight
	|			THEN TRUE
	|		WHEN NOT ProfilesRights.EditRight
	|			THEN FALSE
	|		WHEN NOT AccessRestrictionKinds.AccessKind IS NULL
	|			THEN NOT AccessRestrictionKinds.RightUpdate
	|		WHEN NOT TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN NOT TypesRestrictionsPermissionsUnconditional.RightUpdate
	|		ELSE FALSE
	|	END AS AccessTypeRightChangeWithoutRestriction,
	|	CASE
	|		WHEN ProfilesRights.UnrestrictedAddRight
	|			THEN TRUE
	|		WHEN NOT ProfilesRights.InteractiveAddRight
	|			THEN FALSE
	|		WHEN NOT AccessRestrictionKinds.AccessKind IS NULL
	|			THEN NOT AccessRestrictionKinds.RightUpdate
	|		WHEN NOT TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN NOT TypesRestrictionsPermissionsUnconditional.RightUpdate
	|		ELSE FALSE
	|	END AS AccessTypeRightAdditionWithoutRestriction,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind IS NULL
	|				AND TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN FALSE
	|		ELSE ProfilesRights.ViewRight
	|	END AS AccessTypeRightView,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind IS NULL
	|				AND TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN FALSE
	|		ELSE ProfilesRights.EditRight
	|	END AS AccessTypeRightEditing,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind IS NULL
	|				AND TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN FALSE
	|		ELSE ProfilesRights.InteractiveAddRight
	|	END AS AccessTypeRightInteractiveAdd,
	|	CASE
	|		WHEN NOT AccessRestrictionKinds.AccessKind IS NULL
	|			THEN AccessRestrictionKinds.AccessKind
	|		WHEN NOT TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|			THEN TypesRestrictionsPermissionsUnconditional.AccessKind
	|		ELSE UNDEFINED
	|	END AS AccessKind,
	|	CASE
	|		WHEN NOT AccessRestrictionKinds.AccessKind IS NULL
	|			THEN AccessRestrictionKinds.AccessKindPresentation + CASE
	|					WHEN AccessKindsAndValues.AllAllowed IS NULL
	|						THEN """"
	|					WHEN AccessKindsAndValues.AllAllowed = FALSE
	|						THEN CASE
	|								WHEN VALUETYPE(AccessRestrictionKinds.AccessKind) = TYPE(Catalog.Users)
	|										OR VALUETYPE(AccessRestrictionKinds.AccessKind) = TYPE(Catalog.ExternalUsers)
	|									THEN &TextAllowedUsers
	|								ELSE &TextAllowed
	|							END
	|					ELSE CASE
	|							WHEN VALUETYPE(AccessRestrictionKinds.AccessKind) = TYPE(Catalog.Users)
	|									OR VALUETYPE(AccessRestrictionKinds.AccessKind) = TYPE(Catalog.ExternalUsers)
	|								THEN &TextForbiddenUsers
	|							ELSE &TextForbidden
	|						END
	|				END
	|		ELSE CASE
	|				WHEN ProfilesRights.ViewRight
	|							AND NOT ProfilesRights.UnrestrictedReadRight
	|						OR ProfilesRights.EditRight
	|							AND NOT ProfilesRights.UnrestrictedUpdateRight
	|						OR ProfilesRights.InteractiveAddRight
	|							AND NOT ProfilesRights.UnrestrictedAddRight
	|					THEN CASE
	|							WHEN NOT TypesRestrictionsPermissionsUnconditional.AccessKind IS NULL
	|								THEN TypesRestrictionsPermissionsUnconditional.AccessKindPresentation
	|							ELSE &TextRestrictionWithoutAccessTypes
	|						END
	|				ELSE &TextUnlimited
	|			END
	|	END AS AccessKindPresentation,
	|	ISNULL(AccessKindsAndValues.AllAllowed, FALSE) AS AllAllowed,
	|	CASE
	|		WHEN AccessRestrictionKinds.AccessKind IS NULL
	|			THEN """"
	|		WHEN NOT EmptyAccessValueReferences.Presentation IS NULL
	|			THEN EmptyAccessValueReferences.Presentation
	|		WHEN AccessKindsAndValues.AccessValue IS NULL
	|				OR AccessKindsAndValues.AccessValue = UNDEFINED
	|			THEN CASE
	|					WHEN AccessKindsAndValues.AllAllowed
	|						THEN &TextAllAllowed
	|					ELSE &TextAllForbidden
	|				END
	|		ELSE AccessKindsAndValues.AccessValue
	|	END AS AccessValue,
	|	UserGroupCompositions.User AS User,
	|	ISNULL(UsersInfo.CanSignIn, FALSE) AS CanSignIn
	|FROM
	|	RightsOfProfilesToTables AS ProfilesRights
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (AccessGroups.Profile = ProfilesRights.Profile)
	|			AND (NOT AccessGroups.DeletionMark)
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsMembers
	|		ON (AccessGroupsMembers.Ref = AccessGroups.Ref)
	|		LEFT JOIN AccessRestrictionKinds AS AccessRestrictionKinds
	|			INNER JOIN AccessKindsAndValues AS AccessKindsAndValues
	|			ON (AccessKindsAndValues.AccessKind = AccessRestrictionKinds.AccessKind)
	|				AND (AccessRestrictionKinds.AccessKind <> VALUE(Enum.AdditionalAccessValues.AccessAllowed))
	|				AND (AccessRestrictionKinds.AccessKind <> VALUE(Enum.AdditionalAccessValues.AccessDenied))
	|		ON (AccessRestrictionKinds.Table = ProfilesRights.Table)
	|			AND (AccessKindsAndValues.AccessGroup = AccessGroups.Ref)
	|			AND (NOT AccessRestrictionKinds.ForExternalUsers
	|					AND (VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.Users)
	|						OR VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.UserGroups))
	|				OR AccessRestrictionKinds.ForExternalUsers
	|					AND (VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.ExternalUsers)
	|						OR VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.ExternalUsersGroups)))
	|			AND (ProfilesRights.ViewRight
	|					AND NOT ProfilesRights.UnrestrictedReadRight
	|					AND AccessRestrictionKinds.ReadRight
	|				OR ProfilesRights.EditRight
	|					AND NOT ProfilesRights.UnrestrictedUpdateRight
	|					AND AccessRestrictionKinds.RightUpdate
	|				OR ProfilesRights.InteractiveAddRight
	|					AND NOT ProfilesRights.UnrestrictedAddRight
	|					AND AccessRestrictionKinds.RightUpdate)
	|		LEFT JOIN AccessRestrictionKinds AS TypesRestrictionsPermissionsUnconditional
	|		ON (TypesRestrictionsPermissionsUnconditional.Table = ProfilesRights.Table)
	|			AND (TypesRestrictionsPermissionsUnconditional.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessAllowed)
	|				OR TypesRestrictionsPermissionsUnconditional.AccessKind = VALUE(Enum.AdditionalAccessValues.AccessDenied))
	|			AND (NOT TypesRestrictionsPermissionsUnconditional.ForExternalUsers
	|					AND (VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.Users)
	|						OR VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.UserGroups))
	|				OR TypesRestrictionsPermissionsUnconditional.ForExternalUsers
	|					AND (VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.ExternalUsers)
	|						OR VALUETYPE(AccessGroupsMembers.User) = TYPE(Catalog.ExternalUsersGroups)))
	|		LEFT JOIN EmptyAccessValueReferences AS EmptyAccessValueReferences
	|		ON (EmptyAccessValueReferences.EmptyRef = AccessKindsAndValues.AccessValue)
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = AccessGroupsMembers.User)
	|			AND (ISNULL(UserGroupCompositions.User.IsInternal, FALSE) <> TRUE)
	|			AND (&SelectionCriteriaForUsers)
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = UserGroupCompositions.User)";
	
	RequestTextWithGroupingByReportsSupplement =
	"SELECT
	|	RolesRightsToReports.Report AS Report,
	|	RolesRightsToReports.Role AS Role
	|INTO RolesRightsToReports
	|FROM
	|	&RolesRightsToReports AS RolesRightsToReports
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccessGroupProfilesRoles.Ref AS Profile,
	|	RolesRightsToReports.Report AS Report
	|INTO RightsOfProfilesToReports
	|FROM
	|	RolesRightsToReports AS RolesRightsToReports
	|		INNER JOIN Catalog.AccessGroupProfiles.Roles AS AccessGroupProfilesRoles
	|		ON RolesRightsToReports.Role = AccessGroupProfilesRoles.Role
	|			AND (NOT AccessGroupProfilesRoles.Ref.DeletionMark)
	|
	|INDEX BY
	|	Report
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsTables.Report AS Report,
	|	ReportsTables.MetadataObject AS Table
	|INTO ReportsTables
	|FROM
	|	&ReportsTables AS ReportsTables
	|WHERE
	|	&SelectingReportsByTables
	|
	|INDEX BY
	|	Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportTablesWithPermissions.Report AS Report,
	|	ReportTablesWithPermissions.Table AS Table,
	|	ReportTablesWithPermissions.Profile AS Profile,
	|	MAX(ReportTablesWithPermissions.ReportRight) AS ReportRight,
	|	MAX(ReportTablesWithPermissions.UnrestrictedReadRight) AS UnrestrictedReadRight,
	|	MAX(ReportTablesWithPermissions.UnrestrictedUpdateRight) AS UnrestrictedUpdateRight,
	|	MAX(ReportTablesWithPermissions.UnrestrictedAddRight) AS UnrestrictedAddRight,
	|	MAX(ReportTablesWithPermissions.ViewRight) AS ViewRight,
	|	MAX(ReportTablesWithPermissions.EditRight) AS EditRight,
	|	MAX(ReportTablesWithPermissions.InteractiveAddRight) AS InteractiveAddRight
	|INTO ProfilesRights
	|FROM
	|	(SELECT
	|		ReportsTables.Report AS Report,
	|		ReportsTables.Table AS Table,
	|		RightsOfProfilesToReports.Profile AS Profile,
	|		TRUE AS ReportRight,
	|		FALSE AS UnrestrictedReadRight,
	|		FALSE AS UnrestrictedUpdateRight,
	|		FALSE AS UnrestrictedAddRight,
	|		FALSE AS ViewRight,
	|		FALSE AS EditRight,
	|		FALSE AS InteractiveAddRight
	|	FROM
	|		ReportsTables AS ReportsTables
	|			INNER JOIN RightsOfProfilesToReports AS RightsOfProfilesToReports
	|			ON (RightsOfProfilesToReports.Report = ReportsTables.Report)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReportsTables.Report,
	|		ReportsTables.Table,
	|		RightsOfProfilesToTables.Profile,
	|		FALSE,
	|		RightsOfProfilesToTables.UnrestrictedReadRight,
	|		RightsOfProfilesToTables.UnrestrictedUpdateRight,
	|		RightsOfProfilesToTables.UnrestrictedAddRight,
	|		RightsOfProfilesToTables.ViewRight,
	|		RightsOfProfilesToTables.EditRight,
	|		RightsOfProfilesToTables.InteractiveAddRight
	|	FROM
	|		ReportsTables AS ReportsTables
	|			INNER JOIN RightsOfProfilesToTables AS RightsOfProfilesToTables
	|			ON (RightsOfProfilesToTables.Table = ReportsTables.Table)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReportsTables.Report,
	|		ReportsTables.Table,
	|		VALUE(Catalog.AccessGroupProfiles.EmptyRef),
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE,
	|		FALSE
	|	FROM
	|		ReportsTables AS ReportsTables
	|	WHERE
	|		NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						RightsOfProfilesToReports AS RightsOfProfilesToReports
	|					WHERE
	|						RightsOfProfilesToReports.Report = ReportsTables.Report)
	|		AND NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						RightsOfProfilesToTables AS RightsOfProfilesToTables
	|					WHERE
	|						RightsOfProfilesToTables.Table = ReportsTables.Table)) AS ReportTablesWithPermissions
	|
	|GROUP BY
	|	ReportTablesWithPermissions.Report,
	|	ReportTablesWithPermissions.Table,
	|	ReportTablesWithPermissions.Profile";
	
	RequestTextWithGroupingByReports =
	"SELECT DISTINCT
	|	ProfilesRights.Report AS Report,
	|	CASE
	|		WHEN ProfilesRights.ReportRight
	|			THEN 1
	|		ELSE 0
	|	END AS ReportRight,
	|	ProfilesRights.Table AS MetadataObject,
	|	CASE
	|		WHEN &SimplifiedAccessRightsSetupInterface
	|			THEN AccessGroups.Profile
	|		ELSE AccessGroups.Ref
	|	END AS AccessGroup,
	|	ProfilesRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	ProfilesRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	ProfilesRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	CASE
	|		WHEN ProfilesRights.InteractiveAddRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedAddRight
	|						THEN 3
	|					ELSE 0
	|				END
	|		WHEN ProfilesRights.EditRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedUpdateRight
	|						THEN 2
	|					ELSE 0
	|				END
	|		WHEN ProfilesRights.ViewRight
	|			THEN CASE
	|					WHEN ProfilesRights.UnrestrictedReadRight
	|						THEN 1
	|					ELSE 0
	|				END
	|		ELSE 0
	|	END AS RightUnlimited,
	|	ProfilesRights.ViewRight AS ViewRight,
	|	ProfilesRights.EditRight AS EditRight,
	|	ProfilesRights.InteractiveAddRight AS InteractiveAddRight,
	|	CASE
	|		WHEN ProfilesRights.InteractiveAddRight
	|			THEN 3
	|		WHEN ProfilesRights.EditRight
	|			THEN 2
	|		WHEN ProfilesRights.ViewRight
	|			THEN 1
	|		ELSE 0
	|	END AS Right,
	|	UserGroupCompositions.User AS User,
	|	ISNULL(UsersInfo.CanSignIn, FALSE) AS CanSignIn
	|INTO UsersRights
	|FROM
	|	ProfilesRights AS ProfilesRights
	|		INNER JOIN Catalog.AccessGroups AS AccessGroups
	|		ON (AccessGroups.Profile = ProfilesRights.Profile)
	|			AND (NOT AccessGroups.DeletionMark)
	|		INNER JOIN Catalog.AccessGroups.Users AS AccessGroupsMembers
	|		ON (AccessGroupsMembers.Ref = AccessGroups.Ref)
	|		INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|		ON (UserGroupCompositions.UsersGroup = AccessGroupsMembers.User)
	|			AND (ISNULL(UserGroupCompositions.User.IsInternal, FALSE) <> TRUE)
	|			AND (&SelectionCriteriaForUsers)
	|		LEFT JOIN InformationRegister.UsersInfo AS UsersInfo
	|		ON (UsersInfo.User = UserGroupCompositions.User)";
	
	TheTextOfTheRequestWithGroupingByReportsIsFinal =
	"SELECT DISTINCT
	|	UsersRights.User AS User,
	|	UsersRights.CanSignIn AS CanSignIn
	|INTO UsersWithRights
	|FROM
	|	UsersRights AS UsersRights
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UsersRights.Report AS Report,
	|	UsersRights.ReportRight AS ReportRight,
	|	UsersRights.MetadataObject AS MetadataObject,
	|	UsersRights.AccessGroup AS AccessGroup,
	|	UsersRights.UnrestrictedReadRight AS UnrestrictedReadRight,
	|	UsersRights.UnrestrictedUpdateRight AS UnrestrictedUpdateRight,
	|	UsersRights.UnrestrictedAddRight AS UnrestrictedAddRight,
	|	UsersRights.RightUnlimited AS RightUnlimited,
	|	UsersRights.ViewRight AS ViewRight,
	|	UsersRights.EditRight AS EditRight,
	|	UsersRights.InteractiveAddRight AS InteractiveAddRight,
	|	UsersRights.Right AS Right,
	|	UsersRights.User AS User,
	|	UsersRights.CanSignIn AS CanSignIn
	|FROM
	|	UsersRights AS UsersRights
	|
	|UNION ALL
	|
	|SELECT
	|	ReportsTables.Report,
	|	0,
	|	ReportsTables.Table,
	|	CASE
	|		WHEN &SimplifiedAccessRightsSetupInterface
	|			THEN VALUE(Catalog.AccessGroupProfiles.EmptyRef)
	|		ELSE VALUE(Catalog.AccessGroups.EmptyRef)
	|	END,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	FALSE,
	|	0,
	|	UsersWithRights.User,
	|	UsersWithRights.CanSignIn
	|FROM
	|	ReportsTables AS ReportsTables
	|		INNER JOIN UsersWithRights AS UsersWithRights
	|		ON (NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						UsersRights AS UsersRights
	|					WHERE
	|						UsersRights.Report = ReportsTables.Report
	|						AND UsersRights.MetadataObject = ReportsTables.Table
	|						AND UsersRights.User = UsersWithRights.User))";
	
	Query = New Query;
	
	SelectionCriteriaForUsers = "";
	FilterConditionByCanSignIn = "";
	If SelectionByEnteringTheProgramIsAllowed() Then
		QueryTextWithoutGroupingByReportsWithAccessRestrictionsStart =
			QueryTextWithoutGroupingByReportsWithAccessRestrictionsStart + "
			|		INNER JOIN InformationRegister.UsersInfo AS UsersInfo
			|		ON (UsersInfo.User = UserGroupCompositions.User)
			|			AND (UsersInfo.CanSignIn)";
		FilterConditionByCanSignIn = "
		|			AND (UsersInfo.CanSignIn)";
	EndIf;
	
	SelectionByUserType = SelectionByUserType();
	FilterForSpecifiedUsers     = FilterForSpecifiedUsers();
	If ValueIsFilled(FilterForSpecifiedUsers.Value) And FilterForSpecifiedUsers.WithoutGroups Then
		Query.SetParameter("SelectedUsersWithoutGroups", FilterForSpecifiedUsers.Value);
		SelectionCriteriaForUsers = SelectionCriteriaForUsers + "
			|			AND (UserGroupCompositions.User IN (&SelectedUsersWithoutGroups))";
		
	ElsIf ValueIsFilled(FilterForSpecifiedUsers.Value) Then
		Query.SetParameter("SelectedUsersAndGroups", FilterForSpecifiedUsers.Value);
		SelectionCriteriaForUsers = SelectionCriteriaForUsers + "
			|		INNER JOIN InformationRegister.UserGroupCompositions AS FilterUsers
			|		ON (FilterUsers.User = UserGroupCompositions.User)
			|			AND (FilterUsers.UsersGroup IN (&SelectedUsersAndGroups))";
		
	ElsIf SelectionByUserType = "Users" Then
		SelectionCriteriaForUsers = SelectionCriteriaForUsers + "
			|			AND (VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.Users))";
		
	ElsIf SelectionByUserType = "ExternalUsers" Then
		SelectionCriteriaForUsers = SelectionCriteriaForUsers + "
			|			AND (VALUETYPE(UserGroupCompositions.User) = TYPE(Catalog.ExternalUsers))";
	EndIf;
	SelectionCriteriaForUsers = Mid(SelectionCriteriaForUsers, 4);
	
	GroupByReportsEnabled = GroupByReportsEnabled();
	VariantWithRestrictedAccess = VariantWithRestrictedAccess();
	
	If GroupByReportsEnabled Then
		QueryTextMain = RequestTextWithGroupingByReports;
		Query.Text = QueryTextShared + Common.QueryBatchSeparator()
			+ RequestTextWithGroupingByReportsSupplement;
		Query.SetParameter("RolesRightsToReports", RolesRightsToReports());
		Query.SetParameter("ReportsTables",     ReportsTables());
		
	ElsIf VariantWithRestrictedAccess Then
		UniversalRestriction =
			AccessManagementInternal.LimitAccessAtRecordLevelUniversally(True, True);
		If UniversalRestriction Then
			QueryTextWithoutGroupingByReportsWithAccessRestrictionsRestrictionTypes
				= QueryTextWithoutGroupingByReportsWithAccessRestrictionsRestrictionTypesNew;
			Query.SetParameter("AccessRestrictionKinds",
				Reports.AccessRightsAnalysis.AccessRestrictionKinds(, True));
		Else
			QueryTextWithoutGroupingByReportsWithAccessRestrictionsRestrictionTypes
				= QueryTextWithoutGroupingByReportsWithAccessRestrictions;
			Query.SetParameter("AccessRestrictionKinds",
				Reports.AccessRightsAnalysis.AccessRestrictionKinds());
		EndIf;
		QueryTextMain = QueryTextWithoutGroupingByReportsWithAccessRestrictionsStart
			+ Common.QueryBatchSeparator()
			+ QueryTextWithoutGroupingByReportsWithAccessRestrictionsRestrictionTypes
			+ Common.QueryBatchSeparator()
			+ QueryTextWithoutGroupingByReportsWithAccessRestrictionsEnd;
		Query.Text = QueryTextShared;
		Query.SetParameter("TextAllowed", " (" + NStr("en = 'Allowed';")+ ")");
		Query.SetParameter("TextForbidden", " (" + NStr("en = 'Denied';") + ")");
		Query.SetParameter("TextAllowedUsers", " (" + NStr("en = 'Allowed';") + ") - "
			+ NStr("en = 'Authorized user and their groups are always allowed';"));
		Query.SetParameter("TextForbiddenUsers", " (" + NStr("en = 'Denied';") + ") - "
			+ NStr("en = 'Authorized user and their groups are always allowed';"));
		Query.SetParameter("TextRestrictionWithoutAccessTypes", "<" + NStr("en = 'Restriction without access kinds';")+ ">");
		Query.SetParameter("TextUnlimited", "<" + NStr("en = 'No restriction';") + ">");
		Query.SetParameter("TextAllAllowed", "<" + NStr("en = 'All allowed';") + ">");
		Query.SetParameter("TextAllForbidden", "<" + NStr("en = 'All denied';") + ">");
		Query.SetParameter("EmptyAccessValueReferences",
			AccessManagementInternal.EmptyAccessValueReferences());
	Else
		QueryTextMain = RequestTextWithoutGroupingByReports;
		Query.Text = QueryTextShared;
	EndIf;
	
	SimplifiedInterface = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	If Not SimplifiedInterface Then
		QueryTextMain = StrReplace(QueryTextMain,
			"SELECT DISTINCT", "SELECT"); // @query-part-1 @query-part-2
	EndIf;
	Query.Text = Query.Text + Common.QueryBatchSeparator()
		+ QueryTextMain;
	
	Query.SetParameter("SimplifiedAccessRightsSetupInterface", SimplifiedInterface);
	Query.SetParameter("ExtensionsRolesRights", AccessManagementInternal.ExtensionsRolesRights());
	
	FilterByTables = FilterByTables();
	If ValueIsFilled(FilterByTables) Then
		Query.SetParameter("SelectedTables", FilterByTables);
		Query.Text = StrReplace(Query.Text, "&SelectingRightsByTables",
			"RolesRights.MetadataObject IN (&SelectedTables)");
		Query.Text = StrReplace(Query.Text, "&SelectingReportsByTables",
			"ReportsTables.MetadataObject IN (&SelectedTables)");
	Else
		Query.Text = StrReplace(Query.Text, "&SelectingRightsByTables", "TRUE");
		Query.Text = StrReplace(Query.Text, "&SelectingReportsByTables", "TRUE");
	EndIf;
	
	Query.Text = StrReplace(Query.Text,
		"AND (&SelectionCriteriaForUsers)", SelectionCriteriaForUsers);
	
	If ValueIsFilled(FilterConditionByCanSignIn) Then
		Query.Text = Query.Text + FilterConditionByCanSignIn;
		Query.Text = StrReplace(Query.Text,
			"LEFT JOIN InformationRegister.UsersInfo AS UsersInfo",
			"INNER JOIN InformationRegister.UsersInfo AS UsersInfo");
	EndIf;
	
	If GroupByReportsEnabled Then
		Query.Text = Query.Text + "
		|
		|INDEX BY
		|	Report,
		|	MetadataObject,
		|	User";
		Query.Text = Query.Text + Common.QueryBatchSeparator()
			+ TheTextOfTheRequestWithGroupingByReportsIsFinal;
	EndIf;
	
	Result = Query.Execute().Unload();
	
	Return Result;
	
EndFunction

Function GroupByReportsEnabled()
	
	FieldList = New Array;
	FillGroupsFieldsList(SettingsComposer.GetSettings().Structure, FieldList);
	
	Return FieldList.Find(New DataCompositionField("Report")) <> Undefined;
	
EndFunction

Function VariantWithRestrictedAccess()
	
	Variant = SettingsComposer.Settings.AdditionalProperties.PredefinedOptionKey;
	
	Return Variant = "UserRightsToTable";
	
EndFunction

// Returns:
//  Structure:
//    * HasHierarchy - Boolean
//    * RightsDetails - FixedArray of See InformationRegisters.ObjectsRightsSettings.AvailableRightProperties
//    * RefType    - Type
//    * EmptyRef - AnyRef
//
Function SettingsRightsByTableInselection()
	
	Table = FilterByTables();
	If Not ValueIsFilled(Table)
	 Or Not DescriptionOfIDTypes().ContainsType(TypeOf(Table)) Then
		Return Undefined;
	EndIf;
	
	MetadataTables = Common.MetadataObjectByID(Table, False);
	If MetadataTables = Undefined
	 Or Not Common.IsRefTypeObject(MetadataTables) Then
		Return Undefined;
	EndIf;
	
	ObjectManager = Common.ObjectManagerByFullName(MetadataTables.FullName());
	EmptyRef = ObjectManager.EmptyRef();
	RefType = TypeOf(EmptyRef);
	AvailableRights = AccessManagementInternal.RightsForObjectsRightsSettingsAvailable();
	
	RightsDetails = AvailableRights.ByRefsTypes.Get(RefType);
	If RightsDetails = Undefined Then
		Return Undefined;
	EndIf;
	
	Properties = New Structure("Hierarchical", False);
	FillPropertyValues(Properties, MetadataTables);
	
	Result = New Structure;
	Result.Insert("HasHierarchy", Properties.Hierarchical);
	Result.Insert("RightsDetails", RightsDetails);
	Result.Insert("RefType",    RefType);
	Result.Insert("EmptyRef", EmptyRef);
	
	Return Result;
	
EndFunction

// Parameters:
//  ItemsCollection - DataCompositionSettingStructureItemCollection
//  FieldList - Array
//
Procedure FillGroupsFieldsList(ItemsCollection, FieldList)
	
	For Each Item In ItemsCollection Do
		If (TypeOf(Item) = Type("DataCompositionGroup")
			Or TypeOf(Item) = Type("DataCompositionTableGroup"))
			And Item.Use Then
			For Each Field In Item.GroupFields.Items Do
				If TypeOf(Field) = Type("DataCompositionGroupField") Then
					If Field.Use Then
						FieldList.Add(Field.Field);
					EndIf;
				EndIf;
			EndDo;
			FillGroupsFieldsList(Item.Structure, FieldList);
		ElsIf TypeOf(Item) = Type("DataCompositionTable") And Item.Use Then
			FillGroupsFieldsList(Item.Rows, FieldList);
			FillGroupsFieldsList(Item.Columns, FieldList);
		EndIf;
	EndDo;
	
EndProcedure

Function SelectedReport()
	
	SelectedReports = New Array;
	Filter = SettingsComposer.GetSettings().Filter;
	For Each Item In Filter.Items Do 
		If Item.Use And Item.LeftValue = New DataCompositionField("Report") Then
			If Item.ComparisonType = DataCompositionComparisonType.Equal Then
				SelectedReports.Add(Item.RightValue);
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	If SelectedReports.Count() = 1 Then
		Return SelectedReports[0];
	EndIf;
	
	Return Undefined;
	
EndFunction

Function SelectionByUserType()
	
	If Not Constants.UseExternalUsers.Get() Then
		Return "Users";
	EndIf;
	
	FilterField = SettingsComposer.GetSettings().DataParameters.Items.Find("UsersKind");
	If Not FilterField.Use Then
		Return "";
	EndIf;
	
	If FilterField.Value = 0 Then
		Return "Users";
	EndIf;
	
	If FilterField.Value = 1 Then
		Return "ExternalUsers";
	EndIf;
	
	Return "";
	
EndFunction

Function FilterForSpecifiedUsers()
	
	Result = New Structure;
	Result.Insert("WithoutGroups", True);
	Result.Insert("Value", Undefined);
	
	If Not Users.IsFullUser(,, False) Then
		Result.Value = Users.AuthorizedUser();
		Return Result;
	EndIf;
	
	FilterField = SettingsComposer.GetSettings().DataParameters.Items.Find("User");
	FilterValue = FilterField.Value;
	If Not FilterField.Use Or Not ValueIsFilled(FilterValue) Then
		Return Result;
	EndIf;
	Result.Value = FilterValue;
	
	If TypeOf(FilterValue) <> Type("ValueList") Then
		FilterValue = New ValueList;
		FilterValue.Add(Result.Value);
	EndIf;
	
	For Each ListItem In FilterValue Do
		If TypeOf(ListItem.Value) = Type("CatalogRef.UserGroups")
		 Or TypeOf(ListItem.Value) = Type("CatalogRef.ExternalUsersGroups") Then
			Result.WithoutGroups = False;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function FilterByTables()
	
	Filter = SettingsComposer.GetSettings().Filter;
	For Each Item In Filter.Items Do 
		If Item.Use And Item.LeftValue = New DataCompositionField("MetadataObject") Then
			If Item.ComparisonType = DataCompositionComparisonType.Equal
			 Or Item.ComparisonType = DataCompositionComparisonType.InList Then
				Return Item.RightValue;
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function SelectionByEnteringTheProgramIsAllowed()
	
	Filter = SettingsComposer.GetSettings().Filter;
	
	For Each Item In Filter.Items Do 
		If Item.Use
		   And Item.LeftValue = New DataCompositionField("CanSignIn")
		   And Item.ComparisonType = DataCompositionComparisonType.Equal
		   And Item.RightValue = True Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

Function RightsSettingsOnObjects()
	
	Result = New Structure;
	Result.Insert("RightsSettingsOnObjects", New ValueTable);
	Result.Insert("SettingsRightsHierarchy",   New ValueTable);
	Result.Insert("SettingsRightsLegend",    New ValueTable);
	Result.Insert("OwnerSettingsHeader", "");
	
	If Not VariantWithRestrictedAccess() Then
		Return Result;
	EndIf;
	
	RightsSettings = SettingsRightsByTableInselection();
	If RightsSettings = Undefined Then
		Return Result;
	EndIf;
	Result.OwnerSettingsHeader = String(RightsSettings.RefType);
	
	UserDetails = FilterForSpecifiedUsers().Value;
	If TypeOf(UserDetails) = Type("ValueList") Then
		If UserDetails.Count() <> 1 Then
			Return Result;
		EndIf;
		User = UserDetails[0].Value;
	Else
		User = UserDetails;
	EndIf;
	If TypeOf(User) <> Type("CatalogRef.Users")
	   And TypeOf(User) <> Type("CatalogRef.ExternalUsers") Then
		Return Result;
	EndIf;
	
	If Users.IsFullUser(User,, False) Then
		Return Result;
	EndIf;
	
	SubfolderName = DescriptionColumnsForSubfolders().Name;
	TitlesRight = TitlesRight(RightsSettings, SubfolderName);
	
	Query = New Query;
	Query.SetParameter("ObjectType",    RightsSettings.RefType);
	Query.SetParameter("User",   User);
	Query.SetParameter("SubfolderName", SubfolderName);
	Query.SetParameter("HasHierarchy",   RightsSettings.HasHierarchy);
	Query.SetParameter("EmptyParent", RightsSettings.EmptyRef);
	Query.SetParameter("TitlesRight",  TitlesRight);
	Query.SetParameter("ViewPersonal",  NStr("en = 'Personal';"));
	Query.SetParameter("ViewUndefined", NStr("en = 'Undefined';"));
	Query.SetParameter("ViewUserGroup",
		" (" + NStr("en = 'User group';") + ")");
	Query.SetParameter("ExternalUserGroupView",
		" (" + NStr("en = 'External user group';") + ")");
	
	Query.Text =
	"SELECT
	|	RightsSettings.Object AS SettingsOwner,
	|	RightsSettings.User AS User_Settings,
	|	RightsSettings.Right AS CustomizedRight,
	|	CASE
	|		WHEN RightsSettings.RightIsProhibited
	|			THEN 2
	|		ELSE 1
	|	END AS RightsValue
	|INTO RightsSettingsByOwners
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|WHERE
	|	TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			WHERE
	|				UserGroupCompositions.UsersGroup = RightsSettings.User
	|				AND UserGroupCompositions.User = &User)
	|	AND VALUETYPE(RightsSettings.Object) = &ObjectType
	|
	|UNION ALL
	|
	|SELECT
	|	RightsSettings.Object,
	|	RightsSettings.User,
	|	&SubfolderName,
	|	CASE
	|		WHEN MAX(RightsSettings.InheritanceIsAllowed) = FALSE
	|			THEN 2
	|		ELSE 1
	|	END
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsSettings
	|WHERE
	|	&HasHierarchy
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			WHERE
	|				UserGroupCompositions.UsersGroup = RightsSettings.User
	|				AND UserGroupCompositions.User = &User)
	|	AND VALUETYPE(RightsSettings.Object) = &ObjectType
	|
	|GROUP BY
	|	RightsSettings.Object,
	|	RightsSettings.User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalculatedPermissions.SettingsOwner AS SettingsOwner,
	|	CalculatedPermissions.CustomizedRight AS CustomizedRight,
	|	MAX(CalculatedPermissions.RightsValue) AS RightsValue
	|INTO CalculatedPermissionsByOwners
	|FROM
	|	(SELECT DISTINCT
	|		SettingsInheritance.Object AS SettingsOwner,
	|		RightsSettings.Right AS CustomizedRight,
	|		1 AS RightsValue
	|	FROM
	|		InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|			INNER JOIN InformationRegister.ObjectsRightsSettings AS RightsSettings
	|			ON (VALUETYPE(SettingsInheritance.Object) = &ObjectType)
	|				AND (RightsSettings.Object = SettingsInheritance.Parent)
	|				AND SettingsInheritance.UsageLevel < RightsSettings.RightPermissionLevel
	|			INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			ON (UserGroupCompositions.User = &User)
	|				AND (UserGroupCompositions.UsersGroup = RightsSettings.User)
	|	
	|	UNION ALL
	|	
	|	SELECT DISTINCT
	|		SettingsInheritance.Object,
	|		RightsSettings.Right,
	|		2
	|	FROM
	|		InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|			INNER JOIN InformationRegister.ObjectsRightsSettings AS RightsSettings
	|			ON (VALUETYPE(SettingsInheritance.Object) = &ObjectType)
	|				AND (RightsSettings.Object = SettingsInheritance.Parent)
	|				AND SettingsInheritance.UsageLevel < RightsSettings.RightProhibitionLevel
	|			INNER JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			ON (UserGroupCompositions.User = &User)
	|				AND (UserGroupCompositions.UsersGroup = RightsSettings.User)) AS CalculatedPermissions
	|
	|GROUP BY
	|	CalculatedPermissions.SettingsOwner,
	|	CalculatedPermissions.CustomizedRight
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SettingsInheritance.Object AS SettingsOwner,
	|	SettingsInheritance.Inherit AS SettingsInheritance
	|INTO InheritanceSettingsByOwners
	|FROM
	|	InformationRegister.ObjectRightsSettingsInheritance AS SettingsInheritance
	|WHERE
	|	SettingsInheritance.Object = SettingsInheritance.Parent
	|	AND VALUETYPE(SettingsInheritance.Object) = &ObjectType
	|	AND TRUE IN
	|			(SELECT TOP 1
	|				TRUE
	|			FROM
	|				CalculatedPermissionsByOwners AS CalculatedPermissionsByOwners
	|					INNER JOIN InformationRegister.ObjectRightsSettingsInheritance AS Parents
	|					ON
	|						Parents.Object = CalculatedPermissionsByOwners.SettingsOwner
	|							AND Parents.Parent = SettingsInheritance.Object)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TitlesRight.NameOfRight AS NameOfRight,
	|	TitlesRight.TitlePermissions AS TitlePermissions,
	|	TitlesRight.RightIndex AS RightIndex
	|INTO TitlesRight
	|FROM
	|	&TitlesRight AS TitlesRight
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CalculatedPermissionsByOwners.SettingsOwner AS SettingsOwner,
	|	ISNULL(InheritanceSettingsByOwners.SettingsInheritance, FALSE) AS SettingsInheritance
	|INTO OneOwnerSettings
	|FROM
	|	CalculatedPermissionsByOwners AS CalculatedPermissionsByOwners
	|		LEFT JOIN InheritanceSettingsByOwners AS InheritanceSettingsByOwners
	|		ON (InheritanceSettingsByOwners.SettingsOwner = CalculatedPermissionsByOwners.SettingsOwner)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN InheritanceSettingsByOwners.SettingsOwner.Parent <> &EmptyParent
	|			THEN InheritanceSettingsByOwners.SettingsOwner.Parent
	|		ELSE UNDEFINED
	|	END AS ParentOwnerOrUserSettings,
	|	InheritanceSettingsByOwners.SettingsOwner AS OwnerOrUserSettings,
	|	PRESENTATION(InheritanceSettingsByOwners.SettingsOwner) AS OwnerOrUserSettingsPresentation,
	|	CASE
	|		WHEN InheritanceSettingsByOwners.SettingsOwner.Parent <> &EmptyParent
	|			THEN InheritanceSettingsByOwners.SettingsOwner.Parent
	|		ELSE UNDEFINED
	|	END AS SettingsOwner,
	|	TRUE AS ThisSettingsOwner
	|FROM
	|	InheritanceSettingsByOwners AS InheritanceSettingsByOwners
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	RightsSettingsByOwners.SettingsOwner,
	|	RightsSettingsByOwners.User_Settings,
	|	CASE
	|		WHEN VALUETYPE(RightsSettingsByOwners.User_Settings) = TYPE(Catalog.Users)
	|				OR VALUETYPE(RightsSettingsByOwners.User_Settings) = TYPE(Catalog.ExternalUsers)
	|			THEN &ViewPersonal
	|		WHEN VALUETYPE(RightsSettingsByOwners.User_Settings) = TYPE(Catalog.UserGroups)
	|			THEN CAST(RightsSettingsByOwners.User_Settings AS Catalog.UserGroups).Description + &ViewUserGroup
	|		WHEN VALUETYPE(RightsSettingsByOwners.User_Settings) = TYPE(Catalog.ExternalUsersGroups)
	|			THEN CAST(RightsSettingsByOwners.User_Settings AS Catalog.ExternalUsersGroups).Description + &ExternalUserGroupView
	|		ELSE &ViewUndefined
	|	END,
	|	RightsSettingsByOwners.SettingsOwner,
	|	FALSE
	|FROM
	|	RightsSettingsByOwners AS RightsSettingsByOwners
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN CalculatedPermissionsByOwners.SettingsOwner.Parent <> &EmptyParent
	|			THEN CalculatedPermissionsByOwners.SettingsOwner.Parent
	|		ELSE UNDEFINED
	|	END AS SettingsOwner,
	|	CalculatedPermissionsByOwners.SettingsOwner AS OwnerOrUserSettings,
	|	TRUE AS ThisSettingsOwner,
	|	ISNULL(InheritanceSettingsByOwners.SettingsInheritance, FALSE) AS InheritanceSettingsOwner,
	|	ISNULL(TitlesRight.TitlePermissions, CalculatedPermissionsByOwners.CustomizedRight) AS CustomizedRight,
	|	ISNULL(TitlesRight.RightIndex, 99) AS RightIndex,
	|	CalculatedPermissionsByOwners.RightsValue AS RightsValue
	|FROM
	|	CalculatedPermissionsByOwners AS CalculatedPermissionsByOwners
	|		LEFT JOIN TitlesRight AS TitlesRight
	|		ON (TitlesRight.NameOfRight = CalculatedPermissionsByOwners.CustomizedRight)
	|		LEFT JOIN InheritanceSettingsByOwners AS InheritanceSettingsByOwners
	|		ON (InheritanceSettingsByOwners.SettingsOwner = CalculatedPermissionsByOwners.SettingsOwner)
	|
	|UNION ALL
	|
	|SELECT
	|	RightsSettingsByOwners.SettingsOwner,
	|	RightsSettingsByOwners.User_Settings,
	|	FALSE,
	|	ISNULL(InheritanceSettingsByOwners.SettingsInheritance, FALSE),
	|	ISNULL(TitlesRight.TitlePermissions, RightsSettingsByOwners.CustomizedRight),
	|	ISNULL(TitlesRight.RightIndex, 99),
	|	RightsSettingsByOwners.RightsValue
	|FROM
	|	RightsSettingsByOwners AS RightsSettingsByOwners
	|		LEFT JOIN TitlesRight AS TitlesRight
	|		ON (TitlesRight.NameOfRight = RightsSettingsByOwners.CustomizedRight)
	|		LEFT JOIN InheritanceSettingsByOwners AS InheritanceSettingsByOwners
	|		ON (InheritanceSettingsByOwners.SettingsOwner = RightsSettingsByOwners.SettingsOwner)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN OneOwnerSettings.SettingsOwner.Parent <> &EmptyParent
	|			THEN OneOwnerSettings.SettingsOwner.Parent
	|		ELSE UNDEFINED
	|	END,
	|	OneOwnerSettings.SettingsOwner,
	|	TRUE,
	|	OneOwnerSettings.SettingsInheritance,
	|	TitlesRight.TitlePermissions,
	|	TitlesRight.RightIndex,
	|	0
	|FROM
	|	TitlesRight AS TitlesRight
	|		INNER JOIN OneOwnerSettings AS OneOwnerSettings
	|		ON (NOT TRUE IN
	|					(SELECT TOP 1
	|						TRUE
	|					FROM
	|						CalculatedPermissionsByOwners AS CalculatedPermissions
	|					WHERE
	|						CalculatedPermissions.CustomizedRight = TitlesRight.NameOfRight))";
	
	QueryResults = Query.ExecuteBatch();
	
	Result.SettingsRightsHierarchy   = QueryResults[QueryResults.UBound()-1].Unload();
	Result.RightsSettingsOnObjects = QueryResults[QueryResults.UBound()].Unload();
	Result.SettingsRightsLegend    = SettingsRightsLegend(TitlesRight, RightsSettings.HasHierarchy);
	
	Return Result;
	
EndFunction

Function TitlesRight(RightsSettings, SubfolderName)
	
	Result = New ValueTable;
	Result.Columns.Add("NameOfRight",       New TypeDescription("String",
		,,, New StringQualifiers(60, AllowedLength.Variable)));
	Result.Columns.Add("RightIndex",    New TypeDescription("Number",
		,, New NumberQualifiers(2, 0, AllowedSign.Nonnegative)));
	Result.Columns.Add("TitlePermissions", New TypeDescription("String",
		,,, New StringQualifiers(60, AllowedLength.Variable)));
	Result.Columns.Add("HintPermissions", New TypeDescription("String",
		,,, New StringQualifiers(150, AllowedLength.Variable)));
	
	For Each RightDetails In RightsSettings.RightsDetails Do
		RightPresentations = InformationRegisters.ObjectsRightsSettings.AvailableRightPresentation(RightDetails);
		NewRow = Result.Add();
		NewRow.NameOfRight       = RightDetails.Name;
		NewRow.RightIndex    = RightDetails.RightIndex;
		NewRow.TitlePermissions = StrReplace(RightPresentations.Title, Chars.LF, " ");
		NewRow.HintPermissions = StrReplace(RightPresentations.ToolTip, Chars.LF, " ");
	EndDo;
	
	If RightsSettings.HasHierarchy Then
		ColumnDetails = DescriptionColumnsForSubfolders();
		NewRow = Result.Add();
		NewRow.NameOfRight       = ColumnDetails.Name;
		NewRow.RightIndex    = RightsSettings.RightsDetails.Count();
		NewRow.TitlePermissions = ColumnDetails.Title;
		NewRow.HintPermissions = ColumnDetails.ToolTip;
	EndIf;
	
	Return Result;
	
EndFunction

Function DescriptionColumnsForSubfolders()
	
	Result = New Structure;
	Result.Insert("Name", "ForSubfolders");
	Result.Insert("Title", NStr("en = 'For subfolders';"));
	Result.Insert("ToolTip",
		NStr("en = 'Rights both for the current folder and its subfolders';"));
	
	Return Result;
	
EndFunction

Function SettingsRightsLegend(TitlesRight, HasHierarchy)
	
	Result = TitlesRight.Copy(, "TitlePermissions,HintPermissions");
	
	If HasHierarchy Then
		NewRow = Result.Insert(0);
		NewRow.TitlePermissions = "";
		NewRow.HintPermissions = NStr("en = 'Right inheritance from parent folders';");
	EndIf;
	
	For Each String In Result Do
		String.HintPermissions = "- " + String.HintPermissions;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure DisableGroups(ComposerSettings, GroupingNames)
	
	Names = StrSplit(GroupingNames, ",", False);
	For Each Group In ComposerSettings.Structure Do
		If Names.Find(Group.Name) = Undefined Then
			Continue;
		EndIf;
		Group.Use = False;
	EndDo;
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf