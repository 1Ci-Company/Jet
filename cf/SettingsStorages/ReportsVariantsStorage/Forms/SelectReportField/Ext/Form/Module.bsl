///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CloseOnChoice = False; 
	Initialize();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersAvailableFields

#Region PlugInListOfFields

&AtClient
Procedure Attachable_ListOfFieldsBeforeExpanding(Item, String, Cancel)
	
	FormulasConstructorClient.ListOfFieldsBeforeExpanding(ThisObject, Item, String, Cancel);
	
EndProcedure

&AtClient
Procedure Attachable_ExpandTheCurrentFieldListItem()
	
	FormulasConstructorClient.ExpandTheCurrentFieldListItem(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_FillInTheListOfAvailableFields(FillParameters) Export // ACC:78 The procedure is called from common module FormulaConstructorClient.
	
	FillInTheListOfAvailableFields(FillParameters);
	
EndProcedure

&AtServer
Procedure FillInTheListOfAvailableFields(FillParameters)
	
	FormulasConstructor.FillInTheListOfAvailableFields(ThisObject, FillParameters);
	
EndProcedure

&AtClient
Procedure Attachable_ListOfFieldsSelection(Item, RowSelected, Field, StandardProcessing)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure Attachable_ListOfFieldsStartDragging(Item, DragParameters, Perform)
	
	FormulasConstructorClient.ListOfFieldsStartDragging(ThisObject, Item, DragParameters, Perform);
	
EndProcedure

&AtClient
Procedure APlugInListOfFieldsWhenActivatingALine(Item)
	
	AttachIdleHandler("HideUnusedCommands", 0.1, True);
	
EndProcedure

&AtClient
Procedure HideUnusedCommands()
	
	NamesOfFormulaEditingCommands = NamesOfFormulaEditingCommands();
	ExceptionCommandName = "AddFormula";
	
	FormulaEditingCommands = New Array;
	
	For Each Item In Items.AvailableFieldsContextMenu.ChildItems Do // 
		
		Item.Visible = TypeOf(Item) = Type("FormButton")
			And NamesOfFormulaEditingCommands.Find(Item.CommandName) <> Undefined;
		
		If Item.Visible And Item.CommandName <> ExceptionCommandName Then 
			FormulaEditingCommands.Add(Item);
		EndIf;
		
	EndDo;
	
	For Each CommandName In NamesOfFormulaEditingCommands Do 
		
		Item = Items.Find(CommandName);
		
		If Item <> Undefined And Item.CommandName <> ExceptionCommandName Then 
			FormulaEditingCommands.Add(Item);
		EndIf;
		
	EndDo;
	
	ListBox = ListOfAvailableFields(ThisObject).Field;
	FormulaEditingIsAvailable = FormulaEditingIsAvailable(ListBox.CurrentData);
	
	For Each Item In FormulaEditingCommands Do 
		Item.Enabled = FormulaEditingIsAvailable;
	EndDo;
	
EndProcedure

&AtClient
Procedure Attachable_SearchStringEditTextChange(Item, Text, StandardProcessing)
	
	FormulasConstructorClient.SearchStringEditTextChange(ThisObject, Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_PerformASearchInTheListOfFields()

	PerformASearchInTheListOfFields();
	
EndProcedure

&AtServer
Procedure PerformASearchInTheListOfFields()
	
	FormulasConstructor.PerformASearchInTheListOfFields(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SearchStringClearing(Item, StandardProcessing)
	
	FormulasConstructorClient.SearchStringClearing(ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtServer
Procedure Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters)
	FormulasConstructor.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
EndProcedure

&AtClient
Procedure Attachable_FormulaEditorHandlerClient(Parameter, AdditionalParameters = Undefined) Export // ACC:78 - Procedure is called from FormulaConstructorClient.StartSearchInFieldsList. 
	FormulasConstructorClient.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
	If AdditionalParameters.RunAtServer Then
		Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters);
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_StartSearchInFieldsList()

	FormulasConstructorClient.StartSearchInFieldsList(ThisObject);
	
EndProcedure

#EndRegion

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure AddFormula(Command)
	
	ActivateAGroupOfFormulas(False);
	
	FormulaEditingOptions = FormulasConstructorClient.FormulaEditingOptions();
	FormulaEditingOptions.Operands = ReportSettings.SchemaURL;
	FormulaEditingOptions.OperandsDCSCollectionName = FieldsCollectionName;
	FormulaEditingOptions.Description = NewFieldDescr();
	FormulaEditingOptions.ForQuery = True;
	
	Handler = New NotifyDescription("AfterAddingTheFormula", ThisObject);
	FormulasConstructorClient.StartEditingTheFormula(FormulaEditingOptions, Handler);
	
EndProcedure

&AtClient
Procedure ChangeFormula(Command)
	
	ListBox = ListOfAvailableFields(ThisObject).Field;
	String = ListBox.CurrentData;
	
	If Not FormulaEditingIsAvailable(String) Then 
		Return;
	EndIf;
	
	ReportsOptionsInternalClient.ChangeFormula(
		ThisObject, SettingsComposer.Settings, String.DataPath, FieldsCollectionName);
	
EndProcedure

// Parameters:
//  FormulaDescription - DataCompositionAvailableField
//                  - Structure:
//                      * Formula - String
//                      * FormulaPresentation - String
//                      * Description - String
//  Formula - Structure:
//    * Formula - DataCompositionUserFieldExpression
//    * FieldsCollection - DataCompositionAvailableFields
//  
&AtClient
Procedure AfterChangingTheFormula(FormulaDescription, Formula) Export 
	
	If TypeOf(FormulaDescription) <> Type("Structure") Then 
		Return;
	EndIf;
	
	ReportsOptionsInternalClient.AfterChangingTheFormula(FormulaDescription, Formula);
	
	List = Items.Find("AvailableFields");
	
	If List = Undefined Then
		Return;
	EndIf;
	
	String = List.CurrentData;
	
	If String <> Undefined Then 
		String.Title = FormulaDescription.Title;
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteFormula(Command)
	
	ListBox = ListOfAvailableFields(ThisObject).Field;
	String = ListBox.CurrentData;
	
	If Not FormulaEditingIsAvailable(String) Then 
		Return;
	EndIf;
	
	Formulae = SettingsComposer.Settings.UserFields.Items;
	Formula = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(SettingsComposer.Settings, String.DataPath);
	Formulae.Delete(Formula);
	
	UpdateFieldCollections();	
	ActivateAGroupOfFormulas();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure Initialize()
	
	SettingsComposer = Parameters.SettingsComposer;
	Mode = Parameters.Mode;
	ReportSettings = Parameters.ReportSettings;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
	
	SetTheCollectionName();
	SetTheIDOfTheSettingsStructureElement();
	InitializeTheListOfAvailableFields();
	ActivateTheAvailableField();
	
EndProcedure

&AtServer
Procedure SetTheCollectionName()
	
	Modes = New Map;
	Modes.Insert("Filters", "FilterAvailableFields");
	Modes.Insert("SelectedFields", "SelectionAvailableFields");
	Modes.Insert("Sort", "OrderAvailableFields");
	Modes.Insert("GroupFields", "GroupAvailableFields");
	Modes.Insert("GroupingComposition", "GroupAvailableFields");
	Modes.Insert("OptionStructure", "GroupAvailableFields");
	Modes.Insert("AppearanceFields", "ConditionalAppearance.FieldsAvailableFields");
	Modes.Insert("TermsOfRegistration", "ConditionalAppearance.FilterAvailableFields");
	
	FieldsCollectionName = Modes[Mode];
	
	If FieldsCollectionName = Undefined Then		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Mode parameter contains invalid value: %1.';"), String(Mode));		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetTheIDOfTheSettingsStructureElement()
	
	SettingsStructureItemID = CommonClientServer.StructureProperty(
		Parameters, "SettingsStructureItemID");
	
	If SettingsStructureItemID = Undefined Then
		Return;
	EndIf;
	
	SettingsStructureItem = SettingsComposer.Settings.GetObjectByID(SettingsStructureItemID);
	
	If TypeOf(SettingsStructureItem) = Type("DataCompositionTableStructureItemCollection")
		Or TypeOf(SettingsStructureItem) = Type("DataCompositionChartStructureItemCollection")
		Or TypeOf(SettingsStructureItem) = Type("DataCompositionTable")
		Or TypeOf(SettingsStructureItem) = Type("DataCompositionChart") Then
		
		SettingsStructureItemID = Undefined;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeTheListOfAvailableFields()
	
	// FormulasConstructor
	
	ParametersForAddingAListOfFields = FormulasConstructor.ParametersForAddingAListOfFields();
	ParametersForAddingAListOfFields.LocationOfTheList = LocationOfTheList(Items);
	
	ParametersForAddingAListOfFields.FieldsCollections = FieldsCollections();
	
	ParametersForAddingAListOfFields.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
	ParametersForAddingAListOfFields.ListHandlers.Insert("OnActivateRow", "APlugInListOfFieldsWhenActivatingALine");
	ParametersForAddingAListOfFields.UseBackgroundSearch = True;
	
	FormulasConstructor.AddAListOfFieldsToTheForm(ThisObject, ParametersForAddingAListOfFields);
	
	// End FormulasConstructor
	
	AddFormulaEditingCommandsToTheContextMenu();
	
EndProcedure

&AtServer
Procedure AddFormulaEditingCommandsToTheContextMenu()
	
	ListBox = ListOfAvailableFields(ThisObject).Field;
	
	NameOfTheFormulaEditingCommandPanel = "FormulaEditingCommands";
	NamesOfFormulaEditingCommands = NamesOfFormulaEditingCommands();
	
	For Each CommandName In NamesOfFormulaEditingCommands Do 
		
		ButtonName = "ContextMenu" + NameOfTheFormulaEditingCommandPanel + CommandName;
		Button = Items.Add(ButtonName, Type("FormButton"), ListBox.ContextMenu);
		Button.CommandName = CommandName;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ActivateTheAvailableField()
	
	Field = CommonClientServer.StructureProperty(Parameters, "DCField");
	
	If Field = Undefined Then
		Return;
	EndIf;
	
	FieldsCollection = FieldsCollection(ThisObject);
	AvailableField = FieldsCollection.FindField(Field);
	If AvailableField = Undefined Then
		Return;
	EndIf;
	
	FieldOfAvailableFields = Items.AvailableFields; // ACC:275 - Items are generated programmatically.
	DataOfAvailableFields = ThisObject[FieldOfAvailableFields.DataPath].GetItems();
	For Each ListLine In DataOfAvailableFields Do 
		If ListLine.Field = Field Then 
			FieldOfAvailableFields.CurrentRow = ListLine.GetID();
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectAndClose()
	
	ClearMessages();
	ListBox = ListOfAvailableFields(ThisObject).Field;
	If TypeOf(ListBox.CurrentData) = Type("FormDataTreeItem") And ListBox.CurrentData.Folder Then
		CommonClient.MessageToUser(NStr("en = 'Select a report field, not a group.';"));
		Return;
	ElsIf TypeOf(ListBox.CurrentData) <> Type("FormDataTreeItem") Then
		CommonClient.MessageToUser(NStr("en = 'Select a report field.';"));
		Return;
	EndIf;
	
	SelectedField = FormulasConstructorClient.TheSelectedFieldInTheFieldList(ThisObject);
	
	AvailableField = Undefined;
	Parent = SelectedField.Parent; // See FormulasConstructorClient.TheSelectedFieldInTheFieldList

	If Parent <> Undefined
		And Parent.Name = IDOfTheFormulaGroup() Then 
		
		AvailableField = ReportsOptionsInternalClientServer.TheFormulaOnTheDataPath(
			SettingsComposer.Settings, SelectedField.DataPath);
			
		If TypeOf(AvailableField) <> Type("DataCompositionUserFieldExpression") Then
			AvailableField = Undefined;
		EndIf;
		
	ElsIf FieldsCollectionName = "GroupAvailableFields"
		And SelectedField.Name = "DetailedRecords" Then
		
		AvailableField = "<>";
		
	EndIf;
	
	If AvailableField = Undefined Then
		
		FieldsCollection = FieldsCollection(ThisObject);
		Field = New DataCompositionField(SelectedField.DataPath);
		AvailableField = FieldsCollection.FindField(Field);
		
	EndIf;
	
	NotifyChoice(AvailableField);
	Close(AvailableField);
	
EndProcedure

&AtClient
Procedure AfterAddingTheFormula(FormulaDescription, AdditionalParameters) Export 
	
	If TypeOf(FormulaDescription) <> Type("Structure")
		Or Not FormulaDescription.Property("Formula") Then 
		
		Return;
	EndIf;
	
	ReportsOptionsInternalClient.AddFormula(SettingsComposer.Settings, FieldsCollection(ThisObject), FormulaDescription);
	UpdateFieldCollections();
	ActivateAGroupOfFormulas();
	
EndProcedure

&AtServer
Procedure UpdateFieldCollections()
	
	FormulasConstructor.UpdateFieldCollections(ThisObject, FieldsCollections());
	
EndProcedure

&AtClient
Function NewFieldDescr()
	
	FieldHeaders = New Map;
	
	UserFields =  SettingsComposer.Settings.SelectionAvailableFields.Items.Find(New DataCompositionField("UserFields"));
	If UserFields = Undefined Then
		Return NStr("en = 'Field 1';");
	EndIf;
	
	For Each Field In UserFields.Items Do
		FieldHeaders.Insert(Field.Title, True);
	EndDo;

	For FieldNumber = 1 To 100 Do
		FieldDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Field %1';"), FieldNumber);
		If FieldHeaders[FieldDescription] = Undefined Then
			Return FieldDescription;
		EndIf;
	EndDo;
	
	Return NStr("en = 'Field';");
	
EndFunction

#Region Common

&AtClientAtServerNoContext
Function LocationOfTheList(Items)
	
	Return Items.AvailableFieldsGroup;
	
EndFunction

// Parameters:
//  Form - ClientApplicationForm
//
// Returns:
//  Structure:
//    * Field - FormTable:
//        ** Name - String
//        ** Title - String
//        ** Field - TypeDescription
//        ** DataPath - String
//        ** RepresentationOfTheDataPath - String
//        ** Type - TypeDescription
//        ** Picture - Picture
//        ** Folder - Boolean
//        ** Table - Boolean
//        ** YourOwnSetOfFields - Boolean 
//        ** Indent - String
//        ** MatchesFilter - Boolean
//        ** TheSubordinateElementCorrespondsToTheSelection - Boolean
//    * Data - FormDataTree:
//        ** Name - String
//        ** Title - String
//        ** Field - TypeDescription
//        ** DataPath - String
//        ** RepresentationOfTheDataPath - String
//        ** Type - TypeDescription
//        ** Picture - Picture
//        ** Folder - Boolean
//        ** Table - Boolean
//        ** YourOwnSetOfFields - Boolean 
//        ** Indent - String
//        ** MatchesFilter - Boolean
//        ** TheSubordinateElementCorrespondsToTheSelection - Boolean
//
&AtClientAtServerNoContext
Function ListOfAvailableFields(Form)
	
	ListOfAvailableFields = New Structure("Field, Data");
	LocationOfTheList = LocationOfTheList(Form.Items);
	For Each Item In LocationOfTheList.ChildItems Do 
		
		If TypeOf(Item) = Type("FormTable") Then 
			ListOfAvailableFields.Field = Item;
			ListOfAvailableFields.Data = Form[Item.Name];
			Break;
		EndIf;
		
	EndDo;
	
	Return ListOfAvailableFields;
	
EndFunction

&AtClientAtServerNoContext
Function IDOfTheFormulaGroup()
	
	Return "UserFields";
	
EndFunction

&AtClientAtServerNoContext
Function NamesOfFormulaEditingCommands()
	
	Return StrSplit("AddFormula, ChangeFormula, DeleteFormula", ", ", False);
	
EndFunction

// Parameters:
//  SelectedField - 
// 
// Returns:
//  Boolean
//
&AtClientAtServerNoContext
Function FormulaEditingIsAvailable(SelectedField)
	
	If TypeOf(SelectedField) <> Type("FormDataTreeItem") Then 
		Return False;
	EndIf;
	
	Parent = SelectedField.GetParent();
	
	Return Parent <> Undefined And Parent.Name = IDOfTheFormulaGroup();
	
EndFunction

&AtClientAtServerNoContext
Function FieldsCollection(Form)
	
	Settings = Form.SettingsComposer.Settings;
	If Form.FieldsCollectionName = "GroupAvailableFields" Then
		
		If Form.SettingsStructureItemID = Undefined Then
			SettingsStructureItem = Settings;
		Else
			SettingsStructureItem = Settings.GetObjectByID(
				Form.SettingsStructureItemID);
		EndIf;
		
		If TypeOf(SettingsStructureItem) = Type("DataCompositionSettings") Then
			Return SettingsStructureItem.GroupAvailableFields;
		Else
			Return SettingsStructureItem.GroupFields.GroupFieldsAvailableFields;
		EndIf;
		
	ElsIf StrFind(Form.FieldsCollectionName, ".") > 0 Then 
		
		DescriptionOfTheFieldCollectionName = StrSplit(Form.FieldsCollectionName, ".");
		FieldsCollection = Settings;
		For Each Item In DescriptionOfTheFieldCollectionName Do 
			FieldsCollection = FieldsCollection[Item];
		EndDo;
		Return FieldsCollection;
		
	EndIf;
	
	Return Settings[Form.FieldsCollectionName];
	
EndFunction

&AtServer
Function FieldsCollections()
	
	FieldsCollections = New Array;
	FieldsCollections.Add(FieldsCollection(ThisObject));
	
	If SettingsComposer.Settings.UserFields.Items.Count() = 0 Then
		FieldsCollections.Add(AdditionalFieldOfTheFormulaGroup());
	EndIf;
	
	If Mode = "OptionStructure" Then
		FieldsCollections.Add(AdditionalFieldOfDetailedRecords());
	EndIf;
	
	Return FieldsCollections;
	
EndFunction

&AtServer
Function AdditionalFieldOfTheFormulaGroup()
	
	FieldTable = FormulasConstructor.FieldTable();
	Field = FieldTable.Add();
	Field.Id = IDOfTheFormulaGroup();
	Field.Presentation = NStr("en = 'Formulas';");
	Field.Order = 99;
	
	Return FormulasConstructor.FieldsCollection(FieldTable);
	
EndFunction

&AtServer
Function AdditionalFieldOfDetailedRecords()
	
	FieldTable = FormulasConstructor.FieldTable();
	Field = FieldTable.Add();
	Field.Id = "DetailedRecords";
	Field.Presentation = NStr("en = '<Detailed records>';");
	
	Return FormulasConstructor.FieldsCollection(FieldTable);
	
EndFunction

&AtClient
Function GroupOfFormulas()
	
	List = ListOfAvailableFields(ThisObject).Data;
	Rows = List.GetItems();
	
	IndexOf = Rows.Count() - 1;
	
	While IndexOf >= 0 Do 
		
		String = Rows[IndexOf];
		
		If String.Name = IDOfTheFormulaGroup() Then 
			Return String;
		EndIf;
		
		IndexOf = IndexOf - 1;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure ActivateAGroupOfFormulas(ExpandFormulas = True)
	
	GroupOfFormulas = GroupOfFormulas();
	
	ListBox = ListOfAvailableFields(ThisObject).Field;
	ListBox.CurrentRow = GroupOfFormulas.GetID();
	
	CurrentItem = ListBox;
	
	If ExpandFormulas Then 
		ListBox.Expand(GroupOfFormulas.GetID());
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion