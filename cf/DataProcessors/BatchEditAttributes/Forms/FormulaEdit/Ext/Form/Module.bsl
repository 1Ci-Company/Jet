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
	
	Formula         = Parameters.Formula;
	SourceFormula = Parameters.Formula;
	
	UsesOperandTree = Parameters.UsesOperandTree;
	
	Items.OperandsPagesGroup.CurrentPage = Items.NumericOperandsPage;
	Operands.Load(GetFromTempStorage(Parameters.Operands));
	For Each CurRow In Operands Do
		If CurRow.DeletionMark Then
			CurRow.PictureIndex = 3;
		Else
			CurRow.PictureIndex = 2;
		EndIf;
	EndDo;
	
	OperatorsTree = GetStandardOperatorsTree();
	ValueToFormAttribute(OperatorsTree, "Operators");
	
	If ValueIsFilled(Parameters.OperandsTitle) Then
		Items.OperandsGroup.Title = Parameters.OperandsTitle;
		Items.OperandsGroup.ToolTip = Parameters.OperandsTitle;
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	StandardProcessing = False;
	If Not Modified Or Not ValueIsFilled(SourceFormula) Or SourceFormula = Formula Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	ShowQueryBox(New NotifyDescription("BeforeCloseCompletion", ThisObject), NStr("en = 'The data has been changed. Do you want to save the changes?';"), QuestionDialogMode.YesNoCancel);
	
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	If Response = DialogReturnCode.Yes Then
		If CheckFormula(Formula, Operands()) Then
			Modified = False;
			Close(Formula);
		EndIf;
	ElsIf Response = DialogReturnCode.No Then
		Modified = False;
		Close(Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SettingsComposerSettingsChoiceAvailableChoiceFieldsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StringText = String(SettingsComposer.Settings.OrderAvailableFields.GetObjectByID(RowSelected).Field);
	Operand = ProcessOperandText(StringText);
	InsertTextIntoFormula(Operand);
	
EndProcedure

&AtClient
Procedure SettingsComposerDragStart(Item, DragParameters, Perform)
	
	ItemText = String(SettingsComposer.Settings.OrderAvailableFields.GetObjectByID(Items.SettingsComposer.CurrentRow).Field);
	DragParameters.Value = ProcessOperandText(ItemText);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperands

&AtClient
Procedure OperandsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name = "OperandsValue" Then
		Return;
	EndIf;
	
	If Item.CurrentData.DeletionMark Then
		StandardProcessing = False;
		
		ShowQueryBox(
			New NotifyDescription("OperandsSelectionCompletion", ThisObject), 
			NStr("en = 'Selected item is marked for deletion.
				|Continue?';"), 
			QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	StandardProcessing = False;
	InsertOperandIntoFormula();
	
EndProcedure

&AtClient
Procedure OperandsSelectionCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		InsertOperandIntoFormula();
	EndIf;

EndProcedure

&AtClient
Procedure OperandsDragStart(Item, DragParameters, StandardProcessing)
	
	DragParameters.Value = GetOperandTextToInsert(Item.CurrentData.Id);
	
EndProcedure

&AtClient
Procedure OperandsDragEnd(Item, DragParameters, StandardProcessing)
	
	If Item.CurrentData.DeletionMark Then
		ShowQueryBox(New NotifyDescription("OperandsDragEndCompletion", ThisObject),
			NStr("en = 'Selected item is marked for deletion.
			|Continue?';"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure OperandsDragEndCompletion(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	
	If Response = DialogReturnCode.No Then
		
		BeginningOfTheLine  = 0;
		BeginningOfTheColumn = 0;
		EndOfRow   = 0;
		EndOfColumn  = 0;
		
		Items.Formula.GetTextSelectionBounds(BeginningOfTheLine, BeginningOfTheColumn, EndOfRow, EndOfColumn);
		Items.Formula.SelectedText = "";
		Items.Formula.SetTextSelectionBounds(BeginningOfTheLine, BeginningOfTheColumn, BeginningOfTheLine, BeginningOfTheColumn);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OperandsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.OperandsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ParentRow = CurrentData.GetParent();
	If ParentRow = Undefined Then
		Return;
	EndIf;
	
	InsertTextIntoFormula(GetOperandTextToInsert(
		ParentRow.Id + "." + CurrentData.Id));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperandsTree

&AtClient
Procedure OperandsTreeDragStart(Item, DragParameters, Perform)
	
	If DragParameters.Value = Undefined Then
		Return;
	EndIf;
	
	TreeRow = OperandsTree.FindByID(DragParameters.Value);
	ParentRow = TreeRow.GetParent();
	If ParentRow = Undefined Then
		Perform = False;
		Return;
	Else
		DragParameters.Value = 
		   GetOperandTextToInsert(ParentRow.Id +"." + TreeRow.Id);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersOperators

&AtClient
Procedure OperatorsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	InsertOperatorIntoFormula();
	
EndProcedure

&AtClient
Procedure OperatorsDragStart(Item, DragParameters, StandardProcessing)
	
	If ValueIsFilled(Item.CurrentData.Operator) Then
		DragParameters.Value = Item.CurrentData.Operator;
	Else
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsDragEnd(Item, DragParameters, StandardProcessing)
	
	If Item.CurrentData.Operator = "Format(,)" Then
		RowFormat = New FormatStringWizard;
		RowFormat.Show(New NotifyDescription("OperatorsDragEndCompletion", ThisObject, New Structure("RowFormat", RowFormat)));
	EndIf;
	
EndProcedure

&AtClient
Procedure OperatorsDragEndCompletion(Text, AdditionalParameters) Export
	
	RowFormat = AdditionalParameters.RowFormat;
	
	
	If ValueIsFilled(RowFormat.Text) Then
		TextForInsert = "Format( , """ + RowFormat.Text + """)";
		Items.Formula.SelectedText = TextForInsert;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If CheckFormula(Formula, Operands()) Then
		Close(Formula);
	EndIf;
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	ClearMessages();
	CheckFormulaInteractive(Formula, Operands());
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure InsertTextIntoFormula(TextForInsert, Move = 0)
	
	RowStart = 0;
	RowEnd = 0;
	ColumnStart = 0;
	ColumnEnd = 0;
	
	Items.Formula.GetTextSelectionBounds(RowStart, ColumnStart, RowEnd, ColumnEnd);
	
	If (ColumnEnd = ColumnStart) And (ColumnEnd + StrLen(TextForInsert)) > Items.Formula.Width / 8 Then
		Items.Formula.SelectedText = "";
	EndIf;
		
	Items.Formula.SelectedText = TextForInsert;
	
	If Not Move = 0 Then
		Items.Formula.GetTextSelectionBounds(RowStart, ColumnStart, RowEnd, ColumnEnd);
		Items.Formula.SetTextSelectionBounds(RowStart, ColumnStart - Move, RowEnd, ColumnEnd - Move);
	EndIf;
		
	CurrentItem = Items.Formula;
	
EndProcedure

&AtClient
Procedure InsertOperandIntoFormula()
	
	InsertTextIntoFormula(GetOperandTextToInsert(Items.Operands.CurrentData.Id));
	
EndProcedure

&AtClient
Function Operands()
	
	Result = New Array();
	For Each Operand In Operands Do
		Result.Add(Operand.Id);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure InsertOperatorIntoFormula()
	
	If Items.Operators.CurrentData.Description = "Format" Then
		RowFormat = New FormatStringWizard;
		RowFormat.Show(New NotifyDescription("InsertOperatorIntoFormulaCompletion", ThisObject, New Structure("RowFormat", RowFormat)));
		Return;
	Else	
		InsertTextIntoFormula(Items.Operators.CurrentData.Operator, Items.Operators.CurrentData.Move);
	EndIf;
	
EndProcedure

&AtClient
Procedure InsertOperatorIntoFormulaCompletion(Text, AdditionalParameters) Export
	
	RowFormat = AdditionalParameters.RowFormat;
	
	If ValueIsFilled(RowFormat.Text) Then
		TextForInsert = "Format( , """ + RowFormat.Text + """)";
		InsertTextIntoFormula(TextForInsert, Items.Operators.CurrentData.Move);
	Else	
		InsertTextIntoFormula(Items.Operators.CurrentData.Operator, Items.Operators.CurrentData.Move);
	EndIf;
	
EndProcedure

&AtClient
Function ProcessOperandText(OperandText)
	
	StringText = OperandText;
	StringText = StrReplace(StringText, "[", "");
	StringText = StrReplace(StringText, "]", "");
	Operand = "[" + StrReplace(StringText, 
		?(PropertiesSet.SetOfProductProperties, "Products.", 
			?(Not PropertiesSet.Property("CharacteristicsPropertySet") Or PropertiesSet.CharacteristicsPropertySet, "ProductCharacteristic.", "ProductSeries.")), "") + "]";
	
	Return Operand
	
EndFunction

&AtServer
Function GetEmptyOperatorsTree()
	
	Tree = New ValueTree();
	Tree.Columns.Add("Description");
	Tree.Columns.Add("Operator");
	Tree.Columns.Add("Move", New TypeDescription("Number"));
	
	Return Tree;
	
EndFunction

&AtServer
Function AddOperatorsGroup(Tree, Description)
	
	NewFolder = Tree.Rows.Add();
	NewFolder.Description = Description;
	
	Return NewFolder;
	
EndFunction

&AtServer
Function AddOperator(Tree, Parent, Description, Operator = Undefined, Move = 0)
	
	NewRow = ?(Parent <> Undefined, Parent.Rows.Add(), Tree.Rows.Add());
	NewRow.Description = Description;
	NewRow.Operator = ?(ValueIsFilled(Operator), Operator, Description);
	NewRow.Move = Move;
	
	Return NewRow;
	
EndFunction

&AtServer
Function GetStandardOperatorsTree()
	
	Tree = GetEmptyOperatorsTree();
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'Separators';"));
	
	AddOperator(Tree, OperatorsGroup, "/", " + ""/"" + ");
	AddOperator(Tree, OperatorsGroup, "\", " + ""\"" + ");
	AddOperator(Tree, OperatorsGroup, "|", " + ""|"" + ");
	AddOperator(Tree, OperatorsGroup, "_", " + ""_"" + ");
	AddOperator(Tree, OperatorsGroup, ",", " + "", "" + ");
	AddOperator(Tree, OperatorsGroup, ".", " + "". "" + ");
	AddOperator(Tree, OperatorsGroup, NStr("en = 'Whitespace';"), " + "" "" + ");
	AddOperator(Tree, OperatorsGroup, "(", " + "" ("" + ");
	AddOperator(Tree, OperatorsGroup, ")", " + "") "" + ");
	AddOperator(Tree, OperatorsGroup, """", " + """""""" + ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'Operators';"));
	
	AddOperator(Tree, OperatorsGroup, "+", " + ");
	AddOperator(Tree, OperatorsGroup, "-", " - ");
	AddOperator(Tree, OperatorsGroup, "*", " * ");
	AddOperator(Tree, OperatorsGroup, "/", " / ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'Logical operators and constants';"));
	AddOperator(Tree, OperatorsGroup, "<", " < ");
	AddOperator(Tree, OperatorsGroup, ">", " > ");
	AddOperator(Tree, OperatorsGroup, "<=", " <= ");
	AddOperator(Tree, OperatorsGroup, ">=", " >= ");
	AddOperator(Tree, OperatorsGroup, "=", " = ");
	AddOperator(Tree, OperatorsGroup, "<>", " <> ");
	AddOperator(Tree, OperatorsGroup, "And",      " " + "And"      + " ");
	AddOperator(Tree, OperatorsGroup, "Or",    " " + "Or"    + " ");
	AddOperator(Tree, OperatorsGroup, "Not",     " " + "Not"     + " ");
	AddOperator(Tree, OperatorsGroup, "TRUE", " " + "TRUE" + " ");
	AddOperator(Tree, OperatorsGroup, "FALSE",   " " + "FALSE"   + " ");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'Numeric functions';"));
	
	AddOperator(Tree, OperatorsGroup, "Max", "Max(,)", 2);
	AddOperator(Tree, OperatorsGroup, "Min",  "Min(,)", 2);
	AddOperator(Tree, OperatorsGroup, "Round",  "Round(,)", 2);
	AddOperator(Tree, OperatorsGroup, "Int",  "Int()", 1);
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'String functions';"));
	
	AddOperator(Tree, OperatorsGroup, "String", "String()");
	AddOperator(Tree, OperatorsGroup, "Upper", "Upper()");
	AddOperator(Tree, OperatorsGroup, "Left", "Left()");
	AddOperator(Tree, OperatorsGroup, "Lower", "Lower()");
	AddOperator(Tree, OperatorsGroup, "Right", "Right()");
	AddOperator(Tree, OperatorsGroup, "TrimL", "TrimL()");
	AddOperator(Tree, OperatorsGroup, "TrimAll", "TrimAll()");
	AddOperator(Tree, OperatorsGroup, "TrimR", "TrimR()");
	AddOperator(Tree, OperatorsGroup, "Title", "Title()");
	AddOperator(Tree, OperatorsGroup, "StrReplace", "StrReplace(,,)");
	AddOperator(Tree, OperatorsGroup, "StrLen", "StrLen()");
	
	OperatorsGroup = AddOperatorsGroup(Tree, NStr("en = 'Other functions';"));
	
	AddOperator(Tree, OperatorsGroup, NStr("en = 'Condition';"), "?(,,)", 3);
	AddOperator(Tree, OperatorsGroup, "PredefinedValue", "PredefinedValue()");
	AddOperator(Tree, OperatorsGroup, "ValueIsFilled", "ValueIsFilled()");
	AddOperator(Tree, OperatorsGroup, "Format", "Format(,)");
	
	Return Tree;
	
EndFunction

&AtClientAtServerNoContext
Function GetOperandTextToInsert(Operand)
	
	Return "[" + Operand + "]";
	
EndFunction

&AtClient
Function CheckFormula(Formula, Operands)
	
	If Not ValueIsFilled(Formula) Then
		Return True;
	EndIf;
	
	ReplacementValue = """1""";
	
	CalculationText = Formula;
	For Each Operand In Operands Do
		CalculationText = StrReplace(CalculationText, GetOperandTextToInsert(Operand), ReplacementValue);
	EndDo;
	
	If StrStartsWith(TrimL(CalculationText), "=") Then
		CalculationText = Mid(TrimL(CalculationText), 2);
	EndIf;
	
	Try
		CalculationResult2 = Eval(CalculationText);
	Except
		ErrorText = NStr("en = 'Formula is invalid.
			|Formulas must comply with the syntax of 1C:Enterprise regular expressions.';");
		MessageToUser(ErrorText, , "Formula");
		Return False;
	EndTry;
	
	Return True;
	
EndFunction 

&AtClient
Procedure CheckFormulaInteractive(Formula, Operands)
	
	If ValueIsFilled(Formula) Then
		If CheckFormula(Formula, Operands) Then
			ShowUserNotification(
				NStr("en = 'Formula is valid.';"),
				,
				,
				PictureInformation32());
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function PictureInformation32()
	If SSLVersionMatchesRequirements() Then
		Return PictureLib["Information32"];
	Else
		Return New Picture;
	EndIf;
EndFunction

&AtServer
Function SSLVersionMatchesRequirements()
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.SSLVersionMatchesRequirements();
EndFunction

&AtClient
Procedure MessageToUser(Val MessageToUserText, Val Field = "", Val DataPath = "")
	Message = New UserMessage;
	Message.Text = MessageToUserText;
	Message.Field = Field;
	
	If Not IsBlankString(DataPath) Then
		Message.DataPath = DataPath;
	EndIf;
		
	Message.Message();
EndProcedure

#EndRegion
