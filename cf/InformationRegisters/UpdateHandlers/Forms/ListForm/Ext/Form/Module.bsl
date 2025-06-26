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
	
	If ValueIsFilled(Parameters.ExecutionMode) Then
		CommonClientServer.SetDynamicListFilterItem(List, "ExecutionMode", Parameters.ExecutionMode);
		FilterExecutionMode = Parameters.ExecutionMode;
	EndIf;
	
	SeparatedDataUsageAvailable = Common.SeparatedDataUsageAvailable();
	
	If SeparatedDataUsageAvailable
		And Users.IsFullUser() Then
		Items.DataAreaAuxiliaryData.Visible = False;
	EndIf;

	Items.DataAreasUpdateProgress.Visible = Not SeparatedDataUsageAvailable;
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		UpdateProgressReport = ModuleInfobaseUpdateInternalSaaS.UpdateProgressReport();
		SetQueryText();
	Else
		Items.DataAreasUpdateProgress.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Upper(EventName) = Upper("Write_UpdateHandlers") Then
		Items.List.Refresh();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterStatusOnChange(Item)
	CommonClientServer.SetDynamicListFilterItem(List, "Status", FilterStatus, , , ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
Procedure FilterExecutionModeOnChange(Item)
	CommonClientServer.SetDynamicListFilterItem(List, "ExecutionMode", FilterExecutionMode, , , ValueIsFilled(FilterExecutionMode));
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	HandlerName = Item.CurrentData.HandlerName;
	Filter = New Structure("HandlerName", HandlerName);
	If Not SeparatedDataUsageAvailable Then
		Filter.Insert("DataAreaAuxiliaryData", Item.CurrentData.DataAreaAuxiliaryData);
	EndIf;
	
	ValueType = Type("InformationRegisterRecordKey.UpdateHandlers");
	WriteParameters = New Array(1);
	WriteParameters[0] = Filter;
	
	RecordKey = RecordKey(ValueType, WriteParameters);
	ShowValue(Undefined, RecordKey);
EndProcedure

&AtServer
Function RecordKey(ValueType, WriteParameters)
	
	Return New(ValueType, WriteParameters);
	
EndFunction

&AtClient
Procedure DataAreasUpdateProgressClick(Item)
	OpenForm(UpdateProgressReport);
EndProcedure

&AtServer
Procedure SetQueryText()
	
	QueryText =
		"SELECT
		|	UpdateHandlersOverridable.HandlerName,
		|	UpdateHandlersOverridable.Status,
		|	UpdateHandlersOverridable.Version,
		|	UpdateHandlersOverridable.LibraryName,
		|	UpdateHandlersOverridable.ProcessingDuration,
		|	UpdateHandlersOverridable.ExecutionMode,
		|	UpdateHandlersOverridable.RegistrationVersion,
		|	UpdateHandlersOverridable.VersionOrder,
		|	UpdateHandlersOverridable.Id,
		|	UpdateHandlersOverridable.AttemptCount,
		|	UpdateHandlersOverridable.ExecutionStatistics,
		|	UpdateHandlersOverridable.ErrorInfo,
		|	UpdateHandlersOverridable.Comment,
		|	UpdateHandlersOverridable.Priority,
		|	UpdateHandlersOverridable.CheckProcedure,
		|	UpdateHandlersOverridable.UpdateDataFillingProcedure,
		|	UpdateHandlersOverridable.DeferredProcessingQueue,
		|	UpdateHandlersOverridable.ExecuteInMasterNodeOnly,
		|	UpdateHandlersOverridable.RunAlsoInSubordinateDIBNodeWithFilters,
		|	UpdateHandlersOverridable.Multithreaded,
		|	UpdateHandlersOverridable.BatchProcessingCompleted,
		|	UpdateHandlersOverridable.UpdateGroup,
		|	UpdateHandlersOverridable.StartIteration,
		|	UpdateHandlersOverridable.DataToProcess,
		|	UpdateHandlersOverridable.DeferredHandlerExecutionMode,
		|	UpdateHandlersOverridable.ObjectsToChange,
		|	UpdateHandlersOverridable.DataAreaAuxiliaryData AS DataAreaAuxiliaryData,
		|	UpdateHandlersOverridable.DataRegistrationDuration
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlersOverridable";  
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.QueryText = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

#EndRegion

