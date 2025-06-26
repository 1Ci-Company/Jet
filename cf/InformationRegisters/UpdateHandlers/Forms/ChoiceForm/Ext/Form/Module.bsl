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
	Title = NStr("en = 'Select handlers for deferred update restart';");
	
	SetConditionalAppearance();
	FillHandlerList(Parameters.SelectedHandlers.UnloadValues());
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersHandlerList

&AtClient
Procedure HandlerListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	Item.CurrentData.Selected = Not Item.CurrentData.Selected;
EndProcedure

&AtClient
Procedure HandlerListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure HandlerListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group, Parameter)
	Cancel = True;
EndProcedure

&AtClient
Procedure HandlerListBeforeRowChange(Item, Cancel)
	If Item <> Undefined
		And Item.CurrentItem <> Undefined
		And Item.CurrentItem.Name = Items.Selected.Name Then
		Return;
	EndIf;
	
	
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Done(Command)
	Close(SelectedHandlers());
EndProcedure

&AtClient
Procedure Select(Command)
	
	For Each RowID In Items.HandlerList.SelectedRows Do
		SelectedRow = HandlerList.FindByID(RowID);
		SelectedRow.Selected = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure CancelSelect(Command)
	For Each RowID In Items.HandlerList.SelectedRows Do
		SelectedRow = HandlerList.FindByID(RowID);
		SelectedRow.Selected = False;
	EndDo;
EndProcedure

&AtClient
Procedure CancelAll(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("Selected", True);
	FoundRows = HandlerList.FindRows(SearchParameters);
	For Each String In FoundRows Do
		String.Selected = False;
	EndDo;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.HandlerName.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Status.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Version.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("HandlerList.Selected");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	Item.Appearance.SetParameterValue("BackColor", WebColors.HoneyDew);
	
EndProcedure

&AtServer
Procedure FillHandlerList(SelectedHandlers)
	Query = New Query;
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.SetParameter("DeferredHandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Parallel);
	Query.Text =
		"SELECT
		|	InformationRegisterUpdateHandlers.HandlerName AS HandlerName,
		|	InformationRegisterUpdateHandlers.Status AS Status,
		|	InformationRegisterUpdateHandlers.Version AS Version
		|FROM
		|	InformationRegister.UpdateHandlers AS InformationRegisterUpdateHandlers
		|WHERE
		|	InformationRegisterUpdateHandlers.Status = &Status
		|	AND InformationRegisterUpdateHandlers.DeferredHandlerExecutionMode = &DeferredHandlerExecutionMode";
	Handlers = Query.Execute().Unload();
	Handlers.Columns.Add("Selected", New TypeDescription("Boolean"));
	
	For Each SelectedHandler In SelectedHandlers Do
		FoundHandler = Handlers.Find(SelectedHandler, "HandlerName");
		FoundHandler.Selected = True;
	EndDo;
	
	ValueToFormAttribute(Handlers, "HandlerList");
EndProcedure

&AtServer
Function SelectedHandlers()
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Selected", True);
	SelectedHandlers = HandlerList.Unload(FilterParameters, "HandlerName");
	
	Return SelectedHandlers.UnloadColumn("HandlerName");
	
EndFunction

#EndRegion


