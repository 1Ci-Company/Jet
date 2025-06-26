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

// Updates the list of commands depending on the current context.
//
// Parameters:
//   Form - ClientApplicationForm - a form that requires update of commands.
//   Source - FormDataStructure
//            - FormTable - a context to check conditions (Form.Object or Form.Items.List).
//
Procedure UpdateCommands(Form, Val Source = Undefined) Export
	
	ClientParameters = AttachableCommandsParameters(Form);
	If TypeOf(ClientParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	If ClientParameters.InputOnBasisUsingAttachableCommands Then
		CreateBasedOnSubmenu = Form.Items.Find("FormCreateBasedOn");
		If CreateBasedOnSubmenu <> Undefined And CreateBasedOnSubmenu.Visible Then
			CreateBasedOnSubmenu.Visible = False;
		EndIf;
	EndIf;
	
	If Source = Undefined Then
		For Each CommandsPrefix In ClientParameters.CommandsOwners Do
			Source = CommandOwnerByCommandPrefix(CommandsPrefix, Form);
			RefreshSourceCommands(Form, Source, CommandsPrefix);
		EndDo;
		
		Return;
	Else
		RefreshSourceCommands(Form, Source);
	EndIf;
	
	Return;
	
EndProcedure

#EndRegion

#Region Private

// Properties of the second handler parameter of the attachable command shared both by client and server handlers.
//
// Returns:
//  Structure:
//   * CommandDetails - Structure - properties match the value table columns of the Commands parameter
///of the AttachableCommandsOverridable.OnDefineCommandsAttachedToObject procedure.
//                                   Key properties:
//      ** Id - String - Command ID.
//      ** Presentation - String - Command presentation in a form.
//      ** Name - String - a command name on a form.
//   * Form - ClientApplicationForm - a form the command is called from.
//   * IsObjectForm - Boolean - True if the command is called from the object form.
//   * Source - FormTable
//              - FormDataStructure - an object or a form list with the Reference field.
//
Function CommandExecuteParameters() Export
	Result = New Structure;
	Result.Insert("CommandDetails", Undefined);
	Result.Insert("Form", Undefined);
	Result.Insert("Source", Undefined);
	Result.Insert("IsObjectForm", False);
	Return Result;
EndFunction

Function ConditionsBeingExecuted(Conditions, AttributesValues)
	For Each Condition In Conditions Do
		AttributeName = Condition.Attribute;
		If Not AttributesValues.Property(AttributeName) Then
			Continue;
		EndIf;
		ConditionBeingExecuted = True;
		If Condition.ComparisonType = ComparisonType.Equal
			Or Condition.ComparisonType = DataCompositionComparisonType.Equal Then
			ConditionBeingExecuted = AttributesValues[AttributeName] = Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.Greater
			Or Condition.ComparisonType = DataCompositionComparisonType.Greater Then
			ConditionBeingExecuted = AttributesValues[AttributeName] > Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.GreaterOrEqual
			Or Condition.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
			ConditionBeingExecuted = AttributesValues[AttributeName] >= Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.Less
			Or Condition.ComparisonType = DataCompositionComparisonType.Less Then
			ConditionBeingExecuted = AttributesValues[AttributeName] < Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.LessOrEqual
			Or Condition.ComparisonType = DataCompositionComparisonType.LessOrEqual Then
			ConditionBeingExecuted = AttributesValues[AttributeName] <= Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.NotEqual
			Or Condition.ComparisonType = DataCompositionComparisonType.NotEqual Then
			ConditionBeingExecuted = AttributesValues[AttributeName] <> Condition.Value;
		ElsIf Condition.ComparisonType = ComparisonType.InList
			Or Condition.ComparisonType = DataCompositionComparisonType.InList Then
			If TypeOf(Condition.Value) = Type("ValueList") Then
				ConditionBeingExecuted = Condition.Value.FindByValue(AttributesValues[AttributeName]) <> Undefined;
			Else // Array
				ConditionBeingExecuted = Condition.Value.Find(AttributesValues[AttributeName]) <> Undefined;
			EndIf;
		ElsIf Condition.ComparisonType = ComparisonType.NotInList
			Or Condition.ComparisonType = DataCompositionComparisonType.NotInList Then
			If TypeOf(Condition.Value) = Type("ValueList") Then
				ConditionBeingExecuted = Condition.Value.FindByValue(AttributesValues[AttributeName]) = Undefined;
			Else // Array
				ConditionBeingExecuted = Condition.Value.Find(AttributesValues[AttributeName]) = Undefined;
			EndIf;
		ElsIf Condition.ComparisonType = DataCompositionComparisonType.Filled Then
			ConditionBeingExecuted = ValueIsFilled(AttributesValues[AttributeName]);
		ElsIf Condition.ComparisonType = DataCompositionComparisonType.NotFilled Then
			ConditionBeingExecuted = Not ValueIsFilled(AttributesValues[AttributeName]);
		EndIf;
		If Not ConditionBeingExecuted Then
			Return False;
		EndIf;
	EndDo;
	Return True;
EndFunction

Procedure HideShowAllSubordinateButtons(FormGroup, Visible)
	For Each SubordinateItem In FormGroup.ChildItems Do
		If TypeOf(SubordinateItem) = Type("FormGroup") Then
			HideShowAllSubordinateButtons(SubordinateItem, Visible);
		ElsIf TypeOf(SubordinateItem) = Type("FormButton") Then
			SubordinateItem.Visible = Visible;
		EndIf;
	EndDo;
EndProcedure

// Returns:
//  Structure:
//   * HasVisibilityConditions - Boolean
//   * SubmenuWithVisibilityConditions - Array of Structure:
//    ** Name - String
//    ** CommandsWithVisibilityConditions - Array
//    ** HasCommandsWithoutVisibilityConditions - Boolean
//   * CommandsMarked - Array
//   * RootSubmenuAndCommands - 
//   * CommandsAvailability - Boolean
//   * CommandsTableAddress - String
//   * InputOnBasisUsingAttachableCommands - Boolean
//
Function AttachableCommandsParameters(Form)
	
	Structure = New Structure("AttachableCommandsParameters", Null);
	FillPropertyValues(Structure, Form);
	Return Structure.AttachableCommandsParameters;
	
EndFunction

// Returns:
//  Array of FormDataStructure, FormDataCollectionItem:
//   * Ref - AnyRef
// 
Function SelectedObjects(Source)
	
	SelectedObjects = New Array; // Array of FormDataStructure, FormDataCollectionItem
	
	If TypeOf(Source) = Type("FormTable") Then
		SelectedRows = Source.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			If TypeOf(SelectedRow) = Type("DynamicListGroupRow") Then
				Continue;
			EndIf;
			CurrentRow = Source.RowData(SelectedRow);
			If CurrentRow <> Undefined Then
				SelectedObjects.Add(CurrentRow);
			EndIf;
		EndDo;
	Else
		SelectedObjects.Add(Source);
	EndIf;
	
	Return SelectedObjects;
	
EndFunction


Function ThisObjectUnlockCommand(Conditions)
	For Each Condition In Conditions Do
		AttributeName = Condition.Attribute;
		If AttributeName = "IBVersionUpdate_ObjectLocked" Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

Function HideObjectUnlockCommand(Form)
	SignLock = Form.Commands.Find("IBVersionUpdate_ObjectLocked");
	If SignLock = Undefined Then
		Return True;
	EndIf;
	
	Return False;
EndFunction

Procedure RefreshSourceCommands(Val Form, Val Source, Val SourceName = "")
	
	ClientParameters = AttachableCommandsParameters(Form);
	If TypeOf(ClientParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	If ClientParameters.InputOnBasisUsingAttachableCommands Then
		CreateBasedOnSubmenu = Form.Items.Find("FormCreateBasedOn");
		If CreateBasedOnSubmenu <> Undefined And CreateBasedOnSubmenu.Visible Then
			CreateBasedOnSubmenu.Visible = False;
		EndIf;
	EndIf;
	
	If TypeOf(Source) = Type("FormTable") Then
		CommandsAvailability = (Source.CurrentRow <> Undefined);
	Else
		CommandsAvailability = True;
	EndIf;

	For Each RootSubmenuOrCommand In ClientParameters.RootSubmenuAndCommands Do
		ButtonOrSubmenuName = RootSubmenuOrCommand.Key;
		SubmenuOrButtonProperties = RootSubmenuOrCommand.Value;
		If ValueIsFilled(SourceName) And SubmenuOrButtonProperties.CommandsPrefix <> SourceName Then
			Continue;
		EndIf;

		ButtonOrSubmenu = Form.Items[ButtonOrSubmenuName];
		If ButtonOrSubmenu.Enabled = CommandsAvailability Then
			Continue;
		EndIf;
		
		ButtonOrSubmenu.Enabled = CommandsAvailability;
		If TypeOf(ButtonOrSubmenu) = Type("FormGroup") And ButtonOrSubmenu.Type = FormGroupType.Popup Then
			HideShowAllSubordinateButtons(ButtonOrSubmenu, CommandsAvailability);
			CapCommand = Form.Items.Find(ButtonOrSubmenuName + "Stub");
			If CapCommand <> Undefined Then
				CapCommand.Visible = Not CommandsAvailability And SubmenuOrButtonProperties.HasInCommandBar;
			EndIf;
		EndIf;
	EndDo;
	
	For Each CommandDetails In ClientParameters.CommandsMarked Do
		If ValueIsFilled(SourceName) And CommandDetails.CommandsPrefix <> SourceName Then
			Continue;
		EndIf;
		If ValueIsFilled(CommandDetails.CheckMarkValue) Then
			If TypeOf(Source) = Type("FormTable") Then
				TheExpressionComputingTheValueOfTheNotes = StrReplace(CommandDetails.CheckMarkValue, "%SOURCE%", Source.Name);	
			Else
				TheExpressionComputingTheValueOfTheNotes = CommandDetails.CheckMarkValue;
			EndIf;
			
			Form.Items[CommandDetails.NameOnForm].Check = Eval(TheExpressionComputingTheValueOfTheNotes); // ACC:488 The code being executed is safe.
		EndIf;
	EndDo;
	
	If Not CommandsAvailability Or Not ClientParameters.HasVisibilityConditions Then
		Return;
	EndIf;
	
	CheckTypesDetails = TypeOf(Source) = Type("FormTable");
	SelectedObjects = SelectedObjects(Source);
	
	For Each SubmenuShortInfo In ClientParameters.SubmenuWithVisibilityConditions Do
		HasVisibleCommands = False;
		Popup = Form.Items.Find(SubmenuShortInfo.Name);
		ChangeVisible = (TypeOf(Popup) = Type("FormGroup") And Popup.Type = FormGroupType.Popup);
		HideObjectUnlockCommand = HideObjectUnlockCommand(Form);
		
		For Each Command In SubmenuShortInfo.CommandsWithVisibilityConditions Do
			If ValueIsFilled(SourceName) And Command.CommandsPrefix <> SourceName Then
				Continue;
			EndIf;
			
			CommandItem = Form.Items[Command.NameOnForm];
			Visible = SelectedObjects.Count() > 0;
			For Each Object In SelectedObjects Do
				If CheckTypesDetails
					And TypeOf(Command.ParameterType) = Type("TypeDescription")
					And Not Command.ParameterType.ContainsType(TypeOf(Object.Ref)) Then
					Visible = False;
					Break;
				EndIf;

				If ValueIsFilled(Command.VisibilityConditionsByObjectTypes) Then
					VisibilityConditions = Command.VisibilityConditionsByObjectTypes[TypeOf(Object.Ref)];
				Else
					VisibilityConditions = Command.VisibilityConditions;
				EndIf;

				If ValueIsFilled(VisibilityConditions) And Not ConditionsBeingExecuted(VisibilityConditions, Object) Then
					Visible = False;
					Break;
				EndIf;
			EndDo;
			
			If HideObjectUnlockCommand And ThisObjectUnlockCommand(Command.VisibilityConditions) Then
				CommandItem.Visible = False;
			ElsIf ChangeVisible Then
				CommandItem.Visible = Visible;
			Else
				CommandItem.Enabled = Visible;
			EndIf;
			HasVisibleCommands = HasVisibleCommands Or Visible;
		EndDo;
		
		If Not SubmenuShortInfo.HasCommandsWithoutVisibilityConditions Then
			CapCommand = Form.Items.Find(SubmenuShortInfo.Name + "Stub");
			If CapCommand <> Undefined Then
				CapCommand.Visible = Not HasVisibleCommands;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Function CommandOwnerByCommandName(CommandName, Form) Export
	
	Result = Undefined;
	
	StringParts1 = StrSplit(CommandName, "_", True);
	If StringParts1.Count() >= 4 Then
		OwnerType = StringParts1[1];
		OwnerName = StringParts1[2];
		
		Result = CommandOwnerByCommandPrefix(OwnerType + "_" + OwnerName, Form);
	EndIf;
	
	Return Result;
	
EndFunction

Function CommandOwnerByCommandPrefix(CommandPrefix, Form)
	
	Result = Undefined;
	
	StringParts1 = StrSplit(CommandPrefix, "_", True);
	If StringParts1.Count() = 2 Then
		OwnerType = StringParts1[0];
		OwnerName = StringParts1[1];
		PropertiesValues = New Structure(OwnerName);
		If OwnerType = "Attribute" Then
			FillPropertyValues(PropertiesValues, Form);
		ElsIf OwnerType = "Item" Then
			FillPropertyValues(PropertiesValues, Form.Items);
		EndIf;
		Result = PropertiesValues[OwnerName];
	EndIf;
	
	Return Result;
	
EndFunction
#EndRegion