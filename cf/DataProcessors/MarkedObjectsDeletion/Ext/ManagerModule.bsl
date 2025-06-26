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

#Region Private

// Delete the objects marked for deletion.
// 
// Parameters:
//  DeletionParameters - See DeletionParameters
//  JobID - UUID
// 
// Returns:
//   See DeletionResult
//
Function ToDeleteMarkedObjects(DeletionParameters, JobID = Undefined) Export
	
	If Not Users.IsFullUser() Then
		Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
	EndIf;
	
	Measurement = CurrentUniversalDateInMilliseconds();	
	MarkedObjectsDeletionOverridable.BeforeSearchForItemsMarkedForDeletion(DeletionParameters); // ACC:222 For backward compatibility.
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(True);
	EndIf;
	
	Try
		ObjectsToDelete = DeletionParameters.UserObjects;
		DeletionResult = DeletionResult(ObjectsToDelete, DeletionParameters);
		
		// To cancel the job on the client side.
		If ValueIsFilled(JobID)Then
			DeletionResult.JobID = JobID;
		EndIf;
		
		If DeletionResult.Exclusively Then
			DeleteMarkedObjectsExclusively(ObjectsToDelete, DeletionResult);
		Else
			DeleteMarkedObjectsCompetitively(ObjectsToDelete, DeletionResult);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.DisableAccessKeysUpdate(False);
		EndIf;
	Except	
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.DisableAccessKeysUpdate(False);
		EndIf;
		Raise;
	EndTry;
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.AfterDeleteMarkedObjects(DeletionResult);
	EndIf;
	
	Measurement = CurrentUniversalDateInMilliseconds() - Measurement;
	SendStatistics1(DeletionParameters.Mode, Measurement, DeletionResult.Total);
	
	Return DeletionResult;
EndFunction

#Region CompetitiveDeletion

// Parameters:
//  ObjectsToDelete - Array of AnyRef
//   DeletionParameters - See DeletionResult
//
Procedure DeleteMarkedObjectsCompetitively(ObjectsToDelete, DeletionParameters)
	
	MetadataInfo = MetadataInfo(DeletionParameters, ObjectsToDelete);
	ObjectsToDelete = ObjectsToDelete(ObjectsToDelete, MetadataInfo);
	ProcessingResult = ProcessObjectsToDelete(DeletionParameters, ObjectsToDelete, MetadataInfo);
	
	ReflectUsageInstances(DeletionParameters, ProcessingResult.UsageInstances);
	ReflectNotDeletedItems(DeletionParameters, ProcessingResult.NotDeletedObjects);
	DeletionParameters.Trash = New Array(New FixedArray(ProcessingResult.DeletedObjects));
EndProcedure

#Region ResultConversionToFormat

// Parameters:
//   DeletionParameters - See DeletionResult
//   NotTrash - See ObjectsToDeletePackage
//
Procedure ReflectNotDeletedItems(DeletionParameters, NotTrash)

	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		NotTrash.UnloadColumn("ItemToDeleteRef"), "DataVersion");
	For Each Item In NotTrash Do

		// An object can be deleted if its parent object is marked for deletion.
		If ObjectDeleted(Item.ItemToDeleteRef, DataVersions) Then
			Continue;
		EndIf;
		
		DeletionParameters.NotTrash.Add(Item.ItemToDeleteRef);
		If Item.DeletionResult <> DeletionResultCodes().NoMarkedForDeletion Then
			InformationRegisters.NotDeletedObjects.Add(Item.ItemToDeleteRef);
		EndIf;
		
		If Item.DeletionResult = DeletionResultCodes().ErrorOnDelete Then
			Cause = DeletionParameters.ObjectsPreventingDeletion.Add();
			Cause.ItemToDeleteRef = Item.ItemToDeleteRef;
			Cause.ErrorDescription = ErrorProcessing.BriefErrorDescription(Item.ErrorInfo) + Item.Messages;
			Cause.DetailedErrorDetails = ErrorProcessing.DetailErrorDescription(Item.ErrorInfo);
		ElsIf Item.DeletionResult = DeletionResultCodes().NoMarkedForDeletion Then 	
			Cause = DeletionParameters.ObjectsPreventingDeletion.Add();
			Cause.ItemToDeleteRef = Item.ItemToDeleteRef;
			Cause.ErrorDescription = NStr("en = 'The object being deleted is not marked for deletion.';");
		EndIf;

	EndDo;
	
EndProcedure

Procedure ReflectUsageInstances(DeletionParameters, UsageInstances)

	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		UsageInstances.UnloadColumn("UsageInstance1"), "DataVersion");
	ObjectsPreventingDeletion = DeletionParameters.ObjectsPreventingDeletion;
	For Each UsageInstanceInfo1 In UsageInstances Do
		If ObjectDeleted(UsageInstanceInfo1.UsageInstance1, DataVersions) Then
			Continue;
		EndIf;
		
		Cause = ObjectsPreventingDeletion.Add();
		Cause.ItemToDeleteRef    = UsageInstanceInfo1.ItemToDeleteRef;
		Cause.UsageInstance1 = UsageInstanceInfo1.UsageInstance1;
		Cause.Metadata = UsageInstanceInfo1.Metadata;
	EndDo;
	
	ColumnsThatPreventDeletion = New Array;
	For Each Column In ObjectsPreventingDeletion.Columns Do
		ColumnsThatPreventDeletion.Add(Column.Name);
	EndDo;
	
	// Group the table to exclude duplicates (since the packages are not searched for repetitions.
	ObjectsPreventingDeletion.GroupBy(StrConcat(ColumnsThatPreventDeletion, ","));
EndProcedure

#EndRegion

#Region ObjectsDeletion

// Parameters:
//   DeletionParameters - See DeletionResult
//   ObjectsToDelete - See ObjectsToDelete
//   MetadataInfo - See MetadataInfo
// 	
// Returns:
//   See ProcessingResult
//
Function ProcessObjectsToDelete(DeletionParameters, ObjectsToDelete, MetadataInfo)
	
	DeletionResults = ProcessingResult();
	Package = ObjectsToDeletePackage();
	ObjectsWithDeleteProhibition = ObjectsToDeletePackage();
	
	For Each QueueItem In ObjectsToDelete Do
		If Not Package.Find(QueueItem.ItemToDeleteRef, "ItemToDeleteRef") <> Undefined Then
			// @skip-check query-in-loop - Batch processing of a large amount of data.
			QueueItemInPackage = QueueItemToPackage(QueueItem, MetadataInfo, Package); 
			
			If ItemProcessingProhibited(QueueItemInPackage) Then
				ObjectsWithDeleteProhibition = TablesMerge(ObjectsWithDeleteProhibition, QueueItemInPackage);
			Else
				Package = TablesMerge(Package, QueueItemInPackage, True);
			EndIf;
		EndIf;
		
		If Package.Count() >= DeletionParameters.PackageSize
				Or ObjectsToDelete.IndexOf(QueueItem) = ObjectsToDelete.Count()-1 Then
				
			PackageProcessingResult = ProcessPackage(DeletionParameters, Package);
			DeletionResults = MergeDeletionResult(DeletionResults, PackageProcessingResult);
			Package.Clear();
		EndIf;
	EndDo;
	
	DeletionResults = MergeDeletionResult(
		DeletionResults, 
		ResultOfDeletionFromUnprocessedPackage(DeletionParameters, ObjectsWithDeleteProhibition));	
	
	// Attempt to delete objects that form circular references within a transaction.
	NumberOfUndeletedItems = 0;
	While DeletionResults.NotDeletedObjects.Count() <> NumberOfUndeletedItems Do
		NumberOfUndeletedItems = DeletionResults.NotDeletedObjects.Count();
		
		Package = CircularRefs(DeletionResults.NotDeletedObjects, DeletionResults.UsageInstances);
		CircularReferencesProcessingResult = ProcessPackageInOneTransaction(DeletionParameters, Package);
		If CircularReferencesProcessingResult.DeletedObjects.Count() > 0 Then
			DeletionResults = AfterDeleteCircularReferencesResult(DeletionResults, CircularReferencesProcessingResult);	
		EndIf;
	EndDo;
	
	Return DeletionResults;
EndFunction

Function ResultOfDeletionFromUnprocessedPackage(DeletionParameters, ObjectsWithDeleteProhibition)
	DeletionResults = ProcessingResult();
	
	DeletionResults.NotDeletedObjects = TablesMerge(
		DeletionResults.NotDeletedObjects,
		ObjectsWithDeleteProhibition);
		
	DeletionResults.UsageInstances = TablesMerge(
		DeletionResults.UsageInstances,
		RemainingUsageInstancesOfObjectToDelete(DeletionParameters,
			PackageItemsUsageInstances(DeletionParameters, ObjectsWithDeleteProhibition)));
			
	Return DeletionResults;			
EndFunction

Function ItemProcessingProhibited(QueueItemInPackage)
	Return (QueueItemInPackage.Count() > 0 
		And QueueItemInPackage[QueueItemInPackage.Count() - 1].DeletionResult 
			<> DeletionResultCodes().Success);
EndFunction

Function QueueItemToPackage(QueueItem, MetadataInfo, Exceptions)
	Package = ObjectsToDeletePackage();
	DeletionResult = Undefined;
	
	// Skip if an object is deleted of added to the package as a subordinate object.	
	If Not ObjectDeleted(QueueItem.ItemToDeleteRef) 
		And Exceptions.Find(QueueItem.ItemToDeleteRef, "ItemToDeleteRef") = Undefined Then
			
		MetadataInformation = MetadataInfo.Find(QueueItem.Type, "Type");
		DeletionMark = Common.ObjectAttributeValue(QueueItem.ItemToDeleteRef, "DeletionMark");
		ChildSubordinateItems = ?(DeletionMark,
			ChildSubordinateItems(QueueItem.ItemToDeleteRef, MetadataInformation),
			ChildSubordinateItemsTable());
		
		If Not DeletionMark Then
			DeletionResult = DeletionResultCodes().NoMarkedForDeletion;
		ElsIf ItemDeletionAllowed(ChildSubordinateItems) Then
			DeletionResult = DeletionResultCodes().Success;
			SupplementPackageWithChildAndSubordinateItems(Package, QueueItem.ItemToDeleteRef, ChildSubordinateItems, Exceptions);
		Else
			DeletionResult = DeletionResultCodes().HasChildSubordinateItemsNotMarkedForDeletion;	
		EndIf;
		
		PackageItem = Package.Add();
		PackageItem.ItemToDeleteRef = QueueItem.ItemToDeleteRef;
		PackageItem.HasChildObjects = MetadataInformation.Hierarchical;
		PackageItem.HasSubordinateObjects = MetadataInformation.HasSubordinateObjects;
		PackageItem.ChildSubordinateObjects = ChildSubordinateItems;
		PackageItem.DeletionResult = DeletionResult;
		PackageItem.IsMainObject = True;
		PackageItem.TheMainElementOfTheLink = QueueItem.ItemToDeleteRef;
	EndIf;
	
	Return Package;
EndFunction

Function ProcessPackage(DeletionParameters, Package)
	PackageProcessingResult = ProcessingResult();
	
	If ValueIsFilled(DeletionParameters.JobID) And Common.DebugMode() Then
		Id = DeletionParameters.JobID;
	Else	
		SetPrivilegedMode(True);
		BackgroundJob = GetCurrentInfoBaseSession().GetBackgroundJob();
		Id = ?(BackgroundJob <> Undefined, BackgroundJob.UUID, New UUID);
		SetPrivilegedMode(False);
	EndIf;
	
	BeforeProcessPackage(Package, Id);
	
	UsageInstances = PackageItemsUsageInstances(DeletionParameters, Package);

	MainAndSubordinateObjects = New Array;
	RefsToObjectsToDelete = New Array;
	For Each Item In Package Do
		MainAndSubordinateObjects.Add(Item);
		RefsToObjectsToDelete.Add(Item.ItemToDeleteRef);
		If Not Item.IsMainObject Then
			Continue;
		EndIf;
		
		Context = New Structure;
		BeforeDeletingAGroupOfObjects(Context, Common.FixedData(RefsToObjectsToDelete, False));
		
		YouCanTDeleteTheMainObject = False;
		UndeletedItems = New Array;
		IsTransactionCanceled = False;
		BeginTransaction();
		Try
			
			MainObject = MainAndSubordinateObjects[MainAndSubordinateObjects.UBound()];
			For Each ItemToRemove In MainAndSubordinateObjects Do
				
				Filter = New Structure("ItemToDeleteRef", ItemToRemove.ItemToDeleteRef);
				DeletionResult = DeletePackageItem(DeletionParameters, ItemToRemove,
					UsageInstances.Copy(Filter), UndeletedItems);
							
				If DeletionResult.ErrorInfo <> Undefined Then
					RollbackTransaction();
					IsTransactionCanceled = True;
				EndIf;
				
				ReflectPackageItemDeletionResult(DeletionParameters, PackageProcessingResult, DeletionResult);
					
				If Not ItemToRemove.IsMainObject And DeletionResult.Code = DeletionResultCodes().ErrorOnDelete Then
					// If a child item is deleted with an error, other items cannot be deleted.
					// Return the parent item with the only undeleted item.
					YouCanTDeleteTheMainObject = True;
					UndeletedItems.Add(DeletionResult.ItemToDeleteRef);
					
					ResultOfDeletingTheMainElement = ResultOfDeletingAnElement(MainObject);
					ResultOfDeletingTheMainElement.Code = DeletionResultCodes().HasUsageInstances;
					
					Filter = New Structure("ItemToDeleteRef, UsageInstance1", MainObject.ItemToDeleteRef, ItemToRemove.ItemToDeleteRef);
					ResultOfDeletingTheMainElement.UsageInstances = UsageInstances.Copy(Filter);
					
					ReflectPackageItemDeletionResult(DeletionParameters, PackageProcessingResult,
						ResultOfDeletingTheMainElement);
						
					Break;	
						
				ElsIf DeletionResult.Code <> DeletionResultCodes().Success Then
					YouCanTDeleteTheMainObject = True;
					UndeletedItems.Add(DeletionResult.ItemToDeleteRef);
				EndIf;
				
			EndDo;
			
			// ACC:330-off - No.783.1.3. It is acceptable to specify the code after "CommitTransaction".
			// This method, "RollbackTransaction", will throw an exception.
			If Not IsTransactionCanceled Then
				If Not YouCanTDeleteTheMainObject Then
					CommitTransaction();
				Else
					RollbackTransaction();
				EndIf;
			EndIf;
			// ACC:330-on
		Except
			If Not IsTransactionCanceled Then
				RollbackTransaction();
			EndIf;
			Raise;
		EndTry;

		AfterDeletingAGroupOfObjects(Context, Not YouCanTDeleteTheMainObject);
		MainAndSubordinateObjects.Clear();
		RefsToObjectsToDelete.Clear();

	EndDo;
	
	AfterProcessPackage(DeletionParameters, Id);
	ClearRefsToObjectsToDelete(DeletionParameters, PackageProcessingResult);

	Return PackageProcessingResult;
EndFunction

// See MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects
Procedure BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete)
	SSLSubsystemsIntegration.BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);
	MarkedObjectsDeletionOverridable.BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);
EndProcedure

// See MarkedObjectsDeletionOverridable.AfterDeletingAGroupOfObjects
Procedure AfterDeletingAGroupOfObjects(Context, Success)
	SSLSubsystemsIntegration.AfterDeletingAGroupOfObjects(Context, Success);
	MarkedObjectsDeletionOverridable.AfterDeletingAGroupOfObjects(Context, Success);
EndProcedure

Function ResultOfDeletingAnElement(Val Item)
	Result = New Structure();
	
	Result.Insert("ItemToDeleteRef", Item.ItemToDeleteRef);
	Result.Insert("Code", DeletionResultCodes().Success);
	Result.Insert("UsageInstances", UsageInstances());
	Result.Insert("Messages", New FixedArray(New Array));
	Result.Insert("IsMainObject", Item.IsMainObject);
	Result.Insert("ErrorInfo");
	
	Return Result;
EndFunction

#Region ClearingRefsToObjectsToDelete

// Parameters:
//   DeletionParameters - See DeletionResult
//   PackageProcessingResult - See ProcessingResult
//
Procedure ClearRefsToObjectsToDelete(DeletionParameters, PackageProcessingResult)
	If Not DeletionParameters.ClearRefsInUsageInstances
		Or PackageProcessingResult.RefsCleanupLocations.Count() = 0 Then
			
		Return;
	EndIf;
	
	UsageInstances = PackageProcessingResult.RefsCleanupLocations;
	UsageInstances.Sort("UsageInstance1", New CompareValues());

	ObjectsToDeleteInUsageInstance = New Array;
	CurrentUsageInstancePosition = 0;
	For Each UsageInstanceInformationRecord In UsageInstances Do
		If UsageInstances[CurrentUsageInstancePosition].UsageInstance1
			  <> UsageInstanceInformationRecord.UsageInstance1 Then

			ClearRefsInUsageInstance(UsageInstances[CurrentUsageInstancePosition].UsageInstance1,
				ObjectsToDeleteInUsageInstance);
			CurrentUsageInstancePosition = UsageInstances.IndexOf(UsageInstanceInformationRecord);
			ObjectsToDeleteInUsageInstance.Clear();
		EndIf;
		
		ObjectsToDeleteInUsageInstance.Add(UsageInstanceInformationRecord.ItemToDeleteRef);

		If UsageInstances.IndexOf(UsageInstanceInformationRecord) = UsageInstances.Count() - 1 Then
			ClearRefsInUsageInstance(UsageInstanceInformationRecord.UsageInstance1,
				ObjectsToDeleteInUsageInstance);
		EndIf;
	EndDo;
EndProcedure

Procedure ClearRefsInUsageInstance(UsageInstance1, ObjectsToDelete)

	BeginTransaction();
	Try
		ObjectMetadata = UsageInstance1.Metadata();

		Block = New DataLock();
		Item = Block.Add(UsageInstance1.Metadata().FullName());
		Item.SetValue("Ref", UsageInstance1);
		Block.Lock();
		
		OccurrenceObject = UsageInstance1.GetObject();
		If OccurrenceObject = Undefined Then
			CommitTransaction();
			Return;
		EndIf;
		
		ClearRefsInAttributesCollection(OccurrenceObject, ObjectMetadata.StandardAttributes, ObjectsToDelete);
		ClearRefsInAttributesCollection(OccurrenceObject, ObjectMetadata.Attributes, ObjectsToDelete);
		
		For Each TabularSection In ObjectMetadata.TabularSections Do
			ClearRefsInTabularSection(OccurrenceObject[TabularSection.Name], TabularSection.Attributes, ObjectsToDelete);
		EndDo;
		
		ThereAreStandardTabularSections = CommonClientServer.HasAttributeOrObjectProperty(ObjectMetadata,
			"StandardTabularSections");
		StandardTabularSections = ?(ThereAreStandardTabularSections,
			ObjectMetadata.StandardTabularSections,
			New Array);
			
		For Each TabularSection In StandardTabularSections Do
			ClearRefsInTabularSection(OccurrenceObject[TabularSection.Name], TabularSection.StandardAttributes, ObjectsToDelete);
		EndDo;
		
		OccurrenceObject.AdditionalProperties.Insert("DontControlObjectsToDelete");
		OccurrenceObject.DataExchange.Load = True;
		OccurrenceObject.Write();

		CommitTransaction();
	Except
		RollbackTransaction();
		WriteWarning(NStr("en = 'Couldn''t remove links to the object in ""%1"" due to:';"), 
			UsageInstance1, ErrorInfo());
	EndTry;
	
EndProcedure

Procedure ClearRefsInTabularSection(OccurrenceObject, AttributesCollection, ObjectsToDelete)
	For Each TSRow In OccurrenceObject Do
		ClearRefsInAttributesCollection(TSRow, AttributesCollection, ObjectsToDelete);
	EndDo;
EndProcedure

Procedure ClearRefsInAttributesCollection(OccurrenceObject, AttributesCollection, ObjectsToDelete)
	For Each Attribute In AttributesCollection Do
		If ObjectsToDelete.Find(OccurrenceObject[Attribute.Name]) <> Undefined Then
			OccurrenceObject[Attribute.Name] = Attribute.Type.AdjustValue(Undefined);
		EndIf;
	EndDo;	
EndProcedure

// Parameters:
//   DeletionResults - See ProcessingResult
//   CircularReferencesProcessingResult - See ProcessingResult
//
// Returns:
//   See ProcessingResult
//
Function AfterDeleteCircularReferencesResult(DeletionResults, CircularReferencesProcessingResult)
	Result = ProcessingResult();
	Result.DeletedObjects = New Array(New FixedArray(DeletionResults.DeletedObjects));
		
	For Each Item In DeletionResults.NotDeletedObjects Do
		                                                  
		If CircularReferencesProcessingResult.DeletedObjects.Find(Item.ItemToDeleteRef) <> Undefined Then
			Result.DeletedObjects.Add(Item.ItemToDeleteRef);
		Else
			FillPropertyValues(Result.NotDeletedObjects.Add(),  Item);
			For Each UsageInstance1 In DeletionResults.UsageInstances.FindRows(New Structure("ItemToDeleteRef", Item.ItemToDeleteRef)) Do
				FillPropertyValues(Result.UsageInstances.Add(),  UsageInstance1);
			EndDo;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction
#EndRegion

#Region ChildSubordinateItemsGeneration

// Parameters:
//   QueueItem - See ObjectsToDelete
//   MetadataInformation - See MetadataInfo
//
// Returns:
//   See ChildSubordinateItemsTable
//
Function ChildSubordinateItems(ItemToDeleteRef, MetadataInformation)
	
	SetPrivilegedMode(True);
	ChildSubordinateItems = ChildSubordinateItemsTable();
	
	QueryPackages = New Array;
	
	If MetadataInformation.Hierarchical Then
		QueryPackages.Add(SubordinateItemsQueryText(MetadataInformation));
	EndIf;
	
	If MetadataInformation.SubordinateObjectsDetails.Count() > 0 Then
		QueryPackages.Add(QueryTextSubordinateElements(MetadataInformation));	
	EndIf;
	
	If QueryPackages.Count() > 0 Then
		QueryText = StrConcat(QueryPackages, Common.QueryBatchSeparator());
		Query = New Query(QueryText);
		Query.SetParameter("Parent", ItemToDeleteRef);
		Query.SetParameter("Ref", ItemToDeleteRef);
		
		PackageResult = Query.ExecuteBatch();
		
		If MetadataInformation.SubordinateObjectsDetails.Count() > 0 Then
			SubordinateItemsSelection = PackageResult[PackageResult.Count()-1].Select();
			ChildSubordinateItems = TablesMerge(ChildSubordinateItems, 
				ChildItems(SubordinateItemsSelection));
		EndIf;
		
		If MetadataInformation.Hierarchical Then
			ChildItemsSelection = PackageResult[0].Unload(QueryResultIteration.ByGroupsWithHierarchy);
			ChildSubordinateItems = TablesMerge(ChildSubordinateItems, 
				SubordinateItems(ItemToDeleteRef, ChildItemsSelection));
		EndIf;
	EndIf;
	
	Return ChildSubordinateItems;
	
EndFunction

// Recursively generates a child item table.
//
//  Parameters:
//   PackageResult - ValueTree
//
// Returns:
//   See ChildSubordinateItemsTable
//
Function SubordinateItems(MainItem, PackageResult)
	Result = ChildSubordinateItemsTable();
	
	For Each TreeRow In PackageResult.Rows Do
		
		If TreeRow.Item = MainItem Then
			SubordinateItems = SubordinateItems(MainItem, TreeRow);
			Result = TablesMerge(Result, SubordinateItems)
		Else
			ResultRecord = Result.Add();
			FillPropertyValues(ResultRecord, TreeRow);
			ResultRecord.SubordinateItems = SubordinateItems(MainItem, TreeRow);
			Result = TablesMerge(ResultRecord.SubordinateItems, Result, True);
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

// Parameters:
//   PackageResult - QueryResultSelection
//
// Returns:
//   See ChildSubordinateItemsTable
//
Function ChildItems(PackageResult)
	ChildSubordinateItems = ChildSubordinateItemsTable();

	While PackageResult.Next() Do
		FillPropertyValues(ChildSubordinateItems.Add(), PackageResult);
	EndDo;
	
	Return ChildSubordinateItems;
EndFunction

// Returns:
// 	ValueTable :
//   * Item - AnyRef
//   * SubordinateItems - See ChildSubordinateItemsTable 
//   * DeletionMark - Boolean
//   * ElementType - String
//
Function ChildSubordinateItemsTable()
	ChildSubordinateItems = New ValueTable();
	ChildSubordinateItems.Columns.Add("Item");
	ChildSubordinateItems.Columns.Add("SubordinateItems", New TypeDescription("ValueTable"));
	ChildSubordinateItems.Columns.Add("DeletionMark", New TypeDescription("Boolean"));
	ChildSubordinateItems.Columns.Add("ElementType", New TypeDescription("String"));
	Return ChildSubordinateItems
EndFunction

Function SubordinateItemsQueryText(MetadataInformation)
	QueryTemplate = "SELECT
	|	Tab.Ref AS Item,
	|	Tab.DeletionMark AS DeletionMark,
	|	""Subsidiary"" AS ElementType
	|FROM
	|	&TableName AS Tab
	|WHERE
	|	Tab.Ref IN HIERARCHY (&Parent)
	|ORDER BY
	|	Item HIERARCHY";
	
	Table = MetadataInformation.Metadata.FullName();
	QueryText = StrReplace(QueryTemplate, "&TableName", Table);
	
	Return QueryText;
EndFunction

// Parameters:
//   MetadataInformation - See MetadataInfo
//
// Returns:
//   String
//
Function QueryTextSubordinateElements(MetadataInformation)
	QueriesTexts = New Array;// Array of String
	
	LinkConditionTemplate = "Tab.%1 = &Ref";
	QueryTemplate = "SELECT
	|	Tab.Ref AS Item,
	|	Tab.DeletionMark AS DeletionMark,
	|	""Subordinated"" AS ElementType
	|FROM
	|	&TableName AS Tab
	|WHERE
	|	Tab.Ref <> &Ref
	|	AND &LinkConditionExpression";
	
	LinkConditionExpression = "FALSE";
	For Each SubordinateObject In MetadataInformation.SubordinateObjectsDetails Do
		LinkConditionExpression = StringFunctionsClientServer.SubstituteParametersToString(LinkConditionTemplate, SubordinateObject.AttributeName);
		QueryText = StrReplace(QueryTemplate, "&TableName", SubordinateObject.Metadata.FullName());
		QueryText = StrReplace(QueryText, "&LinkConditionExpression", LinkConditionExpression);
		QueriesTexts.Add(QueryText);
	EndDo;
	
	Return StrConcat(QueriesTexts, Chars.LF + "UNION ALL" + Chars.LF);	
EndFunction
#EndRegion

// Parameters:
//   DeletionResults - See ProcessingResult
//   ProcessingResult - See ProcessingResult
//
Function MergeDeletionResult(DeletionResults, ProcessingResult)
	
	Result = ProcessingResult();
	Result.NotDeletedObjects = TablesMerge(DeletionResults.NotDeletedObjects, ProcessingResult.NotDeletedObjects);
	Result.UsageInstances = TablesMerge(DeletionResults.UsageInstances, ProcessingResult.UsageInstances);
	Result.DeletedObjects = Common.CopyRecursive(DeletionResults.DeletedObjects);
	CommonClientServer.SupplementArray(Result.DeletedObjects, ProcessingResult.DeletedObjects);
	Return Result;	
	
EndFunction

// Parameters:
//   Receiver - ValueTable
//   Source - ValueTable
//   DestinationColumn - String
//   SourceColumn1 - String
//
// Returns:
//   Boolean
//
Function SourceDestinationSubset(Receiver, Source, DestinationColumn, SourceColumn1)
	Result = True;
	
	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		Source.UnloadColumn("UsageInstance1"), "DataVersion");
	For Each UsageInstanceInfo1 In Source Do
		If Not ObjectDeleted(UsageInstanceInfo1.UsageInstance1, DataVersions)
				And Receiver.Find(UsageInstanceInfo1[SourceColumn1], DestinationColumn) = Undefined Then
			Result = False;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function ItemDeletionAllowed(AdditionalInfo)
	Result = True;
	
	For Each Item In AdditionalInfo Do
		If Not Item.DeletionMark And Not Item.ElementType = "Subordinated" Then
			Result = False;
			Break;
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function ObjectDeleted(ItemToDeleteRef, DataVersions = Undefined)
	Return ValueIsFilled(ItemToDeleteRef) 
		And CommonClientServer.HasAttributeOrObjectProperty(ItemToDeleteRef, "DataVersion")
		And ?(DataVersions <> Undefined, Not ValueIsFilled(DataVersions[ItemToDeleteRef])
			Or Not ValueIsFilled(DataVersions[ItemToDeleteRef].DataVersion),
			Not ValueIsFilled(Common.ObjectAttributeValue(ItemToDeleteRef, "DataVersion")));
EndFunction

// Parameters:
//   DeletionParameters - See DeletionResult
//   PackageProcessingResult - See ProcessingResult
//   Item - See ObjectsToDeletePackage
//   DeletionResult - See DeletePackageItem
//
Procedure ReflectPackageItemDeletionResult(DeletionParameters, PackageProcessingResult, DeletionResult)
	
	If Not DeletionResult.IsMainObject And DeletionResult.Code = DeletionResultCodes().Success Then
		Return;
	EndIf;
	
	If DeletionResult.Code <> DeletionResultCodes().Success Then
		NotDeletedItem = PackageProcessingResult.NotDeletedObjects.Add();
		FillPropertyValues(NotDeletedItem, DeletionResult);
		NotDeletedItem.DeletionResult =  DeletionResult.Code;
		NotDeletedItem.ErrorInfo = DeletionResult.ErrorInfo;
		NotDeletedItem.Messages = UserMessagesAsString(DeletionResult.Messages);
		PackageProcessingResult.UsageInstances = TablesMerge(
			PackageProcessingResult.UsageInstances,
			DeletionResult.UsageInstances);
	Else
		PackageProcessingResult.DeletedObjects.Add(DeletionResult.ItemToDeleteRef);
		PackageProcessingResult.RefsCleanupLocations = TablesMerge(
			PackageProcessingResult.RefsCleanupLocations,
			DeletionResult.UsageInstances);
	EndIf;	
	
	If DeletionResult.IsMainObject Then
		DeletionParameters.ProcessedItemsCount = DeletionParameters.ProcessedItemsCount + 1;
	EndIf;
	
	NotifyOfProgress(DeletionParameters);

EndProcedure

Function UserMessagesAsString(Messages)
	Result = "";
	
	For Each Item In Messages Do
		Result = Chars.LF + Result + Item.Text;
	EndDo;
	
	Return Result;
EndFunction

// Process the package in one transaction.
// 
// Parameters:
//  DeletionParameters - See DeletionResult
//  Package - See ObjectsToDeletePackage
// 
// Returns:
//   See ProcessingResult
//
Function ProcessPackageInOneTransaction(DeletionParameters, Package)
	
	Result = ProcessingResult();
	
	Context = New Structure;
	ObjectsToDelete = Package.UnloadColumn("ItemToDeleteRef");
	BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);

	ItemPresentation = "";
	BeginTransaction();
	Try
		For Each PackageItem In Package Do
			
			ItemToRemove = PackageItem.ItemToDeleteRef;
			ItemPresentation = Common.SubjectString(ItemToRemove);
			
			Block = New DataLock();
			Item = Block.Add(ItemToRemove.Metadata().FullName());
			Item.SetValue("Ref", ItemToRemove);
			Block.Lock();
			
			Object = ItemToRemove.GetObject();
			If Object <> Undefined Then
				DeleteObject(Object);
				Result.DeletedObjects.Add(ItemToRemove);
			EndIf;
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Result.NotDeletedObjects = Package.Copy();
		WriteWarning(NStr("en = 'Couldn''t delete ""%1"" due to:';"),
			ItemPresentation, ErrorInfo());
	EndTry;
	AfterDeletingAGroupOfObjects(Context, True);
	 
	Return Result;
EndFunction

// Parameters:
//   DeletionParameters - See DeletionResult
//   Item - ValueTableRow of See ObjectsToDeletePackage
//   UsageInstances - See UsageInstances
//   UndeletedItems - Array of AnyRef
//
// Returns:
//   Structure:
//   * Code - String
//   * UsageInstances - See PackageItemsUsageInstances
//   * Messages - Array of UserMessage
//   * ErrorInfo - Undefined
// 	                      - ErrorInfo
//
Function DeletePackageItem(DeletionParameters, Item, UsageInstances, UndeletedItems)

	Result = ResultOfDeletingAnElement(Item);
	If ObjectDeleted(Item.ItemToDeleteRef) Then // The object has already been deleted.
		Return Result;
	EndIf;
	
	If Item.ChildSubordinateObjects.Count() > 0 Then
		DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
			Item.ChildSubordinateObjects.UnloadColumn("Item"), "DataVersion");
	EndIf;

	// The item has child or subordinate objects pending deletion.
	For Each ChildSubordinateItem In Item.ChildSubordinateObjects Do
		If Not ObjectDeleted(ChildSubordinateItem.Item, DataVersions) 
				Or UndeletedItems.Find(ChildSubordinateItem.Item) <> Undefined Then
				
			Result.Code = DeletionResultCodes().HasUsageInstances;
			Result.UsageInstances = RemainingUsageInstancesOfObjectToDelete(
				DeletionParameters, UsageInstances, ChildSubordinateItem.Item);
			Return Result; 
		EndIf;
	EndDo;
	
	RefsCleanupLocations = RefsCleanupLocations(DeletionParameters, UsageInstances);
	ItemPresentation = Common.SubjectString(Item.ItemToDeleteRef);
	Try
		Block = New DataLock();
		LockItem = Block.Add(Item.ItemToDeleteRef.Metadata().FullName());
		LockItem.SetValue("Ref", Item.ItemToDeleteRef);
		Block.Lock();
		
		Object = Item.ItemToDeleteRef.GetObject();
		DeleteObject(Object);	
	Except
		ErrorInfo = ErrorInfo();
		WriteWarning(NStr("en = 'Couldn''t delete ""%1"" due to:';"), ItemPresentation, ErrorInfo);
		Result.Messages = TimeConsumingOperations.UserMessages(True);
		Result.ErrorInfo = ErrorInfo; 
		Result.Code = DeletionResultCodes().ErrorOnDelete;
		Return Result;
	EndTry;

	RemainingUsageInstances = RemainingUsageInstancesOfObjectToDelete(DeletionParameters, UsageInstances);
	If RemainingUsageInstances.Count() = 0
			Or RefsCleanupLocations.Count() = RemainingUsageInstances.Count() Then
		
		Result.UsageInstances = RefsCleanupLocations;  	
	Else
		Result.UsageInstances = RemainingUsageInstances;
		Result.Code = DeletionResultCodes().HasUsageInstances;
	EndIf;

	Return Result;
EndFunction

Procedure DeleteObject(Object)
	Object.AdditionalProperties.Insert("DontControlObjectsToDelete");
	Object.Delete();
EndProcedure

Function RecordExists(UsageInstanceInfo1)
	RegisterManager = Common.ObjectManagerByFullName(UsageInstanceInfo1.Metadata.FullName());// InformationRegisterManager, AccountingRegisterManager, CalculationRegisterManager, AccumulationRegisterManager
	Set = RegisterManager.CreateRecordSet();
	For IndexOf = 0 To Set.Filter.Count() - 1 Do
		FilterElement = Set.Filter[IndexOf];
		FilterElement.Set(UsageInstanceInfo1.UsageInstance1[FilterElement.Name]);
	EndDo;
	Set.Read();
	Return Set.Count() > 0;
EndFunction

Function LinkInTheLeadingDimension(UsageInstanceInfo1)
	
	DimensionsNames = MarkedObjectsDeletionCached.RegisterMasterDimensions(UsageInstanceInfo1.Metadata.FullName());
	Dimensions = New Structure(DimensionsNames);
	FillPropertyValues(Dimensions, UsageInstanceInfo1.UsageInstance1);
	For Each Dimension In Dimensions Do
		If Dimension.Value = UsageInstanceInfo1.ItemToDeleteRef Then
			Return True;
		EndIf;
	EndDo;
	Return False;
	
EndFunction

// Parameters:
//   DeletionParameters - Structure
//   Package - See ObjectsToDeletePackage
// 	
// Returns:
//   See UsageInstances
//
Function PackageItemsUsageInstances(DeletionParameters, Package)
	Result = UsageInstances();
	
	SetPrivilegedMode(True);
	UsageInstancesSearchParameters = Common.UsageInstancesSearchParameters();
	UsageInstancesSearchParameters.CancelRefsSearchExceptions = CancelRefsSearchExceptionsOnDeleteObjects();
	UsageInstances = Common.UsageInstances(Package.UnloadColumn("ItemToDeleteRef"),,UsageInstancesSearchParameters);
	UsageInstances.Columns[0].Name = "ItemToDeleteRef";
	UsageInstances.Columns[1].Name = "UsageInstance1";
	UsageInstances.Columns[2].Name = "Metadata";
	
	CommonClientServer.SupplementTable(UsageInstances, Result);
	
	Return Result;
EndFunction

// Parameters:
//   Package - See ObjectsToDeletePackage
//   ChildSubordinateItems - See ChildSubordinateItems
//
Procedure SupplementPackageWithChildAndSubordinateItems(Package, MainItem, ChildSubordinateItems, Exceptions)
	For Each ItemDetails In ChildSubordinateItems Do
		If Package.Find(ItemDetails.Item, "ItemToDeleteRef") <> Undefined
			Or Exceptions.Find(ItemDetails.Item, "ItemToDeleteRef") <> Undefined Then
			
			Continue;
		EndIf;
		
		PackageItem = Package.Add();
		PackageItem.TheMainElementOfTheLink = MainItem;
		PackageItem.ItemToDeleteRef = ItemDetails.Item;
		PackageItem.ChildSubordinateObjects = ItemDetails.SubordinateItems;
	EndDo;
EndProcedure

// Parameters:
//   DeletionParameters - See DeletionResult
//
Procedure NotifyOfProgress(ExecutionParameters)
	CurrentTime = CurrentUniversalDateInMilliseconds();
	If ExecutionParameters.IsScheduledJob 
			Or CurrentTime - ExecutionParameters.TheNotificationTime <= ExecutionParameters.NotificationPeriod Then
		Return;
	EndIf;
	ExecutionParameters.Total = ExecutionParameters.CountOfItemsToDelete;
	MarkCollectionTraversalProgress(ExecutionParameters, "UserObjects");
	ExecutionParameters.TheNotificationTime = CurrentTime;
EndProcedure

#EndRegion

#Region CollectionsFilters

// Parameters:
//   Package - See ObjectsToDeletePackage
//   UsageInstances - See UsageInstances
// 	
// Returns:
//   See ObjectsToDeletePackage
//
Function CircularRefs(Package, UsageInstances)
	Result = RefsOnlyToItemsInPackage(Package, UsageInstances);
	
	CountInPackage = Package.Count();
	While (Result[0].Count() <> CountInPackage) Do
		CountInPackage = Result[0].Count();
		Result = RefsOnlyToItemsInPackage(Result[0], Result[1]);
	EndDo;
	
	Return Result[0];
EndFunction

// Parameters:
//   DeletionParameters - Structure:
//   * PackageSize - Number
//   * RefSearchExclusions - Array
//   UsageInstances - See PackageItemsUsageInstances
//
// Returns:
//   See UsageInstances
//
Function RemainingUsageInstancesOfObjectToDelete(DeletionParameters, UsageInstances, LinkException = Undefined)
	Result = UsageInstances.CopyColumns();

	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		UsageInstances.UnloadColumn("UsageInstance1"), "DataVersion");
	For Each UsageInstanceInfo1 In UsageInstances Do
		IsReference = UsageInstanceInfo1.UsageInstance1 <> Undefined 
			And CommonClientServer.HasAttributeOrObjectProperty(UsageInstanceInfo1.UsageInstance1, "DataVersion");
		IsConstant = Metadata.Constants.Contains(UsageInstanceInfo1.Metadata);	
		
		If IsReference
			And (Not ObjectDeleted(UsageInstanceInfo1.UsageInstance1, DataVersions)
				Or UsageInstanceInfo1.UsageInstance1 = LinkException)
			And Not UsageInstanceInfo1.IsInternalData  Then
			FillPropertyValues(Result.Add(), UsageInstanceInfo1);
		EndIf;
		
		If Common.IsSequence(UsageInstanceInfo1.Metadata) Then
			// Delete data if the reference is found only in the table.
			Continue;
		EndIf;
		
		If Not IsReference And Not IsConstant And Not UsageInstanceInfo1.IsInternalData
			And RecordExists(UsageInstanceInfo1) 
			And Not LinkInTheLeadingDimension(UsageInstanceInfo1) Then
			FillPropertyValues(Result.Add(), UsageInstanceInfo1);
		EndIf;
		
		If Not IsReference And IsConstant
			And UsageInstanceInfo1.UsageInstance1 = Undefined Then
			FillPropertyValues(Result.Add(), UsageInstanceInfo1);
		EndIf;
	EndDo;

	Return Result;
EndFunction

Function RefsCleanupLocations(DeletionParameters, UsageInstances)
	Result = UsageInstances();
	
	If Not DeletionParameters.ClearRefsInUsageInstances Then
		Return Result;
	EndIf;
	
	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		UsageInstances.UnloadColumn("UsageInstance1"), "DataVersion");
	UsageInstances.Sort("Metadata");
	For Each UsageInstanceInfo1 In UsageInstances Do
		
		UsageInstanceType = TypeOf(UsageInstanceInfo1.UsageInstance1);
		IsReference = Common.IsReference(UsageInstanceType);
		
		If IsReference
			And Not ObjectDeleted(UsageInstanceInfo1.UsageInstance1, DataVersions) 
			And Common.ObjectAttributeValue(UsageInstanceInfo1.UsageInstance1, "DeletionMark") 
			And Not UsageInstanceInfo1.IsInternalData Then
				
			FillPropertyValues(Result.Add(), UsageInstanceInfo1);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function RefsOnlyToItemsInPackage(Package, UsageInstances)
	Result = New Array;
	NewPackage = ObjectsToDeletePackage();
	ProbableDuplicatesUsageInstances = UsageInstances();
	
	For Each Item In Package Do
		If Item.DeletionResult <> DeletionResultCodes().HasUsageInstances 
				And Item.DeletionResult <> DeletionResultCodes().HasChildSubordinateItems Then
			Continue;
		EndIf;
		
		ItemUsageInstances = UsageInstances.Copy(New Structure("ItemToDeleteRef", Item.ItemToDeleteRef), "UsageInstance1");
		If SourceDestinationSubset(Package, ItemUsageInstances, "ItemToDeleteRef", "UsageInstance1") Or UsageInstances.Count() = 0 Then
			FillPropertyValues(NewPackage.Add(), Item);
			
			For Each Item In ItemUsageInstances Do
				FillPropertyValues(ProbableDuplicatesUsageInstances.Add(), Item);
			EndDo;
		EndIf;	
	EndDo;
	
	Result.Add(NewPackage);
	Result.Add(UsageInstances);
	
	Return Result;
EndFunction

#EndRegion

#Region CompetitiveUpdateEventHandlers

Procedure AfterProcessPackage(DeletionParameters, Id)
	MarkedObjectsDeletionInternal.UnlockUsageOfObjectsToDelete(Id);
	SessionParameters.ObjectsDeletionInProgress = False;
EndProcedure

Procedure BeforeProcessPackage(Package, Id)
	SessionParameters.ObjectsDeletionInProgress = True;
	MarkedObjectsDeletionInternal.SetObjectsToDeleteUsageLock(Package, Id);
EndProcedure

#EndRegion

#Region Constructors

// Returns:
//  Structure:
//   * UserObjects - Array of AnyRef 
//   * Exclusively - Boolean 
//   * ClearRefsInUsageInstances - Boolean
//   * Mode - String
//   * IsScheduledJob - Boolean
//   * PackageSize - Number
//
Function DeletionParameters() Export
	
	Result = New Structure;
	Result.Insert("UserObjects", New Array);
	Result.Insert("Exclusively", False);
	Result.Insert("ClearRefsInUsageInstances", False);
	Result.Insert("Mode", "");
	Result.Insert("IsScheduledJob", False);
	Result.Insert("PackageSize", 100);
	Return Result;
	
EndFunction

// DeletionParameters:
//   ObjectsToDelete - Array of AnyRef
//   DeletionParameters - See DeletionParameters
//
// Returns:
//   Structure:
//   * NotDeletedObjectsCount - Number
//   * ToRedelete - Array of AnyRef
//   * ObjectsPreventingDeletion - ValueTable:
//      ** ItemToDeleteRef - AnyRef
//      ** UsageInstance1  - AnyRef
//      ** FoundStatus - String
//      ** DetailedErrorDetails - String
//      ** ErrorDescription - String
//   * NotTrash - Array of AnyRef
//   * Trash - Array of AnyRef
//   * UserObjects - Array of AnyRef
//   * Exclusively - Boolean
//   * ClearRefsInUsageInstances - Boolean
//   * TypesInformationCache - Map
//   * PackageSize - Number
//   * RefSearchExclusions - Array of MetadataObject
//   * JobID - UUID
//   * TheNotificationTime - Number - the time of the last notification in milliseconds
//   * NotificationPeriod - Number - the number of milliseconds between notifications
//
Function DeletionResult(ObjectsToDelete, DeletionParameters)
	RefSearchExclusions = RefSearchExceptionsOnDelete();

	ProcessingParameters = New Structure;
	ProcessingParameters.Insert("Exclusively", DeletionParameters.Exclusively);
	ProcessingParameters.Insert("ExcludingRules", New Map);
	ProcessingParameters.Insert("RefSearchExclusions", RefSearchExclusions);
	ProcessingParameters.Insert("PackageSize", DeletionParameters.PackageSize);
	ProcessingParameters.Insert("TypesInformationCache", New Map);
	ProcessingParameters.Insert("ClearRefsInUsageInstances", DeletionParameters.ClearRefsInUsageInstances);
	
	ProcessingParameters.Insert("UserObjects", New Array);
	
	ObjectsPreventingDeletion = New ValueTable;
	ObjectsPreventingDeletion.Columns.Add("ItemToDeleteRef");
	ObjectsPreventingDeletion.Columns.Add("UsageInstance1");
	ObjectsPreventingDeletion.Columns.Add("FoundStatus", New TypeDescription("String",, New StringQualifiers(10)));
	ObjectsPreventingDeletion.Columns.Add("ErrorDescription", New TypeDescription("String"));
	ObjectsPreventingDeletion.Columns.Add("DetailedErrorDetails", New TypeDescription("String"));
	MetadataColumnsTypes = New Array; 
	MetadataColumnsTypes.Add("MetadataObject");
	MetadataColumnsTypes.Add("Undefined");
	ObjectsPreventingDeletion.Columns.Add("Metadata", New TypeDescription(MetadataColumnsTypes));
	
	ObjectsPreventingDeletion.Indexes.Add("ItemToDeleteRef");
	ObjectsPreventingDeletion.Indexes.Add("UsageInstance1");
	
	ProcessingParameters.Insert("Trash",              New Array);
	ProcessingParameters.Insert("NotTrash",            New Array);
	ProcessingParameters.Insert("ObjectsPreventingDeletion", ObjectsPreventingDeletion);
	ProcessingParameters.Insert("ToRedelete",      New Array);
	ProcessingParameters.Insert("CountOfItemsToDelete",    ObjectsToDelete.Count());
	ProcessingParameters.Insert("NotDeletedObjectsCount",  0);
	ProcessingParameters.Insert("ProcessedItemsCount",  0);
	ProcessingParameters.Insert("Total",  0);
	ProcessingParameters.Insert("Number",  0);
	ProcessingParameters.Insert("JobID", "");
	
	// Reduce the rmngr memory allocated for messages.
	ProcessingParameters.Insert("TheNotificationTime", 0);
	ProcessingParameters.Insert("NotificationPeriod", 60000); // Milliseconds.
	ProcessingParameters.Insert("IsScheduledJob", DeletionParameters.IsScheduledJob);
	
	Return ProcessingParameters;
EndFunction

Function RefSearchExceptionsOnDelete()
	RefSearchExclusions = Common.RefSearchExclusions();
	For Each Item In MarkedObjectsDeletionInternal.ExceptionsOfSearchForRefsAllowingDeletion() Do
		RefSearchExclusions.Insert(Item, "*");
	EndDo;
	
	RefSearchExclusions.Delete(Metadata.Catalogs.ExternalUsers);
	
	Return RefSearchExclusions;
EndFunction

// Returns:
//   Structure:
//   * NotDeletedObjects - See ObjectsToDeletePackage
//   * DeletedObjects - Array of AnyRef
//   * UsageInstances - See UsageInstances
//   * RefsCleanupLocations - See UsageInstances
//
Function ProcessingResult()

	Result = New Structure();
	Result.Insert("DeletedObjects", New Array);
	Result.Insert("NotDeletedObjects", ObjectsToDeletePackage()); 
	Result.Insert("UsageInstances", UsageInstances());
	Result.Insert("RefsCleanupLocations", UsageInstances());
	Return Result;
	
EndFunction

// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef
//   * UsageInstance1 - AnyRef
//   * Metadata - MetadataObject 
//   * IsInternalData - Boolean 
//
Function UsageInstances() Export
	Table = New ValueTable();
	
	Table.Columns.Add("ItemToDeleteRef");
	Table.Columns.Add("UsageInstance1");
	Table.Columns.Add("Metadata");
	Table.Columns.Add("IsInternalData", New TypeDescription("Boolean"));
	
	Table.Indexes.Add("ItemToDeleteRef");
	Table.Indexes.Add("UsageInstance1");
	
	Return Table;
EndFunction

// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef
//   * HasChildObjects - Boolean
//   * HasSubordinateObjects - Boolean
//   * ErrorInfo - ErrorInfo
//   * Messages - String
//   * DeletionResult - Number
//   * ChildSubordinateObjects - See ChildSubordinateItemsTable
//   * IsMainObject - Boolean
//
Function ObjectsToDeletePackage()
	
	Package = New ValueTable;
	Package.Columns.Add("ItemToDeleteRef");
	Package.Columns.Add("HasChildObjects", , New TypeDescription("Boolean"));
	Package.Columns.Add("HasSubordinateObjects", New TypeDescription("Boolean"));
	Package.Columns.Add("ErrorInfo", New TypeDescription("ErrorInfo"));
	Package.Columns.Add("Messages", New TypeDescription("String"));
	Package.Columns.Add("DeletionResult", New TypeDescription("Number"));
	Package.Columns.Add("ChildSubordinateObjects", New TypeDescription("ValueTable"));
	Package.Columns.Add("IsMainObject", New TypeDescription("Boolean"));
	Package.Columns.Add("TheMainElementOfTheLink");
	
	Package.Indexes.Add("ItemToDeleteRef");
	Return Package;
	
EndFunction

Function DeletionResultCodes() 
	ErrorsTypes = New Structure;
	ErrorsTypes.Insert("Success", -1);
	ErrorsTypes.Insert("HasUsageInstances", 0);
	ErrorsTypes.Insert("ErrorOnDelete", 1);
	ErrorsTypes.Insert("HasChildSubordinateItems", 2);
	ErrorsTypes.Insert("HasChildSubordinateItemsNotMarkedForDeletion", 3);
	ErrorsTypes.Insert("NoMarkedForDeletion", 4);
	Return ErrorsTypes;
EndFunction

// Parameters:
//   ObjectsToDeleteArray - Array of AnyRef
//   MetadataInfo - ValueTable:
//   * Metadata - MetadataObject
//   * Hierarchical - Boolean
//   * Priority - Number
//   * Type - Type
//
// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef
//   * Priority - Number
//   * Type - Type
//
Function ObjectsToDelete(ObjectsToDeleteArray, MetadataInfo)
	ObjectsToDelete = New ValueTable;
	ObjectsToDelete.Columns.Add("ItemToDeleteRef");
	ObjectsToDelete.Columns.Add("Priority", New TypeDescription("Number"));
	ObjectsToDelete.Columns.Add("AttemptsNumber", New TypeDescription("Number"));
	ObjectsToDelete.Columns.Add("Type", New TypeDescription("Type"));
	ObjectsToDelete.Indexes.Add("ItemToDeleteRef");
	
	ObjectsAttemptsCount = InformationRegisters.NotDeletedObjects.ObjectsAttemptsCount(ObjectsToDeleteArray);
	
	For Each Item In ObjectsToDeleteArray Do
		ElementType = TypeOf(Item);
		QueueItem = ObjectsToDelete.Add();
		QueueItem.ItemToDeleteRef = Item;
		QueueItem.Priority = MetadataInfo.FindRows(New Structure("Type", ElementType))[0].Priority;
		QueueItem.Type = ElementType;
		AttemptsNumber = ObjectsAttemptsCount.Find(Item, "ItemToDeleteRef");
		QueueItem.AttemptsNumber = ?(AttemptsNumber = Undefined, 0, AttemptsNumber.AttemptsNumber);
	EndDo;
	
	ObjectsToDelete.Sort("AttemptsNumber, Priority");
	
	Return ObjectsToDelete;
EndFunction
#EndRegion

#Region MetadataInfoGeneration

// Parameters:
//   DeletionParameters - Structure 
//   ObjectsToDelete - Array of AnyRef
//
// Returns:
//   ValueTable:
//   * Metadata - MetadataObject 
//   * Hierarchical - Boolean
//   * Priority - Number
//   * Type - Type
//   * SubordinateObjectsDetails - ValueTable
//
Function MetadataInfo(DeletionParameters, ObjectsToDelete)
	
	Result = New ValueTable();
	Result.Columns.Add("Metadata", New TypeDescription("MetadataObject"));
	Result.Columns.Add("Hierarchical", New TypeDescription("Boolean"));
	Result.Columns.Add("Priority", New TypeDescription("Number"));
	Result.Columns.Add("HasSubordinateObjects", New TypeDescription("Boolean"));
	Result.Columns.Add("Type", New TypeDescription("Type"));
	Result.Columns.Add("SubordinateObjectsDetails", New TypeDescription("ValueTable"));
	
	Result.Indexes.Add("Type");
	Result.Indexes.Add("Metadata");
	
	FillMetadataInfo(Result, ObjectsToDelete);
	Return Result;
	
EndFunction

// Returns:
//   ValueTable:
//   * Type - Type
//   * SubordinateMetadata - MetadataObject
//   * Attributes - Array
//
Function SubordinateObjectsSearchTable()
	Table = New ValueTable;
	Table.Columns.Add("Type", New TypeDescription("Type"));
	Table.Columns.Add("Metadata", New TypeDescription("MetadataObject"));
	Table.Columns.Add("AttributeName", New TypeDescription("String"));
	
	Return Table;
EndFunction

Procedure FillMetadataInfo(MetadataInfo, ObjectsToDelete)
	SubordinateObjects = Common.SubordinateObjects();
	
	For Each Item In ObjectsToDelete Do
		If MetadataInfo.Find(Item.Metadata(), "Metadata") = Undefined Then
			MetadataInformation = MetadataInfo.Add();
			MetadataInformation.Metadata = Item.Metadata();
			MetadataInformation.Priority = 0;
			MetadataInformation.Type = TypeOf(Item);
			MetadataInformation.SubordinateObjectsDetails = SubordinateObjectsSearchTable();
			MetadataInformation.Hierarchical = IsHierarchicalMetadataObject(MetadataInformation.Metadata);
		EndIf;
	EndDo;
	
	For Each MetadataObject In Metadata.Catalogs Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		If SubordinateObjectDetails = Undefined
				And MetadataObject.Owners.Count() > 0 Then
				
			SubordinateObjectDetails	= SubordinateObjects.Add();
			SubordinateObjectDetails.SubordinateObject = MetadataObject;
			SubordinateObjectDetails.LinksFields = "Owner";
		ElsIf MetadataObject.Owners.Count() > 0 Then
			
			SubordinateObjectDetails.LinksFields = ?(StrFind(SubordinateObjectDetails.LinksFields, "Owner") > 0,
				SubordinateObjectDetails.LinksFields,
				SubordinateObjectDetails.LinksFields + ",Owner");
		EndIf;
			
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.Documents Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCharacteristicTypes Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfCalculationTypes Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.StandardTabularSections);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.ChartsOfAccounts Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.StandardTabularSections);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.BusinessProcesses Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
	
	For Each MetadataObject In Metadata.Tasks Do
		SubordinateObjectDetails = SubordinateObjects.Find(MetadataObject, "SubordinateObject");
		
		RegisterAttributes(MetadataInfo, MetadataObject.StandardAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.AddressingAttributes, SubordinateObjectDetails);
		RegisterAttributes(MetadataInfo, MetadataObject.Attributes, SubordinateObjectDetails);
		RegisterTabularSectionsAttributes(MetadataInfo, MetadataObject.TabularSections);
	EndDo;
EndProcedure

Procedure RegisterTabularSectionsAttributes(MetadataInfo, TabularSections)
	For Each TabularSection In TabularSections Do
		If TypeOf(TabularSection) = Type("MetadataObject") Then
			RegisterAttributes(MetadataInfo, TabularSection.Attributes);	
		Else
			RegisterAttributes(MetadataInfo, TabularSection.StandardAttributes);
		EndIf;
	EndDo;
EndProcedure

Procedure RegisterAttributes(MetadataInfo, AttributesCollection, SubordinateObjectDetails = Undefined)
	
	For Each Attribute In AttributesCollection Do
		RegisterAttribute(MetadataInfo, Attribute, SubordinateObjectDetails);
	EndDo;
	
EndProcedure

Procedure RegisterAttribute(MetadataInfo, Attribute,
		SubordinateObjectDetails)
	LinkFieldsNames = ?(ValueIsFilled(SubordinateObjectDetails), StrSplit(SubordinateObjectDetails.LinksFields, ","), New Array);
	IsSubordinateObjectLinksField = LinkFieldsNames.Find(Attribute.Name) <> Undefined;

	For Each Type In Attribute.Type.Types() Do
		If MarkedObjectsDeletionInternal.IsSimpleType(Type) Then
			Continue;
		EndIf;

		FoundInfo = MetadataInfo.Find(Type, "Type");
		If FoundInfo <> Undefined Then
			FoundInfo.Priority = FoundInfo.Priority + 1;

			If IsSubordinateObjectLinksField Then
				Link = FoundInfo.SubordinateObjectsDetails.Add();
				Link.Type = Type;
				Link.Metadata = SubordinateObjectDetails.SubordinateObject;
				Link.AttributeName = Attribute.Name;
				FoundInfo.HasSubordinateObjects = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Function IsHierarchicalMetadataObject(MetadataObject)

	If Common.IsChartOfAccounts(MetadataObject) Then
		Return True;
	Else
		AttributeValue = New Structure("Hierarchical");
		FillPropertyValues(AttributeValue, MetadataObject);
		Return AttributeValue.Hierarchical;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region ExclusiveDeletion

// Parameters:
//  ObjectsToDelete - Array of AnyRef
//  ExecutionParameters - See DeletionResult
// 
Procedure DeleteMarkedObjectsExclusively(ObjectsToDelete, ExecutionParameters)
	
	ExecutionParameters.RefSearchExclusions =  Common.RefSearchExclusions();
	For Each CancelException In CancelRefsSearchExceptionsOnDeleteObjects() Do
		ExecutionParameters.RefSearchExclusions.Delete(CancelException);
	EndDo;
	
	If Not ExecutionParameters.Property("ExcludingRules") Then
		ExecutionParameters.Insert("ExcludingRules", New Map); // Cache of search exceptions rules.
	EndIf;
	
	MetadataInfo = MetadataInfo(ExecutionParameters, ObjectsToDelete);
	TypesInformation = MarkedObjectsDeletionInternal.TypesInformation(ObjectsToDelete);
	SubordinateObjects = New Array;
	DeletableObjectsInfoRecords = StandardSubsystemsServer.ObjectAttributeValuesIfExist(ObjectsToDelete, 
		"DeletionMark,DataVersion");
	
	For IndexOf = -(ObjectsToDelete.Count() - 1) To 0 Do
		RemovableObject = ObjectsToDelete[-IndexOf];
		
		DeletableObjectInfoRecords = New Map;
		DeletableObjectInfoRecords[RemovableObject] = New Structure("DataVersion");
		DeletableObjectInfoRecords[RemovableObject].DataVersion = 
			?(ValueIsFilled(DeletableObjectsInfoRecords[RemovableObject]), 
				DeletableObjectsInfoRecords[RemovableObject].DataVersion, Undefined);
		If Not ObjectDeleted(RemovableObject, DeletableObjectInfoRecords) 
				And Not DeletableObjectsInfoRecords[RemovableObject].DeletionMark Then
			ReasonForNotDeletion = New Structure;
			ReasonForNotDeletion.Insert("ItemToDeleteRef", RemovableObject);
			ReasonForNotDeletion.Insert("UsageInstance1", NStr("en = 'The object being deleted is not marked for deletion.';"));
			ReasonForNotDeletion.Insert("FoundMetadata");
			WriteReasonToResult(ExecutionParameters, ReasonForNotDeletion, TypesInformation);
			ObjectsToDelete.Delete(-IndexOf);
			Continue;
		EndIf;
		
		MetadataInformation = MetadataInfo.Find(TypeOf(RemovableObject), "Type");
		MetadataInformation.Hierarchical = False; // Search only for subordinate items.
		
		// @skip-check query-in-loop - Batch processing of a large amount of data.
		ChildSubordinateObjects = ChildSubordinateItems(RemovableObject, MetadataInformation);
		For Each SubordinateObject In ChildSubordinateObjects Do
			If SubordinateObject.DeletionMark Or SubordinateObject.ElementType = "Subordinated" Then
				SubordinateObjects.Add(SubordinateObject.Item);
			EndIf;
		EndDo;
	EndDo;
	CommonClientServer.SupplementArray(ObjectsToDelete, SubordinateObjects);
	
	Context = New Structure;
	BeforeDeletingAGroupOfObjects(Context, ObjectsToDelete);
	
	TypesInformation = New Map; 
	While ObjectsToDelete.Count() > 0 Do
		
		ObjectsPreventingDeletion = New ValueTable;
		
		// Attempt to delete objects with reference integrity control.
		SetPrivilegedMode(True);
		Try
			DeleteObjects(ObjectsToDelete, True, ObjectsPreventingDeletion);
		Except
			ErrorInfo = ErrorInfo();
			WriteWarning(NStr("en = 'Couldn''t delete items due to:';"), Undefined, ErrorInfo);
			ErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo);

			Messages = TimeConsumingOperations.UserMessages(True);
			For Each Message In Messages Do 
				ErrorDescription = ErrorDescription + Chars.LF + Chars.LF + Message.Text;
			EndDo;
			AfterDeletingAGroupOfObjects(Context, False);
			
			Raise ErrorDescription;
		EndTry;
		
		SetPrivilegedMode(False);
		
		If ObjectsPreventingDeletion.Columns.Count() < 3 Then
			Raise NStr("en = 'Cannot delete the objects.';");
		EndIf;
		
		InternalDataLinks = Common.InternalDataLinks(ObjectsPreventingDeletion, ExecutionParameters.RefSearchExclusions);

		// Assign column names to the table of conflicts occurred upon deletion.
		ObjectsPreventingDeletion.Columns[0].Name = "ItemToDeleteRef";
		ObjectsPreventingDeletion.Columns[1].Name = "UsageInstance1";
		ObjectsPreventingDeletion.Columns[2].Name = "Metadata";
		
		AllLinksInExceptions = True;
		
		AfterDeletingAGroupOfObjects(Context, ObjectsPreventingDeletion.Count() = 0);
		
		TypesInformation = MarkedObjectsDeletionInternal.TypesInformation(
			ObjectsPreventingDeletion.UnloadColumn("ItemToDeleteRef"), TypesInformation); 

		// Analyze occurrences of the objects marked for deletion.
		For Each TableRow In ObjectsPreventingDeletion Do
			// Check excluding rights.
			If InternalDataLinks[TableRow] <> Undefined
					Or LinkOnlyToLeadingRegistersDimensions(TableRow) 
					Or Common.IsSequence(TableRow.Metadata) Then 
				Continue; // The link does not prevent deletion.
			EndIf;
			
			// Check for a detected reference among objects being deleted.
			IndexOf = ObjectsToDelete.Find(TableRow.UsageInstance1);
			If IndexOf <> Undefined Then
				Continue; // The link does not prevent deletion.
			EndIf;
			
			// Cannot delete the object (a detected reference or register record prevents deletion).
			AllLinksInExceptions = False;
			
			// Narrow down the objects to be deleted.
			IndexOf = ObjectsToDelete.Find(TableRow.ItemToDeleteRef);
			If IndexOf <> Undefined Then
				ObjectsToDelete.Delete(IndexOf);
			EndIf;
			
			WriteReasonToResult(ExecutionParameters, TableRow, TypesInformation);
		EndDo;
		
		// Delete objects without control if all the links are in reference search exceptions.
		If AllLinksInExceptions Then
			SetPrivilegedMode(True);
			DeleteObjects(ObjectsToDelete, False);
			AfterDeletingAGroupOfObjects(Context, True);
			SetPrivilegedMode(False);
			Break;
		EndIf;
	EndDo;
	
	ExecutionParameters.Insert("Trash", ObjectsToDelete);
EndProcedure

Procedure WriteWarning(Val LongDesc, Val ItemPresentation, Val ErrorInfo)
	If TypeOf(ErrorInfo) = Type("ErrorInfo") Then
		TextForLog = ErrorProcessing.DetailErrorDescription(ErrorInfo);
	Else
		TextForLog = ErrorInfo;
	EndIf;
	TextForLog = StringFunctionsClientServer.SubstituteParametersToString(LongDesc, ItemPresentation) 
		+ Chars.LF + TextForLog;
	WriteLogEvent(NStr("en = 'Delete marked objects';", Common.DefaultLanguageCode()),
		EventLogLevel.Warning,,, TextForLog);
EndProcedure

Procedure WriteReasonToResult(ExecutionParameters, TableRow, TypesInformation)
	ObjectType = TypeOf(TableRow.ItemToDeleteRef);
	TypeInformation = TypesInformation[ObjectType]; // See MarkedObjectsDeletionInternal.TypeInformation
	If TypeInformation.Technical Then
		Return;
	EndIf;
	
	// Add non-deleted objects.
	If ExecutionParameters.NotTrash.Find(TableRow.ItemToDeleteRef) = Undefined Then
		ExecutionParameters.NotTrash.Add(TableRow.ItemToDeleteRef);
	EndIf;

	Cause = ExecutionParameters.ObjectsPreventingDeletion.Add();
	FillPropertyValues(Cause, TableRow);

	UsageInstance1 = TableRow.UsageInstance1;	 
	If TypeOf(UsageInstance1) = Type("String") Then
		Cause.ErrorDescription = UsageInstance1;
		Cause.UsageInstance1 = Undefined;
	EndIf; 

	If UsageInstance1 = Undefined 
		And Not Metadata.Constants.Contains(TableRow.Metadata) Then
			Cause.ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Unresolvable references detected (%1)';"),
				TableRow.Metadata.Presentation());
	EndIf;
	
EndProcedure

Function LinkOnlyToLeadingRegistersDimensions(DataLinkDetails)

	Result = False;
	If Not Common.IsRegister(DataLinkDetails.Metadata) Then
		Return Result;
	EndIf;	

	For Each Dimension In DataLinkDetails.Metadata.Dimensions Do
		
		If DataLinkDetails.UsageInstance1[Dimension.Name] = DataLinkDetails.ItemToDeleteRef
				And Dimension.Master Then
			Result = True;
			Break;
		EndIf;
		
		If DataLinkDetails.UsageInstance1["Recorder"] = DataLinkDetails.ItemToDeleteRef Then
			Result = True;
		EndIf;
		
	EndDo;	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Transfer information to the client.

// Parameters:
//   ExecutionParameters - See DeletionResult 
//   CollectionName - String
//
Procedure MarkCollectionTraversalProgress(ExecutionParameters, CollectionName)
	ExecutionParameters.Number = ExecutionParameters.Number + 1;
	
	Percent = Round(100 * (ExecutionParameters.ProcessedItemsCount)
		/ ExecutionParameters.CountOfItemsToDelete);
	AdditionalParameters = Undefined;
	
	// Prepare parameters to be passed.
	If CollectionName = "BeforeSearchForItemsMarkedForDeletion" Then
		
		Text = NStr("en = 'Preparing to search for objects marked for deletion.';");
		
	ElsIf CollectionName = "FindMarkedForDeletion" Then
		
		Text = NStr("en = 'Searching for objects marked for deletion.';");
		
	ElsIf CollectionName = "AllObjectsMarkedForDeletion" Then
		
		Text = NStr("en = 'Analyzing objects marked for deletion.';");
		
	ElsIf CollectionName = "ExclusiveDeletion" Then
		
		Text = NStr("en = 'Deleting objects.';");
		
	ElsIf CollectionName = "UserObjects" Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("SessionNumber", InfoBaseSessionNumber());
		AdditionalParameters.Insert("ProcessedItemsCount", ExecutionParameters.ProcessedItemsCount);
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Processed %1 of %2';"),
			ExecutionParameters.ProcessedItemsCount,
			ExecutionParameters.CountOfItemsToDelete);
		
	ElsIf CollectionName = "ToRedelete" Then
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Analyzing skipped objects: %1 out of %2.';"),
			Format(ExecutionParameters.Number, "NZ=0; NG="),
			Format(ExecutionParameters.Total, "NZ=0; NG="));
		
	ElsIf CollectionName = "ObjectsPreventingDeletion" Then
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Analyzing objects that prevent deletion: %1 out of %2.';"),
			Format(ExecutionParameters.Number, "NZ=0; NG="),
			Format(ExecutionParameters.Total, "NZ=0; NG="));
		
	Else
		
		Return;
		
	EndIf;
	
	TimeConsumingOperations.ReportProgress(Percent, Text, AdditionalParameters);
EndProcedure

#EndRegion

Function TablesMerge(Table1, Table2, SaveOrder = False)
	Return MarkedObjectsDeletionInternal.TablesMerge(Table1, Table2, SaveOrder);
EndFunction

Procedure SendStatistics1(DeletionMode, RunTime, ItemsToDeleteCount)
	
	If Not Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Return;
	EndIf;	
	
	ModuleMonitoringCenter = Common.CommonModule("MonitoringCenter");
	ModuleMonitoringCenter.WriteBusinessStatisticsOperation(
		"Core.DeleteMarkedObjects."+DeletionMode, RunTime,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Number of items: %1';"), ItemsToDeleteCount));
		
EndProcedure

Function CancelRefsSearchExceptionsOnDeleteObjects()

	CancelExceptions = New Array;
	CancelExceptions.Add(Metadata.Catalogs.ExternalUsers);
	Return CancelExceptions;

EndFunction

#EndRegion

#EndIf
