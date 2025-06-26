///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Function LayoutDiagramOfDataFromTheValueTable(ValueTable) Export
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetObject"));
	DataSet.DataSource = "DataSource1";
	DataSet.Name = "DataSet1";
	DataSet.ObjectName = "Data";
	
	For Each TableRow In ValueTable Do
		Field = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		Field.Field = TableRow.Id;
		Field.DataPath = TableRow.Id;
		If ValueIsFilled(TableRow.Presentation) Then
			Field.Title = TableRow.Presentation;
		EndIf;
		Field.ValueType = TableRow.ValueType;
		
		If ValueIsFilled(TableRow.Format) Then
			ParameterValue = Field.Appearance.FindParameterValue(New DataCompositionParameter("Format"));
			If ParameterValue <> Undefined Then
				ParameterValue.Use = True;
				ParameterValue.Value = TableRow.Format;
			EndIf;
		EndIf;
		
		AdditionalParameters = New Structure("Order,IsFunction,Hidden,ExpressionToInsert");
		FillPropertyValues(AdditionalParameters, TableRow);
		
		AdditionalParameters.Insert("Picture",  Base64String(TableRow.Picture.GetBinaryData()));
		
		Field.EditParameters.SetParameterValue("Mask", 
			Common.ValueToJSON(AdditionalParameters));
	EndDo;
	
	Return DataCompositionSchema;
	
EndFunction

Function DataLayoutSchemeFromTheValueTree(ValueTree) Export
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetObject"));
	DataSet.DataSource = "DataSource1";
	DataSet.Name = "DataSet1";
	DataSet.ObjectName = "Data";
	
	AddAGroupOfItemsToADataset(ValueTree, DataSet);
	
	Return DataCompositionSchema;
	
EndFunction

Function FieldDetails(DataPath, ListsOfFields) Export
	
	DataCompositionSchema = Undefined;
	DataCompositionSchemaId = Undefined;
	DataPathInNestedSchema = Undefined;
	FieldOwner = Undefined;
	Type = Undefined;
	Folder = Undefined;
	Table = Undefined;
	
	For Each ListSettings In ListsOfFields Do
		SourcesOfAvailableFields = ListSettings.SourcesOfAvailableFields;
		FieldsCollection = ListSettings.FieldsCollection;
		If FieldsCollection = Undefined Then
			ListSettings.FieldsCollection = NewCollectionOfFields();
			FieldsCollection = ListSettings.FieldsCollection;
			FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(FieldsCollection);
			FillingParametersForAvailableAttributesList.ListSettings = ListSettings;
			FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, SourcesOfAvailableFields);
		EndIf;

		Attribute = FindField(DataPath, ChildItems(FieldsCollection), False, SourcesOfAvailableFields, ListSettings);
		If Attribute <> Undefined Then
			Parent = Parent(Attribute);
			While Parent <> Undefined Do
				If Parent.YourOwnSetOfFields Then
					Break;
				Else
					Parent = Parent(Parent);
					Continue;
				EndIf;
			EndDo;
			
			If Parent <> Undefined Then
				For Each SourceOfAvailableFields In SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings, Parent) Do
					Field = SourceOfAvailableFields.FieldsCollection.FindField(Attribute.Field);
					If Field <> Undefined Then
						FieldOwner = Parent.DataPath;
						DataCompositionSchema = SourceOfAvailableFields.DataCompositionSchema;
						DataCompositionSchemaId = SourceOfAvailableFields.DataCompositionSchemaId;
						DataPathInNestedSchema = String(Attribute.Field);
						Type = Field.ValueType;
						Folder = Attribute.Folder;
						Table = Attribute.Table;
					EndIf;
				EndDo;
			EndIf;
			
			If FieldOwner = Undefined Then
				For Each SourceOfAvailableFields In SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings) Do
					Field = SourceOfAvailableFields.FieldsCollection.FindField(Attribute.Field);
					If Field <> Undefined Then
						FieldOwner = "Ref";
						DataCompositionSchema = SourceOfAvailableFields.DataCompositionSchema;
						DataCompositionSchemaId = SourceOfAvailableFields.DataCompositionSchemaId;
						DataPathInNestedSchema = String(Attribute.Field);
						Type = Field.ValueType;
						Folder = Attribute.Folder;
						Table = Attribute.Table;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("Field", DataPath);
	Result.Insert("DataCompositionSchema", DataCompositionSchema);
	Result.Insert("DataCompositionSchemaId", DataCompositionSchemaId);
	Result.Insert("DataPath", DataPathInNestedSchema);
	Result.Insert("Owner", FieldOwner);
	Result.Insert("Format", FormatFields(DataPath, DataCompositionSchema));
	Result.Insert("Type", Type);
	Result.Insert("Folder", Folder);
	Result.Insert("Table", Table);
	
	Return Result;
	
EndFunction

// Returns:
//  ValueTable:
//   * FieldsCollection - ValueTree
//   * SourcesOfAvailableFields - ValueTable
//   * IdentifierBrackets - Boolean
//   * ViewBrackets - Boolean
//   * UseIdentifiersForFormulas - Boolean
//   * WhenDefiningAvailableFieldSources - String
//
Function DescriptionOfFieldLists() Export
	
	Result = New ValueTable();
	Result.Columns.Add("FieldsCollection");
	Result.Columns.Add("SourcesOfAvailableFields");
	Result.Columns.Add("IdentifierBrackets", New TypeDescription("Boolean"));
	Result.Columns.Add("ViewBrackets", New TypeDescription("Boolean"));
	Result.Columns.Add("UseIdentifiersForFormulas", New TypeDescription("Boolean"));
	Result.Columns.Add("WhenDefiningAvailableFieldSources", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

// Returns:
//  ValueTable
// 
Function CollectionOfSourcesOfAvailableFields() Export
	
	Result = New ValueTable;
	
	For Each AttributeDetails In SourceListAvailableFieldsAttributes() Do
		AttributeName = AttributeDetails.Key;
		AttributeType = AttributeDetails.Value;
		Result.Columns.Add(AttributeName, AttributeType);
	EndDo;
	
	Return Result;
	
EndFunction

Function ColumnNamePresentation(NameOfTheFieldList) Export
	
	Return NameOfTheFieldList + "Presentation";
	
EndFunction

Function FormulaElements(Val Formula) Export

	AllItems = New Array;
	OperandsAndFunctions = New Map;
	
	Separators = "()/*-+%=<>, " + Chars.Tab + Chars.LF;
	OpeningParentheses = 0;
	ThisIsStringInDoubleQuotes = False;
	ThisIsStringInSingleQuotes = False;
	
	Operand = "";
	
	For IndexOf = 1 To StrLen(Formula) Do

		Char = Mid(Formula, IndexOf, 1);
		IsSeparator = StrFind(Separators, Char) > 0;
		
		If OpeningParentheses = 0 And Char = """" And Not ThisIsStringInSingleQuotes Then
			ThisIsStringInDoubleQuotes = Not ThisIsStringInDoubleQuotes;
			AllItems.Add(Char);
			Continue;
		EndIf;

		If OpeningParentheses = 0 And Char = "'" And Not ThisIsStringInDoubleQuotes Then
			ThisIsStringInSingleQuotes = Not ThisIsStringInSingleQuotes;
			AllItems.Add(Char);
			Continue;
		EndIf;
		
		If ThisIsStringInDoubleQuotes Or ThisIsStringInSingleQuotes Then
			AllItems[AllItems.UBound()] = AllItems[AllItems.UBound()] + Char;
			Continue;
		EndIf;

		If Char = "[" Then
			OpeningParentheses = OpeningParentheses + 1;
		EndIf;
		
		If Char = "]" And OpeningParentheses > 0 Then
			OpeningParentheses = OpeningParentheses - 1;
		EndIf;
		
		If IsSeparator And OpeningParentheses = 0 Then
			If ValueIsFilled(Operand) Then
				IsFunction = False;
				If Char = "(" And StrFind(Operand, ".") = 0 Then
					IsFunction = True;
				EndIf;
				
				If IsFunction Or Not CommonClientServer.IsNumber(Operand) Then
					OperandsAndFunctions.Insert(AllItems.UBound() + 1, IsFunction);
				EndIf;
				
				AllItems.Add(Operand);
				Operand = "";
			EndIf;
			AllItems.Add(Char);
		Else
			Operand = Operand + Char;
		EndIf;
	EndDo;
	
	If ValueIsFilled(Operand) And Not CommonClientServer.IsNumber(Operand) Then
		OperandsAndFunctions.Insert(AllItems.UBound() + 1, False);
	EndIf;
	
	AllItems.Add(Operand);
	
	Result = New Structure;
	Result.Insert("AllItems", AllItems);
	Result.Insert("OperandsAndFunctions", OperandsAndFunctions);
	
	Return Result;
	
EndFunction

Function FieldsCollection(Val FieldSource, Form = Undefined, Val NameOfTheSKDCollection = Undefined) Export

	SettingsComposer = FieldSourceSettingsLinker(FieldSource, Form);
	If SettingsComposer = Undefined Then
		Return Undefined;
	EndIf;
	
	Return CollectionOfSettingsLinkerFields(SettingsComposer, NameOfTheSKDCollection);
	
EndFunction


Function CheckFormula(Form, FormulaPresentation) Export
	
	FormulaElements = FormulaElements(FormulaPresentation);
	
	RecognizedElements = New Map;
	
	For Each Item In Form.ConnectedFieldLists Do
		NameOfTheFieldList = Item.NameOfTheFieldList;
		FieldsCollection = Form[NameOfTheFieldList];
		IdentifierBrackets = Item.IdentifierBrackets;
		
		For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
			OperandRepresentation = FormulaElements.AllItems[ItemDetails.Key];
			IsFunction = ItemDetails.Value;
			DataPath = ClearSquareBrackets(OperandRepresentation);
			Attribute = FindTheProps(Form, NameOfTheFieldList, DataPath, FieldsCollection.GetItems(), True);
			If Attribute <> Undefined  Then
				If IsFunction <> Attribute.IsFunction Then
					Continue;
				EndIf;
				Operand = Attribute.DataPath;
				If IdentifierBrackets Then
					Operand = WrapInSquareBrackets(Operand);
				EndIf;
				RecognizedElements.Insert(ItemDetails.Key, Operand);
			EndIf;
		EndDo;
	EndDo;
	
	Errors = New Array;
	
	For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
		Operand = FormulaElements.AllItems[ItemDetails.Key];
		IsFunction = ItemDetails.Value;
		
		If RecognizedElements[ItemDetails.Key] = Undefined Then
			If IsFunction Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Unknown function in the expression - ""%1""';"),
					Operand);
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Field %1 is not found in the list of available fields';"),
					Operand);
			EndIf;
			Errors.Add(ErrorText);
		EndIf;
	EndDo;
	
	Result = StrConcat(Errors, Chars.LF);
	Return Result;
	
EndFunction

Procedure FormulaEditorHandler(Form, Parameter, AdditionalParameters) Export
	OperationKey = AdditionalParameters.OperationKey;
	If OperationKey = "ClearUpSearchString" Then
		ClearUpSearchString(Form, Parameter);
	ElsIf OperationKey = "RunBackgroundSearchInFieldList" Then
		Parameter = RunBackgroundSearchInFieldList(Form);
	EndIf;
EndProcedure

// Run a search in the field list.
// 
// Parameters:
//  ShapeStructure - Structure:
//    * 
// 
// Returns:
//  Undefined, Structure - Run a search in the field list.:
//   * ItemsTree 
//   * FoundItems1 - Array
//
Function RunSearchInListOfFields(ShapeStructure) Export
	
	CurrentSession = GetCurrentInfoBaseSession().GetBackgroundJob();
	IsBackgroundJob = (CurrentSession <> Undefined);
	
	NameOfTheFieldList = ShapeStructure.ListName;
	TheNameOfTheSearchStringProps = TheNameOfTheFieldListSearchStringDetails(NameOfTheFieldList);
	Filter = ShapeStructure[TheNameOfTheSearchStringProps];
	FilterIs_Specified = ValueIsFilled(Filter);
	
	If FilterIs_Specified Then
		CacheTable = New ValueTable;
		CacheTable.Columns.Add("NameOfTheFieldList", New TypeDescription("String"));
		CacheTable.Columns.Add("FieldType", New TypeDescription("TypeDescription"));
		CacheTable.Columns.Add("AvailableFields", New TypeDescription("ValueTable"));
		ShapeStructure.Insert("CacheForDCS_", CacheTable);
		SearchResult = SetFilter(ShapeStructure, NameOfTheFieldList, Filter, ShapeStructure[NameOfTheFieldList]);
	EndIf;
	
	If SearchResult.FoundItems1.Count() > 0 Then
		Return SearchResult;
	Else
		Return Undefined;
	EndIf;
		
EndFunction

#EndRegion


#Region Private

Procedure SetTreeRowsIDs(Collection)
	For Each TableRow In Collection.Rows Do
		If Not ValueIsFilled(TableRow.Id) Then
			TableRow.Id = New UUID();
		EndIf;
		SetTreeRowsIDs(TableRow);
	EndDo;
EndProcedure

// Parameters:
//  Form - ClientApplicationForm
//
Function RunBackgroundSearchInFieldList(Form)
	
	CancellationResult = CancelBackgroundSearchJob(Form);
	SearchListParameters = SearchListParameters(Form);
	
	ExecutionParameters = TimeConsumingOperations.FunctionExecutionParameters(Form.UUID);
	TimeConsumingOperation = TimeConsumingOperations.ExecuteFunction(ExecutionParameters, 
		"FormulasConstructorInternal.RunSearchInListOfFields", SearchListParameters);

	CancellationResult.BackgroundSearchJobs.Insert(CancellationResult.NameOfTheSearchString, 
		TimeConsumingOperation.JobID);
	If IsTempStorageURL(Form.AddressOfLongRunningOperationDetails) Then
		PutToTempStorage(CancellationResult.BackgroundSearchJobs, Form.AddressOfLongRunningOperationDetails);
	Else
		Form.AddressOfLongRunningOperationDetails = PutToTempStorage(CancellationResult.BackgroundSearchJobs, 
			Form.UUID);
	EndIf;
		
	Return	TimeConsumingOperation;
	
EndFunction

Function CancelBackgroundSearchJob(Form)
	
	If IsTempStorageURL(Form.AddressOfLongRunningOperationDetails) Then
		BackgroundSearchJobs = GetFromTempStorage(Form.AddressOfLongRunningOperationDetails);
	Else
		BackgroundSearchJobs = New Map();
	EndIf;
	
	NameOfTheSearchString = Form.NameOfCurrSearchString;
	
	If BackgroundSearchJobs[NameOfTheSearchString] <> Undefined Then
		JobID = BackgroundSearchJobs[NameOfTheSearchString];
		TimeConsumingOperations.CancelJobExecution(JobID);
		WaitForJobCompletion = Common.FileInfobase();
		While WaitForJobCompletion Do
			ExecutionResult = TimeConsumingOperations.JobCompleted(JobID, True);
			If ExecutionResult.Status <> "Running" Then
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Return New Structure("BackgroundSearchJobs, NameOfTheSearchString", BackgroundSearchJobs, NameOfTheSearchString);
EndFunction

Function SearchListParameters(Form)
	NameOfSearchStringCurrentAttribute = Form.NameOfCurrSearchString;
	FIlterRow = Form[NameOfSearchStringCurrentAttribute];
	ListName = NameOfFieldsListAttribute(NameOfSearchStringCurrentAttribute);
	
	ConnectedFieldLists = Form.ConnectedFieldLists.Unload();
	Filter = New Structure("NameOfTheFieldList", NameOfFieldsListAttribute(NameOfSearchStringCurrentAttribute));
	AttachedFieldListsSearchStrings = ConnectedFieldLists.Copy(Filter);
	
	FilterIs_Specified = ValueIsFilled(FIlterRow);
		
	If Not FilterIs_Specified Then
		PerformASearchInTheListOfFields(Form);
		Return Undefined;
	EndIf;
	
	SearchListParameters = New Structure;
	SearchListParameters.Insert("ListName", ListName);
	SearchListParameters.Insert("ConnectedFieldLists", AttachedFieldListsSearchStrings);
		
	For Each AttachedListOfFields In AttachedFieldListsSearchStrings Do
		NameOfTheFieldList = AttachedListOfFields.NameOfTheFieldList;
		TheNameOfTheSearchStringProps = TheNameOfTheFieldListSearchStringDetails(NameOfTheFieldList);
					
		SearchListParameters.Insert(TheNameOfTheSearchStringProps, Form[TheNameOfTheSearchStringProps]);
		FieldTree = TreeOfAvailableAttributes(Form, AttachedListOfFields.NameOfTheFieldList);
		
		ValueToFormData(FieldTree, Form[AttachedListOfFields.NameOfTheFieldList]);
		SetTreeRowsIDs(FieldTree);
		SearchListParameters.Insert(AttachedListOfFields.NameOfTheFieldList, FieldTree);
		
		TableOfSources = Form.FormAttributeToValue(AttachedListOfFields.NameOfTheSourceList);
		For Each TableRow In TableOfSources Do
			If TableRow.DataCompositionSchema <> Undefined Then
				If IsTempStorageURL(TableRow.DataCompositionSchema) Then
					DataCompositionSchema = GetFromTempStorage(TableRow.DataCompositionSchema);
				Else
					DataCompositionSchema = TableRow.DataCompositionSchema;
				EndIf;
				TableRow.DataCompositionSchema = Common.ValueToXMLString(DataCompositionSchema);
			EndIf;
			Container = AvailableFieldsIntoDCSContainer(TableRow.FieldsCollection);
			TableRow.FieldsCollection = Common.ValueToXMLString(Container);
		EndDo;
		SourcesTableRow = Common.ValueToXMLString(TableOfSources);
		SearchListParameters.Insert(AttachedListOfFields.NameOfTheSourceList, SourcesTableRow);
	EndDo;
	Return SearchListParameters;
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  ListName - String
//  
// Returns: 
//  ValueTree:
//   * Name - String
//   * Title - String
//   * Field - DataCompositionField
//   * DataPath - String
//   * RepresentationOfTheDataPath - String
//   * Type - TypeDescription
//   * Picture - Picture
//   * Folder - Boolean
//   * Table - Boolean
//   * YourOwnSetOfFields - Boolean
//   * Indent - String
//   * MatchesFilter - Boolean
//   * TheSubordinateElementCorrespondsToTheSelection - Boolean
//   * IsFolder - Boolean
//   * IsFunction - Boolean
//   * Weight - Number
//   * Id - UUID
//						
Function TreeOfAvailableAttributes(Val Form, Val ListName)
	TreeOfCurrList = Form.FormAttributeToValue(ListName);// ValueTree
	If TreeOfCurrList.Columns.Find("Id") = Undefined Then
		TreeOfCurrList.Columns.Add("Id", New TypeDescription("UUID"));
	EndIf;
	Return TreeOfCurrList;
EndFunction

Function AvailableFieldsFromDCSContainer(Container)
	Return FieldsCollection(Container);
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//  Parameters - See ParametersForAddingAListOfFields
//
Procedure AddAListOfFieldsToTheForm(Form, Parameters) Export
	
	AddingOptions = ParametersForAddingAListOfFields();
	FillPropertyValues(AddingOptions, Parameters);
	
	AttributesToBeAdded = New Array;
	
	AttributesValues = New Structure("ConnectedFieldLists, AddressOfLongRunningOperationDetails");
	FillPropertyValues(AttributesValues, Form);
	ConnectedFieldLists = AttributesValues.ConnectedFieldLists;
	If ConnectedFieldLists = Undefined Then
		TheNameOfThePropsConnectedFieldLists = "ConnectedFieldLists";
		AttributesToBeAdded.Add(New FormAttribute(TheNameOfThePropsConnectedFieldLists, New TypeDescription("ValueTable")));
		AttributesToBeAdded.Add(New FormAttribute("NameOfTheFieldList", New TypeDescription("String"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("NameOfTheSourceList", New TypeDescription("String"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("IdentifierBrackets", New TypeDescription("Boolean"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("ViewBrackets", New TypeDescription("Boolean"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("UseIdentifiersForFormulas", New TypeDescription("Boolean"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("WhenDefiningAvailableFieldSources", New TypeDescription("String"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("ExpandableBranches", New TypeDescription("String"), TheNameOfThePropsConnectedFieldLists));
		
		AttributesToBeAdded.Add(New FormAttribute("NameOfCurrSearchString", New TypeDescription("String")));
		
	EndIf;
	
	NameOfTheFieldList = AddingOptions.ListName;
	
	AddressOfLongRunningOperationDetails = AttributesValues.AddressOfLongRunningOperationDetails;
	If AddressOfLongRunningOperationDetails = Undefined Then
		TheNameOfThePropsConnectedFieldLists = "ConnectedFieldLists";
		AttributesToBeAdded.Add(New FormAttribute("UseBackgroundSearch", New TypeDescription("Boolean"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("NumberOfCharsToAllowSearching", New TypeDescription("Number"), TheNameOfThePropsConnectedFieldLists));
		AttributesToBeAdded.Add(New FormAttribute("AddressOfLongRunningOperationDetails", New TypeDescription("String")));
		AttributesToBeAdded.Add(New FormAttribute("CacheForDCS_", New TypeDescription("ValueTable")));
		AttributesToBeAdded.Add(New FormAttribute("NameOfTheFieldList", New TypeDescription("String"), "CacheForDCS_"));
		AttributesToBeAdded.Add(New FormAttribute("FieldType", New TypeDescription("TypeDescription"), "CacheForDCS_"));
		AttributesToBeAdded.Add(New FormAttribute("AvailableFields", New TypeDescription("ValueTable"), "CacheForDCS_"));
		For Each AttributeDetails In DetailsOfTheConnectedList() Do
			AttributeName = AttributeDetails.Key;
			AttributeType = AttributeDetails.Value;
			AttributesToBeAdded.Add(New FormAttribute(AttributeName, AttributeType, "CacheForDCS_.AvailableFields"));
		EndDo;
		AttributesToBeAdded.Add(New FormAttribute("HasSubordinateItems", New TypeDescription("Boolean"), "CacheForDCS_.AvailableFields"));
	EndIf;
	
	If FindFormAttribute(Form, NameOfTheFieldList) = Undefined Then
		AttributesToBeAdded.Add(New FormAttribute(NameOfTheFieldList, New TypeDescription("ValueTree")));
	EndIf;
	
	For Each AttributeDetails In DetailsOfTheConnectedList() Do
		AttributeName = AttributeDetails.Key;
		If FindFormAttribute(Form, AttributeName) = Undefined Then
			AttributeType = AttributeDetails.Value;
			AttributesToBeAdded.Add(New FormAttribute(AttributeName, AttributeType, NameOfTheFieldList));
		EndIf;
	EndDo;
	
	NameOfTheSearchString = TheNameOfTheFieldListSearchStringDetails(NameOfTheFieldList);
	AttributesToBeAdded.Add(New FormAttribute(NameOfTheSearchString, New TypeDescription("String")));
	
	NameOfTheSourceList = NameOfTheFieldList + "Sources";
	AttributesToBeAdded.Add(New FormAttribute(NameOfTheSourceList, New TypeDescription("ValueTable")));
	For Each AttributeDetails In SourceListAvailableFieldsAttributes() Do
		AttributeName = AttributeDetails.Key;
		AttributeType = AttributeDetails.Value;
		AttributesToBeAdded.Add(New FormAttribute(AttributeName, AttributeType, NameOfTheSourceList));
	EndDo;
	
	Form.ChangeAttributes(AttributesToBeAdded);
	
	LocationOfTheSearchString = AddingOptions.LocationOfTheSearchString;
	If Not ValueIsFilled(LocationOfTheSearchString) Then
		LocationOfTheSearchString = AddingOptions.LocationOfTheList;
	EndIf;
	
	FieldList = Form.Items.Find(NameOfTheFieldList);
	
	SearchGroup1 = Form.Items.Add("Group" + NameOfTheSearchString, Type("FormGroup"), LocationOfTheSearchString);
	SearchGroup1.Type = FormGroupType.UsualGroup;
	SearchGroup1.Representation = UsualGroupRepresentation.None;
	SearchGroup1.ShowTitle = False; 
	SearchGroup1.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	SearchString = Form.Items.Add(NameOfTheSearchString, Type("FormField"), SearchGroup1);
	
	NameOfCleanupCommand = NameOfTheSearchString + "Clearing";
	If Form.Commands.Find(NameOfCleanupCommand) = Undefined Then
		Command = Form.Commands.Add(NameOfTheSearchString + "Clearing");
		Command.Action = "Attachable_SearchStringClearing";
		Command.Representation = ButtonRepresentation.Picture;
	EndIf;
	
	SearchCleanUpButton = Form.Items.Add(NameOfCleanupCommand, Type("FormButton"), SearchGroup1);
	SearchCleanUpButton.Type = FormButtonType.UsualButton;
	SearchCleanUpButton.Picture = PictureLib.InputFieldClear;
	SearchCleanUpButton.VerticalAlignInGroup = ItemVerticalAlign.Center;
	SearchCleanUpButton.CommandName = NameOfCleanupCommand;
	SearchCleanUpButton.ShapeRepresentation = ButtonShapeRepresentation.WhenActive;
	SearchCleanUpButton.Title = NStr("en = 'Clear';");
	
	If FieldList <> Undefined Then
		Form.Items.Move(SearchGroup1, LocationOfTheSearchString, FieldList);
	EndIf;
				
	SearchString.DataPath = NameOfTheSearchString;
	SearchString.Type = FormFieldType.InputField;
	SearchString.InputHint = AddingOptions.HintForEnteringTheSearchString;
	SearchString.TitleLocation = FormItemTitleLocation.None;
	SearchString.SetAction("EditTextChange", "Attachable_SearchStringEditTextChange");
	SearchString.AutoMaxWidth = False;
	SearchString.EditTextUpdate = EditTextUpdate.DontUse;
	SearchString.Title = NStr("en = 'Find';");
	
	If FieldList = Undefined Then
		FieldList = Form.Items.Add(NameOfTheFieldList, Type("FormTable"), AddingOptions.LocationOfTheList);
		FieldList.DataPath = NameOfTheFieldList;
	EndIf;
	
	FieldList.InitialTreeView = InitialTreeView.NoExpand;
	FieldList.TitleLocation = FormItemTitleLocation.None;
	FieldList.Header = False;
	FieldList.HorizontalLines = False;
	FieldList.VerticalLines = False;
	FieldList.ChangeRowSet = False;
	FieldList.ChangeRowOrder = False;
	FieldList.SelectionMode = TableSelectionMode.SingleRow;
	FieldList.CommandBar.Visible = False;
	FieldList.SetAction("BeforeExpand", "Attachable_ListOfFieldsBeforeExpanding");
	FieldList.SetAction("DragStart", "Attachable_ListOfFieldsStartDragging");
	
	For Each ContextMenuButton In AddingOptions.ContextMenu Do
		Button = Form.Items.Add(NameOfTheFieldList + ContextMenuButton.Key, Type("FormButton"), FieldList.ContextMenu);
		Button.CommandName = ContextMenuButton.Value;
		Button.Type = FormButtonType.CommandBarButton; 
	EndDo;
	
	For Each Handler In AddingOptions.ListHandlers Do
		EventName = Handler.Key;
		ProcedureName = Handler.Value;
		FieldList.SetAction(EventName, ProcedureName);
	EndDo;
	
	ColumnGroup = Form.Items.Add(NameOfTheFieldList + "PictureAndPresentation", Type("FormGroup"), FieldList);
	ColumnGroup.Group = ColumnsGroup.InCell;
	
	FieldPicture = Form.Items.Add(NameOfTheFieldList + "Picture", Type("FormField"), ColumnGroup);
	FieldPicture.DataPath = NameOfTheFieldList + ".Picture";
	FieldPicture.Type = FormFieldType.PictureField;
	FieldPicture.ShowInHeader = False;
	FieldPicture.Title = NStr("en = 'Picture';");
	
	FieldPresentation = Form.Items.Add(ColumnNamePresentation(NameOfTheFieldList), Type("FormField"), ColumnGroup);
	FieldPresentation.DataPath = NameOfTheFieldList + ".Title";
	FieldPresentation.Type = FormFieldType.InputField;
	FieldPresentation.ReadOnly = True;
	FieldPresentation.Title = NStr("en = 'Title';");
	
	FieldPresentation = Form.Items.Add(NameOfTheFieldList + "RepresentationOfTheDataPath", Type("FormField"), ColumnGroup);
	FieldPresentation.DataPath = NameOfTheFieldList + ".RepresentationOfTheDataPath";
	FieldPresentation.Type = FormFieldType.LabelField;
	FieldPresentation.ReadOnly = True;
	FieldPresentation.Visible = False;
	FieldPresentation.Title = NStr("en = 'Field';");
	
	ConnectedFieldLists = Form.ConnectedFieldLists; // ValueTable
	ConnectedList = ConnectedFieldLists.Add();
	ConnectedList.NameOfTheFieldList = NameOfTheFieldList;
	ConnectedList.NameOfTheSourceList = NameOfTheSourceList;
	ConnectedList.IdentifierBrackets = AddingOptions.IdentifierBrackets;
	ConnectedList.ViewBrackets = AddingOptions.ViewBrackets;
	ConnectedList.UseIdentifiersForFormulas = AddingOptions.UseIdentifiersForFormulas;
	ConnectedList.WhenDefiningAvailableFieldSources = AddingOptions.WhenDefiningAvailableFieldSources;
	If AddingOptions.UseBackgroundSearch Then 
		ConnectedList.UseBackgroundSearch = AddingOptions.UseBackgroundSearch;
		ConnectedList.NumberOfCharsToAllowSearching = AddingOptions.NumberOfCharsToAllowSearching;
	EndIf;
	
	SourcesOfAvailableFields = Form[NameOfTheSourceList]; // ValueTable
	
	FieldsCollections = AddingOptions.FieldsCollections;
	If TypeOf(FieldsCollections) = Type("Array") Then
		FieldsCollections = New ValueList;
		FieldsCollections.LoadValues(AddingOptions.FieldsCollections);
	EndIf;
	
	For Each Item In FieldsCollections Do
		FieldsCollection = Item.Value;
		DataSource = Item.Presentation;
		If Not ValueIsFilled(DataSource) Then
			DataSource = AddingOptions.PrimarySourceName;
		EndIf;
		SourceOfAvailableFields = SourcesOfAvailableFields.Add();
		If TypeOf(FieldsCollection) = Type("String") And IsTempStorageURL(FieldsCollection) Then
			SourceOfAvailableFields.DataCompositionSchema = FieldsCollection;
			SourceOfAvailableFields.FieldsCollection = FieldsCollection(FieldsCollection);
		Else
			SourceOfAvailableFields.FieldsCollection = FieldsCollection;
		EndIf;
		SourceOfAvailableFields.DataSource = DataSource;
		SourceOfAvailableFields.Replace = AddingOptions.Replace;
	EndDo;
	
	For Each SourceOfAvailableFields In AddingOptions.SourcesOfAvailableFields Do
		FillPropertyValues(SourcesOfAvailableFields.Add(), SourceOfAvailableFields);
	EndDo;
	
	FieldTree = Form.FormAttributeToValue(NameOfTheFieldList);
	TableOfSources = Form.FormAttributeToValue(NameOfTheSourceList);
	
	FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(FieldTree);
	FillingParametersForAvailableAttributesList.FormUniqueID = Form.UUID;
	FillingParametersForAvailableAttributesList.ListSettings = ConnectedList;
	FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, TableOfSources);
		
	Form.ValueToFormAttribute(FieldTree, NameOfTheFieldList);
	Form.ValueToFormAttribute(TableOfSources, NameOfTheSourceList);
	
	SetConditionalAppearance(Form, NameOfTheFieldList);
	
EndProcedure

Function FindFormAttribute(Form, AttributeName)
	AttributesArray = Form.GetAttributes();
	For Each FormAttribute In AttributesArray Do
		If FormAttribute.Name = AttributeName Then
			Return FormAttribute;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

// Returns:
//  Structure:
//   * LocationOfTheList - FormGroup
//                           - FormTable
//                           - ClientApplicationForm
//   * UseBackgroundSearch - Boolean
//   * NumberOfCharsToAllowSearching - Number
//   * ListName - String
//   * FieldsCollections - Array
//   * LocationOfTheSearchString - FormGroup
//                                 - FormTable
//                                 - ClientApplicationForm
//   * HintForEnteringTheSearchString - String
//   * ListHandlers - Structure
//   * IncludeGroupsInTheDataPath - Boolean
//   * IdentifierBrackets - Boolean
//   * ViewBrackets - Boolean
//   * SourcesOfAvailableFields - See CollectionOfSourcesOfAvailableFields
//   * UseIdentifiersForFormulas - Boolean
//   * WhenDefiningAvailableFieldSources - String
//   * PrimarySourceName - String
//   * Replace - Boolean
//
Function ParametersForAddingAListOfFields() Export
	
	Result = New Structure;
	Result.Insert("LocationOfTheList");
	Result.Insert("UseBackgroundSearch", False);
	Result.Insert("NumberOfCharsToAllowSearching", 3);
	Result.Insert("ListName", "AvailableFields");
	Result.Insert("FieldsCollections", New Array);
	Result.Insert("LocationOfTheSearchString");
	Result.Insert("HintForEnteringTheSearchString", NStr("en = 'Find…';"));
	Result.Insert("ListHandlers", New Structure);
	Result.Insert("IncludeGroupsInTheDataPath", True);
	Result.Insert("IdentifierBrackets", False);
	Result.Insert("ViewBrackets", True);
	Result.Insert("SourcesOfAvailableFields", CollectionOfSourcesOfAvailableFields());
	Result.Insert("UseIdentifiersForFormulas", False);
	Result.Insert("WhenDefiningAvailableFieldSources", "");
	Result.Insert("PrimarySourceName", "");
	Result.Insert("ContextMenu", New Structure);
	Result.Insert("Replace", False);
	
	Return Result;
	
EndFunction

Procedure PopulateTreeByAvailableFields(TreeRow, AvailableFields)
	For Each AvailableField In AvailableFields.Items Do
		NewRow = TreeRow.Rows.Add();
		FillPropertyValues(NewRow, AvailableField);
		NewRow.Id = String(AvailableField.Field);
		Parent = AvailableField.Parent;
		
		If Parent <> Undefined And StrStartsWith(NewRow.Id, String(Parent.Field)) Then
			NewRow.Id = Mid(NewRow.Id, StrLen(String(Parent.Field)) + 2);
		EndIf;
			
		NewRow.Presentation = AvailableField.Title;
		NewRow.Folder = AvailableField.Folder And Not AvailableField.Table;
		If (AvailableField.Folder Or AvailableField.Table) And AvailableField.Items.Count() <> 0 Then
			PopulateTreeByAvailableFields(NewRow, AvailableField);
		EndIf;
	EndDo;
EndProcedure

Procedure ClearUpSearchString(Form, TagName)
	
	SearchString = Form.Items[StrReplace(TagName, "Clearing", "")];
	Form.CurrentItem = SearchString;
	Form[SearchString.Name] = "";
	CancelBackgroundSearchJob(Form);
	
EndProcedure

Procedure UpdateFieldCollections(Form, FieldsCollections, NameOfTheFieldList = "AvailableFields") Export
	
	SourcesOfAvailableFields = ListOfSourcesOfAvailableFields(Form, NameOfTheFieldList); // FormDataCollection
	MainDataSourceName = MainDataSourceName(SourcesOfAvailableFields);
	SourcesOfAvailableFields.Clear();
	
	CollectionOfDataSourcesFields = FieldsCollections;
	If TypeOf(FieldsCollections) = Type("Array") Then
		CollectionOfDataSourcesFields = New ValueList;
		CollectionOfDataSourcesFields.LoadValues(FieldsCollections);
	EndIf;
	
	For IndexOf = 0 To FieldsCollections.Count()-1 Do
		FieldsCollection = CollectionOfDataSourcesFields[IndexOf].Value;
		DataSource = CollectionOfDataSourcesFields[IndexOf].Presentation;
		If Not ValueIsFilled(DataSource) Then
			DataSource = MainDataSourceName;
		EndIf;
		
		SourceOfAvailableFields = SourcesOfAvailableFields.Insert(IndexOf);
		SourceOfAvailableFields.DataSource = DataSource;
		SourceOfAvailableFields.FieldsCollection = FieldsCollection;
	EndDo;
	
	Form[NameOfTheFieldList].GetItems().Clear();
	ListSettings = FormulasConstructorClientServer.FieldListSettings(Form, NameOfTheFieldList);
	
	FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(Form[NameOfTheFieldList]);
	FillingParametersForAvailableAttributesList.ListSettings = ListSettings;
	FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, SourcesOfAvailableFields);
	
EndProcedure

Function FieldTable() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Id", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("ValueType", New TypeDescription("TypeDescription"));
	Result.Columns.Add("Picture", New TypeDescription("Picture"));
	Result.Columns.Add("Order", New TypeDescription("Number"));
	Result.Columns.Add("Format", New TypeDescription("String"));
	Result.Columns.Add("IsFunction", New TypeDescription("Boolean"));
	Result.Columns.Add("Hidden", New TypeDescription("Boolean"));
	Result.Columns.Add("ExpressionToInsert", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

Function FieldTree() Export
	
	Result = New ValueTree();
	Result.Columns.Add("Id", New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("ValueType", New TypeDescription("TypeDescription"));
	Result.Columns.Add("Picture", New TypeDescription("Picture"));
	Result.Columns.Add("Order", New TypeDescription("Number"));
	Result.Columns.Add("Folder", New TypeDescription("Boolean"));
	Result.Columns.Add("Table", New TypeDescription("Boolean"));
	Result.Columns.Add("Format", New TypeDescription("String"));
	Result.Columns.Add("IsFunction", New TypeDescription("Boolean"));
	Result.Columns.Add("Hidden", New TypeDescription("Boolean"));
	Result.Columns.Add("ExpressionToInsert", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

Function FieldSourceSettingsLinker(Val FieldSource, Form = Undefined) Export
	
	If IsTempStorageURL(FieldSource) Then
		FieldSource = GetFromTempStorage(FieldSource);
	EndIf;
	
	DataCompositionSchema = FieldSource;
	If TypeOf(FieldSource) = Type("ValueTable") Then
		DataCompositionSchema = LayoutDiagramOfDataFromTheValueTable(FieldSource);
	ElsIf TypeOf(FieldSource) = Type("ValueTree") Then
		DataCompositionSchema = DataLayoutSchemeFromTheValueTree(FieldSource);
	EndIf;
	
	If TypeOf(DataCompositionSchema) <> Type("DataCompositionSchema") Then
		Return Undefined;
	EndIf;
	
	If Form <> Undefined Then
		UUID = Form.UUID;
	EndIf;
	SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemaURL);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(AvailableSettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	Return SettingsComposer;
	
EndFunction

Function CollectionOfSettingsLinkerFields(Val SettingsComposer, Val NameOfTheSKDCollection = Undefined)
	
	If Not ValueIsFilled(NameOfTheSKDCollection) Then
		NameOfTheSKDCollection = "FilterAvailableFields";
	EndIf;
	
	DescriptionOfTheFieldCollectionName = StrSplit(NameOfTheSKDCollection, ".");
	FieldsCollection = SettingsComposer.Settings;
	
	For Each Item In DescriptionOfTheFieldCollectionName Do 
		FieldsCollection = FieldsCollection[Item];
	EndDo;
	
	Return FieldsCollection;
EndFunction

Function FillingParametersForAvailableAttributesList(CurrentAttribute)
	Parameters = New Structure;
	Parameters.Insert("NameOfTheFieldList", "");
	Parameters.Insert("FormUniqueID", Undefined);
	Parameters.Insert("ListSettings", Undefined);
	Parameters.Insert("CurrentAttribute", CurrentAttribute);
	Return Parameters;
EndFunction

Procedure FillInTheListOfAvailableDetails(Parameters, SourcesOfAvailableFields, DCSCache = Undefined)
	
	NameOfTheFieldList = Parameters.NameOfTheFieldList;
	FormUniqueID = Parameters.FormUniqueID;
	ListSettings = Parameters.ListSettings;
	CurrentAttribute = Parameters.CurrentAttribute;
	
	CacheData = Undefined;
	AvailableAttributes = Undefined;
	TypeSpecified = TypeOf(CurrentAttribute) = Type("ValueTreeRow") And CurrentAttribute.Type <> New TypeDescription();
	If DCSCache <> Undefined And TypeSpecified Then
		CacheFilter = New Structure("NameOfTheFieldList, FieldType", NameOfTheFieldList, CurrentAttribute.Type);
		CacheData = DCSCache.FindRows(CacheFilter);
		If CacheData.Count() > 0 Then
			AvailableAttributes = CacheData[0].AvailableFields;
		EndIf;
	EndIf;
	
	If AvailableAttributes = Undefined Then
		CollectionsOfAvailableFields = CollectionsOfAvailableFields(CurrentAttribute, SourcesOfAvailableFields, ListSettings, FormUniqueID);
		AvailableAttributes = AvailableAttributes(CollectionsOfAvailableFields);
		If DCSCache <> Undefined And TypeSpecified And CacheData.Count() = 0 Then
			CacheData = DCSCache.Add();
			CacheData.NameOfTheFieldList = NameOfTheFieldList;
			CacheData.FieldType = CurrentAttribute.Type;
			CacheData.AvailableFields = AvailableAttributes;
		EndIf;
	EndIf;
	
	AttributesCollection = ChildItems(CurrentAttribute);
	FieldReferenceAdded = False;
	For Each AvailableProps In AvailableAttributes Do
		If AvailableProps.Name = "Ref" Then
			If TypeOf(CurrentAttribute) <> Type("FormDataTree") And TypeOf(CurrentAttribute) <> Type("ValueTree")
				Or FieldReferenceAdded Then
				Continue;
			EndIf;
			FieldReferenceAdded = True;
		EndIf;
		
		Attribute = AttributesCollection.Add();
		FillPropertyValues(Attribute, AvailableProps);
		
		If Parent(Attribute) <> Undefined Then
			Parent = Parent(Attribute);
			If Attribute.IsFolder Then
				Attribute.DataPath = Parent.DataPath;
				Attribute.RepresentationOfTheDataPath = String(Parent.RepresentationOfTheDataPath);
			Else
				If ValueIsFilled(Parent.DataPath) Then
					Attribute.DataPath = Parent.DataPath + "." + Attribute.Name;
					Attribute.RepresentationOfTheDataPath = String(Parent.RepresentationOfTheDataPath) + "." + Attribute.Title;
				EndIf;
			EndIf;
		EndIf;
		
		If AvailableProps.HasSubordinateItems Then
			ChildItems(Attribute).Add();
		ElsIf ListSettings <> Undefined And ValueIsFilled(ListSettings.WhenDefiningAvailableFieldSources) Then
			CollectionsOfPropsFields = CollectionsOfAvailableFields(Attribute, SourcesOfAvailableFields, ListSettings, FormUniqueID);
			If ValueIsFilled(CollectionsOfPropsFields) And Not StrFind(Attribute.DataPath, Attribute.Name + ".")
				And ValueIsFilled(CollectionsOfPropsFields[0].Items) Then
					ChildItems(Attribute).Add();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function AvailableAttributes(CollectionsOfAvailableFields)

	AvailableAttributes = NewCollectionOfAvailableProps();
	AvailableAttributes.Columns.Add("HasSubordinateItems", New TypeDescription("Boolean"));
	AvailableAttributes.Columns.Add("Order", New TypeDescription("Number"));
	AvailableAttributes.Columns.Add("DotsInFieldCount", New TypeDescription("Number"));
	AvailableAttributes.Indexes.Add("Field");
	
	ServiceFields = ServiceFields();
	AttachedFilesTypes = AttachedFilesTypes();
	FieldsPrefixesPicture = FieldsPrefixesPicture(); 
	
	For Each CollectionOfAvailableFields In CollectionsOfAvailableFields Do
		For Each FieldDetails In CollectionOfAvailableFields.Items Do
			If IsInternalField(FieldDetails, ServiceFields) Then
				Continue;
			EndIf;
			
			FoundAttributes = AvailableAttributes.FindRows(New Structure("Field", FieldDetails.Field));
			For Each Attribute In FoundAttributes Do
				If Not FieldDetails.Type.ContainsType(Type("ValueTable")) Then
					Attribute.Type = New TypeDescription(Attribute.Type, FieldDetails.Type.Types());
				EndIf;
			EndDo;
			If FoundAttributes.Count() > 0 Then
				Continue;
			EndIf;

			Attribute = AvailableAttributes.Add();
			
			Attribute.Title = FieldDetails.Title;
			If FieldDetails.Parent <> Undefined And StrStartsWith(Attribute.Title, FieldDetails.Parent.Title) Then
				Attribute.Title = Mid(Attribute.Title, StrLen(FieldDetails.Parent.Title) + 2);
			EndIf;
			
			Attribute.Field = FieldDetails.Field;
			Attribute.Name = FieldName(FieldDetails.Field);
			Attribute.DotsInFieldCount = StrOccurrenceCount(Attribute.Field, ".");
			
			If Not FieldDetails.Type.ContainsType(Type("ValueTable")) Then
				Attribute.Type = FieldDetails.Type;
			EndIf;
			
			Attribute.Folder = FieldDetails.Folder;
			Attribute.Table = FieldDetails.Table;
			Attribute.Order = 1;
			
			AdditionalParameters = New Map;
			If TypeOf(FieldDetails) = Type("DataCompositionFilterAvailableField") And ValueIsFilled(FieldDetails.Mask)
				And StrStartsWith(FieldDetails.Mask, "{") And StrEndsWith(FieldDetails.Mask, "}") Then
				AdditionalParameters = Common.JSONValue(FieldDetails.Mask);
			EndIf;
			
			If AdditionalParameters["Picture"] <> Undefined Then
				Attribute.Picture = New Picture(Base64Value(AdditionalParameters["Picture"]));
			EndIf;
			
			Order = AdditionalParameters["Order"];
			If ValueIsFilled(Order) Then
				Attribute.Order = Order;
			EndIf;
			
			Attribute.IsFolder = AdditionalParameters["IsFolder"];
			If Attribute.IsFolder Then
				Attribute.Folder = Attribute.IsFolder;
			EndIf;
			
			Attribute.IsFunction = AdditionalParameters["IsFunction"];
			Attribute.Hidden = AdditionalParameters["Hidden"];
			Attribute.ExpressionToInsert = AdditionalParameters["ExpressionToInsert"];
			
			If Not ValueIsFilled(Attribute.Picture) Then
				Attribute.Picture = ImageOfType(FieldDetails.Type);
				
				If Attribute.Table Then
					Attribute.Picture = PictureLib.TypeList;
				ElsIf Attribute.Folder Then
					Attribute.Picture = PictureLib.FolderType;
				ElsIf IsPictureAttribute(Attribute, FieldsPrefixesPicture, AttachedFilesTypes) Then
					Attribute.Picture = PictureLib.TypePicture;
				ElsIf StrStartsWith(Attribute.Name, "Stamp") Then
					Attribute.Picture = PictureLib.DigitalSignatureStamp;
				EndIf;
			EndIf;
			
			If FieldDetails.Field = New DataCompositionField("SystemFields") Then
				Attribute.Order = 2;
			EndIf;
			If FieldDetails.Field = New DataCompositionField("UserFields") Then
				Attribute.Title = NStr("en = 'Formulas';");
				Attribute.Picture = PictureLib.TypeFunction;
				Attribute.Order = 3;
			EndIf;
			If FieldDetails.Field = New DataCompositionField("DetailedRecords") Then
				Attribute.Order = 4;
			EndIf;
			If FieldDetails.Field = New DataCompositionField("CommonAttributes") Then
				Attribute.Order = 5;
			EndIf;
			
			Attribute.RepresentationOfTheDataPath = "";
			If Not Attribute.IsFolder Then
				Attribute.DataPath = Attribute.Name;
				Attribute.RepresentationOfTheDataPath = Attribute.Title;
			EndIf;
			
			HasSubordinateItems = Attribute.IsFolder Or HasSubordinateElements(FieldDetails);
			If HasSubordinateItems Then
				Attribute.HasSubordinateItems = True;
			EndIf;
			
		EndDo;
	EndDo;
	
	AvailableAttributes.Sort("Order, Title, DotsInFieldCount");
	Return AvailableAttributes;
	
EndFunction

Function IsInternalField(Val FieldDetails, Val ServiceFields)

	FieldName = String(FieldDetails.Field);
	If FieldDetails.Table And ServiceFields[FieldName] = True Then
		Return True;
	EndIf;
	For Each SystemField In ServiceFields Do
		If StrEndsWith(FieldName, "." + SystemField.Key) Then	
			Return True;
		EndIf;
	EndDo;
	
	Return (StrEndsWith(FieldName, ".DataVersion"));

EndFunction

Function ServiceFields()
	Result = New Map;
	Result["AdditionalAttributes"] = True;
	Result["ContactInformation"] = True;
	Result["Presentations"] = True;
	Return Result;
EndFunction	

Function IsPictureAttribute(Attribute, FieldsPrefixesPicture, AttachedFilesTypes)

	For Each FieldPrefix In FieldsPrefixesPicture Do
		If StrStartsWith(Attribute.Name, "." + FieldPrefix.Key) Then	
			Return True;
		EndIf;
	EndDo;

 	Return Attribute.Type.Types().Count() = 1 And AttachedFilesTypes.ContainsType(Attribute.Type.Types()[0]);
		
EndFunction

Function FieldsPrefixesPicture()
	Result = New Map;
	Result["Signature"] = True;
	Result["Facsimile"] = True;
	Result["Picture"] = True;
	Return Result;
EndFunction	
	
Function AttachedFilesTypes()
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		Return ModuleFilesOperationsInternal.AttachedFilesTypes();
	EndIf;
	Return New TypeDescription();
	
EndFunction	

// Returns:
//  ValueTable:
//   * Name - String
//   * Title - String
//   * Field - DataCompositionField
//   * DataPath - String
//   * RepresentationOfTheDataPath - String
//   * Type - TypeDescription
//   * Picture - Picture
//   * Folder - Boolean
//   * Table - Boolean
//   * YourOwnSetOfFields - Boolean 
//   * Indent - String
//   * MatchesFilter - Boolean
//   * TheSubordinateElementCorrespondsToTheSelection - Boolean
//   * IsFolder - Boolean
//   * Hidden - Boolean
//   * ExpressionToInsert - String
//
Function NewCollectionOfAvailableProps() 
	
	AvailableAttributes = New ValueTable;
	For Each AttributeDetails In DetailsOfTheConnectedList() Do
		AttributeName = AttributeDetails.Key;
		AttributeType = AttributeDetails.Value;
		AvailableAttributes.Columns.Add(AttributeName, AttributeType);
	EndDo;
	
	Return AvailableAttributes;
	
EndFunction

// Parameters:
//  Collection - FormDataTree
//            - FormDataTreeItemCollection
//            - ValueTree
//            - ValueTreeRow
//
Function ChildItems(Collection)
	
	If TypeOf(Collection) = Type("ValueTree") Or TypeOf(Collection) = Type("ValueTreeRow") Then
		Return Collection.Rows;
	EndIf;
	
	Return Collection.GetItems();
	
EndFunction

// Parameters:
//  Item - FormDataTree
//          - FormDataTreeItemCollection
//          - ValueTree
//          - ValueTreeRow
//
Function Parent(Item)
	
	If TypeOf(Item) = Type("FormDataTreeItem") Then
		Return Item.GetParent();
	ElsIf TypeOf(Item) = Type("ValueTreeRow") Then
		Return Item.Parent;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function FindByID(Collection, RowID)
	
	If TypeOf(Collection) = Type("ValueTree") Or TypeOf(Collection) = Type("ValueTreeRow") Then
		Return Collection.Rows.Find(RowID, "Id", True);
	EndIf;
	
	Return Collection.FindByID(RowID);
	
EndFunction

// Returns:
//  Array of DataCompositionAvailableFields
//
Function CollectionsOfAvailableFields(Attribute, SourcesOfAvailableFields, ListSettings, FormUniqueID)
	
	Result = New Array;
	
	If TypeOf(Attribute) = Type("FormDataTree") Or TypeOf(Attribute) = Type("ValueTree") Then
		For Each SourceOfAvailableFields In SourcesOfAvailableFields Do
			Result.Add(SourceOfAvailableFields.FieldsCollection);
		EndDo;
		Return Result;
	EndIf;
	
	Replace = False;
	For Each SourceOfAvailableFields In SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings, Attribute, FormUniqueID) Do
		Attribute.YourOwnSetOfFields = True;
		Result.Add(SourceOfAvailableFields.FieldsCollection);
		Replace = Replace Or SourceOfAvailableFields.Replace;
	EndDo;
	
	If Replace And ValueIsFilled(Result) Then
		Return Result;
	EndIf;
	
	Parent = Parent(Attribute);
	While Parent <> Undefined Do
		If Parent.YourOwnSetOfFields Then
			Break;
		Else
			Parent = Parent(Parent);
			Continue;
		EndIf;
	EndDo;
	
	If Parent <> Undefined Then
		For Each SourceOfAvailableFields In SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings, Parent, FormUniqueID) Do
			Field = SourceOfAvailableFields.FieldsCollection.FindField(Attribute.Field);
			If Field <> Undefined Then
				Result.Add(Field);
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(Result) And Attribute.Field = New DataCompositionField("Number") Then
		Return Result;
	EndIf;
	
	If Not Replace Or Not ValueIsFilled(Result) Then
		For Each SourceOfAvailableFields In SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings, ,FormUniqueID) Do
			Field = SourceOfAvailableFields.FieldsCollection.FindField(Attribute.Field);
			If Field <> Undefined Then
				Result.Add(Field);
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
	
EndFunction

Function SourcesOfAvailableFields(SourcesOfAvailableFields, ListSettings, Attribute = Undefined, FormUniqueID = Undefined)
	
	Result = New Array;
	MainDataSourceName = MainDataSourceName(SourcesOfAvailableFields);

	If Attribute = Undefined Then
		Filter = New Structure("DataSource", MainDataSourceName);
		For Each SourceOfAvailableFields In SourcesOfAvailableFields.FindRows(Filter) Do
			Result.Add(SourceOfAvailableFields);
		EndDo;
		Return Result;
	EndIf;
	
	DataSources = New Array;
	
	Parent = Parent(Attribute);
	While Parent <> Undefined And Parent.Folder Do
		Parent = Parent(Parent);
	EndDo;
	
	If Parent = Undefined Then
		If ValueIsFilled(MainDataSourceName) Then
			DataSource = MainDataSourceName + "." + Attribute.Name;
			DataSources.Add(DataSource);
		EndIf;
	Else
		For Each Type In Parent.Type.Types() Do
			If Type = Type("CatalogRef.MetadataObjectIDs")
				Or Type = Type("CatalogRef.ExtensionObjectIDs") Then
				Continue;
			EndIf;
			MetadataObject = Metadata.FindByType(Type);
			If MetadataObject = Undefined Then
				Continue;
			EndIf;
			
			DataSource = MetadataObject.FullName() + "." + Attribute.Name;
			DataSources.Add(DataSource);
		EndDo;
	EndIf;
	
	ArrayOfMetadataEnumerations = FormulasConstructorCached.EnumsMetadata();
	
	For Each Type In Attribute.Type.Types() Do
		If Type = Type("CatalogRef.MetadataObjectIDs")
			Or Type = Type("CatalogRef.ExtensionObjectIDs") Then
			Continue;
		EndIf;
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Or ArrayOfMetadataEnumerations.Find(MetadataObject) <> Undefined Then
			Continue;
		EndIf;
		DataSource = MetadataObject.FullName();
		DataSources.Add(DataSource);
	EndDo;
	
	For Each DataSource In DataSources Do
		SourceFound = False;
		For Each SourceOfAvailableFields In SourcesOfAvailableFields Do
			If TheStringMatchesTheTemplate(DataSource, SourceOfAvailableFields.DataSource) Then
				Result.Add(SourceOfAvailableFields);
				SourceFound = True;
				Continue;
			EndIf;
		EndDo;
		
		If Not SourceFound And ListSettings <> Undefined
			And ValueIsFilled(ListSettings.WhenDefiningAvailableFieldSources) Then
			
			FieldSources = CollectionOfSourcesOfAvailableFields();
			Module = Common.CommonModule(ListSettings.WhenDefiningAvailableFieldSources);
			Module.WhenDefiningAvailableFieldSources(DataSource, Attribute.Type, FieldSources, FormUniqueID);
			
			If ValueIsFilled(FieldSources) Then
				For Each FieldSource In FieldSources Do
					SourceOfAvailableFields = SourcesOfAvailableFields.Add();
					FillPropertyValues(SourceOfAvailableFields, FieldSource);
					Result.Add(SourceOfAvailableFields);
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	If ValueIsFilled(Result) Then
		Return Result;
	EndIf;
	
	For Each Type In Attribute.Type.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Or Metadata.Enums.Contains(MetadataObject) Then
			Continue;
		EndIf;
		DataSource = MetadataObject.FullName();
		
		UseIdentifiersForFormulas = False;
		If ListSettings <> Undefined Then
			UseIdentifiersForFormulas = ListSettings.UseIdentifiersForFormulas;
		EndIf;
		
		If UseIdentifiersForFormulas Then
			SettingsComposer = ObjectSettingsLinker(MetadataObject);
			SourceOfAvailableFields = SourcesOfAvailableFields.Add();
			SourceOfAvailableFields.DataSource = DataSource;
			SourceOfAvailableFields.FieldsCollection = SettingsComposer.Settings.FilterAvailableFields;
			SourceOfAvailableFields.Replace = True;
			
			Result.Add(SourceOfAvailableFields);
			
			FieldsCollection = CollectionOfAdditionalDetails(MetadataObject.FullName());
			If FieldsCollection <> Undefined Then
				SourceOfAvailableFields = SourcesOfAvailableFields.Add();
				SourceOfAvailableFields.DataSource = DataSource;
				SourceOfAvailableFields.FieldsCollection = FieldsCollection;
				
				Result.Add(SourceOfAvailableFields);
			EndIf;
			
			FieldsCollection = CollectionOfContactInformationFields(MetadataObject.FullName());
			If FieldsCollection <> Undefined Then
				SourceOfAvailableFields = SourcesOfAvailableFields.Add();
				SourceOfAvailableFields.DataSource = DataSource;
				SourceOfAvailableFields.FieldsCollection = FieldsCollection;
				
				Result.Add(SourceOfAvailableFields);
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function TheStringMatchesTheTemplate(Val String, Val Template)
	
	If Not ValueIsFilled(Template) Then
		Return False;
	EndIf;
	
	If Not StrOccurrenceCount(Template, "*") Then
		Return String = Template;
	EndIf;
	
	String = StrConcat(StrSplit(String, " " + Chars.LF + Chars.CR + Chars.Tab, False), " ");
	TheStringMatchesTheTemplate = True;
	
	For Each PartsOfTheTemplate In StrSplit(Template, "*", True) Do
		FragmentToSearchFor = StrConcat(StrSplit(PartsOfTheTemplate, " " + Chars.LF + Chars.CR + Chars.Tab, False), " ");

		If Not ValueIsFilled(String) And FragmentToSearchFor = "" Then
			TheStringMatchesTheTemplate = False;
			Break;
		EndIf;
		
		Position = StrFind(String, FragmentToSearchFor);
		If Position = 0 Then
			TheStringMatchesTheTemplate = False;
			Break;
		EndIf;
		
		String = Mid(String, Position + StrLen(FragmentToSearchFor));
	EndDo;
	
	If Not StrEndsWith(Template, "*") And ValueIsFilled(String) Then
		TheStringMatchesTheTemplate = False;
	EndIf;
	
	Return TheStringMatchesTheTemplate;
	
EndFunction

Function ObjectSettingsLinker(MetadataObject)
	
	DataCompositionSchema = Undefined;
	
	If TypeOf(MetadataObject) = Type("String") Then
		DataCompositionSchema = GetCommonTemplate("PrintData" + MetadataObject);
	Else
		ThereIsPrintData = MetadataObject.Templates.Find("PrintData") <> Undefined;
		If ThereIsPrintData Then
			ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
			DataCompositionSchema = ObjectManager.GetTemplate("PrintData");
		Else
			QueryText = QueryText(MetadataObject.FullName());
			DataCompositionSchema = DataCompositionSchema(QueryText);
		EndIf;
	EndIf;
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(DataCompositionSchema);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(AvailableSettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	Return SettingsComposer;
	
EndFunction

Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

Function QueryText(TypesOfObjectsToChange, RestrictSelection = False)
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(TypesOfObjectsToChange, ",", False) Do
		MetadataObjects.Add(Common.MetadataObjectByFullName(ObjectName));
	EndDo;
	
	ObjectsStructure = CommonObjectsAttributes(TypesOfObjectsToChange);
	
	Result = "";
	TableAlias = "SpecifiedTableAlias";
	For Each MetadataObject In MetadataObjects Do
		
		If Not IsBlankString(Result) Then
			Result = Result + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
		EndIf;
		
		QueryText = "";
		
		For Each AttributeName In ObjectsStructure.Attributes Do
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "," + Chars.LF;
			EndIf;
			QueryText = QueryText + TableAlias + "." + AttributeName + " AS " + AttributeName;
		EndDo;
		
		For Each TabularSection In ObjectsStructure.TabularSections Do
			TabularSectionName = TabularSection.Key;
			QueryText = QueryText + "," + Chars.LF + TableAlias + "." + TabularSectionName + ".(";
			
			AttributesRow = "LineNumber";
			TabularSectionAttributes = TabularSection.Value;
			For Each AttributeName In TabularSectionAttributes Do
				If Not IsBlankString(AttributesRow) Then
					AttributesRow = AttributesRow + "," + Chars.LF;
				EndIf;
				AttributesRow = AttributesRow + AttributeName;
			EndDo;
			QueryText = QueryText + AttributesRow +"
			|)";
		EndDo;
		
		QueryText = "SELECT " + ?(RestrictSelection, "TOP 1001 ", "") //@query-part
			+ QueryText + Chars.LF + "
			|FROM
			|	"+ MetadataObject.FullName() + " AS " + TableAlias;
		
		Result = Result + QueryText;
	EndDo;
		
		
	Return Result;
	
EndFunction

Function CommonObjectsAttributes(ObjectsTypes) Export
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(ObjectsTypes, ",", False) Do
		MetadataObjects.Add(Common.MetadataObjectByFullName(ObjectName));
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", New Array);
	Result.Insert("TabularSections", New Structure);
	
	If MetadataObjects.Count() = 0 Then
		Return Result;
	EndIf;
		
	CommonAttributesList = ItemsList(MetadataObjects[0].Attributes, False);
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		CommonAttributesList = AttributesIntersection(CommonAttributesList, MetadataObjects[IndexOf].Attributes);
	EndDo;
	
	StandardAttributes = MetadataObjects[0].StandardAttributes;
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		StandardAttributes = AttributesIntersection(StandardAttributes, MetadataObjects[IndexOf].StandardAttributes);
	EndDo;
	For Each Attribute In StandardAttributes Do
		CommonAttributesList.Add(Attribute);
	EndDo;
	
	Result.Attributes = ItemsList(CommonAttributesList);
	
	TabularSections = ItemsList(MetadataObjects[0].TabularSections);
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		TabularSections = SetIntersection(TabularSections, ItemsList(MetadataObjects[IndexOf].TabularSections));
	EndDo;
	
	For Each TabularSectionName In TabularSections Do
		TabularSectionAttributes = ItemsList(MetadataObjects[0].TabularSections[TabularSectionName].Attributes, False);
		For IndexOf = 1 To MetadataObjects.Count() - 1 Do
			TabularSectionAttributes = AttributesIntersection(TabularSectionAttributes, MetadataObjects[IndexOf].TabularSections[TabularSectionName].Attributes);
		EndDo;
		If TabularSectionAttributes.Count() > 0 Then
			Result.TabularSections.Insert(TabularSectionName, ItemsList(TabularSectionAttributes));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function SetIntersection(Set1, Set2) Export
	
	Result = New Array;
	
	For Each Item In Set2 Do
		IndexOf = Set1.Find(Item);
		If IndexOf <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function AttributesIntersection(AttributesCollection1, AttributesCollection2)
	
	Result = New Array;
	
	For Each Attribute2 In AttributesCollection2 Do
		For Each Attribute1 In AttributesCollection1 Do
			If Attribute1.Name = Attribute2.Name 
				And (Attribute1.Type = Attribute2.Type Or Attribute1.Name = "Ref") Then
				Result.Add(Attribute1);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Parameters:
//   Collection - Array of MetadataObjectAttribute
//             - Array of MetadataObjectTabularSection
//   NamesOnly - Boolean
// Returns:
//   Array
//
Function ItemsList(Collection, NamesOnly = True)
	Result = New Array;
	For Each Item In Collection Do
		If NamesOnly Then
			Result.Add(Item.Name);
		Else
			Result.Add(Item);
		EndIf;
	EndDo;
	Return Result;
EndFunction

Procedure FillInTheListOfAvailableFields(Form, FillParameters) Export
	
	RowID = FillParameters.RowID;
	ListName = FillParameters.ListName;
	
	ExpandAttribute(RowID, ListName, Form);
	
EndProcedure

Function ListOfSourcesOfAvailableFields(Form, NameOfTheFieldList)
	
	NameOfTheSourceList = FormulasConstructorClientServer.FieldListSettings(Form, NameOfTheFieldList).NameOfTheSourceList;
	Return Form[NameOfTheSourceList];
	
EndFunction

Function PropertiesListForObjectsKind(ObjectsKind)
	Result = New Array;
	
	PropertiesKinds = New Array;
	PropertiesKinds.Add("AdditionalAttributes");
	PropertiesKinds.Add("AdditionalInfo");
	
	ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
	If ModulePropertyManagerInternal <> Undefined Then
		For Each PropertyKind1 In PropertiesKinds Do
			ListOfProperties = ModulePropertyManagerInternal.PropertiesListForObjectsKind(ObjectsKind, PropertyKind1);
			If ListOfProperties <> Undefined Then
				For Each Item In ListOfProperties Do
					Result.Add(Item.Property);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

Function CollectionOfAdditionalDetails(MetadataObjectName)
	
	ListOfProperties = PropertiesListForObjectsKind(MetadataObjectName);
	If Not ValueIsFilled(ListOfProperties) Then
		Return Undefined;
	EndIf;
	
	AttributesValues = Common.ObjectsAttributesValues(ListOfProperties, "Title,IDForFormulas,ValueType");
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetObject"));
	DataSet.DataSource = "DataSource1";
	DataSet.Name = "DataSet1";
	
	For Each Item In AttributesValues Do
		Property = Item.Value;
		Field = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		Field.Field = Property.IDForFormulas;
		Field.DataPath = Property.IDForFormulas;
		If ValueIsFilled(Property.Title) Then
			Field.Title = Property.Title;
		EndIf;
		Field.ValueType = Property.ValueType;
	EndDo;
	
	SchemaURL = PutToTempStorage(DataCompositionSchema);
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemaURL);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(AvailableSettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	Return SettingsComposer.Settings.FilterAvailableFields;
	
EndFunction

Function CollectionOfContactInformationFields(MetadataObjectName)
	
	ContactInformationKinds = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");

		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(
			Common.ObjectManagerByFullName(MetadataObjectName).EmptyRef());
	EndIf;
	
	If Not ValueIsFilled(ContactInformationKinds) Then
		Return Undefined;
	EndIf;
		
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetObject"));
	DataSet.DataSource = "DataSource1";
	DataSet.Name = "DataSet1";
	
	For Each ContactInformationKind In ContactInformationKinds Do
		If Not ValueIsFilled(ContactInformationKind.IDForFormulas) Then
			Continue;
		EndIf;
		Field = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
		Field.Field = ContactInformationKind.IDForFormulas;
		Field.DataPath = ContactInformationKind.IDForFormulas;
		If ValueIsFilled(ContactInformationKind.Description) Then
			Field.Title = ContactInformationKind.Description;
		EndIf;
		Field.ValueType = New TypeDescription("String");
	EndDo;
	
	SchemaURL = PutToTempStorage(DataCompositionSchema);
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(SchemaURL);
	
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(AvailableSettingsSource);
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	Return SettingsComposer.Settings.FilterAvailableFields;
	
EndFunction

Procedure PerformASearchInTheListOfFields(Form) Export
	
	NameOfTheFieldList = NameOfFieldsListAttribute(Form.NameOfCurrSearchString);
	TheNameOfTheSearchStringProps = Form.NameOfCurrSearchString;
	Filter = Form[TheNameOfTheSearchStringProps];
	FilterIs_Specified = ValueIsFilled(Filter);
	
	If ValueIsFilled(Filter) Then
		SearchResultsRoot = FormulasConstructorClientServer.SearchResultsString(Form[NameOfTheFieldList], False);
		If SearchResultsRoot <> Undefined Then
			Form[NameOfTheFieldList].GetItems().Delete(SearchResultsRoot);
		EndIf;
		
		SearchListParameters = SearchListParameters(Form);
		SearchResult = RunSearchInListOfFields(SearchListParameters);
		If SearchResult <> Undefined Then
			SearchResultsRoot = FormulasConstructorClientServer.SearchResultsString(Form[NameOfTheFieldList]);
			SearchResultsRoot.Title = Filter;
			For Each FoundItem In SearchResult.FoundItems1 Do
				SearchResultsString = SearchResultsRoot.GetItems().Add();
				FillPropertyValues(SearchResultsString, FoundItem);
			EndDo;
			FormulasConstructorClientServer.DoSortByColumn(SearchResultsRoot, "Weight");
		EndIf;
	Else
		SearchResultsRoot = FormulasConstructorClientServer.SearchResultsString(Form[NameOfTheFieldList], False);
		If SearchResultsRoot <> Undefined Then
			Form[NameOfTheFieldList].GetItems().Delete(SearchResultsRoot);
		EndIf;
	EndIf;
	Form.Items[NameOfTheFieldList + "Presentation"].Visible = Not FilterIs_Specified;
	Form.Items[NameOfTheFieldList + "RepresentationOfTheDataPath"].Visible = FilterIs_Specified;
	Form.Items[NameOfTheFieldList].Representation = ?(FilterIs_Specified, TableRepresentation.List, 
		TableRepresentation.Tree);
	
EndProcedure

Function SetFilter(Val Form, Val ListName, Val Filter,
	Val AttributesCollection = Undefined, Val Level = 0)
	
	CurrentSession = GetCurrentInfoBaseSession().GetBackgroundJob();
	IsBackgroundJob = (CurrentSession <> Undefined);
	
	CountInBatch = 5;
	MaxNumOfResults = 25;
	MaxSearchLevel = 3;
	
	MaximumNumberOfResultsHasBeenAchieved = False;
	FilterConsideringLevels = StrSplit(Filter, ".", False);
	SearchConsideringLevels = FilterConsideringLevels.Count() > 1;
	If SearchConsideringLevels Then
		MaxSearchLevel = FilterConsideringLevels.Count();
	EndIf;
	Filter = ?(StrEndsWith(Filter, "."), Mid(Filter, 1, StrLen(Filter)-1), Filter);
	
	FilterStructure1 = New Structure("MatchesFilter", True);
	Level = 1;
	FoundItemsCount = 0;
	CollectionAcquisitionParameters = New Structure;
	CollectionAcquisitionParameters.Insert("ListName", ListName);
	CollectionAcquisitionParameters.Insert("Form", Form);
	CollectionAcquisitionParameters.Insert("SearchConsideringLevels", SearchConsideringLevels);
	PortionLines = New Array;
	AllFoundLines = New Array;
	
	While True Do	
		UsedNodes = New Map;
		While True Do
			BatchOfCurrentLevelFIelds = GetBatchOfGivenLevelFields(CollectionAcquisitionParameters, AttributesCollection, Level, UsedNodes);
			If BatchOfCurrentLevelFIelds = Undefined Then
				Break;
			EndIf;
			
			If SearchConsideringLevels Then
				SetFilterFlag(FoundItemsCount, MaxNumOfResults, BatchOfCurrentLevelFIelds, FilterConsideringLevels[Level-1], 
					SearchConsideringLevels, FilterConsideringLevels.Count() = Level);
			Else
				SetFilterFlag(FoundItemsCount, MaxNumOfResults, BatchOfCurrentLevelFIelds, Filter);
			EndIf;
			
			If IsBackgroundJob Then
				ArrayOfFoundElements = BatchOfCurrentLevelFIelds.Rows.FindRows(FilterStructure1, True);
				If ArrayOfFoundElements.Count() <> 0 Then
					For Each FoundItem In ArrayOfFoundElements Do
						StringStructure = TreeStringIntoStructure(FoundItem, AttributesCollection);
						PortionLines.Add(StringStructure);
						AllFoundLines.Add(StringStructure);
						If PortionLines.Count() = CountInBatch Then
							SendPortionOfFound(PortionLines);
						EndIf;
					EndDo;
				EndIf;
			EndIf;
			
			If FoundItemsCount = MaxNumOfResults Then
				MaximumNumberOfResultsHasBeenAchieved = True;
				Break;	
			EndIf;

		EndDo;
		
		If Level >= 2 And IsBackgroundJob And PortionLines.Count() > 0 Then
			SendPortionOfFound(PortionLines);
		EndIf;
		
		Level = Level + 1;
		If MaximumNumberOfResultsHasBeenAchieved Or Level > MaxSearchLevel  Then
			Break;
		EndIf;
		
	EndDo; 
	
	If Not IsBackgroundJob Then
		ArrayOfFoundElements = AttributesCollection.Rows.FindRows(FilterStructure1, True);
		If ArrayOfFoundElements.Count() <> 0 Then
			For Each FoundItem In ArrayOfFoundElements Do
				StringStructure = TreeStringIntoStructure(FoundItem, AttributesCollection);
				AllFoundLines.Add(StringStructure);
			EndDo;
		EndIf;
	EndIf;
	
	Result = New Structure("FoundItems1", AllFoundLines);
	Return Result;
	
EndFunction

Procedure SendPortionOfFound(FoundRows)
	Result = New Structure("FoundItems1", FoundRows);
	Common.MessageToUser(Common.ValueToXMLString(Result));
	FoundRows.Clear();
EndProcedure

Function TreeStringIntoStructure(TreeRow, Tree)
	
	Columns = New Array();
	For Each Column In Tree.Columns Do
		Columns.Add(Column.Name);
	EndDo;
	
	ColumnsByRow = StrConcat(Columns, ",");
	
	Result = New Structure(ColumnsByRow);
	FillPropertyValues(Result, TreeRow);
			
	Return Result;
	
EndFunction

Procedure SetFilterFlag(FoundItemsCount, Val MaxNumOfResults, Val AttributesCollection,
	Val Filter, SearchConsideringLevels = False, TargetLevel = False)
	
	For Each Attribute In ChildItems(AttributesCollection) Do
		If FoundItemsCount = MaxNumOfResults Then
			Return;
		EndIf;
		If (SearchConsideringLevels And Not IsRelevantParent(Attribute))
			Or (Not SearchConsideringLevels And TheParentPropsMatchTheSelection(Attribute)) Then
			Attribute.MatchesFilter = False;
		Else
			SearchResult = FindTextInALine(Attribute, Filter, SearchConsideringLevels);
			If Not SearchConsideringLevels Or TargetLevel Then
				Attribute.MatchesFilter = SearchResult.MatchesFilter;
			EndIf;
			
			If SearchResult.MatchesFilter Then
				FoundItemsCount = FoundItemsCount + 1;
				Attribute.RepresentationOfTheDataPath = SearchResult.FormattedString;
				Attribute.Weight = SearchResult.Weight;
				ParentOfAttribute = Parent(Attribute);
				If ParentOfAttribute <> Undefined Then
					ParentOfAttribute.TheSubordinateElementCorrespondsToTheSelection = True;
					If SearchConsideringLevels Then
						ParentOfAttribute.Weight = ParentOfAttribute.Weight + Attribute.Weight;
						If ParentOfAttribute.MatchesFilter Then
							FoundItemsCount = FoundItemsCount - 1;
						EndIf;
						ParentOfAttribute.MatchesFilter = False;
					Else
						ParentOfAttribute.Weight = Max(ParentOfAttribute.Weight, Attribute.Weight);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndDo;

EndProcedure

Function GetBatchOfGivenLevelFields(CollectionAcquisitionParameters, AttributesCollection, Level, UsedNodes)
	If Level = 1 Then
		If UsedNodes.Get(-1) <> Undefined Then
			Return Undefined;
		Else
			UsedNodes.Insert(-1, True);
			Return AttributesCollection;
		EndIf;
	EndIf;
	
	Return GetLevelCollection(CollectionAcquisitionParameters, AttributesCollection, Level, UsedNodes);
EndFunction    

Function GetID(Item)
	If TypeOf(Item) = Type("FormDataTreeItem") Then
		Return Item.GetID();
	ElsIf TypeOf(Item) = Type("ValueTreeRow") Then
		Return Item.Id;
	EndIf;
	
	Return Undefined;
EndFunction

Function GetLevelCollection(CollectionAcquisitionParameters, AttributesCollection, Level, UsedNodes, CurrentLevel = 1, ParentIndex = "")
	
	If Level = CurrentLevel Then
		IDOfAttribute = ParentIndex;
		UsedNodes.Insert(IDOfAttribute, True);
		Return AttributesCollection;
	EndIf;

	CollectionItems = ChildItems(AttributesCollection);
	
	For Each Attribute In CollectionItems Do
		IDOfAttribute = GetID(Attribute);
		If UsedNodes.Get(IDOfAttribute) = Undefined Then
			
			If Attribute.DataPath = "<SearchResultsString>" Or StrFind(Attribute.DataPath, ".Delete") > 0 Then
				UsedNodes.Insert(IDOfAttribute, True);
				Continue;
			EndIf;
			
			If CollectionItems.Count() = CollectionItems.IndexOf(Attribute)+1 Then
				CollectionParent = Parent(AttributesCollection);
				If CollectionParent <> Undefined Then
					UsedNodes.Insert(ParentIndex, True);
				EndIf;
			EndIf;
			
			If Level = CurrentLevel + 1 Then
				If (Not Attribute.MatchesFilter And Not CollectionAcquisitionParameters.SearchConsideringLevels) 
					Or (Attribute.Weight > 0 And CollectionAcquisitionParameters.SearchConsideringLevels) Then
					ExpandAttribute(IDOfAttribute, CollectionAcquisitionParameters.ListName, CollectionAcquisitionParameters.Form);
				EndIf;
			EndIf;
			
			Collection = GetLevelCollection(CollectionAcquisitionParameters, Attribute, Level, UsedNodes, CurrentLevel + 1, IDOfAttribute);
			
			If Collection <> Undefined Then
				Return Collection;
			EndIf; 
		EndIf;
	EndDo;
EndFunction

Function TheParentPropsMatchTheSelection(Attribute)
	
	Parent = Parent(Attribute);
	
	If Parent <> Undefined Then
		Return Parent.MatchesFilter Or TheParentPropsMatchTheSelection(Parent);
	EndIf;
	
	Return False;
	
EndFunction

Function IsRelevantParent(Attribute)
	
	Parent = Parent(Attribute);
	
	If Parent <> Undefined Then
		Return Parent.Weight <> 0;
	EndIf;
	
	Return True;
	
EndFunction

Procedure ExpandAttribute(RowID, ListName, Form)
	
	Filter = Form[TheNameOfTheFieldListSearchStringDetails(ListName)];
	
	CurrentData = FindByID(Form[ListName], RowID);
	AttributesCollection = ChildItems(CurrentData);

	ListSettings = FormulasConstructorClientServer.FieldListSettings(Form, ListName);
	
	If AttributesCollection.Count() = 0 Or AttributesCollection[0].Field <> Undefined Then
		Return;
	EndIf;
	
	AttributesCollection.Clear();
	SourcesOfAvailableFields = ListOfSourcesOfAvailableFields(Form, ListName);
	If TypeOf(SourcesOfAvailableFields) = Type("String") Then
		SourcesOfAvailableFields = Common.ValueFromXMLString(SourcesOfAvailableFields);
		NameOfTheSourceList = FormulasConstructorClientServer.FieldListSettings(Form, ListName).NameOfTheSourceList;
		For Each TableRow In SourcesOfAvailableFields Do
			
			If TableRow.DataCompositionSchema <> Undefined Then
				TableRow.DataCompositionSchema = Common.ValueFromXMLString(TableRow.DataCompositionSchema);
			EndIf;
			
			Container = Common.ValueFromXMLString(TableRow.FieldsCollection);
			TableRow.FieldsCollection = AvailableFieldsFromDCSContainer(Container);
						
		EndDo;
		Form[NameOfTheSourceList] = SourcesOfAvailableFields;
	EndIf;
	
	CacheForDCS_ = ?(TypeOf(Form) = Type("Structure"), Form.CacheForDCS_, Form.FormAttributeToValue("CacheForDCS_"));
	
	FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(CurrentData);
	FillingParametersForAvailableAttributesList.NameOfTheFieldList = ListName;
	FillingParametersForAvailableAttributesList.ListSettings = ListSettings;
	FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, SourcesOfAvailableFields, CacheForDCS_);
	
	If TypeOf(Form) = Type("Structure") Then
		Form.CacheForDCS_ = CacheForDCS_;
	Else
		Form.ValueToFormAttribute(CacheForDCS_, "CacheForDCS_");
	EndIf;
	
	If TypeOf(CurrentData) = Type("ValueTreeRow") Then
		SetTreeRowsIDs(CurrentData);
	EndIf;
EndProcedure

Procedure ExpandTheField(CurrentData, SourcesOfAvailableFields, ListSettings)
	
	AttributesCollection = ChildItems(CurrentData);
	
	If AttributesCollection.Count() = 0 Or AttributesCollection[0].Field <> Undefined Then
		Return;
	EndIf;
	AttributesCollection.Clear();
	
	FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(CurrentData);
	FillingParametersForAvailableAttributesList.ListSettings = ListSettings;
	FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, SourcesOfAvailableFields);
	
EndProcedure

Procedure SetConditionalAppearance(Form, NameOfTheFieldList)
	
	ConditionalAppearance = Form.ConditionalAppearance;
	
	//
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Picture");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Presentation");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "RepresentationOfTheDataPath");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(NameOfTheFieldList + ".MatchesFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(TheNameOfTheFieldListSearchStringDetails(NameOfTheFieldList));
	FilterElement.ComparisonType = DataCompositionComparisonType.Filled;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
	AppearanceItem.Appearance.SetParameterValue("Show", False);

	//
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Picture");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Presentation");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "RepresentationOfTheDataPath");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(NameOfTheFieldList + ".Hidden");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	
	AppearanceItem.Appearance.SetParameterValue("Visible", False);
	AppearanceItem.Appearance.SetParameterValue("Show", False); 
	
	//
	
	AppearanceItem = ConditionalAppearance.Items.Add();
	
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Picture");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "Presentation");
	FormattedField = AppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField(NameOfTheFieldList + "RepresentationOfTheDataPath");
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(NameOfTheFieldList + ".MatchesFilter");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True; 
	
	FilterElement = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField(NameOfTheFieldList + ".RepresentationOfTheDataPath");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotContains;
	FilterElement.RightValue = ".";
	
	AppearanceItem.Appearance.SetParameterValue("Font", StyleFonts.ImportantLabelFont);
		
	
EndProcedure

Procedure AddAGroupOfItemsToADataset(ItemsCollection, DataSet, Parent = Undefined)
	
	For Each Item In ItemsCollection.Rows Do
		IsFolder = False;
		
		If Item.Folder Then
			Field = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetFieldFolder"));
		ElsIf Item.Table Then 
			Field = DataSet.Fields.Add(Type("DataCompositionSchemaNestedDataSet"));
			Field.Field = Item.Id;
		Else
			Field = DataSet.Fields.Add(Type("DataCompositionSchemaDataSetField"));
			Field.ValueType = Item.ValueType;
			Field.Field = Item.Id;
			If TypeOf(Parent) = Type("DataCompositionSchemaNestedDataSet") Then
				Field.Field = Parent.DataPath + "." + Item.Id;
			EndIf;
			IsFolder = Item.Rows.Count() > 0 And Not ValueIsFilled(Item.ValueType);			
			
			AdditionalParameters = New Structure("Order,IsFolder,IsFunction,Hidden,ExpressionToInsert");
			FillPropertyValues(AdditionalParameters, Item);
			AdditionalParameters.IsFolder = IsFolder;
			AdditionalParameters.Insert("Picture", Base64String(Item.Picture.GetBinaryData()));			

			Field.EditParameters.SetParameterValue("Mask", 
				Common.ValueToJSON(AdditionalParameters));
		EndIf;
		
		Field.DataPath = Item.Id;
		If Parent <> Undefined Then
			Field.DataPath = Parent.DataPath + "." + Field.DataPath;
		EndIf;
			
		If ValueIsFilled(Item.Presentation) Then
			Field.Title = Item.Presentation;
		EndIf;
		
		If ValueIsFilled(Item.Format) Then
			ParameterValue = Field.Appearance.FindParameterValue(New DataCompositionParameter("Format"));
			If ParameterValue <> Undefined Then
				ParameterValue.Use = True;
				ParameterValue.Value = Item.Format;
			EndIf;
		EndIf;
		
		AddAGroupOfItemsToADataset(Item, DataSet, Field);
	EndDo;
	
EndProcedure

#Region ReadingTheFormula

Function TheFormulaFromTheView(Form, FormulaPresentation, ShouldEscapeUnknownFunctions = True) Export
	
	FormulaElements = FormulaElements(FormulaPresentation);
	Expression = FormulaPresentation;
	ReplacedItems = New Map;
	
	For Each Item In Form.ConnectedFieldLists Do
		NameOfTheFieldList = Item.NameOfTheFieldList;
		FieldsCollection = Form[NameOfTheFieldList];
		IdentifierBrackets = Item.IdentifierBrackets;
		
		For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
			OperandRepresentation = FormulaElements.AllItems[ItemDetails.Key];
			IsFunction = ItemDetails.Value;
			
			DataPath = ClearSquareBrackets(OperandRepresentation);
			Attribute = FindTheProps(Form, NameOfTheFieldList, DataPath, FieldsCollection.GetItems(), True);
			If Attribute <> Undefined  Then
				If IsFunction <> Attribute.IsFunction Then
					Continue;
				EndIf;
				
				Operand = ClearSquareBrackets(Attribute.DataPath);
				If IdentifierBrackets Then
					Operand = WrapInSquareBrackets(Operand);
				EndIf;
				ReplacedItems.Insert(ItemDetails.Key, Operand);
			EndIf;
		EndDo;
	EndDo;
	
	ReplaceFormulaElements(Expression, FormulaElements, ReplacedItems, ShouldEscapeUnknownFunctions);
	Return Expression;
	
EndFunction

Function FormulaPresentation(Form, Formula) Export
	
	FormulaElements = FormulaElements(Formula);
	Expression = Formula;
	ReplacedItems = New Map;
	
	For Each Item In Form.ConnectedFieldLists Do
		NameOfTheFieldList = Item.NameOfTheFieldList;
		FieldsCollection = Form[NameOfTheFieldList];
		ViewBrackets = Item.ViewBrackets;
		
		For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
			Operand = FormulaElements.AllItems[ItemDetails.Key];
			IsFunction = ItemDetails.Value;
			
			DataPath = ClearSquareBrackets(Operand);
			If StrFind(DataPath, "[") Or StrFind(DataPath, "]") Then
				Continue;
			EndIf;
			
			DataPath = String(New DataCompositionField(DataPath));
			
			Attribute = FindTheProps(Form, NameOfTheFieldList, DataPath, FieldsCollection.GetItems(), False);
			If Attribute <> Undefined Then
				If IsFunction <> Attribute.IsFunction Then
					Continue;
				EndIf;
				
				OperandRepresentation = Attribute.RepresentationOfTheDataPath;
				If ViewBrackets Then
					OperandRepresentation = WrapInSquareBrackets(Attribute.RepresentationOfTheDataPath);
				EndIf;
				ReplacedItems.Insert(ItemDetails.Key, OperandRepresentation);
			EndIf;
		EndDo;
	EndDo;
	
	ReplaceFormulaElements(Expression, FormulaElements, ReplacedItems, False);
	Return Expression;
	
EndFunction

Function RepresentationOfTheExpression(Val Expression, ListsOfFields) Export
	
	FormulaElements = FormulaElements(Expression);
	Result = Expression;
	ReplacedItems  = New Map;
	
	For Each ListSettings In ListsOfFields Do
		FieldsCollection = ListSettings.FieldsCollection;
		SourcesOfAvailableFields = ListSettings.SourcesOfAvailableFields;
		If FieldsCollection = Undefined Then
			FieldsCollection = NewCollectionOfFields();
			FillingParametersForAvailableAttributesList = FillingParametersForAvailableAttributesList(FieldsCollection);
			FillingParametersForAvailableAttributesList.ListSettings = ListSettings;
			FillInTheListOfAvailableDetails(FillingParametersForAvailableAttributesList, SourcesOfAvailableFields);
		EndIf;
		
		For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
			Operand = FormulaElements.AllItems[ItemDetails.Key];
			IsFunction = ItemDetails.Value;
			
			DataPath = ClearSquareBrackets(Operand);
			Attribute = FindField(DataPath, ChildItems(FieldsCollection), False, SourcesOfAvailableFields, ListSettings);
			If Attribute <> Undefined Then
				If IsFunction <> Attribute.IsFunction Then
					Continue;
				EndIf;
				
				OperandRepresentation = Attribute.RepresentationOfTheDataPath;
				If ListSettings.ViewBrackets Then
					OperandRepresentation = WrapInSquareBrackets(Attribute.RepresentationOfTheDataPath);
				EndIf;
				ReplacedItems.Insert(ItemDetails.Key, OperandRepresentation);
			EndIf;
		EndDo;
	EndDo;

	ReplaceFormulaElements(Result, FormulaElements, ReplacedItems);
	Return Result;
	
EndFunction

Function FormatFields(DataPath, SchemaURL)
	
	If Not ValueIsFilled(SchemaURL) Then
		Return "";
	EndIf;
	
	DataCompositionSchema = GetFromTempStorage(SchemaURL); // DataCompositionSchema
	
	Field = DataCompositionSchema.DataSets[0].Fields.Find(DataPath);
	If TypeOf(Field) <> Type("DataCompositionSchemaDataSetField") Then
		If DataPath = "Date" Then
			Return "DLF=D;";
		Else
			Return "";
		EndIf;
	EndIf;
	
	ParameterValue = Field.Appearance.FindParameterValue(New DataCompositionParameter("Format"));
	If ParameterValue <> Undefined Then
		Return ParameterValue.Value;
	EndIf;

	Return "";
	
EndFunction

Function ExpressionToCheck(Form, FormulaPresentation, NameOfTheListOfOperands) Export
	
	FormulaElements = FormulaElements(FormulaPresentation);
	Expression = FormulaPresentation;
	ReplacedItems = New Map;
	
	For Each Item In Form.ConnectedFieldLists Do
		NameOfTheFieldList = Item.NameOfTheFieldList;
		FieldsCollection = Form[NameOfTheFieldList];
		IdentifierBrackets = Item.IdentifierBrackets;
		
		For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
			OperandRepresentation = FormulaElements.AllItems[ItemDetails.Key];
			IsFunction = ItemDetails.Value;
			
			DataPath = ClearSquareBrackets(OperandRepresentation);
			Attribute = FindTheProps(Form, NameOfTheFieldList, DataPath, FieldsCollection.GetItems(), True);
			If Attribute <> Undefined  Then
				If IsFunction <> Attribute.IsFunction Then
					Continue;
				EndIf;
				
				If NameOfTheListOfOperands = NameOfTheFieldList Then
					Operand = Attribute.Type.AdjustValue(1);
					If TypeOf(Operand) = Type("String") Then
						Operand = """" + Operand + """";
					EndIf;
					If TypeOf(Operand) = Type("Boolean") Then
						Operand = Format(Operand, "BF=False; BT=True"); // Must be in the configuration language.
					EndIf;
					If TypeOf(Operand) = Type("Date") Then
						Operand = "'" + Format(CurrentSessionDate(), "DF=yyyyMMddHHmm") +  "'"; // Used in the Calculate() expression.
					EndIf;
					If Common.IsReference(TypeOf(Operand)) Then
						Operand = "1";
					EndIf;
				Else
					Operand = ClearSquareBrackets(Attribute.DataPath);
					If IdentifierBrackets Then
						Operand = WrapInSquareBrackets(Operand);
					EndIf;
				EndIf;
				
				ReplacedItems.Insert(ItemDetails.Key, Operand);
			EndIf;
		EndDo;
	EndDo;
	
	ReplaceFormulaElements(Expression, FormulaElements, ReplacedItems);
	Expression = FormatNumbers(Expression);
	
	Return Expression;
	
EndFunction

Procedure ReplaceFormulaElements(Expression, FormulaElements, Values, ShouldEscapeUnknownFunctions = True)
	
	For Each ItemDetails In FormulaElements.OperandsAndFunctions Do
		Operand = FormulaElements.AllItems[ItemDetails.Key];
		IsFunction = ItemDetails.Value;
		Value = Values[ItemDetails.Key];
		If Value = Undefined Then
			If IsFunction And ShouldEscapeUnknownFunctions
				And Not StrEndsWith(Operand, SuffixDisabledFunctions()) Then
				Value = Operand + SuffixDisabledFunctions();
			Else
				Value = Operand;
			EndIf;
		EndIf;
		
		FormulaElements.AllItems[ItemDetails.Key] = Value;
	EndDo;
	
	Expression = StrConcat(FormulaElements.AllItems);
	
EndProcedure

Function SuffixDisabledFunctions()
	
	Return "__";
	
EndFunction

Function ClearSquareBrackets(String)
	
	If StrStartsWith(String, "[") And StrEndsWith(String, "]") Then
		Return Mid(String, 2, StrLen(String) - 2);
	EndIf;
	
	Return String;
	
EndFunction

Function WrapInSquareBrackets(String)
	
	Return "[" + String + "]";
	
EndFunction

Function FindTheProps(Form, ListName, DataPath, AttributesCollection, SearchByView)
	
	NameOfTheSearchField = "DataPath";
	If SearchByView Then
		NameOfTheSearchField = "RepresentationOfTheDataPath";
	EndIf;
	
	Owners = New Array;
	
	For Each Attribute In AttributesCollection Do
		If Lower(Attribute[NameOfTheSearchField]) = Lower(DataPath) Then
			Return Attribute;
		EndIf;
		If Attribute.Folder Or StrStartsWith(Lower(DataPath), Lower(Attribute[NameOfTheSearchField]) + ".") Then
			Owners.Add(Attribute);
		EndIf;
	EndDo;
	
	For Each Owner In Owners Do
		ExpandAttribute(Owner.GetID(), ListName, Form);
		FoundAttribute = FindTheProps(Form, ListName, DataPath, Owner.GetItems(), SearchByView);
		
		If FoundAttribute <> Undefined Then
			Return FoundAttribute;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function FindField(DataPath, AttributesCollection, SearchByView, SourcesOfAvailableFields, ListSettings)
	
	NameOfTheSearchField = "DataPath";
	If SearchByView Then
		NameOfTheSearchField = "RepresentationOfTheDataPath";
	EndIf;
	
	Owner = Undefined;
	Folders = New Array;
	
	For Each Attribute In AttributesCollection Do
		If Lower(Attribute[NameOfTheSearchField]) = Lower(DataPath) Then
			Return Attribute;
		EndIf;
		If Attribute.Folder Then
			Folders.Add(Attribute);
		Else
			If StrStartsWith(Lower(DataPath), Lower(Attribute[NameOfTheSearchField]) + ".") Then
				Owner = Attribute;
			EndIf;
		EndIf;
	EndDo;
	
	If Owner <> Undefined Then
		ExpandTheField(Owner, SourcesOfAvailableFields, ListSettings);
		Return FindField(DataPath, ChildItems(Owner), SearchByView, SourcesOfAvailableFields, ListSettings);
	EndIf;
	
	For Each Folder In Folders Do
		ExpandTheField(Folder, SourcesOfAvailableFields, ListSettings);
		Attribute = FindField(DataPath, ChildItems(Folder), SearchByView, SourcesOfAvailableFields, ListSettings);
		
		If Attribute <> Undefined Then
			Return Attribute;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

Function DetailsOfTheConnectedList()
	
	Result = New Structure;
	
	Result.Insert("Name", New TypeDescription("String"));
	Result.Insert("Title", New TypeDescription("String"));
	Result.Insert("Field", New TypeDescription());
	Result.Insert("DataPath", New TypeDescription("String"));
	Result.Insert("RepresentationOfTheDataPath", New TypeDescription);
	Result.Insert("Type", New TypeDescription("TypeDescription"));
	Result.Insert("Picture", New TypeDescription("Picture"));
	Result.Insert("Folder", New TypeDescription("Boolean"));
	Result.Insert("Table", New TypeDescription("Boolean"));
	Result.Insert("YourOwnSetOfFields", New TypeDescription("Boolean"));
	Result.Insert("Indent", New TypeDescription("String"));
	Result.Insert("MatchesFilter", New TypeDescription("Boolean"));
	Result.Insert("TheSubordinateElementCorrespondsToTheSelection", New TypeDescription("Boolean"));
	Result.Insert("IsFolder", New TypeDescription("Boolean"));
	Result.Insert("IsFunction", New TypeDescription("Boolean"));
	Result.Insert("Hidden", New TypeDescription("Boolean"));
	Result.Insert("ExpressionToInsert", New TypeDescription("String"));
	Result.Insert("Weight", New TypeDescription("Number"));
	
	Return Result;
	
EndFunction

Function SourceListAvailableFieldsAttributes()
	
	Result = New Structure;
	
	Result.Insert("DataSource", New TypeDescription("String"));
	Result.Insert("FieldsCollection", New TypeDescription());
	Result.Insert("Replace", New TypeDescription("Boolean"));
	Result.Insert("DataCompositionSchema", New TypeDescription());
	Result.Insert("DataCompositionSchemaId", New TypeDescription("String"));
	
	Return Result;
	
EndFunction

Function NewCollectionOfFields()
	
	Result = New ValueTree();
	For Each AttributeDetails In DetailsOfTheConnectedList() Do
		AttributeName = AttributeDetails.Key;
		AttributeType = AttributeDetails.Value;
		Result.Columns.Add(AttributeName, AttributeType);
	EndDo;	
	
	Return Result;
	
EndFunction

Function ImageOfType(TypeDescription)
	
	Picture = FormulasConstructorCached.PictureByName("TypeUndefined");
	If TypeDescription.Types().Count() = 1 Then
		Type = TypeDescription.Types()[0];
		If Type = Type("Number") Then
			Picture = FormulasConstructorCached.PictureByName("NumberType");
		ElsIf Type = Type("Date") Then
			Picture = FormulasConstructorCached.PictureByName("DateType");
		ElsIf Type = Type("Boolean") Then
			Picture = FormulasConstructorCached.PictureByName("BooleanType");
		ElsIf Type = Type("String") Then
			Picture = FormulasConstructorCached.PictureByName("StringType");
		ElsIf Common.IsReference(Type) Then
			Picture = FormulasConstructorCached.PictureByName("TypeRef");
		ElsIf Type = Type("UUID") Then
			Picture = FormulasConstructorCached.PictureByName("TypeID");
		EndIf;
	ElsIf TypeDescription.Types().Count() > 1 Then
		Picture = FormulasConstructorCached.PictureByName("TypeFlexibleMain");
	EndIf;
	
	Return Picture;
	
EndFunction

Function ListOfOperators(GroupsOfOperators = Undefined) Export
	
	ListOfOperators =  FieldTree();
	
	If GroupsOfOperators = Undefined Then
		GroupsOfOperators = "LogicalOperatorsAndConstants,
		|NumericFunction, StringFunctions, OtherFunctions";
	ElsIf GroupsOfOperators = "AllSKDOperators" Then
		GroupsOfOperators = "OperationsOnSKDLines, WorkingWithDCSDates, SKDComparisonOperations,
		|LogicalOperationsOfTheSKD, AggregateFunctionsOfTheSCD, OtherDCSFunctions";
	EndIf;
	
	For Each Item In New Structure(GroupsOfOperators) Do
		GroupName = Item.Key;
		If GroupName = "LogicalOperatorsAndConstants" Then
			AddAGroupOfOperatorsLogicalOperatorsAndConstants(ListOfOperators);
		ElsIf GroupName = "NumericFunction" Then
			AddAGroupOfOperatorsNumericFunctions(ListOfOperators);
		ElsIf GroupName = "StringFunctions" Then
			AddAGroupOfOperatorsStringFunctions(ListOfOperators);
		ElsIf GroupName = "OtherFunctions" Then
			AddAGroupOfOperatorsOtherFunctions(ListOfOperators);
		ElsIf GroupName = "OperationsOnSKDLines" Then
			AddAGroupOfOperatorsOperationsOnStrings(ListOfOperators);
		ElsIf GroupName = "WorkingWithDCSDates" Then
			AddGroupOfOperatorsWorkingWithDates(ListOfOperators);
		ElsIf GroupName = "SKDComparisonOperations" Then
			AddAGroupOfComparisonOperationOperators(ListOfOperators);
		ElsIf GroupName = "LogicalOperationsOfTheSKD" Then
			AddAGroupOfLogicalOperationsOperators(ListOfOperators);
		ElsIf GroupName = "AggregateFunctionsOfTheSCD" Then
			AddAGroupOfOperatorsAggregateFunctions(ListOfOperators);
		ElsIf GroupName = "OtherDCSFunctions" Then
			AddGroupOfOperatorsOtherDCSFunctions(ListOfOperators);
		EndIf;
	EndDo;	
	
	Return ListOfOperators;
	
EndFunction

Procedure AddAGroupOfOperatorsLogicalOperatorsAndConstants(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "LogicalOperatorsAndConstants";
	Group.Presentation = NStr("en = 'Logical operators and constants';");
	Group.Order = 3;
	
	Type = New TypeDescription("Boolean");
	
	AddAnOperatorToAGroup(Group, "And", NStr("en = 'AND';"), Type);
	AddAnOperatorToAGroup(Group, "Or", NStr("en = 'OR';"), Type);
	AddAnOperatorToAGroup(Group, "Not", NStr("en = 'NOT';"), Type);
	AddAnOperatorToAGroup(Group, "True", NStr("en = 'True';"), Type);
	AddAnOperatorToAGroup(Group, "False", NStr("en = 'False';"), Type);
	
EndProcedure

Procedure AddAGroupOfOperatorsNumericFunctions(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "NumericFunction";
	Group.Presentation = NStr("en = 'Numeric functions';");
	Group.Order = 4;
	Group.Picture = PictureLib.TypeFunction;
	
	Type = New TypeDescription("Number");
	
	AddAnOperatorToAGroup(Group, "Max", NStr("en = 'Max';"), Type, True);
	AddAnOperatorToAGroup(Group, "Min", NStr("en = 'Min';"), Type, True);
	AddAnOperatorToAGroup(Group, "Round", NStr("en = 'Round off';"), Type, True);
	AddAnOperatorToAGroup(Group, "Int", NStr("en = 'Integral part';"), Type, True);
	
EndProcedure

Procedure AddAGroupOfOperatorsStringFunctions(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "StringFunctions";
	Group.Presentation = NStr("en = 'String functions';");
	Group.Order = 5;
	Group.Picture = PictureLib.TypeFunction;
	
	Type = New TypeDescription("String");
	
	// NStr has localizable IDs.
	
	AddAnOperatorToAGroup(Group, "String", NStr("en = 'Convert into a string';"), Type, True);
	AddAnOperatorToAGroup(Group, "Upper", NStr("en = 'Uppercase';"), Type, True);
	AddAnOperatorToAGroup(Group, "Lower", NStr("en = 'Lowercase';"), Type, True);
	AddAnOperatorToAGroup(Group, "Title", NStr("en = 'Each word is uppercase';"), Type, True);
	AddAnOperatorToAGroup(Group, "Left", NStr("en = 'Left characters';"), Type, True);
	AddAnOperatorToAGroup(Group, "Right", NStr("en = 'Right characters';"), Type, True);
	AddAnOperatorToAGroup(Group, "TrimL", NStr("en = 'Remove spaces on the left';"), Type, True);
	AddAnOperatorToAGroup(Group, "TrimAll", NStr("en = 'Remove spaces on the left and right';"), Type, True);
	AddAnOperatorToAGroup(Group, "TrimR", NStr("en = 'Remove spaces on the right';"), Type, True);
	AddAnOperatorToAGroup(Group, "StrReplace", NStr("en = 'Replace characters in the string';"), Type, True);
	AddAnOperatorToAGroup(Group, "StrLen", NStr("en = 'String length';"), New TypeDescription("Number"), True);
	
EndProcedure

Procedure AddAGroupOfOperatorsOtherFunctions(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "OtherFunctions";
	Group.Presentation = NStr("en = 'Other functions';");
	Group.Order = 6;
	Group.Picture = PictureLib.TypeFunction;
	
	AddAnOperatorToAGroup(Group, "?", NStr("en = 'Condition';"), New TypeDescription("Boolean"), True);
	AddAnOperatorToAGroup(Group, "ValueIsFilled", NStr("en = 'Value is filled';"), New TypeDescription("Boolean"), True);
	AddAnOperatorToAGroup(Group, "Format", NStr("en = 'Format';"), New TypeDescription("String"), True);
	
EndProcedure

Procedure AddAnOperatorToAGroup(Group, Id, Val Presentation, Type = Undefined, IsFunction = False, Hidden = False)
	
	Operator = Group.Rows.Add();
	Operator.Id = Id;
	Operator.Presentation = OperatorPresentation(Presentation);
	Operator.ValueType = Type;
	Operator.Picture = PictureLib.IsEmpty;
	Operator.IsFunction = IsFunction;
	Operator.Hidden = Hidden;

EndProcedure

Procedure AddAGroupOfOperatorsOperationsOnStrings(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "OperationsOnStrings";
	Group.Presentation = NStr("en = 'String operations';");
	Group.Order = 2;
	
	Type = New TypeDescription("String");
	
	AddAnOperatorToAGroup(Group, "LIKE", NStr("en = 'LIKE';"), Type);
	
EndProcedure

Procedure AddGroupOfOperatorsWorkingWithDates(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "WorkingWithDCSDates";
	Group.Presentation = NStr("en = 'Date management';");
	Group.Order = 2;
	Group.Picture = PictureLib.TypeFunction;
	
	Type = New TypeDescription("Number");
	
	AddAnOperatorToAGroup(Group, "YEAR", NStr("en = 'YEAR';"), Type, True);
	AddAnOperatorToAGroup(Group, "MONTH", NStr("en = 'MONTH';"), Type, True);
	AddAnOperatorToAGroup(Group, "NUMBER", NStr("en = 'NUMBER';"), Type, True);
	AddAnOperatorToAGroup(Group, "DAYOFYEAR", NStr("en = 'Day of the year';"), Type, True);
	AddAnOperatorToAGroup(Group, "DAY", NStr("en = 'DAY';"), Type, True);
	AddAnOperatorToAGroup(Group, "WEEK", NStr("en = 'WEEK';"), Type, True);
	AddAnOperatorToAGroup(Group, "WEEKDAY", NStr("en = 'Day of the week';"), Type, True);
	AddAnOperatorToAGroup(Group, "HOUR", NStr("en = 'HOUR';"), Type, True);
	AddAnOperatorToAGroup(Group, "MINUTE", NStr("en = 'MINUTE';"), Type, True);
	AddAnOperatorToAGroup(Group, "SECOND", NStr("en = 'SECOND';"), Type, True);

	AddAnOperatorToAGroup(Group, "BEGINOFPERIOD", NStr("en = 'Period start';"), New TypeDescription, True);
	AddAnOperatorToAGroup(Group, "ENDOFPERIOD", NStr("en = 'Period end';"), New TypeDescription, True);
	AddAnOperatorToAGroup(Group, "ADDTODATE", NStr("en = 'Add to the date';"), New TypeDescription, True);
	
	AddAnOperatorToAGroup(Group, "DATEDIFF", NStr("en = 'Difference between dates';"), Type, True);
	
	AddAnOperatorToAGroup(Group, "CURRENTDATE", NStr("en = 'Current date';"), New TypeDescription, True);
	
EndProcedure

Procedure AddAGroupOfComparisonOperationOperators(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "ComparisonOperation";
	Group.Presentation = NStr("en = 'Comparison operations';");
	Group.Order = 3;
	
	Type = New TypeDescription("Boolean");
	
	AddAnOperatorToAGroup(Group, "In", NStr("en = 'IN';"), Type, True);
	AddAnOperatorToAGroup(Group, "ValueIsFilled", NStr("en = 'Value is filled';"), Type, True);
	
EndProcedure

Procedure AddAGroupOfLogicalOperationsOperators(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "LogicalOperations";
	Group.Presentation = NStr("en = 'Logical operations';");
	Group.Order = 4;
	
	Type = New TypeDescription("Boolean");
	
	AddAnOperatorToAGroup(Group, "NOT", NStr("en = 'NOT';"), Type);
	AddAnOperatorToAGroup(Group, "And", NStr("en = 'AND';"), Type);
	AddAnOperatorToAGroup(Group, "OR", NStr("en = 'OR';"), Type);
	
	Operator = Group.Rows.Add();
	Operator.Id = "CHOICEIFTHENELSEEND";
	Operator.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 ... %3 ...';"),
		OperatorPresentation(NStr("en = 'CASE';")),
		OperatorPresentation(NStr("en = 'WHEN';")),
		OperatorPresentation(NStr("en = 'THEN';")));
	Operator.Picture = PictureLib.IsEmpty;
	Operator.ExpressionToInsert = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1
		|	%2 <%6> %3 <%6>
		|	%4 <%6>
		|%5';"),
		OperatorPresentation(NStr("en = 'CASE';")),
		OperatorPresentation(NStr("en = 'WHEN';")),
		OperatorPresentation(NStr("en = 'THEN';")),
		OperatorPresentation(NStr("en = 'ELSE';")),
		OperatorPresentation(NStr("en = 'END';")),
		NStr("en = 'Expression';"));
	
	AddAnOperatorToAGroup(Group, "CASE", NStr("en = 'CASE';"), , , True); // @query-part
	AddAnOperatorToAGroup(Group, "WHEN", NStr("en = 'WHEN';"), , , True);
	AddAnOperatorToAGroup(Group, "THEN", NStr("en = 'THEN';"), , , True);
	AddAnOperatorToAGroup(Group, "ELSE", NStr("en = 'ELSE';"), , , True);
	AddAnOperatorToAGroup(Group, "END", NStr("en = 'END';"), , , True);
	AddAnOperatorToAGroup(Group, "TRUE", NStr("en = 'TRUE';"), , , True);
	AddAnOperatorToAGroup(Group, "FALSE", NStr("en = 'FALSE';"), , , True);
	
EndProcedure

Procedure AddAGroupOfOperatorsAggregateFunctions(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "AggregateFunctions";
	Group.Presentation = NStr("en = 'Aggregate functions';");
	Group.Order = 5;
	Group.Picture = PictureLib.TypeFunction;
	
	Type = New TypeDescription("Number");
	
	AddAnOperatorToAGroup(Group, "SUM", NStr("en = 'SUM';"), Type, True);
	AddAnOperatorToAGroup(Group, "COUNT", NStr("en = 'COUNT';"), Type, True);
	AddAnOperatorToAGroup(Group, "MAXIMUM", NStr("en = 'MAX';"), Type, True);
	AddAnOperatorToAGroup(Group, "MINIMUM", NStr("en = 'MIN';"), Type, True);
	AddAnOperatorToAGroup(Group, "MEAN", NStr("en = 'AVG';"), Type, True);
	
EndProcedure

Procedure AddGroupOfOperatorsOtherDCSFunctions(ListOfOperators)
	
	Group = ListOfOperators.Rows.Add();
	Group.Id = "OtherFunctions";
	Group.Presentation = NStr("en = 'Other functions';");
	Group.Order = 6;
	Group.Picture = PictureLib.TypeFunction;
	
	AddAnOperatorToAGroup(Group, "STRING", NStr("en = 'STRING';"), New TypeDescription("String"), True);
	AddAnOperatorToAGroup(Group, "VALUE", NStr("en = 'VALUE';"), New TypeDescription, True);
	
EndProcedure

Function TheNameOfTheFieldListSearchStringDetails(NameOfTheFieldList)
	
	Return "SearchString" + NameOfTheFieldList;
	
EndFunction

Function NameOfFieldsListAttribute(NameOfFieldLIstSearchString)
	
	Return StrReplace(NameOfFieldLIstSearchString, "SearchString", "");
	
EndFunction

Function MainDataSourceName(SourcesOfAvailableFields)
	
	If SourcesOfAvailableFields.Count() > 0 Then
		Return SourcesOfAvailableFields[0].DataSource;
	EndIf;
	
	Return "";
	
EndFunction

Function FormatNumbers(String, FractionalPartSeparator = ".")
	
	Result = "";
	Number = "";
	IsDelimiterInNumber = False;
	PreviousChar = "";
	
	StringLength = StrLen(String);
	For IndexOf = 1 To StringLength Do
		If IndexOf < StringLength Then
			NextChar = Mid(String, IndexOf + 1, 1);
		Else
			NextChar = "";
		EndIf;
		Char = Mid(String, IndexOf, 1);
		
		PreviousCharacterThisDelimiter = PreviousChar = "" Or StrFind("()[]/*-+%=<>, " + Chars.Tab + Chars.LF, PreviousChar) > 0;
		
		If IsDigit(Char) And (PreviousCharacterThisDelimiter Or IsDigit(PreviousChar) And ValueIsFilled(Number)) Then
			Number = Number + Char;
		ElsIf Not IsDelimiterInNumber And (Char = "," Or Char = ".") And IsDigit(NextChar)
			And (IsDigit(PreviousChar) Or PreviousCharacterThisDelimiter) And ValueIsFilled(Number) Then
			Number = Number + FractionalPartSeparator;
			IsDelimiterInNumber = True;
		Else
			Result = Result + Number + Char;
			Number = "";
			IsDelimiterInNumber = False;
		EndIf;
		
		PreviousChar = Char;
		Char = "";
	EndDo;
	
	Result = Result + Number + Char;
	Return Result;
	
EndFunction

Function IsDigit(Char)
	
	Return StrFind("1234567890", Char) > 0;
	
EndFunction

Function FieldName(Field)
	
	FieldName = "";
	String = String(Field);
	OpeningParentheses = 0;
	
	For IndexOf = -StrLen(String) To -1 Do
		Position = -IndexOf;
		Char = Mid(String, Position, 1);
		
		If Char = "]" Then
			OpeningParentheses = OpeningParentheses + 1;
		EndIf;
		
		If Char = "[" Then
			OpeningParentheses = OpeningParentheses - 1;
		EndIf;
		
		If Char = "." And OpeningParentheses = 0 Then
			Break;
		Else
			FieldName = Char + FieldName;
		EndIf;
	EndDo;
	
	Return FieldName;
	
EndFunction

Function HasSubordinateElements(Val FieldDetails)
	
	If FieldDetails.Folder Or FieldDetails.Table Then
		Return True;
	EndIf;
	
	For Each Type In FieldDetails.Type.Types() Do
		If Common.IsReference(Type) 
			Or Type = Type("Date") And FieldDetails.Items.Count() > 0 Then
			Return True;
		EndIf; 
	EndDo;
	
	Return False;
	
EndFunction

Procedure ClearFilterFlag(Collection)
	For Each CollectionRow In ChildItems(Collection) Do
		CollectionRow.MatchesFilter = False;
		CollectionRow.TheSubordinateElementCorrespondsToTheSelection = False;
		ClearFilterFlag(CollectionRow);
	EndDo;
EndProcedure

Function AvailableFieldsIntoDCSContainer(AvailableFields)
	FieldTree = FieldTree();
	PopulateTreeByAvailableFields(FieldTree, AvailableFields);
	Return DataLayoutSchemeFromTheValueTree(FieldTree);
EndFunction

Function OperatorPresentation(Val Operator)
	
	Return StrReplace(Title(Operator), " ", "")
	
EndFunction

Function FindTextInALine(String, Text, SearchConsideringLevels)
	Return FormulasConstructorClientServer.FindTextInALine(String, Text, 
		StyleFonts.ImportantLabelFont, StyleColors.SuccessResultColor, SearchConsideringLevels);
EndFunction
	
#EndRegion