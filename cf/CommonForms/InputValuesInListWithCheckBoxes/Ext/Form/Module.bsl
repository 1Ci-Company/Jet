///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var ListItemBeforeStartChanging; // See ListItemBeforeStartChanging

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RestrictSelectionBySpecifiedValues = Parameters.RestrictSelectionBySpecifiedValues;
	QuickChoice = Parameters.QuickChoice;
	
	TypesInformation = ReportsServer.ExtendedTypesDetails(Parameters.TypeDescription, True);
	TypesInformation.Insert("ContainsRefTypes", False);
	
	AllTypesWithQuickChoice = TypesInformation.TypesCount < 10
		And (TypesInformation.TypesCount = TypesInformation.ObjectTypes.Count());
	For Each Type In TypesInformation.ObjectTypes Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		TypesInformation.ContainsRefTypes = True;
		
		Kind = Upper(StrSplit(MetadataObject.FullName(), ".")[0]);
		If Kind <> "ENUM" Then
			If Kind = "CATALOG"
				Or Kind = "CHARTOFCALCULATIONTYPES"
				Or Kind = "CHARTOFCHARACTERISTICTYPES"
				Or Kind = "EXCHANGEPLAN"
				Or Kind = "CHARTOFACCOUNTS" Then
				If MetadataObject.ChoiceMode <> Metadata.ObjectProperties.ChoiceMode.QuickChoice Then
					AllTypesWithQuickChoice = False;
				EndIf;
			Else
				AllTypesWithQuickChoice = False;
			EndIf;
		EndIf;
		
		If Not AllTypesWithQuickChoice Then
			Break;
		EndIf;
	EndDo;
	
	ValuesForSelection = Parameters.ValuesForSelection;
	Marked = Parameters.Marked;
	
	If AllTypesWithQuickChoice Then
		QuickChoice = True;
	EndIf;
	
	If Not RestrictSelectionBySpecifiedValues And QuickChoice And Not Parameters.ValuesForSelectionFilled Then
		ValuesForSelection = ReportsServer.ValuesForSelection(Parameters);
	EndIf;
	
	Title = Parameters.Presentation;
	If IsBlankString(Title) Then
		Title = String(Parameters.TypeDescription);
	EndIf;
	
	If TypesInformation.TypesCount = 0 Then
		RestrictSelectionBySpecifiedValues = True;
	ElsIf Not TypesInformation.ContainsObjectTypes Or QuickChoice Then
		Items.ListPick.Visible       = False;
		Items.ListPickMenu.Visible   = False;
		Items.ListPickFooter.Visible = False;
		Items.ListAdd.LocationInCommandBar = ButtonLocationInCommandBar.InCommandBar;
	EndIf;
	
	ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
	Items.ListValue.ChoiceFoldersAndItems = ReportsClientServer.GroupsAndItemsTypeValue(ChoiceFoldersAndItems);
	
	List.ValueType = TypesInformation.TypesDetailsForForm;
	If TypeOf(ValuesForSelection) = Type("ValueList") Then
		ValuesForSelection.FillChecks(False);
		CommonClientServer.SupplementList(List, ValuesForSelection, True, True);
	EndIf;
	If TypeOf(Marked) = Type("ValueList") Then
		Marked.FillChecks(True);
		CommonClientServer.SupplementList(List, Marked, True, Not RestrictSelectionBySpecifiedValues);
	EndIf;
	
	If List.Count() = 0 Then
		Items.ListPickFooter.Visible = False;
	EndIf;
	
	If RestrictSelectionBySpecifiedValues Then
		Items.ListValue.ReadOnly = True;
		Items.List.ChangeRowSet    = False;
		
		Items.ListAddDelete.Visible     = False;
		Items.ListAddDeleteMenu.Visible = False;
		
		Items.ListSort.Visible     = False;
		Items.ListSortMenu.Visible = False;
		
		Items.ListMove.Visible     = False;
		Items.ListMoveMenu.Visible = False;
		
		Items.ListPickFooter.Visible = False;
	EndIf;
	
	ChoiceParameters = Parameters.ChoiceParameters;
	If TypeOf(ChoiceParameters) = Type("Array") Then
		Items.ListValue.ChoiceParameters = New FixedArray(ChoiceParameters);
	EndIf;
	
	WindowOptionsKey = Parameters.UniqueKey;
	If IsBlankString(WindowOptionsKey) Then
		WindowOptionsKey = Common.TrimStringUsingChecksum(String(List.ValueType), 128);
	EndIf;
	
	If RestrictSelectionBySpecifiedValues
		Or Not TypesInformation.ContainsRefTypes
		Or Not Common.SubsystemExists("StandardSubsystems.ImportDataFromFile") Then
			Items.ListPasteFromClipboard.Visible     = False;
			Items.ListPasteFromClipboardMenu.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	IDRow = Item.CurrentRow;
	If IDRow = Undefined Then
		Return;
	EndIf;
	
	ValueListInForm = ThisObject[Item.Name];
	ListItemInForm = ValueListInForm.FindByID(IDRow);
	
	CurrentRow = Item.CurrentData;
	If CurrentRow = Undefined Then
		Return;
	EndIf;
	ListItemBeforeStartChanging = ListItemBeforeStartChanging();
	FillPropertyValues(ListItemBeforeStartChanging, ListItemInForm);
	ListItemBeforeStartChanging.Id = IDRow;
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	If RestrictSelectionBySpecifiedValues Then
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	If RestrictSelectionBySpecifiedValues Then
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure ListBeforeEditEnd(Item, NewRow, CancelEditStart, CancelEditComplete)
	If CancelEditStart Then
		Return;
	EndIf;
	
	IDRow = Item.CurrentRow;
	If IDRow = Undefined Then
		Return;
	EndIf;
	ValueListInForm = ThisObject[Item.Name];
	ListItemInForm = ValueListInForm.FindByID(IDRow);
	
	Value = ListItemInForm.Value;
	
	For Each ListItemDuplicateInForm In ValueListInForm Do
		If ListItemDuplicateInForm.Value = Value And ListItemDuplicateInForm <> ListItemInForm Then
			CancelEditComplete = True; // Restrict duplicates.
			Break;
		EndIf;
	EndDo;
	
	HasInformation = (ListItemBeforeStartChanging <> Undefined And ListItemBeforeStartChanging.Id = IDRow);
	If Not CancelEditComplete And HasInformation And ListItemBeforeStartChanging.Value <> Value Then
		If RestrictSelectionBySpecifiedValues Then
			CancelEditComplete = True;
		Else
			ListItemInForm.Presentation = ""; // Populate the presentation.
			ListItemInForm.Check = True; // Set the flag.
		EndIf;
	EndIf;
	
	If CancelEditComplete Then
		// Roll back the values.
		If HasInformation Then
			FillPropertyValues(ListItemInForm, ListItemBeforeStartChanging);
		EndIf;
		// Restart the BeforeEditEnd event with CancelEditStart = True.
		Item.EndEditRow(True);
	Else
		If NewRow Then
			ListItemInForm.Check = True; // Set the flag.
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ListChoiceProcessing(Item, SelectionResult, StandardProcessing)
	StandardProcessing = False;
	
	Selected_ = ReportsClientServer.ValuesByList(SelectionResult);
	Selected_.FillChecks(True);
	
	AddOn = CommonClientServer.SupplementList(List, Selected_, True, True);
	If AddOn.Total = 0 Then
		Return;
	EndIf;
	If AddOn.Total = 1 Then
		NotificationTitle = NStr("en = 'The item added to the list.';");
	Else
		NotificationTitle = NStr("en = 'The items added to the list.';");
	EndIf;
	ShowUserNotification(
		NotificationTitle,
		,
		String(Selected_),
		PictureLib.ExecuteTask);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CompleteEditing(Command)
	If ModalMode
		Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(List);
	Else
		NotifyChoice(List);
	EndIf;
EndProcedure

&AtClient
Procedure PasteFromClipboard(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", List.ValueType);
	SearchParameters.Insert("ChoiceParameters", Items.ListValue.ChoiceParameters);
	SearchParameters.Insert("FieldPresentation", Title);
	SearchParameters.Insert("Scenario", "RefsSearch");
	
	ExecutionParameters = New Structure;
	Handler = New NotifyDescription("PasteFromClipboardCompletion", ThisObject, ExecutionParameters);
	
	ModuleDataImportFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleDataImportFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure PasteFromClipboardCompletion(FoundObjects, ExecutionParameters) Export
	
	If FoundObjects = Undefined Then
		Return;
	EndIf;
	
	For Each Value In FoundObjects Do
		ReportsClientServer.AddUniqueValueToList(List, Value, Undefined, True);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Constructors.

// The constructor of details of value list item properties.
//
//  Returns:
//   Structure - Details of the value list items, where:
//       * Id - Number
//       * Check - Boolean
//       * Value - Undefined
//       * Presentation - String
//
&AtClient
Function ListItemBeforeStartChanging()
	
	Item = New Structure();
	Item.Insert("Id", 0);
	Item.Insert("Check", False);
	Item.Insert("Value", Undefined);
	Item.Insert("Presentation", "");
	
	Return Item;
	
EndFunction

#EndRegion