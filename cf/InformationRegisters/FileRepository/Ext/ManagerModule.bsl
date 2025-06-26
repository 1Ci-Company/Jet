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

Procedure WriteBinaryData(Val File, Val BinaryData) Export
	
	Hashing = New DataHashing(HashFunction.SHA256);

	IsEmptyBinaryData = (BinaryData = Undefined);
	If IsEmptyBinaryData Then
		EmptyBinaryData = GetBinaryDataFromString("");
		Hashing.Append(EmptyBinaryData);
		Size = EmptyBinaryData.Size();
	Else
		Hashing.Append(BinaryData);
		Size = BinaryData.Size();
	EndIf;
	Hash = GetBase64StringFromBinaryData(Hashing.HashSum);
	
	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("Catalog.BinaryDataStorage");
		LockItem.SetValue("Hash", Hash);
		Block.Lock();
		
		DeleteBinaryData(File);
		
		Query = New Query;
		Query.SetParameter("Hash", Hash);
		Query.SetParameter("Size", Size);
		Query.Text =
		"SELECT
		|	BinaryDataStorage.Ref AS Ref
		|FROM
		|	Catalog.BinaryDataStorage AS BinaryDataStorage
		|WHERE
		|	BinaryDataStorage.Hash = &Hash
		|	AND BinaryDataStorage.Size = &Size";
		Selection = Query.Execute().Select();
		BinaryDataStorageRef = Undefined;
		If Selection.Next() Then
			BinaryDataStorageRef = Selection.Ref;
		Else
			BinaryDataStorageObject = Catalogs.BinaryDataStorage.CreateItem();
			BinaryDataStorageObject.Size = Size;
			BinaryDataStorageObject.Hash = Hash;
			BinaryDataStorageObject.BinaryData = ?(IsEmptyBinaryData,
				Undefined, New ValueStorage(BinaryData, New Deflation(9)));
			BinaryDataStorageObject.Write();
			BinaryDataStorageRef = BinaryDataStorageObject.Ref;
		EndIf;
		
		Record = CreateRecordManager();
		Record.File = File;
		Record.BinaryDataStorage = BinaryDataStorageRef;
		Record.Write(False);
		
		CommitTransaction();	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteBinaryData(File) Export
	
	BeginTransaction();
	Try
		
		Query = New Query;
		Query.SetParameter("File", File);
		Query.Text =
		"SELECT TOP 1
		|	FileRepository.BinaryDataStorage AS BinaryDataStorage,
		|	FileRepository.BinaryDataStorage.Hash AS Hash
		|FROM
		|	InformationRegister.FileRepository AS FileRepository
		|WHERE
		|	FileRepository.File = &File";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Block = New DataLock;
			LockItem = Block.Add("Catalog.BinaryDataStorage");
			LockItem.SetValue("Hash", Selection.Hash);
			Block.Lock();
			
			Record = CreateRecordManager();
			Record.File = File;
			Record.Delete();
			
			Query = New Query;
			Query.SetParameter("BinaryDataStorage", Selection.BinaryDataStorage);
			Query.Text = 
			"SELECT TOP 1
			|	TRUE AS Validation
			|FROM
			|	InformationRegister.FileRepository AS FileRepository
			|WHERE
			|	FileRepository.BinaryDataStorage = &BinaryDataStorage";
			If Query.Execute().IsEmpty() Then
				CatObject = Selection.BinaryDataStorage.GetObject();
				CatObject.DataExchange.Load = True;
				CatObject.Delete();
			EndIf;
		EndIf;
		
		If Not FilesOperationsInternalCached.IsDeduplicationCompleted() Then
			Record = InformationRegisters.DeleteFilesBinaryData.CreateRecordManager();
			Record.File = File;
			Record.Delete();
		EndIf;
		
		CommitTransaction();	
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function FileURL1(File) Export

	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("File", File);
	Query.Text =
	"SELECT TOP 1
	|	FileRepository.BinaryDataStorage AS BinaryDataStorage
	|FROM
	|	InformationRegister.FileRepository AS FileRepository
	|WHERE
	|	FileRepository.File = &File";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Return GetURL(Selection.BinaryDataStorage, "BinaryData");
	EndIf;
	
	RecordKey = InformationRegisters.DeleteFilesBinaryData.CreateRecordKey(New Structure("File", File));
	
	Return GetURL(RecordKey, "FileBinaryData");
		
EndFunction

Procedure TransferData_(ShouldReportProgress = False, ResultAddress = Undefined) Export
	
	ProgressTemplate = NStr("en = '%1 (%2 MB) out of %3 (%4 MB) files processed';");
	TotalRecords = 0;
	TotalSizeMB = 0;
	If ShouldReportProgress Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	COUNT(*) AS TotalRecords
		|FROM
		|	InformationRegister.DeleteFilesBinaryData AS DeleteFilesBinaryData";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			TotalRecords = Selection.TotalRecords;
		EndIf;
		
		IncludeObjects = New Array();
		IncludeObjects.Add(Metadata.InformationRegisters.DeleteFilesBinaryData);
		TotalSizeMB = Round(GetDatabaseDataSize(, IncludeObjects) / 1024 / 1024, 0);
		Text = StringFunctionsClientServer.SubstituteParametersToString(ProgressTemplate, 
			0, 0, TotalRecords, TotalSizeMB);
		TimeConsumingOperations.ReportProgress(0, Text);
	EndIf;
	
	Selection = InformationRegisters.DeleteFilesBinaryData.Select();
	ProcessedRecordsCount = 0;
	ProcessedSizeCount = 0;
	Errors = New Array;
	While Selection.Next() Do
		File = Selection.File;
		FileDescription = String(File);
		BeginTransaction();
		Try
			
			Block = New DataLock();
			Block.Add("InformationRegister.DeleteFilesBinaryData").SetValue("File", File);
			Block.Add("InformationRegister.FileRepository").SetValue("File", File);
			Block.Lock();
			
			BinaryData = Selection.FileBinaryData.Get();
			If TypeOf(BinaryData) = Type("Picture") Then
				TempFileName = GetTempFileName();
				BinaryData.Write(TempFileName);
				BinaryData = New BinaryData(TempFileName);
				
				FileSystem.DeleteTempFile(TempFileName);
			ElsIf TypeOf(BinaryData) <> Type("BinaryData") Then
				ErrorText = NStr("en = 'Detected data type: %3. Expected data type: %4. Information register: %1. File: %2';");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					Metadata.InformationRegisters.DeleteFilesBinaryData.Name,
					FileDescription,
					TypeOf(BinaryData),
					Type("BinaryData"));
				ErrorDescription = New Structure;
				ErrorDescription.Insert("FileName", Common.SubjectString(File));
				ErrorDescription.Insert("Error", ErrorText);
				ErrorDescription.Insert("DetailErrorDescription", ErrorText);
				ErrorDescription.Insert("Version", File);
				Errors.Add(ErrorDescription);
				
				WriteLogEvent(NStr("en = 'Files.File deduplication error.';", Common.DefaultLanguageCode()),
					EventLogLevel.Error, , File, ErrorText);
				RollbackTransaction();
				Continue;
			EndIf;
			
			// @skip-check query-in-loop - Batch processing of a large amount of data. 
			If Not RecordExists(File) Then
				WriteBinaryData(File, BinaryData);
			EndIf;
			
			Record = InformationRegisters.DeleteFilesBinaryData.CreateRecordManager();
			Record.File = File;
			Record.Delete();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If ShouldReportProgress Then
			ProcessedRecordsCount = ProcessedRecordsCount + 1;
			ProcessedSizeCount = ProcessedSizeCount + BinaryData.Size();
			If ProcessedRecordsCount % 100 = 0 Then
				Percent = Round(ProcessedRecordsCount * 100 / TotalRecords);
				Text = StringFunctionsClientServer.SubstituteParametersToString(ProgressTemplate, 
					ProcessedRecordsCount, Round(ProcessedSizeCount / 1024 / 1024), TotalRecords, TotalSizeMB);
				TimeConsumingOperations.ReportProgress(Percent, Text);
			EndIf;
		EndIf;
	EndDo; 
	
	If ValueIsFilled(ResultAddress) And Errors.Count() > 0 Then
		PutToTempStorage(Errors, ResultAddress);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Update handlers.

// Registers objects, 
// for which it is necessary to update register records on the "InfobaseUpdate" exchange plan.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FilesVersions.Ref
		|FROM
		|	Catalog.FilesVersions AS FilesVersions
		|		LEFT JOIN InformationRegister.DeleteFilesBinaryData AS DeleteFilesBinaryData
		|		ON FilesVersions.Ref = DeleteFilesBinaryData.File
		|WHERE
		|	DeleteFilesBinaryData.File IS NULL
		|	AND FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InInfobase)
		|
		|ORDER BY
		|	FilesVersions.UniversalModificationDate DESC";
	
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DeleteFilesBinaryData.File AS Ref
	|FROM
	|	InformationRegister.DeleteFilesBinaryData AS DeleteFilesBinaryData
	|WHERE
	|	VALUETYPE(DeleteFilesBinaryData.File) = &FileType";
	
	Query.SetParameter("FileType", TypeOf(Catalogs.Files.EmptyRef()));
	
	ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
	InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.FilesVersions");
	If Selection.Count() > 0 Then
		TransferFilesBinaryDataToFileStorageInfoRegister(Selection);
	EndIf;
	
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.Files");
	If Selection.Count() > 0 Then
		ToCreateTheMissingVersionFile(Selection);
	EndIf;
	
	ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.FilesVersions")
		And InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.Files");
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#Region Private

Procedure TransferFilesBinaryDataToFileStorageInfoRegister(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("InformationRegister.DeleteStoredVersionFiles");
			DataLockItem.SetValue("FileVersion", Selection.Ref);
			DataLockItem.Mode = DataLockMode.Shared;
			DataLock.Lock();
			
			WriteFileVersionManager = InformationRegisters.DeleteStoredVersionFiles.CreateRecordManager();
			WriteFileVersionManager.FileVersion = Selection.Ref;
			WriteFileVersionManager.Read();
			
			BinaryData = WriteFileVersionManager.StoredFile.Get();
			// @skip-check query-in-loop - Batch processing of a large amount of data. 
			WriteBinaryData(Selection.Ref, BinaryData);

			InfobaseUpdate.MarkProcessingCompletion(Selection.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			// If processing for a document failed, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t process binary data of file %1. Reason:
				|%2';"), 
				Selection.Ref, ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
				EventLogLevel.Warning, Selection.Ref.Metadata(), Selection.Ref, 
				MessageText);
		EndTry;
		
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some binary data of the file: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
			EventLogLevel.Information, Metadata.Catalogs.FilesVersions,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Another batch of file binary data is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

Procedure ToCreateTheMissingVersionFile(Selection)
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	While Selection.Next() Do
		
		FileRef = Selection.Ref; // CatalogRef.Files
		RepresentationOfTheReference = String(FileRef);
		
		Block = New DataLock;
		LockItem = Block.Add("Catalog.Files");
		LockItem.SetValue("Ref", FileRef);
		
		LockItem = Block.Add("InformationRegister.DeleteFilesBinaryData");
		LockItem.SetValue("File", FileRef);
		
		BeginTransaction();
		Try
			Block.Lock();
			
			FileObject1 = FileRef.GetObject();
			
			If FileObject1 <> Undefined Then
				
				Version = Catalogs.FilesVersions.CreateItem();
				Version.SetNewCode();
				
				PropertiesSet = "Author,Owner,UniversalModificationDate,CreationDate,PictureIndex,
				|Description,DeletionMark, PathToFile,Size,Extension,TextExtractionStatus,
				|TextStorage, FileStorageType, Volume";
				
				FillPropertyValues(Version, FileObject1, PropertiesSet);
				Version.VersionNumber = 1;
				Version.Owner = FileRef;
				
				InfobaseUpdate.WriteObject(Version);
				
				FileObject1.CurrentVersion = Version.Ref;
				InfobaseUpdate.WriteObject(FileObject1);
				
				BinaryFilesData = InformationRegisters.DeleteFilesBinaryData.CreateRecordManager();
				BinaryFilesData.File = FileRef;
				BinaryFilesData.Read();
				If BinaryFilesData.Selected() Then
					// @skip-check query-in-loop - Batch processing of a large amount of data. 
					WriteBinaryData(Version.Ref, BinaryFilesData.FileBinaryData.Get());
					BinaryFilesData.Delete();
				EndIf;
				
			EndIf;
			
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			
			RollbackTransaction();
			// If processing for a file failed, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				FileRef,
				RepresentationOfTheReference,
				ErrorInfo());
			
		EndTry;
		
	EndDo;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some files: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
			Metadata.Catalogs.FilesVersions,,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Another batch of files is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
EndProcedure

Function RecordExists(File)
	
	Query = New Query;
	Query.SetParameter("File", File);
	Query.Text =
	"SELECT TOP 1
	|	1 AS Validation
	|FROM
	|	InformationRegister.FileRepository AS FileRepository
	|WHERE
	|	FileRepository.File = &File";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#EndRegion


#EndIf
