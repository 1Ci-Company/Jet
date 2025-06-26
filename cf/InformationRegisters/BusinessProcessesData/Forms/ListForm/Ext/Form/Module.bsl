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
	
	BusinessProcessesAndTasksServer.SetBusinessProcessesAppearance(List.ConditionalAppearance);
	InfobaseUpdate.CheckObjectProcessed(Metadata.InformationRegisters.BusinessProcessesData.FullName(), 
		ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_PerformerTask" Then
		Items.List.Refresh();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Items.List.CurrentData <> Undefined Then
		ShowValue(, Items.List.CurrentData.BusinessProcess);
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData <> Undefined Then
		ShowValue(,Item.CurrentData.BusinessProcess);
		Cancel = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure DeletionMark(Command)
	BusinessProcessesAndTasksClient.BusinessProcessesListDeletionMark(Items.List);
EndProcedure

&AtClient
Procedure Flowchart(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.BusinessProcessFlowchart.Form", 
		New Structure("BusinessProcess", Items.List.CurrentData.BusinessProcess));
		
EndProcedure

&AtClient
Procedure BusinessProcessTasks(Command)
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenForm("Task.PerformerTask.Form.TasksByBusinessProcess",
		New Structure("FilterValue", Items.List.CurrentData.BusinessProcess));
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Completed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);
	
EndProcedure

#EndRegion