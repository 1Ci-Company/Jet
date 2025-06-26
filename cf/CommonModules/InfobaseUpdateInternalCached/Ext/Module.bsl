///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

// Returns the earliest infobase version used across all data areas.
//
// Returns:
//  String - for example, "2.3.1.4".
//
Function EarliestIBVersion() Export
	
	If Common.DataSeparationEnabled() Then
		
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		
		EarliestDataAreaVersion = ModuleInfobaseUpdateInternalSaaS.EarliestDataAreaVersion();
	Else
		EarliestDataAreaVersion = Undefined;
	EndIf;
	
	IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	
	If EarliestDataAreaVersion = Undefined Then
		EarliestIBVersion = IBVersion;
	Else
		If CommonClientServer.CompareVersions(IBVersion, EarliestDataAreaVersion) > 0 Then
			EarliestIBVersion = EarliestDataAreaVersion;
		Else
			EarliestIBVersion = IBVersion;
		EndIf;
	EndIf;
	
	Return EarliestIBVersion;
	
EndFunction

#EndRegion

#Region Private

// Checks if the infobase update is required when the configuration version is changed.
//
Function InfobaseUpdateRequired() Export
	
	If InfobaseUpdateInternal.UpdateRequired(
			Metadata.Version, InfobaseUpdateInternal.IBVersion(Metadata.Name)) Then
		Return True;
	EndIf;
	
	If Not InfobaseUpdateInternal.DeferredUpdateHandlersRegistered() Then
		Return True;
	EndIf;
	
	If InfobaseUpdateInternal.IsStartInfobaseUpdateSet() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns the map of names and IDs for deferred handlers
// and handler queues.
//
Function DeferredUpdateHandlerQueue() Export
	
	Handlers        = InfobaseUpdate.NewUpdateHandlerTable();
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For Each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If SubsystemDetails.DeferredHandlersExecutionMode <> "Parallel" Then
			Continue;
		EndIf;
		
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnAddUpdateHandlers(Handlers);
	EndDo;
	
	Filter = New Structure;
	Filter.Insert("ExecutionMode", "Deferred");
	DeferredHandlers = Handlers.FindRows(Filter);
	
	QueueByName          = New Map;
	QueueByID = New Map;
	For Each DeferredHandler In DeferredHandlers Do
		If DeferredHandler.DeferredProcessingQueue = 0 Then
			Continue;
		EndIf;
		
		QueueByName.Insert(DeferredHandler.Procedure, DeferredHandler.DeferredProcessingQueue);
		If ValueIsFilled(DeferredHandler.Id) Then
			QueueByID.Insert(DeferredHandler.Id, DeferredHandler.DeferredProcessingQueue);
		EndIf;
	EndDo;
	
	Result = New Map;
	Result.Insert("ByName", QueueByName);
	Result.Insert("ByID", QueueByID);
	
	Return New FixedMap(Result);
	
EndFunction

// Caches metadata object types when checking the availability
// of an object to be written on the content of the InfobaseUpdate exchange plan.
// 
// Returns:
//  Map
//
Function CacheForCheckingRegisteredObjects() Export
	
	Return New Map;
	
EndFunction

// The initial population of predefined data.

// Returns:
//  FixedMap of KeyAndValue:
//   * Key - MetadataObject
//   * Value - String
//
Function ObjectsWithInitialFilling() Export
	
	Result = New Map();
	
	SubsystemSettings = InfobaseUpdateInternal.SubsystemSettings();
	ObjectsWithInitialFilling = SubsystemSettings.ObjectsWithInitialFilling;
	For Each ObjectWithInitialPopulation In ObjectsWithInitialFilling Do
		Result.Insert(ObjectWithInitialPopulation, ObjectWithInitialPopulation.FullName());
	EndDo;
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion
