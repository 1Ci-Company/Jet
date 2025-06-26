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

// For description of this function, see the InfobaseUpdateInternal module.
Function UpdateInfobase(OnClientStart = False, Restart = False, ExecuteDeferredHandlers1 = False) Export
	
	ParametersOfUpdate = InfobaseUpdateInternal.ParametersOfUpdate();
	ParametersOfUpdate.OnClientStart = OnClientStart;
	ParametersOfUpdate.Restart = Restart;
	ParametersOfUpdate.ExecuteDeferredHandlers1 = ExecuteDeferredHandlers1;
	
	Try
		Result = InfobaseUpdateInternal.UpdateInfobase(ParametersOfUpdate);
	Except
		// Switch to opening the data re-sync form before a startup with the options
		// "Sync and continue" and "Continue".
		If Common.SubsystemExists("StandardSubsystems.DataExchange")
		   And Common.IsSubordinateDIBNode() Then
			ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
			ModuleDataExchangeServer.EnableDataExchangeMessageImportRecurrenceBeforeStart();
		EndIf;
		Raise;
	EndTry;
	
	Restart = ParametersOfUpdate.Restart;
	Return Result;
	
EndFunction

// Unlocks file infobase.
Procedure RemoveFileInfobaseLock() Export
	
	If Not Common.FileInfobase() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnections = Common.CommonModule("IBConnections");
		ModuleIBConnections.AllowUserAuthorization();
	EndIf;
	
EndProcedure

Function ReportDetailsData(DetailsData, DetailsIndex, Cache = Undefined, CachePriorities = Undefined) Export
	If Not ValueIsFilled(DetailsData) Then
		Return Undefined;
	EndIf;
	
	Data = GetFromTempStorage(DetailsData);
	If DetailsIndex = Undefined Then
		Return Undefined;
	EndIf;
	Details = Data.Items[DetailsIndex].GetFields();
	If Details.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	StartUpdates = UpdateInfo.DeferredUpdateStartTime;
	
	DetailsValue = Details.Get(0);
	Result = New Structure;
	Result.Insert("FieldName", DetailsValue.Field);
	Result.Insert("Value", DetailsValue.Value);
	Result.Insert("StartUpdates", StartUpdates);
	Result.Insert("Cache", Cache);
	Result.Insert("CachePriorities", CachePriorities);
	
	Return Result;
EndFunction

Procedure UnlockObjectToEdit(ObjectsArray) Export
	
	MetadataAndFilterByData = Undefined;
	For Each Object In ObjectsArray Do
		MetadataAndFilterByData = InfobaseUpdate.MetadataAndFilterByData(Object);
	EndDo;
	
	If MetadataAndFilterByData = Undefined Then
		Return;
	EndIf;
	
	Block = New DataLock;
	Block.Add("Constant.LockedObjectsInfo");
	BeginTransaction();
	Try
		Block.Lock();
		
		LockedObjectsInfo = InfobaseUpdateInternal.LockedObjectsInfo();
		UnlockedObjects = LockedObjectsInfo.UnlockedObjects[MetadataAndFilterByData.FullName]; // Array
		If UnlockedObjects = Undefined Then
			UnlockedObjects = CommonClientServer.ValueInArray(MetadataAndFilterByData.Filter);
		Else
			UnlockedObjects.Add(MetadataAndFilterByData.Filter);
		EndIf;
		
		LockedObjectsInfo.UnlockedObjects[MetadataAndFilterByData.FullName] = UnlockedObjects;
		InfobaseUpdateInternal.WriteLockedObjectsInfo(LockedObjectsInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion
