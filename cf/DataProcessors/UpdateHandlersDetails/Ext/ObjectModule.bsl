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

#Region Variables

Var PluralForm Export;
Var SingularForm Export;
Var SubsystemsModules Export;
Var PrioritizingMetadataTypes;

#EndRegion

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NotCheckedAttributeArray = New Array;
	
	If UpdateHandlers.Count() = 1 Then
		If StrFind(UpdateHandlers[0].Procedure, "FirstRun") > 0 Then
			NotCheckedAttributeArray.Add("UpdateHandlers.Version");
		EndIf;
		ExecutionMode = UpdateHandlers[0].ExecutionMode;
		If ExecutionMode = "Exclusively" Or ExecutionMode = "Seamless" Then
			NotCheckedAttributeArray.Add("UpdateHandlers.UpdateDataFillingProcedure");
			NotCheckedAttributeArray.Add("UpdateHandlers.Comment");
		EndIf;
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributeArray);
	
EndProcedure

#EndRegion

#Region Private

#Region QueueNumbersFilling

// Fills in a queue number
//
// Parameters:
//  UpdateIterations - Array of See InfobaseUpdateInternal.UpdateIteration
//
Procedure FillQueueNumber(UpdateIterations) Export
	
	ImportSubsystemsHandlers(UpdateIterations);
	BuildQueue(True);
	SetQueueNumber(UpdateIterations);
	
EndProcedure

// Imports details of configuration handlers to the data processor tables
//
Procedure ImportHandlers() Export
	
	StartTotal = CurrentUniversalDateInMilliseconds();
	Measurements = New Structure;
	
	SubsystemsHandlers = NewSubsystemsHandlers();
	SubsystemsDetails1    = StandardSubsystemsCached.SubsystemsDetails();
	LibraryOrder = 1;
	For Each SubsystemName In SubsystemsDetails1.Order Do
		
		SubsystemDetails = SubsystemsDetails1.ByNames.Get(SubsystemName);
		Module             = Common.CommonModule(SubsystemDetails.MainServerModule);
		
		Handlers = InfobaseUpdate.NewUpdateHandlerTable();
		Module.OnAddUpdateHandlers(Handlers);
		
		HandlerRow = SubsystemsHandlers.Add();
		
		HandlerRow.Subsystem                            = SubsystemName;
		HandlerRow.Version                                = TrimAll(SubsystemDetails.Version);
		HandlerRow.MainServerModuleName          = SubsystemDetails.MainServerModule;
		HandlerRow.DeferredHandlersExecutionMode = SubsystemDetails.DeferredHandlersExecutionMode;
		HandlerRow.Handlers                           = Handlers;
		HandlerRow.LibraryOrder                     = LibraryOrder;
		
		LibraryOrder = LibraryOrder + 1;
	EndDo;
	
	ImportSubsystemsHandlers(SubsystemsHandlers);
	
	Measurements.Insert("TotalImportHandlers", TimeDifference1((CurrentUniversalDateInMilliseconds() - StartTotal)/1000));
	
EndProcedure

// Imports details of subsystem handlers to the data processor tables
//
// Parameters:
//  SubsystemsHandlers - See NewSubsystemsHandlers
// 
Procedure ImportSubsystemsHandlers(SubsystemsHandlers)
	
	AdditionalInfo = Undefined;
	If TypeOf(SubsystemsHandlers) = Type("Array") Then
		AdditionalInfo = New Map;
		SubsystemsDetails = StandardSubsystemsCached.SubsystemsDetails();
		For Each Library In SubsystemsHandlers Do
			InformationRecords = SubsystemsDetails.ByNames[Library.Subsystem];
			MoreInformation = MoreInformation();
			MoreInformation.DeferredHandlersExecutionMode = InformationRecords.DeferredHandlersExecutionMode;
			MoreInformation.LibraryOrder = SubsystemsDetails.Order.Find(Library.Subsystem) + 1;
			AdditionalInfo.Insert(Library.Subsystem, MoreInformation);
		EndDo;
	EndIf;
	
	UpdateHandlers.Clear();
	ObjectsToRead.Clear();
	ObjectsToChange.Clear();
	ObjectsToLock.Clear();
	ExecutionPriorities.Clear();
	
	SubsystemsModules = New Structure;
	For Each Library In SubsystemsHandlers Do
		
		If AdditionalInfo = Undefined Then
			MoreInformation = MoreInformation();
			MoreInformation.DeferredHandlersExecutionMode = Library.DeferredHandlersExecutionMode;
			MoreInformation.LibraryOrder = Library.LibraryOrder;
		Else
			MoreInformation = AdditionalInfo[Library.Subsystem];
		EndIf;
		
		ImportHandlersTable(Library, MoreInformation);
		
		SubsystemsModules.Insert(Library.Subsystem, Library.MainServerModuleName);
		
	EndDo;
	
	UpdateHandlersConflictsInfo();
	
EndProcedure

// Defines handler intersections by the data of objects to read/to change
// and updates the data on whether handler execution priorities are specified.
//
// Returns:
//   ValueTable - new data of the UpdateHandlers tabular section
//
Function UpdateHandlersConflictsInfo() Export
	
	Query = TempTablesQuery();
	QueriesTexts = New Array;
	QueriesTexts.Add(TempTablesQueryText());
	QueriesTexts.Add(ConflictsDataUpdateQueryText());
	Query.Text = StrConcat(QueriesTexts, Common.QueryBatchSeparator());
	Query.SetParameter("Parallel", "Parallel");
	Query.SetParameter("Deferred", "Deferred");
	
	QueriesResult = Query.ExecuteBatch();
	LastQueryIndex = QueriesResult.UBound();
	
	NewDetails = QueriesResult[LastQueryIndex].Unload();
	NewDetails.Sort("Subsystem DESC, Procedure");
	UpdateHandlers.Load(NewDetails);
	
	Priorities = QueriesResult[LastQueryIndex-1].Unload();
	ExecutionPriorities.Load(Priorities);
	
	Conflicts1 = QueriesResult[LastQueryIndex-2].Unload();
	HandlersConflicts.Load(Conflicts1);
	
	ReadOrder = QueriesResult[LastQueryIndex-3].Unload();
	LowPriorityReading.Load(ReadOrder);
	
	
	PrioritiesByRecord = 0;
	NotByWritingPriority = 0;
	HandlersByRecord = New Map;
	HandlersNotByRecord = New ValueList;
	ObjectsBeingDevelopedTotalCount = 0;
	OrdersAreNotEqual = 0;
	NotAnyOrder = 0;
	InverseOrder = 0;
	SubsystemsToDevelop = SubsystemsToDevelop();
	Priorities.Columns.Insert(5, "NotAny", New TypeDescription("Number",New NumberQualifiers(10, 0)));
	Priorities.Columns.Insert(6, "Inversion", New TypeDescription("Number",New NumberQualifiers(10, 0)));
	For Each Priority In Priorities Do
		If Priority.Order <> "Any" And Priority.OrderAuto = "Any" And Not Priority.WriteAgain Then
			Priority.NotAny = 1;
		EndIf;
		If Priority.Order = "Before" And Priority.OrderAuto = "After"
			Or Priority.Order = "After" And Priority.OrderAuto = "Before" Then
			Priority.Inversion = 1;
		EndIf;
		If SubsystemsToDevelop.Find(Priority.Subsystem1) <> Undefined Then
			OrdersAreNotEqual = OrdersAreNotEqual + Priority.OrdersAreNotEqual;
			NotAnyOrder = NotAnyOrder + Priority.NotAny;
			InverseOrder = InverseOrder + Priority.Inversion;
			NotByWritingPriority = NotByWritingPriority + Priority.NotByWritingPriority;
			If Priority.WritingPriority Then
				PrioritiesByRecord = PrioritiesByRecord + 1;
				HandlersByRecord.Insert(Priority.Ref + "_" + Priority.Handler2,True);
				HandlersByRecord.Insert(Priority.Handler2 + "_" + Priority.Ref,True);
			EndIf;
			ObjectsBeingDevelopedTotalCount = ObjectsBeingDevelopedTotalCount + 1;
		EndIf;
	EndDo;
	
	For Each Priority In Priorities Do
		If SubsystemsToDevelop.Find(Priority.Subsystem1) <> Undefined Then
			If HandlersByRecord[Priority.Ref + "_" + Priority.Handler2] = Undefined
					And HandlersByRecord[Priority.Handler2 + "_" + Priority.Ref] = Undefined Then
				HandlersNotByRecord.Add(Priority.Ref,Priority.Handler2);
			EndIf;
		EndIf;
	EndDo;
	
	Return NewDetails;
	
EndFunction

// Builds a handler execution queue based on intersection data and specified handler execution priorities.
//
// Parameters:
//   RaiseException - Boolean - throw an exception if errors occurred
//
// Returns:
//   Boolean - True if no errors occurred when building the queue
//
Function BuildQueue(RaiseException = False) Export
	
	StartTotal = CurrentUniversalDateInMilliseconds();
	Measurements = New Structure;
	
	Errors.Clear();
	If UpdateHandlers.Count() = 0 Then
		ImportHandlers();
	Else
		BeginTime = CurrentUniversalDateInMilliseconds();
		UpdateHandlersConflictsInfo();
		Measurements.Insert("UpdateHandlersConflictsInfo", TimeDifference1((CurrentUniversalDateInMilliseconds() - BeginTime)/1000));
	EndIf;
	
	BeginTime = CurrentUniversalDateInMilliseconds();
	CanBuildQueue = CanBuildQueue();
	Measurements.Insert("CanBuildQueue", TimeDifference1((CurrentUniversalDateInMilliseconds() - BeginTime)/1000));
	If Not CanBuildQueue Then
		OutputErrorMessage(RaiseException);
		Return False;
	EndIf;
	
	BeginTime = CurrentUniversalDateInMilliseconds();
	HasExecutionCycle = HasHandlersExecutionCycle();
	Measurements.Insert("HasHandlersExecutionCycle", TimeDifference1((CurrentUniversalDateInMilliseconds() - BeginTime)/1000));
	If HasExecutionCycle Then
		OutputErrorMessage(RaiseException);
		Return False;
	EndIf;
	
	BeginTime = CurrentUniversalDateInMilliseconds();
	Query = TempTablesQuery();
	Query.SetParameter("Parallel", "Parallel");
	Query.SetParameter("Deferred", "Deferred");
	
	QueriesTexts = New Array;
	QueriesTexts.Add(Query.Text);
	QueriesTexts.Add(TempQueueBuildingTablesText());
	
	Query.Text = StrConcat(QueriesTexts, Common.QueryBatchSeparator());
	
	HandlersQueue = New Map;
	HandlersAvailabilityInQueue = New Map;
	MaxQueue = 1;
	
	SelectionByHandlersToAdd = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionByHandlersToAdd.Next() Do
		
		HandlerToAdd = SelectionByHandlersToAdd.Handler;
		
		HandlerDetails = New Structure;
		HandlerDetails.Insert("Queue",1);
		HandlerDetails.Insert("LinkedHandlers", New Map);
		
		HandlersQueue.Insert(HandlerToAdd, HandlerDetails);
		
		AddHandlerToExistenceInQueue(HandlersAvailabilityInQueue, 1, HandlerToAdd, MaxQueue);
		
		If Not SelectionByHandlersToAdd.HasIntersections Then
			Continue;
		EndIf;
		
		SelectionByRelatedHandlers = SelectionByHandlersToAdd.Select(QueryResultIteration.ByGroups);
		
		While SelectionByRelatedHandlers.Next() Do
			
			LinkedHandler = SelectionByRelatedHandlers.LinkedHandler;
			
			LinkDetails = New Structure;
			LinkDetails.Insert("QueuingOrder", SelectionByRelatedHandlers.QueuingOrder);
			LinkDetails.Insert("WriteObjectAgain", SelectionByRelatedHandlers.HasWriteAgain);
			
			HandlersQueue[HandlerToAdd].LinkedHandlers.Insert(LinkedHandler, LinkDetails); 
			
		EndDo;
		
		RecursionData = New Structure("Handler", HandlerToAdd);
		RecursionData.Insert("LinkedItems", New Array);
		RecursionData.Insert("ProcessedItems", New Map);
		ShiftRecursivelyLinkedHandlers(HandlersQueue, HandlersAvailabilityInQueue, HandlerToAdd, MaxQueue, RecursionData);
		
	EndDo;
	
	// Clear the new queue.
	If UpdateHandlers.Total("NewQueue") > 0 Then
		For Each LongDesc In UpdateHandlers Do
			LongDesc.NewQueue = 0;
		EndDo;
	EndIf;
	
	// Remove blanks in the queue number, which could appear during recursive transitions.
	NumberChange = 0;
	For QueueNumber = 1 To MaxQueue Do
		
		If HandlersAvailabilityInQueue.Get(QueueNumber) = Undefined
			Or HandlersAvailabilityInQueue[QueueNumber].Count() = 0 Then
			NumberChange = NumberChange + 1;
		Else 
			For Each Handler In HandlersAvailabilityInQueue[QueueNumber] Do
				
				NewQueueNumber = HandlersQueue[Handler.Key].Queue - NumberChange;
				HandlerDetails = UpdateHandlers.Find(Handler.Key ,"Ref");
				If HandlerDetails.NewQueue <> NewQueueNumber Then
					HandlerDetails.NewQueue = NewQueueNumber;
				EndIf;
				
			EndDo;
		EndIf;
		
	EndDo;
	
	TempTableManager = Query.TempTablesManager;
	UpdateTempTable(TempTableManager, "Handlers", UpdateHandlers.Unload());
	Measurements.Insert("QueueBuilding", TimeDifference1((CurrentUniversalDateInMilliseconds() - BeginTime)/1000));
	
	BeginTime = CurrentUniversalDateInMilliseconds();
	OK1 = Not HasQueueBuildingErrors(Query);
	Measurements.Insert("HasQueueBuildingErrors", TimeDifference1((CurrentUniversalDateInMilliseconds() - BeginTime)/1000));
	
	If Not OK1 Then
		OutputErrorMessage(RaiseException);
	EndIf;
	
	Measurements.Insert("TotalInQueueBuild", TimeDifference1((CurrentUniversalDateInMilliseconds() - StartTotal)/1000));
	
	Return OK1;
	
EndFunction

#EndRegion

#Region InitializationAndFilling

Procedure ConstantsInitialization()
	
	PluralForm = New Map;
	PluralForm.Insert("Constant", "Constants");
	PluralForm.Insert("Catalog", "Catalogs");
	PluralForm.Insert("Document", "Documents");
	PluralForm.Insert("ChartOfCharacteristicTypes", "ChartsOfCharacteristicTypes");
	PluralForm.Insert("ExchangePlan", "ExchangePlans");
	PluralForm.Insert("ChartOfAccounts", "ChartsOfAccounts");
	PluralForm.Insert("ChartOfCalculationTypes", "ChartsOfCalculationTypes");
	PluralForm.Insert("InformationRegister", "InformationRegisters");
	PluralForm.Insert("AccumulationRegister", "AccumulationRegisters");
	PluralForm.Insert("AccountingRegister", "AccountingRegisters");
	PluralForm.Insert("CalculationRegister", "CalculationRegisters");
	PluralForm.Insert("BusinessProcess", "BusinessProcesses");
	PluralForm.Insert("Task", "Tasks");
	PluralForm.Insert("Report", "Reports");
	PluralForm.Insert("DataProcessor", "DataProcessors");
	PluralForm.Insert("CommonModule", "CommonModule");

	SingularForm = New Map;
	For Each Class In PluralForm Do
		SingularForm.Insert(Class.Value, Class.Key);
	EndDo;
	
EndProcedure

#EndRegion

#Region HandlersImport

Procedure ImportHandlersTable(Library, AdditionalInfo)
	
	For Each HandlerDetails In Library.Handlers Do // See InfobaseUpdate.NewUpdateHandlerTable
		
		Names = StrSplit(HandlerDetails.Procedure, ".");
		Names.Delete(Names.UBound());
		
		NewDetails = UpdateHandlers.Add();
		NewDetails.Ref = HandlerDetails.Id;
		If Not ValueIsFilled(HandlerDetails.Id) Then
			NewDetails.Ref = New UUID;
		EndIf;
		FillPropertyValues(NewDetails, HandlerDetails);
		NewDetails.Subsystem = Library.Subsystem;
		NewDetails.MainServerModuleName = Library.MainServerModuleName;
		NewDetails.LibraryName = StrReplace(Library.MainServerModuleName, "InfobaseUpdate", "");
		NewDetails.LibraryOrder = AdditionalInfo.LibraryOrder;
		NewDetails.ObjectName = StrConcat(Names,".");
		NewDetails.DeferredHandlersExecutionMode = AdditionalInfo.DeferredHandlersExecutionMode;
		NewDetails.Order = HandlerDetails.Order;
		If Not ValueIsFilled(NewDetails.Order) Then
			NewDetails.Order = AdditionalInfo.Order;
		EndIf;
		NewDetails.VersionAsNumber = VersionAsNumber(HandlerDetails.Version);
		FillRevisionVersion(NewDetails);
		
		ImportHandlerObjects("ObjectsToRead",   NewDetails.Ref, HandlerDetails.ObjectsToRead);
		ImportHandlerObjects("ObjectsToChange", NewDetails.Ref, HandlerDetails.ObjectsToChange);
		ImportHandlerObjects("ObjectsToLock",NewDetails.Ref, HandlerDetails.ObjectsToLock);
		ImportHandlerObjects("NewObjects",NewDetails.Ref, HandlerDetails.NewObjects);
		ImportHandlerPriorities(NewDetails.Ref, HandlerDetails.ExecutionPriorities);
	EndDo;

EndProcedure

Procedure ImportHandlerObjects(TabularSectionName, HandlerRef, ObjectsAsString)
	
	If IsBlankString(ObjectsAsString) Then
		Return;
	EndIf;
	
	ObjectsNames = StrSplit(ObjectsAsString, ",", False);
	For Each ObjectName In ObjectsNames Do
		
		If TabularSectionName = "ObjectsToLock" Then
			LockFlagSelected = RaiseFlag("LockInterface", "ObjectsToChange", ObjectName, HandlerRef);
			If Not LockFlagSelected Then
				LockFlagSelected = RaiseFlag("LockInterface", "ObjectsToRead", ObjectName, HandlerRef);
			EndIf;
		EndIf;
		
		If TabularSectionName = "NewObjects" Then
			RaiseFlag("NewObjects", "ObjectsToChange", ObjectName, HandlerRef);
			Continue;
		EndIf;
		
		If TabularSectionName <> "ObjectsToLock" Or Not LockFlagSelected Then
			TabularSection = ThisObject[TabularSectionName]; // See DataProcessor.UpdateHandlersDetails.ObjectsToRead
			NewDetails = TabularSection.Add();
			NewDetails.Ref = HandlerRef;
			NewDetails.MetadataObject = TrimAll(ObjectName);
			If TabularSectionName <> "ObjectsToLock" Then
				NewDetails.OrderOfType = ObjectTypeOrder(TrimAll(ObjectName));
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

Function RaiseFlag(FlagName, TSName, ObjectName, HandlerRef)
	
	Filter = New Structure("Ref,MetadataObject", HandlerRef, ObjectName);
	FoundObjects = ThisObject[TSName].FindRows(Filter);
	For Each FoundObject In FoundObjects Do
		FoundObject[FlagName] = True;
	EndDo;
	Return FoundObjects.Count() > 0;
	
EndFunction

Procedure ImportHandlerPriorities(HandlerRef, HandlerPriorities)
	
	If HandlerPriorities = Undefined Then
		Return;
	EndIf;
		
	For Each Priority In HandlerPriorities Do
		NewPriority = ExecutionPriorities.Add();
		NewPriority.Ref = HandlerRef;
		NewPriority.Order = Priority.Order;
		NewPriority.Procedure2 = Priority.Procedure;
	EndDo;
	
EndProcedure

// Returns:
//   ValueTable:
//   * Subsystem - String 
//   * Version - String
//   * MainServerModuleName - String
//   * DeferredHandlersExecutionMode - String
//   * Handlers - String
//   * LibraryOrder - Number
//
Function NewSubsystemsHandlers()
	
	SubsystemsHandlers = New ValueTable;
	
	SubsystemsHandlers.Columns.Add("Subsystem");
	SubsystemsHandlers.Columns.Add("Version");
	SubsystemsHandlers.Columns.Add("MainServerModuleName");
	SubsystemsHandlers.Columns.Add("DeferredHandlersExecutionMode");
	SubsystemsHandlers.Columns.Add("Handlers");
	SubsystemsHandlers.Columns.Add("LibraryOrder");
	
	Return SubsystemsHandlers;
	
EndFunction

Procedure FillRevisionVersion(LongDesc)
	
	If StrOccurrenceCount(LongDesc.Version, ".") <> 3 Then
		Return;
	EndIf;
	
	VersionNumbers = StrSplit(LongDesc.Version, ".");
	VersionNumbers.Delete(0);
	LongDesc.RevisionAsNumber = VersionAsNumber(StrConcat(VersionNumbers, "."));
	
EndProcedure

#EndRegion

#Region ConflictsDetection

Function ConflictsDataUpdateQueryText()
	
	DestructionText = "DROP HandlersConflicts";
	
#Region TextOfHandlersIntersection
	// Other handlers read and write modifiable objects
	TextOfHandlersIntersection = 
	"SELECT
	|	T.MetadataObject AS MetadataObject,
	|	T.HandlerWriter AS HandlerWriter,
	|	MIN(UpdatePriorities1.OrderOfType) AS OrderOfType1,
	|	T.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	MIN(UpdatePriorities2.OrderOfType) AS OrderOfType2,
	|	MIN(T.WritingPriority) AS WritingPriority,
	|	MAX(T.DataToReadWriter) AS DataToReadWriter,
	|	MAX(T.WriteAgain) AS WriteAgain,
	|	MAX(T.ThisIsReader) AS ThisIsReader
	|INTO HandlersIntersections
	|FROM 
	|(
	|
	|	SELECT
	|		ObjectsToChange.Ref AS HandlerWriter,
	|		ObjectsToReadByOtherHandlers.Ref AS ReadOrWriteHandler2,
	|		ObjectsToChange.MetadataObject AS MetadataObject,
	|		TRUE AS WritingPriority,
	|		TRUE AS DataToReadWriter,
	|		FALSE AS WriteAgain,
	|		TRUE AS ThisIsReader
	|	FROM
	|		ObjectsToChange AS ObjectsToChange
	|		INNER JOIN ObjectsToRead AS ObjectsToReadByOtherHandlers
	|		ON ObjectsToChange.MetadataObject = ObjectsToReadByOtherHandlers.MetadataObject
	|			AND ObjectsToChange.ExecutionMode = ObjectsToReadByOtherHandlers.ExecutionMode
	|			AND ObjectsToChange.Ref <> ObjectsToReadByOtherHandlers.Ref
	|	WHERE
	|		ObjectsToChange.DeferredHandlersExecutionMode = &Parallel
	|		AND ObjectsToChange.ExecutionMode = &Deferred
	|		AND NOT ObjectsToChange.NewObjects
	|		AND ObjectsToReadByOtherHandlers.DeferredHandlersExecutionMode = &Parallel
	|		AND ObjectsToReadByOtherHandlers.ExecutionMode = &Deferred
	|		
	|	UNION ALL
	|
	|	
	|	SELECT
	|		ObjectsToChange.Ref AS HandlerWriter,
	|		ObjectsChangedByOtherHandlers.Ref AS ReadOrWriteHandler2,
	|		ObjectsToChange.MetadataObject AS MetadataObject,
	|		FALSE AS WritingPriority,
	|		FALSE AS DataToReadWriter,
	|		TRUE AS WriteAgain,
	|		FALSE AS ThisIsReader
	|	FROM
	|		ObjectsToChange AS ObjectsToChange
	|		INNER JOIN ObjectsToChange AS ObjectsChangedByOtherHandlers
	|		ON ObjectsToChange.MetadataObject = ObjectsChangedByOtherHandlers.MetadataObject
	|			AND ObjectsToChange.ExecutionMode = ObjectsChangedByOtherHandlers.ExecutionMode
	|			AND ObjectsToChange.Ref <> ObjectsChangedByOtherHandlers.Ref
	|	WHERE
	|		ObjectsToChange.DeferredHandlersExecutionMode = &Parallel
	|		AND ObjectsToChange.ExecutionMode = &Deferred
	|		AND NOT ObjectsToChange.NewObjects
	|		AND ObjectsChangedByOtherHandlers.DeferredHandlersExecutionMode = &Parallel
	|		AND ObjectsChangedByOtherHandlers.ExecutionMode = &Deferred
	|
	|) AS T
	|LEFT JOIN TypeUpdatePriorities AS UpdatePriorities1
	|	ON T.HandlerWriter = UpdatePriorities1.Ref
	|LEFT JOIN TypeUpdatePriorities AS UpdatePriorities2
	|	ON T.ReadOrWriteHandler2 = UpdatePriorities2.Ref
	|
	|GROUP BY
	|	T.MetadataObject,
	|	T.HandlerWriter,
	|	T.ReadOrWriteHandler2
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2";
#EndRegion
	
#Region TextTTConflicts
	TextTTConflicts = 
	"SELECT
	|	T.HandlerWriter AS HandlerWriter,
	|	T.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	MIN(T.OrderOfType1) AS OrderOfType1,
	|	MIN(T.OrderOfType2) AS OrderOfType2,
	|	MIN(T.WritingPriority) AS WritingPriority,
	|	MAX(T.DataToReadWriter) AS DataToReadWriter,
	|	MAX(T.WriteAgain) AS WriteAgain,
	|	MAX(T.ThisIsReader) AS ThisIsReader
	|INTO ttConflicts
	|FROM
	|	(SELECT
	|		Conflicts1.HandlerWriter AS HandlerWriter,
	|		Conflicts1.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|		Conflicts1.OrderOfType1 AS OrderOfType1,
	|		Conflicts1.OrderOfType2 AS OrderOfType2,
	|		Conflicts1.WritingPriority AS WritingPriority,
	|		Conflicts1.DataToReadWriter AS DataToReadWriter,
	|		Conflicts1.WriteAgain AS WriteAgain,
	|		Conflicts1.ThisIsReader AS ThisIsReader
	|	FROM 
	|		HandlersIntersections AS Conflicts1
	|
	|	UNION ALL
	|
	|	SELECT
	|		Conflicts1.ReadOrWriteHandler2 AS HandlerWriter,
	|		Conflicts1.HandlerWriter AS ReadOrWriteHandler2,
	|		Conflicts1.OrderOfType2 AS OrderOfType2,
	|		Conflicts1.OrderOfType1 AS OrderOfType1,
	|		NOT Conflicts1.WritingPriority AS WritingPriority,
	|		Conflicts1.DataToReadWriter AS DataToReadWriter,
	|		Conflicts1.WriteAgain AS WriteAgain,
	|		FALSE AS ThisIsReader
	|	FROM 
	|		HandlersIntersections AS Conflicts1
	|	) AS T
	|
	|GROUP BY
	|	T.HandlerWriter,
	|	T.ReadOrWriteHandler2
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2";
#EndRegion
	
#Region TtPrioritiesByRecord
	TtPrioritiesByRecord = 
	"SELECT DISTINCT
	|	Conflicts1.HandlerWriter AS HandlerWriter,
	|	Conflicts1.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	Conflicts1.WritingPriority AS WritingPriority
	|INTO TtPrioritiesByRecord
	|FROM 
	|	ttConflicts AS Conflicts1
	|WHERE
	|	Conflicts1.WritingPriority
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2";
#EndRegion
	
#Region TextTTPriorities
	TextTTPriorities = 
	"SELECT DISTINCT
	|	Conflicts1.HandlerWriter AS HandlerWriter,
	|	Conflicts1.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	Conflicts1.DataToReadWriter AS DataToReadWriter,
	|	ConflictsMirrored.DataToReadWriter AS DataToReadWriter2,
	|	Conflicts1.WriteAgain AS WriteAgain,
	|	ConflictsMirrored.WriteAgain AS WriteAgain2,
	|	Conflicts1.ThisIsReader AS ThisIsReader,
	|	ConflictsMirrored.ThisIsReader AS ThisIsReader2,
	|	Conflicts1.OrderOfType1 AS OrderOfType1,
	|	Conflicts1.OrderOfType2 AS OrderOfType2,
	|	ISNULL(Handlers1.RevisionAsNumber, 0) AS RevisionAsNumber1,
	|	ISNULL(Handlers2.RevisionAsNumber, 0) AS RevisionAsNumber2,
	|	ISNULL(Handlers1.VersionAsNumber, 0) AS VersionAsNumber1,
	|	ISNULL(Handlers2.VersionAsNumber, 0) AS VersionAsNumber2,
	|	ISNULL(Handlers1.LibraryOrder, 0) AS LibraryOrder1,
	|	ISNULL(Handlers2.LibraryOrder, 0) AS LibraryOrder2,
	|
	|	CASE WHEN ISNULL(Priorities.Order, &IsBlankString) = ISNULL(PrioritiesViceVersa.Order, &IsBlankString)
	|				AND ISNULL(Priorities.Order, &IsBlankString) <> &Any
	|		THEN &IsBlankString
	|		ELSE
	|			ISNULL(Priorities.Order,
	|					ISNULL(PrioritiesViceVersa.Order, &IsBlankString))
	|	END <> &IsBlankString AS ExecutionOrderSpecified,
	|	Conflicts1.WritingPriority AS WritingPriority,
	|	CASE WHEN ISNULL(Priorities.Order, &IsBlankString) = ISNULL(PrioritiesViceVersa.Order, &IsBlankString)
	|				AND ISNULL(Priorities.Order, &IsBlankString) <> &Any
	|		THEN &IsBlankString
	|		ELSE
	|			ISNULL(Priorities.Order,
	|				ISNULL(CASE PrioritiesViceVersa.Order
	|						WHEN &Before THEN &After
	|						WHEN &After THEN &Before
	|						WHEN &Any THEN &Any
	|					END, 
	|					&IsBlankString))
	|	END AS Order,
	|	CASE
	|		WHEN Conflicts1.WritingPriority
	|			THEN &Before
	|		WHEN NOT PrioritiesByRecordInversed.WritingPriority IS NULL
	|			THEN &After
	|
	|		WHEN Conflicts1.OrderOfType1 = Conflicts1.OrderOfType2 AND Conflicts1.WriteAgain
	|				OR Conflicts1.OrderOfType1 = Conflicts1.OrderOfType2 AND Conflicts1.ThisIsReader = ConflictsMirrored.ThisIsReader
	|			THEN &Any
	|		WHEN Conflicts1.OrderOfType1 > Conflicts1.OrderOfType2
	|			OR (Conflicts1.OrderOfType1 = Conflicts1.OrderOfType2 AND NOT Conflicts1.ThisIsReader)
	|			THEN &After
	|		WHEN Conflicts1.OrderOfType1 < Conflicts1.OrderOfType2
	|			OR (Conflicts1.OrderOfType1 = Conflicts1.OrderOfType2 AND Conflicts1.ThisIsReader)
	|			THEN &Before
	|
	|		WHEN ISNULL(Handlers1.LibraryOrder, 0) = ISNULL(Handlers2.LibraryOrder, 0)
	|			AND ISNULL(Handlers1.VersionAsNumber, 0) > ISNULL(Handlers2.VersionAsNumber, 0)
	|			THEN &After
	|		WHEN ISNULL(Handlers1.LibraryOrder, 0) = ISNULL(Handlers2.LibraryOrder, 0)
	|			AND ISNULL(Handlers1.VersionAsNumber, 0) < ISNULL(Handlers2.VersionAsNumber, 0)
	|			THEN &Before
	|		ELSE
	|			&IsBlankString
	|	END AS OrderAuto
	|INTO ttPriorities
	|FROM 
	|	ttConflicts AS Conflicts1
	|	LEFT JOIN ExecutionPriorities AS Priorities
	|	ON Conflicts1.HandlerWriter = Priorities.Ref
	|		AND Conflicts1.ReadOrWriteHandler2 = Priorities.Handler2
	|
	|	LEFT JOIN ExecutionPriorities AS PrioritiesViceVersa
	|	ON Conflicts1.HandlerWriter = PrioritiesViceVersa.Handler2
	|		AND Conflicts1.ReadOrWriteHandler2 = PrioritiesViceVersa.Ref
    |
	|	LEFT JOIN ttConflicts AS ConflictsMirrored
	|	ON Conflicts1.HandlerWriter = ConflictsMirrored.ReadOrWriteHandler2
	|		AND Conflicts1.ReadOrWriteHandler2 = ConflictsMirrored.HandlerWriter
	|
	|	LEFT JOIN TtPrioritiesByRecord AS PrioritiesByRecordInversed
	|	ON Conflicts1.HandlerWriter = PrioritiesByRecordInversed.ReadOrWriteHandler2
	|		AND Conflicts1.ReadOrWriteHandler2 = PrioritiesByRecordInversed.HandlerWriter
	|
	|	LEFT JOIN Handlers AS Handlers1
	|	ON Conflicts1.HandlerWriter = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON Conflicts1.ReadOrWriteHandler2 = Handlers2.Ref
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2";
#EndRegion
	
#Region TextNewPriorities
	TextNewPriorities =
	"SELECT DISTINCT
	|	Priorities.HandlerWriter AS HandlerWriter,
	|	Priorities.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	ISNULL(Handlers1.DeferredProcessingQueue, """") AS Queue1,
	|	ISNULL(Handlers2.DeferredProcessingQueue, """") AS Queue2,
	|	Priorities.RevisionAsNumber1 AS RevisionAsNumber1,
	|	Priorities.RevisionAsNumber2 AS RevisionAsNumber2,
	|	Priorities.VersionAsNumber1 AS VersionAsNumber1,
	|	Priorities.VersionAsNumber2 AS VersionAsNumber2,
	|	Priorities.LibraryOrder1 AS LibraryOrder1,
	|	Priorities.LibraryOrder2 AS LibraryOrder2,
	|	Priorities.DataToReadWriter AS DataToReadWriter,
	|	Priorities.DataToReadWriter2 AS DataToReadWriter2,
	|	Priorities.WriteAgain AS WriteAgain,
	|	Priorities.WriteAgain2 AS WriteAgain2,
	|	Priorities.ThisIsReader AS ThisIsReader,
	|	Priorities.ThisIsReader2 AS ThisIsReader2,
	|	Priorities.OrderOfType1 AS OrderOfType1,
	|	Priorities.OrderOfType2 AS OrderOfType2,
	|	CASE 
	|		WHEN Priorities.ExecutionOrderSpecified
	|			THEN Priorities.ExecutionOrderSpecified
	|		ELSE
	|			CASE
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.LibraryOrder > 0 AND Handlers2.LibraryOrder > 0
	|					AND Handlers1.LibraryOrder < Handlers2.LibraryOrder
	|					THEN &Before
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.LibraryOrder > 0 AND Handlers2.LibraryOrder > 0
	|					AND Handlers1.LibraryOrder > Handlers2.LibraryOrder
	|					THEN &After
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.DeferredProcessingQueue > 0 AND Handlers2.DeferredProcessingQueue > 0
	|					AND Handlers1.DeferredProcessingQueue < Handlers2.DeferredProcessingQueue
	|					THEN &Before
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.DeferredProcessingQueue > 0 AND Handlers2.DeferredProcessingQueue > 0
	|					AND Handlers1.DeferredProcessingQueue > Handlers2.DeferredProcessingQueue
	|					THEN &After
	|				ELSE
	|					Priorities.OrderAuto
	|			END <> &IsBlankString
	|	END AS ExecutionOrderSpecified,
	|	Priorities.WritingPriority AS WritingPriority,
	|	CASE 
	|		WHEN Priorities.ExecutionOrderSpecified
	|			THEN Priorities.Order
	|		ELSE
	|			CASE
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.LibraryOrder > 0 AND Handlers2.LibraryOrder > 0
	|					AND Handlers1.LibraryOrder < Handlers2.LibraryOrder
	|					THEN &Before
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.LibraryOrder > 0 AND Handlers2.LibraryOrder > 0
	|					AND Handlers1.LibraryOrder > Handlers2.LibraryOrder
	|					THEN &After
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.DeferredProcessingQueue > 0 AND Handlers2.DeferredProcessingQueue > 0
	|					AND Handlers1.DeferredProcessingQueue < Handlers2.DeferredProcessingQueue
	|					THEN &Before
	|				WHEN (NOT Handlers1.SubsystemUnderDevelopment OR NOT Handlers2.SubsystemUnderDevelopment)
	|					AND Handlers1.DeferredProcessingQueue > 0 AND Handlers2.DeferredProcessingQueue > 0
	|					AND Handlers1.DeferredProcessingQueue > Handlers2.DeferredProcessingQueue
	|					THEN &After
	|				ELSE
	|					Priorities.OrderAuto
	|			END
	|	END AS Order,
	|	Priorities.OrderAuto AS OrderAuto
	|INTO NewPriorities
	|FROM 
	|	ttPriorities AS Priorities
	|
	|	LEFT JOIN Handlers AS Handlers1
	|	ON Priorities.HandlerWriter = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON Priorities.ReadOrWriteHandler2 = Handlers2.Ref
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2";
#EndRegion
	
#Region TextTTLowPriorityHandlers
	TextTTLowPriorityHandlers = 
	"SELECT DISTINCT
	|	ItemsToRead.MetadataObject AS MetadataObject,
	|	ItemsToRead.Order AS OrderReader,
	|	Editable1.Order AS OrderWriter,
	|	ItemsToRead.Ref AS Reader,
	|	Editable1.Ref AS Writer,
	|	ItemsToRead.Procedure AS ReaderProcedure,
	|	Editable1.Procedure AS WriteProcedure
	|	
	|INTO TTLowPriorityReading
	|FROM ObjectsToRead AS ItemsToRead
	|	INNER JOIN ObjectsToChange AS Editable1
	|	ON ItemsToRead.MetadataObject = Editable1.MetadataObject
	|WHERE
	|	(ItemsToRead.Order = VALUE(Enum.OrderOfUpdateHandlers.Crucial)
	|		AND Editable1.Order <> VALUE(Enum.OrderOfUpdateHandlers.Crucial))
	|	OR (ItemsToRead.Order = VALUE(Enum.OrderOfUpdateHandlers.Normal)
	|		AND Editable1.Order = VALUE(Enum.OrderOfUpdateHandlers.Noncritical))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	LowPriorityReading.Reader AS Reader,
	|	LowPriorityReading.MetadataObject AS MetadataObject,
	|	LowPriorityReading.OrderReader AS OrderReader,
	|	LowPriorityReading.OrderWriter AS OrderWriter,
	|	LowPriorityReading.OrderReader.Order AS NumberOrderReader,
	|	LowPriorityReading.OrderWriter.Order AS NumberOrderWriter,
	|	Priorities.Order AS PrioritiesOrder,
	|	LowPriorityReading.Writer AS Writer,
	|	HandlersReaders.ObjectName AS ReaderObject,
	|	WriteHandlers.ObjectName AS WriterObject,
	|	LowPriorityReading.ReaderProcedure AS ReaderProcedure,
	|	LowPriorityReading.WriteProcedure AS WriteProcedure
	|INTO ttTTLowOrderReadingWithFilterByPriority
	|FROM 
	|	TTLowPriorityReading AS LowPriorityReading
	|	LEFT JOIN NewPriorities AS Priorities
	|	ON LowPriorityReading.Reader = Priorities.HandlerWriter
	|	AND LowPriorityReading.Writer = Priorities.ReadOrWriteHandler2
	|
	|	LEFT JOIN Handlers AS HandlersReaders
	|	ON LowPriorityReading.Reader = HandlersReaders.Ref
	|
	|	LEFT JOIN Handlers AS WriteHandlers
	|	ON LowPriorityReading.Writer = WriteHandlers.Ref
	|WHERE
	|	NOT (HandlersReaders.ObjectName = WriteHandlers.ObjectName
	|		AND LowPriorityReading.OrderReader.Order < LowPriorityReading.OrderWriter.Order
	|		AND Priorities.Order = ""Before"")
	|";
#EndRegion
	
#Region IssueText
	IssueText = 
	"SELECT
	|	Issues.Handler AS Handler,
	|	MAX(Issues.DataToReadWriter) AS DataToReadWriter,
	|	MAX(Issues.WriteAgain) AS WriteAgain,
	|	MIN(Issues.ExecutionOrderSpecified) AS ExecutionOrderSpecified,
	|	MAX(Issues.LowPriorityReading) AS LowPriorityReading
	|	
	|INTO Issues
	|FROM
	|	(SELECT
	|		Issues.HandlerWriter AS Handler,
	|		Issues.DataToReadWriter AS DataToReadWriter,
	|		Issues.WriteAgain AS WriteAgain,
	|		Issues.ExecutionOrderSpecified AS ExecutionOrderSpecified,
	|		FALSE AS LowPriorityReading
	|	FROM
	|		NewPriorities AS Issues
	|	
	|	UNION ALL
	|
	|	SELECT DISTINCT
	|		LowPriorityReading.Reader AS Handler,
	|		FALSE AS DataToReadWriter,
	|		FALSE AS WriteAgain,
	|		TRUE AS ExecutionOrderSpecified,
	|		TRUE AS LowPriorityReading
	|	FROM 
	|		ttTTLowOrderReadingWithFilterByPriority AS LowPriorityReading) AS Issues
	|
	|GROUP BY
	|	Issues.Handler
	|
	|INDEX BY
	|	Handler";
#EndRegion
	
#Region TextLowPriorityHandlers
	TextLowPriorityHandlers = 
	"SELECT DISTINCT
	|	LowPriorityReading.Reader AS Ref,
	|	LowPriorityReading.MetadataObject AS MetadataObject,
	|	LowPriorityReading.OrderReader AS OrderReader,
	|	LowPriorityReading.OrderWriter AS OrderWriter,
	|	LowPriorityReading.OrderReader.Order AS NumberOrderReader,
	|	LowPriorityReading.OrderWriter.Order AS NumberOrderWriter,
	|	LowPriorityReading.PrioritiesOrder AS PrioritiesOrder,
	|	LowPriorityReading.Writer AS Writer,
	|	LowPriorityReading.ReaderObject AS ReaderObject,
	|	LowPriorityReading.WriterObject AS WriterObject,
	|	LowPriorityReading.ReaderProcedure AS ReaderProcedure,
	|	LowPriorityReading.WriteProcedure AS WriteProcedure
	|	
	|FROM 
	|	ttTTLowOrderReadingWithFilterByPriority AS LowPriorityReading
	|";
#EndRegion
	
#Region TextConflicts
	TextConflicts = 
	"SELECT
	|	Conflicts1.MetadataObject AS MetadataObject,
	|	Conflicts1.HandlerWriter AS HandlerWriter,
	|	Conflicts1.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	Conflicts1.DataToReadWriter AS DataToReadWriter,
	|	Conflicts1.WriteAgain AS WriteAgain,
	|	Conflicts1.ThisIsReader AS ThisIsReader,
	|	Conflicts1.OrderOfType1 AS OrderOfType1,
	|	Conflicts1.OrderOfType2 AS OrderOfType2,
	|	ISNULL(WriteHandlers.Procedure, """") AS WriteProcedure,
	|	ISNULL(ReadOrWriteHandlers2.Procedure, """") AS ReadOrWriteProcedure2
	|FROM 
	|	HandlersIntersections AS Conflicts1
	|
	|	LEFT JOIN Handlers AS WriteHandlers
	|	ON Conflicts1.HandlerWriter = WriteHandlers.Ref
	|
	|	LEFT JOIN Handlers AS ReadOrWriteHandlers2
	|	ON Conflicts1.ReadOrWriteHandler2 = ReadOrWriteHandlers2.Ref
	|
	|ORDER BY
	|	MetadataObject,
	|	WriteProcedure,
	|	ReadOrWriteProcedure2";
#EndRegion
	
#Region TextPriorities
	TextPriorities = 
	"SELECT
	|	Priorities.HandlerWriter AS Ref,
	|	Priorities.ReadOrWriteHandler2 AS Handler2,
	|	Priorities.Order AS Order,
	|	Priorities.OrderAuto AS OrderAuto,
	|	Priorities.WritingPriority AS WritingPriority,
	|	CASE WHEN Priorities.WritingPriority AND Priorities.OrderAuto <> &Before
	|		THEN 1
	|		ELSE 0
	|	END AS NotByWritingPriority,
	|	CASE WHEN Priorities.Order <> Priorities.OrderAuto
	|		THEN 1
	|		ELSE 0
	|	END AS OrdersAreNotEqual,
	|	Priorities.ExecutionOrderSpecified AS ExecutionOrderSpecified,
	|	Priorities.DataToReadWriter AS DataToReadWriter,
	|	Priorities.DataToReadWriter2 AS DataToReadWriter2,
	|	Priorities.WriteAgain AS WriteAgain,
	|	Priorities.WriteAgain2 AS WriteAgain2,
	|	Priorities.ThisIsReader AS ThisIsReader,
	|	Priorities.ThisIsReader2 AS ThisIsReader2,
	|	Priorities.OrderOfType1 AS OrderOfType1,
	|	Priorities.OrderOfType2 AS OrderOfType2,
	|	Priorities.RevisionAsNumber1 AS RevisionAsNumber1,
	|	Priorities.RevisionAsNumber2 AS RevisionAsNumber2,
	|	Priorities.VersionAsNumber1 AS VersionAsNumber1,
	|	Priorities.VersionAsNumber2 AS VersionAsNumber2,
	|	Priorities.LibraryOrder1 AS LibraryOrder1,
	|	Priorities.LibraryOrder2 AS LibraryOrder2,
	|	ISNULL(WriteHandlers.Procedure, """") AS Procedure1,
	|	ISNULL(WriteHandlers.Subsystem, """") AS Subsystem1,
	|	ISNULL(WriteHandlers.Comment, """") AS Comment1,
	|	ISNULL(ReadWriteHandlers2.Procedure, """") AS Procedure2,
	|	ISNULL(ReadWriteHandlers2.Subsystem, """") AS Subsystem2,
	|	ISNULL(ReadWriteHandlers2.Comment, """") AS Comment2
	|FROM
	|	NewPriorities AS Priorities
	|	LEFT JOIN Handlers AS WriteHandlers
	|	ON Priorities.HandlerWriter = WriteHandlers.Ref
	|
	|	LEFT JOIN Handlers AS ReadWriteHandlers2
	|	ON Priorities.ReadOrWriteHandler2 = ReadWriteHandlers2.Ref
	|
	|ORDER BY
	|	Procedure1,
	|	Procedure2";
#EndRegion

#Region TextDescription
	TextDescription = 
	"SELECT
	|	Handlers.Ref AS Ref,
	|	Handlers.Subsystem AS Subsystem,
	|	Handlers.MainServerModuleName AS MainServerModuleName,
	|	Handlers.InitialFilling AS InitialFilling,
	|	Handlers.Version AS Version,
	|	Handlers.VersionAsNumber AS VersionAsNumber,
	|	Handlers.RevisionAsNumber AS RevisionAsNumber,
	|	Handlers.Procedure AS Procedure,
	|	Handlers.ExecutionMode AS ExecutionMode,
	|	Handlers.DeferredHandlersExecutionMode AS DeferredHandlersExecutionMode,
	|	Handlers.ExecuteInMandatoryGroup AS ExecuteInMandatoryGroup,
	|	Handlers.Priority AS Priority,
	|	Handlers.SharedData AS SharedData,
	|	Handlers.HandlerManagement AS HandlerManagement,
	|	Handlers.Comment AS Comment,
	|	Handlers.Id AS Id,
	|	Handlers.CheckProcedure AS CheckProcedure,
	|	Handlers.UpdateDataFillingProcedure AS UpdateDataFillingProcedure,
	|	Handlers.DeferredProcessingQueue AS DeferredProcessingQueue,
	|	Handlers.ExecuteInMasterNodeOnly AS ExecuteInMasterNodeOnly,
	|	Handlers.RunAlsoInSubordinateDIBNodeWithFilters AS RunAlsoInSubordinateDIBNodeWithFilters,
	|	Handlers.Multithreaded AS Multithreaded,
	|	Handlers.Changed AS Changed,
	|	Handlers.TechnicalDesign AS TechnicalDesign,
	|	Handlers.LibraryName AS LibraryName,
	|	Handlers.LibraryOrder AS LibraryOrder,
	|	Handlers.Order AS Order,
	|	Handlers.ObjectName AS ObjectName,
	|	Handlers.SubsystemUnderDevelopment AS SubsystemUnderDevelopment,
	|	ISNULL(Issues.DataToReadWriter, FALSE) AS DataToReadWriter,
	|	ISNULL(Issues.WriteAgain, FALSE) AS WriteAgain,
	|	ISNULL(Issues.ExecutionOrderSpecified, FALSE) AS ExecutionOrderSpecified,
	|	ISNULL(Issues.LowPriorityReading, FALSE) AS LowPriorityReading,
	|	&NoIssues AS IssueStatus,
	|	CASE
	|		WHEN Handlers.CheckProcedure <> """"
	|				AND Handlers.CheckProcedure <> &StandardCheckProcedure
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ChangedCheckProcedure
	|FROM
	|	Handlers AS Handlers
	|	LEFT JOIN Issues AS Issues
	|		ON Handlers.Ref = Issues.Handler";
#EndRegion
	
	ArrayOfTexts = New Array;
	ArrayOfTexts.Add(DestructionText);
	ArrayOfTexts.Add(TextOfHandlersIntersection);
	ArrayOfTexts.Add(TextTTConflicts);
	ArrayOfTexts.Add(TtPrioritiesByRecord);
	ArrayOfTexts.Add(TextTTPriorities);
	ArrayOfTexts.Add(TextNewPriorities);
	ArrayOfTexts.Add(TextTTLowPriorityHandlers);
	ArrayOfTexts.Add(IssueText);
	ArrayOfTexts.Add(TextLowPriorityHandlers);
	ArrayOfTexts.Add(TextConflicts);
	ArrayOfTexts.Add(TextPriorities);
	ArrayOfTexts.Add(TextDescription);
	
	Text = StrConcat(ArrayOfTexts, Common.QueryBatchSeparator());
	
	Return Text;
	
EndFunction

Function TempTablesQuery()
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text = TempTablesQueryText();
	Query.SetParameter("NoIssues", NStr("en = 'No issues';"));
	Query.SetParameter("StandardCheckProcedure", "InfobaseUpdate.DataUpdatedForNewApplicationVersion");
	Query.SetParameter("Before", "Before");
	Query.SetParameter("After", "After");
	Query.SetParameter("Any", "Any");
	Query.SetParameter("IsBlankString", "");
	Query.SetParameter("SubsystemsToDevelop", SubsystemsToDevelop());
	
	Query.SetParameter("Handlers", UpdateHandlers.Unload());
	Query.SetParameter("ObjectsToRead", ObjectsToRead.Unload());
	Query.SetParameter("ObjectsToChange", ObjectsToChange.Unload());
	Query.SetParameter("ObjectsToLock", ObjectsToLock.Unload());
	Query.SetParameter("ExecutionPriorities", ExecutionPriorities.Unload());
	Query.SetParameter("HandlersConflicts", HandlersConflicts.Unload());
	
	Return Query;
	
EndFunction

Function TempTablesQueryText()

	QueriesTexts = New Array;

#Region HandlersDetails
	QueriesTexts.Add(TempHandlersTableText());
#EndRegion

#Region ObjectsToRead
	QueryTextObjectsToRead = 
	"SELECT
	|	ObjectsToRead.Ref AS Ref,
	|	ObjectsToRead.MetadataObject AS MetadataObject,
	|	ObjectsToRead.OrderOfType AS OrderOfType,
	|	ObjectsToRead.LockInterface AS LockInterface,
	|	&NewObjects AS NewObjects
	|INTO ttObjectsToRead
	|FROM
	|	&ObjectsToRead AS ObjectsToRead
	|
	|INDEX BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectsToRead.Ref AS Ref,
	|	ObjectsToRead.MetadataObject AS MetadataObject,
	|	ObjectsToRead.OrderOfType AS OrderOfType,
	|	Handlers.ExecutionMode AS ExecutionMode,
	|	Handlers.InitialFilling AS InitialFilling,
	|	Handlers.Procedure AS Procedure,
	|	Handlers.Order AS Order,
	|	Handlers.DeferredHandlersExecutionMode AS DeferredHandlersExecutionMode,
	|	ObjectsToRead.LockInterface AS LockInterface,
	|	ObjectsToRead.NewObjects AS NewObjects
	|INTO ObjectsToRead
	|FROM
	|	ttObjectsToRead AS ObjectsToRead
	|	LEFT JOIN Handlers AS Handlers
	|	ON ObjectsToRead.Ref = Handlers.Ref
	|
	|INDEX BY
	|	Ref,
	|	MetadataObject
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ttObjectsToRead";
	QueriesTexts.Add(StrReplace(QueryTextObjectsToRead, "&NewObjects", "FALSE"));
#EndRegion

#Region ObjectsToChange
	QueryTextObjectsToChange = StrReplace(QueryTextObjectsToRead, "&NewObjects", "ObjectsToRead.NewObjects");
	QueryTextObjectsToChange = StrReplace(QueryTextObjectsToChange, "ObjectsToRead", "ObjectsToChange");
	QueriesTexts.Add(StrReplace(QueryTextObjectsToChange, "ObjectsToRead", "ObjectsToChange"));
#EndRegion

#Region TypeUpdatePriorities
	QueryTextTypeUpdatePriorities = 
	"SELECT
	|	ObjectsToChange.Ref AS Ref,
	|	MIN(ObjectsToChange.OrderOfType) AS OrderOfType
	|INTO TypeUpdatePriorities
	|FROM
	|	ObjectsToChange AS ObjectsToChange
	|GROUP BY
	|	ObjectsToChange.Ref
	|
	|INDEX BY
	|	Ref";
	QueriesTexts.Add(QueryTextTypeUpdatePriorities);
#EndRegion

#Region ObjectsToLock
	QueriesTexts.Add(
	"SELECT
	|	ObjectsToLock.Ref AS Ref,
	|	ObjectsToLock.MetadataObject AS MetadataObject
	|INTO ObjectsToLock
	|FROM
	|	&ObjectsToLock AS ObjectsToLock");
#EndRegion

#Region ExecutionPriorities
	QueriesTexts.Add(
	"SELECT
	|	ExecutionPriorities.Ref AS Ref,
	|	ExecutionPriorities.Order AS Order,
	|	ExecutionPriorities.Procedure2 AS Procedure2,
	|	ExecutionPriorities.ExecutionOrderSpecified AS ExecutionOrderSpecified,
	|	ExecutionPriorities.WriteAgain AS WriteAgain,
	|	ExecutionPriorities.DataToReadWriter AS DataToReadWriter
	|INTO ttPriorities
	|FROM
	|	&ExecutionPriorities AS ExecutionPriorities
	|
	|INDEX BY
	|	Procedure2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExecutionPriorities.Ref AS Ref,
	|	Handlers2.Ref AS Handler2,
	|	ExecutionPriorities.Order AS Order,
	|	Handlers1.Procedure AS Procedure,
	|	ExecutionPriorities.Procedure2 AS Procedure2,
	|	ExecutionPriorities.ExecutionOrderSpecified AS ExecutionOrderSpecified,
	|	ExecutionPriorities.WriteAgain AS WriteAgain,
	|	ExecutionPriorities.DataToReadWriter AS DataToReadWriter
	|INTO ExecutionPriorities
	|FROM
	|	ttPriorities AS ExecutionPriorities
	|	LEFT JOIN Handlers AS Handlers1
	|	ON ExecutionPriorities.Ref = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON ExecutionPriorities.Procedure2 = Handlers2.Procedure
	|
	|INDEX BY
	|	Ref,
	|	Handler2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ttPriorities");
#EndRegion
	
#Region HandlersConflicts
	QueriesTexts.Add(
	"SELECT
	|	HandlersConflicts.HandlerWriter AS HandlerWriter,
	|	HandlersConflicts.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|	HandlersConflicts.MetadataObject AS MetadataObject,
	|	HandlersConflicts.DataToReadWriter AS DataToReadWriter,
	|	HandlersConflicts.WriteAgain AS WriteAgain
	|INTO HandlersConflicts
	|FROM
	|	&HandlersConflicts AS HandlersConflicts
	|
	|INDEX BY
	|	HandlerWriter,
	|	ReadOrWriteHandler2,
	|	MetadataObject");
#EndRegion

	Return StrConcat(QueriesTexts, Common.QueryBatchSeparator());

EndFunction

Function TempHandlersTableText()
	
	Return
	"SELECT
	|	Handlers.Ref AS Ref,
	|	Handlers.Subsystem AS Subsystem,
	|	Handlers.MainServerModuleName AS MainServerModuleName,
	|	Handlers.InitialFilling AS InitialFilling,
	|	Handlers.Version AS Version,
	|	Handlers.VersionAsNumber AS VersionAsNumber,
	|	Handlers.RevisionAsNumber AS RevisionAsNumber,
	|	Handlers.Procedure AS Procedure,
	|	Handlers.ExecutionMode AS ExecutionMode,
	|	Handlers.DeferredHandlersExecutionMode AS DeferredHandlersExecutionMode,
	|	Handlers.ExecuteInMandatoryGroup AS ExecuteInMandatoryGroup,
	|	Handlers.Priority AS Priority,
	|	Handlers.SharedData AS SharedData,
	|	Handlers.HandlerManagement AS HandlerManagement,
	|	Handlers.Comment AS Comment,
	|	Handlers.Id AS Id,
	|	Handlers.CheckProcedure AS CheckProcedure,
	|	Handlers.UpdateDataFillingProcedure AS UpdateDataFillingProcedure,
	|	Handlers.DeferredProcessingQueue AS DeferredProcessingQueue,
	|	Handlers.NewQueue AS NewQueue,
	|	Handlers.ExecuteInMasterNodeOnly AS ExecuteInMasterNodeOnly,
	|	Handlers.RunAlsoInSubordinateDIBNodeWithFilters AS RunAlsoInSubordinateDIBNodeWithFilters,
	|	Handlers.Multithreaded AS Multithreaded,
	|	Handlers.IssueStatus AS IssueStatus,
	|	Handlers.DataToReadWriter AS DataToReadWriter,
	|	Handlers.WriteAgain AS WriteAgain,
	|	Handlers.Changed AS Changed,
	|	Handlers.TechnicalDesign AS TechnicalDesign,
	|	Handlers.LibraryName AS LibraryName,
	|	Handlers.LibraryOrder AS LibraryOrder,
	|	Handlers.Order AS Order,
	|	Handlers.ObjectName AS ObjectName,
	|	Handlers.Subsystem IN (&SubsystemsToDevelop) AS SubsystemUnderDevelopment
	|INTO Handlers
	|FROM
	|	&Handlers AS Handlers
	|
	|INDEX BY
	|	Ref,
	|	Procedure";
	
EndFunction

#EndRegion

#Region QueueBuilding

Function TempQueueBuildingTablesText()

	Return
	"SELECT
	|	Conflicts1.HandlerWriter AS HandlerWriter,
	|	Conflicts1.ReadOrWriteHandler2 AS ReadOrWriteHandler2,
	|
	|	WriteHandlers.ExecutionMode AS ExecutionMode1,
	|	ReadWriteHandlers2.ExecutionMode AS ExecutionMode2,
	|
	|	Conflicts1.WriteAgain AS WriteAgain,
	|	WriteHandlers.Procedure AS Procedure1,
	|	ReadWriteHandlers2.Procedure AS Procedure2
	|
	|INTO HandlersIssues
	|FROM
	|	HandlersConflicts AS Conflicts1
	|	LEFT JOIN Handlers AS WriteHandlers
	|	ON Conflicts1.HandlerWriter = WriteHandlers.Ref
	|
	|	LEFT JOIN Handlers AS ReadWriteHandlers2
	|	ON Conflicts1.ReadOrWriteHandler2 = ReadWriteHandlers2.Ref
	|
	|WHERE
	|	WriteHandlers.DeferredHandlersExecutionMode = &Parallel
	|	AND WriteHandlers.ExecutionMode = &Deferred
	|
	|	AND ReadWriteHandlers2.DeferredHandlersExecutionMode = &Parallel
	|	AND ReadWriteHandlers2.ExecutionMode = &Deferred
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Priorities.Ref AS Handler1,
	|	Priorities.Handler2 AS Handler2,
	|	Priorities.Order AS Order,
	|
	|	Handlers1.VersionAsNumber AS VersionAsNumber1,
	|	Handlers1.Procedure AS Procedure1,
	|
	|	Handlers2.VersionAsNumber AS VersionAsNumber2,
	|	Handlers2.Procedure AS Procedure2,
	|
	|	Handlers1.ExecutionMode AS ExecutionMode1,
	|	Handlers2.ExecutionMode AS ExecutionMode2
	|
	|INTO HandlersPriorities
	|FROM
	|	ExecutionPriorities AS Priorities
	|	LEFT JOIN Handlers AS Handlers1
	|	ON Priorities.Ref = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON Priorities.Handler2 = Handlers2.Ref
	|
	|WHERE
	|	Handlers1.DeferredHandlersExecutionMode = &Parallel
	|	AND Handlers1.ExecutionMode = &Deferred
	|
	|	AND Handlers2.DeferredHandlersExecutionMode = &Parallel
	|	AND Handlers2.ExecutionMode = &Deferred
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	T.Handler AS Handler,
	|	T.VersionAsNumber AS VersionAsNumber,
	|	T.Procedure AS Procedure,
	|	SUM(T.IntersectionsCount) AS IntersectionsCount,
	|	SUM(T.CountHandler1First) AS CountHandler1First,
	|	SUM(T.CountAnyOrder) AS CountAnyOrder
	|INTO HandlersIntersections
	|FROM
	|	(SELECT
	|		UpdateHandlers.Ref AS Handler,
	|		UpdateHandlers.VersionAsNumber AS VersionAsNumber,
	|		UpdateHandlers.Procedure AS Procedure,
	|		0 AS IntersectionsCount,
	|		0 AS CountHandler1First,
	|		0 AS CountAnyOrder
	|	FROM
	|		Handlers AS UpdateHandlers
	|	WHERE
	|		UpdateHandlers.DeferredHandlersExecutionMode = &Parallel
	|		AND UpdateHandlers.ExecutionMode = &Deferred
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Priorities.Handler1 AS Handler,
	|		Priorities.VersionAsNumber1 AS VersionAsNumber,
	|		Priorities.Procedure1 AS Procedure,
	|		1 AS IntersectionsCount,
	|		CASE
	|			WHEN Priorities.Order = &Before
	|				THEN 1
	|			ELSE 0
	|		END AS CountHandler1First,
	|		CASE
	|			WHEN Priorities.Order = &Any
	|				THEN 1
	|			ELSE 0
	|		END AS CountAnyOrder
	|	FROM
	|		HandlersPriorities AS Priorities
	|	) AS T
	|
	|GROUP BY
	|	T.Handler,
	|	T.Procedure,
	|	T.VersionAsNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	HandlersIssues.HandlerWriter AS Handler1,
	|	HandlersIssues.ReadOrWriteHandler2 AS Handler2,
	|	MAX(HandlersIssues.WriteAgain) AS HasWriteAgain
	|INTO WriteAgain
	|FROM
	|	HandlersIssues AS HandlersIssues
	|
	|GROUP BY
	|	HandlersIssues.HandlerWriter,
	|	HandlersIssues.ReadOrWriteHandler2
	|
	|HAVING
	|	MAX(HandlersIssues.WriteAgain) = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Intersections.Handler AS Handler,
	|	Intersections.VersionAsNumber AS VersionAsNumber,
	|	Intersections.Procedure AS Procedure,
	|	Intersections.IntersectionsCount <> 0 AS HasIntersections,
	|	Intersections.CountHandler1First AS FirstHandler1,
	|	Intersections.CountAnyOrder AS AnyOrder,
	|	ISNULL(Priorities.Handler2, """") AS LinkedHandler,
	|	ISNULL(Priorities.VersionAsNumber2, 0) AS LinkedVersionAsNumber,
	|	ISNULL(Priorities.Procedure2, """") AS LinkedProcedure,
	|	ISNULL(Priorities.Order, """") AS QueuingOrder,
	|	ISNULL(WriteAgain.HasWriteAgain, FALSE) AS HasWriteAgain
	|FROM
	|	HandlersIntersections AS Intersections
	|		LEFT JOIN HandlersPriorities AS Priorities
	|		ON Intersections.Handler = Priorities.Handler1
	|
	|			LEFT JOIN WriteAgain AS WriteAgain
	|			ON Priorities.Handler1 = WriteAgain.Handler1
	|				AND Priorities.Handler2 = WriteAgain.Handler2
	|
	|ORDER BY
	|	HasIntersections,
	|	FirstHandler1 DESC,
	|	AnyOrder DESC,
	|	VersionAsNumber,
	|	Procedure,
	|	LinkedVersionAsNumber,
	|	LinkedProcedure
	|TOTALS
	|	MAX(HasIntersections)
	|BY
	|	Handler";

EndFunction

Procedure AddHandlerToExistenceInQueue(HandlersAvailabilityInQueue, Queue, Handler, MaxQueue)
	If HandlersAvailabilityInQueue.Get(Queue) = Undefined Then
		HandlersAvailabilityInQueue.Insert(Queue, New Map);
	EndIf;
	HandlersAvailabilityInQueue[Queue].Insert(Handler);
	
	If MaxQueue < Queue Then
		MaxQueue = Queue;
	EndIf;
EndProcedure

Procedure ShiftRecursivelyLinkedHandlers(HandlersQueue, HandlersAvailabilityInQueue, Handler, MaxQueue, RecursionData)
	
	LinkedHandlers = HandlersQueue[Handler].LinkedHandlers;
	
	For Each LinkedHandler In LinkedHandlers Do
		
		If Handler = LinkedHandler.Key Then
			Continue;
		EndIf;
		
		If HandlersQueue[LinkedHandler.Key] = Undefined Then
			Continue;
		EndIf;
		
		If LinkedHandler.Value.QueuingOrder = "Any" Then
			
			If LinkedHandler.Value.WriteObjectAgain
				And HandlersQueue[Handler].Queue = HandlersQueue[LinkedHandler.Key].Queue Then
				
				RemoveHandlerFromQueue(HandlersAvailabilityInQueue, HandlersQueue[Handler].Queue, Handler);
				HandlersQueue[Handler].Queue = HandlersQueue[Handler].Queue + 1;
				AddHandlerToExistenceInQueue(HandlersAvailabilityInQueue, HandlersQueue[Handler].Queue, Handler, MaxQueue);

				// Offset completed linked handlers.
				ShiftRecursivelyLinkedHandlers(HandlersQueue, HandlersAvailabilityInQueue, Handler, MaxQueue, RecursionData);
			EndIf;
			
		ElsIf LinkedHandler.Value.QueuingOrder = "Before" Then
			
			If HandlersQueue[Handler].Queue >= HandlersQueue[LinkedHandler.Key].Queue Then
				
				RemoveHandlerFromQueue(HandlersAvailabilityInQueue, HandlersQueue[LinkedHandler.Key].Queue, LinkedHandler.Key);
				HandlersQueue[LinkedHandler.Key].Queue = HandlersQueue[Handler].Queue + 1;
				AddHandlerToExistenceInQueue(HandlersAvailabilityInQueue, HandlersQueue[LinkedHandler.Key].Queue, LinkedHandler.Key, MaxQueue);
				
				// Offset linked handlers of a linked handler.
				ShiftRecursivelyLinkedHandlers(HandlersQueue, HandlersAvailabilityInQueue, LinkedHandler.Key, MaxQueue, RecursionData);
			EndIf;
			
		ElsIf LinkedHandler.Value.QueuingOrder = "After" Then
			
			If HandlersQueue[LinkedHandler.Key].Queue >= HandlersQueue[Handler].Queue Then
				
				RemoveHandlerFromQueue(HandlersAvailabilityInQueue, HandlersQueue[Handler].Queue, Handler);
				HandlersQueue[Handler].Queue = HandlersQueue[LinkedHandler.Key].Queue + 1;
				AddHandlerToExistenceInQueue(HandlersAvailabilityInQueue, HandlersQueue[Handler].Queue, Handler, MaxQueue);
				
				// Offset completed linked handlers.
				ShiftRecursivelyLinkedHandlers(HandlersQueue, HandlersAvailabilityInQueue, Handler, MaxQueue, RecursionData);
			EndIf;
			
		Else
			ExceptionText = NStr("en = 'An error occurred while building the queue.';");
			Raise ExceptionText;
		EndIf;
	
	EndDo;
	
EndProcedure

Procedure RemoveHandlerFromQueue(HandlersAvailabilityInQueue, Queue, Handler)
	HandlersAvailabilityInQueue[Queue].Delete(Handler);
EndProcedure

Function HasQueueBuildingErrors(Query, ReportErrors = True)
	
	QueryText =
	"SELECT
	|	HandlersPriorities.Procedure1 AS Handler1,
	|	HandlersPriorities.Procedure2 AS Handler2,
	|	""IssueInHandlersOrder"" AS Issue1
	|FROM
	|	HandlersPriorities AS HandlersPriorities
	|	LEFT JOIN WriteAgain AS DoubleEntry
	|	ON HandlersPriorities.Handler1 = DoubleEntry.Handler1
	|		AND HandlersPriorities.Handler2 = DoubleEntry.Handler2
	|
	|	LEFT JOIN Handlers AS Handlers1
	|	ON HandlersPriorities.Handler1 = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON HandlersPriorities.Handler2 = Handlers2.Ref
	|
	|WHERE
	|	(HandlersPriorities.Order = &Before
	|			AND Handlers1.NewQueue >= Handlers2.NewQueue
	|		OR HandlersPriorities.Order = &Any
	|			AND NOT DoubleEntry.Handler1 IS NULL 
	|			AND Handlers1.NewQueue = Handlers2.NewQueue)
	|
	|UNION ALL
	|
	|SELECT
	|	Handlers.Procedure AS Handler1,
	|	"""" AS Handler2,
	|	""ProblemIsNotFirst"" AS Issue1
	|FROM
	|	Handlers AS Handlers
	|		LEFT JOIN HandlersPriorities AS HandlersPriorities
	|		ON Handlers.Ref = HandlersPriorities.Handler1
	|WHERE
	|	NOT Handlers.InitialFilling
	|	AND Handlers.DeferredHandlersExecutionMode = &Parallel
	|	AND Handlers.ExecutionMode = &Deferred
	|	AND Handlers.NewQueue <> 1
	|	AND HandlersPriorities.Handler1 IS NULL "; 
	
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	HasIssue = Not QueryResult.IsEmpty();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		MessageText = NStr("en = 'An error occurred in the queue building algorithm: the %Handler1% handler is to be placed in queue 1.';");
		If Selection.Issue1 = "IssueInHandlersOrder" Then
			MessageText = NStr("en = 'An error occurred in the queue building algorithm: the %Handler1% and %Handler2% handlers are placed in the incorrect order.';");
			MessageText = StrReplace(MessageText, "%Handler2%", Selection.Handler2);
		EndIf;
		MessageText = StrReplace(MessageText, "%Handler1%", Selection.Handler1);
		If ReportErrors Then
			Common.MessageToUser(MessageText);
		EndIf;
		AddError(Selection.Handler1, MessageText);
	EndDo;
		
	Return HasIssue;
	
EndFunction

Function CanBuildQueue()
	
	Query = TempTablesQuery();
	
	QueryText =
	"SELECT DISTINCT
	|	ISNULL(Handlers1.Procedure, """") AS Handler1,
	|	ISNULL(Handlers2.Procedure, """") AS Handler2
	|FROM
	|	ExecutionPriorities AS Priorities
	|	LEFT JOIN Handlers AS Handlers1
	|	ON Priorities.Ref = Handlers1.Ref
	|
	|	LEFT JOIN Handlers AS Handlers2
	|	ON Priorities.Handler2 = Handlers2.Ref
	|
	|WHERE
	|	NOT Handlers1.InitialFilling
	|	AND NOT Handlers2.InitialFilling
	|	AND NOT Priorities.ExecutionOrderSpecified
	|
	|ORDER BY
	|	Handler1,
	|	Handler2";
	
	QueriesTexts = New Array;
	QueriesTexts.Add(Query.Text);
	QueriesTexts.Add(QueryText);
	Query.Text = StrConcat(QueriesTexts, Common.QueryBatchSeparator());
	
	EmptyPriorities = Query.Execute().Select();
	OK1 = EmptyPriorities.Count() = 0;
	While EmptyPriorities.Next() Do
		MessageText = NStr("en = 'Operations with the pair of handlers %Handler% - %LinkedHandler% are not completed.';");
		MessageText = MessageText + Chars.LF + NStr("en = 'Issue status: %QueuingOrder%';");
		MessageText = StrReplace(MessageText, "%Handler%", EmptyPriorities.Handler1);
		MessageText = StrReplace(MessageText, "%LinkedHandler%", EmptyPriorities.Handler2);
		MessageText = StrReplace(MessageText, "%QueuingOrder%", NStr("en = 'Execution priority is not set.';"));
		AddError(EmptyPriorities.Handler1, MessageText);
	EndDo;
	
	OK1 = OK1 And LowPriorityReading.Count() = 0;
	WrongPriorities = LowPriorityReading.Unload();
	WrongPriorities.GroupBy("ReaderProcedure");
	For Each Handler In WrongPriorities Do
		MessageText = NStr("en = 'Readable objects of the %Handler% handler
		|include objects that are processed by handlers with a lower priority than the current one.
		|This will cause the current handler to wait for them to complete. Resolve this mismatch.';");
		MessageText = StrReplace(MessageText, "%Handler%", Handler.ReaderProcedure);
		AddError(Handler.ReaderProcedure, MessageText);
	EndDo;
	
	Return OK1;
	
EndFunction

Procedure AddError(HandlerProcedure, MessageText)
	
	NewError = Errors.Add();
	NewError.MetadataObject = ObjectNameFromDataProcessorProcedure(HandlerProcedure);
	NewError.Handler = HandlerProcedure;
	NewError.Message = MessageText;
	
EndProcedure

Procedure UpdateTempTable(TempTableManager, TableName, NewTable, IndexingFields = "Ref")
	
	Query = New Query;
	Query.TempTablesManager = TempTableManager;
	
	QueryTextDestroyTT = "";
	If Query.TempTablesManager.Tables.Find(TableName) <> Undefined Then
		QueryTextDestroyTT = "DROP " + TableName + ";
		|";
	EndIf;
	
	QueryTextTT =
	"SELECT
	|&Fields
	|INTO DestinationName
	|FROM
	|	&Table AS T";
	
	FieldArray = New Array;
	For Each Column In NewTable.Columns Do
		FieldArray.Add(StringFunctionsClientServer.SubstituteParametersToString("	T.%1 AS %1", Column.Name));
	EndDo;
	
	TableFieldText = StrConcat(FieldArray, "," + Chars.LF);
	IndexingFieldText = ?(IndexingFields = "", "", "INDEX BY " + IndexingFields);
	
	QueryTextTT = StrReplace(QueryTextTT, "&Fields", TableFieldText); // @Query-part-1
	QueryTextTT = StrReplace(QueryTextTT, "DestinationName", TableName);
	QueryTextTT = QueryTextTT + Chars.LF + IndexingFieldText;
	
	Query.Text = QueryTextDestroyTT + QueryTextTT;
	Query.SetParameter("Table", NewTable);
	
	Query.Execute();
	
EndProcedure

Function ObjectNameFromDataProcessorProcedure(DataProcessorProcedureName)
	
	NameParts = StrSplit(DataProcessorProcedureName, ".");
	If NameParts.Count() = 2 Then
		ObjectName = "CommonModule." + NameParts[0];
	Else
		NameParts[0] = SingularForm[NameParts[0]];
		NameParts.Delete(NameParts.UBound());
		ObjectName = StrConcat(NameParts, ".");
	EndIf;
	
	Return ObjectName;
	
EndFunction

Procedure OutputErrorMessage(RaiseException = True)
	
	If RaiseException Then
		EventName = NStr("en = 'Build the update handlers queue';", Common.DefaultLanguageCode());
		ListOfProblemHandlers = "";
		For Each Error In Errors Do
			If Not IsBlankString(Error.Handler) Then
				HandlersErrors = StrSplit(Error.Handler, Chars.LF);
				If HandlersErrors.Count() = 1 Then
					MetadataObject = Common.MetadataObjectByFullName(Error.MetadataObject);
				EndIf;
				HandlersErrors = StrSplit(Error.Handler, Chars.LF);
				For Each Handler In HandlersErrors Do
					If StrFind(ListOfProblemHandlers, Handler) = 0 Then
						ListOfProblemHandlers = ListOfProblemHandlers + Handler + Chars.LF;
					EndIf;
				EndDo;
			EndIf;
			WriteLogEvent(
				EventName,
				EventLogLevel.Error,
				MetadataObject,
				Error.Handler,
				Error.Message);
		EndDo;
		ExceptionText = NStr("en = 'Some errors were found upon building the queue of deferred update handlers.
			|Fix them using the built-in ""Update handlers details"" data processor.
			|To do this, start the application with the ""%1"" startup parameter.
			|Errors are listed in the event log.
			|
			|List of handlers with issues:';");
		ExceptionText = StrReplace(ExceptionText, "%1", "DisableSystemStartupLogic");
		Raise ExceptionText + Chars.LF + ListOfProblemHandlers;
	Else
		For Each Error In Errors Do
			Common.MessageToUser(Error.Message);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region HasHandlersExecutionCycle

// Checks whether the execution cycle is available for all handlers by priority data.
//
// Returns:
//   Boolean - True if the execution cycle is available
//
Function HasHandlersExecutionCycle(TheHandlerBeingChecked = Undefined, Val HandlerPriorities = Undefined, ReportErrors = False)

	If ExecutionPriorities.Count() = 0 Then
		Return False;
	EndIf;
	
	ListOfEdges = ExecutionPriorities.Unload(, "Ref, Handler2, Order");
	If HandlerPriorities <> Undefined Then
		reverseorder = reverseorder();
		For Each NewPriority In HandlerPriorities Do
			
			Filter = New Structure("Ref,Handler2");
			FillPropertyValues(Filter, NewPriority);
			FoundEdges = ListOfEdges.FindRows(Filter);
			If FoundEdges.Count() = 0 Then
				NewEdge = ListOfEdges.Add();
				FillPropertyValues(NewEdge, NewPriority);
			Else
				FillPropertyValues(FoundEdges[0], NewPriority);
				Filter.Ref = NewPriority.Handler2;
				Filter.Handler2 = NewPriority.Ref;
				FoundEdges = ListOfEdges.FindRows(Filter);
				FoundEdges[0].Order = reverseorder[NewPriority.Order];
			EndIf;
			
		EndDo;
	EndIf;
	ListOfEdges.Columns.Ref.Name = "Begin";
	ListOfEdges.Columns.Handler2.Name = "End";

	AnyDependencies = ListOfEdges.FindRows(New Structure("Order", "Any"));
	For Each AnyDependency In AnyDependencies Do
		ListOfEdges.Delete(AnyDependency);
	EndDo;
	
	DependenciesUpTo = ListOfEdges.FindRows(New Structure("Order", "Before"));
	For Each DependencyTo In DependenciesUpTo Do
		Begin = DependencyTo.Begin;
		DependencyTo.Begin = DependencyTo.End;
		DependencyTo.End = Begin;
	EndDo;
	
	ListOfEdges.Columns.Delete("Order");
	OptimizeTheListOfEdges(ListOfEdges);
	ListOfVertexes = ListOfVertexes(ListOfEdges);
	AdjacencyList = AdjacencyList(ListOfEdges, ListOfVertexes);
	IndexOfTheHandlerBeingChecked = Undefined;
	
	If TheHandlerBeingChecked <> Undefined Then
		Filter = New Structure("Value", TheHandlerBeingChecked);
		FoundRows = ListOfVertexes.FindRows(Filter);
		If FoundRows.Count() = 0 Then
			Return False;
		EndIf;
		TheStringOfTheHandlerBeingChecked = FoundRows[0];
		IndexOfTheHandlerBeingChecked = ListOfVertexes.IndexOf(TheStringOfTheHandlerBeingChecked);
	EndIf;
	
	GraphCycles = FindTheCyclesOfTheGraph(ListOfVertexes, AdjacencyList, IndexOfTheHandlerBeingChecked);
	HasCycle = GraphCycles.Count() > 0;
	
	If HasCycle Then
		
		For Each GraphCycle In GraphCycles Do
			
			FullPath = New Array;
			For Each Ref In GraphCycle Do
				LongDesc = UpdateHandlers.Find(Ref, "Ref");
				FullPath.Add(LongDesc.Procedure);
			EndDo;
			PathText = StrConcat(FullPath, Chars.LF);
			
			MessageText = NStr("en = 'An execution order cycle is found:';") + Chars.LF + "%Path%";
			MessageText = StrReplace(MessageText, "%Path%", PathText);
			
			AddError(PathText, MessageText);
			If ReportErrors Then
				Common.MessageToUser(MessageText);
			EndIf;
			
		EndDo;
	EndIf;
	
	Return HasCycle;
	
EndFunction

#Region SearchForCycles

Procedure AddALoopToTheSearchResult(Parameters)
	
	StartOfTheCycle = Parameters.StartOfTheCycle;
	Vertex = Parameters.EndOfTheCycle;
	Path = Parameters.Path;
	
	CycleStructure = New Array;
	CycleStructure.Add(StartOfTheCycle);
	
	While Vertex <> StartOfTheCycle Do
		CycleStructure.Add(Vertex);
		Vertex = Path[Vertex];
	EndDo;
	
	CycleStructure.Add(StartOfTheCycle);
	FlipTheArray(CycleStructure);
	Parameters.Cycles.Add(CycleStructure);
	
EndProcedure

Procedure FillTheVerticesWithValues(ArrayOfVertices, ListOfVertexes)
	
	For VertexIndex = 0 To ArrayOfVertices.UBound() Do
		ArrayOfVertices[VertexIndex] = ListOfVertexes[ArrayOfVertices[VertexIndex]].Value;
	EndDo;
	
EndProcedure

Procedure FillLoopsWithValues(Parameters)
	
	ListOfVertexes = Parameters.ListOfVertexes;
	
	For Each CycleStructure In Parameters.Cycles Do
		FillTheVerticesWithValues(CycleStructure, ListOfVertexes);
	EndDo;
	
EndProcedure

Procedure OptimizeTheListOfEdges(ListOfEdges)
	
	ListOfEdges.GroupBy("Begin, End");
	ListOfEdges.Indexes.Add("Begin");
	
EndProcedure

Procedure FlipTheArray(Array)
	
	StartIndex = 0;
	TheEndIndex = Array.UBound();
	
	While StartIndex < TheEndIndex Do
		Value = Array[StartIndex];
		Array[StartIndex] = Array[TheEndIndex];
		Array[TheEndIndex] = Value;
		StartIndex = StartIndex + 1;
		TheEndIndex = TheEndIndex - 1;
	EndDo;
	
EndProcedure

Procedure SearchInTheDepthOfTheGraph(ExitVertex, Parameters)
	
	VertexStates = Parameters.VertexStates;
	VertexStates[ExitVertex] = 1;
	EntryVertexes = Parameters.AdjacencyList[ExitVertex];
	
	If EntryVertexes <> Undefined Then
		For IndexOfTheInputVertex = 0 To EntryVertexes.Count() - 1 Do
			EntryVertex = EntryVertexes[IndexOfTheInputVertex];
			StateOfTheInputVertex = VertexStates[EntryVertex];
			
			If StateOfTheInputVertex = Undefined Then
				Parameters.Path[EntryVertex] = ExitVertex;
				SearchInTheDepthOfTheGraph(EntryVertex, Parameters);
			ElsIf StateOfTheInputVertex = 1 Then
				Parameters.StartOfTheCycle = EntryVertex;
				Parameters.EndOfTheCycle = ExitVertex;
				AddALoopToTheSearchResult(Parameters);
			EndIf;
		EndDo;
	EndIf;
	
	VertexStates[ExitVertex] = 2;
	
EndProcedure

Procedure RemoveUnnecessaryLoops(Cycles)
	
	InitialCycles = MatchingOfRepresentationsAndValuesOfCycles(Cycles);
	NormalizedCycles = New Array;
	
	For Each TheOriginalCycle In InitialCycles Do
		NormalizedCycle = NormalizeTheCycle(TheOriginalCycle.Value);
		NormalizedCycles.Add(NormalizedCycle);
	EndDo;
	
	UniqueCycles = MatchingOfRepresentationsAndValuesOfCycles(NormalizedCycles);
	Cycles.Clear();
	
	For Each UniqueCycle In UniqueCycles Do
		Cycles.Add(UniqueCycle.Value);
	EndDo;
	
EndProcedure

Function IndexOfTheMinimumValueInTheArray(Array)
	
	If Array.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Minimum = Array[0];
	MinimumIndex = 0;
	
	For IndexOf = 1 To Array.UBound() Do
		Value = Array[IndexOf];
		
		If Value < Minimum Then
			Minimum = Value;
			MinimumIndex = IndexOf;
		EndIf;
	EndDo;
	
	Return MinimumIndex;
	
EndFunction

Function FindTheCyclesOfTheGraph(ListOfVertexes, AdjacencyList, StartingVertex = Undefined)
	
	SearchParameters = NewSearchParametersInTheDepthOfTheGraph(ListOfVertexes, AdjacencyList);
	NumberOfVertices = ListOfVertexes.Count();
	
	If StartingVertex = Undefined Then
		For IndexOfTheExitVertex = 0 To NumberOfVertices - 1 Do
			SearchParameters.VertexStates = New Array(NumberOfVertices);
			SearchInTheDepthOfTheGraph(IndexOfTheExitVertex, SearchParameters);
		EndDo;
	Else
		SearchInTheDepthOfTheGraph(StartingVertex, SearchParameters);
	EndIf;
	
	RemoveUnnecessaryLoops(SearchParameters.Cycles);
	FillLoopsWithValues(SearchParameters);
	
	Return SearchParameters.Cycles;
	
EndFunction

Function NewSearchParametersInTheDepthOfTheGraph(ListOfVertexes, AdjacencyList)
	
	NumberOfVertices = ListOfVertexes.Count();
	
	SearchParameters = New Structure;
	SearchParameters.Insert("ListOfVertexes", ListOfVertexes);
	SearchParameters.Insert("AdjacencyList", AdjacencyList);
	SearchParameters.Insert("VertexStates", New Array(NumberOfVertices));
	SearchParameters.Insert("Path", New Array(NumberOfVertices));
	SearchParameters.Insert("Cycles", New Array);
	SearchParameters.Insert("StartOfTheCycle");
	SearchParameters.Insert("EndOfTheCycle");
	
	Return SearchParameters;
	
EndFunction

Function NormalizeTheCycle(CycleStructure)
	
	CycleStructure.Delete(CycleStructure.UBound());
	MinimumIndex = IndexOfTheMinimumValueInTheArray(CycleStructure);
	NormalizedCycle = CyclicallyShiftedArray(CycleStructure, -MinimumIndex);
	NormalizedCycle.Add(NormalizedCycle[0]);
	
	Return NormalizedCycle;
	
EndFunction

Function MatchingOfRepresentationsAndValuesOfCycles(Cycles)
	
	Map = New Map;
	
	For Each CycleStructure In Cycles Do
		CycleView = StrConcat(CycleStructure, " → ");
		Value = Map[CycleView];
		
		If Value = Undefined Then
			Map[CycleView] = CycleStructure;
		EndIf;
	EndDo;
	
	Return Map;
	
EndFunction

Function ListOfVertexes(ListOfEdges)
	
	ExitVertices = ListOfEdges.Copy(, "Begin");
	EntryVertexes = ListOfEdges.Copy(, "End");
	EntryVertexes.GroupBy("End");
	
	For Each EntryVertex In EntryVertexes Do
		ExitVertex = ExitVertices.Add();
		ExitVertex.Begin = EntryVertex.End;
	EndDo;
	
	ExitVertices.GroupBy("Begin");
	ExitVertices.Columns.Begin.Name = "Value";
	ExitVertices.Indexes.Add("Value");
	
	Return ExitVertices;
	
EndFunction

Function AdjacencyList(ListOfEdges, ListOfVertexes)
	
	NumberOfVertices = ListOfVertexes.Count();
	AdjacencyList = New Array(NumberOfVertices);
	SelectionInTheListOfEdges = New Structure("Begin");
	SelectionInTheListOfVertices = New Structure("Value");
	
	For VertexIndex = 0 To NumberOfVertices - 1 Do
		ExitVertex = ListOfVertexes[VertexIndex].Value;
		SelectionInTheListOfEdges.Begin = ExitVertex;
		EntryVertexes = ListOfEdges.FindRows(SelectionInTheListOfEdges);
		NumberOfInputVertices = EntryVertexes.Count();
		
		If NumberOfInputVertices > 0 Then
			ListOfInputVertices = New Array(NumberOfInputVertices);
			AdjacencyList[VertexIndex] = ListOfInputVertices;
			
			For IndexOfTheInputVertex = 0 To NumberOfInputVertices - 1 Do
				EntryVertex = EntryVertexes[IndexOfTheInputVertex].End;
				SelectionInTheListOfVertices.Value = EntryVertex;
				ListOfInputVertices[IndexOfTheInputVertex] = ListOfVertexes.IndexOf(ListOfVertexes.FindRows(SelectionInTheListOfVertices)[0]);
			EndDo;
		EndIf;
	EndDo;
	
	Return AdjacencyList;
	
EndFunction

Function CyclicallyShiftedArray(Array, Offset)
	
	Count = Array.Count();
	ShiftedArray = New Array(Count);
	
	For IndexOf = 0 To Array.UBound() Do
		SourceOffset = IndexOf - Offset + ?(Offset < 0, 0, Count);
		TheIndexOfTheSource = SourceOffset % Count;
		ShiftedArray[IndexOf] = Array[TheIndexOfTheSource];
	EndDo;
	
	Return ShiftedArray;
	
EndFunction

#EndRegion

#EndRegion

#Region Other

Procedure SetQueueNumber(UpdateIterations)
	
	ColumnsNames = "Subsystem,MainServerModuleName";
	Subsystems = UpdateHandlers.Unload(,ColumnsNames);
	Subsystems.GroupBy(ColumnsNames);
	
	For Each Library In UpdateIterations Do
		
		Filter = New Structure("ExecutionMode", "Deferred");
		Filter.Insert("DeferredProcessingQueue", 0);
		DeferredHandlers = Library.Handlers.FindRows(Filter); // See InfobaseUpdate.NewUpdateHandlerTable
// ()
		For Each Handler In DeferredHandlers Do
			Filter = New Structure;
			Filter.Insert("Version", Handler.Version);
			Filter.Insert("Procedure", Handler.Procedure);
			Filter.Insert("Id", String(Handler.Id));
			FoundADescriptionOf = UpdateHandlers.FindRows(Filter);
			For Each LongDesc In FoundADescriptionOf Do
				Handler.DeferredProcessingQueue = LongDesc.NewQueue;
			EndDo;
		EndDo;// By deferred handlers.
		
	EndDo;// By libraries.
	
EndProcedure

// Returns the time between the specified dates in the "00:00:00" format.
// If the TimeStructure parameter is specified, the Hours, Minutes, and Seconds values are returned separately.
// if StartTime = 0, transforms the date to the time format and returns the TimeStructure parameter if required.
//
// Parameters:
//   EndTime - Date - End time.
//   BeginTime - Date - Start time.
//   TimeStructure - Structure - separate components:
//    * Hours1 - Number
//    * Minutes1 - Number
//    * Seconds - Number
//    * TimeDifferenceSec - Number
//
// Returns:
//   String
//
Function TimeDifference1(EndTime, BeginTime = 0, TimeStructure = Undefined)
	Diff = EndTime - BeginTime;
	TimeDifferenceSec = Max(-Diff,Diff);
	Hours1 = Int(TimeDifferenceSec/3600);
	Minutes1 = Int(TimeDifferenceSec/60) - 60*Hours1;
	Seconds = TimeDifferenceSec - 60*Minutes1 - 60*60*Hours1;
	TimeStructure = New Structure;
	TimeStructure.Insert("Hours1",Hours1);
	TimeStructure.Insert("Minutes1",Minutes1);
	TimeStructure.Insert("Seconds",Seconds);
	TimeStructure.Insert("TimeDifferenceSec",TimeDifferenceSec);
	Return  ?(StrLen(String(Hours1))    = 1,"0" + String(Hours1),    String(Hours1))  +":"
			+?(StrLen(String(Minutes1))  = 1,"0" + String(Minutes1),  String(Minutes1))+":"
			+?(StrLen(String(Round(Seconds))) = 1,"0" + String(Seconds), String(Seconds));
EndFunction

// Returns a number presentation of a version.
//
// Parameters:
//   Version - String - a version number in the Х.Х.ХХ.ХХХ format 
//
// Returns:
//   Number - a version number converted into an integer
//
Function VersionAsNumber(Version) Export
	
	Result = 0;
	
	VersionsArray = Version;
	If TypeOf(Version) = Type("String") Then
		VersionsArray = StrSplit(Version, ".");
	EndIf;
	If VersionsArray.Count() = 4 Then
		Result = Number(VersionsArray[0]) * 10000000 + Number(VersionsArray[1]) * 1000000 
				  + Number(VersionsArray[2]) * 10000 + Number(VersionsArray[3]);
					
	ElsIf VersionsArray.Count() = 3 Then
		Result = Number(VersionsArray[0]) * 1000000 + Number(VersionsArray[1]) * 10000
				  + Number(VersionsArray[2]);
					
	ElsIf VersionsArray.Count() = 2 Then
		Result = Number(VersionsArray[0]) * 10000 + Number(VersionsArray[1]);
		
	EndIf;
		
	Return Result;
	
EndFunction

// Returns the list of subsystems to be developed in the configuration 
//
// Returns:
//   Array of String - subsystem names as they were set in the InfobaseUpdateXXX common modules
//
Function SubsystemsToDevelop() Export
	
	Result = New Array;
	InfobaseUpdateOverridable.WhenFormingAListOfSubsystemsUnderDevelopment(Result);
	InfobaseUpdateOverridable.OnGenerateListOfSubsystemsToDevelop(Result); // ACC:222 For backward compatibility.
	Return Result;
	
EndFunction

Function MoreInformation()
	Result = New Structure("DeferredHandlersExecutionMode,LibraryOrder,Order");
	Result.Order = Enums.OrderOfUpdateHandlers.Normal;
	Return Result;
EndFunction

Function FillInMetaDataTypePriorities()
	
	PrioritizingMetadataTypes = New Map;
	PrioritizingMetadataTypes.Insert("Constant", 10);
	PrioritizingMetadataTypes.Insert("Catalog", 20);
	PrioritizingMetadataTypes.Insert("ChartOfAccounts", 30);
	PrioritizingMetadataTypes.Insert("ChartOfCharacteristicTypes", 40);
	PrioritizingMetadataTypes.Insert("ExchangePlan", 50);
	PrioritizingMetadataTypes.Insert("ChartOfCalculationTypes", 60);
	PrioritizingMetadataTypes.Insert("Task", 70);
	PrioritizingMetadataTypes.Insert("BusinessProcess", 80);
	PrioritizingMetadataTypes.Insert("InformationRegisterIndependent", 90);
	PrioritizingMetadataTypes.Insert("Document", 100);
	PrioritizingMetadataTypes.Insert("DocumentJournal", 110);
	PrioritizingMetadataTypes.Insert("InformationRegister", 120);
	PrioritizingMetadataTypes.Insert("AccumulationRegister", 130);
	PrioritizingMetadataTypes.Insert("CalculationRegister", 140);
	PrioritizingMetadataTypes.Insert("AccountingRegister", 150);

	InfobaseUpdateOverridable.WhenPrioritizingMetadataTypes(PrioritizingMetadataTypes);
	
	Return PrioritizingMetadataTypes;

EndFunction

Function ObjectTypeOrder(FullName)
	
	If StrOccurrenceCount(FullName, ".") = 0 Then
		Return Undefined;
	EndIf;
	
	Names = StrSplit(FullName,".");
	ObjectType = Names[0];
	If ObjectType = "InformationRegister" Then
		ObjectMetadata = Common.MetadataObjectByFullName(FullName);
		If ObjectMetadata.WriteMode =  Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			ObjectType = ObjectType + "Independent";
		EndIf;
	EndIf;
	
	Result = PrioritizingMetadataTypes[FullName];
	If Result = Undefined Then
		Result = PrioritizingMetadataTypes[ObjectType];
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the mapping of direct and backward orders.
// "Before" in the direct order matches "After" in the backward order. 
// "After" in the direct order matches "Before" in the backward order. 
// "Any" in the direct order matches "Any" in the backward order.
//
// Returns:
//   Map
//
Function reverseorder() Export
	
	InverseOrder = New Map;
	InverseOrder.Insert("Before","After");
	InverseOrder.Insert("After","Before");
	InverseOrder.Insert("Any","Any");
	Return InverseOrder;
	
EndFunction

#EndRegion

#EndRegion

#Region Initialize

ConstantsInitialization();
FillInMetaDataTypePriorities();

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf
