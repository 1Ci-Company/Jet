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
	
	Var_Key = "";
	For Each Warning In Parameters.Warnings Do
		Var_Key = Var_Key + Warning.ActionIfFlagSet.Form + Warning.ActionOnClickHyperlink.Form;
	EndDo;
	
	WindowOptionsKey = "ExitWarnings" + Common.CheckSumString(Var_Key);
	
	InitializeItemsInForm(Parameters.Warnings);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Parameters:
//  Item - FormDecoration
//
&AtClient
Procedure Attachable_HyperlinkClick(Item)
	TagName = Item.Name;
	
	For Each QuestionRow In ItemsAndParameters Do
		QuestionParameters = New Structure("Name, Form, FormParameters");
		
		FillPropertyValues(QuestionParameters, QuestionRow.Value);
		If TagName = QuestionParameters.Name Then 
			
			If QuestionParameters.Form <> Undefined Then
				OpenForm(QuestionParameters.Form, QuestionParameters.FormParameters, ThisObject);
			EndIf;
			
			Break;
		EndIf;
	EndDo;
	
EndProcedure

// Parameters:
//  Item - FormDecoration
//
&AtClient
Procedure Attachable_CheckBoxOnChange(Item)
	
	TagName      = Item.Name;
	FoundItem = Items.Find(TagName);
	
	If FoundItem = Undefined Then 
		Return;
	EndIf;
	
	ElementValue = ThisObject[TagName];
	If TypeOf(ElementValue) <> Type("Boolean") Then
		Return;
	EndIf;

	ArrayID = TaskArrayIDByName(TagName);
	If ArrayID = Undefined Then 
		Return;
	EndIf;
	
	ArrayElement = TasksToRunAfterClose.FindByID(ArrayID);
	
	Use = Undefined;
	If ArrayElement.Value.Property("Use", Use) Then 
		If TypeOf(Use) = Type("Boolean") Then 
			ArrayElement.Value.Use = ElementValue;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ExitApp(Command)
	
	ExecuteTasksOnClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close(True);
	
EndProcedure

#EndRegion

#Region Private

// Creates form items based on questions passed to a user.
//
// Parameters:
//     Questions - Array - Structures containing the question value parameters.
//                        See StandardSubsystems.Core\BeforeExit.
//
&AtServer
Procedure InitializeItemsInForm(Val Warnings)
	
	For Each CurrentWarning In WarningTable(Warnings) Do 
		
		// Adding the item to the form only if either a flag text or a hyperlink text is specified, but not both at the same time.
		RefRequired = Not IsBlankString(CurrentWarning.HyperlinkText);
		FlagRequired   = Not IsBlankString(CurrentWarning.CheckBoxText);
		
		If RefRequired And FlagRequired Then
			Continue;
			
		ElsIf RefRequired Then
			CreateHyperlinkInForm(CurrentWarning);
			
		ElsIf FlagRequired Then
			CreateCheckBoxInForm(CurrentWarning);
			
		EndIf;
		
	EndDo;
	
	// Footer.
	LabelText = NStr("en = 'Exit the app?';");
	
	LabelName    = FindLabelNameInForm("QuestionLabel1");
	LabelGroup = GenerateFormItemGroup();
	
	InformationTextItem = Items.Add(LabelName, Type("FormDecoration"), LabelGroup);
	InformationTextItem.VerticalAlign = ItemVerticalAlign.Bottom;
	InformationTextItem.Title             = LabelText;
	InformationTextItem.Height                = 2;
	
EndProcedure

&AtServer
Function WarningTable(Val Warnings)
	
	Result = New ValueTable;
	Result.Columns.Add("NoteText");
	Result.Columns.Add("CheckBoxText");
	Result.Columns.Add("ActionIfFlagSet");
	Result.Columns.Add("HyperlinkText");
	Result.Columns.Add("ActionOnClickHyperlink");
	Result.Columns.Add("Priority");
	Result.Columns.Add("OutputSingleWarning");
	Result.Columns.Add("ExtendedTooltip");
	
	SingleWarnings = New Array;
	
	For Each WarningItem In Warnings Do
		TableRow = Result.Add();
		FillPropertyValues(TableRow, WarningItem);
		
		If TableRow.OutputSingleWarning = True Then
			SingleWarnings.Add(TableRow);
		EndIf;
	EndDo;
	
	// Clear all warnings if at least one warning needs to be cleared (OutputSingleWarning = True).
	If SingleWarnings.Count() > 0 Then
		Result = Result.Copy(SingleWarnings);
	EndIf;
	
	// The higher the priority the higher the position of the warning in the list.
	Result.Sort("Priority DESC");
	
	Return Result;
EndFunction

&AtServer
Function GenerateFormItemGroup()
	
	GroupName = FindLabelNameInForm("GroupOnForm");
	
	Var_Group = Items.Add(GroupName, Type("FormGroup"), Items.MainGroup);
	Var_Group.Type = FormGroupType.UsualGroup;
	
	Var_Group.HorizontalStretch = True;
	Var_Group.ShowTitle      = False;
	Var_Group.Representation              = UsualGroupRepresentation.None;
	
	Return Var_Group; 
	
EndFunction

&AtServer
Procedure CreateHyperlinkInForm(QuestionStructure)
	
	Var_Group = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.NoteText) Then 
		LabelName = FindLabelNameInForm("QuestionLabel1");
		LabelType = Type("FormDecoration");
		
		LabelParent = Var_Group;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.NoteText;
	EndIf;
	
	If IsBlankString(QuestionStructure.HyperlinkText) Then
		Return;
	EndIf;
	
	// Generate a hyperlink.
	HyperlinkName = FindLabelNameInForm("QuestionLabel1");
	HyperlinkType = Type("FormDecoration");
	
	HyperlinkParent = Var_Group;

	HyperlinkItem = Items.Add(HyperlinkName, HyperlinkType, HyperlinkParent);
	HyperlinkItem.Hyperlink = True;
	HyperlinkItem.Title   = QuestionStructure.HyperlinkText;
	HyperlinkItem.SetAction("Click", "Attachable_HyperlinkClick");
	
	SetExtendedTooltip(HyperlinkItem, QuestionStructure);
	
	DataProcessorStructure = QuestionStructure.ActionOnClickHyperlink;
	If IsBlankString(DataProcessorStructure.Form) Then
		Return;
	EndIf;
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", HyperlinkName);
	FormOpenParameters.Insert("Form", DataProcessorStructure.Form);
	
	FormParameters = DataProcessorStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ApplicationShutdown", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	ItemsAndParameters.Add(FormOpenParameters);
		
EndProcedure

&AtServer
Procedure CreateCheckBoxInForm(QuestionStructure)
	
	DefaultValue = True;
	Var_Group  = GenerateFormItemGroup();
	
	If Not IsBlankString(QuestionStructure.NoteText) Then
		LabelName = FindLabelNameInForm("QuestionLabel1");
		LabelType = Type("FormDecoration");
		
		LabelParent = Var_Group;
		
		InformationTextItem = Items.Add(LabelName, LabelType, LabelParent);
		InformationTextItem.Title = QuestionStructure.NoteText;
	EndIf;
	
	If IsBlankString(QuestionStructure.CheckBoxText) Then 
		Return;
	EndIf;
	
	// Adding the attribute to the form.
	CheckBoxName = FindLabelNameInForm("QuestionLabel1");
	FlagType = Type("FormField");
	
	FlagParent = Var_Group;
	
	TypesArray = New Array;
	TypesArray.Add(Type("Boolean"));
	LongDesc = New TypeDescription(TypesArray);
	
	AttributesToBeAdded = New Array;
	NewAttribute = New FormAttribute(CheckBoxName, LongDesc, , CheckBoxName, False);
	AttributesToBeAdded.Add(NewAttribute);
	ChangeAttributes(AttributesToBeAdded);
	ThisObject[CheckBoxName] = DefaultValue;
	
	NewFormField = Items.Add(CheckBoxName, FlagType, FlagParent);
	NewFormField.DataPath = CheckBoxName;
	
	NewFormField.TitleLocation = FormItemTitleLocation.Right;
	NewFormField.Title          = QuestionStructure.CheckBoxText;
	NewFormField.Type                = FormFieldType.CheckBoxField;
	
	SetExtendedTooltip(NewFormField, QuestionStructure);
	
	If IsBlankString(QuestionStructure.ActionIfFlagSet.Form) Then
		Return;	
	EndIf;
	
	ActionStructure = QuestionStructure.ActionIfFlagSet;
	
	NewFormField.SetAction("OnChange", "Attachable_CheckBoxOnChange");
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("Name", CheckBoxName);
	FormOpenParameters.Insert("Form", ActionStructure.Form);
	FormOpenParameters.Insert("Use", DefaultValue);
	
	FormParameters = ActionStructure.FormParameters;
	If FormParameters = Undefined Then 
		FormParameters = New Structure;
	EndIf;
	FormParameters.Insert("ApplicationShutdown", True);
	FormOpenParameters.Insert("FormParameters", FormParameters);
	
	TasksToRunAfterClose.Add(FormOpenParameters);
	
EndProcedure

&AtServer
Procedure SetExtendedTooltip(FormItem, Val DetailsString)
	
	ExtendedTooltipDetails = DetailsString.ExtendedTooltip;
	If ExtendedTooltipDetails = "" Then
		Return;
	EndIf;
	
	If TypeOf(ExtendedTooltipDetails) <> Type("String") Then
		// Setting the extended tooltip.
		FillPropertyValues(FormItem.ExtendedTooltip, ExtendedTooltipDetails);
		FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
		Return;
	EndIf;
	
	FormItem.ExtendedTooltip.Title = ExtendedTooltipDetails;
	FormItem.ToolTipRepresentation = ToolTipRepresentation.Button;
	
EndProcedure

&AtServer
Function FindLabelNameInForm(ItemTitle)
	IndexOf = 0;
	SearchFlag = True;
	
	Name = "";
	While SearchFlag Do 
		RowIndex1 = String(Format(IndexOf, "NZ=-"));
		RowIndex1 = StrReplace(RowIndex1, "-", "");
		Name = ItemTitle + RowIndex1;
		
		FoundItem = Items.Find(Name);
		If FoundItem = Undefined Then 
			Break;
		EndIf;
		
		IndexOf = IndexOf + 1;
	EndDo;
	
	Return Name;
EndFunction

&AtClient
Function TaskArrayIDByName(TagName)
	For Each ArrayElement In TasksToRunAfterClose Do
		Description = "";
		If ArrayElement.Value.Property("Name", Description) Then 
			If Not IsBlankString(Description) And Description = TagName Then
				Return ArrayElement.GetID();
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

&AtClient
Procedure ExecuteTasksOnClose(Result = Undefined, InitialTaskNumber = Undefined) Export
	
	If InitialTaskNumber = Undefined Then
		InitialTaskNumber = 0;
	EndIf;
	
	For TaskNumber = InitialTaskNumber To TasksToRunAfterClose.Count() - 1 Do
		
		ArrayElement = TasksToRunAfterClose[TaskNumber];
		Use = Undefined;
		If Not ArrayElement.Value.Property("Use", Use) Then 
			Continue;
		EndIf;
		If TypeOf(Use) <> Type("Boolean") Then 
			Continue;
		EndIf;
		If Use <> True Then 
			Continue;
		EndIf;
		
		Form = Undefined;
		If ArrayElement.Value.Property("Form", Form) Then 
			FormParameters = Undefined;
			If ArrayElement.Value.Property("FormParameters", FormParameters) Then 
				Notification = New NotifyDescription("ExecuteTasksOnClose", ThisObject, TaskNumber + 1);
				OpenForm(Form, StructureFromFixedStructure(FormParameters),,,,,Notification, FormWindowOpeningMode.LockOwnerWindow);
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	Close(False);
	
EndProcedure

&AtClient
Function StructureFromFixedStructure(Source)
	
	Result = New Structure;
	
	For Each Item In Source Do
		Result.Insert(Item.Key, Item.Value);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion
