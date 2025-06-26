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
	
	SetConditionalAppearance();
	
	SearchAreas = Parameters.SearchAreas;
	RadioButtonsEverywhereInSections = SearchAreas.Count();
	
	SelectedIDs = New Map();
	NameIDs = Common.MetadataObjectIDs(Parameters.SearchAreas.UnloadValues());
	For Each Item In NameIDs Do
		SelectedIDs.Insert(Item.Value, True);
	EndDo;
	OnFillSearchSectionsTree(SelectedIDs);
	
	SearchInSections = SearchInSections(RadioButtonsEverywhereInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.SearchSectionsTree, SearchInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.Commands, SearchInSections);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandCurrentSectionsTreeSection(Items.SearchSectionsTree)
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SearchAreaOnChange(Item)
	
	SearchInSections = SearchInSections(RadioButtonsEverywhereInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.SearchSectionsTree, SearchInSections);
	UpdateAvailabilityOnSwitchEverywhereInSections(Items.Commands, SearchInSections);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSearchSectionsTree

&AtClient
Procedure SearchSectionsTreeMarkOnChange(Item)
	
	TreeItem = CurrentItem.CurrentData;
	
	OnMarkTreeItem(TreeItem);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OkCommand(Command)
	
	CurrentData = Items.SearchSectionsTree.CurrentData;
	
	CurrentSection = "";
	If CurrentData <> Undefined Then
		CurrentSection = CurrentData.Section;
	EndIf;
	RowID = Items.SearchSectionsTree.CurrentRow;
	
	SearchSettings1 = New ValueList();
	If SearchInSections(RadioButtonsEverywhereInSections) Then
		SearchSettings1 = SectionsTreeAreasList();
	EndIf;
	
	Close(SearchSettings1);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	MarkAllTreeItemsRecursively(SearchSectionsTree, MarkCheckBoxIsNotSelected());
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	MarkAllTreeItemsRecursively(SearchSectionsTree, MarkCheckBoxIsSelected());
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	TreeItemsCollection = SearchSectionsTree.GetItems();
	SectionsTreeItem = Items.SearchSectionsTree;
	
	For Each TreeItem In TreeItemsCollection Do
		SectionsTreeItem.Collapse(TreeItem.GetID());
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	TreeItemsCollection = SearchSectionsTree.GetItems();
	SectionsTreeItem = Items.SearchSectionsTree;
	
	For Each TreeItem In TreeItemsCollection Do
		SectionsTreeItem.Expand(TreeItem.GetID(), True);
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtServer
Procedure OnFillSearchSectionsTree(SelectedIDs)
	
	Tree = FormAttributeToValue("SearchSectionsTree");
	FillSearchSectionsTree(Tree, SelectedIDs);
	ValueToFormAttribute(Tree, "SearchSectionsTree");
	
	OnSetSearchArea(SearchSectionsTree);
	
EndProcedure

&AtServer
Procedure OnSetSearchArea(SearchSectionsTree)
	
	For Each SearchArea In SearchAreas Do
		
		TreeItem = Undefined;
		CurrentSection = Undefined;
		NestedItems = SearchSectionsTree.GetItems();
		
		// Search for a tree item by a path to the data.
		
		DataPath = SearchArea.Presentation;
		Sections = StrSplit(DataPath, ",", False);
		For Each CurrentSection In Sections Do
			For Each TreeItem In NestedItems Do
				
				If TreeItem.Section = CurrentSection Then
					NestedItems = TreeItem.GetItems();
					Break;
				EndIf;
				
			EndDo;
		EndDo;
		
		// If the tree item is found, the check mark is set.
		
		If TreeItem <> Undefined
			And TreeItem.Section = CurrentSection Then
			
			TreeItem.Check = MarkCheckBoxIsSelected();
			MarkParentsItemsRecursively(TreeItem);
		EndIf;
		
	EndDo;
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure OnMarkTreeItem(TreeItem)
	
	TreeItem.Check = NextItemCheckMarkValue(TreeItem);
	
	If RequiredToMarkNestedItems(TreeItem) Then 
		MarkNestedItemsRecursively(TreeItem);
	EndIf;
	
	If TreeItem.Check = MarkCheckBoxIsNotSelected() Then 
		TreeItem.Check = CheckMarkValueRelativeToNestedItems(TreeItem);
	EndIf;
	
	MarkParentsItemsRecursively(TreeItem);
	
EndProcedure

#EndRegion

#Region PresentationModel

&AtClientAtServerNoContext
Function MarkCheckBoxIsNotSelected()
	
	Return 0;
	
EndFunction

&AtClientAtServerNoContext
Function MarkCheckBoxIsSelected()
	
	Return 1;
	
EndFunction

&AtClientAtServerNoContext
Function MarkSquare()
	
	Return 2;
	
EndFunction

&AtServerNoContext
Procedure FillSearchSectionsTree(SearchSectionsTree, SelectedIDs)
	
	AddSearchSectionsTreeRowsBySubsystemsRecursively(SearchSectionsTree, Metadata.Subsystems, SelectedIDs);
	FillServicePropertiesAfterGetSectionsRecursively(SearchSectionsTree);
	
EndProcedure

&AtServerNoContext
Procedure AddSearchSectionsTreeRowsBySubsystemsRecursively(CurrentTreeRow, Subsystems, SelectedIDs)
	
	For Each Subsystem In Subsystems Do
		
		If MetadataObjectAvailable(Subsystem) Then
			
			NewRowSubsystem = NewTreeItemSection(CurrentTreeRow, Subsystem);
			
			AddSearchSectionsTreeRowsByContentRecursively(NewRowSubsystem, Subsystem.Content, SelectedIDs);
			
			If Subsystem.Subsystems.Count() > 0 Then
				AddSearchSectionsTreeRowsBySubsystemsRecursively(NewRowSubsystem, Subsystem.Subsystems, SelectedIDs);
			EndIf;
			
			If NewRowSubsystem.Rows.Count() = 0 Then
				CurrentTreeRow.Rows.Delete(NewRowSubsystem);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure AddSearchSectionsTreeRowsByContentRecursively(CurrentTreeRow, SubsystemComposition, SelectedIDs)
	
	For Each SubsystemObject In SubsystemComposition Do
		
		If Common.IsCatalog(SubsystemObject)
			Or Common.IsDocument(SubsystemObject)
			Or Common.IsChartOfCalculationTypes(SubsystemObject)
			Or Common.IsChartOfCharacteristicTypes(SubsystemObject)
			Or Common.IsExchangePlan(SubsystemObject)
			Or Common.IsChartOfAccounts(SubsystemObject)
			Or Common.IsBusinessProcess(SubsystemObject)
			Or Common.IsTask(SubsystemObject) Then
			
			If MetadataObjectAvailable(SubsystemObject) Then
				
				NewRowObject = NewTreeItemMetadataObject(CurrentTreeRow, SubsystemObject);
				NewRowObject.Check = SelectedIDs[NewRowObject.MetadataObjectsList];
				If Common.IsCatalog(SubsystemObject) Then 
					SubordinateCatalogs = SubordinateCatalogs(SubsystemObject);
					AddSearchSectionsTreeRowsByContentRecursively(NewRowObject, SubordinateCatalogs, SelectedIDs);
				EndIf;
				
			EndIf;
			
		ElsIf Common.IsDocumentJournal(SubsystemObject) Then
			
			If MetadataObjectAvailable(SubsystemObject) Then
				
				NewRowLog = NewTreeItemSection(CurrentTreeRow, SubsystemObject);
				
				AddSearchSectionsTreeRowsByContentRecursively(NewRowLog, SubsystemObject.RegisteredDocuments, SelectedIDs);
				
				If NewRowLog.Rows.Count() = 0 Then
					CurrentTreeRow.Rows.Delete(NewRowLog);
				EndIf;
				
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function NewTreeItemSection(CurrentTreeRow, Section)
	
	SectionPresentation = Section;
	If Common.IsDocumentJournal(Section) Then
		SectionPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 (Log)';"), SectionPresentation);
	EndIf;
	
	NewRow = CurrentTreeRow.Rows.Add();
	NewRow.Section = SectionPresentation;
	
	If IsRootSubsystem(Section) Then 
		NewRow.Picture = Section.Picture;
	EndIf;
	
	Return NewRow;
	
EndFunction

&AtServerNoContext
Function NewTreeItemMetadataObject(CurrentTreeRow, MetadataObject)
	
	ObjectPresentation = Common.ListPresentation(MetadataObject);
	
	NewRow = CurrentTreeRow.Rows.Add();
	NewRow.Section = ObjectPresentation;
	NewRow.MetadataObjectsList = Common.MetadataObjectID(MetadataObject);
	
	Return NewRow;
	
EndFunction

&AtServerNoContext
Procedure FillServicePropertiesAfterGetSectionsRecursively(CurrentTreeRow)
	
	If TypeOf(CurrentTreeRow) = Type("ValueTreeRow") Then 
		
		IsMetadataObject = ValueIsFilled(CurrentTreeRow.MetadataObjectsList);
		CurrentTreeRow.IsMetadataObject = IsMetadataObject;
		If CurrentTreeRow.Level() = 0 Then 
			CurrentTreeRow.DataPath = CurrentTreeRow.Section;
		Else 
			CurrentTreeRow.IsSubsection = Not IsMetadataObject;
			CurrentTreeRow.DataPath = CurrentTreeRow.Parent.DataPath + "," + CurrentTreeRow.Section;
		EndIf;
		
	EndIf;
	
	For Each SubordinateRow In CurrentTreeRow.Rows Do 
		FillServicePropertiesAfterGetSectionsRecursively(SubordinateRow);
		SubordinateRow.Rows.Sort("IsSubsection, Section");
	EndDo;
	
EndProcedure

&AtServer
Function SectionsTreeAreasList()
	
	Tree = FormAttributeToValue("SearchSectionsTree");
	
	AreasListIDs = New ValueList;
	FillAreasListRecursively(AreasListIDs, Tree.Rows);
	AreasList = IDsToAreasList(AreasListIDs);
	
	Return AreasList;
	
EndFunction

&AtServer
Function IDsToAreasList(AreasListIDs)
	Result = New ValueList();
	
	Query = New Query("SELECT
	|	MetadataObjectIDs.FullName AS FullName,
	|	MetadataObjectIDs.Presentation AS Presentation
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref IN (&IDs)
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionObjectIDs.FullName,
	|	ExtensionObjectIDs.Presentation
	|FROM
	|	Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|WHERE
	|	ExtensionObjectIDs.Ref IN (&IDs)");
	Query.SetParameter("IDs", AreasListIDs);
	Selection = Query.Execute().Select();
	
	While (Selection.Next()) Do
		Result.Add(Selection.FullName, Selection.Presentation);
	EndDo;
	
	Return Result;
EndFunction

&AtServerNoContext
Procedure FillAreasListRecursively(AreasList, SectionsTreeRows)
	
	For Each RowSection In SectionsTreeRows Do
		
		If RowSection.Check = MarkCheckBoxIsSelected() Then
			
			If RowSection.IsMetadataObject Then
				AreasList.Add(RowSection.MetadataObjectsList, RowSection.DataPath);
			EndIf;
			
		EndIf;
		
		FillAreasListRecursively(AreasList, RowSection.Rows);
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function SearchInSections(RadioButtonsEverywhereInSections)
	
	Return (RadioButtonsEverywhereInSections = 1);
	
EndFunction

#EndRegion

#Region Presentations

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Section.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("SearchSectionsTree.IsSubsection");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.FunctionsPanelSectionColor);
	
EndProcedure

#EndRegion

#Region InteractivePresentationLogic

&AtClientAtServerNoContext
Procedure UpdateAvailabilityOnSwitchEverywhereInSections(Item, SearchInSections)
	
	Item.Enabled = SearchInSections;
	
EndProcedure

&AtClient
Procedure ExpandCurrentSectionsTreeSection(Item)
	
	// Go to the section, with which you worked at previous settings.
	If Not IsBlankString(CurrentSection) And RowID <> 0 Then
		
		SearchSection = SearchSectionsTree.FindByID(RowID);
		If SearchSection = Undefined 
			Or SearchSection.Section <> CurrentSection Then
			Return;
		EndIf;
		
		SectionParent = SearchSection.GetParent();
		While SectionParent <> Undefined Do
			Items.SearchSectionsTree.Expand(SectionParent.GetID());
			SectionParent = SectionParent.GetParent();
		EndDo;
		
		Items.SearchSectionsTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NextItemCheckMarkValue(TreeItem)
	
	// 0 - Cleared Flag.
	// 1 - Raised Flag.
	// 2 - Raised Square.
	//
	// Override the graph of a finite-state machine.
	//
	// 1C:Enterprise runs a closed cycle when a mark is changed.
	// That is, it has a strong connectivity component:
	// 0-1-2-0-1-2-0-1...
	//
	//    0
	//   / \
	//  2 - 1
	//
	// Cycle: Cleared Flag - Raised Flag - Raised Square - Cleared Flag.
	//
	// The required behavior is a nondeterministic finite automaton with a strong connectivity component:
	// 0-1-0-1-0...
	//
	// That is, a Cleared Flag should transit into a Raised Flag, which transits into a Cleared Flag.
	//
	// Also:
	//
	// Cycles for sections:
	// a) 1-0-1-0-1...
	// b) 2-0-1-0-1-0-...
	//
	//      /\
	// 2 - 0 -1
	//
	// That is a Raised Square transits into a Cleared Flag.
	//
	// Cycles for metadata objects:
	// a) 1-0-1-0-1-0...
	// b) 2-1-0-1-0-1-0...
	//
	//      /\
	// 2 - 1 -0
	//
	// That is, a Raised Square transits into a Raised Flag.
	
	// At the time of checking, the platform has already changed the check box value.
	
	If TreeItem.IsMetadataObject Then
		// Previous check box value = 2: Square is selected.
		If TreeItem.Check = 0 Then
			Return MarkCheckBoxIsSelected();
		EndIf;
	EndIf;
	
	// Previous check box value = 1: Check box is selected.
	If TreeItem.Check = 2 Then 
		Return MarkCheckBoxIsNotSelected();
	EndIf;
	
	// In all other cases, the platform sets a value.
	Return TreeItem.Check;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkParentsItemsRecursively(TreeItem)
	
	Parent = TreeItem.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems1 = Parent.GetItems();
	If ParentItems1.Count() = 0 Then
		Parent.Check = MarkCheckBoxIsSelected();
	ElsIf TreeItem.Check = MarkSquare() Then
		Parent.Check = MarkSquare();
	Else
		Parent.Check = CheckMarkValueRelativeToNestedItems(Parent);
	EndIf;
	
	MarkParentsItemsRecursively(Parent);
	
EndProcedure

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function CheckMarkValueRelativeToNestedItems(TreeItem)
	
	NestedItemsState = NestedItemsState(TreeItem);
	
	HasMarkedItems   = NestedItemsState.HasMarkedItems;
	HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
	
	If TreeItem.IsMetadataObject Then 
		
		// Since the object should be returned, its status matters.
		// Do not reset the current flag.
		// 
		
		If TreeItem.Check = MarkCheckBoxIsSelected() Then 
			// Leave the check box selected, regardless of nested items.
			Return MarkCheckBoxIsSelected();
		EndIf;
		
		If TreeItem.Check = MarkCheckBoxIsNotSelected()
			Or TreeItem.Check = MarkSquare() Then 
			
			If HasMarkedItems Then
				Return MarkSquare();
			Else 
				Return MarkCheckBoxIsNotSelected();
			EndIf;
		EndIf;
		
	Else 
		
		// Sections' status is ignored as they depend on their children. 
		// 
		
		If HasMarkedItems Then
			
			If HasUnmarkedItems Then
				Return MarkSquare();
			Else
				Return MarkCheckBoxIsSelected();
			EndIf;
			
		EndIf;
		
		Return MarkCheckBoxIsNotSelected();
		
	EndIf;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function NestedItemsState(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	HasMarkedItems   = False;
	HasUnmarkedItems = False;
	
	For Each NestedItem In NestedItems Do
		
		If NestedItem.Check = MarkCheckBoxIsNotSelected() Then 
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkCheckBoxIsSelected() Then 
			HasMarkedItems = True;
			
			If NestedItem.IsMetadataObject Then 
				
				// Metadata objects marked for deletion can have
				// child items that are not marked for deletion.
				// To deal with this, elevate the child items to the parent's level.
				
				State = NestedItemsState(NestedItem);
				HasMarkedItems   = HasMarkedItems   Or State.HasMarkedItems;
				HasUnmarkedItems = HasUnmarkedItems Or State.HasUnmarkedItems;
			EndIf;
			
			Continue;
		EndIf;
		
		If NestedItem.Check = MarkSquare() Then 
			HasMarkedItems   = True;
			HasUnmarkedItems = True;
			Continue;
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("HasMarkedItems",   HasMarkedItems);
	Result.Insert("HasUnmarkedItems", HasUnmarkedItems);
	
	Return Result;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Function RequiredToMarkNestedItems(TreeItem)
	
	If TreeItem.IsMetadataObject Then 
		
		// If not all of the object's child items are selected, that indicates a user's choice.
		// Skip these items to avoid affecting the user's choice.
		
		NestedItemsState = NestedItemsState(TreeItem);
		
		HasMarkedItems   = NestedItemsState.HasMarkedItems;
		HasUnmarkedItems = NestedItemsState.HasUnmarkedItems;
		
		If HasMarkedItems And HasUnmarkedItems Then 
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Parameters:
//  TreeItem - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//
&AtClientAtServerNoContext
Procedure MarkNestedItemsRecursively(TreeItem)
	
	NestedItems = TreeItem.GetItems();
	
	For Each NestedItem In NestedItems Do
		
		NestedItem.Check = TreeItem.Check;
		MarkNestedItemsRecursively(NestedItem);
		
	EndDo;
	
EndProcedure

// Parameters:
//  ItemSearchSectionsTree - FormDataTreeItem:
//      * Check             - Number  - a required tree attribute.
//      * IsMetadataObject - Boolean - a required tree attribute.
//  CheckMarkValue - Number - a value being set.
//
&AtClientAtServerNoContext
Procedure MarkAllTreeItemsRecursively(ItemSearchSectionsTree, CheckMarkValue)
	
	TreeItemsCollection = ItemSearchSectionsTree.GetItems();
	
	For Each TreeItem In TreeItemsCollection Do
		TreeItem.Check = CheckMarkValue;
		MarkAllTreeItemsRecursively(TreeItem, CheckMarkValue);
	EndDo;
	
EndProcedure

#EndRegion

#Region BusinessLogic

&AtServerNoContext
Function IsRootSubsystem(MetadataObject)
	
	Return Metadata.Subsystems.Contains(MetadataObject);
	
EndFunction

&AtServerNoContext
Function MetadataObjectAvailable(MetadataObject)
	
	AvailableByRights = AccessRight("View", MetadataObject);
	AvailableByFunctionalOptions = Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject);
	
	MetadataProperties = New Structure("IncludeInCommandInterface");
	FillPropertyValues(MetadataProperties, MetadataObject);
	
	If MetadataProperties.IncludeInCommandInterface = Undefined Then 
		IncludeInCommandInterface = True; // Ignore if the property is missing.
	Else 
		IncludeInCommandInterface = MetadataProperties.IncludeInCommandInterface;
	EndIf;
	
	Return AvailableByRights And AvailableByFunctionalOptions 
		 And IncludeInCommandInterface;
	
EndFunction

&AtServerNoContext
Function SubordinateCatalogs(MetadataObject)
	
	Result = New Array;
	
	For Each Catalog In Metadata.Catalogs Do
		If Catalog.Owners.Contains(MetadataObject)
			And MetadataObjectAvailable(Catalog) Then 
			
			Result.Add(Catalog);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion