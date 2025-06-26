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

// Search for duplicates for the specified SampleObject value.
//
// Parameters:
//     SearchArea - String - Data table name (full metadata name) of the search location.
//                              For example, "Catalog.Products". 
//                              Supports search in catalogs, charts of characteristic types, calculation types, and charts of accounts.
//     SampleObject - AnyRef, CatalogObject - Item whose duplicates are to be found.
//     AdditionalParameters - Arbitrary - Parameter to pass to event handlers.
//
// Returns:
//     ValueTable:
//       * Ref       - AnyRef - Item reference.
//       * Code          - String
//                      - Number - Item code.
//       * Description - String - Item description.
//       * Parent     - AnyRef - Parent to the group of duplicates.
//                                      If Parent is empty, the item is the parent to the group.
//       * OtherFields - Arbitrary - a value of the corresponding filter fields and criteria for comparing duplicates.
// 
Function FindItemDuplicates(Val SearchArea, Val SampleObject, Val AdditionalParameters) Export
	
	DuplicatesSearchParameters = New Structure;
	DuplicatesSearchParameters.Insert("PrefilterComposer");
	DuplicatesSearchParameters.Insert("DuplicatesSearchArea", SearchArea);
	DuplicatesSearchParameters.Insert("TakeAppliedRulesIntoAccount", True);
	
	// From parameters.
	DuplicatesSearchParameters.Insert("SearchRules", New ValueTable);
	DuplicatesSearchParameters.SearchRules.Columns.Add("Attribute", New TypeDescription("String"));
	DuplicatesSearchParameters.SearchRules.Columns.Add("Rule",  New TypeDescription("String"));
	
	// See DataProcessor.DuplicateObjectsDetection
	DuplicatesSearchParameters.PrefilterComposer = New DataCompositionSettingsComposer;
	SearchAreaMetadata = Common.MetadataObjectByFullName(SearchArea);
	AvailableFilterAttributes = AvailableFilterAttributesNames(SearchAreaMetadata.StandardAttributes);
	AvailableFilterAttributes = ?(IsBlankString(AvailableFilterAttributes), ",", AvailableFilterAttributes)
		+ AvailableFilterAttributesNames(SearchAreaMetadata.Attributes);
	QueryText = "SELECT * FROM #Table";
	QueryText = StrReplace(QueryText, "*", Mid(AvailableFilterAttributes, 2));
	QueryText = StrReplace(QueryText, "#Table", SearchArea);
	
	CompositionSchema = New DataCompositionSchema;
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = QueryText;
	DataSet.AutoFillAvailableFields = True;
	
	DuplicatesSearchParameters.PrefilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(CompositionSchema));
	
	SearchProcessing = DataProcessors.DuplicateObjectsDetection.Create();
	
	UseAppliedRules = SearchProcessing.HasSearchForDuplicatesAreaAppliedRules(SearchArea);
	If UseAppliedRules Then
		AppliedParameters = DuplicatesSearchParameters(DuplicatesSearchParameters.SearchRules, 
			DuplicatesSearchParameters.PrefilterComposer);
		SearchAreaManager = SearchProcessing.SearchForDuplicatesAreaManager(SearchArea);
		SearchAreaManager.DuplicatesSearchParameters(AppliedParameters, AdditionalParameters);
		DuplicatesSearchParameters.Insert("AdditionalParameters", AdditionalParameters);
	EndIf;
	
	DuplicatesGroups = SearchProcessing.DuplicatesGroups(DuplicatesSearchParameters, SampleObject);
	Result = DuplicatesGroups.DuplicatesTable;
	
	For Each Item In Result.FindRows(New Structure("Parent", Undefined)) Do
		Result.Delete(Item);
	EndDo;
	EmptyRef = SearchAreaManager.EmptyRef();
	For Each Item In Result.FindRows(New Structure("Ref", EmptyRef)) Do
		Result.Delete(Item);
	EndDo;
	
	Return Result; 
EndFunction

// Adds related subordinate objects to a duplicate collection.
//
// Parameters:
//  ReplacementPairs		 - See Common.ReplaceReferences.ReplacementPairs
//  ReplacementParameters	 - See Common.RefsReplacementParameters
//
Procedure SupplementDuplicatesWithLinkedSubordinateObjects(ReplacementPairs, ReplacementParameters) Export
	
	ObjectsLinks = Common.SubordinateObjects();
	SubordinateObjectsLinks = SubordinateObjectsLinksByTypes();
	SubordinateObjectsDetails = New Map;

	For Each LinkRow In ObjectsLinks Do
		AddSubordinateObjectsLinks(SubordinateObjectsLinks, LinkRow);	
    	FillObjectDetails(SubordinateObjectsDetails, LinkRow);
	EndDo;
	
	ReplacementTables = New Map;
	For Each OriginalDuplicate In ReplacementPairs Do
		SelectUsedLinks(OriginalDuplicate.Value, SubordinateObjectsLinks);
		AddToReplacementTables(OriginalDuplicate, ReplacementTables, SubordinateObjectsLinks);
	EndDo;

	Filter = New Structure("Used", True);
	UsedLinks = SubordinateObjectsLinks.Copy(Filter);
	If UsedLinks.Count() = 0 Then
		Return;
	EndIf;
	UsedLinks.Sort("Key");
	
	TempTablesManager = New TempTablesManager;
	PutReplacementsTablesInQuery(TempTablesManager, ReplacementTables);

	FoundDuplicatesTables = New Map;
	PackageParts = New Array;
	Position = 0;
	While Position <= UsedLinks.Count() - 1 Do
		
		SubordinateObjectName = UsedLinks[Position].Key;
		SubordinateObjectDetails = SubordinateObjectsDetails[SubordinateObjectName];
		Filter = New Structure("Key, Used", SubordinateObjectName, True);
		SubordinateObjectLinks = SubordinateObjectsLinks.FindRows(Filter);
		PackageParts.Add(ObjectsForReplacementQueryText( SubordinateObjectDetails, SubordinateObjectLinks));
		
		FoundDuplicatesTables.Insert(SubordinateObjectDetails.Key, PackageParts.Count() * 3 - 1); // 3 - Number of packages to add. 
		Position = Position + SubordinateObjectLinks.Count();
	
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text = StrConcat(PackageParts, Common.QueryBatchSeparator());	
	Result = Query.ExecuteBatch();
	
	For Each Replacement In FoundDuplicatesTables Do
		
		NotPickedReplacements = New Array;
		SubordinateObjectDetails = SubordinateObjectsDetails[Replacement.Key];
		PickedReplacements = Result[Replacement.Value].Unload();
		
		AddFoundKeysToDuplicates(PickedReplacements, ReplacementPairs, NotPickedReplacements);
		
		If ValueIsFilled(SubordinateObjectDetails.SearchMethodModuleName) 
			And NotPickedReplacements.Count() > 0 Then
			ExecuteSearchByAppliedRules(UsedLinks, NotPickedReplacements, SubordinateObjectDetails,
				ReplacementPairs);
		EndIf;
	
	EndDo;
	
EndProcedure

// Searches for all instances of the given string in the passed string array.
//
// Parameters:
//  InitialString - String - A list of strings beings searched, which are separated by the character
//                            passed in the "Separator" parameter.
//  SearchString   - String - String to be found.
//  Separator    - String - A character that delimits the string into substrings.
//                            It is required if the passed strings is an array of strings.
//  SearchParameters - See ParametersOfSearchForSimilarStrings.
//
// Example:
//  SourceString = "Turning lathe~Desk lamp~Food container~Wood container";
//  IndexesOfFuzzyMatches = DuplicateObjectsDetection.FindSimilarStrings(SourceString, "Food container");
//  The function will return "2,3", which are the indexes of the items "Food container" and "Wood container".
//  
//
// Returns:
//  String - Comma-delimited list of duplicate indexes (indexing starts with "0").
//
Function FindSimilarStrings(InitialString, SearchString, Separator = "~", SearchParameters = Undefined) Export
	
	CreateAddIn = TypeOf(SearchParameters) <> Type("Structure")
		Or Not SearchParameters.Property("SearchAddIn")
		Or SearchParameters.SearchAddIn = Undefined;
	
	StringsComparisonForSimilarity = ParametersOfSearchForSimilarStrings(CreateAddIn);
	If TypeOf(SearchParameters) = Type("Structure") Then
		FillPropertyValues(StringsComparisonForSimilarity, SearchParameters, , ?(CreateAddIn, "SearchAddIn", ""));
	EndIf;
	
	SearchAddIn = StringsComparisonForSimilarity.SearchAddIn;
	ExceptionWords = Lower(StrConcat(StringsComparisonForSimilarity.ExceptionWords, Separator));
	
	RowIndexes = SearchAddIn.StringSearch(Lower(SearchString), Lower(InitialString), "~", 
		StringsComparisonForSimilarity.SmallStringsLength, StringsComparisonForSimilarity.SmallStringsMatchPercentage, 
		StringsComparisonForSimilarity.StringsMatchPercentage, ExceptionWords);
	
	Return StrReplace(RowIndexes, Char(8239), "");
	
EndFunction

// Returns parameters for the "FindSimilarStrings" function.
// 
// Parameters:
//  AttachAddInSSL - Boolean - If set to "True", the string search add-in will be attached.
//                                  Intended for optimization in cases where searching for similar strings is expected.
//                                  
// 
// Returns:
//  Structure:
//     * StringsMatchPercentage          - Number - The default value is "90".
//     * SmallStringsMatchPercentage - Number - The default value is "80".
//     * SmallStringsLength             - Number - The default value is "30".
//     * ExceptionWords - Array of String
//     * SearchAddIn - AddInObject
//
Function ParametersOfSearchForSimilarStrings(AttachAddInSSL = True) Export
	
	Result = New Structure;
	Result.Insert("StringsMatchPercentage", 90);
	Result.Insert("SmallStringsMatchPercentage", 80);
	Result.Insert("SmallStringsLength", 30);
	Result.Insert("ExceptionWords", New Array);
	
	FuzzySearch1 = Undefined; 
	If AttachAddInSSL Then
		SetSafeModeDisabled(True);
		FuzzySearch1 = Common.AttachAddInFromTemplate("FuzzyStringMatchExtension", 
			"CommonTemplate.StringSearchAddIn");
		If FuzzySearch1 = Undefined Then
			Raise NStr("en = 'Cannot attach the fuzzy search add-in. See the Event log for details.';");
		EndIf;
	EndIf;
	Result.Insert("SearchAddIn", FuzzySearch1);
	
	Return Result;
	
EndFunction

#EndRegion

#Region Internal

// Called
// in the duplicate search standalone workstation at the final assistant step. Use it upon searching for possible duplicates to filter locations where possible duplicates might be
//
// Returns:
//   Array of Type
//
Function TypesToExcludeFromPossibleDuplicates() Export

	TypesToExclude = New Array;
	SSLSubsystemsIntegration.OnAddTypesToExcludeFromPossibleDuplicates(TypesToExclude);		
	Return TypesToExclude;

EndFunction

Function CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters) Export
	
	Result = "";
	Errors = CheckCanReplaceItems(ReplacementPairs, ReplacementParameters);
	For Each KeyValue In Errors Do
		Result = Result + Chars.LF + KeyValue.Value;
	EndDo;
	Return TrimAll(Result);
	
EndFunction

Function CheckCanReplaceItems(ReplacementPairs, ReplacementParameters) Export
	
	If ReplacementPairs.Count() = 0 Then
		Return New Map;
	EndIf;
	
	For Each Item In ReplacementPairs Do
		TheFirstControl = Item.Key;
		Break;
	EndDo;
	
	Result = New Map;
	
	MetadataObjectName = TheFirstControl.Metadata().FullName();
	ObjectInfo = ObjectsWithDuplicatesSearch()[MetadataObjectName];
	If ObjectInfo <> Undefined And (ObjectInfo = "" 
		Or StrFind(ObjectInfo, "CanReplaceItems") > 0) Then
		ManagerModule = Common.ObjectManagerByRef(TheFirstControl);
		Result = ManagerModule.CanReplaceItems(ReplacementPairs, ReplacementParameters);
	EndIf;
	
	DuplicateObjectsDetectionOverridable.OnDefineItemsReplacementAvailability(MetadataObjectName, ReplacementPairs, 
		ReplacementParameters, Result);
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Subsystem event handlers.

// See ReportsOptionsOverridable.CustomizeReportsOptions.
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.SearchForReferences);
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export
	
	If AttachableCommandsKinds.Find("Administration", "Name") = Undefined Then
		
		Kind = AttachableCommandsKinds.Add();
		Kind.Name         = "Administration";
		Kind.SubmenuName  = "Service";
		Kind.Title   = NStr("en = 'Tools';");
		Kind.Order     = 80;
		Kind.Picture    = PictureLib.ServiceSubmenu;
		Kind.Representation = ButtonRepresentation.PictureAndText;	
		
	EndIf;
	
EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export
	
	AttachedObjects = ObjectsWithDuplicatesMergeCommands();
	For Each AttachedObject In AttachedObjects Do
		
		If AccessRight("Update", AttachedObject)
			And Sources.Rows.Find(AttachedObject, "Metadata") <> Undefined Then
			
			Command = Commands.Add();
			Command.Kind = "Administration";
			Command.Importance = "SeeAlso";
			Command.Presentation = NStr("en = 'Merge selected items…';");
			Command.WriteMode = "NotWrite";
			Command.VisibilityInForms = "ListForm";
			Command.MultipleChoice = True;
			Command.Handler = "DuplicateObjectsDetectionClient.MergeSelectedItems";
			Command.OnlyInAllActions = True;
			Command.Order = 40;
			
			Command = Commands.Add();
			Command.Kind = "Administration";
			Command.Importance = "SeeAlso";
			Command.Presentation = NStr("en = 'Replace selected items…';");
			Command.WriteMode = "NotWrite";
			Command.VisibilityInForms = "ListForm";
			Command.MultipleChoice = True;
			Command.Handler = "DuplicateObjectsDetectionClient.ReplaceSelected";
			Command.OnlyInAllActions = True;
			Command.Order = 40;
			
		EndIf;	
	
	EndDo;

EndProcedure

#EndRegion

#Region Private

// See DataProcessor.DuplicateObjectsDetection.
Function AvailableFilterAttributesNames(Val MetadataCollection)
	Result = "";
	StoreType = Type("ValueStorage");
	
	For Each Attribute In MetadataCollection Do
		IsStorage = Attribute.Type.ContainsType(StoreType);
		If Not IsStorage Then
			Result = Result + "," + Attribute.Name;
		EndIf
	EndDo;
	
	Return Result;
EndFunction

Procedure DefineUsageInstances(Val RefSet, Val ResultAddress) Export
	
	SearchTable = Common.UsageInstances(RefSet);
	
	Filter = New Structure("IsInternalData", False);
	ActualRows = SearchTable.FindRows(Filter);
	
	Result = SearchTable.Copy(ActualRows, "Ref");
	Result.Columns.Add("Occurrences", New TypeDescription("Number"));
	Result.FillValues(1, "Occurrences");
	
	Result.Indexes.Add("Ref");
	
	Result.GroupBy("Ref", "Occurrences");
	For Each Ref In RefSet Do
		If Result.Find(Ref, "Ref") = Undefined Then
			Result.Add().Ref = Ref;
		EndIf;
	EndDo;
	
	PutToTempStorage(Result, ResultAddress);
EndProcedure

// Replaces references in all infobase data. 
//
// Parameters:
//     Parameters - Structure:
//       * ReplacementPairs - Map of KeyAndValue:
//           * Key     - AnyRef - a reference to be replaced.
//           * Value - AnyRef - a reference to use as a replacement.
//           Self-references and empty search references are ignored.
//       * DeletionMethod - String - optional. What to do with the duplicate after a successful replacement.
//           ""                - default. Do nothing.
//           "Mark"         - mark for deletion.
//           "Directly" - delete directly.
//     ResultAddress - String - address of a temporary storage where the result of replacement is saved - ValueTable:
//       * Ref - AnyRef - a reference that was replaced.
//       * ErrorObject - Arbitrary - object - error cause.
//       * ErrorObjectPresentation - String - string representation of an error object.
//       * ErrorType - String - error type marker. Possible options:
//                              "LockError" - some objects were locked during reference processing
//                              "DataChanged" - data was changed by another user during processing
//                              "WritingError" - cannot write the object
//                              "UnknownData" - data not planned for analysis was found during processing.
//                                                    The replacement is not completed
//                              "CannotReplace"   - the CanReplaceItems handler returned a failure.
//       * ErrorText - String - detailed error description.
//
Procedure ReplaceReferences(Parameters, Val ResultAddress) Export
	
	RefsReplacementParameters = Common.RefsReplacementParameters();
	RefsReplacementParameters.DeletionMethod = Parameters.DeletionMethod;
	RefsReplacementParameters.IncludeBusinessLogic = True;
	RefsReplacementParameters.ReplacePairsInTransaction = False;
	
	Result = Common.ReplaceReferences(Parameters.ReplacementPairs, RefsReplacementParameters);
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

// Generates a table of managed metadata objects and their common settings.
//
// Returns:
//   ValueTable:
//       * FullName             - String   - Full name of the metadata table.
//       * ItemPresentation - String   - User-readable item presentation.
//       * ListPresentation   - String   - User-readable list presentation.
//       * Removed                - Boolean   - Metadata object has the "Delete" prefix.
//       * EventDuplicateSearchParameters      - Boolean - Handler CanReplaceItems is defined in the manager module.
//       * EventOnDuplicatesSearch            - Boolean - Handler DuplicatesSearchParameters is defined in the manager module.
//       * EventCanReplaceItems - Boolean - Handler OnDuplicatesSearch is defined in the manager module.
//
Function MetadataObjectsSettings() Export
	Settings = New ValueTable;
	Settings.Columns.Add("Kind",                   New TypeDescription("String"));
	Settings.Columns.Add("FullName",             New TypeDescription("String"));
	Settings.Columns.Add("ItemPresentation", New TypeDescription("String"));
	Settings.Columns.Add("ListPresentation",   New TypeDescription("String"));
	Settings.Columns.Add("Removed",                New TypeDescription("Boolean"));
	Settings.Columns.Add("EventDuplicateSearchParameters",      New TypeDescription("Boolean"));
	Settings.Columns.Add("EventOnDuplicatesSearch",            New TypeDescription("Boolean"));
	Settings.Columns.Add("EventCanReplaceItems", New TypeDescription("Boolean"));
	
	ListOfObjects = ObjectsWithDuplicatesSearch();
	RegisterMetadataCollection(Settings, ListOfObjects, Metadata.Catalogs, "Catalog");
	RegisterMetadataCollection(Settings, ListOfObjects, Metadata.Documents, "Document");
	RegisterMetadataCollection(Settings, ListOfObjects, Metadata.ChartsOfAccounts, "ChartOfAccounts");
	RegisterMetadataCollection(Settings, ListOfObjects, Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes");
	RegisterMetadataCollection(Settings, ListOfObjects, Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes");
	
	Result = Settings.Copy(New Structure("Removed", False));
	Result.Sort("ListPresentation");
	
	Return Result;
EndFunction

Function ObjectsWithDuplicatesSearch() Export
	
	ListOfObjects = New Map;
	SSLSubsystemsIntegration.OnDefineObjectsWithSearchForDuplicates(ListOfObjects);
	DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates(ListOfObjects);
	Return ListOfObjects;

EndFunction

Procedure RegisterMetadataCollection(Settings, ListOfObjects, MetadataCollection, Kind)
	
	For Each MetadataObject In MetadataCollection Do
		If Not AccessRight("View", MetadataObject)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
			Continue; // Access denied. Do not display in the list.
		EndIf;
		
		TableRow = Settings.Add();
		TableRow.Kind = Kind;
		TableRow.FullName = MetadataObject.FullName();
		TableRow.Removed = StrStartsWith(MetadataObject.Name, "Delete");
		TableRow.ItemPresentation = Common.ObjectPresentation(MetadataObject);
		TableRow.ListPresentation = Common.ListPresentation(MetadataObject);
		
		Events = ListOfObjects[TableRow.FullName];
		If TypeOf(Events) = Type("String") Then
			If IsBlankString(Events) Then
				TableRow.EventDuplicateSearchParameters      = True;
				TableRow.EventOnDuplicatesSearch            = True;
				TableRow.EventCanReplaceItems = True;
			Else
				TableRow.EventDuplicateSearchParameters      = StrFind(Events, "DuplicatesSearchParameters") > 0;
				TableRow.EventOnDuplicatesSearch            = StrFind(Events, "OnSearchForDuplicates") > 0;
				TableRow.EventCanReplaceItems = StrFind(Events, "CanReplaceItems") > 0;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

// Subsystem presentation. It is used for writing to the event log and in other places.
Function SubsystemDescription(ForUser) Export
	LanguageCode = ?(ForUser, Common.DefaultLanguageCode(), "");
	Return NStr("en = 'Duplicate cleaner';", LanguageCode);
EndFunction

// Parameters:
//  SearchRules - ValueTable:
//    * Attribute - String 
//    * Rule - String 
//  PrefilterComposer - DataCompositionSettingsComposer
//
// Returns:
//  Structure:
//    * SearchRules - ValueTable:
//        ** Attribute - String
//        ** Rule - String
//    * StringsComparisonForSimilarity - Structure:
//        ** StringsMatchPercentage - Number
//        ** SmallStringsMatchPercentage - Number
//        ** SmallStringsLength - Number
//        ** ExceptionWords - Array
//    * FilterComposer - DataCompositionSettingsComposer
//    * ComparisonRestrictions - Array
//    * ItemsCountToCompare - Number
//
Function DuplicatesSearchParameters(SearchRules, PrefilterComposer) Export
	
	StringsComparisonForSimilarity = New Structure;
	StringsComparisonForSimilarity.Insert("StringsMatchPercentage", 90);
	StringsComparisonForSimilarity.Insert("SmallStringsMatchPercentage", 80);
	StringsComparisonForSimilarity.Insert("SmallStringsLength", 30);
	StringsComparisonForSimilarity.Insert("ExceptionWords", New Array);
	
	Result = New Structure;
	Result.Insert("SearchRules",        SearchRules);
	Result.Insert("StringsComparisonForSimilarity", StringsComparisonForSimilarity);
	Result.Insert("FilterComposer",    PrefilterComposer);
	Result.Insert("ComparisonRestrictions", New Array);
	Result.Insert("ItemsCountToCompare", 1500);
	Result.Insert("HideInsignificantDuplicates", True);
	Return Result;
	
EndFunction

#Region ReplaceDuplicatesInDimensionKeys

// See Common.SubordinateObjectsLinksByTypes.
Function SubordinateObjectsLinksByTypes() Export

	Return Common.SubordinateObjectsLinksByTypes();

EndFunction 

Procedure AddSubordinateObjectsLinks(SubordinateObjectsLinks, LinkRow)
	
	KeyAttributes = StringFunctionsClientServer.SplitStringIntoSubstringsArray(LinkRow.LinksFields,",",,True);
	SubordinateObjectName = LinkRow.SubordinateObject.FullName();
	For Each AttributeName In KeyAttributes Do
		
		If CommonClientServer.HasAttributeOrObjectProperty(
				LinkRow.SubordinateObject.StandardAttributes, AttributeName) Then
		
			AttributeType = LinkRow.SubordinateObject.StandardAttributes[AttributeName];
			For Each AttributeType In AttributeType.Type.Types() Do
				
				Record = SubordinateObjectsLinks.Add();	
				Record.Key = SubordinateObjectName;
				Record.AttributeType = AttributeType;
				Record.AttributeName = AttributeName;
				
			EndDo;
			
		ElsIf CommonClientServer.HasAttributeOrObjectProperty(
				LinkRow.SubordinateObject.Attributes, AttributeName) Then
			
			AttributeType = LinkRow.SubordinateObject.Attributes[AttributeName];
			For Each AttributeType In AttributeType.Type.Types() Do
				
				Record = SubordinateObjectsLinks.Add();	
				Record.Key = SubordinateObjectName;
				Record.AttributeType = AttributeType;
				Record.AttributeName = AttributeName;
				
			EndDo;
			
		Else 
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Link field %1 does not exist in metadata object %2';"), 
				AttributeName, SubordinateObjectName);
			Raise ErrorDescription;
		EndIf;
			
	EndDo;

EndProcedure

Procedure FillObjectDetails(SubordinateObjectsDetails, LinkRow)
	
	SubordinateObjectName = LinkRow.SubordinateObject.FullName();
	KeyAttributes = StringFunctionsClientServer.SplitStringIntoSubstringsArray(LinkRow.LinksFields,",",,True);
	
	ObjectDetails = NewSubordinateObjectDetails();
	ObjectDetails.Key = SubordinateObjectName;
	ObjectDetails.KeyAttributes = KeyAttributes;
	ObjectDetails.SearchMethodModuleName = LinkRow.OnSearchForReferenceReplacement;
	ObjectDetails.RunAutoSearch = LinkRow.RunReferenceReplacementsAutoSearch;
	
	SubordinateObjectsDetails.Insert(SubordinateObjectName, ObjectDetails);

EndProcedure

Function NewSubordinateObjectDetails()

	ObjectDetails = New Structure;
	ObjectDetails.Insert("Key");
	ObjectDetails.Insert("KeyAttributes");
	ObjectDetails.Insert("SearchMethodModuleName");
	ObjectDetails.Insert("RunAutoSearch");
	Return ObjectDetails;

EndFunction

Procedure SelectUsedLinks(Duplicate1, SubordinateObjectsLinks) 

	If SubordinateObjectsLinks.Find(TypeOf(Duplicate1), "AttributeType") = Undefined Then
		Return;	
	EndIf;
	
	RefMetadata = Duplicate1.Metadata();
	If SubordinateObjectsLinks.Find(RefMetadata, "Metadata") <> Undefined Then
		Return;
	EndIf;
	
	UsedLinks = SubordinateObjectsLinks.FindRows(New Structure("AttributeType",TypeOf(Duplicate1)));
	For Each Link In UsedLinks Do
		
		Link.Metadata = RefMetadata;
		Link.Used = True;
		
	EndDo;
	
EndProcedure

// Parameters:
//   ReplacementTable - ValueTable:
//   * Ref - AnyRef
//   * Replacement - AnyRef
//   ReplacementPairs - Map
//   NotPickedReplacements - Array of AnyRef
//
Procedure AddFoundKeysToDuplicates(ReplacementTable, ReplacementPairs, NotPickedReplacements)

	For Each FoundDuplicate In ReplacementTable Do
	
		If FoundDuplicate.Replacement = NULL Then
			NotPickedReplacements.Add(FoundDuplicate);	
		Else
			ReplacementPairs.Insert(FoundDuplicate.Ref, FoundDuplicate.Replacement);
		EndIf;	
		
	EndDo;
	
EndProcedure

// Parameters:
//   FoundDuplicate - ValueTableRow:
//   * Ref - AnyRef
//   * Replacement - AnyRef
//   SubordinateObjectDetails - Arbitrary
//   UsedLinks - ValueTable:
//   * Key - Type
//   * AttributeType - String
//   * AttributeName - String
//   * Used - Boolean
//   * Metadata - MetadataObject
// Returns:
//   Structure:
//   * UsedLinks - ValueTable:
//     ** Key - Type
//     ** AttributeType - String
//     ** AttributeName - String
//     ** Used - Boolean
//     ** Metadata - MetadataObject
//   * ValueToReplace - AnyRef 
//
Function NewReplacementParameters(FoundDuplicate, SubordinateObjectDetails, UsedLinks)

	ReplacementParameters = New Structure;
	ReplacementParameters.Insert("ValueToReplace", FoundDuplicate.Ref);
	ReplacementParameters.Insert("UsedLinks",
		UsedLinks.Copy(New Structure("Key",SubordinateObjectDetails.Key)));
	ReplacementParameters.Insert("KeyAttributesValue", New Structure);
	
	KeyAttributes = SubordinateObjectDetails.KeyAttributes;	
	For Each KeyAttribute In KeyAttributes Do
		ReplacementParameters.KeyAttributesValue.Insert(KeyAttribute, FoundDuplicate[KeyAttribute]);
	EndDo;

	Return ReplacementParameters;

EndFunction

Function ObjectsForReplacementQueryText(SubordinateObjectDetails, Links)

	QueryText = QueryTemplate();

	KeyName = StrReplace(SubordinateObjectDetails.Key, ".", "");
	KeyTable = SubordinateObjectDetails.Key;

	NotAttributesToChange = "";
	AttributesToChange = "";
	KeysValue = "";
	ValueAttributesToChange = "";
	ConnectionValueOfAttributesToReplace = "";
	LinksByKey = "";
	
	AttributesToChangeArray = New Array;
	If SubordinateObjectDetails.RunAutoSearch Then
	
		For Each Link In Links Do
			AttributesToChangeArray.Add(Link.AttributeName);
		EndDo;	
	
	EndIf;
	
	For Each KeyAttribute In SubordinateObjectDetails.KeyAttributes Do
		
		Value = "UNION" // @query-part
			+ StrReplace(" SELECT
							|	Tab.Ref AS Ref,
							|	&NotAttributesToChange,
							|	&AttributesToChange
							|FROM
							|	#KeyTable AS Tab
							|WHERE
							|	&KeyAttribute IN 
							|	(SELECT
							|		Tab.Original
							|	FROM
							|		ReplacementTable AS Tab)", "&KeyAttribute","Tab." + KeyAttribute);
		KeysValue = KeysValue + Value;
		
		Value = StringFunctionsClientServer.SubstituteParametersToString("Tab.%1 = Replacement.%1 ", KeyAttribute);
		LinksByKey = LinksByKey + ?(IsBlankString(LinksByKey), Value, "And " + Value);
							
		If AttributesToChangeArray.Find(KeyAttribute) <> Undefined Then
			
			Value = StringFunctionsClientServer.SubstituteParametersToString("Tab.%1 AS %1", KeyAttribute);
			AttributesToChange = AttributesToChange + ?(IsBlankString(AttributesToChange),Value, ","+Value);
			
			Value = StringFunctionsClientServer.SubstituteParametersToString("CASE WHEN Replacement%1.Original IS NULL THEN Tab.%1 ELSE Replacement%1.Duplicate1 END AS %1", KeyAttribute);
			ValueAttributesToChange = ValueAttributesToChange + ?(IsBlankString(ValueAttributesToChange),Value, ","+Value);
		
			Value = StringFunctionsClientServer.SubstituteParametersToString(" LEFT JOIN ReplacementTable AS Replacement%1
								|ON Tab.%1 = Replacement%1.Original", KeyAttribute);
			ConnectionValueOfAttributesToReplace = ConnectionValueOfAttributesToReplace + Value;
			
		Else
			
			Value =  StringFunctionsClientServer.SubstituteParametersToString("Tab.%1 AS %1", KeyAttribute);
			NotAttributesToChange = NotAttributesToChange + ?(IsBlankString(NotAttributesToChange),Value, ","+Value);

		EndIf;
		
	EndDo;

	AddToQueryText(QueryText, "#KeysValue", KeysValue);
	AddToQueryText(QueryText, "LEFT JOIN #ConnectionValueOfAttributesToReplace ON TRUE", ConnectionValueOfAttributesToReplace);
	AddToQueryText(QueryText, "&LinksByKey", LinksByKey);
	AddToQueryText(QueryText, "&NotAttributesToChange", ?(IsBlankString(NotAttributesToChange), "UNDEFINED", NotAttributesToChange));
	AddToQueryText(QueryText, "&AttributesToChange",  ?(IsBlankString(AttributesToChange), "UNDEFINED", AttributesToChange));
	
	AddToQueryText(QueryText, "#KeyTable", KeyTable);
	AddToQueryText(QueryText, "#KeyName", KeyName);
	
	Return QueryText;

EndFunction

Function QueryTemplate()
	
	Return "
	|SELECT
	|	Tab.Ref AS Ref,
	|	&NotAttributesToChange,
	|	&AttributesToChange
	|INTO #KeyNameSourceData
	|FROM
	|	#KeyTable AS Tab
	|WHERE
	|	FALSE" + "
	|
	|#KeysValue
	|;
	|" + "
	|SELECT
	|	Tab.Ref AS Ref,
	|	&NotAttributesToChange,
	|	&AttributesToChange
	|INTO #KeyNameTheValueOfTheDetailsAfterReplacement
	|FROM
	|	#KeyNameSourceData AS Tab
	|   LEFT JOIN #ConnectionValueOfAttributesToReplace ON TRUE
	|;
	|SELECT
	|	Tab.Ref AS Ref,
	|	Replacement.Ref AS Replacement,
	|	&NotAttributesToChange,
	|	&AttributesToChange
	|FROM
	|	#KeyNameTheValueOfTheDetailsAfterReplacement AS Tab
	|	LEFT JOIN #KeyTable AS Replacement
	|	ON Tab.Ref <> Replacement.Ref
	|	AND &LinksByKey 
	|
	|";

EndFunction

Procedure AddToQueryText(QueryText, ParameterName, Text)

	QueryText = StrReplace(QueryText, ParameterName, Text);

EndProcedure

Procedure AddToReplacementTables(OriginalDuplicate, ReplacementTables, SubordinateObjectsLinks) 

	KeyAttributeMetadata = OriginalDuplicate.Key.Metadata();
	KeyAttributeTableName = KeyAttributeMetadata.FullName();
	SearchKey = StrReplace(KeyAttributeTableName,".",""); 
	If SubordinateObjectsLinks.Find(KeyAttributeMetadata, "Metadata") = Undefined Then
		Return;
	EndIf;
	
	ReplacementTable = ReplacementTables[SearchKey];
	If ReplacementTable = Undefined Then
		Types = New Array;
		Types.Add(TypeOf(OriginalDuplicate.Key));
		OriginalRefType = New TypeDescription(Types);

		ReplacementTable = New ValueTable;
		ReplacementTable.Columns.Add("Original", OriginalRefType);
		ReplacementTable.Columns.Add("Duplicate1", OriginalRefType);
		
		ReplacementTables.Insert(SearchKey, ReplacementTable);
	EndIf;
	
	ReplacementString = ReplacementTable.Add();
	ReplacementString.Original = OriginalDuplicate.Key;
	ReplacementString.Duplicate1 = OriginalDuplicate.Value;

EndProcedure

Procedure PutReplacementsTablesInQuery(TempTablesManager, ReplacementTables)

	QueryParts = New Array;
	Separator = Chars.LF + "UNION ALL" + Chars.LF;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	QueryText = "
	|SELECT
	|	UNDEFINED AS Original,
	|	UNDEFINED AS Duplicate1
	|INTO ReplacementTable 
	|WHERE 
	|	FALSE";
	
	InsertQueryTemplate = "
	|SELECT
	|	Tab.Original AS Original,
	|	Tab.Duplicate1 AS Duplicate1
	|INTO TT_TableName
	|FROM
	|	&TableName AS Tab";
	
	MergeQueryTemplate = "
	|SELECT
	|	Tab.Original AS Original,
	|	Tab.Duplicate1 AS Duplicate1
	|FROM
	|	TT_TableName AS Tab";

	For Each ValuesTable In ReplacementTables Do
	
		QueryParts.Add(StrReplace(InsertQueryTemplate, "TableName", ValuesTable.Key));			
		Query.SetParameter(ValuesTable.Key, ValuesTable.Value); 
		QueryText = QueryText + Separator + StrReplace(MergeQueryTemplate, "TableName", ValuesTable.Key);
		
	EndDo;
	
	QueryText = QueryText + Chars.LF + "INDEX BY Original";
	
	QueryParts.Add(QueryText);
	Query.Text = StrConcat(QueryParts, Common.QueryBatchSeparator());
	Query.Execute();

EndProcedure

Procedure ExecuteSearchByAppliedRules(Val UsedLinks, Val NotPickedReplacements, Val SubordinateObjectDetails, Val ReplacementPairs)
	
	Var SearchMethodParameters, Cnt;
	
	For Cnt = 0 To NotPickedReplacements.Count() - 1 Do
		
		NotPickedReplacements[Cnt] = NewReplacementParameters(
			NotPickedReplacements[Cnt],
			SubordinateObjectDetails,
			UsedLinks);	
		
	EndDo;
	
	SearchMethodParameters = New Array;
	SearchMethodParameters.Add(ReplacementPairs);
	SearchMethodParameters.Add(NotPickedReplacements);
	Common.ExecuteConfigurationMethod(
		SubordinateObjectDetails.SearchMethodModuleName+".OnSearchForReferenceReplacement",
		SearchMethodParameters);

EndProcedure

Function ObjectsWithDuplicatesMergeCommands()

	ObjectsWithCommands = New Array;
	DuplicateObjectsDetectionOverridable.OnDefineObjectsWithReferenceReplacementDuplicatesMergeCommands(ObjectsWithCommands);
	Return ObjectsWithCommands;

EndFunction

#EndRegion

#EndRegion