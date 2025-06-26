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

	ForQuery = Parameters.ForQuery;
	BracketsOperands = Parameters.BracketsOperands;
	
	ParametersForAddingAListOfFields = FormulasConstructorInternal.ParametersForAddingAListOfFields();
	ParametersForAddingAListOfFields.ListName = NameOfTheListOfOperands();
	
	ParametersForAddingAListOfFields.FieldsCollections.Add(ReadTheListOfOperands());
	ParametersForAddingAListOfFields.LocationOfTheList = Items.AvailableFieldsGroup;
	ParametersForAddingAListOfFields.HintForEnteringTheSearchString = NStr("en = 'Find operand…';");
	ParametersForAddingAListOfFields.UseIdentifiersForFormulas = Not ForQuery;
	ParametersForAddingAListOfFields.ViewBrackets = BracketsOperands;
	ParametersForAddingAListOfFields.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
	ParametersForAddingAListOfFields.UseBackgroundSearch = True;
	FormulasConstructorInternal.AddAListOfFieldsToTheForm(ThisObject, ParametersForAddingAListOfFields);
	
	ParametersForAddingAListOfFields = FormulasConstructorInternal.ParametersForAddingAListOfFields();
	ParametersForAddingAListOfFields.ListName = NameOfTheListOfOperators();
	ParametersForAddingAListOfFields.FieldsCollections.Add(ListOfOperators());
	ParametersForAddingAListOfFields.LocationOfTheList = Items.OperatorsAndFunctionsGroup;
	ParametersForAddingAListOfFields.HintForEnteringTheSearchString = NStr("en = 'Find operator or function…';");
	ParametersForAddingAListOfFields.ViewBrackets = False;
	ParametersForAddingAListOfFields.ListHandlers.Insert("Selection", "Attachable_ListOfFieldsSelection");
	ParametersForAddingAListOfFields.ListHandlers.Insert("DragStart", "Attachable_OperatorsDragStart");
	ParametersForAddingAListOfFields.ListHandlers.Insert("DragEnd", "Attachable_OperatorsDragEnd");
	FormulasConstructorInternal.AddAListOfFieldsToTheForm(ThisObject, ParametersForAddingAListOfFields);
	
	FormulaPresentation = FormulasConstructorInternal.FormulaPresentation(ThisObject, Parameters.Formula);
	
	Items.Description.Visible = Parameters.Description <> Undefined;
	Description = Parameters.Description;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttributeListOfOperators = ThisObject[NameOfTheListOfOperators()];
	ItemOperatorsList = Items[NameOfTheListOfOperators()];
	ItemsOperators = AttributeListOfOperators.GetItems();
	If ItemsOperators.Count() > 0 Then
		ItemOperatorsList.Expand(ItemsOperators[0].GetID());	
	EndIf;	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("ConfirmAndClose", ThisObject);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit);
	
	If Modified Or Exit Then
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)

	If Not Items.Description.Visible Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("Description");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CompleteEditing(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFormula(Command)
	
	ExecuteCheck();
	ShowMessageBox(, NStr("en = 'Check succeeded.';"));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	CloseForm();
	
EndProcedure

&AtClient
Procedure CloseForm()

	ExecuteCheck();
	Modified = False;
	Close(FormulaDescription());
	
EndProcedure

&AtServer
Function ReadTheListOfOperands()
	
	ListOfOperands = Parameters.Operands;
	If IsTempStorageURL(ListOfOperands) Then
		ListOfOperands = GetFromTempStorage(ListOfOperands);
	EndIf;
	
	If ListOfOperands = Undefined Then
		ListOfOperands = FormulasConstructorInternal.FieldTable();
	EndIf;
	
	SettingsComposer = FormulasConstructorInternal.FieldSourceSettingsLinker(ListOfOperands);
	
	Return FormulasConstructorInternal.FieldsCollection(ListOfOperands, , Parameters.OperandsDCSCollectionName);
	
EndFunction

&AtClient
Function FormulaDescription()
	
	FormulaDescription = New Structure;
	FormulaDescription.Insert("Formula", TheFormulaFromTheView());
	FormulaDescription.Insert("FormulaPresentation", FormulaPresentation);
	If Items.Description.Visible Then
		FormulaDescription.Insert("Description", Description);
	EndIf;
	
	Return FormulaDescription;
	
EndFunction

&AtServer
Function TheFormulaFromTheView()
	
	Return FormulasConstructorInternal.TheFormulaFromTheView(ThisObject, FormulaPresentation, Not ForQuery);
	
EndFunction

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
Procedure Attachable_FillInTheListOfAvailableFields(FillParameters) Export // ACC:78 - Called from FormulaConstructorClient.
	
	FillInTheListOfAvailableFields(FillParameters);
	
EndProcedure

&AtServer
Procedure FillInTheListOfAvailableFields(FillParameters)
	
	FormulasConstructorInternal.FillInTheListOfAvailableFields(ThisObject, FillParameters);
	
EndProcedure

&AtClient
Procedure Attachable_ListOfFieldsStartDragging(Item, DragParameters, Perform)
	
	FormulasConstructorClient.ListOfFieldsStartDragging(ThisObject, Item, DragParameters, Perform);
	
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

&AtClient
Procedure Attachable_StartSearchInFieldsList()

	FormulasConstructorClient.StartSearchInFieldsList(ThisObject);
	
EndProcedure

&AtServer
Procedure Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters)
	FormulasConstructor.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
EndProcedure

&AtClient
Procedure Attachable_FormulaEditorHandlerClient(Parameter, AdditionalParameters = Undefined) Export // ACC:78 - The procedure is called from "FormulaConstructorClient.StartSearchInFieldsList".
	FormulasConstructorClient.FormulaEditorHandler(ThisObject, Parameter, AdditionalParameters);
	If AdditionalParameters.RunAtServer Then
		Attachable_FormulaEditorHandlerServer(Parameter, AdditionalParameters);
	EndIf;
EndProcedure

#EndRegion

#Region AdditionalHandlersForConnectedLists

// Parameters:
//  Item - FormTable
//
&AtClient
Procedure Attachable_ListOfFieldsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	SelectedField = FormulasConstructorClient.TheSelectedFieldInTheFieldList(ThisObject);
	If Item.Name = NameOfTheListOfOperands() Then
		FormulaPresentation = TrimR(FormulaPresentation) + " [" + SelectedField.RepresentationOfTheDataPath + "]";
	Else
		FormulaPresentation = TrimR(FormulaPresentation) + " " + ExpressionToInsert(SelectedField);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OperatorsDragStart(Item, DragParameters, Perform)
	
	Operator = FormulasConstructorClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators());
	DragParameters.Value = ExpressionToInsert(Operator);
	
EndProcedure

&AtClient
Procedure Attachable_OperatorsDragEnd(Item, DragParameters, StandardProcessing)
	
	If FormulasConstructorClient.TheSelectedFieldInTheFieldList(ThisObject, NameOfTheListOfOperators()).DataPath = "Format" Then
		RowFormat = New FormatStringWizard;
		RowFormat.Show(New NotifyDescription("OperatorsDragEndCompletion", ThisObject, New Structure("RowFormat", RowFormat)));
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsDragEndCompletion(Text, AdditionalParameters) Export
	
	RowFormat = AdditionalParameters.RowFormat;
	
	If ValueIsFilled(RowFormat.Text) Then
		TextForInsert = "Format( , """ + RowFormat.Text + """)";
		Items.FormulaPresentation.SelectedText = TextForInsert;
	EndIf;
	
EndProcedure

#EndRegion

&AtClientAtServerNoContext
Function NameOfTheListOfOperands()
	
	Return "ListOfOperands";
	
EndFunction

&AtClientAtServerNoContext
Function NameOfTheListOfOperators()
	
	Return "ListOfOperators";
	
EndFunction

&AtServer
Function ListOfOperators()
	
	ListOfOperators = Parameters.Operators;
	If Not ValueIsFilled(ListOfOperators) Then
		ListOfOperators = FormulasConstructorInternal.ListOfOperators(?(ForQuery, "AllSKDOperators", Undefined));
	EndIf;
	
	Return FormulasConstructorInternal.FieldsCollection(ListOfOperators, , Parameters.OperatorsDCSCollectionName);
	
EndFunction

&AtClient
Function ExpressionToInsert(Operator)
	
	Return FormulasConstructorClient.ExpressionToInsert(Operator);
	
EndFunction

&AtServer
Function ExpressionToCheck()
	
	Return FormulasConstructorInternal.ExpressionToCheck(ThisObject, FormulaPresentation, NameOfTheListOfOperands());
	
EndFunction

&AtServer
Procedure CheckTheExpressionForTheRequest()
	
	Expression = FormulasConstructorInternal.TheFormulaFromTheView(ThisObject, FormulaPresentation, False);
	Field = SettingsComposer.Settings.UserFields.Items.Add(Type("DataCompositionUserFieldExpression"));
	
	Try
		Field.SetDetailRecordExpression(Expression);
	Except
		Raise ErrorProcessing.BriefErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtClient
Procedure ExecuteCheck()
	
	If ForQuery Then
		Try
			CheckTheExpressionForTheRequest();
		Except
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			Raise TheTextOfTheErrorMessageWhenCheckingTheFormula(ErrorText);
		EndTry;
	Else
		Expression = ExpressionToCheck();
		Try
			Result = Eval(Expression);
		Except
			ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			Raise TheTextOfTheErrorMessageWhenCheckingTheFormula(ErrorText);
		EndTry;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function TheTextOfTheErrorMessageWhenCheckingTheFormula(ErrorText)
	
	MessageTemplate = NStr("en = 'The entered formula is incorrect:
	|%1';");
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		MessageTemplate, ErrorText);
		
	Return MessageText;
	
EndFunction

#EndRegion
