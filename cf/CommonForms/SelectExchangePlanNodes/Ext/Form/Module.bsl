///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

////////////////////////////////////////////////////////////////////////////////
// Choice form for "exchange plan node" fields.
//  
////////////////////////////////////////////////////////////////////////////////

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Processing the standard parameters.
	If Not Parameters.CloseOnChoice Then
		PickMode = True;
		If Parameters.MultipleChoice Then
			MultipleChoice = True;
		EndIf;
	EndIf;
	
	If TypeOf(Parameters.ExchangePlansForSelection) = Type("Array") Then
		ExchangePlansInUse = New Array;
		For Each Item In Parameters.ExchangePlansForSelection Do
			If TypeOf(Item) = Type("String") Then
				ExchangePlanMetadata = Common.MetadataObjectByFullName(Item);
				If ExchangePlanMetadata = Undefined Then
					ExchangePlanMetadata = Common.MetadataObjectByFullName("ExchangePlan." + Item);
				EndIf;
			ElsIf TypeOf(Item) = Type("Type") Then
				ExchangePlanMetadata = Metadata.FindByType(Item);
			Else
				ExchangePlanMetadata = Metadata.FindByType(TypeOf(Item));
			EndIf;
			If ExchangePlanMetadata <> Undefined Then
				ExchangePlansInUse.Add(ExchangePlanMetadata);
			EndIf;
		EndDo;
		PopulateExchangePlans(ExchangePlansInUse);
	Else
		PopulateExchangePlans(Metadata.ExchangePlans);
	EndIf;
	
	If PickMode Then
		Title = NStr("en = 'Select exchange plan nodes';");
	EndIf;
	If MultipleChoice Then
		Items.ExchangePlansNodes.SelectionMode = TableSelectionMode.MultiRow;
	EndIf;
	
	FoundRows = ExchangePlansNodes.FindRows(New Structure("Node", Parameters.CurrentRow));	
	If FoundRows.Count() > 0 Then
		Items.ExchangePlansNodes.CurrentRow = FoundRows[0].GetID();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExchangePlansNodes

&AtClient
Procedure ExchangePlansNodesSelection(Item, RowSelected, Field, StandardProcessing)
	
	If MultipleChoice Then
		SelectionValue = New Array;
		SelectionValue.Add(ExchangePlansNodes.FindByID(RowSelected).Node);
		NotifyChoice(SelectionValue);
	Else
		NotifyChoice(ExchangePlansNodes.FindByID(RowSelected).Node);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	
	If MultipleChoice Then
		SelectionValue = New Array;
		For Each SelectedRow In Items.ExchangePlansNodes.SelectedRows Do
			SelectionValue.Add(ExchangePlansNodes.FindByID(SelectedRow).Node)
		EndDo;
		NotifyChoice(SelectionValue);
	Else
		CurrentData = Items.ExchangePlansNodes.CurrentData;
		If CurrentData = Undefined Then
			ShowMessageBox(, NStr("en = 'No nodes are selected.';"));
		Else
			NotifyChoice(CurrentData.Node);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure PopulateExchangePlans(Var_ExchangePlans)
	
	QueriesTexts = New Array;
	
	For Each MetadataObject In Var_ExchangePlans Do
		
		If MetadataObject = Undefined Or Not Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		
		If Not AccessRight("View", MetadataObject) Then
			Continue;
		EndIf;
		
		ExchangePlanRef = Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef();

		QueryText = 
			"SELECT ALLOWED
			|	&ExchangePlanEmptyRef AS EmptyRef,
			|	&ExchangePlanPresentation AS ExchangePlanPresentation,
			|	ExchangePlanTable.Ref AS Ref,
			|	ExchangePlanTable.Presentation AS Presentation
			|FROM
			|	&ExchangePlanTable AS ExchangePlanTable
			|WHERE
			|	NOT ExchangePlanTable.ThisNode";
		QueryText = StrReplace(QueryText, "&ExchangePlanEmptyRef", 
			"VALUE(" + MetadataObject.FullName() + ".EmptyRef)"); // @query-part-2
		QueryText = StrReplace(QueryText, "&ExchangePlanPresentation", """" + MetadataObject.Presentation() + """");
		QueryText = StrReplace(QueryText, "&ExchangePlanTable", MetadataObject.FullName());
		If QueriesTexts.Count() > 0 Then
			QueryText = StrReplace(QueryText, "SELECT ALLOWED", "Select"); // @query-part
		EndIf;	

		QueriesTexts.Add(QueryText);
		
		If Parameters.SelectAllNodes Then
			NewRow = ExchangePlansNodes.Add();
			NewRow.ExchangePlan              = ExchangePlanRef;
			NewRow.ExchangePlanPresentation = MetadataObject.Synonym;
			NewRow.Node                    = ExchangePlanRef;
			NewRow.NodePresentation       = NStr("en = '<All infobases>';");
		EndIf;
		
	EndDo; 
	
	If QueriesTexts.Count() = 0 Then
		Return;
	EndIf;
	
	QueryText = StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF);
	Query = New Query(QueryText);	
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = ExchangePlansNodes.Add();
		NewRow.ExchangePlan              = Selection.EmptyRef;
		NewRow.ExchangePlanPresentation = Selection.ExchangePlanPresentation;
		NewRow.Node                    = Selection.Ref;
		NewRow.NodePresentation       = Selection.Presentation;
	EndDo;
	
	ExchangePlansNodes.Sort("ExchangePlanPresentation Asc");
	
EndProcedure

#EndRegion
