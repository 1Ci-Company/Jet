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

#Region ForCallsFromOtherSubsystems

// See InfobaseUpdateSSL.OnAddUpdateHandlers.
Procedure OnAddUpdateHandlers(Handlers) Export

	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "MarkedObjectsDeletionInternal.EnableDeleteMarkedObjects";
	Handler.ExecutionMode = "Seamless";

	Handler = Handlers.Add();
	Handler.Version = "3.1.6.79";
	Handler.Procedure = "MarkedObjectsDeletionInternal.SetDeletionScheduleTagged";
	Handler.ExecutionMode = "Seamless";

EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings
Procedure OnDefineScheduledJobSettings(Settings) Export

	Dependence = Settings.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.MarkedObjectsDeletion;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseMarkedObjectsDeletion;
	Dependence.EnableOnEnableFunctionalOption = False;

EndProcedure

// See JobsQueueOverridable.OnGetTemplateList.
Procedure OnGetTemplateList(JobTemplates) Export

	JobTemplates.Add(Metadata.ScheduledJobs.MarkedObjectsDeletion.Name);
	JobTemplates.Add(Metadata.ScheduledJobs.MarkedObjectsDeletionControl.Name);

EndProcedure

// See JobsQueueOverridable.OnDefineHandlerAliases.
Procedure OnDefineHandlerAliases(NamesAndAliasesMap) Export

	NamesAndAliasesMap.Insert(Metadata.ScheduledJobs.MarkedObjectsDeletion.MethodName);
	NamesAndAliasesMap.Insert(Metadata.ScheduledJobs.MarkedObjectsDeletionControl.MethodName);

EndProcedure

// See CommonOverridable.OnAddReferenceSearchExceptions.
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export

	RefSearchExclusions.Add(Metadata.InformationRegisters.ObjectsToDelete);
	RefSearchExclusions.Add(Metadata.InformationRegisters.NotDeletedObjects);

EndProcedure

// See AttachableCommandsOverridable.OnDefineCommandsAttachedToObject.
Procedure OnDefineCommandsAttachedToObject(FormSettings, Sources, AttachedReportsAndDataProcessors, Commands) Export

	AttachedObjects = New Array;
	MarkedObjectsDeletionOverridable.OnDefineObjectsWithShowMarkedObjectsCommand(AttachedObjects);
	For Each AttachedObject In AttachedObjects Do

		Source = Sources.Rows.Find(AttachedObject, "Metadata");
		If Source <> Undefined Then

			Command = Commands.Add();
			Command.Kind = "ObjectsMarkedForDeletionDisplay";
			Command.Importance = "SeeAlso";
			Command.Presentation = NStr("en = 'Show objects marked for deletion';");
			Command.WriteMode = "NotWrite";
			Command.VisibilityInForms = "ListForm";
			Command.MultipleChoice = False;
			Command.Handler = "MarkedObjectsDeletionClient.RunAttachableCommandShowObjectsMarkedForDeletion";
			Command.OnlyInAllActions = True;
			Command.CheckMarkValue = "MarkedObjectsDeletionParameters.%Source%.CheckMarkValue";
			Command.Order = 20;

			If Users.IsFullUser() Then
				Command = Commands.Add();
				Command.Kind = "GoToMarkedForDeletionItems";
				Command.Importance = "SeeAlso";
				Command.Presentation = NStr("en = 'Go to objects marked for deletion';");
				Command.WriteMode = "NotWrite";
				Command.VisibilityInForms = "ListForm";
				Command.MultipleChoice = False;
				Command.Handler = "MarkedObjectsDeletionClient.RunAttachableCommandGoToObjectsMarkedForDeletion";
				Command.OnlyInAllActions = True;
				Command.Order = 20;
			EndIf;

		EndIf;

	EndDo;
EndProcedure

// See AttachableCommandsOverridable.OnDefineAttachableCommandsKinds.
Procedure OnDefineAttachableCommandsKinds(AttachableCommandsKinds) Export

	If AttachableCommandsKinds.Find("ObjectsMarkedForDeletionDisplay", "Name") = Undefined Then

		Kind = AttachableCommandsKinds.Add();
		Kind.Name         = "ObjectsMarkedForDeletionDisplay";
		Kind.SubmenuName  = "Service";
		Kind.Title   = NStr("en = 'Tools';");
		Kind.Order     = 80;
		Kind.Picture    = PictureLib.ServiceSubmenu;
		Kind.Representation = ButtonRepresentation.PictureAndText;

	EndIf;

	If AttachableCommandsKinds.Find("GoToMarkedForDeletionItems", "Name") = Undefined Then

		Kind = AttachableCommandsKinds.Add();
		Kind.Name         = "GoToMarkedForDeletionItems";
		Kind.SubmenuName  = "Service";
		Kind.Title   = NStr("en = 'Tools';");
		Kind.Order     = 80;
		Kind.Picture    = PictureLib.ServiceSubmenu;
		Kind.Representation = ButtonRepresentation.PictureAndText;

	EndIf;

EndProcedure

// Parameters:
//   ToDoList - See ToDoListServer.ToDoList.
//
Procedure OnFillToDoList(ToDoList) Export
	If Not Users.IsFullUser() Then
		Return;
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT
	|	ISNULL(COUNT(NotDeletedObjects.Object),0) AS Total
	|FROM
	|	InformationRegister.NotDeletedObjects AS NotDeletedObjects
	|WHERE
	|	NotDeletedObjects.AttemptsNumber > 3";

	QueryResult = Query.Execute();
	NotDeletedObjectsCount1 = QueryResult.Select();
	NotDeletedObjectsCount1.Next();

	ModuleToDoListServer = Common.CommonModule("ToDoListServer");

	Subsystem = Metadata.Subsystems.Find("Administration");
	If Subsystem = Undefined Or Not AccessRight("View", Subsystem)
		Or Not Common.MetadataObjectAvailableByFunctionalOptions(Subsystem) Then
		Sections = ModuleToDoListServer.SectionsForObject("DataProcessor.DeleteMarkedObjects");
	Else
		Sections = New Array;
		Sections.Add(Subsystem);
	EndIf;

	JobID = "NotDeletedObjects";
	For Each Section In Sections Do

		ToDoItem = ToDoList.Add();
		ToDoItem.Id  = JobID;
		ToDoItem.HasToDoItems       = NotDeletedObjectsCount1.Total > 0;
		ToDoItem.Presentation  = NStr("en = 'Skipped objects';");
		ToDoItem.Count     = NotDeletedObjectsCount1.Total;
		ToDoItem.Form          = "InformationRegister.NotDeletedObjects.ListForm";
		ToDoItem.Owner       = Section;

	EndDo;

EndProcedure

// See CommonOverridable.OnAddSessionParameterSettingHandlers.
Procedure OnAddSessionParameterSettingHandlers(Handlers) Export

	Handlers.Insert("ObjectsDeletionInProgress", "MarkedObjectsDeletionInternal.SessionParametersSetting");

EndProcedure

// Parameters:
//  ParameterName - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	If ParameterName = "ObjectsDeletionInProgress" Then
		SessionParameters.ObjectsDeletionInProgress = False;
		SpecifiedParameters.Add("ObjectsDeletionInProgress");
	EndIf;
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport.
Procedure OnFillTypesExcludedFromExportImport(Types) Export

	Types.Add(Metadata.InformationRegisters.NotDeletedObjects);
	Types.Add(Metadata.InformationRegisters.ObjectsToDelete);
	Types.Add(Metadata.Constants.CheckIfObjectsToDeleteAreUsed);

EndProcedure

// See ODataInterfaceOverridable.OnPopulateDependantTablesForODataImportExport
Procedure OnPopulateDependantTablesForODataImportExport(Tables) Export

	Tables.Add(Metadata.InformationRegisters.NotDeletedObjects.FullName());
	Tables.Add(Metadata.InformationRegisters.ObjectsToDelete.FullName());

EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region SubscriptionsHandlers

Procedure ProhibitUsageOfObjectsToDeleteInCatalogsOnWrite(Source, Cancel) Export
	ProhibitUsageOfObjectsToDelete(Source, Cancel);
EndProcedure

Procedure ProhibitUsageOfObjectsToDeleteInRecordSetsOnWrite(Source, Cancel, Replacing) Export
	ProhibitUsageOfObjectsToDelete(Source, Cancel);
EndProcedure

Procedure ProhibitUsageOfObjectsToDeleteInCalculationRegistersSetsOnWrite(Source, Cancel, Replacing) Export
	ProhibitUsageOfObjectsToDelete(Source, Cancel);
EndProcedure

Procedure ProhibitUsageOfObjectsToDeleteInConstantsOnWrite(Source, Cancel) Export
	ProhibitUsageOfObjectsToDelete(Source, Cancel);
EndProcedure

Procedure ProhibitUsageOfObjectsToDeleteInDocumentsBeforeWrite(Source, Cancel, WriteMode, PostingMode) Export
	ProhibitUsageOfObjectsToDelete(Source, Cancel);
EndProcedure

#EndRegion

Function AllowedDeletionModes() Export

	AllowedModes = New Array;
	AllowedModes.Add("Standard");
	AllowedModes.Add("Exclusive");
	AllowedModes.Add("Simplified");
	Return AllowedModes;

EndFunction

Procedure EnableDeleteMarkedObjects() Export
	Constants.UseMarkedObjectsDeletion.Set(True);
EndProcedure

Procedure SetDeletionScheduleTagged() Export

	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;

	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101040000'; // At 4:00. 
	Schedule.EndTime = '00010101060000'; // At 6:00. 
	Schedule.CompletionTime = '00010101060000'; // 06:00 

	JobParameters = New Structure;
	JobParameters.Insert("Schedule", Schedule);
	JobParameters.Insert("RestartIntervalOnFailure", 10);
	JobParameters.Insert("RestartCountOnFailure", 3);

	ScheduledJobsServer.SetScheduledJobParameters(
		Metadata.ScheduledJobs.MarkedObjectsDeletion, JobParameters);

EndProcedure

// Scheduled job entry point.
//
Procedure MarkedObjectsDeletionScheduled() Export

	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.MarkedObjectsDeletion);
	ObjectsToDelete = MarkedObjectsDeletion.MarkedForDeletion(, True);
	ToDeleteMarkedObjectsInternal(ObjectsToDelete, "Standard",, True);

EndProcedure

// Returns True if the passed type is simple
// 
// Parameters:
//   Type - Type
//
// Returns:
//   Boolean
//
Function IsSimpleType(Type) Export
	Return (Type = Undefined Or Type = Type("String") Or Type = Type("Number") Or Type = Type("Boolean") Or Type = Type(
		"Date"));
EndFunction

// Generates a list of metadata objects where dead references are allowed.
// The result is cached.
// 
// Returns:
//   Array of MetadataObject
//
Function ExceptionsOfSearchForRefsAllowingDeletion() Export
	Return MarkedObjectsDeletionCached.ExceptionsOfSearchForRefsAllowingDeletion();
EndFunction

// Unlocks objects after the deletion session timeout is expired.
// Used in case of abnormal termination of deletion sessions. 
// 
// 
Procedure MarkedObjectsDeletionControl() Export
	Common.OnStartExecuteScheduledJob(
		Metadata.ScheduledJobs.MarkedObjectsDeletionControl);

	SetPrivilegedMode(True);
	If Not CheckIfObjectsToDeleteAreUsed() Then
		Return;
	EndIf;

	TheLifetimeOfALock = TheLifetimeOfALock();
	UnlockTime = CurrentSessionDate() - TheLifetimeOfALock;

	QueryText =
	"SELECT DISTINCT TOP 1000
	|	ObjectsToDelete.SessionID AS SessionID,
	|	ObjectsToDelete.Period AS LockTime
	|FROM
	|	InformationRegister.ObjectsToDelete AS ObjectsToDelete
	|WHERE
	|	ObjectsToDelete.Period <= &UnlockTime
	|	AND &Condition
	|
	|ORDER BY
	|	LockTime";
	TimeCondition = "ObjectsToDelete.Period > &LockTime";
	QueryTextWithCondition = StrReplace(QueryText, "&Condition", TimeCondition);

	Query = New Query(StrReplace(QueryText, "&Condition", "TRUE"));
	Query.SetParameter("UnlockTime", UnlockTime);
	QueryResult = Query.Execute().Unload();

	ProcessedSessions = New Map;
	While QueryResult.Count() > 0 Do

		For Each SelectionDetailRecords In QueryResult Do
			IsDeletionSessionProcessed = ProcessedSessions[SelectionDetailRecords.SessionID];
			If IsDeletionSessionProcessed = True Then
				Continue;
			EndIf;

			If IsDeletionSessionProcessed = Undefined Then
				HasDeletionSession = BackgroundJobs.FindByUUID(
					SelectionDetailRecords.SessionID) <> Undefined;
				ProcessedSessions[SelectionDetailRecords.SessionID] = Not HasDeletionSession;
			Else
				HasDeletionSession = True;
			EndIf;
			Try
				// @skip-check query-in-loop - Batch processing of a large amount of data.
				UnlockUsageOfObjectsToDelete(SelectionDetailRecords.SessionID, ?(
					HasDeletionSession, SelectionDetailRecords.LockTime, Undefined));
			Except
				WriteLogEvent(
					NStr("en = 'Marked object deletion';", Common.DefaultLanguageCode()),
					EventLogLevel.Error,,, NStr(
					"en = 'Cannot disable check of marked objects due to:';") + Chars.LF
					+ ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			EndTry;
		EndDo;

		ProcessedSessions = New Map;
		Query.Text = QueryTextWithCondition;
		Query.SetParameter("LockTime", SelectionDetailRecords.LockTime);
		Query.SetParameter("UnlockTime", UnlockTime);
		QueryResult = Query.Execute().Unload(); // @skip-check query-in-loop - Batch processing of a large amount of data.

	EndDo;

	TryDisableMarkedObjectsDeletionControl();

EndProcedure

// Returns the timeout (in seconds) for locking the object to be deleted. 
// By default, 3 hours.
// 
// Returns:
//   Number
//
Function TheLifetimeOfALock() Export

	Return 3 * 60 * 60;

EndFunction

// Generated a string key to save the view settings of the objects marked for deletion.
//
// Parameters:
//   FormName - String
//   ListName - String
//
// Returns:
//   String
//
Function SettingsKey(FormName, ListName) Export

	Var_Key = "ShowObjectsMarkedForDeletion1/" + FormName + "/" + ListName;
	Return Var_Key;

EndFunction

// Parameters:
//   ObjectType - Type
//
// Returns:
//  Structure:
//    * FullName - String - Upper-case full metadata object name. For example, "CATALOG.CURRENCIES".
//    * ItemPresentation - String - For example. "Currency".
//    * ListPresentation - String - For example. "Currencies".
//    * Kind - String - Upper-case metadata object type. For example, "CATALOG".
//    * Referential - Boolean - True if the object is a reference type object.
//    * Technical - Boolean - True if the object must not be added to the list.
//    * Separated1 - Boolean - Filled only in the SaaS mode. 
//
Function TypeInformation(ObjectType, ComplementableInfoAboutTypes = Undefined) Export

	If ComplementableInfoAboutTypes = Undefined Then
		ComplementableInfoAboutTypes = New Map;
	EndIf;

	Information = ComplementableInfoAboutTypes[ObjectType];
	If Information <> Undefined Then
		Return Information;
	EndIf;

	Information = New Structure("FullName, ItemPresentation, ListPresentation,
								 |Kind, Referential, Technical, Separated1");
	ComplementableInfoAboutTypes[ObjectType] = Information;

	MetadataObject = Metadata.FindByType(ObjectType);

	Information.FullName = Upper(MetadataObject.FullName());
	Information.Kind = Left(Information.FullName, StrFind(Information.FullName, ".") - 1);
	Information.ItemPresentation = Common.ObjectPresentation(MetadataObject);
	Information.ListPresentation = Common.ListPresentation(MetadataObject);
	Information.Referential = Common.IsRefTypeObject(MetadataObject);
	Information.Technical = IsTechnicalObject(Information.FullName);

	If Common.DataSeparationEnabled() Then

		If Common.SubsystemExists("CloudTechnology.Core") Then
			ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
			IsSeparatedMetadataObject = ModuleSaaSOperations.IsSeparatedMetadataObject(MetadataObject);
		Else
			IsSeparatedMetadataObject = False;
		EndIf;
		Information.Separated1 = IsSeparatedMetadataObject;

	EndIf;
	Return Information;

EndFunction

// Parameters:
//   Objects - Array of AnyRef
//   ComplementableInfoAboutTypes - See TypesInformation
//
// Returns:
//   Map of KeyAndValue:
//     Key - Type - Metadata object type. For example, MetadataCatalog.Currencies.
//     Value - See TypeInformation 
//
Function TypesInformation(Objects, ComplementableInfoAboutTypes = Undefined) Export

	Result = ?(TypeOf(ComplementableInfoAboutTypes) = Type("Map"), ComplementableInfoAboutTypes,
		New Map);

	For Each ObjectRef In Objects Do
		ObjectType = TypeOf(ObjectRef);
		If Result[ObjectType] = Undefined Then
			Result[ObjectType] = TypeInformation(ObjectType);
		EndIf;
	EndDo;
	Return Result;

EndFunction

Function TablesMerge(Table1, Table2, SaveOrder = False) Export
	If SaveOrder Or Table1.Count() >= Table2.Count() Then
		Receiver = Table1.Copy();
		Source = Table2;
	Else
		Receiver = Table2.Copy();
		Source = Table1;
	EndIf;

	For Each Item In Source Do
		FillPropertyValues(Receiver.Add(), Item);
	EndDo;

	Return Receiver;
EndFunction

// Parameters:
//   Settings - ValueTable:
//   * Attribute - String
//   * Metadata - String
//
// Returns:
//   Number
//
Function AdditionalAttributesNumber(Settings) Export
	Result = 0;
	IntermediateTable = Settings.Copy(, "Metadata,Attribute");
	IntermediateTable.Columns.Add("Counter", New TypeDescription("Number"));
	IntermediateTable.FillValues(1, "Counter");
	IntermediateTable.GroupBy("Metadata", "Counter");
	IntermediateTable.Sort("Counter Desc");

	If IntermediateTable.Count() > 0 Then
		Result = IntermediateTable[0].Counter;
	EndIf;

	Return Result;
EndFunction

Function HasLockedRelevantObjects()

	TheLifetimeOfALock = TheLifetimeOfALock();
	UnlockTime = CurrentSessionDate() - TheLifetimeOfALock;
	
	Query = New Query();
	Query.Text =
	"SELECT DISTINCT TOP 1
	|	ObjectsToDelete.SessionID AS SessionID,
	|	ObjectsToDelete.Period AS LockTime
	|FROM
	|	InformationRegister.ObjectsToDelete AS ObjectsToDelete
	|WHERE
	|	ObjectsToDelete.Period > &UnlockTime";
	
	Query.SetParameter("UnlockTime", UnlockTime);
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

#Region MarkedObjectsDeletionFormCommandHandlers

Function MarkedForDeletion(MetadataFilter, Settings, MarkedForDeletionItemsTree, SearchForTechnologicalObjects = False) Export
	MarkedForDeletion = MarkedObjectsDeletion.MarkedForDeletion(MetadataFilter, SearchForTechnologicalObjects);
	Marked = ObjectsToDeleteFromFormData(MarkedForDeletionItemsTree);
	Return MarkedForDeletionItemsTree(MarkedForDeletion, Settings, Marked);
EndFunction

// Performs either of the following user-chosen actions for object pointers that prevent it from being deleted:
// • Replaces the references to the given object with a reference to another object.
// • Markes the pointer for deletion.
// 
// Parameters:
//   ActionsTable - ValueTable:
//     * Source - AnyRef - Object to be deleted.
//     * FoundItemReference - AnyRef - Object pointer.
//     * Action - String - Valid values are::
//                           "ReplaceRef" - Replace the reference with a reference to the object specified in "ActionParameter".
//                              "Delete" - Mark the object that refers to the given object for deletion.
//                           
//     * ActionParameter - If "ReplaceRef" is selected, it contains a reference to the replacing object.
//
// Returns:
//   See ObjectsToDeleteProcessingResult
//
Function RunDataProcessorOfReasonsForNotDeletion(ActionsTable) Export

	Result = ObjectsToDeleteProcessingResult();

	ReplacementPairs = New Map;
	DeletionMarkQueue = New Array;
	DataVersions = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		ActionsTable.UnloadColumn("Source"), "DataVersion");
		
	For Each Action In ActionsTable Do

		If Action.Action <> "ReplaceRef" And (Not ValueIsFilled(DataVersions[Action.Source])
			Or Not ValueIsFilled(Action.FoundItemReference)
			Or Not ValueIsFilled(Value(Action.FoundItemReference, "DataVersion"))) Then

			Continue;
		EndIf;

		If Action.Action = "Delete" Then
			If Common.ObjectAttributeValue(Action.FoundItemReference, "DeletionMark") Then
				ResultString1 = Result.Add();
				ResultString1.ItemToDeleteRef = Action.FoundItemReference;
				ResultString1.DeletionRequired1 = True;
			Else
				DeletionMarkQueue.Add(Action.FoundItemReference);
			EndIf;
		ElsIf Action.Action = "ReplaceRef" Then
			ReplacementPairs.Insert(Action.Source, Action.ActionParameter);
		Else
			ResultString1 = Result.Add();
			ResultString1.ItemToDeleteRef = Action.FoundItemReference;
		EndIf;
	EndDo;

	If DeletionMarkQueue.Count() > 0 Then
		Result = TablesMerge(Result, ProcessDeletionMarksQueue(DeletionMarkQueue));
	EndIf;

	If ReplacementPairs.Count() > 0 Then
		ReplacementResult = Common.ReplaceReferences(ReplacementPairs, Common.RefsReplacementParameters());
		For Each ResultString1 In ReplacementResult Do
			NewRow = Result.Add();
			NewRow.ItemToDeleteRef = ResultString1.Ref;
			NewRow.FoundItemReference = ResultString1.ErrorObject;
			NewRow.ErrorText = ResultString1.ErrorText;
		EndDo;
	EndIf;

	Return Result;

EndFunction

// Deletes the objects marked on the DataProcessors.MarkedObjectsDeletion.DefaultForm form
// and generates the data to import in the form.
// 
// When opening a form with the passed ObjectsToDelete parameter, a list of the objects to be deleted is generated
// from the parameter value.
// 
// Parameters:
//   ObjectsToDeleteSource - ValueTree:
//     * ItemToDeleteRef - AnyRef
// 	                     - ValueList of AnyRef
//   DeletionMode - String
//   AdditionalAttributesSettings - ValueTable
//   PreviousStepResult - See ObjectsToDeleteProcessingResult
//   JobID - UUID - UUID of the form where the job was started.
// 													 Intended for releasing the lock when the job is interrupted 
// 													 and the form closed.
//
// Returns:
//   See FormDataFromDeletionResult
//
Function ToDeleteMarkedObjects(Val ObjectsToDeleteSource, DeletionMode, AdditionalAttributesSettings,
	PreviousStepResult, JobID, ShouldDeleteTechnologicalObjects = False) Export
	
	MarkedObjectsDeletionControl();
	
	If TypeOf(ObjectsToDeleteSource) = Type("ValueList") Then
		ObjectsToDeleteSource = MarkedForDeletionItemsTree(ObjectsToDeleteSource.UnloadValues(),
			AdditionalAttributesSettings, New Array);
	ElsIf ObjectsToDeleteSource = Undefined Then
		ObjectsToDeleteSource = MarkedForDeletionItemsTree(MarkedObjectsDeletion.MarkedForDeletion(, True),
			AdditionalAttributesSettings, New Array);
	EndIf;

	PreviousStepResult = AdditionalDataProcessorStepResult(PreviousStepResult);
	ObjectsToDelete = ObjectsToDeleteFromAdditionalProcessingResult(PreviousStepResult);
	CommonClientServer.SupplementArray(ObjectsToDelete, 
		ObjectsToDeleteFromFormData(ObjectsToDeleteSource, PreviousStepResult));

	DeletionResult = ToDeleteMarkedObjectsInternal(ObjectsToDelete, DeletionMode, JobID);
	Result = FormDataFromDeletionResult(ObjectsToDeleteSource, DeletionResult,
		AdditionalAttributesSettings, PreviousStepResult, ShouldDeleteTechnologicalObjects);

	Return Result;
EndFunction

#EndRegion

// Records the information required for locking objects that should be deleted.
// Starts a scheduled job that checks if the objects are being used.
// Does not support shared sessions in the SaaS mode.
//
Procedure SetObjectsToDeleteUsageLock(Package, SessionID) Export

	IsSaaSModel = Common.DataSeparationEnabled();
	InDataArea = ?(IsSaaSModel, Common.SeparatedDataUsageAvailable(), False);
	If IsSaaSModel And Not InDataArea Then
		Return;
	EndIf;

	RecordSet = InformationRegisters.ObjectsToDelete.CreateRecordSet();
	RecordSet.Filter.SessionID.Set(SessionID);

	DeletionStartTime = CurrentSessionDate();
	For Each Item In Package Do
		Record = RecordSet.Add();
		Record.SessionID = SessionID;
		Record.Object = Item.ItemToDeleteRef;
		Record.Period = DeletionStartTime;
	EndDo;

	BeginTransaction();
	Try
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ObjectsToDelete");
		LockItem.SetValue("SessionID", SessionID);
		Block.Lock();

		Constants.CheckIfObjectsToDeleteAreUsed.Set(True);
		RecordSet.Write();

		Filter = New Structure("Metadata", Metadata.ScheduledJobs.MarkedObjectsDeletionControl);
		SetPrivilegedMode(True);
		CheckJob = ScheduledJobsServer.FindJobs(Filter);
		For Each Job In CheckJob Do
			ScheduledJobsServer.ChangeJob(Job.UUID, New Structure("Use",
				True));
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

// Disables the usage control for objects to be deleted. Disables the scheduled job if all the objects marked for deletion are processed. 
// Not applicable to shared SaaS sessions.
// 
// 
// Parameters:
//   SessionID - UUID
//   UnlockTime - Date
//
Procedure UnlockUsageOfObjectsToDelete(SessionID, UnlockTime = Undefined) Export
	If Common.DataSeparationEnabled() And Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;

	RecordSet = InformationRegisters.ObjectsToDelete.CreateRecordSet();
	RecordSet.Filter.SessionID.Set(SessionID);
	If UnlockTime <> Undefined Then
		RecordSet.Filter.Period.Set(UnlockTime);
	EndIf;
	RecordSet.Write();

	If UnlockTime = Undefined Then
		TryDisableMarkedObjectsDeletionControl();
	EndIf;

EndProcedure

Procedure TryDisableMarkedObjectsDeletionControl()

	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.CheckIfObjectsToDeleteAreUsed");
		Block.Lock();

		If Constants.CheckIfObjectsToDeleteAreUsed.Get() Then
			Query = New Query("SELECT TOP 1 Tab.SessionID FROM InformationRegister.ObjectsToDelete AS Tab");
			If Query.Execute().IsEmpty() Then
				Constants.CheckIfObjectsToDeleteAreUsed.Set(False);

				Filter = New Structure("Metadata",
					Metadata.ScheduledJobs.MarkedObjectsDeletionControl);
				SetPrivilegedMode(True);
				CheckJob = ScheduledJobsServer.FindJobs(Filter);
				For Each Job In CheckJob Do
					ScheduledJobsServer.ChangeJob(Job.UUID,
						New Structure("Use", False));
				EndDo;
			EndIf;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure
	
// Receive a value of the view settings of the marked objects from the storage.
// 
// Parameters:
//   FormName - String
//   ListName - String
// Returns:
//   See Common.FormDataSettingsStorageLoad
//
Function ImportObjectsMarkedForDeletionViewSetting(FormName, ListName) Export
	SettingsKey = SettingsKey(FormName, ListName);
	Return Common.FormDataSettingsStorageLoad(FormName, SettingsKey, False);
EndFunction

// Unmarks the items for deletion if there is at least one object marked for deletion.
// If all the objects are not marked for deletion, marks for deletion.
//
// Throws exception if an error occurred when marking for deletion.
//
// Parameters:
//  References	 - Array of AnyRef
//
// Returns:
//   ValueTable:
//   * Ref - AnyRef
//   * DeletionMarkNewValue - Boolean
//
Function RemovePutATickRemoval(References) Export
	Result = New ValueTable;
	Result.Columns.Add("Ref");
	Result.Columns.Add("DeletionMarkNewValue");
	TotalValueOfTheDeletionMark = False;

	TheValueOfTheMarksRemoval = Common.ObjectsAttributeValue(References, "DeletionMark");

	NumberOfUnmarkedItemsToDelete = 0;
	For Each LinkTheValueOfTheProp In TheValueOfTheMarksRemoval Do
		If LinkTheValueOfTheProp.Value = False Then
			NumberOfUnmarkedItemsToDelete = NumberOfUnmarkedItemsToDelete + 1;
		EndIf;
	EndDo;

	If NumberOfUnmarkedItemsToDelete = TheValueOfTheMarksRemoval.Count() Then
		TotalValueOfTheDeletionMark = True;
	EndIf;

	BeginTransaction();
	Try

		For Each LinkTheValueOfTheProp In TheValueOfTheMarksRemoval Do

			If LinkTheValueOfTheProp.Value <> TotalValueOfTheDeletionMark Then
				ResultString1 = Result.Add();
				ResultString1.Ref = LinkTheValueOfTheProp.Key;

				Object = LinkTheValueOfTheProp.Key.GetObject();
				Object.SetDeletionMark(TotalValueOfTheDeletionMark);
				ResultString1.DeletionMarkNewValue = TotalValueOfTheDeletionMark;
			EndIf;

		EndDo;
		CommitTransaction();

	Except
		RollbackTransaction();
		Raise;
	EndTry;

	Return Result;
EndFunction

#Region SearchForItemsmarkedForDeletion

// Parameters:
//   ObjectsToDelete - Array of AnyRef
//   Settings - ValueTable:
//       * Attribute - String
//       * Metadata - String
//       * Presentation - String
//   Marked - Array of AnyRef
//
// Returns:
//   See NewTreeOfDeletableObjects
//
Function MarkedForDeletionItemsTree(ObjectsToDelete, Settings, Marked)
	MarksAreSetSelectively = (Marked.Count() > 0);
	ValueTree = NewTreeOfDeletableObjects(AdditionalAttributesNumber(Settings));

	AdditionalDeletableObjectsIDs = StandardSubsystemsServer.ObjectAttributeValuesIfExist(ObjectsToDelete, "Date");

	FirstLevelNodes = New Map;

	TypesInformation = TypesInformation(ObjectsToDelete);
	For Each ItemToDeleteRef In ObjectsToDelete Do
		TypeOfObjectToDelete = TypeOf(ItemToDeleteRef);
		TypeInformation = TypesInformation[TypeOfObjectToDelete]; // See TypeInformation

		NodeOfType = FirstLevelNodes[TypeOfObjectToDelete];
		If NodeOfType = Undefined Then
			NodeOfType = ValueTree.Rows.Add();
			NodeOfType.ItemToDeleteRef = TypeInformation.FullName;
			NodeOfType.Presentation = TypeInformation.ListPresentation;
			NodeOfType.Check       = True;
			NodeOfType.Count    = 0;
			NodeOfType.PictureNumber = -1;
			NodeOfType.IsMetadataObjectDetails = True;
			NodeOfType.Technical = TypeInformation.Technical;
			FillAdditionalAttributesDetails(Settings, TypeInformation.FullName, NodeOfType);
			FirstLevelNodes[TypeOfObjectToDelete] = NodeOfType;
		EndIf;
		NodeOfType.Count = NodeOfType.Count + 1;
		NodeOfType.Presentation = TypeInformation.ListPresentation + " (" + NodeOfType.Count + ")";

		NodeOfItemToDelete = NodeOfType.Rows.Add();
		NodeOfItemToDelete.ItemToDeleteRef = ItemToDeleteRef;
		NodeOfItemToDelete.Presentation = String(ItemToDeleteRef);
		NodeOfItemToDelete.Check       = True;
		NodeOfItemToDelete.PictureNumber = PictureNumber(ItemToDeleteRef, True, TypeInformation.Kind, "Removed");
		AttributesValues = AdditionalDeletableObjectsIDs.Get(ItemToDeleteRef);
		NodeOfItemToDelete.Date = ?(AttributesValues = Undefined, '00010101', AttributesValues.Date);
		
		NodeOfType.Technical         = TypeInformation.Technical;

		If MarksAreSetSelectively And Marked.Find(ItemToDeleteRef) = Undefined Then
			NodeOfItemToDelete.Check = False;
			NodeOfType.Check       = False;
		EndIf;

	EndDo;

	ValueTree = SupplementTreeWithAdditionalAttributes(ValueTree, Settings);

	ValueTree.Columns.Delete(ValueTree.Columns.Count);
		ValueTree.Rows.Sort("Date, Presentation", True);

	Return ValueTree;
EndFunction

Procedure FillAdditionalAttributesDetails(Val Settings, Val FullObjectName, Val NodeOfType)
	IndexOf = 1;
	For Each Setting In Settings Do
		If Upper(Setting.Metadata) = FullObjectName Then
			NodeOfType["Attribute" + (IndexOf)] = Setting.Presentation;
			IndexOf = IndexOf + 1;
		EndIf;
	EndDo;
EndProcedure

// Parameters:
//   ValueTree - ValueTree
//   Settings - ValueTable
//
// Returns:
//   ValueTree
//
Function SupplementTreeWithAdditionalAttributes(ValueTree, Settings)
	Result = ValueTree.Copy();
	Result.Rows.Clear();

	For Each Item In Settings Do
		Item.Metadata = Upper(Item.Metadata);
	EndDo;

	For Each MetadataType In ValueTree.Rows Do
		ResultMetadataType = Result.Rows.Add();
		FillPropertyValues(ResultMetadataType, MetadataType);
		MarkedForDeletion = MetadataType.Rows.UnloadColumn("ItemToDeleteRef");
		AdditionalAttributes = AdditionalAttributesValues(MarkedForDeletion, Settings.FindRows(
			New Structure("Metadata", Upper(MetadataType.ItemToDeleteRef))));

		For Each MarkedObject In MetadataType.Rows Do
			MarkedObjectResult = ResultMetadataType.Rows.Add();
			FillPropertyValues(MarkedObjectResult, MarkedObject);
			FillAdditionalAttributesValue(MarkedObjectResult, AdditionalAttributes);
		EndDo;
	EndDo;

	Return Result;
EndFunction

Procedure FillAdditionalAttributesValue(Val MarkedObjectResult, Val AdditionalAttributes)
	IndexOf = 1;
	AdditionalAttributesValue = AdditionalAttributes[MarkedObjectResult.ItemToDeleteRef];
	If AdditionalAttributesValue <> Undefined Then
		For Each AttributeValue In AdditionalAttributesValue Do
			MarkedObjectResult["Attribute" + IndexOf] = AttributeValue.Value;
			IndexOf = IndexOf + 1;
		EndDo;
	EndIf;
EndProcedure

// Parameters:
//   MarkedForDeletion - Array
//   AdditionalAttributesSettings - Array of ValueTableRow
//
// Returns:
//   Map
//
Function AdditionalAttributesValues(MarkedForDeletion, AdditionalAttributesSettings)
	Result = New Map;
	AdditionalAttributes = New Array;

	For Each Attribute In AdditionalAttributesSettings Do
		AdditionalAttributes.Add(Attribute.Attribute);
	EndDo;

	If AdditionalAttributes.Count() > 0 Then
		Result = Common.ObjectsAttributesValues(MarkedForDeletion, StrConcat(
			AdditionalAttributes, ","));
	EndIf;

	Return Result;
EndFunction

#EndRegion

#Region ExecutionOfAdditionalDataProcessorOfReasonsForNotDeletion

Function ProcessDeletionMarksQueue(DeletionMarkQueue)
	Result = ObjectsToDeleteProcessingResult();

	ErrorsPresentations = New Map;
	ObjectsWithErrors = New Array;

	For Each Item In DeletionMarkQueue Do

		LongDesc = Result.Add();
		LongDesc.ItemToDeleteRef = Item;
		LongDesc.DeletionRequired1 = True;

		BeginTransaction();
		Try
			Block = New DataLock;
			LockItem = Block.Add(Item.Metadata().FullName());
			LockItem.SetValue("Ref", Item);
			Block.Lock();

			RemovableObject = Item.GetObject();
			RemovableObject.AdditionalProperties.Insert("DontControlObjectsToDelete");
			RemovableObject.SetDeletionMark(True);
			CommitTransaction();

		Except
			RollbackTransaction();
			Error = ErrorInfo();
			LongDesc.DeletionRequired1 = False;
			LongDesc.ErrorText = ErrorProcessing.BriefErrorDescription(Error);

			ErrorsPresentations[Item] = ErrorProcessing.DetailErrorDescription(Error);
			ObjectsWithErrors.Add(Item);
		EndTry;

	EndDo;

	If ErrorsPresentations.Count() > 0 Then

		ErrorText = New Array;
		ObjectsPresentations = Common.SubjectAsString(ObjectsWithErrors);
		For Each Object In ObjectsWithErrors Do
			ErrorText.Add(ObjectsPresentations[Object] + ":" + Chars.LF + ErrorsPresentations[Object]);
		EndDo;
		WriteLogEvent(
			NStr("en = 'Marked object deletion';", Common.DefaultLanguageCode()), EventLogLevel.Error,
			,, NStr("en = 'Couldn''t mark the following objects for deletion:';") + Chars.LF + StrConcat(
			ErrorText, Chars.LF + Chars.LF));

	EndIf;

	Return Result;
EndFunction

#EndRegion

#Region ObjectsToDeleteUsageControl

Procedure ProhibitUsageOfObjectsToDelete(Source, Cancel)
	
	// Do not set "DataExchange.Load" to "True" as the check is performed
	// when importing from external sources.

	If ExclusiveMode() Then
		Return;
	EndIf;

	If Source.AdditionalProperties.Property("DontControlObjectsToDelete")
		Or SessionParameters.ObjectsDeletionInProgress Then
		Return;
	EndIf;

	If Common.IsConstant(Source.Metadata()) Then
		ValuesType = TypeOf(Source.Value);

		If Not Common.IsReference(ValuesType) Then
			Return;
		EndIf;
	EndIf;

	SetPrivilegedMode(True);

	If Not CheckIfObjectsToDeleteAreUsed() Then
		Return;
	EndIf;
	
	If Not HasLockedRelevantObjects() Then
		Return;
	EndIf;

	If ExceptionsOfSearchForRefsAllowingDeletion().Find(Source.Metadata()) <> Undefined Then
		Return;
	EndIf;

	SourceType = TypeOf(Source);
	If SourceType = Type("InformationRegisterRecordSet.ObjectsToDelete") Or SourceType = Type(
		"InformationRegisterRecordSet.NotDeletedObjects") Then
		Return;
	EndIf;

	RefsToObjectsToDelete = New Array;
	Try
		RefsToObjectsToDelete = MarkedObjectsDeletion.RefsToObjectsToDelete(Source);
	Except
		Error = ErrorInfo();
		WriteLogEvent(
				NStr("en = 'Delete marked objects';", Common.DefaultLanguageCode()),
			EventLogLevel.Error,,, NStr("en = 'Cannot control objects to be deleted:';")
			+ ErrorProcessing.DetailErrorDescription(Error));
	EndTry;

	MessageText = "";
	If RefsToObjectsToDelete.Count() = 1 Then
		RepresentationOfTheReference = "";
		For Each RefToDelete In RefsToObjectsToDelete Do
			RepresentationOfTheReference = Common.SubjectString(RefToDelete.Key);
		EndDo;

		MessageText = NStr("en = 'The selected item %1 is currently being deleted as it was marked for deletion.
							  |Select another value.';");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageText, RepresentationOfTheReference);

	ElsIf RefsToObjectsToDelete.Count() > 1 Then

		LinkRepresentation = New Array;
		For Each RefToDelete In RefsToObjectsToDelete Do
			LinkRepresentation.Add(Common.SubjectString(RefToDelete.Key));
		EndDo;

		MessageText = NStr("en = 'The selected items are currently being deleted as they were marked for deletion.
							  |Select other values.
							  |%1';");

		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageText, StrConcat(LinkRepresentation, "-" + Chars.LF));
	EndIf;

	If RefsToObjectsToDelete.Count() > 0 Then
		Raise MessageText;
	EndIf;
EndProcedure

#EndRegion

#Region MarkedObjectsDeletion

// Returns:
//   Structure:
//   * Trash - Array of AnyRef
//   * NotDeletedObjectsCount - Number
//   * DeletedItemsCount - Number
//   * NotDeletedItemsLinks - See NotDeletedItemsLinks
//   * MarkedForDeletionItemsTree - See NewTreeOfDeletableObjects
//   * NotTrash - See NewTreeOfDeletableObjects
//
Function FormDataFromDeletionResult(ObjectsToDeleteTree, DeletionResult, AdditionalAttributesSettings,
	PreviousStepResult, ShouldDeleteTechnologicalObjects)

	MarkedForDeletionItemsTree = FormTreeToUniversalTree(ObjectsToDeleteTree, AdditionalAttributesNumber(
		AdditionalAttributesSettings));

	Result = New Structure;
	Result.Insert("Trash", New Array(New FixedArray(DeletionResult.Trash)));
	Result.Insert("NotTrash", NewTreeOfDeletableObjects());
	Result.Insert("MarkedForDeletionItemsTree", MarkedForDeletionItemsTree);
	Result.Insert("NotDeletedItemsLinks", NotDeletedItemsLinks());
	Result.Insert("DeletedItemsCount", 0);
	Result.Insert("NotDeletedObjectsCount", 0);

	ObjectsPreventingDeletion = DeletionResult.ObjectsPreventingDeletion.UnloadColumn("ItemToDeleteRef");
	TypesInformation = TypesInformation(ObjectsPreventingDeletion);

	AttributesNames = New Array;
	AttributesNames.Add("DeletionMark");
	AttributesNames.Add("Posted");
	Attributes = StandardSubsystemsServer.ObjectAttributeValuesIfExist(
		DeletionResult.ObjectsPreventingDeletion.UnloadColumn("UsageInstance1"), AttributesNames);

	For Each ObjectToPreventDeletion In DeletionResult.ObjectsPreventingDeletion Do
		AddTreeRow(Result.NotTrash, ObjectToPreventDeletion.ItemToDeleteRef, TypesInformation,
			ShouldDeleteTechnologicalObjects);
		AddTreeRow(Result.MarkedForDeletionItemsTree, ObjectToPreventDeletion.ItemToDeleteRef,
			TypesInformation, ShouldDeleteTechnologicalObjects);
		AddNotDeletedItemRelationsRow(Result.NotDeletedItemsLinks, ObjectToPreventDeletion, TypesInformation,
			Attributes, ShouldDeleteTechnologicalObjects);
	EndDo;

	Result.MarkedForDeletionItemsTree.Rows.Sort("Presentation", True);
	Result.NotDeletedItemsLinks.Sort("ItemToDeleteRef", New CompareValues);

	Result.MarkedForDeletionItemsTree = MarkedForDeletionItemsTreeWithoutDeletedItems(
		Result.MarkedForDeletionItemsTree, DeletionResult.Trash);

	ChangedTreeRows = Result.MarkedForDeletionItemsTree.Rows.FindRows(
		New Structure("Modified", True));
	For Each NotDeletedItemGroup In ChangedTreeRows Do
		NotDeletedItemGroup.Presentation = NotDeletedItemGroup.Presentation + " (" + Format(
			NotDeletedItemGroup.LinkCount, "NZ=0; NG=") + ")";
	EndDo;

	Result.MarkedForDeletionItemsTree = SupplementTreeWithAdditionalAttributes(
		Result.MarkedForDeletionItemsTree, AdditionalAttributesSettings);

	Result.NotDeletedItemsLinks = TablesMerge(
		PreviousStepErrors(PreviousStepResult), Result.NotDeletedItemsLinks);

	Result.NotDeletedObjectsCount = DeletionResult.NotTrash.Count();
	Result.DeletedItemsCount = DeletionResult.Trash.Count();

	Return Result
EndFunction

Function AdditionalDataProcessorStepResult(PreviousStepResultIntermediate)
	Return ?(TypeOf(PreviousStepResultIntermediate) <> Type("ValueTable"),
		ObjectsToDeleteProcessingResult(), PreviousStepResultIntermediate);
EndFunction

Function FormTreeToUniversalTree(ObjectsToDeleteTree, AdditionalAttributesCount)
	Result = NewTreeOfDeletableObjects(AdditionalAttributesCount);
	CopyRows(Result.Rows, ObjectsToDeleteTree.Rows);
	Return Result;
EndFunction

// Parameters:
//   PreviousStepResult - See NotDeletedItemsLinks
//
// Returns:
//   See NotDeletedItemsLinks
//
Function PreviousStepErrors(PreviousStepResult)
	Result = NotDeletedItemsLinks();

	For Each Item In PreviousStepResult Do
		If IsBlankString(Item.ErrorText) Then
			Continue;
		EndIf;

		PreviousStepError = Result.Add();
		If Not Item.DeletionRequired1 Then
			PreviousStepError.ItemToDeleteRef = Item.ItemToDeleteRef;
			PreviousStepError.Presentation = Item.ErrorText;
			PreviousStepError.FoundItemReference = Item.ErrorText;
		Else
			FillPropertyValues(PreviousStepError, Item);
		EndIf;

		PreviousStepError.IsError = True;
		PreviousStepError.PictureNumber = 11;
	EndDo;

	Return Result;
EndFunction

// Generates the objects to delete from the tree of the marked ones except for those marked for deletion
// on additional processing.
// 
// Parameters:
//   ObjectsToDeleteSource - ValueTree:
//                 * ItemToDeleteRef - AnyRef
// 							  - ValueList of AnyRef
//   ErrorsProcessingResult - See RunDataProcessorOfReasonsForNotDeletion
//
// Returns:
//   Array of AnyRef
//
Function ObjectsToDeleteFromFormData(ObjectsToDeleteSource, ErrorsProcessingResult = Undefined)

	If ErrorsProcessingResult = Undefined Then
		ProhibitedForDeletion = ObjectsToDeleteProcessingResult();
	Else
		ProhibitedForDeletion = ErrorsProcessingResult.Copy(New Structure("DeletionRequired1", False));
	EndIf;

	Result = New Array;
	FoundItems = ObjectsToDeleteSource.Rows.FindRows(New Structure("Check", 1), True);
	For Each TreeRow In FoundItems Do
		If TypeOf(TreeRow.ItemToDeleteRef) <> Type("String") And ProhibitedForDeletion.Find(
			TreeRow.ItemToDeleteRef, "FoundItemReference") = Undefined Then
			Result.Add(TreeRow.ItemToDeleteRef);
		EndIf;
	EndDo;

	Return Result;

EndFunction

Function ObjectsToDeleteFromAdditionalProcessingResult(ErrorsProcessingResult)

	Result = New Array;
	For Each Item In ErrorsProcessingResult.FindRows(New Structure("DeletionRequired1", True)) Do
		Result.Add(Item.ItemToDeleteRef);
	EndDo;
	Return Result;

EndFunction

Function MarkedForDeletionItemsTreeWithoutDeletedItems(MarkedForDeletion, Trash)
	Result = MarkedForDeletion.Copy();
	
	DeletedItems = New Map();
	For Each Item In Trash Do
		DeletedItems.Insert(Item, True);
	EndDo; 
	
	ModifiedParents = New Map;
	ObjectsToDelete = Result.Rows.FindRows(New Structure("Check", 1), True);
	For Each Item In ObjectsToDelete Do
		If Item.Parent <> Undefined And (Item.Technical And Not Item.IsMetadataObjectDetails 
			Or DeletedItems[Item.ItemToDeleteRef] <> Undefined) Then
			ModifiedParents.Insert(Item.Parent);
			DeletedItems.Delete(Item.ItemToDeleteRef);
			Item.Parent.Rows.Delete(Item);
		EndIf;
	EndDo;
	
	For Each DeletedItem In DeletedItems Do
		Item = Result.Rows.Find(DeletedItem.Key, "ItemToDeleteRef", True);
		If Item <> Undefined Then
			ModifiedParents.Insert(Item.Parent);
			Item.Parent.Rows.Delete(Item);
		EndIf;
	EndDo;
	
	For Each ValueParent In ModifiedParents Do
		Parent = ValueParent.Key;
		If Parent.Rows.Count() = 0 Then
			Result.Rows.Delete(Parent);
		ElsIf Parent.Rows.FindRows(New Structure("Check", 1)).Count() = 0 Then
			Parent.Check = 0;
		EndIf;
	EndDo;

	Return Result;
EndFunction

Procedure AddTreeRow(NotDeletedItemsTree, ItemToDeleteRef, TypesInformation, ShouldDeleteTechnologicalObjects)

	TypeInformation = TypesInformation[TypeOf(ItemToDeleteRef)]; // See TypeInformation
	ObjectsToDeleteStrings = NotDeletedItemsTree.Rows.FindRows(New Structure("ItemToDeleteRef", ItemToDeleteRef), True);
	TreeRow = ?(ObjectsToDeleteStrings.Count() = 0, Undefined, ObjectsToDeleteStrings[0]);

	If TreeRow = Undefined And (Not TypeInformation.Technical Or ShouldDeleteTechnologicalObjects) Then
		NotDeletedItemGroup = NotDeletedItemsTree.Rows.FindRows(
			New Structure("ItemToDeleteRef", TypeInformation.FullName));
		NotDeletedItemGroup = ?(NotDeletedItemGroup.Count() = 0, Undefined, NotDeletedItemGroup[0]);

		If NotDeletedItemGroup = Undefined Then
			NotDeletedItemGroup = NotDeletedItemsTree.Rows.Add();
			NotDeletedItemGroup.PictureNumber   = -1;
			NotDeletedItemGroup.ItemToDeleteRef = TypeInformation.FullName;
			NotDeletedItemGroup.Presentation   = TypeInformation.ListPresentation;
		EndIf;

		NotDeletedItemGroup.LinkCount = NotDeletedItemGroup.LinkCount + 1;
		NotDeletedItemGroup.Modified = True;

		TreeRow = NotDeletedItemGroup.Rows.Add();
		TreeRow.ItemToDeleteRef = ItemToDeleteRef;
		TreeRow.Presentation   = String(ItemToDeleteRef);
		TreeRow.PictureNumber = PictureNumber(
			TreeRow.ItemToDeleteRef, True, TypeInformation.Kind, "Removed");
	EndIf;

	If TreeRow <> Undefined Then
		TreeRow.Check = True;
		TreeRow.LinkCount = TreeRow.LinkCount + 1;
	EndIf;

EndProcedure

Procedure AddNotDeletedItemRelationsRow(NotDeletedItemsLinksTable, Cause, TypesInformation,
	Attributes, ShouldDeleteTechnologicalObjects)

	PictureNumber = 0;
	Kind = "";
	FoundStatus = "";

	If Cause.Metadata <> Undefined And Metadata.Constants.Contains(Cause.Metadata) Then
		ObjectType = Type("ConstantValueManager." + Cause.Metadata.Name);
	Else
		ObjectType = TypeOf(Cause.UsageInstance1);
	EndIf;

	TableRow = NotDeletedItemsLinksTable.Add();
	TableRow.ItemToDeleteRef    = Cause.ItemToDeleteRef;
	TableRow.IsError          = ValueIsFilled(Cause.ErrorDescription);
	TableRow.FoundItemReference = ?(TableRow.IsError, Cause.ErrorDescription, Cause.UsageInstance1);

	If TableRow.IsError Or Cause.Metadata = Undefined Then
		TableRow.Presentation = Cause.DetailedErrorDetails;
		TableRow.PictureNumber = 11;
	ElsIf Cause.UsageInstance1 = Undefined Then
		TableRow.FoundItemReference = Cause.Metadata.FullName();
		TableRow.IsConstant = True;
		TableRow.ReferenceType = False;
		TableRow.Presentation = Common.ObjectPresentation(Cause.Metadata) + " (" + NStr(
			"en = 'Constant';") + ")";
		Kind = "CONSTANT";
	Else
		TypeInformation = TypeInformation(ObjectType, TypesInformation);
		If TypeInformation.Kind = "DOCUMENT" Then
			Values = Attributes[Cause.UsageInstance1];
			FoundStatus = ?(Values.DeletionMark, "Removed", ?(Values.Posted, "Posted", ""));
		ElsIf TypeInformation.Referential Then
			Values = Attributes[Cause.UsageInstance1];
			FoundStatus = ?(Values.DeletionMark, "Removed", "");
		EndIf;

		TableRow.ReferenceType = TypeInformation.Referential;
		If Common.IsRegister(Cause.Metadata) Then
			TableRow.Presentation = Common.ObjectPresentation(Cause.Metadata) + " (" + NStr(
				"en = 'Register';") + ")";
		Else
			TableRow.Presentation = String(Cause.UsageInstance1) + " ("
				+ TypeInformation.ItemPresentation + ")";
		EndIf;
		InfoAboutDeletable = TypeInformation(TypeOf(Cause.ItemToDeleteRef), TypesInformation);
		If InfoAboutDeletable.Technical And Not ShouldDeleteTechnologicalObjects Then // Intended for optimization
			TableRow.PresentationItemToDelete = InfoAboutDeletable.ItemPresentation;
		Else
			TableRow.PresentationItemToDelete = String(Cause.ItemToDeleteRef);
		EndIf;

		Kind = TypeInformation.Kind;
	EndIf;

	PictureNumber = TableRow.PictureNumber;
	TableRow.PictureNumber = ?(PictureNumber <> 0, PictureNumber, PictureNumber(TableRow.FoundItemReference,
		TableRow.ReferenceType, Kind, FoundStatus));

EndProcedure

// Parameters:
//  ObjectsToDelete - Array of AnyRef
//  DeletionMode - String 
//  JobID - UUID
//  IsScheduledJob - Boolean
// 
// Returns:
//  Structure:
//   * ObjectsPreventingDeletion - ValueTable:
//      ** ItemToDeleteRef - AnyRef
//      ** UsageInstance1  - AnyRef
//      ** FoundStatus - String
//      ** DetailedErrorDetails - String
//      ** ErrorDescription - String
//   * Trash - Array of AnyRef
//   * NotTrash - Array of AnyRef
//   * Success - Boolean
// 
Function ToDeleteMarkedObjectsInternal(ObjectsToDelete, DeletionMode = "Standard",
	JobID = Undefined, IsScheduledJob = False) Export

	AllowedModes = AllowedDeletionModes();
	If AllowedModes.Find(DeletionMode) = Undefined Then
		ErrorText = NStr("en = 'Invalid value of the %1 parameter in %2.
						   |Expected value: %3.
						   |Actual value: %4 (type: %5).';");

		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, "DeletionMode",
			"ToDeleteMarkedObjects", StrConcat(AllowedModes, Chars.LF + "-"), DeletionMode, TypeOf(
			DeletionMode));
		Raise ErrorText;
	EndIf;

	Result = New Structure("ObjectsPreventingDeletion, Trash, NotTrash, Success");

	DeletionParameters = DataProcessors.MarkedObjectsDeletion.DeletionParameters();
	DeletionParameters.UserObjects = ObjectsToDelete;
	If DeletionMode = "Exclusive" Then
		SetExclusiveModeIfNecessary(True, JobID);
		DeletionParameters.Exclusively = True;
	ElsIf DeletionMode = "Simplified" Then
		DeletionParameters.ClearRefsInUsageInstances = True;
	EndIf;
	DeletionParameters.Mode = DeletionMode;
	DeletionParameters.IsScheduledJob = IsScheduledJob;

	Try
		DeletionResult = DataProcessors.MarkedObjectsDeletion.ToDeleteMarkedObjects(DeletionParameters,
			JobID);
		If CommonClientServer.StructureProperty(DeletionParameters, "Exclusively", False) And ExclusiveMode() Then
			SetExclusiveModeIfNecessary(False, JobID);
		EndIf;
	Except
		If CommonClientServer.StructureProperty(DeletionParameters, "Exclusively", False) Then
			SetExclusiveModeIfNecessary(False, JobID);
		EndIf;
		Raise;
	EndTry;

	FillPropertyValues(Result, DeletionResult);
	Result.Success = Result.NotTrash.Count() = 0;

	Return Result;
EndFunction

#EndRegion

Procedure CopyRows(RowsDestination, StringsSources)
	For Each SourceRow In StringsSources Do
		DestinationRow = RowsDestination.Add();
		FillPropertyValues(DestinationRow, SourceRow);
		CopyRows(DestinationRow.Rows, SourceRow.Rows);
	EndDo;
EndProcedure

Function ExceptionsOfSearchForRefsAllowingDeletionInternal() Export
	Exceptions = New Array;

	Exceptions.Add(Metadata.InformationRegisters.ObjectsToDelete);
	Exceptions.Add(Metadata.InformationRegisters.NotDeletedObjects);
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.OnAddRefsSearchExceptionsThatAllowDeletion(Exceptions);
	EndIf;

	Return Exceptions;
EndFunction

Function IsTechnicalObject(Val FullObjectName)

	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsServer = Common.CommonModule("ReportsServer");
		If ModuleReportsServer.IsTechnicalObject(FullObjectName) Then
			Return True;
		EndIf;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		If ModuleFilesOperationsInternal.IsTechnicalObject(FullObjectName) Then
			Return True;
		EndIf;
	EndIf;

	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeServer = Common.CommonModule("DataExchangeServer");
		If ModuleDataExchangeServer.IsTechnicalObject(FullObjectName) Then
			Return True;
		EndIf;
	EndIf;

	Return FullObjectName = Upper("Catalog.MetadataObjectIDs") Or FullObjectName = Upper(
		"Catalog.ExtensionObjectIDs") Or FullObjectName = Upper("Catalog.ExtensionsVersions");

EndFunction

// Returns the picture index from the collection for displaying in a form
// 
// Parameters:
//   ReferenceOrData - AnyRef
//   ReferenceType - Boolean
//   Kind - String
//   Status - String
//
// Returns:
//   Number - — picture index
//
Function PictureNumber(Val ReferenceOrData, Val ReferenceType, Val Kind, Val Status) Export

	Kind = Upper(Kind);
	If ReferenceType Then
		If Kind = "CATALOG" Or Kind = "CHARTOFCHARACTERISTICTYPES" Then
			PictureNumber = 3;
		ElsIf Kind = "DOCUMENT" Then
			PictureNumber = 12;
		ElsIf Kind = "CHARTOFACCOUNTS" Then
			PictureNumber = 15;
		ElsIf Kind = "CHARTOFCALCULATIONTYPES" Then
			PictureNumber = 17;
		ElsIf Kind = "BUSINESSPROCESS" Then
			PictureNumber = 19;
		ElsIf Kind = "TASK" Then
			PictureNumber = 21;
		ElsIf Kind = "EXCHANGEPLAN" Then
			PictureNumber = 23;
		Else
			PictureNumber = -2;
		EndIf;
		If Status = "Removed" Then
			PictureNumber = PictureNumber + 1;
		ElsIf Status = "Posted" Then
			PictureNumber = PictureNumber + 2;
		EndIf;
	Else
		If Kind = "CONSTANT" Then
			PictureNumber = 25;
		ElsIf Kind = "INFORMATIONREGISTER" Then
			PictureNumber = 26;
		ElsIf Kind = "ACCUMULATIONREGISTER" Then
			PictureNumber = 28;
		ElsIf Kind = "ACCOUNTINGREGISTER" Then
			PictureNumber = 34;
		ElsIf Kind = "CALCULATIONREGISTER" Then
			PictureNumber = 38;
		ElsIf ReferenceOrData = Undefined Then
			PictureNumber = 11;
		Else
			PictureNumber = 8;
		EndIf;
	EndIf;

	Return PictureNumber;
EndFunction

Procedure SetExclusiveModeIfNecessary(ExclusiveModeValue, JobID)
	If ValueIsFilled(JobID) Then
		// Use the form to manage the standalone mode.
		Return;
	EndIf;

	If ExclusiveMode() <> ExclusiveModeValue Then
		SetExclusiveMode(ExclusiveModeValue);
	EndIf;
EndProcedure

Function CheckIfObjectsToDeleteAreUsed()
	IsSaaSModel = Common.DataSeparationEnabled();
	InDataArea = ?(IsSaaSModel, Common.SeparatedDataUsageAvailable(), False);
	If IsSaaSModel And Not InDataArea Then
		Return False;
	EndIf;

	ValueUpdatePeriod = 60000;

	ConstantData = MarkedObjectsDeletionCached.CheckIfObjectsToDeleteAreUsed();
	If CurrentUniversalDateInMilliseconds() - ConstantData.TimeStamp > ValueUpdatePeriod Then
		ConstantData.Value = Constants.CheckIfObjectsToDeleteAreUsed.Get();
		ConstantData.TimeStamp = CurrentUniversalDateInMilliseconds();
	EndIf;

	Return ConstantData.Value;
EndFunction

#Region Constructors

// Returns:
//   ValueTable:
//   * Ref - AnyRef
//   * ErrorText - String
//   * DeletionRequired1 - Boolean
//   * FoundItemReference - AnyRef
//   					  - Undefined
//
Function ObjectsToDeleteProcessingResult()
	StringType = New TypeDescription("String");

	Errors = New ValueTable;
	Errors.Columns.Add("ItemToDeleteRef");
	Errors.Columns.Add("FoundItemReference");
	Errors.Columns.Add("ErrorText", StringType);
	Errors.Columns.Add("DeletionRequired1", New TypeDescription("Boolean"));
	Return Errors
EndFunction

// Parameters:
//   AdditionalAttributesNumber - Number
//
// Returns:
//   ValueTree:
//   * Check - Number
//   * ItemToDeleteRef - AnyRef
//                     - String
//   * Presentation - String
//   * PresentationItemToDelete - String
//   * PictureNumber - Number
//   * HadErrorsOnDelete - Boolean
//   * IsMetadataObjectDetails - Boolean - for conditional appearance.
//   * LinkCount - Number
//   * Count - Number - the amount of items in the metadata object node (for presentation)
//   * Modified - Boolean - the group content was modified
//   * Technical - Boolean - True if the object must not be added to the list.
//   * Attribute1 - Arbitrary - Additional attribute value. 
//                                Support multiple columns: Attribute2, Attribute3, and so on.
//
Function NewTreeOfDeletableObjects(AdditionalAttributesNumber = 0)
	Result = New ValueTree;
	Result.Columns.Add("Check", New TypeDescription("Number", , , New NumberQualifiers(1, 0)));
	Result.Columns.Add("ItemToDeleteRef");
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("PresentationItemToDelete", New TypeDescription("String"));
	Result.Columns.Add("PictureNumber", New TypeDescription("Number"));
	Result.Columns.Add("HadErrorsOnDelete", New TypeDescription("Boolean"));
	Result.Columns.Add("IsMetadataObjectDetails", New TypeDescription("Boolean"));
	Result.Columns.Add("LinkCount", New TypeDescription("Number"));
	Result.Columns.Add("Count", New TypeDescription("Number"));
	Result.Columns.Add("Modified", New TypeDescription("Boolean"));
	Result.Columns.Add("Technical", New TypeDescription("Boolean"));
	Result.Columns.Add("Date", New TypeDescription("Date"));

	For IndexOf = 1 To AdditionalAttributesNumber Do
		Result.Columns.Add("Attribute" + IndexOf);
	EndDo;

	Return Result;
EndFunction

// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef
//   * FoundItemReference - AnyRef
//                        - String
//   * PictureNumber - Number
//   * Presentation - String
//   * ReferenceType - Boolean
//   * IsError - Boolean
//   * IsConstant - Boolean
//   * PresentationItemToDelete - String
//
Function NotDeletedItemsLinks()
	Table = ObjectsPreventingDeletion();

	Table.Columns.Add("PictureNumber", New TypeDescription("Number"));
	Table.Columns.Add("ReferenceType", New TypeDescription("Boolean"));
	Table.Columns.Add("IsError", New TypeDescription("Boolean"));
	Table.Columns.Add("IsConstant", New TypeDescription("Boolean"));

	Table.Indexes.Add("ItemToDeleteRef");

	Return Table;
EndFunction

// Errors upon object deletion.
// 
// Returns:
//   ValueTable:
//   * ItemToDeleteRef - AnyRef - an object to be deleted, the column is being indexed.
//   * FoundItemReference - AnyRef - the object that has references to the object to be deleted.
// 						  - String - — a detailed error description, if an error occurred while deleting an object.
//   * PresentationItemToDelete - String - Presentation of the object being deleted.
//   * Presentation - String - The title of the item or details of the error occurred when deleting an object. 
//
Function ObjectsPreventingDeletion() Export
	Table = New ValueTable;

	Table.Columns.Add("ItemToDeleteRef");
	Table.Columns.Add("FoundItemReference");
	Table.Columns.Add("PresentationItemToDelete", New TypeDescription("String"));
	Table.Columns.Add("Presentation", New TypeDescription("String"));

	Table.Indexes.Add("ItemToDeleteRef");

	Return Table;
EndFunction

Function Value(Source, PropertyName, DefaultValue = Undefined)

	Buffer = New Structure(PropertyName, DefaultValue);
	FillPropertyValues(Buffer, Source);
	Return Buffer[PropertyName];

EndFunction

#EndRegion

#EndRegion