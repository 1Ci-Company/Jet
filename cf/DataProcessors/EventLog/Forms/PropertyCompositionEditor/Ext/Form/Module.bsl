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
	
	ListToEdit = Parameters.ListToEdit;
	ParametersToSelect = Parameters.ParametersToSelect;
	
	SetEditorParameters(ListToEdit, ParametersToSelect);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CheckOnChange(Item)
	SelectTreeItem(Items.List.CurrentData, Items.List.CurrentData.Check);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectFilterComposition(Command)
	
	Notify("EventLogFilterItemValueChoice",
	           GetEditedList(),
	           FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure SelectAllCheckBoxes()
	SetMarks(True);
EndProcedure

&AtClient
Procedure ClearAllCheckBoxes()
	SetMarks(False);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetEditorParameters(ListToEdit, ParametersToSelect)
	StringParts1 = StrSplit(ParametersToSelect, ".");
	If StringParts1.Count() > 1 Then
		ParametersToSelect = StringParts1[0];
		Separator = StringParts1[1];
		FilterParameterStructure = GetEventLogFilterValues();
		FilterValues = FilterParameterStructure[ParametersToSelect].Get(Separator);
		FilterValues.Insert("", NStr("en = '<Not set>';"));
	Else
		FilterParameterStructure = GetEventLogFilterValues(ParametersToSelect);
		FilterValues = FilterParameterStructure[ParametersToSelect];
	EndIf;
	// Getting a list of event presentations.
	If ParametersToSelect = "Event" Or ParametersToSelect = "Event" Then
		
		For Each MapItem In FilterValues Do
			EventPresentationString = EventPresentations.Add();
			EventPresentationString.Presentation = MapItem.Value;
		EndDo;
		
	EndIf;
	
	If TypeOf(FilterValues) = Type("Array") Then
		ListItems = List.GetItems();
		For Each ArrayElement In FilterValues Do
			NewItem = ListItems.Add();
			NewItem.Check = False;
			NewItem.Value = ArrayElement;
			NewItem.Presentation = ArrayElement;
		EndDo;
	ElsIf TypeOf(FilterValues) = Type("Map") Then
		
		If ParametersToSelect = "Event"
			Or ParametersToSelect = "Event"
			Or ParametersToSelect = "Metadata"
			Or ParametersToSelect = "Metadata" Then
			
			// Getting as a tree.
			For Each MapItem In FilterValues Do
				NewItem = GetTreeBranch(MapItem.Value, ParametersToSelect);
				NewItem.Check = False;
				If IsBlankString(NewItem.Value) Then
					NewItem.Value = MapItem.Key;
				Else
					NewItem.Value = NewItem.Value + Chars.LF + MapItem.Key;
				EndIf;
				NewItem.FullPresentation = MapItem.Value;
			EndDo;
			
		Else 
			// Getting as a flat list.
			IsUnspecifiedUserAdded = False;
			ListItems = List.GetItems();
			For Each MapItem In FilterValues Do
				NewItem = ListItems.Add();
				NewItem.Check = False;
				If ParametersToSelect = "SessionDataSeparationValues" Then
					NewItem.Value = Format(MapItem.Key, "NG=");
				Else
					NewItem.Value = MapItem.Key;
				EndIf;
				
				If (ParametersToSelect = "User" Or ParametersToSelect = "User") Then
					// In this case, the username serves as a key.
					NewItem.Value = MapItem.Key;
					
					If MapItem.Value = "" Then
						// For default users.
						IsUnspecifiedUserAdded = True;
						NewItem.Presentation = UnspecifiedUserFullName();
					Else
						// For utility users.
						InternalUserPresentation = InternalUserFullName(MapItem.Key);
						If Not IsBlankString(InternalUserPresentation) Then
							NewItem.Presentation = InternalUserPresentation;
						Else
							SetPrivilegedMode(True);
							IBUser = InfoBaseUsers.FindByUUID(
								MapItem.Key);
							SetPrivilegedMode(False);
							If IBUser = Undefined Then
								NewItem.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
									NStr("en = '%1 <Deleted>';"), MapItem.Value);
							Else
								NewItem.Presentation = MapItem.Value;
							EndIf;
						EndIf;
					EndIf;
					NewItem.FullPresentation = NewItem.Presentation;
				Else
					NewItem.Presentation = MapItem.Value;
					NewItem.FullPresentation = MapItem.Value;
				EndIf;
			EndDo;
			
			If Not IsUnspecifiedUserAdded
			   And (ParametersToSelect = "User" Or ParametersToSelect = "User") Then
				
				SetPrivilegedMode(True);
				EmptyInfobaseUser = InfoBaseUsers.FindByName("");
				SetPrivilegedMode(False);
				NewItem = ListItems.Add();
				NewItem.Check = False;
				NewItem.Value = EmptyInfobaseUser.UUID;
				NewItem.Presentation = UnspecifiedUserFullName();
				NewItem.FullPresentation = NewItem.Presentation;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Selecting marks of tree items that are mapped to ListToEdit items.
	SelectFoundItems(List.GetItems(), ListToEdit);
	
	// Check if the list has child items.
	// If it has, change the control to "List".
	IsTree = False;
	For Each TreeItem In List.GetItems() Do
		If TreeItem.GetItems().Count() > 0 Then 
			IsTree = True;
			Break;
		EndIf;
	EndDo;
	If Not IsTree Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
	OrderTreeItems();
	
EndProcedure

&AtClient
Function GetEditedList()
	
	ListToEdit = New ValueList;
	
	ListToEdit.Clear();
	HasNotSelected = False;
	FillListToEdit(ListToEdit, List.GetItems(), HasNotSelected);
	
	Return ListToEdit;
	
EndFunction

&AtServer
Function GetTreeBranch(Presentation, ParametersToSelect, Recursion = False)
	PathStrings = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Presentation, ".", True, True);
	If (ParametersToSelect = "Metadata"
			Or ParametersToSelect = "Metadata")
		And PathStrings.Count() > 2 Then
		ObjectName = PathStrings[0];
		PathStrings.Delete(0);
		MetadataObjectName = StrConcat(PathStrings, ". ");
		PathStrings = New Array;
		PathStrings.Add(ObjectName);
		PathStrings.Add(MetadataObjectName);
	EndIf;
	
	If PathStrings.Count() = 1 Then
		TreeItems = List.GetItems();
		BranchName = PathStrings[0];
	ElsIf PathStrings.Count() = 0 Then
		TreeItems = List.GetItems();
		BranchName = "";
	Else
		// Assembling a path to the parent branch by path fragments.
		ParentPathPresentation = "";
		For Cnt = 0 To PathStrings.Count() - 2 Do
			If Not IsBlankString(ParentPathPresentation) Then
				ParentPathPresentation = ParentPathPresentation + ".";
			EndIf;
			ParentPathPresentation = ParentPathPresentation + PathStrings[Cnt];
		EndDo;
		TreeItems = GetTreeBranch(ParentPathPresentation, ParametersToSelect, True).GetItems();
		BranchName = PathStrings[PathStrings.Count() - 1];
	EndIf;
	
	If AddedBranches.FindByValue(BranchName) <> Undefined Then
		For Each TreeItem In TreeItems Do
			If TreeItem.Presentation = BranchName Then
				If TreeItem.GetItems().Count() = 0 Then
					// This is a standalone event, don't include in groups.
					Continue;
				EndIf;
				
				If PathStrings.Count() = 1 And Not Recursion Then
					Break;
				EndIf;
				Return TreeItem;
			EndIf;
		EndDo;
	EndIf;
	// The tree item is not found, it has to be created.
	AddedBranches.Add(BranchName);
	
	TreeItem = TreeItems.Add();
	TreeItem.Presentation = BranchName;
	TreeItem.Check = False;
	Return TreeItem;
EndFunction

&AtClient
Procedure FillListToEdit(ListToEdit, TreeItems, HasNotSelected)
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			FillListToEdit(ListToEdit, TreeItem.GetItems(), HasNotSelected);
		Else
			If TreeItem.Check Then
				NewListItem = ListToEdit.Add();
				NewListItem.Value      = TreeItem.Value;
				NewListItem.Presentation = TreeItem.FullPresentation;
			Else
				HasNotSelected = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SelectFoundItems(TreeItems, ListToEdit)
	
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			SelectFoundItems(TreeItem.GetItems(), ListToEdit);
		Else
			If ListToEdit.FindByValue(TreeItem.Value) <> Undefined Then
				TreeItem.Check = True;
				CheckBranchMarked(TreeItem.GetParent());
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectTreeItem(TreeItem, Check, CheckBranchMarked = True)
	TreeItem.Check = Check;
	// Selecting marks of all child items of the tree.
	For Each TreeChildItem In TreeItem.GetItems() Do
		SelectTreeItem(TreeChildItem, Check, False);
	EndDo;
	// Checking if parent item state should be changed.
	If CheckBranchMarked Then
		CheckBranchMarked(TreeItem.GetParent());
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure CheckBranchMarked(Branch)
	If Branch = Undefined Then 
		Return;
	EndIf;
	ChildBranches = Branch.GetItems();
	
	HasTrue = False;
	HasFalse = False;
	For Each ChildBranch In ChildBranches Do
		If ChildBranch.Check Then
			HasTrue = True;
			If HasFalse Then
				Break;
			EndIf;
		Else
			HasFalse = True;
			If HasTrue Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If HasTrue Then
		If HasFalse Then
			// There are branches with both selected and cleared marks. If necessary, clearing the mark of the current item and then checking the parent.
			If Branch.Check Then
				Branch.Check = False;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		Else
			// All child branch marks are selected.
			If Not Branch.Check Then
				Branch.Check = True;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		EndIf;
	Else
		// All child branch marks are cleared.
		If Branch.Check Then
			Branch.Check = False;
			CheckBranchMarked(Branch.GetParent());
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetMarks(Value, TreeBranch1 = Undefined)
	
	If TreeBranch1 = Undefined Then
		TreeBranch1 = List;
	EndIf;
	
	For Each ListLine In TreeBranch1.GetItems() Do
		ListLine.Check = Value;
		SetMarks(Value, ListLine);
	EndDo;
	
EndProcedure

&AtServer
Procedure OrderTreeItems()
	
	ListTree = FormAttributeToValue("List");
	ListTree.Rows.Sort("Presentation Asc", True);
	ValueToFormAttribute(ListTree, "List");
	
EndProcedure

&AtServer
Function UnspecifiedUserFullName()
	
	Return NStr("en = '<Not specified>';");
	
EndFunction

&AtServerNoContext
Function InternalUserFullName(IBUserID)
	
	If Common.DataSeparationEnabled()
	   And Common.SeparatedDataUsageAvailable()
	   And Common.SubsystemExists("CloudTechnology.Core") Then
		
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		Return ModuleSaaSOperations.AliasOfUserOfInformationBase(IBUserID);
	EndIf;
	
	Return "";
	
EndFunction

#EndRegion
