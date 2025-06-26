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

// StandardSubsystems.AdditionalReportsAndDataProcessors

// Returns data about an external data processor.
//
// Returns:
//   See AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo
//
Function ExternalDataProcessorInfo() Export
	Var RegistrationParameters;
	
	If SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessorsClientServer = CommonModule("AdditionalReportsAndDataProcessorsClientServer");
		
		RegistrationParameters = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorInfo("2.1.3.1");// See AdditionalReportsAndDataProcessors.ExternalDataProcessorInfo 
		
		RegistrationParameters.Kind = ModuleAdditionalReportsAndDataProcessorsClientServer.DataProcessorKindAdditionalDataProcessor();
		RegistrationParameters.Version = "2.2.1";
		RegistrationParameters.SafeMode = False;
		
		NewCommand = RegistrationParameters.Commands.Add();
		NewCommand.Presentation = NStr("en = 'Bulk attribute edit';");
		NewCommand.Id = "OpenGlobally";
		NewCommand.Use = ModuleAdditionalReportsAndDataProcessorsClientServer.CommandTypeOpenForm();
		NewCommand.ShouldShowUserNotification = False;
	EndIf;
	
	Return RegistrationParameters;
	
EndFunction

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region Private

// For internal use.
Function QueryText(TypesOfObjectsToChange, RestrictSelection = False) Export
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(TypesOfObjectsToChange, ",", False) Do
		MetadataObjects.Add(Metadata.FindByFullName(ObjectName));
	EndDo;
	
	ObjectsStructure = CommonObjectsAttributes(TypesOfObjectsToChange);
	
	Result = "";
	TableAlias = "SpecifiedTableAlias";
	For Each MetadataObject In MetadataObjects Do
		
		If Not IsBlankString(Result) Then
			Result = Result + Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF;
		EndIf;
		
		QueryText = "";
		
		For Each AttributeName In ObjectsStructure.Attributes Do
			If Not IsBlankString(QueryText) Then
				QueryText = QueryText + "," + Chars.LF;
			EndIf;
			QueryText = QueryText + TableAlias + "." + AttributeName + " AS " + AttributeName;
		EndDo;
		
		For Each TabularSection In ObjectsStructure.TabularSections Do
			TabularSectionName = TabularSection.Key;
			QueryText = QueryText + "," + Chars.LF + TableAlias + "." + TabularSectionName + ".(";
			
			AttributesRow = "LineNumber";
			TabularSectionAttributes = TabularSection.Value;
			For Each AttributeName In TabularSectionAttributes Do
				If Not IsBlankString(AttributesRow) Then
					AttributesRow = AttributesRow + "," + Chars.LF;
				EndIf;
				AttributesRow = AttributesRow + TabularSectionName + "." +  AttributeName + " AS " + AttributeName; //@query-part-2
			EndDo;
			QueryText = QueryText + AttributesRow +"
			|)";
		EndDo;
		
		QueryText = "SELECT " + ?(RestrictSelection, "TOP 1001 ", "") //@query-part
			+ QueryText + Chars.LF + "

			|FROM
			|	"+ MetadataObject.FullName() + " AS " + TableAlias;
			
		Result = Result + QueryText;
	EndDo;
		
		
	Return Result;
	
EndFunction

Function CommonObjectsAttributes(ObjectsTypes) Export
	
	MetadataObjects = New Array;
	For Each ObjectName In StrSplit(ObjectsTypes, ",", False) Do
		MetadataObjects.Add(Metadata.FindByFullName(ObjectName));
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", New Array);
	Result.Insert("TabularSections", New Structure);
	
	If MetadataObjects.Count() = 0 Then
		Return Result;
	EndIf;	
		
	CommonAttributesList = ItemsList(MetadataObjects[0].Attributes, False);
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		CommonAttributesList = AttributesIntersection(CommonAttributesList, MetadataObjects[IndexOf].Attributes);
	EndDo;
	
	StandardAttributes = MetadataObjects[0].StandardAttributes;
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		StandardAttributes = AttributesIntersection(StandardAttributes, MetadataObjects[IndexOf].StandardAttributes);
	EndDo;
	For Each Attribute In StandardAttributes Do
		CommonAttributesList.Add(Attribute);
	EndDo;
	
	Result.Attributes = ItemsList(CommonAttributesList);
	
	TabularSections = ItemsList(MetadataObjects[0].TabularSections);
	For IndexOf = 1 To MetadataObjects.Count() - 1 Do
		TabularSections = SetIntersection(TabularSections, ItemsList(MetadataObjects[IndexOf].TabularSections));
	EndDo;
	
	For Each TabularSectionName In TabularSections Do
		TabularSectionAttributes = ItemsList(MetadataObjects[0].TabularSections[TabularSectionName].Attributes, False);
		For IndexOf = 1 To MetadataObjects.Count() - 1 Do
			TabularSectionAttributes = AttributesIntersection(TabularSectionAttributes, MetadataObjects[IndexOf].TabularSections[TabularSectionName].Attributes);
		EndDo;
		If TabularSectionAttributes.Count() > 0 Then
			Result.TabularSections.Insert(TabularSectionName, ItemsList(TabularSectionAttributes));
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction


// Parameters:
//   Collection - Array of MetadataObjectAttribute
//             - Array of MetadataObjectTabularSection
//   NamesOnly - Boolean
// Returns:
//   Array
//
Function ItemsList(Collection, NamesOnly = True)
	Result = New Array;
	For Each Item In Collection Do
		If NamesOnly Then
			Result.Add(Item.Name);
		Else
			Result.Add(Item);
		EndIf;
	EndDo;
	Return Result;
EndFunction

Function SetIntersection(Set1, Set2) Export
	
	Result = New Array;
	
	For Each Item In Set2 Do
		IndexOf = Set1.Find(Item);
		If IndexOf <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function AttributesIntersection(AttributesCollection1, AttributesCollection2)
	
	Result = New Array;
	
	For Each Attribute2 In AttributesCollection2 Do
		For Each Attribute1 In AttributesCollection1 Do
			If Attribute1.Name = Attribute2.Name 
				And (Attribute1.Type = Attribute2.Type Or Attribute1.Name = "Ref") Then
				Result.Add(Attribute1);
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// For internal use.
Function DataCompositionSchema(QueryText) Export
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
EndFunction

// For internal use.
Function ChangeObjects1(Parameters, ResultAddress) Export
	
	ObjectsToProcess = Parameters.ObjectsToProcess.Get().Rows;
	ObjectsForChanging   = Parameters.ObjectsForChanging.Get().Rows;
	
	ChangeResult = New Structure("HasErrors, ProcessingState");
	ChangeResult.HasErrors         = False;
	ChangeResult.ProcessingState = New Map;
	
	If ObjectsToProcess = Undefined Then
		ObjectsToProcess = New Array;// Array of AnyRef
		For Each ObjectToChange In ObjectsForChanging Do
			ObjectsToProcess.Add(ObjectToChange);
		EndDo;
	EndIf;
	
	If ObjectsToProcess.Count() = 0 Then
		PutToTempStorage(ChangeResult, ResultAddress);
		Return Undefined;
	EndIf;
	
	If Parameters.OperationType = "ExecuteAlgorithm" And DataSeparationEnabled() Then
		PutToTempStorage(ChangeResult, ResultAddress);
		Return Undefined;
	EndIf;
	
	StopChangeOnError = Parameters.StopChangeOnError;
	If StopChangeOnError = Undefined Then
		StopChangeOnError = Parameters.InterruptOnError;
	EndIf;
	
	RunAlgorithmCodeInSafeMode = (Parameters.ExecutionMode <> 1);
	
	IsExternalDataProcessor = IsExternalDataProcessor();
	If IsExternalDataProcessor Then
		Parameters.ExternalReportDataProcessor =
			?(ValueIsFilled(ExternalDataProcessorBinaryDataAddress),
				GetFromTempStorage(ExternalDataProcessorBinaryDataAddress), Undefined);
	EndIf;
	
	If Not IsLongRunningOperationsAvailable()
	 Or IsExternalDataProcessor 
	   And TypeOf(Parameters.ExternalReportDataProcessor) <> Type("BinaryData") Then
		
		ModificationSettings = ModificationSettings(Parameters, RunAlgorithmCodeInSafeMode);
		ObjectsBatchChangeResult(ObjectsToProcess, ChangeResult, ModificationSettings);
	Else
		Return RunObjectsChangeInMultipleThreads(Parameters, ObjectsToProcess, ChangeResult,
			StopChangeOnError, RunAlgorithmCodeInSafeMode);
	EndIf;
	
	PutToTempStorage(ChangeResult, ResultAddress);
	
	Return Undefined;
	
EndFunction

// Parameters:
//   Block - DataLock 
//   Ref - AnyRef
//
Procedure LockRef(Val Block, Val Ref)
	
	LockDataForEdit(Ref);
	LockItem = Block.Add(ObjectKindByRef(Ref) + "." + Ref.Metadata().Name);
	LockItem.SetValue("Ref", Ref);

EndProcedure

// Returns:
//   Structure:
//   * ObjectAttributesToChange - Array of String 
//   * AdditionalObjectAttributesToChange - Map
//   * AdditionalObjectInfoToChange - Map
//   * AddInfoRecordsArray - Array of InformationRegisterRecordManager.AdditionalInfo
//
Function MakeChanges(Val ObjectData, Val ObjectToChange, Val Parameters)
	
	Result = New Structure;
	Result.Insert("ObjectAttributesToChange",    New Array);
	Result.Insert("AdditionalObjectAttributesToChange", New Map);
	Result.Insert("AdditionalObjectInfoToChange",  New Map);
	Result.Insert("AddInfoRecordsArray",      New Array);
	Result.Insert("ExternalAttributesToChange",    New Map);
	
	AdditionalAttributes = New Array;
	For Each Operation In Parameters.AttributesToChange Do
		If Operation.OperationKind = 2 Then
			AdditionalAttributes.Add(Operation.Property);
		EndIf;
	EndDo;
	
	PropertiesOfAdditionalDetails = Undefined;
	If AdditionalAttributes.Count() > 0 Then
		ModuleCommon = CommonModule("Common");
		PropertiesOfAdditionalDetails = ModuleCommon.ObjectsAttributesValues(AdditionalAttributes, "ValueType, MultilineInputField");
	EndIf;
	
	// Run modification operations.
	For Each Operation In Parameters.AttributesToChange Do
		
		Value = EvalExpression(Operation.Value, ObjectToChange, Parameters.AvailableAttributes);
		If Operation.OperationKind = 1 Then // Change an attribute.
			
			If ObjectToChange[Operation.Name] = Null Then
				Continue;
			EndIf;
			
			ObjectToChange[Operation.Name] = Value;
			Result.ObjectAttributesToChange.Add(Operation.Name);
			
		ElsIf Operation.OperationKind = 2 Then // Change an additional attribute.
			
			If Not PropertyMustChange(ObjectToChange.Ref, Operation.Property, Parameters) Then
				Continue;
			EndIf;
			
			FoundRow   = ObjectToChange.AdditionalAttributes.Find(Operation.Property, "Property");
			PropsProperties = PropertiesOfAdditionalDetails[Operation.Property];
			CompositeType      = PropsProperties.ValueType.Types().Count() > 1;
			If (CompositeType And Value <> Undefined)
				Or (Not CompositeType And ValueIsFilled(Value)) Then
				If FoundRow = Undefined Then
					FoundRow = ObjectToChange.AdditionalAttributes.Add();
					FoundRow.Property = Operation.Property;
				EndIf;
				FoundRow.Value = Value;
				
				ModulePropertyManagerInternal = CommonModule("PropertyManagerInternal");
				If ModulePropertyManagerInternal.UseUnlimitedString(PropsProperties.ValueType, PropsProperties.MultilineInputField) Then
					FoundRow.TextString = Value;
				EndIf;
			Else
				If FoundRow <> Undefined Then
					ObjectToChange.AdditionalAttributes.Delete(FoundRow);
				EndIf;
			EndIf;
			
			FormAttributeName = AddAttributeNamePrefix() + StrReplace(String(Operation.Property.UUID()), "-", "_");
			Result.AdditionalObjectAttributesToChange.Insert(FormAttributeName, Value);
			
		ElsIf Operation.OperationKind = 3 Then // Change an additional information record.
			
			If Not PropertyMustChange(ObjectToChange.Ref, Operation.Property, Parameters) Then
				Continue;
			EndIf;
			
			RecordManager = InformationRegisters["AdditionalInfo"].CreateRecordManager();
			RecordManager.Object = ObjectToChange.Ref;
			RecordManager.Property = Operation.Property;
			RecordManager.Value = Value;
			Result.AddInfoRecordsArray.Add(RecordManager);
			
			FormAttributeName = AddInfoNamePrefix() + StrReplace(String(Operation.Property.UUID()), "-", "_");
			Result.AdditionalObjectInfoToChange.Insert(FormAttributeName, Value);
		
		ElsIf Operation.OperationKind = 4 Then // Update an external attribute.
			
			If Value = Undefined
			   And Operation.AllowedTypes.Types().Count() = 1 Then
				
				CastedValue = Operation.AllowedTypes.AdjustValue(Value);
			Else
				CastedValue = Value;
			EndIf;
			Result.ExternalAttributesToChange.Insert(Operation.Name, CastedValue);
			
		EndIf;
		
	EndDo;
	
	If Parameters.TabularSectionsToChange.Count() > 0 Then
		MakeChangesToTabularSections(ObjectToChange, ObjectData, Parameters.TabularSectionsToChange);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure RunAlgorithmCode(Val Object, Val AlgorithmCode, Val ExecuteInSafeMode)
	
	If ExecuteInSafeMode Or Not AccessRight("Administration", Metadata) Then
		AlgorithmCode = "Object = Parameters;
		|" + AlgorithmCode;
		ExecuteInSafeMode(AlgorithmCode, Object);
	Else
		Execute AlgorithmCode; // ACC:487 In error correction scenarios, the code can be executed on behalf of an Administrator.
	EndIf;
	
EndProcedure

Function DataSeparationEnabled()
	
	SaaSAvailable = Metadata.FunctionalOptions.Find("SaaSOperations");
	If SaaSAvailable <> Undefined Then
		OptionName1 = "SaaSOperations";
		Return IsSeparatedConfiguration() And GetFunctionalOption(OptionName1);
	EndIf;
	
	Return False;
	
EndFunction

// Returns a flag indicating if there are any common separators in the configuration.
//
// Returns:
//   Boolean
//
Function IsSeparatedConfiguration()
	
	HasSeparators = False;
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

Function DetermineWriteMode(Val ObjectToChange, Val IsDocument, Val DeveloperMode)
	
	WriteMode = Undefined;
	If DeveloperMode Then
		WriteMode = Undefined;
		ObjectToChange.DataExchange.Load = True;
	ElsIf IsDocument Then
		WriteMode = DocumentWriteMode.Write;
		If ObjectToChange.Posted Then
			WriteMode = DocumentWriteMode.Posting;
		ElsIf ObjectToChange.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow Then
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
	EndIf;
	Return WriteMode;

EndFunction

Function PropertyMustChange(Ref, Property, Parameters)
	
	If SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = CommonModule("PropertyManager");
		If ModulePropertyManager = Undefined Then
			Return False;
		EndIf;
	EndIf;
	
	ObjectKindByRef = ObjectKindByRef(Ref);
	If (ObjectKindByRef = "Catalog" Or ObjectKindByRef = "ChartOfCharacteristicTypes")
		And ObjectIsFolder(Ref) Then
		Return False;
	EndIf;
	
	If Not ModulePropertyManager.CheckObjectProperty(Ref, Property) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function FillCheckErrorsText()
	
	Result = "";
	ArrayOfMessages = GetUserMessages(True);
	
	For Each UserMessage In ArrayOfMessages Do
		Result = Result + UserMessage.Text + Chars.LF;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillChangeResult(Result, Ref, ErrorMessage)
	
	ChangeStatus = New Structure;
	ChangeStatus.Insert("ErrorCode", "Error");
	ChangeStatus.Insert("ErrorMessage", ErrorMessage);
	
	Result.ProcessingState.Insert(Ref, ChangeStatus);
	Result.HasErrors = True;
	
EndProcedure

Procedure FillAdditionalPropertiesChangeResult(Result, Ref, ObjectToChange, Changes = Undefined)
	
	ChangeStatus = New Structure;
	ChangeStatus.Insert("ErrorCode", "");
	ChangeStatus.Insert("ErrorMessage", "");
	ChangeStatus.Insert("ChangedAttributesValues", New Map);
	If Changes <> Undefined Then
		For Each AttributeName In Changes.ObjectAttributesToChange Do
			ChangeStatus.ChangedAttributesValues.Insert(AttributeName, ObjectToChange[AttributeName]);
		EndDo;
	EndIf;
	ChangeStatus.Insert("ChangedAddAttributesValues", 
		?(Changes <> Undefined, Changes.AdditionalObjectAttributesToChange, Changes));
	ChangeStatus.Insert("ChangedAddInfoValues", 
		?(Changes <> Undefined, Changes.AdditionalObjectInfoToChange, Changes));
	
	Result.ProcessingState.Insert(Ref, ChangeStatus);
	
EndProcedure

Function AddAttributeNamePrefix()
	Return "AdditionalAttribute5_";
EndFunction

Function AddInfoNamePrefix()
	Return "AdditionalInfoItem1_";
EndFunction

Procedure MakeChangesToTabularSections(ObjectToChange, ObjectData, ChangesToTabularSections)
	
	For Each TabularSectionChanges In ChangesToTabularSections Do
		TableName = TabularSectionChanges.Key;
		AttributesToChange = TabularSectionChanges.Value;
		For Each TableRow In ObjectToChange[TableName] Do
			If StringMatchesFilter(TableRow, ObjectData, TableName) Then
				For Each AttributeToChange In AttributesToChange Do
					TableRow[AttributeToChange.Name] = AttributeToChange.Value;
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// Parameters:
//   TableRow - ValueTableRow:
//   * LineNumber - Number
//   ObjectData - AnyRef
//   TableName - String
//
Function StringMatchesFilter(TableRow, ObjectData, TableName)
	
	Rows = ?(TypeOf(ObjectData) = Type("ValueTreeRow"), 
		ObjectData.Rows, ObjectData.TabularSections.Rows);
	
	Return Rows.FindRows(New Structure(TableName + "LineNumber", TableRow.LineNumber)).Count() = 1;
	
EndFunction

Procedure FillEditableObjectsCollection(AvailableObjects, ShowHiddenItems) Export

	MetadataObjectsCollections = New Array;
	MetadataObjectsCollections.Add(Metadata.Catalogs);
	MetadataObjectsCollections.Add(Metadata.Documents);
	MetadataObjectsCollections.Add(Metadata.BusinessProcesses);
	MetadataObjectsCollections.Add(Metadata.Tasks);
	MetadataObjectsCollections.Add(Metadata.ChartsOfCalculationTypes);
	MetadataObjectsCollections.Add(Metadata.ChartsOfCharacteristicTypes);
	MetadataObjectsCollections.Add(Metadata.ChartsOfAccounts);
	MetadataObjectsCollections.Add(Metadata.ExchangePlans);
	
	PrefixOfObjectsToDelete = "delete";
	ObjectsToDelete = New ValueList;
	
	ObjectsManagers = Undefined;
	ModuleCommon = Undefined;
	If SSLVersionMatchesRequirements() Then
		ObjectsManagers = ObjectsManagersForEditingAttributes();
		ModuleCommon = CommonModule("Common");
	EndIf;
	
	For Each MetadataObjectCollection In MetadataObjectsCollections Do
		For Each MetadataObject In MetadataObjectCollection Do
			If ModuleCommon <> Undefined
			   And Not ModuleCommon.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
				Continue;
			EndIf;
			If Not ShowHiddenItems Then
				If StrStartsWith(Lower(MetadataObject.Name),PrefixOfObjectsToDelete)
					Or IsInternalObject(MetadataObject, ObjectsManagers) Then
					Continue;
				EndIf;
			EndIf;
			
			If AccessRight("Update", MetadataObject) Then
				If StrStartsWith(Lower(MetadataObject.Name),PrefixOfObjectsToDelete) Then
					ObjectsToDelete.Add(MetadataObject.FullName(), MetadataObject.Presentation());
				Else 
					AvailableObjects.Add(MetadataObject.FullName(), MetadataObject.Presentation());
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	AvailableObjects.SortByPresentation();
	ObjectsToDelete.SortByPresentation();
	
	For Each Item In ObjectsToDelete Do
		AvailableObjects.Add(Item.Value, Item.Presentation);
	EndDo;
	
EndProcedure

Function IsInternalObject(Val MetadataObject, Val ObjectsManagers)
	
	AttributesEditingSettings = AttributesEditingSettings(MetadataObject, ObjectsManagers);
	
	ToEdit = AttributesEditingSettings.ToEdit;
	NotToEdit = AttributesEditingSettings.NotToEdit;
	
	If TypeOf(NotToEdit) = Type("Array") And NotToEdit.Find("*") <> Undefined
		Or TypeOf(ToEdit) = Type("Array") And Not ValueIsFilled(ToEdit) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function AttributesEditingSettings(MetadataObject, ObjectsManagers = Null) Export
	
	If ObjectsManagers = Null Then
		ObjectsManagers = ObjectsManagersForEditingAttributes();
	EndIf;
	
	ToEdit   = Undefined;
	NotToEdit = Undefined;
	
	If ObjectsManagers <> Undefined Then
		AvailableMethods = ObjectManagerMethodsForEditingAttributes(MetadataObject.FullName(), ObjectsManagers);
		If TypeOf(AvailableMethods) = Type("Array") And (AvailableMethods.Count() = 0
			Or AvailableMethods.Find("AttributesToEditInBatchProcessing") <> Undefined) Then
				ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
				ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
		EndIf;
	Else
		// For configurations without SSL or with an old SSL integrated,
		// identify if the object has editable attributes.
		ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
		Try
			ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
		Except
			// Method not found.
			ToEdit = Undefined;
		EndTry;
	EndIf;
	
	If ObjectsManagers <> Undefined Then
		If TypeOf(AvailableMethods) = Type("Array") And (AvailableMethods.Count() = 0
			Or AvailableMethods.Find("AttributesToSkipInBatchProcessing") <> Undefined) Then
				If ObjectManager = Undefined Then
					ObjectManager = ObjectManagerByFullName(MetadataObject.FullName());
				EndIf;
				NotToEdit = ObjectManager.AttributesToSkipInBatchProcessing();
		EndIf;
		
	Else
		// For configurations without SSL or with an old SSL integrated,
		// identify if the object has non-editable attributes.
		Try
			NotToEdit = ObjectManager.AttributesToSkipInBatchProcessing();
		Except
			// Method not found.
			NotToEdit = Undefined;
		EndTry;
	EndIf;
	
	If SSLVersionMatchesRequirements() Then
		ModuleSSLSubsystemsIntegration = CommonModule("SSLSubsystemsIntegration");
		ModuleBatchObjectsModificationOverridable = CommonModule("BatchEditObjectsOverridable");
		
		ModuleSSLSubsystemsIntegration.OnDefineEditableObjectAttributes(
			MetadataObject, ToEdit, NotToEdit);
		
		ModuleBatchObjectsModificationOverridable.OnDefineEditableObjectAttributes(
			MetadataObject, ToEdit, NotToEdit);
	EndIf;
	
	Result = New Structure;
	Result.Insert("ToEdit", ToEdit);
	Result.Insert("NotToEdit", NotToEdit);
	
	Return Result;
	
EndFunction

Function ObjectManagerMethodsForEditingAttributes(ObjectName, ObjectsManagers)
	
	InformationOnObjectManager = ObjectsManagers[ObjectName];
	If InformationOnObjectManager = Undefined Then
		Return "NotSupported";
	EndIf;
	AvailableMethods = StrSplit(InformationOnObjectManager, Chars.LF, False);
	Return AvailableMethods;
	
EndFunction

Function ObjectsManagersForEditingAttributes()
	
	ObjectsWithLockedAttributes = New Map;
	If Not SubsystemExists("StandardSubsystems.Core") Then
		Return ObjectsWithLockedAttributes;
	EndIf;
	
	ModuleSSLSubsystemsIntegration = CommonModule("SSLSubsystemsIntegration");
	ModuleBatchObjectsModificationOverridable = CommonModule("BatchEditObjectsOverridable");
	If ModuleSSLSubsystemsIntegration = Undefined Or ModuleBatchObjectsModificationOverridable = Undefined Then
		Return ObjectsWithLockedAttributes;
	EndIf;
	
	ModuleSSLSubsystemsIntegration.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	ModuleBatchObjectsModificationOverridable.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	
	Return ObjectsWithLockedAttributes;
	
EndFunction

Function SSLVersionMatchesRequirements() Export
	
	Try
		ModuleStandardSubsystemsServer = CommonModule("StandardSubsystemsServer");
	Except
		// Module doesn't exist.
		ModuleStandardSubsystemsServer = Undefined;
	EndTry;
	If ModuleStandardSubsystemsServer = Undefined Then 
		Return False;
	EndIf;
	
	SSLVersion = ModuleStandardSubsystemsServer.LibraryVersion();
	Return CompareVersions(SSLVersion, "3.1.10.127") >= 0;
	
EndFunction

Function IsLongRunningOperationsAvailable() Export
	Return SSLVersionMatchesRequirements() And SubsystemExists("StandardSubsystems.Core");
EndFunction

// Compares two versions in the String format.
//
// Parameters:
//  VersionString1  - String - the first version in the RR.{S|SS}.VV.BB format.
//  VersionString2  - String - the second version.
//
// Returns:
//   Number   - if VersionString1 > VersionString2, it is a positive number. If they are equal, it is 0.
//
Function CompareVersions(Val VersionString1, Val VersionString2) Export
	
	String1 = ?(IsBlankString(VersionString1), "0.0.0.0", VersionString1);
	String2 = ?(IsBlankString(VersionString2), "0.0.0.0", VersionString2);
	Version1 = StrSplit(String1, ".");
	If Version1.Count() <> 4 Then
		Raise SubstituteParametersToString(
			NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString1", VersionString1);
	EndIf;
	Version2 = StrSplit(String2, ".");
	If Version2.Count() <> 4 Then
		Raise SubstituteParametersToString(
			NStr("en = 'Invalid %1 parameter format: %2';"), "VersionString2", VersionString2);
	EndIf;
	
	Result = 0;
	For Digit = 0 To 3 Do
		Result = Number(Version1[Digit]) - Number(Version2[Digit]);
		If Result <> 0 Then
			Return Result;
		EndIf;
	EndDo;
	Return Result;
	
EndFunction

// Returns an object manager by the passed full name of a metadata object.
// Restriction: does not process business process route points.
//
// Parameters:
//  FullName - String - a full name of metadata object. Example: "Catalog.Company".
//
// Returns:
//  CatalogManager, DocumentManager, DataProcessorManager, InformationRegisterManager - an object manager.
// 
// Example:
//  CatalogManager = Common.ObjectManagerByFullName("Catalog.Companies");
//  EmptyRef = CatalogManager.EmptyRef();
//
Function ObjectManagerByFullName(FullName) Export
	Var MOClass, MetadataObjectName1, Manager;
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() >= 2 Then
		MOClass = NameParts[0];
		MetadataObjectName1  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register.
			Manager = CalculationRegisters;
		Else
			SubordinateMOClass = NameParts[2];
			SubordinateMOName = NameParts[3];
			If Upper(SubordinateMOClass) = "RECALCULATION" Then
				// Recalculate.
				Try
					Manager = CalculationRegisters[MetadataObjectName1].Recalculations;
					MetadataObjectName1 = SubordinateMOName;
				Except
					Manager = Undefined;
				EndTry;
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MetadataObjectName1];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise SubstituteParametersToString(NStr("en = 'Unknown metadata object type: %1.';"), FullName);
	
EndFunction

Function EvalExpression(Val Expression, Object, AvailableAttributes)
	
	If Not(TypeOf(Expression) = Type("String") And StrStartsWith(Expression, "=")) Then
		Return Expression;
	EndIf;
		
	If StrStartsWith(Expression, "'=") Then
		Return Mid(Expression, 2);
	EndIf;
	
	Expression = Mid(Expression, 2);
	
	For Each AttributeDetails In AvailableAttributes Do
		If StrFind(Expression, "[" + AttributeDetails.Presentation + "]") = 0 Then
			Continue;
		EndIf;
		
		Value = "";
		If AttributeDetails.OperationKind = 1 Then
			Value = Object[AttributeDetails.Name];
			
		ElsIf AttributeDetails.OperationKind < 4 Then
			ModulePropertyManager = CommonModule("PropertyManager");
			ListOfProperties = New Array;
			ListOfProperties.Add(AttributeDetails.Property);
			PropertiesValues = ModulePropertyManager.PropertiesValues(Object.Ref, True, True, ListOfProperties);
			For Each TableRow In PropertiesValues.FindRows(New Structure("Property", AttributeDetails.Property)) Do
				Value = TableRow.Value;
			EndDo;
		Else
			ErrorText = SubstituteParametersToString(
				NStr("en = 'Expressions do not support the ""%1"" attribute';"), AttributeDetails.Presentation);
			Raise ErrorText;
		EndIf;
		
		Expression = StrReplace(Expression, "[" + AttributeDetails.Presentation + "]", """" 
			+ StrReplace(StrReplace(Value, """", """"""), Chars.LF, Chars.LF + "|") + """");
	EndDo;
	
	Return CalculateInSafeMode(Expression);
	
EndFunction

Procedure DisableAccessKeysUpdate(Disconnect, ScheduleUpdate1 = True)
	
	If Not SSLVersionMatchesRequirements() Then
		Return;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.Users") Then
		ModuleUsers = CommonModule("Users");
		If Not ModuleUsers.IsFullUser() Then
			Return;
		EndIf;
	EndIf;
	
	If SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(Disconnect, ScheduleUpdate1);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone mode support.

// Returns the name of a kind
// for a referenced metadata object.
//
// Does not regard business process route points.
//
// Parameters:
//  Ref - AnyRef
//
// Returns:
//  String
//
Function ObjectKindByRef(Ref) Export
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns the name of a kind for a metadata object of a specific type.
//
// Does not regard business process route points.
//
// Parameters:
//  Type       - an applied object type defined in the configuration.
//
// Returns:
//  String       - Metadata object kind name. For example, Catalog or Document.
// 
Function ObjectKindByType(Type) Export
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise SubstituteParametersToString(NStr("en = 'Invalid parameter value type: %1.';"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is an item group.
//
// Parameters:
//  Object       - Object, Reference, FormDataStructure for the Object type.
//
// Returns:
//  Boolean
//
Function ObjectIsFolder(Object) Export
	
	If RefTypeValue(Object) Then
		Ref = Object;
	Else
		//@skip-check reading-attribute-from-database - Data is being read from an object.
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If Metadata.Catalogs.Contains(ObjectMetadata) Then
		
		If Not ObjectMetadata.Hierarchical
		 Or ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf Not Metadata.ChartsOfCharacteristicTypes.Contains(ObjectMetadata) Then
		Return False;
		
	ElsIf Not ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder");
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value - AnyRef
//
// Returns:
//  Boolean
//
Function RefTypeValue(Value) Export
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a structure containing attribute values retrieved from the infobase
// using the object reference.
// 
//  If access to any of the attributes is denied, an exception is raised.
//  To read attribute values regardless of current user rights,
//  enable privileged mode.
// 
// Parameters:
//  Ref    - AnyRef
//
//  Attributes - String - attribute names separated with commas, formatted
//              according to structure requirements.
//              Example: "Code, Description, Parent".
//            - Structure
//            - FixedStructure - keys are field aliases used for resulting structure
//              keys, values (optional) are field names. If a value is empty,
//              it is considered equal to the key.
//              If a value is empty, it is considered equal to the key.
//            - Array
//            - FixedArray - attribute names formatted according to
//              structure property requirements.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If the string of the requested attributes is empty, an empty structure is returned.
//
Function ObjectAttributesValues(Ref, Val Attributes) Export
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StrSplit(Attributes, ",", False);
	EndIf;
	
	AttributesStructure1 = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure1 = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributesStructure1.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise SubstituteParametersToString(NStr("en = 'Invalid Attributes parameter type: %1.';"), String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributesStructure1 Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|	&FieldTexts
	|FROM
	|	&TableName AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref
	|";
	Query.Text = StrReplace(Query.Text, "&FieldTexts", FieldTexts);
	Query.Text = StrReplace(Query.Text, "&TableName", Ref.Metadata().FullName());
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributesStructure1 Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns attribute values retrieved from the infobase using the object reference.
//
//  If access to the attribute is denied, an exception is raised.
//  To read attribute values regardless of current user rights,
//  enable privileged mode.
//
// Parameters:
//  Ref    - AnyRef
//  AttributeName - String - for example, "Code".
//
// Returns:
//  Arbitrary    - Depends on the type of the read attribute.
//
Function ObjectAttributeValue(Ref, AttributeName) Export
	
	Result = ObjectAttributesValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns True if a subsystem exists.
//
// Parameters:
//  FullSubsystemName - String - the full name of the subsystem metadata object, excluding word "Subsystem.".
//                        Example: "StandardSubsystems.Core".
//
// Example of calling an optional subsystem:
//
//  If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
//  	ModuleAccessManagement = Common.CommonModule("AccessManagement");
//  	ModuleAccessManagement.<Method name>();
//  EndIf;
//
// Returns:
//  Boolean
//
Function SubsystemExists(FullSubsystemName) Export
	
	SubsystemsNames = SubsystemsNames();
	Return SubsystemsNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a map between subsystem names and the True value;
Function SubsystemsNames() Export
	
	Return New FixedMap(SubordinateSubsystemsNames(Metadata));
	
EndFunction

Function SubordinateSubsystemsNames(ParentSubsystem)
	
	Names = New Map;
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		Names.Insert(CurrentSubsystem.Name, True);
		SubordinatesNames = SubordinateSubsystemsNames(CurrentSubsystem);
		
		For Each SubordinateFormName In SubordinatesNames Do
			Names.Insert(CurrentSubsystem.Name + "." + SubordinateFormName.Key, True);
		EndDo;
	EndDo;
	
	Return Names;
	
EndFunction

// Returns a reference to the common module by the name.
//
// Parameters:
//  Name          - String - a common module name, for example:
//                 "Common",
//                 "CommonClient".
//
// Returns:
//  CommonModule
//
Function CommonModule(Name) Export
	
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name); // ACC:488 "Calculate" instead of "Common.CalculateInSafeMode" because it's a standalone data processor.
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("en = 'Common module ""%1"" does not exist.';"), Name);
	EndIf;
	
	Return Module;
	
EndFunction

Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

// ACC:487-off - A copy of "ExecuteInSafeMode" and "CalculateInSafeMode"
// of the "Common" module as the data processor is rejected.

// Executes an arbitrary algorithm in the 1C:Enterprise script, setting
//  the safe mode of script execution and the safe mode of data separation
//  for all separators of the configuration. As the result, when the algorithm is being executed:
//   - attempts to set the privileged mode are ignored;
//   - all external (relative to the 1C:Enterprise platform) actions (COM, =
//       add-in loading, external application startup, operating system command execution,
//       file system and Internet resource access) are prohibited;
//   - session separators cannot be disabled;
//   - session separator values cannot be changed (if data separation
//       is not disabled conditionally);
//   - objects that manage the conditional separation state cannot be changed.
//
// Parameters:
//  Algorithm - String - containing an arbitrary algorithm in the 1C:Enterprise language.
//  Parameters - Arbitrary - any value as might be required
//    for the algorithm. The algorithm code must refer to this value
//    as the Parameters variable.
//
Procedure ExecuteInSafeMode(Val Algorithm, Val Parameters = Undefined)
	
	SetSafeMode(True);
	
	SeparatorArray = ConfigurationSeparators();
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Execute Algorithm;
	
EndProcedure

// Evaluates the passed expression, setting the safe mode of script execution
// and the safe mode of data separation for all separators of the configuration.
//
// Parameters:
//  Expression - String - an expression in the 1C:Enterprise language.
//  Parameters - Arbitrary - the context required to calculate the expression.
//    To address the context in the expression text, use "Parameters" name.
//    For example, expression "Parameters.Value1 = Parameters.Value2" addresses values
//    Value1 and Value2 that were passed to Parameters as properties.
//
// Returns:
//   Arbitrary - the result of the expression calculation.
//
// Example:
//
//  // Example 1
//  Parameters = New Structure;
//  Parameters.Insert("Value1", 1);
//  Parameters.Insert("Value2", 10);
//  Result = Common.ExecuteInSafeMode("Parameters.Value1 = Parameters.Value2", Parameters);
//
//  // Example 2
//  Result = Common.ExecuteInSafeMode("StandardSubsystemsServer.LibraryVersion()");
//
Function CalculateInSafeMode(Val Expression, Val Parameters = Undefined)
	
	SetSafeMode(True);
	
	If SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = CommonModule("SaaSOperations");
		SeparatorArray = ModuleSaaSOperations.ConfigurationSeparators();
	Else
		SeparatorArray = New Array;
	EndIf;
	
	For Each SeparatorName In SeparatorArray Do
		
		SetDataSeparationSafeMode(SeparatorName, True);
		
	EndDo;
	
	Return Eval(Expression);
	
EndFunction

// ACC:487-on

// Returns an array of the separators that are in the configuration.
//
// Returns:
//   FixedArray of String - an array of names of common attributes which
//  serve as separators.
//
Function ConfigurationSeparators() Export
	
	SeparatorArray = New Array;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			SeparatorArray.Add(CommonAttribute.Name);
		EndIf;
	EndDo;
	
	Return New FixedArray(SeparatorArray);
	
EndFunction

#Region MultiThreadedObjectModification

// ACC:581-off Export as it is called from a background job.
Function ObjectsBatchChangeResult(ObjectsToProcess, ChangeResult, ModificationSettings) Export

	Ref         = Undefined;
	WriteError = True;
	
	ModuleUsersInternal = CommonModule("UsersInternal");
	If ModuleUsersInternal = Undefined
	 Or Not SSLVersionMatchesRequirements() Then
		ModuleUsersInternal = Undefined;
	EndIf;
	
	DisableAccessKeysUpdate(True);
	If ModificationSettings.ChangeInTransaction Then
		BeginTransaction();
	EndIf;
	
	Try
		If ModificationSettings.ChangeInTransaction Then
			Block = New DataLock;
			For Each ObjectData In ObjectsToProcess Do
				Ref = ObjectData.Ref;
				LockRef(Block, ObjectData.Ref);
			EndDo;
			Block.Lock();
		EndIf;
		
		For Each ObjectData In ObjectsToProcess Do
			
			WriteError = True;
			BeginTransaction();
			Try
				
				Ref = ObjectData.Ref;
				If Not ModificationSettings.ChangeInTransaction Then
					Block = New DataLock;
					LockRef(Block, Ref);
					Block.Lock();
				EndIf;
				
				ObjectToChange = Ref.GetObject();
				
				Changes = Undefined;
				If ModificationSettings.OperationType = "ExecuteAlgorithm" Then
					RunAlgorithmCode(ObjectToChange, ModificationSettings.AlgorithmCode,
						ModificationSettings.RunAlgorithmCodeInSafeMode);
				Else
					Changes = MakeChanges(ObjectData, ObjectToChange, ModificationSettings);
				EndIf;
				
				// Write mode.
				IsDocument = Metadata.Documents.Contains(ObjectToChange.Metadata());
				WriteMode = DetermineWriteMode(ObjectToChange, IsDocument, ModificationSettings.DeveloperMode);
				
				// Validate value population.
				If Not ModificationSettings.DeveloperMode Then
					If Not IsDocument Or WriteMode = DocumentWriteMode.Posting Then
						If Not ObjectToChange.CheckFilling() Then
							Raise FillCheckErrorsText();
						EndIf;
					EndIf;
				EndIf;
				
				// Write additional info.
				If Changes <> Undefined And Changes.AddInfoRecordsArray.Count() > 0 Then
					For Each RecordManager In Changes.AddInfoRecordsArray Do
						RecordManager.Write(True);
					EndDo;
				EndIf;
				
				If ModuleUsersInternal <> Undefined
				   And Changes <> Undefined
				   And ValueIsFilled(Changes.ExternalAttributesToChange) Then
					
					ModuleUsersInternal.OnChangeExternalAttributes(ObjectToChange,
						Changes.ExternalAttributesToChange);
				EndIf;
				
				ChangesAreConfigured = ValueIsFilled(ModificationSettings.AttributesToChange)
					Or ValueIsFilled(ModificationSettings.TabularSectionsToChange);
				
				MustWriteObject = ModificationSettings.ObjectWriteOption <> "NotWrite"
					And (ObjectToChange.Modified() Or Not ChangesAreConfigured);
				
				// Write the object.
				If MustWriteObject Then
					If WriteMode <> Undefined Then
						ObjectToChange.Write(WriteMode);
					Else
						ObjectToChange.Write();
					EndIf;
				EndIf;
				
				FillAdditionalPropertiesChangeResult(ChangeResult, Ref, ObjectToChange, Changes);
				
				UnlockDataForEdit(Ref);
				CommitTransaction();
				
			Except
				
				RollbackTransaction();
				If ModificationSettings.ChangeInTransaction Then
					UnlockDataForEdit(Ref);
				EndIf;
				
				FillChangeResult(ChangeResult, Ref, ErrorInfo());
				If ModificationSettings.StopChangeOnError Or ModificationSettings.ChangeInTransaction Then
					WriteError = False;
					Raise;
				EndIf;
				
				Continue;
			EndTry;
			
		EndDo;
		
		DisableAccessKeysUpdate(False);
		If ModificationSettings.ChangeInTransaction Then
			CommitTransaction();
		EndIf;
		
	Except
		
		If ModificationSettings.ChangeInTransaction Then 
			RollbackTransaction();
			For Each ObjectData In ObjectsToProcess Do
				UnlockDataForEdit(ObjectData.Ref);
			EndDo;
		EndIf;
		
		DisableAccessKeysUpdate(False, ModificationSettings.ChangeInTransaction);
		
		If WriteError Then
			BriefErrorDescription = ErrorProcessing.BriefErrorDescription(ErrorInfo());
			FillChangeResult(ChangeResult, Ref, BriefErrorDescription);
		EndIf;
		
	EndTry;
	
	Return ChangeResult;
	
EndFunction
// ACC:581-on

Function RunObjectsChangeInMultipleThreads(Parameters, ObjectsToProcess, ChangeResult,
		StopChangeOnError, RunAlgorithmCodeInSafeMode)
	
	FormIdentifier = New UUID;
	
	ModuleTimeConsumingOperations = CommonModule("TimeConsumingOperations");
	
	ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Bulk attribute edit';");
	
	IsExternalDataProcessor = IsExternalDataProcessor();
	If IsExternalDataProcessor Then
		ExecutionParameters.ExternalReportDataProcessor = Parameters.ExternalReportDataProcessor;
	EndIf;
	
	BatchesArray    = New Array;
	PortionOfObjects  = New Array;
	ObjectsCounter = 0;
	
	LongRunningOperationsThreadCount = ModuleTimeConsumingOperations.AllowedNumberofThreads();
	
	ShouldProcessInSingleThread = Parameters.ChangeInTransaction Or Parameters.InterruptOnError; 
	If LongRunningOperationsThreadCount > 0 And Not ShouldProcessInSingleThread Then
		ObjectCountInBatch = Int(ObjectsToProcess.Count() / LongRunningOperationsThreadCount);
	Else
		ObjectCountInBatch = ObjectsToProcess.Count();
	EndIf;
	
	TabularSectionsDetails = TabularSectionsDetails(Parameters);
	
	For Each ObjectData In ObjectsToProcess Do
		If ObjectsCounter = ObjectCountInBatch Then
			BatchesArray.Add(PortionOfObjects);
			PortionOfObjects  = New Array;
			ObjectsCounter = 0;
		EndIf;
		
		TabularSections = TabularSectionsDetails.Copy();
		
		AddValueTreeRowsRecursively(TabularSections, ObjectData);
		
		DataOfBatch = New Structure;
		DataOfBatch.Insert("Ref",         ObjectData.Ref);
		DataOfBatch.Insert("TabularSections", TabularSections);
		
		PortionOfObjects.Add(DataOfBatch);
		
		ObjectsCounter = ObjectsCounter + 1;
	EndDo;
	
	If PortionOfObjects.Count() > 0 Then
		BatchesArray.Add(PortionOfObjects);
	EndIf;
	
	MethodParameters      = New Map;
	BatchesUpperBound = BatchesArray.UBound();
	
	ModificationSettings = ModificationSettings(Parameters, RunAlgorithmCodeInSafeMode);
	
	For BatchIndex = 0 To BatchesUpperBound Do
		ParametersArray = New Array;
		ParametersArray.Add(BatchesArray[BatchIndex]);
		ParametersArray.Add(ChangeResult);
		ParametersArray.Add(ModificationSettings);
		
		MethodParameters.Insert(BatchIndex, ParametersArray);
	EndDo;
	
	FunctionName = StrTemplate("%1.BatchEditAttributes.ObjectModule.ObjectsBatchChangeResult",
		?(IsExternalDataProcessor, "ExternalDataProcessor", "DataProcessor"));
	
	ExecutionResult = ModuleTimeConsumingOperations.ExecuteFunctionInMultipleThreads(FunctionName,
		ExecutionParameters, MethodParameters);
		
	Return ExecutionResult;
	
EndFunction

Function TabularSectionsDetails(Parameters)

	TabularSectionsDetails = New ValueTree;
	
	ObjectsForChanging = Parameters.ObjectsForChanging.Get();
	If ObjectsForChanging = Undefined Then
		ObjectsForChanging = Parameters.ObjectsToProcess.Get();
	EndIf;
	
	For Each Column In ObjectsForChanging.Columns Do
		TabularSectionsDetails.Columns.Add(Column.Name, Column.ValueType, Column.Title, Column.Width);
	EndDo;
	
	Return TabularSectionsDetails;
	
EndFunction

Procedure AddValueTreeRowsRecursively(Recipient, Source)
	
	For Each SourceRow1 In Source.Rows Do
		
		CurrentRow = Recipient.Rows.Add();
		FillPropertyValues(CurrentRow, SourceRow1);
		
		If SourceRow1.Rows.Count() > 0 Then
			AddValueTreeRowsRecursively(CurrentRow, SourceRow1);
		EndIf;
		
	EndDo;
	
EndProcedure

// For internal use.
Function IsExternalDataProcessor()
	
	ObjectStructure = New Structure;
	ObjectStructure.Insert("UsedFileName", Undefined);
	FillPropertyValues(ObjectStructure, ThisObject);
	
	Return (ObjectStructure.UsedFileName <> Undefined);
	
EndFunction

Function ModificationSettings(Parameters, RunAlgorithmCodeInSafeMode)
	
	ModificationSettings = New Structure;
	ModificationSettings.Insert("ObjectWriteOption");
	ModificationSettings.Insert("RunAlgorithmCodeInSafeMode", RunAlgorithmCodeInSafeMode);
	ModificationSettings.Insert("AvailableAttributes");
	ModificationSettings.Insert("AttributesToChange");
	ModificationSettings.Insert("TabularSectionsToChange");
	ModificationSettings.Insert("ChangeInTransaction");
	ModificationSettings.Insert("AlgorithmCode");
	ModificationSettings.Insert("StopChangeOnError");
	ModificationSettings.Insert("DeveloperMode");
	ModificationSettings.Insert("OperationType");
	
	FillPropertyValues(ModificationSettings, Parameters);
	
	Return ModificationSettings;
	
EndFunction

#EndRegion

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf