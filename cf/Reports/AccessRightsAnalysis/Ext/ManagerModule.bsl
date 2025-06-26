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

// See ReportsOptionsOverridable.BeforeAddReportCommands.
Procedure BeforeAddReportCommands(ReportsCommands, Parameters, StandardProcessing) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
	
	If Not AccessRight("View", Metadata.Reports.AccessRightsAnalysis)
	 Or StandardSubsystemsServer.IsBaseConfigurationVersion() Then
		Return;
	EndIf;
	
	VariantPresentation = NStr("en = 'User rights';");
	OnlyInAllActions = False;
	OptionImportance = "";
	
	If Parameters.FormName = "Catalog.Users.Form.ListForm"
	 Or Parameters.FormName = "Catalog.ExternalUsers.Form.ListForm" Then
		
		If Not Users.IsFullUser() Then
			Return;
		EndIf;
		VariantKey = "UsersRightsToTables";
		
	ElsIf Parameters.FormName = "Catalog.Users.Form.ItemForm"
	      Or Parameters.FormName = "Catalog.ExternalUsers.Form.ItemForm" Then
		
		If Not Users.IsFullUser() Then
			Return;
		EndIf;
		VariantKey = "UserRightsToTables";
		VariantPresentation = NStr("en = 'User rights';");
		
	ElsIf Not Users.IsFullUser() Then
		VariantKey = "UserRightsToTable";
		VariantPresentation = NStr("en = 'User rights';");
		OnlyInAllActions = True;
		OptionImportance = "SeeAlso";
	Else
		VariantKey = "UsersRightsToTable";
		OnlyInAllActions = True;
		OptionImportance = "SeeAlso";
	EndIf;
	
	Command = ReportsCommands.Add();
	Command.VariantKey = VariantKey;
	Command.Presentation = VariantPresentation;
	Command.OnlyInAllActions = OnlyInAllActions;
	Command.MultipleChoice = True;
	Command.Importance = OptionImportance;
	Command.Manager = "Report.AccessRightsAnalysis";
	
EndProcedure

// Parameters:
//   Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//   ReportSettings - See ReportsOptions.DescriptionOfReport.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanels(Settings, ReportSettings, False);
	ReportSettings.DefineFormSettings = True;
	SubsystemForAdministration = Metadata.Subsystems.Find("Administration");
	SubsystemForMonitoring = ?(SubsystemForAdministration = Undefined, Undefined,
		SubsystemForAdministration.Subsystems.Find("UserMonitoring"));
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "AccessRightsAnalysis");
	OptionSettings.LongDesc = NStr("en = 'Shows user rights to infobase tables (you can enable grouping by reports).';");
	If SubsystemForMonitoring <> Undefined Then
		OptionSettings.Location.Insert(SubsystemForMonitoring, "Important");
	EndIf;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersRightsToTables");
	OptionSettings.LongDesc = NStr("en = 'Shows user rights to infobase tables.';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserRightsToTables");
	OptionSettings.LongDesc = NStr("en = 'Shows individual user''s rights to different infobase tables.';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersRightsToTable");
	OptionSettings.LongDesc = NStr("en = 'Shows different users'' rights to the same infobase table.';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserRightsToTable");
	OptionSettings.LongDesc = NStr("en = 'Shows user''s rights to one infobase table with record-level restriction settings (RLS).';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserRightsToReportTables");
	OptionSettings.LongDesc = NStr("en = 'Shows individual user''s rights to different infobase tables used in a separate report.';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UsersRightsToReportTables");
	OptionSettings.LongDesc = NStr("en = 'Shows different users'' rights to different infobase tables used in a separate report.';");
	OptionSettings.Enabled = False;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UserRightsToReportsTables");
	OptionSettings.LongDesc = NStr("en = 'Shows individual user''s rights to different infobase tables grouped by reports.';");
	OptionSettings.Enabled = False;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Parameters:
//  DetailsDataAddress - String - the address of the temporary report details data storage.
//  Details - DataCompositionDetailsID - details item.
//
// Returns:
//  Structure:
//   * DetailsFieldName1 - String
//   * FieldList - Map of KeyAndValue:
//    ** Key - String
//    ** Value - Arbitrary
//
Function DetailsParameters(DetailsDataAddress, Details) Export
	
	DetailsData = GetFromTempStorage(DetailsDataAddress); // DataCompositionDetailsData
	DetailsItem = DetailsData.Items[Details];

	FieldList = New Map;
	FillFieldsList(FieldList, DetailsItem);
	
	DetailsFieldName1 = "";
	For Each Simple In DetailsItem.GetFields() Do
		DetailsFieldName1 = Simple.Field;
		Break;
	EndDo;
	
	Result = New Structure;
	Result.Insert("DetailsFieldName1", DetailsFieldName1);
	Result.Insert("FieldList", FieldList);
	
	ParameterFormatName = New DataCompositionParameter("NameFormat");
	If DetailsData.Settings.DataParameters.Items.Find(ParameterFormatName) <> Undefined Then
		// Report.RolesRights
		Return Result;
	EndIf;
	
	AccessGroup = FieldList.Get("AccessGroup");
	If Not AccessRight("View", Metadata.Catalogs.AccessGroups)
	 Or ValueIsFilled(AccessGroup)
	   And TypeOf(AccessGroup) = Type("CatalogRef.AccessGroups")
	   And Not AccessManagement.ReadingAllowed(AccessGroup) Then
		
		FieldList.Delete("AccessGroup");
	EndIf;
	
	AccessValue = FieldList.Get("AccessValue");
	If TypeOf(AccessValue) = Type("String") Then
		BlankRefs = AccessManagementInternal.EmptyAccessValueReferences();
		FoundRow = BlankRefs.Find(AccessValue, "Presentation");
		If FoundRow <> Undefined Then
			FieldList.Insert("AccessValue", FoundRow.EmptyRef);
		EndIf;
	EndIf;
	
	DetailsValue = FieldList.Get(DetailsFieldName1);
	
	If DetailsFieldName1 = "ReportTitleMetadataObject" Then
		If ValueIsFilled(DetailsValue) Then
			MetadataObject = Common.MetadataObjectByID(DetailsValue, False);
			If TypeOf(MetadataObject) = Type("MetadataObject")
			   And AccessRight("View", MetadataObject) Then
				FieldList.Insert("MetadataObjectURL",
					GetURL(MetadataObject));
			EndIf;
		EndIf;
	EndIf;
	
	ValueMetadata = Metadata.FindByType(TypeOf(DetailsValue));
	If ValueMetadata = Undefined
	 Or Not AccessRight("View", ValueMetadata)
	 Or ValueIsFilled(DetailsValue)
	   And Not AccessManagement.ReadingAllowed(DetailsValue) Then
		
		FieldList.Delete(DetailsFieldName1);
		DetailsValue = Undefined;
	EndIf;
	
	If ValueIsFilled(DetailsValue)
	   And DetailsFieldName1 = "OwnerOrUserSettings"
	   And Metadata.DefinedTypes.RightsSettingsOwner.Type.ContainsType(TypeOf(DetailsValue))
	   And Not AccessManagement.HasRight("RightsManagement", DetailsValue) Then
		
		FieldList.Delete(DetailsFieldName1);
	EndIf;
	
	Return Result;
	
EndFunction

// Parameters:
//   FieldList - Map
//   DetailsItem - DataCompositionFieldDetailsItem
//                      - DataCompositionGroupDetailsItem
//
Procedure FillFieldsList(FieldList, DetailsItem)
	
	If TypeOf(DetailsItem) = Type("DataCompositionFieldDetailsItem") Then
		For Each Simple In DetailsItem.GetFields() Do
			If FieldList[Simple.Field] = Undefined Then
				FieldList.Insert(Simple.Field, Simple.Value);
			EndIf;
		EndDo;
	EndIf;
		
	For Each Parent In DetailsItem.GetParents() Do
		FillFieldsList(FieldList, Parent);
	EndDo;
	
EndProcedure

// Returns a table containing access restriction kind by metadata object right.
// If no record is returned, that means this right has no restrictions.
//  
//
// Parameters:
//  ForExternalUsers - Boolean - If True, return external user restrictions.
//                              Applicable only to universal restrictions.
//
//  AccessTypeForTablesWithDisabledUse - Boolean - If True, add access kind Enumeration.AdditionalAccessValues.AccessAllowed
//    to the inactive tables (only a universal restriction).
//    Applicable only to universal restrictions.
//    
//
// Returns:
//  ValueTable:
//   * ForExternalUsers - Boolean - If False, restrict the access for internal users.
//                                 If True, restrict the access for external users.
//                                 This column is applicable only to universal restrictions.
//   * Table       - CatalogRef.MetadataObjectIDs
//                   - CatalogRef.ExtensionObjectIDs - Table ID.
//   * AccessKind    - AnyRef - Empty reference of the main access kind value type.
//   * Presentation - String - Access kind presentation.
//   * Right         - String - Read, Update.
//
Function AccessRestrictionKinds(ForExternalUsers = Undefined,
			AccessTypeForTablesWithDisabledUse = False) Export
	
	UniversalRestriction =
		AccessManagementInternal.LimitAccessAtRecordLevelUniversally(True, True);
	
	If Not UniversalRestriction Then
		Cache = AccessManagementInternalCached.MetadataObjectsRightsRestrictionsKinds();
		
		If CurrentSessionDate() < Cache.UpdateDate + 60*30 Then
			Return Cache.Table;
		EndIf;
	EndIf;
	
	AccessKindsValuesTypes =
		AccessManagementInternalCached.ValuesTypesOfAccessKindsAndRightsSettingsOwners().Get(); // ValueTable
	
	Query = New Query;
	Query.SetParameter("PermanentRestrictionKinds",
		AccessManagementInternalCached.PermanentMetadataObjectsRightsRestrictionsKinds());
	
	If UniversalRestriction Then
		Query.Text =
		"SELECT
		|	PermanentRestrictionKinds.ForExternalUsers AS ForExternalUsers,
		|	PermanentRestrictionKinds.FullName AS FullName,
		|	PermanentRestrictionKinds.Table AS Table,
		|	PermanentRestrictionKinds.Right AS Right,
		|	PermanentRestrictionKinds.AccessKind AS AccessKind
		|INTO PermanentRestrictionKinds
		|FROM
		|	&PermanentRestrictionKinds AS PermanentRestrictionKinds
		|WHERE
		|	&FilterForExternalUsers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccessTypesWithView.AccessKind AS AccessKind,
		|	AccessTypesWithView.Presentation AS Presentation
		|INTO AccessTypesWithView
		|FROM
		|	&AccessTypesWithView AS AccessTypesWithView
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TablesWithRestrictionDisabled.ForExternalUsers AS ForExternalUsers,
		|	TablesWithRestrictionDisabled.FullName AS FullName,
		|	TablesWithRestrictionDisabled.Table AS Table,
		|	TablesWithRestrictionDisabled.AccessKind AS AccessKind,
		|	TablesWithRestrictionDisabled.Presentation AS Presentation
		|INTO TablesWithRestrictionDisabled
		|FROM
		|	&TablesWithRestrictionDisabled AS TablesWithRestrictionDisabled
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	AccessRestrictionKinds.ForExternalUsers AS ForExternalUsers,
		|	AccessRestrictionKinds.Table AS Table,
		|	AccessRestrictionKinds.Right AS Right,
		|	AccessRestrictionKinds.AccessKind AS AccessKind,
		|	AccessRestrictionKinds.Presentation AS Presentation
		|FROM
		|	(SELECT
		|		PermanentRestrictionKinds.ForExternalUsers AS ForExternalUsers,
		|		PermanentRestrictionKinds.Table AS Table,
		|		CASE
		|			WHEN NOT TablesWithRestrictionDisabled.FullName IS NULL
		|				THEN """"
		|			ELSE PermanentRestrictionKinds.Right
		|		END AS Right,
		|		CASE
		|			WHEN NOT TablesWithRestrictionDisabled.FullName IS NULL
		|				THEN TablesWithRestrictionDisabled.AccessKind
		|			ELSE PermanentRestrictionKinds.AccessKind
		|		END AS AccessKind,
		|		CASE
		|			WHEN NOT TablesWithRestrictionDisabled.FullName IS NULL
		|				THEN TablesWithRestrictionDisabled.Presentation
		|			ELSE ISNULL(AccessTypesWithView.Presentation, &RepresentationUnknownAccessType)
		|		END AS Presentation
		|	FROM
		|		PermanentRestrictionKinds AS PermanentRestrictionKinds
		|			LEFT JOIN TablesWithRestrictionDisabled AS TablesWithRestrictionDisabled
		|			ON (TablesWithRestrictionDisabled.ForExternalUsers = PermanentRestrictionKinds.ForExternalUsers)
		|				AND (TablesWithRestrictionDisabled.FullName = PermanentRestrictionKinds.FullName)
		|			LEFT JOIN AccessTypesWithView AS AccessTypesWithView
		|			ON (AccessTypesWithView.AccessKind = PermanentRestrictionKinds.AccessKind)
		|	WHERE
		|		PermanentRestrictionKinds.AccessKind <> UNDEFINED
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TablesWithRestrictionDisabled.ForExternalUsers,
		|		TablesWithRestrictionDisabled.Table,
		|		"""",
		|		TablesWithRestrictionDisabled.AccessKind,
		|		TablesWithRestrictionDisabled.Presentation
		|	FROM
		|		TablesWithRestrictionDisabled AS TablesWithRestrictionDisabled
		|			LEFT JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
		|			ON (PermanentRestrictionKinds.ForExternalUsers = TablesWithRestrictionDisabled.ForExternalUsers)
		|				AND (PermanentRestrictionKinds.FullName = TablesWithRestrictionDisabled.FullName)
		|	WHERE
		|		PermanentRestrictionKinds.FullName IS NULL
		|		AND TablesWithRestrictionDisabled.Table <> UNDEFINED) AS AccessRestrictionKinds";
		
		If TypeOf(ForExternalUsers) = Type("Boolean") Then
			Query.SetParameter("ForExternalUsers", ForExternalUsers);
			Query.Text = StrReplace(Query.Text, "&FilterForExternalUsers",
				"PermanentRestrictionKinds.ForExternalUsers = &ForExternalUsers");
		Else
			Query.Text = StrReplace(Query.Text, "&FilterForExternalUsers", "TRUE");
		EndIf;
		Query.SetParameter("AccessTypesWithView",
			AccessTypesWithView(AccessKindsValuesTypes, False));
		Query.SetParameter("RepresentationUnknownAccessType",
			RepresentationUnknownAccessType());
		Query.SetParameter("TablesWithRestrictionDisabled",
			TablesWithRestrictionDisabled(ForExternalUsers,
				AccessTypeForTablesWithDisabledUse));
	Else
		Query.SetParameter("AccessKindsValuesTypes", AccessKindsValuesTypes);
		Query.SetParameter("UsedAccessKinds",
			AccessTypesWithView(AccessKindsValuesTypes, True));
		// ACC:96-off - No.434. Using JOIN is acceptable as the rows should be unique and
		// the result will be cached.
		Query.Text =
		"SELECT
		|	PermanentRestrictionKinds.Table AS Table,
		|	PermanentRestrictionKinds.Right AS Right,
		|	PermanentRestrictionKinds.AccessKind AS AccessKind,
		|	PermanentRestrictionKinds.ObjectTable AS ObjectTable
		|INTO PermanentRestrictionKinds
		|FROM
		|	&PermanentRestrictionKinds AS PermanentRestrictionKinds
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccessKindsValuesTypes.AccessKind AS AccessKind,
		|	AccessKindsValuesTypes.ValuesType AS ValuesType
		|INTO AccessKindsValuesTypes
		|FROM
		|	&AccessKindsValuesTypes AS AccessKindsValuesTypes
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	UsedAccessKinds.AccessKind AS AccessKind,
		|	UsedAccessKinds.Presentation AS Presentation
		|INTO UsedAccessKinds
		|FROM
		|	&UsedAccessKinds AS UsedAccessKinds
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	PermanentRestrictionKinds.Table AS Table,
		|	""Read"" AS Right,
		|	VALUETYPE(RowsSets.AccessValue) AS ValuesType
		|INTO VariableRestrictionKinds
		|FROM
		|	InformationRegister.AccessValuesSets AS SetsNumbers
		|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
		|		ON (PermanentRestrictionKinds.Right = ""Read"")
		|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
		|			AND (VALUETYPE(SetsNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
		|			AND (SetsNumbers.Read)
		|		INNER JOIN InformationRegister.AccessValuesSets AS RowsSets
		|		ON (RowsSets.Object = SetsNumbers.Object)
		|			AND (RowsSets.SetNumber = SetsNumbers.SetNumber)
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	PermanentRestrictionKinds.Table,
		|	""Update"",
		|	VALUETYPE(RowsSets.AccessValue)
		|FROM
		|	InformationRegister.AccessValuesSets AS SetsNumbers
		|		INNER JOIN PermanentRestrictionKinds AS PermanentRestrictionKinds
		|		ON (PermanentRestrictionKinds.Right = ""Update"")
		|			AND (PermanentRestrictionKinds.AccessKind = UNDEFINED)
		|			AND (VALUETYPE(SetsNumbers.Object) = VALUETYPE(PermanentRestrictionKinds.ObjectTable))
		|			AND (SetsNumbers.Update)
		|		INNER JOIN InformationRegister.AccessValuesSets AS RowsSets
		|		ON (RowsSets.Object = SetsNumbers.Object)
		|			AND (RowsSets.SetNumber = SetsNumbers.SetNumber)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PermanentRestrictionKinds.Table AS Table,
		|	PermanentRestrictionKinds.Right AS Right,
		|	AccessKindsValuesTypes.AccessKind AS AccessKind
		|INTO AllRightsRestrictionsKinds
		|FROM
		|	PermanentRestrictionKinds AS PermanentRestrictionKinds
		|		INNER JOIN AccessKindsValuesTypes AS AccessKindsValuesTypes
		|		ON PermanentRestrictionKinds.AccessKind = AccessKindsValuesTypes.AccessKind
		|			AND (PermanentRestrictionKinds.AccessKind <> UNDEFINED)
		|
		|UNION
		|
		|SELECT
		|	VariableRestrictionKinds.Table,
		|	VariableRestrictionKinds.Right,
		|	AccessKindsValuesTypes.AccessKind
		|FROM
		|	VariableRestrictionKinds AS VariableRestrictionKinds
		|		INNER JOIN AccessKindsValuesTypes AS AccessKindsValuesTypes
		|		ON (VariableRestrictionKinds.ValuesType = VALUETYPE(AccessKindsValuesTypes.ValuesType))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AllRightsRestrictionsKinds.Table AS Table,
		|	AllRightsRestrictionsKinds.Right AS Right,
		|	AllRightsRestrictionsKinds.AccessKind AS AccessKind,
		|	UsedAccessKinds.Presentation AS Presentation
		|FROM
		|	AllRightsRestrictionsKinds AS AllRightsRestrictionsKinds
		|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
		|		ON AllRightsRestrictionsKinds.AccessKind = UsedAccessKinds.AccessKind";
		// ACC:96-on
	EndIf;
	
	Upload0 = Query.Execute().Unload();
	
	If Not UniversalRestriction Then
		Cache.Table = Upload0;
		Cache.UpdateDate = CurrentSessionDate();
	EndIf;
	
	Return Upload0;
	
EndFunction

// For function AccessRestrictionKinds.
Function AccessTypesWithView(AccessKindsValuesTypes, UsedOnly)
	
	AccessKinds = AccessKindsValuesTypes.Copy(, "AccessKind");
	
	AccessKinds.GroupBy("AccessKind");
	AccessKinds.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150)));
	UsedAccessKinds = AccessManagementInternal.UsedAccessKinds();
	
	IndexOf = AccessKinds.Count()-1;
	While IndexOf >= 0 Do
		String = AccessKinds[IndexOf];
		AccessKindProperties = AccessManagementInternal.AccessKindProperties(String.AccessKind);
		
		If AccessKindProperties = Undefined Then
			RightsSettingsOwnerMetadata = Metadata.FindByType(TypeOf(String.AccessKind));
			If RightsSettingsOwnerMetadata = Undefined Then
				String.Presentation = RepresentationUnknownAccessType();
			Else
				String.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Rights settings for %1';"),
					RightsSettingsOwnerMetadata.Presentation());
			EndIf;
			
		ElsIf Not UsedOnly
		      Or UsedAccessKinds.Get(AccessKindProperties.Ref) <> Undefined Then
			
			String.Presentation = AccessManagementInternal.AccessKindPresentation(AccessKindProperties);
		Else
			AccessKinds.Delete(String);
		EndIf;
		
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return AccessKinds;
	
EndFunction

// Intended for functions "AccessRestrictionKinds", "AccessKindsWithPresentation".
Function RepresentationUnknownAccessType()
	
	Return NStr("en = 'Unknown access kind';");
	
EndFunction

// For function AccessRestrictionKinds.
Function TablesWithRestrictionDisabled(ForExternalUsers, FillIn)
	
	IDsTypes = New Array;
	IDsTypes.Add(Type("CatalogRef.MetadataObjectIDs"));
	IDsTypes.Add(Type("CatalogRef.ExtensionObjectIDs"));
	
	Result = New ValueTable;
	Result.Columns.Add("ForExternalUsers", New TypeDescription("Boolean"));
	Result.Columns.Add("FullName",
		Metadata.Catalogs.MetadataObjectIDs.Attributes.FullName.Type);
	Result.Columns.Add("Table",    New TypeDescription(IDsTypes));
	Result.Columns.Add("AccessKind", AccessManagementInternalCached.DetailsOfAccessValuesTypesAndRightsSettingsOwners());
	Result.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150)));
	
	If Not FillIn Then
		Return Result;
	EndIf;
	
	ActiveParameters = AccessManagementInternal.ActiveAccessRestrictionParameters(
		Undefined, Undefined, False);
	
	If ForExternalUsers <> True Then
		AddTablesWithRestrictionDisabled(Result, ActiveParameters, False);
	EndIf;
	If ForExternalUsers <> False Then
		AddTablesWithRestrictionDisabled(Result, ActiveParameters, True);
	EndIf;
	FullNames = Result.UnloadColumn("FullName");
	NameIdentifiers = Common.MetadataObjectIDs(FullNames, False);
	For Each String In Result Do
		String.Table = NameIdentifiers.Get(String.FullName);
	EndDo;
	
	Return Result;
	
EndFunction

// Intended for function "UnrestrictedTables".
Procedure AddTablesWithRestrictionDisabled(TablesWithRestrictionDisabled,
			ActiveParameters, ForExternalUsers)
	
	If ForExternalUsers Then
		AdditionalContext = ActiveParameters.AdditionalContext.ForExternalUsers;
	Else
		AdditionalContext = ActiveParameters.AdditionalContext.ForUsers;
	EndIf;
	
	ListsWithDisabledRestriction = AdditionalContext.ListsWithDisabledRestriction;
	ListRestrictionsProperties     = AdditionalContext.ListRestrictionsProperties;
	
	For Each KeyAndValue In ListRestrictionsProperties Do
		FullName = KeyAndValue.Key;
		If Not KeyAndValue.Value.AccessDenied
		   And ListsWithDisabledRestriction.Get(FullName) = Undefined Then
			Continue;
		EndIf;
		NewRow = TablesWithRestrictionDisabled.Add();
		NewRow.ForExternalUsers = ForExternalUsers;
		NewRow.FullName = FullName;
		If KeyAndValue.Value.AccessDenied Then
			NewRow.AccessKind    = Enums.AdditionalAccessValues.AccessDenied;
			NewRow.Presentation = "<" + NStr("en = 'Access denied';") + ">";
		Else
			NewRow.AccessKind    = Enums.AdditionalAccessValues.AccessAllowed;
			NewRow.Presentation = "<" + NStr("en = 'Restriction disabled';") + ">";
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf

