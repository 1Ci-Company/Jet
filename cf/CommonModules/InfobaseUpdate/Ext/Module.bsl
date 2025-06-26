///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for use in update handlers.
//

// Records changes into the passed object.
// To be used in update handlers.
//
// Parameters:
//   Data                            - Arbitrary - an object, record set, or manager of the constant
//                                                      to be written.
//   RegisterOnExchangePlanNodes - Boolean       - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic              - Boolean       - enables business logic when writing the object.
//
Procedure WriteData(Val Data, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False) Export
	
	Data.DataExchange.Load = Not EnableBusinessLogic;
	Data.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	
	If RegisterOnExchangePlanNodes = Undefined
		Or Not RegisterOnExchangePlanNodes Then
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Write();
	
	If TheObjectIsRegisteredOnTheExchangePlan(Data) Then
		MarkProcessingCompletion(Data);
	EndIf;
	
EndProcedure

// Records changes in a passed reference object.
// To be used in update handlers.
//
// Parameters:
//   Object                            - Arbitrary - the reference object to be written. For example, CatalogObject.
//   RegisterOnExchangePlanNodes - Boolean       - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic              - Boolean       - enables business logic when writing the object.
//   Var_DocumentWriteMode               - DocumentWriteMode - valid only for DocumentObject data type - the document
//                                                            write mode.
//											If the parameter is not passed, the document is written in the Write mode.
//
Procedure WriteObject(Val Object, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False, Var_DocumentWriteMode = Undefined) Export
	
	Object.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	Object.DataExchange.Load = Not EnableBusinessLogic;
	
	If RegisterOnExchangePlanNodes = Undefined
		Or Not RegisterOnExchangePlanNodes
		And Not Object.IsNew() Then
		Object.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	If Var_DocumentWriteMode <> Undefined Then
		If TypeOf(Var_DocumentWriteMode) <> Type("DocumentWriteMode") Then
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid type of parameter %1';"),
				"DocumentWriteMode");
			Raise ExceptionText;
		EndIf;
		Object.DataExchange.Load = Object.DataExchange.Load
			And Not Var_DocumentWriteMode = DocumentWriteMode.Posting
			And Not Var_DocumentWriteMode = DocumentWriteMode.UndoPosting;
		Object.Write(Var_DocumentWriteMode);
	Else
		Object.Write();
	EndIf;
	
	If TheObjectIsRegisteredOnTheExchangePlan(Object) Then
		MarkProcessingCompletion(Object);
	EndIf;
	
EndProcedure

// Records changes in the passed data set.
// To be used in update handlers.
//
// Parameters:
//   RecordSet - InformationRegisterRecordSet
//                - AccumulationRegisterRecordSet
//                - AccountingRegisterRecordSet
//                - CalculationRegisterRecordSet - the record set to be written.
//   Replace     - Boolean - defines the record replacement mode in accordance with
//                           the current filter criteria. True - the existing
//                           records are deleted before writing. False - the new records are appended to the existing
//                           records.
//   RegisterOnExchangePlanNodes - Boolean       - enables registration in exchange plan nodes when writing the object.
//   EnableBusinessLogic              - Boolean       - enables business logic when writing the object.
//
Procedure WriteRecordSet(Val RecordSet, Replace = True, Val RegisterOnExchangePlanNodes = Undefined,
	Val EnableBusinessLogic = False) Export
	
	RecordSet.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	RecordSet.DataExchange.Load = Not EnableBusinessLogic;
	
	If RegisterOnExchangePlanNodes = Undefined 
		Or Not RegisterOnExchangePlanNodes Then
		RecordSet.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	RecordSet.Write(Replace);
	
	If TheObjectIsRegisteredOnTheExchangePlan(RecordSet) Then
		MarkProcessingCompletion(RecordSet);
	EndIf;
	
EndProcedure

// Deletes the passed object.
// To be used in update handlers.
//
// Parameters:
//  Data                            - Arbitrary - the object to be deleted.
//  RegisterOnExchangePlanNodes - Boolean       - enables registration in exchange plan nodes when writing the object.
//  EnableBusinessLogic              - Boolean       - enables business logic when writing the object.
//
Procedure DeleteData(Val Data, Val RegisterOnExchangePlanNodes = Undefined, 
	Val EnableBusinessLogic = False) Export
	
	Data.AdditionalProperties.Insert("RegisterAtExchangePlanNodesOnUpdateIB", RegisterOnExchangePlanNodes);
	
	Data.DataExchange.Load = Not EnableBusinessLogic;
	If RegisterOnExchangePlanNodes = Undefined 
		Or Not RegisterOnExchangePlanNodes Then
		Data.DataExchange.Recipients.AutoFill = False;
	EndIf;
	
	Data.Delete();
	
EndProcedure

// Returns a string constant for generating event log messages.
//
// Returns:
//   String - the text of an event in the event log.
//
Function EventLogEvent() Export
	
	Return InfobaseUpdateInternal.EventLogEvent();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions to check object availability when running deferred update.
//

// If
// there are unfinished deferred update handlers
// that process the passed Data object, the procedure throws an exception or locks form to disable editing.
//
// For calls made from the deferred update handler (handler interface check scenario),
// the check does not start unless the DeferredHandlerName parameter is specified. The blank parameter
// means the update order is formed during the update queue generation.
//
// Parameters:
//  Data  - CatalogObject
//          - DocumentObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfAccountsObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - AnyRef
//          - FormDataStructure 
//          - String - A reference, object, record set, or full name of the metadata object
//                       whose processing should be checked.
//  Form  - ClientApplicationForm - if an object is not processed, the ReadOnly property is set
//           for the passed form. If the form is not
//           passed, an exception is thrown.
//
//  DeferredHandlerName - String - unless blank, checks that another deferred handler
//           that makes a call has a smaller queue number than the current deferred number.
//           If the queue number is greater, it throws an exception as it is forbidden to use
//           application interface specified in the InterfaceProcedureName parameter.
//
//  InterfaceProcedureName - String - the application interface name
//           displayed in the exception message shown when checking queue number
//           of the deferred handler specified in the DeferredHandlerName parameter.
//
//  Example:
//   Locking object form in the OnCreateAtServer module handler:
//   InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
//
//   Locking object (a record set) form in the BeforeWrite module handler:
//   InfobaseUpdate.CheckObjectProcessed(ThisObject);
//
//   Check that the object is updated and throw the DigitalSignature.UpdateSignature procedure
//   exception unless the object is not processed by
//   Catalog.DigitalSignatures.ProcessDataForMigrationToNewVersion:
//
//   InfobaseUpdate.CheckObjectProcessed(SignedObject,,
//      "Catalog.DigitalSignatures.ProcessDataForMigrationToNewVersion",
//      "DigitalSignature.UpdateSignature");
//
//   Check and raise an exception if not all objects of the required type are updated:
//   InfobaseUpdate.CheckObjectProcessed("Document.SalesOrder"); 
//
Procedure CheckObjectProcessed(Data, Form = Undefined, DeferredHandlerName = "", InterfaceProcedureName = "") Export
	
	If Not IsCallFromUpdateHandler() Then
		Result = ObjectProcessed(Data);
		If Result.Processed Then
			Return;
		EndIf;
			
		If Form = Undefined Then
			Raise Result.ExceptionText;
		EndIf;
		
		Form.ReadOnly = True;
		If Form.Commands.Find("IBVersionUpdate_ObjectLocked") = Undefined Then
			Form.Commands.Add("IBVersionUpdate_ObjectLocked");
		EndIf;
		Common.MessageToUser(Result.ExceptionText);
		Return;
	EndIf;
	
	If Not ValueIsFilled(DeferredHandlerName) Then
		Return;
	EndIf;
	
	If DeferredHandlerName = SessionParameters.UpdateHandlerParameters.HandlerName Then
		Return;
	EndIf;
	
	RequiredHandlerQueue = DeferredUpdateHandlerQueue(DeferredHandlerName);
	CurrentHandlerQueue = SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue;
	If CurrentHandlerQueue > RequiredHandlerQueue Then
		Return;
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot call %1
		           |from update handler
		           |%2
		           | as its queue number is less than or equal to the queue number of update handler
		           |%3.';"),
		InterfaceProcedureName,
		SessionParameters.UpdateHandlerParameters.HandlerName,
		DeferredHandlerName);
	
EndProcedure

// Check whether there are deferred update handlers
// that are processing the passed Data object.
//
// Parameters:
//  Data  - CatalogObject
//          - DocumentObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfAccountsObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - AnyRef
//          - FormDataStructure 
//          - String - A reference, object, record set, or full name of the metadata object
//                     whose lock should be checked.
//
// Returns:
//   Structure:
//     * Processed       - Boolean - the flag showing whether the object is processed.
//     * ExceptionText - String - the exception text in case the object is not processed.
//                         Contains the list of unfinished handlers.
//
// Example:
//   Check that all objects of the type are updated:
//   AllOrdersProcessed = InfobaseUpdate.ObjectProcessed("Document.SalesOrder"); 
//
Function ObjectProcessed(Data) Export
	
	Result = New Structure;
	Result.Insert("Processed", True);
	Result.Insert("ExceptionText", "");
	Result.Insert("IncompleteHandlersString", "");
	
	If Data = Undefined Then
		Return Result;
	EndIf;
	
	If DeferredUpdateCompleted() Then
		Return Result;
	EndIf;
	
	LockedObjectsInfo = InfobaseUpdateInternal.LockedObjectsInfo();
	
	MetadataAndFilter = Undefined;
	If TypeOf(Data) = Type("String") Then
		FullName = Data;
	Else
		MetadataAndFilter = MetadataAndFilterByData(Data);
		FullName = MetadataAndFilter.Metadata.FullName();
	EndIf;
	
	UnlockedObjects = LockedObjectsInfo.UnlockedObjects;
	AvailableToEdit = UnlockedObjects[FullName];
	If MetadataAndFilter <> Undefined
		And AvailableToEdit <> Undefined
		And AvailableToEdit.Find(MetadataAndFilter.Filter) <> Undefined Then
		Return Result; // The object is unlocked and can be modified.
	EndIf;
	
	BlockUpdate = False;
	MessageText = "";
	InfobaseUpdateOverridable.OnExecuteCheckObjectProcessed(FullName, BlockUpdate, MessageText);
	
	ObjectToCheck = StrReplace(FullName, ".", "");
	
	ObjectHandlers = LockedObjectsInfo.ObjectsToLock[ObjectToCheck];
	If ObjectHandlers = Undefined Then
		Return Result;
	EndIf;
	
	Processed = True;
	IncompleteHandlers = New Array;
	For Each Handler In ObjectHandlers Do
		HandlerProperties = LockedObjectsInfo.Handlers[Handler];
		If HandlerProperties.Completed Then
			Processed = True;
		ElsIf TypeOf(Data) = Type("String") Then
			Processed = False;
		Else
			// ACC:488-off Safe mode is not required.
			Processed = Eval(HandlerProperties.CheckProcedure + "(MetadataAndFilter)");
			// ACC:488-on
		EndIf;
		
		Result.Processed = Processed And Result.Processed;
		
		If Not Processed Then
			IncompleteHandlers.Add(Handler);
		EndIf;
	EndDo;
	
	If IncompleteHandlers.Count() > 0 Then
		
		PartsExceptions = New Array;
		PartsExceptions.Add(NStr("en = 'Operations with this object are temporarily blocked
			|until the scheduled upgrade to a new version is completed.';"));
		PartsExceptions.Add(StrConcat(StrSplit(NStr("en = 'To enable editing, click More actions > Unlock.
			|Do that responsibly, as it might
			|corrupt the document.';"), Chars.LF), " "));
		PartsExceptions.Add(NStr("en = 'The following data processing procedures are not completed';"));
		
		ExceptionText = StrConcat(PartsExceptions, Chars.LF + Chars.LF) + ":";
		
		IncompleteHandlersString = "";
		For Each IncompleteHandler In IncompleteHandlers Do
			IncompleteHandlersString = IncompleteHandlersString + Chars.LF + IncompleteHandler;
		EndDo;
		Result.ExceptionText = ExceptionText + IncompleteHandlersString;
		Result.IncompleteHandlersString = IncompleteHandlersString;
	EndIf;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions intended for deferred update handlers
// whose operation mode is set to "Parallel".
//

// Checking that the passed data is updated.
//
// Parameters:
//  Data - AnyRef
//         - Array
//         - InformationRegisterRecordSet, AccumulationRegisterRecordSet, AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet - the data the changes to be recorded for.
//         - ValueTable - Dimension values of an independent information register. Requirements:
//                              a) all register dimensions are included in the main filter;
//                              b) the table contains only the columns that match the register dimension names
//                                that were previously subject to process request;
//                              c) during the update, the filter applied to the process request is applied
//                                to sets to be recorded;
//                              d) the respective flag value and full register name are passed to AdditionalParameters.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingMarkParameters.
//  Queue - Number
//          - Undefined - the position in a processing queue where the current handler is running. By default, you do not have to
//                           pass the position as its value is obtained from the parameters of the session that runs the update handler.
//
Procedure MarkProcessingCompletion(Data, AdditionalParameters = Undefined, Queue = Undefined) Export
	If Queue = Undefined Then
		If SessionParameters.UpdateHandlerParameters.ExecutionMode <> "Deferred"
			Or SessionParameters.UpdateHandlerParameters.DeferredHandlersExecutionMode <> "Parallel" Then
			Return;
		EndIf;
		Queue = SessionParameters.UpdateHandlerParameters.DeferredProcessingQueue;
	EndIf;
	
	If Not SessionParameters.UpdateHandlerParameters.HasProcessedObjects Then
		NewSessionParameters = InfobaseUpdateInternal.NewUpdateHandlerParameters();
		
		FillPropertyValues(NewSessionParameters, SessionParameters.UpdateHandlerParameters);
		NewSessionParameters.HasProcessedObjects = True;
		
		TransactionID = New UUID;
		RecordManager = InformationRegisters.CommitDataProcessedByHandlers.CreateRecordManager();
		RecordManager.TransactionID = TransactionID;
		RecordManager.Write();
		
		NewSessionParameters.TransactionID = TransactionID;
		
		SessionParameters.UpdateHandlerParameters = New FixedStructure(NewSessionParameters);
	EndIf;
	
	DataCopy = Data;
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If (TypeOf(Data) = Type("Array")
		Or TypeOf(Data) = Type("ValueTable"))
		And Data.Count() = 0 Then
		
		ExceptionText = NStr("en = 'An empty array is passed to procedure %1. Cannot mark the data processing procedure as completed.';");
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "InfobaseUpdate.MarkProcessingCompletion");
		Raise ExceptionText;
		
	EndIf;
	
	Node = QueueRef(Queue);
	
	If AdditionalParameters.IsRegisterRecords Then
		
		DeleteTheRegistrationOfChangesToTheSubordinateRegister(Node, Data, AdditionalParameters.FullRegisterName);
		
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		DeleteRegistrationOfIndependentRegisterChanges(Node, Data, AdditionalParameters.FullRegisterName);
		
	Else
		If TypeOf(Data) = Type("MetadataObject") Then
			ExceptionText = NStr("en = 'Setting ""update processing completed"" flag to an entire metadata object is not supported. This flag can be set to specific data.';");
			Raise ExceptionText;
		EndIf;
		
		If TypeOf(Data) <> Type("Array") Then
			
			ObjectValueType = TypeOf(Data);
			ObjectMetadata  = Metadata.FindByType(ObjectValueType);
			
			If Common.IsInformationRegister(ObjectMetadata)
				And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				Set = Common.ObjectManagerByFullName(ObjectMetadata.FullName()).CreateRecordSet();
				For Each FilterElement In Data.Filter Do
					Set.Filter[FilterElement.Name].Value = FilterElement.Value;
					Set.Filter[FilterElement.Name].Use = FilterElement.Use;
				EndDo;
				SetMissingFiltersInSet(Set, ObjectMetadata, Data.Filter);
			ElsIf (Common.IsRefTypeObject(ObjectMetadata)
					And Not Common.IsReference(ObjectValueType)
					And Data.IsNew())
				Or Common.IsConstant(ObjectMetadata) Then
				Return;
			Else
				Set = Data;
			EndIf;
			
			WriteProgressProgressHandler(Data, Node, ObjectMetadata);
			ExchangePlans.DeleteChangeRecords(Node, Set);
			DataCopy = Set;
		Else
			WriteProgressProgressHandler(Data, Node, ObjectMetadata);
			DeleteRegistrationOfObjectChanges(Node, Data);
		EndIf;
		
	EndIf;
	
	If Not Common.IsSubordinateDIBNode() Then
		InformationRegisters.DataProcessedInMasterDIBNode.MarkProcessingCompletion(Queue, DataCopy, AdditionalParameters); 
	EndIf;
	
EndProcedure

// Additional parameters of functions MarkForProcessing and MarkProcessingCompletion.
// 
// Returns:
//  Structure:
//     * IsRegisterRecords - Boolean - the Data function parameter passed references to recorders that require update.
//                              Default value is False.
//      * FullRegisterName - String - the full name of the register that requires update. For example, AccumulationRegister.ProductStock.
//      * SelectAllRecorders - Boolean - all posted documents passed in
//                                           the type second parameter are selected for processing.
//                                           In this scenario, the Data parameter can pass the following
//                                           MetadataObject: Document or DocumentRef.
//      * IsIndependentInformationRegister - Boolean - the function Data parameter passes table with dimension values
//                                                 to update. The default value is False.
//
Function AdditionalProcessingMarkParameters() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("IsRegisterRecords", False);
	AdditionalParameters.Insert("SelectAllRecorders", False);
	AdditionalParameters.Insert("IsIndependentInformationRegister", False);
	AdditionalParameters.Insert("FullRegisterName", "");
	
	Return AdditionalParameters;
	
EndFunction

// The InfobaseUpdate.MarkForProcessing procedure main parameters
// that are initialized by the change registration mechanism
// and must not be overridden in the code of procedures that mark update handlers for processing.
//
// Returns:
//  Structure:
//     * Queue - Number - the position in the queue for the current handler.
//     * WriteChangesForSubordinateDIBNodeWithFilters - FastInfosetWriter - the parameter
//          is available only when the DataExchange subsystem is embedded.
//     * SelectionParameters - See AdditionalMultithreadProcessingDataSelectionParameters
//
Function MainProcessingMarkParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("Queue", 0);
	Parameters.Insert("HandlerName", "");
	Parameters.Insert("ReRegistration", False);
	Parameters.Insert("SelectionParameters");
	Parameters.Insert("UpToDateData", UpToDateDataSelectionParameters());
	Parameters.Insert("RegisteredRecordersTables", New Map);
	Parameters.Insert("SubsystemVersionAtStartUpdates", Undefined);
	
	If Common.SubsystemExists("StandardSubsystems.DataExchange") Then
		
		Parameters.Insert("NameOfChangedFile", Undefined);
		Parameters.Insert("WriteChangesForSubordinateDIBNodeWithFilters", Undefined);
		
	EndIf;
	
	Return Parameters; 
	
EndFunction

// Returns normalized information on the passed data. 
// Which then is used in data lock check procedures for deferred update handlers.
//
// Parameters:
//  Data  - CatalogObject
//          - DocumentObject
//          - ChartOfCharacteristicTypesObject
//          - ChartOfAccountsObject
//          - ChartOfCalculationTypesObject
//          - InformationRegisterRecordSet
//          - AccumulationRegisterRecordSet
//          - AccountingRegisterRecordSet
//          - CalculationRegisterRecordSet
//          - AnyRef
//          - FormDataStructure - the value of the input Data parameter.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingMarkParameters
// 
// Returns:
//  Structure:
//    * Data - CatalogObject
//             - DocumentObject
//             - ChartOfCharacteristicTypesObject
//             - ChartOfAccountsObject
//             - ChartOfCalculationTypesObject
//             - InformationRegisterRecordSet
//             - AccumulationRegisterRecordSet
//             - AccountingRegisterRecordSet
//             - CalculationRegisterRecordSet
//             - AnyRef
//             - FormDataStructure - the data to be analyzed. 
//    * ObjectMetadata   - MetadataObject - the metadata object that matches the Data parameter.
//    * FullName           - String      - Metadata object's full name. See method "MetadataObject.FullName".
//    * Filter               - AnyRef - if Data is a reference object, it is the reference value. 
//                                            If Data is a recorder subordinate register, it is the recorder filter value.
//			   	              - Structure   - if Data is an independent information register, it is the structure that matches 
//                                            the filters set for the dimensions.
//    * IsNew            - Boolean      - if Data is a reference object, it is a new object flag. 
//                                            For other data types, it is always False.
//	
Function MetadataAndFilterByData(Data, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If AdditionalParameters.IsRegisterRecords Then
		ObjectMetadata = Common.MetadataObjectByFullName(AdditionalParameters.FullRegisterName);		
	Else
		ObjectMetadata = Undefined;
	EndIf;
	
	Filter = Undefined;
	DataType = TypeOf(Data);
	IsNew = False;
	
	If TypeOf(Data) = Type("String") Then
		ObjectMetadata = Common.MetadataObjectByFullName(Data);
	ElsIf DataType = Type("FormDataStructure") Then
		
		If CommonClientServer.HasAttributeOrObjectProperty(Data, "Ref") Then
			
			If ObjectMetadata = Undefined Then
				ObjectMetadata = Data.Ref.Metadata();
			EndIf;
			
			Filter = Data.Ref;
			
			If Not ValueIsFilled(Filter) Then
				IsNew = True;
			EndIf;
			
		ElsIf CommonClientServer.HasAttributeOrObjectProperty(Data, "SourceRecordKey") Then	

			If ObjectMetadata = Undefined Then
				ObjectMetadata = Metadata.FindByType(TypeOf(Data.SourceRecordKey)); // MetadataObjectInformationRegister 
			EndIf;
			Filter = New Structure;
			For Each Dimension In ObjectMetadata.Dimensions Do
				Filter.Insert(Dimension.Name, Data[Dimension.Name]);
			EndDo;
			
		Else
			ExceptionText = NStr("en = 'Cannot use procedure %1 in this form.';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "InfobaseUpdate.MetadataAndFilterByData");
		EndIf;
		
	Else
		
		If ObjectMetadata = Undefined Then
			ObjectMetadata = Data.Metadata();
		EndIf;
		
		If Common.IsRefTypeObject(ObjectMetadata) Then
			
			If Common.IsReference(DataType) Then
				Filter = Data;
			Else
				Filter = Data.Ref;
				
				If Data.IsNew() Then
					IsNew = True;
				EndIf;
			
			EndIf;
			
		ElsIf Common.IsInformationRegister(ObjectMetadata)
			And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			Filter = New Structure;
			For Each FilterElement In Data.Filter Do
				If FilterElement.Use Then 
					Filter.Insert(FilterElement.Name, FilterElement.Value);
				EndIf;
			EndDo;
			
		ElsIf Common.IsRegister(ObjectMetadata) Then
			If AdditionalParameters.IsRegisterRecords Then
				Filter = Data;
			Else
				Filter = Data.Filter.Recorder.Value;
			EndIf;
		Else
			ExceptionText = NStr("en = 'Function %1 does not support analysis of this metadata type.';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "InfobaseUpdate.MetadataAndFilterByData");
			Raise ExceptionText;
		EndIf;
		
	EndIf;
	
	Result = New Structure;
	Result.Insert("Data", Data);
	Result.Insert("Metadata", ObjectMetadata);
	Result.Insert("FullName", ObjectMetadata.FullName());
	Result.Insert("Filter", Filter);
	Result.Insert("IsNew", IsNew);
	
	Return Result;
EndFunction

// Mark passed objects for update.
// Note. It is not recommended that you pass to the Data parameter all the data
// to update at once as big collections of Arrays
// or ValueTable type might take a significant amount of space on the server and affect
// its performance. It is recommended that you transfer
// data by batches about 1000 objects at a time.
//
// Parameters:
//  MainParameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Data            - AnyRef
//                    - Array
//                    - InformationRegisterRecordSet, AccumulationRegisterRecordSet, AccountingRegisterRecordSet
//                    - CalculationRegisterRecordSet - the data the changes to be recorded for.
//                    - ValueTable - Dimension values of an independent information register. Requirements:
//                        a) no dimensions with the "Node" name;
//                        b) all register dimensions are included in the main filter;
//                        c) the table contains only the columns that match the register dimension names
//                          that are subject to process request;
//                        d) during the update, the filter applied to the process request is applied
//                          to sets to be recorded;
//                        e) the respective flag value and full register name are passed to AdditionalParameters.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingMarkParameters.
// 
Procedure MarkForProcessing(MainParameters, Data, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingMarkParameters();
	EndIf;
	
	If (TypeOf(Data) = Type("Array")
		Or TypeOf(Data) = Type("ValueTable"))
		And Data.Count() = 0 Then
		Return;
	EndIf;
	
	If MainParameters.Property("SelectionParameters")
		And TypeOf(MainParameters.SelectionParameters) = Type("Structure") Then
		FullNamesOfObjects  = Undefined;
		FullRegistersNames = Undefined;
		MainParameters.SelectionParameters.Property("FullNamesOfObjects", FullNamesOfObjects);
		MainParameters.SelectionParameters.Property("FullRegistersNames", FullRegistersNames);
		
		NamesArray = StrSplit(FullNamesOfObjects, ",", False);
		CommonClientServer.SupplementArray(NamesArray, StrSplit(FullRegistersNames, ",", False));
		
		NonExistent = New Array;
		For Each FullObjectName In NamesArray Do
			FullObjectName = TrimAll(FullObjectName);
			ObjectExist = (Common.MetadataObjectByFullName(FullObjectName) <> Undefined);
			If Not ObjectExist Then
				NonExistent.Add(FullObjectName);
			EndIf;
		EndDo;
		
		If NonExistent.Count() <> 0 Then
			ExceptionText = NStr("en = 'Non-existing objects are specified in the %1 property of the deferred handler data population procedures:
				|%2.';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText,
				"SelectionParameters", StrConcat(NonExistent, ", "));
			Raise ExceptionText;
		EndIf;
		
	EndIf;
	
	If MainParameters.Property("UpdateRestart")
		And MainParameters.UpdateRestart = True Then
		Node = QueueRef(MainParameters.Queue, True);
	Else
		Node = QueueRef(MainParameters.Queue);
	EndIf;
	
	If AdditionalParameters.IsRegisterRecords Then
		
		FullRegisterName = AdditionalParameters.FullRegisterName;
		
		If AdditionalParameters.SelectAllRecorders Then
			
			If TypeOf(Data) = Type("MetadataObject") Then
				MetadataOfDocument = Data;
			ElsIf Common.IsReference(TypeOf(Data)) Then
				MetadataOfDocument = Data.Metadata();
			Else
				ExceptionText = NStr("en = 'To register all register recorders, in the Data parameter, pass the metadata object ""Document"" or ""DocumentRef"".';");
				Raise ExceptionText;
			EndIf;
			FullDocumentName = MetadataOfDocument.FullName();
			
			QueryText =
			"SELECT
			|	DocumentTable.Ref AS Ref
			|FROM
			|	#DocumentTable AS DocumentTable
			|WHERE
			|	DocumentTable.Posted";
			
			QueryText = StrReplace(QueryText, "#DocumentTable", FullDocumentName);
			Query = New Query;
			Query.Text = QueryText;
			
			Recorders = Query.Execute().Unload().UnloadColumn("Ref");
			
		Else
			Recorders = Data;
			
			// Save the list of tables for which the registration was performed.
			For Each Recorder In Recorders Do
				TableType = TypeOf(Recorder);
				If Recorder.IsEmpty() Then
					Continue;
				EndIf;
				
				If MainParameters.RegisteredRecordersTables[TableType] = Undefined Then
					FullTableName = Recorder.Metadata().FullName();
					MainParameters.RegisteredRecordersTables.Insert(TableType, FullTableName);
				EndIf;
			EndDo;
		EndIf;
		
		RegisterChangesToTheSubordinateRegister(MainParameters,
			Node,
			Recorders,
			"SubordinateRegister",
			FullRegisterName);
		
	ElsIf AdditionalParameters.IsIndependentInformationRegister Then
		
		RegisterChangesToTheIndependentRegister(MainParameters,
			Node,
			Data,
			"IndependentRegister",
			AdditionalParameters.FullRegisterName);
		
	Else
		If TypeOf(Data) = Type("Array") Or Common.IsReference(TypeOf(Data)) Then
			RegisterObjectChanges(MainParameters, Node, Data, "Ref");
		Else
			If TypeOf(Data) = Type("MetadataObject") Then
				ExceptionText = NStr("en = 'Registration of an entire metadata object for update is not supported. Please update specific data.';");
				Raise ExceptionText;
			EndIf;
			
			ObjectMetadata = Metadata.FindByType(TypeOf(Data));
			
			If Common.IsInformationRegister(ObjectMetadata)
				And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
				
				SetMissingFiltersInSet(Data, ObjectMetadata, Data.Filter);
				
			EndIf;
			RecordChanges(MainParameters, Node, Data, "IndependentRegister", ObjectMetadata.FullName());
		EndIf;
	EndIf;
	
EndProcedure

// Register passed recorders as the ones that require record update.
// 
// Parameters:
//  Parameters         - See InfobaseUpdate.MainProcessingMarkParameters.
//  Recorders      - Array - a recorder ref array.
//  FullRegisterName - String - the full name of a register that requires update.
//
Procedure MarkRecordersForProcessing(Parameters, Recorders, FullRegisterName) Export
	
	AdditionalParameters = AdditionalProcessingMarkParameters();
	AdditionalParameters.IsRegisterRecords = True;
	AdditionalParameters.FullRegisterName = FullRegisterName;
	MarkForProcessing(Parameters, Recorders, AdditionalParameters);
	
EndProcedure

// Additional parameters for the data selected for processing.
// 
// Returns:
//  Structure:
//   * SelectInBatches - Boolean - select data to process in chunks.
//                        If documents are selected, the data chunks are formed considering the document sorting
//                        (from newest to latest). If register recorders are selected and the full document name has been passed, the data chunks are formed
//                        considering the recorder sorting (from newest to latest).
//                        If the full document name has not been passed, the data chunks are formed considering the register sorting:
//                        a) Get maximum date for each recorder;
//                        b) If a register has no records, it goes on top.
//   * TempTableName - String - the parameter is valid for methods that create temporary tables. If the name is not specified
//                           (the default scenario), the temporary table is created with the name specified
//                           in the method description.
//   * AdditionalDataSources - Map of KeyAndValue - Intended for methods that select recorders and references for processing.
//                                     The map keys can contain one of the following data kinds:
//                                     1. Paths to document header attributes or tabular sections attributes that:
//                                     are connected with other tables (including implicit connections when
//                                        addressing "separated by dot").
//                                        2. Names of reference metadata objects (String) that contain
//                                     a map in their values where the key is a register name (String), and in the map
//                                        value in the keys of which is the same as in the cl. 1, that means,
//                                        map hierarchy "Object" -> "Register" -> "Sources".
//                                        Procedures check data lock for these tables by the handlers with lowest positions
//                                     in the queue. Source name format: <AttributeName> or
//                                     <TabularSectionName>.<TabularSectionAttributeName>. 
//                                     For a seamless population,
//                                     See SetDataSource
//                                                                     .
//   * OrderFields  - Array - the name of independent information register fields used to organize
//                                    a query result.
//   * MaxSelection - Number - the maximum number of selecting records.
//   * NameOfTheDimensionToSelect - String - a name of the independent information register dimension to which set records are subordinate,
//                                      (a substitute of a recorder for registers subordinate to recorders).
//
Function AdditionalProcessingDataSelectionParameters() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("SelectInBatches", True);
	AdditionalParameters.Insert("TempTableName", "");
	AdditionalParameters.Insert("AdditionalDataSources", New Map);
	AdditionalParameters.Insert("OrderFields", New Array);
	AdditionalParameters.Insert("MaxSelection", MaxRecordsCountInSelection());
	AdditionalParameters.Insert("NameOfTheDimensionToSelect", "Recorder");
	
	Return AdditionalParameters;
	
EndFunction

// Parameters used for selecting handler's up-to-date data when running an update.
// Intended for handlers with regular order.
// The filtered-out data will be processed by non-critical update handlers.
// 
// Returns:
//   Structure:
//      * FilterField   - String - The comparison attribute.
//      * ComparisonType - ComparisonType - Valid values are "Greater", "Less", "Equal",
//                                      "GreaterOrEqual", "LessOrEqual".
//      * Value     - Arbitrary - The comparison value.
//
Function UpToDateDataSelectionParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("FilterField");
	Parameters.Insert("ComparisonType");
	Parameters.Insert("Value");
	
	Return Parameters;
	
EndFunction

// Additional parameters for the data selected for multithread processing.
//
// Returns:
//  Structure - Fields from "AdditionalProcessingDataSelectionParameters" supplemented the following fields:
//   * FullNamesOfObjects - String - full names of updated objects (for example, documents) separated by commas.
//   * FullRegistersNames - String - full registers names separated by commas.
//   * OrderingFieldsOnUserOperations - Array - ordering fields that are used when updating
//                                                with user operations priority.
//   * OrderingFieldsOnProcessData - Array - ordering fields that are used when updating
//                                            with data processing priority.
//   * SelectionMethod - String - one of the selection method:
//                              InfobaseUpdate.IndependentInfoRegistryMeasurementsSelectionMethod(),
//                              InfobaseUpdate.RegistryRecordersSelectionMethod(),
//                              InfobaseUpdate.RefsSelectionMethod().
//   * LastSelectedRecord - ValueList - end of the previous selection (internal field).
//   * FirstRecord - ValueList - selection start (internal field).
//   * LatestRecord - ValueList - end of the previous selection (internal field).
//   * OptimizeSelectionByPages - Boolean - if True, the selection is executed without OR, the False value can
//                                        be useful if the original request is not optimal, then it will be faster with OR.
//
Function AdditionalMultithreadProcessingDataSelectionParameters() Export
	
	AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	AdditionalParameters.Insert("FullNamesOfObjects");
	AdditionalParameters.Insert("FullRegistersNames");
	AdditionalParameters.Insert("OrderingFieldsOnUserOperations", New Array);
	AdditionalParameters.Insert("OrderingFieldsOnProcessData", New Array);
	AdditionalParameters.Insert("SelectionMethod");
	AdditionalParameters.Insert("LastSelectedRecord");
	AdditionalParameters.Insert("FirstRecord");
	AdditionalParameters.Insert("LatestRecord");
	AdditionalParameters.Insert("OptimizeSelectionByPages", True);
	
	Return AdditionalParameters;
	
EndFunction

// Set the AdditionalDataSources parameter in the structure returned by the function
// AdditionalProcessingDataSelectionParameters().
//
// It is used when the data sources must be set by documents and registers.
// Applied by multithread updating.
//
// Parameters:
//  AdditionalDataSources - See AdditionalProcessingDataSelectionParameters
//  Source - See AdditionalProcessingDataSelectionParameters
//  Object - String - document name (full or short).
//  Register - String - register name (full or short).
//
Procedure SetDataSource(AdditionalDataSources, Source, Object = "", Register = "") Export
	
	ObjectName = MetadataObjectName(Object);
	RegisterName = MetadataObjectName(Register);
	
	If IsBlankString(ObjectName) And IsBlankString(RegisterName) Then
		AdditionalDataSources.Insert(Source);
	Else
		ObjectRegister = AdditionalDataSources[ObjectName];
		
		If ObjectRegister = Undefined Then
			ObjectRegister = New Map;
			AdditionalDataSources[ObjectName] = ObjectRegister;
		EndIf;
		
		DataSources = ObjectRegister[RegisterName];
		
		If DataSources = Undefined Then
			DataSources = New Map;
			ObjectRegister[RegisterName] = DataSources;
		EndIf;
		
		DataSources.Insert(Source);
	EndIf;
	
EndProcedure

// Get the AdditionalDataSources parameter value from the structure returned by
// the AdditionalProcessingDataSelectionParameters() function.
//
// It can be used when the data sources need to be retrieved by document or register.
// Applied for multithreaded updates.
//
// Parameters:
//  AdditionalDataSources - See AdditionalProcessingDataSelectionParameters
//  Object - String - Document name (full or short).
//  Register - String - Register name (full or short).
//
// Returns:
//  Map - Data sources for the specified document and register.
//
Function DataSources(AdditionalDataSources, Object = "", Register = "") Export
	
	If IsSimpleDataSource(AdditionalDataSources) Then
		Return AdditionalDataSources;
	Else
		ObjectName = MetadataObjectName(Object);
		RegisterName = MetadataObjectName(Register);
		ObjectRegister = AdditionalDataSources[ObjectName];
		MapType = Type("Map");
		
		If TypeOf(ObjectRegister) = MapType Then
			DataSources = ObjectRegister[RegisterName];
			
			If TypeOf(DataSources) = MapType Then
				Return DataSources;
			EndIf;
		EndIf;
		
		Return New Map;
	EndIf;
	
EndFunction

// Creates temporary reference table that are not processed in the current queue
// and not locked by the lesser priority queues.
// Table name: TemporaryTableToProcess<RegisterName>, For example, TemporaryTableToProcessStock.
// Table columns:
//   Recorder - DocumentRef.
//
// Parameters:
//  Queue					 - Number  - the position in the queue for the current handler.
//  FullDocumentName		 - String - the name of the document that requires record update. 
//                             If the records are not based on the document data, the passed value is Undefined. 
//                             In this case, the document table is not checked for lock.
//                             For example, "Document.GoodsReceipt".
//  FullRegisterName	 - String	 - the name of the register that requires record update.
//  	                   For example, "AccumulationRegister.ProductStock".
//  TempTablesManager	 - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters	 - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - The result of the temporary table generation:
//   * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. 
//                                             There are two reasons records can be missing:
//                                             all references have been processed or the references to be processed are locked by 
//                                             the lower-priority handlers.
//   * HasDataToProcess - Boolean - the queue contains references to process.
//   * TempTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfRegisterRecordersToProcess(Queue, FullDocumentName, FullRegisterName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	RegisterName = StrSplit(FullRegisterName,".",False)[1];
	
	CurrentQueue = QueueRef(Queue);
	
	If FullDocumentName = Undefined Then 
		If AdditionalParameters.SelectInBatches Then
			QueryText =
			"SELECT TOP 1000
			|	RegisterTableChanges.Recorder AS Recorder,
			|	MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1))) AS Period
			|INTO #TTToProcessRecorder
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		LEFT JOIN #RegisterRecordsTable AS RegisterTable
			|		ON RegisterTableChanges.Recorder = RegisterTable.Recorder
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND NOT TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			TTLockedRecorder AS TTLockedRecorder
			|		WHERE
			|			RegisterTableChanges.Recorder = TTLockedRecorder.Recorder)
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|GROUP BY
			|	RegisterTableChanges.Recorder
			|
			|ORDER BY
			|	MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1)))
			|
			|INDEX BY
			|	Recorder
			|
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder"; // @query-part
			
			QueryText = StrReplace(QueryText,"#RegisterRecordsTable", FullRegisterName);	
		Else
			QueryText =
			"SELECT
			|	RegisterTableChanges.Recorder AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND NOT TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			TTLockedRecorder AS TTLockedRecorder
			|		WHERE
			|			RegisterTableChanges.Recorder = TTLockedRecorder.Recorder)
			|	AND &ConditionByAdditionalSourcesRegisters
			|
			|INDEX BY
			|	Recorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder";
		EndIf;
	Else
		FragmentsOfTheQuery = New Array;
		QueryFragment =
			"SELECT TOP 1000
			|	DocumentTable.Ref AS Recorder
			|INTO #TTToProcessRecorder
			|FROM
			|	#RegisterTableChanges AS RegisterTableChanges
			|		INNER JOIN #FullDocumentName AS DocumentTable
			|		ON RegisterTableChanges.Recorder = DocumentTable.Ref
			|WHERE
			|	RegisterTableChanges.Node = &CurrentQueue
			|	AND NOT TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			TTLockedRecorder AS TTLockedRecorder
			|		WHERE
			|			DocumentTable.Ref = TTLockedRecorder.Recorder)
			|	AND NOT TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			TTLockedReference AS TTLockedReference
			|		WHERE
			|			DocumentTable.Ref = TTLockedReference.Ref)
			|	AND &ConditionByAdditionalSourcesRefs
			|	AND &ConditionByAdditionalSourcesRegisters";
		FragmentsOfTheQuery.Add(QueryFragment);
		
		If AdditionalParameters.SelectInBatches Then
			QueryFragment =
				"
				|ORDER BY
				|	DocumentTable.Date DESC";
			FragmentsOfTheQuery.Add(QueryFragment);
		EndIf;
		
		QueryFragment =
			"
			|INDEX BY
			|	Recorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedRecorder
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TTLockedReference";
		FragmentsOfTheQuery.Add(QueryFragment);
		QueryText = StrConcat(FragmentsOfTheQuery, Chars.LF);
		
		AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
		AdditionalParametersForTTCreation.TempTableName = "TTLockedReference";
		CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullDocumentName, TempTablesManager, AdditionalParametersForTTCreation);
	EndIf;
	
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName = "TTToProcess" + RegisterName;
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#RegisterTableChanges", FullRegisterName + ".Changes");	
	QueryText = StrReplace(QueryText, "#TTToProcessRecorder", TempTableName);
	
	AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
	AdditionalParametersForTTCreation.TempTableName = "TTLockedRecorder";
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullRegisterName, TempTablesManager, AdditionalParametersForTTCreation);
	
	AddAdditionalSourceLockCheck(Queue, QueryText, FullDocumentName, FullRegisterName, TempTablesManager, True, AdditionalParameters);
	
	QueryText = StrReplace(QueryText, "#FullDocumentName", FullDocumentName);
		
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TempTableName", False, False, "");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(Queue, FullRegisterName);
	EndIf;	
	
	Return Result; 
	
EndFunction

// Returns a chunk of recorders that require record update.
//  The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//  Lock by other queues includes documents and registers.
//  If the full document name has been passed, the selected recorders are sorted by date (from newest to latest).
//  If the full document name has not been passed, the data chunks are formed considering the register sorting:
//				- Get maximum date for each recorder;
//				- If a register has no records, it goes on top.
// Parameters:
//  Queue					 - Number - the position in the queue the handler and the data it will process are assigned to.
//  FullDocumentName		 - String - the name of the document that requires record update. If the records are not based on the document
//									data, the passed value is Undefined. In this case, the document table is not checked for lock.
//									For example, Document.GoodsReceipt.
//  FullRegisterName		 - String	 - the name of the register that requires record update.
//  	For example, AccumulationRegister.ProductStock.
//  AdditionalParameters	 - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//   QueryResultSelection - A set of recorders to be processed. Set fields are:
//     * Recorder - DocumentRef
//     * Period - Date - if the full document name is passed, the date of the document.
//                       Otherwise, the maximum period of the recorder.
//     * Posted - Boolean
//                - Undefined - the Posted attribute value of the document if the full document name is passed,
//                                 or Undefined if the document name is not passed.
//   ValueTable - data that must be processed, column names match the register dimension names.
//
Function SelectRegisterRecordersToProcess(Queue, FullDocumentName, FullRegisterName, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	UpdateHandlerParameters = Undefined;
	AdditionalParameters.Property("UpdateHandlerParameters", UpdateHandlerParameters);
	
	TempTablesManager = New TempTablesManager();
	CheckSelectionParameters(AdditionalParameters);
	BuildParameters = SelectionBuildParameters(AdditionalParameters);
	
	HasSelectionFilter = False;
	If FullDocumentName = Undefined Then
		QueryText =
		"SELECT TOP 1000
		|	&SelectedFields
		|FROM
		|	#RegisterTableChanges AS RegisterTableChanges
		|		LEFT JOIN #RegisterRecordsTable AS RegisterTable
		|		ON RegisterTableChanges.Recorder = RegisterTable.Recorder
		|WHERE
		|	RegisterTableChanges.Node = &CurrentQueue
		|	AND NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			TTLockedRecorder AS TTLockedRecorder
		|		WHERE
		|			RegisterTableChanges.Recorder = TTLockedRecorder.Recorder)
		|	AND &ConditionByAdditionalSourcesRegisters
		|
		|GROUP BY
		|	RegisterTableChanges.Recorder";
		
		If BuildParameters.SelectionByPage Then
			QueryText = QueryText + "
				|
				|HAVING
				|	&PagesCondition"
		EndIf;
		
		QueryText = QueryText + "
			|
			|ORDER BY
			|	&SelectionOrder";
		QueryText = StrReplace(QueryText, "#RegisterRecordsTable", FullRegisterName);
		SetRegisterOrderingFields(BuildParameters);
	Else
		QueryText =
		"SELECT TOP 1000
		|	&SelectedFields
		|FROM
		|	#RegisterTableChanges AS RegisterTableChanges
		|		INNER JOIN #FullDocumentName AS DocumentTable
		|		ON RegisterTableChanges.Recorder = DocumentTable.Ref
		|
		|WHERE
		|	RegisterTableChanges.Node = &CurrentQueue
		|	AND NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			TTLockedRecorder AS TTLockedRecorder
		|		WHERE
		|			RegisterTableChanges.Recorder = TTLockedRecorder.Recorder)
		|	AND NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			TTLockedReference AS TTLockedReference
		|		WHERE
		|			RegisterTableChanges.Recorder = TTLockedReference.Ref)
		|	AND &ConditionByAdditionalSourcesRefs
		|	AND &ConditionByAdditionalSourcesRegisters
		|	AND &PagesCondition
		|	AND &ConditionUpToDateData
		|
		|ORDER BY
		|	&SelectionOrder";
		AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
		AdditionalParametersForTTCreation.TempTableName = "TTLockedReference";
		CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullDocumentName, TempTablesManager, AdditionalParametersForTTCreation);
		SetRegisterOrderingFieldsByDocument(BuildParameters);
		
		FilterOfUpToDateData = InfobaseUpdateInternal.FilterOfUpToDateData(UpdateHandlerParameters, "DocumentTable");
		QueryText = StrReplace(QueryText, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
		
		If FilterOfUpToDateData.HasSelectionFilter Then
			HasSelectionFilter = True;
			QueryTextChecks =
				"SELECT TOP 1
				|	TRUE
				|FROM
				|	#RegisterTableChanges AS RegisterTableChanges
				|		INNER JOIN #FullDocumentName AS DocumentTable
				|		ON RegisterTableChanges.Recorder = DocumentTable.Ref
				|WHERE
				|	RegisterTableChanges.Node = &CurrentQueue
				|	AND &ConditionUpToDateData";
			QueryTextChecks = StrReplace(QueryTextChecks, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
			QueryTextChecks = StrReplace(QueryTextChecks,"#RegisterTableChanges", FullRegisterName + ".Changes");
			QueryTextChecks = StrReplace(QueryTextChecks,"#FullDocumentName", FullDocumentName);
			
			VerificationRequest = New Query;
			VerificationRequest.SetParameter("CurrentQueue", QueueRef(Queue));
			VerificationRequest.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
			VerificationRequest.Text = QueryTextChecks;
			
			IsAllUpToDateDataProcessed = VerificationRequest.Execute().IsEmpty();
			SetHandlerParametersOnSelectData(AdditionalParameters, IsAllUpToDateDataProcessed, UpdateHandlerParameters, FullDocumentName);
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#RegisterTableChanges", FullRegisterName + ".Changes");	
	
	AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
	AdditionalParametersForTTCreation.TempTableName = "TTLockedRecorder";
	NameOfTheDimensionToSelect = AdditionalParameters.NameOfTheDimensionToSelect;
	
	If Upper(NameOfTheDimensionToSelect) <> Upper("Recorder") Then
		AdditionalParametersForTTCreation.NameOfTheDimensionToSelect = NameOfTheDimensionToSelect;
		Dimension = StringFunctionsClientServer.SubstituteParametersToString(".%1", NameOfTheDimensionToSelect);
		QueryText = StrReplace(QueryText, ".Recorder", Dimension);
	EndIf;
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullRegisterName, TempTablesManager, AdditionalParametersForTTCreation);
	SetSelectionSize(QueryText, AdditionalParameters);
	AddAdditionalSourceLockCheck(Queue, QueryText, FullDocumentName, FullRegisterName, TempTablesManager, False, AdditionalParameters);
	
	QueryText = StrReplace(QueryText, "#FullDocumentName", FullDocumentName);
		
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", QueueRef(Queue));
	If HasSelectionFilter Then
		Query.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
	EndIf;
	
	SetFieldsByPages(Query, BuildParameters);
	SetOrderByPages(Query, BuildParameters);
	
	Return SelectDataToProcess(Query, BuildParameters);
	
EndFunction

// Returns a chunk of references that require processing.
//  The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//	The returned document references are sorted by date (from newest to latest).
//
// Parameters:
//  Queue				 - Number - the position in the queue the handler and the data it will
//									process are assigned to.
//  FullObjectName	 - String	 - the name of the object that require processing. For example, Document.GoodsReceipt.
//  AdditionalParameters	 - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//   QueryResultSelection - A set of references to be processed. Set fields are:
//     * Ref - AnyRef
//   ValueTable - data that must be processed, column names map the register dimension names.
//
Function SelectRefsToProcess(Queue, FullObjectName, AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	UpdateHandlerParameters = Undefined;
	AdditionalParameters.Property("UpdateHandlerParameters", UpdateHandlerParameters);
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName);
	IsDocument = Common.IsDocument(ObjectMetadata)
				Or Common.IsTask(ObjectMetadata);
	
	CheckSelectionParameters(AdditionalParameters);
	BuildParameters = SelectionBuildParameters(AdditionalParameters);
	
	QueryText =
	"SELECT TOP 1000
	|	&SelectedFields
	|FROM
	|	#ObjectTableChanges AS ChangesTable
	|		INNER JOIN #ObjectTable AS ObjectTable
	|		ON ChangesTable.Ref = ObjectTable.Ref
	|WHERE
	|	ChangesTable.Node = &CurrentQueue
	|	AND NOT TRUE IN (
	|		SELECT TOP 1
	|			TRUE
	|		FROM
	|			#TTLockedReference AS TTLockedReference
	|		WHERE
	|			ChangesTable.Ref = TTLockedReference.Ref)
	|	AND &ConditionByAdditionalSourcesRefs
	|	AND &ConditionByAdditionalSourcesRegisters
	|	AND &PagesCondition
	|	AND &ConditionUpToDateData";
	If IsDocument Or BuildParameters.SelectionByPage Then
		QueryText = QueryText + "
		|
		|ORDER BY
		|	&SelectionOrder";
	EndIf;
	
	FilterOfUpToDateData = InfobaseUpdateInternal.FilterOfUpToDateData(UpdateHandlerParameters, "ObjectTable");
	QueryText = StrReplace(QueryText, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
	If FilterOfUpToDateData.HasSelectionFilter Then
		QueryTextChecks =
			"SELECT TOP 1
			|	TRUE
			|FROM
			|	#ObjectTableChanges AS ChangesTable
			|		INNER JOIN #ObjectTable AS ObjectTable
			|		ON ChangesTable.Ref = ObjectTable.Ref
			|WHERE
			|	ChangesTable.Node = &CurrentQueue
			|	AND &ConditionUpToDateData";
		QueryTextChecks = StrReplace(QueryTextChecks, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
		QueryTextChecks = StrReplace(QueryTextChecks,"#ObjectTableChanges", FullObjectName + ".Changes");
		QueryTextChecks = StrReplace(QueryTextChecks,"#ObjectTable", FullObjectName);
		
		VerificationRequest = New Query;
		VerificationRequest.SetParameter("CurrentQueue", QueueRef(Queue));
		VerificationRequest.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
		VerificationRequest.Text = QueryTextChecks;
		
		IsAllUpToDateDataProcessed = VerificationRequest.Execute().IsEmpty();
		
		SetHandlerParametersOnSelectData(AdditionalParameters, IsAllUpToDateDataProcessed, UpdateHandlerParameters)
	EndIf;
	
	QueryText = QueryText + "
	|;
	|DROP
	|	#TTLockedReference"; 
	SetRefsOrderingFields(BuildParameters, IsDocument);
	QueryText = StrReplace(QueryText, "#TTLockedReference","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");
	QueryText = StrReplace(QueryText,"#ObjectTable", FullObjectName);
	SetSelectionSize(QueryText, AdditionalParameters);
	TempTablesManager = New TempTablesManager();
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheck(Queue, QueryText, FullObjectName, Undefined, TempTablesManager, False, AdditionalParameters);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", QueueRef(Queue));
	If FilterOfUpToDateData.HasSelectionFilter Then
		Query.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
	EndIf;
	
	SetFieldsByPages(Query, BuildParameters);
	If IsDocument Or BuildParameters.SelectionByPage Then
		SetOrderByPages(Query, BuildParameters);
	EndIf;
	
	Return SelectDataToProcess(Query, BuildParameters);
	
EndFunction

// Creates temporary reference table that are not processed in the current queue
//  and not locked by the lesser priority queues.
//  Table name: TemporaryTableForProcessing<ObjectName>, for instance, TemporaryTableForProcessingProducts.
//  Table columns:
//   Ref - AnyRef.
//
// Parameters:
//  Queue           - Number  - the position in the queue for the current handler.
//  FullObjectName  - String - full name of an object, for which the check is run (for instance, Catalog.Products).
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - The result of the temporary table generation:
//   * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. There are
//                                            two reasons records can be missing:
//                                             all references have been processed or the references to be processed are locked by
//                                             the lower-priority handlers.
//   * HasDataToProcess - Boolean - the queue contains references to process.
//   * TempTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfRefsToProcess(Queue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName);
	FragmentsOfTheQuery = New Array;
	
	QueryFragment =
		"SELECT TOP 1000
		|	ObjectTable.Ref AS Ref
		|INTO #TTToProcessRef
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|		INNER JOIN #ObjectTable AS ObjectTable
		|		ON ChangesTable.Ref = ObjectTable.Ref
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			#TTLockedReference AS TTLockedReference
		|		WHERE
		|			ObjectTable.Ref = TTLockedReference.Ref)
		|	AND &ConditionByAdditionalSourcesRefs
		|	AND &ConditionByAdditionalSourcesRegisters
		|	AND &ConditionUpToDateData";
	
	If Not AdditionalParameters.SelectInBatches Then
		QueryFragment = StrReplace(QueryFragment, "SELECT TOP 1000", "SELECT"); // @query-part-1 @query-part-2
	EndIf;
	
	FilterOfUpToDateData = InfobaseUpdateInternal.FilterOfUpToDateData(Undefined, "ObjectTable");
	QueryFragment = StrReplace(QueryFragment, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
	If FilterOfUpToDateData.HasSelectionFilter Then
		QueryTextChecks =
			"SELECT TOP 1
			|	TRUE
			|FROM
			|	#ObjectTableChanges AS ChangesTable
			|		INNER JOIN #ObjectTable AS ObjectTable
			|		ON ChangesTable.Ref = ObjectTable.Ref
			|WHERE
			|	ChangesTable.Node = &CurrentQueue
			|	AND &ConditionUpToDateData";
		QueryTextChecks = StrReplace(QueryTextChecks, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
		QueryTextChecks = StrReplace(QueryTextChecks,"#ObjectTableChanges", FullObjectName + ".Changes");
		QueryTextChecks = StrReplace(QueryTextChecks,"#ObjectTable", FullObjectName);
		
		VerificationRequest = New Query;
		VerificationRequest.SetParameter("CurrentQueue", QueueRef(Queue));
		VerificationRequest.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
		VerificationRequest.Text = QueryTextChecks;
		
		IsAllUpToDateDataProcessed = VerificationRequest.Execute().IsEmpty();
		
		SetHandlerParametersOnSelectData(AdditionalParameters, IsAllUpToDateDataProcessed, Undefined)
	EndIf;
	
	FragmentsOfTheQuery.Add(QueryFragment);
	IsReference = Common.IsDocument(ObjectMetadata) Or Common.IsTask(ObjectMetadata);
	
	If AdditionalParameters.SelectInBatches And IsReference Then
		FragmentsOfTheQuery.Add("ORDER BY
			|	ObjectTable.Date DESC");
	EndIf;
	
	QueryFragment =
		"INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP #TTLockedReference";
	FragmentsOfTheQuery.Add(QueryFragment);
	QueryText = StrConcat(FragmentsOfTheQuery, Chars.LF);
	
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName = "TTToProcess" + ObjectName;
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#TTLockedReference","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText, "#TTToProcessRef",TempTableName);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");	
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheck(Queue, QueryText, FullObjectName, Undefined, TempTablesManager, True, AdditionalParameters);
	
	QueryText = StrReplace(QueryText,"#ObjectTable", FullObjectName);	
	
	CurrentQueue = QueueRef(Queue);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TempTableName", False, False,"");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(Queue, FullObjectName);
	EndIf;	
		
	Return Result;
	
EndFunction

// Returns the values of independent information register dimensions for processing.
// The input is the data registered in the queue. Data in the higher-priority queues is processed first.
//
// Parameters:
//  Queue           - Number - the position in the queue the handler and the data it will
//                              process are assigned to.
//  FullObjectName  - String - the name of the object that require processing. For example, InformationRegister.ProductBarcodes.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//   QueryResultSelection - the selection from dimension values that require processing. The field names match the register dimension
//                                 names. If a dimension is not in the processing queue,
//                                 this dimension selection value is blank.
//   ValueTable - data that must be processed, column names map the register dimension names.
//
Function SelectStandaloneInformationRegisterDimensionsToProcess(Queue, FullObjectName, AdditionalParameters = Undefined) Export
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	UpdateHandlerParameters = Undefined;
	AdditionalParameters.Property("UpdateHandlerParameters", UpdateHandlerParameters);
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName);
	BuildParameters = SelectionBuildParameters(AdditionalParameters, "ChangesTable");
	OrderingFieldsAreSet = OrderingFieldsAreSet(AdditionalParameters);
	OrderingRequired = OrderingFieldsAreSet Or BuildParameters.SelectionByPage;
	
	Query = New Query;
	QueryText =
		"SELECT TOP 1000
		|	&SelectedFields
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND &UnlockedFilterConditionText
		|	AND &ConditionByAdditionalSourcesRefs
		|	AND &PagesCondition
		|	AND &ConditionUpToDateData";
	
	If OrderingRequired Then
		SetStandaloneInformationRegisterOrderingFields(BuildParameters);
		QueryText = QueryText + "
			|ORDER BY
			|	&SelectionOrder
			|";
	EndIf;
	
	FilterOfUpToDateData = InfobaseUpdateInternal.FilterOfUpToDateData(UpdateHandlerParameters, "ChangesTable");
	QueryText = StrReplace(QueryText, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
	If FilterOfUpToDateData.HasSelectionFilter Then
		QueryTextChecks =
			"SELECT TOP 1
			|	TRUE
			|FROM
			|	#ObjectTableChanges AS ChangesTable
			|WHERE
			|	ChangesTable.Node = &CurrentQueue
			|	AND &ConditionUpToDateData";
		QueryTextChecks = StrReplace(QueryTextChecks, "&ConditionUpToDateData", FilterOfUpToDateData.Condition);
		QueryTextChecks = StrReplace(QueryTextChecks,"#ObjectTableChanges", FullObjectName + ".Changes");
		
		VerificationRequest = New Query;
		VerificationRequest.SetParameter("CurrentQueue", QueueRef(Queue));
		VerificationRequest.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
		VerificationRequest.Text = QueryTextChecks;
		
		IsAllUpToDateDataProcessed = VerificationRequest.Execute().IsEmpty();
		SetHandlerParametersOnSelectData(AdditionalParameters, IsAllUpToDateDataProcessed, UpdateHandlerParameters)
	EndIf;
	
	MeasurementsWithBasicSelection = New Array;
	
	For Each Dimension In ObjectMetadata.Dimensions Do
		If Not Dimension.MainFilter Then
			Continue;
		EndIf;
		
		SetDimension(BuildParameters, Dimension.Name);
		MeasurementsWithBasicSelection.Add(Dimension.Name);
		Query.SetParameter("EmptyValueOfDimension"+ Dimension.Name, Dimension.Type.AdjustValue()); 
	EndDo;
	
	NonPeriodicFlag = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical;
	If ObjectMetadata.InformationRegisterPeriodicity <> NonPeriodicFlag
		And ObjectMetadata.MainFilterOnPeriod Then
		SetPeriod(BuildParameters);
	EndIf;
	
	SetResources(BuildParameters, ObjectMetadata.Resources);
	SetAttributes1(BuildParameters, ObjectMetadata.Attributes);
	
	UnlockedFilterConditionText = ConditionForSelectingUnblockedMeasurements(MeasurementsWithBasicSelection);
	QueryText = StrReplace(QueryText, "&UnlockedFilterConditionText", UnlockedFilterConditionText);
	QueryText = StrReplace(QueryText, "#ObjectTableChanges", FullObjectName + ".Changes");
	QueryText = StrReplace(QueryText, "#TTLockedDimensions","TTLocked" + ObjectName);
	SetSelectionSize(QueryText, AdditionalParameters);
	
	TempTablesManager = New TempTablesManager();
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager);
	
	AddAdditionalSourceLockCheckForStandaloneRegister(Queue,
																				QueryText,
																				FullObjectName,
																				TempTablesManager,
																				AdditionalParameters);	
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", QueueRef(Queue));
	If FilterOfUpToDateData.HasSelectionFilter Then
		Query.SetParameter("UpToDateDataFilterVal", FilterOfUpToDateData.Value);
	EndIf;
	
	SetFieldsByPages(Query, BuildParameters);
	If OrderingRequired Then
		SetOrderByPages(Query, BuildParameters);
	EndIf;
	
	Return SelectDataToProcess(Query, BuildParameters);
	
EndFunction

// Creates a temporary table with values of an independent information register for processing.
//  Table name: TemporaryTableForProcessing<ObjectName>, Example: TTForProcessingProductsBarcodes.
//  The table columns match the register dimensions. If a dimension is not 
//	in the processing queue, this dimension selection value is blank.
//
// Parameters:
//  Queue					 - Number					 - the position in the queue for the current handler.
//  FullObjectName		 - String					 - full name of an object, for which the check is run (for instance, Catalog.Products).
//  TempTablesManager	 - TempTablesManager	 - manager, in which the temporary table is created.
//  AdditionalParameters	 - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
// 
// Returns:
//  Structure - The result of the temporary table generation:
//   * HasRecordsInTemporaryTable - Boolean - the created table has at least one record. There are
//                                            two reasons records can be missing:
//                                              all references have been processed or the references to be processed are locked by
//                                              the lower-priority handlers.
//   * HasDataToProcess - Boolean - there is data for processing in the queue (subsequently, not everything is processed).
//   * TempTableName - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfStandaloneInformationRegisterDimensionsToProcess(Queue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	ObjectName = StrSplit(FullObjectName,".",False)[1];
	ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName);
	
	Query = New Query;
	QueryText =
		"SELECT TOP 1000
		|	&DimensionSelectionText
		|INTO #TTToProcessDimensions
		|FROM
		|	#ObjectTableChanges AS ChangesTable
		|WHERE
		|	ChangesTable.Node = &CurrentQueue
		|	AND &UnlockedFilterConditionText
		|	AND &ConditionByAdditionalSourcesRefs
		|INDEX BY
		|	&IndexedDimensions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP #TTLockedDimensions";
	
	If Not AdditionalParameters.SelectInBatches Then
		QueryText = StrReplace(QueryText, "SELECT TOP 1000", "SELECT"); // @query-part-1 @query-part-2
	EndIf;
	
	MeasurementsWithBasicSelection = New Array;
	SelectTheMeasurement = New Array;
	TemplateForTheSelectedDimension = "ChangesTable.%1 AS %1";
	
	PeriodicRegister = 
		(ObjectMetadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical)
		And ObjectMetadata.MainFilterOnPeriod;
	For Each Dimension In ObjectMetadata.Dimensions Do
		If Not Dimension.MainFilter Then
			Continue;
		EndIf;
		
		SelectedDimension = StringFunctionsClientServer.SubstituteParametersToString(TemplateForTheSelectedDimension,
			Dimension.Name);
		SelectTheMeasurement.Add(SelectedDimension);
		MeasurementsWithBasicSelection.Add(Dimension.Name);
		Query.SetParameter("EmptyValueOfDimension"+ Dimension.Name, Dimension.Type.AdjustValue()); 
	EndDo;
	
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName = "TTToProcess" + ObjectName;
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	
	UnlockedFilterConditionText = ConditionForSelectingUnblockedMeasurements(MeasurementsWithBasicSelection);
	
	If PeriodicRegister Then
		MeasurementsWithBasicSelection.Add("Period");
	EndIf;
	
	DimensionSelectionText = FieldsForQuery(MeasurementsWithBasicSelection,, "ChangesTable");
	TheTextOfTheIndexedMeasurements = OrderingsForQuery(MeasurementsWithBasicSelection);
	QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
	QueryText = StrReplace(QueryText, "&IndexedDimensions", TheTextOfTheIndexedMeasurements);
	QueryText = StrReplace(QueryText, "&UnlockedFilterConditionText", UnlockedFilterConditionText);
	QueryText = StrReplace(QueryText,"#ObjectTableChanges", FullObjectName + ".Changes");	
	QueryText = StrReplace(QueryText, "#TTLockedDimensions","TTLocked" + ObjectName);
	QueryText = StrReplace(QueryText, "#TTToProcessDimensions",TempTableName);
	
	CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager);
	AddAdditionalSourceLockCheckForStandaloneRegister(Queue,
																				QueryText,
																				FullObjectName,
																				TempTablesManager,
																				AdditionalParameters);	
	
	CurrentQueue = QueueRef(Queue);
	
	Query.Text = QueryText;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("CurrentQueue", CurrentQueue);
	QueryResult = Query.ExecuteBatch();
	
	Result = New Structure("HasRecordsInTemporaryTable,HasDataToProcess,TempTableName", False, False,"");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult[0].Unload()[0].Count <> 0;
	
	If Result.HasRecordsInTemporaryTable Then
		Result.HasDataToProcess = True;
	Else
		Result.HasDataToProcess = HasDataToProcess(Queue, FullObjectName);
	EndIf;	
		
	Return Result;
	
EndFunction

// Checks if there is unprocessed data.
//
// Parameters:
//  Queue    - Number        - the position in the queue the handler and the data
//                              it will process are assigned to.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  FullObjectNameMetadata - String
//                             - MetadataObject - a full name of an object being processed or 
//                              its metadata. For example, "Document.GoodsReceipt"
//                             - Array - an array of full names of metadata objects;
//                              an array cannot have independent information registers.
//  Filter - AnyRef
//        - Structure
//        - Undefined
//        - Array - filters data to be checked.
//                   If passed Undefined - checked for the whole object type.
//                   If an object is a register subordinate to a recorder, then a reference
//                   to a recorder or an array of references is filtered.
//                   If an object is of a reference type, then either a reference or an array of references is filtered.
//                   If an object is an independent information register, then a structure containing values of dimensions is filtered.
//                   Structure key - dimension name, value - filter value (an array of values can be passed).
//
// Returns:
//  Boolean - True if not all data is processed.
//
Function HasDataToProcess(Queue, FullObjectNameMetadata, Filter = Undefined) Export
	
	If DeferredUpdateCompleted() Then
		Return False;
	EndIf;
	
	If TypeOf(FullObjectNameMetadata) = Type("String") Then
		FullNamesOfObjectsToProcess = StrSplit(FullObjectNameMetadata, ",");
	ElsIf TypeOf(FullObjectNameMetadata) = Type("Array") Then
		FullNamesOfObjectsToProcess = FullObjectNameMetadata;
	ElsIf TypeOf(FullObjectNameMetadata) = Type("MetadataObject") Then
		FullNamesOfObjectsToProcess = New Array;
		FullNamesOfObjectsToProcess.Add(FullObjectNameMetadata.FullName());
	Else
		ExceptionText = NStr("en = 'Invalid type of parameter ""%1"" is passed to function %2';");
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "FullObjectNameMetadata", "InfobaseUpdate.HasDataToProcess");
		Raise ExceptionText;
	EndIf;	
	
	Query = New Query;
	
	QueryTexts = New Array;
	RegisterRequestTexts = New Array;
	FilterIs_Specified = False;
	
	For Each TypeToProcess In FullNamesOfObjectsToProcess Do
		
		If TypeOf(TypeToProcess) = Type("MetadataObject") Then
			ObjectMetadata = TypeToProcess;
			FullObjectName  = TypeToProcess.FullName();
		Else
			ObjectMetadata = Common.MetadataObjectByFullName(TypeToProcess);
			FullObjectName  = TypeToProcess;
		EndIf;
		CheckingRegister = False;
		
		ObjectName = StrSplit(FullObjectName,".",False)[1];
		
		DataFilterCriterion = "TRUE";
		ConditionForCheckingTheRegistrar = "TRUE";
		
		
		If Common.IsRefTypeObject(ObjectMetadata) Then
			QueryText =
			"SELECT TOP 1
			|	ChangesTable.Ref AS Ref
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion
			|	AND TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			#ObjectTable AS Table
			|		WHERE
			|			Table.Ref = ChangesTable.Ref)";
			
			Query.SetParameter("Ref", Filter);
			
			If Filter <> Undefined Then
				DataFilterCriterion = "ChangesTable.Ref IN (&Filter)";
			EndIf;
			
		ElsIf Common.IsInformationRegister(ObjectMetadata)
			And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			
			If FullNamesOfObjectsToProcess.Count() > 1 Then
				ExceptionText = NStr("en = 'In the name array in parameter ""%1"", an independent information register is passed to function %2.';");
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText,
					"FullObjectNameMetadata", "InfobaseUpdate.HasDataToProcess");
				Raise ExceptionText;
			EndIf;	
			
			FilterIs_Specified = True;
			
			QueryText =
			"SELECT TOP 1
			|	&DimensionSelectionText
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion";
			
			DimensionSelectionText = "";
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionSelectionText = DimensionSelectionText + "
				|	ChangesTable." + Dimension.Name + " AS " + Dimension.Name + ",";
				
				If Filter <> Undefined Then
					DataFilterCriterion = DataFilterCriterion + "
					|	AND (ChangesTable." + Dimension.Name + " IN (&FilterValue" + Dimension.Name + ")
					|		OR ChangesTable." + Dimension.Name + " = &EmptyValue" + Dimension.Name + ")";
					
					If Filter.Property(Dimension.Name) Then
						Query.SetParameter("FilterValue" + Dimension.Name, Filter[Dimension.Name]);
					Else
						Query.SetParameter("FilterValue" + Dimension.Name, Dimension.Type.AdjustValue());
					EndIf;
					
					Query.SetParameter("EmptyValue" + Dimension.Name, Dimension.Type.AdjustValue());
				EndIf;
			EndDo;
			
			If IsBlankString(DimensionSelectionText) Then
				DimensionSelectionText = "*";
			Else
				DimensionSelectionText = Left(DimensionSelectionText, StrLen(DimensionSelectionText) - 1);
			EndIf;
			
			QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
			
		ElsIf Common.IsRegister(ObjectMetadata) Then
			CheckingRegister = True;
			
			VerificationRequestTemplate = 
				"TRUE IN (SELECT TOP 1
				|	TRUE
				|FROM
				|	#TableName AS TableToCheck
				|WHERE
				|	ChangesTable.Recorder = TableToCheck.Ref)";
			
			QueryCollection = New Array;
			LoggerTypes = ObjectMetadata.StandardAttributes.Recorder.Type;
			LoggerTypes = LoggerTypes.Types();
			For Each TypeOfRegistrar In LoggerTypes Do
				RegistrarMetadata = Metadata.FindByType(TypeOfRegistrar);
				If RegistrarMetadata = Undefined Then
					Continue;
				EndIf;
				FullRecorderName = RegistrarMetadata.FullName();
				QueryTextChecks = StrReplace(VerificationRequestTemplate, "#TableName", FullRecorderName);
				QueryCollection.Add(QueryTextChecks);
			EndDo;
			
			ConditionForCheckingTheRegistrar = StrConcat(QueryCollection, Chars.LF + "OR ");
			
			QueryText =
			"SELECT TOP 1
			|	ChangesTable.Recorder AS Ref
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|	AND &DataFilterCriterion
			|	AND (&ConditionForRegistrars)";
			
			If Filter <> Undefined Then
				DataFilterCriterion = "ChangesTable.Recorder IN (&Filter)";
			EndIf;
			
		Else
			ExceptionText = NStr("en = 'Function %2 does not support checks for metadata type ""%1"".';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText,
				String(ObjectMetadata), "InfobaseUpdate.HasDataToProcess");
			Raise ExceptionText;
		EndIf;
		
		QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
		QueryText = StrReplace(QueryText, "#ObjectTable", FullObjectName);
		QueryText = StrReplace(QueryText, "#ObjectName", ObjectName);
		QueryText = StrReplace(QueryText, "&DataFilterCriterion", DataFilterCriterion);
		QueryText = StrReplace(QueryText, "&ConditionForRegistrars", ConditionForCheckingTheRegistrar);
		
		If CheckingRegister Then
			RegisterRequestTexts.Add(QueryText);
		Else
			QueryTexts.Add(QueryText);
		EndIf;
		
	EndDo;
	
	Connector = "
	|
	|UNION ALL
	|";

	QueryText = StrConcat(QueryTexts, Connector);
	
	FinalArrayOfRequests = New Array;
	FinalArrayOfRequests.Add(QueryText);
	CommonClientServer.SupplementArray(FinalArrayOfRequests, RegisterRequestTexts);
	
	For Each QueryText In FinalArrayOfRequests Do
		If Not ValueIsFilled(QueryText) Then
			Continue;
		EndIf;
		
		If Queue = Undefined Then
			NodeFilterCriterion = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCriterion = "	ChangesTable.Node IN (&Nodes) ";
			If TypeOf(Queue) = Type("Array") Then
				Query.SetParameter("Nodes", Queue);
			Else
				Query.SetParameter("Nodes", QueueRef(Queue));
			EndIf;
		EndIf;
		
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCriterion);
		
		If Not FilterIs_Specified Then
			Query.SetParameter("Filter", Filter);
		EndIf;
			
		Query.Text = QueryText;
		
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		If Not Query.Execute().IsEmpty() Then // @skip-check query-in-loop - To avoid heavy queries.
			Return True;
		EndIf;
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	EndDo; 
	
	Return False;
EndFunction

// Checks if all data is processed.
//
// Parameters:
//  Queue    - Number        - the position in the queue the handler and the data
//                              it will process are assigned to.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  FullObjectNameMetadata - String
//                             - MetadataObject - a full name of an object being processed or 
//                              its metadata. For example, "Document.GoodsReceipt"
//                             - Array - an array of full names of metadata objects;
//                              an array cannot have independent information registers.
//  Filter - AnyRef
//        - Structure
//        - Undefined
//        - Array - filters data to be checked.
//                   If passed Undefined - checked for the whole object type.
//                   If an object is a register subordinate to a recorder, then a reference
//                   to a recorder or an array of references is filtered.
//                   If an object is of a reference type, then either a reference or an array of references is filtered.
//                   If an object is an independent information register, then a structure containing values of dimensions is filtered.
//                   Structure key - dimension name, value - filter value (an array of values can be passed).
// 
// Returns:
//  Boolean - True if all data is processed.
//
Function DataProcessingCompleted(Queue, FullObjectNameMetadata, Filter = Undefined) Export
	
	Return Not HasDataToProcess(Queue, FullObjectNameMetadata, Filter);
	
EndFunction

// Checks if there is data locked by smaller queues.
//
// Parameters:
//  Queue - Number
//          - Undefined - the position in the queue the handler and
//                           the data it will process are assigned to.
//  FullObjectNameMetadata - String
//                             - MetadataObject - a full name of an object being processed or
//                                        its metadata. For example, "Document.GoodsReceipt"
//                             - Array - an array of full names of metadata objects;
//                                        an array cannot have independent information registers.
// 
// Returns:
//  Boolean - True if processing of the object is locked by smaller queues.
//
Function HasDataLockedByPreviousQueues(Queue, FullObjectNameMetadata) Export
	
	Return HasDataToProcess(EarlierQueueNodes(Queue), FullObjectNameMetadata);
	
EndFunction

// Checks if data processing carried our by handlers of an earlier queue was finished.
//
// Parameters:
//  Queue    - Number        - the position in the queue the handler and the data
//                              it will process are assigned to.
//             - Undefined - checked if general processing is complete;
//             - Array       - checked if there is data to be processed in the queues list.
//  Data     - AnyRef
//             - InformationRegisterRecordSet, AccumulationRegisterRecordSet
//             - AccountingRegisterRecordSet, CalculationRegisterRecordSet
//             - CatalogObject, DocumentObject, ChartOfCharacteristicTypesObject, BusinessProcessObject, TaskObject
//             - FormDataStructure - a reference to an object, an object proper,
//                              or a set of records to be checked.
//                              If ExtendedParameters.IsRegisterRecords = True, then Data is a recorder of a register
//                              specified in AdditionalParameters.
//  AdditionalParameters   - See InfobaseUpdate.AdditionalProcessingMarkParameters.
//  MetadataAndFilter          - See InfobaseUpdate.MetadataAndFilterByData.
// 
// Returns:
//  Boolean - True if the passed object is updated to a new version and can be changed.
//
Function CanReadAndEdit(Queue, Data, AdditionalParameters = Undefined, MetadataAndFilter = Undefined) Export
	
	If DeferredUpdateCompleted() Then
		Return True;
	EndIf;
	
	If MetadataAndFilter = Undefined Then
		MetadataAndFilter = MetadataAndFilterByData(Data, AdditionalParameters);
	EndIf;
	
	If MetadataAndFilter.IsNew Then
		Return True;
	EndIf;
	
	If Queue = Undefined Then
		Return Not HasDataToProcess(Undefined, MetadataAndFilter.Metadata, MetadataAndFilter.Filter);
	Else
		Return Not HasDataToProcess(EarlierQueueNodes(Queue), MetadataAndFilter.Metadata, MetadataAndFilter.Filter);
	EndIf;
	
EndFunction

// Creates a temporary table containing locked data.
// Table name: TemporaryTables Locked<ObjectName>, for example TemporaryTableLockedProductsAndServices
//  Table columns:
//      for the reference type objects
//          * Ref;
//      for registers subordinate to a recorder
//          * Recorder;
//      for registers containing a direct record
//          * columns that correspond to dimensions of a register.
//
// Parameters:
//  Queue                 - Number
//                          - Undefined - the position in a processing queue where the current handler is running.
//                             If passed Undefined, then checked in all queues.
//  FullObjectName        - String - full name of an object, for which the check is run
//                             (for instance, Catalog.Products).
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters
//
// Returns:
//  Structure:
//     * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//     * TempTableName          - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, FullObjectName, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName); // MetadataObjectCatalog, MetadataObjectDocument
	NameOfTheDimensionToSelect = AdditionalParameters.NameOfTheDimensionToSelect;
	DeferredUpdateCompletedSuccessfully = GetFunctionalOption("DeferredUpdateCompletedSuccessfully");
	
	If Common.IsRefTypeObject(ObjectMetadata) Then
		If DeferredUpdateCompletedSuccessfully Then
			QueryText =
			"SELECT
			|	&EmptyValue AS Ref
			|INTO #TempTableName
			|WHERE
			|	FALSE";
			                                           
			Query.SetParameter("EmptyValue", ObjectMetadata.StandardAttributes.Ref.Type.AdjustValue()); 
		Else	
			QueryText =
			"SELECT
			|	ChangesTable.Ref AS Ref
			|INTO #TempTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|
			|INDEX BY
			|	Ref";
		EndIf;
	ElsIf Common.IsInformationRegister(ObjectMetadata)
		And ObjectMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent
		And Upper(NameOfTheDimensionToSelect) = Upper("Recorder") Then
		DimensionsNames = New Array;
		AliasesOfMeasurements = New Array;
		
		If DeferredUpdateCompletedSuccessfully Then
			QueryText =
			"SELECT
			|	&DimensionSelectionText
			|INTO #TempTableName
			|WHERE
			|	FALSE";
			
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionsNames.Add("&EmptyValueOfDimension" + Dimension.Name);
				AliasesOfMeasurements.Add(Dimension.Name);
				Query.SetParameter("EmptyValueOfDimension" + Dimension.Name, Dimension.Type.AdjustValue());
			EndDo;
			
		Else
			QueryText =
			"SELECT
			|	&DimensionSelectionText
			|INTO #TempTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|INDEX BY
			|	&IndexedDimensions";
			
			For Each Dimension In ObjectMetadata.Dimensions Do
				If Not Dimension.MainFilter Then
					Continue;
				EndIf;
				
				DimensionsNames.Add("ChangesTable." + Dimension.Name);
				If Not (Dimension.Type.Types().Count() > 1
					And (Dimension.Type.Types().Find(Type("Boolean")) <> Undefined
						Or Dimension.Type.Types().Find(Type("String")) <> Undefined
						Or Dimension.Type.Types().Find(Type("Date")) <> Undefined)) Then
					
					AliasesOfMeasurements.Add(Dimension.Name);
				EndIf;
			EndDo;
			
			If AliasesOfMeasurements.Count() = 0 Then
				QueryText = StrReplace(QueryText, "INDEX BY", "");
			EndIf;
			
			QueryText = StrReplace(QueryText, "&IndexedDimensions", OrderingsForQuery(AliasesOfMeasurements));
		EndIf;
		
		NonPeriodicFlag = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical;
		If ObjectMetadata.InformationRegisterPeriodicity <> NonPeriodicFlag
			And ObjectMetadata.MainFilterOnPeriod Then
			DimensionsNames.Add("ChangesTable.Period");
			AliasesOfMeasurements.Add("Period");
		EndIf;
		
		If DimensionsNames.Count() = 0 Then
			DimensionSelectionText = "*";
		Else
			DimensionSelectionText = FieldsForQuery(DimensionsNames, AliasesOfMeasurements);
		EndIf;
		
		QueryText = StrReplace(QueryText, "&DimensionSelectionText", DimensionSelectionText);
		
	ElsIf Common.IsRegister(ObjectMetadata) Then
		
		If DeferredUpdateCompletedSuccessfully Then
			QueryText =
			"SELECT
			|	&EmptyValue AS Recorder
			|INTO #TempTableName
			|WHERE
			|	FALSE";
			
			Query.SetParameter("EmptyValue", ObjectMetadata.StandardAttributes.Recorder.Type.AdjustValue()); 
			
		Else
			QueryText =
			"SELECT DISTINCT
			|	ChangesTable.Recorder AS Recorder
			|INTO #TempTableName
			|FROM
			|	#ChangesTable AS ChangesTable
			|WHERE
			|	&NodeFilterCriterion
			|
			|INDEX BY
			|	Recorder";
		EndIf;
		
		
		If Upper(NameOfTheDimensionToSelect) <> Upper("Recorder") Then
			QueryText = StrReplace(QueryText, "Recorder", NameOfTheDimensionToSelect);
		EndIf;
	Else
		ExceptionText = NStr("en = 'Function %1 does not support checks for this metadata type.';");
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, "InfobaseUpdate.CreateTemporaryTableOfDataProhibitedFromReadingAndEditing");
		Raise ExceptionText;
	EndIf;
	
	If Not DeferredUpdateCompletedSuccessfully Then
		
		If Queue = Undefined Then
			NodeFilterCriterion = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCriterion = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(Queue));
		EndIf;	
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCriterion);
	
		QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
		
	EndIf;
	
	ObjectName = StrSplit(FullObjectName, ".")[1];
	
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName =  "TTLocked"+ObjectName;
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	
	QueryText = StrReplace(QueryText, "#TempTableName", TempTableName);
	
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable,TempTableName", False, "");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
			
	Return Result;
	
EndFunction

// Creates a temporary table of blocked references.
//  Table name: TemporaryTable Locked.
//  Table columns:
//    * Ref.
//
// Parameters:
//  Queue                 - Number
//                          - Undefined - the position in a processing queue where
//                             the current handler is running. If passed Undefined, then checked in all queues.
//  FullNamesOfObjects     - String
//                          - Array - full name of an object, for which the check is run
//                             (for instance, Catalog.Products).
//                             It is allowed to pass objects of a reference type or registers subordinate to a recorder.
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters
//
// Returns:
//  Structure:
//    * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//    * TempTableName          - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing(Queue, FullNamesOfObjects, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		QueryText =
		"SELECT
		|	UNDEFINED AS Ref
		|INTO #TempTableName
		|WHERE
		|	FALSE";
	Else	
		If TypeOf(FullNamesOfObjects) = Type("String") Then
			FullObjectNamesArray = StrSplit(FullNamesOfObjects,",",False);
		ElsIf TypeOf(FullNamesOfObjects) = Type("Array") Then 
			FullObjectNamesArray = FullNamesOfObjects;
		Else
			FullObjectNamesArray = New Array;
			FullObjectNamesArray.Add(FullNamesOfObjects);
		EndIf;
		
		QueryTextArray = New Array;
		
		HasRegisters = False;
		
		For Each TypeToProcess In FullObjectNamesArray Do
			
			If TypeOf(TypeToProcess) = Type("MetadataObject") Then
				ObjectMetadata = TypeToProcess;
				FullObjectName  = TypeToProcess.FullName();
			Else
				ObjectMetadata = Common.MetadataObjectByFullName(TypeToProcess);
				FullObjectName  = TypeToProcess;
			EndIf;
			
			ObjectMetadata = Common.MetadataObjectByFullName(FullObjectName);
			
			If Common.IsRefTypeObject(ObjectMetadata) Then
				If QueryTextArray.Count() = 0 Then
					QueryText =
					"SELECT
					|	ChangesTable.Ref AS Ref
					|INTO #NameOfTheTemporaryTableOfTheFirstQuery
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";
				Else
					QueryText =
					"SELECT
					|	ChangesTable.Ref AS Ref
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";	
				EndIf;
			ElsIf Common.IsRegister(ObjectMetadata) Then
				If QueryTextArray.Count() = 0 Then
					QueryText =
					"SELECT
					|	ChangesTable.Recorder AS Ref
					|INTO #NameOfTheTemporaryTableOfTheFirstQuery
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";
				Else
					QueryText =
					"SELECT
					|	ChangesTable.Recorder AS Ref
					|FROM
					|	#ChangesTable AS ChangesTable
					|WHERE
					|	&NodeFilterCriterion";
				EndIf;
				
				HasRegisters = True;
				
			Else
				ExceptionText = NStr("en = 'Function %2 does not support checks for metadata type ""%1"".';");
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText,
					String(ObjectMetadata), "InfobaseUpdate.CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing");
				Raise ExceptionText;
			EndIf;
		
			QueryText = StrReplace(QueryText, "#ChangesTable", FullObjectName + ".Changes");
			
			QueryTextArray.Add(QueryText);
		EndDo;
		
		Connector = "
		|
		|UNION ALL
		|";
		
		QueryText = StrConcat(QueryTextArray, Connector); 
		
		If HasRegisters And QueryTextArray.Count() > 1 Then
			QueryTemplate =
			"SELECT DISTINCT
			|	NestedQuery.Ref AS Ref
			|INTO #TempTableName
			|FROM
			|	#QueryText AS NestedQuery
			|
			|INDEX BY
			|	Ref";
			QueryText = StrReplace(QueryTemplate, "#QueryText", "(" + QueryText + ")");
			QueryText = StrReplace(QueryText, "INTO #NameOfTheTemporaryTableOfTheFirstQuery", "");
		Else
			QueryText = QueryText + "
			|
			|INDEX BY
			|	Ref";
			QueryText = StrReplace(QueryText, "#NameOfTheTemporaryTableOfTheFirstQuery", "#TempTableName");
		EndIf;
		
		If Queue = Undefined Then
			NodeFilterCriterion = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCriterion = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(Queue));
		EndIf;	
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCriterion);
	EndIf;	
	
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName =  "TTLocked";
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	QueryText = StrReplace(QueryText, "#TempTableName", TempTableName);
	
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable, TempTableName", False, "");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
	
	Return Result;
	
EndFunction

// Creates a temporary table of changes in register dimensions subordinate to recorders for dimensions that have unprocessed recorders.
//  Creates a temporary table of changes in register dimensions subordinate to recorders for dimensions that have unprocessed recorders:
//  - determine locked recorders;
//  - join with the main recorder table by these recorders;
//  - get the values of changes from the main table;
//  - perform the grouping.
//  Table name: TemporaryTables Locked<ObjectName>, for example, TTLockedStock.
//  The table columns match the passed dimensions.
//
// Parameters:
//  Queue                 - Number
//                          - Undefined - the position in a processing queue where
//                             the current handler is running. If passed Undefined,
//                             then checked in all queues.
//  FullRegisterName       - String - the name of the register that requires record update.
//                             For example, AccumulationRegister.ProductStock
//  Dimensions               - String
//                          - Array - the name of dimensions by which the lock must be checked,
//                             separated by commas, or an array of names.
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters
//
// Returns:
//  Structure:
//   * HasRecordsInTemporaryTable - Boolean - the created table has at least one record.
//   * TempTableName          - String - a name of a created temporary table.
//
Function CreateTemporaryTableOfLockedDimensionValues(Queue, FullRegisterName, Dimensions, TempTablesManager, AdditionalParameters = Undefined) Export
	
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalProcessingDataSelectionParameters();
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If TypeOf(Dimensions) = Type("String") Then
		DimensionsArray = StrSplit(Dimensions, ",", False);
	Else
		DimensionsArray = Dimensions;
	EndIf;
	
	ObjectMetadata = Common.MetadataObjectByFullName(FullRegisterName);
	DimensionsNames = New Array;
	AliasesOfMeasurements = New Array;
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		QueryText =
		"SELECT
		|	&DimensionValues
		|INTO #TempTableName
		|WHERE
		|	FALSE";
		
		For Each DimensionStr In DimensionsArray Do
			Dimension = ObjectMetadata.Dimensions.Find(DimensionStr);
			DimensionsNames.Add("&EmptyValueOfDimension" + Dimension.Name);
			AliasesOfMeasurements.Add(Dimension.Name);
			Query.SetParameter("EmptyValueOfDimension" + Dimension.Name, Dimension.Type.AdjustValue()); 
		EndDo;
	Else
		
		QueryText =
		"SELECT DISTINCT
		|	&DimensionValues
		|INTO #TempTableName
		|FROM
		|	#ChangesTable AS ChangesTable
		|		INNER JOIN #RegisterTable AS RegisterTable
		|		ON ChangesTable.Recorder = RegisterTable.Recorder
		|WHERE
		|	&NodeFilterCriterion
		|INDEX BY
		|	&IndexedDimensions";
		
		For Each Dimension In DimensionsArray Do
			DimensionsNames.Add("RegisterTable." + Dimension);
			AliasesOfMeasurements.Add(Dimension);
		EndDo;
		
		TheTextOfTheIndexedMeasurements = OrderingsForQuery(AliasesOfMeasurements);
		QueryText = StrReplace(QueryText, "&IndexedDimensions", TheTextOfTheIndexedMeasurements);
		QueryText = StrReplace(QueryText, "#ChangesTable", FullRegisterName + ".Changes");
		QueryText = StrReplace(QueryText, "#RegisterTable", FullRegisterName);
		
		If Queue = Undefined Then
			NodeFilterCriterion = "	ChangesTable.Node REFS ExchangePlan.InfobaseUpdate ";
		Else
			NodeFilterCriterion = "	ChangesTable.Node IN (&Nodes) ";
			Query.SetParameter("Nodes", EarlierQueueNodes(Queue));
		EndIf;	
		
		QueryText = StrReplace(QueryText, "&NodeFilterCriterion", NodeFilterCriterion);
	EndIf;
	
	ObjectName = StrSplit(FullRegisterName, ".")[1];
	If IsBlankString(AdditionalParameters.TempTableName) Then
		TempTableName =  "TTLocked" + ObjectName;
	Else
		TempTableName = AdditionalParameters.TempTableName;
	EndIf;
	QueryText = StrReplace(QueryText, "#TempTableName", TempTableName);
	
	DimensionValues = FieldsForQuery(DimensionsNames, AliasesOfMeasurements);
	QueryText = StrReplace(QueryText, "&DimensionValues", DimensionValues);
	Query.Text = QueryText;
	QueryResult = Query.Execute();
	
	Result = New Structure("HasRecordsInTemporaryTable,TempTableName", False, "");
	Result.TempTableName = TempTableName;
	Result.HasRecordsInTemporaryTable = QueryResult.Unload()[0].Count <> 0;
			
	Return Result;
	
EndFunction

// The function is used for checking objects in opening forms and before recording.
// It can be used as a function for checking by default in case there is
// enough logics - blocked objects are registered on the InfobaseUpdate exchange plan nodes.
//
// Parameters:
//  MetadataAndFilter - See InfobaseUpdate.MetadataAndFilterByData.
//
// Returns:
//  Boolean - True if the object is updated and available for changing.
//
Function DataUpdatedForNewApplicationVersion(MetadataAndFilter) Export
	
	Return CanReadAndEdit(Undefined, MetadataAndFilter.Data,,MetadataAndFilter); 
	
EndFunction

// Data selection through SelectStandaloneInformationRegisterDimensionsToProcess().
//
// Returns:
//  String - the "IndependentInfoRegistryMeasurements" constant.
//
Function SelectionMethodOfIndependentInfoRegistryMeasurements() Export
	
	Return "IndependentInfoRegistryMeasurements";
	
EndFunction

// Data selection through SelectRegisterRecordersToProcess().
//
// Returns:
//  String - the "RegisterRecorders" constant.
//
Function RegisterRecordersSelectionMethod() Export
	
	Return "RegistryRecorders";
	
EndFunction

// Data selection through SelectRefsToProcess().
//
// Returns:
//  String - the "Refs" constant.
//
Function RefsSelectionMethod() Export
	
	Return "References";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Checks if the infobase update is required when the configuration version is changed.
//
// Returns:
//   Boolean - True if an update is required.
//
Function InfobaseUpdateRequired() Export
	
	Return InfobaseUpdateInternalCached.InfobaseUpdateRequired();
	
EndFunction

// Returns True if the infobase is being updated.
//
// Returns:
//   Boolean - True if an update is in progress.
//
Function InfobaseUpdateInProgress() Export
	
	If Common.DataSeparationEnabled()
		And Not Common.SeparatedDataUsageAvailable() Then
		Return InfobaseUpdateRequired();
	EndIf;
	
	Return SessionParameters.IBUpdateInProgress;
	
EndFunction

// Returns a flag indicating whether deferred update completed.
//
// Parameters:
//  SubsystemsNames - String - if it is passed, the result of completing
//                            update for the transferred subsystem will be checked, and not for the entire configuration.
//                 - Array - if it is required to check update completion of the several
//                            subsystems at once.
//
// Returns:
//  Boolean - True if an update is in completed.
//
Function DeferredUpdateCompleted(Val SubsystemsNames = Undefined) Export
	
	If GetFunctionalOption("DeferredUpdateCompletedSuccessfully") Then
		IsSubordinateDIBNode = Common.IsSubordinateDIBNode();
		If Not IsSubordinateDIBNode Then
			Return True;
		Else
			Return GetFunctionalOption("DeferredMasterNodeUpdateCompleted");
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(SubsystemsNames) Then
		Return False;
	EndIf;
	
	If TypeOf(SubsystemsNames) = Type("String") Then
		SubsystemsNames = StrSplit(SubsystemsNames, ",");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Subsystems", SubsystemsNames);
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.LibraryName IN (&Subsystems)
		|	AND UpdateHandlers.Status <> &Status";
	Return Query.Execute().Unload().Count() = 0;
	
EndFunction

// Returns True if the function is called from the update handler.
// For any type of an update handler - exclusive, seamless, or deferred.
//
// Parameters:
//  HandlerExecutionMode - String - Deferred, Seamless, Exclusive or a combination of these
//                               variants separated by commas. If given, only a call from update handlers from the stated execution mode
//                               is checked.
//
// Returns:
//  Boolean - True if the function is called from the update handler.
//
Function IsCallFromUpdateHandler(HandlerExecutionMode = "") Export
	
	ExecutionMode = SessionParameters.UpdateHandlerParameters.ExecutionMode;
	If Not ValueIsFilled(ExecutionMode) Then
		Return False;
	EndIf;
	
	If Not ValueIsFilled(HandlerExecutionMode) Then
		Return True;
	EndIf;
	
	Return (StrFind(HandlerExecutionMode, ExecutionMode) > 0);
	
EndFunction

// Returns an empty table of update handlers and initial infobase filling handlers. 
//
// Returns:
//   ValueTable   - A table with the following columns:
//    1. For update handlers of any type:
//
//     * InitialFilling - Boolean - if True, then a handler is started on a launch with an empty base.
//     * Version              - String - for example, "2.1.3.39". Configuration version number.
//                                      The handler is executed when the configuration migrates to this version number.
//                                      If an empty string is specified, this handler is intended for initial filling only
//                                      (when the InitialFilling parameter is specified).
//     * Procedure           - String - the full name of an update handler or initial filling handler. 
//                                      For example, "MEMInfobaseUpdate.FillNewAttribute"
//                                      Must be an export procedure.
//     * ExecutionMode     - String - Update handler execution mode. Valid values are::
//                                      "Exclusive", "Deferred", "Seamless".
//                                      By default, "Exclusive" (if no value is passed).
//
//    2. For SaaS update handlers:
//
//     * SharedData         - Boolean - if True, the handler is executed prior to
//                                      other handlers that use shared data.
//                                      Is is allowed to specify it only for handlers with Exclusive or Seamless execution mode.
//                                      If the True value is specified for a handler with
//                                      a Deferred execution mode, an exception will be brought out.
//     * HandlerManagement - Boolean - if True, then the handler has a parameter of a Structure type which has
//                                          the SeparatedHandlers property that is the table of values characterized by the structure
//                                          returned by this function.
//                                      In this case the version column is ignored. If separated handler
//                                      execution is required, you have to add a row with
//                                      the description of the handler procedure.
//                                      Makes sense only for required (Version = *) update handlers 
//                                      having a SharedData flag set.
//
//    3) For deferred update handlers:
//
//     * Comment         - String - details for actions executed by an update handler.
//     * Id       - UUID - it must be filled in only for deferred update handlers
//                                                 and not required for others. Helps to identify
//                                                 a handler in case it was renamed.
//     
//     * ObjectsToLock  - String - it must be filled in only for deferred update handlers
//                                      and not required for others. Full names of objects separated by commas. 
//                                      These names must be locked from changing until data processing procedure is finalized.
//                                      If it is not empty, then the CheckProcedure property must also be filled in.
//     * NewObjects        - String - It is required and intended for deferred update handlers only.
//                                      Accepts a comma-delimited list of the full names of the objects 
//                                      that will be created during the update handler runtime.
//     * CheckProcedure   - String - It is required and intended for deferred update handlers only.
//                                       It takes the name of a function that, for the given object, 
//                                      determines whether the data processing procedure has been completed. 
//                                      When processing is completed, the function should return "True". 
//                                      Called from the "InfobaseUpdate.CheckObjectProcessed" procedure.
//                                      The function takes the following parameters::
//                                         Parameters - See InfobaseUpdate.MetadataAndFilterByData.
//
//    4. For update handlers in libraries and configurations with parallel deferred handlers:
//
//     * UpdateDataFillingProcedure - String - the procedure for registering data
//                                      to be updated by this handler must be specified.
//     * ExecuteInMasterNodeOnly  - Boolean - only for deferred update handlers with a Parallel execution mode.
//                                      Specify as True if an update handler must be executed only in the master
//                                      DIB node.
//     * RunAlsoInSubordinateDIBNodeWithFilters - Boolean - only for deferred update handlers with a Parallel execution
//                                      mode.
//                                      Specify as True if an update handler must also be executed in
//                                      the subordinate DIB node using filters.
//     * ObjectsToRead              - String - objects to be read by the update handler while processing data.
//     * ObjectsToChange            - String - objects to be changed by the update handler while processing data.
//     * ExecutionPriorities         - ValueTable - table of execution priorities for deferred handlers
//                                      changing or reading the same data. For more information, see the commentary
//                                      to the InfobaseUpdate.HandlerExecutionPriorities function.
//     * Multithreaded                - Boolean - True if the handler supports multi-threaded data processing.
//     * Order  - EnumRef.OrderOfUpdateHandlers
//    
//    5. For real-time and exclusive initial population handlers:
//     * DoNotExecuteWhenSwitchingFromAnotherProgram - Boolean - If True, the initial subsystem population handlers won't run during a migration from an app.
//                                          (By default, such handlers are executed automatically.)
//                                          6. For internal use only
//
//    :
//
//     * ExecuteInMandatoryGroup - Boolean - specify this parameter if the handler must be
//                                      executed in the group that contains handlers for the "*" version.
//                                      You can change the order of handlers
//                                      in the group by changing their priorities.
//     * Priority           - Number  - for internal use.
//
//    6) Obsolete, used for backwards compatibility (not to be specified for new handlers):
//
//     * ExclusiveMode    - Undefined
//                           - Boolean - if Undefined, the handler 
//                                      is executed unconditionally in the exclusive mode.
//                                      For handlers that execute migration to a specific version (Version <> *):
//                                        False - handler execution does not require an exclusive mode.
//                                        True - handler execution requires an exclusive mode.
//                                      For required update handlers (Version = "*"):
//                                        False - handler execution does not require an exclusive mode.
//                                        True - handler execution may require an exclusive mode.
//                                                 A parameter of structure type
//                                                 with ExclusiveMode property (of Boolean type) is passed to such handlers.
//                                                 To execute the handler in exclusive mode, set
//                                                 this parameter to True. In this case the handler must perform
//                                                 the required update operations. Changing the parameter
//                                                 in the handler body is ignored.
//                                                 To execute the handler in nonexclusive mode, set this parameter to
//                                                 False. In this case the handler must not make any
//                                                 changes to the infobase.
//                                                 If the analysis reveals that a handler needs to
//                                                 change infobase data, set the parameter value to the True,
//                                                 and stop handler execution.
//                                                 In this case nonexclusive infobase update is
//                                                 canceled and an error message with a recommendation to perform the update in
//                                                 exclusive mode is displayed.
//
Function NewUpdateHandlerTable() Export
	
	Handlers = New ValueTable;
	// Common properties.
	Handlers.Columns.Add("InitialFilling", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Version",    New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("Procedure", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ExecutionMode", New TypeDescription("String"));
	// For libraries.
	Handlers.Columns.Add("ExecuteInMandatoryGroup", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Priority", New TypeDescription("Number", New NumberQualifiers(2)));
	// For the service model.
	Handlers.Columns.Add("SharedData",             New TypeDescription("Boolean"));
	Handlers.Columns.Add("HandlerManagement", New TypeDescription("Boolean"));
	// For deferred update handlers.
	Handlers.Columns.Add("Comment", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("Id", New TypeDescription("UUID"));
	Handlers.Columns.Add("CheckProcedure", New TypeDescription("String"));
	Handlers.Columns.Add("ObjectsToLock", New TypeDescription("String"));
	Handlers.Columns.Add("NewObjects", New TypeDescription("String"));
	// For the Parallel execution mode of the deferred update.
	Handlers.Columns.Add("UpdateDataFillingProcedure", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("DeferredProcessingQueue",  New TypeDescription("Number", New NumberQualifiers(4)));
	Handlers.Columns.Add("ExecuteInMasterNodeOnly",  New TypeDescription("Boolean"));
	Handlers.Columns.Add("RunAlsoInSubordinateDIBNodeWithFilters",  New TypeDescription("Boolean"));
	Handlers.Columns.Add("ObjectsToRead", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ObjectsToChange", New TypeDescription("String", , New StringQualifiers(0)));
	Handlers.Columns.Add("ExecutionPriorities");
	Handlers.Columns.Add("Multithreaded", New TypeDescription("Boolean"));
	Handlers.Columns.Add("Order", New TypeDescription("EnumRef.OrderOfUpdateHandlers"));
	// For initial population handlers.
	Handlers.Columns.Add("DoNotExecuteWhenSwitchingFromAnotherProgram", New TypeDescription("Boolean"));
	
	// Obsolete. Reverse compatibility with edition 2.2.
	Handlers.Columns.Add("Optional");
	Handlers.Columns.Add("ExclusiveMode");
	
	Return Handlers;
	
EndFunction

// Returns the empty table of execution priorities for deferred handlers
// changing or reading the same data. For using update handlers in descriptions.
//
// Returns:
//  ValueTable:
//    * Order       - String - the order of handlers relative to the specified procedure.
//                               Possible variants: "Before", "After", and "Any".
//    * Id - UUID - an identifier of a procedure to establish relation with.
//    * Procedure     - String - a full name of the procedure by which the handler is executed.
//
// Example:
//  Priority = HandlerExecutionPriorities().Add();
//  Priority.Order = "Before"; // the order of handlers relative to the procedure below.
//  Priority.Procedure = "Document.SalesOrder.UpdateDataForMigrationToNewVersion";
//
Function HandlerExecutionPriorities() Export
	
	Priorities = New ValueTable;
	Priorities.Columns.Add("Order", New TypeDescription("String", , New StringQualifiers(0)));
	Priorities.Columns.Add("Id");
	Priorities.Columns.Add("Procedure", New TypeDescription("String", , New StringQualifiers(0)));
	
	Return Priorities;
	
EndFunction

// Executes handlers from the UpdateHandlers list 
// for LibraryID library update to InfobaseMetadataVersion version.
//
// Parameters:
//   LibraryID   - String       - a configuration name or library ID.
//   IBMetadataVersion        - String       - metadata version to be updated to.
//   UpdateHandlers     - Map - list of update handlers.
//   HandlerExecutionProgress - Structure:
//       * TotalHandlerCount     - String - a total number of handlers being executed.
//       * CompletedHandlersCount - Boolean - a number of completed handlers.
//   SeamlessUpdate     - Boolean       - True if an update is seamless.
//
// Returns:
//   ValueTree   - executed update handlers.
//
Function ExecuteUpdateIteration(Val LibraryID, Val IBMetadataVersion, 
	Val UpdateHandlers, Val HandlerExecutionProgress, Val SeamlessUpdate = False) Export
	
	UpdateIteration = InfobaseUpdateInternal.UpdateIteration(LibraryID, 
		IBMetadataVersion, UpdateHandlers);
		
	Parameters = New Structure;
	Parameters.Insert("HandlerExecutionProgress", HandlerExecutionProgress);
	Parameters.Insert("SeamlessUpdate", SeamlessUpdate);
	Parameters.Insert("InBackground", False);
	
	Return InfobaseUpdateInternal.ExecuteUpdateIteration(UpdateIteration, Parameters);
	
EndFunction

// Runs a non-interactive infobase update.
// Intended to be called through an external connection.
// When calling the method containing extensions that modify the configuration role, an exception will be thrown.
// NOTE: Before calling the method, clean up obsolete patches.
// See the "ConfigurationUpdate.PatchesChanged" function.
// 
// Intended for being used in other libraries and configurations.
//
// Parameters:
//  ExecuteDeferredHandlers1 - Boolean - if True, then a deferred update will be executed
//    in the default update mode. Only for a client-server mode.
//
// Returns:
//  String -  Update handlers runtime status::
//           "Done", "NotRequired", "ExclusiveModeSettingError".
//
Function UpdateInfobase(ExecuteDeferredHandlers1 = False) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSTechnology = Common.CommonModule("CloudTechnology");
		CTLLibraryVersion = ModuleSaaSTechnology.LibraryVersion();
		YesBeforeUpdatingTheInformationBase = InfobaseUpdateInternal.VersionWeight("2.0.0.0") < InfobaseUpdateInternal.VersionWeight(CTLLibraryVersion);
		If YesBeforeUpdatingTheInformationBase Then
			Success = ModuleSaaSTechnology.BeforeUpdateInfobase(ExecuteDeferredHandlers1);
			If Success Then
				Return "Success";
			EndIf;
		EndIf;
	EndIf;
	
	StartDate = CurrentSessionDate();
	Result = InfobaseUpdateInternalServerCall.UpdateInfobase(,,
		ExecuteDeferredHandlers1);
	EndDate = CurrentSessionDate();
	InfobaseUpdateInternal.WriteUpdateExecutionTime(StartDate, EndDate);
	
	Return Result;
	
EndFunction

// Returns a table of subsystem versions used in the configuration.
// The procedure is used for batch import and export of information about subsystem versions.
//
// Returns:
//   ValueTable:
//     * SubsystemName - String - subsystem name.
//     * Version        - String - a subsystem version.
//
Function SubsystemsVersions() Export
	
	StandardProcessing = True;
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		AreaSubsystemVersions = ModuleInfobaseUpdateInternalSaaS.SubsystemsVersions(StandardProcessing);
		If Not StandardProcessing Then
			Return AreaSubsystemVersions;
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubsystemsVersions.SubsystemName AS SubsystemName,
	|	SubsystemsVersions.Version AS Version
	|FROM
	|	InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	Return Query.Execute().Unload();

EndFunction 

// Sets all subsystem versions.
// The procedure is used for batch import and export of information about subsystem versions.
//
// Parameters:
//   SubsystemsVersions - ValueTable:
//     * SubsystemName - String - subsystem name.
//     * Version        - String - a subsystem version.
//
Procedure SetSubsystemVersions(SubsystemsVersions) Export
	
	StandardProcessing = True;
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.WhenInstallingSubsystemVersions(SubsystemsVersions, StandardProcessing);
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.SubsystemsVersions.CreateRecordSet();
	
	For Each Version In SubsystemsVersions Do
		NewRecord = RecordSet.Add();
		NewRecord.SubsystemName = Version.SubsystemName;
		NewRecord.Version = Version.Version;
		NewRecord.IsMainConfiguration = (Version.SubsystemName = Metadata.Name);
	EndDo;
	
	RecordSet.Write();

EndProcedure

// Get configuration or parent configuration (library) version
// that is stored in the infobase.
//
// Parameters:
//  LibraryID   - String - a configuration name or library ID.
//
// Returns:
//   String   - version.
//
// Example:
//   IBConfigurationVersion = IBVersion(Metadata.Name);
//
Function IBVersion(Val LibraryID) Export
	
	Return InfobaseUpdateInternal.IBVersion(LibraryID);
	
EndFunction

// Writes a configuration or parent configuration (library) version to the infobase.
//
// Parameters:
//  LibraryID - String - configuration name or parent configuration (library) name.
//  VersionNumber             - String - a version number.
//  IsMainConfiguration - Boolean - a flag indicating that the LibraryID corresponds to the configuration name.
//
Procedure SetIBVersion(Val LibraryID, Val VersionNumber, Val IsMainConfiguration) Export
	
	InfobaseUpdateInternal.SetIBVersion(LibraryID, VersionNumber, IsMainConfiguration);
	
EndProcedure

// Registers a new subsystem in the SubsystemsVersions information register.
// For instance, it can be used to create a subsystem on
// the basis of already existing metadata without using initial filling handlers.
// If the subsystem is registered, succeeding registration will not be performed.
// This method can be called from the BeforeInfobaseUpdate procedure of the common
// module InfobaseUpdateOverridable.
//
// Parameters:
//  SubsystemName - String - name of a subsystem in the form set in the common module
//                           InfobaseUpdateXXX.
//                           For example - "StandardSubsystems".
//  VersionNumber   - String - full number of a version the subsystem must be registered for.
//                           If the number is not stated, it will be registered for a version "0.0.0.1". It is necessary to indicate
//                           if only last handlers should be executed or all of them.
//
Procedure RegisterNewSubsystem(SubsystemName, VersionNumber = "") Export
	
	StandardProcessing = True;
	If Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		ModuleInfobaseUpdateInternalSaaS.RegisterNewSubsystem(SubsystemName, VersionNumber, StandardProcessing);
	EndIf;
	
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	| SubsystemsVersions.SubsystemName AS SubsystemName
	|FROM
	| InformationRegister.SubsystemsVersions AS SubsystemsVersions";
	
	ConfigurationSubsystems = Query.Execute().Unload().UnloadColumn("SubsystemName");
	
	If ConfigurationSubsystems.Count() > 0 Then
		// This is not the first launch of a program
		If ConfigurationSubsystems.Find(SubsystemName) = Undefined Then
			Record = InformationRegisters.SubsystemsVersions.CreateRecordManager();
			Record.SubsystemName = SubsystemName;
			Record.Version = ?(VersionNumber = "", "0.0.0.1", VersionNumber);
			Record.Write();
		EndIf;
	EndIf;
	
	InformationRecords = InfobaseUpdateInternal.InfobaseUpdateInfo();
	ElementIndex = InformationRecords.NewSubsystems.Find(SubsystemName);
	If ElementIndex <> Undefined Then
		InformationRecords.NewSubsystems.Delete(ElementIndex);
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(InformationRecords);
	EndIf;
	
EndProcedure

// Returns a queue number of a deferred update handler by its full
// name or a UUID.
//
// Parameters:
//  NameOrID - String
//                      - UUID - The full name or id of a deferred update handler.
//                        For details, See NewUpdateHandlerTable
//                        
//                                                  (properties "Procedure" and "ID").
//
// Returns:
//  Number, Undefined - queue number of a passed handler. If
//                        a handler is not found, the Undefined value will be returned.
//
Function DeferredUpdateHandlerQueue(NameOrID) Export
	
	Result = InfobaseUpdateInternalCached.DeferredUpdateHandlerQueue();
	
	If TypeOf(NameOrID) = Type("UUID") Then
		QueueByID = Result["ByID"];
		Return QueueByID[NameOrID];
	Else
		QueueByName = Result["ByName"];
		Return QueueByName[NameOrID];
	EndIf;
	
EndFunction

// Max records quantity in data selection for update.
//
// Returns:
//  Number - constant 1000.
//
Function MaxRecordsCountInSelection() Export
	
	Return 1000;
	
EndFunction

// Returns table with data to update.
// Used in multithread update handlers.
//
// Parameters:
//  Parameters - Structure - the parameter that is passed in update handler.
//
// Returns:
//  ValueTable - For a Ref object with the following columns:
//     * Ref - AnyRef - a reference to the object to be updated.
//     * Date   - Date - the column is present only for documents.
//  
//  ValueTable - for the register, columns depend on the dimensions 
//                     of the object to update.
//
Function DataToUpdateInMultithreadHandler(Parameters) Export
	
	DataSet = Parameters.DataToUpdate.DataSet;
	
	If DataSet.Count() > 0 Then
		Data = DataSet[0].Data.Copy();
		
		For IndexOf = 1 To DataSet.Count() - 1 Do
			Set = DataSet[IndexOf];
			
			For Each SetData In Set.Data Do
				DataString1 = Data.Add();
				FillPropertyValues(DataString1, SetData);
			EndDo;
		EndDo;
		
		If Data.Count() > 0 Then
			Return Data;
		EndIf;
	EndIf;
	
	Return New ValueTable;
	
EndFunction

// Returns the current value of deferred data processing priority.
//
// Returns:
//  String - possible values of DataProcessing and UserWork.
//
Function DeferredProcessingPriority() Export
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	If UpdateInfo.DeferredUpdateManagement.Property("ForceUpdate") Then
		Return "DataProcessing";
	Else
		Return "UserWork";
	EndIf;
EndFunction

// Allows to change the deferred data processing priority.
//
// Parameters:
//  Priority - String - a priority value. Allowed values are DataProcessing and UserWork.
//
Procedure SetDeferredProcessingPriority(Priority) Export
	
	BeginTransaction();
	Try
		Block = New DataLock;
		Block.Add("Constant.IBUpdateInfo");
		Block.Lock();
		
		UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
		If Priority = "DataProcessing" Then
			UpdateInfo.DeferredUpdateManagement.Insert("ForceUpdate");
		Else
			UpdateInfo.DeferredUpdateManagement.Delete("ForceUpdate");
		EndIf;
		
		InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns the number of infobase update threads.
//
// If this number is specified in the UpdateThreadsCount command-line parameter, the parameter is returned.
// Otherwise, the value of the InfobaseUpdateThreadCount constant is returned (if defined).
// Otherwise, returns the default value (see DefaultInfobaseUpdateThreadCount()).
//
// Returns:
//  Number - number of threads.
//
Function UpdateThreadsCount() Export
	Return InfobaseUpdateInternal.InfobaseUpdateThreadCount();
EndFunction

// Allows to set the number of update threads of a deferred data processor.
//
// Parameters:
//  Count - Number - number of threads.
//
Procedure SetUpdateThreadsCount(Count) Export
	Constants.InfobaseUpdateThreadCount.Set(Count);
EndProcedure

// Returns the flag indicating whether multithread updates are allowed.
// You can enable multithread updates in InfobaseUpdateOverridable.OnDefineSettings().
//
// Returns:
//  Boolean - multithread updates are allowed if True. The default value is False (for backward compatibility).
//
Function MultithreadUpdateAllowed() Export
	Return InfobaseUpdateInternal.MultithreadUpdateAllowed();
EndFunction

// Returns data area update progress.
//
// Parameters:
//  UpdateMode - String - defines an update stage to receive data.
//                             Available values: "Seamless" and "Deferred".
//
// Returns:
//  Structure:
//     * Updated3   - Number - the quantity of areas whose update stage is completed.
//     * Running - Number - the quantity of areas being updated.
//     * Waiting1     - Number - the quantity of areas waiting for the update stage start.
//     * Issues    - Number - the quantity of areas where errors occurred during the update.
//     * AreasWithIssues - Array of Number - the numbers of areas where errors occurred during the update.
//     * AreasRunning - Array of Number - the numbers of areas being updated.
//     * AreasWaitingFor     - Array of Number - the numbers of areas waiting for the update stage start.
//     * AreasUpdated   - Array of Number - the numbers of areas whose update stage is completed.
//
Function DataAreasUpdateProgress(UpdateMode) Export
	
	If Not Common.DataSeparationEnabled() 
		Or Not Common.SubsystemExists("CloudTechnology.Core") 
		Or Not Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		Return Undefined;
	EndIf;
	
	UpdateModeOnline = "Nonexclusive";
	UpdateModeDeferred  = "Deferred2";
	
	If UpdateMode = UpdateModeOnline Then
		ExecutionModes = New Array;
		ExecutionModes.Add(Enums.HandlersExecutionModes.Seamless);
		ExecutionModes.Add(Enums.HandlersExecutionModes.Exclusively);
	ElsIf UpdateMode = UpdateModeDeferred Then
		ExecutionModes = CommonClientServer.ValueInArray(
			Enums.HandlersExecutionModes.Deferred);
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect value of the ""%1"" parameter.
				 |Possible values: ""%2"", ""%3""';"), "UpdateMode", UpdateModeOnline, UpdateModeDeferred);
	EndIf;
	
	StatusOrderUpdated = 4;
	TheStateOrderIsPending = 3;
	TheStateOrderIsInProgress = 2;
	ErrorStatusOrder = 1;
	
	Query = New Query;
	
	Query.SetParameter("ExecutionModes", ExecutionModes);
	Query.SetParameter("UpdateMode", UpdateMode);
	Query.SetParameter("UpdateModeOnline", UpdateModeOnline);
	Query.SetParameter("UpdateModeDeferred", UpdateModeDeferred);
	
	Query.SetParameter("StatusOrderUpdated", StatusOrderUpdated);
	Query.SetParameter("TheStateOrderIsInProgress", TheStateOrderIsInProgress);
	Query.SetParameter("TheStateOrderIsPending", TheStateOrderIsPending);
	Query.SetParameter("ErrorStatusOrder", ErrorStatusOrder);
	
	ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
	AreasUpdatedToVersion = ModuleInfobaseUpdateInternalSaaS.AreasUpdatedToVersion(Metadata.Name, Metadata.Version);
	
	ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
	Query.SetParameter("AreasUsed", ModuleSaaSOperations.DataAreasUsed().Unload());
	Query.SetParameter("UpdatedAreas", AreasUpdatedToVersion);
	
	Query.Text =
	"SELECT
	|	AreasUsed.DataArea AS DataArea
	|INTO AreasUsed
	|FROM
	|	&AreasUsed AS AreasUsed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UpdatedAreas.DataAreaAuxiliaryData AS DataAreaAuxiliaryData,
	|	UpdatedAreas.DeferredHandlersRegistrationCompleted AS DeferredHandlersRegistrationCompleted
	|INTO UpdatedAreas
	|FROM
	|	&UpdatedAreas AS UpdatedAreas
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AreasUsed.DataArea AS DataArea,
	|	NOT UpdatedAreas.DataAreaAuxiliaryData IS NULL AS OperationalUpdateCompleted,
	|	NOT UpdatedAreas.DataAreaAuxiliaryData IS NULL
	|		AND NOT UpdatedAreas.DeferredHandlersRegistrationCompleted AS DeferredUpdateHandlersRegistrationRunnin
	|INTO DataAreas
	|FROM
	|	AreasUsed AS AreasUsed
	|		LEFT JOIN UpdatedAreas AS UpdatedAreas
	|		ON (UpdatedAreas.DataAreaAuxiliaryData = AreasUsed.DataArea)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataAreas.DataArea AS DataArea,
	|	MIN(CASE
	|			WHEN &UpdateMode = &UpdateModeOnline
	|					AND DataAreas.OperationalUpdateCompleted
	|				THEN CASE
	|						WHEN DataAreas.DeferredUpdateHandlersRegistrationRunnin
	|							THEN &TheStateOrderIsInProgress
	|						ELSE &StatusOrderUpdated
	|					END
	|			WHEN &UpdateMode = &UpdateModeDeferred
	|					AND NOT DataAreas.OperationalUpdateCompleted
	|				THEN &TheStateOrderIsPending
	|			WHEN &UpdateMode = &UpdateModeDeferred
	|					AND ISNULL(UpdateHandlers.Status, VALUE(Enum.UpdateHandlersStatuses.Completed)) = VALUE(Enum.UpdateHandlersStatuses.Completed)
	|				THEN &StatusOrderUpdated
	|			WHEN UpdateHandlers.Status = VALUE(Enum.UpdateHandlersStatuses.Running)
	|				THEN &TheStateOrderIsInProgress
	|			WHEN UpdateHandlers.Status = VALUE(Enum.UpdateHandlersStatuses.Error)
	|				THEN &ErrorStatusOrder
	|			ELSE &TheStateOrderIsPending
	|		END) AS StatusOrder
	|INTO UpdateStatistics
	|FROM
	|	DataAreas AS DataAreas
	|		LEFT JOIN InformationRegister.UpdateHandlers AS UpdateHandlers
	|		ON (UpdateHandlers.DataAreaAuxiliaryData = DataAreas.DataArea)
	|			AND (UpdateHandlers.ExecutionMode IN (&ExecutionModes))
	|
	|GROUP BY
	|	DataAreas.DataArea
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UpdateStatistics.StatusOrder AS StatusOrder,
	|	UpdateStatistics.DataArea AS DataArea
	|FROM
	|	UpdateStatistics AS UpdateStatistics
	|
	|ORDER BY
	|	DataArea
	|TOTALS
	|	COUNT(DISTINCT DataArea)
	|BY
	|	StatusOrder";
	
	UpdateProgress = InfobaseUpdateInternal.NewProgressInUpdatingDataAreas();
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return UpdateProgress;
	EndIf;
	
	SelectionStatusOrder = Result.Select(QueryResultIteration.ByGroups);
	While SelectionStatusOrder.Next() Do
		
		If SelectionStatusOrder.StatusOrder = StatusOrderUpdated Then
			UpdateProgress.Updated3 = SelectionStatusOrder.DataArea;
			Details = UpdateProgress.AreasUpdated;
		ElsIf SelectionStatusOrder.StatusOrder = TheStateOrderIsInProgress Then
			UpdateProgress.Running = SelectionStatusOrder.DataArea;
			Details = UpdateProgress.AreasRunning;
		ElsIf SelectionStatusOrder.StatusOrder = ErrorStatusOrder Then
			UpdateProgress.Issues = SelectionStatusOrder.DataArea;
			Details = UpdateProgress.AreasWithIssues;
		Else
			UpdateProgress.Waiting1 = SelectionStatusOrder.DataArea;
			Details = UpdateProgress.AreasWaitingFor;
		EndIf;
		
		SelectingAnArea = SelectionStatusOrder.Select();
		While SelectingAnArea.Next() Do
			Details.Add(SelectingAnArea.DataArea);
		EndDo;
		
	EndDo;
	
	Return UpdateProgress;
	
EndFunction

// Returns a table of update handlers by the specified filter.
// In SaaS mode, if the filter by data areas is not set,
// both separated and shared handlers are returned.
// 
// Parameters:
//  Filter - Structure:
//     * ExecutionModes - Array of String - available values match the value names
//                                             of the HandlersExecutionModes enumeration.
//     * Statuses - Array of String - available values match the value names
//                                    of the UpdateHandlersStatuses enumeration.
//     * DataAreas - Array of Number - area numbers to receive handlers.
//
// Returns:
//  ValueTable:
//     * HandlerName - String
//     * ExecutionMode - String - the name of the matching value of the HandlersExecutionModes enumeration
//     * LibraryName - String
//     * Version - String
//     * Status - String - the name of the matching value of the UpdateHandlersStatuses enumeration
//     * ProcessingDuration - Number
//     * ErrorInfo - String
//     * DataArea - Number
//
Function UpdateHandlers(Filter = Undefined) Export
	
	If Filter = Undefined Then
		Filter = New Structure;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UpdateHandlers.HandlerName AS HandlerName,
	|	UpdateHandlers.ExecutionMode AS ExecutionModeLink,
	|	UpdateHandlers.LibraryName AS LibraryName,
	|	UpdateHandlers.Version AS Version,
	|	UpdateHandlers.Status AS StatusLink,
	|	UpdateHandlers.ProcessingDuration AS ProcessingDuration,
	|	UpdateHandlers.ErrorInfo AS ErrorInfo,
	|	UpdateHandlers.DataAreaAuxiliaryData AS DataArea
	|FROM
	|	InformationRegister.UpdateHandlers AS UpdateHandlers
	|WHERE
	|	&ConditionForAreaHandlers
	|
	|UNION ALL
	|
	|SELECT
	|	UpdateHandlers.HandlerName,
	|	UpdateHandlers.ExecutionMode,
	|	UpdateHandlers.LibraryName,
	|	UpdateHandlers.Version,
	|	UpdateHandlers.Status,
	|	UpdateHandlers.ProcessingDuration,
	|	UpdateHandlers.ErrorInfo,
	|	0
	|FROM
	|	InformationRegister.SharedDataUpdateHandlers AS UpdateHandlers
	|WHERE
	|	&ConditionForSharedDataHandlers";
	
	QueryConditions = New Array;
	
	HasFilterRealTimeUpdate = False;
	If Filter.Property("ExecutionModes") Then
		ExecutionModes = New Array;
		For Each EnumValueName In Filter.ExecutionModes Do
			ExecutionMode = InfobaseUpdateInternal.TheValueOfTheEnumerationByName(EnumValueName,
				Metadata.Enums.HandlersExecutionModes);
			ExecutionModes.Add(ExecutionMode);
			If ExecutionMode = Enums.HandlersExecutionModes.Seamless
				Or ExecutionMode = Enums.HandlersExecutionModes.Exclusively Then
				HasFilterRealTimeUpdate = True;
			EndIf;
		EndDo;
		QueryConditions.Add("UpdateHandlers.ExecutionMode IN (&ExecutionModes)");
		Query.SetParameter("ExecutionModes", ExecutionModes);
	EndIf;
	
	HasFilterRunning = False;
	If Filter.Property("Statuses") Then
		Statuses = New Array;
		For Each EnumValueName In Filter.Statuses Do
			Status = InfobaseUpdateInternal.TheValueOfTheEnumerationByName(EnumValueName,
				Metadata.Enums.UpdateHandlersStatuses);
			Statuses.Add(Status);
			If Status = Enums.UpdateHandlersStatuses.Running Then
				HasFilterRunning = True;
			EndIf;
		EndDo;
		QueryConditions.Add("UpdateHandlers.Status IN (&Statuses)");
		Query.SetParameter("Statuses", Statuses);
	EndIf;
	
	If ValueIsFilled(QueryConditions) Then
		ConditionForSharedDataHandlers = StrConcat(QueryConditions, Chars.LF + " And ");
	Else
		ConditionForSharedDataHandlers = "TRUE";
	EndIf;
	
	If Filter.Property("DataAreas") Then
		DataAreas = Filter.DataAreas;
	ElsIf Common.DataSeparationEnabled() Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		DataAreas = ModuleSaaSOperations.DataAreasUsed().Unload().UnloadColumn(
			"DataArea");
	Else
		DataAreas = Undefined;
	EndIf;
	
	If DataAreas <> Undefined Then
		QueryConditions.Add("UpdateHandlers.DataAreaAuxiliaryData IN (&DataAreas)");
		Query.SetParameter("DataAreas", DataAreas);
		If Filter.Property("DataAreas") And Filter.DataAreas.Find(0) = Undefined Then
			ConditionForSharedDataHandlers = "FALSE";
		EndIf;
	EndIf;
	
	If ValueIsFilled(QueryConditions) Then
		ConditionForAreaHandlers = StrConcat(QueryConditions, Chars.LF + " And ");
	Else
		ConditionForAreaHandlers = "TRUE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ConditionForAreaHandlers", ConditionForAreaHandlers);
	Query.Text = StrReplace(Query.Text, "&ConditionForSharedDataHandlers", ConditionForSharedDataHandlers);
	
	HandlersInformation = InfobaseUpdateInternal.NewTableOfInformationAboutHandlers();
	ModeNamesByValue = InfobaseUpdateInternal.NamesByEnumerationValues(Metadata.Enums.HandlersExecutionModes);
	NamesOfStatusesByValue = InfobaseUpdateInternal.NamesByEnumerationValues(Metadata.Enums.UpdateHandlersStatuses);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		String = HandlersInformation.Add();
		FillPropertyValues(String, Selection);
		String.ExecutionMode = ModeNamesByValue[Selection.ExecutionModeLink];
		String.Status = NamesOfStatusesByValue[Selection.StatusLink];
		
	EndDo;
	
	If HasFilterRealTimeUpdate And HasFilterRunning 
		And Common.SubsystemExists("StandardSubsystems.SaaSOperations.IBVersionUpdateSaaS") Then
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule("InfobaseUpdateInternalSaaS");
		UpdatedAreas = ModuleInfobaseUpdateInternalSaaS.AreasUpdatedToVersion(Metadata.Name, Metadata.Version);
		AreasRunningRegistration = UpdatedAreas.FindRows(
			New Structure("DeferredHandlersRegistrationCompleted", False));
		For Each ItemBeingRegistered In AreasRunningRegistration Do
			AreaNumber = ItemBeingRegistered.DataAreaAuxiliaryData;
			If DataAreas <> Undefined And DataAreas.Find(AreaNumber) = Undefined Then
				Continue;
			EndIf;
			String = HandlersInformation.Add();
			String.HandlerName = NStr("en = 'Internal procedures to register deferred handlers';");
			String.ExecutionMode = ModeNamesByValue[Enums.HandlersExecutionModes.Seamless];
			String.LibraryName = "StandardSubsystemsLibrary";
			String.Status = NamesOfStatusesByValue[Enums.UpdateHandlersStatuses.Running];
			String.DataArea = AreaNumber;
		EndDo;
	EndIf;
	
	Return HandlersInformation;
	
EndFunction

// Returns a table of configuration objects to update with a list of handlers
// that update them to the current version.
//
// Returns:
//  Map of KeyAndValue:
//     * Key - String - full object name.
//     * Value - Array of String - names of update handlers to execute.
//
Function UpdatedObjects() Export
	
	Query = New Query;
	Query.SetParameter("ExecutionMode", Enums.HandlersExecutionModes.Deferred);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName,
		|	UpdateHandlers.ObjectsToChange AS ObjectsToChange
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.ExecutionMode = &ExecutionMode";
	Handlers = Query.Execute().Unload();
	UpdatedObjects = New Map;
	For Each Handler In Handlers Do
		ObjectsToChangeInParts = StrSplit(Handler.ObjectsToChange, ",", False);
		For Each ObjectToChange In ObjectsToChangeInParts Do
			ObjectToChange = TrimAll(ObjectToChange);
			If UpdatedObjects[ObjectToChange] = Undefined Then
				UpdatedObjects[ObjectToChange] = New Array;
			EndIf;
			Handlers = UpdatedObjects[ObjectToChange]; // Array
			Handlers.Add(Handler.HandlerName);
		EndDo;
	EndDo;
	
	Return UpdatedObjects;
	
EndFunction

// Adds an obsolete object to a list of objects that should be deleted during updates.
// 
//
// Parameters:
//  Objects - Map of KeyAndValue:
//   * Key - String - See the "Object" parameter below.
//   * Value - Boolean, Map - See the "Refinement" parameter below.
//
//  Object - String - Takes either of the following values:
//     - The full name of the metadata object that should be cleared.
//     - A metadata object with a main table. For example, "Catalog.DeleteJobsQueue".
//     - A enumeration member. For example, "Enum.BusinessTransactions.DeleteWriteOffGoodsTransferredToPartners".
//     - A route point. For example, "BusinessProcess.Job.RoutePoint.DeleteReturnToAssignee".
//     - All points of a route. For example, "BusinessProcess.Job.Points".
//     - A register field included in a unique index. For example, "InformationRegister.PersonsResponsible.Warehouse".
//
//  Refinement - Boolean - In cases where the "Object" parameter contains an obsolete object.
//               The object's name must start with "Delete".
//               If set to True, the object data will be deleted. By default, False.
//            - TypeDescription, Type, EnumRef, BusinessProcessRoutePointRef - 
//               In cases where the "Object" parameter contains a field whose type
//               must be reduced by either a list of reference types, a single type,
//               a enumeration member value, or a business process' route point value.
//
Procedure AddObjectPlannedForDeletion(Objects, Object, Refinement = False) Export
	
	If TypeOf(Refinement) = Type("Boolean") Then
		Objects.Insert(Object, Refinement);
	Else
		ReducedTypesAndValues = Objects.Get(Object);
		If ReducedTypesAndValues = Undefined Then
			ReducedTypesAndValues = New Map;
			Objects.Insert(Object, ReducedTypesAndValues);
		EndIf;
		If TypeOf(Refinement) = Type("TypeDescription") Then
			For Each Type In Refinement.Types() Do
				ReducedTypesAndValues.Insert(Type, True);
			EndDo;
		Else
			ReducedTypesAndValues.Insert(Refinement, True);
		EndIf;
	EndIf;
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.GetApplicationUpdates

// Returns status of deferred update handlers.
//
// Returns:
//  String - an empty string if all handlers are executed successfully.
//           "UncompletedStatus" - some handlers are not executed.
//           "ErrorStatus" - all handlers are completed, but there is at least one handler with an error.
//           "StatusSuspended" - all handlers are completed, but there is at least one suspended handler.
//
Function DeferredUpdateStatus() Export
	
	Return InfobaseUpdateInternal.UncompletedHandlersStatus();
	
EndFunction

// End OnlineUserSupport.GetApplicationUpdates

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Initial data population.

#Region FillPredefinedItems

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Register predefined items to update in the update handler.
//
// Parameters:
//  Parameters        - Structure - update handler service parameters.
//  MetadataObject - MetadataObject
//                   - Undefined - objects to be updated
//  AdditionalParameters - Structure:
//   *  UpdateMode  - String - defines registration options of predefined items to update. Options:
//                              All - registers all predefined items;
//                              NewAndChanged - updates only new and changed items;
//                              MultilingualStrings - if changes were made in multilanguage attributes.
//   * SkipEmpty  - Boolean -  if True, empty strings in default master data are excluded from the check for changes.
//                            For example, an object will not be registered when an attribute in the infobase is filled in, and the code contains an empty string.
//   * CompareTabularSections - Boolean - if False, tabular sections are ignored and not compared for differences.
//
Procedure RegisterPredefinedItemsToUpdate(Parameters, MetadataObject = Undefined, AdditionalParameters = Undefined) Export
	
	InfobaseUpdateInternal.RegisterPredefinedItemsToUpdate(Parameters, MetadataObject, AdditionalParameters);
	
EndProcedure

// Fills in predefined object items in the update handler with default master data.
//
// Parameters:
//  Parameters           - Structure- update handler service parameters.
//  MetadataObject    - MetadataObject - Object to populate.
//  PopulationSettings - See PopulationSettings
//
Procedure FillItemsWithInitialData(Parameters, MetadataObject, PopulationSettings = Undefined) Export
	
	// Backward compatibility.
	If TypeOf(PopulationSettings) = Type("Boolean") Then
		UpdateMultilanguageStrings = PopulationSettings;
		PopulationSettings = PopulationSettings();
		PopulationSettings.UpdateMultilingualStringsOnly = UpdateMultilanguageStrings;
	ElsIf PopulationSettings = Undefined Then
		PopulationSettings = PopulationSettings();
	EndIf;
	
	InfobaseUpdateInternal.FillItemsWithInitialData(Parameters, MetadataObject, PopulationSettings);
	
EndProcedure

// Populate the object with the predefined data from the initial population code block.
// 
// Parameters:
//  ObjectToFillIn - CatalogObject
//                    - ChartOfCharacteristicTypesObject - Object to populate.
//  PopulationSettings - See PopulationSettings
// 
Procedure FillObjectInitialData(ObjectToFillIn, PopulationSettings) Export
	
	InfobaseUpdateInternal.FillObjectInitialData(ObjectToFillIn, PopulationSettings);
	
EndProcedure

// Updates the predefined data with the data from the initial population code.
// 
// Parameters:
//  MetadataObject - MetadataObject - The objects containing the predefined items.
//  ParametersOfUpdate - See PredefinedItemsUpdateParameters
//                      - Undefined - Update all the predefined items.
//
Procedure DoUpdatePredefinedItems(MetadataObject, ParametersOfUpdate = Undefined) Export
	
	PredefinedItemsUpdateParameters = ?(ParametersOfUpdate = Undefined,
		PredefinedItemsUpdateParameters(), ParametersOfUpdate);
	InfobaseUpdateInternal.UpdateObjectPredefinedItems(MetadataObject, PredefinedItemsUpdateParameters);
	
EndProcedure

// The parameter constructor used in the "DoUpdatePredefinedItems" procedure.
//
// Returns:
//  Structure:
//    * Attributes - String - Comma-delimited list of attributes that should be force-updated.
//    * Items - Array - A list of predefined items that should be updated.
//                          If an empty list is passed, all predefined items will be updated.
//    * UpdateMultilingualStringsOnly - Boolean - If set to "True", update only multi-language attributes.
//                                                   By default, "False". Applicable only to multi-language configurations.
//                                                    
//
Function PredefinedItemsUpdateParameters() Export
	
	Result = New Structure;
	Result.Insert("Attributes", "");
	Result.Insert("Items", New Array);
	Result.Insert("UpdateMultilingualStringsOnly", False);
	
	Return Result;
	
EndFunction 

// Population settings for predefined and built-in items.
// 
// Returns:
//  Structure:
//   * UpdateMultilingualStringsOnly - Boolean - if True, only multilingual strings will be updated.
//   * Attributes - String - A comma-delimited list of attributes to update. For example, "Description,Comment".
//
Function PopulationSettings() Export
	
	Result = New Structure;
	Result.Insert("UpdateMultilingualStringsOnly", False);
	Result.Insert("Attributes", "");

	Return Result;
	
EndFunction

#EndRegion

// Logs an event when update handler is running.
// When writing an error or warning, saves it to the update handler information.
// This records are used in update mechanics interfaces.
//
// Parameters:
//  Ref_Metadata - AnyRef, MetadataObject - A reference for Ref data. A metadata object for other data types.
//  Presentation    - String - The String presentation of the data. For Ref data, it should be obtained prior to processing.
//                                 (If it is obtained in the Except clause, it might cause en error.)
//  ErrorInfo - ErrorInfo, String - To log an error, pass the "ErrorInfo" object.
//                                 To clarify the issue, pass a String comment.
//                                 
//  Level - EventLogLevel - A log level. If not specified, set the level to "Error".
//
Procedure WriteErrorToEventLog(Ref_Metadata, Val Presentation, ErrorInfo = Undefined, Level = Undefined) Export
	
	Data = Undefined;
	MetadataObject = Undefined;
	If Common.IsReference(TypeOf(Ref_Metadata)) Then
		Data = Ref_Metadata;
		MetadataObject = Ref_Metadata.Metadata();
	Else
		MetadataObject = Ref_Metadata;
	EndIf;
	
	ErrorText = "";
	If TypeOf(ErrorInfo) = Type("String") Then
		ErrorText = ErrorInfo;
	Else
		ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo);
	EndIf;
	
	If Not ValueIsFilled(Presentation) Then
		Presentation = MetadataObject.Name;
	EndIf;
	
	MessageText = NStr("en = 'Couldn''t process ""%1"" due to:
		|%2';");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
		Presentation,
		ErrorText);
	
	WriteLogEvent(EventLogEvent(),
		EventLogLevel.Warning,
		MetadataObject,
		Data,
		MessageText);
	
	HandlerName = SessionParameters.UpdateHandlerParameters.HandlerName;
	If Level = EventLogLevel.Error
		Or Level = Undefined Then
		InfobaseUpdateInternal.AddErrorInformationInHandler(HandlerName);
	ElsIf Level = EventLogLevel.Warning Then
		InfobaseUpdateInternal.AddErrorInformationInHandler(HandlerName);
	EndIf;
	
EndProcedure

// Logs an event when update handler is running.
// When writing an error or warning, saves it to the update handler information.
// This records are used in update mechanics interfaces.
//
// Parameters:
//  Comment - String - Error message to write to the Event log.
//  Level     - EventLogLevel - Event severity level.
//                If not specified, an Error event will be written.
//  Parameters   - Structure - Input parameters passed to the update handler.
//
Procedure WriteEventToRegistrationLog(Comment, Level = Undefined, Parameters = Undefined) Export
	
	If TypeOf(Parameters) = Type("Structure")
		And Parameters.Property("HandlerName") Then
		HandlerName = Parameters.HandlerName;
	Else
		HandlerName = SessionParameters.UpdateHandlerParameters.HandlerName;
	EndIf;
	
	If Level = EventLogLevel.Error
		Or Level = Undefined Then
		InfobaseUpdateInternal.AddErrorInformationInHandler(HandlerName);
		InfobaseUpdateInternal.WriteError(Comment);
	ElsIf Level = EventLogLevel.Warning Then
		InfobaseUpdateInternal.AddErrorInformationInHandler(HandlerName);
		InfobaseUpdateInternal.WriteWarning(Comment);
	Else
		InfobaseUpdateInternal.WriteInformation(Comment);
	EndIf;
	
EndProcedure

// Restarts deferred update handlers in an infobase where real-time and standalone handling has already completed.
// Intended for cases when update handlers or registration procedures were modified.
// Does the following:
// - Stops the scheduled job of this deferred update.
// - Re-registers the data to update:
//
// - By default, for pending handlers.
//  - For passed update handlers from the list or handlers required to update to the version.
//  - To do so, in the filter, pass the "Handlers" parameter.
//    - Handlers that update subsystems from the current version. Including the completed handlers.
//    - To do so, in the filter, pass the "Subsystems" parameter.
//      The parameter must contain subsystem names and versions.
//    - Starts a deferred update scheduled job.
//      
//      
//  
//
// Parameters:
//  Filter - Structure:
//             * Key     - String - Subsystem name.
//             * Value - String - Version number.
//        - Array - Names of update handlers to be re-started.
//
Procedure RelaunchDeferredUpdate(Filter = Undefined) Export
	
	If Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	If TypeOf(Filter) = Type("Structure")
		And Filter.Count() = 0 Then
		Raise NStr("en = 'The dataset is missing the list of subsystems that require restart of deferred handlers.';");
	EndIf;
	
	// Deferred update handlers.
	InfobaseUpdateInternal.OnEnableDeferredUpdate(False);
	
	If Not Common.DataSeparationEnabled() Then
		JobsFilter = New Structure;
		JobsFilter.Insert("MethodName", "InfobaseUpdateInternal.ExecuteDeferredUpdate");
		JobsFilter.Insert("State", BackgroundJobState.Active);
		FoundJobs = BackgroundJobs.GetBackgroundJobs(JobsFilter);
		For Each UpdateJob In FoundJobs Do
			If UpdateJob.State = BackgroundJobState.Active Then
				UpdateJob.Cancel();
			EndIf;
		EndDo;
	EndIf;
	
	Groups = InfobaseUpdateInternal.NewDetailsOfDeferredUpdateHandlersThreadsGroups();
	InfobaseUpdateInternal.CancelAllThreadsExecution(Groups);
	
	// Re-register data.
	RequestTemporary = New Query;
	RequestTemporary.Text =
		"SELECT
		|	InfobaseUpdate.Ref AS Ref
		|FROM
		|	ExchangePlan.InfobaseUpdate AS InfobaseUpdate
		|WHERE
		|	InfobaseUpdate.Temporary = TRUE";
	
	Block = New DataLock;
	LockItem = Block.Add("ExchangePlan.InfobaseUpdate");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		TempQueues = RequestTemporary.Execute().Unload();
		For Each TempQueue In TempQueues Do
			ExchangePlans.DeleteChangeRecords(TempQueue.Ref);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	LockedObjectsInfo = InfobaseUpdateInternal.LockedObjectsInfo();
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("OnClientStart", False);
	RegistrationParameters.Insert("UpdateRestart", True);
	
	// List of pending handlers.
	Query = New Query;
	Query.SetParameter("HandlerExecutionMode", Enums.DeferredHandlersExecutionModes.Parallel);
	Query.SetParameter("Status", Enums.UpdateHandlersStatuses.Completed);
	Query.Text =
		"SELECT
		|	UpdateHandlers.HandlerName AS HandlerName
		|FROM
		|	InformationRegister.UpdateHandlers AS UpdateHandlers
		|WHERE
		|	UpdateHandlers.DeferredHandlerExecutionMode = &HandlerExecutionMode
		|	AND UpdateHandlers.Status <> &Status";
	
	If TypeOf(Filter) = Type("Array") Then
		RegistrationParameters.Insert("RegisteredHandlers", Filter);
		For Each Handler In Filter Do
			ResetHandlerState(Handler);
			
			HandlerInfo = LockedObjectsInfo.Handlers[Handler];
			If HandlerInfo <> Undefined Then
				LockedObjectsInfo.Handlers[Handler].Completed = False;
			EndIf;
		EndDo;
		
		IncompleteHandlers = Query.Execute().Unload();
		For Each IncompleteHandler In IncompleteHandlers Do
			ResetHandlerState(IncompleteHandler.HandlerName);
			
			HandlerInfo = LockedObjectsInfo.Handlers[Handler];
			If HandlerInfo <> Undefined Then
				LockedObjectsInfo.Handlers[Handler].Completed = False;
			EndIf;
		EndDo;
	ElsIf TypeOf(Filter) = Type("Structure") Then
		UpdateIterations = InfobaseUpdateInternal.UpdateIterations();
		For Each UpdateIteration In UpdateIterations Do
			If Filter.Property(UpdateIteration.Subsystem) Then
				UpdateIteration.PreviousVersion = Filter[UpdateIteration.Subsystem];
			EndIf;
		EndDo;
		
		DataProcessors.UpdateHandlersDetails.FillQueueNumber(UpdateIterations);
		InfobaseUpdateInternal.UpdateListOfUpdateHandlersToExecute(UpdateIterations, False, "Deferred3");
		
	EndIf;
	
	InfobaseUpdateInternal.WriteLockedObjectsInfo(LockedObjectsInfo);
	InfobaseUpdateInternal.FillDataForParallelDeferredUpdate1(RegistrationParameters);
	
	// Re-obtain temporary queues if they were added.
	TempQueues = RequestTemporary.Execute().Unload();
	
	// Copy queues.
	DataLock = New DataLock;
	LockItem = DataLock.Add("ExchangePlan.InfobaseUpdate");
	LockItem.DataSource = TempQueues;
	LockItem.UseFromDataSource("Ref", "Ref");
	BeginTransaction();
	Try
		DataLock.Lock();
		
		For Each TempQueue In TempQueues Do
			TempQueueObject = TempQueue.Ref.GetObject();
			Queue = TempQueueObject.Queue;
			
			MainQueue = QueueRef(Queue);
			MainQueueObject = MainQueue.GetObject();
			
			TempQueueObject.Description = XMLString(Queue);
			TempQueueObject.Temporary = False;
			
			MainQueueObject.Description = XMLString(Queue) + " " + NStr("en = 'Old after restart';");
			MainQueueObject.Temporary = True;
			
			TempQueueObject.Write();
			MainQueueObject.Write();
			
			ExchangePlans.DeleteChangeRecords(MainQueue);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	UpdateInfo = InfobaseUpdateInternal.InfobaseUpdateInfo();
	UpdateInfo.DeferredUpdateCompletedSuccessfully = Undefined;
	UpdateInfo.DeferredUpdatesEndTime = Undefined;
	UpdateInfo.CurrentUpdateIteration = 1;
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(UpdateInfo);
	
	If Not Common.DataSeparationEnabled() Then
		Constants.OrderOfDataToProcess.Set(Enums.OrderOfUpdateHandlers.Crucial);
	EndIf;
	
	Constants.DeferredUpdateCompletedSuccessfully.Set(False);
	If Not Common.IsSubordinateDIBNode() Then
		Constants.DeferredMasterNodeUpdateCompleted.Set(False);
	EndIf;
	
	InfobaseUpdateInternal.OnEnableDeferredUpdate(True);
	
EndProcedure

// Restarts standalone (real-time) update handlers in an infobase where real-time (standalone) handling has already completed.
// 
//
// Parameters:
//  Filter - Structure:
//    * Key     - String - Subsystem name.
//    * Value - String - Version number.
//
Procedure RestartExclusiveUpdate(Filter) Export
	
	UpdateIterations = InfobaseUpdateInternal.UpdateIterations();
	VersionsInstalled = False;
	For Each UpdateIteration In UpdateIterations Do
		If Filter.Property(UpdateIteration.Subsystem) Then
			UpdateIteration.PreviousVersion = Filter[UpdateIteration.Subsystem];
			VersionsInstalled = True;
		EndIf;
	EndDo;
	
	If Not VersionsInstalled Then
		Return;
	EndIf;
	
	DataProcessors.UpdateHandlersDetails.FillQueueNumber(UpdateIterations);
	InfobaseUpdateInternal.UpdateListOfUpdateHandlersToExecute(UpdateIterations, False, "Monopoly");
	
	HandlerExecutionProgress = New Structure;
	HandlerExecutionProgress.Insert("TotalHandlerCount", 0);
	HandlerExecutionProgress.Insert("CompletedHandlersCount", 0);
	
	Parameters = New Structure;
	Parameters.Insert("HandlerExecutionProgress", HandlerExecutionProgress);
	Parameters.Insert("SeamlessUpdate", False);
	Parameters.Insert("InBackground", False);
	Parameters.Insert("MarkRegisterData", True);
	
	For Each UpdateIteration In UpdateIterations Do
		InfobaseUpdateInternal.ExecuteUpdateIteration(UpdateIteration, Parameters);
	EndDo;
	
EndProcedure

// Registers data issues found during update in the "Data integrity" subsystem.
//
// Parameters:
//  ObjectWithIssue - AnyRef - Object in which the issue is found.
//  IssueSummary - String - Issue description.
//  Parameters - Structure - Input parameters passed to the update handler.
//
Procedure FileIssueWithData(ObjectWithIssue, IssueSummary, Parameters = Undefined) Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		Return;
	EndIf;
	
	If TypeOf(Parameters) = Type("Structure")
		And Parameters.Property("HandlerName") Then
		HandlerName = Parameters.HandlerName;
	Else
		HandlerName = SessionParameters.UpdateHandlerParameters.HandlerName;
	EndIf;
	
	ModuleAccountingAudit          = Common.CommonModule("AccountingAudit");
	ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
	
	CheckExecutionParameters = ModuleAccountingAudit.CheckExecutionParameters("IBVersionUpdate", HandlerName);
	CheckKind = ModuleAccountingAudit.CheckKind(CheckExecutionParameters);
	Validation    = ModuleAccountingAudit.CheckByID("InfoBaseUpdateProblemWithData");
	
	CheckParameters = ModuleAccountingAuditInternal.PrepareCheckParameters(Validation, Undefined);
	
	Issue1 = ModuleAccountingAudit.IssueDetails(ObjectWithIssue, CheckParameters);
	Issue1.CheckKind = CheckKind;
	Issue1.IssueSummary = IssueSummary;
	
	TemplateEntryToLog = NStr("en = 'An issue found in object ""%2"" when running handler ""%1"".
		|Issue details:
		|%3';");
	
	TextToWriteToLog = StringFunctionsClientServer.SubstituteParametersToString(TemplateEntryToLog,
		HandlerName, ObjectWithIssue, IssueSummary);
	InfobaseUpdateInternal.WriteWarning(TextToWriteToLog);
	
	ModuleAccountingAudit.WriteIssue(Issue1, CheckParameters);
	
EndProcedure

// Allows you to toggle deferred update. In on-prem, controls the "Use" flag of the DeferredIBUpdate scheduled job.
// In SaaS, controls the queue job.
//
// Parameters:
//  Use - Boolean - If True, deferred update is enabled.
//
Procedure EnableDisableDeferredUpdate(Use) Export
	
	InfobaseUpdateInternal.OnEnableDeferredUpdate(Use);
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

// Obsolete: no longer required as the actions are executed automatically by an update feature.
// 
// Removes a deferred handler from the handler execution queue for the new version.
// It is recommended for use in cases, such as switching from a deferred handler execution mode
// to an exclusive (seamless) one.
// To perform this action, add a new separate update handler of a
// "Seamless" execution mode and a "SharedData = False" flag, and place a call for this method in it.
//
// Parameters:
//  HandlerName - String - full procedure name of a deferred handler.
//
Procedure DeleteDeferredHandlerFromQueue(HandlerName) Export
	Return;
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure AddAdditionalSourceLockCheck(Queue, QueryText, FullObjectName, FullRegisterName, TempTablesManager, IsTemporaryTableCreation, AdditionalParameters)
	
	If AdditionalParameters.AdditionalDataSources.Count() = 0 Then
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRefs", "TRUE");
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", "TRUE");
	Else
		AdditionalSourcesRefs = New Array;
		AdditionalSourcesRegisters = New Array;
		
		For Each KeyValue In AdditionalParameters.AdditionalDataSources Do
			DataSource = KeyValue.Key;
			
			If StandardSubsystemsServer.IsRegisterTable(DataSource) And StrFind(DataSource,".") <> 0 Then
				AdditionalSourcesRegisters.Add(DataSource);
			Else
				AdditionalSourcesRefs.Add(DataSource);
			EndIf;
		EndDo;
		
#Region AdditionalSourcesRefs
		
		If AdditionalSourcesRefs.Count() > 0 Then
			If FullObjectName = Undefined Then
				ExceptionText = NStr("en = '%FunctionName% function call error: additional data sources were passed without a document name.';");
				ExceptionText = StrReplace(ExceptionText, "%FunctionName%", "InfobaseUpdate.AddAdditionalSourceLockCheck");
				Raise ExceptionText;
			EndIf;
			
			MetadataOfDocument = Common.MetadataObjectByFullName(FullObjectName);
			TemporaryTablesOfLockedAdditionalSources = New Map;
			HeaderAttributes = New Map;
			TSAttributes = New Map;
			
			For Each DataSource In AdditionalSourcesRefs Do
				TheCompositionOfTheDataSource = CompositionOfTheReferenceDataSource(DataSource);
				TSName = TheCompositionOfTheDataSource.TabularSection;
				AttributeName = TheCompositionOfTheDataSource.Attribute;
				
				If ValueIsFilled(TSName) Then
					SourceTypes = MetadataOfDocument.TabularSections[TSName].Attributes[AttributeName].Type.Types();
				Else
					SourceTypes = MetadataOfDocument.Attributes[AttributeName].Type.Types();
				EndIf;
				
				For Each SourceType In SourceTypes Do
					If IsPrimitiveType(SourceType) Or IsEnum(SourceType) Then
						Continue;
					EndIf;
					
					SourceMetadata = Metadata.FindByType(SourceType);
					
					If ValueIsFilled(TSName) Then
						Metadata_Attributes = TheValueForTheKey(TSAttributes, TSName);
						Attributes = TheValueForTheKey(Metadata_Attributes, SourceMetadata);
						Attributes[AttributeName] = True;
					Else
						Attributes = TheValueForTheKey(HeaderAttributes, SourceMetadata);
						Attributes[AttributeName] = True;
					EndIf;
					
					LockedAdditionalSourceTTName = TemporaryTablesOfLockedAdditionalSources[SourceMetadata];
					
					If LockedAdditionalSourceTTName = Undefined Then
						FullSourceName = SourceMetadata.FullName();
						LockedAdditionalSourceTTName = "TTLocked" + StrReplace(FullSourceName,".","_");
						TemporaryTablesOfLockedAdditionalSources[SourceMetadata] = LockedAdditionalSourceTTName;
						AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
						AdditionalParametersForTTCreation.TempTableName = LockedAdditionalSourceTTName;
						CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, // @skip-check query-in-loop - Batch verification of locked data.
							FullSourceName,
							TempTablesManager,
							AdditionalParametersForTTCreation); 
					EndIf;
				EndDo;
			EndDo;
			
			ConditionsForAdditionalSourcesLinks = New Array;
			ConditionSeparatorForAdditionalSourcesLinks =
				"
				|	AND ";
			
			If TSAttributes.Count() > 0 Then
				Query = New Query;
				Query.Text = RequestTextInTBlockedByPM(TSAttributes,
					FullObjectName,
					FullRegisterName,
					TemporaryTablesOfLockedAdditionalSources);
				Query.TempTablesManager = TempTablesManager;
				Query.Execute();
				
				ConditionsForAdditionalSourcesLinks.Add(TextOfTheConditionBlockedByPM(FullObjectName, FullRegisterName));
				TemporaryTablesOfLockedAdditionalSources["LockedByTabularSection"] = "LockedByTabularSection";
			EndIf;
			
			If HeaderAttributes.Count() > 0 Then
				TheTermsBlockedOnTheCap = TextOfTheConditionBlockedByHeader(HeaderAttributes,
					FullRegisterName,
					TemporaryTablesOfLockedAdditionalSources);
				ConditionsForAdditionalSourcesLinks.Add(TheTermsBlockedOnTheCap);
			EndIf;
			
			ConditionByAdditionalSourcesRefs = StrConcat(ConditionsForAdditionalSourcesLinks,
				ConditionSeparatorForAdditionalSourcesLinks);
			
			QueryTexts = New Array;
			QueryTexts.Add(QueryText);
			AddRequestsToDeleteTUES(QueryTexts, TemporaryTablesOfLockedAdditionalSources);
			QueryText = CombineRequestsIntoABatch(QueryTexts);
			
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRefs", ConditionByAdditionalSourcesRefs);
			QueryText = StrReplace(QueryText, "#FullDocumentName", FullObjectName);
		Else
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRefs", "TRUE");
		EndIf;
#EndRegion
		
#Region AdditionalSourcesRegisters

		If AdditionalSourcesRegisters.Count() > 0 Then
			
			ConditionByAdditionalSourcesRegisters = "TRUE";
			
			TemporaryTablesOfLockedAdditionalSources = New Map;
			
			For Each DataSource In AdditionalSourcesRegisters Do
				SourceMetadata = Common.MetadataObjectByFullName(DataSource);
				
				If Common.IsInformationRegister(SourceMetadata)
					And SourceMetadata.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					ExceptionText = NStr("en = 'The %DataSource% register is independent. The check supports only registers that are subordinate to recorders.';");
					ExceptionText = StrReplace(ExceptionText, "%DataSource%",DataSource);
					Raise ExceptionText;
				EndIf;
				
				LockedAdditionalSourceTTName = TemporaryTablesOfLockedAdditionalSources.Get(SourceMetadata);
				
				If LockedAdditionalSourceTTName = Undefined Then
					LockedAdditionalSourceTTName = "TTLocked" + StrReplace(DataSource,".","_");
					
					AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
					AdditionalParametersForTTCreation.TempTableName = LockedAdditionalSourceTTName;
					CreateTemporaryTableOfDataProhibitedFromReadingAndEditing(Queue, DataSource, TempTablesManager, AdditionalParametersForTTCreation); // @skip-check query-in-loop - Batch verification of locked data.
					
					TemporaryTablesOfLockedAdditionalSources.Insert(SourceMetadata, LockedAdditionalSourceTTName);
				EndIf;
			EndDo;
			
			QueryTexts = New Array;
			QueryTexts.Add(QueryText);
			AddRequestsToDeleteTUES(QueryTexts, TemporaryTablesOfLockedAdditionalSources);
			QueryText = CombineRequestsIntoABatch(QueryTexts);
			
			ConditionByAdditionalSourcesRegisters = TextOfTheConditionBlockedByRegisters(FullRegisterName,
				TemporaryTablesOfLockedAdditionalSources);
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", ConditionByAdditionalSourcesRegisters);
		Else
			QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRegisters", "TRUE");
		EndIf;
#EndRegion
	EndIf;	
EndProcedure

Function IsPrimitiveType(TypeToCheck)
	
	If TypeToCheck = Type("Undefined")
		Or TypeToCheck = Type("Boolean")
		Or TypeToCheck = Type("String")
		Or TypeToCheck = Type("Number")
		Or TypeToCheck = Type("Date")
		Or TypeToCheck = Type("UUID") Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

Procedure AddAdditionalSourceLockCheckForStandaloneRegister(Queue, QueryText, FullRegisterName, TempTablesManager, AdditionalParameters)
	
	If AdditionalParameters.AdditionalDataSources.Count() = 0 Then
		
		QueryText = StrReplace(QueryText, "#ConnectionToAdditionalSourcesQueryText", "");
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRefs", "TRUE");
	
	Else
		
		RegisterMetadata = Common.MetadataObjectByFullName(FullRegisterName);
		ConditionsForAdditionalSourcesLinks = New Array;
		TemplateConditionsForAdditionalSourcesLinks =
			"	NOT TRUE IN (
			|		SELECT TOP 1
			|			TRUE
			|		FROM
			|			%1 AS %1
			|		WHERE
			|			ChangesTable.%2 = %1.Ref)";
		
		For Each KeyValue In AdditionalParameters.AdditionalDataSources Do
			
			DataSource = KeyValue.Key;
			
			SourceTypes = RegisterMetadata.Dimensions[DataSource].Type.Types();
			MetadataObjectsArray = New Array;
			
			For Each SourceType In SourceTypes Do
				
				If IsPrimitiveType(SourceType) Or IsEnum(SourceType) Then
					Continue;
				EndIf;
				
				MetadataObjectsArray.Add(Metadata.FindByType(SourceType));
				
			EndDo;
			
			AdditionalParametersForTTCreation = AdditionalProcessingDataSelectionParameters();
			TempTableName = "TTLocked" + DataSource;
			AdditionalParametersForTTCreation.TempTableName = TempTableName;
			
			CreateTemporaryTableOfRefsProhibitedFromReadingAndEditing(Queue, MetadataObjectsArray, TempTablesManager, AdditionalParametersForTTCreation); // @skip-check query-in-loop - Batch verification of locked data.
			
			ConditionByAdditionalSourcesRefs = StringFunctionsClientServer.SubstituteParametersToString(
				TemplateConditionsForAdditionalSourcesLinks,
				TempTableName,
				DataSource);
			ConditionsForAdditionalSourcesLinks.Add(ConditionByAdditionalSourcesRefs);
		EndDo;
		
		SeparatorAnd =
			"
			|	AND ";
		ConditionByAdditionalSourcesRefs = StrConcat(ConditionsForAdditionalSourcesLinks, SeparatorAnd);
		QueryText = StrReplace(QueryText, "&ConditionByAdditionalSourcesRefs", ConditionByAdditionalSourcesRefs);

	EndIf;
EndProcedure

Procedure SetMissingFiltersInSet(Set, SetMetadata, FiltersToSet)
	For Each Dimension In SetMetadata.Dimensions Do
		
		HasFilterByDimension = False;
		
		If TypeOf(FiltersToSet) = Type("ValueTable") Then
			HasFilterByDimension = FiltersToSet.Columns.Find(Dimension.Name) <> Undefined;
		Else //Filter
			HasFilterByDimension = FiltersToSet[Dimension.Name].Use;	
		EndIf;
		
		If Not HasFilterByDimension Then
			EmptyValue = Dimension.Type.AdjustValue();
			Set.Filter[Dimension.Name].Set(EmptyValue);
		EndIf;
	EndDo;
	
	If SetMetadata.MainFilterOnPeriod Then
		
		If TypeOf(FiltersToSet) = Type("ValueTable") Then
			HasFilterByDimension = FiltersToSet.Columns.Find("Period") <> Undefined;
		Else //Filter
			HasFilterByDimension = FiltersToSet.Period.Use;
		EndIf;
		
		If Not HasFilterByDimension Then
			EmptyValue = '00010101';
			Set.Filter.Period.Set(EmptyValue);
		EndIf;
		
	EndIf;
EndProcedure

// Record changes of one data item as it was before the optimization.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Node - ExchangePlanRef.InfobaseUpdate
//  Data - AnyRef
//         - InformationRegisterRecordSet
//         - AccumulationRegisterRecordSet
//         - AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet
//  DataKind - String
//  FullObjectName - String
//
Procedure RecordChanges(Parameters, Node, Data, DataKind, FullObjectName = "")
	
	RegistrationParameters = NewRegistrationParameters(Parameters, Node, DataKind, FullObjectName);
	RegisterChangesToADataItem(Data, RegistrationParameters);
	CompleteDataPortionRegistration(RegistrationParameters);
	
EndProcedure

// Record changes of one or several references.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Node - ExchangePlanRef.InfobaseUpdate
//  References - AnyRef
//         - Array of AnyRef
//  DataKind - String
//  FullObjectName - String
//
Procedure RegisterObjectChanges(Parameters, Node, References, DataKind, FullObjectName = "")
	
	RegistrationParameters = NewRegistrationParameters(Parameters, Node, DataKind, FullObjectName);
	
	For Each Ref In ItemArray(References) Do
		If Ref.IsEmpty() Then
			Continue;
		EndIf;
		
		RegisterChangesToADataItem(Ref, RegistrationParameters);
	EndDo;
	
	CompleteDataPortionRegistration(RegistrationParameters);
	
EndProcedure

// Record changes of the subordinate register by the specified recorders.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Node - ExchangePlanRef.InfobaseUpdate
//  Recorders - AnyRef
//               - Array of AnyRef
//  DataKind - String
//  FullObjectName - String
//
Procedure RegisterChangesToTheSubordinateRegister(Parameters, Node, Recorders, DataKind, FullObjectName)
	
	RegistrationParameters = NewRegistrationParameters(Parameters, Node, DataKind, FullObjectName);
	
	For Each Recorder In ItemArray(Recorders) Do
		Set = GetAReusedSet(RegistrationParameters.ReusedSets);
		Set.Filter.Recorder.Set(Recorder);
		
		RegisterChangesToADataItem(Set, RegistrationParameters);
	EndDo;
	
	CompleteDataPortionRegistration(RegistrationParameters);
	
EndProcedure

// Record changes of the independent register by the value table,
// where columns are dimensions, and rows are records to register.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Node - ExchangePlanRef.InfobaseUpdate
//  Records - ValueTable
//  DataKind - String
//  FullObjectName - String
//
Procedure RegisterChangesToTheIndependentRegister(Parameters, Node, Records, DataKind, FullObjectName)
	
	RegistrationParameters = NewRegistrationParameters(Parameters, Node, DataKind, FullObjectName);
	RegisterMetadata = Common.MetadataObjectByFullName(FullObjectName);
	
	For Each Record In Records Do
		Set = GetAReusedSet(RegistrationParameters.ReusedSets);
		SetMissingFiltersInSet(Set, RegisterMetadata, Records);
		
		For Each Column In Records.Columns Do
			Set.Filter[Column.Name].Value = Record[Column.Name];
			Set.Filter[Column.Name].Use = True;
		EndDo;
		
		RegisterChangesToADataItem(Set, RegistrationParameters);
	EndDo;
	
	CompleteDataPortionRegistration(RegistrationParameters);
	
EndProcedure

// Record a data item in the table for registration of changes,
// increase the counter of registered data,
// and save update data to the DIB file (it is required when DIB with filters is used).
//
// Parameters:
//  Data - AnyRef
//         - InformationRegisterRecordSet
//         - AccumulationRegisterRecordSet
//         - AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet
//  RegistrationParameters - See NewRegistrationParameters.
//
Procedure RegisterChangesToADataItem(Data, RegistrationParameters)
	
	If RegistrationParameters.BatchRegistrationIsAvailable Then
		RegistrationParameters.DataForRegistration.Add(Data);
		RegisterADataPackage(RegistrationParameters, RegistrationParameters.DataForRegistration);
	Else
		Try
			ExchangePlans.RecordChanges(RegistrationParameters.Node, Data);
		Except
			ExceptionText = NStr("en = 'Cannot register data for processing. The tables for which the data is registered
				|might not be included in the ""%1"" exchange plan.
				|To detect such errors, use the %2 tool.
				|
				|%3';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, 
				Metadata.ExchangePlans.InfobaseUpdate.Name,
				"SSLImplementationCheck",
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise ExceptionText;
		EndTry;
		ReleaseTheReusedSetsInTheParameters(RegistrationParameters);
	EndIf;
	
	IncreaseTheNumberOfRegisteredData(RegistrationParameters.Parameters,
		Data,
		RegistrationParameters.FullObjectName);
	
	If RegistrationParameters.WriteUpdateDataToAFile Then
		RegistrationParameters.ModuleDataExchangeServer.WriteUpdateDataToFile(RegistrationParameters.Parameters,
			Data,
			RegistrationParameters.DataKind,
			RegistrationParameters.FullObjectName);
	EndIf;
	
EndProcedure

// Register a data package if it is big enough
// or manually register it at the end of data batch registration.
//
// Parameters:
//  RegistrationParameters - See NewRegistrationParameters.
//  Data - Array of AnyRef
//         - Array of InformationRegisterRecordSet
//         - Array of AccumulationRegisterRecordSet
//         - Array of AccountingRegisterRecordSet
//         - Array of CalculationRegisterRecordSet
//  Forcibly - Boolean - True if the package must be registered even if it is small.
//  PackageSize - Number - if a package contains the same or larger number of records, it is registered.
//
Procedure RegisterADataPackage(RegistrationParameters, Data, Forcibly = False, PackageSize = 1000)
	
	If Data.Count() >= PackageSize Or Forcibly And Data.Count() > 0 Then
		Try
			ExchangePlans.RecordChanges(RegistrationParameters.Node, Data);
		Except
			ExceptionText = NStr("en = 'Cannot register data for processing. The tables for which the data is registered
				|might not be included in the ""%1"" exchange plan.
				|To detect such errors, use the %2 tool.
				|
				|%3';");
			ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(ExceptionText, 
				Metadata.ExchangePlans.InfobaseUpdate.Name,
				"SSLImplementationCheck",
				ErrorProcessing.DetailErrorDescription(ErrorInfo()));
			Raise ExceptionText;
		EndTry;
		Data.Clear();
		
		ReleaseTheReusedSetsInTheParameters(RegistrationParameters);
	EndIf;
	
EndProcedure

// Write the remaining data batch at the end of the registration process if batch registration is available.
//
// Parameters:
//  RegistrationParameters - See NewRegistrationParameters.
//
Procedure CompleteDataPortionRegistration(RegistrationParameters)
	
	If RegistrationParameters.BatchRegistrationIsAvailable Then
		RegisterADataPackage(RegistrationParameters, RegistrationParameters.DataForRegistration, True);
	EndIf;
	
EndProcedure

// Increase the amount of registered data in the statistics.
//
// Parameters:
//  Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//  Data - AnyRef
//         - InformationRegisterRecordSet
//         - AccumulationRegisterRecordSet
//         - AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet
//  FullObjectName - String
//
Procedure IncreaseTheNumberOfRegisteredData(Parameters, Data, FullObjectName)
	
	If Parameters.Property("HandlerData") Then
		If Not ValueIsFilled(FullObjectName) Then
			FullName = Data.Metadata().FullName();
		Else
			FullName = FullObjectName;
		EndIf;
		
		ObjectData2 = Parameters.HandlerData[FullName];
		
		If ObjectData2 = Undefined Then
			ObjectData2 = New Structure;
			ObjectData2.Insert("Count", 1);
			ObjectData2.Insert("Queue", Parameters.Queue);
			Parameters.HandlerData.Insert(FullName, ObjectData2);
		Else
			ObjectData2.Count = ObjectData2.Count + 1;
		EndIf;
	EndIf;
	
EndProcedure

// Delete the registration of one or several references.
//
// Parameters:
//  Node - ExchangePlanRef.InfobaseUpdate
//  References - AnyRef
//         - Array of AnyRef
//
Procedure DeleteRegistrationOfObjectChanges(Node, References)
	
	DeletionParameters = NewParametersForDeletingRegistration(Node);
	
	For Each Ref In ItemArray(References) Do
		DeleteRegistrationOfDataItemChanges(Ref, DeletionParameters);
	EndDo;
	
	CompleteDeletionOfDataPortionRegistration(DeletionParameters);
	
EndProcedure

// Delete the registration of changes of a subordinate register by the specified recorders.
//
// Parameters:
//  Node - ExchangePlanRef.InfobaseUpdate
//  Recorders - AnyRef
//               - Array of AnyRef
//  FullObjectName - String
//
Procedure DeleteTheRegistrationOfChangesToTheSubordinateRegister(Node, Recorders, FullObjectName)
	
	DeletionParameters = NewParametersForDeletingRegistration(Node, FullObjectName);
	
	For Each Recorder In ItemArray(Recorders) Do
		Set = GetAReusedSet(DeletionParameters.ReusedSets);
		Set.Filter.Recorder.Set(Recorder);
		
		WriteProgressProgressHandler(Set, Node); // @skip-check query-in-loop - The loop has no query.
		DeleteRegistrationOfDataItemChanges(Set, DeletionParameters);
	EndDo;
	
	CompleteDeletionOfDataPortionRegistration(DeletionParameters);
	
EndProcedure

// Delete the registration of changes of an independent register by the value table.
//
// Parameters:
//  Node - ExchangePlanRef.InfobaseUpdate
//  Records - ValueTable
//  FullObjectName - String
//
Procedure DeleteRegistrationOfIndependentRegisterChanges(Node, Records, FullObjectName)
	
	DeletionParameters = NewParametersForDeletingRegistration(Node, FullObjectName);
	RegisterMetadata = Common.MetadataObjectByFullName(FullObjectName);
	
	For Each Record In Records Do
		Set = GetAReusedSet(DeletionParameters.ReusedSets);
		SetMissingFiltersInSet(Set, RegisterMetadata, Records);
		
		For Each Column In Records.Columns Do
			Set.Filter[Column.Name].Value = Record[Column.Name];
			Set.Filter[Column.Name].Use = True;
		EndDo;
		
		WriteProgressProgressHandler(Set, Node, RegisterMetadata); // @skip-check query-in-loop - The loop has no query.
		DeleteRegistrationOfDataItemChanges(Set, DeletionParameters);
	EndDo;
	
	CompleteDeletionOfDataPortionRegistration(DeletionParameters);
	
EndProcedure

// Delete the registration of a data package if it is big enough
// or do it manually at the end of data batch registration deletion.
//
// Parameters:
//  DeletionParameters - See NewParametersForDeletingRegistration.
//  Data - Array of AnyRef
//         - Array of InformationRegisterRecordSet
//         - Array of AccumulationRegisterRecordSet
//         - Array of AccountingRegisterRecordSet
//         - Array of CalculationRegisterRecordSet
//  Forcibly - Boolean - True if the package must be deleted even if it is small.
//  PackageSize - Number - if a package contains the same or larger number of records, it is registered.
//
Procedure DeleteRegistrationOfDataPackageChanges(DeletionParameters, Data, Forcibly = False, PackageSize = 1000)
	
	If Data.Count() >= PackageSize Or Forcibly And Data.Count() > 0 Then
		ExchangePlans.DeleteChangeRecords(DeletionParameters.Node, Data);
		Data.Clear();
		
		ReleaseTheReusedSetsInTheParameters(DeletionParameters);
	EndIf;
	
EndProcedure

// Delete the registration of a data item in the change registration table.
//
// Parameters:
//  Data - AnyRef
//         - InformationRegisterRecordSet
//         - AccumulationRegisterRecordSet
//         - AccountingRegisterRecordSet
//         - CalculationRegisterRecordSet
//  DeletionParameters - See NewParametersForDeletingRegistration.
//
Procedure DeleteRegistrationOfDataItemChanges(Data, DeletionParameters)
	
	If DeletionParameters.BatchRegistrationIsAvailable Then
		DeletionParameters.DataToDelete.Add(Data);
		DeleteRegistrationOfDataPackageChanges(DeletionParameters, DeletionParameters.DataToDelete);
	Else
		ExchangePlans.DeleteChangeRecords(DeletionParameters.Node, Data);
		ReleaseTheReusedSetsInTheParameters(DeletionParameters);
	EndIf;
	
EndProcedure

// Delete the remaining data batch at the end of the registration deletion process if batch registration is available.
//
// Parameters:
//  DeletionParameters - See NewParametersForDeletingRegistration.
//
Procedure CompleteDeletionOfDataPortionRegistration(DeletionParameters)
	
	If DeletionParameters.BatchRegistrationIsAvailable Then
		DeleteRegistrationOfDataPackageChanges(DeletionParameters, DeletionParameters.DataToDelete, True);
	EndIf;
	
EndProcedure

// Checks whether it is required to save update data to the file when a DIB with filters is used.
//
// Returns:
//  Boolean - True - data must be saved to the file for DIB.
//
Function WriteUpdateDataToAFile(Parameters)
	
	Return Common.SubsystemExists("StandardSubsystems.DataExchange")
	      And StandardSubsystemsCached.DIBUsed("WithFilter")
	   And Not Parameters.ReRegistration
	   And Not Common.IsSubordinateDIBNode();
	
EndFunction

// Get the DataExchangeServer common module if it is available.
//
// Returns:
//  CommonModule
//
Function ModuleDataExchangeServer(WriteUpdateDataToAFile)
	
	Return ?(WriteUpdateDataToAFile, Common.CommonModule("DataExchangeServer"), Undefined);
	
EndFunction

// Return an array of items even if one item is passed.
//
// Parameters:
//  Items - Array
//           - Arbitrary
//
// Returns:
//  Array
//
Function ItemArray(Items)
	
	If TypeOf(Items) <> Type("Array") Then
		ItemArray = New Array;
		ItemArray.Add(Items);
	Else
		ItemArray = Items;
	EndIf;
	
	Return ItemArray;
	
EndFunction

// A structure with the context of data registration in the exchange plan.
//
// Parameters:
//  Node - ExchangePlanRef.InfobaseUpdate
//  DataKind - String
//  FullObjectName - String
//
// Returns:
//  Structure:
//   * Parameters - See InfobaseUpdate.MainProcessingMarkParameters.
//   * Node - ExchangePlanRef.InfobaseUpdate
//   * DataKind - String
//   * FullObjectName - String
//   * DataForRegistration - Array
//   * ObjectManager - DocumentManager
//                     - CatalogManager
//                     - ChartOfCharacteristicTypesManager
//                     - ChartOfAccountsManager
//                     - ChartsOfCalculationTypesManager
//                     - BusinessProcessManager
//                     - TaskManager
//                     - InformationRegisterManager
//                     - AccumulationRegisterManager
//                     - AccountingRegisterManager
//                     - CalculationRegisterManager
//   * BatchRegistrationIsAvailable - Boolean
//   * WriteUpdateDataToAFile - Boolean
//   * ModuleDataExchangeServer - CommonModule
//
Function NewRegistrationParameters(Parameters, Node, DataKind, FullObjectName)
	
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Parameters", Parameters);
	RegistrationParameters.Insert("Node", Node);
	RegistrationParameters.Insert("DataKind", DataKind);
	RegistrationParameters.Insert("FullObjectName", FullObjectName);
	RegistrationParameters.Insert("DataForRegistration", New Array);
	RegistrationParameters.Insert("BatchRegistrationIsAvailable", True);
	RegistrationParameters.Insert("WriteUpdateDataToAFile", WriteUpdateDataToAFile(Parameters));
	RegistrationParameters.Insert("ModuleDataExchangeServer",
		ModuleDataExchangeServer(RegistrationParameters.WriteUpdateDataToAFile));
	
	ObjectManager = Undefined;
	
	If ValueIsFilled(FullObjectName) Then
		ObjectManager = Common.ObjectManagerByFullName(FullObjectName);
		
		If Common.IsRegister(Common.MetadataObjectByFullName(FullObjectName)) Then
			RegistrationParameters.Insert("ReusedSets", NewReusedSets(ObjectManager));
		EndIf;
	EndIf;
	
	RegistrationParameters.Insert("ObjectManager", ObjectManager);
	
	Return RegistrationParameters;
	
EndFunction

// A structure with the deletion context of data registration in the exchange plan.
//
// Parameters:
//  Node - ExchangePlanRef.InfobaseUpdate
//  FullObjectName - String
//
// Returns:
//  Structure:
//   * Node - ExchangePlanRef.InfobaseUpdate
//   * FullObjectName - String
//   * DataToDelete - Array
//   * ObjectManager - DocumentManager
//                     - CatalogManager
//                     - ChartOfCharacteristicTypesManager
//                     - ChartOfAccountsManager
//                     - ChartsOfCalculationTypesManager
//                     - BusinessProcessManager
//                     - TaskManager
//                     - InformationRegisterManager
//                     - AccumulationRegisterManager
//                     - AccountingRegisterManager
//                     - CalculationRegisterManager
//   * BatchRegistrationIsAvailable - Boolean
//
Function NewParametersForDeletingRegistration(Node, FullObjectName = "")
	
	DeletionParameters = New Structure;
	DeletionParameters.Insert("Node", Node);
	DeletionParameters.Insert("FullObjectName", FullObjectName);
	DeletionParameters.Insert("DataToDelete", New Array);
	DeletionParameters.Insert("BatchRegistrationIsAvailable", True);
	
	ObjectManager = Undefined;
	
	If ValueIsFilled(FullObjectName) Then
		ObjectManager = Common.ObjectManagerByFullName(FullObjectName);
		
		If Common.IsRegister(Common.MetadataObjectByFullName(FullObjectName)) Then
			DeletionParameters.Insert("ReusedSets", NewReusedSets(ObjectManager));
		EndIf;
	EndIf;
	
	DeletionParameters.Insert("ObjectManager", ObjectManager);
	
	Return DeletionParameters;
	
EndFunction

// A new collection of reused sets.
//
// Parameters:
//  Manager - InformationRegisterManager
//           - AccumulationRegisterManager
//           - CalculationRegisterManager
//           - AccountingRegisterManager - manager to create a record set.
//  Size - Number
//
// Returns:
//  Structure:
//   * Sets - Array - reused sets.
//   * CreatedOn - Number - number of created sets.
//   * Issued - Number - number of issued sets.
//
Function NewReusedSets(Manager, Size = 1000)
	
	ReusedObjects = New Structure;
	ReusedObjects.Insert("Manager", Manager);
	ReusedObjects.Insert("Sets", New Array(Size));
	ReusedObjects.Insert("CreatedOn", 0);
	ReusedObjects.Insert("Issued", 0);
	
	Return ReusedObjects;
	
EndFunction

// Receive a previously created reused set or create a new one and receive it.
//
// Parameters:
//  ReusedSets - See NewReusedSets.
//
// Returns:
//  - InformationRegisterRecordSet
//  - AccumulationRegisterRecordSet
//  - CalculationRegisterRecordSet
//  - AccountingRegisterRecordSet - a set ready for use.
//
Function GetAReusedSet(ReusedSets)
	
	If ReusedSets.CreatedOn = ReusedSets.Issued Then
		NewSet = ReusedSets.Manager.CreateRecordSet();
		
		If ReusedSets.CreatedOn > ReusedSets.Sets.UBound() Then
			ReusedSets.Sets.Add(NewSet);
		Else
			ReusedSets.Sets[ReusedSets.CreatedOn] = NewSet;
		EndIf;
		
		ReusedSets.CreatedOn = ReusedSets.CreatedOn + 1;
	EndIf;
	
	TheReturnedSet = ReusedSets.Sets[ReusedSets.Issued];
	ReusedSets.Issued = ReusedSets.Issued + 1;
	
	Return TheReturnedSet;
	
EndFunction

// Unlock previously locked reused sets.
//
// Parameters:
//  ReusedSets - See NewReusedSets.
//
Procedure ReleaseReusedSets(ReusedSets)
	
	ReusedSets.Issued = 0;
	
EndProcedure

// Unlock previously locked reused sets based on parameters.
//
// Parameters:
//  Parameters - See NewRegistrationParameters
//            - See NewParametersForDeletingRegistration.
//
Procedure ReleaseTheReusedSetsInTheParameters(Parameters)
	
	If Parameters.Property("ReusedSets") Then
		ReleaseReusedSets(Parameters.ReusedSets);
	EndIf;
	
EndProcedure

Function EarlierQueueNodes(Queue)
	Return ExchangePlans.InfobaseUpdate.EarlierQueueNodes(Queue);
EndFunction

Function QueueRef(Queue, Temporary = False)
	Return ExchangePlans.InfobaseUpdate.NodeInQueue(Queue, Temporary);
EndFunction

// Selection creation context using the following functions:
// - SelectRegisterRecordersToProcess();
// - SelectRefsToProcess();
// - SelectStandaloneInformationRegisterDimensionsToProcess();
//
// Parameters:
//  AdditionalParameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters
//  TableName - String - the name of the table from which the data is selected.
//
// Returns:
//  Structure:
//   * AdditionalParameters - Structure - the input parameter reference copy for mechanism procedures.
//   * SelectionByPage - Boolean - True if the selection is executed by page.
//   * TableName - String - the name of the table from which the data is selected.
//   * SelectionFields1 - Array - fields that are placed in the request selection list.
//   * OrderFields - Array - fields that are placed in request of ordering section.
//   * UsedOrderingFields - Map - Cache of the passwords that were used for ordering.
//   * Aliases - Array - name aliases of fields being selected that are inserted in selection request.
//   * Directions - Array - ordering directions (ASC, and DESC).
//
Function SelectionBuildParameters(AdditionalParameters, TableName = Undefined)
	
	CheckSelectionParameters(AdditionalParameters);
	
	BuildParameters = New Structure;
	BuildParameters.Insert("AdditionalParameters", AdditionalParameters);
	BuildParameters.Insert("SelectionByPage", IsSelectionByPages(AdditionalParameters));
	BuildParameters.Insert("TableName", TableName);
	BuildParameters.Insert("SelectionFields1", New Array);
	BuildParameters.Insert("OrderFields", New Array);
	BuildParameters.Insert("UsedOrderingFields", New Map);
	BuildParameters.Insert("Aliases", New Array);
	BuildParameters.Insert("Directions", New Array);
	
	Return BuildParameters;
	
EndFunction

// Set ordering fields in SelectRefsToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//  IsDocument - Boolean - True if document references are processed.
//
Procedure SetRefsOrderingFields(BuildParameters, IsDocument)
	
	SelectionFields1 = BuildParameters.SelectionFields1;
	OrderFields = BuildParameters.OrderFields;
	SelectionByPage = BuildParameters.SelectionByPage;
	
	If IsDocument Then
		If SelectionByPage Then
			SelectionFields1.Add("ObjectTable.Date");
		EndIf;
		
		OrderFields.Add("ObjectTable.Date");
	EndIf;
	
	SelectionFields1.Add("ChangesTable.Ref");
	
	If SelectionByPage Then
		OrderFields.Add("ChangesTable.Ref");
	EndIf;
	
EndProcedure

// Set ordering fields for register in SelectRegisterRecordersToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//
Procedure SetRegisterOrderingFields(BuildParameters)
	
	SelectionFields1 = BuildParameters.SelectionFields1;
	Aliases = BuildParameters.Aliases;
	OrderFields = BuildParameters.OrderFields;
	NameOfTheDimensionToSelect = BuildParameters.AdditionalParameters.NameOfTheDimensionToSelect;
	LoggerField = StringFunctionsClientServer.SubstituteParametersToString("RegisterTableChanges.%1",
		NameOfTheDimensionToSelect);
	
	SelectionFields1.Add(LoggerField);
	Aliases.Add(NameOfTheDimensionToSelect);
	
	If BuildParameters.SelectionByPage Then
		OrderFields.Add(LoggerField);
	Else
		If Upper(NameOfTheDimensionToSelect) = Upper("Recorder") Then
			SelectionFields1.Add("MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1)))");
			Aliases.Add("Period");
			OrderFields.Add("MAX(ISNULL(RegisterTable.Period, DATETIME(3000, 1, 1)))");
		Else
			DateField = StringFunctionsClientServer.SubstituteParametersToString("%1.Date", LoggerField);
			SelectionFields1.Add(DateField);
			Aliases.Add("Period");
			OrderFields.Add(DateField);
		EndIf;
	EndIf;
	
EndProcedure

// Set ordering fields for document in SelectRegisterRecordersToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//
Procedure SetRegisterOrderingFieldsByDocument(BuildParameters)
	
	SelectionFields1 = BuildParameters.SelectionFields1;
	Aliases = BuildParameters.Aliases;
	OrderFields = BuildParameters.OrderFields;
	OrderFields.Add("DocumentTable.Date");
	NameOfTheDimensionToSelect = BuildParameters.AdditionalParameters.NameOfTheDimensionToSelect;
	LoggerField = StringFunctionsClientServer.SubstituteParametersToString("RegisterTableChanges.%1",
		NameOfTheDimensionToSelect);
	
	If BuildParameters.SelectionByPage Then
		SelectionFields1.Add("DocumentTable.Date");
		Aliases.Add("Date");
		OrderFields.Add(LoggerField);
	EndIf;
	
	SelectionFields1.Add(LoggerField);
	Aliases.Add(NameOfTheDimensionToSelect);
	
EndProcedure

// Set ordering fields for document in SelectStandaloneInformationRegisterDimensionsToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//
Procedure SetStandaloneInformationRegisterOrderingFields(BuildParameters)
	
	Separators = " " + Chars.Tab + Chars.LF;
	OrderFields = BuildParameters.AdditionalParameters.OrderFields;
	
	For FieldIndex = 0 To OrderFields.UBound() Do
		Field = OrderFields[FieldIndex];
		Content = StrSplit(Field, Separators, False);
		FieldName = Content[0];
		BuildParameters.SelectionFields1.Add(FieldName);
		BuildParameters.UsedOrderingFields[FieldName] = True;
		
		If Content.Count() > 1 Then
			BuildParameters.Directions.Add(Content[1]);
		Else
			BuildParameters.Directions.Add(?(FieldIndex = 0, "DESC", ""));
		EndIf;
	EndDo;
	
EndProcedure

// Consider the dimension in generating request parameters in SelectStandaloneInformationRegisterDimensionsToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//  DimensionName - String - the name of the dimension being processed.
//
Procedure SetDimension(BuildParameters, DimensionName)
	
	If BuildParameters.UsedOrderingFields[DimensionName] = Undefined Then
		BuildParameters.SelectionFields1.Add(DimensionName);
		OrderingFieldsAreSet = OrderingFieldsAreSet(BuildParameters.AdditionalParameters);
		
		If OrderingFieldsAreSet Or BuildParameters.SelectionByPage Then
			BuildParameters.Directions.Add("");
		EndIf;
	EndIf;
	
EndProcedure

// Consider the period in generating request parameters in SelectStandaloneInformationRegisterDimensionsToProcess ().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//
Procedure SetPeriod(BuildParameters)
	
	BuildParameters.SelectionFields1.Insert(0, "Period");
	BuildParameters.Directions.Insert(0, "");
	
EndProcedure

// Consider the resources in generating request parameters in SelectStandaloneInformationRegisterDimensionsToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//  Resources             - MetadataObjectCollection
//
Procedure SetResources(BuildParameters, Resources)
	
	If BuildParameters.SelectionFields1.Count() = 0 Then
		For Each Resource In Resources Do
			If BuildParameters.UsedOrderingFields[Resource.Name] = Undefined Then
				BuildParameters.SelectionFields1.Add(Resource.Name);
				BuildParameters.Directions.Add("");
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Consider the attributes in generating request parameters in SelectStandaloneInformationRegisterDimensionsToProcess().
//
// Parameters:
//  BuildParameters - See SelectionBuildParameters
//  Attributes           - MetadataObjectCollection
//
Procedure SetAttributes1(BuildParameters, Attributes)
	
	If BuildParameters.SelectionFields1.Count() = 0 Then
		For Each Attribute In Attributes Do
			If BuildParameters.UsedOrderingFields[Attribute.Name] = Undefined Then
				BuildParameters.SelectionFields1.Add(Attribute.Name);
				BuildParameters.Directions.Add("");
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Set the data in the following functions considering selection by page:
// - SelectRegisterRecordersToProcess();
// - SelectRefsToProcess();
// - SelectStandaloneInformationRegisterDimensionsToProcess();
//
// Parameters:
//  Query - Query - data selection request.
//  BuildParameters - See SelectionBuildParameters
//
// Returns:
//   QueryResultSelection - in case of usual selection.
//   ValueTable - in case of selection by page.
//
Function SelectDataToProcess(Query, BuildParameters)
	
	If BuildParameters.SelectionByPage Then
		Return SelectDataByPage(Query, BuildParameters);
	Else
		Query.Text = StrReplace(Query.Text, "&PagesCondition", "TRUE");
		Return Query.Execute().Select();
	EndIf;
	
EndFunction

// Get the value table with the data to process considering selection by page.
//
// Parameters:
//  Query - Query - data selection request.
//  BuildParameters - See SelectionBuildParameters
//
// Returns:
//  ValueTable - data for update handler (multithread).
//
Function SelectDataByPage(Query, BuildParameters)
	
	SelectionFields1 = BuildParameters.SelectionFields1;
	Parameters = BuildParameters.AdditionalParameters;
	ChangesTable = BuildParameters.TableName;
	Directions = BuildParameters.Directions;
	LastSelectedRecord = Parameters.LastSelectedRecord;
	FirstRecord = Parameters.FirstRecord;
	LatestRecord = Parameters.LatestRecord;
	SelectFirstRecords = LastSelectedRecord = Undefined
	              And FirstRecord = Undefined
	              And LatestRecord = Undefined;
	
	If SelectFirstRecords Then
		ChangeSelectionMax(Query.Text, MaxRecordsCountInSelection(), Parameters.MaxSelection);
		Query.Text = StrReplace(Query.Text, "&PagesCondition", "TRUE");
		Result = Query.Execute().Unload();
	Else
		SelectRange = FirstRecord <> Undefined Or LatestRecord <> Undefined;
		BaseQueryText = Query.Text;
		
		If SelectRange Then
			Conditions = PageRangeConditions(SelectionFields1, Parameters, Directions);
		Else
			Conditions = ConditionsForTheFollowingPage(SelectionFields1, Parameters, Directions);
		EndIf;
		
		If Parameters.OptimizeSelectionByPages Then
			Result = Undefined;
			LastConditionIndex = Conditions.Count() - 1;
			DeferTemporaryTablesDrop = Conditions.Count() > 1;
			
			If DeferTemporaryTablesDrop Then
				TemporaryTablesDropQueryText = CutTemporaryTablesDrop(BaseQueryText);
			EndIf;
			
			For IndexOf = 0 To LastConditionIndex Do
				If Result = Undefined Then
					Count = Parameters.MaxSelection;
				Else
					Count = Parameters.MaxSelection - Result.Count();
				EndIf;
				
				Query.Text = String(BaseQueryText);
				ChangeSelectionMax(Query.Text, MaxRecordsCountInSelection(), Count);
				SetSelectionByPageConditions(Query, Conditions, ChangesTable, Parameters, True, IndexOf);
				
				If DeferTemporaryTablesDrop And IndexOf = LastConditionIndex Then
					Query.Text = Query.Text + TemporaryTablesDropQueryText;
				EndIf;
				
				Upload0 = Query.Execute().Unload(); // @skip-check query-in-loop - Optimized date retrieval.
				
				If Result = Undefined Then
					Result = Upload0;
				Else
					For Each ExportString In Upload0 Do
						ResultString1 = Result.Add();
						FillPropertyValues(ResultString1, ExportString);
					EndDo;
				EndIf;
				
				If Result.Count() = Parameters.MaxSelection Then
					Break;
				EndIf;
			EndDo;
		Else
			ChangeSelectionMax(Query.Text, MaxRecordsCountInSelection(), Parameters.MaxSelection);
			SetSelectionByPageConditions(Query, Conditions, ChangesTable, Parameters, True);
			Result = Query.Execute().Unload();
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

// Delete from the requests package temporary tables deletion and return them as a result of this function.
//
// Parameters:
//  QueryText - String - the modified query text.
//
// Returns:
//  String - text fragment with temporary tables deletion.
//
Function CutTemporaryTablesDrop(QueryText)
	
	DropQueries = New Array;
	PositionToDrop = StrFind(QueryText, "DROP");
	
	While PositionToDrop > 0 Do
		SeparatorPosition = StrFind(QueryText, ";",, PositionToDrop);
		
		If SeparatorPosition > 0 Then
			DropQuery = Mid(QueryText, PositionToDrop, SeparatorPosition - PositionToDrop + 1);
		Else
			DropQuery = Mid(QueryText, PositionToDrop);
		EndIf;
		
		If DropQueries.Count() = 0 Then
			DropQueries.Add(Chars.LF);
		EndIf;
		
		DropQueries.Add(DropQuery);
		QueryText = StrReplace(QueryText, DropQuery, "");
		PositionToDrop = StrFind(QueryText, "DROP");
	EndDo;
	
	Return StrConcat(DropQueries, Chars.LF);
	
EndFunction

// Add conditions restricting selection by page to the query.
//
// Selection by page operates in two modes:
// - selection from above - the records larger than the specified one (similar to the dynamic list);
// - range selection - records between two specified records including them.
//
// Parameters:
//  Query  - Query - data selection request.
//  Conditions - See NewConditionsOfSelectionByPage
//  Table - String - name of the table from which the selection is executed.
//  Parameters - See InfobaseUpdate.AdditionalProcessingMarkParameters
//  Top - Boolean - True if they are first conditions in the query.
//  ConditionNumber - Number - processing condition number.
//
Procedure SetSelectionByPageConditions(Query, Conditions, Table, Parameters, Top, ConditionNumber = Undefined)
	
	FirstRecord = Parameters.FirstRecord;
	LatestRecord = Parameters.LatestRecord;
	SelectRange = FirstRecord <> Undefined
	              Or LatestRecord <> Undefined;
	
	If Not SelectRange Then
		FirstRecord = Parameters.LastSelectedRecord;
	EndIf;
	
	Columns = Conditions.Columns;
	ColumnsCount = Columns.Count();
	ConditionsAnd = New Array;
	ConditionsOr = New Array;
	HasConditionsOr = (ConditionNumber = Undefined);
	HasTable = Not IsBlankString(Table);
	ConditionAndPattern = ?(HasTable, Table + ".%1 %2 &%3", "%1 %2 &%3");
	ConditionOrPattern = "(%1)";
	ConditionsAndSeparator =
		"
		|	AND ";
	ConditionsOrSeparator =
		"
		|	) OR (
		|	";
	
	If HasConditionsOr Then
		StartIndex = 0;
		EndIndex = Conditions.Count() - 1;
	Else
		StartIndex = ConditionNumber;
		EndIndex = ConditionNumber;
	EndIf;
	
	For RowIndex = StartIndex To EndIndex Do
		ConditionsAnd.Clear();
		
		For ColumnIndex = 0 To ColumnsCount - 1 Do
			Operator = Conditions[RowIndex][ColumnIndex];
			FieldIndex = ?(SelectRange, Int(ColumnIndex / 2), ColumnIndex) + 2;
			
			If Not IsBlankString(Operator) Then
				Column = Columns[ColumnIndex];
				FullFieldName = Column.Title;
				ParameterName = Column.Name + "Value";
				FieldName = ColumnNameForQuery(FullFieldName);
				Condition = StringFunctionsClientServer.SubstituteParametersToString(ConditionAndPattern, FieldName, Operator, ParameterName);
				ConditionsAnd.Add(Condition);
				
				If IsRangeEndColumnName(Column.Name) Then
					ParameterValue = LatestRecord[FieldIndex].Value;
				Else
					ParameterValue = FirstRecord[FieldIndex].Value;
				EndIf;
				
				Query.SetParameter(ParameterName, ParameterValue);
			EndIf;
		EndDo;
		
		ConditionsText = StrConcat(ConditionsAnd, ConditionsAndSeparator);
		
		If HasConditionsOr Then
			ConditionsOr.Add(ConditionsText);
		EndIf;
	EndDo;
	
	If HasConditionsOr Then
		ConditionsOrText = StrConcat(ConditionsOr, ConditionsOrSeparator);
		ConditionsText = StringFunctionsClientServer.SubstituteParametersToString(ConditionOrPattern, ConditionsOrText);
	EndIf;
	
	If Not Top Then
		ConditionsText = "	And " + ConditionsText;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&PagesCondition", ConditionsText);
	
EndProcedure

// Appends a set of conditions with another one, joined with "AND".
//
// Parameters:
//  Conditions - ValueTableRow of See NewConditionsOfSelectionByPage
//  SelectionFields1 - Array - Fields to be retrieved by the query.
//  Count - Number - The number of the starting fields that should be used when generating conditions.
//  Operator - String - The operator to be added to the last condition.
//  ForRange - Boolean - If set to "False", a condition for the range start is expected. If set to "True", a condition for the range end is expected.
//
// Returns:
//  ValueTableRow of See NewConditionsOfSelectionByPage
//
Function AppendCondition(Conditions, SelectionFields1, Count, Operator, ForRange = False)
	
	ColumnNameStart = ColumnNameFromSelectionField(SelectionFields1[Count - 1]);
	ColumnNameEnd = RangeColumnName(ColumnNameStart);
	Conditions[?(ForRange, ColumnNameEnd, ColumnNameStart)] = Operator;
	
	Return Conditions;
	
EndFunction

// Add conditions for the boundaries (such as " = " or " >= ").
//
// Parameters:
//  AllConditions - See NewConditionsOfSelectionByPage
//  SelectionFields1 - Array - Fields to be retrieved by the query.
//  Count - Number - The number of the starting fields that should be used when generating conditions.
//  Operator - String - The operator to be added to the last condition.
//  ForRange - Boolean - If set to "False", a condition for the range start is expected. If set to "True", a condition for the range end is expected.
//
// Returns:
//  ValueTableRow of See NewConditionsOfSelectionByPage
//
Function AddTerms(AllConditions, SelectionFields1, Count, Operator, ForRange = False)
	
	Conditions = AllConditions.Add();
	
	For ColumnNumber = 1 To Count - 1 Do
		ColumnNameStart = ColumnNameFromSelectionField(SelectionFields1[ColumnNumber - 1]);
		ColumnNameEnd = RangeColumnName(ColumnNameStart);
		Conditions[?(ForRange, ColumnNameEnd, ColumnNameStart)] = "=";
	EndDo;
	
	AppendCondition(Conditions, SelectionFields1, Count, Operator, ForRange);
	
	Return Conditions;
	
EndFunction

// Get conditions to filter records larger than the specified one (similar to the dynamic list).
//
// Parameters:
//  SelectionFields1 - Array - fields selected by query.
//  Parameters - See InfobaseUpdate.AdditionalProcessingMarkParameters.
//  Directions - Array - ordering directions (ASC, and DESC) in the quantity equal to the SelectionFields quantity.
//              - Undefined - order is not specified (always ASC).
//
// Returns:
//   See NewConditionsOfSelectionByPage
//
Function ConditionsForTheFollowingPage(SelectionFields1, Parameters, Directions)
	
	AllConditions = NewConditionsOfSelectionByPage(SelectionFields1);
	FieldsCount = SelectionFields1.Count();
	
	While FieldsCount > 0 Do
		NewConditions = AllConditions.Add();
		
		For ConditionNumber = 1 To FieldsCount Do
			FieldColumnName = SelectionFields1[ConditionNumber - 1];
			
			If ConditionNumber < FieldsCount Then
				Operator = "=";
			Else
				Operator = OperatorGreater(Directions[ConditionNumber - 1]);
			EndIf;
			
			NewConditions[ColumnNameFromSelectionField(FieldColumnName)] = Operator;
		EndDo;
		
		FieldsCount = FieldsCount - 1;
	EndDo;
	
	Return AllConditions;
	
EndFunction

// Get the conditions to select the records between two specified records, inclusively.
//
// Parameters:
//  SelectionFields1 - Array - fields selected by query.
//  Parameters - See InfobaseUpdate.AdditionalProcessingMarkParameters.
//  Directions - Array - ordering directions (ASC, and DESC) in the quantity equal to the SelectionFields quantity.
//              - Undefined - order is not specified (always ASC).
//
// Returns:
//   See NewConditionsOfSelectionByPage
//
Function PageRangeConditions(SelectionFields1, Parameters, Directions)
	
	AllConditions = NewConditionsOfSelectionByPage(SelectionFields1, True);
	FirstRecord = Parameters.FirstRecord;
	LatestRecord = Parameters.LatestRecord;
	FieldsCount = SelectionFields1.Count();
	FieldsTotal = SelectionFields1.Count();
	InsertPosition = 0;
	
	If FirstRecord = Undefined And LatestRecord = Undefined Then
		Return AllConditions;
	EndIf;
	
	If FirstRecord = LatestRecord Then
		AddTerms(AllConditions, SelectionFields1, FieldsCount, "=");
	EndIf;
	
	While FieldsCount > 0 Do
		Direction = Directions[FieldsCount - 1];
		IsCurrentColumnsIdentical = RecordsAreEqual(FirstRecord, LatestRecord, FieldsCount);
		IsPreviousColumnsIdentical = RecordsAreEqual(FirstRecord, LatestRecord, FieldsCount - 1);
		
		If FirstRecord <> Undefined Then
			If FieldsCount = FieldsTotal Then // All columns of the range start.
				Operator = OperatorGreaterOrEqual(Direction);
				Conditions = AddTerms(AllConditions, SelectionFields1, FieldsCount, Operator);
				
				If IsPreviousColumnsIdentical Then
					Operator = OperatorLessOrEqual(Direction);
					AppendCondition(Conditions, SelectionFields1, FieldsCount, Operator, True);
				EndIf;
			Else // Some columns of the range start.
				If Not IsCurrentColumnsIdentical Then
					Operator = OperatorGreater(Direction);
					Conditions = AddTerms(AllConditions, SelectionFields1, FieldsCount, Operator);
					
					If IsPreviousColumnsIdentical Then
						Operator = OperatorLess(Direction);
						AppendCondition(Conditions, SelectionFields1, FieldsCount, Operator, True);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
		If LatestRecord <> Undefined Then
			If FieldsCount = FieldsTotal Then // All columns of the range end.
				If Not IsPreviousColumnsIdentical Then
					Operator = OperatorLessOrEqual(Direction);
					Conditions = AddTerms(AllConditions, SelectionFields1, FieldsCount, Operator, True);
				EndIf;
			Else // Some columns of the range end.
				If Not IsCurrentColumnsIdentical And Not IsPreviousColumnsIdentical Then
					Operator = OperatorLess(Direction);
					Conditions = AddTerms(AllConditions, SelectionFields1, FieldsCount, Operator, True);
				EndIf;
			EndIf;
		EndIf;
		
		FieldsCount = FieldsCount - 1;
	EndDo;
	
	Return AllConditions;
	
EndFunction

// Returns the two records comparison result.
//
// Parameters:
//  FirstRecord - ValueList of String
//  LatestRecord - ValueList of String
//  FieldsCount - Number - applied fields quantity in the record key.
//
// Returns:
//  Boolean - True if the records are equal.
//
Function RecordsAreEqual(FirstRecord, LatestRecord, FieldsCount)
	
	If FirstRecord = Undefined And LatestRecord = Undefined Then
		Return True;
	EndIf;
	
	If FirstRecord = Undefined Or LatestRecord = Undefined Then
		Return False;
	EndIf;
	
	For IndexOf = 2 To FieldsCount + 2 - 1 Do
		If FirstRecord[IndexOf].Value <> LatestRecord[IndexOf].Value Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Returns the value table with the conditions of selection by page.
//
// Parameters:
//  SelectionFields1 - Array - fields selected by query.
//  ForRange - Boolean - True if the table will be used to restrict the range.
//                 In this case, additional columns are added for the lower range condition.
//
// Returns:
//  ValueTable - table columns describe query fields, where a full field name is stored in the title.
//                    Column names are generated dynamically from query selection fields.
//                    Each row describes conditions for one query that selects data batches for a page
//                    or condition group upon the selection via OR. The following conditions are stored in the table cells:
//                    ("=", ">", "<", ">=", "<=")..
// 
Function NewConditionsOfSelectionByPage(SelectionFields1, ForRange = False)
	
	Conditions = New ValueTable;
	Columns = Conditions.Columns;
	
	For Each SelectionField In SelectionFields1 Do
		Name = ColumnNameFromSelectionField(SelectionField);
		Columns.Add(Name,, SelectionField);
		
		If ForRange Then
			Columns.Add(RangeColumnName(Name),, SelectionField);
		EndIf;
	EndDo;
	
	Return Conditions;
	
EndFunction

// Return a column name for the condition by the range bottom of the selection by page.
//
// Parameters:
//  FieldName - String - Field name.
//
// Returns:
//  String - a field name for the condition by the range bottom.
//
Function RangeColumnName(FieldName)
	
	Return FieldName + EndOfRangePostfix();
	
EndFunction

// Returns a name, for example, for a value table column, received from the full query field name.
//
// Parameters:
//  Name - String - a full query field name (it can be point-separated).
//
// Returns:
//  String - Field name.
//
Function ColumnNameFromSelectionField(Name)
	
	CharsToReplace = ".,() ";
	ColumnName = String(Name);
	
	For IndexOf = 1 To StrLen(CharsToReplace) Do
		Char = Mid(CharsToReplace, IndexOf, 1);
		ColumnName = StrReplace(ColumnName, Char, "_");
	EndDo;
	
	Return ColumnName;
	
EndFunction

// Field name received from the column containing page-wise filter conditions. See NewConditionsOfSelectionByPage.
//
// Parameters:
//  FieldName - String - Field name.
//
// Returns:
//  String - a field name without service characters.
//
Function ColumnNameForQuery(FieldName)
	
	If IsRangeEndColumnName(FieldName) Then
		Return Left(FieldName, StrLen(FieldName) - StrLen(EndOfRangePostfix()));
	Else
		Return FieldName;
	EndIf;
	
EndFunction

// Defines if the column describes the end of selection by page range.
//
// Parameters:
//  FieldName - String - Field name.
//
// Returns:
//  Boolean - True if this field describes the selection by page range end.
//
Function IsRangeEndColumnName(FieldName)
	
	Return StrEndsWith(FieldName, EndOfRangePostfix());
	
EndFunction

Function EndOfRangePostfix()
	
	Return "_" + "RangeEnd";
	
EndFunction

// Checking if data selection parameters are filed in correctly.
//
// Parameters:
//  Parameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
//
Procedure CheckSelectionParameters(Parameters)
	
	If Not Parameters.SelectInBatches And IsSelectionByPages(Parameters) Then
		Raise NStr("en = 'Multi-threaded update handler must select data in portions.';");
	EndIf;
	
EndProcedure

// Generates a query text fragment with fields to select.
//
// Parameters:
//  FieldsNames - Array - field names as an array.
//  Aliases - Array - aliases as an array with the same number of elements, as FieldsNames has.
//             - Undefined - in this case aliases are equal to field names.
//  TableName - String - a name of a table that contains fields.
//                        if a blank row is specified, a table name is not inserted.
//  Additional - Boolean - True, if these are not the first fields in the selection and they require "," before them.
//
// Returns:
//  String - a query text fragment with fields to select.
//
Function FieldsForQuery(FieldsNames, Aliases = Undefined, TableName = "", Additional = False)
	
	FieldsCount = FieldsNames.Count();
	
	If FieldsCount = 0 Then
		Return "";
	EndIf;
	
	HasAliases = Aliases <> Undefined And Aliases.Count() = FieldsCount;
	FullTableName = ?(IsBlankString(TableName), "", TableName + ".");
	AliasesToUse = New Map;
	Fields = New Array;
	
	For IndexOf = 0 To FieldsCount - 1 Do
		FieldName = FieldsNames[IndexOf];
		
		If HasAliases Then
			Alias = Aliases[IndexOf];
		Else
			Content = StrSplit(FieldName, ".");
			Alias = Content[Content.Count() - 1];
			AliasToUse = AliasesToUse[Alias];
			
			If AliasToUse = Undefined Then
				AliasesToUse[Alias] = 1;
			Else
				AliasesToUse[Alias] = AliasesToUse[Alias] + 1;
				Alias = Alias + Format(AliasesToUse[Alias], "NG=0");
			EndIf;
		EndIf;
		
		If CommonClientServer.NameMeetPropertyNamingRequirements(Alias) Then
			Alias = " AS " + Alias;
		Else
			Alias = "";
		EndIf;
		
		Name = FullTableName + FieldName + Alias;
		Fields.Add(Name);
	EndDo;
	
	Separator = ",
		|	";
	
	Return ?(Additional, Separator, "") + StrConcat(Fields, Separator);
	
EndFunction

// Generates a query text fragment with the specified order.
//
// Parameters:
//  FieldsNames - Array - field names as an array.
//  Directions - Array - ordering directions (ASC, and DESC) in the quantity equal to the FieldsNames quantity.
//              - Undefined - order is not specified (always ASC).
//  TableName - String - a name of a table that contains fields.
//                        if a blank row is specified, a table name is not inserted.
//  Additional - Boolean - True, if these are not the first fields in the selection and they require "," before them.
//
// Returns:
//  String - a query text fragment for ordering.
//
Function OrderingsForQuery(FieldsNames, Directions = Undefined, TableName = "", Additional = False)
	
	FieldsCount = FieldsNames.Count();
	
	If FieldsCount = 0 Then
		Return "";
	EndIf;
	
	FullTableName = ?(IsBlankString(TableName), "", TableName + ".");
	HasDirections = Directions <> Undefined And Directions.Count() = FieldsCount;
	Ordering = New Array;
	
	For IndexOf = 0 To FieldsCount - 1 Do
		FieldName = FieldsNames[IndexOf];
		
		If HasDirections Then
			CurrentDirection = Directions[IndexOf];
			Direction = ?(IsBlankString(CurrentDirection), "", " " + CurrentDirection);
		Else
			Direction = "";
		EndIf;
		
		Order = FullTableName + FieldName + Direction;
		Ordering.Add(Order);
	EndDo;
	
	Separator = ",
		|	";
	
	Return ?(Additional, Separator, "") + StrConcat(Ordering, Separator);
	
EndFunction

// Set size of the query filter that gets data for an update.
//
// Parameters:
//  QueryText - String - a modified query text.
//  Parameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
//
Procedure SetSelectionSize(QueryText, Parameters)
	
	SelectionSize = ?(Parameters.SelectInBatches, Parameters.MaxSelection, Undefined);
	ChangeSelectionMax(QueryText, 1000, SelectionSize);
	
EndProcedure

// Set query selection size (FIRST N).
//
// Parameters:
//  QueryText - String - text of a query to be modified.
//  CurrentCount - Number - the amount specified in the current query text.
//  NewCount - Number - a new value for "FIRST N".
//                  - Undefined - Select all (without FIRST N).
//
Procedure ChangeSelectionMax(QueryText, CurrentCount, NewCount)
	
	SearchText = "TOP " + Format(CurrentCount, "NZ=0; NG=0"); // @query-part
	
	If NewCount = Undefined Then
		ReplacementText = "";
	Else
		ReplacementText = "TOP " + Format(NewCount, "NZ=0; NG=0"); // @query-part
	EndIf;
	
	QueryText = StrReplace(QueryText, SearchText, ReplacementText);
	
EndProcedure

// Set selection fields considering multithread update handlers.
//
// Parameters:
//  Query - Query - a query to be modified.
//  FieldsNames - Array - names of fields to select.
//  Aliases - Array - aliases of fields to select.
//  TableName - String - a name of a table that contains fields.
//                        if a blank row is specified, a table name is not inserted.
//
Procedure SetFieldsByPages(Query, BuildParameters)
	
	SelectedFields = FieldsForQuery(BuildParameters.SelectionFields1,
		BuildParameters.Aliases,
		BuildParameters.TableName);
	
	Query.Text = StrReplace(Query.Text, "&SelectedFields", SelectedFields);
	
EndProcedure

// Set selection order considering multithread update handlers.
//
// Parameters:
//  Query - Query - The query to be modified.
//  FieldsNames - Array - Names of the fields to select.
//  Parameters -  See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
//  TableName - String - The source table name.
//                        If an empty string is passed, the table name won't be inserted.
//  Directions - Array - The ordering directions ("ASC" or "DESC"). The number of array items matches the number of "FieldsNames".
//              - Undefined - order is not specified (always ASC).
//
Procedure SetOrderByPages(Query, BuildParameters)
	
	SelectionFields1 = BuildParameters.SelectionFields1;
	TableName = BuildParameters.TableName;
	Directions = BuildParameters.Directions;
	
	If Directions.Count() = 0 Then
		Directions.Add("DESC");
		
		If BuildParameters.SelectionByPage Then
			For IndexOf = 1 To SelectionFields1.Count() - 1 Do
				Directions.Add("");
			EndDo;
		EndIf;
	EndIf;
	
	SelectionOrder = OrderingsForQuery(SelectionFields1, Directions, TableName);
	Query.Text = StrReplace(Query.Text, "&SelectionOrder", SelectionOrder);
	
EndProcedure

// Allows to determine if the selection is by pages.
//
// Parameters:
//   Parameters - See InfobaseUpdate.AdditionalProcessingDataSelectionParameters.
//
// Returns:
//  Boolean - True if the selection is multithread.
//
Function IsSelectionByPages(Parameters)
	
	Return Parameters.Property("SelectionMethod") And Parameters.SelectInBatches;
	
EndFunction

// Returns if ordering is ascending.
//
// Parameters:
//  Direction - String - an ordering direction to check.
//
// Returns:
//  Boolean - True if ordering is ascending, otherwise False.
//
Function OrderingAscending(Direction)
	
	If Direction = Undefined Then
		Return True;
	Else
		OrderInReg = Upper(Direction);
	
		// DontTranslate: "DESC".
		Return Not (OrderInReg = "DESC" Or OrderInReg = "DESC");
	EndIf;
	
EndFunction

// Returns the ">" operator for selection by pages considering the ordering direction.
//
// Parameters:
//  Direction - String - an ordering direction to check.
//
// Returns:
//  String - the ">", operator if Order = ASC, otherwise "<".
//
Function OperatorGreater(Direction)
	
	Return ?(OrderingAscending(Direction), ">", "<");
	
EndFunction

// Returns the "<" operator for selection by pages considering the ordering direction.
//
// Parameters:
//  Direction - String - an ordering direction to check.
//
// Returns:
//  String - the "<", operator if Order = ASC, otherwise ">".
//
Function OperatorLess(Direction)
	
	Return ?(OrderingAscending(Direction), "<", ">");
	
EndFunction

// Returns the ">=" operator for selection by pages considering the ordering direction.
//
// Parameters:
//  Direction - String - an ordering direction to check.
//
// Returns:
//  String - operator ">=", if Order = ASC, otherwise "<=".
//
Function OperatorGreaterOrEqual(Direction)
	
	Return ?(OrderingAscending(Direction), ">=", "<=");
	
EndFunction

// Returns the "<=" operator for selection by pages considering the ordering direction.
//
// Parameters:
//  Direction - String - an ordering direction to check.
//
// Returns:
//  String - operator "<=", if Order = ASC, otherwise ">=".
//
Function OperatorLessOrEqual(Direction)
	
	Return ?(OrderingAscending(Direction), "<=", ">=");
	
EndFunction

// Returns a metadata object name from its full name.
//
// Parameters:
//  FullName - String - Full name of a metadata object.
//
// Returns:
//  String - Metadata object name (after a dot).
//
Function MetadataObjectName(FullName)
	
	Position = StrFind(FullName, ".", SearchDirection.FromEnd);
	
	If Position > 0  Then
		Return Mid(FullName, Position + 1);
	Else
		Return FullName;
	EndIf;
	
EndFunction

// Returns if there are ordering fields.
//
// Parameters:
//  
Function OrderingFieldsAreSet(AdditionalParameters)
	
	Return AdditionalParameters.OrderFields.Count() > 0;
	
EndFunction

// Returns the data source type ( See AdditionalProcessingDataSelectionParameters
// , items 1 and 2).
//
// Parameters:
//  AdditionalDataSources - See AdditionalProcessingDataSelectionParameters
//
// Returns:
//  Boolean - True if it is a simple set of sources as in clause 1, False if it is a map hierarchy
//           as in clause 2.
//
Function IsSimpleDataSource(AdditionalDataSources)
	
	SimpleSource = False;
	ComplexSource = False;
	MapType = Type("Map");
	
	For Each KeyAndValue In AdditionalDataSources Do
		If TypeOf(KeyAndValue.Value) = MapType Then
			ComplexSource = True;
		Else
			SimpleSource = True;
		EndIf;
	EndDo;
	
	If SimpleSource And ComplexSource Then
		Error = NStr("en = 'Invalid data source (see %1).';");
		Error = StringFunctionsClientServer.SubstituteParametersToString(Error, "AdditionalProcessingDataSelectionParameters()");
		Raise Error;
	Else
		Return SimpleSource;
	EndIf;
	
EndFunction

Function IsEnum(TypeToCheck)
	
	Return Enums.AllRefsType().ContainsType(TypeToCheck);
	
EndFunction

// Add the queries that destruct the specified temporary tables to the query list.
//
// Parameters:
//  Queries - Array - an array to which query texts are added.
//  TemporaryTable - Map
//
Procedure AddRequestsToDeleteTUES(Queries, TemporaryTable)
	
	QueryTemplate =
		"DROP
		|	%1";
	
	For Each TempTable In TemporaryTable Do
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, TempTable.Value);
		Queries.Add(QueryText);
	EndDo;
	
EndProcedure

// Receive a collection value by a key, and if the key is not found, create a value of the specified type for the key.
//
// Parameters:
//   Collection - Map
//             - Structure - a collection in which a value is searched for.
//   Var_Key - Arbitrary - a key to search the value.
//   Type - String - type of the value to be created.
//
// Returns:
//  Map
//
Function TheValueForTheKey(Collection, Var_Key, Type = "Map")
	
	Value = Collection[Var_Key];
	
	If Value = Undefined Then
		Value = New(Type);
		Collection[Var_Key] = Value;
	EndIf;
	
	Return Value;
	
EndFunction

// Merge the specified query texts into a package.
//
// Parameters:
//  Queries - Array - query texts that must be merged.
//  TheSeparatorQueries - String
//                      - Undefined - a query separator text (by default, the same as the constructor has).
//
// Returns:
//  String - queries that are merged into a package.
//
Function CombineRequestsIntoABatch(Queries, TheSeparatorQueries = Undefined)
	
	If TheSeparatorQueries = Undefined Then
		Separator =
			"
			|;
			|
			|";
	Else
		Separator = TheSeparatorQueries;
	EndIf;
	
	Return StrConcat(Queries, Separator);
	
EndFunction

// Receive a data source as a structure with the TabularSection and Attribute fields.
//
// Parameters:
//  Source - String - a data source (a path to a header attribute or an object tabular section).
//
// Returns:
//  Structure:
//   * TabularSection - String - a table name (Undefined if the source is a header attribute).
//   * Attribute - String - an attribute name.
//
Function CompositionOfTheReferenceDataSource(Source)
	
	Content = StrSplit(Source, ".");
	LongDesc = New Structure("TabularSection, Attribute");
	
	If Content.Count() > 1 Then
		LongDesc.TabularSection = TrimAll(Content[0]);
		LongDesc.Attribute = TrimAll(Content[1]);
	Else
		LongDesc.Attribute = TrimAll(Content[0]);
	EndIf;
	
	Return LongDesc;
	
EndFunction

// A query text for creating a temporary table with references locked by table attributes.
//
// Parameters:
//  TSAttributes - Map of KeyAndValue:
//   * Key - String - the table name of a data source.
//   * Value - Map of KeyAndValue:
//     ** Key - MetadataObject - a metadata object that matches the data source type.
//     ** Value - Map of KeyAndValue:
//        *** Key - String - the tabular section attribute name of a data source.
//        *** Value - Boolean - True as the default value (it is not required as it is a set).
//  FullObjectName - String - the full name of a reference metadata object to be updated.
//  FullRegisterName - String - the full name of a register metadata object to be updated.
//  TemporaryTable - Map of KeyAndValue:
//   * Key - MetadataObject - for which a temporary table is created.
//   * Value - String - a temporary table name.
//
// Returns:
//  String - Query text.
//
Function RequestTextInTBlockedByPM(TSAttributes, FullObjectName, FullRegisterName, TemporaryTable)
	
	QueryTemplate =
		"SELECT
		|	&Attribute AS Ref
		|INTO LockedByTabularSection
		|FROM
		|	&ChangesTable AS ChangesTable
		|WHERE
		|	&Condition
		|INDEX BY
		|	Ref";
	ConditionTemplate =
		"TRUE IN " + "(" + "
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			#Table AS THOfTheDocumentFullNameOfTheObject
		|		WHERE
		|			&ConditionForATableField
		|			AND (&TextOfConditionsForBlockedUsers)" + ")";
	TemplateForBlockedConditions =
		"TRUE IN " + "(" + "
		|					SELECT TOP 1
		|						TRUE
		|					FROM
		|						#Table AS InTTheTableIsBlocked
		|					WHERE
		|						&ConditionForBlockedUsers" + ")";
	TemplateOfTheConditionForTheBankDetails = "TSDocument_%1.%2 = %3.Ref"; // @query-part
	ConditionSeparator =
		"
		|	OR ";
	ConditionSeparatorForBlockedItems =
		"
		|				OR ";
	ConditionSeparatorByBankDetails =
		"
		|						OR ";
	
	If FullRegisterName <> Undefined Then
		TableField = "Recorder";
		Table = FullRegisterName;
	Else
		TableField = "Ref";
		Table = FullObjectName;
	EndIf;
	
	Conditions = New Array;
	
	For Each TabularSectionDetails In TSAttributes Do
		TabularSection = TabularSectionDetails.Key;
		Metadata_Attributes = TabularSectionDetails.Value;
		ConditionsForBlockedUsers = New Array;
		
		For Each MetadataDetails In Metadata_Attributes Do
			SourceMetadata = MetadataDetails.Key;
			Attributes = MetadataDetails.Value;
			TableOfBlockedUsers = TemporaryTable[SourceMetadata];
			ConditionsForBankDetails = New Array;
			
			For Each AttributeDetails In Attributes Do
				Attribute = AttributeDetails.Key;
				ConditionForBankDetails = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfTheConditionForTheBankDetails,
					TabularSection,
					Attribute,
					TableOfBlockedUsers);
				ConditionsForBankDetails.Add(ConditionForBankDetails);
			EndDo;
			
			TextOfTermsAndConditionsByBankDetails = StrConcat(ConditionsForBankDetails, ConditionSeparatorByBankDetails);
			ConditionForBlockedUsers = StrReplace(TemplateForBlockedConditions, "#Table", TableOfBlockedUsers);
			ConditionForBlockedUsers = StrReplace(ConditionForBlockedUsers, "InTTheTableIsBlocked", TableOfBlockedUsers);
			ConditionForBlockedUsers = StrReplace(ConditionForBlockedUsers, "&ConditionForBlockedUsers", TextOfTermsAndConditionsByBankDetails);
			ConditionsForBlockedUsers.Add(ConditionForBlockedUsers);
		EndDo;
		
		TextOfConditionsForBlockedUsers = StrConcat(ConditionsForBlockedUsers, ConditionSeparatorForBlockedItems);
		Condition = StrReplace(ConditionTemplate, "#Table", FullObjectName + "." + TabularSection);
		Condition = StrReplace(Condition, "THOfTheDocumentFullNameOfTheObject", "TSDocument_" + TabularSection);
		Condition = StrReplace(Condition, "&ConditionForATableField", "ChangesTable." + TableField + " = TSDocument_"+ TabularSection + ".Ref");
		Condition = StrReplace(Condition, "&TextOfConditionsForBlockedUsers", TextOfConditionsForBlockedUsers);
		Conditions.Add(Condition);
	EndDo;
	
	ConditionsText = StrConcat(Conditions, ConditionSeparator);
	
	QueryText = StrReplace(QueryTemplate, "&Attribute", TableField);
	QueryText = StrReplace(QueryText, "&ChangesTable", Table + ".Changes");
	QueryText = StrReplace(QueryText, "&Condition", ConditionsText);
	
	Return QueryText;
	
EndFunction

// A query condition text for removing data locked by the register from the update.
//
// Parameters:
//  FullRegisterName - String - the full name of a register metadata object to be updated.
//  TemporaryTable - Map of KeyAndValue:
//   * Key - MetadataObject - for which a temporary table is created.
//   * Value - String - a temporary table name.
//
// Returns:
//  String - Query text.
//
Function TextOfTheConditionBlockedByRegisters(FullRegisterName, TemporaryTable)
	
	ConditionTemplate =
		"NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			%1 AS %1
		|		WHERE
		|			%2 = %1.Recorder)";
	ConditionSeparator =
		"
		|	AND ";
	Field = ?(FullRegisterName <> Undefined, "RegisterTableChanges.Recorder", "ObjectTable.Ref");
	Conditions = New Array;
	
	For Each DescriptionOfTheTemporaryTable In TemporaryTable Do
		TempTable = DescriptionOfTheTemporaryTable.Value;
		Condition = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, TempTable, Field);
		Conditions.Add(Condition);
	EndDo;
	
	Return StrConcat(Conditions, ConditionSeparator);
	
EndFunction

// A query condition text for removing data locked by table attributes from the update.
//
// Parameters:
//  FullObjectName - String - the full name of a reference metadata object to be updated.
//  FullRegisterName - String - the full name of a register metadata object to be updated.
//
// Returns:
//  String - Query text.
//
Function TextOfTheConditionBlockedByPM(FullObjectName, FullRegisterName)
	
	Field = ?(FullRegisterName <> Undefined, "RegisterTableChanges.Recorder", "ChangesTable.Ref");
	ConditionTemplate =
		"NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			LockedByTabularSection AS LockedByTabularSection
		|		WHERE
		|			%1 = LockedByTabularSection.Ref)";
	
	Return StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, Field);
	
EndFunction

// A query condition text for removing data locked by object header attributes from the update.
//
// Parameters:
//  HeaderAttributes - Map of KeyAndValue:
//   * Key - MetadataObject - a metadata object that matches the data source type.
//   * Value - Map of KeyAndValue:
//      ** Key - String - the tabular section attribute name of a data source.
//      ** Value - Boolean - True as the default value (it is not required as it is a set).
//  FullRegisterName - String - the full name of a register metadata object to be updated.
//  TemporaryTable - Map of KeyAndValue:
//   * Key - MetadataObject - for which a temporary table is created.
//   * Value - String - a temporary table name.
//
// Returns:
//  String - Query text.
//
Function TextOfTheConditionBlockedByHeader(HeaderAttributes, FullRegisterName, TemporaryTable)
	
	ConditionTemplate =
		"NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			%1 AS %1
		|		WHERE
		|			%2)";
	TemplateOfTheConditionForTheBankDetails = "%1.%2 = %3.Ref";
	ConditionSeparator =
		"
		|	AND ";
	ConditionSeparatorByBankDetails =
		"
		|			OR ";
	Table = ?(FullRegisterName <> Undefined, "DocumentTable", "ObjectTable");
	Conditions = New Array;
	
	For Each MetadataDetails In HeaderAttributes Do
		SourceMetadata = MetadataDetails.Key;
		TableOfBlockedUsers = TemporaryTable[SourceMetadata];
		Attributes = MetadataDetails.Value;
		ConditionsForBankDetails = New Array;
		
		For Each AttributeDetails In Attributes Do
			Attribute = AttributeDetails.Key;
			ConditionForBankDetails = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfTheConditionForTheBankDetails,
				Table,
				Attribute,
				TableOfBlockedUsers);
			ConditionsForBankDetails.Add(ConditionForBankDetails);
		EndDo;
		
		TextOfTermsAndConditionsByBankDetails = StrConcat(ConditionsForBankDetails, ConditionSeparatorByBankDetails);
		Condition = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate,
			TableOfBlockedUsers,
			TextOfTermsAndConditionsByBankDetails);
		Conditions.Add(Condition);
	EndDo;
	
	Return StrConcat(Conditions, ConditionSeparator);
	
EndFunction

// Generates a condition for filtering only unlocked dimension combinations.
//
// Parameters:
//  Dimensions - Array - names of dimensions to be filtered.
//
// Returns:
//  String - text of a filter criterion.
//
Function ConditionForSelectingUnblockedMeasurements(Dimensions)
	
	ConditionsForMeasurements = New Array;
	TemplateForAMeasurementCondition =
		"(ChangesTable.%1 = TTLockedDimensions.%1
		|				OR ChangesTable.%1 = &EmptyValueOfDimension%1
		|				OR TTLockedDimensions.%1 = &EmptyValueOfDimension%1)";
	ThePatternConditionForTheSelectionOfUnlocked =
		"	NOT TRUE IN (
		|		SELECT TOP 1
		|			TRUE
		|		FROM
		|			#TTLockedDimensions AS TTLockedDimensions
		|		WHERE
		|			%1)";
	SeparatorAnd =
		"
		|			AND ";
	
	For Each Dimension In Dimensions Do
		Condition = StringFunctionsClientServer.SubstituteParametersToString(TemplateForAMeasurementCondition, Dimension);
		ConditionsForMeasurements.Add(Condition);
	EndDo;
	
	ConditionsForAllDimensions = StrConcat(ConditionsForMeasurements, SeparatorAnd);
	Return StringFunctionsClientServer.SubstituteParametersToString(ThePatternConditionForTheSelectionOfUnlocked,
		ConditionsForAllDimensions);
	
EndFunction

Function TheObjectIsRegisteredOnTheExchangePlan(Data)
	
	ObjectType = TypeOf(Data);
	
	Cache = InfobaseUpdateInternalCached.CacheForCheckingRegisteredObjects();
	ItIsPartOf = Cache.Get(ObjectType);
	If ItIsPartOf <> Undefined Then
		Return ItIsPartOf;
	EndIf;
	
	MetadataObject = Metadata.FindByType(ObjectType);
	If MetadataObject = Undefined Then
		Cache.Insert(ObjectType, False);
		Return False;
	EndIf;
	
	ExchangePlanContent = Metadata.ExchangePlans.InfobaseUpdate.Content;
	ItIsPartOf = ExchangePlanContent.Contains(MetadataObject);
	Cache.Insert(ObjectType, ItIsPartOf);
	
	Return ItIsPartOf;
	
EndFunction

Procedure ResetHandlerState(Handler)
	
	HandlerUpdates = InformationRegisters.UpdateHandlers.CreateRecordManager();
	HandlerUpdates.HandlerName = Handler;
	HandlerUpdates.Read();
	
	HandlerUpdates.Status = Enums.UpdateHandlersStatuses.NotPerformed;
	HandlerUpdates.ProcessingDuration = 0;
	HandlerUpdates.AttemptCount = 0;
	HandlerUpdates.ExecutionStatistics = New ValueStorage(New Map);
	HandlerUpdates.ErrorInfo = "";
	HandlerUpdates.BatchProcessingCompleted = True;
	
	HandlerUpdates.Write();
	
EndProcedure

Procedure WriteProgressProgressHandler(Data, Node, ObjectMetadata = Undefined)
	
	ObjectsProcessed = 0;
	If (TypeOf(Data) = Type("Array")
		Or TypeOf(Data) = Type("ValueTable")) Then
		ObjectsProcessed = Data.Count();
	Else
		If ObjectMetadata = Undefined Then
			ObjectValueType = TypeOf(Data);
			ObjectMetadata  = Metadata.FindByType(ObjectValueType);
		EndIf;
		If Common.IsRefTypeObject(ObjectMetadata) Then
			FullName = ObjectMetadata.FullName();
			Query = New Query;
			Query.SetParameter("Node", Node);
			Query.SetParameter("Ref", Data.Ref);
			Query.Text = 
				"SELECT TOP 1
				|	TRUE
				|FROM
				|	&NameOfChangeTable AS ChangesTable1
				|WHERE
				|	ChangesTable1.Node = &Node
				|	AND ChangesTable1.Ref = &Ref";
			Query.Text = StrReplace(Query.Text, "&NameOfChangeTable", FullName + ".Changes"); // @query-part
			If Not Query.Execute().IsEmpty() Then
				ObjectsProcessed = 1;
			EndIf;
		Else
			If Data.Count() = 0 Then
				ObjectsProcessed = 1;
			Else
				ObjectsProcessed = Data.Count();
			EndIf;
		EndIf;
	EndIf;
	
	If ObjectsProcessed = 0 Then
		Return;
	EndIf;
	
	NewSessionParameters = InfobaseUpdateInternal.NewUpdateHandlerParameters();
	FillPropertyValues(NewSessionParameters, SessionParameters.UpdateHandlerParameters);
	NewSessionParameters.ProcessedObjectsCount1 = NewSessionParameters.ProcessedObjectsCount1 + ObjectsProcessed;
	
	If NewSessionParameters.ProgressLastRecordDate = Undefined
		Or CurrentSessionDate() - NewSessionParameters.ProgressLastRecordDate > 15 Then // More than 15 seconds since the last progress save.
		InfobaseUpdateInternal.WriteProgressProgressHandler(NewSessionParameters);
		
		NewSessionParameters.ProcessedObjectsCount1 = 0;
		NewSessionParameters.ProgressLastRecordDate = CurrentSessionDate();
	EndIf;
	
	SessionParameters.UpdateHandlerParameters = New FixedStructure(NewSessionParameters);
	
EndProcedure

Procedure SetHandlerParametersOnSelectData(AdditionalParameters, IsAllUpToDateDataProcessed, UpdateHandlerParameters, FullDocumentName = Undefined)
	
	If UpdateHandlerParameters = Undefined Then
		HandlerParameters = SessionParameters.UpdateHandlerParameters;
	Else
		HandlerParameters = UpdateHandlerParameters;
	EndIf;
	
	HandlerParameters = New Structure(HandlerParameters);
	If FullDocumentName = Undefined Then
		HandlerParameters.IsUpToDateDataProcessed = IsAllUpToDateDataProcessed;
	Else
		If HandlerParameters.ProcessedRecordersTables = Undefined Then
			ProcessedTables = CommonClientServer.ValueInArray(FullDocumentName);
		Else
			ProcessedTables = New Array(HandlerParameters.ProcessedRecordersTables);
			ProcessedTables.Add(FullDocumentName);
		EndIf;
		ProcessedTables = New FixedArray(ProcessedTables);
		HandlerParameters.ProcessedRecordersTables = ProcessedTables;
	EndIf;
	
	If UpdateHandlerParameters = Undefined Then
		SessionParameters.UpdateHandlerParameters = New FixedStructure(HandlerParameters);
	Else
		AdditionalParameters.UpdateHandlerParameters = New FixedStructure(HandlerParameters);
	EndIf;
	
EndProcedure

#EndRegion