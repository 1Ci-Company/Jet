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

// Sets the passed schema to the report and initializes Settings Composer based on the schema.
// If a report form is the context, the procedure refreshes the main form attribute (Report).
// The result is that the object context and the report form get synchronized.
// For example, it is called from the BeforeImportSettingsToComposer handler of an object of the universal report
// in order to set the schema generated programmatically based on another metadata object.
//
// Parameters:
//  Report - ReportObject
//        - ExternalReport - Target DCS report.
//  Context - ClientApplicationForm - Report form or a report settings form.
//             It is passed as is from the BeforeImportSettingsToComposer event parameter.
//           - Structure:
//               * RefOfReport - Arbitrary     - Report reference.
//               * FullName - String           - Full name of a report.
//               * Metadata - MetadataObject - Report metadata.
//               * Object - ReportObject
//                        - ExternalReport - Report object.:
//                            ** SettingsComposer - DataCompositionSettingsComposer - Report settings.
//                            ** DataCompositionSchema - DataCompositionSchema - Report schema.
//               * VariantKey - String - Predefined report option name or a user report option ID.
//               * SchemaURL - String - Address in the temporary storage where the report schema is located.
//               * Success - Boolean - True if the report is attached.
//               * ErrorText - String - Error text.
//       
//       
//  Schema - DataCompositionSchema - Schema to apply to the report.
//  SchemaKey - String - ID of the new schema to be written to the user settings additional properties. 
//                       
//
// Example:
//  In the object handler of the BeforeImportSettingsToComposer report, Settings Composer
//  is initialized based on schema from the common templates:
//  If SchemaKey <> "1" Then
//  	  SchemaKey = "1";
//  	  Schema = GetCommonTemplate("MyCommonCompositionSchema");
//  	  ReportsServer.EnableSchema(ThisObject, Context, Schema, SchemaKey);
//  EndIf;
//
Procedure AttachSchema(Report, Context, Schema, SchemaKey) Export
	FormEvent = (TypeOf(Context) = Type("ClientApplicationForm"));
	
	Report.DataCompositionSchema = Schema;
	If FormEvent Then
		ReportSettings = Context.ReportSettings;
		SchemaURL = ReportSettings.SchemaURL;
		ReportSettings.SchemaModified = True;
	Else
		SchemaURLFilled = (TypeOf(Context.SchemaURL) = Type("String") And IsTempStorageURL(Context.SchemaURL));
		If Not SchemaURLFilled Then
			FormIdentifier = CommonClientServer.StructureProperty(Context, "FormIdentifier");
			If TypeOf(FormIdentifier) = Type("UUID") Then
				SchemaURLFilled = True;
				Context.SchemaURL = PutToTempStorage(Schema, FormIdentifier);
			EndIf;
		EndIf;
		If SchemaURLFilled Then
			SchemaURL = Context.SchemaURL;
		Else
			SchemaURL = PutToTempStorage(Schema);
		EndIf;
		Context.SchemaModified = True;
	EndIf;
	PutToTempStorage(Schema, SchemaURL);
	
	ReportVariant = ?(FormEvent, ReportSettings.OptionRef, Undefined);
	InitializeSettingsComposer(Report.SettingsComposer, SchemaURL, Report, ReportVariant);
	
	If FormEvent Then
		ValueToFormData(Report, Context.Report);
	EndIf;
EndProcedure

// Initializes a data composition Settings Composer with exception handling.
//
// Parameters:
//  SettingsComposer - DataCompositionSettingsComposer - Settings Composer to initialize.
//  Schema - DataCompositionSchema
//        - String
//  Report - ReportObject
//        - Undefined - Report whose composer to be initialized.
//  ReportVariant - CatalogRef.ReportsOptions
//                - Undefined - Report option storage.
//
Procedure InitializeSettingsComposer(SettingsComposer, Schema, Report = Undefined, ReportVariant = Undefined) Export 
	Try
		SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(Schema));
	Except
		EventName = NStr("en = 'Settings Composer failed to initialize.';",
			Common.DefaultLanguageCode());
		
		MetadataObject = Undefined;
		If Report <> Undefined Then 
			MetadataObject = Report.Metadata();
		ElsIf ReportVariant <> Undefined Then 
			MetadataObject = ReportVariant.Metadata();
		EndIf;
		
		Comment = ErrorProcessing.DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(
			EventName, EventLogLevel.Error, MetadataObject, ReportVariant, Comment);
		
		Raise;
	EndTry;
EndProcedure

// Outputs command to a report form as a button to the specified group.
// It also registers the command protecting it from deletion upon redrawing the form.
// To call from the OnCreateAtServer report form event.
//
// Parameters:
//   ReportForm - ClientApplicationForm
//               - ManagedFormExtensionForReports - Form, where::
//     * ConstantAttributes - ValueList
//     * ConstantCommands - ValueList
//   CommandOrCommands - FormCommand     - Command, to which the displayed buttons will be connected.
//                       If the Action property has a blank string,
//                       when the command is executed, the ReportsClientOverridable.CommandHandler procedure will be called.
//                       If the Action property contains a string of the "<CommonClientModuleName>.<ExportProcedureName>" kind,
//                       when the command is executed in the specified module, the specified procedure with two parameters
//                       will be called, similar to the first two parameters of the ReportsClientOverridable.CommandHandler procedure.
//                     - Array - Set of commands (FormCommand) that will be output to the given group.
//   GroupType - String - Conditional name of the group that will host the button.
//               "Main" - Group with the "Generate" and "Generate on open" buttons.
//               "Settings" - Group with buttons "Settings", "Change report options", and so on.
//               "SpreadsheetDocumentOperations" - Group with buttons "Find", "Expand all groups", and so on.
//               "Integration" - Group with such buttons as "Print," "Save", and "Send".
//               "SubmenuSend" - Submenu in the "Integration" group to send via email.
//               "Other" - Group with such buttons as "Change form" and "Help".
//   ToGroupBeginning - Boolean - If True, the button will be output to the beginning of the group. Otherwise, a button will be output to group end.
//   OnlyInAllActions - Boolean - If True, the button will be output only to the "More actions" submenu.
//                           Otherwise, the button will be output both to the "More actions" submenu and to the form command bar.
//   SubgroupSuffix - String - If it is filled, commands will be merged into a subgroup.
//                      SubgroupSuffix is added to the right subgroup name.
//
Procedure OutputCommand(ReportForm, CommandOrCommands, GroupType, ToGroupBeginning = False, OnlyInAllActions = False, SubgroupSuffix = "") Export
	BeforeWhatToInsert = Undefined;
	MoreGroup = Undefined;
	
	If GroupType = "Main_Page" Then
		Group = ReportForm.Items.MainGroup1;
		MoreGroup = ReportForm.Items.MoreCommandBarMainGroup;
	ElsIf GroupType = "Settings" Then
		Group = ReportForm.Items.ReportSettingsGroup;
		MoreGroup = ReportForm.Items.MoreCommandBarReportSettingsGroup;
	ElsIf GroupType = "SpreadsheetDocumentOperations" Then
		Group = ReportForm.Items.WorkInTableGroup;
		MoreGroup = ReportForm.Items.MoreCommandBarTableActionsGroup;
	ElsIf GroupType = "Integration" Then
		Group = ReportForm.Items.GroupOutput;
		MoreGroup = ReportForm.Items.MoreCommandBarOutputGroup;
	ElsIf GroupType = "SubmenuSend" Then
		Group = ReportForm.Items.SendGroup;
		MoreGroup = ReportForm.Items.MoreCommandBarSendGroup;
	ElsIf GroupType = "Other" Then
		Group = ReportForm.Items.MainCommandBar;
		MoreGroup = ReportForm.Items.MoreCommandBar;
		BeforeWhatToInsert = ?(ToGroupBeginning, ReportForm.Items.NewWindow, Undefined);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Invalid value is passed in parameter %2 on calling procedure %1.';"),
			"ReportsServer.OutputCommand",
			"GroupType");
	EndIf;
	
	If OnlyInAllActions Then 
		Group = MoreGroup;
		MoreGroup = Undefined;
	EndIf;
	
	If ToGroupBeginning And BeforeWhatToInsert = Undefined Then
		BeforeWhatToInsert = Group.ChildItems[0];
	EndIf;
	
	If TypeOf(CommandOrCommands) = Type("FormCommand") Then
		Commands = New Array;
		Commands.Add(CommandOrCommands);
	Else
		Commands = CommandOrCommands;
	EndIf;
	
	If SubgroupSuffix <> "" Then
		Subgroup = ReportForm.Items.Find(Group.Name + SubgroupSuffix);
		If Subgroup = Undefined Then
			Subgroup = ReportForm.Items.Insert(Group.Name + SubgroupSuffix, Type("FormGroup"), Group, BeforeWhatToInsert);
			If Subgroup.Type = FormGroupType.Popup Then
				Subgroup.Type = FormGroupType.ButtonGroup;
			EndIf;
		EndIf;
		Group = Subgroup;
		BeforeWhatToInsert = Undefined;
	EndIf;
	
	For Each Command In Commands Do
		Handler = ?(StrOccurrenceCount(Command.Action, ".") = 0, "", Command.Action);
		ReportForm.ConstantCommands.Add(Command.Name, Handler);
		Command.Action = "Attachable_Command";
		
		Button = ReportForm.Items.Insert(Command.Name, Type("FormButton"), Group, BeforeWhatToInsert);
		Button.CommandName = Command.Name;
		
		If MoreGroup = Undefined Then 
			Button.LocationInCommandBar = ?(OnlyInAllActions, 
				ButtonLocationInCommandBar.InAdditionalSubmenu, ButtonLocationInCommandBar.InCommandBar);
			Continue;
		EndIf;
		
		Button = ReportForm.Items.Insert(Command.Name + "More", Type("FormButton"), MoreGroup);
		Button.CommandName = Command.Name;
		Button.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
	EndDo;
EndProcedure

// Hyperlinks the cell and fills address fields and reference presentations.
//
// Parameters:
//   Cell      - SpreadsheetDocumentRange - Spreadsheet area.
//   HyperlinkAddress - String                          - Address of the hyperlink to be displayed in the specified cell.
//			       Hyperlinks of the following formats automatically open in a standard report form::
//			       "http://<address>", "https://<address>", "e1cib/<address>", "e1c://<address>"
//			       Such hyperlinks are opened using the CommonClient.OpenURL procedure.
//			       See URLPresentation.URL in Syntax Assistant.
//			       To open hyperlinks of other formats write code in the
//			       ReportsClientOverridable.SpreadsheetDocumentChoiceProcessing procedure.
//   RepresentationOfTheReference - String
//                       - Undefined - Description to be displayed in the given cell.
//                                        If Undefined, HyperlinkAddress is displayed as is.
//
Procedure OutputHyperlink(Cell, HyperlinkAddress, RepresentationOfTheReference = Undefined) Export
	Cell.Hyperlink = True;
	Cell.Font       = New Font(Cell.Font, , , , , True); // ACC:1345 The font is based on the cell font. It can be a custom font and depends on the template appearance.
	Cell.TextColor  = Metadata.StyleItems.HyperlinkColor.Value;
	Cell.Details = HyperlinkAddress;
	Cell.Text       = ?(RepresentationOfTheReference = Undefined, HyperlinkAddress, RepresentationOfTheReference);
EndProcedure

// Defines that a report is blank.
//
// Parameters:
//   ReportObject - ReportObject
//               - ExternalReport - Report to be checked.
//   DCProcessor - DataCompositionProcessor - Object composing the data in the report.
//
// Returns:
//   Boolean - True if the report is blank. False if the report contains data.
//
Function ReportIsBlank(ReportObject, DCProcessor = Undefined) Export
	If DCProcessor = Undefined Then
		
		If ReportObject.DataCompositionSchema = Undefined Then
			Return False; // Not a DCS report.
		EndIf;
		
		// Objects to create a data composition template.
		DCTemplateComposer = New DataCompositionTemplateComposer;
		
		// Composes a template.
		DCTemplate = DCTemplateComposer.Execute(ReportObject.DataCompositionSchema, ReportObject.SettingsComposer.GetSettings());
		
		// Skip the check whether the report is empty.
		If ThereIsExternalDataSet(DCTemplate.DataSets) Then
			Return False;
		EndIf;
		
		// Object that composes data.
		DCProcessor = New DataCompositionProcessor;
		
		// Initialize an object.
		DCProcessor.Initialize(DCTemplate, , , True);
		
	Else
		
		// Move to the beginning of the composition.
		DCProcessor.Reset();
		
	EndIf;
	
	// Object for outputting the composition result into the spreadsheet.
	DCResultOutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	
	// Determines the spreadsheet document in which the result has to be displayed.
	DCResultOutputProcessor.SetDocument(New SpreadsheetDocument);
	
	// Sequential output.
	DCResultOutputProcessor.BeginOutput();
	
	// Gets the next item of the composition result.
	DCResultItem = DCProcessor.Next();
	While DCResultItem <> Undefined Do
		
		// Output the item of the report composition result into the document.
		DCResultOutputProcessor.OutputItem(DCResultItem);
		
		// Determine a non-empty result.
		For Each DCTemplateParameterValue In DCResultItem.ParameterValues Do
			Try
				ValueIsFilled = ValueIsFilled(DCTemplateParameterValue.Value);
			Except
				ValueIsFilled = False; // Line, Border, Color and other DC objects which can appear on the output.
			EndTry;
			If ValueIsFilled Then
				DCResultOutputProcessor.EndOutput();
				Return False;
			EndIf;
		EndDo;
		
		Try
			// Gets the next item of the composition result.
			DCResultItem = DCProcessor.Next();
		Except
			Return False;
		EndTry;
		
	EndDo;
	
	// Indicate to the object that the output of the result is complete.
	DCResultOutputProcessor.EndOutput();
	
	Return True;
EndFunction

// Returns a collection of report form item properties (report settings) linked to settings
// that can be overridden in the report object module.
// 
// Parameters:
//   FormType - ReportFormType
//   SettingsComposer - DataCompositionSettingsComposer
//   AdditionalParameters - See ReportsClientServer.DefaultReportSettings
// 
// Returns:
//   Structure:
//   * Groups - See FormItemsGroupProperties
//   * Fields - ValueTable:
//       ** SettingIndex - Number
//       ** SettingID  - String
//       ** Settings - DataCompositionSettings
//       ** SettingItem - DataCompositionFilterItem
//                           - DataCompositionSettingsParameterValue
//                           - DataCompositionSelectedField
//                           - DataCompositionOrderItem
//                           - ConditionalAppearanceItem
//       ** SettingDetails - DataCompositionFilterAvailableField
//                            - DataCompositionAvailableParameters
//                            - DataCompositionAvailableField
//       ** Presentation - String
//       ** GroupID - String
//       ** TitleLocation - FormItemTitleLocation
//       ** HorizontalStretch - Boolean
//                                   - Undefined
//       ** Width - Number
//
Function SettingsFormItemsProperties(FormType, SettingsComposer, AdditionalParameters) Export
	
	ItemsProperties = New Structure("Groups, Fields");
	ItemsProperties.Groups = New Structure;
	
	Fields = SettingsFormItemsFields();
	
	AvailableModes = New Array;
	AvailableModes.Add(DataCompositionSettingsItemViewMode.QuickAccess);
	If FormType = ReportFormType.Settings Then 
		AvailableModes.Add(DataCompositionSettingsItemViewMode.Normal);
	EndIf;
	
	UnavailableStructureItems = New Map;
	UnavailableStructureItems.Insert(Type("DataCompositionGroup"), ReportFormType.Settings);
	UnavailableStructureItems.Insert(Type("DataCompositionTableGroup"), ReportFormType.Settings);
	UnavailableStructureItems.Insert(Type("DataCompositionChartGroup"), ReportFormType.Settings);
	UnavailableStructureItems.Insert(Type("DataCompositionTable"), ReportFormType.Settings);
	UnavailableStructureItems.Insert(Type("DataCompositionChart"), ReportFormType.Settings);
	
	InformationRecords = UserSettingsInfo(SettingsComposer.Settings);
	UserSettings = SettingsComposer.UserSettings;
	For Each UserSettingItem In UserSettings.Items Do 
		FoundInfo = InformationRecords[UserSettingItem.UserSettingID];
		If FoundInfo = Undefined Then 
			Continue;
		EndIf;

		SettingItem = FoundInfo.SettingItem; // DataCompositionGroup, DataCompositionTableGroup, DataCompositionChartGroup 
		If SettingItem = Undefined
			Or UnavailableStructureItems.Get(TypeOf(SettingItem)) = FormType
			Or AvailableModes.Find(SettingItem.ViewMode) = Undefined Then 
			Continue;
		EndIf;
		
		ElementType = TypeOf(SettingItem);
		If ElementType = Type("DataCompositionConditionalAppearanceItem") Then 
			Presentation = ReportsClientServer.ConditionalAppearanceItemPresentation(
				SettingItem, Undefined, "");
			
			If Not ValueIsFilled(SettingItem.Presentation) Then 
				SettingItem.Presentation = Presentation;
			ElsIf Not ValueIsFilled(SettingItem.UserSettingPresentation)
				And SettingItem.Presentation <> Presentation Then 
				
				SettingItem.UserSettingPresentation = SettingItem.Presentation;
				SettingItem.Presentation = Presentation;
			EndIf;
		EndIf;
		
		Field = Fields.Add();
		Field.SettingID = UserSettingItem.UserSettingID;
		Field.SettingIndex = UserSettings.Items.IndexOf(UserSettingItem);
		Field.Settings = FoundInfo.Settings;
		Field.SettingItem = SettingItem;
		Field.SettingDetails = FoundInfo.SettingDetails;
		Field.TitleLocation = FormItemTitleLocation.Auto;
		
		If UnavailableStructureItems.Get(TypeOf(SettingItem)) <> Undefined Then 
			Presentation = SettingItem.OutputParameters.Items.Find("TITLE");
			If Presentation <> Undefined
				And ValueIsFilled(Presentation.Value) Then 
				Field.Presentation = Presentation.Value;
			EndIf;
		EndIf;
		
		If FormType = ReportFormType.Settings
			And TypeOf(SettingItem) = Type("DataCompositionConditionalAppearanceItem") Then 
			Field.GroupID = "More";
		EndIf;
	EndDo;
	
	If Fields.Find("More", "GroupID") <> Undefined Then 
		ItemsProperties.Groups.Insert("More", FormItemsGroupProperties());
	EndIf;
	
	Fields.Sort("SettingIndex");
	ItemsProperties.Fields = Fields;
	
	If AdditionalParameters.Events.OnDefineSettingsFormItemsProperties Then 
		ReportObject(AdditionalParameters.FullName).OnDefineSettingsFormItemsProperties(
			FormType, ItemsProperties, UserSettings.Items);
	EndIf;
	
	Return ItemsProperties;
EndFunction

// The wizard of group items properties of user settings form.
//
// Returns:
//   Structure - Contains property values of the group:
//    * Representation - UsualGroupRepresentation - See Syntax Assistant for "UsualGroupPresentation".
//    * Group - ChildFormItemsGroup - Number of the item groups (columns)::
//       ** Vertical - ChildFormItemsGroup - Equals to one column.
//       ** HorizontalIfPossible - ChildFormItemsGroup - Equals to two columns.
//       ** AlwaysHorizontal - ChildFormItemsGroup - Number of columns equals to the number of group items.
//                                                                        
//    * Title - String - See Syntax Assistant for "FormGroup.Title".
//    * BackColor - Color - See Syntax Assistant for "FormGroup.BackColor".
//    * ToolTip - String - See Syntax Assistant for "FormGroup.Tooltip".
//    * ToolTipRepresentation - ToolTipRepresentation - See Syntax Assistant for "FormGroup.TooltipRepresentation".
//    * Height - Number - See Syntax Assistant for "FormGroup.Height".
//    * Width - Number - See Syntax Assistant for "FormGroup.Width".
//    * VerticalStretch - Undefined, Boolean - See Syntax Assistant for "FormGroup.VerticalStretch".
//    * HorizontalStretch - Undefined, Boolean - See Syntax Assistant for "FormGroup.HorizontalStretch".
//
Function FormItemsGroupProperties() Export 
	GroupProperties = New Structure;
	GroupProperties.Insert("Representation", UsualGroupRepresentation.None);
	GroupProperties.Insert("Group", ChildFormItemsGroup.HorizontalIfPossible);
	
	GroupProperties.Insert("Title", "");
	GroupProperties.Insert("BackColor", New Color);

	GroupProperties.Insert("ToolTip", "");
	GroupProperties.Insert("ToolTipRepresentation", ToolTipRepresentation.Auto);

	GroupProperties.Insert("Height", 0);
	GroupProperties.Insert("Width", 0);
	GroupProperties.Insert("VerticalStretch", Undefined);
	GroupProperties.Insert("HorizontalStretch", Undefined);
	
	Return GroupProperties;
EndFunction

#EndRegion

#Region Internal

// Outputs and groups form items linked to user settings.
// The form contains the ManagedFormExtensionForReport type.
//
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForSettingsComposer
//   ItemsHierarchyNode - FormGroup
//   ParametersOfUpdate - See ReportsClientServer.ReportFormUpdateParameters
//
Procedure UpdateSettingsFormItems(Form, ItemsHierarchyNode, ParametersOfUpdate = Undefined) Export 
	BeforeUpdatingTheElementsOfTheSettingsForm(Form, ParametersOfUpdate);
	
	If Common.IsMobileClient() Then 
		Form.CreateUserSettingsFormItems(ItemsHierarchyNode);
		RestoreFiltersValues(Form);
		Return;
	EndIf;
	
	Items = Form.Items;
	ReportSettings = Form.ReportSettings;
	
	StyylizedItemsKinds = StrSplit("Period, List, CheckBox", ", ", False);
	AttributesNames = SettingsItemsAttributesNames(Form, StyylizedItemsKinds);
	
	PrepareFormToRegroupItems(Form, ItemsHierarchyNode, AttributesNames, StyylizedItemsKinds);
	
	TemporaryGroup = Items.Add("Temporary", Type("FormGroup"));
	TemporaryGroup.Type = FormGroupType.UsualGroup;
	
	Mode = DataCompositionSettingsViewMode.QuickAccess;
	If Form.ReportFormType = ReportFormType.Settings Then 
		Mode = DataCompositionSettingsViewMode.All;
	EndIf;
	
	Form.CreateUserSettingsFormItems(TemporaryGroup, Mode, 1);
	
	ItemsProperties = SettingsFormItemsProperties(
		Form.ReportFormType, Form.Report.SettingsComposer, ReportSettings);
	
	RegroupSettingsFormItems(
		Form, ItemsHierarchyNode, ItemsProperties, AttributesNames, StyylizedItemsKinds);
	
	Items.Delete(TemporaryGroup);
	RestoreFiltersValues(Form);
	
	// Call an overridable module.
	If ReportSettings.Events.AfterQuickSettingsBarFilled Then
		ReportObject = ReportObject(ReportSettings.FullName);
		ReportObject.AfterQuickSettingsBarFilled(Form, ParametersOfUpdate);
	EndIf;
EndProcedure

// Parameters:
//   ImportParameters - See ReportsClientServer.ReportFormUpdateParameters
//   ReportSettings - Structure
//
Function AvailableSettings(ImportParameters, ReportSettings) Export 
	Settings = Undefined;
	UserSettings = Undefined;
	FixedSettings = Undefined;
	
	If ImportParameters.DCSettingsComposer <> Undefined Then
		Settings = ImportParameters.DCSettingsComposer.Settings;
		UserSettings = ImportParameters.DCSettingsComposer.UserSettings;
		FixedSettings = ImportParameters.DCSettingsComposer.FixedSettings;
	Else
		If ImportParameters.DCSettings <> Undefined Then
			Settings = ImportParameters.DCSettings;
		EndIf;
		If ImportParameters.DCUserSettings <> Undefined Then
			UserSettings = ImportParameters.DCUserSettings;
		EndIf;
	EndIf;
	
	If ReportSettings.Events.BeforeImportSettingsToComposer Then
		If TypeOf(ReportSettings.NewXMLSettings) = Type("String") Then
			Try
				Settings = Common.ValueFromXMLString(ReportSettings.NewXMLSettings);
				
				// Connects to the schema to restore parameters' unused values that are lost during serialization.
				//  See the Syntax Assistant for "DataCompositionDataParameterValues".
				SettingsComposer = New DataCompositionSettingsComposer;
				InitializeSettingsComposer(SettingsComposer, ReportSettings.SchemaURL);
				SettingsComposer.LoadSettings(Settings);
				
				Settings = SettingsComposer.Settings;
			Except
				Settings = Undefined;
			EndTry;
			ReportSettings.NewXMLSettings = Undefined;
		EndIf;
		
		If TypeOf(ReportSettings.NewUserXMLSettings) = Type("String") Then
			Try
				UserSettings = Common.ValueFromXMLString(
					ReportSettings.NewUserXMLSettings);
			Except
				UserSettings = Undefined;
			EndTry;
			ReportSettings.NewUserXMLSettings = Undefined;
		EndIf;
	EndIf;
	
	Return New Structure("Settings, UserSettings, FixedSettings",
		Settings, UserSettings, FixedSettings);
EndFunction

// Parameters:
//   AvailableSettings - Structure
//   ImportParameters - See ReportsClientServer.ReportFormUpdateParameters
//
Procedure ResetCustomSettings(AvailableSettings, ImportParameters) Export 

	If Not ImportParameters.ResetCustomSettings Then 
		Return;
	EndIf;
	
	If AvailableSettings.UserSettings = Undefined Then 
		AdditionalProperties = Undefined;
	Else
		AdditionalProperties = AvailableSettings.UserSettings.AdditionalProperties;
	EndIf;
	
	AvailableSettings.UserSettings = New DataCompositionUserSettings;
	
	If AdditionalProperties = Undefined Then 
		Return;
	EndIf;
	
	For Each Property In AdditionalProperties Do 
		AvailableSettings.UserSettings.AdditionalProperties.Insert(Property.Key, Property.Value);
	EndDo;
EndProcedure

Procedure SetAvailableValues(Report, Form) Export 
	SettingsComposer = Form.Report.SettingsComposer;
	
	SettingsCollections = New Array; // Array of DataCompositionUserSettings, DataCompositionDataParameterValues, DataCompositionFilter
	SettingsCollections.Add(SettingsComposer.UserSettings);
	SettingsCollections.Add(SettingsComposer.Settings.DataParameters);
	SettingsCollections.Add(SettingsComposer.Settings.Filter);
	
	For Each SettingsCollection In SettingsCollections Do 
		IsUserSettings = (TypeOf(SettingsCollection) = Type("DataCompositionUserSettings"));
		
		For Each SettingItem In SettingsCollection.Items Do 
			If TypeOf(SettingItem) <> Type("DataCompositionSettingsParameterValue")
				And TypeOf(SettingItem) <> Type("DataCompositionFilterItem") Then 
				Continue;
			EndIf;
			
			If Not IsUserSettings
				And ValueIsFilled(SettingItem.UserSettingID) Then 
				Continue;
			EndIf;
			
			If IsUserSettings Then 
				UserSettingItem = SettingItem;
				
				MainSettingItem = ReportsClientServer.GetObjectByUserID(
					SettingsComposer.Settings,
					UserSettingItem.UserSettingID,,
					SettingsCollection);
			Else
				UserSettingItem = SettingItem;
				MainSettingItem = SettingItem;
			EndIf;
			
			SettingDetails = ReportsClientServer.FindAvailableSetting(
				SettingsComposer.Settings, MainSettingItem);
			// @skip-check query-in-loop - Query multiple tables.
			SetValidSettingsValues(Form, Report, SettingsComposer, UserSettingItem, MainSettingItem, SettingDetails);
			
			If TypeOf(MainSettingItem) = Type("DataCompositionFilterItem") Then
				SettingDetails = SettingsComposer.Settings.StructureItemsFilterAvailableFields.FindField(MainSettingItem.LeftValue);
				If SettingDetails <> Undefined Then
					// @skip-check query-in-loop - Query multiple tables.
					SetValidSettingsValues(Form, Report, SettingsComposer, UserSettingItem, MainSettingItem, SettingDetails);
				EndIf;
			EndIf;

		EndDo;
	EndDo;
EndProcedure

Function IsTechnicalObject(Val FullObjectName) Export
	
	Return FullObjectName = Upper(Metadata.Catalogs.PredefinedExtensionsReportsOptions.FullName())
		Or FullObjectName = Upper(Metadata.Catalogs.PredefinedReportsOptions.FullName());
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Option settings.

// Defines output parameter properties that affect the display of title, data parameters, and filters.
//  * Show title;
//  * Header;
//  * Show data parameters;
//  * Show filter;
//
// Parameters:
//  Context - Structure - Information on the report option and its metadata ID.
//  Settings - DataCompositionSettings - Settings whose output parameters are being set.
//  Reset - Boolean - Flag indicating that output parameters must be returned to the original state.
//
Procedure InitializePredefinedOutputParameters(Context, Settings, Reset = False) Export 
	If Settings = Undefined Then 
		Return;
	EndIf;
	
	If Reset Then 
		
		ResetPredefinedOutputParameters(Settings);
		Return;
		
	EndIf;
	
	OutputParameters = Settings.OutputParameters.Items;
	
	// The "Title" parameter is always available but only in the report setting form.
	Object = OutputParameters.Find("TITLE");
	Object.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	Object.UserSettingID = "";
	
	SetStandardReportHeader(Object, Context);
	
	// Parameter OutputTitle is always disabled. Properties depend on the Title parameter.
	LinkedObject = OutputParameters.Find("TITLEOUTPUT");
	LinkedObject.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	LinkedObject.UserSettingID = "";
	LinkedObject.Use = True;
	
	If Object.Use Then 
		LinkedObject.Value = DataCompositionTextOutputType.Auto;
	Else
		LinkedObject.Value = DataCompositionTextOutputType.DontOutput;
	EndIf;
	
	// The "OutputParameters" parameter is always available but only in the report setting form.
	Object = OutputParameters.Find("DATAPARAMETERSOUTPUT");
	Object.ViewMode = DataCompositionSettingsItemViewMode.Normal;
	Object.UserSettingID = "";
	Object.Use = True;
	
	If Object.Value <> DataCompositionTextOutputType.DontOutput Then 
		Object.Value = DataCompositionTextOutputType.Auto;
	EndIf;
	
	// Parameter OutputTitle is always disabled. The property values repeat the OutputDataParameters parameter.
	LinkedObject = OutputParameters.Find("FILTEROUTPUT");
	LinkedObject.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	LinkedObject.UserSettingID = "";
	LinkedObject.Use = True;
	
	If LinkedObject.Value <> DataCompositionTextOutputType.DontOutput Then 
		LinkedObject.Value = DataCompositionTextOutputType.Auto;
	EndIf;
	
	SaveStandardValuesOfPredefinedOutputParameters(Settings);
EndProcedure

Procedure SetStandardReportHeader(Title, Context)
	If ValueIsFilled(Title.Value) Then 
		Return;
	EndIf;
	
	ReportID = CommonClientServer.StructureProperty(Context, "ReportRef");
	If ReportID = Undefined Then 
		Return;
	EndIf;
	
	IsAdditionalReportOrDataProcessorType = False;
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		IsAdditionalReportOrDataProcessorType = ModuleAdditionalReportsAndDataProcessors.IsAdditionalReportOrDataProcessorType(
			TypeOf(ReportID));
	EndIf;
	
	If TypeOf(ReportID) = Type("String")
		Or IsAdditionalReportOrDataProcessorType Then 
		Title.Value = CommonClientServer.StructureProperty(Context, "Description", "");
		Return;
	EndIf;
	
	Variant = CommonClientServer.StructureProperty(Context, "OptionRef");
	If ValueIsFilled(Variant) Then 
		Title.Value = String(Variant);
	EndIf;
	
	If ValueIsFilled(Title.Value)
		And Title.Value <> "Main" Then 
		Return;
	EndIf;
	
	MetadataOfReport = Common.MetadataObjectByID(ReportID, False);
	If TypeOf(MetadataOfReport) = Type("MetadataObject") Then 
		Title.Value = MetadataOfReport.Presentation();
	EndIf;
EndProcedure

Procedure SaveStandardValuesOfPredefinedOutputParameters(Settings)
	
	StandardProperties = StandardPropertiesOfPredefinedOutputParameters(Settings);
	
	If StandardProperties <> Undefined Then 
		Return;
	EndIf;
	
	StandardProperties = New Array;
	
	OutputParameters = Settings.OutputParameters.Items;
	IdsOfOutputParameters = StrSplit("TITLE, TITLEOUTPUT, DATAPARAMETERSOUTPUT, FILTEROUTPUT", ", ", False);
	
	For Each Id In IdsOfOutputParameters Do 
		
		FoundParameter = OutputParameters.Find(Id);
		
		If FoundParameter = Undefined Then 
			Continue;
		EndIf;
		
		ParameterProperties = StandardPropertiesOfAPredefinedOutputParameter();
		FillPropertyValues(ParameterProperties, FoundParameter);
		ParameterProperties.Id =  Id;
		
		StandardProperties.Add(ParameterProperties);
		
	EndDo;
	
	If ParameterProperties.Count() > 0 Then 
		
		Settings.AdditionalProperties.Insert(
			KeyOfStandardPropertiesOfPredefinedOutputParameters(), StandardProperties);
		
	EndIf;
	
EndProcedure

Procedure ResetPredefinedOutputParameters(Settings)
	
	StandardProperties = StandardPropertiesOfPredefinedOutputParameters(Settings);
	
	If StandardProperties = Undefined Then 
		Return;
	EndIf;
	
	OutputParameters = Settings.OutputParameters.Items;
	
	For Each ParameterProperties In StandardProperties Do 
		
		FoundParameter = OutputParameters.Find(ParameterProperties.Id);
		
		If FoundParameter = Undefined Then 
			Continue;
		EndIf;
		
		FillPropertyValues(FoundParameter, ParameterProperties);
		
	EndDo;
	
EndProcedure

Function ItIsRequiredToResetThePredefinedOutputParameters(ImportParameters) Export 
	
	If ImportParameters.ClearOptionSettings Then  
		Return False;
	EndIf;
	
	Return ImportParameters.EventName = ReportsClientServer.NameOfTheDefaultSettingEvent();
	
EndFunction

Function KeyOfStandardPropertiesOfPredefinedOutputParameters()
	
	Return "StandardPropertiesOfPredefinedOutputParameters";
	
EndFunction

// Parameters:
//  Settings - DataCompositionSettings
// 
// Returns:
//  - Undefined
//  - Array of Structure:
//      * Id - String
//      * Use - Boolean
//      * Value - Undefined
//
Function StandardPropertiesOfPredefinedOutputParameters(Settings)
	
	Return CommonClientServer.StructureProperty(
		Settings.AdditionalProperties,
		KeyOfStandardPropertiesOfPredefinedOutputParameters());
	
EndFunction

// Returns:
//  Structure:
//    * Id - String
//    * Use - Boolean
//    * Value - Undefined
//
Function StandardPropertiesOfAPredefinedOutputParameter()
	
	Return New Structure("Id, Use, Value", "", False, Undefined);
	
EndFunction

Procedure RestoreFiltersValues(Form) 
	PathToItemsData = Form.PathToItemsData;
	If PathToItemsData = Undefined Then 
		Return;
	EndIf;
	
	UserSettings = Form.Report.SettingsComposer.UserSettings;
	
	FiltersValuesCache = CommonClientServer.StructureProperty(
		UserSettings.AdditionalProperties, "FiltersValuesCache");
	
	If FiltersValuesCache = Undefined Then 
		Return;
	EndIf;
	
	For Each CacheItem In FiltersValuesCache Do 
		FilterValue = CacheItem.Value;
		If FilterValue.Count() = 0 Then 
			Continue;
		EndIf;
		
		SettingItem = UserSettings.Items.Find(CacheItem.Key);
		If SettingItem = Undefined Then 
			Continue;
		EndIf;
		
		IndexOf = UserSettings.Items.IndexOf(SettingItem);
		ListName = PathToItemsData.ByIndex[IndexOf];
		If ListName = Undefined Then 
			Continue;
		EndIf;
		
		List = Form[ListName];
		If List = Undefined Then 
			Continue;
		EndIf;
		
		For Each Item In FilterValue Do 
			If List.FindByValue(Item.Value) = Undefined Then 
				List.Add(Item.Value);
			EndIf;
		EndDo;
	EndDo;
EndProcedure

Procedure SetFixedFilters(FiltersStructure, DCSettings, ReportSettings) Export
	If TypeOf(DCSettings) <> Type("DataCompositionSettings")
		Or FiltersStructure = Undefined
		Or FiltersStructure.Count() = 0 Then
		Return;
	EndIf;

	DCParameters = DCSettings.DataParameters;
	DCFilters = DCSettings.Filter;
	DCComparisonType = DataCompositionComparisonType.Equal;
	ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	Presentation = "";
	Id = "";
	
	For Each KeyAndValue In FiltersStructure Do
		Name = KeyAndValue.Key;
		
		If ThisSelectionDecipherHandlerByDetailedRecords(KeyAndValue.Value) Then 
			SelectionProperties = KeyAndValue.Value;
			Value = SelectionProperties.Value;
			DCComparisonType = SelectionProperties.ComparisonType;
			ViewMode = SelectionProperties.ViewMode;
			Presentation = SelectionProperties.Presentation;
			Id = SelectionProperties.UserSettingID;
		Else
			Value = KeyAndValue.Value;
		EndIf;

		If TypeOf(Value) = Type("FixedArray") Then
			Value = New Array(Value);
		EndIf;

		If TypeOf(Value) = Type("Array") Then
			List = New ValueList;
			List.LoadValues(Value);
			Value = List;
		EndIf;

		DCParameter = DCParameters.FindParameterValue(New DataCompositionParameter(Name));

		If TypeOf(DCParameter) = Type("DataCompositionSettingsParameterValue") Then
			DCParameter.UserSettingID = Id;
			DCParameter.Use    = True;
			DCParameter.ViewMode = ViewMode;
			DCParameter.Value         = Value;
			Continue;
		EndIf;

		If TypeOf(Value) = Type("Structure") Then
			DCComparisonType = CommonClientServer.StructureProperty(
				Value, "ComparisonType", DataCompositionComparisonType.Equal);
			Value = CommonClientServer.StructureProperty(Value, "RightValue");
		ElsIf TypeOf(Value) = Type("ValueList") Then
			DCComparisonType = DataCompositionComparisonType.InList;
		EndIf;
		
		CommonClientServer.SetFilterItem(
			DCFilters, Name, Value, DCComparisonType, Presentation, True, ViewMode, Id);
	EndDo;
EndProcedure

Function ThisSelectionDecipherHandlerByDetailedRecords(Filter)
	
	If TypeOf(Filter) <> Type("Structure") Then 
		Return False;
	EndIf;
	
	SelectionProperties = ReportsOptionsInternal.DecryptionHandlerSelectionPropertiesByDetailRecords();
	
	If Filter.Count() <> SelectionProperties.Count() Then 
		Return False;
	EndIf;
	
	For Each Property In SelectionProperties Do 
		
		If Not Filter.Property(Property.Key) Then 
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

Procedure FillinAdditionalProperties(ReportObject, NewSettings1, Val VariantKey, Val PredefinedOptionKey,
			Val OptionContext = "", Val FormParametersSelection = Undefined) Export
	
	If TypeOf(NewSettings1) = Type("DataCompositionSettings") Then
		FillAdditionProperty(NewSettings1, "VariantKey", VariantKey);
		FillAdditionProperty(NewSettings1, "PredefinedOptionKey", PredefinedOptionKey);
		FillAdditionProperty(NewSettings1, "OptionContext", OptionContext);
		FillAdditionProperty(NewSettings1, "FormParametersSelection", FormParametersSelection, New Structure);
	EndIf;
	
	CurrentSettings = ReportObject.SettingsComposer.Settings;
	FillAdditionProperty(CurrentSettings, "VariantKey", VariantKey);
	FillAdditionProperty(CurrentSettings, "PredefinedOptionKey", PredefinedOptionKey);
	FillAdditionProperty(CurrentSettings, "OptionContext", OptionContext);
	FillAdditionProperty(CurrentSettings, "FormParametersSelection", FormParametersSelection, New Structure);
	
EndProcedure

Procedure FillAdditionProperty(Settings, PropertyName, PropertyValue, DefaultValue = "")
	
	If ValueIsFilled(PropertyValue) Then
		Settings.AdditionalProperties.Insert(PropertyName, PropertyValue);
	ElsIf Not Settings.AdditionalProperties.Property(PropertyName, PropertyValue) Then
		Settings.AdditionalProperties.Insert(PropertyName, DefaultValue);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// User settings.

// Collects statistics on the number of user settings broken down by display modes.
//
// Parameters:
//  SettingsComposer - DataCompositionSettingsComposer - Relevant composer.
//
// Returns:
//   Structure - Number of user settings broken down by display modes:
//     * QuickAccessSettingsCount - Number - Number of settings with the "QuickAccess" or "Auto" display modes.
//     * Typical - Number - Number of settings with the "Typical" display mode.
//     * Total - Number - Total number of available settings.
//
Function CountOfAvailableSettings(SettingsComposer) Export 
	AvailableSettings = New Structure;
	AvailableSettings.Insert("QuickAccessSettingsCount", 0);
	AvailableSettings.Insert("Typical", 0);
	AvailableSettings.Insert("Total", 0);
	
	UserSettings = SettingsComposer.UserSettings;
	For Each UserSettingItem In UserSettings.Items Do 
		SettingItem = ReportsClientServer.GetObjectByUserID(
			SettingsComposer.Settings,
			UserSettingItem.UserSettingID,,
			UserSettings);
		
		ViewMode = ?(SettingItem = Undefined,
			UserSettingItem.ViewMode, SettingItem.ViewMode);
		
		If ViewMode = DataCompositionSettingsItemViewMode.Auto
			Or ViewMode = DataCompositionSettingsItemViewMode.QuickAccess Then 
			AvailableSettings.QuickAccessSettingsCount = AvailableSettings.QuickAccessSettingsCount + 1;
		ElsIf ViewMode = DataCompositionSettingsItemViewMode.Normal Then 
			AvailableSettings.Typical = AvailableSettings.Typical + 1;
		EndIf;
	EndDo;
	
	AvailableSettings.Total = AvailableSettings.QuickAccessSettingsCount + AvailableSettings.Typical;
	
	Return AvailableSettings;
EndFunction

Function UserSettingsItemProperties(SettingsComposer, UserSettingItem, SettingItem, SettingDetails)
	Properties = UserSettingsItemPropertiesPalette();
	
	Properties.DCUserSetting = UserSettingItem;
	Properties.DCItem = SettingItem;
	Properties.AvailableDCSetting = SettingDetails;
	
	Properties.Id = UserSettingItem.UserSettingID;
	Properties.DCID = SettingsComposer.UserSettings.GetIDByObject(
		UserSettingItem);
	Properties.ItemID = StrReplace(
		UserSettingItem.UserSettingID, "-", "");
	
	SettingItemType = TypeOf(SettingItem);
	If SettingItemType = Type("DataCompositionSettingsParameterValue") Then 
		Properties.DCField = New DataCompositionField("DataParameters." + String(SettingItem.Parameter));
		Properties.Value = SettingItem.Value;
	ElsIf TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
		Properties.DCField = SettingItem.LeftValue;
		Properties.Value = SettingItem.RightValue;
	EndIf;
	
	Properties.Type = ReportsClientServer.SettingTypeAsString(SettingItemType);
	
	If SettingDetails = Undefined Then 
		Return Properties;
	EndIf;
	
	Properties.TypeDescription = SettingDetails.ValueType;
	
	If SettingDetails.AvailableValues <> Undefined Then 
		Properties.ValuesForSelection = SettingDetails.AvailableValues;
	EndIf;
	
	Return Properties;
EndFunction

Function UserSettingsItemPropertiesPalette()
	Properties = New Structure;
	Properties.Insert("QuickChoice", False);
	Properties.Insert("ListInput", False);
	Properties.Insert("ComparisonType", DataCompositionComparisonType.Equal);
	Properties.Insert("Owner", Undefined);
	Properties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	Properties.Insert("OutputAllowed", True);
	Properties.Insert("OutputInMainSettingsGroup", False);
	Properties.Insert("OutputFlagOnly", False);
	Properties.Insert("OutputFlag", True);
	Properties.Insert("Global", True);
	Properties.Insert("AvailableDCSetting", Undefined);
	Properties.Insert("SelectionValuesQuery", New Query);
	Properties.Insert("Value", Undefined);
	Properties.Insert("ValuesForSelection", New ValueList);
	Properties.Insert("Id", "");
	Properties.Insert("DCID", Undefined);
	Properties.Insert("ItemID", "");
	Properties.Insert("CollectionName", "");
	Properties.Insert("TypesInformation", New Structure);
	Properties.Insert("TypeRestriction", Undefined);
	Properties.Insert("RestrictSelectionBySpecifiedValues", False);
	Properties.Insert("TypeDescription", New TypeDescription("Undefined"));
	Properties.Insert("MarkedValues", Undefined);
	Properties.Insert("ChoiceParameters", New Array);
	Properties.Insert("Subtype", "");
	Properties.Insert("DCField", Undefined);
	Properties.Insert("UserSetting", Undefined);
	Properties.Insert("DCUserSetting", Undefined);
	Properties.Insert("Presentation", "");
	Properties.Insert("DefaultPresentation", "");
	Properties.Insert("Parent", Undefined);
	Properties.Insert("ChoiceParameterLinks", New Array);
	Properties.Insert("MetadataRelations", New Array);
	Properties.Insert("TypeLink", Undefined);
	Properties.Insert("EventOnChange", False);
	Properties.Insert("State", "");
	Properties.Insert("ValueListRedefined", False);
	Properties.Insert("TreeRow", Undefined);
	Properties.Insert("Rows", Undefined);
	Properties.Insert("Type", "");
	Properties.Insert("ChoiceForm", "");
	Properties.Insert("Width", 0);
	Properties.Insert("DCItem", Undefined);
	
	Return Properties;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary

// Creates and returns an instance of the report by full metadata object name.
//
// Parameters:
//  FullName - String - Full name of the metadata object. Example: "Report.BusinessProcesses".
//
// Returns:
//  ReportObject - Report instance.
//
Function ReportObject(Id) Export
	FullName = Id;
	
	If TypeOf(Id) = Type("CatalogRef.MetadataObjectIDs") Then
		FullName = Common.ObjectAttributeValue(Id, "FullName");
	EndIf;
	
	ObjectDetails = StrSplit(FullName, ".");
	
	If ObjectDetails.Count() >= 2 Then
		Kind = Upper(ObjectDetails[0]);
		Name = ObjectDetails[1];
	Else
		Raise StrReplace(NStr("en = 'Report %1 has invalid name.';"), "%1", FullName);
	EndIf;
	
	If Kind = "REPORT" Then
		Return Reports[Name].Create();
	ElsIf Kind = "EXTERNALREPORT" Then
		Return ExternalReports.Create(Name); // ACC:553 Only for external reports, which are not attached to the "Additional reports and data processors" subsystem. The call is safe as all external reports go through security checks when being attached.
	Else
		Raise StrReplace(NStr("en = '%1 is not a report.';"), "%1", FullName);
	EndIf;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating form items of user settings

Procedure BeforeUpdatingTheElementsOfTheSettingsForm(Form, ParametersOfUpdate)
	
	If TypeOf(ParametersOfUpdate) <> Type("Structure") Then 
		Return;
	EndIf;
	
	SettingsComposer = Form.Report.SettingsComposer;
	If ParametersOfUpdate.EventName = "DefaultSettings" Then 
		SettingsComposer.Settings.AdditionalProperties.Insert("TheOrderOfTheSettingsElements", New Map);
	EndIf;
	
EndProcedure

// Returns:
//  ValueTable:
//    * SettingIndex - Number
//    * SettingID  - String
//    * Settings - DataCompositionSettings
//    * SettingItem - DataCompositionFilterItem
//                       - DataCompositionSettingsParameterValue
//                       - DataCompositionSelectedField
//                       - DataCompositionOrderItem
//                       - ConditionalAppearanceItem
//    * SettingDetails - DataCompositionFilterAvailableField
//                        - DataCompositionAvailableParameters
//                        - DataCompositionAvailableField
//    * Presentation - String
//    * GroupID - String
//    * TitleLocation - FormItemTitleLocation
//    * HorizontalStretch - Boolean
//                               - Undefined
//    * Width - Number
//
Function SettingsFormItemsFields()
	
	RowDescription = New TypeDescription("String");
	NumberDetails = New TypeDescription("Number");
	
	Fields = New ValueTable;
	Fields.Columns.Add("SettingIndex", NumberDetails);
	Fields.Columns.Add("SettingID", RowDescription);
	Fields.Columns.Add("Settings");
	Fields.Columns.Add("SettingItem");
	Fields.Columns.Add("SettingDetails");
	Fields.Columns.Add("Presentation", RowDescription);
	Fields.Columns.Add("GroupID", RowDescription);
	Fields.Columns.Add("TitleLocation", New TypeDescription("FormItemTitleLocation"));
	Fields.Columns.Add("HorizontalStretch");
	Fields.Columns.Add("Width", NumberDetails);
	
	Return Fields;
	
EndFunction

// Getting info on main settings included in user settings.

// Returns indexed properties of user report settings such as matching
// items of the main settings and additional data composition fields.
// 
// Parameters:
//  Settings - DataCompositionSettings
// 
// Returns:
//   See InfoKinds
//
Function UserSettingsInfo(Settings) Export 
	InformationRecords = New Map;
	GetGroupingInfo(Settings, InformationRecords, Settings.AdditionalProperties);
	
	Return InformationRecords;
EndFunction

Procedure GetGroupingInfo(Group, InformationRecords, AdditionalProperties)
	GroupType = TypeOf(Group);
	If GroupType <> Type("DataCompositionSettings")
		And GroupType <> Type("DataCompositionGroup")
		And GroupType <> Type("DataCompositionTableGroup")
		And GroupType <> Type("DataCompositionChartGroup") Then 
		Return;
	EndIf;
	
	If GroupType <> Type("DataCompositionSettings")
		And ValueIsFilled(Group.UserSettingID) Then 
		
		InfoKinds = InfoKinds();
		InfoKinds.Settings = Group;
		InfoKinds.SettingItem = Group;
		
		InformationRecords.Insert(Group.UserSettingID, InfoKinds);
	EndIf;
	
	GetSettingsItemInfo(Group, InformationRecords, AdditionalProperties);
EndProcedure

Procedure GetTableInfo(Table, InformationRecords, AdditionalProperties)
	If TypeOf(Table) <> Type("DataCompositionTable") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Table.UserSettingID) Then 
		InfoKinds = InfoKinds();
		InfoKinds.Settings = Table;
		InfoKinds.SettingItem = Table;
		
		InformationRecords.Insert(Table.UserSettingID, InfoKinds);
	EndIf;
	
	GetSettingsItemInfo(Table, InformationRecords, AdditionalProperties);
	GetCollectionInfo(Table, Table.Rows, InformationRecords, AdditionalProperties);
	GetCollectionInfo(Table, Table.Columns, InformationRecords, AdditionalProperties);
EndProcedure

Procedure GetChartInfo(Chart, InformationRecords, AdditionalProperties)
	If TypeOf(Chart) <> Type("DataCompositionChart") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Chart.UserSettingID) Then 
		InfoKinds = InfoKinds();
		InfoKinds.Settings = Chart;
		InfoKinds.SettingItem = Chart;
		
		InformationRecords.Insert(Chart.UserSettingID, InfoKinds);
	EndIf;
	
	GetSettingsItemInfo(Chart, InformationRecords, AdditionalProperties);
	GetCollectionInfo(Chart, Chart.Series, InformationRecords, AdditionalProperties);
	GetCollectionInfo(Chart, Chart.Points, InformationRecords, AdditionalProperties);
EndProcedure

Procedure GetCollectionInfo(SettingsItem, Collection, InformationRecords, AdditionalProperties)
	CollectionType = TypeOf(Collection);
	If CollectionType <> Type("DataCompositionTableStructureItemCollection")
		And CollectionType <> Type("DataCompositionChartStructureItemCollection")
		And CollectionType <> Type("DataCompositionSettingStructureItemCollection") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Collection.UserSettingID) Then 
		InfoKinds = InfoKinds();
		InfoKinds.Settings = SettingsItem;
		InfoKinds.SettingItem = Collection;
		
		InformationRecords.Insert(Collection.UserSettingID, InfoKinds);
	EndIf;
	
	For Each Item In Collection Do 
		Settings = Item;
		If TypeOf(Item) = Type("DataCompositionNestedObjectSettings") Then
			If ValueIsFilled(Item.UserSettingID) Then 
				InfoKinds = InfoKinds();
				InfoKinds.Settings = Item;
				InfoKinds.SettingItem = Item;
				
				InformationRecords.Insert(Item.UserSettingID, InfoKinds);
			EndIf;
			
			Settings = Item.Settings;
		EndIf;

		GetGroupingInfo(Settings, InformationRecords, AdditionalProperties);
		GetTableInfo(Settings, InformationRecords, AdditionalProperties);
		GetChartInfo(Settings, InformationRecords, AdditionalProperties);
	EndDo;
EndProcedure

Procedure GetSettingsItemInfo(SettingsItem, InformationRecords, AdditionalProperties)
	PropertiesIDs = SettingsPropertiesIDs(AdditionalProperties);
	AdditionalIDs = New Array;
	
	AvailableProperties = New Structure("Selection, Filter, Order, ConditionalAppearance, Structure");
	
	SettingsItemType = TypeOf(SettingsItem);
	If SettingsItemType <> Type("DataCompositionTable")
		And SettingsItemType <> Type("DataCompositionChart") Then 
		
		AdditionalIDs.Add("Filter");
		AdditionalIDs.Add("Order");
		AdditionalIDs.Add("Structure");
		
		If SettingsItemType = Type("DataCompositionSettings") Then 
			AdditionalIDs.Add("DataParameters");
		EndIf;
	EndIf;
	
	CommonClientServer.SupplementArray(PropertiesIDs, AdditionalIDs, True);
	
	For Each Id In PropertiesIDs Do 
		Property = SettingsItem[Id];
		
		If AvailableProperties.Property(Id)
			And ValueIsFilled(Property.UserSettingID) Then 
			
			InfoKinds = InfoKinds();
			InfoKinds.Settings = SettingsItem;
			InfoKinds.SettingItem = Property;
			
			InformationRecords.Insert(Property.UserSettingID, InfoKinds);
		EndIf;
		
		GetSettingsPropertyItemsInfo(SettingsItem, Property, Id, InformationRecords, AdditionalProperties);
		GetCollectionInfo(SettingsItem, Property, InformationRecords, AdditionalProperties);
	EndDo;
EndProcedure

// Adds information about filter items, parameter values, and so on.
// 
// Parameters:
//   Settings - DataCompositionSettings
//   Property - DataCompositionFilter
//            - DataCompositionDataParameterValues
//            - DataCompositionOutputParameterValues
//            - DataCompositionConditionalAppearance
//   PropertyID - String
//   InformationRecords - See InfoKinds
//   AdditionalProperties - Structure
//
Procedure GetSettingsPropertyItemsInfo(Settings, Property, PropertyID, InformationRecords, AdditionalProperties)
	PropertiesWithItems = New Structure("Filter, DataParameters, OutputParameters, ConditionalAppearance");
	If Not PropertiesWithItems.Property(PropertyID) Then 
		Return;
	EndIf;
	
	For Each Item In Property.Items Do 
		ElementType = TypeOf(Item);
		
		If ValueIsFilled(Item.UserSettingID) Then 
			LongDesc = Undefined;
			If ElementType = Type("DataCompositionFilterItem") Then 
				
				AvailableFields = Settings[PropertyID].FilterAvailableFields;
				If AvailableFields <> Undefined Then 
					LongDesc = AvailableFields.FindField(Item.LeftValue);
				EndIf;
				
			ElsIf ElementType = Type("DataCompositionParameterValue")
				Or ElementType = Type("DataCompositionSettingsParameterValue") Then 
				
				AvailableParameters = Settings[PropertyID].AvailableParameters;
				If AvailableParameters <> Undefined Then 
					LongDesc = AvailableParameters.FindParameter(Item.Parameter);
				EndIf;
			EndIf;
			
			InfoKinds = InfoKinds();
			InfoKinds.Settings = Settings;
			InfoKinds.SettingItem = Item;
			InfoKinds.SettingDetails = LongDesc;
			
			InformationRecords.Insert(Item.UserSettingID, InfoKinds);
		EndIf;
		
		If ElementType = Type("DataCompositionFilterItemGroup") Then 
			GetSettingsPropertyItemsInfo(
				Settings, Item, PropertyID, InformationRecords, AdditionalProperties);
		ElsIf ElementType = Type("DataCompositionParameterValue")
			Or ElementType = Type("DataCompositionSettingsParameterValue") Then 
			GetNestedParametersValuesInfo(
				Settings, Item.NestedParameterValues, PropertyID, InformationRecords, AdditionalProperties);
		EndIf;
	EndDo;
EndProcedure

Procedure GetNestedParametersValuesInfo(Settings, ParameterValues, PropertyID, InformationRecords, AdditionalProperties)
	For Each ParameterValue In ParameterValues Do 
		If ValueIsFilled(ParameterValue.UserSettingID) Then 
			InfoKinds = InfoKinds();
			InfoKinds.Settings = Settings;
			InfoKinds.SettingItem = ParameterValue;
			InfoKinds.SettingDetails =
				Settings[PropertyID].AvailableParameters.FindParameter(ParameterValue.Parameter);
			
			InformationRecords.Insert(ParameterValue.UserSettingID, InfoKinds);
		EndIf;
		
		GetNestedParametersValuesInfo(
			Settings, ParameterValue.NestedParameterValues, PropertyID, InformationRecords, AdditionalProperties);
	EndDo;
EndProcedure

Function SettingsPropertiesIDs(AdditionalProperties)
	DefaultPropertiesIDs = StrSplit("Selection, OutputParameters, ConditionalAppearance", ", ", False);
	
	PropertiesIDs = CommonClientServer.StructureProperty(
		AdditionalProperties,
		"SettingsPropertiesIDs",
		DefaultPropertiesIDs);
	
	Return Common.CopyRecursive(PropertiesIDs);
EndFunction

// The constructor of a user settings property index.
// 
// Returns:
//   Structure:
//   * Settings - DataCompositionSettings
//   * SettingItem - DataCompositionFilterItem
//                    - DataCompositionParameterValue
//                    - DataCompositionSelectedField
//   * SettingDetails - DataCompositionFilterAvailableField
//                     - DataCompositionAvailableParameter
//
Function InfoKinds()
	Return New Structure("Settings, SettingItem, SettingDetails");
EndFunction

// Regroup form items associated to user settings.

// Generates collections of attribute names grouped by styles: Period, CheckBox, or List.
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports
//   ItemsKinds - Array of String
//
// Returns:
//   Structure:
//     * GeneratedItems - Structure
//     * PredefinedItems1 - Structure
//
Function SettingsItemsAttributesNames(Form, ItemsKinds)
	PredefinedItemsattributesNames = New Structure;
	GeneratedItemsAttributesNames = New Structure;
	
	For Each ItemKind In ItemsKinds Do 
		PredefinedItemsattributesNames.Insert(ItemKind, New Array);
		GeneratedItemsAttributesNames.Insert(ItemKind, New Array);
	EndDo;
	
	Attributes = Form.GetAttributes();
	For Each Attribute In Attributes Do 
		For Each ItemKind In ItemsKinds Do 
			If StrStartsWith(Attribute.Name, ItemKind)
				And StringFunctionsClientServer.OnlyNumbersInString(StrReplace(Attribute.Name, ItemKind, "")) Then
				
				AttributesNamesByKinds = PredefinedItemsattributesNames[ItemKind]; // Array of String
				AttributesNamesByKinds.Add(Attribute.Name);
			EndIf;
			
			If StrStartsWith(Attribute.Name, "SettingsComposerUserSettingsItem")
				And StrEndsWith(Attribute.Name, ItemKind) Then 
				
				AttributesNamesByKinds = GeneratedItemsAttributesNames[ItemKind]; // Array of String
				AttributesNamesByKinds.Add(Attribute.Name);
			EndIf;
		EndDo;
	EndDo;
	
	AttributesNames = New Structure;
	AttributesNames.Insert("PredefinedItems1", PredefinedItemsattributesNames);
	AttributesNames.Insert("GeneratedItems", GeneratedItemsAttributesNames);
	
	Return AttributesNames;
EndFunction

Procedure PrepareFormToRegroupItems(Form, ItemsHierarchyNode, AttributesNames, StyylizedItemsKinds)
	Items = Form.Items;
	
	// Regroup predefined form items.
	PredefinedItemsProperties = StrSplit("Indent, Pickup, PasteFromClipboard1", ", ", False);
	PredefinedItemsProperties.Add("");
	
	For Each ItemKind In StyylizedItemsKinds Do 
		PredefinedAttributesNames = AttributesNames.PredefinedItems1[ItemKind];
		For Each AttributeName In PredefinedAttributesNames Do 
			For Each Property In PredefinedItemsProperties Do 
				FoundItem = Items.Find(AttributeName + Property);
				If FoundItem <> Undefined Then 
					Items.Move(FoundItem, Items.PredefinedSettingsItems);
					FoundItem.Visible = False;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// Delete dynamic form items.
	ItemsHierarchyNodes = New Array;
	ItemsHierarchyNodes.Add(ItemsHierarchyNode);
	
	FoundNode = Items.Find("More");
	If FoundNode <> Undefined Then 
		ItemsHierarchyNodes.Add(FoundNode);
	EndIf;
	
	Exceptions = New Array;
	
	FoundNode = Items.Find("PredefinedSettings");
	If FoundNode <> Undefined Then 
		Exceptions.Add(FoundNode);
	EndIf;
	
	For Each CurrentNode In ItemsHierarchyNodes Do 
		HierarchyOfItems = CurrentNode.ChildItems;
		ElementIndex = HierarchyOfItems.Count() - 1;
		While ElementIndex >= 0 Do 
			HierarchyItem = HierarchyOfItems[ElementIndex];
			If Exceptions.Find(HierarchyItem) = Undefined Then 
				Items.Delete(HierarchyItem);
			EndIf;
			ElementIndex = ElementIndex - 1;
		EndDo;
	EndDo;
EndProcedure

Procedure RegroupSettingsFormItems(Form, Val ItemsHierarchyNode, ItemsProperties, AttributesNames, StyylizedItemsKinds)
	SettingsDescription = ItemsProperties.Fields.Copy(,
		"SettingIndex, SettingID, Settings, SettingItem, SettingDetails");
	
	SettingsItems = SettingsFormItems(Form, SettingsDescription, AttributesNames);
	SetSettingsFormItemsProperties(Form, SettingsItems, ItemsProperties);
	
	If Form.ReportFormType <> ReportFormType.Settings Then 
		SettingsItems.FillValues(False, "IsList");
	EndIf;
	
	TakeListToSeparateGroup(SettingsItems, ItemsProperties);
	
	GroupsIDs = ItemsProperties.Fields.Copy();
	GroupsIDs.GroupBy("GroupID");
	GroupsIDs = GroupsIDs.UnloadColumn("GroupID");
	
	Items = Form.Items;
	
	If GroupsIDs.Count() = 1 Then 
		ItemsHierarchyNode.Group = ChildFormItemsGroup.AlwaysHorizontal;
	Else
		ItemsHierarchyNode.Group = ChildFormItemsGroup.Vertical;
	EndIf;
	
	NumberOfGroup = 0;
	For Each GroupID In GroupsIDs Do 
		NumberOfGroup = NumberOfGroup + 1;
		
		GroupProperties = Undefined;
		If Not ValueIsFilled(GroupID)
			Or Not ItemsProperties.Groups.Property(GroupID, GroupProperties) Then 
			GroupProperties = FormItemsGroupProperties();
		EndIf;
		
		FoundHierarchyNode = Items.Find(GroupID);
		If FoundHierarchyNode <> Undefined Then 
			ItemsHierarchyNode = FoundHierarchyNode;
			NumberOfGroup = 1;
		EndIf;
		
		GroupName = ItemsHierarchyNode.Name + "String" + NumberOfGroup;
		Group = Items.Find(GroupName);
		
		If Group = Undefined Then 
			Group = SettingsFormItemsGroup(Form, ItemsHierarchyNode, GroupName);
			Group.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Row %1';"), NumberOfGroup);
		EndIf;
		
		FillPropertyValues(Group, GroupProperties,, "Group, Title");
		Group.Group = ChildFormItemsGroup.AlwaysHorizontal;
		RefinePropertiesGroupNodeHierarchyElementsFormSettings(Group, GroupProperties);
		
		SearchGroupFields = New Structure("GroupID", GroupID);
		GroupFieldsProperties = ItemsProperties.Fields.FindRows(SearchGroupFields);
		GroupSettingsItems = GroupSettingsItems(SettingsItems, GroupFieldsProperties);
		
		AdditionalProperties = Form.Report.SettingsComposer.Settings.AdditionalProperties;
		PrepareSettingsFormItemsToDistribution(
			GroupSettingsItems, GroupProperties.Group, ThisIsTheMainForm(Form), AdditionalProperties);
		
		DistributeSettingsFormItems(Form, Group, GroupSettingsItems);
	EndDo;
	
	RefinePropertiesGroupsNodeHierarchyElementsFormSettings(ItemsHierarchyNode);
	
	OutputStylizedSettingsFormItems(Form, SettingsItems, SettingsDescription, AttributesNames, StyylizedItemsKinds);
	AddColumnMargins(Form, SettingsItems, ItemsHierarchyNode);
EndProcedure

Procedure RefinePropertiesGroupNodeHierarchyElementsFormSettings(Group, GroupProperties)
	
	GroupTitle = CommonClientServer.StructureProperty(GroupProperties, "Title", "");
	
	If ValueIsFilled(GroupTitle) Then 
		Group.Title = GroupTitle;
	EndIf;
	
	If Group.Behavior = UsualGroupBehavior.Usual Then 
		Return;
	EndIf;
	
	Group.ShowTitle = True;
	
	GroupCollapsed = CommonClientServer.StructureProperty(GroupProperties, "Collapsed_", False);
	
	If GroupCollapsed Then 
		Group.Hide();
	Else
		Group.Show();
	EndIf;
	
EndProcedure

Procedure RefinePropertiesGroupsNodeHierarchyElementsFormSettings(ItemsHierarchyNode)
	
	BehaviorOverridden = BehaviorGroupsNodeHierarchyElementsFormSettingsOverridden(ItemsHierarchyNode);
	
	If Not BehaviorOverridden Then 
		Return;
	EndIf;
	
	For Each Group In ItemsHierarchyNode.ChildItems Do 
		Group.United = True;
	EndDo;
	
EndProcedure

Function BehaviorGroupsNodeHierarchyElementsFormSettingsOverridden(ItemsHierarchyNode)
	
	For Each Group In ItemsHierarchyNode.ChildItems Do 
		
		If ValueIsFilled(Group.ToolTip)
			Or ValueIsFilled(Group.Height)
			Or ValueIsFilled(Group.Width)
			Or Group.VerticalStretch <> Undefined
			Or Group.HorizontalStretch <> Undefined
			Or Group.Behavior <> UsualGroupBehavior.Usual Then 
			
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Procedure AddColumnMargins(Form, SettingsItems, ItemsHierarchyNode)
	
	If Not ThisIsTheMainForm(Form) Then 
		Return;
	EndIf;
	
	ReportSettings = Form.ReportSettings;
	
	If ReportSettings.Events.OnDefineSettingsFormItemsProperties Then 
		Return;
	EndIf;
	
	Items = Form.Items;
	
	Statistics = SettingsItems.Copy();
	Statistics.GroupBy("SettingIndex");
	
	If Statistics.Count() < 2 Then 
		Return;
	EndIf;
	
	ChildItems = ItemsHierarchyNode.ChildItems;
	ColumnsCount = ChildItems.Count();
	
	For ColumnNumber = 2 To ColumnsCount Do 
		
		Column = ChildItems[ColumnNumber - 1];
		
		GroupName = ItemsHierarchyNode.Name + "ColumnFields" + ColumnNumber;
		ColumnFieldGroup = SettingsFormItemsGroup(Form, ItemsHierarchyNode, GroupName);
		
		ColumnFieldGroup.Group = Column.Group;
		ColumnFieldGroup.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'The %1 column fields';"), ColumnNumber);
		
		ColumnFields = Column.ChildItems;
		NumberOfColumnFields = ColumnFields.Count();
		
		For FieldNumber = 1 To NumberOfColumnFields Do 
			Items.Move(ColumnFields[0], ColumnFieldGroup);
		EndDo;
		
		Column.Group = ChildFormItemsGroup.AlwaysHorizontal;
		
		IndentName = ItemsHierarchyNode.Name + "ColumnMarginIndentation" + ColumnNumber;
		Indent = Items.Add(IndentName, Type("FormDecoration"), Column);
		Indent.Title = "  ";
		
		Items.Move(ColumnFieldGroup, Column);
		
	EndDo;
	
EndProcedure

// Searching setting form items created by the system and preparing them for distribution.

Function SettingsFormItems(Form, SettingsDescription, AttributesNames)
	Items = Form.Items;
	
	SettingsItems = SettingsItemsCollectionPalette();
	FindSettingsFormItems(Form, Items.Temporary, SettingsItems, SettingsDescription);
	DeleteCheckBoxValueElements(SettingsItems);
	
	SummaryInfo = SettingsItems.Copy();
	SummaryInfo.GroupBy("SettingIndex", "Checksum");
	IncompleteItems = SummaryInfo.FindRows(New Structure("Checksum", 1));
	
	Search = New Structure("SettingIndex, SettingProperty");
	CommonProperties = "IsPeriod, IsFlag, IsList, ValueType, ChoiceForm, AvailableValues, SettingID";
	
	For Each Record In IncompleteItems Do 
		Item = SettingsItems.Find(Record.SettingIndex, "SettingIndex");
		Item.Field.TitleLocation = FormItemTitleLocation.None;
		
		SourceProperty = "Value";
		LinkedProperty = "Use";
		If StrEndsWith(Item.Field.Name, LinkedProperty) Then 
			SourceProperty = "Use";
			LinkedProperty = "Value";
		EndIf;
		
		AdditionalItemName = StrReplace(Item.Field.Name, Item.SettingProperty, LinkedProperty);
		
		ItemGroup = Item.Field.Parent;
		If Items.Find(AdditionalItemName) <> Undefined
			Or ItemGroup.ChildItems.Find(AdditionalItemName) <> Undefined Then 
			
			If Item.IsFlag Then 
				AdditionalItemName = AdditionalItemName + "Additional";
			Else
				Continue;
			EndIf;
		EndIf;
		
		AdditionalItem = Items.Add(AdditionalItemName, Type("FormDecoration"), ItemGroup);
		AdditionalItem.Title = Item.Field.Title;
		AdditionalItem.AutoMaxHeight = False;
		
		AdditionalRecord = SettingsItems.Add();
		AdditionalRecord.Field = AdditionalItem;
		AdditionalRecord.SettingIndex = Record.SettingIndex;
		AdditionalRecord.SettingProperty = LinkedProperty;
		AdditionalRecord.Checksum = 1;
		
		Search.SettingIndex = Record.SettingIndex;
		Search.SettingProperty = SourceProperty;
		LinkedItems1 = SettingsItems.FindRows(Search);
		FillPropertyValues(AdditionalRecord, LinkedItems1[0], CommonProperties);
	EndDo;
	
	FindValuesAsCheckBoxes(Form, SettingsItems, AttributesNames);
	
	SettingsItems.Sort("SettingIndex");
	
	Return SettingsItems;
EndFunction

Function SettingsItemsCollectionPalette()
	NumberDetails = New TypeDescription("Number");
	RowDescription = New TypeDescription("String");
	FlagDetails = New TypeDescription("Boolean");
	
	SettingsItems = New ValueTable;
	SettingsItems.Columns.Add("Order", NumberDetails);
	SettingsItems.Columns.Add("SettingIndex", NumberDetails);
	SettingsItems.Columns.Add("SettingProperty", RowDescription);
	SettingsItems.Columns.Add("Field");
	SettingsItems.Columns.Add("SettingID", RowDescription);
	SettingsItems.Columns.Add("IsPeriod", FlagDetails);
	SettingsItems.Columns.Add("IsList", FlagDetails);
	SettingsItems.Columns.Add("IsFlag", FlagDetails);
	SettingsItems.Columns.Add("IsValueAsCheckBox", FlagDetails);
	SettingsItems.Columns.Add("ValueType");
	SettingsItems.Columns.Add("ChoiceForm", RowDescription);
	SettingsItems.Columns.Add("AvailableValues");
	SettingsItems.Columns.Add("Checksum", NumberDetails);
	SettingsItems.Columns.Add("ColumnNumber", NumberDetails);
	SettingsItems.Columns.Add("NumberOfGroup", NumberDetails);
	
	Return SettingsItems;
EndFunction

// Searches for form items linked to the report user settings
// created with the CreateUserSettingsFormItems method.
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports:
//     * Items - FormAllItems
//     * Report - ReportObject
//   Items_Group - FormGroup
//   SettingsItems - See SettingsItemsCollectionPalette
//   SettingsDescription - ValueTable
//
Procedure FindSettingsFormItems(Form, Items_Group, SettingsItems, SettingsDescription)
	UserSettings = Form.Report.SettingsComposer.UserSettings.Items;
	
	MainProperties = New Structure("Use, Value");
	For Each Item In Items_Group.ChildItems Do 
		If TypeOf(Item) = Type("FormGroup") Then 
			FindSettingsFormItems(Form, Item, SettingsItems, SettingsDescription);
		ElsIf TypeOf(Item) = Type("FormField") Then 
			SettingProperty = Undefined;
			SettingIndex = ReportsClientServer.SettingItemIndexByPath(Item.Name, SettingProperty);
			
			ItemSettingDetails = SettingsDescription.Find(SettingIndex, "SettingIndex");
			If ItemSettingDetails = Undefined Then 
				Continue;
			EndIf;
			
			Record = SettingsItems.Add();
			Record.SettingIndex = SettingIndex;
			Record.SettingProperty = SettingProperty;
			Record.Field = Item;
			Record.SettingID = ItemSettingDetails.SettingID;
			
			SettingItem = ItemSettingDetails.SettingItem;
			SettingDetails = ItemSettingDetails.SettingDetails;
			
			If SettingDetails <> Undefined Then 
				FillPropertyValues(Record, SettingDetails, "ValueType, ChoiceForm, AvailableValues");
			EndIf;
			
			If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
				Record.IsPeriod = TypeOf(SettingItem.Value) = Type("StandardPeriod");
				Record.IsList = SettingDetails <> Undefined And SettingDetails.ValueListAllowed;
			ElsIf TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
				Record.IsPeriod = TypeOf(SettingItem.RightValue) = Type("StandardPeriod");
				Record.IsFlag = ValueIsFilled(SettingItem.Presentation)
					Or SettingItem.ComparisonType = DataCompositionComparisonType.Filled
					Or SettingItem.ComparisonType = DataCompositionComparisonType.NotFilled;
				
				UserSettingItem = UserSettings.Find(
					ItemSettingDetails.SettingID);
				
				Record.IsList = Not Record.IsFlag
					And ReportsClientServer.IsListComparisonKind(UserSettingItem.ComparisonType);
			ElsIf TypeOf(SettingItem) = Type("DataCompositionConditionalAppearanceItem") Then 
				Record.IsFlag = ValueIsFilled(SettingItem.Presentation)
					Or ValueIsFilled(SettingItem.UserSettingPresentation);
			EndIf;
			
			If MainProperties.Property(Record.SettingProperty) Then 
				Record.Checksum = 1;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Procedure DeleteCheckBoxValueElements(SettingsItems)
	Search = New Structure("SettingProperty, IsFlag", "Value", True);
	FoundItems1 = SettingsItems.FindRows(Search);
	
	For Each Item In FoundItems1 Do 
		SettingsItems.Delete(Item);
	EndDo;
EndProcedure

Procedure FindValuesAsCheckBoxes(Form, SettingsItems, AttributesNames)
	Search = New Structure;
	Search.Insert("ValueType", New TypeDescription("Boolean"));
	FoundItems1 = SettingsItems.Copy(Search);
	FoundItems1.GroupBy("SettingIndex, ValueType", "Checksum");
	
	FoundItems1 = FoundItems1.FindRows(New Structure("Checksum", 2));
	If FoundItems1.Count() = 0 Then 
		Return;
	EndIf;
	
	Search = New Structure("SettingProperty, SettingIndex");
	For Each Item In FoundItems1 Do 
		Search.SettingProperty = "Use";
		Search.SettingIndex = Item.SettingIndex;
		
		CheckBoxItem = SettingsItems.FindRows(Search);
		If CheckBoxItem.Count() = 0 Then 
			Continue;
		EndIf;
		
		CheckBoxItem = CheckBoxItem[0];
		
		If TypeOf(CheckBoxItem.AvailableValues) = Type("ValueList")
			And CheckBoxItem.AvailableValues.Count() > 0 Then 
			Continue;
		EndIf;
		
		If TypeOf(CheckBoxItem.Field) <> Type("FormDecoration") Then 
			Continue;
		EndIf;
		
		Search.SettingProperty = "Value";
		
		ItemValue1 = SettingsItems.FindRows(Search);
		If ItemValue1.Count() = 0 Then 
			Continue;
		EndIf;
		
		CheckBoxItem.SettingProperty = "Value";
		CheckBoxItem.IsFlag = True;
		CheckBoxItem.IsValueAsCheckBox = True;
		
		ItemValue1 = ItemValue1[0];
		ItemValue1.SettingProperty = "Use";
		ItemValue1.IsFlag = True;
		ItemValue1.IsValueAsCheckBox = True;
		ItemValue1.Field.Visible = False;
	EndDo;
EndProcedure

// If necessary, overrides properties of form items linked to the following settings:
// Visibility, Width, HorizontalStretch, and so on.
// 
// Parameters:
//  Form - ClientApplicationForm
//        - ManagedFormExtensionForReports:
//    * Report - ReportObject
//  SettingsItems - See SettingsItemsCollectionPalette
//  ItemsProperties - Structure:
//    * Groups - Structure
//    * Fields - ValueTable
//
Procedure SetSettingsFormItemsProperties(Form, SettingsItems, ItemsProperties)
		SettingsComposer = Form.Report.SettingsComposer;
	
#Region SetItemsPropertiesUsage
	
	Exceptions = New Array;
	Exceptions.Add(DataCompositionComparisonType.Equal);
	Exceptions.Add(DataCompositionComparisonType.Contains);
	Exceptions.Add(DataCompositionComparisonType.Filled);
	Exceptions.Add(DataCompositionComparisonType.Like);
	Exceptions.Add(DataCompositionComparisonType.InList);
	Exceptions.Add(DataCompositionComparisonType.InListByHierarchy);
	
	FoundItems1 = SettingsItems.FindRows(New Structure("SettingProperty", "Use"));
	For Each Item In FoundItems1 Do 
		Field = Item.Field; // FormField
		FieldProperties = ItemsProperties.Fields.Find(Item.SettingIndex, "SettingIndex");
		
		If ValueIsFilled(FieldProperties.Presentation) Then 
			Field.Title = FieldProperties.Presentation;
		EndIf;
		
		If TypeOf(Field) = Type("FormField") Then 
			Field.TitleLocation = FormItemTitleLocation.Right;
			Field.SetAction("OnChange", "Attachable_SettingItem_OnChange");
		ElsIf TypeOf(Field) = Type("FormDecoration") Then 
			Field.Visible = True;
		EndIf;
		
		If StrLen(Field.Title) > 40 Then
			Field.TitleHeight = 2;
		EndIf;
		
		SettingItem = FieldProperties.SettingItem;
		If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
			Field.Title = Field.Title + ":";
		ElsIf TypeOf(SettingItem) = Type("DataCompositionFilterItem") Then 
			
			Condition = SettingItem.ComparisonType;
			If ValueIsFilled(SettingItem.UserSettingID) Then 
				
				UserSettingItem = SettingsComposer.UserSettings.Items.Find(
					SettingItem.UserSettingID);
				
				If UserSettingItem <> Undefined Then 
					Condition = UserSettingItem.ComparisonType;
				EndIf;
			EndIf;
			
			If Exceptions.Find(Condition) <> Undefined Then 
				Field.Title = Field.Title + ":";
			ElsIf Not ValueIsFilled(SettingItem.Presentation) Then 
				Field.Title = Field.Title + " (" + Lower(Condition) + "):";
			EndIf;
		EndIf;
	EndDo;
	
#EndRegion
	
#Region SetItemsPropertiesSettingsItems
	
	FoundItems1 = SettingsItems.FindRows(New Structure("SettingProperty", "ComparisonType"));
	For Each Item In FoundItems1 Do
		Field = Item.Field; // FormField 
		Field.Visible = False;
	EndDo;
	
#EndRegion
	
#Region SetItemsPropertiesValue
	
	LinkedItems1 = SettingsItems.Copy(New Structure("SettingProperty", "Use"));
	
	PickingParameters = New Map;
	ExtendedTypesDetails = New Map;
	
	FoundItems1 = SettingsItems.FindRows(New Structure("SettingProperty", "Value"));
	For Each Item In FoundItems1 Do 
		Field = Item.Field; // FormField
		
		LinkedItem1 = LinkedItems1.Find(Item.SettingIndex, "SettingIndex");
		LinkedField = LinkedItem1.Field; // FormField
		
		If TypeOf(Field) = Type("FormDecoration") Then 
			If StrEndsWith(LinkedField.Title, ":") Then 
				LinkedField.Title = Left(LinkedField.Title, StrLen(LinkedField.Title) - 1);
			EndIf;
			
			LinkedField.TitleLocation = FormItemTitleLocation.None;
			Field.Title = LinkedField.Title;
		Else // Input field.
			FieldProperties = ItemsProperties.Fields.Find(Item.SettingIndex, "SettingIndex");
			FillPropertyValues(Field, FieldProperties,, "TitleLocation");
			
			If ThisIsTheMainForm(Form) And Not OutputSettingsTitles(Form) Then 
				If StrEndsWith(LinkedField.Title, ":") Then 
					Title = Left(LinkedField.Title, StrLen(LinkedField.Title) - 1);
				Else
					Title = LinkedField.Title;
				EndIf;
				
				Field.InputHint = Title;
				Field.ToolTip = Field.InputHint;
			Else
				Field.TitleLocation = FormItemTitleLocation.Auto;
			EndIf;
			
			If TypeOf(LinkedField) = Type("FormDecoration") Then 
				LinkedField.Title = " ";
			Else
				LinkedField.TitleLocation = FormItemTitleLocation.None;
				LinkedField.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
			EndIf;
			
			If Item.IsFlag Then 
				Field.Visible = False;
				Continue;
			EndIf;
			
			Field.SetAction("OnChange", "Attachable_SettingItem_OnChange");
			If Item.IsList Then
				Field.SetAction("StartChoice", "Attachable_SettingItemStartChoice");
			EndIf;
			
			Field.ChoiceForm = Item.ChoiceForm;
			If ValueIsFilled(Field.ChoiceForm) Then 
				PickingParameters.Insert(Item.SettingIndex, Field.ChoiceForm);
			EndIf;
			
			Result = CommonClientServer.SupplementList(Field.ChoiceList, Item.AvailableValues, False, True);
			Field.ListChoiceMode = Not Item.IsList And Result.Total > 0;
			
			If Field.HorizontalStretch = Undefined Then
				Field.HorizontalStretch = True;
				Field.AutoMaxWidth = False;
				Field.MaxWidth = 40;
			EndIf;
			
			If Item.ValueType = Undefined Then 
				Continue;
			EndIf;
			
			ExtendedTypeDetails = ExtendedTypesDetails(Item.ValueType, True, PickingParameters);
			ExtendedTypesDetails.Insert(Item.SettingIndex, ExtendedTypeDetails);
			
			Field.AvailableTypes = ExtendedTypeDetails.TypesDetailsForForm;
			Field.TypeRestriction = ExtendedTypeDetails.TypesDetailsForForm;
			
			If StrLen(Field.Title) > 40 Then
				Field.TitleHeight = 2;
			EndIf;
			
			If ExtendedTypeDetails.TypesCount = 1 Then 
				If ExtendedTypeDetails.ContainsNumberType Then 
					Field.ChoiceButton = Field.ChoiceList.Count() = 0 Or Item.IsList;
					If Field.HorizontalStretch = True Then
						Field.HorizontalStretch = False;
					EndIf;
				ElsIf ExtendedTypeDetails.ContainsDateType Then 
					Field.MaxWidth = 25;
				ElsIf ExtendedTypeDetails.ContainsBooleanType Then 
					If Field.ChoiceList.Count() = 0 Then 
						Field.MaxWidth = 5;
					Else
						Field.HorizontalStretch = False;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	AdditionalProperties = SettingsComposer.Settings.AdditionalProperties;
	AdditionalProperties.Insert("PickingParameters", PickingParameters);
	AdditionalProperties.Insert("ExtendedTypesDetails", ExtendedTypesDetails);
	
#EndRegion
EndProcedure

Function OutputSettingsTitles(Form)
	
	FormAttributes = Form.GetAttributes();
	NameOfSoughtAttribute = "OutputSettingsTitles";
	
	For Each Attribute In FormAttributes Do 
		
		If Attribute.Name = NameOfSoughtAttribute Then 
			Return Form[NameOfSoughtAttribute];
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

// Allocates a group for a list that refers to a setting with a comparison type:
// InList, NotInList, and so on.
// 
// Parameters:
//   SettingsItems - See SettingsItemsCollectionPalette
//   ItemsProperties - Structure:
//   * Groups - Structure
//   * Fields - ValueTable
//
Procedure TakeListToSeparateGroup(SettingsItems, ItemsProperties)
	Search = New Structure("IsList", True);
	Statistics = SettingsItems.Copy(Search);
	Statistics.GroupBy("SettingIndex");
	
	If Statistics.Count() <> 1 Then 
		Return;
	EndIf;
	
	SettingIndex = SettingsItems.FindRows(Search)[0].SettingIndex;
	FieldProperties = ItemsProperties.Fields.Find(SettingIndex, "SettingIndex");
	If ValueIsFilled(FieldProperties.GroupID) Then 
		Return;
	EndIf;
	
	GroupID = "_" + StrReplace(New UUID, "-", "");
	FieldProperties.GroupID = GroupID;
	ItemsProperties.Groups.Insert(GroupID, FormItemsGroupProperties());
EndProcedure

Function GroupSettingsItems(SettingsItems, GroupFieldsProperties)
	GroupSettingsItems = SettingsItems.CopyColumns();
	
	Search = New Structure("SettingIndex");
	For Each Properties In GroupFieldsProperties Do 
		Search.SettingIndex = Properties.SettingIndex;
		FoundItems1 = SettingsItems.FindRows(Search);
		For Each Item In FoundItems1 Do 
			FillPropertyValues(GroupSettingsItems.Add(), Item);
		EndDo;
	EndDo;
	
	Return GroupSettingsItems;
EndFunction

// Distributing setting form items in the hierarchy.

Procedure PrepareSettingsFormItemsToDistribution(SettingsItems, Group, ThisIsTheMainForm, AdditionalProperties)
#Region BeforePreparation
	
	Statistics = SettingsItems.Copy();
	Statistics.GroupBy("SettingIndex");
	
 	ColumnsCount = 1;
	If Group = ChildFormItemsGroup.HorizontalIfPossible Then 
		ColumnsCount = Min(?(ThisIsTheMainForm, 3, 2), Statistics.Count());
	ElsIf Group = ChildFormItemsGroup.AlwaysHorizontal Then 
		ColumnsCount = Statistics.Count();
	EndIf;
	ColumnsCount = Max(1, ColumnsCount);
	
	ArrangeTheElementsOfTheSettingsForm(SettingsItems, AdditionalProperties);
	
#EndRegion
	
#Region SetColumnsNumbers
	
	Statistics = SettingsItems.Copy();
	Statistics.GroupBy("Order, SettingIndex");
	
	ItemCount = Statistics.Count();
	IndexOf = 0;
	PropertiesBorder = ItemCount - 1;
	
	Step = ItemCount / ColumnsCount;
	BreakBoundary = ?(ItemCount % ColumnsCount = 0, Step - 1, Int(Step));
	Step = ?(BreakBoundary = 0, 1, Round(Step));
	
	Search = New Structure("SettingIndex");
	For ColumnNumber = 1 To ColumnsCount Do 
		While IndexOf <= BreakBoundary Do 
			Search.SettingIndex = Statistics[IndexOf].SettingIndex;
			FoundItems1 = SettingsItems.FindRows(Search);
			For Each Item In FoundItems1 Do 
				Item.ColumnNumber = ColumnNumber;
			EndDo;
			IndexOf = IndexOf + 1;
		EndDo;
		
		BreakBoundary = BreakBoundary + Step;
		If BreakBoundary > PropertiesBorder Then 
			BreakBoundary = PropertiesBorder;
		EndIf;
	EndDo;
	
	DistributeListsByColumnsProportionally(SettingsItems, ColumnsCount);
	
#EndRegion
	
#Region SetGroupsNumbers
	
	SearchOptions = New Array;
	SearchOptions.Add(New Structure("NumberOfGroup, IsFlag, IsList", 0, False, False));
	SearchOptions.Add(New Structure("NumberOfGroup, IsFlag, IsList", 0, True, False));
	SearchOptions.Add(New Structure("NumberOfGroup, IsFlag, IsList", 0, False, True));
	
	NumberOfGroup = 1;
	For Each Search In SearchOptions Do 
		FoundItems1 = SettingsItems.FindRows(Search);
		
		Previous_Index = Undefined;
		For Each Item In FoundItems1 Do 
			If Item.IsFlag Or Item.IsList Then 
				IndexOf = Item.SettingIndex;
			Else
				IndexOf = SettingsItems.IndexOf(Item);
			EndIf;
			
			If Previous_Index = Undefined Then 
				Previous_Index = IndexOf;
			EndIf;
			
			If ((Item.IsFlag Or Item.IsList) And IndexOf <> Previous_Index)
				Or (Not Item.IsFlag And Not Item.IsList And IndexOf > Previous_Index + 1) Then 
				NumberOfGroup = NumberOfGroup + 1;
			EndIf;
			
			Item.NumberOfGroup = NumberOfGroup;
			Previous_Index = IndexOf;
		EndDo;
		
		NumberOfGroup = NumberOfGroup + 1;
	EndDo;
	
#EndRegion
EndProcedure

Procedure ArrangeTheElementsOfTheSettingsForm(SettingsItems, AdditionalProperties)
	
	TheOrderOfTheSettingsElements = CommonClientServer.StructureProperty(
		AdditionalProperties, "TheOrderOfTheSettingsElements", New Map);
	
	Search = New Structure("SettingID");
	
	If TheOrderOfTheSettingsElements.Count() = 0 Then 
		
		FoundItems1 = SettingsItems.FindRows(New Structure("IsPeriod", True));
		
		For Each Item In FoundItems1 Do 
			Item.Order = -1;
		EndDo;
		
		Order = 0;
		
	Else
		
		For Each TheOrderOfTheElement In TheOrderOfTheSettingsElements Do 
			
			Search.SettingID = TheOrderOfTheElement.Key;
			FoundItems1 = SettingsItems.FindRows(Search);
			
			For Each Item In FoundItems1 Do 
				Item.Order = TheOrderOfTheElement.Value;
			EndDo;
			
		EndDo;
		
		IndexOfSettingsElements = SettingsItems.Copy();
		IndexOfSettingsElements.GroupBy("Order, SettingID");
		IndexOfSettingsElements.Sort("Order");
		
		Boundary = IndexOfSettingsElements.Count() - 1;
		Order = ?(Boundary >= 0, IndexOfSettingsElements[Boundary].Order, 0);
		
	EndIf;
	
	For Each Item In SettingsItems Do 
		
		If Item.Order <> 0 Then 
			Continue;
		EndIf;
		
		Order = Order + 1;
		
		Search.SettingID = Item.SettingID;
		LinkedItems1 = SettingsItems.FindRows(Search);
		
		For Each LinkedItem1 In LinkedItems1 Do 
			LinkedItem1.Order = Order;
		EndDo;
		
	EndDo;
	
	SettingsItems.Sort("Order, SettingIndex");
	
	CurrentOrderOfSettingsElements = SettingsItems.Copy();
	CurrentOrderOfSettingsElements.GroupBy("Order, SettingID");
	
	For Each TheOrderOfTheElement In CurrentOrderOfSettingsElements Do 
		TheOrderOfTheSettingsElements.Insert(TheOrderOfTheElement.SettingID, TheOrderOfTheElement.Order);
	EndDo;
	
	AdditionalProperties.Insert("TheOrderOfTheSettingsElements", TheOrderOfTheSettingsElements);
	
EndProcedure

Procedure DistributeListsByColumnsProportionally(SettingsItems, ColumnsCount)
	If ColumnsCount <> 2
		Or SettingsItems.Find(True, "IsList") = Undefined Then 
		Return;
	EndIf;
	
	NumberDetails = New TypeDescription("Number");
	
	Statistics = SettingsItems.Copy();
	Statistics.GroupBy("SettingIndex, IsList, ColumnNumber");
	Statistics.Columns.Add("ListsCount", NumberDetails);
	
	For Each Item In Statistics Do 
		Item.ListsCount = Number(Item.IsList);
	EndDo;
	
	Statistics.GroupBy("ColumnNumber", "ListsCount");
	
	ListsCount = Statistics.Total("ListsCount");
	If ListsCount = 1 Then 
		Return;
	EndIf;
	
	Statistics.Sort("ListsCount");
	
	Mean = Round(ListsCount / Statistics.Count(), 0, RoundMode.Round15as10);
	Receiver = Statistics[0];
	Source = Statistics[Statistics.Count() - 1];
	
	Deviation = Mean - Receiver.ListsCount;
	If Deviation = 0 Then 
		Return;
	EndIf;
	
	Search = New Structure("IsList, ColumnNumber", True, Source.ColumnNumber);
	SourceItems = SettingsItems.Copy(Search);
	SourceItems.GroupBy("SettingIndex");
	If Receiver.ColumnNumber > Source.ColumnNumber Then 
		SourceItems.Sort("SettingIndex Desc");
	EndIf;
	
	Deviation = Min(Deviation, SourceItems.Count());
	Search = New Structure("SettingIndex");
	
	IndexOf = 0;
	While Deviation > 0 Do 
		Search.SettingIndex = SourceItems[IndexOf].SettingIndex;
		LinkedItems1 = SettingsItems.FindRows(Search);
		For Each Item In LinkedItems1 Do 
			Item.ColumnNumber = Receiver.ColumnNumber;
		EndDo;
		
		IndexOf = IndexOf + 1;
		Deviation = Deviation - 1;
	EndDo;
EndProcedure

Procedure DistributeSettingsFormItems(Form, Val Group, SettingsItems)
	ColumnsCount = 0;
	If SettingsItems.Count() > 0 Then 
		ColumnsCount = SettingsItems[SettingsItems.Count() - 1].ColumnNumber;
	EndIf;
	
	Items = Form.Items;
	
	For ColumnNumber = 1 To ColumnsCount Do 
		ItemsFlags = SettingsItems.Copy(New Structure("ColumnNumber", ColumnNumber));
		ItemsFlags.GroupBy("IsFlag, IsList, NumberOfGroup");
		
		InputFieldsOnly = ItemsFlags.Find(True, "IsFlag") = Undefined
			And ItemsFlags.Find(True, "IsList") = Undefined;
		
		ColumnName = Group.Name + "Column" + ColumnNumber;
		Column = ?(ColumnsCount = 1, Group, Items.Find(ColumnName));
		If Column = Undefined Then 
			Column = SettingsFormItemsGroup(Form, Group, ColumnName);
			Column.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Column %1';"), ColumnNumber);
			
			If InputFieldsOnly Then 
				Column.Group = ChildFormItemsGroup.AlwaysHorizontal;
			EndIf;
		EndIf;
		
		If ColumnNumber > 1 Then 
			Column.Representation = UsualGroupRepresentation.NormalSeparation;
		EndIf;
		
		If InputFieldsOnly Then 
			DistributeSettingsFormItemsByProperties(Form, Column, SettingsItems, ColumnNumber);
			Continue;
		EndIf;
		
		LineNumber = 0;
		For Each Signs In ItemsFlags Do 
			LineNumber = LineNumber + 1;
			Parent = SettingsFormItemsHierarchy(Form, Column, Signs, LineNumber, ColumnNumber);
			
			DistributeSettingsFormItemsByProperties(Form, Parent, SettingsItems, ColumnNumber, Signs.NumberOfGroup);
		EndDo;
	EndDo;
EndProcedure

Procedure DistributeSettingsFormItemsByProperties(Form, Parent, SettingsItems, ColumnNumber, NumberOfGroup = Undefined)
	Items = Form.Items;
	
	SettingsProperties = StrSplit("Use, ComparisonType, Value", ", ", False);
	For Each SettingProperty In SettingsProperties Do 
		GroupName = Parent.Name + SettingProperty;
		Group = SettingsFormItemsGroup(Form, Parent, GroupName);
		Group.Title = SettingProperty;
		Group.Visible = (SettingProperty <> "ComparisonType");
		
		Search = New Structure("SettingProperty, ColumnNumber", SettingProperty, ColumnNumber);
		If NumberOfGroup <> Undefined Then 
			Search.Insert("NumberOfGroup", NumberOfGroup);
		EndIf;
		
		FoundItems1 = SettingsItems.FindRows(Search);
		For Each Item In FoundItems1 Do 
			Group.United = SettingProperty = "Use" And Item.IsList;
			Items.Move(Item.Field, Group);
		EndDo;
	EndDo;
EndProcedure

Function SettingsFormItemsHierarchy(Form, Parent, Signs, LineNumber, ColumnNumber)
	RowName = Parent.Name + "String" + LineNumber;
	String = SettingsFormItemsGroup(Form, Parent, RowName);
	String.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Row %1.%2';"), ColumnNumber, LineNumber);
	
	If Not Signs.IsList Then 
		String.Group = ChildFormItemsGroup.AlwaysHorizontal;
	EndIf;
	
	If Signs.IsFlag Or Signs.IsList Then 
		Return String;
	EndIf;
	
	ColumnName = String.Name + "Column1";
	Column = SettingsFormItemsGroup(Form, String, ColumnName);
	Column.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Column %1.%2.1';"), ColumnNumber, LineNumber);
	
	Column.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	Return Column;
EndFunction

Function SettingsFormItemsGroup(Form, Parent, GroupName)
	Items = Form.Items;
	
	Group = Items.Find(GroupName);
	If Group <> Undefined Then 
		Return Group;
	EndIf;
	
	Group = Items.Add(GroupName, Type("FormGroup"), Parent);
	Group.Type = FormGroupType.UsualGroup;
	Group.ShowTitle = False;
	Group.Representation = UsualGroupRepresentation.None;
	Group.Behavior = UsualGroupBehavior.Usual;
	Group.Group = ChildFormItemsGroup.Vertical;
	
	If ThisIsTheMainForm(Form) And Not OutputSettingsTitles(Form) Then 
		Group.United = False;
	EndIf;
	
	Return Group;
EndFunction

Function ThisIsTheMainForm(Form)
	
	Return (Form.ReportFormType = ReportFormType.Main);
	
EndFunction

// Output stylized setting form items.

Procedure OutputStylizedSettingsFormItems(Form, SettingsItems, SettingsDescription, AttributesNames, ItemsKinds)
	// Change attributes.
	PathToItemsData = New Structure("ByName, ByIndex", New Map, New Map);
	
	AttributesToAdd = DetailsOfTheSettingsElementsToBeAdded(SettingsItems, ItemsKinds, AttributesNames, PathToItemsData);
	AttributesToDelete = DetailsOfTheSettingsElementsToBeDeleted(ItemsKinds, AttributesNames, PathToItemsData);
	
	Form.ChangeAttributes(AttributesToAdd, AttributesToDelete);
	DeleteSettingsItemsCommands(Form, AttributesToDelete);
	
	Form.PathToItemsData = PathToItemsData;
	
	// Change items.
	OutputSettingsPeriods(Form, SettingsItems, AttributesNames);
	OutputSettingsLists(Form, SettingsItems, SettingsDescription, AttributesNames);
	OutputValuesAsCheckBoxesFields(Form, SettingsItems, AttributesNames);
EndProcedure

Function DetailsOfTheSettingsElementsToBeAdded(SettingsItems, ItemsKinds, AttributesNames, PathToItemsData)
	AttributesToAdd = New Array;
	
	ItemsTypes = New Structure;
	ItemsTypes.Insert("Period", New TypeDescription("StandardPeriod"));
	ItemsTypes.Insert("List", New TypeDescription("ValueList"));
	ItemsTypes.Insert("CheckBox", New TypeDescription("Boolean"));
	
	ItemsKindsIndicators = New Structure("Period, List, CheckBox", "IsPeriod", "IsList", "IsValueAsCheckBox");
	ItemsKindsProperties = New Structure("Period, List, CheckBox", "Value", "Value", "Use");
	
	For Each ItemKind In ItemsKinds Do 
		Flag = ItemsKindsIndicators[ItemKind];
		
		Generated = AttributesNames.GeneratedItems[ItemKind];
		Predefined = AttributesNames.PredefinedItems1[ItemKind];
		
		PredefinedItemsIndex = -1;
		PredefinedItemsBorder = Predefined.UBound();
		
		Search = New Structure;
		Search.Insert(Flag, True);
		Search.Insert("SettingProperty", "Value");
		
		FoundItems1 = SettingsItems.Copy(Search);
		For Each Item In FoundItems1 Do 
			If PredefinedItemsBorder >= FoundItems1.IndexOf(Item) Then 
				PredefinedItemsIndex = PredefinedItemsIndex + 1;
				PathToItemsData.ByName.Insert(Predefined[PredefinedItemsIndex], Item.SettingIndex);
				PathToItemsData.ByIndex.Insert(Item.SettingIndex, Predefined[PredefinedItemsIndex]);
				Continue;
			EndIf;
			
			Field = Item.Field; // FormField
			ItemTitle = Field.Title;
			If StrEndsWith(Field.Name, ItemsKindsProperties[ItemKind]) Then
				Position = StrFind(Field.Name, ItemsKindsProperties[ItemKind], SearchDirection.FromEnd);
				ItemNameTemplate = Left(Field.Name, Position - 1) + "%1";
			Else
				ItemNameTemplate = Field.Name;
			EndIf;
			
			AttributeName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, ItemKind);
			If Generated.Find(AttributeName) = Undefined Then 
				ElementType = Item.ValueType;
				ItemsTypes.Property(ItemKind, ElementType);
				
				AttributesToAdd.Add(New FormAttribute(AttributeName, ElementType,, ItemTitle));
			EndIf;
			
			PathToItemsData.ByName.Insert(AttributeName, Item.SettingIndex);
			PathToItemsData.ByIndex.Insert(Item.SettingIndex, AttributeName);
		EndDo;
	EndDo;
	
	Return AttributesToAdd;
EndFunction

Function DetailsOfTheSettingsElementsToBeDeleted(ItemsKinds, AttributesNames, PathToItemsData)
	AttributesToDelete = New Array;
	
	For Each ItemKind In ItemsKinds Do 
		Generated = AttributesNames.GeneratedItems[ItemKind];
		For Each AttributeName In Generated Do 
			If PathToItemsData.ByName[AttributeName] = Undefined Then 
				AttributesToDelete.Add(AttributeName);
			EndIf;
		EndDo;
	EndDo;
	
	Return AttributesToDelete;
EndFunction

Procedure DeleteSettingsItemsCommands(Form, AttributesToDelete)
	CommandsSuffixes = StrSplit("SelectPeriod, Pickup, PasteFromClipboard1", ", ", False);
	
	For Each AttributeName In AttributesToDelete Do 
		For Each Suffix In CommandsSuffixes Do 
			Command = Form.Commands.Find(AttributeName + Suffix);
			If Command <> Undefined Then 
				Form.Commands.Delete(Command);
			EndIf;
		EndDo;
	EndDo;
EndProcedure

// Output setting form items

Procedure OutputSettingsPeriods(Form, SettingsItems, AttributesNames)
	FoundItems1 = SettingsItems.FindRows(New Structure("IsPeriod, SettingProperty", True, "Value"));
	If FoundItems1.Count() = 0 Then 
		Return;
	EndIf;
	
	Items = Form.Items;
	PredefinedItemsattributesNames = AttributesNames.PredefinedItems1.Period;
	
	PresentationOption = Form.ReportSettings.PeriodRepresentationOption;
	ThisIsTheStandardRepresentation = (PresentationOption = Enums.PeriodPresentationOptions.Standard);
	
	ShouldOutputPeriodTitles = OutputSettingsTitles(Form) And FoundItems1.Count() >= 2;
	
	For Each Item In FoundItems1 Do 
		LinkedItems1 = SettingsItems.FindRows(New Structure("SettingIndex", Item.SettingIndex));
		For Each LinkedItem1 In LinkedItems1 Do 
			LinkedItem1.Field.Visible = (LinkedItem1.SettingProperty = "Use");
		EndDo;
		
		Period = InitializePeriod(Form, Item.SettingIndex);
		
		Field = Item.Field;
		Parent = Field.Parent; // FormGroup
		
		NextItem = Undefined;
		ElementIndex = Parent.ChildItems.IndexOf(Field);
		If Parent.ChildItems.Count() > ElementIndex + 1 Then 
			NextItem = Parent.ChildItems.Get(ElementIndex + 1);
		EndIf;
		
		AttributeName = Form.PathToItemsData.ByIndex[Item.SettingIndex];
		If PredefinedItemsattributesNames.Find(AttributeName) <> Undefined Then 
			FoundItem = Items.Find(AttributeName);
			Items.Move(FoundItem, Parent, NextItem);
			FoundItem.Visible = True;
			
			For Each PeriodElement In FoundItem.ChildItems Do 
				PeriodElementType = TypeOf(PeriodElement);
				
				If PeriodElementType = Type("FormField") Then 
					PeriodElement.Title = PeriodElementHeader(PeriodElement.Name, Field.Title, ShouldOutputPeriodTitles);
					PeriodElement.ToolTip = PeriodElement.Title;
					PeriodElement.InputHint = PeriodElement.Title;
					If ShouldOutputPeriodTitles And StrEndsWith(Lower(PeriodElement.Name), Lower("StartDate")) Then
						ToolTip = PeriodElementHeader(PeriodElement.Name, Field.Title, False);
						PeriodElement.ToolTip = ToolTip;
						PeriodElement.InputHint = ToolTip;
						PeriodElement.TitleLocation = FormItemTitleLocation.Left;
					EndIf;
				EndIf;
				
				If ThisIsTheStandardRepresentation Then 
					PeriodElement.Visible = PeriodElementType <> Type("FormButton")
						Or (PeriodElementType = Type("FormButton")
						And StrStartsWith(PeriodElement.CommandName, "SelectPeriod"));
				Else
					PeriodElement.Visible = (PeriodElementType = Type("FormButton")
						Or PeriodElementType = Type("FormGroup"));
				EndIf;
				
				SetThePropertiesOfThePeriodSelectionButton(PeriodElement, Period, ThisIsTheStandardRepresentation);
				
			EndDo;
			
			Continue;
		EndIf;
		
		ItemNameTemplate = StrReplace(Field.Name, "Value", "%1%2");
		
		Group = PeriodItemsGroup(Items, Parent, NextItem, ItemNameTemplate, Field.Title);
		
		AddAPeriodShiftCommand(Form, Group, ItemNameTemplate, ThisIsTheStandardRepresentation, -1);
		AddAPeriodField(Items, Group, ItemNameTemplate, "StartDate", Field.Title, ThisIsTheStandardRepresentation, ShouldOutputPeriodTitles);
		
		TagName = StringFunctionsClientServer.SubstituteParametersToString(ItemNameTemplate, "Separator");
		Separator = Items.Find(TagName);
		If Separator = Undefined Then 
			Separator = Items.Add(TagName, Type("FormDecoration"), Group);
		EndIf;
		Separator.Type = FormDecorationType.Label;
		Separator.Title = Char(8211); // En dash.
		Separator.Visible = ThisIsTheStandardRepresentation;
		
		AddAPeriodField(Items, Group, ItemNameTemplate, "EndDate", Field.Title, ThisIsTheStandardRepresentation, ShouldOutputPeriodTitles);
		AddPeriodChoiceCommand(Form, Group, ItemNameTemplate, Period, ThisIsTheStandardRepresentation);
		AddAPeriodShiftCommand(Form, Group, ItemNameTemplate, ThisIsTheStandardRepresentation);
	EndDo;
EndProcedure

Function PeriodItemsGroup(Items, Parent, NextItem, NameTemplate, Title)
	TagName = StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, "", "Period");
	
	Group = Items.Find(TagName);
	If Group = Undefined Then 
		Group = Items.Add(TagName, Type("FormGroup"), Parent);
	EndIf;
	Group.Type = FormGroupType.UsualGroup;
	Group.Representation = UsualGroupRepresentation.None;
	Group.Group = ChildFormItemsGroup.AlwaysHorizontal;
	Group.Title = Title;
	Group.ShowTitle = False;
	Group.EnableContentChange = False;
	
	If NextItem <> Undefined Then 
		Items.Move(Group, Parent, NextItem);
	EndIf;
	
	Return Group;
EndFunction

Procedure AddAPeriodField(Items, Group, NameTemplate, Property, SettingItemTitle, ThisIsTheStandardRepresentation, ShouldOutputPeriodTitles)
	TagName = StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, "", Property);
	
	Item = Items.Find(TagName);
	If Item = Undefined Then 
		Item = Items.Add(TagName, Type("FormField"), Group);
	EndIf;
	Item.Type = FormFieldType.InputField;
	Item.DataPath = StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, "Period.", Property);
	Item.Width = 9;
	Item.HorizontalStretch = False;
	Item.ChoiceButton = True;
	Item.OpenButton = False;
	Item.ClearButton = False;
	Item.SpinButton = False;
	Item.TextEdit = True;
	Item.Title = PeriodElementHeader(Property, SettingItemTitle, ShouldOutputPeriodTitles);
	Item.ToolTip = Item.Title;
	Item.InputHint = Item.Title;
	Item.TitleLocation = FormItemTitleLocation.None;
	If ShouldOutputPeriodTitles And StrEndsWith(Lower(Property), Lower("StartDate")) Then
		ToolTip = PeriodElementHeader(Property, SettingItemTitle, False);
		Item.ToolTip = ToolTip;
		Item.InputHint = ToolTip;
		Item.TitleLocation = FormItemTitleLocation.Left;
	EndIf;
	Item.SetAction("OnChange", "Attachable_Period_OnChange");
	Item.Visible = ThisIsTheStandardRepresentation;
EndProcedure

Function PeriodElementHeader(Property, SettingItemTitle, ShouldOutputPeriodTitles)

	If ShouldOutputPeriodTitles And StrEndsWith(Lower(Property), Lower("StartDate")) Then
		Return SettingItemTitle;
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 (date %2)';"),
		SettingItemTitle,
		?(StrEndsWith(Lower(Property), Lower("StartDate")), NStr("en = 'start';"), NStr("en = 'end';")));
	
EndFunction

Procedure AddAPeriodShiftCommand(Form, Group, NameTemplate, ThisIsTheStandardRepresentation, ShiftDirection = 1)
	TagName = StringFunctionsClientServer.SubstituteParametersToString(
		NameTemplate, "", ?(ShiftDirection > 0, "MoveThePeriodForward", "MoveThePeriodBack"));
	
	Command = Form.Commands.Find(TagName);
	If Command = Undefined Then 
		Command = Form.Commands.Add(TagName);
	EndIf;
	
	If ShiftDirection > 0 Then 
		Command.Action = "Attachable_MoveThePeriodForward";
		Command.Title = ">";
		Command.ToolTip = NStr("en = 'Move forward';");
	Else
		Command.Action = "Attachable_MoveThePeriodBack";
		Command.Title = "<";
		Command.ToolTip = NStr("en = 'Move back';");
	EndIf;
	
	Button = Form.Items.Find(TagName);
	If Button = Undefined Then 
		Button = Form.Items.Add(TagName, Type("FormButton"), Group);
	EndIf;
	Button.CommandName = TagName;
	Button.ShapeRepresentation = ButtonShapeRepresentation.WhenActive;
	Button.Font = Metadata.StyleItems.ImportantLabelFont.Value;
	Button.Visible = Not ThisIsTheStandardRepresentation;
EndProcedure

Procedure AddPeriodChoiceCommand(Form, Group, NameTemplate, Period, ThisIsTheStandardRepresentation)
	TagName = StringFunctionsClientServer.SubstituteParametersToString(NameTemplate, "", "SelectPeriod");
	
	Command = Form.Commands.Find(TagName);
	If Command = Undefined Then 
		Command = Form.Commands.Add(TagName);
	EndIf;
	Command.Action = "Attachable_SelectPeriod";
	Command.Title = NStr("en = 'Select period…';");
	Command.ToolTip = Command.Title;
	Command.Representation = ButtonRepresentation.Picture;
	Command.Picture = PictureLib.InputFieldSelect;
	
	NameOfTheButtonGroup = StrReplace(TagName, "SelectPeriod", "GroupSelectPeriod_");
	ButtonsGroup = SettingsFormItemsGroup(Form, Group, NameOfTheButtonGroup);
	ButtonsGroup.ChildItemsHorizontalAlign = ItemHorizontalLocation.Center;
	
	Button = Form.Items.Find(TagName);
	If Button = Undefined Then 
		Button = Form.Items.Add(TagName, Type("FormButton"), ButtonsGroup);
	EndIf;
	Button.CommandName = TagName;
	
	SetThePropertiesOfThePeriodSelectionButton(ButtonsGroup, Period, ThisIsTheStandardRepresentation);
EndProcedure

Procedure SetThePropertiesOfThePeriodSelectionButton(PeriodElement, Period, ThisIsTheStandardRepresentation)
	If TypeOf(PeriodElement) <> Type("FormGroup")
		Or PeriodElement.ChildItems.Count() = 0
		Or StrFind(PeriodElement.Name, "SelectPeriod") = 0 Then 
		
		Return;
	EndIf;
	
	Button = PeriodElement.ChildItems[0];
	Button.Title = StringFunctions.PeriodPresentationInText(Period.StartDate, Period.EndDate);
	Button.Font = Metadata.StyleItems.ImportantLabelFont.Value;
	
	If ThisIsTheStandardRepresentation Then 
		Button.Width = 3;
		Button.Representation = ButtonRepresentation.Picture;
		Button.Picture = PictureLib.InputFieldSelect;
		Button.ShapeRepresentation = ButtonShapeRepresentation.Auto;
	Else
		PeriodElement.Width = 15;
		
		Button.Representation = ButtonRepresentation.Text;
		Button.ShapeRepresentation = ButtonShapeRepresentation.None;
	EndIf;
EndProcedure

// Sets values for standard period properties: StartDate and EndDate
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports:
//     * Items - FormAllItems
//     * Report - ReportObject
//   IndexOf - Number
//
// Returns:
//   StandardPeriod
//
Function InitializePeriod(Form, IndexOf)
	UserSettings = Form.Report.SettingsComposer.UserSettings;
	SettingItem = UserSettings.Items[IndexOf];
	
	Path = Form.PathToItemsData.ByIndex[IndexOf];
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		Period = SettingItem.Value;
	Else // Filter element.
		Period = SettingItem.RightValue;
	EndIf;
	
	Form[Path] = Period;
	
	Return Period;
EndFunction

// Output lists of setting form items.

Procedure OutputSettingsLists(Form, SettingsItems, SettingsDescription, AttributesNames)
	Search = New Structure("IsList, SettingProperty", True, "Value");
	FoundItems1 = SettingsItems.FindRows(Search);
	If FoundItems1.Count() = 0 Then 
		Return;
	EndIf;
	
	LinkedItems1 = SettingsItems.Copy(New Structure("IsList, SettingProperty", True, "Use"));
	
	For Each Item In FoundItems1 Do 
		LinkedItem1 = LinkedItems1.Find(Item.SettingIndex, "SettingIndex");
		If LinkedItem1 <> Undefined Then
			LinkedField = LinkedItem1.Field;
			If TypeOf(LinkedField) = Type("FormField") And LinkedField.Type = FormFieldType.CheckBoxField Then
				LinkedField.TitleLocation = FormItemTitleLocation.Right;
			EndIf;
		EndIf;
		
		Item.Field.Visible = False;
		LongDesc = SettingsDescription.Find(Item.SettingIndex, "SettingIndex");
		
		ListName = Form.PathToItemsData.ByIndex[Item.SettingIndex];
		
		AddListItems(Form, Item, LongDesc, ListName, AttributesNames);
		AddListCommands(Form, Item, SettingsItems, ListName);
	EndDo;
EndProcedure

// Creates form items of the FormTable type that refer to an attribute of the ValueList type
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports:
//     * Report - ReportObject
//   SettingItem - ValueTableRow
//   SettingItemDetails - ValueTableRow
//                             - Undefined
//   ListName - String
//   AttributesNames - Structure:
//   * GeneratedItems - Structure
//   * PredefinedItems1 - Structure
//
Procedure AddListItems(Form, SettingItem, SettingItemDetails, ListName, AttributesNames)
	Items = Form.Items; 
	Field = SettingItem.Field; // FormField
	
	PredefinedItemsattributesNames = AttributesNames.PredefinedItems1.List;
	
	If PredefinedItemsattributesNames.Find(ListName) = Undefined Then 
		List = Items.Add(ListName, Type("FormTable"), Field.Parent);
		List.DataPath = ListName;
		List.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		List.Height = 3;
		List.SetAction("OnChange", "Attachable_List_OnChange");
		List.SetAction("BeforeAddRow", "Attachable_List_BeforeAddRow");
		List.SetAction("BeforeRowChange", "Attachable_List_BeforeStartChanges");
		List.SetAction("ChoiceProcessing", "Attachable_List_ChoiceProcessing");
		
		ListFields = Items.Add(List.Name + "Columns", Type("FormGroup"), List);
		ListFields.Type = FormGroupType.ColumnGroup;
		ListFields.Group = ColumnsGroup.InCell;
		ListFields.Title = NStr("en = 'Fields';");
		ListFields.ShowTitle = False;
		
		TaggingField = Items.Add(ListName + "Check", Type("FormField"), ListFields);
		TaggingField.Type = FormFieldType.CheckBoxField;
		TaggingField.DataPath = ListName + ".Check";
		TaggingField.EditMode = ColumnEditMode.Directly;
		TaggingField.SetAction("OnChange", "Attachable_ListItemMark_OnChange");
		
		ValueField = Items.Add(ListName + "Value", Type("FormField"), ListFields);
		ValueField.Type = FormFieldType.InputField;
		ValueField.DataPath = ListName + ".Value";
		ValueField.SetAction("OnChange", "Attachable_ListItem_OnChange");
		ValueField.SetAction("StartChoice", "Attachable_ListItem_StartChoice");
	Else
		List = Items.Find(ListName);
		List.Visible = True;
		
		ListFields = Items.Find(List.Name + "Columns");
		ValueField = Items.Find(List.Name + "Value");
		
		Items.Move(List, Field.Parent);
	EndIf;
	
	List.Title = Field.Title;
	
	Properties = "AvailableTypes, TypeRestriction, AutoMarkIncomplete, ChoiceParameterLinks, TypeLink";
	FillPropertyValues(ValueField, Field, Properties);
	
	CommonClientServer.SupplementList(ValueField.ChoiceList, Field.ChoiceList, False, True);
	
	EditParameters = New Structure("QuickChoice, ChoiceFoldersAndItems");
	If SettingItemDetails.SettingDetails <> Undefined Then 
		FillPropertyValues(EditParameters, SettingItemDetails.SettingDetails);
	EndIf;
	
	ValueField.QuickChoice = EditParameters.QuickChoice;
	
	Condition = ReportsClientServer.SettingItemCondition(
		SettingItemDetails.SettingItem, SettingItemDetails.SettingDetails);
	ValueField.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(
		EditParameters.ChoiceFoldersAndItems, Condition);
	
	ValueField.ChoiceParameters = ReportsClientServer.ChoiceParameters(
		SettingItemDetails.Settings,
		Form.Report.SettingsComposer.UserSettings.Items,
		SettingItemDetails.SettingItem);
	
	InitializeList(Form, SettingItem.SettingIndex, ValueField, SettingItemDetails.SettingItem);
	
	If Field.ChoiceList.Count() > 0 Then 
		List.ChangeRowSet = False;
		ValueField.ReadOnly = True;
	EndIf;
EndProcedure

Procedure AddListCommands(Form, SettingItem, SettingsItems, ListName)
	Items = Form.Items; 
	
	Search = New Structure("SettingProperty, SettingIndex", "Use");
	Search.SettingIndex = SettingItem.SettingIndex;
	
	TitleField = SettingsItems.FindRows(Search)[0].Field;
	TitleGroup = TitleField.Parent;
	TitleGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	ListGroup = TitleGroup.Parent;
	ListGroup.Representation = UsualGroupRepresentation.NormalSeparation;
	
	If Not Items[ListName].ChangeRowSet Then 
		Return;
	EndIf;
	
	TagName = ListName + "Indent";
	Indent = Items.Find(TagName);
	If Indent = Undefined Then 
		Indent = Items.Add(TagName, Type("FormDecoration"), TitleGroup);
	ElsIf Indent.Parent <> TitleGroup Then 
		Items.Move(Indent, TitleGroup);
	EndIf;
	Indent.Type = FormDecorationType.Label;
	Indent.Title = "     ";
	Indent.HorizontalStretch = True;
	Indent.AutoMaxWidth = False;
	Indent.Visible = True;
	
	CommandName = ListName + "Pickup";
	CommandTitle = NStr("en = 'Pick';");
	AddListCommand(Form, TitleGroup, CommandName, CommandTitle, "Attachable_List_Pick");
	
	If TypeOf(SettingItem.ValueType) <> Type("TypeDescription")
	 Or Not Common.SubsystemExists("StandardSubsystems.ImportDataFromFile") Then 
		Return;
	EndIf;
	
	HasReferenceType = False;
	For Each Current_Type In SettingItem.ValueType.Types() Do
		If Common.IsReference(Current_Type) Then
			HasReferenceType = True;
			Break;
		EndIf;
	EndDo;
	
	If HasReferenceType Then
		
		CommandName = ListName + ReportsClientServer.PasteFromClipboardCommandName();
		CommandTitle = NStr("en = 'Paste from clipboard…';");
		AddListCommand(Form, TitleGroup, CommandName, CommandTitle,
			"Attachable_List_PasteFromClipboard", PictureLib.PasteFromClipboard);
			
	EndIf;
	
EndProcedure

Procedure AddListCommand(Form, Parent, CommandName, Title, Action, Picture = Undefined)
	Command = Form.Commands.Find(CommandName);
	If Command = Undefined Then 
		Command = Form.Commands.Add(CommandName);
	EndIf;
	Command.Action = Action;
	Command.Title = Title;
	Command.ToolTip = Title;
	
	If Picture = Undefined Then 
		Command.Representation = ButtonRepresentation.Text;
	Else
		Command.Representation = ButtonRepresentation.Picture;
		Command.Picture = PictureLib.PasteFromClipboard;
	EndIf;
	
	Button = Form.Items.Find(CommandName);
	If Button = Undefined Then 
		Button = Form.Items.Add(CommandName, Type("FormButton"), Parent);
	ElsIf Button.Parent <> Parent Then 
		Form.Items.Move(Button, Parent);
	EndIf;
	Button.CommandName = CommandName;
	Button.Type = FormButtonType.Hyperlink;
	Button.Visible = True;
EndProcedure

Procedure InitializeList(Form, IndexOf, Field, SettingItem)
	UserSettings = Form.Report.SettingsComposer.UserSettings;
	SettingItem = UserSettings.Items[IndexOf];
	
	Path = Form.PathToItemsData.ByIndex[IndexOf];
	List = Form[Path];
	List.ValueType = Field.AvailableTypes;
	List.Clear();
	
	ValueFieldName = "RightValue";
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		ValueFieldName = "Value";
	EndIf;
	
	SelectedValues = ReportsClientServer.ValuesByList(SettingItem[ValueFieldName]);
	If SelectedValues.Count() > 0 Then 
		SettingItem[ValueFieldName] = SelectedValues;
	Else
		SelectedValues = ReportsClientServer.ValuesByList(SettingItem[ValueFieldName]);
		If SelectedValues.Count() > 0 Then 
			// The user setting value is restored during runtime of the method
			// "CreateUserSettingsFormItems".
			SettingItem[ValueFieldName] = SelectedValues;
		EndIf;
	EndIf;
	
	AvailableValues = New ValueList;
	If Field.QuickChoice = True Then 
		ListParameters = New Structure("ChoiceParameters, TypeDescription, ChoiceFoldersAndItems, Filter");
		FillPropertyValues(ListParameters, Field);
		ListParameters.TypeDescription = Field.AvailableTypes;
		ListParameters.Filter = New Structure;
		
		AvailableValues = ValuesForSelection(ListParameters);
	EndIf;
	
	If AvailableValues.Count() = 0 Then 
		AvailableValues = Field.ChoiceList;
	EndIf;
	
	CommonClientServer.SupplementList(List, AvailableValues, False, True);
	CommonClientServer.SupplementList(List, SelectedValues, False, True);
	
	For Each ListItem In List Do 
		If Not ValueIsFilled(ListItem.Value) Then 
			Continue;
		EndIf;
		
		FoundItem = AvailableValues.FindByValue(ListItem.Value);
		If FoundItem <> Undefined Then 
			ListItem.Presentation = FoundItem.Presentation;
		EndIf;
		
		FoundItem = SelectedValues.FindByValue(ListItem.Value);
		ListItem.Check = (FoundItem <> Undefined);
	EndDo;
	
	ListBox = Form.Items[Path]; // FormTable
	If SettingItem.Use Then 
		ListBox.TextColor = New Color;
	Else
		ListBox.TextColor = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	EndIf;
EndProcedure

// Output values as check box fields.

Procedure OutputValuesAsCheckBoxesFields(Form, SettingsItems, AttributesNames)
	Search = New Structure("IsValueAsCheckBox, SettingProperty", True, "Use");
	FoundItems1 = SettingsItems.FindRows(Search);
	If FoundItems1.Count() = 0 Then 
		Return;
	EndIf;
	
	Items = Form.Items;
	PredefinedItemsattributesNames = AttributesNames.PredefinedItems1.CheckBox;
	
	For Each Item In FoundItems1 Do 
		Field = Item.Field;
		
		AttributeName = Form.PathToItemsData.ByIndex[Item.SettingIndex];
		If PredefinedItemsattributesNames.Find(AttributeName) = Undefined Then 
			CheckBoxField = Items.Add(AttributeName, Type("FormField"), Field.Parent);
			CheckBoxField.Type = FormFieldType.CheckBoxField;
			CheckBoxField.DataPath = AttributeName;
			CheckBoxField.SetAction("OnChange", "Attachable_SettingItem_OnChange");
		Else
			CheckBoxField = Items.Find(AttributeName);
			Items.Move(CheckBoxField, Field.Parent);
			CheckBoxField.Visible = True;
		EndIf;
		
		CheckBoxField.Title = Field.Title;
		CheckBoxField.TitleLocation = FormItemTitleLocation.None;
		Item.Field = CheckBoxField;
		
		InitializeCheckBox(Form, Item.SettingIndex);
	EndDo;
EndProcedure

// Sets the check box value.
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ManagedFormExtensionForReports:
//     * Report - ReportObject
//   IndexOf - Number
//
Procedure InitializeCheckBox(Form, IndexOf)
	UserSettings = Form.Report.SettingsComposer.UserSettings;
	SettingItem = UserSettings.Items[IndexOf];
	
	Path = Form.PathToItemsData.ByIndex[IndexOf];
	If TypeOf(SettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		Form[Path] = SettingItem.Value;
	Else // Filter element.
		Form[Path] = SettingItem.RightValue;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Save form status.

// Stores the form state.
// 
// Parameters:
//   Form - ClientApplicationForm
//   TableName - String
//   KeyColumns - String
// 
// Returns:
//   Structure:
//   * Current - Undefined
//   * Selected3 - Array
//
Function RememberSelectedRows(Form, TableName, KeyColumns) Export
	TableAttribute1 = Form[TableName];
	TableItem = Form.Items.Find(TableName); // FormTable
	
	Result = New Structure;
	Result.Insert("Selected3", New Array);
	Result.Insert("Current", Undefined);
	
	CurrentRowID1 = TableItem.CurrentRow;
	If CurrentRowID1 <> Undefined Then
		TableRow = TableAttribute1.FindByID(CurrentRowID1);
		If TableRow <> Undefined Then
			RowData = New Structure(KeyColumns);
			FillPropertyValues(RowData, TableRow);
			Result.Current = RowData;
		EndIf;
	EndIf;
	
	SelectedRows = TableItem.SelectedRows;
	If SelectedRows <> Undefined Then
		For Each SelectedID In SelectedRows Do
			If SelectedID = CurrentRowID1 Then
				Continue;
			EndIf;
			TableRow = TableAttribute1.FindByID(SelectedID);
			If TableRow <> Undefined Then
				RowData = New Structure(KeyColumns);
				FillPropertyValues(RowData, TableRow);
				Result.Selected3.Add(RowData);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

// Restores the form state.
// 
// Parameters:
//   Form - ClientApplicationForm
//   TableName - String
//   KeyColumns - String
// 
Procedure RestoreSelectedRows(Form, TableName, TableRows) Export
	TableAttribute1 = Form[TableName];
	TableItem = Form.Items[TableName]; // FormTable
	
	TableItem.SelectedRows.Clear();
	
	If TableRows.Current <> Undefined Then
		FoundItems = ReportsClientServer.FindTableRows(TableAttribute1, TableRows.Current);
		If FoundItems <> Undefined And FoundItems.Count() > 0 Then
			For Each TableRow In FoundItems Do
				If TableRow <> Undefined Then
					Id = TableRow.GetID();
					TableItem.CurrentRow = Id;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	For Each RowData In TableRows.Selected3 Do
		FoundItems = ReportsClientServer.FindTableRows(TableAttribute1, RowData);
		If FoundItems <> Undefined And FoundItems.Count() > 0 Then
			For Each TableRow In FoundItems Do
				If TableRow <> Undefined Then
					TableItem.SelectedRows.Add(TableRow.GetID());
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Report is empty.

// Checks if there are external data sets.
//
// Parameters:
//   DataSets - DataCompositionTemplateDataSets - Collection of data sets to be checked.
//
// Returns: 
//   Boolean - True if is has external data sets.
//
Function ThereIsExternalDataSet(DataSets)
	
	For Each DataSet In DataSets Do
		
		If TypeOf(DataSet) = Type("DataCompositionTemplateDataSetObject") Then
			
			Return True;
			
		ElsIf TypeOf(DataSet) = Type("DataCompositionTemplateDataSetUnion") Then
			
			If ThereIsExternalDataSet(DataSet.Items) Then
				
				Return True;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Selection parameters.

Function ValuesForSelection(SetupParameters, TypeOrTypes = Undefined) Export
	GettingChoiceDataParameters = New Structure("Filter, ChoiceFoldersAndItems");
	FillPropertyValues(GettingChoiceDataParameters, SetupParameters);
	AddItemsFromChoiceParametersToStructure(GettingChoiceDataParameters, SetupParameters.ChoiceParameters);
	
	ValuesForSelection = New ValueList;
	If TypeOf(TypeOrTypes) = Type("Type") Then
		Types = New Array;
		Types.Add(TypeOrTypes);
	ElsIf TypeOf(TypeOrTypes) = Type("Array") Then
		Types = TypeOrTypes;
	Else
		Types = SetupParameters.TypeDescription.Types();
	EndIf;
	
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		Manager = Common.ObjectManagerByFullName(MetadataObject.FullName());
		
		ChoiceList = Manager.GetChoiceData(GettingChoiceDataParameters);
		For Each ListItem In ChoiceList Do
			ValueForSelection = ValuesForSelection.Add();
			FillPropertyValues(ValueForSelection, ListItem);
			
			// For enumerations, values are returned as a structure with the Value property.
			EnumerationValue = Undefined;
			If TypeOf(ValueForSelection.Value) = Type("Structure") 
				And ValueForSelection.Value.Property("Value", EnumerationValue) Then
				ValueForSelection.Value = EnumerationValue;
			EndIf;	
				
		EndDo;
	EndDo;
	Return ValuesForSelection;
EndFunction

Procedure AddItemsFromChoiceParametersToStructure(Structure, ChoiceParametersArray)
	For Each ChoiceParameter In ChoiceParametersArray Do
		CurrentStructure = Structure;
		RowsArray = StrSplit(ChoiceParameter.Name, ".");
		Count = RowsArray.Count();
		If Count > 1 Then
			For IndexOf = 0 To Count-2 Do
				Var_Key = RowsArray[IndexOf];
				If CurrentStructure.Property(Var_Key) And TypeOf(CurrentStructure[Var_Key]) = Type("Structure") Then
					CurrentStructure = CurrentStructure[Var_Key];
				Else
					CurrentStructure.Insert(Var_Key, New Structure);
					CurrentStructure = CurrentStructure[Var_Key];
				EndIf;
			EndDo;
		EndIf;
		Var_Key = RowsArray[Count-1];
		CurrentStructure.Insert(Var_Key, ChoiceParameter.Value);
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data composition schema

// Adds the selected data composition field.
//
// Parameters:
//   Where - DataCompositionSettingsComposer
//        - DataCompositionSettings
//        - DataCompositionSelectedFields -
//       Collection to add the selected field to.
//   DCNameOrField - String
//                - DataCompositionField - Field name.
//   Title    - String - Field presentation.
//
// Returns:
//   DataCompositionSelectedField - Selected added field.
//
Function AddSelectedField(Where, DCNameOrField, Title = "") Export
	
	If TypeOf(Where) = Type("DataCompositionSettingsComposer") Then
		SelectedDCFields = Where.Settings.Selection;
	ElsIf TypeOf(Where) = Type("DataCompositionSettings") Then
		SelectedDCFields = Where.Selection;
	Else
		SelectedDCFields = Where;
	EndIf;
	
	If TypeOf(DCNameOrField) = Type("String") Then
		DCField = New DataCompositionField(DCNameOrField);
	Else
		DCField = DCNameOrField;
	EndIf;
	
	SelectedDCField = SelectedDCFields.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = DCField;
	If Title <> "" Then
		SelectedDCField.Title = Title;
	EndIf;
	
	Return SelectedDCField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Context options.

Procedure AddContextOptions(Report, Variants, ContextOptions) Export 
	
	If ContextOptions.Count() = 0 Then 
		Return;
	EndIf;
	
	MissingOptions = New Array;
	
	For Each ContextOption In ContextOptions Do 
		
		If Variants.Find(ContextOption.Value, "VariantKey") = Undefined Then 
			MissingOptions.Add(ContextOption.Value);
		EndIf;
		
	EndDo;
	
	If MissingOptions.Count() = 0 Then 
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	ReportsOptions.*,
	|	ReportsOptions.Presentation AS Description
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey IN (&MissingOptions)");
	
	Query.SetParameter("Report", Report);
	Query.SetParameter("MissingOptions", MissingOptions);
	
	Variant = Query.Execute().Select();
	
	While Variant.Next() Do
		FillPropertyValues(Variants.Add(), Variant);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Miscellaneous.

Function ExtendedTypesDetails(SourceDescriptionOfTypes, CastToForm, PickingParameters = Undefined) Export
	Result = New Structure;
	Result.Insert("ContainsTypeType",        False);
	Result.Insert("ContainsDateType",       False);
	Result.Insert("ContainsBooleanType",     False);
	Result.Insert("ContainsStringType",     False);
	Result.Insert("ContainsNumberType",      False);
	Result.Insert("ContainsPeriodType",     False);
	Result.Insert("ContainsUUIDType",        False);
	Result.Insert("ContainsStorageType",  False);
	Result.Insert("ContainsObjectTypes", False);
	Result.Insert("ReducedLengthItem",     True);
	
	Result.Insert("TypesCount",            0);
	Result.Insert("PrimitiveTypesNumber", 0);
	Result.Insert("ObjectTypes", New Array);
	
	If CastToForm Then
		AddedTypes = New Array;
		RemovedTypes = New Array;
		Result.Insert("OriginalTypesDetails", SourceDescriptionOfTypes);
		Result.Insert("TypesDetailsForForm", SourceDescriptionOfTypes);
	EndIf;
	
	If SourceDescriptionOfTypes = Undefined Then
		Return Result;
	EndIf;
	
	TypesArray = SourceDescriptionOfTypes.Types();
	For Each Type In TypesArray Do
		If Type = Type("Null") Then 
			RemovedTypes.Add(Type);
			Continue;
		EndIf;
		
		If Type = Type("DataCompositionField") Then
			If CastToForm Then
				RemovedTypes.Add(Type);
			EndIf;
			Continue;
		EndIf;
		
		SettingMetadata = Metadata.FindByType(Type);
		If SettingMetadata <> Undefined Then 
			If Common.MetadataObjectAvailableByFunctionalOptions(SettingMetadata) Then
				If TypeOf(PickingParameters) = Type("Map") Then 
					PickingParameters.Insert(Type, SettingMetadata.FullName() + ".ChoiceForm");
				EndIf;
			Else // Object is unavailable.
				If CastToForm Then
					RemovedTypes.Add(Type);
				EndIf;
				Continue;
			EndIf;
		EndIf;
		
		Result.TypesCount = Result.TypesCount + 1;
		
		If Type = Type("Type") Then
			Result.ContainsTypeType = True;
		ElsIf Type = Type("Date") Then
			Result.ContainsDateType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("Boolean") Then
			Result.ContainsBooleanType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("Number") Then
			Result.ContainsNumberType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
		ElsIf Type = Type("StandardPeriod") Then
			Result.ContainsPeriodType = True;
		ElsIf Type = Type("String") Then
			Result.ContainsStringType = True;
			Result.PrimitiveTypesNumber = Result.PrimitiveTypesNumber + 1;
			If SourceDescriptionOfTypes.StringQualifiers.Length = 0
				And SourceDescriptionOfTypes.StringQualifiers.AllowedLength = AllowedLength.Variable Then
				Result.ReducedLengthItem = False;
			EndIf;
		ElsIf Type = Type("UUID") Then
			Result.ContainsUUIDType = True;
		ElsIf Type = Type("ValueStorage") Then
			Result.ContainsStorageType = True;
		Else
			Result.ContainsObjectTypes = True;
			Result.ObjectTypes.Add(Type);
		EndIf;
		
	EndDo;
	
	If CastToForm
		And (AddedTypes.Count() > 0 Or RemovedTypes.Count() > 0) Then
		Result.TypesDetailsForForm = New TypeDescription(SourceDescriptionOfTypes, AddedTypes, RemovedTypes);
	EndIf;
	
	Return Result;
EndFunction

Function ValueToArray(Value) Export
	If TypeOf(Value) = Type("Array") Then
		Return Value;
	Else
		Array = New Array;
		Array.Add(Value);
		Return Array;
	EndIf;
EndFunction

Function CastIDToName(Id) Export
	Return StrReplace(StrReplace(String(Id), "-", ""), ".", "_");
EndFunction

// Finds a data composition item by the full path.
//
// Parameters:
//   DCSettings - DataCompositionSettings - Root settings node containing the required item.
//   FullPathToItem - String - Full path to an item. It can be retrieved in the FullPathToItem() function.
//
// Returns:
//   - DataCompositionSettings
//   - DataCompositionSettingStructureItemCollection
//   - DataCompositionGroup
//   - DataCompositionTableStructureItemCollection
//   - DataCompositionTableGroup
//   - DataCompositionChartStructureItemCollection
//   - DataCompositionChartGroup - Found settings node.
//
Function SettingsItemByFullPath(Val Settings, Val FullPathToItem) Export
	Indexes = StrSplit(FullPathToItem, "/", False);
	SettingsItem = Settings;
	
	For Each IndexOf In Indexes Do
		If IndexOf = "Rows" Then
			SettingsItem = SettingsItem.Rows;
		ElsIf IndexOf = "Columns" Then
			SettingsItem = SettingsItem.Columns;
		ElsIf IndexOf = "Series" Then
			SettingsItem = SettingsItem.Series;
		ElsIf IndexOf = "Points" Then
			SettingsItem = SettingsItem.Points;
		ElsIf IndexOf = "Structure" Then
			SettingsItem = SettingsItem.Structure;
		ElsIf IndexOf = "Settings" Then
			SettingsItem = SettingsItem.Settings;
		Else
			SettingsItem = SettingsItem[Number(IndexOf)];
		EndIf;
	EndDo;
	
	Return SettingsItem;
EndFunction

// Parameters:
//  ImportParameters - See ReportsClientServer.ReportFormUpdateParameters
//  SettingsComposer - DataCompositionSettingsComposer
//
Procedure SetFiltersConditions(ImportParameters, SettingsComposer) Export 

	If ImportParameters.FiltersConditions = Undefined Then
		Return;
	EndIf;
	
	Settings = SettingsComposer.Settings;
	UserSettings = SettingsComposer.UserSettings;
	
	For Each Condition In ImportParameters.FiltersConditions Do
		UserSettingItem = UserSettings.GetObjectByID(Condition.Key);
		UserSettingItem.ComparisonType = Condition.Value;
		
		If ReportsClientServer.IsListComparisonKind(UserSettingItem.ComparisonType)
			And TypeOf(UserSettingItem.RightValue) <> Type("ValueList") Then 
			
			UserSettingItem.RightValue = ReportsClientServer.ValuesByList(
				UserSettingItem.RightValue);
		EndIf;
		
		SettingItem = ReportsClientServer.GetObjectByUserID(
			Settings, UserSettingItem.UserSettingID,, UserSettings);
		
		FillPropertyValues(SettingItem, UserSettingItem, "ComparisonType, RightValue");
	EndDo;
EndProcedure

Procedure SetValidSettingsValues(Form, Report, SettingsComposer, UserSettingItem, 
	MainSettingItem, SettingDetails)
		
	SettingProperties = UserSettingsItemProperties(
	SettingsComposer, UserSettingItem, MainSettingItem, SettingDetails);
	
	// Extension functionality.
	SSLSubsystemsIntegration.OnDefineSelectionParametersReportsOptions(Undefined, SettingProperties);
	
	// Global settings of type output.
	ReportsOverridable.OnDefineSelectionParameters(Undefined, SettingProperties);
	
	// Local override for a report.
	If Form.ReportSettings.Events.OnDefineSelectionParameters Then 
		Report.OnDefineSelectionParameters(Form, SettingProperties);
	EndIf;
	
	// Populate automatically.
	If SettingProperties.SelectionValuesQuery.Text <> "" Then
		// @skip-check query-in-loop - Query multiple tables.
		ValuesToAdd = SettingProperties.SelectionValuesQuery.Execute().Unload().UnloadColumn(0);
		For Each Item In ValuesToAdd Do
			ReportsClientServer.AddUniqueValueToList(
			SettingProperties.ValuesForSelection, Item, Undefined, False);
		EndDo;
		SettingProperties.ValuesForSelection.SortByPresentation(SortDirection.Asc);
	EndIf;
	
	If TypeOf(SettingProperties.ValuesForSelection) = Type("ValueList")
		And SettingProperties.ValuesForSelection.Count() > 0 Then 
		SettingDetails.AvailableValues = SettingProperties.ValuesForSelection;
	EndIf;
	
EndProcedure

#EndRegion
