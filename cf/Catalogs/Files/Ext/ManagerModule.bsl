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

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchEditObjects

// Returns object attributes that can be edited using the bulk attribute modification data processor.
// 
//
// Returns:
//  Array of String
//
Function AttributesToEditInBatchProcessing() Export
	
	Return FilesOperations.AttributesToEditInBatchProcessing();
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// StandardSubsystems.AccessManagement

// Parameters:
//   Restriction - See AccessManagementOverridable.OnFillAccessRestriction.Restriction.
//
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	ObjectReadingAllowed(FileOwner)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ObjectUpdateAllowed(FileOwner)";
	
	Restriction.TextForExternalUsers1 =
	"AllowRead
	|WHERE
	|	CASE 
	|		WHEN VALUETYPE(FileOwner) = TYPE(Catalog.FilesFolders)
	|			THEN ObjectReadingAllowed(CAST(FileOwner AS Catalog.FilesFolders))
	|		ELSE ValueAllowed(CAST(Author AS Catalog.ExternalUsers))
	|	END
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	CASE 
	|		WHEN VALUETYPE(FileOwner) = TYPE(Catalog.FilesFolders)
	|			THEN ObjectUpdateAllowed(CAST(FileOwner AS Catalog.FilesFolders))
	|		ELSE ValueAllowed(CAST(Author AS Catalog.ExternalUsers))
	|	END";
	Restriction.ByOwnerWithoutSavingAccessKeysForExternalUsers = False;
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defines the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//  Parameters - See GenerateFromOverridable.BeforeAddGenerationCommands.Parameters
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
EndProcedure

// Intended for use by the AddGenerationCommands procedure in other object manager modules.
// Adds this object to the list of generation commands.
//
// Parameters:
//  GenerationCommands - See GenerateFromOverridable.BeforeAddGenerationCommands.GenerationCommands
//
// Returns:
//  ValueTableRow, Undefined - Details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("GenerateFrom");
		Return ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.Catalogs.Files);
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If Parameters.Count() = 0 Then
		SelectedForm = "Files"; // Opening the file list because the specific file is not specified.
		StandardProcessing = False;
	EndIf;
	If FormType = "ListForm" Then
		CurrentRow = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
		If TypeOf(CurrentRow) = Type("CatalogRef.Files") And Not CurrentRow.IsEmpty() Then
			StandardProcessing = False;
			FileOwner = Common.ObjectAttributeValue(CurrentRow, "FileOwner");
			If TypeOf(FileOwner) = Type("CatalogRef.FilesFolders") Then
				Parameters.Insert("Folder", FileOwner);
				SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			Else
				Parameters.Insert("FileOwner", FileOwner);
				SelectedForm = "DataProcessor.FilesOperations.Form.AttachedFiles";
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	AllFilesProcessed = False;
	Ref = "";
	
	SelectionParameters = Parameters.SelectionParameters;
	SelectionParameters.FullNamesOfObjects = "Catalog.Files";
	SelectionParameters.SelectionMethod = InfobaseUpdate.RefsSelectionMethod();
	
	While Not AllFilesProcessed Do
		
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1000
			|	Files.Ref AS Ref
			|FROM
			|	Catalog.Files AS Files
			|		LEFT JOIN InformationRegister.FilesInfo AS FilesInfo
			|		ON Files.Ref = FilesInfo.File
			|WHERE
			|	((Files.UniversalModificationDate = DATETIME(1, 1, 1, 0, 0, 0)
			|					AND Files.CurrentVersion <> VALUE(Catalog.FilesVersions.EmptyRef)
			|				OR Files.FileStorageType = VALUE(Enum.FileStorageTypes.EmptyRef))
			|				AND Files.Ref > &Ref
			|			OR FilesInfo.File IS NULL)
			|
			|ORDER BY
			|	Ref";
		
		Query.SetParameter("Ref", Ref);
		// @skip-check query-in-loop - Batch processing of a large amount of data.
		ReferencesArrray = Query.Execute().Unload().UnloadColumn("Ref");
		
		InfobaseUpdate.MarkForProcessing(Parameters, ReferencesArrray);
		
		RefsCount = ReferencesArrray.Count();
		If RefsCount < 1000 Then
			AllFilesProcessed = True;
		EndIf;
		
		If RefsCount > 0 Then
			Ref = ReferencesArrray[RefsCount - 1];
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion(Parameters) Export
	
	ProcessingCompleted = True;
	
	SelectedData = InfobaseUpdate.DataToUpdateInMultithreadHandler(Parameters);
	
	ObjectsProcessed = 0;
	ObjectsWithIssuesCount = 0;
	
	For Each String In SelectedData Do
		RepresentationOfTheReference = String(String.Ref);
		BeginTransaction();
		Try
			
			DataLockFile = New DataLock;
			DataLockItem = DataLockFile.Add("Catalog.Files");
			DataLockItem.SetValue("Ref", String.Ref);
			DataLockItem.Mode = DataLockMode.Shared;
			DataLockFile.Lock();
			
			CurrentVersion = Common.ObjectAttributeValue(String.Ref, "CurrentVersion");
			
			DataLock = New DataLock;
			DataLockItem = DataLock.Add("Catalog.FilesVersions");
			DataLockItem.SetValue("Ref", CurrentVersion);
			DataLockItem.Mode = DataLockMode.Shared;
			DataLock.Lock();
			
			CurrentVersionAttributes = Common.ObjectAttributesValues(CurrentVersion, 
				"UniversalModificationDate,FileStorageType");
			
			FileToUpdate = String.Ref.GetObject(); // CatalogObject.Files
			FileToUpdate.UniversalModificationDate = CurrentVersionAttributes.UniversalModificationDate;
			FileToUpdate.FileStorageType             = CurrentVersionAttributes.FileStorageType;
			
			RecordSet = InformationRegisters.FilesInfo.CreateRecordSet();
			RecordSet.Filter.File.Set(String.Ref);
			RecordSet.Read();
			If RecordSet.Count() = 0 Then
				FileInfo1 = RecordSet.Add();
				FillPropertyValues(FileInfo1, FileToUpdate);
				FileInfo1.File          = FileToUpdate.Ref;
				AuthorAndOwner               = Common.ObjectAttributesValues(FileToUpdate.Ref, "Author, FileOwner");
				FileInfo1.Author         = AuthorAndOwner.Author;
				FileInfo1.FileOwner = AuthorAndOwner.FileOwner;
				
				If FileToUpdate.SignedWithDS And FileToUpdate.Encrypted Then
					FileInfo1.SignedEncryptedPictureNumber = 2;
				ElsIf FileToUpdate.Encrypted Then
					FileInfo1.SignedEncryptedPictureNumber = 1;
				ElsIf FileToUpdate.SignedWithDS Then
					FileInfo1.SignedEncryptedPictureNumber = 0;
				Else
					FileInfo1.SignedEncryptedPictureNumber = -1;
				EndIf;
				InfobaseUpdate.WriteRecordSet(RecordSet);
			EndIf;
			
			InfobaseUpdate.WriteObject(FileToUpdate);
			
			InfobaseUpdate.MarkProcessingCompletion(String.Ref);
			ObjectsProcessed = ObjectsProcessed + 1;
			CommitTransaction();
		Except
			RollbackTransaction();
			// If you fail to process a document, try again.
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			
			InfobaseUpdate.WriteErrorToEventLog(
				String.Ref,
				RepresentationOfTheReference,
				ErrorInfo());
		EndTry;
		
	EndDo;
	
	If Not InfobaseUpdate.DataProcessingCompleted(Parameters.Queue, "Catalog.Files") Then
		ProcessingCompleted = False;
	EndIf;
	
	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) the files: %1';"), 
			ObjectsWithIssuesCount);
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(), 
			EventLogLevel.Information, , ,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Yet another batch of files is processed: %1';"),
				ObjectsProcessed));
	EndIf;
	
	Parameters.ProcessingCompleted = ProcessingCompleted;
	
EndProcedure

#EndRegion

#EndIf

