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
	
	If ValueIsFilled(Parameters.BusinessProcess) Then
		BusinessProcess = Parameters.BusinessProcess;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateFlowchart();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BusinessProcessOnChange(Item)
	UpdateFlowchart();
EndProcedure

&AtClient
Procedure FlowchartSelection(Item)
	OpenRoutePointTasksList();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RefreshExecute(Command)
	UpdateFlowchart();   
EndProcedure

&AtClient
Procedure TasksExecute(Command)
	OpenRoutePointTasksList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateFlowchart()
	
	If ValueIsFilled(BusinessProcess) Then
		Flowchart = BusinessProcess.GetObject().GetFlowchart();
	ElsIf BusinessProcess <> Undefined Then
		Flowchart = BusinessProcesses[BusinessProcess.Metadata().Name].GetFlowchart();
		Return;
	Else
		Flowchart = New GraphicalSchema;
		Return;
	EndIf;
	
	HasState = BusinessProcess.Metadata().Attributes.Find("State") <> Undefined;
	BusinessProcessProperties = Common.ObjectAttributesValues(
		BusinessProcess, "Author,Date,CompletedOn,Completed,Started" 
		+ ?(HasState, ",State", ""));
	FillPropertyValues(ThisObject, BusinessProcessProperties);
	If BusinessProcessProperties.Completed Then
		Status = NStr("en = 'Completed';");
		Items.StatusGroup.CurrentPage = Items.CompletedGroup;
	ElsIf BusinessProcessProperties.Started Then
		Status = NStr("en = 'Started';");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	Else	
		Status = NStr("en = 'Not started';");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	EndIf;
	If HasState Then
		Status = Status + ", " + Lower(State);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRoutePointTasksList()

#If WebClient Or MobileClient Then
	ShowMessageBox(, NStr("en = 'Cannot perform the operation in web client or mobile client.
		|Start thin client.';"));
	Return;
#EndIf
	ClearMessages();
	CurItem = Items.Flowchart.CurrentItem;

	If Not ValueIsFilled(BusinessProcess) Then
		CommonClient.MessageToUser(
			NStr("en = 'Specify a business process.';"),,
			"BusinessProcess");
		Return;
	EndIf;
	
	If CurItem = Undefined 
		Or	Not (TypeOf(CurItem) = Type("GraphicalSchemaItemActivity")
		Or TypeOf(CurItem) = Type("GraphicalSchemaItemSubBusinessProcess")) Then
		
		CommonClient.MessageToUser(
			NStr("en = 'To view the task list, select an action point or a nested business process of the flowchart.';"),,
			"Flowchart");
		Return;
	EndIf;

	FormCaption = NStr("en = 'Business process route point tasks';");
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("BusinessProcess,RoutePoint", BusinessProcess, CurItem.Value));
	FormParameters.Insert("FormCaption", FormCaption);
	FormParameters.Insert("ShowTasks", 0);
	FormParameters.Insert("FiltersVisibility", False);
	FormParameters.Insert("OwnerWindowLock", FormWindowOpeningMode.LockOwnerWindow);
	FormParameters.Insert("Task", String(CurItem.Value));
	FormParameters.Insert("BusinessProcess", String(BusinessProcess));
	OpenForm("Task.PerformerTask.ListForm", FormParameters, ThisObject, BusinessProcess);

EndProcedure

#EndRegion
