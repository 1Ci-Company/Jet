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
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	CommonClientServer.SetDynamicListFilterItem(
		List, "Executed", False);
			
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.TaskDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
	// Setting dynamic list filter.
	CommonClientServer.SetDynamicListFilterItem(
		List, "DeletionMark", False, DataCompositionComparisonType.Equal, , ,
		DataCompositionSettingsItemViewMode.Normal);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	GroupByColumnOnServer(Settings["GroupingMode"]);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Var_Group)
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Copy, 
		Parent, Var_Group);
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	If Item.CurrentData <> Undefined
		And Item.CurrentData.Property("AcceptedForExecution")
		And Not Item.CurrentData.AcceptedForExecution Then
			AcceptForExecutionAvailable(True);
	Else
		AcceptForExecutionAvailable(False);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

&AtClient
Procedure GroupByImportance(Command)
	GroupByColumn("Importance");
EndProcedure

&AtClient
Procedure GroupByNoGroup(Command)
	GroupByColumn("");
EndProcedure

&AtClient
Procedure GroupByRoutePoint(Command)
	GroupByColumn("RoutePoint");
EndProcedure

&AtClient
Procedure GroupByAuthor(Command)
	GroupByColumn("Author");
EndProcedure

&AtClient
Procedure GroupBySubject(Command)
	GroupByColumn("SubjectString");
EndProcedure

&AtClient
Procedure GroupByDueDate(Command)
	GroupByColumn("GroupDueDate");
EndProcedure

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
	AcceptForExecutionAvailable(False);
	
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	AcceptForExecutionAvailable(True);
	
EndProcedure

&AtClient
Procedure RefreshTasksList(Command)
	
	RefreshTasksListOnServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	// Hide the second line in the grouping.
	TaskListColumns = New Array();  // Array of FormField
	SelectAllSubordinateItems(Items.ColumnsGroup, TaskListColumns);
	For Each FormItem In TaskListColumns Do
		
		If FormItem = Items.Description Then
			Continue;
		EndIf;
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(FormItem.Name);
		
	EndDo;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("List.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Visible", False);
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure SelectAllSubordinateItems(Parent, Result)
	
	For Each FormItem In Parent.ChildItems Do
		
		Result.Add(FormItem);
		If TypeOf(FormItem) = Type("FormGroup") Then
			SelectAllSubordinateItems(FormItem, Result); 
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	List.Group.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupingField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnOnServer(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	List.Group.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupingField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	// The color of the overdue tasks depends on the current date.
	// Therefore, refresh the conditional appearance.
	SetConditionalAppearance();
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure AcceptForExecutionAvailable(FlagValue1)
	
	Items.AcceptForExecution.Enabled                      = FlagValue1;
	Items.ListContextMenuAcceptForExecution.Enabled = FlagValue1;
	Items.ListContextMenuCancelAcceptForExecution.Enabled = Not FlagValue1;

EndProcedure

#EndRegion
