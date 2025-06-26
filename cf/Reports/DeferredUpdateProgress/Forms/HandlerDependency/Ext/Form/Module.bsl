///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtServer
Var PriorityTable, ProcessorQueue, ProgressProcessing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HandlerName = Parameters.Value;
	CachePriorities = Parameters.CachePriorities;
	
	SourceHandler = HandlerName;
	
	Title = NStr("en = 'Dependences of handler ""%1""';");
	Title = StringFunctionsClientServer.SubstituteParametersToString(Title, HandlerName);
	
	ProgressProcessing = GetFromTempStorage(Parameters.Cache).Copy(); // ValueTable
	ProgressProcessing.Columns.ObjectCount.Name = "LeftToProcess";
	HandlerData = ProgressProcessing.Find(HandlerName, "HandlerUpdates");
	
	PriorityTable = Undefined;
	If ValueIsFilled(CachePriorities) Then
		PriorityTable = GetFromTempStorage(CachePriorities);
	EndIf;
	If PriorityTable = Undefined Then
		HandlersDetails = DataProcessors.UpdateHandlersDetails.Create();
		HandlersDetails.ImportHandlers();
		
		PriorityTable = HandlersDetails.ExecutionPriorities.Unload(, "Procedure1,Procedure2,Order");
		PutToTempStorage(PriorityTable, CachePriorities);
	EndIf;
	
	Dependencies = FormAttributeToValue("DependencyTree");
	
	Query = New Query;
	Query.SetParameter("DeferredProcessingQueue", HandlerData.Queue);
	Query.SetParameter("DeferredHandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Parallel);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.DeferredProcessingQueue AS Queue,
		|	UpdateHandlers.Status AS Status
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.DeferredProcessingQueue < &DeferredProcessingQueue
		|	AND UpdateHandlers.DeferredHandlerExecutionMode = &DeferredHandlerExecutionMode";
	ProcessorQueue = Query.Execute().Unload();
	ProcessorQueue.Indexes.Add("HandlerName");
	
	HandlerConflicts = HandlerConflicts(HandlerName);
	
	MainHandler = Dependencies.Rows.Add();
	FillPropertyValues(MainHandler, HandlerParameters(HandlerName));
	MainHandler.TotalProgress = ProgressProcessing(MainHandler);
	
	SetHandlerStatus(MainHandler, HandlerData.Status);
	
	HandlerQueue = HandlerData.Queue;
	
	AddChildHandlers(MainHandler.Rows, HandlerName, HandlerConflicts, HandlerQueue);
	
	ValueToFormAttribute(Dependencies, "DependencyTree");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("Attachable_ExpandLines", 0.1, True);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RegisteredData(Command)
	CurrentData = Items.DependencyTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	TransmittedParameters = New Structure;
	TransmittedParameters.Insert("HandlerName", CurrentData.HandlerUpdates);
	TransmittedParameters.Insert("TotalObjectCount", CurrentData.TotalObjectCount);
	TransmittedParameters.Insert("LeftToProcess", CurrentData.LeftToProcess);
	TransmittedParameters.Insert("Progress", CurrentData.TotalProgress);
	TransmittedParameters.Insert("ProcessedForPeriod", CurrentData.ProcessedForInterval);
	OpenForm("Report.DeferredUpdateProgress.Form.RegisteredData", TransmittedParameters, , CurrentData.HandlerUpdates);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddChildHandlers(TreeRow, HandlerName, HandlerConflicts, HandlerQueue)
	
	For Each StringConflict In HandlerConflicts Do
		If StringConflict.Order = "Before" Then
			Continue;
		EndIf;
		
		SecondHandler = StringConflict.Procedure2;
		QueueStatus = QueueAndProcessorStatus(SecondHandler);
		If QueueStatus = Undefined
			Or QueueStatus.Queue >= HandlerQueue Then
			// This handler has a higher priority. Doesn't interrupt the runtime.
			Continue;
		EndIf;
		HandlerParameters = HandlerParameters(SecondHandler);
		If HandlerParameters = Undefined Then
			// Handler didn't register any data. Doesn't interrupt the runtime.
			Continue;
		EndIf;
		DependencyString = TreeRow.Add();
		FillPropertyValues(DependencyString, HandlerParameters);
		DependencyString.TotalProgress = ProgressProcessing(HandlerParameters);
		SetHandlerStatus(DependencyString, QueueStatus.Status);
		
		SecondHandlerConflicts = HandlerConflicts(SecondHandler);
		
		AddChildHandlers(DependencyString.Rows, SecondHandler, SecondHandlerConflicts, QueueStatus.Queue)
	EndDo;
	
EndProcedure

&AtServer
Function ProgressProcessing(HandlerParameters)
	
	Return Int(((HandlerParameters.TotalObjectCount - HandlerParameters.LeftToProcess)/HandlerParameters.TotalObjectCount*100)*100)/100;
	
EndFunction

&AtServer
Function HandlerParameters(HandlerName)
	HandlerData = ProgressProcessing.Find(HandlerName, "HandlerUpdates");
	Return HandlerData;
EndFunction

&AtServer
Function HandlerConflicts(HandlerName)
	
	RowFilter = New Structure;
	RowFilter.Insert("Procedure1", HandlerName);
	HandlerConflicts = PriorityTable.FindRows(RowFilter);
	
	Return HandlerConflicts;
	
EndFunction

&AtServer
Function QueueAndProcessorStatus(HandlerName)
	
	Result = ProcessorQueue.Find(HandlerName, "HandlerName");
	Return Result;
	
EndFunction

&AtServer
Procedure SetHandlerStatus(String, Status)
	
	If Status = Enums.UpdateHandlersStatuses.Completed Then
		String.Picture = PictureLib.AppearanceCircleGreen;
	ElsIf Status = Enums.UpdateHandlersStatuses.Error Then
		String.Picture = PictureLib.AppearanceCircleRed;
	Else
		String.Picture = PictureLib.AppearanceCircleEmpty;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_ExpandLines()
	
	MainProcessorBranch = DependencyTree.GetItems()[0];
	Id = MainProcessorBranch.GetID();
	Items.DependencyTree.Expand(Id, False);
	
EndProcedure

#EndRegion