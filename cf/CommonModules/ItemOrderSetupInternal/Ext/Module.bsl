///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Returns a value of an additional order attribute for a new object.
//
// Parameters:
//  Information - Structure - information on object metadata;
//  Parent   - AnyRef - a reference to the object parent;
//  Owner   - AnyRef - a reference to the object owner.
//
// Returns:
//  Number - Value of the additional order attribute.
//
Function GetNewAdditionalOrderingAttributeValue(Information, Parent, Owner) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query();
	
	QueryConditions = New Array;
	
	If Information.HasParent Then
		QueryConditions.Add("Table.Parent = &Parent");
		Query.SetParameter("Parent", Parent);
	EndIf;
	
	If Information.HasOwner Then
		QueryConditions.Add("Table.Owner = &Owner");
		Query.SetParameter("Owner", Owner);
	EndIf;
	
	AdditionalConditions = "TRUE";
	For Each Condition In QueryConditions Do
		AdditionalConditions = AdditionalConditions + " And " + Condition;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	Table.AddlOrderingAttribute AS AddlOrderingAttribute
	|FROM
	|	&Table AS Table
	|WHERE
	|	&AdditionalConditions
	|
	|ORDER BY
	|	AddlOrderingAttribute DESC";
	
	QueryText = StrReplace(QueryText, "&Table", Information.FullName);
	QueryText = StrReplace(QueryText, "&AdditionalConditions", AdditionalConditions);
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return ?(Not ValueIsFilled(Selection.AddlOrderingAttribute), 1, Selection.AddlOrderingAttribute + 1);
	
EndFunction

Function CheckItemsOrdering(MetadataTables)
	If Not AccessRight("Update", MetadataTables) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	QueryText = 
	"SELECT
	|	&Owner AS Owner,
	|	&Parent AS Parent,
	|	Table.AddlOrderingAttribute AS AddlOrderingAttribute,
	|	1 AS Count,
	|	Table.Ref AS Ref
	|INTO AllItems
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Owner,
	|	AllItems.Parent,
	|	AllItems.AddlOrderingAttribute,
	|	SUM(AllItems.Count) AS Count
	|INTO IndexStatistics
	|FROM
	|	AllItems AS AllItems
	|
	|GROUP BY
	|	AllItems.AddlOrderingAttribute,
	|	AllItems.Parent,
	|	AllItems.Owner
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IndexStatistics.Owner,
	|	IndexStatistics.Parent,
	|	IndexStatistics.AddlOrderingAttribute
	|INTO Duplicates
	|FROM
	|	IndexStatistics AS IndexStatistics
	|WHERE
	|	IndexStatistics.Count > 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllItems.Ref AS Ref
	|FROM
	|	AllItems AS AllItems
	|		INNER JOIN Duplicates AS Duplicates
	|		ON AllItems.AddlOrderingAttribute = Duplicates.AddlOrderingAttribute
	|			AND AllItems.Parent = Duplicates.Parent
	|			AND AllItems.Owner = Duplicates.Owner
	|
	|UNION ALL
	|
	|SELECT
	|	AllItems.Ref
	|FROM
	|	AllItems AS AllItems
	|WHERE
	|	AllItems.AddlOrderingAttribute = 0";
	
	Information = ItemOrderSetup.GetInformationForMoving(MetadataTables);
	
	QueryText = StrReplace(QueryText, "&Table", Information.FullName);
	
	ParentField = "Parent";
	If Not Information.HasParent Then
		ParentField = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Parent", ParentField);
	
	OwnerField = "Owner";
	If Not Information.HasOwner Then
		OwnerField = "1";
	EndIf;
	QueryText = StrReplace(QueryText, "&Owner", OwnerField);
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(Information.FullName);
			LockItem.SetValue("Ref", Selection.Ref);
			Block.Lock();
			
			Ref = Selection.Ref; // CatalogRef, ChartOfCharacteristicTypesRef - 
			Object = Ref.GetObject();
			Object.AddlOrderingAttribute = 0;
			Object.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Continue;
		EndTry;
	EndDo;
	
	Return True;
	
EndFunction

Function MoveItem(ItemList, CurrentItemRef, Direction) Export
	
	AccessParameters = AccessParameters("Update", CurrentItemRef.Metadata(), "Ref");
	If Not AccessParameters.Accessibility Then
		Return NStr("en = 'You are not authorized to change the item sequence.';");
	EndIf;
	
	Information = ItemOrderSetup.GetInformationForMoving(CurrentItemRef.Metadata());
	DataCompositionSettings = ItemList.GetPerformingDataCompositionSettings();
	
	// Hierarchical catalogs support filters by parent.
	// Otherwise, the display mode should be hierarchy or tree.
	RepresentedAsList = ItemList.Representation = TableRepresentation.List;
	If Information.HasParent And RepresentedAsList And Not ListContainsFilterByParent(DataCompositionSettings) Then
		Return NStr("en = 'To change the item sequence, set the view mode to Tree or Hierarchical list.';");
	EndIf;
	
	// For subordinate catalogs, filter by owner is to be set.
	If Information.HasOwner And Not ListContainsFilterByOwner(DataCompositionSettings) Then
		Return NStr("en = 'To change the item sequence, filter the list by the Owner field.';");
	EndIf;
	
	// Checking the Use flag of the AddlOrderingAttribute attribute for the item to be moved.
	If Information.HasGroups Then
		IsFolder = Common.ObjectAttributeValue(CurrentItemRef, "IsFolder");
		If IsFolder And Not Information.ForGroups Or Not IsFolder And Not Information.ForItems Then
			Return NStr("en = 'Cannot move the selected item.';");
		EndIf;
	EndIf;
	
	CheckItemsOrdering(CurrentItemRef.Metadata());
	
	DataCompositionSettings = ItemList.GetPerformingDataCompositionSettings(); // DataCompositionSettings
	ErrorText = CheckSortingInList(DataCompositionSettings);
	If Not IsBlankString(ErrorText) Then
		Return ErrorText;
	EndIf;
	
	DataCompositionGroup = DataCompositionSettings.Structure[0];
	
	DataCompositionField = DataCompositionGroup.Selection.SelectionAvailableFields.Items.Find("Ref").Field;
	HasFieldRef = False;
	For Each DataCompositionSelectedField In DataCompositionGroup.Selection.Items Do
		If TypeOf(DataCompositionSelectedField) = Type("DataCompositionAutoSelectedField") Then
			Continue;
		EndIf;
		If DataCompositionSelectedField.Field = DataCompositionField Then
			HasFieldRef = True;
			Break;
		EndIf;
	EndDo;
	If Not HasFieldRef Then
		DataCompositionSelectedField = DataCompositionGroup.Selection.Items.Add(Type("DataCompositionSelectedField"));
		DataCompositionSelectedField.Use = True;
		DataCompositionSelectedField.Field = DataCompositionField;
	EndIf;
	
	DataCompositionSchema = ItemList.GetPerformingDataCompositionScheme();
	ValueTree = ExecuteQuery(DataCompositionSchema, DataCompositionSettings);
	If ValueTree = Undefined Then
		Return NStr("en = 'To change the item sequence, reset the list settings
			| (Menu More - Use standard settings).';");
	EndIf;
	
	ValueTreeRow = ValueTree.Rows.Find(CurrentItemRef, "Ref", True);
	Parent = ValueTreeRow.Parent;
	If Parent = Undefined Then
		Parent = ValueTree;
	EndIf;
	
	CurrentItemIndex = Parent.Rows.IndexOf(ValueTreeRow);
	NeighborItemIndex = CurrentItemIndex;
	If Direction = ItemOrderSetup.ItemMovementDirectionUp() Then
		If CurrentItemIndex > 0 Then
			NeighborItemIndex = CurrentItemIndex - 1;
		EndIf;
	Else // Downward.
		If CurrentItemIndex < Parent.Rows.Count() - 1 Then
			NeighborItemIndex = CurrentItemIndex + 1;
		EndIf;
	EndIf;
	
	If CurrentItemIndex <> NeighborItemIndex Then
		NeighborRow = Parent.Rows.Get(NeighborItemIndex);
		NeighborItemRef = NeighborRow.Ref;
		
		If Not Information.HasGroups Or Information.ForGroups Or Not NeighborItemRef.IsFolder Then
			ErrorText = "";
			StandardProcessing = True;
			SSLSubsystemsIntegration.BeforeItemMoved(CurrentItemRef, NeighborItemRef, Direction, ErrorText, StandardProcessing);
			
			If StandardProcessing Then
				SwapItems(CurrentItemRef, NeighborItemRef, Information.FullName);
			Else
				Return ErrorText;
			EndIf;
		EndIf;
	EndIf;
	
	Return "";
EndFunction

Function ExecuteQuery(DataCompositionSchema, DataCompositionSettings)
	
	Result = New ValueTree;
	TemplateComposer = New DataCompositionTemplateComposer;
	Try
		DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
			DataCompositionSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	Except
		Return Undefined;
	EndTry;
	
	DataCompositionProcessor = New DataCompositionProcessor;
	DataCompositionProcessor.Initialize(DataCompositionTemplate);
	
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(Result);
	OutputProcessor.Output(DataCompositionProcessor);
	
	Return Result;
	
EndFunction

// Parameters:
//  FirstItemRef - CatalogRef
//                      - ChartOfCharacteristicTypesRef
//  SecondItemRef - CatalogRef
//                      - ChartOfCharacteristicTypesRef
//  TableName - String
//
Procedure SwapItems(FirstItemRef, SecondItemRef, TableName)
	
	Block = New DataLock;
	LockItem = Block.Add(TableName);
	LockItem.SetValue("Ref", FirstItemRef);
	LockItem = Block.Add(TableName);
	LockItem.SetValue("Ref", SecondItemRef);
	
	BeginTransaction();
	Try
		Block.Lock();
		LockDataForEdit(FirstItemRef);
		LockDataForEdit(SecondItemRef);
		
		FirstItemObject = FirstItemRef.GetObject();
		SecondItemObject = SecondItemRef.GetObject();
		
		FirstItemIndex = FirstItemObject.AddlOrderingAttribute;
		SecondItemIndex = SecondItemObject.AddlOrderingAttribute;
		
		FirstItemObject.AddlOrderingAttribute = SecondItemIndex;
		SecondItemObject.AddlOrderingAttribute = FirstItemIndex;
	
		FirstItemObject.Write();
		SecondItemObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function CheckSortingInList(DataCompositionSettings)
	
	OrderItems = DataCompositionSettings.Order.Items; // DataCompositionOrderItemCollection
	
	AdditionalOrderFields = New Array;
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField1"));
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField2"));
	AdditionalOrderFields.Add(New DataCompositionField("AdditionalOrderField3"));
	
	Item = Undefined;
	For Each OrderItem In OrderItems Do
		If OrderItem.Use Then
			Item = OrderItem;
			If AdditionalOrderFields.Find(Item.Field) <> Undefined Then
				Continue;
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	SortingCorrect = False;
	If Item <> Undefined And TypeOf(Item) = Type("DataCompositionOrderItem") Then
		If Item.OrderType = DataCompositionSortDirection.Asc Then
			If Item.Field = New DataCompositionField("AddlOrderingAttribute")
				Or Item.Field = New DataCompositionField("Ref.AddlOrderingAttribute") Then
				SortingCorrect = True;
			EndIf;
		EndIf;
	EndIf;
	
	AddlOrderingAttribute = DataCompositionSettings.Order.OrderAvailableFields.FindField(New DataCompositionField("AddlOrderingAttribute"));
	If Not SortingCorrect Then
		Return StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'To transfer items, sort the
			|list by the ""%1"" field (ascending)';"), AddlOrderingAttribute.Title);
	EndIf;
	
	Return "";
	
EndFunction

Function ListContainsFilterByOwner(DataCompositionSettings)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Owner"));
	RequiredFilters.Add(New DataCompositionField("Owner"));
	
	Return HasRequiredFilter(DataCompositionSettings.Filter, RequiredFilters);
	
EndFunction

Function ListContainsFilterByParent(DataCompositionSettings)
	
	RequiredFilters = New Array;
	RequiredFilters.Add(New DataCompositionField("Parent"));
	RequiredFilters.Add(New DataCompositionField("Parent"));
	
	Return HasRequiredFilter(DataCompositionSettings.Filter, RequiredFilters);
	
EndFunction

Function HasRequiredFilter(FiltersCollection, RequiredFilters)
	
	For Each Filter In FiltersCollection.Items Do
		If TypeOf(Filter) = Type("DataCompositionFilterItemGroup") Then
			FilterFound = HasRequiredFilter(Filter, RequiredFilters);
		Else
			FilterFound = RequiredFilters.Find(Filter.LeftValue) <> Undefined;
		EndIf;
		
		If FilterFound Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction


#EndRegion
