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

// Registers objects, 
// for which it is necessary to update register records on the InfobaseUpdate exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	SelectionParameters = Parameters.SelectionParameters; // See InfobaseUpdate.AdditionalMultithreadProcessingDataSelectionParameters
	SelectionParameters.FullRegistersNames = Metadata.InformationRegisters.FilesExist.FullName();
	SelectionParameters.SelectionMethod = InfobaseUpdate.SelectionMethodOfIndependentInfoRegistryMeasurements();
	SelectionParameters.NameOfTheDimensionToSelect = "ObjectWithFiles";
	
	AdditionalParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AdditionalParameters.IsIndependentInformationRegister = True;
	AdditionalParameters.FullRegisterName = "InformationRegister.FilesExist";
	
	FirstQueryText =
		"SELECT DISTINCT
		|	AttachedFiles.FileOwner AS FileOwner
		|INTO FileOwnersForAnalysis
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.IsInternal = TRUE
		|	AND AttachedFiles.DeletionMark = FALSE
		|
		|INDEX BY
		|	FileOwner";
	
	SecondQueryText = 
		"SELECT TOP 1000
		|	FileOwnersForAnalysis.FileOwner AS ObjectWithFiles
		|FROM
		|	FileOwnersForAnalysis AS FileOwnersForAnalysis
		|		INNER JOIN InformationRegister.FilesExist AS FilesExist
		|		ON FileOwnersForAnalysis.FileOwner = FilesExist.ObjectWithFiles
		|WHERE
		|	NOT TRUE IN
		|				(SELECT TOP 1
		|					TRUE
		|				FROM
		|					&CatalogName AS AttachedFiles
		|				WHERE
		|					FileOwnersForAnalysis.FileOwner = AttachedFiles.FileOwner
		|					AND AttachedFiles.IsInternal = FALSE
		|					AND AttachedFiles.DeletionMark = FALSE)
		|	AND FilesExist.HasFiles = TRUE
		|	AND FileOwnersForAnalysis.FileOwner > &FileOwnerRef
		|
		|ORDER BY
		|	FileOwner";
	
	ObjectsWithFiles = Metadata.InformationRegisters.FilesExist.Dimensions.ObjectWithFiles.Type.Types();
	ProcessedObjectsWithFiles = New Map;
	
	For Each ObjectWithFiles In ObjectsWithFiles Do
		CatalogNames = FilesOperationsInternal.FileStorageCatalogNames(ObjectWithFiles, True);
				
		For Each KeyAndValue In CatalogNames Do
			
			If ProcessedObjectsWithFiles[KeyAndValue.Key] = True Then
				Continue;
			EndIf;
			If Common.HasObjectAttribute("IsInternal", Metadata.Catalogs[KeyAndValue.Key]) = False Then
				Continue;
			EndIf;
						
			Query = New Query;
			Query.TempTablesManager = New TempTablesManager;
			Query.Text =  StrReplace(FirstQueryText,"&CatalogName","Catalog." + KeyAndValue.Key);
			// @skip-check query-in-loop - Batch processing of data
			Query.Execute();
			
			Query.Text = StrReplace(SecondQueryText,"&CatalogName","Catalog." + KeyAndValue.Key);
			AllFilesOwnersProcessed = False;
			FileOwnerRef = "";
			
			While Not AllFilesOwnersProcessed Do
				
				Query.SetParameter("FileOwnerRef", FileOwnerRef);
				
				// @skip-check query-in-loop - Batch processing of data
				ValueTable = Query.Execute().Unload(); 
			
				InfobaseUpdate.MarkForProcessing(Parameters, ValueTable, AdditionalParameters);
				
				RefsCount = ValueTable.Count();
				If RefsCount < 1000 Then
					AllFilesOwnersProcessed = True;
				EndIf;
				
				If RefsCount > 0 Then
					FileOwnerRef = ValueTable[RefsCount-1].ObjectWithFiles;
				EndIf;
		
			EndDo;
			
			ProcessedObjectsWithFiles.Insert(KeyAndValue.Key,True);
		EndDo;	
	EndDo;
	
EndProcedure

// Update register records.
Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	// 
	DataToProcess = InfobaseUpdate.DataToUpdateInMultithreadHandler(Parameters);
	
	If DataToProcess.Count() = 0 Then
		Parameters.ProcessingCompleted = True;
		Return;	
	EndIf;
	
	FullRegisterName = "InformationRegister.FilesExist";
	
	AddlParameters = InfobaseUpdate.AdditionalProcessingMarkParameters();
	AddlParameters.IsIndependentInformationRegister = True;
	AddlParameters.FullRegisterName = FullRegisterName;
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("ObjectWithFiles");
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add(FullRegisterName);
		LockItem.DataSource = DataToProcess;
		LockItem.UseFromDataSource("ObjectWithFiles", "ObjectWithFiles");
		LockItem.Mode = DataLockMode.Exclusive;
		Block.Lock();
		
		Query = New Query;
		// 
		// 
		Query.Text = 
			"SELECT
			|	DataToProcess.ObjectWithFiles AS Ref
			|INTO DataForProcessing
			|FROM
			|	&DataToProcess AS DataToProcess
			|
			|INDEX BY
			|	Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	DataForProcessing.Ref AS Ref,
			|	FilesExist.ObjectWithFiles AS ObjectWithFiles,
			|	FilesExist.HasFiles AS HasFiles,
			|	FilesExist.ObjectID AS ObjectID
			|FROM
			|	DataForProcessing AS DataForProcessing
			|		LEFT JOIN InformationRegister.FilesExist AS FilesExist
			|		ON DataForProcessing.Ref = FilesExist.ObjectWithFiles";
		
		Query.SetParameter("DataToProcess", DataToProcess);
	
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();		
		
		UpdatedDataHasBeenSuccessfullyProcessed = True;
		
		While SelectionDetailRecords.Next() Do
			
			RecordSetFilesExist = Undefined;
			
			RepresentationOfTheReference = String(SelectionDetailRecords.Ref);
						
			If Not ValueIsFilled(SelectionDetailRecords.ObjectWithFiles) Then
				// 
				NewRow = DataTable.Add();
				NewRow.ObjectWithFiles = SelectionDetailRecords.Ref;
				
			ElsIf FilesOperationsInternal.OwnerHasFiles(SelectionDetailRecords.ObjectWithFiles) = True Then
				// 						
				FillPropertyValues(DataTable.Add(),SelectionDetailRecords);
				
			Else
				// The owner has only service files, and the register has a record.
				RecordSetFilesExist = CreateRecordSet();
				RecordSetFilesExist.Filter.ObjectWithFiles.Set(SelectionDetailRecords.ObjectWithFiles);
				FilesExistSetRecord = RecordSetFilesExist.Add();
				FillPropertyValues(FilesExistSetRecord,SelectionDetailRecords);
				
				FilesExistSetRecord.HasFiles = False;
				InfobaseUpdate.WriteRecordSet(RecordSetFilesExist, True);
					
			EndIf;
										
		EndDo;
				
		If DataTable.Count() Then
			InfobaseUpdate.MarkProcessingCompletion(DataTable,AddlParameters,Parameters.Queue);
		EndIf;
		
		MessageTemplate = NStr("en = 'Регистр сведений ""Наличие файлов"". Обработана порция объектов: %1';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, DataToProcess.Count());
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(), EventLogLevel.Information, , ,
				MessageText);
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		
		UpdatedDataHasBeenSuccessfullyProcessed = False;
	EndTry;

	If UpdatedDataHasBeenSuccessfullyProcessed = False Then
		ObjectsProcessed = 0;
		ObjectsWithIssuesCount = 0;

		ListOfDescriptions = New Array;
		ListOfDescriptions.Add(NStr("en = 'Не удалось обработать объекты по обработчику регистра сведений ""Наличие файлов"":';"));

		For Each CurrentItem In DataToProcess Do
			
			ExceptionReason = 0;
            RepresentationOfTheReference = String(CurrentItem.ObjectWithFiles);
			
			BeginTransaction();

			Try

				ExceptionReason = 1; // IObjectLock

				Block = New DataLock;
				
				// 
				LockItem = Block.Add("InformationRegister.FilesExist");
				LockItem.SetValue("ObjectWithFiles", CurrentItem.ObjectWithFiles);
				LockItem.Mode = DataLockMode.Exclusive;

				Block.Lock();
				
				ExceptionReason = 2; // 
				
				HasFiles = FilesOperationsInternal.OwnerHasFiles(CurrentItem.ObjectWithFiles);
				
				WriteSet = False;				
				If HasFiles = True Then
					// 						
					DataTable.Clear();
					FillPropertyValues(DataTable.Add(),CurrentItem);
				Else
												
					RecordSetFilesExist = CreateRecordSet();
					RecordSetFilesExist.Filter.ObjectWithFiles.Set(CurrentItem.ObjectWithFiles);
	                RecordSetFilesExist.Read();
					
					If RecordSetFilesExist.Count() = 1 Then
						// The owner has only service files, and the register has a record.
						FilesExistSetRecord = RecordSetFilesExist[0];
						If FilesExistSetRecord.HasFiles = True Then
							FilesExistSetRecord.HasFiles = False;
							WriteSet = True;
						Else
							DataTable.Clear();
							FillPropertyValues(DataTable.Add(),CurrentItem);
						EndIf;
					Else
						// The owner has only service files but there is no record in the "FilesExist" information register. Set the processing flag.					
						DataTable.Clear();
						FillPropertyValues(DataTable.Add(),CurrentItem);
					EndIf;
				EndIf;
				
				ExceptionReason = 3; // Record
				If WriteSet Then
					InfobaseUpdate.WriteRecordSet(RecordSetFilesExist, True);
				Else
					InfobaseUpdate.MarkProcessingCompletion(DataTable,AddlParameters,Parameters.Queue);
				EndIf;
				
				ObjectsProcessed = ObjectsProcessed + 1;
				CommitTransaction();

			Except

				RollbackTransaction();

				ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot update information on the availability of files %1. Reason:
						|%2';"), 
					RepresentationOfTheReference, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
				WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Warning,
					CurrentItem.ObjectWithFiles.Metadata(), CurrentItem.ObjectWithFiles, MessageText);
					
				If ExceptionReason = 2 Then
					
					InfobaseUpdate.FileIssueWithData(CurrentItem.ObjectWithFiles, MessageText);
					
					// 
					DataTable.Clear();
					FillPropertyValues(DataTable.Add(),CurrentItem);
					
					InfobaseUpdate.MarkProcessingCompletion(DataTable,AddlParameters);

				ElsIf ExceptionReason = 3 Then
					
					InfobaseUpdate.FileIssueWithData(CurrentItem.ObjectWithFiles, MessageText);
					// 
					
					DataTable.Clear();
					FillPropertyValues(DataTable.Add(),CurrentItem);
					
					InfobaseUpdate.MarkProcessingCompletion(DataTable,AddlParameters);
																
					Raise MessageText;
				EndIf;
				
			EndTry;

		EndDo;

		If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then

			ListOfDescriptions.Add(NStr("en = 'Всего пропущено: %1';"));
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(StrConcat(ListOfDescriptions, Chars.LF), 
				ObjectsWithIssuesCount);
			Raise MessageText;

		Else

			MessageTemplate = NStr("en = 'Регистр сведений ""Наличие файлов"". Обработана порция объектов: %1';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, ObjectsProcessed);
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(), EventLogLevel.Information, , ,
				MessageText);

		EndIf;
	
	EndIf;	
	
	Parameters.ProcessingCompleted = Not InfobaseUpdate.HasDataToProcess(Parameters.Queue,
		FullRegisterName);
					
EndProcedure

#EndRegion

#EndIf

