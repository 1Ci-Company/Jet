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

// Starts a report generation process in the report form.
//  When the generation is completed, CompletionHandler is called.
//
// Parameters:
//   ReportForm - ClientApplicationForm - Report form.
//   CompletionHandler - NotifyDescription - Handler to be called once the report is generated.
//     To the first parameter of the procedure, specified in CompletionHandler,
//     the following parameter is passed: ReportGenerated (Boolean) - indicates that a report was generated successfully.
//
Procedure GenerateReport(ReportForm, CompletionHandler = Undefined) Export
	If TypeOf(CompletionHandler) = Type("NotifyDescription") Then
		ReportForm.HandlerAfterGenerateAtClient = CompletionHandler;
	EndIf;
	ReportForm.AttachIdleHandler("Generate", 0.1, True);
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Method of working with DCS from the report option.

Function ValueTypeRestrictedByLinkByType(Settings, UserSettings, SettingItem, SettingItemDetails, ValueType = Undefined) Export 
	If SettingItemDetails = Undefined Then 
		Return ?(ValueType = Undefined, New TypeDescription("Undefined"), ValueType);
	EndIf;
	
	If ValueType = Undefined Then 
		ValueType = SettingItemDetails.ValueType;
	EndIf;

	If TypeOf(SettingItem) = Type("DataCompositionFilterItem") And ValueType = New TypeDescription("Date")
		And Not ReportsClientServer.IsListComparisonKind(SettingItem.ComparisonType) Then
		ValueType = New TypeDescription("StandardBeginningDate");
	EndIf;

	TypeLink = SettingItemDetails.TypeLink;
	
	LinkedSettingItem = SettingItemByField(Settings, UserSettings, TypeLink.Field);
	If LinkedSettingItem = Undefined Then
		Return ValueType;
	EndIf;
	
	AllowedComparisonKinds = New Array;
	AllowedComparisonKinds.Add(DataCompositionComparisonType.Equal);
	AllowedComparisonKinds.Add(DataCompositionComparisonType.InHierarchy);
	
	If TypeOf(LinkedSettingItem) = Type("DataCompositionFilterItem")
		And (Not LinkedSettingItem.Use
		Or AllowedComparisonKinds.Find(LinkedSettingItem.ComparisonType) = Undefined) Then 
		Return ValueType;
	EndIf;
	
	LinkedSettingItemDetails = ReportsClientServer.FindAvailableSetting(Settings, LinkedSettingItem);
	If LinkedSettingItemDetails = Undefined Then 
		Return ValueType;
	EndIf;
	
	If TypeOf(LinkedSettingItem) = Type("DataCompositionSettingsParameterValue")
		And (LinkedSettingItemDetails.Use <> DataCompositionParameterUse.Always
		Or Not LinkedSettingItem.Use) Then 
		Return ValueType;
	EndIf;
	
	If TypeOf(LinkedSettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		LinkedSettingItemValue = LinkedSettingItem.Value;
	ElsIf TypeOf(LinkedSettingItem) = Type("DataCompositionFilterItem") Then 
		LinkedSettingItemValue = LinkedSettingItem.RightValue;
	EndIf;
	
	ExtDimensionType = ReportsOptionsServerCall.ExtDimensionType(LinkedSettingItemValue, TypeLink.LinkItem);
	If TypeOf(ExtDimensionType) = Type("TypeDescription") Then
		LinkedTypes = ExtDimensionType.Types();
	Else
		LinkedTypes = LinkedSettingItemDetails.ValueType.Types();
	EndIf;
	
	RemovedTypes = ValueType.Types();
	IndexOf = RemovedTypes.UBound();
	While IndexOf >= 0 Do 
		If LinkedTypes.Find(RemovedTypes[IndexOf]) <> Undefined Then 
			RemovedTypes.Delete(IndexOf);
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	Return New TypeDescription(ValueType,, RemovedTypes);
EndFunction

// Searches a setup item by the data composition field.
// 
// Parameters:
//   Settings - DataCompositionSettings
//   UserSettings - DataCompositionUserSettingsItemCollection
//   Field - DataCompositionField
// 
// Returns:
//   Undefined
//
Function SettingItemByField(Settings, UserSettings, Field)
	SettingItem = DataParametersItemByField(Settings, UserSettings, Field);
	
	If SettingItem = Undefined Then 
		FindFilterItemByField(Field, Settings.Filter.Items, UserSettings, SettingItem);
	EndIf;
	
	Return SettingItem;
EndFunction

Function DataParametersItemByField(Settings, UserSettings, Field)
	If TypeOf(Settings) <> Type("DataCompositionSettings") Then 
		Return Undefined;
	EndIf;
	
	SettingsItems = Settings.DataParameters.Items;
	For Each Item In SettingsItems Do 
		UserItem1 = UserSettings.Find(Item.UserSettingID);
		ItemToAnalyse = ?(UserItem1 = Undefined, Item, UserItem1);
		
		Fields = New Array;
		Fields.Add(New DataCompositionField(String(Item.Parameter)));
		Fields.Add(New DataCompositionField("DataParameters." + String(Item.Parameter)));
		
		If ItemToAnalyse.Use
			And (Fields[0] = Field Or Fields[1] = Field) Then 
			
			Return ItemToAnalyse;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Procedure FindFilterItemByField(Field, FilterItems1, UserSettings, SettingItem)
	For Each Item In FilterItems1 Do 
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			FindFilterItemByField(Field, Item.Items, UserSettings, SettingItem)
		Else
			UserItem1 = UserSettings.Find(Item.UserSettingID);
			ItemToAnalyse = ?(UserItem1 = Undefined, Item, UserItem1);
			
			If ItemToAnalyse.Use And Item.LeftValue = Field Then 
				SettingItem = ItemToAnalyse;
				Break;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

// Returns full setup item details including a custom setting item, an available field
// of data composition filter, data composition index and settings to which the current item is subordinate.
// 
// Parameters:
//   SettingsComposer - DataCompositionSettingsComposer
//   Id - Number
//                 - String
// 
// Returns:
//   Structure:
//   * LongDesc - Undefined
//              - DataCompositionAvailableSettingsObject
//              - DataCompositionAvailableField
//   * Item - DataCompositionTableStructureItemCollection
//             - DataCompositionChart
//             - DataCompositionNestedObjectSettings
//             - DataCompositionSelectedFields
//             - DataCompositionSettings
//             - DataCompositionGroup
//             - DataCompositionTableGroup
//             - DataCompositionConditionalAppearance
//             - Undefined
//             - DataCompositionFilter
//             - DataCompositionSettingStructureItemCollection
//             - DataCompositionOrder
//             - DataCompositionTable
//             - DataCompositionChartGroup
//             - DataCompositionChartStructureItemCollection
//   * UserSettingItem - DataCompositionFilterItem
//                                      - DataCompositionParameterValue
//   * IndexOf - Number
//   * Settings - DataCompositionSettings
// 
Function SettingItemInfo(SettingsComposer, Id) Export 
	Settings = SettingsComposer.Settings;
	UserSettings = SettingsComposer.UserSettings;
	
	If TypeOf(Id) = Type("Number") Then 
		IndexOf = Id;
	Else
		IndexOf = ReportsClientServer.SettingItemIndexByPath(Id);
	EndIf;
	
	UserSettingItem = UserSettings.Items[IndexOf];
	
	SettingsHierarchy = New Array;
	Item = ReportsClientServer.GetObjectByUserID(
		Settings,
		UserSettingItem.UserSettingID,
		SettingsHierarchy,
		UserSettings);
	
	Settings = ?(SettingsHierarchy.Count() > 0, SettingsHierarchy[SettingsHierarchy.UBound()], Settings);
	LongDesc = ReportsClientServer.FindAvailableSetting(Settings, Item);
	
	InformationRecords = New Structure;
	InformationRecords.Insert("Settings", Settings);
	InformationRecords.Insert("IndexOf", IndexOf);
	InformationRecords.Insert("UserSettingItem", UserSettingItem);
	InformationRecords.Insert("Item", Item);
	InformationRecords.Insert("LongDesc", LongDesc);
	
	Return InformationRecords;
EndFunction

// Defines the FoldersAndItemsUse type value depending on the comparison type (preferably) or the source value.
//
// Parameters:
//  Condition - DataCompositionComparisonType
//          - Undefined - Current comparison kind value.
//  SourceValue - FoldersAndItemsUse
//                   - FoldersAndItems - Current value of the
//                     ChoiceFoldersAndItems property.
//
// Returns:
//   FoldersAndItemsUse - Member of the FoldersAndItemsUse enumeration.
//
Function ValueOfFoldersAndItemsUseType(SourceValue, Condition = Undefined) Export
	If Condition <> Undefined Then 
		If Condition = DataCompositionComparisonType.InListByHierarchy
			Or Condition = DataCompositionComparisonType.NotInListByHierarchy Then 
			If SourceValue = FoldersAndItems.Folders
				Or SourceValue = FoldersAndItemsUse.Folders Then 
				Return FoldersAndItemsUse.Folders;
			Else
				Return FoldersAndItemsUse.FoldersAndItems;
			EndIf;
		ElsIf Condition = DataCompositionComparisonType.InHierarchy
			Or Condition = DataCompositionComparisonType.NotInHierarchy Then 
			Return FoldersAndItemsUse.Folders;
		EndIf;
	EndIf;
	
	If TypeOf(SourceValue) = Type("FoldersAndItemsUse") Then 
		Return SourceValue;
	ElsIf SourceValue = FoldersAndItems.Items Then
		Return FoldersAndItemsUse.Items;
	ElsIf SourceValue = FoldersAndItems.FoldersAndItems Then
		Return FoldersAndItemsUse.FoldersAndItems;
	ElsIf SourceValue = FoldersAndItems.Folders Then
		Return FoldersAndItemsUse.Folders;
	EndIf;
	
	Return Undefined;
EndFunction

#Region ReportPeriod

// Calls a dialog box for editing a standard period.
//
// Parameters:
//  Form - ClientApplicationForm - Report form or a report settings form.
//  CommandName - String - Period choice command name that contains a period value path.
//  Var_PeriodVariant - Undefined
//                 - EnumRef.PeriodOptions
//
Procedure SelectPeriod(Form, CommandName, Var_PeriodVariant = Undefined) Export
	Path = StrReplace(CommandName, "SelectPeriod", "Period");
	Period = Form[Path];
	
	Context = New Structure();
	Context.Insert("Form", Form);
	Context.Insert("CommandName", CommandName);
	Context.Insert("Path", Path);
	Context.Insert("Period", Period);
	
	Handler = New NotifyDescription("SelectPeriodCompletion", ThisObject, Context);
	
	StandardProcessing = True;
	ReportsClientOverridable.OnClickPeriodSelectionButton(Form, Period, StandardProcessing, Handler);
	
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	If Var_PeriodVariant = Undefined Then 
		Var_PeriodVariant = Form.ReportSettings.PeriodVariant;
	EndIf;
	
	If Var_PeriodVariant = PredefinedValue("Enum.PeriodOptions.Fiscal") Then 
	
		Context.Delete("Form");
		
		OpenForm("SettingsStorage.ReportsVariantsStorage.Form.SelectFiscalPeriod",
			Context,
			Form,,,,
			Handler);
		
	Else
	
		Dialog = New StandardPeriodEditDialog;
		Dialog.Period = Period;
		Dialog.Show(Handler);
		
	EndIf;
EndProcedure

// Shifts a period back or forward.
//
// Parameters:
//  Form - ClientApplicationForm - Report form or a report settings form.
//  CommandName - String - Period choice command name that contains a period value path.
//
Procedure ShiftThePeriod(Form, CommandName) Export
	If StrFind(Lower(CommandName), "back") > 0 Then 
		
		ShiftDirection = -1;
		Path = StrReplace(CommandName, "MoveThePeriodBack", "Period");
	Else 
		ShiftDirection = 1;
		Path = StrReplace(CommandName, "MoveThePeriodForward", "Period");
	EndIf;
	
	Period = Form[Path]; // StandardPeriod
	
	If Not ValueIsFilled(Period.StartDate)
		Or Not ValueIsFilled(Period.EndDate) Then 
		
		Return;
	EndIf;
	
	If Period.StartDate = BegOfDay(Period.EndDate) Then
		
		Period.StartDate = Period.StartDate + 86400 * ShiftDirection;
		Period.EndDate = EndOfDay(Period.StartDate);
		
	ElsIf Period.StartDate = BegOfMonth(Period.EndDate) Then
		
		Period.StartDate = AddMonth(Period.StartDate, ShiftDirection);
		Period.EndDate = EndOfMonth(Period.StartDate);
		
	ElsIf Period.StartDate = BegOfQuarter(Period.EndDate) Then
		
		Period.StartDate = AddMonth(Period.StartDate, 3 * ShiftDirection);
		Period.EndDate = EndOfQuarter(Period.StartDate);
		
	ElsIf Period.StartDate = BegOfYear(Period.EndDate)
		And EndOfYear(Period.StartDate) = Period.EndDate Then
		
		Period.StartDate = AddMonth(Period.StartDate, 12 * ShiftDirection);
		Period.EndDate = EndOfYear(Period.StartDate);
		
	ElsIf Period.StartDate = BegOfYear(Period.EndDate)
		And (Month(Period.EndDate) = 6 Or Month(Period.EndDate) = 9) Then
		
		Period.StartDate = AddMonth(Period.StartDate, 12 * ShiftDirection);
		Period.EndDate = AddMonth(Period.EndDate, 12 * ShiftDirection);
		
	EndIf;
	
	Form[Path] = Period;
	SetPeriod(Form, Path);
	
	ReportsClientServer.NotifyOfSettingsChange(Form);
EndProcedure

// Handler for editing a standard period.
//
// Parameters:
//  SelectionResult - Structure:
//                  - StandardPeriod - Value returned by the dialog box.
//  Context - Structure - Contains a report form (settings form) and a period value path.
//
Procedure SelectPeriodCompletion(SelectionResult, Context) Export 
	If SelectionResult = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(SelectionResult) = Type("Structure")
		And SelectionResult.Property("Event") Then 
		
		SelectPeriod(SelectionResult.FormOwner, SelectionResult.CommandName, SelectionResult.PeriodVariant);
		Return;
		
	ElsIf TypeOf(SelectionResult) = Type("Structure") Then 
		
		Form = SelectionResult.FormOwner;
		Period = SelectionResult.Period;
		
	Else
		
		Form = Context.Form;
		Period = SelectionResult;
		
	EndIf;
	
	Form[Context.Path] = Period;
	SetPeriod(Form, Context.Path);
	
	ReportsClientServer.NotifyOfSettingsChange(Form);
EndProcedure

// Initializes value of the period setting item.
// 
// Parameters:
//   Form - ClientApplicationForm
//         - ReportFormExtension:
//     * Report - ReportObject
//   Path - String
//
Procedure SetPeriod(Form, Val Path) Export 
	SettingsComposer = Form.Report.SettingsComposer;
	
	Properties = StrSplit("StartDate, EndDate", ", ", False);
	For Each Property In Properties Do 
		Path = StrReplace(Path, Property, "");
	EndDo;
	
	IndexOf = Form.PathToItemsData.ByName[Path];
	If IndexOf = Undefined Then 
		Path = Path + "Period";
		IndexOf = Form.PathToItemsData.ByName[Path];
	EndIf;
	
	Period = Form[Path]; // StandardPeriod
	
	UserSettingItem = SettingsComposer.UserSettings.Items[IndexOf];
	UserSettingItem.Use = True;
	
	If TypeOf(UserSettingItem) = Type("DataCompositionSettingsParameterValue") Then 
		UserSettingItem.Value = Period;
	Else // Filter element.
		UserSettingItem.RightValue = Period;
	EndIf;
	
	NameOfThePeriodSelectionButton = StrReplace(Path, "Period", "SelectPeriod");
	PeriodSelectionButton = Form.Items.Find(NameOfThePeriodSelectionButton);
	PeriodSelectionButton.Title = StringFunctionsClient.PeriodPresentationInText(
		Period.StartDate, Period.EndDate);
	
	ReportsClientServer.NotifyOfSettingsChange(Form);
EndProcedure

#EndRegion

#Region Other

Function SpecifyItemTypeOnAddToCollection(CollectionType) Export
	Return CollectionType <> Type("DataCompositionTableStructureItemCollection")
		And CollectionType <> Type("DataCompositionChartStructureItemCollection")
		And CollectionType <> Type("DataCompositionConditionalAppearanceItemCollection");
EndFunction

Procedure CacheFilterValue(SettingsComposer, FilterElement, FilterValue) Export 
	AdditionalProperties = SettingsComposer.UserSettings.AdditionalProperties;
	
	FiltersValuesCache = CommonClientServer.StructureProperty(
		AdditionalProperties, "FiltersValuesCache", New Map);
	
	TheItemSelectionKeySettings = Undefined;
	
	If ValueIsFilled(FilterElement.UserSettingID) Then 
		
		FiltersValuesCache.Insert(FilterElement.UserSettingID, FilterValue);
		
		FoundTheElementsOfTheSettings = SettingsComposer.UserSettings.GetMainSettingsByUserSettingID(
			FilterElement.UserSettingID);
		
		If FoundTheElementsOfTheSettings.Count() > 0 Then 
			TheItemSelectionKeySettings = FoundTheElementsOfTheSettings[0];
		EndIf;
		
	Else
		TheItemSelectionKeySettings = FilterElement;
	EndIf;
	
	If TypeOf(TheItemSelectionKeySettings) = Type("DataCompositionFilterItem") Then 
		FiltersValuesCache.Insert(TheItemSelectionKeySettings.LeftValue, FilterValue);
	EndIf;
	
	AdditionalProperties.Insert("FiltersValuesCache", FiltersValuesCache);
EndProcedure

Function SelectionValueCache(SettingsComposer, FilterElement) Export 
	FilterValue = Undefined;
	
	AdditionalProperties = SettingsComposer.UserSettings.AdditionalProperties;
	
	FiltersValuesCache = CommonClientServer.StructureProperty(
		AdditionalProperties, "FiltersValuesCache", New Map);
	
	If ValueIsFilled(FilterElement.UserSettingID) Then 
		FilterValue = FiltersValuesCache[FilterElement.UserSettingID];
	EndIf;
	
	If FilterValue <> Undefined Then 
		Return FilterValue;
	EndIf;
	
	TheItemSelectionKeySettings = Undefined;
	
	If ValueIsFilled(FilterElement.UserSettingID) Then 
		
		FoundTheElementsOfTheSettings = SettingsComposer.UserSettings.GetMainSettingsByUserSettingID(
			FilterElement.UserSettingID);
		
		If FoundTheElementsOfTheSettings.Count() > 0 Then 
			TheItemSelectionKeySettings = FoundTheElementsOfTheSettings[0];
		EndIf;
		
	Else
		TheItemSelectionKeySettings = FilterElement;
	EndIf;
	
	If TypeOf(TheItemSelectionKeySettings) = Type("DataCompositionFilterItem") Then 
		FilterValue = FiltersValuesCache[TheItemSelectionKeySettings.LeftValue];
	EndIf;
	
	Return FilterValue;
EndFunction

// Defines a full path to a data composition item.
//
// Parameters:
//   Settings - DataCompositionSettings - Root settings node that is used as a start for a full path.
//   SettingsItem - DataCompositionSettings
//                   - DataCompositionNestedObjectSettings
//                   - DataCompositionTable
//                   - DataCompositionTableStructureItemCollection
//                   - DataCompositionChart
//                   - DataCompositionChartStructureItemCollection
//                   - DataCompositionFilterItem
//                   - DataCompositionFilterItemGroup
//                   - DataCompositionParameterValue
//                   - DataCompositionFilterItemGroup
//
// Returns:
//   String - Full path of the item. Can be used in the FindItemByFullPath() function.
//   Undefined if failed to build the path.
//
Function FullPathToSettingsItem(Val Settings, Val SettingsItem) Export
	Result = New Array;
	SettingsItemParent = SettingsItem;
	
	While SettingsItemParent <> Undefined
		And SettingsItemParent <> Settings Do
		
		SettingsItem = SettingsItemParent;
		SettingsItemParent = SettingsItemParent.Parent;
		ParentType = TypeOf(SettingsItemParent);
		
		If ParentType = Type("DataCompositionTable") Then
			TableRows = SettingsItemParent.Rows; // DataCompositionTableStructureItemCollection
			IndexOf = TableRows.IndexOf(SettingsItem);
			If IndexOf = -1 Then
				TableColumns1 = SettingsItemParent.Columns; // DataCompositionTableStructureItemCollection
				IndexOf = TableColumns1.IndexOf(SettingsItem);
				CollectionName = "Columns";
			Else
				CollectionName = "Rows";
			EndIf;
		ElsIf ParentType = Type("DataCompositionChart") Then
			ChartSeriesCollection = SettingsItemParent.Series; // DataCompositionChartStructureItemCollection
			IndexOf = ChartSeriesCollection.IndexOf(SettingsItem);
			If IndexOf = -1 Then
				ChartPoints = SettingsItemParent.Points; // DataCompositionChartStructureItemCollection
				IndexOf = ChartPoints.IndexOf(SettingsItem);
				CollectionName = "Points";
			Else
				CollectionName = "Series";
			EndIf;
		ElsIf ParentType = Type("DataCompositionNestedObjectSettings") Then
			CollectionName = "Settings";
			IndexOf = Undefined;
		Else
			CollectionName = "Structure";
			IndexOf = SettingsItemParent.Structure.IndexOf(SettingsItem);
		EndIf;
		
		If IndexOf = -1 Then
			Return Undefined;
		EndIf;
		
		If IndexOf <> Undefined Then
			Result.Insert(0, IndexOf);
		EndIf;
		
		Result.Insert(0, CollectionName);
	EndDo;
	
	Return StrConcat(Result, "/");
EndFunction

Function ChoiceOverride(ReportForm, Val Handler, LayoutItem,
			AvailableTypes, MarkedValues, ChoiceParameters) Export

	If TypeOf(LayoutItem) = Type("DataCompositionAvailableParameter") Then
		FieldName = String(LayoutItem.Parameter);
	ElsIf TypeOf(LayoutItem) = Type("DataCompositionFilterAvailableField") Then
		FieldName = String(LayoutItem.Field);
	Else
		FieldName = "";
	EndIf;
	
	If Not ValueIsFilled(FieldName) Then
		Return False;
	EndIf;
	
	SelectionConditions = New Structure;
	SelectionConditions.Insert("FieldName",           FieldName);
	SelectionConditions.Insert("LayoutItem", LayoutItem);
	SelectionConditions.Insert("AvailableTypes",     AvailableTypes);
	SelectionConditions.Insert("Marked",        MarkedValues);
	SelectionConditions.Insert("ChoiceParameters",   New Array(ChoiceParameters));
	
	OpenStandardForm = True;
	SSLSubsystemsIntegrationClient.AtStartValueSelection(ReportForm, SelectionConditions, Handler, OpenStandardForm);
	ReportsClientOverridable.AtStartValueSelection(ReportForm, SelectionConditions, Handler, OpenStandardForm);
	
	Return Not OpenStandardForm;
	
EndFunction

Function IsSelectMetadataObjects(AvailableTypes, Val MarkedValues, Handler) Export 
	
	TypesCount = AvailableTypes.Types().Count();
	
	If TypesCount = 1 Then
		IsSelectMetadataObjects =
			    AvailableTypes.ContainsType(Type("CatalogRef.MetadataObjectIDs"))
			Or AvailableTypes.ContainsType(Type("CatalogRef.ExtensionObjectIDs"));
		
	ElsIf TypesCount = 2 Then
		IsSelectMetadataObjects =
			    AvailableTypes.ContainsType(Type("CatalogRef.MetadataObjectIDs"))
			  And AvailableTypes.ContainsType(Type("CatalogRef.ExtensionObjectIDs"));
	Else
		IsSelectMetadataObjects = False;
	EndIf;
	
	If IsSelectMetadataObjects Then 
		CheckMarkedValues(MarkedValues, AvailableTypes);
		
		PickingParameters = StandardSubsystemsClientServer.MetadataObjectsSelectionParameters();
		PickingParameters.SelectedMetadataObjects = MarkedValues;
		PickingParameters.ChooseRefs = True;
		PickingParameters.Title = NStr("en = 'Pick tables';");
		
		StandardSubsystemsClient.ChooseMetadataObjects(PickingParameters, Handler);
	EndIf;
	
	Return IsSelectMetadataObjects;
	
EndFunction

Procedure StartSelectUsers(Form, FormItem, AvailableTypes, Val MarkedValues,
			ChoiceParameters, ChoiceHandler, FollowUpHandler) Export
	
	OtherTypes = New TypeDescription(AvailableTypes,,
		"CatalogRef.Users, CatalogRef.UserGroups,
		|CatalogRef.ExternalUsers, CatalogRef.ExternalUsersGroups");
	
	UsersTypes = New TypeDescription(AvailableTypes,, OtherTypes.Types());
	
	TypesCount = UsersTypes.Types().Count();
	
	If TypesCount = 1 Then
		IsSelectUsers =
			    UsersTypes.ContainsType(Type("CatalogRef.Users"))
			Or UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers"));
		
	ElsIf TypesCount = 2 Then
		IsSelectUsers =
			    UsersTypes.ContainsType(Type("CatalogRef.Users"))
			  And UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers"))
			Or UsersTypes.ContainsType(Type("CatalogRef.Users"))
			  And UsersTypes.ContainsType(Type("CatalogRef.UserGroups"))
			Or UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers"))
			  And UsersTypes.ContainsType(Type("CatalogRef.ExternalUsersGroups"));
		
	ElsIf TypesCount = 4 Then
		IsSelectUsers =
			    UsersTypes.ContainsType(Type("CatalogRef.Users"))
			  And UsersTypes.ContainsType(Type("CatalogRef.UserGroups"))
			  And UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers"))
			  And UsersTypes.ContainsType(Type("CatalogRef.ExternalUsersGroups"));
	Else
		IsSelectUsers = False;
	EndIf;
	
	If Not IsSelectUsers Then
		ExecuteNotifyProcessing(FollowUpHandler, Undefined);
		Return;
	EndIf;
	
	ChooseType =
		    TypesCount = 4
		Or TypesCount = 2
		  And UsersTypes.ContainsType(Type("CatalogRef.Users"))
		  And UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers"));
	
	Context = New Structure;
	Context.Insert("UsersTypes",     UsersTypes);
	Context.Insert("OtherTypes",            OtherTypes);
	Context.Insert("MarkedValues",    MarkedValues);
	Context.Insert("ChoiceParameters",       ChoiceParameters);
	Context.Insert("ChoiceHandler",      ChoiceHandler);
	Context.Insert("FollowUpHandler", FollowUpHandler);
	
	UserTypesList = New ValueList;
	UserTypesList.LoadValues(OtherTypes.Types());
	
	If Not ChooseType And OtherTypes.Types().Count() = 0 Then
		If AvailableTypes.ContainsType(Type("CatalogRef.Users")) Then
			UserTypesList.Add(Type("CatalogRef.Users"));
		Else
			UserTypesList.Add(Type("CatalogRef.ExternalUsers"));
		EndIf;
		SelectUsersAfterSelectionType(UserTypesList[0], Context);
	Else
		If UsersTypes.ContainsType(Type("CatalogRef.Users")) Then
			UserTypesList.Add(Type("CatalogRef.Users"));
		EndIf;
		If UsersTypes.ContainsType(Type("CatalogRef.ExternalUsers")) Then
			UserTypesList.Add(Type("CatalogRef.ExternalUsers"));
		EndIf;
		If OtherTypes.Types().Count() > 0 Then
			For Each ListItem In UserTypesList Do
				ListItem.Presentation = String (ListItem.Value);
			EndDo;
			UserTypesList.SortByPresentation();
		EndIf;
		Form.ShowChooseFromMenu(
			New NotifyDescription("SelectUsersAfterSelectionType", ThisObject, Context),
			UserTypesList,
			FormItem);
	EndIf;
	
EndProcedure

Procedure CheckMarkedValues(MarkedValues, AvailableTypes)
	
	IndexOf = MarkedValues.Count() - 1;
	
	While IndexOf >= 0 Do 
		Item = MarkedValues[IndexOf];
		IndexOf = IndexOf - 1;
		
		If Not AvailableTypes.ContainsType(TypeOf(Item.Value))
		 Or Not ValueIsFilled(Item.Value) Then 
			MarkedValues.Delete(Item);
		EndIf;
	EndDo;
	
EndProcedure

Procedure SelectUsersAfterSelectionType(SelectedElement, Context) Export
	
	If SelectedElement = Undefined Then
		Return;
	EndIf;
	
	PickingParameters = New Structure;
	
	If SelectedElement.Value = Type("CatalogRef.Users") Then
		FullChoiceFormName = "Catalog.Users.ChoiceForm";
		If Context.UsersTypes.ContainsType(Type("CatalogRef.UserGroups")) Then 
			PickingParameters.Insert("UsersGroupsSelection", True);
			PickFormHeader = NStr("en = 'Pick groups and users';");
		Else
			PickFormHeader = NStr("en = 'Pick users';");
		EndIf;
	ElsIf SelectedElement.Value = Type("CatalogRef.ExternalUsers") Then
		FullChoiceFormName = "Catalog.ExternalUsers.ChoiceForm";
		If Context.UsersTypes.ContainsType(Type("CatalogRef.UserGroups")) Then 
			PickingParameters.Insert("SelectExternalUsersGroups", True);
			PickFormHeader = NStr("en = 'Pick groups and external users';");
		Else
			PickFormHeader = NStr("en = 'Pick external users';");
		EndIf;
	Else
		ExecuteNotifyProcessing(Context.FollowUpHandler, SelectedElement);
		Return;
	EndIf;
	
	List = New ValueList;
	List.LoadValues(Context.MarkedValues.UnloadValues());
	CheckMarkedValues(List, Context.UsersTypes);
	SelectedUsers = List.UnloadValues();
	
	PickingParameters.Insert("ChoiceMode", True);
	PickingParameters.Insert("CloseOnChoice", False);
	PickingParameters.Insert("MultipleChoice", True);
	PickingParameters.Insert("AdvancedPick", True);
	PickingParameters.Insert("ChoiceParameters", Context.ChoiceParameters);
	PickingParameters.Insert("PickFormHeader", PickFormHeader);
	PickingParameters.Insert("SelectedUsers", SelectedUsers);
	
	Handler = New NotifyDescription("SelectUsersCompletion", ThisObject, Context);
	
	OpenForm(FullChoiceFormName, PickingParameters, ThisObject,,,, Handler);
	
EndProcedure

Procedure SelectUsersCompletion(Result, Context) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Context.OtherTypes.Types().Count() > 0 Then
		List = New ValueList;
		List.LoadValues(Result);
		List.FillChecks(True);
		
		For Each ListItem In Context.MarkedValues Do
			If Context.OtherTypes.ContainsType(TypeOf(ListItem.Value)) Then
				FillPropertyValues(List.Add(), ListItem);
			EndIf;
		EndDo;
		ExecuteNotifyProcessing(Context.ChoiceHandler, List);
	Else
		ExecuteNotifyProcessing(Context.ChoiceHandler, Result);
	EndIf;
	
EndProcedure

Procedure UpdateListViews(DestinationList, SourceList) Export 
	
	If TypeOf(SourceList) <> Type("ValueList") Then
		Return;
	EndIf;
	
	For Each Item In SourceList Do 
		
		If Not ValueIsFilled(Item.Presentation) Then 
			Continue;
		EndIf;
		
		FoundItem = DestinationList.FindByValue(Item.Value);
		
		If FoundItem <> Undefined Then 
			FoundItem.Presentation = Item.Presentation;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion