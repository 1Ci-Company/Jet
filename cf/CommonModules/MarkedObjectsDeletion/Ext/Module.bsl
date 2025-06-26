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

// Permanently deletes objects marked for deletion ensuring reference integrity.
// It must be called outside of transactions as the function manages transactions and batching.
//
// Parameters:
//  ObjectsToDelete - Array of ExchangePlanRef 
//                   - Array of CatalogRef
//                   - Array of DocumentRef
//                   - Array of ChartOfAccountsRef
//                   - Array of ChartOfCalculationTypesRef
//                   - Array of BusinessProcessRef
//                   - Array of TaskRef - the objects for deletion.
//  DeletionMode - String - Deletion method. Takes the following values:
//		Standard - Deletes objects and ensures the reference integrity and multi-user work. 
//					    Exclusive - Deletes objects and ensures the reference integrity with the exclusive mode.
//		If it fails to set the exclusive mode, an exception is raised.
//					    Simplified - Deletes objects ensuring the reference integrity of the objects that are not marked for deletion.
//		Clears the references to the objects being deleted in the objects marked for deletion objects.
//					    
//
// Returns:	
//    Structure:
//      * Success - Boolean - True if all the objects were deleted.
//      * ObjectsPreventingDeletion - ValueTable - the objects that have references to the objects to be deleted:
//        ** ItemToDeleteRef - AnyRef
//        ** UsageInstance1 - AnyRef - a reference to the object that prevents deletion.
//									  - Undefined - — the object is used in a constant or 
//									  	an error occurred while deleting. The constant details are specified in the Metadata field.
//									  	Error details are specified in the ErrorDescription field.
//        ** ErrorDescription - String - error details upon the object deletion.
//        ** DetailedErrorDetails - String - detailed error description upon the object deletion.
//        ** Metadata - MetadataObject - metadata details on the object that prevents deletion.
//        * Trash - Array of AnyRef- successfully deleted objects.
//        * NotTrash - Array of AnyRef - not deleted objects.
//
Function ToDeleteMarkedObjects(ObjectsToDelete, DeletionMode = "Standard") Export
	Return MarkedObjectsDeletionInternal.ToDeleteMarkedObjectsInternal(ObjectsToDelete, DeletionMode);
EndFunction

// Generates the internal and overridable objects marked for deletion considering separation and filtering.
//  When executed in separated session, the objects will be returned considering separation.
// The overridable items are excluded from search results.
// 
// Parameters:
//   MetadataFilter - ValueList of String - A list of full names of metadata objects where
// 												 the marked for deletion objects will be searched for.
// 												 For example, "Catalog.Products".
//                   - Undefined - — filter by metadata objects will not be applied.
//
//  SearchForTechnologicalObjects - Boolean - if True, the search will be carried out in the metadata objects
//											added to the reference search exceptions. 
//											See Common.RefSearchExclusions. 
//											For example, in the AccessKeys catalog.
//
//
// Returns:
//   Array of AnyRef
//
Function MarkedForDeletion(Val MetadataFilter = Undefined, SearchForTechnologicalObjects = False) Export

	IsSaaSModel = Common.DataSeparationEnabled();
	InDataArea = ?(IsSaaSModel, Common.SeparatedDataUsageAvailable(), False);
	MetadataFilter = ?(MetadataFilter <> Undefined And MetadataFilter.Count() > 0,
		MetadataFilter.UnloadValues(), Undefined);

	ObjectsToDeleteSearchExceptions = New Array;
	SearchExceptions = New Map;
	If Not SearchForTechnologicalObjects Then
		RefSearchExclusions = Common.RefSearchExclusions();
		For Each SearchException In RefSearchExclusions Do
			If SearchException.Value = "*" Then
				ObjectsToDeleteSearchExceptions.Add(SearchException.Key);
				SearchExceptions[SearchException.Key] = True;
			EndIf;
		EndDo;
	EndIf;

	MarkedForDeletion = New Array;
	For Each Item In FindMarkedForDeletion( , MetadataFilter, ObjectsToDeleteSearchExceptions) Do
		If Not MatchesMetadataFilter(MetadataFilter, Item) Or SearchExceptions[Item.Metadata()]
			<> Undefined Then
			Continue;
		EndIf;

		MarkedForDeletion.Add(Item);
	EndDo;

	Result = New Array;
	ArePredefinedItems = Common.ArePredefinedItems(MarkedForDeletion);
	TypesInformation = MarkedObjectsDeletionInternal.TypesInformation(MarkedForDeletion);

	For Each Item In MarkedForDeletion Do

		If Not MatchesMetadataFilter(MetadataFilter, Item) Or SearchExceptions[Item.Metadata()]
			<> Undefined Then
			Continue;
		EndIf;

		Information = TypesInformation[TypeOf(Item)];
		IsPredefined = ArePredefinedItems[Item];
		IsSharedObjectInDataArea = InDataArea And Not Information.Separated1;

		ObjectSubjectToDeletion = Not IsPredefined And Not IsSharedObjectInDataArea
			And (Not Information.Technical Or SearchForTechnologicalObjects);
		If ObjectSubjectToDeletion Then
			Result.Add(Item);
		EndIf;

	EndDo;

	Return Result;
EndFunction

#Region FormsPublic

// Sets visibility on the objects marked for deletion.
// 
// Parameters:
//   Form - ClientApplicationForm - a form containing dynamic list
//   MarkedObjectsDisplaySettings - See MarkedObjectsDisplaySettings
//                                          - — FormTable is an item of the dynamic list form. 
//
// Example:
// 	// To set one list
// 	MarkedObjectsDeletion.OnCreateAtServer(ThisObject, Elements.List);
// 	
// 	// To set several lists
// 	MarkedObjectsViewSettings = MarkedObjectsDeletion.MarkedObjectsViewSettings();
// 	Setting = ViewSettings.Add();
// 	Setting.FormItemName = Items.List1.Name;
// 	Setting = ViewSettings.Add();
// 	Setting.FormItemName = Items.List2.Name;
// 	 
// 	// Setting the main table is required to go to the marked objects list 
// 	// with a predefined filter
// 	MainListTables = New ValueList();
// 	MainListTables.Add("Catalog.Products");
// 	Setting.MetadataTypes = MainListTables;
// 	MarkedObjectsDeletion.OnCreateAtServer(ThisObject, MarkedObjectsViewSettings);
//
Procedure OnCreateAtServer(Form, Val MarkedObjectsDisplaySettings) Export
	If TypeOf(MarkedObjectsDisplaySettings) <> Type("ValueTable") Then
		MarkedObjectsDisplaySettings = MarkedListObjectsDisplaySetup(Form,
			MarkedObjectsDisplaySettings);
	Else
		FillListNamesByFormItems(Form, MarkedObjectsDisplaySettings);
	EndIf;

	CreateSettingsStorageAttribute(Form);
	For Each Setting In MarkedObjectsDisplaySettings Do
		FilterValue = MarkedObjectsDeletionInternal.ImportObjectsMarkedForDeletionViewSetting(
			Form.FormName, Setting.ListName);
		SpecifyListSettings(Form, Setting, FilterValue);
	EndDo;

EndProcedure

// Generated the settings of displaying the objects marked for deletion.
// 
// Returns:
//   ValueTable:
//   * FormItemName - String - the form table name connected with the dynamic list.
//   * MetadataTypes - ValueList of String - the types of the objects displayed in the dynamic list.
//   * ListName - String - optional. The dynamic list name on the form.
//
Function MarkedObjectsDisplaySettings() Export

	Settings = New ValueTable;
	Settings.Columns.Add("ListName", New TypeDescription("String"));
	Settings.Columns.Add("MetadataTypes", New TypeDescription("ValueList"));
	Settings.Columns.Add("FormItemName", New TypeDescription("String"));
	Return Settings;

EndFunction

// Returns information on the setting of marked object deletion on schedule.
// See the usage example in the documentation.
// 
// Returns:
//   Structure:
//   * Schedule - See ScheduledJobsServer.JobSchedule
//   * Use - Boolean - indicates whether a scheduled job is used.
//
Function ModeDeleteOnSchedule() Export
	Return MarkedObjectsDeletionInternalServerCall.ModeDeleteOnSchedule();
EndFunction

// Sets the Show marked objects command mark according to the saved user settings.
// Used to set the initial value of the form button mark.
// 
// Parameters:
//   Form - ClientApplicationForm 	
//   FormTable - FormTable - the form table that relates to the dynamic list
//   FormButton - FormButton - a button connected with the Show marked objects command
//
Procedure SetShowMarkedObjectsCommandMark(Form, FormTable, FormButton) Export
	FilterValue = MarkedObjectsDeletionInternal.ImportObjectsMarkedForDeletionViewSetting(
		Form.FormName, FormTable.Name);
	Form.Items.ShowObjectsMarkedForDeletion.Check = Not FilterValue;
EndProcedure

#EndRegion

// Returns a list of objects being deleted and whose references are present in the Source object.
// For records that are subordinate to a register, always returns a empty Ref list in order to:
//  - Mitigate the performance downgrade.
//  - Ensure the stability of the automatic record generation. For example, when closing a month. 
//
// Parameters:
//   Source - CatalogObject
//            - DocumentObject
//            - InformationRegisterRecordSet - Object to search in for the objects to be deleted.
//
// Returns:
//   Map of KeyAndValue:
//   * Key - AnyRef - Object to be deleted whose reference is present in Source.
//   * Value - String - Reference presentation.
//
Function RefsToObjectsToDelete(Source) Export
	RefsToObjectsToDelete = New Map;
	SourceMetadata = Source.Metadata();

	If CommonClientServer.HasAttributeOrObjectProperty(Source, "Ref") Then
		LinkDescriptions = ReferenceToObjectsToDeleteInTheObject(ObjectDetails(Source, SourceMetadata),
			SourceMetadata);
	ElsIf Common.IsConstant(SourceMetadata) Then
		ConstantValue = Source.Value;
		If Common.IsReference(TypeOf(ConstantValue)) Then
			LinkDescriptions = NewLinksInTheObject();
			ReferenceDetails = LinkDescriptions.Add();
			ReferenceDetails.Ref = ConstantValue;
			ReferenceDetails.Table = SourceMetadata.FullName();
			ReferenceDetails.Field = "Value";
		EndIf;
	ElsIf IsIndependentInformationRegister(SourceMetadata) Then
		LinkDescriptions = ReferencesToObjectsToDeleteInTheSet(
			SetDetails(Source, SourceMetadata), SourceMetadata);
	Else
		Return New Map;
	EndIf;

	RefsToDelete = LockedRefsToDelete(LinkDescriptions.UnloadColumn("Ref"));
	DeletedLinksDeleteMarks = Common.ObjectsAttributeValue(RefsToDelete, "DeletionMark");

	AddedLinks = LinksAddedWhenTheObjectWasChanged(LinkDescriptions, DeletedLinksDeleteMarks);
	For Each ReferenceDetails In AddedLinks Do
		RefsToObjectsToDelete.Insert(ReferenceDetails.Ref, ReferenceDetails.Presentation);
	EndDo;

	Return RefsToObjectsToDelete;
EndFunction

#Region ObsoleteProceduresAndFunctions

// Deprecated. Outdated. Check box state for the setup form of marked objects deletion.
// Use instead MarkedObjectsDeletion.ModeDeleteOnSchedule.
//
// Returns: 
//   Boolean - a value.
//
Function DeleteOnScheduleCheckBoxValue() Export

	Filter = New Structure;
	Filter.Insert("Metadata", Metadata.ScheduledJobs.MarkedObjectsDeletion);
	Jobs = ScheduledJobsServer.FindJobs(Filter);

	For Each Job In Jobs Do
		Return Job.Use;
	EndDo;

	Return False;

EndFunction

#EndRegion

#EndRegion

#Region Private

// Generates the settings of hiding the marked objects for the dynamic list.
// 
// Parameters:
//   Form - ClientApplicationForm
//   ItemList - FormTable
//   MetadataTypes - Array of String
//                  - Undefined - — the main dynamic list table by default 
//
// Returns:
//   See MarkedObjectsDisplaySettings
//
Function MarkedListObjectsDisplaySetup(Form, ItemList, MetadataTypes = Undefined)
	CommonClientServer.CheckParameter("MarkedListObjectsDisplaySetup", "ItemList",
		ItemList, New TypeDescription("FormTable"));
	List = Form[ItemList.DataPath]; // DynamicList

	Settings = MarkedObjectsDisplaySettings();
	Setting = Settings.Add();
	Setting.ListName = ItemList.DataPath;
	Setting.FormItemName = ItemList.Name;
	If MetadataTypes = Undefined And ValueIsFilled(List.MainTable) Then

		TypesList = New ValueList;
		TypesList.Add(List.MainTable);
		Setting.MetadataTypes = TypesList;
	Else
		Setting.MetadataTypes = MetadataTypes;
	EndIf;

	Return Settings;
EndFunction

// Outputs controls on the form and resolves the conflict of fixed and user list settings.
// 
// Parameters:
//   Form - ClientApplicationForm
//   Setting - See MarkedObjectsDisplaySettings
//
Procedure SpecifyListSettings(Form, Setting, FilterValue)

	DeleteUserSettingOfObjectsMarkedForDeletionFilter(Form, Setting.ListName);
	MarkedObjectsDeletionInternalClientServer.SetFilterByDeletionMark(Form[Setting.ListName],
		FilterValue);
	SaveSettingToFormData(Form, Setting, FilterValue);

EndProcedure

Procedure SaveSettingToFormData(Form, Setting, FilterValue)
	SettingDetails = Common.ValueTableRowToStructure(Setting);
	SettingDetails.Insert("FilterValue", FilterValue);
	SettingDetails.Insert("CheckMarkValue", Not FilterValue);
	Form.MarkedObjectsDeletionParameters.Insert(Setting.FormItemName, SettingDetails);
EndProcedure

// Parameters:
//   Form - ClientApplicationForm:
//     * MarkedObjectsDeletionParameters - Structure 
//
Procedure CreateSettingsStorageAttribute(Form)

	AttributeName = "MarkedObjectsDeletionParameters";
	PropertiesValues = New Structure(AttributeName, Null);
	FillPropertyValues(PropertiesValues, Form);
	MarkedObjectsDeletionParameters = PropertiesValues.MarkedObjectsDeletionParameters;
	If TypeOf(MarkedObjectsDeletionParameters) <> Type("Structure") Then
		AttributesToBeAdded = New Array;
		AttributesToBeAdded.Add(New FormAttribute(AttributeName, New TypeDescription));
		Form.ChangeAttributes(AttributesToBeAdded);
		Form.MarkedObjectsDeletionParameters = New Structure;
	EndIf;

EndProcedure

// Removes the filter from the saved user settings by the DeletionMark field
// 
// Parameters:
//   Form - ClientApplicationForm 
//   ListName - String 
//
Procedure DeleteUserSettingOfObjectsMarkedForDeletionFilter(Form, ListName)

	SettingsKey = Form.FormName + "." + ListName + "/CurrentUserSettings";
	Settings = Common.SystemSettingsStorageLoad(SettingsKey, ""); // DataCompositionUserSettings -
	DynamicList = Form[ListName]; // DynamicList - 
	DeletionMarkField = DynamicList.SettingsComposer.Settings.FilterAvailableFields.Items.Find(
		"DeletionMark");

	If Settings <> Undefined And DeletionMarkField <> Undefined Then
		DeleteUserSettingsFilterItem(Settings, DeletionMarkField);
		Common.SystemSettingsStorageSave(SettingsKey, "", Settings);
	EndIf;

EndProcedure

Procedure DeleteUserSettingsFilterItem(Val Settings, Val DeletionMarkField)

	For Each Setting In Settings.Items Do

		If TypeOf(Setting) <> Type("DataCompositionFilter") Then
			Continue;
		EndIf;

		For Cnt = -(Setting.Items.Count() - 1) To 0 Do
			SettingItem = Setting.Items[-Cnt]; // DataCompositionFilter
			If SettingItem.LeftValue = DeletionMarkField.Field Then
				Setting.Items.Delete(SettingItem);
			EndIf;
		EndDo;

	EndDo;

EndProcedure

//	Parameters:
//    MarkedObjectsDisplaySettings - See MarkedListObjectsDisplaySetup
//
Procedure FillListNamesByFormItems(Form, MarkedObjectsDisplaySettings)
	For Each Setting In MarkedObjectsDisplaySettings Do
		FormTable = Form.Items[Setting.FormItemName];// FormTable - 
		Setting.ListName = FormTable.DataPath;
	EndDo;
EndProcedure

Function RefsToObjectsToDeleteInAttributes(SourceDetails, Attributes)
	ValuesOfRefTypes = NewLinksInTheObject();

	For Each Attribute In Attributes Do

		If Attribute.Name = "Ref" Then
			Continue;
		EndIf;

		Value = SourceDetails.Source[Attribute.Name];
		ValueType = TypeOf(Value);
		If ValueIsFilled(Value) And Common.IsReference(ValueType) Then
			ReferenceDetails = ValuesOfRefTypes.Add();
			ReferenceDetails.Ref = Value;
			ReferenceDetails.Table = SourceDetails.Table;
			ReferenceDetails.Field = Attribute.Name;
			ReferenceDetails.FilterCriterion = SourceDetails.FilterCriterion;
		EndIf;
	EndDo;

	Return ValuesOfRefTypes;
EndFunction

Function RefsToObjectsToDeleteInTabularSections(SourceDetails, TabularSections,
	AttributesCollectionName = "Attributes")
	ValuesOfRefTypes = NewLinksInTheObject();

	For Each TabularSection In TabularSections Do

		If Not CommonClientServer.HasAttributeOrObjectProperty(SourceDetails.Source,
			TabularSection.Name) Then
			Continue;
		EndIf;

		For Each TSRow In SourceDetails.Source[TabularSection.Name] Do
			TabularSectionDetails = Common.CopyRecursive(SourceDetails);
			TabularSectionDetails.Source = TSRow;
			TabularSectionDetails.Table = SourceDetails.Table + "." + TabularSection.Name;

			CommonClientServer.SupplementTable(
				RefsToObjectsToDeleteInAttributes(TabularSectionDetails, TabularSection[AttributesCollectionName]),
				ValuesOfRefTypes);
		EndDo;
	EndDo;

	Return ValuesOfRefTypes;
EndFunction

Function RefsToObjectsToDeleteInRecordSet(SourceDetails, Val Attributes, IsAccountingRegister = False)
	ValuesOfRefTypes = NewLinksInTheObject();

	For Each Record In SourceDetails.Source Do
		RecordDetails = Common.CopyRecursive(SourceDetails);
		RecordDetails.Source = Record;

		For Each FilterCriterion In SourceDetails.FilterCriterion Do
			RecordDetails.FilterCriterion.Insert(FilterCriterion.Key, Record[FilterCriterion.Key]);
		EndDo;

		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInAttributes(RecordDetails, Attributes), ValuesOfRefTypes);
	EndDo;

	Return ValuesOfRefTypes;
EndFunction

// Parameters:
//   Attributes -  MetadataObjectCollection
//
// Returns:
//   Array
//
Function GenerateAccountingRegistersAttributesWithCorrespondence(Val Attributes)
	RegisterWithCorrespondenceAttributes = New Array;

	For Each Attribute In Attributes Do
		If CommonClientServer.HasAttributeOrObjectProperty(Attribute, "Balance")
			And (Attribute.Balance) Then
			RegisterWithCorrespondenceAttributes.Add(New Structure("Name", Attribute.Name));
		Else
			RegisterWithCorrespondenceAttributes.Add(New Structure("Name", Attribute.Name + "Dr"));
			RegisterWithCorrespondenceAttributes.Add(New Structure("Name", Attribute.Name + "Cr"));
		EndIf;
	EndDo;

	Return RegisterWithCorrespondenceAttributes;
EndFunction

#Region RefsToObjectsToDelete

Function ReferenceToObjectsToDeleteInTheObject(Source, SourceMetadata)
	ValuesOfRefTypes = NewLinksInTheObject();

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "StandardAttributes") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInAttributes(Source, SourceMetadata.StandardAttributes),
			ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "AddressingAttributes") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInAttributes(Source, SourceMetadata.AddressingAttributes),
			ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "Attributes") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInAttributes(Source, SourceMetadata.Attributes), ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "TabularSections") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInTabularSections(Source, SourceMetadata.TabularSections),
			ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "StandardTabularSections") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInTabularSections(Source, SourceMetadata.StandardTabularSections,
			"StandardAttributes"), ValuesOfRefTypes);
	EndIf;

	Return ValuesOfRefTypes;
EndFunction

Function ReferencesToObjectsToDeleteInTheSet(Source, SourceMetadata)
	ValuesOfRefTypes = NewLinksInTheObject();
	IsAccountingRegister = Common.IsAccountingRegister(SourceMetadata);

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "Dimensions") Then
		If Common.IsAccountingRegister(SourceMetadata) And SourceMetadata.Correspondence Then
			Attributes = GenerateAccountingRegistersAttributesWithCorrespondence( SourceMetadata.Dimensions);
		Else
			Attributes =  SourceMetadata.Dimensions;
		EndIf;
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInRecordSet(Source, Attributes, IsAccountingRegister), ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "Resources") Then
		If Common.IsAccountingRegister(SourceMetadata) And SourceMetadata.Correspondence Then
			Attributes = GenerateAccountingRegistersAttributesWithCorrespondence( SourceMetadata.Resources);
		Else
			Attributes =  SourceMetadata.Resources;
		EndIf;
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInRecordSet(Source, Attributes, IsAccountingRegister), ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "StandardAttributes") Then
		If IsAccountingRegister Then
			Attributes = GenerateStandardAccountingRegisterAttributes(SourceMetadata);
		Else
			Attributes = SourceMetadata.StandardAttributes;
		EndIf;
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInRecordSet(Source, Attributes, IsAccountingRegister), ValuesOfRefTypes);
	EndIf;

	If CommonClientServer.HasAttributeOrObjectProperty(SourceMetadata, "Attributes") Then
		CommonClientServer.SupplementTable(
			RefsToObjectsToDeleteInRecordSet(Source, SourceMetadata.Attributes, IsAccountingRegister),
			ValuesOfRefTypes);
	EndIf;

	Return ValuesOfRefTypes;
EndFunction

// Parameters:
//   SourceMetadata - MetadataObjectAccountingRegister
//
// Returns:
//   Array
//
Function GenerateStandardAccountingRegisterAttributes(SourceMetadata)
	StandardAttributes = New Array;

	StandardAttributes.Add(New Structure("Name", "Recorder"));
	If SourceMetadata.Correspondence Then
		StandardAttributes.Add(New Structure("Name", "AccountDr"));
		StandardAttributes.Add(New Structure("Name", "AccountCr"));
	Else
		StandardAttributes.Add(New Structure("Name", "Account"));
	EndIf;

	If SourceMetadata.ChartOfAccounts.MaxExtDimensionCount > 0 Then
		If SourceMetadata.Correspondence Then
			StandardAttributes.Add(New Structure("Name", "ExtDimensionDr"));
			StandardAttributes.Add(New Structure("Name", "ExtDimensionCr"));
		Else
			StandardAttributes.Add(New Structure("Name", "ExtDimension"));
		EndIf;
	EndIf;

	Return StandardAttributes;
EndFunction

Function MatchesMetadataFilter(MetadataFilter, Item)
	Return (Not ValueIsFilled(MetadataFilter) Or MetadataFilter.Find(Item.Metadata().FullName())
		<> Undefined);
EndFunction

Function IsIndependentInformationRegister(SourceMetadata)
	Result = True;

	If Not Common.IsInformationRegister(SourceMetadata) Then
		Return False;
	EndIf;

	For Each StandardAttribute In SourceMetadata.StandardAttributes Do
		If StandardAttribute.Name = "Recorder" Then
			Result = False;
			Break;
		EndIf;
	EndDo;

	Return Result;
EndFunction

Function NewLinksInTheObject()
	Table = New ValueTable;
	Table.Columns.Add("Ref");
	Table.Columns.Add("Table", New TypeDescription("String"));
	Table.Columns.Add("Field", New TypeDescription("String"));
	Table.Columns.Add("FilterCriterion", New TypeDescription("Map"));

	Return Table;
EndFunction

Function ObjectDetails(Source, SourceMetadata)
	LongDesc = New Structure;
	LongDesc.Insert("Source", Source);
	LongDesc.Insert("Table", SourceMetadata.FullName());
	LongDesc.Insert("FilterCriterion", New Map);
	LongDesc.FilterCriterion.Insert("Ref", Source.Ref);

	Return LongDesc;
EndFunction

// Parameters:
//   Source - InformationRegisterRecordSet
//   SourceMetadata - MetadataObjectInformationRegister
//
Function SetDetails(Source, SourceMetadata)
	LongDesc = New Structure;
	LongDesc.Insert("Source", Source);
	LongDesc.Insert("Table", SourceMetadata.FullName());
	LongDesc.Insert("FilterCriterion", New Map);
	For Each Dimension In SourceMetadata.Dimensions Do
		LongDesc.FilterCriterion.Insert(Dimension.Name);
	EndDo;

	For Each Attribute In SourceMetadata.StandardAttributes Do
		If StrCompare(Attribute.Name, "Period") Then
			LongDesc.FilterCriterion.Insert(Attribute.Name);
			Break;
		EndIf;
	EndDo;

	Return LongDesc;
EndFunction

Function LinksAddedWhenTheObjectWasChanged(ReferencesDetails, LinksMarkedForDeletion)

	Result = New ValueTable;
	Result.Columns.Add("Ref");
	Result.Columns.Add("Presentation", New TypeDescription("String"));

	TheSeparatorPackageRequests = Chars.LF + "UNION ALL" + Chars.LF;

	QueryTemplate = "
					|SELECT
					|	&RefValue AS Ref,
					|	PRESENTATION(&RefValue) AS Presentation
					|WHERE
					|	NOT TRUE IN (
					|		SELECT TOP 1
					|			TRUE
					|		FROM 
					|			#TableName AS Table
					|		WHERE
					|			&LinkSelectionCriteria)";

	OtherLinkParameters = 0;
	OtherSelectionParameters = 0;

	Query = New Query;
	For Each ObjectTheValueOfTheNotes In LinksMarkedForDeletion Do

		If Not ObjectTheValueOfTheNotes.Value Then
			Continue;
		EndIf;

		RefValue =  ObjectTheValueOfTheNotes.Key;

		DescriptionOfTheLink = ReferencesDetails.FindRows(New Structure("Ref", RefValue));
		For Each RefToDelete In DescriptionOfTheLink Do
			ReferenceParameter = "RefValue" + XMLString(OtherLinkParameters);
			QueryText = StrReplace(QueryTemplate, "&RefValue", "&" + ReferenceParameter);
			QueryText = StrReplace(QueryText, "#TableName", RefToDelete.Table);
			Query.Parameters.Insert(ReferenceParameter, RefValue);

			ConditionText= New Array;
			For Each Condition In RefToDelete.FilterCriterion Do
				ConditionText.Add("Table." + Condition.Key + " = &Parameter" + OtherSelectionParameters);
				Query.Parameters.Insert("Parameter" + XMLString(OtherSelectionParameters), Condition.Value);
				OtherSelectionParameters= OtherSelectionParameters + 1;
			EndDo;
			ConditionText.Add("Table." + RefToDelete.Field + " = &" + ReferenceParameter);
			FilterText1 = StrConcat(ConditionText, Chars.LF + "And" + Chars.NBSp);
			QueryText = StrReplace(QueryText, "&LinkSelectionCriteria", FilterText1);

			Query.Text = Query.Text + ?(Not IsBlankString(Query.Text), TheSeparatorPackageRequests, "") + QueryText;
			OtherLinkParameters = OtherLinkParameters + 1;
		EndDo;

	EndDo;

	If Not IsBlankString(Query.Text) Then
		QueryResult = Query.Execute();
		Result = QueryResult.Unload();
	EndIf;

	Return Result;
EndFunction

Function LockedRefsToDelete(RefsToDelete)

	UnlockTime = CurrentSessionDate() - MarkedObjectsDeletionInternal.TheLifetimeOfALock();
	Query = New Query("SELECT
						  |	ObjectsToDelete.Object AS Ref
						  |FROM
						  |	InformationRegister.ObjectsToDelete AS ObjectsToDelete
						  |WHERE
						  |	ObjectsToDelete.Object IN(&ObjectsToDelete)
						  |	AND ObjectsToDelete.Period >= &UnlockTime");

	Query.SetParameter("ObjectsToDelete", RefsToDelete);
	Query.SetParameter("UnlockTime", UnlockTime);

	Return Query.Execute().Unload().UnloadColumn("Ref");

EndFunction

#EndRegion

#EndRegion