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

// On the form, creates a hierarchical list with specified fields and a search bar.
// One or several collections of available data composition fields are used as a field source.
// You can expand reference type fields to include an unlimited number of levels.
// You can add and override a subfield list in any field of the list, including
// simple type fields.
// 
// Parameters:
//  Form - ClientApplicationForm - a form, in which the attribute is to be added.
//  Parameters - See ParametersForAddingAListOfFields
//
Procedure AddAListOfFieldsToTheForm(Form, Parameters) Export
	
	FormulasConstructorInternal.AddAListOfFieldsToTheForm(Form, Parameters);
	
EndProcedure

// The constructor of parameter the AddFieldsListToForm procedure parameters.
// 
// Returns:
//  Structure:
//   * LocationOfTheList - FormGroup
//                           - FormTable
//                           - ClientApplicationForm
//   * UseBackgroundSearch - Boolean
//   * NumberOfCharsToAllowSearching - Number   
//   * ListName - String
//   * FieldsCollections - Array of DataCompositionAvailableFields
//   * LocationOfTheSearchString - FormGroup
//                                 - FormTable
//                                 - ClientApplicationForm
//   * HintForEnteringTheSearchString - String
//   * ListHandlers - Structure
//   * IncludeGroupsInTheDataPath - Boolean
//   * IdentifierBrackets - Boolean
//   * ViewBrackets - Boolean
//   * SourcesOfAvailableFields - ValueTable - used when any field requires changing
//                                                 subordinate fields:
//     ** DataSource - String - field details of the field tree can be specified as a tree path
//                                  or metadata object name.
//                                  The source can be specified as a sample where the "*" character denotes multiple
//                                   arbitrary characters.
//                                  For example,
//                                  "*.Description" - add a field subcollection to the "Description" fields,
//                                  "Catalog.Companies" - add a field subcollection to all fields
//                                  of the Companies type.
//     ** FieldsCollection - DataCompositionAvailableFields - data source subfields.
//     ** Replace       - Boolean - if True, the subordinate field list will be replaced. If False it will be supplemented.
//   * UseIdentifiersForFormulas - Boolean
//   * PrimarySourceName - String - Name of the field source object name.
//
Function ParametersForAddingAListOfFields() Export
	
	Return FormulasConstructorInternal.ParametersForAddingAListOfFields();
	
EndFunction

// The constructor of field list for the AddFieldsListToForm procedure.
//
// Returns:
//  ValueTable:
//   * Id - String
//   * Presentation - String
//   * ValueType   - TypeDescription
//   * Picture   - String
//   * Order       - Number
//
Function FieldTable() Export
	
	Return FormulasConstructorInternal.FieldTable();
	
EndFunction

// The constructor of field list for the AddFieldsListToForm procedure.
//
// Returns:
//  ValueTree:
//   * Id - String
//   * Presentation - String
//   * ValueType   - TypeDescription
//   * IconName   - String
//   * Order       - Number
//
Function FieldTree() Export
	
	Return FormulasConstructorInternal.FieldTree();
	
EndFunction

// The constructor of field list for the AddFieldsListToForm procedure.
// Converts a source field collection to the collection of available data composition fields.
// 
// Parameters:
//   FieldSource   - See FieldTable
//                   - ValueTree - See FieldTree
//                   - DataCompositionSchema - A field list is taken from the "FilterAvailableFields" collection of the Settings Composer.
//                                             The collection name can be overridden in the "DCSCollectionName" parameter.
//                                             - String - The address of the value in the temporary storage.
//                   
//   NameOfTheSKDCollection - String - a field collection name in the Settings Composer. Use the parameter if
//                              a data composition schema is passed in the FieldSource parameter.
//                              The default value is FilterAvailableFields. 
//   
//  Returns:
//   DataCompositionAvailableFields
// 
Function FieldsCollection(FieldSource, Val NameOfTheSKDCollection = Undefined) Export
	
	Return FormulasConstructorInternal.FieldsCollection(FieldSource, , NameOfTheSKDCollection);
	
EndFunction

// Used when changing fields displayed in the list being connected.
// Refills the specified list from the passed field collection.
//
// Parameters:
//  Form - ClientApplicationForm
//  FieldsCollections - Array of DataCompositionAvailableFields
//  NameOfTheFieldList - String - on the form, a name of the list that requires field update.
//
Procedure UpdateFieldCollections(Form, FieldsCollections, NameOfTheFieldList = "AvailableFields") Export
	
	FormulasConstructorInternal.UpdateFieldCollections(Form, FieldsCollections, NameOfTheFieldList);
	
EndProcedure

// Handler of the event expanding the list being connected on the form.
//
// Parameters:
//  Form - ClientApplicationForm
//  FillParameters - Structure
//
Procedure FillInTheListOfAvailableFields(Form, FillParameters) Export
	
	FormulasConstructorInternal.FillInTheListOfAvailableFields(Form, FillParameters);
	
EndProcedure

// The handler of the event for changing the edit text of the search field of the list being connected.
//
// Parameters:
//  Form - ClientApplicationForm
//
Procedure PerformASearchInTheListOfFields(Form) Export
	
	FormulasConstructorInternal.PerformASearchInTheListOfFields(Form);
	
EndProcedure

// A universal handler in the client context.
// 
// Parameters:
//  Form - ClientApplicationForm
//  Parameter - Arbitrary
//  AdditionalParameters - See FormulasConstructorClient.HandlerParameters
//
Procedure FormulaEditorHandler(Form, Parameter, AdditionalParameters) Export
	FormulasConstructorInternal.FormulaEditorHandler(Form, Parameter, AdditionalParameters);
EndProcedure

// Prepares a standard list of required kind operators.
// 
// Parameters:
//  GroupsOfOperators - String - enumeration of required operator kinds. Possible values:
//                   Separators, Operators, LogicalOperatorsAndConstants,	
//                   NumericFunctions, StringFunctions, OtherFunctions,
//                   StringOperationsDCS, ComparisonOperationsDCS, LogicalOperationsDCS,
//                   AggregateFunctionsDCS, AllDCSOperators.
// 
// Returns:
//  ValueTree
//
Function ListOfOperators(GroupsOfOperators = Undefined) Export
	
	Return FormulasConstructorInternal.ListOfOperators(GroupsOfOperators);
	
EndFunction

// Generates a formula presentation in the current user language.
// Operands and operators in the formula text are replaced with their presentations.
//
// Parameters:
//  FormulaParameters - See FormulaEditingOptions
//  
// Returns:
//  String
//
Function FormulaPresentation(FormulaParameters) Export
	
	If Not ValueIsFilled(FormulaParameters.Formula) Then
		Return FormulaParameters.Formula;
	EndIf;
	
	DescriptionOfFieldLists = FormulasConstructorInternal.DescriptionOfFieldLists();
	
	SourcesOfAvailableFields = FormulasConstructorInternal.CollectionOfSourcesOfAvailableFields();
	SourceOfAvailableFields = SourcesOfAvailableFields.Add(); 
	SourceOfAvailableFields.FieldsCollection = FormulasConstructorInternal.FieldsCollection(FormulaParameters.Operands);
	
	DescriptionOfTheFieldList = DescriptionOfFieldLists.Add();
	DescriptionOfTheFieldList.SourcesOfAvailableFields = SourcesOfAvailableFields;
	DescriptionOfTheFieldList.ViewBrackets = True;
	
	SourcesOfAvailableFields = FormulasConstructorInternal.CollectionOfSourcesOfAvailableFields();
	SourceOfAvailableFields = SourcesOfAvailableFields.Add(); 
	SourceOfAvailableFields.FieldsCollection = FormulasConstructorInternal.FieldsCollection(FormulaParameters.Operators);
	
	DescriptionOfTheFieldList = DescriptionOfFieldLists.Add();
	DescriptionOfTheFieldList.SourcesOfAvailableFields = SourcesOfAvailableFields;
	
	Return FormulasConstructorInternal.RepresentationOfTheExpression(FormulaParameters.Formula, DescriptionOfFieldLists);
	
EndFunction

// Generates the formula representation in the user's language.
// Operators and operands are replaced with their presentations.
// For usage in forms with default operand lists, (See AddAListOfFieldsToTheForm)
// .
//
// Parameters:
//  Form - ClientApplicationForm
//  Formula - String
//  
// Returns:
//  String
//
Function ViewFormulaByFormData(Form, Formula) Export
	
	Return FormulasConstructorInternal.FormulaPresentation(Form, Formula);
	
EndFunction

// The FormulaParameters parameter constructor for the FormulaPresentation function.
// 
// Returns:
//  Structure:
//   * Formula - String
//   * Operands - String - The address of an operand collection in the temporary storage. Valid values are: 
//                         ValueTable - See FieldTable
//                         ValueTree - See FieldTree
//                         DataCompositionSchema - The operand list is taken from the "FilterAvailableFields" collection of the Settings Composer.
//                                                  You can override the collection name in the "DCSCollectionName" parameter.
//                                                  
//   * Operators - String - The address of an operator collection in the temporary storage. Valid values are: 
//                         ValueTable - See FieldTable
//                         ValueTree - See FieldTree
//                         DataCompositionSchema - The operand list is taken from the "FilterAvailableFields" collection of the Settings Composer.
//                                                  You can override the collection name in the "DCSCollectionName" parameter.
//                                                  
//   * OperandsDCSCollectionName  - String - a field collection name in the Settings Composer. Use the parameter
//                                          if a data composition schema is passed in the Operands parameter.
//                                          The default value is FilterAvailableFields.
//   * OperatorsDCSCollectionName - String - a field collection name in the Settings Composer. Use the parameter
//                                          if a data composition schema is passed in the Operators parameter.
//                                          The default value is FilterAvailableFields.
//   * Description - Undefined - the description is not used for the formula and the field is not available.
//                  - String       - a formula description. If it is filled in or empty, the field is displayed
//                                   on the constructor form.
//   * BracketsOperands - Boolean - Display operands in square brackets.
//
Function FormulaEditingOptions() Export
	
	Return FormulasConstructorClientServer.FormulaEditingOptions();
	
EndFunction

// Replaces operands' presentations with their IDs.
// 
// Parameters:
//  Form - ClientApplicationForm - Form that contains operand lists and operator lists.
//  FormulaPresentation - String - Formula.
//  
// Returns:
//  String
//
Function TheFormulaFromTheView(Form, FormulaPresentation) Export
	
	Return FormulasConstructorInternal.TheFormulaFromTheView(Form, FormulaPresentation);
	
EndFunction

#EndRegion
