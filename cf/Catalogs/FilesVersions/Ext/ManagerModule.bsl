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

	AttributesToEdit = New Array;
	AttributesToEdit.Add("Comment");

	Return AttributesToEdit;

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
	|	ObjectReadingAllowed(Owner.FileOwner)
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	ObjectUpdateAllowed(Owner.FileOwner)";

	Restriction.TextForExternalUsers1 = Restriction.Text;

EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	If FormType = "ObjectForm" Then
		StandardProcessing = False;
		SelectedForm       = "DataProcessor.FilesOperations.Form.AttachedFileVersion";
	EndIf;
EndProcedure

#EndRegion

#Region Internal

// Registers the objects to be updated in the InfobaseUpdate exchange plan.
// 
//
// Parameters:
//  Parameters - Structure - Internal parameter to pass to the InfobaseUpdate.MarkForProcessing procedure.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export

	QueryText =
	"SELECT TOP 1000
	|	FilesVersions.Ref AS Ref
	|FROM
	|	Catalog.FilesVersions AS FilesVersions
	|WHERE
	|	FilesVersions.Ref > &Ref
	|	AND FilesVersions.FileStorageType = VALUE(Enum.FileStorageTypes.InVolumesOnHardDrive)
	|	AND (SUBSTRING(FilesVersions.PathToFile, 1, 1) = ""/""
	|	OR SUBSTRING(FilesVersions.PathToFile, 1, 1) = ""\"")
	|
	|ORDER BY
	|	Ref";

	Query = New Query(QueryText);
	Query.SetParameter("Ref", EmptyRef());
	Result = Query.Execute().Unload();
	While Result.Count() > 0 Do
		VersionsForProcessing = Result.UnloadColumn("Ref");
		InfobaseUpdate.MarkForProcessing(Parameters, VersionsForProcessing);
		Query.SetParameter("Ref", VersionsForProcessing[VersionsForProcessing.UBound()]);
		//@skip-check query-in-loop - Batch data registration for processing
		Result = Query.Execute().Unload();
	EndDo;

EndProcedure

Procedure ProcessVersionStoragePath(Parameters) Export

	VersionRef = InfobaseUpdate.SelectRefsToProcess(Parameters.Queue, "Catalog.FilesVersions");

	ObjectsWithIssuesCount = 0;
	ObjectsProcessed = 0;
	ErrorList = New Array;

	While VersionRef.Next() Do
		Result = RemoveExtraSeparator(VersionRef.Ref);

		If Result.Status = "Error" Then
			ObjectsWithIssuesCount = ObjectsWithIssuesCount + 1;
			ErrorList.Add(Result.ErrorText);
		Else
			ObjectsProcessed = ObjectsProcessed + 1;
			InfobaseUpdate.MarkProcessingCompletion(VersionRef.Ref);
		EndIf;

		If ObjectsProcessed + ObjectsWithIssuesCount = 1000 Then
			Break;
		EndIf;

	EndDo;

	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.Queue,
		"Catalog.FilesVersions");

	If ObjectsProcessed = 0 And ObjectsWithIssuesCount <> 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Couldn''t process (skipped) some file versions: %1
				 |%2';"), ObjectsWithIssuesCount, StrConcat(ErrorList, Chars.LF));
		Raise MessageText;
	Else
		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Information, Metadata.Catalogs.FilesVersions,, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Another batch of file versions is processed: %1';"), 
				ObjectsProcessed));
	EndIf;
EndProcedure

#EndRegion

#Region Private

Function RemoveExtraSeparator(VersionRef)

	Result =  New Structure;
	Result.Insert("Status", "NoUpdateRequired");
	Result.Insert("ErrorText", "");
	NewFilePath = Mid(Common.ObjectAttributeValue(VersionRef, "PathToFile"), 2);

	Block = New DataLock;
	LockItem = Block.Add("Catalog.FilesVersions");
	LockItem.SetValue("Ref", VersionRef);
	LockItem.Mode = DataLockMode.Shared;

	BeginTransaction();
	Try

		Block.Lock();
		VersionObject = VersionRef.GetObject();
		VersionObject.DataExchange.Load = True;
		VersionObject.PathToFile = NewFilePath;
		VersionObject.Write();

		Result.Status = "Updated";
		CommitTransaction();
	Except
		RollbackTransaction();

		ErrorInfo = ErrorInfo();

		Result.Status = "Error";
		Result.ErrorText = ErrorProcessing.BriefErrorDescription(ErrorInfo);

		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot process file version %1. Reason: %2';"), VersionRef,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));

		WriteLogEvent(InfobaseUpdate.EventLogEvent(),
			EventLogLevel.Warning, Metadata.Catalogs.FilesVersions, VersionRef, MessageText);

	EndTry;

	Return Result;

EndFunction

#EndRegion

#EndIf