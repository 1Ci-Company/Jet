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
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);
	SetFilter(FilterParameters);
	
	FormFilterParameters = Common.CopyRecursive(Parameters.Filter);
	Parameters.Filter.Clear();
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.TaskDueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.StartDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.Date.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	If FormFilterParameters <> Undefined Then
		// Replacing fixed filter items to unavailable user settings.
		For Each FilterElement In FormFilterParameters Do
			CommonClientServer.SetDynamicListFilterItem(
				List, FilterElement.Key, FilterElement.Value);
		EndDo;
		
		FilterValue = Undefined;
		If FormFilterParameters.Property("Executed", FilterValue) Then
			Settings["ShowExecuted"] = FilterValue;
		EndIf;
		
		FormFilterParameters.Clear();
	EndIf;
	
	GroupByColumnOnServer(Settings["GroupingMode"]);
	SetFilter(Settings);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		RefreshTasksListOnServer();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

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
Procedure ShowExecutedOnChange(Item)
	
	SetFilterOnClient();
	
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

&AtClient
Procedure OpenBusinessProcess(Command)
	BusinessProcessesAndTasksClient.OpenBusinessProcess(Items.List);
EndProcedure

&AtClient
Procedure OpenTaskSubject(Command)
	BusinessProcessesAndTasksClient.OpenTaskSubject(Items.List);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StartDate.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("Executed");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("Text", "");
	
EndProcedure

&AtClient
Procedure GroupByColumn(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	If Not IsBlankString(GroupingMode) Then
		ShowExecuted = False;
		SetFilterOnClient();
	EndIf;
	List.Group.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupingField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtServer
Procedure GroupByColumnOnServer(Val AttributeColumnName)
	GroupingMode = AttributeColumnName;
	If Not IsBlankString(GroupingMode) Then
		ShowExecuted = False;
		FilterParameters = New Map();
		FilterParameters.Insert("ShowExecuted", ShowExecuted);	
		SetFilter(FilterParameters);	
	EndIf;
	List.Group.Items.Clear();
	If Not IsBlankString(AttributeColumnName) Then
		GroupingField = List.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Field = New DataCompositionField(AttributeColumnName);
	EndIf;
EndProcedure

&AtClient
Procedure SetFilterOnClient()
	
	FilterParameters = New Map();
	FilterParameters.Insert("ShowExecuted", ShowExecuted);	
	SetFilter(FilterParameters);	
	
EndProcedure

&AtServer
Procedure SetFilter(FilterParameters)
	
	If FilterParameters["ShowExecuted"] Then
		GroupByColumnOnServer("");
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Executed", False, , , Not FilterParameters["ShowExecuted"]);
		
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetMyTasksListParameters(List);
	Items.List.Refresh();
	// The color of the overdue tasks depends on the current date.
	// Therefore, refresh the conditional appearance.
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure AcceptForExecutionAvailable(FlagValue1)
	
	Items.AcceptForExecution.Enabled                      = FlagValue1;
	Items.ListContextMenuAcceptForExecution.Enabled = FlagValue1;
	Items.ListContextMenuCancelAcceptForExecution.Enabled = Not FlagValue1;

EndProcedure

#EndRegion