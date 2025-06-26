///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Returns a reference to the report option.
//
// Parameters:
//  Report - CatalogRef.ExtensionObjectIDs
//        - CatalogRef.MetadataObjectIDs
//        - CatalogRef.AdditionalReportsAndDataProcessors
//        - String - Reference to a report or an external report full name.
//  VariantKey - String - Report option name.
//
// Returns:
//  CatalogRef.ReportsOptions, Undefined - Report option. 
//          If the report is missing or the user has insufficient access rights, returns Undefined.
//
Function ReportVariant(Report, VariantKey) Export
	Result = Undefined;
	
	Query = New Query;
	If TypeOf(Report) = Type("CatalogRef.ExtensionObjectIDs") Then
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	Reports.Ref AS ReportVariant
		|FROM
		|	InformationRegister.PredefinedExtensionsVersionsReportsOptions AS ExtensionReports
		|	INNER JOIN Catalog.ReportsOptions AS Reports
		|		ON Reports.PredefinedOption = ExtensionReports.Variant
		|WHERE
		|	ExtensionReports.Report = &Report
		|	AND ExtensionReports.ExtensionsVersion = &ExtensionsVersion
		|	AND ExtensionReports.VariantKey = &VariantKey
		|
		|ORDER BY
		|	Reports.DeletionMark";
		
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Else
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	ReportsOptions.Ref AS ReportVariant
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Report = &Report
		|	AND ReportsOptions.VariantKey = &VariantKey
		|
		|ORDER BY
		|	ReportsOptions.DeletionMark";
	EndIf;
	
	Query.SetParameter("Report", Report);
	Query.SetParameter("VariantKey", VariantKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.ReportVariant;
	EndIf;
	
	Return Result;
EndFunction

// Returns reports (CatalogRef.ReportsOptions) that are available to the current user.
// They must be used in all queries to the "ReportsOptions" catalog table
// as the filter by the "Report" attribute
// except for filtering options from external reports.
//
// Returns:
//  Array - Report that are available to the current user (CatalogRef.ExtensionObjectIDs, 
//           String, CatalogRef.AdditionalReportsAndDataProcessors, 
//           CatalogRef.MetadataObjectIDs).
//           The item type repeats the type of the Catalogs.ReportOptions.Attributes.Report attribute.
//
Function CurrentUserReports() Export
	
	AvailableReports = New Array(ReportsOptionsCached.AvailableReports());
	
	// Additional reports that are available to the current user.
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnAddAdditionalReportsAvailableForCurrentUser(AvailableReports);
	EndIf;
	
	Return AvailableReports;
	
EndFunction

// Returns a list of report options from the ReportsOptionsStorage settings storage. 
// See also StandardSettingsStorageManager.GetList in Syntax Assistant.
// Unlike the 1C:Enterprise method, this function checks access rights to the report instead of the DataAdministration right.
//
// Parameters:
//  ReportKey - String - Full report name (dot-delimited).
//  User - String
//               - UUID
//               - InfoBaseUser
//               - Undefined
//               - CatalogRef.Users - Name, ID, or reference to the user 
//                                                 whose settings to be obtained.
//                                                 If Undefined, takes the current user.
//
// Returns: 
//   ValueList - List of report options, where::
//       * Value - String - Report option key.
//       * Presentation - String - Report option presentation.
//
//
Function ReportOptionsKeys(ReportKey, Val User = Undefined) Export
	
	Return SettingsStorages.ReportsVariantsStorage.GetList(ReportKey, User);
	
EndFunction

// The procedure deletes options of the specified report or all reports.
// See also StandardSettingsStorageManager.Delete in Syntax Assistant.
//
// Parameters:
//  ReportKey - String
//             - Undefined - Full report name (dot-delimited).
//                              If Undefined, settings of all reports will be deleted.
//  VariantKey - String
//               - Undefined - Key of the report option to be deleted.
//                                If Undefined, all the report options will be deleted.
//  User - String
//               - UUID
//               - InfoBaseUser
//               - Undefined
//               - CatalogRef.Users - Name, ID, or reference to the user whose settings will be deleted. 
//                                                 If Undefined, settings of all users will be deleted.
//                                                 
//
Procedure DeleteReportOption(ReportKey, VariantKey, Val User) Export
	
	SettingsStorages.ReportsVariantsStorage.Delete(ReportKey, VariantKey, User);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Support for overridable modules.

// The procedure calls the report manager module to fill in its settings.
// It is used for calling from the ReportsOptionsOverridable.CustomizeReportsOptions.
//
// Parameters:
//  Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//  ReportMetadata - MetadataObject - Metadata of the object that has the SetUpReportOptions(Settings, ReportSettings)
//                                       export procedure in its manager module.
//
Procedure CustomizeReportInManagerModule(Settings, ReportMetadata) Export
	ReportSettings = DescriptionOfReport(Settings, ReportMetadata);
	
	Try
		Reports[ReportMetadata.Name].CustomizeReportOptions(Settings, ReportSettings);
	Except
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of ""%1"" parameter specified. Procedure %2.
			|Failed to configure report options from manager module. Reason:
			|%3';"),
			"VariantKey", "ReportsOptions.CustomizeReportInManagerModule",
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		WriteToLog(EventLogLevel.Error, ErrorText, ReportMetadata);
	EndTry;
EndProcedure

// The function returns settings of the specified report. It is used for setting up the location and common report parameters
//   in ReportsOptionsOverridable.CustomizeReportsOptions.
//
// Parameters:
//  Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//  Report     - MetadataObjectReport
//            - CatalogRef.MetadataObjectIDs - Report reference or metadata.
//
// Returns:
//   ValueTreeRow - Report settings and default settings for the report options of this report, where::
//       * Enabled              - Boolean - If False, the report option is hidden from the report panel.
//       * DefaultVisibility - Boolean - If False, the report option is hidden from the report panel by default.
//       * ShouldShowInOptionsSubmenu - Boolean - If False, the report is hidden from the report choice submenu  
//                                                in the report form. It's used if Enabled is False.
//       * Location           - Map of KeyAndValue - Settings that specify the report option location in sections, where::
//           ** Key     - MetadataObject - Subsystem that contains the report or report option.
//           ** Value - String           - The settings of placing the report in a subsystem or a group. Valid values are:
//               "" - Display the name as normal text in the subsystem.
//               "Important" - Display the name as bold text in the subsystem.
//               "SeeAlso" - Display the name in the "See also" group.
//       * FunctionalOptions - Array of String - Names of the report option's functional options.
//       * SearchSettings  - Structure - Additional settings for searching this report option, where::
//             ** FieldDescriptions - String - Names of report option fields.
//             ** FilterParameterDescriptions - String - Names of report option settings.
//             ** Keywords - String - Additional terminology (including specialized and obsolete).
//             ** TemplatesNames  - String - This parameter is used instead of FieldDescriptions.
//       * DCSSettingsFormat - Boolean - This report uses a standard settings storage format based on the DCS mechanics,
//           and its main forms support the standard schema of interaction between forms
//           (the type and parameters of return values).
//           If False, then the consistency checks and some components that require
//           the standard format will be disabled for this report.
//       * DefineFormSettings - Boolean - The report has an API for integration with the report form
//           including overriding some form settings and subscribing to its events.
//           If True and the report is attached to the general ReportForm form,
//           then the procedure must be defined in the report object module according to the following template::
//               
//               Set the report form settings.
//               //
//               
//               Parameters:
//               Form - ClientApplicationForm, Undefined
//               OptionKey - String, Undefined See ReportsClientServer.DefaultReportSettings
//               //
//               Settings - 
//               	
//               Procedure DefineFormSettings(Form, OptionKey, Settings) Export
//                                             Procedure code.
//                                             EndProcedure
//               
//       * Report - CatalogRef.ExtensionObjectIDs
//               - CatalogRef.AdditionalReportsAndDataProcessors
//               - CatalogRef.MetadataObjectIDs
//               - String - Report full name or reference. 
//       * Metadata - MetadataObjectReport - Report metadata.
//       * VariantKey - String - Report option name.
//       * DetailsReceived - Boolean - Flag indicating whether the row details are already received.
//           The details are generated by the OptionDetails() method.
//       * SystemInfo - Structure - Other internal information.
//     The following columns are internal and read-only:
//     Report, Metadata, OptionKey, DetailsReceived, SystemInfo.
//
Function DescriptionOfReport(Settings, Report) Export
	If TypeOf(Report) = Type("MetadataObject") Then
		Result = Settings.FindRows(New Structure("Metadata, IsOption", Report, False));
	Else
		Result = Settings.FindRows(New Structure("Report, IsOption", Report, False));
	EndIf;
	
	If Result.Count() = 0 Then
		Result = FoundReportDetails(Report);
	EndIf;
	
	If Result.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of ""%1"" parameter is specified. Function ""%2"".
			|Report ""%3"" is not added to subsystem ""%4"". Check ""Option storage"" property in report properties.';"),
			"Report", "ReportsOptions.DescriptionOfReport", String(Report), SubsystemDescription(""));
	EndIf;
	
	Return Result[0];
EndFunction

// The function searches for report option settings. It is used for setting up the location.
// Intended for ReportsOptionsOverridable.CustomizeReportsOptions.
//
// Parameters:
//  Settings    - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//  Report        - ValueTreeRow
//               - MetadataObject - Settings details, metadata, or a report reference.
//  VariantKey - String - Report option name as it is defined in the data composition schema.
//
// Returns:
//   ValueTreeRow - Report option settings, where::
//       * Enabled              - Boolean - If False, the report option is hidden from the report panel.
//       * DefaultVisibility - Boolean - If False, the report option is hidden from the report panel by default.
//       * ShouldShowInOptionsSubmenu - Boolean - If False, the report is hidden from the report choice submenu  
//                                                in the report form. It's used if Enabled is False.
//       * Description         - String - Report option name.
//       * LongDesc             - String - Report option tooltip.
//       * Location           - Map of KeyAndValue - Settings that define the report option location in sections, where::
//           ** Key     - MetadataObject - Subsystem where the report or report option is located.
//           ** Value - String           - The settings of placing the report option in a subsystem or a group. Valid values are:
//               "" - Display the name as normal text in the subsystem.
//               "Important" - Display the name as bold text in the subsystem.
//               "SeeAlso" - Display the name in the "See also" group.
//       * FunctionalOptions - Array of String - Names of the report option's functional options.
//       * SearchSettings  - Structure - Additional settings for searching this report option, where::
//           ** FieldDescriptions              - String - Names of report option fields.
//           ** FilterParameterDescriptions - String - Names of report option settings.
//           ** Keywords                  - String - Additional terminology (including specialized and obsolete).
//           ** TemplatesNames                   - String - This parameter is used instead of FieldDescriptions.
//       * DCSSettingsFormat - Boolean - This report uses a standard settings storage format based on the DCS mechanics,
//           and its main forms support the standard schema of interaction between forms
//           (the type and parameters of return values).
//           If False, then the consistency checks and some components that require
//           the standard format will be disabled for this report.
//       * DefineFormSettings - Boolean - The report has an API for integration with the report form
//           including overriding some form settings and subscribing to its events.
//           If True and the report is attached to the general ReportForm form,
//           then the procedure must be defined in the report object module according to the following template::
//               
//               Set the report form settings.
//               //
//               
//               Parameters:
//               Form - ClientApplicationForm, Undefined
//               OptionKey - String, Undefined
//               //
//               Settings - See the ReportsClientServer.DefaultReportSettings value
//               	
//               Procedure DefineFormSettings(Form, OptionKey, Settings) Export
//                                             Procedure code.
//                                             EndProcedure
//               
//       * Report - CatalogRef.ExtensionObjectIDs
//               - CatalogRef.AdditionalReportsAndDataProcessors
//               - CatalogRef.MetadataObjectIDs
//               - String - Report full name or reference.
//       * LongDesc - String
//       * Metadata - MetadataObjectReport - Report metadata.
//       * VariantKey - String - Report option name.
//       * Purpose - EnumRef.ReportOptionPurposes - Report option assignment (by default, ForComputersAndTablets).
//                                                                      
//       * DetailsReceived - Boolean - Flag indicating whether the row details are already received.
//           Details are generated by the OptionDetails() method.
//       * SystemInfo - Structure - Other internal information.
//     The following columns are internal and read-only:
//     Report, Metadata, OptionKey, DetailsReceived, SystemInfo.
//
Function OptionDetails(Settings, Report, VariantKey) Export
	If TypeOf(Report) = Type("ValueTableRow") Then
		DescriptionOfReport = Report;
	Else
		DescriptionOfReport = DescriptionOfReport(Settings, Report);
	EndIf;
	
	If Settings.Find(DescriptionOfReport.Type, "Type") = Undefined Then 
		Return DescriptionOfReport;
	EndIf;
	
	MetadataOfReport = DescriptionOfReport.Metadata; // MetadataObjectReport
	ReportOptionKey = ?(IsBlankString(VariantKey), DescriptionOfReport.MainOption, VariantKey);
	
	Search = New Structure("Report, VariantKey, IsOption", DescriptionOfReport.Report, ReportOptionKey, True);
	Result = Settings.FindRows(Search);
	
	If Result.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value of ""%1"" parameter specified. Procedure %2.
				|Report ""%4"" is missing option ""%3"".';"),
			"VariantKey", "ReportsOptions.OptionDetails", ReportOptionKey, MetadataOfReport.Name);
	EndIf;
	
	FillOptionRowDetails(Result[0], DescriptionOfReport);
	
	Return Result[0];
EndFunction

// The procedure sets the output mode for Reports and Options in report panels.
// To be called from the ReportsOptionsOverridable.CustomizeReportsOptions procedure of the overridable module
// and from the CustomizeReportOptions procedure of the report object module.
//
// Parameters:
//  Settings - See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//  ReportOrSubsystem - ValueTreeRow
//                     - MetadataObjectReport
//                     - MetadataObjectSubsystem - Details of a report or subsystem
//                       the output mode will apply to. If a subsystem is passed,
//                       the mode is set recursively for all reports of this subsystem.
//  GroupByReports - Boolean
//                        - String - Display mode of this report's hyperlinks in the report panel::
//                          If True, ByReports, options are grouped by a report.
//                          By default, report panels output only a main report option.
//                          Other options of the report are displayed under the main one and are hidden.
//                          However, they can be found by the search or enabled by check boxes in the setup mode.
//                          The main option is the first predefined option in the report schema.
//                          This mode was introduced in version 2.2.2. It reduces the number of hyperlinks displayed in report panels.
//                          If False, ByOptions, all report options are considered independent.
//                          They are visible by default and are displayed independently in report panels.
//                          This mode was used in version 2.2.1 and earlier.
//
Procedure SetOutputModeInReportPanels(Settings, ReportOrSubsystem, GroupByReports) Export
	
	If TypeOf(GroupByReports) <> Type("Boolean") Then
		GroupByReports = (GroupByReports = Upper("ByReports"));
	EndIf;
	
	If TypeOf(ReportOrSubsystem) = Type("ValueTableRow")
		Or Metadata.Reports.Contains(ReportOrSubsystem) Then
		
		SetReportOutputModeInReportsPanels(Settings, ReportOrSubsystem, GroupByReports);
		Return;
	EndIf;

	Subsystems = New Array;
	Subsystems.Add(ReportOrSubsystem);
	Count = 1;
	ProcessedObjects = New Map;
	While Count > 0 Do
		Count = Count - 1;
		Subsystem = Subsystems[0];
		Subsystems.Delete(0);
		For Each NestedSubsystem In Subsystem.Subsystems Do
			Count = Count + 1;
			Subsystems.Add(NestedSubsystem);
		EndDo;
		For Each MetadataObject In ReportOrSubsystem.Content Do
			If ProcessedObjects[MetadataObject] <> Undefined Then
				Continue;
			EndIf;
			
			ProcessedObjects[MetadataObject] = True;
			If Metadata.Reports.Contains(MetadataObject) Then
				SetReportOutputModeInReportsPanels(Settings, MetadataObject, GroupByReports);
			EndIf;
		EndDo;
	EndDo;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Intended for being called from reports.

// Updates content of the UserReportSettings catalog after saving the new setting.
// Called in the same name handler of the report form after the form code execution.
//
// Parameters:
//  Form - ClientApplicationForm - Report form.
//  Settings - DataCompositionUserSettings - It is passed from the OnSaveUserSettingsAtServer procedure as is.
//
Procedure OnSaveUserSettingsAtServer(Form, Settings) Export
	
	FormAttributes = New Structure("ObjectKey, OptionRef");
	FillPropertyValues(FormAttributes, Form);
	If Not ValueIsFilled(FormAttributes.ObjectKey)
		Or Not ValueIsFilled(FormAttributes.OptionRef) Then
		ReportObject = Form.FormAttributeToValue("Report");
		ReportMetadata = ReportObject.Metadata();
		If Not ValueIsFilled(FormAttributes.ObjectKey) Then
			FormAttributes.ObjectKey = ReportMetadata.FullName();
		EndIf;
		If Not ValueIsFilled(FormAttributes.OptionRef) Then
			ReportInformation = ReportInformation(FormAttributes.ObjectKey);
			If Not ValueIsFilled(ReportInformation.ErrorText) Then
				ReportRef = ReportInformation.Report;
			Else
				ReportRef = FormAttributes.ObjectKey;
			EndIf;
			FormAttributes.OptionRef = ReportVariant(ReportRef, Form.CurrentVariantKey);
		EndIf;
	EndIf;
	
	SettingsKey = FormAttributes.ObjectKey + "/" + Form.CurrentVariantKey;
	SettingsList = ReportsUserSettingsStorage.GetList(SettingsKey);
	SettingsCount = SettingsList.Count();
	UserRef = Users.AuthorizedUser();
	
	UserSettings = UserReportOptionSettings(FormAttributes.OptionRef, UserRef);
	If UserSettings = Undefined Then 
		Return;
	EndIf;
	
	For Each Setting In UserSettings Do 
		ListItem = SettingsList.FindByValue(Setting.UserSettingKey);
		
		DeletionMark = (ListItem = Undefined);
		If DeletionMark <> Setting.DeletionMark Then
			SettingObject = Setting.Ref.GetObject(); // CatalogObject.UserReportSettings
			SettingObject.SetDeletionMark(DeletionMark);
		EndIf;
		
		If DeletionMark Then
			If SettingsCount = 0 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		If Setting.Description <> ListItem.Presentation Then
			SettingObject = Setting.Ref.GetObject(); // CatalogObject.UserReportSettings
			SettingObject.Description = ListItem.Presentation;
			
			// The lock isn't set as the user settings are broken down user-wise.
			// Therefore, competitive runtimes are not expected.
			SettingObject.Write(); // 
		EndIf;
		
		SettingsList.Delete(ListItem);
		SettingsCount = SettingsCount - 1;
	EndDo;
	
	For Each ListItem In SettingsList Do
		SettingObject = Catalogs.UserReportSettings.CreateItem();
		SettingObject.Description                  = ListItem.Presentation;
		SettingObject.UserSettingKey = ListItem.Value;
		SettingObject.Variant                       = FormAttributes.OptionRef;
		SettingObject.User                  = UserRef;
		
		// The lock isn't set as the user settings are broken down user-wise.
		// Therefore, competitive runtimes are not expected.
		SettingObject.Write(); // 
	EndDo;
	
EndProcedure

// Extracts information on tables used in a schema or query.
// The calling code handles exceptions (for example, if an incorrect query text was passed).
//
// Parameters:
//  Object - DataCompositionSchema
//         - String - Report schema or query text.
//
// Returns:
//   Array - Names of tables used in the schema or query.
//
// Example:
//  // Call from the native form of the report using DCS.
//  UsedTables = ReportsOptions.UsedTables(FormAttributeToValue(Report).DataCompositionSchema);
//  ReportsOptions.CheckUsedTables(UsedTables).
//  // Call from the OnComposeResult handler of the report using DCS.
//  UsedTables = ReportsOptions.UsedTables(DataCompositionSchema);
//  ReportsOptions.CheckUsedTables(UsedTables).
//  // Call from the OnComposeResult handler of the report using query.
//  UsedTables = ReportsOptions.UsedTables(QueryText);
//  ReportsOptions.CheckUsedTables(UsedTables).
//
Function TablesToUse(Object) Export
	Tables = New Array;
	
	If TypeOf(Object) = Type("DataCompositionSchema") Then
		RegisterDataSetsTables(Tables, Object.DataSets);
	ElsIf TypeOf(Object) = Type("String") Then
		RegisterQueryTables(Tables, Object);
	EndIf;
	
	Return Tables;
EndFunction

// Extracts information on tables used in a schema or query.
//
// Parameters:
//  Report - MetadataObjectReport
//        - ReportObject
//
// Returns:
//   Array of See TablesToUse
//
Function UsedReportTables(Report) Export
	If TypeOf(Report) = Type("MetadataObject") Then 
		ReportObject = ReportsServer.ReportObject(Report.FullName());
		Id = Common.MetadataObjectID(Report);
	Else
		ReportObject = Report;
		Id = Common.MetadataObjectID(Report.Metadata());
	EndIf;
	
	TablesToUse = TablesToUse(ReportObject.DataCompositionSchema);
	
	ReportSettings = ReportSettings(Id, Undefined, ReportObject);
	If ReportSettings.Events.OnDefineUsedTables Then
		ReportObject.OnDefineUsedTables(Undefined, TablesToUse);
	EndIf;
	
	Return TablesToUse;
EndFunction

// Checks whether tables used in the schema or query are updated and inform the user about it.
// Check is executed by the InfobaseUpdate.ObjectProcessed() method.
// The calling code handles exceptions (for example, if an incorrect query text was passed).
//
// Parameters:
//  Object - DataCompositionSchema - Report schema.
//         - String - Query text.
//         - Array - Names of the tables the report uses::
//           * String - Table name.
//  ToReport - Boolean - If True and the tables used by the report have not yet been updated,
//             outputs the message "The report can contain incorrect data."
//             Optional. By default, True.
//
// Returns:
//   Boolean - True if the table list contains tables that pending an update.
//
// Example:
//  Call from the native form of the report.
//  ReportsOptions.CheckUsedTables(FormAttributeToValue("Report").DataCompositionSchema);
//  Call from the OnComposeResult report handler.
//  ReportsOptions.CheckUsedTables(DataCompositionSchema);
//  Call upon query execution.
//  ReportsOptions.CheckUsedTables(QueryText);
//
Function CheckUsedTables(Object, ToReport = True) Export
	If TypeOf(Object) = Type("Array") Then
		TablesToUse = Object;
	Else
		TablesToUse = TablesToUse(Object);
	EndIf;
	For Each FullName In TablesToUse Do
		If Not InfobaseUpdate.ObjectProcessed(FullName).Processed Then
			If ToReport Then
				Common.MessageToUser(DataIsBeingUpdatedMessage());
			EndIf;
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For calling from applied configuration update handlers.

// Resets user settings of specified reports.
//
// Parameters:
//  Var_Key - MetadataObjectReport - Metadata of the report for which settings must be reset.
//       - CatalogRef.ReportsOptions - Report option whose settings must be reset.
//       - String - Full name of the report option whose settings must be reset.
//                  Name format: <NameOfReport>/<NameOfOption>.
//                  If you pass "*", settings of all configuration reports will be reset.
//  SettingsTypes1 - Structure - Types of user settings that have to be reset.
//      Structure keys are also optional. The default value is in parentheses::
//      * FilterElement - Boolean - Flag indicating whether to clear the DataCompositionFilterItem setting. By default, False.
//      * SettingsParameterValue - Boolean - Flag indicating whether to clear the DataCompositionSettingsParameterValue setting. By default, False.
//      * SelectedFields - Boolean - Flag indicating whether to reset the DataCompositionSelectedFields setting. Taken from the "Other" key.
//      * Order - Boolean - Flag indicating whether to reset the DataCompositionOrder setting. Taken from the "Other" key.
//      * ConditionalAppearanceItem - Boolean - Flag indicating whether to reset the DataCompositionConditionalAppearanceItem setting. Taken from the "Other" key.
//      * OtherItems - Boolean - Flag indicating whether to reset other settings not explicitly described in the structure. By default, True.
//
Procedure ResetCustomSettings(Var_Key, SettingsTypes1 = Undefined) Export
	CommonClientServer.CheckParameter(
		"ReportsOptions.ResetCustomSettings",
		"Key",
		Var_Key,
		New TypeDescription("String, MetadataObject, CatalogRef.ReportsOptions"));
	
	ObjectsKeys = New Array; // The final list of keys to be cleared.
	
	// The list of keys can be filled from the query or you can pass one specific key from the outside.
	Query = New Query(
	"SELECT
	|	&ReportName AS ReportName,
	|	&IsExternalReport AS IsExternalReport,
	|	ReportsOptions.VariantKey
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	&Condition");
	
	ReportName = "CASE
	|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
	|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
	|		ELSE CAST(ReportsOptions.Report AS STRING(150))
	|	END";
	
	IsExternalReport = "False";
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then 
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportTableName = ModuleAdditionalReportsAndDataProcessors.AdditionalReportTableName();
		
		ReportName = StringFunctionsClientServer.SubstituteParametersToString("CASE
			|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
			|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
			|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
			|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
			|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(%1)
			|			THEN CAST(ReportsOptions.Report AS %1).ObjectName
			|		ELSE CAST(ReportsOptions.Report AS STRING(150))
			|	END", AdditionalReportTableName);
			
		IsExternalReport = StringFunctionsClientServer.SubstituteParametersToString("CASE
			|		WHEN VALUETYPE(ReportsOptions.Report) = TYPE(%1)
			|			THEN TRUE
			|		ELSE FALSE
			|	END", AdditionalReportTableName);
	
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ReportName", ReportName);
	Query.Text = StrReplace(Query.Text, "&IsExternalReport", IsExternalReport);
	
	If Var_Key = "*" Then
		Query.Text = StrReplace(Query.Text, "&Condition", "ReportType = VALUE(Enum.ReportsTypes.BuiltIn)");
		
	ElsIf TypeOf(Var_Key) = Type("MetadataObject") Then
		
		Query.Text = StrReplace(Query.Text, "&Condition", "Report = &Report");
		Query.SetParameter("Report", Common.MetadataObjectID(Var_Key));
		
	ElsIf TypeOf(Var_Key) = Type("CatalogRef.ReportsOptions") Then
		
		Query.Text = StrReplace(Query.Text, "&Condition", "Ref = &Ref");
		Query.SetParameter("Ref", Var_Key);
		
	ElsIf TypeOf(Var_Key) = Type("String") Then
		
		ObjectKey = "Report." + Var_Key + "/CurrentUserSettings";
		ObjectsKeys.Add(ObjectKey);
		
	Else
		Raise NStr("en = 'Invalid type of Report parameter';");
	EndIf;
	
	If Not IsBlankString(Query.Text) Then
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ReportKind = ?(Selection.IsExternalReport, "ExternalReport.", "Report.");
			ObjectKey = ReportKind + Selection.ReportName +"/"+ Selection.VariantKey + "/CurrentUserSettings";
			ObjectsKeys.Add(ObjectKey);
		EndDo;
	EndIf;
	
	If SettingsTypes1 = Undefined Then
		SettingsTypes1 = New Structure;
	EndIf;
	
	ReportsOptionsClientServer.AddKeyToStructure(SettingsTypes1, "FilterElement", True);
	ReportsOptionsClientServer.AddKeyToStructure(SettingsTypes1, "SettingsParameterValue", True);
	ResetOtherSettings = CommonClientServer.StructureProperty(SettingsTypes1, "OtherItems", True);
	
	SetPrivilegedMode(True);
	
	For Each ObjectKey In ObjectsKeys Do
		StorageSelection = SystemSettingsStorage.Select(New Structure("ObjectKey", ObjectKey));
		
		SuccessiveReadingErrors = 0;
		While True Do
			Try
				GotSelectionItem = StorageSelection.Next();
				SuccessiveReadingErrors = 0;
			Except
				GotSelectionItem = Undefined;
				SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
				WriteToLog(EventLogLevel.Error, 
					NStr("en = 'Cannot read custom report settings due to:';")
					+ Chars.LF
					+ ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
			
			If GotSelectionItem = False Then
				Break;
			ElsIf GotSelectionItem = Undefined Then
				If SuccessiveReadingErrors > 100 Then
					Break;
				Else
					Continue;
				EndIf;
			EndIf;
			
			DCUserSettings = StorageSelection.Settings; // DataCompositionUserSettings
			If TypeOf(DCUserSettings) <> Type("DataCompositionUserSettings") Then
				Continue;
			EndIf;
			
			HasChanges = False;
			Count = DCUserSettings.Items.Count();
			For Number = 1 To Count Do
				ReverseIndex = Count - Number;
				DCUserSetting = DCUserSettings.Items.Get(ReverseIndex);
				Type = ReportsClientServer.SettingTypeAsString(TypeOf(DCUserSetting));
				Reset = CommonClientServer.StructureProperty(SettingsTypes1, Type, ResetOtherSettings);
				
				If Reset Then
					DCUserSettings.Items.Delete(ReverseIndex);
					HasChanges = True;
				EndIf;
			EndDo;
			
			If HasChanges Then
				Common.SystemSettingsStorageSave(
					StorageSelection.ObjectKey,
					StorageSelection.SettingsKey,
					DCUserSettings,
					,
					StorageSelection.User);
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Moves user options from standard options storage to the subsystem storage.
// Used on partial deployment - when the ReportsOptionsStorage is set not for the entire configuration,
// but in the properties of specific reports connected to the subsystem.
// It is recommended for using in specific version update handlers.
//
// Parameters:
//  ReportsNames - String - Comma-delimited report names.
//                          If the parameter is not specified, all reports are moved from standard
//                          storage and then it is cleared up.
//
// Example:
//  Move all user report options upon update.
//  ReportsOptions.MoveUsersOptionsFromStandardStorage();
//  Move user report options transferred to the Report options subsystem storage.
//  ReportsOptions.MoveUsersOptionsFromStandardStorage("EventLogAnalysis, ExpiringTasksOnDate");
//
Procedure MoveUsersOptionsFromStandardStorage(ReportsNames = "") Export
	ProcedurePresentation = NStr("en = 'Direct conversion of report options';");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// The result that will be saved in the storage.
	VariantsTable = Common.CommonSettingsStorageLoad("TransferReportOptions", "OptionsTable", , , "");
	If TypeOf(VariantsTable) <> Type("ValueTable") Or VariantsTable.Count() = 0 Then
		VariantsTable = New ValueTable;
		VariantsTable.Columns.Add("Report",     TypesDetailsString());
		VariantsTable.Columns.Add("Variant",   TypesDetailsString());
		VariantsTable.Columns.Add("Author",     TypesDetailsString());
		VariantsTable.Columns.Add("Setting", New TypeDescription("ValueStorage"));
		VariantsTable.Columns.Add("ReportPresentation",   TypesDetailsString());
		VariantsTable.Columns.Add("VariantPresentation", TypesDetailsString());
		VariantsTable.Columns.Add("AuthorID",   New TypeDescription("UUID"));
	EndIf;
	
	RemoveAll = (ReportsNames = "" Or ReportsNames = "*");
	ArrayOfObjectsKeysToDelete = New Array;
	
	StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(ReportsNames));
	SuccessiveReadingErrors = 0;
	While True Do
		Try
			GotSelectionItem = StorageSelection.Next();
			SuccessiveReadingErrors = 0;
		Except
			GotSelectionItem = Undefined;
			SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
			WriteToLog(EventLogLevel.Error,
				NStr("en = 'Cannot read report options from the standard storage due to:';")
				+ Chars.LF
				+ ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		EndTry;
		
		If GotSelectionItem = False Then
			If ReportsNames = "" Or ReportsNames = "*" Then
				Break;
			Else
				StorageSelection = ReportsVariantsStorage.Select(NewFilterByObjectKey(ReportsNames));
				Continue;
			EndIf;
		ElsIf GotSelectionItem = Undefined Then
			If SuccessiveReadingErrors > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Skip unattached built-in reports.
		ReportMetadata = Common.MetadataObjectByFullName(StorageSelection.ObjectKey); // MetadataObjectReport 
		If ReportMetadata <> Undefined Then
			StorageMetadata1 = ReportMetadata.VariantsStorage;
			If StorageMetadata1 = Undefined Or StorageMetadata1.Name <> "ReportsVariantsStorage" Then
				RemoveAll = False;
				Continue;
			EndIf;
		EndIf;
		
		// All external report options are moved as it's impossible to determine
		// whether they are connected to the subsystem's storage.
		ArrayOfObjectsKeysToDelete.Add(StorageSelection.ObjectKey);
		
		IBUser = InfoBaseUsers.FindByName(StorageSelection.User);
		If IBUser = Undefined Then
			User = Catalogs.Users.FindByDescription(StorageSelection.User, True);
			If Not ValueIsFilled(User) Then
				Continue;
			EndIf;
			UserIdentificator = User.IBUserID;
		Else
			UserIdentificator = IBUser.UUID;
		EndIf;
		
		TableRow = VariantsTable.Add();
		TableRow.Report     = StorageSelection.ObjectKey;
		TableRow.Variant   = StorageSelection.SettingsKey;
		TableRow.Author     = StorageSelection.User;
		TableRow.Setting = New ValueStorage(StorageSelection.Settings, New Deflation(9));
		TableRow.VariantPresentation = StorageSelection.Presentation;
		TableRow.AuthorID   = UserIdentificator;
		If ReportMetadata = Undefined Then
			TableRow.ReportPresentation = StorageSelection.ObjectKey;
		Else
			TableRow.ReportPresentation = ReportMetadata.Presentation();
		EndIf;
	EndDo;
	
	// Clear the standard storage.
	If RemoveAll Then
		ReportsVariantsStorage.Delete(Undefined, Undefined, Undefined);
	Else
		For Each ObjectKey In ArrayOfObjectsKeysToDelete Do
			ReportsVariantsStorage.Delete(ObjectKey, Undefined, Undefined);
		EndDo;
	EndIf;
	
	// Runtime result.
	WriteProcedureCompletionToLog(ProcedurePresentation);
	
	// Import options to the subsystem storage.
	ImportUserOptions(VariantsTable);
EndProcedure

// Imports to the subsystem storage reports options previously saved
// from the system option storage to the common settings storage.
// It is used to import report options upon full or partial deployment.
// At full deployment it can be called from the TransferReportOptions data processor.
// It is recommended for using in specific version update handlers.
//
// Parameters:
//  UserOptions1 - ValueTable
//                           - Undefined - Optional. Used in utility scripts.:
//       * Report - String - Full report name in the format: Report.<ReportName>.
//       * Variant - String - Report option name.
//       * Author - String - Username.
//       * Setting - ValueStorage - DataCompositionUserSettings.
//       * ReportPresentation - String - Report presentation.
//       * VariantPresentation - String - Option presentation.
//       * AuthorID - UUID - User ID.
//
Procedure ImportUserOptions(UserOptions1 = Undefined) Export
	If UserOptions1 = Undefined Then
		UserOptions1 = Common.CommonSettingsStorageLoad(
			"TransferReportOptions", "UserOptions1", , , "");
	EndIf;
	
	If TypeOf(UserOptions1) <> Type("ValueTable")
		Or UserOptions1.Count() = 0 Then
		Return;
	EndIf;
	
	ProcedurePresentation = NStr("en = 'Finalize report option conversion';");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Replace the column names with the names from the catalog structure.
	Columns = UserOptions1.Columns; // ValueTableColumnCollection
	
	Columns.Find("Report").Name = "ReportFullName";
	Columns.Find("Variant").Name = "VariantKey";
	Columns.Find("VariantPresentation").Name = "Description";
	
	// Convert report names into "Metadata object IDs" catalog references.
	Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	Columns.Add("Defined", New TypeDescription("Boolean"));
	Columns.Add("ReportType", Metadata.Catalogs.ReportsOptions.Attributes.ReportType.Type);
	
	For Each OptionDetails In UserOptions1 Do
		ReportInformation = ReportInformation(OptionDetails.ReportFullName);
		If ValueIsFilled(ReportInformation.ErrorText) Then
			WriteToLog(EventLogLevel.Error, ReportInformation.ErrorText);
			Continue;
		EndIf;
		
		OptionDetails.Defined = True;
		OptionDetails.Report = ReportInformation.Report;
		OptionDetails.ReportType = ReportInformation.ReportType;
	EndDo;
	UserOptions1.Sort("ReportFullName Asc, VariantKey Asc");
	
	ReportsSubsystems = PlacingReportsToSubsystems();
	
	Query = New Query("
	|SELECT
	|	UserOptions1.Description,
	|	UserOptions1.ReportPresentation,
	|	UserOptions1.Report,
	|	UserOptions1.ReportFullName,
	|	UserOptions1.ReportType,
	|	UserOptions1.VariantKey,
	|	UserOptions1.Author AS AuthorPresentation1,
	|	UserOptions1.AuthorID,
	|	UserOptions1.Setting AS Settings
	|INTO UserOptions1
	|FROM
	|	&UserOptions1 AS UserOptions1
	|WHERE
	|	UserOptions1.Defined
	|;
	|
	|SELECT
	|	UserOptions1.Description,
	|	UserOptions1.ReportPresentation,
	|	UserOptions1.Report,
	|	UserOptions1.ReportFullName,
	|	UserOptions1.ReportType,
	|	UserOptions1.VariantKey,
	|	UserOptions1.Settings,
	|	Variants.Ref,
	|	UserOptions1.AuthorPresentation1,
	|	Users.Ref AS Author
	|FROM
	|	UserOptions1 AS UserOptions1
	|	LEFT JOIN Catalog.ReportsOptions AS Variants
	|		ON Variants.Report = UserOptions1.Report
	|		AND Variants.VariantKey = UserOptions1.VariantKey
	|		AND Variants.ReportType = UserOptions1.ReportType
	|	LEFT JOIN Catalog.Users AS Users
	|		ON Users.IBUserID = UserOptions1.AuthorID
	|		AND NOT Users.DeletionMark
	|");
	Query.SetParameter("UserOptions1", UserOptions1);
	
	OptionDetails = Query.Execute().Select();
	While OptionDetails.Next() Do 
		If ValueIsFilled(OptionDetails.Ref) Then
			Continue;
		EndIf;
		
		OptionStorage = Catalogs.ReportsOptions.CreateItem();
		FillPropertyValues(OptionStorage, OptionDetails, "Description, Report, ReportType, VariantKey, Author");
		
		OptionStorage.Custom = True;
		OptionStorage.AuthorOnly = True;
		
		If TypeOf(OptionDetails.Settings) = Type("ValueStorage") Then
			OptionStorage.Settings = OptionDetails.Settings;
		Else
			OptionStorage.Settings = New ValueStorage(OptionDetails.Settings);
		EndIf;
		
		// As custom report options are being moved,
		// the location settings are obtained only from the report's metadata.
		FoundSubsystems = ReportsSubsystems.FindRows(New Structure("ReportFullName", OptionDetails.ReportFullName));
		For Each SubsystemDetails In FoundSubsystems Do
			Subsystem = Common.MetadataObjectID(SubsystemDetails.SubsystemMetadata1);
			If TypeOf(Subsystem) = Type("String") Then
				Continue;
			EndIf;
			Section = OptionStorage.Location.Add();
			Section.Use = True;
			Section.Subsystem = Subsystem;
		EndDo;
		
		// Report options are created, thus competitive work with them is excluded.
		OptionStorage.Write();
	EndDo;
	
	Common.CommonSettingsStorageDelete("TransferReportOptions", "OptionsTable", "");
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

#EndRegion

#Region Internal

// The function gets the report object from the report option reference.
//
// Parameters:
//   Parameters - See ReportGenerationParameters
//
// Returns:
//   Structure:
//       * RefOfReport - Arbitrary     - Report reference.
//       * FullName    - String           - Report full name.
//       * Metadata   - MetadataObject - Report metadata.
//       * Object       - ReportObject
//                      - ExternalReport - Report object.:
//           ** SettingsComposer - DataCompositionSettingsComposer - Report settings.
//           ** DataCompositionSchema - DataCompositionSchema - Report schema.
//       * VariantKey - String           - Predefined report option name or a user report option ID.
//       * SchemaURL   - String           - Address in the temporary storage where the report schema is placed.
//       * Success        - Boolean           - True if the report is attached.
//       * ErrorText  - String           - Error text.
//
Function AttachReportAndImportSettings(Val Parameters) Export
	
	ReportGenerationParameters = ReportGenerationParameters();
	FillPropertyValues(ReportGenerationParameters, Parameters);
	Parameters = ReportGenerationParameters;
	
	Result = New Structure("OptionRef1, RefOfReport, VariantKey, FormSettings,
		|Object, Metadata, FullName,
		|DCSchema, SchemaURL, SchemaModified, DCSettings, DCUserSettings,
		|ErrorText, Success");
	FillPropertyValues(Result, Parameters);
	Result.Success = False;
	Result.SchemaModified = False;
	PredefinedOptionKey = "";
	
	// Support the ability to directly select additional reports references in reports mailings.
	If TypeOf(Result.DCSettings) <> Type("DataCompositionSettings")
		And Result.VariantKey = Undefined
		And Result.Object = Undefined
		And TypeOf(Result.OptionRef1) = AdditionalReportRefType() Then
		// Automatically detecting a key and option reference if only a reference of additional report is passed.
		Result.RefOfReport = Result.OptionRef1;
		Result.OptionRef1 = Undefined;
		ConnectingReport = AttachReportObject(Result.RefOfReport, True);
		If Not ConnectingReport.Success Then
			Result.ErrorText = ConnectingReport.ErrorText;
			Return Result;
		EndIf;
		FillPropertyValues(Result, ConnectingReport, "Object, Metadata, FullName");
		ConnectingReport.Clear();
		If Result.Object.DataCompositionSchema = Undefined Then
			Result.Success = True;
			Return Result;
		EndIf;
		DCSettingsOption = Result.Object.DataCompositionSchema.SettingVariants[0];
		Result.VariantKey = DCSettingsOption.Name;
		Result.DCSettings  = DCSettingsOption.Settings;
		Result.OptionRef1 = ReportVariant(Result.RefOfReport, Result.VariantKey);
		PredefinedOptionKey = Result.VariantKey;
	EndIf;
	
	MustReadReportRef = (Result.Object = Undefined And Result.RefOfReport = Undefined);
	MustReadSettings = (TypeOf(Result.DCSettings) <> Type("DataCompositionSettings"));
	If MustReadReportRef Or MustReadSettings Then
		If TypeOf(Result.OptionRef1) <> Type("CatalogRef.ReportsOptions")
			Or Not ValueIsFilled(Result.OptionRef1) Then
			If Not MustReadReportRef And Result.VariantKey <> Undefined Then
				Result.OptionRef1 = ReportVariant(Result.RefOfReport, Result.VariantKey);
			EndIf;
			If Result.OptionRef1 = Undefined Then
				Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Values of parameters ""%2"" are not specified when calling the ""%1"" procedure.';"),
					"ReportsOptions.AttachReportAndImportSettings",
					"OptionRef1, RefOfReport, VariantKey");
				Return Result;
			EndIf;
		EndIf;
		PropertiesNames = "VariantKey,Custom,Parent,Parent.VariantKey" + ?(MustReadReportRef, ",Report", "")
			+ ?(MustReadSettings, ",Settings", "");  // ACC:1297 - These are attribute names. They do not require NStr.
		OptionProperties = Common.ObjectAttributesValues(Result.OptionRef1, PropertiesNames);
		Result.VariantKey = OptionProperties.VariantKey;
		If OptionProperties.Custom And ValueIsFilled(OptionProperties.Parent) Then
			If TypeOf(OptionProperties.ParentVariantKey) = Type("String")
			   And ValueIsFilled(OptionProperties.ParentVariantKey) Then
				PredefinedOptionKey = OptionProperties.ParentVariantKey;
			EndIf;
		Else
			PredefinedOptionKey = Result.VariantKey;
		EndIf;
		If MustReadReportRef Then
			Result.RefOfReport = OptionProperties.Report;
		EndIf;
		If MustReadSettings Then
			Result.DCSettings = OptionProperties.Settings.Get();
			MustReadSettings = (TypeOf(Result.DCSettings) <> Type("DataCompositionSettings"));
		EndIf;
	EndIf;
	
	If Result.Object = Undefined Then
		ConnectingReport = AttachReportObject(Result.RefOfReport, True);
		If Not ConnectingReport.Success Then
			Result.ErrorText = ConnectingReport.ErrorText;
			Return Result;
		EndIf;
		FillPropertyValues(Result, ConnectingReport, "Object, Metadata, FullName");
		ConnectingReport.Clear();
		ConnectingReport = Undefined;
	ElsIf Result.FullName = Undefined Then
		Result.Metadata = Result.Object.Metadata();
		Result.FullName = Result.Metadata.FullName();
	EndIf;
	
	ReportObject = Result.Object;
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	Result.FormSettings = ReportFormSettings(Result.RefOfReport, Result.VariantKey, ReportObject);
	
	If ReportObject.DataCompositionSchema = Undefined Then
		Result.Success = True;
		Return Result;
	EndIf;
	
	// Read settings.
	If MustReadSettings Then
		DCSettingsOptions = ReportObject.DataCompositionSchema.SettingVariants;
		DCSettingsOption = DCSettingsOptions.Find(PredefinedOptionKey);
		
		If DCSettingsOption = Undefined Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The report option ""%1"" (key: ""%2"") is not found in the schema of the ""%3"" report.';"),
				String(Result.OptionRef1),
				Result.VariantKey,
				String(Result.RefOfReport));
			Return Result;
		EndIf;
		
		If DCSettingsOptions.Count() = 1
			Or DCSettingsOptions.IndexOf(DCSettingsOption) = 0 Then 
			
			Result.DCSettings = DCSettingsComposer.Settings;
		Else
			Result.DCSettings = DCSettingsOption.Settings;
		EndIf;
	EndIf;
	
	// Schema initialization.
	SchemaURLFilled = (TypeOf(Result.SchemaURL) = Type("String") And IsTempStorageURL(Result.SchemaURL));
	If SchemaURLFilled And TypeOf(Result.DCSchema) <> Type("DataCompositionSchema") Then
		Result.DCSchema = GetFromTempStorage(Result.SchemaURL);
	EndIf;
	
	Result.SchemaModified = (TypeOf(Result.DCSchema) = Type("DataCompositionSchema"));
	If Result.SchemaModified Then
		ReportObject.DataCompositionSchema = Result.DCSchema;
	EndIf;
	
	If Not SchemaURLFilled And TypeOf(ReportObject.DataCompositionSchema) = Type("DataCompositionSchema") Then
		FormIdentifier = Parameters.FormIdentifier;
		If TypeOf(FormIdentifier) = Type("UUID") Then
			SchemaURLFilled = True;
			Result.SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema, FormIdentifier);
		ElsIf Result.SchemaModified Then
			SchemaURLFilled = True;
			Result.SchemaURL = PutToTempStorage(ReportObject.DataCompositionSchema);
		EndIf;
	EndIf;
	
	If SchemaURLFilled Then
		DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(Result.SchemaURL));
	EndIf;
	
	ReportsServer.FillinAdditionalProperties(ReportObject,
		Result.DCSettings,
		Result.VariantKey,
		PredefinedOptionKey);
	
	If Result.FormSettings.Events.BeforeImportSettingsToComposer Then
		ReportObject.BeforeImportSettingsToComposer(
			Result,
			Parameters.SchemaKey,
			Result.VariantKey,
			Result.DCSettings,
			Result.DCUserSettings);
	EndIf;
	
	FixedDCSettings = Parameters.FixedDCSettings;
	If TypeOf(FixedDCSettings) = Type("DataCompositionSettings")
		And DCSettingsComposer.FixedSettings <> FixedDCSettings Then
		DCSettingsComposer.LoadFixedSettings(FixedDCSettings);
	EndIf;
	
	ReportsClientServer.LoadSettings(DCSettingsComposer, Result.DCSettings, Result.DCUserSettings);
	
	If Result.FormSettings.Events.AfterLoadSettingsInLinker Then
		ReportObject.AfterLoadSettingsInLinker(New Structure);
	EndIf;
	
	Result.Success = True;
	Return Result;
EndFunction

// Updates additional report options when writing it.
//
// Parameters:
//  CurrentObject - CatalogObject.AdditionalReportsAndDataProcessors - Object of the additional report storage. 
//  Cancel - Boolean - Flag indicating whether handler execution was canceled.
//  ExternalObject - ExternalReport - Flag indicating whether handler execution was canceled.
//  
// Usage locations::
//   Catalog.AdditionalReportsAndDataProcessors.OnWriteGlobalReport().
//
Procedure OnWriteAdditionalReport(CurrentObject, Cancel, ExternalObject) Export
	
	If Not ReportsOptionsCached.InsertRight1() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Insufficient rights to save options of additional report %1.';"),
			CurrentObject.Description);
		WriteToLog(EventLogLevel.Error, ErrorText, CurrentObject.Ref);
		Common.MessageToUser(ErrorText);
		Return;
	EndIf;
	
	DeletionMark = CurrentObject.DeletionMark;
	If ExternalObject = Undefined
		Or Not CurrentObject.UseOptionStorage
		Or Not CurrentObject.AdditionalProperties.PublicationAvailable Then
		DeletionMark = True;
	EndIf;
	
	PredefinedOptions = New Map;
	If DeletionMark = False And ExternalObject <> Undefined Then
		ReportMetadata = ExternalObject.Metadata(); 
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema; // MetadataObjectTemplate
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsOption In DCSchema.SettingVariants Do
				PredefinedOptions[DCSettingsOption.Name] = DCSettingsOption.Presentation;
			EndDo;
		Else
			PredefinedOptions[""] = ReportMetadata.Presentation();
		EndIf;
	EndIf;
	
	// When clearing a deletion mark from an additional report,
	// it is not cleared from custom options that were marked interactively.
	QueryText =
	"SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND (&DeletionMark
	|			OR NOT ReportsOptions.Custom
	|			OR NOT ReportsOptions.InteractiveDeletionMark)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Report", CurrentObject.Ref);
	// When marking an additional report for deletion, all report options are also marked for deletion.
	Query.SetParameter("DeletionMark", DeletionMark = True);
	
	// Set deletion mark.
	AdditionalReportOptions = Query.Execute().Unload();
	
	Block = New DataLock;
	LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
	LockItem.DataSource = AdditionalReportOptions;
	LockItem.UseFromDataSource("Ref", "Ref");
	Block.Lock();
	
	For Each ReportVariant In AdditionalReportOptions Do
		
		OptionDeletionMark = DeletionMark;
		Presentation = PredefinedOptions[ReportVariant.VariantKey];
		If Not OptionDeletionMark And Not ReportVariant.Custom And Presentation = Undefined Then
			// A predefined item that doesn't exist in the list of predefined items for this report.
			OptionDeletionMark = True;
		EndIf;
		
		If ReportVariant.DeletionMark <> OptionDeletionMark Then
			OptionObject = ReportVariant.Ref.GetObject();
			OptionObject.AdditionalProperties.Insert("PredefinedObjectsFilling", True);
			If OptionDeletionMark Then
				OptionObject.AdditionalProperties.Insert("IndexSchema", False);
			Else
				OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			EndIf;
			OptionObject.SetDeletionMark(OptionDeletionMark);
		EndIf;
		
		If Presentation <> Undefined Then
			PredefinedOptions.Delete(ReportVariant.VariantKey);
			
			OptionObject = ReportVariant.Ref.GetObject();
			
			If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
				ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
				ModuleNationalLanguageSupportServer.OnReadPresentationsAtServer(OptionObject);
			EndIf;
			
			OptionObject.Description = Presentation;
			OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			
			If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
				ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
				ModuleNationalLanguageSupportServer.BeforeWriteAtServer(OptionObject);
			EndIf;
			
			OptionObject.Write();
		EndIf;
	EndDo;
	
	If Not DeletionMark Then
		// Register new report options.
		For Each Presentation In PredefinedOptions Do
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.Report = CurrentObject.Ref;
			OptionObject.ReportType = Enums.ReportsTypes.Additional;
			OptionObject.VariantKey = Presentation.Key;
			OptionObject.Description = Presentation.Value;
			OptionObject.Custom = False;
			CurrentObject.AdditionalProperties.Property("ReportOptionAssignment", OptionObject.Purpose);
			OptionObject.AdditionalProperties.Insert("ReportObject", ExternalObject);
			
			If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
				ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
				ModuleNationalLanguageSupportServer.BeforeWriteAtServer(OptionObject);
			EndIf;
			
			OptionObject.Write();
		EndDo;
	EndIf;
	
EndProcedure

// Gets options of the passed report and their presentations.
//
// Parameters:
//  FullReportName - See MetadataObjectReport.FullName()
//  InfoBaseUser - String - Name of the infobase user.
//  ReportOptionTable - ValueTable - Table that stores report option data:
//       * ObjectKey - String - Report key in format "Report.ReportName".
//       * VariantKey - String - Report option key.
//       * Presentation - String - Report option presentation.
//       * StandardProcessing - Boolean - If True, a report option is saved to the standard storage.
//  StandardProcessing - Boolean - If True, the report option is saved to the standard storage.
//
Procedure UserReportOptions(FullReportName, InfoBaseUser, ReportOptionTable, StandardProcessing) Export
	ReportKey = FullReportName;
	AllReportOptions = ReportOptionsKeys(ReportKey, InfoBaseUser);
	
	For Each ReportVariant In AllReportOptions Do
		CatalogItem = Catalogs.ReportsOptions.FindByDescription(ReportVariant.Presentation);
		If CatalogItem = Undefined Then 
			Continue;
		EndIf;
		
		StandardProcessing = False;
		
		If Not CatalogItem.AuthorOnly Then 
			Continue;
		EndIf;
		
		ReportOptionRow = ReportOptionTable.Add();
		ReportOptionRow.ObjectKey = FullReportName;
		ReportOptionRow.VariantKey = ReportVariant.Value;
		ReportOptionRow.Presentation = ReportVariant.Presentation;
		ReportOptionRow.StandardProcessing = False;
	EndDo;
	
	If Not StandardProcessing Then 
		Return;
	EndIf;
	
	MetadataOfReport = Common.MetadataObjectByFullName(FullReportName);
	If (MetadataOfReport <> Undefined And MetadataOfReport.VariantsStorage <> Undefined)
		Or TypeOf(ReportsVariantsStorage) <> Type("StandardSettingsStorageManager") Then 
		
		StandardProcessing = False;
	EndIf;
EndProcedure

// Deletes the passed report option from the report option storage.
//
Procedure DeleteUserReportOption(ReportOptionInfo, InfoBaseUser, StandardProcessing) Export
	
	If ReportOptionInfo.StandardProcessing Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	DeleteReportOption(ReportOptionInfo.ObjectKey, ReportOptionInfo.VariantKey, InfoBaseUser);
	
EndProcedure

// Generates additional parameters to open a report option.
//
// Parameters:
//   OptionRef - CatalogRef.ReportsOptions - Reference of the report option being opened.
//
Function OpeningParameters(OptionRef) Export
	OpeningParameters = New Structure("Ref, Report, ReportType, ReportName, VariantKey, MeasurementsKey");
	If TypeOf(OptionRef) = AdditionalReportRefType() Then
		// Support the ability to directly select additional reports references in reports mailings.
		OpeningParameters.Report     = OptionRef;
		OpeningParameters.ReportType = "Additional";
	Else
		QueryText =
		"SELECT ALLOWED
		|	ReportsOptions.Report,
		|	ReportsOptions.ReportType,
		|	ReportsOptions.VariantKey,
		|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Ref = &Ref";
		
		Query = New Query;
		Query.SetParameter("Ref", OptionRef);
		Query.Text = QueryText;
		
		Selection = Query.Execute().Select();
		If Not Selection.Next() Then
			SetPrivilegedMode(True);
			Selection = Query.Execute().Select();
			SetPrivilegedMode(False);
			If Selection.Next() Then
				Raise(NStr("en = 'Insufficient rights to view the report.';"), ErrorCategory.AccessViolation);
			Else
				Raise NStr("en = 'The report option does not exist.';");
			EndIf;
		EndIf;
		
		FillPropertyValues(OpeningParameters, Selection);
		OpeningParameters.Ref    = OptionRef;
		OpeningParameters.ReportType = ReportsOptionsClientServer.ReportByStringType(Selection.ReportType, Selection.Report);
	EndIf;
	
	OnAttachReport(OpeningParameters);
	
	Return OpeningParameters;
EndFunction

// Attaching additional reports.
Procedure OnAttachReport(OpeningParameters) Export
	
	OpeningParameters.Insert("Connected", False);
	
	If OpeningParameters.ReportType = "BuiltIn"
		Or OpeningParameters.ReportType = "Extension" Then
		
		MetadataOfReport = Common.MetadataObjectByID(
			OpeningParameters.Report, False);
		
		If TypeOf(MetadataOfReport) <> Type("MetadataObject") Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot open report %1.
					|The configuration extension that contains the report might have been disabled.';"),
				OpeningParameters.Report);
		EndIf;
		OpeningParameters.ReportName = MetadataOfReport.Name;
		OpeningParameters.Connected = True; // Configuration reports are always attached.
		
	ElsIf OpeningParameters.ReportType = "Extension" Then
		If Metadata.Reports.Find(OpeningParameters.ReportName) = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot open report %1.
					|The configuration extension that contains the report might have been disabled.';"),
				OpeningParameters.ReportName);
		EndIf;
		OpeningParameters.Connected = True;
	ElsIf OpeningParameters.ReportType = "Additional" Then
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnAttachReport(OpeningParameters);
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures of internal interface.

Function SettingsUpdateParameters() Export
	
	Settings = New Structure;
	Settings.Insert("Configuration", True);
	Settings.Insert("Extensions", False);
	Settings.Insert("SharedData", True);
	Settings.Insert("SeparatedData", True);
	Settings.Insert("Nonexclusive", True);
	Settings.Insert("Deferred2", False);
	Settings.Insert("IndexSchema", False);
	Settings.Insert("FillPresentations1", True);
	
	If Common.DataSeparationEnabled() Then
		If Common.SeparatedDataUsageAvailable() Then
			Settings.SharedData = False;
		Else // Shared session.
			Settings.SeparatedData = False;
		EndIf;
	ElsIf Common.IsStandaloneWorkplace() Then // SWP.
		Settings.SharedData = False;
	EndIf;
	
	Settings.Extensions = Settings.SeparatedData;
	
	Return Settings;
	
EndFunction

// Updates subsystem metadata caches considering application operation mode.
// Usage example: after clearing settings storage.
//
// Parameters:
//   Settings - Structure:
//     * Configuration - Boolean - Update the PredefinedReportsOptions shared catalog.
//     * Extensions   - Boolean - Update the PredefinedExtensionsReportsOptions separated catalog.
//     * SharedData       - Boolean - Update the PredefinedReportsOptions shared catalog.
//     * SeparatedData - Boolean - Update the ReportsOptions separated catalog.
//     * Nonexclusive - Boolean - Update the list of report options, their descriptions, and details.
//     * Deferred2  - Boolean - Populate descriptions of fields, parameters, filters, and search keywords.
//     * IndexSchema - Boolean - Always index schemas (ignore the hash sums).
//
Function Refresh(Val Settings = Undefined) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	If Settings = Undefined Then
		Settings = SettingsUpdateParameters();
	EndIf;
	
	Result = New Structure;
	Result.Insert("HasChanges", False);
	
	If Settings.Nonexclusive Then
		
		If Settings.SharedData Then
			
			If Settings.Configuration Then
				InterimResult = CommonDataNonexclusiveUpdate("ConfigurationCommonData", Undefined);
				Result.Insert("NonexclusiveUpdateCommonDataConfiguration", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = CommonDataNonexclusiveUpdate("ExtensionsCommonData", Undefined);
				Result.Insert("NonexclusiveUpdateCommonDataExtensions", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		If Settings.SeparatedData Then
			
			If Settings.Configuration Then
				InterimResult = UpdateReportsOptions("SeparatedConfigurationData");
				Result.Insert("NonexclusiveUpdateSeparatedDataConfiguration", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = UpdateReportsOptions("SeparatedExtensionData");
				Result.Insert("NonexclusiveUpdateSeparatedDataExtensions", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Settings.Deferred2 Then
		
		If Settings.SharedData Then
			
			If Settings.Configuration Then
				InterimResult = UpdateSearchIndex("ConfigurationCommonData", Settings.IndexSchema);
				Result.Insert("DeferredUpdateCommonDataConfiguration", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = UpdateSearchIndex("ExtensionsCommonData", Settings.IndexSchema);
				Result.Insert("DeferredUpdateCommonDataExtensions", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
		If Settings.SeparatedData Then
			
			If Settings.Configuration Then
				InterimResult = UpdateSearchIndex("SeparatedConfigurationData", Settings.IndexSchema);
				Result.Insert("DeferredUpdateSeparatedDataConfiguration", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
			If Settings.Extensions Then
				InterimResult = UpdateSearchIndex("SeparatedExtensionData", Settings.IndexSchema);
				Result.Insert("DeferredUpdateSeparatedDataExtensions", InterimResult);
				If InterimResult <> Undefined And InterimResult.HasChanges Then
					Result.HasChanges = True;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Settings.FillPresentations1 Then 
		SchedulePresentationsFilling();
	EndIf;
	
	Return Result;
EndFunction

Procedure ResetInfillViews(Val Mode) Export
	SetPresentationsFillingFlag(Undefined, True, Mode);
EndProcedure

// Generates a report with the specified parameters.
//
// Parameters:
//   Parameters - See ReportGenerationParameters.
//   CheckFilling - Boolean - If True, validate the report parameters before generating the report.
//   GetCheckBoxEmpty - Boolean - If True, returns the flag indicating whether the generated report is empty.
//
// Returns:
//   Structure - Generation result.
//
Function GenerateReport(Val Parameters, Val CheckFilling, Val GetCheckBoxEmpty) Export
	Result = New Structure("SpreadsheetDocument, Details,
		|OptionRef1, RefOfReport, VariantKey,
		|Object, Metadata, FullName,
		|DCSchema, SchemaURL, SchemaModified, FormSettings,
		|DCSettings, VariantModified,
		|DCUserSettings, UserSettingsModified,
		|ErrorText, Success, DataStillUpdating");
	
	Result.Success = False;
	Result.SpreadsheetDocument = New SpreadsheetDocument;
	Result.VariantModified = False;
	Result.UserSettingsModified = False;
	Result.DataStillUpdating = False;
	
	If GetCheckBoxEmpty Then
		Result.Insert("IsEmpty", False);
	EndIf;
	
	ReportGenerationParameters = ReportGenerationParameters();
	FillPropertyValues(ReportGenerationParameters, Parameters);
	Parameters = ReportGenerationParameters;
	
	Connection = ?(Parameters.Connection <> Undefined, Parameters.Connection, 
		AttachReportAndImportSettings(Parameters));
	FillPropertyValues(Result, Connection); // "Object, Metadata, FullName, OptionKey, DCSchema, SchemaURL, SchemaModified, FormSettings"
	
	If Not Connection.Success Then
		Result.ErrorText = NStr("en = 'Cannot generate the report:';") + Chars.LF + Connection.ErrorText;
		Return Result;
	EndIf;
	
	ReportObject = Result.Object;
	DCSettingsComposer = ReportObject.SettingsComposer;
	
	PopulateExternalReportBinaryData(ReportObject, Parameters);
	
	AuxProperties = DCSettingsComposer.UserSettings.AdditionalProperties;
	AuxProperties.Insert("VariantKey", Result.VariantKey);
	AuxProperties.Insert("TablesToUse", Parameters.TablesToUse);
	
	// Validate data used for report generation.
	
	If CheckFilling Then
		OriginalUserMessages = GetUserMessages(True);
		CheckPassed = ReportObject.CheckFilling();
		UserMessages = GetUserMessages(True);
		
		For Each Message In OriginalUserMessages Do
			Message.Message();
		EndDo;
		
		If Not CheckPassed Then
			Result.ErrorText = NStr("en = 'Population check failed:';");
			For Each Message In UserMessages Do
				Result.ErrorText = Result.ErrorText + Chars.LF + Message.Text;
			EndDo;
			Return Result;
		EndIf;
	EndIf;
	
	Try
		TablesToUse = TablesToUse(Result.DCSchema);
		TablesToUse.Add(Result.FullName);
		
		If Result.FormSettings.Events.OnDefineUsedTables Then
			ReportObject.OnDefineUsedTables(Result.VariantKey, TablesToUse);
		EndIf;
		
		Result.DataStillUpdating = CheckUsedTables(TablesToUse, False);
	Except
		ErrorText = NStr("en = 'Cannot identify referenced tables:';");
		ErrorText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
		WriteToLog(EventLogLevel.Error, ErrorText, Result.OptionRef1);
	EndTry;
	
	// Generate and estimate the speed.
	RunMeasurements = RunMeasurements();
	If RunMeasurements Then
		KeyOperationName = Parameters.KeyOperationName;
		If Not ValueIsFilled(KeyOperationName) Then
			KeyOperationName = ReportsOptionsInternal.MeasurementsKey(Result.FullName,
				 Result.VariantKey) + ".Generation1";
		EndIf;
		KeyOperationComment = Parameters.KeyOperationComment;
		If Not ValueIsFilled(KeyOperationComment)
		   And Result.DCSettings <> Undefined
		   And Result.DCSettings.AdditionalProperties.Property("PredefinedOptionKey") Then
			KeyOperationComment = New Map;
			KeyOperationComment.Insert("PredefinedOptionKey",
				Result.DCSettings.AdditionalProperties.PredefinedOptionKey);
		EndIf;
		ModulePerformanceMonitor = Common.CommonModule("PerformanceMonitor");
		BeginTime = ModulePerformanceMonitor.StartTimeMeasurement();
	EndIf;
	
	Try
		ReportObject.ComposeResult(Result.SpreadsheetDocument, Result.Details);
	Except
		Result.ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
		Result.Success = False;
		
		WriteLogEvent(
			NStr("en = 'Report options.Generate report';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Result.Metadata,
			Result.OptionRef1,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Return Result;
	EndTry;
	
	If RunMeasurements Then
		ModulePerformanceMonitor.EndTechnologicalTimeMeasurement(
			KeyOperationName,
			BeginTime,
			1,
			KeyOperationComment);
	EndIf;
	
	// Commit the result.
	
	If AuxProperties <> DCSettingsComposer.UserSettings.AdditionalProperties Then
		NewAuxProperties = DCSettingsComposer.UserSettings.AdditionalProperties;
		CommonClientServer.SupplementStructure(NewAuxProperties, AuxProperties, False);
		AuxProperties = NewAuxProperties;
	EndIf;
	
	ItemModified = CommonClientServer.StructureProperty(AuxProperties, "VariantModified");
	If ItemModified = True Then
		Result.VariantModified = True;
		Result.DCSettings = DCSettingsComposer.Settings;
	EndIf;
	
	ItemsModified = CommonClientServer.StructureProperty(AuxProperties, "UserSettingsModified");
	If Result.VariantModified Or ItemsModified = True Then
		Result.UserSettingsModified = True;
		Result.DCUserSettings = DCSettingsComposer.UserSettings;
	EndIf;
	
	If GetCheckBoxEmpty Then
		If AuxProperties.Property("ReportIsBlank") Then
			IsEmpty = AuxProperties.ReportIsBlank;
		ElsIf Result.SpreadsheetDocument.TableHeight = 0
			And Result.SpreadsheetDocument.TableWidth = 0 Then 
			IsEmpty = True
		Else
			IsEmpty = ReportsServer.ReportIsBlank(ReportObject);
		EndIf;
		Result.Insert("IsEmpty", IsEmpty);
	EndIf;
	
	PrintSettings = Result.FormSettings.Print;
	PrintSettings.Insert("PrintParametersKey", ReportsClientServer.UniqueKey(Result.FullName, 
		Result.VariantKey));
	FillPropertyValues(Result.SpreadsheetDocument, PrintSettings);
	
	// Set headers and footers.
	
	HeaderOrFooterSettings = Undefined;
	If Result.DCSettings <> Undefined Then 
		Result.DCSettings.AdditionalProperties.Property("HeaderOrFooterSettings", HeaderOrFooterSettings);
	EndIf;
	
	ReportTitle = "";
	If ValueIsFilled(Result.OptionRef1) Then 
		ReportTitle = String(Result.OptionRef1);
	ElsIf Result.Metadata <> Undefined Then 
		ReportTitle = Result.Metadata.Synonym;
	EndIf;
	
	If Not Common.DataSeparationEnabled()
		Or Common.SeparatedDataUsageAvailable() Then 
		
		HeaderFooterManagement.SetHeadersAndFooters(Result.SpreadsheetDocument, ReportTitle,, HeaderOrFooterSettings);
	EndIf;
	
	Result.Success = True;
	
	// Clear trash items.
	
	AuxProperties.Delete("VariantModified");
	AuxProperties.Delete("UserSettingsModified");
	AuxProperties.Delete("VariantKey");
	AuxProperties.Delete("ReportIsBlank");
	AuxProperties.Delete("TablesToUse");
	
	Return Result;
EndFunction

// Returns:
//   Structure:
//     * RefOfReport   - Arbitrary
//     * OptionRef1 - CatalogRef.ReportsOptions
//     * VariantKey   - String - Name of a predefined report option or ID of a user report option.
//     * Object         - ReportObject
//     * FullName      - String
//     * SchemaKey      - String
//     * SchemaURL     - String
//     * ParametersChanged - Boolean
//     * SchemaModified - Boolean
//     * DCSettings    - DataCompositionSettings
//     * DCSchema        - DataCompositionSchema
//     * FixedDCSettings - DataCompositionSettings
//     * DCUserSettings - DataCompositionUserSettings
//     * FormIdentifier - UUID - ID of the form from which the report is attached.
//     * ExternalReportBinaryData - Undefined, BinaryData - For execution in a long-running operation.
//     * KeyOperationName - String
//     * KeyOperationComment - String, Map
//     * TablesToUse - Array
//     * Connection - See AttachReportAndImportSettings
//
Function ReportGenerationParameters() Export
	
	Result = New Structure;
	Result.Insert("RefOfReport", Undefined);
	Result.Insert("OptionRef1", Undefined);
	Result.Insert("VariantKey", Undefined);

	Result.Insert("Object", Undefined);
	Result.Insert("FullName", "");
	Result.Insert("SchemaKey", "");
	Result.Insert("SchemaURL", "");
	Result.Insert("ParametersChanged", False);
	Result.Insert("SchemaModified", False);
	
	Result.Insert("DCSettings", Undefined);
	Result.Insert("DCSchema", Undefined);
	Result.Insert("FixedDCSettings", Undefined);
	Result.Insert("DCUserSettings", Undefined);

	Result.Insert("FormIdentifier", Undefined);
	Result.Insert("ExternalReportBinaryData", Undefined);
	Result.Insert("KeyOperationName", "");
	Result.Insert("KeyOperationComment", "");

	Result.Insert("TablesToUse", New Array);

	Result.Insert("Connection", Undefined);
	
	Return Result;
	
EndFunction
	
// Details report availability by access rights and functional options.
Function ReportsAvailability(ReportsReferences) Export

	Result = New ValueTable;
	Result.Columns.Add("Ref");
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	Result.Columns.Add("ReportByStringType", New TypeDescription("String"));
	Result.Columns.Add("Available", New TypeDescription("Boolean"));
	
	OptionsReferences = New Array;
	ConfigurationReportsReportsReferences = New Array;
	ExtensionsReportsReferences = New Array;
	AddlReportsRefs = New Array;
	
	Duplicates = New Map;
	
	SetPrivilegedMode(True);
	For Each Ref In ReportsReferences Do
		If Duplicates[Ref] <> Undefined Then
			Continue;
		EndIf;
		Duplicates[Ref] = True;
		
		TableRow = Result.Add();
		TableRow.Ref = Ref;
		TableRow.Presentation = String(Ref);
		Type = TypeOf(Ref);
		If Type = Type("CatalogRef.ReportsOptions") Then
			OptionsReferences.Add(Ref);
		Else
			TableRow.Report = Ref;
			TableRow.ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Type, TableRow.Report);
			If TableRow.ReportByStringType = "BuiltIn" Then
				ConfigurationReportsReportsReferences.Add(TableRow.Report);
			ElsIf TableRow.ReportByStringType = "Extension" Then
				ExtensionsReportsReferences.Add(TableRow.Report);
			ElsIf TableRow.ReportByStringType = "Additional" Then
				AddlReportsRefs.Add(TableRow.Report);
			EndIf;
		EndIf;
	EndDo;
	SetPrivilegedMode(False);
	
	If OptionsReferences.Count() > 0 Then
		ReportsValues = Common.ObjectsAttributeValue(OptionsReferences, "Report", True);
		For Each Ref In OptionsReferences Do
			TableRow = Result.Find(Ref, "Ref");
			ReportValue = ReportsValues[Ref];
			If ReportValue = Undefined Then
				TableRow.Presentation = NStr("en = 'Insufficient rights to access the report option.';");
			Else
				TableRow.Report = ReportValue;
				TableRow.ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Undefined, TableRow.Report);
				If TableRow.ReportByStringType = "BuiltIn" Then
					ConfigurationReportsReportsReferences.Add(TableRow.Report);
				ElsIf TableRow.ReportByStringType = "Extension" Then
					ExtensionsReportsReferences.Add(TableRow.Report);
				ElsIf TableRow.ReportByStringType = "Additional" Then
					AddlReportsRefs.Add(TableRow.Report);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	ConfigurationReportsReportsReferences = CommonClientServer.CollapseArray(ConfigurationReportsReportsReferences);
	ExtensionsReportsReferences = CommonClientServer.CollapseArray(ExtensionsReportsReferences);
	AddlReportsRefs = CommonClientServer.CollapseArray(AddlReportsRefs);
	
	If ConfigurationReportsReportsReferences.Count() > 0 Then
		OnDefineReportsAvailability(ConfigurationReportsReportsReferences, Result);
	EndIf;
	
	If ExtensionsReportsReferences.Count() > 0 Then
		OnDefineReportsAvailability(ExtensionsReportsReferences, Result);
	EndIf;
	
	If AddlReportsRefs.Count() > 0 Then
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnDefineReportsAvailability(AddlReportsRefs, Result);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns report information including a reference and a report type by the full report name.
//
// Parameters:
//   ReportFullName - String - Full report name in either of the formats:
//                             Report.<NameOfReport>
//                             ExternalReport.<NameOfReport>
//   RaiseException1 - Boolean - If True, raise an exception when an error occurs. Possible errors::
//                                 Insufficient access rights to the report.
//                                 Unknown report type.
//
// Returns: 
//   Structure:
//       * Report          - CatalogRef.ExtensionObjectIDs
//                        - String
//                        - CatalogRef.AdditionalReportsAndDataProcessors
//                        - CatalogRef.MetadataObjectIDs
//       * ReportType      - EnumRef.ReportsTypes
//       * ReportShortName       - String - For example, FilesChangesDynamics.
//       * ReportFullName - String - For example, Report.FilesChangesDynamics.
//       * ReportMetadata - MetadataObjectReport
//       * ErrorText - String - Error text.
//
Function ReportInformation(Val ReportFullName, Val RaiseException1 = False) Export
	Result = New Structure("Report, ReportType, ReportFullName, ReportShortName, ReportMetadata, ErrorText");
	Result.Report          = ReportFullName;
	Result.ReportFullName = ReportFullName;
	Result.ErrorText    = "";
	
	PointPosition = StrFind(ReportFullName, ".");
	If PointPosition = 0 Then
		Prefix = "";
		Result.ReportShortName = ReportFullName;
	Else
		Prefix = Left(ReportFullName, PointPosition - 1);
		Result.ReportShortName = Mid(ReportFullName, PointPosition + 1);
	EndIf;
	
	If Upper(Prefix) = "REPORT" Then
		Result.ReportMetadata = Metadata.Reports.Find(Result.ReportShortName);
		If Result.ReportMetadata = Undefined Then
			Result.ReportFullName = "ExternalReport." + Result.ReportShortName;
			WriteToLog(EventLogLevel.Warning,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The report %1 was added as an external report.';"),
					ReportFullName));
		ElsIf Not AccessRight("View", Result.ReportMetadata) Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient rights to access report ""%1.""';"),
				ReportFullName);
		EndIf;
	ElsIf Upper(Prefix) = "EXTERNALREPORT" Then
		// It is not required to get metadata and perform checks.
	Else
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Report ""%1"" has unknown type. Expected types: ""%2"" or ""%3"".';"),
			"Report", "ExternalReport", ReportFullName);
		If RaiseException1 Then
			Raise Result.ErrorText;
		EndIf;	
		Return Result;
	EndIf;
	
	If Result.ReportMetadata = Undefined Then
		
		Result.Report = Result.ReportFullName;
		Result.ReportType = Enums.ReportsTypes.External;
		
		// Replace a type and a reference of the external report for additional reports attached to the subsystem storage.
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			
			Result.Insert("ByDefaultAllAttachedToStorage", ByDefaultAllAttachedToStorage());
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnDetermineTypeAndReferenceIfReportIsAuxiliary(Result);
			Result.Delete("ByDefaultAllAttachedToStorage");
			
			If TypeOf(Result.Report) <> Type("String") Then
				Result.ReportType = Enums.ReportsTypes.Additional;
			EndIf;
			
		EndIf;
		
	Else
		Result.Report = Common.MetadataObjectID(Result.ReportMetadata);
		Result.ReportType = ReportType(Result.Report);
	EndIf;
	
	If RaiseException1 And ValueIsFilled(Result.ErrorText) Then
		Raise Result.ErrorText;
	EndIf;	
	Return Result;
	
EndFunction

// Checks the property value of the Option storage report.
//
// Parameters:
//   MetadataOfReport - MetadataObject - Metadata of the report whose property is being checked.
//   WarningText - String - Check result details.
//
// Returns: 
//   Boolean:
//       * True - The option storage property is set to ReportsOptionsStorage.
//       * False - The property value is either not specified or specified but refers
//                to an option storage not supported by the subsystem.
//
Function AdditionalReportOptionsStorageCorrect(MetadataOfReport, WarningText = "") Export 
	If MetadataOfReport.VariantsStorage = Metadata.SettingsStorages.ReportsVariantsStorage Then 
		Return True;
	EndIf;
	
	If MetadataOfReport.VariantsStorage <> Undefined Then 
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""Option storage"" report property has invalid value.
			|Valid value: %1.';"), Metadata.SettingsStorages.ReportsVariantsStorage.FullName());
	Else
		WarningText = NStr("en = 'The ""Option storage"" report property is not specified.';");
	EndIf;

	WarningText = WarningText + Chars.LF + Chars.LF
		+ NStr("en = 'Saving and selecting report options may have some limitations.
		|Contact the additional (external) report developer for further assistance.';");
	Common.MessageToUser(WarningText);
	
	Return False;
EndFunction

// Whether it is possible to index report schema content.
// 
// Returns:
//  Boolean
//
Function SharedDataIndexingAllowed() Export
	Return Not Common.DataSeparationEnabled();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Intended for the integration report.

// Parameters:
//  ReportsType - String
//  ConnectedToTheStorage - Boolean
//
// Returns:
//   See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//
Function PredefinedReportsOptions(ReportsType = "BuiltIn", ConnectedToTheStorage = True) Export
	Result = PredefinedReportsOptionsCollection();
	
	GroupByReports = GlobalSettings().OutputReportsInsteadOfOptions;
	IndexingAllowed = SharedDataIndexingAllowed();
	HasAttachableCommands = Common.SubsystemExists("StandardSubsystems.AttachableCommands");
	If HasAttachableCommands Then
		AttachableReportsAndProcessorsComposition = Metadata.Subsystems["AttachableReportsAndDataProcessors"].Content;
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	EndIf;
	
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	ReportsSubsystems = PlacingReportsToSubsystems();
	StorageFlagCache = Undefined;
	
	For Each ReportMetadata In Metadata.Reports Do 
		If Not SeparatedDataUsageAvailable And ReportMetadata.ConfigurationExtension() <> Undefined Then
			Continue;
		EndIf;
		
		If ConnectedToTheStorage
			And Not ReportAttachedToStorage(ReportMetadata, StorageFlagCache) Then
			Continue;
		EndIf;
		
		ReportRef = Common.MetadataObjectID(ReportMetadata);
		ReportType = ReportByStringType(ReportRef);
		If ReportsType <> Undefined And ReportsType <> ReportType Then
			Continue;
		EndIf;
		
		DescriptionOfReport = DefaultReportDetails(Result, ReportMetadata, ReportRef, ReportType, GroupByReports);
		
		// Location.
		FoundItems = ReportsSubsystems.FindRows(New Structure("ReportMetadata", ReportMetadata)); 
		For Each RowSubsystem In FoundItems Do
			DescriptionOfReport.Location.Insert(RowSubsystem.SubsystemMetadata1, "");
		EndDo;
		
		// Predefined options.
		If DescriptionOfReport.UsesDCS Then
			ReportManager = Reports[ReportMetadata.Name];
			DCSchema = Undefined;
			SettingVariants = Undefined;
			Try
				DCSchema = ReportManager.GetTemplate(ReportMetadata.MainDataCompositionSchema.Name);
			Except
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot read the %1 report scheme:
						|%2';"), ReportMetadata.Name, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
			EndTry;
			// Read report option settings from the schema.
			If DCSchema <> Undefined Then
				Try
					SettingVariants = DCSchema.SettingVariants;
				Except
					If Common.DataSeparationEnabled() Then
						ErrorTextTemplate = NStr("en = 'Cannot read the %1 report option list in a shared session
							|because its settings contain links to separated predefined objects.
							|
							|%2';");
						
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							ErrorTextTemplate, ReportMetadata.Name, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					Else
						ErrorTextTemplate = NStr("en = 'Cannot read the %1 report option list:
							|%2';");
						
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							ErrorTextTemplate, ReportMetadata.Name, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					EndIf;
					
					WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
				EndTry;
			EndIf;
			// Read report option settings from the manager module (if failed to read them from the schema).
			If SettingVariants = Undefined Then
				Try
					SettingVariants = ReportManager.SettingVariants();
				Except
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Cannot read the %1 report option list from the manager module:
							|%2';"), ReportMetadata.Name, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
					WriteToLog(EventLogLevel.Error, ErrorText, ReportMetadata);
				EndTry;
			EndIf;
			// Found option registration.
			If SettingVariants <> Undefined Then
				For Each DCSettingsOption In SettingVariants Do
					OptionDetails = Result.Add();
					OptionDetails.Report        = DescriptionOfReport.Report;
					OptionDetails.ReportFullName = DescriptionOfReport.ReportFullName;
					OptionDetails.VariantKey = DCSettingsOption.Name;
					OptionDetails.Description = DCSettingsOption.Presentation;
					If IsBlankString(OptionDetails.Description) Then // if configuration is partly localized
						OptionDetails.Description = ?(OptionDetails.VariantKey <> "Main", OptionDetails.VariantKey,  // Do not localize.
							DescriptionOfReport.Description + "." + OptionDetails.VariantKey);
					EndIf;	
					OptionDetails.Type          = ReportType;
					OptionDetails.IsOption   = True;
					If IsBlankString(DescriptionOfReport.MainOption) Then
						DescriptionOfReport.MainOption = OptionDetails.VariantKey;
					EndIf;
					OptionDetails.Purpose = DescriptionOfReport.Purpose;
					If IndexingAllowed And TypeOf(DCSettingsOption) = Type("DataCompositionSettingsVariant") Then
						Try
							OptionDetails.SystemInfo.Insert("DCSettings", DCSettingsOption.Settings);
						Except
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Cannot read the settings of the ""%1"" report option:
									|%2';"), OptionDetails.VariantKey, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
							WriteToLog(EventLogLevel.Warning, ErrorText, ReportMetadata);
						EndTry;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
		If IsBlankString(DescriptionOfReport.MainOption) Then
			OptionDetails = Result.Add();
			FillPropertyValues(OptionDetails, DescriptionOfReport, "Report, Description, Purpose, ReportFullName");
			OptionDetails.VariantKey = "";
			OptionDetails.IsOption   = True;
			DescriptionOfReport.MainOption = OptionDetails.VariantKey;
		EndIf;
		
		// Process reports included in the AttachableReportsAndDataProcessors subsystem.
		If HasAttachableCommands And AttachableReportsAndProcessorsComposition.Contains(ReportMetadata) Then
			VenderSettings = ModuleAttachableCommands.AttachableObjectSettings(ReportMetadata.FullName());
			If VenderSettings <> Undefined Then
				If VenderSettings.DefineFormSettings Then
					DescriptionOfReport.DefineFormSettings = True;
				EndIf;
				If VenderSettings.CustomizeReportOptions Then
					CustomizeReportInManagerModule(Result, ReportMetadata);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	ResultCache = Result.Copy(, "Report, Description");
	
	// Extension functionality.
	If ReportsType = Undefined Or ReportsType = "BuiltIn" Then
		CustomizeReportInManagerModule(Result, Metadata.Reports.UniversalReport);
	EndIf;
	
	If ReportsType = Undefined
		Or ReportsType = "BuiltIn"
		Or ReportsType = "Extension" Then
		
		SSLSubsystemsIntegration.OnSetUpReportsOptions(Result);
		ReportsOptionsOverridable.CustomizeReportsOptions(Result);
	EndIf;
	
	FillClearedDescriptions(Result, ResultCache);
	
	// Define main report options.
	For Each DescriptionOfReport In Result.FindRows(New Structure("IsOption", False)) Do
		
		If Not DescriptionOfReport.GroupByReport Then
			DescriptionOfReport.MainOption = "";
			Continue;
		EndIf;
		
		HasMainOption = Not IsBlankString(DescriptionOfReport.MainOption);
		MainOptionEnabled = False;
		If HasMainOption Then
			SearchForDetails = New Structure();
			SearchForDetails.Insert("Report", DescriptionOfReport.Report);
			SearchForDetails.Insert("VariantKey", DescriptionOfReport.MainOption);
			SearchForDetails.Insert("IsOption", True);
			
			FoundADescriptionOf = Result.FindRows(SearchForDetails);
			LongDesc = FoundADescriptionOf[0]; // See DefaultReportDetails
			
			MainOptionEnabled = LongDesc.Enabled;
		EndIf;
		
		If Not HasMainOption Or Not MainOptionEnabled Then
			SearchForDetails = New Structure("Report", DescriptionOfReport.Report);
			FoundADescriptionOf = Result.FindRows(SearchForDetails);
			
			For Each OptionDetails In FoundADescriptionOf Do
				If IsBlankString(OptionDetails.VariantKey) Then
					Continue;
				EndIf;
				
				FillOptionRowDetails(OptionDetails, DescriptionOfReport);
				
				If OptionDetails.Enabled Then
					DescriptionOfReport.MainOption = OptionDetails.VariantKey;
					OptionDetails.DefaultVisibility = True;
					Break;
				EndIf;
			EndDo;
		EndIf;

	EndDo;
	
	Return Result;
EndFunction

// Defines whether a report is attached to the report option storage.
Function ReportAttachedToStorage(ReportMetadata, AllAttachedByDefault = Undefined) Export
	StorageMetadata1 = ReportMetadata.VariantsStorage;
	If StorageMetadata1 = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllAttachedToStorage();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (StorageMetadata1 = Metadata.SettingsStorages.ReportsVariantsStorage);
	EndIf;
	Return ReportAttached;
EndFunction

// Defines whether a report is attached to the common report form.
Function ReportAttachedToMainForm(ReportMetadata, AllAttachedByDefault = Undefined) Export
	MetadataForm = ReportMetadata.DefaultForm;
	If MetadataForm = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllConnectedToMainForm();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (MetadataForm = Metadata.CommonForms.ReportForm);
	EndIf;
	Return ReportAttached;
EndFunction

// Defines whether a report is attached to the common report settings form.
Function ReportAttachedToSettingsForm(ReportMetadata, AllAttachedByDefault = Undefined) Export
	MetadataForm = ReportMetadata.DefaultSettingsForm;
	If MetadataForm = Undefined Then
		If AllAttachedByDefault = Undefined Then
			AllAttachedByDefault = ByDefaultAllAttachedToSettingsForm();
		EndIf;
		ReportAttached = AllAttachedByDefault;
	Else
		ReportAttached = (MetadataForm = Metadata.CommonForms.ReportSettingsForm);
	EndIf;
	Return ReportAttached;
EndFunction

// List of objects where report commands are used.
//
// Returns:
//   Array of MetadataObject - Metadata objects with report commands.
//
Function ObjectsWithReportCommands() Export
	
	Result = New Array;
	SSLSubsystemsIntegration.OnDefineObjectsWithReportCommands(Result);
	ReportsOptionsOverridable.DefineObjectsWithReportCommands(Result);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// 1. Update shared data.
	
	Handler = Handlers.Add();
	Handler.HandlerManagement = True;
	Handler.SharedData     = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Version          = "*";
	Handler.Procedure       = "ReportsOptions.ConfigurationCommonDataNonexclusiveUpdate";
	Handler.Priority       = 90;
	
	////////////////////////////////////////////////////////////////////////////////
	// Update separated data.
	
	// 2.3. Update separated data in local mode.
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.SharedData     = False;
	Handler.ExecutionMode = "Seamless";
	Handler.Version          = "*";
	Handler.Priority       = 70;
	Handler.Procedure       = "ReportsOptions.ConfigurationSharedDataNonexclusiveUpdate";
	
	// 2.4. Update data of a utility user to update the presentations.
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.SharedData     = False;
	Handler.ExecutionMode = "Seamless";
	Handler.Version          = "3.1.2.205";
	Handler.Priority       = 99;
	Handler.Procedure       = "ReportsOptions.InternalUserNonexclusiveUpdate";
	
	////////////////////////////////////////////////////////////////////////////////
	// 3. Deferred update.
	
	// 3.2. Populate information to search for predefined report options.
	If SharedDataIndexingAllowed() Then
		Handler = Handlers.Add();
		If Common.DataSeparationEnabled() Then
			Handler.ExecutionMode = "Seamless";
			Handler.SharedData     = True;
		Else
			Handler.ExecutionMode = "Deferred";
			Handler.SharedData     = False; 
		EndIf;
		Handler.Id = New UUID("38d2a135-53e0-4c68-9bd6-3d6df9b9dcfb");
		Handler.Version        = "*";
		Handler.Procedure     = "ReportsOptions.UpdatePredefinedReportOptionsSearchIndex";
		Handler.Comment   = NStr("en = 'Update search index for predefined reports.';");
	EndIf;
	
	// 3.3. Populate information to search for user report options.
	Handler = Handlers.Add();
	Handler.ExecutionMode = "Deferred";
	Handler.SharedData     = False;
	Handler.Id   = New UUID("5ba93197-230b-4ac8-9abb-ab3662e5ff76");
	Handler.Version          = "*";
	Handler.Procedure       = "ReportsOptions.UpdateUserReportOptionsSearchIndex";
	Handler.Comment     = NStr("en = 'Update search index for custom reports.';");
	
	// 3.4. Set the corresponding references to metadata object IDs in settings of universal report options.
	Handler = Handlers.Add();
	Handler.Version = "3.1.9.5";
	Handler.Id = New UUID("6cd3c6c1-6919-4e18-9725-eb6dbb841f4a");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "Catalogs.ReportsOptions.RegisterDataToProcessForMigrationToNewVersion";
	Handler.Procedure = "Catalogs.ReportsOptions.ProcessDataForMigrationToNewVersion";
	Handler.ObjectsToRead = "Catalog.ReportsOptions";
	Handler.ObjectsToChange = "Catalog.ReportsOptions";
	Handler.ObjectsToLock = "Catalog.ReportsOptions";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Set a data source in the universal report option settings.
		|Once the processing is completed, renaming of metadata objects will not lead to losing the saved report options.
		|Fill the ""Use for"" field with the ""Computers and tablets"" value.';");
	
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "InformationRegisters.ReportOptionsSettings.ProcessDataForMigrationToNewVersion";
	Priority.Order = "Before";
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		NewRow = Handler.ExecutionPriorities.Add();
		NewRow.Procedure = "NationalLanguageSupportServer.ProcessDataForMigrationToNewVersion";
		NewRow.Order = "Before";
	EndIf;
	
	// 3.5. Register settings of report options availability by users (user groups).
	Handler = Handlers.Add();
	Handler.Version = "3.1.2.64";
	Handler.Id = New UUID("eba9f8fb-2755-4d1a-99f5-cdd132e48cfc");
	Handler.ExecutionMode = "Deferred";
	Handler.UpdateDataFillingProcedure = "InformationRegisters.ReportOptionsSettings.RegisterDataToProcessForMigrationToNewVersion";
	Handler.Procedure = "InformationRegisters.ReportOptionsSettings.ProcessDataForMigrationToNewVersion";
	Handler.ObjectsToRead = "Catalog.ReportsOptions";
	Handler.ObjectsToChange = "Catalog.ReportsOptions";
	Handler.ObjectsToLock = "Catalog.ReportsOptions, InformationRegister.ReportOptionsSettings";
	Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.Comment = NStr("en = 'Moves the report access restrictions to the ""Report option settings"" information register.
		|While this procedure is in progress, the report access restrictions for individual users and user groups might not work correctly.';");
	
	Handler.ExecutionPriorities = InfobaseUpdate.HandlerExecutionPriorities();
	Priority = Handler.ExecutionPriorities.Add();
	Priority.Procedure = "Catalogs.ReportsOptions.ProcessDataForMigrationToNewVersion";
	Priority.Order = "After";
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		NewRow = Handler.ExecutionPriorities.Add();
		NewRow.Procedure = "NationalLanguageSupportServer.ProcessDataForMigrationToNewVersion";
		NewRow.Order = "Before";
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.Catalogs.ReportsOptions.TabularSections.Location.Attributes.Subsystem);
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming.
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	Common.AddRenaming(
		Total, "2.1.0.2", "Role.ReadReportOptions", "Role.UsingReportOptions", Library);
	Common.AddRenaming(
		Total, "2.3.3.3", "Role.UsingReportOptions", "Role.AddEditPersonalReportsOptions", Library);
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingRefMappingOnExport.
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.PredefinedReportsOptions);
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	ModuleExportImportData = Common.CommonModule("ExportImportData");
	ModuleExportImportData.AddTypeExcludedFromUploadingUploads(Types,
		Metadata.Catalogs.PredefinedExtensionsReportsOptions,
		ModuleExportImportData.ActionWithLinksDoNotChange());
	Types.Add(Metadata.InformationRegisters.PredefinedExtensionsVersionsReportsOptions);
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport.
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the UserReportSettings catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.UserReportSettings.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchEditObjectsOverridable.OnDefineObjectsWithEditableAttributes.
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.ReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.UserReportSettings.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PredefinedExtensionsReportsOptions.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See UsersOverridable.OnDefineRoleAssignment
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.AddEditPersonalReportsOptions.Name);
	
EndProcedure

// See InformationRegisters.ExtensionVersionParameters.FillAllExtensionParameters.
Procedure OnFillAllExtensionParameters() Export
	
	Settings = SettingsUpdateParameters();
	Settings.Configuration = False;
	Settings.Extensions = True;
	Settings.SharedData = True;
	Settings.SeparatedData = True;
	Settings.Nonexclusive = True;
	Settings.Deferred2 = True;
	
	Refresh(Settings);
	
EndProcedure

// See InformationRegisters.ExtensionVersionParameters.ClearAllExtensionParameters.
Procedure OnClearAllExtemsionParameters() Export
	
	RecordSet = InformationRegisters.PredefinedExtensionsVersionsReportsOptions.CreateRecordSet();
	RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
	RecordSet.Write();
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableObjectsSettingsComposition.
Procedure OnDefineAttachableObjectsSettingsComposition(InterfaceSettings4) Export
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "AddReportCommands";
	Setting.TypeDescription = New TypeDescription("Boolean");
	
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "CustomizeReportOptions";
	Setting.TypeDescription = New TypeDescription("Boolean");
	Setting.AttachableObjectsKinds = "REPORT";
	
	Setting = InterfaceSettings4.Add();
	Setting.Key          = "DefineFormSettings";
	Setting.TypeDescription = New TypeDescription("Boolean");
	Setting.AttachableObjectsKinds = "REPORT";
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.
// 
// Parameters:
//   AttachableCommandsKinds - ValueTable - Supported command kinds, where::
//       * Name - String - Command kind name.
//       * SubmenuName - String - Name of the submenu that will contain the commands of this kind on the object forms.
//       * Title - String - Name of the submenu displayed to users.
//       * Picture - Picture - Submenu picture.
//       * Representation - ButtonRepresentation - Submenu representation mode.
//       * Order - Number - Submenu order in the command bar of the form.
//
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	Kind = AttachableCommandsKinds.Add();
	Kind.Name         = "Reports";
	Kind.SubmenuName  = "ReportsSubmenu";
	Kind.Title   = NStr("en = 'Reports';");
	Kind.Order     = 50;
	Kind.Picture    = PictureLib.Report;
	Kind.Representation = ButtonRepresentation.PictureAndText;
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	ReportsCommands = Commands.CopyColumns();
	ReportsCommands.Columns.Add("VariantKey", New TypeDescription("String, Null"));
	ReportsCommands.Columns.Add("Processed1", New TypeDescription("Boolean"));
	ReportsCommands.Columns.Add("IsNonContextual", New TypeDescription("Boolean"));
	ReportsCommands.Indexes.Add("Processed1");
	
	StandardProcessing = Sources.Rows.Count() > 0;
	FormSettings.Insert("Sources", Sources);
	
	SSLSubsystemsIntegration.BeforeAddReportCommands(ReportsCommands, FormSettings, StandardProcessing);
	ReportsOptionsOverridable.BeforeAddReportCommands(ReportsCommands, FormSettings, StandardProcessing);
	ReportsCommands.FillValues(True, "Processed1");
	If StandardProcessing Then
		ObjectsWithReportCommands = ObjectsWithReportCommands();
		For Each Source In Sources.Rows Do
			For Each DocumentRecorder In Source.Rows Do
				If ObjectsWithReportCommands.Find(DocumentRecorder.Metadata) <> Undefined Then
					OnAddReportsCommands(ReportsCommands, DocumentRecorder, FormSettings);
				EndIf;
			EndDo;
			If ObjectsWithReportCommands.Find(Source.Metadata) <> Undefined Then
				OnAddReportsCommands(ReportsCommands, Source, FormSettings);
			EndIf;
		EndDo;
	EndIf;
	
	FoundItems = AttachedReportsAndDataProcessors.FindRows(New Structure("AddReportCommands", True));
	For Each AttachedObject In FoundItems Do
		OnAddReportsCommands(ReportsCommands, AttachedObject, FormSettings);
	EndDo;
	
	KeyCommandParametersNames = "Id,Presentation,FunctionalOptions,Manager,FormName,VariantKey,
	|FormParameterName,FormParameters,Handler,AdditionalParameters,VisibilityInForms";
	
	AddedCommands = New Map;
	
	For Each ReportsCommand In ReportsCommands Do
		KeyParameters = New Structure(KeyCommandParametersNames);
		FillPropertyValues(KeyParameters, ReportsCommand);
		UUID = Common.CheckSumString(KeyParameters);
		
		FoundCommand = AddedCommands[UUID];
		If FoundCommand <> Undefined And ValueIsFilled(FoundCommand.ParameterType) Then
			If ValueIsFilled(ReportsCommand.ParameterType) Then
				FoundCommand.ParameterType = New TypeDescription(FoundCommand.ParameterType, ReportsCommand.ParameterType.Types());
			Else
				FoundCommand.ParameterType = Undefined;
			EndIf;
			Continue;
		EndIf;
		
		Command = Commands.Add();
		AddedCommands.Insert(UUID, Command);
		
		FillPropertyValues(Command, ReportsCommand);
		Command.Kind = "Reports";
		If Command.Order = 0 Then
			Command.Order = 50;
		EndIf;
		If Command.WriteMode = "" Then
			Command.WriteMode = "WriteNewOnly";
		EndIf;
		If Command.MultipleChoice = Undefined Then
			Command.MultipleChoice = True;
		EndIf;
		If IsBlankString(Command.FormName) And IsBlankString(Command.Handler) Then
			Command.FormName = "Form";
		EndIf;
		If Command.FormParameters = Undefined Then
			Command.FormParameters = New Structure;
		EndIf;
		Command.FormParameters.Insert("VariantKey", ReportsCommand.VariantKey);
		Command.FormParameters.Insert("IsNonContextual", ReportsCommand.IsNonContextual);
		If IsBlankString(Command.Handler) And Not Command.FormParameters.Property("GenerateOnOpen") Then
			Command.FormParameters.Insert("GenerateOnOpen", True);
		EndIf;
	EndDo;
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction.
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ReportsOptions, True);
	Lists.Insert(Metadata.Catalogs.UserReportSettings, True);
	Lists.Insert(Metadata.InformationRegisters.ReportOptionsSettings, True);
	Lists.Insert(Metadata.InformationRegisters.ReportsSnapshots, True);
	
EndProcedure

// See MonitoringCenterOverridable.OnCollectConfigurationStatisticsParameters.
Procedure OnCollectConfigurationStatisticsParameters() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	
	QueryText = 
	"SELECT
	|	COUNT(1) AS Count
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Custom";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	ModuleMonitoringCenter.WriteConfigurationObjectStatistics("Catalog.ReportsOptions.Custom", Selection.Count());
	
EndProcedure

#EndRegion

#Region Private

// Subsystem presentation. It is used for writing to the event log and in other places.
Function SubsystemDescription(LanguageCode)
	Return NStr("en = 'Report options';", ?(LanguageCode = Undefined, Common.DefaultLanguageCode(), LanguageCode));
EndFunction

// Initialize reports.

// The function gets the report object from the report option reference.
//
// Parameters:
//   RefOfReport
//     - CatalogRef.MetadataObjectIDs - Reference to a configuration report.
//     - CatalogRef.ExtensionObjectIDs - Reference to an extension report.
//     - Arbitrary - Reference to an additional or external report.
//
// Returns:
//   Structure - Report parameters (including report's Object)::
//       * Object      - ReportObject
//                     - ExternalReport - Report object.
//       * Name         - String           - Report object name.
//       * FullName   - String           - Full name of the report object.
//       * Metadata  - MetadataObject - Report metadata object.
//       * Ref      - Arbitrary     - Report reference.
//       * Success       - Boolean           - True if the report is attached.
//       * ErrorText - String           - Error text.
//
// Usage locations::
//   ReportMailing.InitializeReport().
//
Function AttachReportObject(RefOfReport, GetMetadata)
	Result = New Structure("Object, Name, FullName, Metadata, Ref, ErrorText");
	Result.Insert("Success", False);
	
	If RefOfReport = Undefined Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Method %1 is missing parameter %2.';"),
			"AttachReportObject",
			"RefOfReport");
		Return Result;
	Else
		Result.Ref = RefOfReport;
	EndIf;
	
	If TypeOf(Result.Ref) = Type("String") Then
		Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot attach report %1 from the app. Reason: The report was added as an external report.';"),
			Result.Ref);
		Return Result;
	EndIf;
	
	If TypeOf(Result.Ref) = Type("CatalogRef.MetadataObjectIDs")
	 Or TypeOf(Result.Ref) = Type("CatalogRef.ExtensionObjectIDs") Then
		
		Result.Metadata = Common.MetadataObjectByID(
			Result.Ref, False);
		
		If TypeOf(Result.Metadata) <> Type("MetadataObject") Then
			Result.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The report %1 is not a part of the app.';"),
				Result.Name);
			Return Result;
		EndIf;
		Result.Name = Result.Metadata.Name;
		If Not AccessRight("Use", Result.Metadata) Then
			Result.ErrorText = NStr("en = 'Insufficient access rights';");
			Return Result;
		EndIf;
		Try
			Result.Object = Reports[Result.Name].Create();
			Result.Success = True;
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot attach report %1:';"),
				Result.Metadata);
			ErrorText = ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo());
			WriteToLog(EventLogLevel.Error, ErrorText, Result.Metadata);
		EndTry;
	Else
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
			ModuleAdditionalReportsAndDataProcessors.OnAttachAdditionalReport(Result.Ref, Result, Result.Success, GetMetadata);
		EndIf;
	EndIf;
	
	If Result.Success And GetMetadata Then
		Result.FullName = Result.Metadata.FullName();
	EndIf;
	
	Return Result;
EndFunction

// Data composition.

// Generates a report with the specified settings. Used in background jobs.
Procedure GenerateReportInBackground(Parameters, StorageAddress) Export
	
	ReportGenerationResult = GenerateReport(Parameters, False, False);
	
	Result = New Structure("SpreadsheetDocument, Details,
		|Success, ErrorText, DataStillUpdating,
		|VariantModified, UserSettingsModified");
	FillPropertyValues(Result, ReportGenerationResult);
	
	If Result.VariantModified Or Parameters.ParametersChanged Then
		Result.Insert("DCSettings", ReportGenerationResult.DCSettings);
	EndIf;
	If Result.UserSettingsModified Then
		Result.Insert("DCUserSettings", ReportGenerationResult.DCUserSettings);
	EndIf;
	
	PutToTempStorage(Result, StorageAddress);
	
EndProcedure

// Fills in settings details for a report option row if it is not filled in.
//
// Parameters:
//   OptionDetails - See DefaultReportDetails
//   DescriptionOfReport -  See DefaultReportDetails
//
Procedure FillOptionRowDetails(OptionDetails, DescriptionOfReport)
	If OptionDetails.DetailsReceived Then
		Return;
	EndIf;
	
	// Settings modification flag.
	OptionDetails.DetailsReceived = True;
	
	// Copy report settings.
	FillPropertyValues(OptionDetails, DescriptionOfReport, "Enabled, DefaultVisibility, GroupByReport, ShouldShowInOptionsSubmenu");
	
	If OptionDetails.VariantKey = DescriptionOfReport.MainOption Then
		// Default option.
		OptionDetails.LongDesc = DescriptionOfReport.LongDesc;
		OptionDetails.DefaultVisibility = True;
	Else
		// Predefined option.
		If OptionDetails.GroupByReport Then
			OptionDetails.DefaultVisibility = False;
		EndIf;
	EndIf;
	
	OptionDetails.Location = Common.CopyRecursive(DescriptionOfReport.Location);
	OptionDetails.FunctionalOptions = Common.CopyRecursive(DescriptionOfReport.FunctionalOptions);
	OptionDetails.SearchSettings = Common.CopyRecursive(DescriptionOfReport.SearchSettings);
	
	MetadataOfReport = DescriptionOfReport.Metadata; // MetadataObjectReport
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then 
		OptionDetails.MeasurementsKey = ReportsOptionsInternal.MeasurementsKey(
			MetadataOfReport.FullName(), OptionDetails.VariantKey);
	EndIf;
EndProcedure

// Report panels.

// Generates a list of sections where the report panel calling commands are available.
//
// Returns:
//   ValueList - see description 1 of the ReportsOptionsOverridable.DefineSectionsWithReportOptions() procedure parameter
//
Function SectionsList() Export
	SectionsList = New ValueList;
	
	SSLSubsystemsIntegration.OnDefineSectionsWithReportOptions(SectionsList);
	ReportsOptionsOverridable.DefineSectionsWithReportOptions(SectionsList);
	
	If Common.SubsystemExists("StandardSubsystems.ApplicationSettings") Then
		ModuleAdministrationPanelSSL = Common.CommonModule("DataProcessors.SSLAdministrationPanel");
		ModuleAdministrationPanelSSL.OnDefineSectionsWithReportOptions(SectionsList);
	EndIf;
	
	Return SectionsList;
EndFunction

// Sets output mode for report options in report panels.
//
// Parameters:
//   Settings - ValueTable - Passed from the CustomizeReportsOptions procedure as is.
//   Report - ValueTableRow:
//         - MetadataObjectReport - Settings details or report metadata.
//   GroupByReports - Boolean - Report display mode.
//                           If True, then "by reports" (options are hidden, the report is enabled and visible).
//                           If False, then "by options" (options are visible, the report is disabled).
//
Procedure SetReportOutputModeInReportsPanels(Settings, Report, GroupByReports)
	If TypeOf(Report) = Type("ValueTableRow") Then
		DescriptionOfReport = Report;
	Else
		DescriptionOfReport = Settings.FindRows(New Structure("Metadata,IsOption", Report, False));
		If DescriptionOfReport.Count() <> 1 Then
			WriteToLog(EventLogLevel.Warning, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Report %1 is not attached to the subsystem.';"), Report.Name));
			Return;
		EndIf;
		DescriptionOfReport = DescriptionOfReport[0];
	EndIf;
	DescriptionOfReport.GroupByReport = GroupByReports;
EndProcedure

// Generates a table of replacements of old option keys for relevant ones.
//
// Returns:
//   ValueTable - Table of changed report option names. Columns::
//       * ReportMetadata - MetadataObjectReport - Metadata of the report whose schema contains the new option name.
//       * OldOptionName - String - Old name of the report option.
//       * RelevantOptionName - String - Current (last relevant) option name.
//       * Report - CatalogRef.MetadataObjectIDs
//               - String - Report reference or name used for storing.
//           See also:
//
// ReportOptionsOverridable.RegisterChangesOfReportOptionsKeys().:
//   
//
Function KeysChanges()
	
	OptionsAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	Changes = New ValueTable;
	Changes.Columns.Add("Report",                 New TypeDescription("MetadataObject"));
	Changes.Columns.Add("OldOptionName",     OptionsAttributes.VariantKey.Type);
	Changes.Columns.Add("RelevantOptionName", OptionsAttributes.VariantKey.Type);
	
	// Overridable part.
	SSLSubsystemsIntegration.OnChangeReportsOptionsKeys(Changes);
	ReportsOptionsOverridable.RegisterChangesOfReportOptionsKeys(Changes);
	
	Changes.Columns.Find("Report").Name = "ReportMetadata";
	Changes.Columns.Add("Report", OptionsAttributes.Report.Type);
	Changes.Indexes.Add("ReportMetadata, OldOptionName");
	
	// Check replacements for correctness.
	For Each Update In Changes Do
		Update.Report = Common.MetadataObjectID(Update.ReportMetadata);
		FoundItems = Changes.FindRows(New Structure("ReportMetadata, OldOptionName", Update.ReportMetadata, Update.RelevantOptionName));
		If FoundItems.Count() > 0 Then
			Conflict = FoundItems[0];
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'A conflict occurred when renaming the ""%1"" report option:
				|The current option name ""%2"" (previous name ""%3"")
				|is also registered as the previous name ""%4"" (current name ""%5"").';"),
				String(Update.Report),
				Update.RelevantOptionName,
				Update.OldOptionName,
				Conflict.OldOptionName,
				Conflict.RelevantOptionName);
		EndIf;
		FoundItems = Changes.FindRows(New Structure("ReportMetadata, OldOptionName", Update.ReportMetadata, Update.OldOptionName));
		If FoundItems.Count() > 2 Then
			Conflict = FoundItems[1];
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'A conflict occurred when renaming the ""%1"" report option:
				|The previous option name ""%2"" (current name ""%3"")
				|is also registered as the previous name of the ""%4"" report option (current name ""%5"").';"),
				String(Update.Report),
				Update.OldOptionName,
				Update.RelevantOptionName,
				String(Conflict.ReportMetadata.Presentation()),
				Conflict.RelevantOptionName);
		EndIf;
	EndDo;
	
	Return Changes;
EndFunction

// Generates a table of report placement by configuration subsystems.
//
// Parameters:
//   Result          - Undefined - Used for recursion.
//   SubsystemParent - Undefined - Used for recursion.
//
// Returns:
//   ValueTable - Result - ValueTable - Location settings for placing reports in subsystems:
//       * ReportMetadata      - MetadataObjectReport
//       * ReportFullName       - String
//       * SubsystemMetadata1 - MetadataObjectSubsystem
//       * SubsystemFullName  - String
//
Function PlacingReportsToSubsystems(Result = Undefined, ParentSubsystem = Undefined)
	If Result = Undefined Then
		FullNameTypesDetails = Metadata.Catalogs.MetadataObjectIDs.Attributes.FullName.Type;
		
		Result = New ValueTable;
		Result.Columns.Add("ReportMetadata",      New TypeDescription("MetadataObject"));
		Result.Columns.Add("ReportFullName",       FullNameTypesDetails);
		Result.Columns.Add("SubsystemMetadata1", New TypeDescription("MetadataObject"));
		Result.Columns.Add("SubsystemFullName",  FullNameTypesDetails);
		
		Result.Indexes.Add("ReportFullName");
		Result.Indexes.Add("ReportMetadata");
		
		ParentSubsystem = Metadata;
	EndIf;
	
	// Iterate through the nested subsystems.
	For Each ChildSubsystem In ParentSubsystem.Subsystems Do
		
		If ChildSubsystem.IncludeInCommandInterface Then
			For Each ReportMetadata In ChildSubsystem.Content Do
				If Not Metadata.Reports.Contains(ReportMetadata) Then
					Continue;
				EndIf;
				
				TableRow = Result.Add();
				TableRow.ReportMetadata      = ReportMetadata;
				TableRow.ReportFullName       = ReportMetadata.FullName();
				TableRow.SubsystemMetadata1 = ChildSubsystem;
				TableRow.SubsystemFullName  = ChildSubsystem.FullName();
				
			EndDo;
		EndIf;
		
		PlacingReportsToSubsystems(Result, ChildSubsystem);
	EndDo;
	
	Return Result;
EndFunction

// Reset the settings of the "Report options" predefined item
//   connected to the "Report options" catalog item.
//
// Parameters:
//   OptionObject - CatalogObject.ReportsOptions
//                 - FormDataStructure - Report options.
//
Function ResetReportOptionSettings(OptionObject) Export
	If OptionObject.Custom
		Or (OptionObject.ReportType <> Enums.ReportsTypes.BuiltIn
			And OptionObject.ReportType <> Enums.ReportsTypes.Extension)
		Or Not ValueIsFilled(OptionObject.PredefinedOption) Then
		Return False;
	EndIf;
	
	OptionObject.Description = Common.ObjectAttributeValue(
		OptionObject.PredefinedOption, "Description");
	
	OptionObject.Author = Undefined;
	OptionObject.AuthorOnly = False;
	OptionObject.LongDesc = "";
	OptionObject.Location.Clear();
	
	Return True;
EndFunction

// Generates description of the String types of the specified length.
Function TypesDetailsString(StringLength = 1000) Export
	Return New TypeDescription("String", , New StringQualifiers(StringLength));
EndFunction

// It defines full rights to subsystem data by role composition.
Function FullRightsToOptions() Export
	
	ReportsOptionsMetadata = Metadata.Catalogs.ReportsOptions;
	StandardAttributes = ReportsOptionsMetadata.StandardAttributes;
	
	AccessParameters = AccessParameters("Update", ReportsOptionsMetadata, StandardAttributes.Ref.Name);
	
	Return AccessParameters.Accessibility And Not AccessParameters.RestrictionByCondition;
	
EndFunction

// Checks whether a report option name is not occupied.
Function DescriptionIsUsed(Report, Ref, Description) Export
	If Description = String(Ref) Then
		Return False; // Check is disabled as the name did not change.
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReportsOptions.Presentation AS Description
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.Ref <> &Ref
	|	AND NOT ReportsOptions.DeletionMark
	|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)";
	
	Query.SetParameter("Report",  Report);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		If Selection.Description = Description Then 
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Checks whether a report option key is not occupied.
Function OptionKeyIsUsed(Report, Ref, VariantKey) Export
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	1 AS OptionKeyIsUsed
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.Ref <> &Ref
	|	AND ReportsOptions.VariantKey = &VariantKey
	|	AND ReportsOptions.DeletionMark = FALSE";
	Query.SetParameter("Report",        Report);
	Query.SetParameter("Ref",       Ref);
	Query.SetParameter("VariantKey", VariantKey);
	
	SetPrivilegedMode(True);
	Result = Not Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return Result;
EndFunction

// Creates a filter by the ObjectKey attribute for StandardSettingsStorageManager.Select().
Function NewFilterByObjectKey(ReportsNames)
	If ReportsNames = "" Or ReportsNames = "*" Then
		Return Undefined;
	EndIf;
	
	SeparatorPosition = StrFind(ReportsNames, ",");
	If SeparatorPosition = 0 Then
		ObjectKey = ReportsNames;
		ReportsNames = "";
	Else
		ObjectKey = TrimAll(Left(ReportsNames, SeparatorPosition - 1));
		ReportsNames = Mid(ReportsNames, SeparatorPosition + 1);
	EndIf;
	
	If StrFind(ObjectKey, ".") = 0 Then
		ObjectKey = "Report." + ObjectKey;
	EndIf;
	
	Return New Structure("ObjectKey", ObjectKey);
EndFunction

// Global subsystem settings.
Function GlobalSettings() Export
	Result = New Structure;
	Result.Insert("OutputReportsInsteadOfOptions", False);
	Result.Insert("OutputDetails1", True);
	Result.Insert("EditOptionsAllowed", True);
	Result.Insert("OutputGeneralHeaderOrFooterSettings", True);
	Result.Insert("OutputIndividualHeaderOrFooterSettings", True);
	
	Result.Insert("Search", New Structure);
	Result.Search.Insert("InputHint", NStr("en = 'Report description, field, or author';"));
	
	Result.Insert("OtherReports", New Structure);
	Result.OtherReports.Insert("CloseAfterChoice", True);
	Result.OtherReports.Insert("ShowCheckBox", False);
	
	SSLSubsystemsIntegration.OnDefineReportsOptionsSettings(Result);
	ReportsOptionsOverridable.OnDefineSettings(Result);
	
	Return Result;
EndFunction

// Global settings of a report panel.
Function CommonPanelSettings() Export
	CommonSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		"ReportPanel");
	If CommonSettings = Undefined Then
		CommonSettings = New Structure("ShowTooltips, SearchInAllSections, DisplayAllReportOptions");
		CommonSettings.ShowTooltips = GlobalSettings().OutputDetails1;
		CommonSettings.SearchInAllSections = False;
		CommonSettings.DisplayAllReportOptions	= False;
	Else
		If Not CommonSettings.Property("DisplayAllReportOptions") Then
			CommonSettings.Insert("DisplayAllReportOptions", False);
		EndIf;
	EndIf;
	Return CommonSettings;
EndFunction

// Global settings of a report panel.
Function SaveCommonPanelSettings(CommonSettings) Export
	If TypeOf(CommonSettings) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	Common.CommonSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		"ReportPanel",
		CommonSettings);
	Return CommonSettings;
EndFunction

// Returns:
//  Structure:
//   * RunMeasurements - Boolean
//
Function ClientParameters() Export
	ClientParameters = New Structure;
	ClientParameters.Insert("RunMeasurements", RunMeasurements());
	
	Return ClientParameters;
EndFunction

Function RunMeasurements()
	
	If Common.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

// Fills in a report option description if it was cleared while applying settings.
//
// Parameters:
//  ReportsOptionsProperties - See PredefinedReportsOptionsCollection.
//  ReportsOptionsPropertiesCache - ValueTable - Copy of the ReportsOptionsProperties table before applying settings, where::
//      * Description - String - Report option description before applying settings.
//      * Report - CatalogRef.ExtensionObjectIDs
//              - CatalogRef.AdditionalReportsAndDataProcessors
//              - CatalogRef.MetadataObjectIDs
//              - String - Reference to a report metadata ID.
//
Procedure FillClearedDescriptions(ReportsOptionsProperties, ReportsOptionsPropertiesCache)
	FoundProperties = ReportsOptionsProperties.FindRows(New Structure("Description", "")); // See PredefinedReportsOptionsCollection
	If FoundProperties.Count() = 0 Then 
		Return;
	EndIf;
	
	ReportsOptionsPropertiesCache.GroupBy("Report, Description");
	ReportsOptionsPropertiesCache.Indexes.Add("Report");
	
	For Each Properties In FoundProperties Do 
		
		CachedProperties = ReportsOptionsPropertiesCache.Find(Properties.Report, "Report");
		
		If CachedProperties <> Undefined
			And ValueIsFilled(CachedProperties.Description) Then 
			
			Properties.Description = CachedProperties.Description;
		EndIf;
	EndDo;
EndProcedure

// For execution in a long-running operation.
//
// Parameters:
//  ReportObject - ReportObject
//  Parameters   - See ReportGenerationParameters
//
Procedure PopulateExternalReportBinaryData(ReportObject, Parameters)
	
	If Not ValueIsFilled(Parameters.ExternalReportBinaryData) Then
		Return;
	EndIf;
	
	BinaryDataStructure = New Structure;
	BinaryDataStructure.Insert("ExternalReportBinaryData", Parameters.ExternalReportBinaryData);
	FillPropertyValues(ReportObject, BinaryDataStructure);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event log

// Record to the event log.
Procedure WriteToLog(Level, Message, ReportVariant = Undefined) Export
	If TypeOf(ReportVariant) = Type("MetadataObject") Then
		MetadataObject = ReportVariant;
		Data = MetadataObject.Presentation();
	Else
		MetadataObject = Metadata.Catalogs.ReportsOptions;
		Data = ReportVariant;
	EndIf;
	WriteLogEvent(SubsystemDescription(Undefined),
		Level, MetadataObject, Data, Message);
EndProcedure

// Writes a procedure start event to the event log.
Procedure WriteProcedureStartToLog(ProcedureName)
	
	EventLog.AddMessageForEventLog(SubsystemDescription(Undefined),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Starting %1.';"), ProcedureName)); 
		
EndProcedure

// Writes a procedure completion event to the event log.
Procedure WriteProcedureCompletionToLog(ProcedureName, ObjectsChanged = Undefined)
	
	Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Finishing %1.';"), ProcedureName);
	If ObjectsChanged <> Undefined Then
		Text = Text + " " 
			+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 objects have been modified.';"), ObjectsChanged);
	EndIf;
	EventLog.AddMessageForEventLog(SubsystemDescription(Undefined),
		EventLogLevel.Information, , , Text);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Standard event handlers.

// Deleting personal report options upon user deletion.
Procedure OnRemoveUser(UserObject, Cancel) Export
	If UserObject.IsNew()
		Or UserObject.DataExchange.Load
		Or Cancel
		Or Not UserObject.DeletionMark Then
		Return;
	EndIf;
	
	// Set a deletion mark of personal user options.
	QueryText =
	"SELECT
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Author = &UserRef
	|	AND ReportsOptions.DeletionMark = FALSE
	|	AND ReportsOptions.AuthorOnly = TRUE";
	
	Query = New Query;
	Query.SetParameter("UserRef", UserObject.Ref);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		OptionObject = Selection.Ref.GetObject();
		OptionObject.AdditionalProperties.Insert("IndexSchema", False);
		OptionObject.SetDeletionMark(True);
	EndDo;
EndProcedure

// Delete subsystems references before their deletion.
Procedure BeforeDeleteMetadataObjectID(MetadataObjectIDObject, Cancel) Export
	If MetadataObjectIDObject.DataExchange.Load Then
		Return;
	EndIf;
	
	Subsystem = MetadataObjectIDObject.Ref;
	
	QueryText =
	"SELECT DISTINCT
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Location.Subsystem = &Subsystem";
	
	Query = New Query;
	Query.SetParameter("Subsystem", Subsystem);
	Query.Text = QueryText;
	
	OptionsToAssign = Query.Execute().Unload().UnloadColumn("Ref");
	
	BeginTransaction();
	Try
		Block = New DataLock;
		For Each OptionRef1 In OptionsToAssign Do
			LockItem = Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", OptionRef1);
		EndDo;
		Block.Lock();
		
		For Each OptionRef1 In OptionsToAssign Do
			OptionObject = OptionRef1.GetObject(); // CatalogObject.ReportsOptions
			
			FoundItems = OptionObject.Location.FindRows(New Structure("Subsystem", Subsystem));
			For Each TableRow In FoundItems Do
				OptionObject.Location.Delete(TableRow);
			EndDo;
			
			OptionObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update.

// [*] Updates cache of configuration metadata: the PredefinedReportOptions catalog
//     and report option parameters in the register.
//
Procedure ConfigurationCommonDataNonexclusiveUpdate(ParametersOfUpdate) Export
	
	Mode = "ConfigurationCommonData";
	StartPresentationsFilling(Mode, True);
	CommonDataNonexclusiveUpdate(Mode, ParametersOfUpdate.SeparatedHandlers);
	
	SchedulePresentationsFilling();
	
EndProcedure

// [*] Updates data of the ReportsOptions catalog in some configuration reports. 
Procedure ConfigurationSharedDataNonexclusiveUpdate() Export
	
	UpdateReportsOptions("SeparatedConfigurationData");
	
EndProcedure

// [*] Updates data of a utility user to update the presentations.
Procedure InternalUserNonexclusiveUpdate() Export 
	
	SetPrivilegedMode(True);
	
	UserName = InternalUsername();
	IBUser = InfoBaseUsers.FindByName(UserName);
	
	If IBUser = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure("IBUserID", IBUser.UUID);
	Selection = Catalogs.Users.Select(,, Filter);
	
	If Not Selection.Next() Then 
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		LockItem = Block.Add(Metadata.Catalogs.Users.FullName());
		LockItem.SetValue("Ref", Selection.Ref);
		Block.Lock();
		
		User = Selection.Ref.GetObject();
		InfobaseUpdate.DeleteData(User);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteLogEvent(
			NStr("en = 'Report options.Update utility user';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Users,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
EndProcedure

Procedure UpdatePredefinedReportOptionsSearchIndex(Parameters = Undefined) Export
	
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then 
		
		Return;
	EndIf;
	
	UpdateSearchIndex("ConfigurationCommonData", True);
	
EndProcedure

Procedure UpdateUserReportOptionsSearchIndex(Parameters = Undefined) Export
	
	UpdateSearchIndex("SeparatedConfigurationData", True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Infobase update / Initial population and update of catalogs.

// Updates cache of configuration metadata/applied extensions.
Function CommonDataNonexclusiveUpdate(Mode, SeparatedHandlers)
	
	////////////////////////////////////////////////////////////////////////////////
	// Only for predefined report options.
	
	Result = CommonDataUpdateResult(Mode, SeparatedHandlers);
	
	UpdateKeysOfPredefinedItems(Mode, Result);
	MarkDeletedPredefinedItems(Mode, Result);
	GenerateOptionsFunctionalityTable(Mode, Result);
	MarkOptionsOfDeletedReportsForDeletion(Mode, Result);
	WriteFunctionalOptionsTable(Mode, Result);
	RecordCurrentExtensionsVersion();
	
	// Update separated data in SaaS mode.
	If Result.SaaSModel And Result.HasImportantChanges Then
		Handlers = Result.SeparatedHandlers;
		If Handlers = Undefined Then
			Handlers = InfobaseUpdate.NewUpdateHandlerTable();
			Result.SeparatedHandlers = Handlers;
		EndIf;
		
		Handler = Handlers.Add();
		Handler.ExecutionMode = "Seamless";
		Handler.Version    = "*";
		Handler.Procedure = "ReportsOptions.ConfigurationSharedDataNonexclusiveUpdate";
		Handler.Priority = 70;
	EndIf;
	
	Return Result;
EndFunction

// Updates data of the ReportsOptions catalog.
Function UpdateReportsOptions(Mode)
	
	Result = ReportsOptionsUpdateResult();
	
	// 1. Update separated report options.
	UpdateReportsOptionsByPredefinedOnes(Mode, Result);

	// 2. Set a deletion mark for options of deleted reports.
	MarkOptionsOfDeletedReportsForDeletion(Mode, Result);
	
	Return Result;
	
EndFunction

// Update the search index of report options.
Function UpdateSearchIndex(Mode, IndexSchema)
	StartPresentationsFilling(Mode, False);
	
	SharedData = (Mode = "ConfigurationCommonData" Or Mode = "ExtensionsCommonData");
	Refinement = Lower(ModePresentation(Mode)) + ", " + ?(IndexSchema, NStr("en = 'full';"), NStr("en = 'by changes';"));
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Updating search index (%1)';"), Refinement);
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	
	If SharedData Then
		Search = New Structure("Report, VariantKey, IsOption", , , True);
		If Mode = "ConfigurationCommonData" Then
			PredefinedOptions = PredefinedReportsOptions("BuiltIn");
			Query.Text =
			"SELECT
			|	PredefinedReportsOptions.Ref,
			|	PredefinedReportsOptions.Report
			|FROM
			|	Catalog.PredefinedReportsOptions AS PredefinedReportsOptions
			|WHERE
			|	PredefinedReportsOptions.DeletionMark = FALSE";
		ElsIf Mode = "ExtensionsCommonData" Then
			PredefinedOptions = PredefinedReportsOptions("Extension");
			Query.Text =
			"SELECT
			|	PredefinedExtensionsVersionsReportsOptions.Variant AS Ref,
			|	PredefinedExtensionsVersionsReportsOptions.Report
			|FROM
			|	InformationRegister.PredefinedExtensionsVersionsReportsOptions AS PredefinedExtensionsVersionsReportsOptions
			|WHERE
			|	PredefinedExtensionsVersionsReportsOptions.ExtensionsVersion = &ExtensionsVersion
			|	AND PredefinedExtensionsVersionsReportsOptions.Variant <> &EmptyRef";
			Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
			Query.SetParameter("EmptyRef", Catalogs.PredefinedExtensionsReportsOptions.EmptyRef());
		EndIf;
	Else
		Query.Text =
		"SELECT
		|	ReportsOptions.Ref,
		|	ReportsOptions.Report
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|WHERE
		|	ReportsOptions.Custom
		|	AND ReportsOptions.ReportType = &ReportType
		|	AND ReportsOptions.Report IN(&AvailableReports)";
		Query.SetParameter("AvailableReports", New Array(ReportsOptionsCached.AvailableReports(False)));
		If Mode = "SeparatedConfigurationData" Then
			Query.SetParameter("ReportType", Enums.ReportsTypes.BuiltIn);
		ElsIf Mode = "SeparatedExtensionData" Then
			Query.SetParameter("ReportType", Enums.ReportsTypes.Extension);
		EndIf;
	EndIf;
	
	ReportsWithIssues = New Map;
	NewInfo = New Map;
	PreviousInfo = New Structure("SettingsHash, FieldDescriptions, FilterParameterDescriptions, Keywords");
	
	ErrorList = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If ReportsWithIssues[Selection.Report] = True Then
			Continue; // Report is not attached. Error was registered earlier.
		EndIf;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(Selection.Ref.Metadata().FullName());
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			OptionObject = Selection.Ref.GetObject(); // CatalogObject.ReportsOptions, CatalogObject.PredefinedReportsOptions, CatalogObject.PredefinedExtensionsReportsOptions
			If OptionObject = Undefined Then
				RollbackTransaction();
				Continue;
			EndIf;
			
			ReportInfo = NewInfo[Selection.Report];
			If ReportInfo = Undefined Then
				ReportInfo = New Structure("DCSettings, SearchSettings, ReportObject, IndexSchema");
				NewInfo[Selection.Report] = ReportInfo;
			EndIf;	
			
			If SharedData Then
				FillPropertyValues(Search, OptionObject, "Report, VariantKey");
				FoundItems = PredefinedOptions.FindRows(Search);
				If FoundItems.Count() = 0 Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The ""%1"" option of the ""%2"" report does not exist.';"), 
						OptionObject.VariantKey, OptionObject.Report);
					WriteToLog(EventLogLevel.Error, ErrorText, OptionObject.Ref);
					RollbackTransaction();
					Continue; // An error occurred.
				EndIf;
				
				OptionDetails = FoundItems[0]; // See DefaultReportDetails
				FillOptionRowDetails(OptionDetails, PredefinedOptions.FindRows(
					New Structure("Report,IsOption", OptionObject.Report, False))[0]);
				
				// If an option is disabled, it cannot be searched for.
				If Not OptionDetails.Enabled Then
					RollbackTransaction();
					Continue; // No need to populate.
				EndIf;
				
				ReportInfo.DCSettings = CommonClientServer.StructureProperty(OptionDetails.SystemInfo, "DCSettings");
				ReportInfo.SearchSettings = OptionDetails.SearchSettings;
			EndIf;
			
			FillPropertyValues(PreviousInfo, FieldsForSearch(OptionObject));
			PreviousInfo.SettingsHash = OptionObject.SettingsHash;
			ReportInfo.IndexSchema = IndexSchema; // Reindex forcedly, without checking the hash.
			
			Try
				SchemaIndexed = FillFieldsForSearch(OptionObject, ReportInfo);
			Except
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot rebuild the search index for option %1, report%2. The report might be corrupted.';"), 
					OptionObject.VariantKey, OptionObject.Report);
				WriteToLog(EventLogLevel.Error, ErrorText + Chars.LF 
					+ ErrorProcessing.DetailErrorDescription(ErrorInfo()), OptionObject.Ref);
				ErrorList.Add(ErrorText);
				RollbackTransaction();
				Continue;
			EndTry;
			
			If SchemaIndexed And SearchSettingsChanged(OptionObject, PreviousInfo) Then
				If SharedData Then
					WritePredefinedObject(OptionObject);
				Else
					InfobaseUpdate.WriteObject(OptionObject);
				EndIf;
			EndIf;
			
			If ReportInfo.ReportObject = Undefined Then
				ReportsWithIssues[Selection.Report] = True; // The report was not attached
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;	
	EndDo;
	SetPresentationsFillingFlag(True, False, Mode);
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
	
	Return Undefined;
EndFunction

// Replace obsolete report option keys with relevant ones.
Procedure UpdateKeysOfPredefinedItems(Mode, Result)
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Updating report option keys (%1)';"), 
		?(Mode = "ConfigurationCommonData", NStr("en = 'configuration metadata';"), NStr("en = 'extension metadata';")));
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Generate a table of replacements of old option keys for relevant ones.
	Changes = KeysChanges();
	
	// Get the references to the report options for key replacement.
	// Don't include the report options whose current keys are registered
	// or whose old keys are vacant.
	// 
	QueryText =
	"SELECT
	|	Changes.Report,
	|	Changes.OldOptionName,
	|	Changes.RelevantOptionName
	|INTO ttChanges
	|FROM
	|	&Changes AS Changes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ttChanges.Report,
	|	ttChanges.RelevantOptionName,
	|	ReportOptionsOld.Ref
	|FROM
	|	ttChanges AS ttChanges
	|		LEFT JOIN Catalog.PredefinedReportsOptions AS ReportOptionsLatest
	|		ON ttChanges.Report = ReportOptionsLatest.Report
	|			AND ttChanges.RelevantOptionName = ReportOptionsLatest.VariantKey
	|		LEFT JOIN Catalog.PredefinedReportsOptions AS ReportOptionsOld
	|		ON ttChanges.Report = ReportOptionsOld.Report
	|			AND ttChanges.OldOptionName = ReportOptionsOld.VariantKey
	|WHERE
	|	ReportOptionsLatest.Ref IS NULL 
	|	AND NOT ReportOptionsOld.Ref IS NULL ";
	
	If Mode = "ExtensionsCommonData" Then
		QueryText = StrReplace(QueryText, ".PredefinedReportsOptions", ".PredefinedExtensionsReportsOptions");
		CatalogName = "Catalog.PredefinedExtensionsReportsOptions";
	Else	
		CatalogName = "Catalog.PredefinedReportsOptions";
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Changes", Changes);
	Query.Text = QueryText;
	
	// Replace obsolete option names with relevant ones.
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result.HasChanges = True;
		Result.HasImportantChanges = True;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(CatalogName);
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			OptionObject = Selection.Ref.GetObject();
			OptionObject.VariantKey = Selection.RelevantOptionName;
			WritePredefinedObject(OptionObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

Procedure MarkDeletedPredefinedItems(Mode, Result)
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Updating predefined settings (%1)';"), 
		?(Mode = "ConfigurationCommonData", NStr("en = 'configuration metadata';"), NStr("en = 'extension metadata';")));
	WriteProcedureStartToLog(ProcedurePresentation);
	
	If Mode = "ConfigurationCommonData" Then
		QueryText = "SELECT * FROM Catalog.PredefinedReportsOptions ORDER BY DeletionMark";
		EmptyRef = Catalogs.PredefinedReportsOptions.EmptyRef();
		TableName = "Catalog.PredefinedReportsOptions";
	ElsIf Mode = "ExtensionsCommonData" Then
		QueryText = "SELECT * FROM Catalog.PredefinedExtensionsReportsOptions ORDER BY DeletionMark";
		EmptyRef = Catalogs.PredefinedExtensionsReportsOptions.EmptyRef();
		TableName = "Catalog.PredefinedExtensionsReportsOptions";
	EndIf;
	
	// Map the information from database and the metadata. Mark the obsolete infobase objects for deletion.
	Result.ReportsOptions.Indexes.Add("Report, VariantKey, FoundInDatabase, IsOption");
	SearchForOption = New Structure("Report, VariantKey, FoundInDatabase, IsOption");
	SearchForOption.FoundInDatabase = False;
	SearchForOption.IsOption        = True;
	
	Query = New Query(QueryText);
	PredefinedReportsOptions = Query.Execute().Unload();
	
	For Each OptionFromBase In PredefinedReportsOptions Do
		
		FillPropertyValues(SearchForOption, OptionFromBase, "Report, VariantKey");
		FoundItems = Result.ReportsOptions.FindRows(SearchForOption);
		If FoundItems.Count() > 0 Then
			OptionDetails = FoundItems[0];
			DescriptionOfReport = Result.ReportsOptions.FindRows(New Structure("Report, IsOption", OptionFromBase.Report, False))[0];
			FillOptionRowDetails(OptionDetails, DescriptionOfReport);
			OptionDetails.FoundInDatabase = True;
			OptionDetails.OptionFromBase = OptionFromBase;
			Continue;
		EndIf;
		
		If OptionFromBase.DeletionMark And OptionFromBase.Parent = EmptyRef Then
			Continue; // No action required.
		EndIf;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(TableName);
			LockItem.SetValue("Ref", OptionFromBase.Ref);
			Block.Lock();
			
			OptionObject = OptionFromBase.Ref.GetObject();
			If OptionObject = Undefined Then
				RollbackTransaction();
				Continue;
			EndIf;
				
			OptionObject.DeletionMark = True;
			OptionObject.Parent = EmptyRef;
			WritePredefinedObject(OptionObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		Result.HasChanges = True;
		Result.HasImportantChanges = True;
		
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

Procedure GenerateOptionsFunctionalityTable(Mode, Result)
	
	OptionsAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	If Mode = "ConfigurationCommonData" Then
		EmptyRef = Catalogs.PredefinedReportsOptions.EmptyRef();
	ElsIf Mode = "ExtensionsCommonData" Then
		EmptyRef = Catalogs.PredefinedExtensionsReportsOptions.EmptyRef();
	EndIf;
	
	FunctionalOptionsTable = New ValueTable;
	FunctionalOptionsTable.Columns.Add("Report",                   OptionsAttributes.Report.Type);
	FunctionalOptionsTable.Columns.Add("PredefinedOption", OptionsAttributes.PredefinedOption.Type);
	FunctionalOptionsTable.Columns.Add("FunctionalOptionName",  New TypeDescription("String"));
	
	Result.Insert("FunctionalOptionsTable", FunctionalOptionsTable);
	
	ReportsWithSettingsList = New ValueList;
	Result.Insert("ReportsWithSettingsList", ReportsWithSettingsList);
	
	MainOptions = New Map;
	For Each OptionDetails In Result.ReportsOptions Do
		
		If Not OptionDetails.IsOption Then
			If OptionDetails.DefineFormSettings Then
				ReportsWithSettingsList.Add(OptionDetails.Report);
			EndIf;
			Continue;
		EndIf;
		
		// Set the ParentOption attribute to relate report options to main report options.
		DescriptionOfReport = Result.ReportsOptions.FindRows(New Structure("Report, IsOption", OptionDetails.Report, False))[0];
		FillOptionRowDetails(OptionDetails, DescriptionOfReport);
		If IsBlankString(DescriptionOfReport.MainOption) Or OptionDetails.VariantKey = DescriptionOfReport.MainOption Then
			MainOptionKey = OptionDetails.ReportFullName + "." + OptionDetails.VariantKey;
			OptionRef = MainOptions[MainOptionKey];
			If OptionRef = Undefined Then
				OptionDetails.ParentOption = EmptyRef;
				OptionRef = UpdatePredefinedReportOption(Mode, OptionDetails, Result); 
				MainOptions[MainOptionKey] = OptionRef;
			EndIf
		Else
			MainOption = Result.ReportsOptions.FindRows(
				New Structure("Report, VariantKey", OptionDetails.Report, DescriptionOfReport.MainOption))[0];
			MainOptionKey = MainOption.ReportFullName + "." + MainOption.VariantKey;
			MainOptionRef = MainOptions[MainOptionKey];
			If MainOptionRef = Undefined Then
				MainOption.ParentOption = EmptyRef;
				MainOptionRef = UpdatePredefinedReportOption(Mode, MainOption, Result); 
				MainOptions[MainOptionKey] = MainOptionRef;
			EndIf;	
			OptionDetails.ParentOption = MainOptionRef;
			OptionRef = UpdatePredefinedReportOption(Mode, OptionDetails, Result);
		EndIf;
		
		For Each FunctionalOptionName In OptionDetails.FunctionalOptions Do
			LinkWithFunctionalOption = FunctionalOptionsTable.Add();
			LinkWithFunctionalOption.Report                   = OptionDetails.Report;
			LinkWithFunctionalOption.PredefinedOption = OptionRef;
			LinkWithFunctionalOption.FunctionalOptionName  = FunctionalOptionName;
		EndDo;
		
	EndDo;

EndProcedure

// Writes option settings to catalog data.
//
// Parameters:
//   Mode - String - Data update kind.
//   OptionDetails - ValueTableRow - Properties of the report option, where::
//       * OptionFromBase - ValueTableRow - Properties of the main report option, where::
//             * Ref - CatalogRef.PredefinedExtensionsReportsOptions
//                      - CatalogRef.PredefinedReportsOptions - Reference to a predefined report option.
//       * Description - String - Report option name.
//       * LongDesc - String - Brief information about the report option.
//   Result - See CommonDataUpdateResult
//
Function UpdatePredefinedReportOption(Mode, OptionDetails, Result)
	
	BeginTransaction();
	Try
		OptionFromBase = OptionDetails.OptionFromBase;
		If Result.UpdateMeasurements Then
			Var_Key = ?(OptionDetails.FoundInDatabase, OptionFromBase.MeasurementsKey, "");
			RegisterOptionMeasurementsForUpdate(Var_Key, OptionDetails.MeasurementsKey, OptionDetails.Description, Result);
		EndIf;
		If OptionDetails.FoundInDatabase Then
			If OptionFromBase.DeletionMark = True // Details obtained. Remove the deletion mark.
				Or KeySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase) Then
				Result.HasImportantChanges = True; // Rewrite key settings (rewriting separated data is required).
			ElsIf Not SecondarySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase) Then
				CommitTransaction();
				Return OptionFromBase.Ref;
			EndIf;
			
			OptionFromBase = OptionDetails.OptionFromBase;
			
			If Mode = "ConfigurationCommonData" Then
				TableName = "Catalog.PredefinedReportsOptions";
			ElsIf Mode = "ExtensionsCommonData" Then
				TableName = "Catalog.PredefinedExtensionsReportsOptions";
			EndIf;
			Block = New DataLock;
			LockItem = Block.Add(TableName);
			LockItem.SetValue("Ref", OptionFromBase.Ref);
			Block.Lock();
			
			OptionObject = OptionFromBase.Ref.GetObject(); // CatalogObject.PredefinedReportsOptions, CatalogObject.PredefinedExtensionsReportsOptions
			OptionObject.Location.Clear();
			If OptionObject.DeletionMark Then
				OptionObject.DeletionMark = False;
			EndIf;
		Else
			Result.HasImportantChanges = True; // Register the new object (separated data update is required).
			If Mode = "ConfigurationCommonData" Then
				OptionObject = Catalogs.PredefinedReportsOptions.CreateItem();
			ElsIf Mode = "ExtensionsCommonData" Then
				OptionObject = Catalogs.PredefinedExtensionsReportsOptions.CreateItem();
			EndIf;
		EndIf;
		
		FillPropertyValues(OptionObject, OptionDetails, 
			"Report, VariantKey, Enabled, DefaultVisibility, GroupByReport, Purpose, ShouldShowInOptionsSubmenu");
		FieldsForSearch = FieldsForSearch(OptionObject);
		
		If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
			ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
			
			If Common.IsMainLanguage() Then
				OptionObject.Description = OptionDetails.Description;
				OptionObject.LongDesc     = OptionDetails.LongDesc;
			EndIf;
			
			If ModuleNationalLanguageSupportServer.FirstAdditionalInfobaseLanguageCode() = CurrentLanguage().LanguageCode Then
				OptionObject.DescriptionLanguage1 = ?(ValueIsFilled(OptionDetails.Description), OptionDetails.Description,
					OptionObject.Description);
				OptionObject.LongDescLanguage1     = ?(ValueIsFilled(OptionDetails.LongDesc), OptionDetails.LongDesc,
					OptionObject.LongDesc);
			EndIf;
			
			If ModuleNationalLanguageSupportServer.SecondAdditionalInfobaseLanguageCode() = CurrentLanguage().LanguageCode Then
				OptionObject.DescriptionLanguage2 = ?(ValueIsFilled(OptionDetails.Description), OptionDetails.Description,
					OptionObject.Description);
				OptionObject.LongDescLanguage2     = ?(ValueIsFilled(OptionDetails.LongDesc), OptionDetails.LongDesc,
					OptionObject.LongDesc);
			EndIf;
		EndIf;
		
		FieldsForSearch.Description = OptionDetails.Description;
		FieldsForSearch.LongDesc = OptionDetails.LongDesc;
		
		SetFieldsForSearch(OptionObject, FieldsForSearch);
		
		OptionObject.Parent = OptionDetails.ParentOption;
		
		ProcedureName = "ReportsOptionsOverridable.CustomizeReportsOptions";
		NameOfManagerModuleProcedure = Common.ObjectAttributeValue(OptionDetails.Report, "FullName");
		If TypeOf(NameOfManagerModuleProcedure) = Type("String") Then
			NameOfManagerModuleProcedure = NameOfManagerModuleProcedure + ".CustomizeReportOptions";
		Else
			NameOfManagerModuleProcedure = "";
		EndIf;
		OptionPlacement = New Array;
		For Each Section In OptionDetails.Location Do
			If Section.Key = Undefined Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'A subsystem to add the %1 report option (%2) to is not specified.
					|See the %3 and %4 procedures.';"), OptionDetails.Description,
					OptionDetails.VariantKey, ProcedureName, NameOfManagerModuleProcedure);
				WriteToLog(EventLogLevel.Error, MessageText);
				Continue;
			EndIf;
			FullName = ?(TypeOf(Section.Key) = Type("String"), Section.Key, Section.Key.FullName());
			OptionPlacement.Add(FullName);
		EndDo;
		SubsystemsIDs = Common.MetadataObjectIDs(OptionPlacement);
		For Each ReportPlacement In OptionDetails.Location Do
			If ReportPlacement.Key = Undefined Then 
				Continue;
			EndIf;
			AssignmentRow2 = OptionObject.Location.Add();
			FullName = ?(TypeOf(ReportPlacement.Key) = Type("String"), ReportPlacement.Key, ReportPlacement.Key.FullName());
			AssignmentRow2.Subsystem = SubsystemsIDs[FullName];
			AssignmentRow2.Important  = (Lower(ReportPlacement.Value) = Lower("Important"));
			AssignmentRow2.SeeAlso = (Lower(ReportPlacement.Value) = Lower("SeeAlso"));
		EndDo;
		
		If Result.UpdateMeasurements Then
			OptionObject.MeasurementsKey = OptionDetails.MeasurementsKey;
		EndIf;
		
		Result.HasChanges = True;
		WritePredefinedObject(OptionObject);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return OptionObject.Ref;
EndFunction

// Defines whether key settings of a predefined report option are changed.
Function KeySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase)
	Return (OptionFromBase.Description <> OptionDetails.Description
		Or OptionFromBase.Parent <> OptionDetails.ParentOption
		Or OptionFromBase.Purpose <> OptionDetails.Purpose
		Or OptionFromBase.DefaultVisibility <> OptionDetails.DefaultVisibility);
EndFunction

// Defines whether secondary settings of a predefined report option are changed.
//
// Parameters:
//   OptionDetails - See DefaultReportDetails
//   OptionFromBase - See DefaultReportDetails
//
Function SecondarySettingsOfPredefinedItemChanged(OptionDetails, OptionFromBase)
	// Header.
	If OptionFromBase.Enabled <> OptionDetails.Enabled
		Or OptionFromBase.LongDesc <> OptionDetails.LongDesc
		Or OptionFromBase.MeasurementsKey <> OptionDetails.MeasurementsKey
		Or OptionFromBase.GroupByReport <> OptionDetails.GroupByReport
		Or OptionFromBase.ShouldShowInOptionsSubmenu <> OptionDetails.ShouldShowInOptionsSubmenu Then
		Return True;
	EndIf;
	
	// Placement table.
	PlacementTable = OptionFromBase.Location;
	If PlacementTable.Count() <> OptionDetails.Location.Count() Then
		Return True;
	EndIf;
	
	For Each KeyAndValue In OptionDetails.Location Do
		Subsystem = Common.MetadataObjectID(KeyAndValue.Key);
		If TypeOf(Subsystem) = Type("String") Then
			Continue;
		EndIf;
		AssignmentRow2 = PlacementTable.Find(Subsystem, "Subsystem");
		If AssignmentRow2 = Undefined
			Or AssignmentRow2.Important <> (Lower(KeyAndValue.Value) = Lower("Important"))
			Or AssignmentRow2.SeeAlso <> (Lower(KeyAndValue.Value) = Lower("SeeAlso")) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

// Defines whether search settings of a predefined report option are changed.
Function SearchSettingsChanged(OptionFromBase, PreviousInfo)
	Return OptionFromBase.SettingsHash <> PreviousInfo.SettingsHash
		Or OptionFromBase.FieldDescriptions <> PreviousInfo.FieldDescriptions
		Or OptionFromBase.FilterParameterDescriptions <> PreviousInfo.FilterParameterDescriptions
		Or OptionFromBase.Keywords <> PreviousInfo.Keywords;
EndFunction

// Adjusts separated data to shared data.
Procedure UpdateReportsOptionsByPredefinedOnes(Mode, Result)
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Updating report options (%1)';"), 
		Lower(ModePresentation(Mode)));
	WriteProcedureStartToLog(ProcedurePresentation);
	
	// Update predefined option information.
	QueryText =
	"SELECT
	|	PredefinedConfigurations.Ref AS PredefinedOption,
	|	PredefinedConfigurations.Description AS Description,
	|	PredefinedConfigurations.Report AS Report,
	|	PredefinedConfigurations.GroupByReport AS GroupByReport,
	|	PredefinedConfigurations.VariantKey AS VariantKey,
	|	PredefinedConfigurations.DefaultVisibility AS DefaultVisibility,
	|	PredefinedConfigurations.Purpose AS Purpose,
	|	PredefinedConfigurations.Parent AS Parent
	|INTO ttPredefined
	|FROM
	|	Catalog.PredefinedReportsOptions AS PredefinedConfigurations
	|WHERE
	|	PredefinedConfigurations.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref,
	|	ReportsOptions.DeletionMark,
	|	ReportsOptions.Report,
	|	ReportsOptions.ReportType,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.Description AS Description,
	|	ReportsOptions.PredefinedOption,
	|	ReportsOptions.Purpose,
	|	ReportsOptions.Parent
	|INTO ttReportOptions
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	(ReportsOptions.ReportType = &ReportType
	|		OR VALUETYPE(ReportsOptions.Report) = &AttributeTypeReport)
	|	AND ReportsOptions.Custom = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN ttPredefined.PredefinedOption IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SetDeletionMark,
	|	CASE
	|		WHEN ttReportOptions.Ref IS NULL 
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CreateNew,
	|	ttPredefined.PredefinedOption AS PredefinedOption,
	|	ttPredefined.Purpose AS Purpose,
	|	ttPredefined.Description AS Description,
	|	ttPredefined.Report AS Report,
	|	ttPredefined.VariantKey AS VariantKey,
	|	ttPredefined.GroupByReport AS GroupByReport,
	|	CASE
	|		WHEN ttPredefined.Parent = &EmptyOptionRef
	|			THEN UNDEFINED
	|		ELSE ttPredefined.Parent
	|	END AS PredefinedOptionParent,
	|	ttReportOptions.Ref AS AttributeRef,
	|	ttReportOptions.Parent AS AttributeParent,
	|	ttReportOptions.Report AS AttributeReport,
	|	ttReportOptions.VariantKey AS AttributeVariantKey,
	|	ttReportOptions.Description AS AttributeDescription,
	|	ttReportOptions.PredefinedOption AS AttributePredefinedOption,
	|	ttReportOptions.Purpose AS AttributeAssignment,
	|	ttReportOptions.DeletionMark AS AttributeDeletionMark
	|FROM
	|	ttReportOptions AS ttReportOptions
	|		FULL JOIN ttPredefined AS ttPredefined
	|		ON ttReportOptions.PredefinedOption = ttPredefined.PredefinedOption";
	
	Query = New Query;
	If Mode = "SeparatedConfigurationData" Then
		Query.SetParameter("ReportType", Enums.ReportsTypes.BuiltIn);
		Query.SetParameter("AttributeTypeReport", Type("CatalogRef.MetadataObjectIDs"));
		Query.SetParameter("EmptyOptionRef", Catalogs.PredefinedReportsOptions.EmptyRef());
	ElsIf Mode = "SeparatedExtensionData" Then
		Query.SetParameter("ReportType", Enums.ReportsTypes.Extension);
		Query.SetParameter("AttributeTypeReport", Type("CatalogRef.ExtensionObjectIDs"));
		Query.SetParameter("EmptyOptionRef", Catalogs.PredefinedExtensionsReportsOptions.EmptyRef());
		QueryText = StrReplace(QueryText, ".PredefinedReportsOptions", ".PredefinedExtensionsReportsOptions");
	EndIf;
	
	AttributesToChange = New Structure("DeletionMark, Parent,
		|Description, Report, VariantKey, PredefinedOption, Purpose");
	MatchingBankDetails = New Map;
	MatchingBankDetails.Insert("DeletionMark",         "AttributeDeletionMark");
	MatchingBankDetails.Insert("Parent",                "AttributeParent");
	MatchingBankDetails.Insert("Description",            "AttributeDescription");
	MatchingBankDetails.Insert("Report",                   "AttributeReport");
	MatchingBankDetails.Insert("VariantKey",            "AttributeVariantKey");
	MatchingBankDetails.Insert("PredefinedOption", "AttributePredefinedOption");
	MatchingBankDetails.Insert("Purpose",              "AttributeAssignment");
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		LanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		
		If ValueIsFilled(LanguageSuffix) Then
			QueryText = StrReplace(QueryText, "PredefinedConfigurations.Description AS Description,", 
				"PredefinedConfigurations.Description AS Description,
				|PredefinedConfigurations.DescriptionLanguage1 AS DescriptionLanguage1,
				|PredefinedConfigurations.DescriptionLanguage2 AS DescriptionLanguage2,");
				
			QueryText = StrReplace(QueryText, "ReportsOptions.Description AS Description,", 
				"ReportsOptions.Description AS Description,
				|ReportsOptions.DescriptionLanguage1 AS DescriptionLanguage1,
				|ReportsOptions.DescriptionLanguage2 AS DescriptionLanguage2,");
				
			QueryText = StrReplace(QueryText, "ttReportOptions.Description AS AttributeDescription,",
				"ttReportOptions.Description AS AttributeDescription,
				|ttReportOptions.DescriptionLanguage1 AS AttributeDescriptionLanguage1,
				|ttReportOptions.DescriptionLanguage2 AS AttributeDescriptionLanguage2,");
				
			QueryText = StrReplace(QueryText, "ttPredefined.Description AS Description,",
				"ttPredefined.Description AS Description,
				|ttPredefined.DescriptionLanguage1 AS DescriptionLanguage1,
				|ttPredefined.DescriptionLanguage2 AS DescriptionLanguage2,");
				
			AttributesToChange.Insert("DescriptionLanguage1");
			AttributesToChange.Insert("DescriptionLanguage2");
			MatchingBankDetails.Insert("DescriptionLanguage1", "AttributeDescriptionLanguage1");
			MatchingBankDetails.Insert("DescriptionLanguage2", "AttributeDescriptionLanguage2");
			
		EndIf;
	EndIf;
	
	Query.Text = QueryText;

	PredefinedItemsPivotTable = Query.Execute().Unload();
	PredefinedItemsPivotTable.Columns.Add("Processed1", New TypeDescription("Boolean"));
	PredefinedItemsPivotTable.Columns.Add("Parent", New TypeDescription("CatalogRef.ReportsOptions"));
	
	// Update main predefined options (without a parent).
	Search = New Structure("PredefinedOptionParent, SetDeletionMark", Undefined, False);
	FoundItems = PredefinedItemsPivotTable.FindRows(Search);
	For Each TableRow In FoundItems Do
		If TableRow.Processed1 Then
			Continue;
		EndIf;
		If Result.ProcessedPredefinedItems[TableRow.PredefinedOption] <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		
		TableRow.Parent = Result.EmptyRef;
		UpdateSeparatedPredefinedItem(Result, AttributesToChange, TableRow, MatchingBankDetails);
		
		If Not TableRow.SetDeletionMark
			And TableRow.GroupByReport
			And Result.SearchForParents[TableRow.Report] = Undefined Then
			Result.SearchForParents[TableRow.Report] = TableRow.AttributeRef;
			
			MainOption = Result.MainOptions.Add();
			MainOption.Report   = TableRow.Report;
			MainOption.Variant = TableRow.AttributeRef;
		EndIf;
	EndDo;
	
	// Update all remaining predefined options (subordinates).
	PredefinedItemsPivotTable.Sort("SetDeletionMark Asc");
	For Each TableRow In PredefinedItemsPivotTable Do
		If TableRow.Processed1 Then
			Continue;
		EndIf;
		If Result.ProcessedPredefinedItems[TableRow.PredefinedOption] <> Undefined Then
			TableRow.SetDeletionMark = True;
		EndIf;
		If TableRow.SetDeletionMark Then
			ParentReference = Result.EmptyRef;
		Else
			ParentReference = Result.SearchForParents[TableRow.Report];
		EndIf;
		
		TableRow.Parent = ParentReference;
		UpdateSeparatedPredefinedItem(Result, AttributesToChange, TableRow, MatchingBankDetails);
	EndDo;
	
	// Update user option parents.
	QueryText = 
	"SELECT
	|	MainReportsOptions.Report,
	|	MainReportsOptions.Variant
	|INTO ttMain
	|FROM
	|	&MainReportsOptions AS MainReportsOptions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReportsOptions.Ref,
	|	ttMain.Variant AS Parent
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		INNER JOIN ttMain AS ttMain
	|		ON ReportsOptions.Report = ttMain.Report
	|			AND ReportsOptions.Parent <> ttMain.Variant
	|			AND ReportsOptions.Parent.Parent <> ttMain.Variant
	|			AND ReportsOptions.Ref <> ttMain.Variant
	|WHERE
	|	ReportsOptions.Custom 
	|	OR NOT ReportsOptions.DeletionMark";
	
	Query = New Query;
	Query.SetParameter("MainReportsOptions", Result.MainOptions);
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Result.HasChanges = True;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ReportsOptions");
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			OptionObject = Selection.Ref.GetObject();
			OptionObject.Parent = Selection.Parent;
			InfobaseUpdate.WriteObject(OptionObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;	
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Updates predefined data in separated mode.
Procedure UpdateSeparatedPredefinedItem(Result, AttributesToChange, TableRow, MatchingBankDetails)
	If TableRow.Processed1 Then
		Return;
	EndIf;
	
	TableRow.Processed1 = True;
	
	If TableRow.SetDeletionMark Then 
		
		If TableRow.AttributeParent = Result.EmptyRef 
			And TableRow.AttributeDeletionMark = True Then
			Return; // Already marked.
		EndIf;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ReportsOptions");
			LockItem.SetValue("Ref", TableRow.AttributeRef);
			Block.Lock();
			
			OptionObject = TableRow.AttributeRef.GetObject();
			OptionObject.Lock();
			
			OptionObject.Parent = Result.EmptyRef;
			OptionObject.DeletionMark = True;
			InfobaseUpdate.WriteObject(OptionObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;	
		
		Result.HasChanges = True;
		Return;
	EndIf;
		
	If TableRow.GroupByReport And Not ValueIsFilled(TableRow.PredefinedOptionParent) Then
		TableRow.Parent = Result.EmptyRef;
	EndIf;
	Result.ProcessedPredefinedItems[TableRow.PredefinedOption] = True;
	FillPropertyValues(AttributesToChange, TableRow);
	AttributesToChange.DeletionMark = False;
	
	If Not TableRow.CreateNew And PropertiesValuesMatch(AttributesToChange, TableRow, MatchingBankDetails) Then
		Return; // No changes.
	EndIf;
	
	BeginTransaction();
	Try
		If TableRow.CreateNew Then // Add.
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.PredefinedOption = TableRow.PredefinedOption;
			OptionObject.Custom = False;
		Else // Update (if has changes).
			Block = New DataLock;
			LockItem = Block.Add("Catalog.ReportsOptions");
			LockItem.SetValue("Ref", TableRow.AttributeRef);
			Block.Lock();
			
			// Transfer user settings.
			ReplaceUserSettingsKeys(AttributesToChange, TableRow);
			
			OptionObject = TableRow.AttributeRef.GetObject();
		EndIf;
		
		FillPropertyValues(OptionObject, AttributesToChange);
		
		ReportByStringType = ReportsOptionsClientServer.ReportByStringType(Undefined, OptionObject.Report);
		OptionObject.ReportType = Enums.ReportsTypes[ReportByStringType];
		InfobaseUpdate.WriteObject(OptionObject);
		
		If TableRow.CreateNew Then
			InformationRegisters.ReportOptionsSettings.WriteReportOptionAvailabilitySettings(
				OptionObject.Ref, TableRow.CreateNew);
		EndIf;
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
		
	Result.HasChanges = True;
	If TableRow.CreateNew Then	
		TableRow.AttributeRef = OptionObject.Ref;
	EndIf;
	
EndProcedure

// Returns True if values of the Structure and Collection properties match the PrefixInCollection prefix.
Function PropertiesValuesMatch(Structure, Collection, MatchingBankDetails)
	For Each KeyAndValue In Structure Do
		If Collection[MatchingBankDetails[KeyAndValue.Key]] <> KeyAndValue.Value Then
			Return False;
		EndIf;
	EndDo;
	Return True;
EndFunction

// Setting a deletion mark for deleted report options.
Procedure MarkOptionsOfDeletedReportsForDeletion(Mode, Result)
	
	ProcedurePresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Deleting options of deleted reports (%1)';"), 
		Lower(ModePresentation(Mode)));
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	
	// ACC:1377-off "Report" attribute consists of 4 types. For this scenario, dereferencing is not essential.
	QueryText =
	"SELECT
	|	ReportsOptions.Ref AS Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	NOT ReportsOptions.DeletionMark
	|	AND ReportsOptions.ReportType = &ReportType
	|	AND ISNULL(ReportsOptions.Report.DeletionMark, TRUE)";
	// ACC:1377-on
	
	TableName = "Catalog.ReportsOptions";
	If Mode = "ConfigurationCommonData" Then
		QueryText = StrReplace(QueryText, ".ReportsOptions", ".PredefinedReportsOptions");
		QueryText = StrReplace(QueryText, "ReportsOptions.ReportType = &ReportType", "True");
		TableName = "Catalog.PredefinedReportsOptions";
	ElsIf Mode = "ExtensionsCommonData" Then
		QueryText = StrReplace(QueryText, ".ReportsOptions", ".PredefinedExtensionsReportsOptions");
		QueryText = StrReplace(QueryText, "ReportsOptions.ReportType = &ReportType", "True");
		TableName = "Catalog.PredefinedExtensionsReportsOptions";
	ElsIf Mode = "SeparatedConfigurationData" Then
		Query.SetParameter("ReportType", Enums.ReportsTypes.BuiltIn);
	ElsIf Mode = "SeparatedExtensionData" Then
		Query.SetParameter("ReportType", Enums.ReportsTypes.Extension);
	EndIf;
	
	Query.Text = QueryText;
	
	OptionsToDeleteRefs = Query.Execute().Unload().UnloadColumn("Ref");
	For Each OptionRef In OptionsToDeleteRefs Do
		Result.HasChanges = True;
		Result.HasImportantChanges = True;
		
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(TableName);
			LockItem.SetValue("Ref", OptionRef);
			Block.Lock();
			
			OptionObject = OptionRef.GetObject();
			If OptionObject = Undefined Then
				RollbackTransaction();
				Continue;
			EndIf;
			OptionObject.Lock();
			OptionObject.DeletionMark = True;
			WritePredefinedObject(OptionObject);
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Transfer custom settings of the option from the relevant storage.
//
// Parameters:
//   OldOption - Structure - Values of report option attributes, where::
//       * Ref - CatalogRef.ReportsOptions - Report option reference.
//   UpdatedOption - ValueTableRow
//
Procedure ReplaceUserSettingsKeys(OldOption, UpdatedOption)
	If OldOption.VariantKey = UpdatedOption.VariantKey
		Or Not ValueIsFilled(OldOption.VariantKey)
		Or Not ValueIsFilled(UpdatedOption.VariantKey)
		Or TypeOf(UpdatedOption.Report) <> Type("CatalogRef.MetadataObjectIDs") Then
		Return;
	EndIf;
	
	ReportFullName = UpdatedOption.Report.FullName;
	OldObjectKey = ReportFullName + "/" + OldOption.VariantKey;
	NewObjectKey = ReportFullName + "/" + UpdatedOption.VariantKey;
	
	Filter = New Structure("ObjectKey", OldObjectKey);
	StorageSelection = ReportsUserSettingsStorage.Select(Filter);
	SuccessiveReadingErrors = 0;
	While True Do
		// Read settings from the storage by the old key.
		Try
			GotSelectionItem = StorageSelection.Next();
			SuccessiveReadingErrors = 0;
		Except
			GotSelectionItem = Undefined;
			SuccessiveReadingErrors = SuccessiveReadingErrors + 1;
			WriteToLog(EventLogLevel.Error,
				NStr("en = 'Cannot read report options from the standard storage due to:';")
					+ Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo()),
				OldOption.Ref);
		EndTry;
		
		If GotSelectionItem = False Then
			Break;
		ElsIf GotSelectionItem = Undefined Then
			If SuccessiveReadingErrors > 100 Then
				Break;
			Else
				Continue;
			EndIf;
		EndIf;
		
		// Read settings details.
		SettingsDescription = ReportsUserSettingsStorage.GetDescription(
			StorageSelection.ObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.User);
		
		// Write settings to the storage by a new key.
		ReportsUserSettingsStorage.Save(
			NewObjectKey,
			StorageSelection.SettingsKey,
			StorageSelection.Settings,
			SettingsDescription,
			StorageSelection.User);
	EndDo;
	
	// Clear old storage settings.
	ReportsUserSettingsStorage.Delete(OldObjectKey, Undefined, Undefined);
EndProcedure

// Writes a predefined object.
Procedure WritePredefinedObject(OptionObject)
	OptionObject.AdditionalProperties.Insert("PredefinedObjectsFilling");
	InfobaseUpdate.WriteObject(OptionObject);
EndProcedure

// Registers changes in the measurement table.
//
// Parameters:
//   OldKey - String - Previous measurement key.
//   UpdatedKey - String - Current measurement key.
//   UpdatedDescription - String - Report's current description.
//   Result - See CommonDataUpdateResult
//
Procedure RegisterOptionMeasurementsForUpdate(Val OldKey, Val UpdatedKey, Val UpdatedDescription, Result)
	If IsBlankString(OldKey) Then
		OldKey = UpdatedKey;
	EndIf;
	
	MeasurementsTable = Result.MeasurementsTable; // ValueTable
	
	MeasurementUpdating = MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Opening";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Opening";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report %1 (open)';"), UpdatedDescription);
	
	MeasurementUpdating = MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Generation1";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Generation1";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report %1 (generate)';"), UpdatedDescription);
	
	MeasurementUpdating = MeasurementsTable.Add();
	MeasurementUpdating.OldName     = OldKey     + ".Settings";
	MeasurementUpdating.UpdatedName = UpdatedKey + ".Settings";
	MeasurementUpdating.UpdatedDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Report %1 (settings)';"), UpdatedDescription);
EndProcedure

// Write report option parameters (metadata cache for application speed).
//
// Parameters:
//   Mode - String - Update mode: ConfigurationCommonData or ExtensionsCommonData.
//   Result - Structure:
//     * ReportsOptions - See PredefinedReportsOptions
//     * HasImportantChanges - Boolean - Flag indicating whether the report options have important changes.
//     * HasChanges - Boolean - Flag indicating whether the report options have changes.
//     * SaaSModel - Boolean - Flag indicating whether the mode is SaaS.
//     * UpdateMeasurements - Boolean - Flag indicating whether the PerformanceMonitor subsystem is integrated.
//     * UpdateConfiguration1 - Boolean - Flag indicating whether configuration data must be updated.
//     * UpdateExtensions - Boolean - Flag indicating whether extension data must be updated.
//     * ReportsWithSettingsList - ValueList:
//         ** Value - CatalogRef.MetadataObjectIDs - Reports whose object module contains
//                                                                           procedures of integrating with the common report form.
//     * SeparatedHandlers - Undefined
//                              - Structure
//     * MeasurementsTable - See MeasurementsTable
//     * FunctionalOptionsTable - ValueTable - Association between functional options and predefined report options::
//         ** Report - CatalogRef.MetadataObjectIDs
//         ** PredefinedOption - CatalogRef.PredefinedReportsOptions
//         ** FunctionalOptionName - String
//
Procedure WriteFunctionalOptionsTable(Mode, Result)
	If Mode = "ExtensionsCommonData" And Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return; // The update is not required.
	EndIf;
	ProcedurePresentation = NStr("en = 'Save shared cache to register';");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Result.FunctionalOptionsTable.Sort("Report, PredefinedOption, FunctionalOptionName");
	Result.ReportsWithSettingsList.SortByValue();
	
	NewValue = New Structure;
	NewValue.Insert("FunctionalOptionsTable", Result.FunctionalOptionsTable);
	NewValue.Insert("ReportsWithSettings", Result.ReportsWithSettingsList.UnloadValues());
	
	FullSubsystemName = ReportsOptionsClientServer.FullSubsystemName();
	
	If Mode = "ConfigurationCommonData" Then
		StandardSubsystemsServer.SetApplicationParameter(FullSubsystemName, NewValue);
	ElsIf Mode = "ExtensionsCommonData" Then
		StandardSubsystemsServer.SetExtensionParameter(FullSubsystemName, NewValue);
	EndIf;
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

// Write the PredefinedExtensionsVersionsReportsOptions register.
//
// Value to save:
//   ValueStorage (Structure) - Cached parameters:
//       * FunctionalOptionsTable - ValueTable - Options and predefined report options names.
//           ** Report - CatalogRef.ExtensionObjectIDs - Report reference.
//           ** PredefinedOption - CatalogRef.PredefinedExtensionsReportsOptions - The option reference.
//           ** FunctionalOptionName - String - Functional option name.
//       * ReportsWithSettings - Array from CatalogRef.ExtensionObjectIDs - reports
//           whose object module contains procedures of deep integration with the common report form.
//
Procedure RecordCurrentExtensionsVersion()
	If Not ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		Return; // The update is not required.
	EndIf;
	
	ProcedurePresentation = NStr("en = 'Save extension version register';");
	WriteProcedureStartToLog(ProcedurePresentation);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PredefinedExtensions.Ref AS Variant,
	|	PredefinedExtensions.Report,
	|	PredefinedExtensions.VariantKey
	|FROM
	|	Catalog.PredefinedExtensionsReportsOptions AS PredefinedExtensions
	|WHERE
	|	PredefinedExtensions.DeletionMark = FALSE";
	
	Table = Query.Execute().Unload();
	Dimensions = New Structure("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Resources = New Structure;
	Set = InformationRegisters.PredefinedExtensionsVersionsReportsOptions.Set(Table, Dimensions, Resources, True);
	InfobaseUpdate.WriteRecordSet(Set, True);
	
	WriteProcedureCompletionToLog(ProcedurePresentation);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update of presentations in other languages.

// Handler of the "PredefinedReportOptionsUpdate" scheduled job.
Procedure FillPredefinedReportsOptionsPresentations(Languages, CurrentLanguageIndex) Export
	
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.PredefinedReportOptionsUpdate);
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	ParametersOfUpdate = SettingsUpdateParameters();
	ParametersOfUpdate.Deferred2 = True;
	ParametersOfUpdate.FillPresentations1 = False;
	
	Refresh(ParametersOfUpdate);
	
	If CurrentLanguageIndex < Languages.UBound() Then
		
		SchedulePresentationsFilling(Languages, CurrentLanguageIndex + 1);
		Return;
		
	EndIf;
	
	JobMetadata = Metadata.ScheduledJobs.PredefinedReportOptionsUpdate;
	Jobs = ScheduledJobsServer.FindJobs(New Structure("Metadata", JobMetadata));
	
	For Each Job In Jobs Do
		Job.Delete();
	EndDo;

EndProcedure

Procedure SchedulePresentationsFilling(Val Languages = Undefined, Val CurrentLanguageIndex = 0)
	
	If Common.FileInfobase() Then
		Return;
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	FillParameters = ReportsOptionsPresentationsFillingParameters(Languages, CurrentLanguageIndex);
	If FillParameters = Undefined Then 
		Return;
	EndIf;
	
	JobsFilter = New Structure("Metadata, Key");
	FillPropertyValues(JobsFilter, FillParameters);
	
	Jobs = ScheduledJobsServer.FindJobs(JobsFilter);
	
	PresentationsFilling = ?(Jobs.Count() = 0, Undefined, Jobs[0]);
	If PresentationsFilling = Undefined Then 
		
		PresentationsFilling = ScheduledJobsServer.AddJob(FillParameters);
		Return;
		
	ElsIf PresentationsFilling.Use Then 
		Return;
	EndIf;
	
	FillPropertyValues(PresentationsFilling, FillParameters);
	PresentationsFilling.Write();
	
EndProcedure

Function ReportsOptionsPresentationsFillingParameters(Languages = Undefined, CurrentLanguageIndex = 0)
	
	If Languages = Undefined Then
		Languages = LanguagesOfReportsOptionsPresentationsForFilling();
	EndIf;
	
	If CurrentLanguageIndex > Languages.UBound() Then
		Return Undefined;
	EndIf;
	
	LanguageCode = Languages[CurrentLanguageIndex];
	InternalUser = InternalUser(LanguageCode);
	
	If InternalUser = Undefined Then 
		Return Undefined;
	EndIf;
	
	JobMetadata = Metadata.ScheduledJobs.PredefinedReportOptionsUpdate;
	JobKey = "ReportsOptionsPresentationsFillingForLanguage" + Upper(LanguageCode);
	JobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Populating presentations of predefined report options for the %1 language';"), LanguageCode);
	
	JobParameters = New Array;
	JobParameters.Add(Languages);
	JobParameters.Add(CurrentLanguageIndex);
	
	TaskSchedule = New JobSchedule;
	TaskSchedule.BeginTime = CurrentSessionDate() + 60;
	
	FillParameters = New Structure;
	FillParameters.Insert("Metadata", JobMetadata);
	FillParameters.Insert("UserName", InternalUser);
	FillParameters.Insert("Key", JobKey);
	FillParameters.Insert("Description", JobDescription);
	FillParameters.Insert("Parameters", JobParameters);
	FillParameters.Insert("Schedule", TaskSchedule);
	FillParameters.Insert("Use", True);
	
	Return FillParameters;
	
EndFunction

Function LanguagesOfReportsOptionsPresentationsForFilling()
	
	Languages = New Array;
	
	CodeCurrentLanguage = ?(TypeOf(CurrentLanguage()) = Type("String"), CurrentLanguage(), CurrentLanguage().LanguageCode);
	
	Exceptions = New Array;
	Exceptions.Add(CodeCurrentLanguage);
	Exceptions.Add(Common.DefaultLanguageCode());
	
	For Each Language In Metadata.Languages Do
		
		If Exceptions.Find(Language) = Undefined Then
			Languages.Add(Language.LanguageCode);
		EndIf;
		
	EndDo;
	
	Return Languages;
	
EndFunction

Function InternalUser(Val LanguageCode)
	
	UserName = InternalUsername();
	
	// Update the infobase user.
	IBUser = InfoBaseUsers.FindByName(UserName);
	
	If IBUser = Undefined Then
		If InfoBaseUsers.GetUsers().Count() = 0 Then 
			Return Undefined;
		EndIf;
		
		IBUser = InfoBaseUsers.CreateUser();
		IBUser.Name = UserName;
		IBUser.Password = String(New UUID);
		IBUser.CannotChangePassword = True;
		IBUser.ShowInList = False;
	EndIf;
	
	IBUser.Language = LanguageByCode(LanguageCode);
	IBUser.Write();
	
	// Update the user (an item of the Users catalog).
	IBUserDetails = New Structure;
	IBUserDetails.Insert("Action", "Write");
	IBUserDetails.Insert("Name", IBUser.Name);
	IBUserDetails.Insert("StandardAuthentication", True);
	IBUserDetails.Insert("ShowInList", IBUser.ShowInList);
	IBUserDetails.Insert("UUID", IBUser.UUID);
	
	Filter = New Structure("IBUserID", IBUser.UUID);
	Selection = Catalogs.Users.Select(,, Filter);
	IsNew = Not Selection.Next();
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		LockItem = Block.Add(Metadata.Catalogs.Users.FullName());
		
		If Not IsNew Then 
			LockItem.SetValue("Ref", Selection.Ref);
		EndIf;
		
		Block.Lock();
		
		If IsNew Then 
			User = Catalogs.Users.CreateItem();
		Else
			User = Selection.Ref.GetObject();
		EndIf;
		
		User.Description = IBUser.Name;
		User.IsInternal = True;
		User.AdditionalProperties.Insert("IBUserDetails", IBUserDetails);
		User.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteLogEvent(
			NStr("en = 'Report options.Create utility user';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Users,,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
		Return Undefined;
	EndTry;
	
	Return IBUser.Name;
	
EndFunction

// Returns metadata by the configuration language code.
//
// Parameters:
//   LanguageCode - String - Language code, for example "en" (as it is set in the LanguageCode property of the MetadataObject metadata: Language).
//
// Returns:
//   MetadataObjectLanguage - If it's found by the passed language code. Otherwise, Undefined.
//   
Function LanguageByCode(Val LanguageCode)
	For Each Language In Metadata.Languages Do
		If Language.LanguageCode = LanguageCode Then
			Return Language;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

Function InternalUsername()
	
	Return "ServiceUserToUpdatePresentations";
	
EndFunction

Function ModePresentation(Mode)
	
	Modes = New Map;
	Modes.Insert("ConfigurationCommonData", NStr("en = 'Shared configuration data';"));
	Modes.Insert("ExtensionsCommonData", NStr("en = 'Shared extension data';"));
	Modes.Insert("SeparatedConfigurationData", NStr("en = 'Separate configuration data';"));
	Modes.Insert("SeparatedExtensionData", NStr("en = 'Separate extension data';"));
	
	ModePresentation = Modes.Get(Mode);
	
	Return ?(ModePresentation = Undefined, "", ModePresentation);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Operations with the subsystem tree from forms.

// Adds conditional appearance items of the subsystem tree.
//
// Parameters:
//   Form - ClientApplicationForm - ReportsOptions catalog item form, report option saving form,
//           or report option location setup form, where::
//       * Items - FormAllItems - Items of the passed form, where::
//             ** SubsystemsTree - FormTable - List of available configuration sections.
//             ** SubsystemsTreeImportance - FormField - Form table field to set the importance of a report option.
//             ** SubsystemsTreeUse - FormField - Flag indicating whether a report option is used in the matching section.
//
Procedure SetSubsystemsTreeConditionalAppearance(Form) Export
	
	FormItems = Form.Items;
	
	SubsystemsTree = FormItems.SubsystemsTree; // FormTable
	ReportUsageFlag = FormItems.SubsystemsTreeUse; // FormField
	ReportImportanceField = FormItems.SubsystemsTreeImportance; // FormField
	
	ReportImportanceOptions = ReportImportanceField.ChoiceList; // ValueList
	ReportImportanceOptions.Add(ImportantPresentation());
	ReportImportanceOptions.Add(SeeAlsoPresentation());
	
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(SubsystemsTree.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SubsystemsTree.Priority");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(ReportUsageFlag.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(ReportImportanceField.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("SubsystemsTree.Priority");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "";

	Item.Appearance.SetParameterValue("Show", False);
	
EndProcedure

// Generates a subsystem tree according to base option data.
Function SubsystemsTreeGenerate(Form, OptionBasis) Export
	// Empty tree without settings.
	Prototype = Form.FormAttributeToValue("SubsystemsTree", Type("ValueTree")); // ValueTree
	SubsystemsTree = ReportsOptionsCached.CurrentUserSubsystems().Tree.Copy();
	For Each PrototypeColumn In Prototype.Columns Do
		If SubsystemsTree.Columns.Find(PrototypeColumn.Name) = Undefined Then
			SubsystemsTree.Columns.Add(PrototypeColumn.Name, PrototypeColumn.ValueType);
		EndIf;
	EndDo;
	
	// Parameters.
	Context = New Structure("SubsystemsTree");
	Context.SubsystemsTree = SubsystemsTree;
	
	// Location set by the administrator.
	Subsystems = New Array;
	For Each AssignmentRow2 In OptionBasis.Location Do
		Subsystems.Add(AssignmentRow2.Subsystem);
		SubsystemsTreeRegisterSubsystemsSettings(Context, AssignmentRow2, AssignmentRow2.Use);
	EndDo;
	
	// Default layout set by the developer.
	QueryText = 
	"SELECT
	|	Location.Ref,
	|	Location.LineNumber,
	|	Location.Subsystem,
	|	Location.Important,
	|	Location.SeeAlso
	|FROM
	|	Catalog.PredefinedReportsOptions.Location AS Location
	|WHERE
	|	Location.Ref = &Ref
	|	AND NOT Location.Subsystem IN (&Subsystems)";
	
	If TypeOf(OptionBasis.PredefinedOption) = Type("CatalogRef.PredefinedExtensionsReportsOptions") Then
		QueryText = StrReplace(QueryText, "PredefinedReportsOptions", "PredefinedExtensionsReportsOptions");
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", OptionBasis.PredefinedOption);
	// Do not read subsystem settings predefined by the administrator.
	Query.SetParameter("Subsystems", Subsystems);
	PredefinedItemPlacement = Query.Execute().Unload();
	For Each AssignmentRow2 In PredefinedItemPlacement Do
		SubsystemsTreeRegisterSubsystemsSettings(Context, AssignmentRow2, True);
	EndDo;
	
	Return Context.SubsystemsTree;
EndFunction

// Adds a subsystem to the tree.
//
// Parameters:
//   Context - Structure - Properties of the report location setting, where::
//       * SubsystemsTree - ValueTree - List of subsystems that use the report, where::
//             ** Importance - String - Report importance.
//
Procedure SubsystemsTreeRegisterSubsystemsSettings(Context, AssignmentRow2, Use)
	Search = New Structure("Ref", AssignmentRow2.Subsystem);
	FoundItems = Context.SubsystemsTree.Rows.FindRows(Search, True);
	If FoundItems.Count() = 0 Then
		Return;
	EndIf;
	
	TreeRow = FoundItems[0];
	
	If AssignmentRow2.Important Then
		TreeRow.Importance = ImportantPresentation();
	ElsIf AssignmentRow2.SeeAlso Then
		TreeRow.Importance = SeeAlsoPresentation();
	Else
		TreeRow.Importance = "";
	EndIf;
	TreeRow.Use = Use;
EndProcedure

// Saves location settings changed by the user to the tabular section of the report option.
//
// Parameters:
//   OptionObject - CatalogObject.ReportsOptions - Report option object, where::
//   ChangedSubsystems - Array of ValueTreeRow - Value tree rows with a changed location, where::
//       * Ref - CatalogRef.ExtensionObjectIDs
//                - CatalogRef.MetadataObjectIDs - Subsystem metadata ID.
//       * Importance - String - Report importance for the subsystem.
//
Procedure SubsystemsTreeWrite(OptionObject, ChangedSubsystems) Export
	For Each Subsystem In ChangedSubsystems Do 
		LineOfATabularSection = OptionObject.Location.Find(Subsystem.Ref, "Subsystem");
		If LineOfATabularSection = Undefined Then
			// Register the report option's location setting unconditionally ("Use" is cleared).
			// - Only in this case, the setting will replace the predefined one (from the shared catalog).
			LineOfATabularSection = OptionObject.Location.Add();
			LineOfATabularSection.Subsystem = Subsystem.Ref;
		EndIf;
		
		If Subsystem.Use = 0 Then
			LineOfATabularSection.Use = False;
		ElsIf Subsystem.Use = 1 Then
			LineOfATabularSection.Use = True;
		Else
			// Keep as-is.
		EndIf;
		
		If Subsystem.Importance = ImportantPresentation() Then
			LineOfATabularSection.Important  = True;
			LineOfATabularSection.SeeAlso = False;
		ElsIf Subsystem.Importance = SeeAlsoPresentation() Then
			LineOfATabularSection.Important  = False;
			LineOfATabularSection.SeeAlso = True;
		Else
			LineOfATabularSection.Important  = False;
			LineOfATabularSection.SeeAlso = False;
		EndIf;
	EndDo;
EndProcedure

// Importance group presentation.
//
// Returns:
//   String - Report importance.
//
Function SeeAlsoPresentation() Export
	Return NStr("en = 'See also:';");
EndFunction 

// Importance group presentation.
//
// Returns:
//   String - Report importance.
//
Function ImportantPresentation() Export
	Return NStr("en = 'Important';");
EndFunction

// Separator that is used to display several descriptions in the interface.
Function PresentationSeparator()
	Return ", ";
EndFunction

// The function converts a report type into a string ID.
Function ReportType(ReportRef) Export
	RefType = TypeOf(ReportRef);
	If RefType = Type("CatalogRef.MetadataObjectIDs") Then
		Return Enums.ReportsTypes.BuiltIn;
	ElsIf RefType = Type("CatalogRef.ExtensionObjectIDs") Then
		Return Enums.ReportsTypes.Extension;
	ElsIf RefType = Type("String") Then
		Return Enums.ReportsTypes.External;
	ElsIf RefType = AdditionalReportRefType() Then
		Return Enums.ReportsTypes.Additional;
	EndIf;
	Return Enums.ReportsTypes.EmptyRef();
EndFunction

Function ReportByStringType(ReportRef) Export
	RefType = TypeOf(ReportRef);
	
	If RefType = Type("CatalogRef.MetadataObjectIDs") Then
		Return "BuiltIn";
	ElsIf RefType = Type("CatalogRef.ExtensionObjectIDs") Then
		Return "Extension";
	ElsIf RefType = Type("String") Then
		Return "External";
	ElsIf RefType = AdditionalReportRefType() Then
		Return "Additional";
	EndIf;
	
	Return Undefined;
EndFunction

// Returns an additional report reference type.
Function AdditionalReportRefType()
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Return Type("CatalogRef.AdditionalReportsAndDataProcessors");
	EndIf;
	
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Manage the report option list.

// Handler for setting conditional appearance of the list of report option users.
//
// Parameters:
//  Form - ClientApplicationForm - Form for saving a report option or a form of a report option catalog item, where::
//      * Items - FormAllItems - Items of the given form.
//
Procedure SetConditionalAppearanceOfReportOptionUsersList(Form) Export 
	
	FormItems = Form.Items;
	UserValueField = FormItems.OptionUsersValue; // FormField
	
	//
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(UserValueField.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionUsers.Value");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	Item.Appearance.SetParameterValue("Text", NStr("en = 'All users';"));
	
	//
	Item = Form.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(UserValueField.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("OptionUsers.Presentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "[IsReportOptionAuthor]";
	
	FontImportantLabel = Metadata.StyleItems.ImportantLabelFont;
	Item.Appearance.SetParameterValue("Font", FontImportantLabel.Value);
	Item.Appearance.SetParameterValue("Text", New DataCompositionField("OptionUsers.Value"));
	
EndProcedure

// Handler of setting user list properties depending on the Availability radio button.
//
// Parameters:
//  Form - ClientApplicationForm - Form for saving a report option or a form of a report option catalog item, where::
//      * Items - FormAllItems - Items of the given form.
//      * UseUserGroups - FormAttribute
//                                        - Boolean - Flag indicating whether the UserGroups catalog
//                                                   is used in the infobase.
//      * UseExternalUsers - FormAttribute
//                                         - Boolean - Flag indicating whether the ExternalUserGroups catalog
//                                                    is used in the infobase.
//
Procedure DefineReportOptionUsersListBehavior(Form) Export 
	
	Items = Form.Items;
	PickingSubmenu = Items.OptionUsersPickGroup; // FormGroup
	
	PickingAvailable = Not Items.Available.ReadOnly
		And AccessRight("Read", Metadata.Catalogs.Users);
	
	GroupsUsed = Form.UseUserGroups Or Form.UseExternalUsers;
	
	Items.OptionUsersCheckBox.Visible = Not GroupsUsed;
	
	If Not PickingAvailable Then
		Items.OptionUsers.ReadOnly = True;
		PickingSubmenu.Visible = False;
		Items.OptionUsersPickGroupUsers.Visible = False;
		Items.OptionUsersPickExternalUsersGroups.Visible = False;
		Items.OptionUsersDelete.Visible = False;
		Items.OptionUsersPickUsers.Visible = False;
		Items.OptionUsersContextMenuCheckAll.Visible = False;
		Items.OptionUsersContextMenuUncheckAll.Visible = False;
		Return;
	EndIf;
	
	PickingSubmenu.Visible = Form.UseUserGroups And Form.UseExternalUsers;
	Items.OptionUsersPickUsers.Visible = Not PickingSubmenu.Visible;
	
	Items.OptionUsersDelete.Visible = GroupsUsed;
	Items.OptionUsers.ChangeRowSet = GroupsUsed And PickingAvailable;
	
	Items.OptionUsersContextMenuCheckAll.Visible = Not GroupsUsed;
	Items.OptionUsersContextMenuUncheckAll.Visible = Not GroupsUsed;
	
EndProcedure

// Returns keys of user settings of the matching report option.
//
// Parameters:
//  ReportVariant - CatalogRef.ReportsOptions - Reference to a report option.
//  User - CatalogRef.ExternalUsers
//               - CatalogRef.Users - Reference to the settings user.
//  SettingsKey - String
//                - Undefined - User settings ID.
//
// Returns:
//   ValueTable, Undefined - Collection of user settings keys, where::
//       * Description - String - Settings description.
//       * Variant - CatalogRef.ReportsOptions - Reference to a report option.
//       * User - CatalogRef.ExternalUsers
//                      - CatalogRef.Users - Reference to the settings user.
//       * UserSettingKey - String - User settings ID.
//
Function UserReportOptionSettings(ReportVariant, Val User, SettingsKey = Undefined)
	
	If TypeOf(ReportVariant) <> Type("CatalogRef.ReportsOptions") Then 
		Return Undefined;
	EndIf;
	
	If TypeOf(User) = Type("Array") Then
		UsersList = User;
	Else
		UsersList = New Array;
		UsersList.Add(User);
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	Settings.*
	|FROM
	|	Catalog.UserReportSettings AS Settings
	|WHERE
	|	Settings.Variant = &ReportVariant
	|	AND (NOT &SettingKeyDefined
	|		OR Settings.UserSettingKey = &SettingsKey)
	|	AND Settings.User IN(&User)
	|
	|ORDER BY
	|	Settings.DeletionMark");
	
	Query.SetParameter("ReportVariant", ReportVariant);
	Query.SetParameter("User", UsersList);
	Query.SetParameter("SettingKeyDefined", SettingsKey <> Undefined);
	Query.SetParameter("SettingsKey", SettingsKey);
	
	Return Query.Execute().Unload();
	
EndFunction

Procedure DisplayTheFlagForNotifyingUsersOfTheReportVariant(Flag) Export 
	
	If Not Common.SubsystemExists("StandardSubsystems.Conversations") Then
		Flag.Visible = False;
		Return;
	EndIf;
	
	ModuleConversations = Common.CommonModule("Conversations");
	If Not ModuleConversations.CollaborationSystemConnected() Then
		Flag.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Generate the presentations of search filters, fields, and parameters.

// The function is called from the OnWrite option event.
// Returns:
//   Boolean - True if the search fields are filled in and OptionObject must be written.
//
Function FillFieldsForSearch(OptionObject, ReportInfo = Undefined) Export
	
	FieldsForSearch = FieldsForSearch(OptionObject);
	
	CheckHash = ReportInfo = Undefined Or Not ReportInfo.IndexSchema;
	If CheckHash Then
		// Check if fields were filled in earlier.
		FillFields = Left(FieldsForSearch.FieldDescriptions, 1) <> "#";
		FillParametersAndFilters = Left(FieldsForSearch.FilterParameterDescriptions, 1) <> "#";
		If Not FillFields And Not FillParametersAndFilters Then
			Return False; // No need to populate.
		EndIf;
	Else	
		FillFields = True;
		FillParametersAndFilters = True;
	EndIf;
	
	// Get a report object, DCS settings, and a report option.
	IsPredefined = IsPredefinedReportOption(OptionObject);
	
	// Preset search settings.
	SearchSettings = ?(ReportInfo <> Undefined, ReportInfo.SearchSettings, Undefined);
	If SearchSettings <> Undefined Then
		WritingRequired = False;
		If ValueIsFilled(SearchSettings.FieldDescriptions) Then
			FieldsForSearch.FieldDescriptions = "#" + TrimAll(SearchSettings.FieldDescriptions);
			FillFields = False;
			WritingRequired = True;
		EndIf;
		If ValueIsFilled(SearchSettings.FilterParameterDescriptions) Then
			FieldsForSearch.FilterParameterDescriptions = "#" + TrimAll(SearchSettings.FilterParameterDescriptions);
			FillParametersAndFilters = False;
			WritingRequired = True;
		EndIf;
		If ValueIsFilled(SearchSettings.Keywords) Then
			FieldsForSearch.Keywords = "#" + TrimAll(SearchSettings.Keywords);
			WritingRequired = True;
		EndIf;
		If Not FillFields And Not FillParametersAndFilters Then
			SetFieldsForSearch(OptionObject, FieldsForSearch);
			Return WritingRequired; // Filling is completed, write the object.
		EndIf;
	EndIf;
	
	// In some scenarios, an object can be already cached in additional properties.
	ReportObject = ?(ReportInfo <> Undefined, ReportInfo.ReportObject, Undefined);
	
	// When a report object is not cached, attach an object in the regular way.
	If ReportObject = Undefined Then
		Connection = AttachReportObject(OptionObject.Report, False);
		If Connection.Success Then
			ReportObject = Connection.Object;
		EndIf;	
		If ReportInfo <> Undefined Then
			ReportInfo.ReportObject = ReportObject;
		EndIf;
		If ReportObject = Undefined Then
			WriteToLog(EventLogLevel.Error, Connection.ErrorText, OptionObject.Ref);
			Return False; // An issue occurred during report attachment.
		EndIf;
	EndIf;
	
	// Extracting template texts is possible only once a report object is received.
	If SearchSettings <> Undefined And ValueIsFilled(SearchSettings.TemplatesNames) Then
		FieldsForSearch.FieldDescriptions = "#" + ExtractTemplateText(ReportObject, SearchSettings.TemplatesNames);
		If Not FillParametersAndFilters Then
			SetFieldsForSearch(OptionObject, FieldsForSearch);
			Return True; // Filling is completed, write the object.
		EndIf;
	EndIf;
	
	// The composition schema that will be a basis for report execution.
	DCSchema = ReportObject.DataCompositionSchema;
	
	// If a report is not on DCS, presentations are not filled or filled by applied features.
	If DCSchema = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Report %2, option %1. Search settings required:
			|Description of fields, parameters, and filters.';"),
			OptionObject.VariantKey, OptionObject.Report);
		If IsPredefined Then
			ErrorText = ErrorText + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'For more details, see procedure ""%1"".';"),
					"ReportsOptionsOverridable.CustomizeReportsOptions");
		EndIf;
		WriteToLog(EventLogLevel.Information, ErrorText, OptionObject.Ref);
		
		Return False;
	EndIf;
	
	DCSettings = ?(ReportInfo <> Undefined, ReportInfo.DCSettings, Undefined);
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		DCSettingsOption = DCSchema.SettingVariants.Find(OptionObject.VariantKey);
		If DCSettingsOption <> Undefined Then
			DCSettings = DCSettingsOption.Settings;
		EndIf;
	EndIf;
	
	// Read settings from option data.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings")
		And TypeOf(OptionObject) = Type("CatalogObject.ReportsOptions") Then
		Try
			DCSettings = OptionObject.Settings.Get();
		Except
			MessageTemplate = NStr("en = 'Cannot read custom report option settings. 
				|They might use renamed or deleted configuration metadata objects
				|or disabled extension metadata objects. For example, if you get the ""Missing view for type"" errors.
				|%1';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate,
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteToLog(EventLogLevel.Error, MessageText, OptionObject.Ref);
			Return False; 
		EndTry;
	EndIf;
	
	// Last check.
	If TypeOf(DCSettings) <> Type("DataCompositionSettings") Then
		If TypeOf(OptionObject) = Type("CatalogObject.PredefinedReportsOptions")
			Or TypeOf(OptionObject) = Type("CatalogObject.PredefinedExtensionsReportsOptions") Then
			WriteToLog(EventLogLevel.Error, 
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot read settings of a predefined report option: %1.';"), OptionObject.MeasurementsKey),
				OptionObject.Ref);
		EndIf;
		Return False;
	EndIf;
	
	NewSettingsHash = Common.CheckSumString(Common.ValueToXMLString(DCSettings));
	If CheckHash And OptionObject.SettingsHash = NewSettingsHash Then
		Return False; // Settings did not change.
	EndIf;
	OptionObject.SettingsHash = NewSettingsHash;
	
	ReportObject.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	ReportsClientServer.LoadSettings(ReportObject.SettingsComposer, DCSettings);
	
	If FillFields Then
		// Convert all autogrouping settings into field sets.
		//   See the Syntax Assistant for "DataCompositionAutoSelectedField",
		//   "DataCompositionAutoGroupField", and "DataCompositionAutoOrderItem".
		ReportObject.SettingsComposer.ExpandAutoFields();
		FieldsForSearch.FieldDescriptions = GenerateFiledsPresentations(ReportObject.SettingsComposer);
	EndIf;
	
	If FillParametersAndFilters Then
		FieldsForSearch.FilterParameterDescriptions = GenerateParametersAndFiltersPresentations(
			ReportObject.SettingsComposer);
	EndIf;
	
	SetFieldsForSearch(OptionObject, FieldsForSearch);
	Return True;
	
EndFunction

Function FieldsForSearch(ReportVariant) 
	
	Result = New Structure;
	Result.Insert("FieldDescriptions", "");
	Result.Insert("FilterParameterDescriptions", "");
	IsUserReportOption = (TypeOf(ReportVariant) = Type("CatalogObject.ReportsOptions"));
	If Not IsUserReportOption Then
		Result.Insert("Keywords", "");
		Result.Insert("LongDesc", "");
		Result.Insert("Description", "");
	EndIf;
	
	// Subsystem check.
	If Common.IsMainLanguage() Or IsUserReportOption Then
		FillPropertyValues(Result, ReportVariant);
		Return Result;
	EndIf;
	
	RowsStoredinTablePart = True;
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		
		If ValueIsFilled(CurrentLanguageSuffix) Then
			Result.Description      = ReportVariant["Description" + CurrentLanguageSuffix];
			Result.LongDesc          = ReportVariant["LongDesc" + CurrentLanguageSuffix];
			Result.FieldDescriptions = ReportVariant["FieldDescriptions" + CurrentLanguageSuffix];
			Result.Keywords     = ReportVariant["Keywords" + CurrentLanguageSuffix];
			Result.FilterParameterDescriptions = ReportVariant["FilterParameterDescriptions" + CurrentLanguageSuffix];
			RowsStoredinTablePart = False;
		EndIf;
	
	EndIf;
	
	If RowsStoredinTablePart Then
		PresentationForLanguage = ReportVariant.Presentations.Find(CurrentLanguage().LanguageCode, "LanguageCode");
		If PresentationForLanguage = Undefined Then
			Return Result;
		EndIf;	
		
		FillPropertyValues(Result, PresentationForLanguage);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure SetFieldsForSearch(ReportVariant, FieldsForSearch)
	
	IsUserReportOption = (TypeOf(ReportVariant) = Type("CatalogObject.ReportsOptions"));
	If Common.IsMainLanguage() Or IsUserReportOption Then
		FillPropertyValues(ReportVariant, FieldsForSearch);
		Return;
	EndIf;
	
	PresentationForLanguage = ReportVariant.Presentations.Find(CurrentLanguage().LanguageCode, "LanguageCode");
	If PresentationForLanguage = Undefined Then
		PresentationForLanguage = ReportVariant.Presentations.Add();
	EndIf;
	
	FillPropertyValues(PresentationForLanguage, FieldsForSearch);
	PresentationForLanguage.LanguageCode = CurrentLanguage().LanguageCode;
	
EndProcedure

Procedure StartPresentationsFilling(Val Mode, Val ResetCache)
	SetPresentationsFillingFlag(CurrentSessionDate(), ResetCache, Mode);
EndProcedure

Procedure SetPresentationsFillingFlag(Val Value, Val ResetCache, Val Mode)
	
	ParameterName = ReportsOptionsClientServer.FullSubsystemName() + ".PresentationsFilled";
	If Mode = "ConfigurationCommonData" Then
		Parameters = StandardSubsystemsServer.ApplicationParameter(ParameterName);
	Else
		Parameters = StandardSubsystemsServer.ExtensionParameter(ParameterName);
	EndIf;
	If Parameters = Undefined Then
		Parameters = New Map;
	ElsIf ResetCache Then
		Parameters.Clear();
	EndIf;
	Parameters[CurrentLanguage().LanguageCode] = Value;
	
	If Mode = "ConfigurationCommonData" Then
		StandardSubsystemsServer.SetApplicationParameter(ParameterName, Parameters);
	Else
		StandardSubsystemsServer.SetExtensionParameter(ParameterName, Parameters);
	EndIf;
	
EndProcedure

Function PresentationsFilled(Val Mode = "") Export
	
	ParameterName = ReportsOptionsClientServer.FullSubsystemName() + ".PresentationsFilled";
	If Mode = "ConfigurationCommonData" Then
		Parameters = StandardSubsystemsServer.ApplicationParameter(ParameterName);
	ElsIf Mode = "SeparatedConfigurationData" Then
		Parameters = StandardSubsystemsServer.ExtensionParameter(ParameterName);
	Else
		SeparatedResult = PresentationsFilled("SeparatedConfigurationData");
		If Common.DataSeparationEnabled() Then
			Return SeparatedResult;
		EndIf;
		CommonResult1 = PresentationsFilled("ConfigurationCommonData");
		If CommonResult1 = "NotFilled1" Or SeparatedResult = "NotFilled1" Then
			Return "NotFilled1";
		ElsIf CommonResult1 = "ToFill" Or SeparatedResult = "ToFill" Then
			Return "ToFill";
		EndIf;
		Return "Filled1";
	EndIf;
	If Parameters = Undefined Then
		Parameters = New Map;
	EndIf;
	
	Result = Parameters[CurrentLanguage().LanguageCode];
	If TypeOf(Result) = Type("Date") Then
		Return ?(CurrentSessionDate() - Result < 15 * 60, "ToFill", "NotFilled1"); // Timeout is 15 minutes.
	EndIf;
	Return ?(Result = True, "Filled1", "NotFilled1");
	
EndFunction	

// Presentations of groups and fields from DCS.
//
// Parameters:
//    DCSettingsComposer - DataCompositionSettingsComposer
//
Function GenerateFiledsPresentations(DCSettingsComposer)

	Result = StrSplit(String(DCSettingsComposer.Settings.Selection), ",", False);

	Collections = New Array;
	Collections.Add(DCSettingsComposer.Settings.Structure);
	IndexOf = 0;
	While IndexOf < Collections.Count() Do
		Collection = Collections[IndexOf];
		IndexOf = IndexOf + 1;
		
		For Each Setting In Collection Do
			
			If TypeOf(Setting) = Type("DataCompositionNestedObjectSettings") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Setting = Setting.Settings;
			EndIf;
			
			CommonClientServer.SupplementArray(Result, StrSplit(String(Setting.Selection), ",", False));
			
			If TypeOf(Setting) = Type("DataCompositionSettings") Then
				Collections.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Collections.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionTable") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Collections.Add(Setting.Rows);
			ElsIf TypeOf(Setting) = Type("DataCompositionTableGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Collections.Add(Setting.Structure);
			ElsIf TypeOf(Setting) = Type("DataCompositionChart") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Collections.Add(Setting.Series);
				Collections.Add(Setting.Points);
			ElsIf TypeOf(Setting) = Type("DataCompositionChartGroup") Then
				If Not Setting.Use Then
					Continue;
				EndIf;
				Collections.Add(Setting.Structure);
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Result = CommonClientServer.CollapseArray(Result);
	
	Return StrConcat(Result, Chars.LF);
EndFunction

// Presentations of parameters and filters from DCS.
//
// Parameters:
//   SettingsComposer - DataCompositionSettingsComposer - See Syntax Assistant
//
Function GenerateParametersAndFiltersPresentations(SettingsComposer)
	Result = New Array;
	
	Settings = SettingsComposer.Settings;
	UserSettings = SettingsComposer.UserSettings;
	
	Modes = DataCompositionSettingsItemViewMode;
	
	For Each UserSetting In UserSettings.Items Do
		SettingType = TypeOf(UserSetting);
		If SettingType = Type("DataCompositionSettingsParameterValue") Then
			IsFilter = False;
		ElsIf SettingType = Type("DataCompositionFilterItem") Then
			IsFilter = True;
		Else
			Continue;
		EndIf;
		
		If UserSetting.ViewMode = Modes.Inaccessible Then
			Continue;
		EndIf;
		
		Id = UserSetting.UserSettingID;
		
		CommonSetting = ReportsClientServer.GetObjectByUserID(
			Settings, Id,, UserSettings);
		
		If CommonSetting = Undefined Then
			Continue;
		EndIf;
		
		If UserSetting.ViewMode = Modes.Auto
			And CommonSetting.ViewMode <> Modes.QuickAccess Then
			Continue;
		EndIf;
		
		PresentationsStructure = New Structure("Presentation, UserSettingPresentation", "", "");
		FillPropertyValues(PresentationsStructure, CommonSetting);
		If ValueIsFilled(PresentationsStructure.UserSettingPresentation) Then
			ItemHeader = PresentationsStructure.UserSettingPresentation;
		ElsIf ValueIsFilled(PresentationsStructure.Presentation) Then
			ItemHeader = PresentationsStructure.Presentation;
		Else
			AvailableSetting = ReportsClientServer.FindAvailableSetting(Settings, CommonSetting);
			If AvailableSetting <> Undefined And ValueIsFilled(AvailableSetting.Title) Then
				ItemHeader = AvailableSetting.Title;
			Else
				ItemHeader = String(?(IsFilter, CommonSetting.LeftValue, CommonSetting.Parameter));
			EndIf;
		EndIf;
		
		ItemHeader = TrimAll(ItemHeader);
		If ItemHeader <> "" Then
			Result.Add(ItemHeader);
		EndIf;
		
	EndDo;
	
	Result = CommonClientServer.CollapseArray(Result);
	
	Return StrConcat(Result, Chars.LF);
EndFunction

// Extracts text information from a template.
Function ExtractTemplateText(ReportObject, TemplatesNames)
	If TypeOf(TemplatesNames) = Type("String") Then
		TemplatesNames = StrSplit(TemplatesNames, ",", False);
	EndIf;
	AreasTexts = New Array;
	For Each TemplateName In TemplatesNames Do
		Template = ReportObject.GetTemplate(TrimAll(TemplateName));
		If TypeOf(Template) = Type("SpreadsheetDocument") Then
			Bottom = Template.TableHeight;
			Right = Template.TableWidth;
			CheckedCells = New Map;
			For ColumnNumber = 1 To Right Do
				For LineNumber = 1 To Bottom Do
					Cell = Template.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
					If CheckedCells[Cell.Name] <> Undefined Then
						Continue;
					EndIf;
					CheckedCells[Cell.Name] = True;
					If TypeOf(Cell) <> Type("SpreadsheetDocumentRange") Then
						Continue;
					EndIf;
					AreaText = TrimAll(Cell.Text);
					If IsBlankString(AreaText) Then
						Continue;
					EndIf;
					
					AreasTexts.Add(AreaText);
					
				EndDo;
			EndDo;
		ElsIf TypeOf(Template) = Type("TextDocument") Then
			AreasTexts.Add(TrimAll(Template.GetText()));
		EndIf;
	EndDo;
	Return StrConcat(AreasTexts, Chars.LF);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Reduce the number of user settings.

// Parameters:
//  ReportRef - CatalogRef.ReportsOptions
//  VariantKey - String
//  ReportObject - ReportObject
//
// Returns:
//   Structure - ReportSettings in the report form and report settings form (stored in form data)::
//       * OptionRef - Undefined
//                       - CatalogRef.ReportsOptions
//       * PredefinedRef - Undefined
//                                - CatalogRef.PredefinedReportsOptions
//                                - CatalogRef.PredefinedExtensionsReportsOptions
//       * PredefinedOptionKey - Undefined
//                                       - String
//       * Custom - Boolean
//       * ReportType - CatalogRef.PredefinedReportsOptions,
//                   - CatalogRef.PredefinedExtensionsReportsOptions
//                   - Undefined
//       * OptionSelectionAllowed - Boolean
//       * SchemaModified - Boolean
//       * PredefinedOptions - ValueList:
//           ** Value      - String - Report option name.
//           ** Presentation - String - Option presentation.
//       * SchemaURL - String - Address of the ReportObject's temp storage obtained as FormAttributeToValue("Report").
//                               
//       * SchemaKey - String
//       * Contextual - Boolean - True if OptionContext is assigned a value.
//       * FullName - String - Full name of the report metadata object.
//       * Description - String - Report metadata object presentation.
//       * ReportRef - CatalogRef.MetadataObjectIDs
//                     - CatalogRef.ExtensionObjectIDs
//                     - String - Full name of the external report.
//       * External - Boolean - If ReportRef type is String.
//       * Subsystem - CatalogRef.MetadataObjectIDs
//                    - CatalogRef.ExtensionObjectIDs - "Subsystem" parameter of the report form.
//       * Safe - Boolean - If SafeMode() <> False when creating the form.
//       * TablesToUse - Array of String - Full names of metadata object tables.
//                             - Undefined
//       * ResultProperties  - See ReportsOptionsInternal.PropertiesOfTheReportResult
//       * UsedFieldsOfTheUniversalSearchByType - Map
//       * EventsSettings - Map of KeyAndValue:
//          ** Key - String - Event (action) name.
//          ** Value - String - Event (action) presentation.
//       * NewXMLSettings - Undefined - No settings.
//                           - String
//       * NewUserXMLSettings - Undefined - No settings.
//                                           - String
//       * SettingsFormAdvancedMode - Number - 0 for common, 1 for extended.
//       * SettingsFormPageName - String
//       * MeasurementsKey - Undefined
//                     - String
//       
//       The further properties are taken from ReportsOptions.ClientParameters.
//       * RunMeasurements - Boolean
//       
//       The further properties are taken from ReportsClientServer.DefaultReportSettings.
//       * GenerateImmediately - Boolean
//       * OutputSelectedCellsTotal - Boolean
//       * EditStructureAllowed - Boolean
//       * EditOptionsAllowed - Boolean
//       * SelectAndEditOptionsWithoutSavingAllowed - Boolean
//       * ControlItemsPlacementParameters - Structure
//                                                  - Undefined
//       * ImportSettingsOnChangeParameters - Array
//       * SearchFields - Array of String
//       * PeriodRepresentationOption - EnumRef.PeriodPresentationOptions
//       * PeriodVariant - EnumRef.PeriodOptions
//       * HideBulkEmailCommands - Boolean
//       * Print - Structure:
//           ** TopMargin - Number
//           ** LeftMargin  - Number
//           ** BottomMargin  - Number
//           ** RightMargin - Number
//           ** PageOrientation - PageOrientation
//           ** FitToPage - Boolean
//           ** PrintScale - Number
//       * Events - Structure:
//           ** OnCreateAtServer - Boolean
//           ** BeforeImportSettingsToComposer - Boolean
//           ** AfterLoadSettingsInLinker - Boolean
//           ** BeforeLoadVariantAtServer - Boolean
//           ** OnLoadVariantAtServer - Boolean
//           ** OnLoadUserSettingsAtServer - Boolean
//           ** BeforeFillQuickSettingsBar - Boolean
//           ** AfterQuickSettingsBarFilled - Boolean
//           ** OnDefineSelectionParameters - Boolean
//           ** OnDefineUsedTables - Boolean
//           ** WhenDefiningTheMainFields - Boolean
//           ** BeforeFormationReport - Boolean
//
Function ReportFormSettings(ReportRef, VariantKey, ReportObject) Export
	
	ReportMetadata = ReportObject.Metadata();
	
	PredefinedOptions = New ValueList;
	If ReportObject.DataCompositionSchema <> Undefined Then
		For Each Variant In ReportObject.DataCompositionSchema.SettingVariants Do
			PredefinedOptions.Add(Variant.Name, Variant.Presentation);
		EndDo;
	EndIf;
	
	Settings = ReportSettings(ReportRef, VariantKey, ReportObject);
	
	Settings.Insert("OptionRef", Undefined);
	Settings.Insert("PredefinedRef", Undefined);
	Settings.Insert("PredefinedOptionKey", Undefined);
	Settings.Insert("Custom", False);
	Settings.Insert("ReportType", Undefined);
	Settings.Insert("OptionSelectionAllowed", True);
	Settings.Insert("SchemaModified", False);
	Settings.Insert("PredefinedOptions", PredefinedOptions);
	Settings.Insert("SchemaURL", "");
	Settings.Insert("SchemaKey", "");
	Settings.Insert("Contextual", False);
	Settings.Insert("FullName", ReportMetadata.FullName());
	Settings.Insert("Description", TrimAll(ReportMetadata.Presentation()));
	Settings.Insert("ReportRef", ReportRef);
	Settings.Insert("Subsystem", Undefined);
	Settings.Insert("External", TypeOf(Settings.ReportRef) = Type("String"));
	Settings.Insert("Safe", SafeMode() <> False);
	Settings.Insert("TablesToUse", Undefined);
	Settings.Insert("ResultProperties", ReportsOptionsInternal.PropertiesOfTheReportResult());
	Settings.Insert("UsedFieldsOfTheUniversalSearchByType", New Map);
	Settings.Insert("EventsSettings", New Map);
	Settings.Insert("ReadCreateFromUserSettingsImmediatelyCheckBox", True);
	Settings.Insert("NewXMLSettings", Undefined);
	Settings.Insert("NewUserXMLSettings", Undefined);
	Settings.Insert("SettingsFormAdvancedMode", 0);
	Settings.Insert("SettingsFormPageName", "FiltersPage");
	Settings.Insert("MeasurementsKey", Undefined);
	Settings.Insert("Purpose", Enums.ReportOptionPurposes.ForAnyDevice);
	Settings.Insert("UseReportSnapshots", False);
	
	CommonClientServer.SupplementStructure(Settings, ClientParameters());
	
	Return Settings;
	
EndFunction

// Parameters:
//  FormParameters - Structure
//
// Returns:
//  Structure:
//   * GenerateOnOpen - Boolean
//   * Filter - Structure - Filter to pass to the form.
//   * PurposeUseKey - String
//   * UserSettingsKey - String
//   * ReadOnly - Boolean
//   * FixedSettings - Undefined
//                            - DataCompositionSettings
//   * Section - String
//   * Subsystem - CatalogRef.MetadataObjectIDs
//                - CatalogRef.ExtensionObjectIDs
//   * SubsystemPresentation - String
//   * InitialKeyOfPredefinedOption - String
//   * InitialOptionKey - String
//
Function StoredReportFormParameters(FormParameters) Export
	
	Parameters = New Structure;
	Parameters.Insert("GenerateOnOpen", False);
	Parameters.Insert("Filter", New Structure);
	Parameters.Insert("PurposeUseKey", "");
	Parameters.Insert("UserSettingsKey", "");
	Parameters.Insert("ReadOnly", False);
	Parameters.Insert("FixedSettings", Undefined);
	Parameters.Insert("Section", Undefined);
	Parameters.Insert("Subsystem", Undefined);
	Parameters.Insert("SubsystemPresentation", "");
	Parameters.Insert("InitialKeyOfPredefinedOption", "");
	Parameters.Insert("InitialOptionKey", "");
	
	FillPropertyValues(Parameters, FormParameters,, "Filter");
	If TypeOf(FormParameters.Filter) = Type("Structure") Then
		CommonClientServer.SupplementStructure(Parameters.Filter, FormParameters.Filter, True);
		FormParameters.Filter.Clear();
	EndIf;
	
	Return Parameters;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm:
//   * CurrentVariantKey - String
//   * ParametersForm  - See StoredReportFormParameters
//   * ReportSettings - See ReportFormSettings
//
// Returns:
//  Boolean
//
Function ItIsAcceptableToSetContext(Form) Export
	
	Return (Form.ParametersForm.InitialKeyOfPredefinedOption = Form.ReportSettings.PredefinedOptionKey)
		Or (Form.ParametersForm.InitialOptionKey = Form.CurrentVariantKey);
	
EndFunction


// Parameters:
//  ReportRef - CatalogRef.ReportsOptions
//  VariantKey - String
//  ReportObject - ReportObject
//
// Returns:
//   See ReportsClientServer.DefaultReportSettings
//
Function ReportSettings(ReportRef, VariantKey, ReportObject)
	ReportSettings = ReportsClientServer.DefaultReportSettings();
	
	ReportsWithSettings = ReportsOptionsCached.Parameters().ReportsWithSettings;
	If ReportsWithSettings.Find(ReportRef) = Undefined 
		And (ReportObject = Undefined Or Metadata.Reports.Contains(ReportObject.Metadata()))Then
		Return ReportSettings;
	EndIf;
	
	If ReportObject = Undefined Then
		Connection = AttachReportObject(ReportRef, False);
		If Connection.Success Then
			ReportObject = Connection.Object;
		Else
			Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Failed to get settings for report %1:';") + Chars.LF + Connection.ErrorText,
				ReportRef);
			WriteToLog(EventLogLevel.Information, Text, ReportRef);
			Return ReportSettings;
		EndIf;
	EndIf;
	
	Try
		ReportObject.DefineFormSettings(Undefined, VariantKey, ReportSettings);
	Except
		If IsExternalReport(ReportObject) Then
			ReportSettings = ReportsClientServer.DefaultReportSettings();
		Else
			MetadataOfReport = ReportObject.Metadata();
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""%1"" (%2) report is attached to
				           |the ""Report options"" subsystem. However, an error occurred when receiving the settings.
				           |The report developer might not have specified the %3 procedure or the report option cache might be outdated:
				           |
				           |%4';"),
				MetadataOfReport.Presentation(),
				MetadataOfReport.FullName(),
				"DefineFormSettings",
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise ErrorText;
		EndIf;
	EndTry;
	
	If Not GlobalSettings().EditOptionsAllowed Then
		ReportSettings.EditOptionsAllowed = False;
	EndIf;
	
	Return ReportSettings;
EndFunction

Function IsExternalReport(ReportObject)
	If ReportObject = Undefined Then
		Return False;
	EndIf;
	
	ReportName = ReportObject.Metadata().Name;
	If Metadata.Reports.Find(ReportName) <> Undefined
		And TypeOf(ReportObject) = Type("ReportObject." + ReportName) Then
		Return False;
	EndIf;
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Search.

// Parameters:
//  SearchParameters - Structure
//
// Returns:
//   See FindReportsOptions
//
Function ReportOptionTable(Val SearchParameters) Export
	
	Return FindReportsOptions(SearchParameters, True).ValueTable;
	
EndFunction

// Returns the list of report options according to specified parameters.
// When searching by the SearchString substring, it also highlights found places in report names and details.
//
// Parameters:
//   SearchParameters - Structure:
//     * SearchString  - String - Optional. One or several words from the titles or details of the required reports. 
//                                
//     * Subsystems    - Array of CatalogRef.MetadataObjectIDs - Optional.
//                       Search only within the report options that belong to the given subsystems.
//     * ExactFilterBySubsystems - Boolean - Optional. If True, show results from the specified subsystems only.
//                       Otherwise, show relevant search results from all the subsystems.
//     * Reports        - Array of CatalogRef.ReportsOptions - Optional. Search only within the given reports.
//     * ReportsTypes   - Array of EnumRef.ReportsTypes - Optional. Search only in the given reports. 
//                       
//     * DeletionMark - Boolean - Optional. If False, returns all report options. 
//                       If True or not specified, returns only the reports not marked for deletion.
//     * OnlyPersonal  - Boolean - Optional. If False or not specified, the administrators receives all the report options,
//                       while common users receive only the report options they have access to.
//                       If True, both common users and the administrators receive only personal report options.
//                       
//   GetSummaryTable - Boolean - If True, populate the ValueTable property in the return value.
//   GetHighlight - Boolean - If True, populate the following properties in the return value:
//                       OptionsHighlight, Subsystems, SubsystemsHighlight, OptionsLinkedWithSubsystems, ParentsLinkedWithOptions. 
//
// Returns: 
//   Structure:
//       * References - Array of CatalogRef.ReportsOptions - Report options whose names and details contain
//                  all the search words.
//       * OptionsHighlight - Map of KeyAndValue - Highlight the found words (if SearchString is specified), where::
//           ** Key - CatalogRef.ReportsOptions
//           ** Value - Structure:
//               *** Ref - CatalogRef.ReportsOptions
//               *** FieldDescriptions                    - String
//               *** FilterParameterDescriptions       - String
//               *** Keywords                        - String
//               *** LongDesc                             - String
//               *** UserSettingsDescriptions - String
//               *** WhereFound                           - Structure:
//                   **** FieldDescriptions                    - Number
//                   **** FilterParameterDescriptions       - Number
//                   **** Keywords                        - Number
//                   **** LongDesc                             - Number
//                   **** UserSettingsDescriptions - Number
//       * Subsystems - Array of CatalogRef.MetadataObjectIDs - Filled in with subsystems
//                      whose names contain all the search words.
//                      All nested report options must be displayed for such subsystems.
//       * SubsystemsHighlight - Map of KeyAndValue - Highlight the found words (if SearchString is specified), where::
//           ** Key - CatalogRef.ReportsOptions
//           ** Value - Structure:
//               *** Ref - CatalogRef.MetadataObjectIDs
//               *** SubsystemDescription - String
//       * OptionsLinkedWithSubsystems - Map of KeyAndValue - Report options and their subsystems, where::
//           ** Key - CatalogRef.ReportsOptions - Option.
//           ** Value - Array of CatalogRef.MetadataObjectIDs - Subsystems.
//       * ValueTable - See SourceTableOfReportVariants
//
Function FindReportsOptions(Val SearchParameters, Val GetSummaryTable = False, Val GetHighlight = False) Export
	
	If PresentationsFilled() = "NotFilled1" Then
		Settings = SettingsUpdateParameters();
		Settings.Deferred2 = True;
		Refresh(Settings);
	EndIf;
	
	If SearchParameters.Property("Subsystems") Then
		SearchOnlyOptionsWithoutSubsystems = ?(SearchParameters.Subsystems.Find(Catalogs.MetadataObjectIDs.EmptyRef())= Undefined, False, True);
		If SearchOnlyOptionsWithoutSubsystems And SearchParameters.Subsystems.Count() = 1 Then
			SearchParameters.Subsystems = New Array;
		EndIf;
	Else
		SearchOnlyOptionsWithoutSubsystems = False;
	EndIf;
	
	HasSearchString = SearchParameters.Property("SearchString") And ValueIsFilled(SearchParameters.SearchString);
	HasFilterByReports = SearchParameters.Property("Reports") And ValueIsFilled(SearchParameters.Reports);
	HasFilterBySubsystems = SearchParameters.Property("Subsystems") And ValueIsFilled(SearchParameters.Subsystems);
	HasFilterByContext = SearchParameters.Property("Context");
	
	HasFilterByReportTypes = SearchParameters.Property("ReportsTypes") And ValueIsFilled(SearchParameters.ReportsTypes);
	
	Result = New Structure;
	Result.Insert("References", New Array);
	Result.Insert("OptionsHighlight", New Map);
	Result.Insert("Subsystems", New Array);
	Result.Insert("SubsystemsHighlight", New Map);
	Result.Insert("OptionsLinkedWithSubsystems", New Map);
	Result.Insert("ParentsLinkedWithOptions", New Array);
	
	If GetSummaryTable Then
		Result.Insert("ValueTable", New ValueTable);
	EndIf;
	
	If Not HasFilterBySubsystems And Not HasSearchString And Not HasFilterByReportTypes And Not HasFilterByReports And Not SearchOnlyOptionsWithoutSubsystems Then
		Return Result;
	EndIf;
	
	HasFilterByVisibility = HasFilterBySubsystems
		And SearchParameters.Property("OnlyItemsVisibleInReportPanel") 
		And SearchParameters.OnlyItemsVisibleInReportPanel = True;
		
	OnlyItemsNotMarkedForDeletion = ?(SearchParameters.Property("DeletionMark"), SearchParameters.DeletionMark, True);
	
	If HasFilterByReports Then
		FilterByReports = SearchParameters.Reports;
		SearchParameters.Insert("DIsabledApplicationOptions", DisabledReportOptions(FilterByReports));
	Else
		SearchParameters.Insert("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
		SearchParameters.Insert("UserReports", CurrentUserReports());
		FilterByReports = SearchParameters.UserReports;
	EndIf;
	
	HasRightToReadAuthors = AccessRight("Read", Metadata.Catalogs.Users);
	CurrentUser = Users.AuthorizedUser();
	ShowPersonalReportsOptionsByOtherAuthors = FullRightsToOptions();
	
	If SearchParameters.Property("OnlyPersonal") Then
		ShowPersonalReportsOptionsByOtherAuthors = ShowPersonalReportsOptionsByOtherAuthors And Not SearchParameters.OnlyPersonal;
	EndIf;
	
	OnlyPersonal = ?(SearchParameters.Property("OnlyPersonal"), SearchParameters.OnlyPersonal, False);
	
	Query = New Query;
	Query.SetParameter("CurrentUser",          CurrentUser);
	Query.SetParameter("UserReports",           FilterByReports);
	Query.SetParameter("DIsabledApplicationOptions", SearchParameters.DIsabledApplicationOptions);
	Query.SetParameter("ExtensionsVersion",             SessionParameters.ExtensionsVersion);
	Query.SetParameter("NoFilterByDeletionMark",   Not OnlyItemsNotMarkedForDeletion);
	Query.SetParameter("HasRightToReadAuthors",       HasRightToReadAuthors);
	Query.SetParameter("HasFilterByReportTypes",      HasFilterByReportTypes);
	Query.SetParameter("HasFilterBySubsystems",       HasFilterBySubsystems);
	Query.SetParameter("HasFilterByContext",         HasFilterByContext);
	Query.SetParameter("ReportsTypes",                  ?(HasFilterByReportTypes, SearchParameters.ReportsTypes, New Array));
	Query.SetParameter("DontGetDetails",           Not HasSearchString And Not GetSummaryTable);
	Query.SetParameter("GetSummaryTable",      GetSummaryTable);
	Query.SetParameter("ShowPersonalReportsOptionsByOtherAuthors", ShowPersonalReportsOptionsByOtherAuthors);
	Query.SetParameter("IsMainLanguage",              Common.IsMainLanguage());
	Query.SetParameter("LanguageCode",                     CurrentLanguage().LanguageCode);
	Query.SetParameter("SubsystemsPresentations",       ReportsOptionsCached.SubsystemsPresentations());
	Query.SetParameter("Context",                     ?(HasFilterByContext, SearchParameters.Context, ""));
	Query.SetParameter("OnlyPersonal",                 OnlyPersonal);

	If HasFilterBySubsystems Or HasSearchString Or SearchOnlyOptionsWithoutSubsystems Then
		
		If HasFilterBySubsystems Then
			If TypeOf(SearchParameters.Subsystems) = Type("Array") Then
				ReportsSubsystems = SearchParameters.Subsystems;
			Else
				ReportsSubsystems = New Array;
				ReportsSubsystems.Add(SearchParameters.Subsystems);
			EndIf;
		Else
			ReportsSubsystems = New Array;
		EndIf;
		
		ReportsSubsystems.Add(Catalogs.MetadataObjectIDs.EmptyRef());
		
		Query.SetParameter("HasSearchString", HasSearchString);
		Query.SetParameter("GetSummaryTable", GetSummaryTable);
		Query.SetParameter("HasFilterByVisibility", HasFilterByVisibility);
		Query.SetParameter("ReportsSubsystems", ReportsSubsystems);
		Query.SetParameter("SearchOptionsWithoutSubsystems", (HasSearchString And Not HasFilterBySubsystems) Or SearchOnlyOptionsWithoutSubsystems);
		Query.SetParameter("SearchOnlyOptionsWithoutSubsystems", SearchOnlyOptionsWithoutSubsystems);
		
		QueryText = ReportsWithSpecifiedFiltersQueryText();
		
		SearchWords = PrepareSearchConditionByRow(Query, QueryText, HasSearchString, SearchParameters, 
			HasRightToReadAuthors);
	Else
		QueryText = ReportsWithSimpleFiltersQueryText();
		If SearchParameters.Property("OptionKeyWithoutConditions")
		   And ValueIsFilled(SearchParameters.OptionKeyWithoutConditions) Then
			
			Query.SetParameter("OptionKeyWithoutConditions", SearchParameters.OptionKeyWithoutConditions);
			QueryText = StrReplace(QueryText, "&FilterOptionKeyWithoutConditions",
				"ReportsOptions.VariantKey = &OptionKeyWithoutConditions");
		Else
			QueryText = StrReplace(QueryText, "&FilterOptionKeyWithoutConditions", "FALSE");
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
		ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
	
		CurrentLanguageSuffix = ModuleNationalLanguageSupportServer.CurrentLanguageSuffix();
		If ValueIsFilled(CurrentLanguageSuffix) Then
			
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ReportsOptions.Description");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ReportsOptions.LongDesc");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ConfigurationOptions.Description");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ConfigurationOptions.LongDesc");
			
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ExtensionOptions.Description");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ExtensionOptions.LongDesc");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ExtensionOptions.FieldDescriptions");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ExtensionOptions.FilterParameterDescriptions");
			ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(QueryText, "ExtensionOptions.Keywords");

			
		EndIf;
	EndIf;

	SetPrivilegedMode(True);
	
	Query.Text = QueryText;
	SourceTable = SourceTableOfReportVariants(Query);
	
	If GetSummaryTable Then
		Result.ValueTable = SourceTable;
	EndIf;
	
	If SourceTable.Count() = 0 Then
		Return Result;
	EndIf;
	
	If HasSearchString And GetHighlight Then
		GenerateSearchResults(SearchWords, SourceTable, Result);
	Else
		GenerateRefsList(SourceTable, Result.References);
	EndIf;
	
	Return Result;
	
EndFunction

Function PrepareSearchConditionByRow(Val Query, QueryText, Val HasSearchString, Val SearchParameters, Val AuthorsReadRight)
	
	If HasSearchString Then
		SearchString = Upper(TrimAll(SearchParameters.SearchString));
		SearchWords = ReportsOptionsClientServer.ParseSearchStringIntoWordArray(SearchString);
		SearchTemplates = New Array;
		For WordNumber = 1 To SearchWords.Count() Do
			Word = SearchWords[WordNumber - 1];
			WordName =  "Word" + Format(WordNumber, "NG=");
			Query.SetParameter(WordName, "%" + Common.GenerateSearchQueryString(Word) + "%");
			SearchTemplate = StrReplace("&NameOfTheSearchField LIKE &ParameterName ESCAPE ""~""", "ParameterName", WordName); // @query-part-1
			SearchTemplates.Add(SearchTemplate);
		EndDo;
		SearchTemplate = StrConcat(SearchTemplates, " OR "); // Do not localize. This is a query fragment.
		
		SearchFields = New Array;
		SearchFields.Add("ReportsOptions.CurrentOptionName"); 
		SearchFields.Add("Location.SubsystemDescription"); 
		SearchFields.Add("ReportsOptions.FieldDescriptions"); 
		SearchFields.Add("ReportsOptions.FilterParameterDescriptions"); 
		SearchFields.Add("ReportsOptions.CurrentDescriptionOption"); 
		SearchFields.Add("ReportsOptions.Keywords"); 
		If AuthorsReadRight Then
			SearchFields.Add("ReportsOptions.Author.Description"); 
		EndIf;
		
		For IndexOf = 0 To SearchFields.Count() - 1 Do
			SearchFields[IndexOf] = StrReplace(SearchTemplate, "&NameOfTheSearchField", SearchFields[IndexOf]);
		EndDo;
		OptionsAndSubsystemsBySearchString = "(" + StrConcat(SearchFields, " OR ") + ")"; // Do not localize. This is a query fragment.
		QueryText = StrReplace(QueryText, "&OptionsAndSubsystemsBySearchString", OptionsAndSubsystemsBySearchString);
		
		UserSettingsBySearchString = "(" + StrReplace(SearchTemplate, "&NameOfTheSearchField", "UserSettings2.Description") + ")";
		QueryText = StrReplace(QueryText, "&UserSettingsBySearchString", UserSettingsBySearchString);
		
	Else
		// Delete the filter used to search in data of report options subsystems.
		QueryText = StrReplace(QueryText, "AND &OptionsAndSubsystemsBySearchString", "");
		// Delete the table used to search in user settings.
		StartOfSelectionFromTable = (
		"UNION ALL
		|
		|SELECT DISTINCT
		|	UserSettings2.Variant");
		
		QueryText = TrimR(Left(QueryText, StrFind(QueryText, StartOfSelectionFromTable) - 1));
	EndIf;
	
	Return SearchWords;
	
EndFunction

Function ReportsWithSpecifiedFiltersQueryText()
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	
	If CurrentLanguageSuffix  <> Undefined Then
	
	TheTextOfTheRequest = "SELECT ALLOWED
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Parent AS Parent,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN ReportsOptions.Author
		|		ELSE UNDEFINED
		|	END AS Author,
		|	ReportsOptions.AuthorOnly AS AuthorOnly,
		|	ReportsOptions.Report AS Report,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedOption AS PredefinedOption,
		|	ReportsOptions.Purpose AS Purpose,
		|	CASE
		|		WHEN ReportsOptions.Custom
		|			THEN ReportsOptions.InteractiveDeletionMark
		|		WHEN ReportsOptions.ReportType = VALUE(Enum.ReportsTypes.Extension)
		|			THEN AvailableExtensionOptions.Variant IS NULL
		|		ELSE ISNULL(ConfigurationOptions.DeletionMark, ReportsOptions.DeletionMark)
		|	END AS DeletionMark,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN (ReportsOptions.Custom
		|				OR ReportsOptions.PredefinedOption IN (
		|						UNDEFINED,
		|						VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|						VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|			THEN ReportsOptions.Description
		|		ELSE ReportsOptions.Description
		|		END AS CurrentOptionName,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN SUBSTRING(ReportsOptions.FieldDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FieldDescriptions, ExtensionOptions.FieldDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FieldDescriptions AS STRING(1000))
		|	END AS FieldDescriptions,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN SUBSTRING(ReportsOptions.FilterParameterDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FilterParameterDescriptions, ExtensionOptions.FilterParameterDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000))
		|	END AS FilterParameterDescriptions,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN SUBSTRING(ReportsOptions.Keywords, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.Keywords, ExtensionOptions.Keywords) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.Keywords AS STRING(1000))
		|	END AS Keywords,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ExtensionOptions.LongDesc) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
		|	END AS CurrentDescriptionOption
		|INTO ReportsOptions
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
		|			ON ReportsOptions.PredefinedOption = AvailableExtensionOptions.Variant
		|			AND AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion
		|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|			ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|			ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
		|WHERE
		|	(NOT &HasFilterByReportTypes
		|		OR ReportsOptions.ReportType IN (&ReportsTypes))
		|	AND ReportsOptions.Report IN (&UserReports)
		|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|	AND (&ShowPersonalReportsOptionsByOtherAuthors
		|		OR ReportsOptions.AuthorOnly = FALSE
		|		OR ReportsOptions.Author = &CurrentUser)
		|	AND ReportsOptions.Context = &Context
		|
		|INDEX BY
		|	Ref
		|";
	
	Else
	
		TheTextOfTheRequest = "SELECT ALLOWED
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Parent AS Parent,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN ReportsOptions.Author
		|		ELSE UNDEFINED
		|	END AS Author,
		|	ReportsOptions.AuthorOnly AS AuthorOnly,
		|	ReportsOptions.Report AS Report,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedOption AS PredefinedOption,
		|	ReportsOptions.Purpose AS Purpose,
		|	CASE
		|		WHEN ReportsOptions.Custom
		|			THEN ReportsOptions.InteractiveDeletionMark
		|		WHEN ReportsOptions.ReportType = VALUE(Enum.ReportsTypes.Extension)
		|			THEN AvailableExtensionOptions.Variant IS NULL
		|		ELSE ISNULL(ConfigurationOptions.DeletionMark, ReportsOptions.DeletionMark)
		|	END AS DeletionMark,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN &IsMainLanguage
		|			AND (ReportsOptions.Custom
		|				OR ReportsOptions.PredefinedOption IN (
		|						UNDEFINED,
		|						VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|						VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|			THEN ReportsOptions.Description
		|		WHEN NOT &IsMainLanguage
		|			AND (ReportsOptions.Custom
		|				OR ReportsOptions.PredefinedOption IN (
		|						UNDEFINED,
		|						VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|						VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|			THEN CAST(ISNULL(OptionsPresentations.Description, ReportsOptions.Description) AS STRING(150))
		|		WHEN &IsMainLanguage
		|			THEN CAST(ISNULL(ISNULL(ConfigurationOptions.Description, ExtensionOptions.Description), ReportsOptions.Description) AS STRING(150))
		|		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.Description, PresentationsFromExtensions.Description), OptionsPresentations.Description) AS STRING(150))
		|	END AS CurrentOptionName,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.FieldDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FieldDescriptions, ExtensionOptions.FieldDescriptions) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.FieldDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(PresentationsFromConfiguration.FieldDescriptions, PresentationsFromExtensions.FieldDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FieldDescriptions AS STRING(1000))
		|	END AS FieldDescriptions,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.FilterParameterDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.FilterParameterDescriptions, ExtensionOptions.FilterParameterDescriptions) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.FilterParameterDescriptions, 1, 1) = """"
		|			THEN CAST(ISNULL(PresentationsFromConfiguration.FilterParameterDescriptions, PresentationsFromExtensions.FilterParameterDescriptions) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000))
		|	END AS FilterParameterDescriptions,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.Keywords, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.Keywords, ExtensionOptions.Keywords) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage
		|				AND SUBSTRING(ReportsOptions.Keywords, 1, 1) = """"
		|			THEN CAST(ISNULL(PresentationsFromConfiguration.Keywords, PresentationsFromExtensions.Keywords) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.Keywords AS STRING(1000))
		|	END AS Keywords,
		|	CASE
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ExtensionOptions.LongDesc) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage AND SUBSTRING(OptionsPresentations.LongDesc, 1, 1) <> """"
		|			THEN CAST(OptionsPresentations.LongDesc AS STRING(1000))
		|		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.LongDesc, PresentationsFromExtensions.LongDesc), ReportsOptions.LongDesc) AS STRING(1000))
		|	END AS CurrentDescriptionOption
		|INTO ReportsOptions
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
		|			ON ReportsOptions.PredefinedOption = AvailableExtensionOptions.Variant
		|			AND AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion
		|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|			ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|			ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
		|		LEFT JOIN Catalog.ReportsOptions.Presentations AS OptionsPresentations
		|			ON ReportsOptions.Ref = OptionsPresentations.Ref
		|			AND OptionsPresentations.LanguageCode = &LanguageCode
		|		LEFT JOIN Catalog.PredefinedReportsOptions.Presentations AS PresentationsFromConfiguration
		|			ON ReportsOptions.PredefinedOption = PresentationsFromConfiguration.Ref
		|			AND PresentationsFromConfiguration.LanguageCode = &LanguageCode
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Presentations AS PresentationsFromExtensions
		|			ON ReportsOptions.PredefinedOption = PresentationsFromExtensions.Ref
		|			AND PresentationsFromExtensions.LanguageCode = &LanguageCode
		|WHERE
		|	(NOT &HasFilterByReportTypes
		|		OR ReportsOptions.ReportType IN (&ReportsTypes))
		|	AND ReportsOptions.Report IN (&UserReports)
		|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|	AND (&ShowPersonalReportsOptionsByOtherAuthors
		|		OR ReportsOptions.AuthorOnly = FALSE
		|		OR ReportsOptions.Author = &CurrentUser)
		|	AND ReportsOptions.Context = &Context
		|
		|INDEX BY
		|	Ref
		|";
		
	EndIf;
	
	QueryTextShared = "SELECT
	|	SubsystemsPresentations.Ref AS Ref,
	|	SubsystemsPresentations.Presentation AS Presentation
	|INTO SubsystemsPresentations
	|FROM
	|	&SubsystemsPresentations AS SubsystemsPresentations
	|WHERE
	|	NOT &IsMainLanguage
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ISNULL(ReportsPlacementrt.Subsystem, ISNULL(ConfigurationReportsPlacement.Subsystem, ExtensionsReportsPlacement.Subsystem)) AS Subsystem
	|INTO ReportsOptionsPlacement
	|FROM
	|	ReportsOptions AS ReportsOptions
	|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
	|			ON AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion
	|			AND AvailableExtensionOptions.Variant = ReportsOptions.PredefinedOption
	|		LEFT JOIN Catalog.ReportsOptions.Location AS ReportsPlacementrt
	|			ON ReportsPlacementrt.Ref = ReportsOptions.Ref
	|			AND (NOT &HasFilterBySubsystems
	|				OR ReportsPlacementrt.Subsystem IN (&ReportsSubsystems))
	|		LEFT JOIN Catalog.PredefinedReportsOptions.Location AS ConfigurationReportsPlacement
	|			ON ConfigurationReportsPlacement.Ref = ReportsOptions.PredefinedOption
	|			AND (NOT &HasFilterBySubsystems
	|				OR ConfigurationReportsPlacement.Subsystem IN (&ReportsSubsystems))
	|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS ExtensionsReportsPlacement
	|			ON ExtensionsReportsPlacement.Ref = ReportsOptions.PredefinedOption
	|			AND (NOT &HasFilterBySubsystems
	|				OR ExtensionsReportsPlacement.Subsystem IN (&ReportsSubsystems))
	|WHERE
	|	(&NoFilterByDeletionMark
	|		OR NOT ReportsOptions.DeletionMark
	|		OR NOT AvailableExtensionOptions.Variant IS NULL)
	|	AND ISNULL(ReportsPlacementrt.Use, TRUE) 
	|	AND NOT ISNULL(ReportsPlacementrt.Subsystem,
	|		ISNULL(ConfigurationReportsPlacement.Subsystem, ExtensionsReportsPlacement.Subsystem)) IS NULL
	|	AND (&ShowPersonalReportsOptionsByOtherAuthors
	|		OR NOT ReportsOptions.AuthorOnly
	|		OR ReportsOptions.Author = &CurrentUser)
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ReportsOptionsPlacement.Ref AS Ref,
	|	ReportsOptionsPlacement.Subsystem,
	|	AvailableReportsOptions.Visible
	|INTO ReportOptionsSettings
	|FROM
	|	ReportsOptionsPlacement AS ReportsOptionsPlacement
	|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			ON UserGroupCompositions.User = &CurrentUser
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS AvailableReportsOptions
	|			ON AvailableReportsOptions.Variant = ReportsOptionsPlacement.Ref
	|			AND AvailableReportsOptions.Subsystem IN (
	|				ReportsOptionsPlacement.Subsystem,
	|				VALUE(Catalog.MetadataObjectIDs.EmptyRef))
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS UnavailableReportsOptions
	|			ON UnavailableReportsOptions.Variant = ReportsOptionsPlacement.Ref
	|			AND UnavailableReportsOptions.Subsystem = ReportsOptionsPlacement.Subsystem
	|			AND (UnavailableReportsOptions.User IN (&CurrentUser, UNDEFINED)
	|				OR VALUETYPE(&CurrentUser) = TYPE(Catalog.Users)
	|					AND UnavailableReportsOptions.User = VALUE(Catalog.UserGroups.AllUsers)
	|				OR VALUETYPE(&CurrentUser) = TYPE(Catalog.ExternalUsers)
	|					AND UnavailableReportsOptions.User = VALUE(Catalog.ExternalUsersGroups.AllExternalUsers))
	|			AND NOT UnavailableReportsOptions.Visible
	|WHERE
	|	&HasFilterByVisibility
	|	AND AvailableReportsOptions.User IN (UserGroupCompositions.UsersGroup, UNDEFINED)
	|	AND AvailableReportsOptions.Subsystem IN (&ReportsSubsystems)
	|	AND AvailableReportsOptions.Visible
	|	AND UnavailableReportsOptions.Variant IS NULL
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ReportsOptionsPlacement.Ref AS Ref,
	|	ReportsOptionsPlacement.Subsystem,
	|	ISNULL(MetadataIDs.Synonym, ISNULL(ExtensionsIDs.Synonym, ISNULL(SubsystemsPresentations.Presentation, """"))) AS SubsystemDescription
	|INTO PlacementConsideringSettings
	|FROM
	|	ReportsOptionsPlacement AS ReportsOptionsPlacement
	|		LEFT JOIN Catalog.MetadataObjectIDs AS MetadataIDs
	|			ON MetadataIDs.Ref = ReportsOptionsPlacement.Subsystem
	|			AND &IsMainLanguage
	|		LEFT JOIN Catalog.ExtensionObjectIDs AS ExtensionsIDs
	|			ON ExtensionsIDs.Ref = ReportsOptionsPlacement.Subsystem
	|			AND &IsMainLanguage
	|		LEFT JOIN SubsystemsPresentations AS SubsystemsPresentations
	|			ON SubsystemsPresentations.Ref = ReportsOptionsPlacement.Subsystem
	|			AND NOT &IsMainLanguage
	|		LEFT JOIN ReportOptionsSettings AS ReportOptionsSettings
	|			ON ReportOptionsSettings.Ref = ReportsOptionsPlacement.Ref
	|			AND ReportOptionsSettings.Subsystem IN (
	|				ReportsOptionsPlacement.Subsystem,
	|				VALUE(Catalog.MetadataObjectIDs.EmptyRef))
	|WHERE
	|	NOT &HasFilterByVisibility
	|		OR ReportOptionsSettings.Visible = TRUE
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ReportsOptions.Parent AS Parent,
	|	ReportsOptions.CurrentOptionName AS OptionDescription,
	|	ReportsOptions.AuthorOnly AS AuthorOnly,
	|	CASE
	|		WHEN &HasRightToReadAuthors
	|			THEN ReportsOptions.Author
	|		ELSE UNDEFINED
	|	END AS Author,
	|	CASE
	|		WHEN &HasRightToReadAuthors
	|			THEN ISNULL(ReportsOptions.Author.Description, """")
	|		ELSE """"
	|	END AS AuthorPresentation,
	|	ReportsOptions.Report AS Report,
	|	CASE
	|		WHEN &GetSummaryTable
	|			THEN ReportsOptions.Report.NAME
	|		ELSE UNDEFINED
	|	END AS ReportName,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	ReportsOptions.ReportType AS ReportType,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.PredefinedOption AS PredefinedOption,
	|	ReportsOptions.Purpose AS Purpose,
	|	ReportsOptions.FilterParameterDescriptions AS FilterParameterDescriptions,
	|	ReportsOptions.FieldDescriptions AS FieldDescriptions,
	|	ReportsOptions.Keywords AS Keywords,
	|	ReportsOptions.CurrentDescriptionOption AS LongDesc,
	|	Location.Subsystem AS Subsystem,
	|	Location.SubsystemDescription AS SubsystemDescription,
	|	UNDEFINED AS UserSettingKey,
	|	UNDEFINED AS UserSettingPresentation,
	|	ReportsOptions.DeletionMark AS DeletionMark
	|FROM
	|	ReportsOptions AS ReportsOptions
	|		INNER JOIN PlacementConsideringSettings AS Location
	|			ON ReportsOptions.Ref = Location.Ref
	|WHERE
	|	(&NoFilterByDeletionMark
	|		OR NOT ReportsOptions.DeletionMark)
	|	AND NOT &SearchOnlyOptionsWithoutSubsystems
	|	AND &OptionsAndSubsystemsBySearchString
	|
	|UNION ALL
	|
	|SELECT
	|	ReportsOptions.Ref,
	|	ReportsOptions.Parent,
	|	ReportsOptions.CurrentOptionName,
	|	ReportsOptions.AuthorOnly,
	|	CASE
	|		WHEN &HasRightToReadAuthors
	|			THEN ReportsOptions.Author
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN &HasRightToReadAuthors
	|			THEN ISNULL(ReportsOptions.Author.Description, """")
	|		ELSE """"
	|	END,
	|	ReportsOptions.Report,
	|	CASE
	|		WHEN &GetSummaryTable
	|			THEN ReportsOptions.Report.NAME
	|		ELSE UNDEFINED
	|	END,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.ReportType,
	|	ReportsOptions.Custom,
	|	ReportsOptions.PredefinedOption,
	|	ReportsOptions.Purpose,
	|	ReportsOptions.FilterParameterDescriptions,
	|	ReportsOptions.FieldDescriptions,
	|	ReportsOptions.Keywords,
	|	ReportsOptions.CurrentDescriptionOption,
	|	VALUE(Catalog.MetadataObjectIDs.EmptyRef),
	|	Location.SubsystemDescription,
	|	UNDEFINED,
	|	UNDEFINED,
	|	ReportsOptions.DeletionMark
	|FROM
	|	ReportsOptions AS ReportsOptions
	|		LEFT JOIN PlacementConsideringSettings AS Location
	|		ON ReportsOptions.Ref = Location.Ref
	|WHERE
	|	(&NoFilterByDeletionMark
	|			OR NOT ReportsOptions.DeletionMark)
	|	AND &OptionsAndSubsystemsBySearchString
	|	AND Location.Subsystem IS NULL
	|	AND &SearchOptionsWithoutSubsystems
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	UserSettings2.Variant,
	|	ReportsOptions.Parent,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UserSettings2.UserSettingKey,
	|	UserSettings2.Description,
	|	UNDEFINED
	|FROM
	|	ReportsOptions AS ReportsOptions
	|		INNER JOIN Catalog.UserReportSettings AS UserSettings2
	|			ON ReportsOptions.Ref = UserSettings2.Variant
	|WHERE
	|	(&NoFilterByDeletionMark
	|		OR ReportsOptions.DeletionMark = FALSE)
	|	AND (&NoFilterByDeletionMark
	|		OR UserSettings2.DeletionMark = FALSE)
	|	AND UserSettings2.User = &CurrentUser
	|	AND NOT &SearchOnlyOptionsWithoutSubsystems
	|	AND &UserSettingsBySearchString";
	
	Return TheTextOfTheRequest + Common.QueryBatchSeparator() + QueryTextShared;
	
EndFunction

Function ReportsWithSimpleFiltersQueryText()
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	
	If CurrentLanguageSuffix <> Undefined Then
		
		QueryText = "SELECT ALLOWED DISTINCT
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Parent AS Parent,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN NOT UserReportOptions.Ref IS NULL
		|			THEN ReportsOptions.Description
		|		ELSE CAST(ISNULL(ISNULL(ConfigurationOptions.Description, ExtensionOptions.Description), ReportsOptions.Description) AS STRING(1000))
		|	END AS Description,
		|	ReportsOptions.AuthorOnly AS AuthorOnly,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN ReportsOptions.Author
		|		ELSE UNDEFINED
		|	END AS Author,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN PRESENTATION(ReportsOptions.Author)
		|		ELSE """"
		|	END AS AuthorPresentation,
		|	ReportsOptions.Report AS Report,
		|	&ReportName AS ReportName,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedOption AS PredefinedOption,
		|	ReportsOptions.Purpose AS Purpose,
		|	CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000)) AS FilterParameterDescriptions,
		|	CAST(ReportsOptions.FieldDescriptions AS STRING(1000)) AS FieldDescriptions,
		|	CAST(ReportsOptions.Keywords AS STRING(1000)) AS Keywords,
		|	CASE
		|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ExtensionOptions.LongDesc) AS STRING(1000))
		|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
		|	END AS LongDesc,
		|	UNDEFINED AS Subsystem,
		|	"""" AS SubsystemDescription,
		|	UNDEFINED AS UserSettingKey,
		|	UNDEFINED AS UserSettingPresentation,
		|	ReportsOptions.DeletionMark AS DeletionMark
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|	LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|		ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
		|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|		ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
		|	LEFT JOIN InformationRegister.UserGroupCompositions AS GroupsOfTheCurrentUser
		|		ON GroupsOfTheCurrentUser.User = &CurrentUser
		|	LEFT JOIN InformationRegister.ReportOptionsSettings AS AvailableReportsOptions
		|		ON AvailableReportsOptions.Variant = ReportsOptions.Ref
		|	LEFT JOIN Catalog.ReportsOptions AS UserReportOptions
		|		ON UserReportOptions.Ref = ReportsOptions.Ref
		|		AND (UserReportOptions.Custom
		|			OR UserReportOptions.PredefinedOption IN (
		|				UNDEFINED,
		|				VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|				VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|WHERE
		|	ReportsOptions.Report IN (&UserReports)
		|	AND (NOT &HasFilterByReportTypes
		|		OR ReportsOptions.ReportType IN (&ReportsTypes))
		|	AND (NOT ReportsOptions.Custom
		|		OR &NoFilterByDeletionMark
		|		OR NOT ReportsOptions.InteractiveDeletionMark)
		|	AND (ReportsOptions.Custom
		|		OR &NoFilterByDeletionMark
		|		OR NOT ReportsOptions.DeletionMark)
		|	AND (&ShowPersonalReportsOptionsByOtherAuthors
		|		OR NOT ReportsOptions.AuthorOnly AND ISNULL(AvailableReportsOptions.User, UNDEFINED) IN (GroupsOfTheCurrentUser.UsersGroup, UNDEFINED)
		|		OR ReportsOptions.Author = &CurrentUser AND ReportsOptions.AuthorOnly AND &OnlyPersonal
		|		OR ReportsOptions.Author = &CurrentUser AND NOT &OnlyPersonal)
		|	AND ISNULL(AvailableReportsOptions.Visible, TRUE)
		|	AND (&HasFilterByContext
		|		AND (ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|			AND (ConfigurationOptions.ShouldShowInOptionsSubmenu = TRUE
  		|			OR ExtensionOptions.ShouldShowInOptionsSubmenu = TRUE)
		|			OR NOT UserReportOptions.Ref IS NULL
		|			AND ReportsOptions.Context = &Context)
		|			OR NOT &HasFilterByContext
		|			AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions))";

	
	Else
		
		QueryText =
		"SELECT ALLOWED DISTINCT
		|	ReportsOptions.Ref AS Ref,
		|	ReportsOptions.Parent AS Parent,
		|	CASE
		|		WHEN &DontGetDetails
		|			THEN UNDEFINED
		|		WHEN &IsMainLanguage
		|			AND NOT UserReportOptions.Ref IS NULL
		|			THEN ReportsOptions.Description
		|		WHEN NOT &IsMainLanguage
		|			AND NOT UserReportOptions.Ref IS NULL
		|			THEN CAST(ISNULL(OptionsPresentations.Description, ReportsOptions.Description) AS STRING(150))
		|		WHEN &IsMainLanguage
		|			THEN CAST(ISNULL(ISNULL(ConfigurationOptions.Description, ExtensionOptions.Description), ReportsOptions.Description) AS STRING(150))
		|		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.Description, PresentationsFromExtensions.Description), OptionsPresentations.Description) AS STRING(150))
		|	END AS Description,
		|	ReportsOptions.AuthorOnly AS AuthorOnly,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN ReportsOptions.Author
		|		ELSE UNDEFINED
		|	END AS Author,
		|	CASE
		|		WHEN &HasRightToReadAuthors
		|			THEN PRESENTATION(ReportsOptions.Author)
		|		ELSE """"
		|	END AS AuthorPresentation,
		|	ReportsOptions.Report AS Report,
		|	&ReportName AS ReportName,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.Custom AS Custom,
		|	ReportsOptions.PredefinedOption AS PredefinedOption,
		|	ReportsOptions.Purpose AS Purpose,
		|	CAST(ReportsOptions.FilterParameterDescriptions AS STRING(1000)) AS FilterParameterDescriptions,
		|	CAST(ReportsOptions.FieldDescriptions AS STRING(1000)) AS FieldDescriptions,
		|	CAST(ReportsOptions.Keywords AS STRING(1000)) AS Keywords,
		|	CASE
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ExtensionOptions.LongDesc) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage AND SUBSTRING(OptionsPresentations.LongDesc, 1, 1) <> """"
		|			THEN CAST(OptionsPresentations.LongDesc AS STRING(1000))
		|		ELSE CAST(ISNULL(ISNULL(PresentationsFromConfiguration.LongDesc, PresentationsFromExtensions.LongDesc), ReportsOptions.LongDesc) AS STRING(1000))
		|	END AS LongDesc,
		|	UNDEFINED AS Subsystem,
		|	"""" AS SubsystemDescription,
		|	UNDEFINED AS UserSettingKey,
		|	UNDEFINED AS UserSettingPresentation,
		|	ReportsOptions.DeletionMark AS DeletionMark
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|	LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|		ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
		|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|		ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
		|	LEFT JOIN Catalog.ReportsOptions.Presentations AS OptionsPresentations
		|		ON ReportsOptions.Ref = OptionsPresentations.Ref
		|		AND (OptionsPresentations.LanguageCode = &LanguageCode)
		|	LEFT JOIN Catalog.PredefinedReportsOptions.Presentations AS PresentationsFromConfiguration
		|		ON ReportsOptions.PredefinedOption = PresentationsFromConfiguration.Ref
		|		AND (PresentationsFromConfiguration.LanguageCode = &LanguageCode)
		|	LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Presentations AS PresentationsFromExtensions
		|		ON ReportsOptions.PredefinedOption = PresentationsFromExtensions.Ref
		|		AND (PresentationsFromExtensions.LanguageCode = &LanguageCode)
		|	LEFT JOIN InformationRegister.UserGroupCompositions AS GroupsOfTheCurrentUser
		|		ON GroupsOfTheCurrentUser.User = &CurrentUser
		|	LEFT JOIN InformationRegister.ReportOptionsSettings AS AvailableReportsOptions
		|		ON AvailableReportsOptions.Variant = ReportsOptions.Ref
		|	LEFT JOIN Catalog.ReportsOptions AS UserReportOptions
		|		ON UserReportOptions.Ref = ReportsOptions.Ref
		|		AND (UserReportOptions.Custom
		|			OR UserReportOptions.PredefinedOption IN (
		|				UNDEFINED,
		|				VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|				VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|WHERE
		|	ReportsOptions.Report IN (&UserReports)
		|	AND (NOT &HasFilterByReportTypes
		|		OR ReportsOptions.ReportType IN (&ReportsTypes))
		|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|	AND (NOT ReportsOptions.Custom
		|		OR &NoFilterByDeletionMark
		|		OR NOT ReportsOptions.InteractiveDeletionMark)
		|	AND (ReportsOptions.Custom
		|		OR &NoFilterByDeletionMark
		|		OR NOT ReportsOptions.DeletionMark)
		|	AND (&ShowPersonalReportsOptionsByOtherAuthors
		|		OR NOT ReportsOptions.AuthorOnly AND ISNULL(AvailableReportsOptions.User, UNDEFINED) IN (GroupsOfTheCurrentUser.UsersGroup, UNDEFINED)
		|		OR ReportsOptions.Author = &CurrentUser AND ReportsOptions.AuthorOnly AND &OnlyPersonal
		|		OR ReportsOptions.Author = &CurrentUser AND NOT &OnlyPersonal)
		|	AND ISNULL(AvailableReportsOptions.Visible, TRUE)
		|	AND (&HasFilterByContext
		|		AND (ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|			AND (ConfigurationOptions.ShouldShowInOptionsSubmenu = TRUE
  		|			OR ExtensionOptions.ShouldShowInOptionsSubmenu = TRUE)
		|			OR NOT UserReportOptions.Ref IS NULL
		|			AND ReportsOptions.Context = &Context)
		|			OR NOT &HasFilterByContext
		|			AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions))";
			
	EndIf;
	
	ReportName = "CASE
	|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
	|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
	|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
	|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(STRING)
	|			THEN CAST(ReportsOptions.Report AS STRING(150))
	|		ELSE UNDEFINED
	|	END";
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then 
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		AdditionalReportTableName = ModuleAdditionalReportsAndDataProcessors.AdditionalReportTableName();
		
		ReportName = StringFunctionsClientServer.SubstituteParametersToString("CASE
			|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.MetadataObjectIDs)
			|			THEN CAST(ReportsOptions.Report AS Catalog.MetadataObjectIDs).Name
			|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(Catalog.ExtensionObjectIDs)
			|			THEN CAST(ReportsOptions.Report AS Catalog.ExtensionObjectIDs).Name
			|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(%1)
			|			THEN CAST(ReportsOptions.Report AS %1).ObjectName
			|		WHEN &GetSummaryTable AND VALUETYPE(ReportsOptions.Report) = TYPE(STRING)
			|			THEN CAST(ReportsOptions.Report AS STRING(150))
			|		ELSE UNDEFINED
			|	END", AdditionalReportTableName);
	EndIf;
	
	Return StrReplace(QueryText, "&ReportName", ReportName);
	
EndFunction

// Parameters:
//  Query - Query
// 
// Returns:
//   ValueTable:
//     * Ref - CatalogRef.ReportsOptions
//     * Parent - CatalogRef.ReportsOptions
//     * Description - String
//     * AuthorOnly - Boolean
//     * Author - CatalogRef.Users
//             - CatalogRef.ExternalUsers
//     * AuthorPresentation - String
//     * Report - CatalogRef.MetadataObjectIDs
//             - CatalogRef.ExtensionObjectIDs
//             - String
//             - CatalogRef.AdditionalReportsAndDataProcessors
//     * ReportName - String
//     * VariantKey - String
//     * ReportType - EnumRef.ReportsTypes
//     * Custom - Boolean
//     * PredefinedOption - CatalogRef.PredefinedReportsOptions
//                               - CatalogRef.PredefinedExtensionsReportsOptions
//     * FilterParameterDescriptions - String
//     * FieldDescriptions - String
//     * Keywords - String
//     * LongDesc - String
//     * Subsystem - CatalogRef.ExtensionObjectIDs
//                  - CatalogRef.MetadataObjectIDs
//     * SubsystemDescription - String
//     * UserSettingKey - String
//     * UserSettingPresentation - String
//     * DeletionMark - Boolean
//
Function SourceTableOfReportVariants(Query) Export
	
	Return Query.Execute().Unload();
	
EndFunction

// Visualizes a result of search for report options.
//
// Parameters:
//   WordArray - Array - Search query keywords, where::
//       * Item - String - Keyword.
//   SourceTable - ValueTable - Result of the report option query, where::
//       * OptionDescription - String - Report option name.
//       * LongDesc - String - Brief information about a report option.
//       * FieldDescriptions - String - String enumeration of report fields.
//       * FilterParameterDescriptions - String - String enumeration of data parameters and filters of report settings.
//       * Keywords - String - String enumeration of keywords.
//       * AuthorPresentation - String - Report author presentation.
//       * UserSettingPresentation - String - User setting description
//                                                           displayed in the settings list.
//       * Subsystem - CatalogRef.ExtensionObjectIDs
//                    - CatalogRef.MetadataObjectIDs - Reference to the metadata ID
//                                                                          of the subsystem containing the report.
//       * SubsystemDescription - String - Presentation of a subsystem where a report is placed.
//       * Ref - CatalogRef.ReportsOptions - Reference to a report option.
//   Result - See FindReportsOptions
//
Procedure GenerateSearchResults(Val WordArray, Val SourceTable, Result)
	
	SourceTable.Sort("Ref");
	TableRow = SourceTable[0];
	
	SearchAreaTemplate = New FixedStructure("Value, FoundWordsCount, WordHighlighting", "", 0, New ValueList);
	Variant = ReportOptionInfo(TableRow.Ref, TableRow.Parent, SearchAreaTemplate);
	
	PresentationSeparator = PresentationSeparator();
	FoundWords = New Map;
	
	Count = SourceTable.Count();
	For IndexOf = 1 To Count Do
		// Populate variables.
		If Not ValueIsFilled(Variant.OptionDescription.Value) And ValueIsFilled(TableRow.OptionDescription) Then
			Variant.OptionDescription.Value = TableRow.OptionDescription;
		EndIf;
		If Not ValueIsFilled(Variant.LongDesc.Value) And ValueIsFilled(TableRow.LongDesc) Then
			Variant.LongDesc.Value = TableRow.LongDesc;
		EndIf;
		If Not ValueIsFilled(Variant.FieldDescriptions.Value) And ValueIsFilled(TableRow.FieldDescriptions) Then
			Variant.FieldDescriptions.Value = TableRow.FieldDescriptions;
		EndIf;
		If Not ValueIsFilled(Variant.FilterParameterDescriptions.Value) And ValueIsFilled(TableRow.FilterParameterDescriptions) Then
			Variant.FilterParameterDescriptions.Value = TableRow.FilterParameterDescriptions;
		EndIf;
		If Not ValueIsFilled(Variant.Keywords.Value) And ValueIsFilled(TableRow.Keywords) Then
			Variant.Keywords.Value = TableRow.Keywords;
		EndIf;
		If Not ValueIsFilled(Variant.AuthorPresentation1.Value) And ValueIsFilled(TableRow.AuthorPresentation) Then
			Variant.AuthorPresentation1.Value = TableRow.AuthorPresentation;
		EndIf;
		If ValueIsFilled(TableRow.UserSettingPresentation) Then
			If Variant.UserSettingsDescriptions.Value = "" Then
				Variant.UserSettingsDescriptions.Value = TableRow.UserSettingPresentation;
			Else
				Variant.UserSettingsDescriptions.Value = Variant.UserSettingsDescriptions.Value
				+ PresentationSeparator
				+ TableRow.UserSettingPresentation;
			EndIf;
		EndIf;
		
		If ValueIsFilled(TableRow.SubsystemDescription)
			And Variant.Subsystems.Find(TableRow.Subsystem) = Undefined Then
			
			Variant.Subsystems.Add(TableRow.Subsystem);
			Subsystem = Result.SubsystemsHighlight.Get(TableRow.Subsystem);
			If Subsystem = Undefined Then
				Subsystem = New Structure;
				Subsystem.Insert("Ref", TableRow.Subsystem);
				Subsystem.Insert("SubsystemDescription", New Structure(SearchAreaTemplate));
				Subsystem.SubsystemDescription.Value = TableRow.SubsystemDescription;
				
				AllWordsFound = True;
				FoundWords.Insert(TableRow.Subsystem, New Map);
				
				For Each Word In WordArray Do
					If MarkWord(Subsystem.SubsystemDescription, Word) Then
						FoundWords[TableRow.Subsystem].Insert(Word, True);
					Else
						AllWordsFound = False;
					EndIf;
				EndDo;
				If AllWordsFound Then
					Result.Subsystems.Add(Subsystem.Ref);
				EndIf;
				Result.SubsystemsHighlight.Insert(Subsystem.Ref, Subsystem);
			EndIf;
			
			SubsystemsDescriptions = Variant.SubsystemsDescriptions.Value;
			Variant.SubsystemsDescriptions.Value = ?(IsBlankString(SubsystemsDescriptions), 
				TableRow.SubsystemDescription, 
				SubsystemsDescriptions + PresentationSeparator + TableRow.SubsystemDescription);
		EndIf;
		
		If IndexOf < Count Then
			TableRow = SourceTable[IndexOf];
		EndIf;
		
		If IndexOf = Count Or TableRow.Ref <> Variant.Ref Then
			// Analyze the collected option information.
			AllWordsFound = True;
			LinkedSubsystems = New Array;
			For Each Word In WordArray Do
				WordFound = MarkWord(Variant.OptionDescription, Word) 
					Or MarkWord(Variant.LongDesc, Word)
					Or MarkWord(Variant.FieldDescriptions, Word, True)
					Or MarkWord(Variant.AuthorPresentation1, Word, True)
					Or MarkWord(Variant.FilterParameterDescriptions, Word, True)
					Or MarkWord(Variant.Keywords, Word, True)
					Or MarkWord(Variant.UserSettingsDescriptions, Word, True);
				
				If Not WordFound Then
					For Each SubsystemRef In Variant.Subsystems Do
						If FoundWords[SubsystemRef] <> Undefined Then
							WordFound = True;
							LinkedSubsystems.Add(SubsystemRef);
						EndIf;
					EndDo;
				EndIf;
				
				If Not WordFound Then
					AllWordsFound = False;
					Break;
				EndIf;
			EndDo;
			
			If AllWordsFound Then // Commit the result.
				Result.References.Add(Variant.Ref);
				Result.OptionsHighlight.Insert(Variant.Ref, Variant);
				If LinkedSubsystems.Count() > 0 Then
					Result.OptionsLinkedWithSubsystems.Insert(Variant.Ref, LinkedSubsystems);
				EndIf;
				// Delete the connection from the subordinate if the parent is found independently.
				ParentIndex = Result.ParentsLinkedWithOptions.Find(Variant.Ref);
				If ParentIndex <> Undefined Then
					Result.ParentsLinkedWithOptions.Delete(ParentIndex);
				EndIf;
				If ValueIsFilled(Variant.Parent) And Result.References.Find(Variant.Parent) = Undefined Then
					Result.References.Add(Variant.Parent);
					Result.ParentsLinkedWithOptions.Add(Variant.Parent);
				EndIf;
			EndIf;
			
			If IndexOf = Count Then
				Break;
			EndIf;
			
			Variant = ReportOptionInfo(TableRow.Ref, TableRow.Parent, SearchAreaTemplate);
		EndIf;
		
	EndDo;

EndProcedure

Function ReportOptionInfo(ReportOptionRef, ParentReference, SearchAreaTemplate)
	
	Variant = New Structure;
	Variant.Insert("Ref", ReportOptionRef);
	Variant.Insert("Parent", ParentReference);
	Variant.Insert("OptionDescription",                 New Structure(SearchAreaTemplate));
	Variant.Insert("LongDesc",                             New Structure(SearchAreaTemplate));
	Variant.Insert("FieldDescriptions",                    New Structure(SearchAreaTemplate));
	Variant.Insert("FilterParameterDescriptions",       New Structure(SearchAreaTemplate));
	Variant.Insert("Keywords",                        New Structure(SearchAreaTemplate));
	Variant.Insert("UserSettingsDescriptions", New Structure(SearchAreaTemplate));
	Variant.Insert("SubsystemsDescriptions",                New Structure(SearchAreaTemplate));
	Variant.Insert("Subsystems",                           New Array);
	Variant.Insert("AuthorPresentation1",                  New Structure(SearchAreaTemplate));
	Return Variant;
	
EndFunction

Procedure GenerateRefsList(Val ValueTable, ReferenceList)
	
	Duplicates = New Map;
	VariantsTable = ValueTable.Copy(, "Ref, Parent");
	VariantsTable.GroupBy("Ref, Parent");
	For Each TableRow In VariantsTable Do
		ReportOptionRef = TableRow.Ref;
		If ValueIsFilled(ReportOptionRef) And Duplicates[ReportOptionRef] = Undefined Then
			ReferenceList.Add(ReportOptionRef);
			Duplicates.Insert(ReportOptionRef);
			ReportOptionRef = TableRow.Parent;
			If ValueIsFilled(ReportOptionRef) And Duplicates[ReportOptionRef] = Undefined Then
				ReferenceList.Add(ReportOptionRef);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function DisabledReportOptions(Val UserReports = Undefined) Export
	
	If UserReports = Undefined Then
		UserReports = New Array(ReportsOptionsCached.AvailableReports());
	EndIf;
	
	// Get options that are unavailable by functional options.
	
	OptionsTable = ReportsOptionsCached.Parameters().FunctionalOptionsTable;
	VariantsTable = OptionsTable.CopyColumns("PredefinedOption, FunctionalOptionName");
	VariantsTable.Columns.Add("OptionValue", New TypeDescription("Number"));
	
	For Each ReportRef In UserReports Do
		FoundItems = OptionsTable.FindRows(New Structure("Report", ReportRef));
		For Each TableRow In FoundItems Do
			RowOption = VariantsTable.Add();
			FillPropertyValues(RowOption, TableRow);
			Value = GetFunctionalOption(TableRow.FunctionalOptionName);
			If Value = True Then
				RowOption.OptionValue = 1;
			EndIf;
		EndDo;
	EndDo;
	
	VariantsTable.GroupBy("PredefinedOption", "OptionValue");
	DisabledItemsTable = VariantsTable.Copy(New Structure("OptionValue", 0));
	DisabledItemsTable.GroupBy("PredefinedOption");
	DisabledItemsByFunctionalOptions = DisabledItemsTable.UnloadColumn("PredefinedOption");
	
	// Add options disabled by the developer.
	Query = New Query(
	"SELECT ALLOWED
	|	ConfigurationOptions.Ref
	|FROM
	|	Catalog.PredefinedReportsOptions AS ConfigurationOptions
	|WHERE
	|	ConfigurationOptions.Report IN (&UserReports)
	|	AND (NOT ConfigurationOptions.Enabled
	|		OR ConfigurationOptions.DeletionMark)
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionOptions.Ref
	|FROM
	|	Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
	|	LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS Versions
	|		ON ExtensionOptions.Ref = Versions.Variant
	|		AND ExtensionOptions.Report = Versions.Report
	|		AND Versions.ExtensionsVersion = &ExtensionsVersion
	|WHERE
	|	ExtensionOptions.Report IN (&UserReports)
	|	AND (NOT ExtensionOptions.Enabled
	|		OR Versions.Variant IS NULL)");
	
	Query.SetParameter("UserReports", UserReports);
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	
	DisabledForced = Query.Execute().Unload().UnloadColumn(0);
	CommonClientServer.SupplementArray(DisabledItemsByFunctionalOptions, DisabledForced);
	
	Return DisabledItemsByFunctionalOptions;
	
EndFunction

// Finds a word and marks a place where it was found.
//
// Parameters:
//   StructureWhere - Structure:
//       * Value - String - Source string.
//       * FoundWordsCount - Number - Search statistics.
//       * WordHighlighting - ValueList - Highlighted word fragments.
//   Word - String - Search substring.
//   UseSeparator - String - Word separator.
//
// Returns:
//   Boolean - True if the word is found.
//
Function MarkWord(StructureWhere, Word, UseSeparator = False) Export
	If StrStartsWith(StructureWhere.Value, "#") Then
		StructureWhere.Value = Mid(StructureWhere.Value, 2);
	EndIf;
	RemainderInReg = Upper(StructureWhere.Value);
	Position = StrFind(RemainderInReg, Word);
	If Position = 0 Then
		Return False;
	EndIf;
	If StructureWhere.FoundWordsCount = 0 Then
		// Initialize the variable that contains directives for highlighting words.
		StructureWhere.WordHighlighting = New ValueList;
		// Scroll the focus to a meaningful word (of the found information).
		If UseSeparator Then
			StorageSeparator = Chars.LF;
			PresentationSeparator = PresentationSeparator();
			SeparatorLength = StrLen(StorageSeparator);
			While Position > 10 Do
				SeparatorPosition = StrFind(RemainderInReg, StorageSeparator);
				If SeparatorPosition = 0 Then
					Break;
				EndIf;
				If SeparatorPosition < Position Then
					// Move the fragment before the separator to the end of area.
					StructureWhere.Value = (
						Mid(StructureWhere.Value, SeparatorPosition + SeparatorLength)
						+ StorageSeparator
						+ Left(StructureWhere.Value, SeparatorPosition - 1));
					RemainderInReg = (
						Mid(RemainderInReg, SeparatorPosition + SeparatorLength)
						+ StorageSeparator
						+ Left(RemainderInReg, SeparatorPosition - 1));
					// Updating information on word location.
					Position = Position - SeparatorPosition - SeparatorLength + 1;
				Else
					Break;
				EndIf;
			EndDo;
			StructureWhere.Value = StrReplace(StructureWhere.Value, StorageSeparator, PresentationSeparator);
			RemainderInReg = StrReplace(RemainderInReg, StorageSeparator, PresentationSeparator);
			Position = StrFind(RemainderInReg, Word);
		EndIf;
	EndIf;
	// Append a word found.
	StructureWhere.FoundWordsCount = StructureWhere.FoundWordsCount + 1;
	// Mark the words.
	LeftPartLength = 0;
	WordLength = StrLen(Word);
	While Position > 0 Do
		StructureWhere.WordHighlighting.Add(LeftPartLength + Position, "+");
		StructureWhere.WordHighlighting.Add(LeftPartLength + Position + WordLength, "-");
		RemainderInReg = Mid(RemainderInReg, Position + WordLength);
		LeftPartLength = LeftPartLength + Position + WordLength - 1;
		Position = StrFind(RemainderInReg, Word);
	EndDo;
	Return True;
EndFunction

// Returns information on the available report options.
//
// Parameters:
//   FillParameters - Structure
//   ResultAddress - String
//
Procedure FindReportOptionsForOutput(FillParameters, ResultAddress) Export
	
	QueryText = QueryTextAvailableReportOptions();
	Query = New Query(QueryText);
	
	SearchByRow = ValueIsFilled(FillParameters.SearchString);
	CurrentSectionOnly = FillParameters.SetupMode Or Not SearchByRow Or FillParameters.SearchInAllSections = 0;
	SubsystemsTable = FillParameters.ApplicationSubsystems; // ValueTable
	SubsystemsTable.Indexes.Add("Ref");
	
	SubsystemsArray = SubsystemsTable.UnloadColumn("Ref");
	
	RowEmptySubsystem = SubsystemsTable.Add();
	RowEmptySubsystem.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
	RowEmptySubsystem.SectionReference = Catalogs.MetadataObjectIDs.EmptyRef(); 
	RowEmptySubsystem.Presentation = NStr("en = 'Not included in sections';");
	RowEmptySubsystem.Priority = "999";
	RowEmptySubsystem.ItemNumber = 0;
		
	SearchParameters = New Structure;
	If SearchByRow Then
		SearchParameters.Insert("SearchString", FillParameters.SearchString);
	EndIf;
	If CurrentSectionOnly Then
		SearchParameters.Insert("Subsystems", SubsystemsArray);
	EndIf;
	SearchResult = FindReportsOptions(SearchParameters, False, True);
	
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	Query.SetParameter("SubsystemsArray", SubsystemsArray);
	Query.SetParameter("SubsystemsTable", SubsystemsTable);
	Query.SetParameter("SectionReference", FillParameters.CurrentSectionRef);
	Query.SetParameter("IsMainLanguage", Common.IsMainLanguage());
	Query.SetParameter("LanguageCode", CurrentLanguage().LanguageCode);
	Query.SetParameter("OptionsFoundBySearch", SearchResult.References);
	Query.SetParameter("SubsystemsFoundBySearch", SearchResult.Subsystems);
	Query.SetParameter("UserReports", SearchParameters.UserReports);
	Query.SetParameter("DIsabledApplicationOptions", SearchParameters.DIsabledApplicationOptions);
	Query.SetParameter("NoFilterBySubsystemsAndReports", Not SearchByRow And SearchParameters.Subsystems.Count() = 0);
	Query.SetParameter("NoFilterByVisibility", FillParameters.SetupMode Or SearchByRow);
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	Query.SetParameter("DisplayAllReportOptions", FillParameters.DisplayAllReportOptions);
	Query.SetParameter("ReportOptionPurposes", FillParameters.ReportOptionPurposes);
	Query.SetParameter("SearchInAllSections", FillParameters.SearchInAllSections);
	If FillParameters.DisplayAllReportOptions Then
		Query.Text = StrReplace(Query.Text, "&ConditionByReportOptionPurpose", "TRUE");
	Else
		Query.Text = StrReplace(Query.Text, "&ConditionByReportOptionPurpose", "ReportsOptions.Purpose IN (&ReportOptionPurposes)");
	EndIf;

	ResultTable1 = Query.Execute().Unload();
	FillReportsNames(ResultTable1);
	
	ResultTable1.Columns.Add("OutputWithMainReport", New TypeDescription("Boolean"));
	ResultTable1.Columns.Add("SubordinateCount", New TypeDescription("Number"));
	ResultTable1.Indexes.Add("Ref");
	
	If SearchByRow Then
		// Delete records about options that are linked to subsystems if a record is not mentioned in the link.
		For Each KeyAndValue In SearchResult.OptionsLinkedWithSubsystems Do
			OptionRef = KeyAndValue.Key;
			LinkedSubsystems = KeyAndValue.Value;
			FoundItems = ResultTable1.FindRows(New Structure("Ref", OptionRef));
			For Each TableRow In FoundItems Do
				If LinkedSubsystems.Find(TableRow.Subsystem) = Undefined Then
					ResultTable1.Delete(TableRow);
				EndIf;
			EndDo;
		EndDo;
		// Delete records about parents that are linked to options if a parent attempts to output without options.
		For Each ParentReference In SearchResult.ParentsLinkedWithOptions Do
			OutputLocation = ResultTable1.FindRows(New Structure("Ref", ParentReference));
			For Each TableRow In OutputLocation Do
				FoundItems = ResultTable1.FindRows(New Structure("Subsystem, Parent", TableRow.Subsystem, ParentReference));
				If FoundItems.Count() = 0 Then
					ResultTable1.Delete(TableRow);
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If CurrentSectionOnly Then
		OtherSections = New Array;
	Else
		TableCopy = ResultTable1.Copy();
		TableCopy.GroupBy("SectionReference");
		OtherSections = TableCopy.UnloadColumn("SectionReference");
		IndexOf = OtherSections.Find(FillParameters.CurrentSectionRef);
		If IndexOf <> Undefined Then
			OtherSections.Delete(IndexOf);
		EndIf;
	EndIf;
	
	WordArray = ?(SearchByRow, 
		ReportsOptionsClientServer.ParseSearchStringIntoWordArray(Upper(TrimAll(FillParameters.SearchString))),
		Undefined);
	
	Result = ReportOptionsToShow();
	Result.CurrentSectionOnly = CurrentSectionOnly;
	Result.SubsystemsTable = SubsystemsTable;
	Result.OtherSections = OtherSections;
	Result.Variants = ResultTable1;
	Result.UseHighlighting = SearchByRow;
	Result.SearchResult = SearchResult;
	Result.WordArray = WordArray;
	
	PutToTempStorage(Result, ResultAddress);
EndProcedure

Function QueryTextAvailableReportOptions()
	
	CurrentLanguageSuffix = Common.CurrentUserLanguageSuffix();
	
	If CurrentLanguageSuffix <> Undefined Then
		
		TheTextOfTheRequest = "
			|SELECT ALLOWED
			|	ReportsOptions.Ref AS Ref,
			|	PredefinedPlacement.Subsystem AS Subsystem,
			|	PredefinedPlacement.Important AS Important,
			|	PredefinedPlacement.SeeAlso AS SeeAlso,
			|	CAST(ISNULL(ConfigurationOptions.Description, ReportsOptions.Description) AS STRING(150)) AS Description,
			|	CASE
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
			|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
			|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
			|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
			|	END AS LongDesc,
			|	ReportsOptions.Report AS Report,
			|	ReportsOptions.ReportType AS ReportType,
			|	ReportsOptions.VariantKey AS VariantKey,
			|	ReportsOptions.Author AS Author,
			|	ReportsOptions.Parent AS Parent,
			|	CASE
			|		WHEN NOT &DisplayAllReportOptions
			|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS VisibilityByAssignment,
			|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
			|INTO ttPredefined
			|FROM
			|	Catalog.ReportsOptions AS ReportsOptions
			|		INNER JOIN Catalog.PredefinedReportsOptions.Location AS PredefinedPlacement
			|			ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
			|				OR (&NoFilterBySubsystemsAndReports
			|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch)))
			|			AND ReportsOptions.PredefinedOption = PredefinedPlacement.Ref
			|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
			|			AND (ReportsOptions.DeletionMark = FALSE)
			|			AND (&NoFilterBySubsystemsAndReports
			|				OR ReportsOptions.Report IN (&UserReports))
			|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
			|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
			|			ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
			|
			|WHERE
			|	NOT ReportsOptions.DeletionMark
			|	AND &ConditionByReportOptionPurpose
			|
			|UNION ALL
			|
			|SELECT
			|	ReportsOptions.Ref,
			|	PredefinedPlacement.Subsystem,
			|	PredefinedPlacement.Important,
			|	PredefinedPlacement.SeeAlso,
			|	CAST(ISNULL(ExtensionOptions.Description, ReportsOptions.Description) AS STRING(150)),
			|	CASE
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
			|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
			|			THEN CAST(ISNULL(ExtensionOptions.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
			|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
			|	END,
			|	ReportsOptions.Report,
			|	ReportsOptions.ReportType,
			|	ReportsOptions.VariantKey,
			|	ReportsOptions.Author,
			|	ReportsOptions.Parent,
			|	CASE
			|		WHEN NOT &DisplayAllReportOptions
			|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
			|			THEN TRUE
			|		ELSE FALSE
			|	END,
			|	ReportsOptions.PredefinedOption.MeasurementsKey
			|FROM
			|	Catalog.ReportsOptions AS ReportsOptions
			|		INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS PredefinedPlacement
			|			ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
			|				OR (&NoFilterBySubsystemsAndReports
			|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch)))
			|			AND ReportsOptions.PredefinedOption = PredefinedPlacement.Ref
			|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
			|			AND (&NoFilterBySubsystemsAndReports
			|				OR ReportsOptions.Report IN (&UserReports))
			|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
			|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
			|			ON AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion
			|			AND AvailableExtensionOptions.Variant = ReportsOptions.PredefinedOption
			|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
			|			ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
			|
			|WHERE
			|	(NOT ReportsOptions.DeletionMark
			|	OR NOT AvailableExtensionOptions.Variant IS NULL)
			|	AND &ConditionByReportOptionPurpose
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED DISTINCT
			|	ReportsPlacementrt.Ref AS Ref,
			|	ReportsPlacementrt.Subsystem AS Subsystem,
			|	ReportsPlacementrt.Use AS Use,
			|	ReportsPlacementrt.Important AS Important,
			|	ReportsPlacementrt.SeeAlso AS SeeAlso,
			|	CASE
			|		WHEN (ReportsOptions.Custom
			|				OR ReportsOptions.PredefinedOption IN (
			|					UNDEFINED,
			|					VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
			|					VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
			|			THEN ReportsOptions.Description
			|		ELSE CAST(ISNULL(ISNULL(ConfigurationReports.Description, ExtensionReports.Description), ReportsOptions.Description) AS STRING(150))
			|	END AS Description,
			|	CASE
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
			|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
			|		WHEN SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
			|			THEN CAST(ISNULL(ConfigurationReports.LongDesc, ExtensionReports.LongDesc) AS STRING(1000))
			|		ELSE CAST(ReportsOptions.LongDesc AS STRING(1000))
			|	END AS LongDesc,
			|	ReportsOptions.Report,
			|	ReportsOptions.ReportType,
			|	ReportsOptions.VariantKey,
			|	ReportsOptions.Author,
			|	CASE
			|		WHEN ReportsOptions.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
			|			THEN VALUE(Catalog.ReportsOptions.EmptyRef)
			|		WHEN ReportsOptions.Parent.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
			|			THEN ReportsOptions.Parent
			|		ELSE ReportsOptions.Parent.Parent
			|	END AS Parent,
			|	CASE
			|		WHEN NOT &DisplayAllReportOptions
			|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS VisibilityByAssignment,
			|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
			|INTO ttOptions
			|FROM
			|	Catalog.ReportsOptions.Location AS ReportsPlacementrt
			|		LEFT JOIN Catalog.ReportsOptions AS ReportsOptions
			|			ON ReportsOptions.Ref = ReportsPlacementrt.Ref
			|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationReports
			|			ON ConfigurationReports.Ref = ReportsOptions.PredefinedOption
			|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionReports
			|			ON ExtensionReports.Ref = ReportsOptions.PredefinedOption
			|WHERE
			|	(ReportsPlacementrt.Ref IN (&OptionsFoundBySearch)
			|		OR (&NoFilterBySubsystemsAndReports
			|			OR ReportsPlacementrt.Subsystem IN (&SubsystemsFoundBySearch)))
			|	AND ReportsPlacementrt.Subsystem IN (&SubsystemsArray)
			|	AND (NOT ReportsOptions.AuthorOnly
			|		OR ReportsOptions.Author = &CurrentUser)
			|	AND (&NoFilterBySubsystemsAndReports
			|		OR ReportsOptions.Report IN (&UserReports))
			|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
			|	AND (NOT ReportsOptions.Custom
			|		OR NOT ReportsOptions.InteractiveDeletionMark)
			|	AND (ReportsOptions.Custom
			|		OR NOT ReportsOptions.DeletionMark)
			|	AND &ConditionByReportOptionPurpose
			|";
			
			If ValueIsFilled(CurrentLanguageSuffix) Then
				If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport") Then
					ModuleNationalLanguageSupportServer = Common.CommonModule("NationalLanguageSupportServer");
		
					ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(TheTextOfTheRequest, "ReportsOptions.Description");
					ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(TheTextOfTheRequest, "ReportsOptions.LongDesc");
					
					ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(TheTextOfTheRequest, "ConfigurationOptions.Description");
					ModuleNationalLanguageSupportServer.ChangeRequestFieldUnderCurrentLanguage(TheTextOfTheRequest, "ConfigurationOptions.LongDesc");
				EndIf;
			EndIf;
			
	Else
		
		TheTextOfTheRequest = "
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ReportsOptions.Ref AS Ref,
		|	PredefinedPlacement.Subsystem AS Subsystem,
		|	PredefinedPlacement.Important AS Important,
		|	PredefinedPlacement.SeeAlso AS SeeAlso,
		|	CASE
		|		WHEN &IsMainLanguage
		|			THEN CAST(ISNULL(ConfigurationOptions.Description, ReportsOptions.Description) AS STRING(150))
		|		ELSE CAST(ISNULL(PresentationsFromConfiguration.Description, OptionsPresentations.Description) AS STRING(150))
		|	END AS Description,
		|	CASE
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationOptions.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage AND SUBSTRING(OptionsPresentations.LongDesc, 1, 1) <> """"
		|			THEN CAST(OptionsPresentations.LongDesc AS STRING(1000))
		|		ELSE CAST(ISNULL(PresentationsFromConfiguration.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
		|	END AS LongDesc,
		|	ReportsOptions.Report AS Report,
		|	ReportsOptions.ReportType AS ReportType,
		|	ReportsOptions.VariantKey AS VariantKey,
		|	ReportsOptions.Author AS Author,
		|	ReportsOptions.Parent AS Parent,
		|	CASE
		|		WHEN NOT &DisplayAllReportOptions
		|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS VisibilityByAssignment,
		|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
		|INTO ttPredefined
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|		INNER JOIN Catalog.PredefinedReportsOptions.Location AS PredefinedPlacement
		|			ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
		|				OR (&NoFilterBySubsystemsAndReports
		|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch)))
		|			AND ReportsOptions.PredefinedOption = PredefinedPlacement.Ref
		|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
		|			AND (ReportsOptions.DeletionMark = FALSE)
		|			AND (&NoFilterBySubsystemsAndReports
		|				OR ReportsOptions.Report IN (&UserReports))
		|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
		|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationOptions
		|			ON ReportsOptions.PredefinedOption = ConfigurationOptions.Ref
		|		LEFT JOIN Catalog.PredefinedReportsOptions.Presentations AS PresentationsFromConfiguration
		|			ON ReportsOptions.PredefinedOption = PresentationsFromConfiguration.Ref
		|			AND (PresentationsFromConfiguration.LanguageCode = &LanguageCode)
		|		LEFT JOIN Catalog.ReportsOptions.Presentations AS OptionsPresentations
		|			ON ReportsOptions.Ref = OptionsPresentations.Ref
		|			AND (OptionsPresentations.LanguageCode = &LanguageCode)
		|WHERE
		|	NOT ReportsOptions.DeletionMark
		|	AND &ConditionByReportOptionPurpose
		|
		|UNION ALL
		|
		|SELECT
		|	ReportsOptions.Ref,
		|	PredefinedPlacement.Subsystem,
		|	PredefinedPlacement.Important,
		|	PredefinedPlacement.SeeAlso,
		|	CASE
		|		WHEN &IsMainLanguage
		|			THEN CAST(ISNULL(ExtensionOptions.Description, ReportsOptions.Description) AS STRING(150))
		|		ELSE CAST(ISNULL(PresentationsFromExtensions.Description, OptionsPresentations.Description) AS STRING(150))
		|	END,
		|	CASE
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ExtensionOptions.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage AND SUBSTRING(OptionsPresentations.LongDesc, 1, 1) <> """"
		|			THEN CAST(OptionsPresentations.LongDesc AS STRING(1000))
		|		ELSE CAST(ISNULL(PresentationsFromExtensions.LongDesc, ReportsOptions.LongDesc) AS STRING(1000))
		|	END,
		|	ReportsOptions.Report,
		|	ReportsOptions.ReportType,
		|	ReportsOptions.VariantKey,
		|	ReportsOptions.Author,
		|	ReportsOptions.Parent,
		|	CASE
		|		WHEN NOT &DisplayAllReportOptions
		|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
		|			THEN TRUE
		|		ELSE FALSE
		|	END,
		|	ReportsOptions.PredefinedOption.MeasurementsKey
		|FROM
		|	Catalog.ReportsOptions AS ReportsOptions
		|		INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Location AS PredefinedPlacement
		|			ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
		|				OR (&NoFilterBySubsystemsAndReports
		|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch)))
		|			AND ReportsOptions.PredefinedOption = PredefinedPlacement.Ref
		|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
		|			AND (&NoFilterBySubsystemsAndReports
		|				OR ReportsOptions.Report IN (&UserReports))
		|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
		|		LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS AvailableExtensionOptions
		|			ON AvailableExtensionOptions.ExtensionsVersion = &ExtensionsVersion
		|			AND AvailableExtensionOptions.Variant = ReportsOptions.PredefinedOption
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionOptions
		|			ON ReportsOptions.PredefinedOption = ExtensionOptions.Ref
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Presentations AS PresentationsFromExtensions
		|			ON ReportsOptions.PredefinedOption = PresentationsFromExtensions.Ref
		|			AND (PresentationsFromExtensions.LanguageCode = &LanguageCode)
		|		LEFT JOIN Catalog.ReportsOptions.Presentations AS OptionsPresentations
		|			ON ReportsOptions.Ref = OptionsPresentations.Ref
		|			AND (OptionsPresentations.LanguageCode = &LanguageCode)
		|WHERE
		|	(NOT ReportsOptions.DeletionMark
		|	OR NOT AvailableExtensionOptions.Variant IS NULL)
		|	AND &ConditionByReportOptionPurpose
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	ReportsPlacementrt.Ref AS Ref,
		|	ReportsPlacementrt.Subsystem AS Subsystem,
		|	ReportsPlacementrt.Use AS Use,
		|	ReportsPlacementrt.Important AS Important,
		|	ReportsPlacementrt.SeeAlso AS SeeAlso,
		|	CASE
		|		WHEN &IsMainLanguage
		|			AND (ReportsOptions.Custom
		|				OR ReportsOptions.PredefinedOption IN (
		|					UNDEFINED,
		|					VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|					VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|			THEN ReportsOptions.Description
		|		WHEN NOT &IsMainLanguage
		|			AND (ReportsOptions.Custom
		|				OR ReportsOptions.PredefinedOption IN (
		|					UNDEFINED,
		|					VALUE(Catalog.PredefinedReportsOptions.EmptyRef),
		|					VALUE(Catalog.PredefinedExtensionsReportsOptions.EmptyRef)))
		|			THEN CAST(ISNULL(ReportsPresentations1.Description, ReportsOptions.Description) AS STRING(150))
		|		WHEN &IsMainLanguage
		|			THEN CAST(ISNULL(ISNULL(ConfigurationReports.Description, ExtensionReports.Description), ReportsOptions.Description) AS STRING(150))
		|		ELSE CAST(ISNULL(ISNULL(ConfigurationReportsPresentations.Description, ExtensionsReportsPresentations.Description), ReportsPresentations1.Description) AS STRING(150))
		|	END AS Description,
		|	CASE
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsOptions.LongDesc AS STRING(1000))
		|		WHEN &IsMainLanguage AND SUBSTRING(ReportsOptions.LongDesc, 1, 1) = """"
		|			THEN CAST(ISNULL(ConfigurationReports.LongDesc, ExtensionReports.LongDesc) AS STRING(1000))
		|		WHEN NOT &IsMainLanguage AND SUBSTRING(ReportsPresentations1.LongDesc, 1, 1) <> """"
		|			THEN CAST(ReportsPresentations1.LongDesc AS STRING(1000))
		|		ELSE CAST(ISNULL(ISNULL(ConfigurationReportsPresentations.LongDesc, ExtensionsReportsPresentations.LongDesc), ReportsOptions.LongDesc) AS STRING(1000))
		|	END AS LongDesc,
		|	ReportsOptions.Report,
		|	ReportsOptions.ReportType,
		|	ReportsOptions.VariantKey,
		|	ReportsOptions.Author,
		|	CASE
		|		WHEN ReportsOptions.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
		|			THEN VALUE(Catalog.ReportsOptions.EmptyRef)
		|		WHEN ReportsOptions.Parent.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
		|			THEN ReportsOptions.Parent
		|		ELSE ReportsOptions.Parent.Parent
		|	END AS Parent,
		|	CASE
		|		WHEN NOT &DisplayAllReportOptions
		|			OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS VisibilityByAssignment,
		|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
		|INTO ttOptions
		|FROM
		|	Catalog.ReportsOptions.Location AS ReportsPlacementrt
		|		LEFT JOIN Catalog.ReportsOptions AS ReportsOptions
		|			ON ReportsOptions.Ref = ReportsPlacementrt.Ref
		|		LEFT JOIN Catalog.ReportsOptions.Presentations AS ReportsPresentations1
		|			ON ReportsPresentations1.Ref = ReportsOptions.Ref
		|			AND ReportsPresentations1.LanguageCode = &LanguageCode
		|		LEFT JOIN Catalog.PredefinedReportsOptions AS ConfigurationReports
		|			ON ConfigurationReports.Ref = ReportsOptions.PredefinedOption
		|		LEFT JOIN Catalog.PredefinedReportsOptions.Presentations AS ConfigurationReportsPresentations
		|			ON ConfigurationReportsPresentations.Ref = ReportsOptions.PredefinedOption
		|			AND ConfigurationReportsPresentations.LanguageCode = &LanguageCode
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions AS ExtensionReports
		|			ON ExtensionReports.Ref = ReportsOptions.PredefinedOption
		|		LEFT JOIN Catalog.PredefinedExtensionsReportsOptions.Presentations AS ExtensionsReportsPresentations
		|			ON ExtensionsReportsPresentations.Ref = ReportsOptions.PredefinedOption
		|			AND ExtensionsReportsPresentations.LanguageCode = &LanguageCode
		|WHERE
		|	(ReportsPlacementrt.Ref IN (&OptionsFoundBySearch)
		|		OR (&NoFilterBySubsystemsAndReports
		|			OR ReportsPlacementrt.Subsystem IN (&SubsystemsFoundBySearch)))
		|	AND ReportsPlacementrt.Subsystem IN (&SubsystemsArray)
		|	AND (NOT ReportsOptions.AuthorOnly
		|		OR ReportsOptions.Author = &CurrentUser)
		|	AND (&NoFilterBySubsystemsAndReports
		|		OR ReportsOptions.Report IN (&UserReports))
		|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
		|	AND (NOT ReportsOptions.Custom
		|		OR NOT ReportsOptions.InteractiveDeletionMark)
		|	AND (ReportsOptions.Custom
		|		OR NOT ReportsOptions.DeletionMark)
		|	AND &ConditionByReportOptionPurpose
		|";
		
	EndIf;

	MainQuery = "
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ISNULL(ttOptions.Ref, ttPredefined.Ref) AS Ref,
	|	ISNULL(ttOptions.Subsystem, ttPredefined.Subsystem) AS Subsystem,
	|	ISNULL(ttOptions.Important, ttPredefined.Important) AS Important,
	|	ISNULL(ttOptions.SeeAlso, ttPredefined.SeeAlso) AS SeeAlso,
	|	ISNULL(ttOptions.Description, ttPredefined.Description) AS Description,
	|	ISNULL(ttOptions.LongDesc, ttPredefined.LongDesc) AS LongDesc,
	|	ISNULL(ttOptions.Author, ttPredefined.Author) AS Author,
	|	ISNULL(ttOptions.Report, ttPredefined.Report) AS Report,
	|	ISNULL(ttOptions.ReportType, ttPredefined.ReportType) AS ReportType,
	|	ISNULL(ttOptions.VariantKey, ttPredefined.VariantKey) AS VariantKey,
	|	ISNULL(ttOptions.Parent, ttPredefined.Parent) AS Parent,
	|	ISNULL(ttOptions.VisibilityByAssignment, ttPredefined.VisibilityByAssignment) AS VisibilityByAssignment,
	|	CASE
	|		WHEN ISNULL(ttOptions.Parent, ttPredefined.Parent) = VALUE(Catalog.ReportsOptions.EmptyRef)
	|		THEN TRUE
	|		ELSE FALSE
	|	END AS TopLevel,
	|	ISNULL(ttOptions.MeasurementsKey, ttPredefined.MeasurementsKey) AS MeasurementsKey
	|INTO ttAllOptionsWithSubsystems
	|FROM
	|	ttPredefined AS ttPredefined
	|		FULL JOIN ttOptions AS ttOptions
	|			ON ttPredefined.Ref = ttOptions.Ref
	|			AND ttPredefined.Subsystem = ttOptions.Subsystem
	|WHERE
	|	ISNULL(ttOptions.Use, TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ReportsOptions.Ref AS Ref,
	|	VALUE(Catalog.MetadataObjectIDs.EmptyRef) AS Subsystem,
	|	FALSE AS Important,
	|	FALSE AS SeeAlso,
	|	ReportsOptions.Description AS Description,
	|	CAST(ReportsOptions.LongDesc AS STRING(1000)) AS LongDesc,
	|	ReportsOptions.Author AS Author,
	|	ReportsOptions.Report AS Report,
	|	ReportsOptions.ReportType AS ReportType,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	CASE
	|		WHEN ReportsOptions.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN VALUE(Catalog.ReportsOptions.EmptyRef)
	|		WHEN ReportsOptions.Parent.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN ReportsOptions.Parent
	|		ELSE ReportsOptions.Parent.Parent
	|	END AS Parent,
	|	CASE
	|		WHEN NOT &DisplayAllReportOptions
	|				OR ReportsOptions.Purpose IN (&ReportOptionPurposes)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS VisibilityByAssignment,
	|	CASE
	|		WHEN ReportsOptions.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TopLevel,
	|	ReportsOptions.PredefinedOption.MeasurementsKey AS MeasurementsKey
	|INTO ttAllOptions
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		LEFT JOIN Catalog.ReportsOptions.Location AS ReportsPlacementrt
	|		ON ReportsOptions.Ref = ReportsPlacementrt.Ref
	|		LEFT JOIN ttAllOptionsWithSubsystems AS ttAllOptionsWithSubsystems
	|		ON ReportsOptions.Ref = ttAllOptionsWithSubsystems.Ref
	|WHERE
	|	(ReportsOptions.Ref IN (&OptionsFoundBySearch)
	|			OR (&NoFilterBySubsystemsAndReports
	|				OR ReportsPlacementrt.Subsystem IN (&SubsystemsFoundBySearch)))
	|	AND (ReportsPlacementrt.Ref IS NULL
	|			OR ReportsPlacementrt.Subsystem IN (&SubsystemsArray))
	|	AND (NOT ReportsOptions.AuthorOnly
	|			OR ReportsOptions.Author = &CurrentUser)
	|	AND (&NoFilterBySubsystemsAndReports
	|			OR ReportsOptions.Report IN (&UserReports))
	|	AND NOT ReportsOptions.PredefinedOption IN (&DIsabledApplicationOptions)
	|	AND (NOT ReportsOptions.Custom
	|			OR NOT ReportsOptions.InteractiveDeletionMark)
	|	AND (ReportsOptions.Custom
	|			OR NOT ReportsOptions.DeletionMark)
	|	AND &ConditionByReportOptionPurpose
	|	AND ttAllOptionsWithSubsystems.Ref IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	ttAllOptionsWithSubsystems.Ref,
	|	ttAllOptionsWithSubsystems.Subsystem,
	|	ttAllOptionsWithSubsystems.Important,
	|	ttAllOptionsWithSubsystems.SeeAlso,
	|	ttAllOptionsWithSubsystems.Description,
	|	ttAllOptionsWithSubsystems.LongDesc,
	|	ttAllOptionsWithSubsystems.Author,
	|	ttAllOptionsWithSubsystems.Report,
	|	ttAllOptionsWithSubsystems.ReportType,
	|	ttAllOptionsWithSubsystems.VariantKey,
	|	ttAllOptionsWithSubsystems.Parent,
	|	ttAllOptionsWithSubsystems.VisibilityByAssignment,
	|	ttAllOptionsWithSubsystems.TopLevel,
	|	ttAllOptionsWithSubsystems.MeasurementsKey
	|FROM
	|	ttAllOptionsWithSubsystems AS ttAllOptionsWithSubsystems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////	
	|SELECT
	|	Subsystems.Ref AS Subsystem,
	|	Subsystems.SectionReference AS SectionReference,
	|	Subsystems.Presentation AS Presentation,
	|	Subsystems.Priority AS Priority
	|INTO ttSubsystems
	|FROM
	|	&SubsystemsTable AS Subsystems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ttAllOptions.Ref AS Ref,
	|	ttAllOptions.Subsystem AS Subsystem,
	|	ttSubsystems.Presentation AS SubsystemPresentation,
	|	ISNULL(ttSubsystems.Priority, """") AS SubsystemPriority,
	|	ttSubsystems.SectionReference AS SectionReference,
	|	CASE
	|		WHEN ttAllOptions.Subsystem = ttSubsystems.SectionReference
	|			AND ttAllOptions.SeeAlso = FALSE
	|		THEN TRUE
	|		ELSE FALSE
	|	END AS NoGroup,
	|	ttAllOptions.Important AS Important,
	|	ttAllOptions.SeeAlso AS SeeAlso,
	|	CASE
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Additional)
	|		THEN TRUE
	|		ELSE FALSE
	|	END AS Additional,
	|	MAX(ISNULL(UnavailableReportsOptions.Visible, ISNULL(AvailableReportsOptions.Visible, FALSE))) AS Visible,
	|	MAX(ISNULL(UnavailableReportsOptions.QuickAccess, ISNULL(AvailableReportsOptions.QuickAccess, FALSE))) AS QuickAccess,
	|	CASE
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.BuiltIn)
	|				OR ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Extension)
	|			THEN ttAllOptions.Report.Name
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Additional)
	|			THEN """"
	|		ELSE SUBSTRING(CAST(ttAllOptions.Report AS STRING(150)), 14, 137)
	|	END AS ReportName,
	|	ISNULL(ttAllOptions.Description, """") AS Description,
	|	ttAllOptions.LongDesc AS LongDesc,
	|	ttAllOptions.Author AS Author,
	|	ttAllOptions.Report AS Report,
	|	ttAllOptions.ReportType AS ReportType,
	|	ttAllOptions.VariantKey AS VariantKey,
	|	ttAllOptions.Parent AS Parent,
	|	ttAllOptions.VisibilityByAssignment AS VisibilityByAssignment,
	|	ttAllOptions.TopLevel AS TopLevel,
	|	ttAllOptions.MeasurementsKey AS MeasurementsKey
	|FROM
	|	ttAllOptions AS ttAllOptions
	|		LEFT JOIN ttSubsystems AS ttSubsystems
	|			ON ttAllOptions.Subsystem = ttSubsystems.Subsystem
	|		LEFT JOIN InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|			ON UserGroupCompositions.User = &CurrentUser
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS AvailableReportsOptions
	|			ON AvailableReportsOptions.Variant = ttAllOptions.Ref
	|			AND AvailableReportsOptions.Subsystem IN (
	|				ttAllOptions.Subsystem,
	|				VALUE(Catalog.MetadataObjectIDs.EmptyRef))
	|			AND AvailableReportsOptions.User IN (UserGroupCompositions.UsersGroup, UNDEFINED)
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS UnavailableReportsOptions
	|			ON UnavailableReportsOptions.Variant = ttAllOptions.Ref
	|			AND UnavailableReportsOptions.Subsystem = ttAllOptions.Subsystem
	|			AND (UnavailableReportsOptions.User IN (&CurrentUser, UNDEFINED)
	|				OR VALUETYPE(&CurrentUser) = TYPE(Catalog.Users)
	|					AND UnavailableReportsOptions.User = VALUE(Catalog.UserGroups.AllUsers)
	|				OR VALUETYPE(&CurrentUser) = TYPE(Catalog.ExternalUsers)
	|					AND UnavailableReportsOptions.User = VALUE(Catalog.ExternalUsersGroups.AllExternalUsers))
	|			AND NOT UnavailableReportsOptions.Visible
	|WHERE
	|	(&NoFilterByVisibility
	|		OR AvailableReportsOptions.Visible = TRUE
	|			AND UnavailableReportsOptions.Variant IS NULL)
	|
	|GROUP BY
	|	ttAllOptions.Ref,
	|	ttAllOptions.Subsystem,
	|	ttSubsystems.Presentation,
	|	ISNULL(ttSubsystems.Priority, """"),
	|	ttSubsystems.SectionReference,
	|	CASE
	|		WHEN ttAllOptions.Subsystem = ttSubsystems.SectionReference
	|			AND ttAllOptions.SeeAlso = FALSE
	|		THEN TRUE
	|		ELSE FALSE
	|	END,
	|	ttAllOptions.Important,
	|	ttAllOptions.SeeAlso,
	|	CASE
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Additional)
	|		THEN TRUE
	|		ELSE FALSE
	|	END,
	|	CASE
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.BuiltIn)
	|				OR ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Extension)
	|			THEN ttAllOptions.Report.Name
	|		WHEN ttAllOptions.ReportType = VALUE(Enum.ReportsTypes.Additional)
	|			THEN """"
	|		ELSE SUBSTRING(CAST(ttAllOptions.Report AS STRING(150)), 14, 137)
	|	END,
	|	ISNULL(ttAllOptions.Description, """"),
	|	ttAllOptions.LongDesc,
	|	ttAllOptions.Author,
	|	ttAllOptions.Report,
	|	ttAllOptions.ReportType,
	|	ttAllOptions.VariantKey,
	|	ttAllOptions.Parent,
	|	ttAllOptions.VisibilityByAssignment,
	|	ttAllOptions.TopLevel,
	|	ttAllOptions.MeasurementsKey
	|
	|ORDER BY
	|	SubsystemPriority,
	|	Description";
	
	Return TheTextOfTheRequest + Common.QueryBatchSeparator() + MainQuery;

EndFunction

// Sets report names by metadata.
//
// Parameters:
//   ResultTable1 - ValueTable - Collection of the found report options, where::
//       * ReportName - String - Report name as it appears in metadata.
//       * Description - String - Report option name.
//       * Report - CatalogRef.ExtensionObjectIDs
//               - CatalogRef.AdditionalReportsAndDataProcessors
//               - CatalogRef.MetadataObjectIDs
//               - String - Reference to a report metadata ID.
//        * ReportType - EnumRef.ReportsTypes - Report category.
//
Procedure FillReportsNames(ResultTable1)
	
	ReportsIDs = New Array;
	For Each ReportRow In ResultTable1 Do
		If Not ReportRow.Additional Then
			ReportsIDs.Add(ReportRow.Report);
		EndIf;
	EndDo;
	ReportsObjects = Common.MetadataObjectsByIDs(ReportsIDs, False);
	NonexistentAndUnavailable = New Array;
	
	For Each ReportForOutput In ResultTable1 Do
		If ReportForOutput.ReportType = Enums.ReportsTypes.BuiltIn
			Or ReportForOutput.ReportType = Enums.ReportsTypes.Extension Then
			MetadataOfReport = ReportsObjects[ReportForOutput.Report]; // MetadataObjectReport
			If MetadataOfReport = Undefined Or MetadataOfReport = Null Then
				NonexistentAndUnavailable.Add(ReportForOutput);
			ElsIf ReportForOutput.ReportName <> MetadataOfReport.Name Then
				ReportForOutput.ReportName = MetadataOfReport.Name;
			EndIf;
		EndIf;
	EndDo;
	
	For Each UnavailableReport In NonexistentAndUnavailable Do
		ResultTable1.Delete(UnavailableReport);
	EndDo;
	
	ReportsWithDescription = ResultTable1.FindRows(New Structure("Description", "")); // Array of ValueTableRow
	For Each DescriptionOfReport In ReportsWithDescription Do
		If ValueIsFilled(DescriptionOfReport.ReportName) Then 
			DescriptionOfReport.Description = DescriptionOfReport.ReportName;
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Determine tables to use.

// Registers tables used in data sets in the array.
Procedure RegisterDataSetsTables(Tables, DataSets)
	For Each Set In DataSets Do
		If TypeOf(Set) = Type("DataCompositionSchemaDataSetQuery") Then
			RegisterQueryTables(Tables, Set.Query);
		ElsIf TypeOf(Set) = Type("DataCompositionSchemaDataSetUnion") Then
			RegisterDataSetsTables(Tables, Set.Items);
		ElsIf TypeOf(Set) = Type("DataCompositionSchemaDataSetObject") Then
			// Nothing to register.
		EndIf;
	EndDo;
EndProcedure

// Registers tables used in the query in the array.
Procedure RegisterQueryTables(Tables, QueryText)
	If Not ValueIsFilled(QueryText) Then
		Return;
	EndIf;
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText(QueryText);
	For Each Query In QuerySchema.QueryBatch Do
		If TypeOf(Query) = Type("QuerySchemaSelectQuery") Then
			RegisterQueryOperatorsTables(Tables, Query.Operators);
		ElsIf TypeOf(Query) = Type("QuerySchemaTableDropQuery") Then
			// Nothing to register.
		EndIf;
	EndDo;
EndProcedure

// Continuation of the procedure (see above).
Procedure RegisterQueryOperatorsTables(Tables, Operators)
	For Each Operator In Operators Do
		For Each Source In Operator.Sources Do
			Source = Source.Source;
			If TypeOf(Source) = Type("QuerySchemaTable") Then
				If Tables.Find(Source.TableName) = Undefined Then
					Tables.Add(Source.TableName);
				EndIf;
			ElsIf TypeOf(Source) = Type("QuerySchemaNestedQuery") Then
				RegisterQueryOperatorsTables(Tables, Source.Query.Operators);
			ElsIf TypeOf(Source) = Type("QuerySchemaTempTableDescription") Then
				// Nothing to register.
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Returns a message text that the report data is still being updated.
Function DataIsBeingUpdatedMessage() Export
	Return NStr("en = 'The report might contain incorrect data since the migration to the new version is not completed. If the report is not available for a while, contact the administrator.';");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Reports submenu.

// Called from OnDefineCommandsAttachedToObject.
Procedure OnAddReportsCommands(Commands, ObjectInfo, FormSettings)
	ObjectInfo.Manager.AddReportCommands(Commands, FormSettings);
	AddedCommands = Commands.FindRows(New Structure("Processed1", False));
	For Each Command In AddedCommands Do
		If Not ValueIsFilled(Command.Manager) Then
			Command.Manager = ObjectInfo.FullName;
		EndIf;
		If Not ValueIsFilled(Command.ParameterType) Then
			If TypeOf(ObjectInfo.DataRefType) = Type("Type") Then
				Command.ParameterType = New TypeDescription(CommonClientServer.ValueInArray(ObjectInfo.DataRefType));
			Else // Type("TypeDescription") or Undefined.
				Command.ParameterType = ObjectInfo.DataRefType;
			EndIf;
		EndIf;
		Command.Processed1 = True;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Service API auxiliaries

// Handler determining whether configuration reports and extensions are available.
Procedure OnDefineReportsAvailability(ReportsReferences, Result)
	ReportsNames = Common.ObjectsAttributeValue(ReportsReferences, "Name", True);
	For Each Report In ReportsReferences Do
		ReportName = ReportsNames[Report];
		AvailableByRLS = True;
		AvailableByRights = True;
		AvailableByOptions = True;
		FoundInApplication = True;
		If ReportName = Undefined Then
			AvailableByRLS = False;
		Else
			ReportMetadata = Metadata.Reports.Find(ReportName);
			If ReportMetadata = Undefined Then
				FoundInApplication = False;
			ElsIf Not AccessRight("View", ReportMetadata) Then
				AvailableByRights = False;
			ElsIf Not Common.MetadataObjectAvailableByFunctionalOptions(ReportMetadata) Then
				AvailableByOptions = False;
			EndIf;
		EndIf;
		FoundItems = Result.FindRows(New Structure("Report", Report));
		For Each TableRow In FoundItems Do
			If Not AvailableByRLS Then
				TableRow.Presentation = NStr("en = '<Insufficient rights to access the report option>';");
			ElsIf Not FoundInApplication Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '<Report %1 doesn''t exist in app>';"),
					ReportName);
			ElsIf Not AvailableByRights Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '<Insufficient rights to access report %1>';"),
					ReportName);
			ElsIf Not AvailableByOptions Then
				TableRow.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '<Report %1 disabled in settings>';"),
					ReportName);
			Else
				TableRow.Available = True;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Determines an attachment method of the common report form.
Function ByDefaultAllConnectedToMainForm()
	MetadataForm = Metadata.DefaultReportForm;
	Return (MetadataForm <> Undefined And MetadataForm = Metadata.CommonForms.ReportForm);
EndFunction

// Defines an attachment method of the common report settings form.
Function ByDefaultAllAttachedToSettingsForm()
	MetadataForm = Metadata.DefaultReportSettingsForm;
	Return (MetadataForm <> Undefined And MetadataForm = Metadata.CommonForms.ReportSettingsForm);
EndFunction

// Defines an attachment method of the report option storage.
Function ByDefaultAllAttachedToStorage()
	StorageMetadata = Metadata.ReportsVariantsStorage; // MetadataObjectSettingsStorage
	
	Return (StorageMetadata <> Undefined And StorageMetadata.Name = "ReportsVariantsStorage");
EndFunction

// Returns the predefined report option flag.
//
// Parameters:
//  ReportVariant - CatalogObject.ReportsOptions
//                - CatalogObject.PredefinedReportsOptions
//                - CatalogObject.PredefinedExtensionsReportsOptions
//                - CatalogRef.ReportsOptions
//                - CatalogRef.PredefinedExtensionsReportsOptions
//                - CatalogRef.PredefinedExtensionsReportsOptions
//                - Structure
//
// Returns:
//   Boolean - If True, the report option is predefined.
//
Function IsPredefinedReportOption(ReportVariant) Export 
	
	ReportOptionType = TypeOf(ReportVariant);
	
	If ReportOptionType = Type("CatalogObject.PredefinedReportsOptions")
		Or ReportOptionType = Type("CatalogObject.PredefinedExtensionsReportsOptions")
		Or ReportOptionType = Type("CatalogRef.PredefinedReportsOptions")
		Or ReportOptionType = Type("CatalogRef.PredefinedExtensionsReportsOptions") Then 
		
		Return True;
	EndIf;
	
	ReportOptionProperties = New Structure("Custom, PredefinedOption");
	FillPropertyValues(ReportOptionProperties, ReportVariant);
	
	Return ReportOptionProperties.Custom <> True
		And ValueIsFilled(ReportOptionProperties.PredefinedOption);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Filters.

// Sets filters based on extended information from the structure.
Procedure ComplementFiltersFromStructure(Filter, Structure, ViewMode = Undefined) Export
	If ViewMode = Undefined Then
		ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	EndIf;
	For Each KeyAndValue In Structure Do
		FieldName = KeyAndValue.Key;
		FilterFields = KeyAndValue.Value;
		Type = TypeOf(FilterFields);
		If Type = Type("Structure") Then
			Condition = DataCompositionComparisonType[FilterFields.Kind];
			Value = FilterFields.Value;
		ElsIf Type = Type("Array") Then
			Condition = DataCompositionComparisonType.InList;
			Value = FilterFields;
		ElsIf Type = Type("ValueList") Then
			Condition = DataCompositionComparisonType.InList;
			Value = FilterFields.UnloadValues();
		ElsIf Type = Type("DataCompositionComparisonType") Then
			Condition = FilterFields;
			Value = Undefined;
		Else
			Condition = DataCompositionComparisonType.Equal;
			Value = FilterFields;
		EndIf;
		CommonClientServer.SetFilterItem(
			Filter,
			FieldName,
			Value,
			Condition,
			,
			True,
			ViewMode);
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Report option settings exchange

#Region ExchangeSettingsBetweenInfobases

// Parameters:
//   FilesDetails - Array of Structure:
//     * Location - String
//     * Name - String
//
// Returns:
//   Array of Structure:
//     * Ref - CatalogRef.ReportsOptions
//     * ReportName - String
//     * Settings - Undefined
//                 - DataCompositionSettings
//     * VariantKey - String
//     * VariantPresentation - String
//     * CurrentUserSettingsKey - String
//     * CurrentUserSettingsPresentation - String
//     * UserSettings - ValueList
//     * Value - String
//     * Presentation - String
//     * UserSettingsStorage - Map of KeyAndValue:
//         ** Key - String
//         ** Value - DataCompositionUserSettings
//
Function UpdateReportOptionsFromFiles(FilesDetails) Export 
	
	ReportsOptionsDetails = New Array;
	
	For Each FileDetails In FilesDetails Do 
		
		ReportOptionDetails = ReportOptionDetails(FileDetails);
		Ref = UpdateReportOptionByDetails(ReportOptionDetails); // @skip-check query-in-loop - Save data object-by-object.
		ReportOptionDetails.Insert("Ref", Ref);
		
		ReportsOptionsDetails.Add(ReportOptionDetails);
		
	EndDo;
	
	Return ReportsOptionsDetails;
	
EndFunction

// Parameters:
//   FileDetails - Structure:
//     * Location - String
//     * Name - String
//   ReportOptionBase - CatalogRef.ReportsOptions
//
// Returns:
//   See ReportOptionDetails
//
Function UpdateReportOptionFromFile(FileDetails, ReportOptionBase) Export 
	
	ReportOptionDetails = ReportOptionDetails(FileDetails);
	Ref = UpdateReportOptionByDetails(ReportOptionDetails, ReportOptionBase);
	ReportOptionDetails.Insert("Ref", Ref);
	Return ReportOptionDetails;
	
EndFunction

// Parameters:
//   FileDetails - Structure:
//     * Location - String
//     * Name - String
//
// Returns:
//  Structure:
//    * ReportName - String
//    * Settings - Undefined
//                - DataCompositionSettings
//    * VariantKey - String
//    * VariantPresentation - String
//    * CurrentUserSettingsKey - String
//    * CurrentUserSettingsPresentation - String
//    * UserSettings - ValueList
//    * Value - String
//    * Presentation - String
//    * UserSettingsStorage - Map of KeyAndValue
//    * Key - String
//    * Value - DataCompositionUserSettings
//    * Ref - CatalogRef.ReportsOptions
//
Function ReportOptionDetails(FileDetails)
	
	DirectoryName = CommonClientServer.AddLastPathSeparator(FileSystem.CreateTemporaryDirectory());
	ArchiveFileName = GetTempFileName("zip"); // ACC:441 - The DeleteReportOptionDetailsFiles procedure deletes temporary files
	
	BinaryData = GetFromTempStorage(FileDetails.Location); // BinaryData
	BinaryData.Write(ArchiveFileName);
	
	Archive = New ZipFileReader(ArchiveFileName);
	Archive.ExtractAll(DirectoryName);
	
	ReportOptionDetails = ReadReportOptionSettings(DirectoryName);
	
	If ValueIsFilled(ReportOptionDetails.ErrorDescription) Then 
		
		DeleteReportOptionDetailsFiles(DirectoryName, ArchiveFileName);
		Raise ReportOptionDetails.ErrorDescription;
		
	EndIf;
	
	ReportOptionDetails.Settings = DeserializedSettings(DirectoryName + "Settings.xml");
	
	Counter = 0;
	
	For Each ListItem In ReportOptionDetails.UserSettings Do 
		
		Counter = Counter + 1;
		FileName = StringFunctionsClientServer.SubstituteParametersToString(DirectoryName + "UserSettings%1.xml", Counter);
		
		ReportOptionDetails.UserSettingsStorage.Insert(
			ListItem.Value, DeserializedSettings(FileName));
		
	EndDo;
	
	DeleteReportOptionDetailsFiles(DirectoryName, ArchiveFileName);
	
	Return ReportOptionDetails;
	
EndFunction

// Parameters:
//  DirectoryName - String
//
// Returns:
//   See ReportOptionSettingsDetails
//
Function ReadReportOptionSettings(DirectoryName)
	
	SettingsDescription = ReportOptionSettingsDetails();
	
#Region ReadSettingsDetailsFile
	
	HeaderDescriptionErrors = NStr("en = 'Incorrect settings description format:';") + Chars.LF;
	
	XMLReader = New XMLReader;
	FileName = "SettingsDescription.xml";
	Try
		XMLReader.OpenFile(DirectoryName + FileName);
	Except
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'File %1 is missing.';"), FileName);
		Return SettingsDescription;
	EndTry;
	
	DOMBuilder = New DOMBuilder;
	DOMDocument = DOMBuilder.Read(XMLReader);
	
	XMLReader.Close();
	
#EndRegion
	
#Region ReadCommonSettingsDetails
	
	If DOMDocument.ChildNodes.Count() = 0 Then 
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Item ""%1"" is missing.';"), "SettingsDescription");
		Return SettingsDescription;
	EndIf;
	
	Item = DOMDocument.ChildNodes.Item(0);
	
	TagName = "ReportName";
	ReportName = Item.Attributes.GetNamedItem(TagName);
	If ReportName = Undefined Then 
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Attribute ""%1"" is missing.';"), TagName);
		Return SettingsDescription;
	EndIf;
	
	SettingsDescription.ReportName = ReportName.Value;	
	Content = Item.ChildNodes;
	
#EndRegion
	
#Region ReadMainSettingsDetails
	
	TagName = "Settings"; 
	If Content.Count() = 0 Then 
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Item ""%1"" is missing.';"), TagName);
		Return SettingsDescription;
	EndIf;
	
	Item = Content.Item(0);
	
	AttributeName = "Key";
	VariantKey = Item.Attributes.GetNamedItem(AttributeName);
	If VariantKey = Undefined Then 
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Item ""%2"" is missing attribute ""%1"".';"), AttributeName, TagName);
		Return SettingsDescription;
	EndIf;
	
	SettingsDescription.VariantKey = VariantKey.Value;
	AttributeName = "Presentation"; 
	VariantPresentation = Item.Attributes.GetNamedItem(AttributeName);
	If VariantPresentation = Undefined Then 
		SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Item ""%2"" is missing attribute ""%1"".';"), AttributeName, TagName);
		Return SettingsDescription;
	EndIf;
	
	SettingsDescription.VariantPresentation = VariantPresentation.Value;
	
#EndRegion
	
#Region ReadUserSettingsDetails
	
	CompositionBorder = Content.Count() - 1;
	If CompositionBorder <= 0 Then 
		Return SettingsDescription;
	EndIf;
	
	TagName = "UserSettings"; 
	For IndexOf = 1 To CompositionBorder Do 
		
		Item = Content.Item(IndexOf);
		AttributeName = "Key";
		SettingsKey = Item.Attributes.GetNamedItem(AttributeName);
		If SettingsKey = Undefined Then 
			SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Item ""%2"" is missing attribute ""%1"".';"), AttributeName, TagName);
			Return SettingsDescription;
		EndIf;
		
		AttributeName = "Presentation";
		SettingsPresentation = Item.Attributes.GetNamedItem(AttributeName);
		If SettingsPresentation = Undefined Then 
			SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Item ""%2"" is missing attribute ""%1"".';"), AttributeName, TagName);			
			Return SettingsDescription;
		EndIf;
		
		AttributeName = "isCurrent";
		IsCurrent1Presentation = Item.Attributes.GetNamedItem(AttributeName);
		If IsCurrent1Presentation = Undefined Then 
			SettingsDescription.ErrorDescription = HeaderDescriptionErrors + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Item ""%2"" is missing attribute ""%1"".';"), AttributeName, TagName);			
			Return SettingsDescription;
		EndIf;
		
		IsCurrent1 = XMLValue(Type("Boolean"), IsCurrent1Presentation.Value);
		
		SettingsDescription.UserSettings.Add(
			SettingsKey.Value, SettingsPresentation.Value, IsCurrent1);
		
		If IsCurrent1 Then			
			SettingsDescription.CurrentUserSettingsKey = SettingsKey.Value;
			SettingsDescription.CurrentUserSettingsPresentation = SettingsPresentation.Value;
		EndIf;
		
	EndDo;
	
#EndRegion
	
	Return SettingsDescription;
	
EndFunction

// Report settings details constructor.
//
// Returns:
//   Structure - Report settings details, where::
//       * ReportName - String - Full name of the report metadata object.
//       * Settings - DataCompositionSettings
//                   - DataCompositionUserSettings
//                   - Undefined - Passed settings.
//       * VariantKey - String - Report option ID.
//       * VariantPresentation - String - Report option presentation.
//       * CurrentUserSettingsKey - String - Current user settings ID.
//       * CurrentUserSettingsPresentation - String - Presentation of the current user settings.
//       * UserSettings - ValueList - List of user settings, where::
//             * Value - String - User settings key.
//             * Presentation - String - User settings presentation.
//       * UserSettingsStorage - Map of KeyAndValue - List of user settings, where::
//             * Key - String - User settings key.
//             * Value - DataCompositionUserSettings - User settings key.
//
Function ReportOptionSettingsDetails()
	
	SettingsDescription = New Structure;
	
	SettingsDescription.Insert("ReportName", "");
	SettingsDescription.Insert("Settings", Undefined);
	SettingsDescription.Insert("VariantKey", "");
	SettingsDescription.Insert("VariantPresentation", "");
	SettingsDescription.Insert("CurrentUserSettingsKey", "");
	SettingsDescription.Insert("CurrentUserSettingsPresentation", "");
	SettingsDescription.Insert("UserSettings", New ValueList);
	SettingsDescription.Insert("UserSettingsStorage", New Map);
	SettingsDescription.Insert("ErrorDescription", "");
	
	Return SettingsDescription;
	
EndFunction

Function DeserializedSettings(FileName)
	
	XMLReader = New XMLReader;
	
	Try
		XMLReader.OpenFile(FileName);
	Except
		FileNameDetails = StrSplit(FileName, GetPathSeparator());
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid settings format: the %1 file is missing.';"),
			FileNameDetails[FileNameDetails.UBound()]);
	EndTry;
	
	Return XDTOSerializer.ReadXML(XMLReader);
	
EndFunction

// Parameters:
//  ReportOptionDetails - Structure:
//    * ErrorDescription - String
//    * UserSettingsStorage - Map
//    * UserSettings - ValueList
//    * CurrentUserSettingsPresentation - String
//    * CurrentUserSettingsKey - String
//    * VariantPresentation - String
//    * VariantKey - String
//    * Settings - Undefined
//    * ReportName - String
//   ReportOptionBase - CatalogRef.ReportsOptions
//
// Returns:
//  CatalogRef.ReportsOptions
//
Function UpdateReportOptionByDetails(Val ReportOptionDetails, Val ReportOptionBase = Undefined)
	
	If Not ReportsOptionsCached.InsertRight1() Then 
		Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
	EndIf;
	
	ReportInformation = ReportInformation(ReportOptionDetails.ReportName, True);
	Author = Users.AuthorizedUser();
	
	BeginTransaction();
	
	Try
		Block = New DataLock;
		Block.Add(Metadata.Catalogs.ReportsOptions.FullName());
		Block.Lock();
		
		ReportVariant = UserReportOption(ReportInformation.Report, ReportOptionDetails.VariantKey, Author);
		If ValueIsFilled(ReportVariant.Ref) Then 
			
			Object = ReportVariant.Ref.GetObject();
			Object.Settings = New ValueStorage(ReportOptionDetails.Settings);
			OptionUsers = New ValueList;
			InformationRegisters.ReportOptionsSettings.ReadReportOptionAvailabilitySettings(
				Object.Ref, OptionUsers);
			
			If OptionUsers.FindByValue(Author) = Undefined Then 
				OptionUsers.Add(Author);
			EndIf;
			
			Object.AdditionalProperties.Insert("OptionUsers", OptionUsers);
			
		Else
			
			Description = AvailableReportOptionDescription(
				ReportInformation.Report, ReportOptionDetails.VariantPresentation);
			
			If ReportVariant.OptionKeyIsUsed Then 
				ReportOptionDetails.VariantKey = String(New UUID());
			EndIf;
			
			If ReportOptionBase = Undefined Then
				ReportOptionBase = ReportVariant(ReportInformation.Report, ReportOptionDetails.VariantKey);
			EndIf;
			
			FillingData = New Structure;
			FillingData.Insert("Report", ReportInformation.Report);
			FillingData.Insert("VariantKey", ReportOptionDetails.VariantKey);
			FillingData.Insert("Settings", ReportOptionDetails.Settings);
			FillingData.Insert("Description", Description);
			FillingData.Insert("Author", Author);
			FillingData.Insert("Basis", ReportOptionBase);
			
			Object = Catalogs.ReportsOptions.CreateItem();
			Object.Fill(FillingData);
			
		EndIf;
		
		Object.Write();
		SaveUserSettingsFromFile(Object.Ref, ReportOptionDetails);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Object.Ref;
	
EndFunction

Procedure SaveUserSettingsFromFile(ReportVariant, ReportOptionDetails)
	
	If ReportOptionDetails.UserSettings.Count() = 0 Then 
		Return;
	EndIf;
	
	SettingsDetailsTemplate = New Structure("ObjectKey, SettingsKey, Presentation, User");
	SettingsDetailsTemplate.ObjectKey = ReportOptionDetails.ReportName + "/" + ReportOptionDetails.VariantKey;
	SettingsDetailsTemplate.User = UserName();
	
	For Each ListItem In ReportOptionDetails.UserSettings Do 
		
		SettingsDescription = New SettingsDescription;
		FillPropertyValues(SettingsDescription, SettingsDetailsTemplate);
		SettingsDescription.SettingsKey = ListItem.Value;
		SettingsDescription.Presentation = ListItem.Presentation;
		
		Settings = ReportOptionDetails.UserSettingsStorage[SettingsDescription.SettingsKey];
		
		ReportsUserSettingsStorage.Save(
			SettingsDescription.ObjectKey,
			SettingsDescription.SettingsKey,
			Settings,
			SettingsDescription,
			SettingsDescription.User);
		
	EndDo;
	
	If Not ValueIsFilled(ReportOptionDetails.CurrentUserSettingsKey) Then 
		Return;
	EndIf;
	
	SettingsDescription = New SettingsDescription;
	FillPropertyValues(SettingsDescription, SettingsDetailsTemplate);
	SettingsDescription.ObjectKey = SettingsDescription.ObjectKey + "/CurrentUserSettings";
	SettingsDescription.SettingsKey = ReportOptionDetails.CurrentUserSettingsKey;
	SettingsDescription.Presentation = ReportOptionDetails.CurrentUserSettingsPresentation;
	
	Settings = ReportOptionDetails.UserSettingsStorage[SettingsDescription.SettingsKey];
	
	Common.SystemSettingsStorageSave(
		SettingsDescription.ObjectKey,
		SettingsDescription.SettingsKey,
		Settings,
		SettingsDescription,
		SettingsDescription.User);
	
EndProcedure

Function UserReportOption(Report, VariantKey, Author)
	
	ReportVariant = New Structure("Ref, OptionKeyIsUsed");
	
#Region UserReportOptionQuery
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	Reports.Ref,
	|	Reports.DeletionMark
	|FROM
	|	Catalog.ReportsOptions AS Reports
	|WHERE
	|	VALUETYPE(&Report) <> TYPE(Catalog.ExtensionObjectIDs)
	|	AND Reports.Report = &Report
	|	AND Reports.VariantKey = &VariantKey
	|	AND Reports.Author = &Author
	|	AND Reports.Custom
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	Reports.Ref,
	|	Reports.DeletionMark
	|FROM
	|	Catalog.ReportsOptions AS Reports
	|	LEFT JOIN InformationRegister.PredefinedExtensionsVersionsReportsOptions AS ExtensionReports
	|		ON ExtensionReports.Variant = Reports.PredefinedOption
	|		AND ExtensionReports.Report = Reports.Report
	|		AND ExtensionReports.VariantKey = Reports.VariantKey
	|WHERE
	|	VALUETYPE(&Report) = TYPE(Catalog.ExtensionObjectIDs)
	|	AND Reports.Report = &Report
	|	AND Reports.VariantKey = &VariantKey
	|	AND Reports.Author = &Author
	|	AND Reports.Custom
	|	AND ExtensionReports.ExtensionsVersion = &ExtensionsVersion
	|
	|ORDER BY
	|	Reports.DeletionMark DESC
	|;
	|
	|SELECT
	|	TRUE IN (
	|		SELECT TOP 1
	|			TRUE
	|		FROM
	|			Catalog.ReportsOptions AS ReportsIdentical
	|		WHERE
	|			ReportsIdentical.Report = &Report
	|			AND ReportsIdentical.VariantKey = &VariantKey
	|	) AS OptionKeyIsUsed");
	
	Query.SetParameter("Report", Report);
	Query.SetParameter("VariantKey", VariantKey);
	Query.SetParameter("Author", Author);
	Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
	
	QueryResults = Query.ExecuteBatch(); // Array of QueryResult
	
#EndRegion
	
	For Each Result In QueryResults Do 
		
		Selection = Result.Select(); // QueryResultSelection
		Selection.Next();
		
		FillPropertyValues(ReportVariant, Selection);
		
	EndDo;
	
	Return ReportVariant;
	
EndFunction

Function AvailableReportOptionDescription(Report, Val Description)
	
	Query = New Query(
	"SELECT ALLOWED
	|	ReportsOptions.Description
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.Description LIKE &DescriptionTemplate ESCAPE ""~""");
	
	Query.SetParameter("Report", Report);
	Query.SetParameter("DescriptionTemplate", 
		Common.GenerateSearchQueryString(Description) + "%");
	
	Result = Query.Execute();	
	If Result.IsEmpty() Then 
		Return Description;
	EndIf;
	
	DescriptionsOccupied = Result.Select();	
	If Not DescriptionsOccupied.FindNext(Description, "Description") Then 
		Return Description;
	EndIf;
	
	DescriptionsOccupied.Reset();
	
	CopiesCounterTemplate = " (%1)";
	DescriptionTemplate = ReportOptionDescriptionTemplate(DescriptionsOccupied, Description, CopiesCounterTemplate);
	
	If Not StrEndsWith(DescriptionTemplate, CopiesCounterTemplate) Then 
		Return DescriptionTemplate;
	EndIf;
	
	MaxCopiesCount = DescriptionsOccupied.Count();	
	For CopyNumber = 1 To MaxCopiesCount Do 
		Description = StringFunctionsClientServer.SubstituteParametersToString(DescriptionTemplate, CopyNumber);
		
		If Not DescriptionsOccupied.FindNext(Description, "Description") Then 
			Return Description;
		EndIf;
		
		DescriptionsOccupied.Reset();
	EndDo;
	
	Return Description;
	
EndFunction

Function ReportOptionDescriptionTemplate(DescriptionsOccupied, Val Description, CopiesCounterTemplate)
	
	CopyFlag = " - " + NStr("en = 'copy';");
	
	If StrEndsWith(Description, CopyFlag) Then 
		Return Description + CopiesCounterTemplate;
	EndIf;
	
	CopyFlagPosition = StrFind(Description, CopyFlag);
	
	If CopyFlagPosition > 0 Then 
		Return Mid(Description, 1, CopyFlagPosition - 1) + CopiesCounterTemplate;
	EndIf;
	
	Description = Description + CopyFlag;
	
	If Not DescriptionsOccupied.FindNext(Description, "Description") Then 
		Return Description;
	EndIf;
	
	DescriptionsOccupied.Reset();
	
	Return Description + CopiesCounterTemplate;
	
EndFunction

Procedure DeleteReportOptionDetailsFiles(DirectoryName, ArchiveFileName)
	
	FileSystem.DeleteTemporaryDirectory(DirectoryName);
	FileSystem.DeleteTempFile(ArchiveFileName);
	
EndProcedure

#EndRegion

#Region ExchangeUserSettingsWithinInfobase

// Parameters:
//   SelectedUsers - ValueList:
//     * Value - CatalogRef.Users
//                - CatalogRef.UserGroups
//                - CatalogRef.ExternalUsersGroups
//  SettingsDetailsTemplate - Structure - Opening parameters of the choice form for selecting users or user groups, where::
//      * Settings - DataCompositionUserSettings - Settings that are exchanged.
//      * ReportVariant - CatalogRef.ReportsOptions - Reference to a report option property storage.
//      * ObjectKey - String - Settings storage dimension.
//      * SettingsKey - String - Dimension - User settings ID.
//      * Presentation - String - User settings description.
//      * VariantModified - Boolean - Flag indicating whether a report option was modified.
//
Procedure ShareUserSettings(SelectedUsers, SettingsDetailsTemplate) Export 
	
	SetPrivilegedMode(True);
	
	CurrentUser = Users.AuthorizedUser();
	UsersProperties = SettingsUsersProperties(SelectedUsers, CurrentUser);
	
	If UsersProperties.Valid2.Count() = 0 Then 
		
		SettingsDetailsTemplate.Insert("Warning", NStr("en = 'The selected users are inactive.';"));
		Return;
		
	EndIf;
	
	If UsersProperties.Invalid1.Count() > 0 Then 
		
		NoteTemplate = NStr("en = 'Some of the selected users are inactive: %1.';");
		
		Explanation = StringFunctionsClientServer.SubstituteParametersToString(
			NoteTemplate, StrConcat(UsersProperties.Invalid1, ", "));
		
		SettingsDetailsTemplate.Insert("Explanation", Explanation);
		
	EndIf;
	
	CheckReportOptionAvailability(SettingsDetailsTemplate.ReportVariant, SelectedUsers);
	
	NormalizeSettingsDetailsTemplate(SettingsDetailsTemplate, CurrentUser);
	
	UsersList = New Array;
	For Each UserProperties In UsersProperties.Valid2 Do 
		SettingsDescription = New SettingsDescription;
		FillPropertyValues(SettingsDescription, SettingsDetailsTemplate);
		SettingsDescription.User = UserProperties.Name;
		
		ReportsUserSettingsStorage.Save(
			SettingsDescription.ObjectKey,
			SettingsDescription.SettingsKey,
			SettingsDetailsTemplate.Settings,
			SettingsDescription,
			SettingsDescription.User);
		
		UsersList.Add(UserProperties.Ref); 
	EndDo;
	
	UsersSettings = UserReportOptionSettings(
		SettingsDetailsTemplate.ReportVariant, UsersList, SettingsDetailsTemplate.SettingsKey);
	
	For Each User In UsersList Do
		UserSettings = UsersSettings.FindRows(New Structure("User", User));
		UpdateInternalUserSettingsInformation(User, SettingsDetailsTemplate, UserSettings);
	EndDo;

	NotifyReportSettingsUsers(UsersProperties.Valid2, SettingsDetailsTemplate);
	
EndProcedure

// Parameters:
//  SelectedUsers - ValueList:
//    * Value - CatalogRef.Users
//               - CatalogRef.UserGroups
//               - CatalogRef.ExternalUsersGroups
//  CurrentUser - CatalogRef.ExternalUsers
//                      - CatalogRef.Users
//
// Returns:
//  Structure:
//    * Invalid1 - Array of Structure
//    * Valid2 - Array of Structure
//
Function SettingsUsersProperties(SelectedUsers, CurrentUser)
	
	UsersProperties = New Structure();
	UsersProperties.Insert("Valid2", New Array);
	UsersProperties.Insert("Invalid1", New Array);
	
#Region UsersQuery
	
	UseUserGroups = GetFunctionalOption("UseUserGroups");
	
	// ACC:96 -off The result must contain unique values.
	
	Query = New Query(
	"SELECT ALLOWED
	|	Users.Ref,
	|	Users.Presentation,
	|	Users.IBUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.Ref IN (&SelectedUsers)
	|	AND Users.Ref <> &CurrentUser
	|	AND NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.IsInternal
	|
	|UNION
	|
	|SELECT
	|	Users.Ref,
	|	Users.Presentation,
	|	Users.IBUserID
	|FROM
	|	Catalog.UserGroups.Content AS UserGroupCompositions
	|	LEFT JOIN Catalog.Users AS Users
	|		ON Users.Ref = UserGroupCompositions.User
	|WHERE
	|	&UseUserGroups
	|	AND UserGroupCompositions.Ref IN (&SelectedUsers)
	|	AND Users.Ref <> &CurrentUser
	|	AND NOT Users.DeletionMark
	|	AND NOT Users.Invalid
	|	AND NOT Users.IsInternal");
	
	// ACC:96-on
	
	Query.SetParameter("SelectedUsers", SelectedUsers);
	Query.SetParameter("CurrentUser", CurrentUser);
	Query.SetParameter("UseUserGroups", UseUserGroups);
	
	Selection = Query.Execute().Select();
	
#EndRegion
	
	While Selection.Next() Do 
		
		IBUser = InfoBaseUsers.FindByUUID(
			Selection.IBUserID);
		
		If IBUser = Undefined Then 
			
			UsersProperties.Invalid1.Add(Selection.Presentation);
			Continue;
			
		EndIf;
		
		UserProperties = UserProperties(Selection.Ref, IBUser.Name, Selection.IBUserID);
		UsersProperties.Valid2.Add(UserProperties);
		
	EndDo;
	
	Return UsersProperties;
	
EndFunction

// Parameters:
//  Ref - CatalogRef.Users
//         - CatalogRef.ExternalUsers
//  IBUserName - String
//  IBUserID - UUID
//
// Returns:
//  Structure:
//    * Ref - CatalogRef.Users
//             - CatalogRef.ExternalUsers
//    * Name - String
//    * IBUserID - UUID
//
Function UserProperties(Ref, IBUserName, IBUserID)
	
	UserProperties = New Structure;
	UserProperties.Insert("Ref", Ref);
	UserProperties.Insert("Name", IBUserName);
	UserProperties.Insert("IBUserID", IBUserID);
	
	Return UserProperties;
	
EndFunction

Procedure CheckReportOptionAvailability(ReportVariant, SelectedUsers)
	
	SelectionWithUsers = InformationRegisters.ReportOptionsSettings.ReportOptionUsers(
		ReportVariant, SelectedUsers);
	
	While SelectionWithUsers.Next() Do 
		
		FoundUser = SelectedUsers.Find(SelectionWithUsers.Ref);
		If FoundUser <> Undefined Then 
			SelectedUsers.Delete(FoundUser);
		EndIf;
		
	EndDo;
	
	If SelectedUsers.Count() = 0
	 Or Not FullRightsToOptions() Then
		Return;
	EndIf;
	
	EnableBusinessLogic = Not InfobaseUpdate.InfobaseUpdateInProgress();
	
	RecordSet = InformationRegisters.ReportOptionsSettings.CreateRecordSet();
	Subsystem = Catalogs.MetadataObjectIDs.EmptyRef();
	
	RecordSet.Filter.Variant.Set(ReportVariant);
	RecordSet.Filter.Subsystem.Set(Subsystem);
	
	For Each User In SelectedUsers Do 
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ReportOptionsSettings");
		LockItem.SetValue("Variant", ReportVariant);
		LockItem.SetValue("User", User);
		LockItem.SetValue("Subsystem", Subsystem);
		
		RecordSet.Filter.User.Set(User);
		
		BeginTransaction();
		Try
			Block.Lock();
			RecordSet.Read();
			
			If RecordSet.Count() = 0 Then
				Record = RecordSet.Add();
				Record.Variant = ReportVariant;
				Record.User = User;
				Record.Subsystem = Subsystem;
			Else
				Record = RecordSet[0];
			EndIf;
			
			If Not Record.Visible Then
				Record.Visible = True;
				InfobaseUpdate.WriteRecordSet(RecordSet, , , EnableBusinessLogic);	
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndDo;
	
	
EndProcedure

Procedure NormalizeSettingsDetailsTemplate(SettingsDetailsTemplate, CurrentUser)
	
	SetUserSettingsPresentation(SettingsDetailsTemplate, CurrentUser);
	
	If ValueIsFilled(SettingsDetailsTemplate.SettingsKey) Then 
		Return;
	EndIf;
	
	SettingsDetailsTemplate.SettingsKey = String(New UUID());
	
	If SettingsDetailsTemplate.VariantModified Then 
		Return;
	EndIf;
	
	Common.SystemSettingsStorageSave(
		SettingsDetailsTemplate.ObjectKey + "/CurrentUserSettings",
		"",
		SettingsDetailsTemplate.Settings);
	
EndProcedure

Procedure SetUserSettingsPresentation(SettingsDetailsTemplate, CurrentUser)
	
	UserSettings = UserReportOptionSettings(
		SettingsDetailsTemplate.ReportVariant, CurrentUser, SettingsDetailsTemplate.SettingsKey);
	
	If UserSettings <> Undefined
		And UserSettings.Count() > 0 Then 
		
		SettingDetails = UserSettings[0]; // See UserReportOptionSettings
		SettingsDetailsTemplate.Presentation = SettingDetails.Description;
		
		Return;
		
	EndIf;
	
	TemplateOfPresentation = NStr("en = '%1''s settings';");
	UserPresentation2 = Common.ObjectAttributeValue(CurrentUser, "Presentation");
	
	If Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		ModuleObjectsPresentationsDeclension = Common.CommonModule("ObjectPresentationDeclension");
		
		UserPresentation2 = ModuleObjectsPresentationsDeclension.DeclinePresentation(
			UserPresentation2, 2, CurrentUser);
	EndIf;
	
	SettingsDetailsTemplate.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		TemplateOfPresentation, UserPresentation2);
	
EndProcedure

Procedure UpdateInternalUserSettingsInformation(User, SettingsDescription, Settings)
	
	If Not ValueIsFilled(Settings) Then 
		
		Object = Catalogs.UserReportSettings.CreateItem();
		Object.Description = SettingsDescription.Presentation;
		Object.UserSettingKey = SettingsDescription.SettingsKey;
		Object.Variant = SettingsDescription.ReportVariant;
		Object.User = User;
		Object.Write(); // ACC:1327
		Return;
		
	EndIf;
	
	Item = Settings[0];
	
	If Not Item.DeletionMark
		And Item.Description = SettingsDescription.Presentation Then
		
		Return;
	EndIf;
	
	Object = Item.Ref.GetObject(); // CatalogObject.
	Object.Description = SettingsDescription.Presentation;
	Object.DeletionMark = False;
	Object.Write(); // ACC:1327
	
EndProcedure

Procedure NotifyReportSettingsUsers(UsersProperties, SettingsDescription)
	
#Region Validation
	
	If Not Common.SubsystemExists("StandardSubsystems.Conversations") Then
		Return;
	EndIf;
	
	ModuleConversationsInternal = Common.CommonModule("ConversationsInternal");
	ModuleConversations = Common.CommonModule("Conversations");
	
	If Not ModuleConversationsInternal.Connected2() Then 
		Return;
	EndIf;
	
#EndRegion
	
#Region DefineMessageRecipients
	
	Recipients = New Array;
	
	For Each UserProperties In UsersProperties Do 
		Recipients.Add(UserProperties.Ref);
	EndDo;
	
	If Recipients.Count() = 0 Then 
		Return;
	EndIf;
	
#EndRegion
	
#Region NewSettingsUsersNotificationGeneration
	
	If ValueIsFilled(SettingsDescription.Presentation) Then 
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The report settings are available: ""%1.""';"), SettingsDescription.Presentation);
	Else
		Text = NStr("en = 'The report settings are available.';");
	EndIf;
	
	Message = ModuleConversations.MessageDetails(Text);
	Message.Data = SettingsDescription;
	Message.Actions.Add(
		ReportsOptionsClientServer.ApplyPassedSettingsActionName(),
		NStr("en = 'Do you want to apply the settings?';"));
		
	Try
		ModuleConversations.SendMessage(
			Users.CurrentUser(),
			Recipients,
			Message,
			SettingsDescription.ReportVariant);
	Except
		
		DefaultLanguageCode = Common.DefaultLanguageCode();
		ReportOptionPresentation = String(SettingsDescription.ReportVariant);
		
		WriteLogEvent(
			NStr("en = 'Report options.Report settings availability notification';", DefaultLanguageCode),
			EventLogLevel.Error,,
			ReportOptionPresentation,
			ErrorProcessing.DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
#EndRegion
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Constructors.

#Region Constructors

// The constructor of a collection of predefined report options.
//
// Returns:
//   See ReportsOptionsOverridable.CustomizeReportsOptions.Settings.
//
Function PredefinedReportsOptionsCollection()
	
	CatalogAttributes = Metadata.Catalogs.ReportsOptions.Attributes;
	
	FlagDetails = New TypeDescription("Boolean");
	ArrayDetails = New TypeDescription("Array");
	MapDetails = New TypeDescription("Map");
	StructureDetails = New TypeDescription("Structure");
	MetadataObjectDetails = New TypeDescription("MetadataObject");
	ReportOptionDetails = New TypeDescription(
		"CatalogRef.PredefinedReportsOptions, 
		|CatalogRef.PredefinedExtensionsReportsOptions");
	
	Result = New ValueTable;
	
	Result.Columns.Add("Report", CatalogAttributes.Report.Type);
	Result.Columns.Add("ReportFullName", TypesDetailsString());
	Result.Columns.Add("Metadata", MetadataObjectDetails);
	Result.Columns.Add("UsesDCS", FlagDetails);
	Result.Columns.Add("VariantKey", CatalogAttributes.VariantKey.Type);
	Result.Columns.Add("DetailsReceived", FlagDetails);
	Result.Columns.Add("Enabled", FlagDetails);
	Result.Columns.Add("DefaultVisibility", FlagDetails);
	Result.Columns.Add("ShouldShowInOptionsSubmenu", FlagDetails);
	Result.Columns.Add("Description", TypesDetailsString());
	Result.Columns.Add("LongDesc", TypesDetailsString());
	Result.Columns.Add("Location", MapDetails);
	Result.Columns.Add("SearchSettings", StructureDetails);
	Result.Columns.Add("SystemInfo", StructureDetails);
	Result.Columns.Add("Type", TypesDetailsString());
	Result.Columns.Add("IsOption", FlagDetails);
	Result.Columns.Add("FunctionalOptions", ArrayDetails);
	Result.Columns.Add("GroupByReport", FlagDetails);
	Result.Columns.Add("MeasurementsKey", TypesDetailsString());
	Result.Columns.Add("MainOption", CatalogAttributes.VariantKey.Type);
	Result.Columns.Add("DCSSettingsFormat", FlagDetails);
	Result.Columns.Add("DefineFormSettings", FlagDetails);
	Result.Columns.Add("Purpose", New TypeDescription("EnumRef.ReportOptionPurposes"));
	
	// Auxiliary information records for the UpdateSettingsOfPredefinedItems procedure.
	Result.Columns.Add("FoundInDatabase", FlagDetails);
	Result.Columns.Add("OptionFromBase"); // Selection row from the table
	Result.Columns.Add("ParentOption", ReportOptionDetails);
	
	Result.Indexes.Add("Report");
	Result.Indexes.Add("Report, IsOption");
	Result.Indexes.Add("Report, VariantKey");
	Result.Indexes.Add("Report, VariantKey, IsOption");
	Result.Indexes.Add("VariantKey");
	Result.Indexes.Add("Metadata, VariantKey");
	Result.Indexes.Add("Metadata, IsOption");
	
	Return Result;
	
EndFunction

// Returns details of a specified report by default.
//
// Parameters:
//  ReportsDetails - See PredefinedReportsOptionsCollection
//  MetadataOfReport - MetadataObjectReport
//  RefOfReport - CatalogRef.MetadataObjectIDs
//               - CatalogRef.ExtensionObjectIDs
//  ReportType - See ReportByStringType
//  GroupByReports - See GlobalSettings
//
// Returns:
//   ValueTableRow - See PredefinedReportsOptionsCollection
//
Function DefaultReportDetails(ReportsDetails, MetadataOfReport, RefOfReport,
	ReportType = Undefined, GroupByReports = Undefined)
	
	If ReportType = Undefined Then 
		ReportType = ReportByStringType(RefOfReport);
	EndIf;
	
	If GroupByReports = Undefined Then 
		GroupByReports = GlobalSettings().OutputReportsInsteadOfOptions;
	EndIf;
	
	UsesDCS = (MetadataOfReport.MainDataCompositionSchema <> Undefined);
	DCSSettingsFormat = (UsesDCS And MetadataOfReport.Attributes.Count() = 0);
	SearchSettings = New Structure("FieldDescriptions, FilterParameterDescriptions, Keywords, TemplatesNames");
	
	DescriptionOfReport = ReportsDetails.Add();
	DescriptionOfReport.Report = RefOfReport;
	DescriptionOfReport.Metadata = MetadataOfReport;
	DescriptionOfReport.Enabled = True;
	DescriptionOfReport.DefaultVisibility = True;
	DescriptionOfReport.LongDesc = MetadataOfReport.Explanation;
	DescriptionOfReport.Description = MetadataOfReport.Presentation();
	DescriptionOfReport.DetailsReceived = True;
	DescriptionOfReport.Type = ReportType;
	DescriptionOfReport.GroupByReport = GroupByReports;
	DescriptionOfReport.UsesDCS = UsesDCS;
	DescriptionOfReport.DCSSettingsFormat = DCSSettingsFormat;
	DescriptionOfReport.SearchSettings = SearchSettings;
	DescriptionOfReport.Purpose = ReportsOptionsInternal.AssigningDefaultReportOption();
	DescriptionOfReport.ReportFullName = MetadataOfReport.FullName();
	
	Return DescriptionOfReport;

EndFunction

// Returns an array with one element, which is details of the report specified by default.
//
// Parameters:
//  Report - MetadataObjectReport
//        - CatalogRef.MetadataObjectIDs - Report reference or metadata.
//
// Returns:
//   Array of See PredefinedReportsOptionsCollection
//
Function FoundReportDetails(Report)
	
	FoundReportDetails = New Array;
	
	If TypeOf(Report) = Type("MetadataObject") Then
		
		RefOfReport = Common.MetadataObjectID(Report);
		MetadataOfReport = Report;
	Else
		RefOfReport = Report;
		MetadataOfReport = Common.MetadataObjectByID(Report);
	EndIf;
	
	If Not ReportAttachedToStorage(MetadataOfReport) Then
		Return FoundReportDetails;
	EndIf;
	
	ReportsDetails = PredefinedReportsOptionsCollection();
	DescriptionOfReport = DefaultReportDetails(ReportsDetails, MetadataOfReport, RefOfReport);
	FoundReportDetails.Add(DescriptionOfReport);
	
	Return FoundReportDetails;
	
EndFunction

// The constructor of the report option update result.
//
// Returns:
//   Structure - Collection of properties of the report option update result, where::
//       * HasChanges - Boolean - Flag indicating whether report options have changes.
//       * HasImportantChanges - Boolean - Flag indicating whether report options have important changes.
//       * EmptyRef - CatalogRef.ReportsOptions - Reference to an empty report option.
//       * ProcessedPredefinedItems - Map - Index of processed report options.
//       * MainOptions - See MainReportsOptionsCollection
//
Function ReportsOptionsUpdateResult()
	
	Result = New Structure();
	
	Result.Insert("HasChanges", False);
	Result.Insert("HasImportantChanges", False);
	Result.Insert("EmptyRef", Catalogs.ReportsOptions.EmptyRef());
	Result.Insert("SearchForParents", New Map);
	Result.Insert("ProcessedPredefinedItems", New Map);
	Result.Insert("MainOptions", MainReportsOptionsCollection());
	
	Return Result;
	
EndFunction

// The constructor of a collection of main report options.
//
// Returns:
//   ValueTable - Collection of the main report options, where::
//       * Report - CatalogRef.ExtensionObjectIDs
//               - CatalogRef.AdditionalReportsAndDataProcessors
//               - CatalogRef.MetadataObjectIDs
//               - String - Reference to a report metadata ID.
//       * Variant - CatalogRef.ReportsOptions - Report option reference.
//
Function MainReportsOptionsCollection()
	
	MainReportsOptions = New ValueTable();
	
	MainReportsOptions.Columns.Add("Report", Metadata.Catalogs.ReportsOptions.Attributes.Report.Type);
	MainReportsOptions.Columns.Add("Variant", New TypeDescription("CatalogRef.ReportsOptions"));
	
	Return MainReportsOptions;
	
EndFunction

// The constructor of updating shared data.
//
// Parameters:
//  Mode - String - Data update kind.
//  SeparatedHandlers - Structure
//
// Returns:
//   Structure - Properties of the shared data update result, where::
//       * UpdateConfiguration1 - Boolean - Flag indicating whether configuration data must be updated.
//       * UpdateExtensions - Boolean - Flag indicating whether extension data must be updated.
//       * SeparatedHandlers - Structure
//       * HasChanges - Boolean - Flag indicating whether report options have changes.
//       * HasImportantChanges - Boolean - Flag indicating whether report options have important changes.
//       * ReportsOptions - ValueTable
//       * UpdateMeasurements - Boolean - Flag indicating whether the PerformanceMonitor subsystem exists.
//       * MeasurementsTable - See MeasurementsTable
//       * SaaSModel - Boolean - Flag indicating SaaS operations.
//
Function CommonDataUpdateResult(Val Mode, Val SeparatedHandlers)
	
	Result = New Structure();
	
	Result.Insert("UpdateConfiguration1", Mode = "ConfigurationCommonData");
	Result.Insert("UpdateExtensions", Mode = "ExtensionsCommonData");
	Result.Insert("SeparatedHandlers", SeparatedHandlers);
	Result.Insert("HasChanges", False);
	Result.Insert("HasImportantChanges", False);
	Result.Insert("ReportsOptions", PredefinedReportsOptions(?(Result.UpdateConfiguration1, "BuiltIn", "Extension")));
	Result.Insert("UpdateMeasurements", Common.SubsystemExists("StandardSubsystems.PerformanceMonitor"));
	Result.Insert("MeasurementsTable", MeasurementsTable());
	Result.Insert("SaaSModel", Common.DataSeparationEnabled());
	
	Return Result;
	
EndFunction

// Measurement table constructor.
//
// Returns:
//   ValueTable:
//       * OldName - String - Outdated measurement key.
//       * UpdatedName - String - Current measurement key.
//       * UpdatedDescription - String - Current description of a report.
//
Function MeasurementsTable()
	
	Result = New ValueTable;
	
	Result.Columns.Add("OldName", TypesDetailsString(150));
	Result.Columns.Add("UpdatedName", TypesDetailsString(150));
	Result.Columns.Add("UpdatedDescription", TypesDetailsString(150));
	
	Return Result;
	
EndFunction

// Constructor of the structure containing the result of available report option search.
// 
// Returns:
//  Structure:
//    * CurrentSectionOnly - Boolean
//    * SubsystemsTable - ValueTable:
//        ** Ref - CatalogRef.MetadataObjectIDs
//                  - CatalogRef.ExtensionObjectIDs
//        ** Presentation - String
//        ** Name - String
//        ** FullName - String
//        ** Priority - String
//        ** ItemNumber - Number
//        ** TagName - String
//        ** ParentReference - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//        ** SectionReference - CatalogRef.MetadataObjectIDs
//                        - CatalogRef.ExtensionObjectIDs
//        ** VisibleOptionsCount - Number
//    * OtherSections - Array
//    * Variants - ValueTable:
//        ** Ref - CatalogRef.ReportsOptions
//        ** Subsystem - CatalogRef.MetadataObjectIDs
//                      - CatalogRef.ExtensionObjectIDs
//        ** SubsystemPresentation - String
//        ** SubsystemPriority - String
//        ** SectionReference - CatalogRef.MetadataObjectIDs
//                        - CatalogRef.ExtensionObjectIDs
//        ** NoGroup - Boolean
//        ** Important - Boolean
//        ** SeeAlso - Boolean
//        ** Additional - Boolean
//        ** Visible - Boolean
//        ** QuickAccess - Boolean
//        ** ReportName - String
//        ** Description - String
//        ** LongDesc - String
//        ** Author - CatalogRef.Users
//                 - CatalogRef.ExternalUsers
//        ** Report - CatalogRef.MetadataObjectIDs
//                 - CatalogRef.ExtensionObjectIDs
//                 - CatalogRef.AdditionalReportsAndDataProcessors
//                 - String
//        ** ReportType - EnumRef.ReportsTypes
//        ** VariantKey - String
//        ** Parent - CatalogRef.ReportsOptions
//        ** TopLevel - Boolean
//        ** MeasurementsKey - String
//    * SectionOptions - 
//    * UseHighlighting - Boolean
//    * SearchResult - See FindReportsOptions
//    * WordArray - Array
//    * GroupName - String
//    * AttributesToBeAdded - Array of FormAttribute
//    * EmptyDecorationsAdded - Number
//    * OutputLimit - Number
//    * RemainsToOutput - Number
//    * NotDisplayed - Number
//    * OptionItemsDisplayed - Number
//    * SearchForOptions - Map
//    * Templates - Structure:
//        ** VariantGroup - Structure:
//             *** Kind - FormGroupType
//             *** HorizontalStretch - Boolean
//             *** Representation - UsualGroupRepresentation
//             *** Group - ChildFormItemsGroup
//             *** ShowTitle - Boolean
//        ** QuickAccessPicture - Structure:
//             *** Kind - FormDecorationType
//             *** Width - Number
//             *** Height - Number
//             *** Picture - Picture
//             *** HorizontalStretch - Boolean
//             *** VerticalStretch - Boolean
//        ** IndentPicture1 - Structure:
//             *** Kind - FormDecorationType
//             *** Width - Number
//             *** Height - Number
//             *** HorizontalStretch - Boolean
//             *** VerticalStretch - Boolean
//        ** OptionLabel - Structure:
//             *** Kind - FormDecorationType
//             *** Hyperlink - Boolean
//             *** TextColor - Color
//             *** VerticalStretch - Boolean
//             *** Height - Number
//             *** HorizontalStretch - Boolean
//             *** AutoMaxWidth - Boolean
//             *** MaxWidth - Number
//    * ContextMenu - Structure:
//        ** RemoveFromQuickAccess - Structure:
//             *** Visible - Boolean
//        ** MoveToQuickAccess - Structure:
//             *** Visible - Boolean
//        ** Change - Structure:
//             *** Visible - Boolean
//    * ImportanceGroups - Array of String
//    * QuickAccess - Structure:
//        ** Filter - Structure:
//             *** QuickAccess - Boolean
//        ** Variants - Array of ValueTableRow
//        ** Count - Number
//    * NoGroup - Structure:
//        ** Filter - Structure:
//             *** QuickAccess - Boolean
//             *** NoGroup - Boolean
//        ** Variants - Array of ValueTableRow
//        ** Count - Number
//    * WithGroup - Structure:
//        ** Filter - Structure:
//             *** QuickAccess - Boolean
//             *** NoGroup - Boolean
//             *** SeeAlso - Boolean
//        ** Variants - Array of ValueTableRow
//        ** Count - Number
//    * SeeAlso - Structure:
//        ** Filter - Structure:
//             *** QuickAccess - Boolean
//             *** NoGroup - Boolean
//             *** SeeAlso - Boolean
//        ** Variants - Array of ValueTableRow
//        ** Count - Number
//    * CurrentSectionOptionsDisplayed - Boolean
//    * OptionsNumber - Number
//    * SectionSubsystems - ValueTable:
//        ** Ref - CatalogRef.MetadataObjectIDs
//                  - CatalogRef.ExtensionObjectIDs
//        ** Presentation - String
//        ** Name - String
//        ** FullName - String
//        ** Priority - String
//        ** ItemNumber - Number
//        ** TagName - String
//        ** ParentReference - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//        ** SectionReference - CatalogRef.MetadataObjectIDs
//                        - CatalogRef.ExtensionObjectIDs
//        ** VisibleOptionsCount - Number
//
Function ReportOptionsToShow() Export
	
	Result = New Structure;
	Result.Insert("CurrentSectionOnly", False);
	Result.Insert("SubsystemsTable", Undefined);
	Result.Insert("OtherSections", New Array);
	Result.Insert("Variants", Undefined);
	Result.Insert("UseHighlighting", False);
	Result.Insert("SearchResult", New Structure);
	Result.Insert("WordArray", New Array);
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion
