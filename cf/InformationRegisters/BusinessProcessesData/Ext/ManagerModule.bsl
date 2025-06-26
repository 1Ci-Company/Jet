///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ObjectReadingAllowed(Owner)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	FullObjectName = Metadata.InformationRegisters.BusinessProcessesData.FullName();

	SelectionParameters = Parameters.SelectionParameters;
	SelectionParameters.FullRegistersNames = FullObjectName;
	SelectionParameters.SelectionMethod = InfobaseUpdate.SelectionMethodOfIndependentInfoRegistryMeasurements();
	
	BusinessProcess = "";
	AllRegisterRecordsProcessed = False;
	While Not AllRegisterRecordsProcessed Do
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT TOP 1000
		|	BusinessProcessesData.Owner AS Owner
		|FROM
		|	InformationRegister.BusinessProcessesData AS BusinessProcessesData
		|WHERE
		|	BusinessProcessesData.Owner > &BusinessProcess
		|	AND BusinessProcessesData.State = VALUE(Enum.BusinessProcessStates.EmptyRef)";
		Query.SetParameter("BusinessProcess", BusinessProcess);
		// @skip-check query-in-loop - Batch processing of data
		RegisterDimensions = Query.Execute().Unload();
		
		AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
		AdditionalParameters.IsIndependentInformationRegister = True;
		AdditionalParameters.FullRegisterName = FullObjectName;
		InfobaseUpdate.MarkForProcessing(Parameters, RegisterDimensions, AdditionalParameters);
		
		RecordsCount = RegisterDimensions.Count();
		If RecordsCount < 1000 Then
			AllRegisterRecordsProcessed = True;
		EndIf;
		
		If RecordsCount > 0 Then
			BusinessProcess = RegisterDimensions[RecordsCount-1].Owner;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	SelectedData = InfobaseUpdate.DataToUpdateInMultithreadHandler(Parameters);
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	BadData = New Map;
	BusinessProcessStates = New Map;
	
	RegisterMetadata = Metadata.InformationRegisters.BusinessProcessesData;
	FullObjectName = RegisterMetadata.FullName();
	
	For Each String In SelectedData Do
		RepresentationOfTheReference = String(String.Owner);
		BeginTransaction();
		Try
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(String.Owner.Metadata().FullName());
			DataLockItem.SetValue("Ref", String.Owner);
			DataLockItem.Mode = DataLockMode.Shared;
			
			DataLockItem = DataLock.Add(FullObjectName);
			DataLockItem.SetValue("Owner", String.Owner);
			
			DataLock.Lock();
			
			HasStateAttribute = BusinessProcessStates[String.Owner.Metadata().FullName()];
			If HasStateAttribute = Undefined Then
				AttributeState = String.Owner.Metadata().Attributes.Find("State");
				HasStateAttribute = AttributeState <> Undefined 
					And AttributeState.Type.ContainsType(Type("EnumRef.BusinessProcessStates"));
				BusinessProcessStates[String.Owner.Metadata().FullName()] = HasStateAttribute;
			EndIf;	
			
			RecordSet = InformationRegisters.BusinessProcessesData.CreateRecordSet();
			RecordSet.Filter.Owner.Set(String.Owner);

			BusinessProcessState = ?(HasStateAttribute, 
				Common.ObjectAttributeValue(String.Owner, "State"), 
				Enums.BusinessProcessStates.Running);
			If BusinessProcessState = Undefined Then
				BadData[String.Owner] = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Business processes"" information register contains records of a non-existent business process: ""%1"".';"),
					String.Owner);
				InfobaseUpdate.MarkProcessingCompletion(RecordSet);
				CommitTransaction();
				Continue;
			EndIf;
			
			RecordSet.Read();
			For Each BusinessProcessInfo In RecordSet Do
				BusinessProcessInfo.State = BusinessProcessState;
			EndDo;
			
			If RecordSet.Modified() Then
				InfobaseUpdate.WriteRecordSet(RecordSet);
			Else
				InfobaseUpdate.MarkProcessingCompletion(RecordSet);
			EndIf;
				
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			InfobaseUpdate.WriteErrorToEventLog(
				String.Owner,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullObjectName);
	
	For Each UnprocessedObject In BadData Do
		InfobaseUpdate.FileIssueWithData(UnprocessedObject.Key, UnprocessedObject.Value);
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some information records about business processes: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			RegisterMetadata,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Another batch of information records about business processes is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
