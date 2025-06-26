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

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	SelectionParameters = Parameters.SelectionParameters;
	SelectionParameters.FullRegistersNames = "InformationRegister.FilesInfo";
	SelectionParameters.SelectionMethod = InfobaseUpdate.SelectionMethodOfIndependentInfoRegistryMeasurements();
	
	File = "";
	AllRegisterRecordsProcessed = False;
	While Not AllRegisterRecordsProcessed Do
		
		Query = New Query;
		Query.Text =
		"SELECT DISTINCT TOP 1000
		|	FilesInfo.File AS File
		|FROM
		|	InformationRegister.FilesInfo AS FilesInfo
		|WHERE
		|	FilesInfo.File > &File
		|	AND FilesInfo.FileStorageType = VALUE(Enum.FileStorageTypes.EmptyRef)";
		Query.SetParameter("File", File);
		// @skip-check query-in-loop - Batch processing of data
		RegisterDimensions = Query.Execute().Unload();
		
		AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
		AdditionalParameters.IsIndependentInformationRegister = True;
		AdditionalParameters.FullRegisterName = "InformationRegister.FilesInfo";
		
		InfobaseUpdate.MarkForProcessing(Parameters, RegisterDimensions, AdditionalParameters);
		
		RecordsCount = RegisterDimensions.Count();
		If RecordsCount < 1000 Then
			AllRegisterRecordsProcessed = True;
		EndIf;
		
		If RecordsCount > 0 Then
			File = RegisterDimensions[RecordsCount-1].File;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	SelectedData = InfobaseUpdate.DataToUpdateInMultithreadHandler(Parameters);
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	BadData = New Map;
	RegisterMetadata = Metadata.InformationRegisters.FilesInfo;
	RegisterPresentation = RegisterMetadata.Presentation();
	FullObjectName = RegisterMetadata.FullName();
	
	For Each String In SelectedData Do
		RepresentationOfTheReference = String(String.File);
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add(String.File.Metadata().FullName());
			DataLockItem.SetValue("Ref", String.File);
			DataLockItem.Mode = DataLockMode.Shared;
			
			DataLockItem = DataLock.Add(FullObjectName);
			DataLockItem.SetValue("File", String.File);
			
			DataLock.Lock();
			
			RecordSet = InformationRegisters.FilesInfo.CreateRecordSet();
			RecordSet.Filter.File.Set(String.File);

			FileStorageType = Common.ObjectAttributeValue(String.File, "FileStorageType");
			If FileStorageType = Undefined Then
				BadData[String.Owner] = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""File info"" information register references a non-existent file: ""%1"".';"),
					String.File);
				InfobaseUpdate.MarkProcessingCompletion(RecordSet);
				CommitTransaction();
				Continue;
			EndIf;
			
			RecordSet.Read();
			For Each FileInfo1 In RecordSet Do
				FileInfo1.FileStorageType = FileStorageType;
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
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process information records on file %1. Reason:
				|%2';"), 
				RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			
			InfobaseUpdate.WriteErrorToEventLog(
				RegisterMetadata,
				RegisterPresentation,
				MessageText);
		EndTry;
		
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, FullObjectName);
	
	For Each UnprocessedObject In BadData Do
		InfobaseUpdate.FileIssueWithData(UnprocessedObject.Key, UnprocessedObject.Value);
	EndDo;

	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some of the file info: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.Files,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of file info is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
