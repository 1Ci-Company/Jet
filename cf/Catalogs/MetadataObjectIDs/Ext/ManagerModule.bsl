///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Not MobileStandaloneServer Then

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
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchEditObjects

// SaaSTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//
// Returns:
//  Array of String - Array of attribute names used to generate a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array;
	Result.Add("FullName");
	
	Return Result;
	
EndFunction

// End SaaSTechnology.ExportImportData

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing) Export
	
	StandardProcessing = False;
	
	Fields.Add("Ref");
	Fields.Add("Description");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing) Export
	
	If Not ValueIsFilled(Data.Ref) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Presentation = StandardSubsystemsCached.MetadataObjectIDPresentation(Data.Ref);
#Else
	Presentation = StandardSubsystemsClientCached.MetadataObjectIDPresentation(Data.Ref);
#EndIf
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Parameters:
//  SessionParametersNames - String
//  SpecifiedParameters - Array of String
//
Procedure SessionParametersSetting(SessionParametersNames, SpecifiedParameters) Export
	
	If SessionParametersNames.Find("UpdateIDCatalogs") = Undefined Then
		Return;
	EndIf;
	
	Result = New Structure;
	Result.Insert("MetadataObjectIDs", False);
	Result.Insert("ExtensionObjectIDs", False);
	
	SessionParameters.UpdateIDCatalogs = New FixedStructure(Result);
	
	SpecifiedParameters.Add("UpdateIDCatalogs");
	
EndProcedure

// For internal use only.
Procedure CheckForUsage(ExtensionsObjects = False) Export
	
	If StandardSubsystemsCached.DisableMetadataObjectsIDs() Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ""%1"" catalog is not used.';"), CatalogDescription(ExtensionsObjects));
		Raise ErrorText;
	EndIf;
	
	If ExtensionsObjects And Not Common.SeparatedDataUsageAvailable() Then
		ErrorText = ExtensionObjectsIDsUnvailableInSharedModeErrorDescription();
		Raise ErrorText;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MasterNode() = Undefined
	   And ValueIsFilled(Common.ObjectManagerByFullName("Constant.MasterNode").Get()) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot use catalog ""%1"" in an infobase whose
			           |master node disconnection was not confirmed.
			           |
			           |To reconnect with the master node, run 1C:Enterprise and click ""Restore"".
					   |Alternatively, set the master node programmatically in the ""MasterNode"" constant.
			           |
			           |To confirm the disconnection, run 1C:Enterprise and click ""Disconnect"".
					   |Alternatively, programmatically clear the value of the ""MasterNode"" constant.';"),
			CatalogDescription(ExtensionsObjects));
		Raise ErrorText;
	EndIf;
	
EndProcedure

// Returns True if the check, update, and search for duplicates are completed.
//
// Parameters:
//  Refresh - Boolean - If True, tries to update
//             the data. If fails, an exception is thrown.
//             If False, the function returns the data state.
//  
//  ExtensionsObjects - Boolean
//
// Returns:
//  Boolean
//
Function IsDataUpdated(Refresh = False, ExtensionsObjects = False) Export
	
	Try
		Updated = StandardSubsystemsServer.ApplicationParameter(
			"StandardSubsystems.Core.MetadataObjectIDs");
	Except
		If Refresh Then
			Raise;
		EndIf;
		Return False;
	EndTry;
	
	If Updated = Undefined Then
		If Refresh Then
			UpdateCatalogData();
		Else
			Return False;
		EndIf;
	EndIf;
	
	If ExtensionsObjects
	   And ValueIsFilled(SessionParameters.AttachedExtensions) Then
		
		If Not Common.SeparatedDataUsageAvailable() Then
			If Refresh Then
				ErrorText = ExtensionObjectsIDsUnvailableInSharedModeErrorDescription();
				Raise ErrorText;
			Else
				Return False;
			EndIf;
		EndIf;
		
		If Not Catalogs.ExtensionObjectIDs.CurrentVersionExtensionObjectIDsFilled() Then
			Catalogs.ExtensionObjectIDs.UpdateCatalogData();
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// For internal use only.
//
// Parameters:
//  Objects - Array of CatalogObject.MetadataObjectIDs
//
Procedure ImportDataToSubordinateNode(Objects) Export
	
	If Common.DataSeparationEnabled() Then
		// Not supported in SaaS mode.
		Return;
	EndIf;
	
	If Not Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	CheckForUsage();
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	Block = New DataLock;
	Block.Add("Catalog.MetadataObjectIDs");
	
	BeginTransaction();
	Try
		Block.Lock();
		
		// Preparing the outgoing table with renaming for searching for duplicates.
		Upload0 = ExportAllIDs();
		Upload0.Columns.Add("DuplicateUpdated", New TypeDescription("Boolean"));
		Upload0.Columns.Add("FullNameLowerCase", New TypeDescription("String"));
		
		// Applying a filter to the objects to be imported. The filter returns only objects that differ from the existing ones.
		ItemsToImportTable = New ValueTable;
		ItemsToImportTable.Columns.Add("Object");
		ItemsToImportTable.Columns.Add("Ref");
		ItemsToImportTable.Columns.Add("MetadataObjectByKey");
		ItemsToImportTable.Columns.Add("MetadataObjectByFullName");
		ItemsToImportTable.Columns.Add("Matches", New TypeDescription("Boolean"));
		
		For Each Object In Objects Do
			ItemToImportProperties = ItemsToImportTable.Add();
			ItemToImportProperties.Object = Object;
			
			If ValueIsFilled(Object.Ref) Then
				ItemToImportProperties.Ref = Object.Ref;
			Else
				ItemToImportProperties.Ref = Object.GetNewObjectRef();
				If Not ValueIsFilled(ItemToImportProperties.Ref) Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Could not import the metadata object ids from the master node.
						           |No reference is specified for the new item:
						           |""%1"".';"),
						Object.FullName);
					Raise ErrorText;
				EndIf;
			EndIf;
			
			// Preliminary processing.
			
			If Not IsCollection(ItemToImportProperties.Ref) Then
				ItemToImportProperties.MetadataObjectByKey = MetadataObjectByKey(
					Object.MetadataObjectKey.Get(), "", "", "");
				
				ItemToImportProperties.MetadataObjectByFullName =
					MetadataFindByFullName(Object.FullName);
				
				If ItemToImportProperties.MetadataObjectByKey = Undefined
				   And ItemToImportProperties.MetadataObjectByFullName = Undefined
				   And Object.DeletionMark <> True Then
					// If an imported object is missing from metadata,
					// it is marked for deletion.
					Object.DeletionMark = True;
				EndIf;
			EndIf;
			
			If Object.DeletionMark Then
				// Objects marked for deletion cannot have "proper" full names.
				// Therefore, to meet this condition, the procedure that updates the object's properties
				// is applied prior to the import.
				UpdateMarkedForDeletionItemProperties(Object);
			EndIf;
			
			Properties = Upload0.Find(ItemToImportProperties.Ref, "Ref");
			If Properties <> Undefined
			   And Properties.Description              = Object.Description
			   And Properties.Parent                  = Object.Parent
			   And Properties.CollectionOrder          = Object.CollectionOrder
			   And Properties.Name                       = Object.Name
			   And Properties.Synonym                   = Object.Synonym
			   And Properties.FullName                 = Object.FullName
			   And Properties.FullSynonym             = Object.FullSynonym
			   And Properties.NoData                 = Object.NoData
			   And Properties.EmptyRefValue      = Object.EmptyRefValue
			   And Properties.PredefinedDataName = Object.PredefinedDataName
			   And Properties.DeletionMark           = Object.DeletionMark
			   And IdenticalMetadataObjectKeys(Properties, Object) Then
				
				ItemToImportProperties.Matches = True;
			EndIf;
			
			If Properties <> Undefined Then
				Upload0.Delete(Properties); // Renaming items to be imported is not required.
			EndIf;
		EndDo;
		ItemsToImportTable.Indexes.Add("Ref");
		
		// Renaming the existing items (except for items to be overwritten during the import) to search for duplicates.
		
		RenameFullNames(Upload0);
		For Each String In Upload0 Do
			String.FullNameLowerCase = Lower(String.FullName);
		EndDo;
		Upload0.Indexes.Add("MetadataObjectKey");
		Upload0.Indexes.Add("FullNameLowerCase");
		
		// Prepare 
		
		ObjectsToWrite = New Array; // Array of CatalogObject.MetadataObjectIDs -
		FullNamesOfItemsToImport = New Map;
		KeysOfItemsToImport = New Map;
		
		For Each ItemToImportProperties In ItemsToImportTable Do
			Object = ItemToImportProperties.Object; // CatalogObject.MetadataObjectIDs
			Ref = ItemToImportProperties.Ref;
			
			If ItemToImportProperties.Matches Then
				Continue; // There is no need to import objects that are identical to existing ones.
			EndIf;
			
			If IsCollection(Ref) Then
				ObjectsToWrite.Add(Object);
				Continue;
			EndIf;
			
			// Checking the items to be imported for duplicates.
			
			If FullNamesOfItemsToImport.Get(Lower(Object.FullName)) <> Undefined Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Could not import the metadata object ids from the master node.
					           |Two items have identical full names:
					           |""%1"".';"),
					Object.FullName);
				Raise ErrorText;
			EndIf;
			FullNamesOfItemsToImport.Insert(Lower(Object.FullName));
			
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If TypeOf(MetadataObjectKey) = Type("Type")
			   And MetadataObjectKey <> Type("Undefined") Then
				
				If KeysOfItemsToImport.Get(MetadataObjectKey) <> Undefined Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Could not import the metadata object ids from the master node.
						           |Two items have identical metadata object keys:
						           |""%1"".';"),
						String(MetadataObjectKey));
					Raise ErrorText;
				EndIf;
				KeysOfItemsToImport.Insert(MetadataObjectKey);
				
				If ItemToImportProperties.MetadataObjectByKey <> ItemToImportProperties.MetadataObjectByFullName Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Could not import the metadata object ids from the master node.
						           |The metadata key ""%1"" does not correspond to the full name ""%2"".';"),
						String(MetadataObjectKey), Object.FullName);
					Raise ErrorText;
				EndIf;
				
				If Not Object.DeletionMark Then
					// Searching existing metadata objects for duplicates by key.
					Filter = New Structure("MetadataObjectKey", MetadataObjectKey);
					FindDuplicatesOnImportDataToSubordinateNode(Upload0, Filter, Object, Ref, ItemsToImportTable);
				EndIf;
			EndIf;
			
			If Not Object.DeletionMark Then
				// Searching existing metadata objects for duplicates by full name.
				Filter = New Structure("FullNameLowerCase", Lower(Object.FullName));
				FindDuplicatesOnImportDataToSubordinateNode(Upload0, Filter, Object, Ref, ItemsToImportTable);
			EndIf;
			
			ObjectsToWrite.Add(Object);
		EndDo;
		
		// Update duplicates.
		Rows = Upload0.FindRows(New Structure("DuplicateUpdated", True));
		For Each Properties In Rows Do
			DuplicateObject1 = Properties.Ref.GetObject();
			FillPropertyValues(DuplicateObject1, Properties);
			DuplicateObject1.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
			DuplicateObject1.DataExchange.Load = True;
			DuplicateObject1.Write();
		EndDo;
		
		PrepareNewSubsystemsListInSubordinateNode(ObjectsToWrite);
		
		// Import objects.
		For Each Object In ObjectsToWrite Do
			Object.DataExchange.Load = True;
			Object.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns references to a metadata object found by the full name of the deleted metadata object.
// Use this function to replace or clear a reference.
//
// Parameters:
//  FullNameOfDeletedItem - String - for example "Role.ReadBasicRegulatoryData".
//
// Returns:
//  Array - Has the following values:
//   * Value - CatalogRef.MetadataObjectIDs
//              - CatalogRef.ExtensionObjectIDs - found reference.
// 
Function DeletedMetadataObjectID(FullNameOfDeletedItem) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MetadataObjectIDs.Ref AS Ref,
	|	MetadataObjectIDs.FullName AS FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionObjectIDs.Ref,
	|	ExtensionObjectIDs.FullName
	|FROM
	|	Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|WHERE
	|	ExtensionObjectIDs.DeletionMark";
	
	Selection = Query.Execute().Select();
	
	FoundRefs = New Array;
	While Selection.Next() Do
		If Not StrStartsWith(Selection.FullName, "? ") Then
			Continue;
		EndIf;
		CurrentFullNameOfDeletedItem = FullNameOfDeletedItem(Selection.FullName);
		If Upper(CurrentFullNameOfDeletedItem) = Upper(FullNameOfDeletedItem) Then
			FoundRefs.Add(Selection.Ref);
		EndIf;
	EndDo;
	
	Return FoundRefs;
	
EndFunction

// Parameters:
//  IDs - Array - Array of values.:
//                     * Value - CatalogRef.MetadataObjectIDs
//                                - CatalogRef.ExtensionObjectIDs - the IDs of
//                                    metadata objects in an application or an extension.
// Returns:
//  Map of KeyAndValue:
//   * Key     - CatalogRef.MetadataObjectIDs
//              - CatalogRef.ExtensionObjectIDs
//   * Value - String - Metadata object full name without a question mark ( ? ).
//
Function FullNamesofMetadataObjectsIncludingRemote(IDs) Export
	
	Query = New Query;
	Query.SetParameter("IDs", IDs);
	Query.Text =
	"SELECT
	|	MetadataObjectIDs.Ref AS Ref,
	|	MetadataObjectIDs.FullName AS FullName
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref IN(&IDs)
	|
	|UNION ALL
	|
	|SELECT
	|	ExtensionObjectIDs.Ref,
	|	ExtensionObjectIDs.FullName
	|FROM
	|	Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
	|WHERE
	|	ExtensionObjectIDs.Ref IN(&IDs)";
	
	Result = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If StrStartsWith(Selection.FullName, "? ") Then
			Result.Insert(Selection.Ref, FullNameOfDeletedItem(Selection.FullName));
		Else
			Result.Insert(Selection.Ref, Selection.FullName);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns:
//  Array of String - Names of collections of metadata objects this catalog supports.
//
Function ValidCollections() Export
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties();
	
	Return CollectionsProperties.UnloadColumn("Name");
	
EndFunction

// For internal use only.
// Parameters:
//  MetadataObjectRole - MetadataObject
// Returns:
//  String
//  Undefined
//
Function RoleMetadataObjectKey(MetadataObjectRole) Export
	Return KeyRole(MetadataObjectRole, False);
EndFunction

// For internal use only.
// Parameters:
//  IDsOfRole - Array of CatalogRef.MetadataObjectIDs
//                     - Array of CatalogRef.ExtensionObjectIDs
// Returns:
//  Map of KeyAndValue:
//   * Key - CatalogRef.MetadataObjectIDs
//          - CatalogRef.ExtensionObjectIDs
//   * Value - See RoleMetadataObjectKey
//
Function RolesKeys(IDsOfRole) Export
	
	Result = New Map;
	Values = Common.ObjectsAttributeValue(IDsOfRole, "MetadataObjectKey");
	
	For Each KeyAndValue In Values Do
		Result.Insert(KeyAndValue.Key, Undefined);
		If TypeOf(KeyAndValue.Value) <> Type("ValueStorage") Then
			Continue;
		EndIf;
		KeyRole = KeyAndValue.Value.Get();
		If TypeOf(KeyRole) <> Type("String")
		 Or Not StringFunctionsClientServer.IsUUID(KeyRole) Then
			Continue;
		EndIf;
		Result.Insert(KeyAndValue.Key, KeyRole);
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

// This procedure updates catalog data using the configuration metadata.
//
// Parameters:
//  HasChanges  - Boolean - a return value). True is returned
//                   to this parameter if changes are saved. Otherwise, not modified.
//
//  HasDeletedItems  - Boolean - a return value. Receives
//                   True if a catalog item was marked
//                   for deletion. Otherwise, not modified.
//
//  IsCheckOnly - Boolean - make no changes, just set
//                   the HasChanges and HasDeleted flags.
//
Procedure UpdateCatalogData(HasChanges = False, HasDeletedItems = False, IsCheckOnly = False) Export
	
	RunDataUpdate(HasChanges, HasDeletedItems, IsCheckOnly);
	
EndProcedure

// Required to export all application metadata object IDs
// to subordinate DIB nodes if the catalog was not included into the DIB before.
// Also can be used to repair the catalog data in DIB nodes.
//
Procedure RegisterTotalChangeForSubordinateDIBNodes() Export
	
	CheckForUsage();
	
	If Common.IsSubordinateDIBNode()
	 Or Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	CatalogMetadata = Metadata.Catalogs.MetadataObjectIDs;
	
	DIBNodes = New Array;
	For Each ExchangePlan In Metadata.ExchangePlans Do
		If ExchangePlan.DistributedInfoBase
		   And ExchangePlan.Content.Contains(CatalogMetadata)Then
		
			ExchangePlanManager = Common.ObjectManagerByFullName(ExchangePlan.FullName());
			Selection = ExchangePlanManager.Select();
			While Selection.Next() Do
				If Selection.Ref <> ExchangePlanManager.ThisNode() Then
					DIBNodes.Add(Selection.Ref);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If DIBNodes.Count() > 0 Then
		ExchangePlans.RecordChanges(DIBNodes, CatalogMetadata);
	EndIf;
	
EndProcedure

// This procedure updates catalog data using the configuration metadata.
//
// Parameters:
//  HasChanges - Boolean - a return value). True is returned
//                  to this parameter if changes are saved. Otherwise, not modified.
//
//  HasDeletedItems - Boolean - a return value. Receives
//                  True if at least one catalog item was marked
//                  for deletion. Otherwise, not modified.
//
//  IsCheckOnly - Boolean - make no changes,
//                   just set the HasChanges, HasDeleted, HasCriticalChanges, and ListOfCriticalChanges flags.
//
//  HasCriticalChanges - Boolean - a return value. Receives
//                  True if critical changes are found. Otherwise, not modified.
//                    Critical changes (only for items without a deletion mark):  
//                    FullName attribute change or adding a new catalog item.
//                  Generally the exclusive mode is required for any critical changes.
//
//  ListOfCriticalChanges - String - a return value. Contains full names
//                  of metadata objects that were added or must be added,
//                  and also whose names were changed or must be changed.
//
//  ExtensionsObjects - Boolean
//
Procedure RunDataUpdate(HasChanges, HasDeletedItems, IsCheckOnly,
			HasCriticalChanges = False, ListOfCriticalChanges = "", ExtensionsObjects = False) Export
	
	If ExtensionsObjects
	   And ValueIsFilled(SessionParameters.AttachedExtensions)
	   And Not Common.SeparatedDataUsageAvailable() Then
		
		RaiseByError(True,
			ExtensionObjectsIDsUnvailableInSharedModeErrorDescription());
	EndIf;
	
	CheckForUsage(ExtensionsObjects);
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	HasCurrentChanges = False;
	If Not ExtensionsObjects Then
		ReplaceSubordinateNodeDuplicatesFoundOnImport(IsCheckOnly, HasCurrentChanges);
	EndIf;
	
	UpdateData1(HasCurrentChanges, HasDeletedItems, IsCheckOnly,
		HasCriticalChanges, ListOfCriticalChanges, ExtensionsObjects);
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
	If Not ExtensionsObjects
	   And Not StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.Core.MetadataObjectIDs", True);
	EndIf;
	
	If Not IsCheckOnly And Not TransactionActive() Then
		UpdateIsCompleted = New Structure(SessionParameters.UpdateIDCatalogs);
		If ExtensionsObjects Then
			UpdateIsCompleted.ExtensionObjectIDs = True;
		Else
			UpdateIsCompleted.MetadataObjectIDs = True;
		EndIf;
		SessionParameters.UpdateIDCatalogs = New FixedStructure(UpdateIsCompleted);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Implementation of procedures declared in other modules.

// See Common.MetadataObjectID.
Function MetadataObjectID(MetadataObjectDetails, RaiseException1) Export
	
	MetadataObjectDetailsType = TypeOf(MetadataObjectDetails);
	If MetadataObjectDetailsType = Type("Type") Then
		
		MetadataObject = Metadata.FindByType(MetadataObjectDetails);
		
		If MetadataObject <> Undefined Then
			FullMetadataObjectName = MetadataObject.FullName();
			
		ElsIf Not RaiseException1 Then
			Return Null;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Incorrect value of the %1 parameter in the %2 function.
				           |Non-existing metadata object is specified: ""%3"".';"),
				"MetadataObjectDetails",
				"Common.MetadataObjectID",
				MetadataObjectDetails);
			Raise ErrorText;
		EndIf;
		
	ElsIf MetadataObjectDetailsType = Type("String") Then
		FullMetadataObjectName = MetadataObjectDetails;
		
	ElsIf MetadataObjectDetailsType = Type("MetadataObject") Then
		FullMetadataObjectName = MetadataObjectDetails.FullName();
		
	ElsIf Not RaiseException1 Then
		Return Null;
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect type of the %1 parameter in the %2 function:
			           |""%3"".';"),
			"MetadataObjectDetails",
			"Common.MetadataObjectID",
			MetadataObjectDetailsType);
		Raise ErrorText;
	EndIf;
	
	Array = New Array;
	Array.Add(FullMetadataObjectName);
	
	IDs = MetadataObjectIDs(Array, RaiseException1, True);
	Id = IDs.Get(FullMetadataObjectName);
	If Id = Undefined Then
		Return Null;
	EndIf;
	
	Return Id;
	
EndFunction

// See Common.MetadataObjectIDs.
Function MetadataObjectIDs(MetadataObjectsDetails, RaiseException1 = True, OneItem = False) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	IDsByFullNames = IDCache().IDsByFullNames;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Result = New Map;
	FullNamesWithoutCache = New Array;
	For Each MetadataObjectDetails In MetadataObjectsDetails Do
		
		MetadataObjectDetailsType = TypeOf(MetadataObjectDetails);
		If MetadataObjectDetailsType = Type("Type") Then
		
			MetadataObject = Metadata.FindByType(MetadataObjectDetails);
			If MetadataObject <> Undefined Then
				FullName = MetadataObject.FullName();
			ElsIf Not RaiseException1 Then
				Continue;
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Incorrect value of parameter %1 in function %2.
					           |Non-existing metadata object is specified: ""%3"".';"),
					"MetadataObjectsDetails",
					"Common.MetadataObjectIDs",
					MetadataObjectDetails);
				Raise ErrorText;
			EndIf;
			
		ElsIf MetadataObjectDetailsType = Type("String") Then
			FullName = MetadataObjectDetails;
			
		ElsIf MetadataObjectDetailsType = Type("MetadataObject") Then
			FullName = MetadataObjectDetails.FullName();
			
		ElsIf Not RaiseException1 Then
			Continue;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Incorrect type of parameter %1 in function %2:
				           |""%3"".';"),
				"MetadataObjectsDetails",
				"Common.MetadataObjectIDs",
				MetadataObjectDetailsType);
			Raise ErrorText;
		EndIf;
		Id = IDsByFullNames.Get(FullName);
		
		If Id = Undefined Then
			FullNamesWithoutCache.Add(FullName);
		Else
			Result.Insert(FullName, Id);
		EndIf;
	EndDo;
	
	If FullNamesWithoutCache.Count() = 0 Then
		Return Result;
	EndIf;
	
	IDs = MetadataObjectIDsWithRetryAttempt(FullNamesWithoutCache,
		RaiseException1, OneItem);
	
	For Each KeyAndValue In IDs Do
		Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
		IDsByFullNames.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Return Result;
	
EndFunction

// See Common.MetadataObjectByID.
Function MetadataObjectByID(Id, RaiseException1) Export
	
	IDs = New Array;
	IDs.Add(Id);
	
	MetadataObjects = MetadataObjectsByIDs(IDs, RaiseException1);
	
	If Id = Undefined Then
		Return Null;
	EndIf;
	
	Return MetadataObjects.Get(Id);
	
EndFunction

// See Common.MetadataObjectsByIDs.
Function MetadataObjectsByIDs(IDs, RaiseException1) Export
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	DetailsOfMetadataObjectsByIDs = IDCache().DetailsOfMetadataObjectsByIDs;
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	RolesByKeys = Undefined;
	Result = New Map;
	IDsWithoutCache = New Array;
	For Each Id In IDs Do
		LongDesc = DetailsOfMetadataObjectsByIDs.Get(Id);
		
		If LongDesc = Undefined
		 Or RaiseException1
		   And LongDesc.Key = Undefined Then
			
			IDsWithoutCache.Add(Id);
			
		ElsIf LongDesc.Key = Undefined Then
			Result.Insert(Id, LongDesc.Object);
			
		ElsIf TypeOf(LongDesc.Key) = Type("Type") Then
			Result.Insert(Id, Metadata.FindByType(LongDesc.Key));
		ElsIf LongDesc.Key <> LongDesc.FullName Then
			If RolesByKeys = Undefined Then
				RolesByKeys = StandardSubsystemsCached.RolesByKeysMetadataObjects();
			EndIf;
			Result.Insert(Id, RolesByKeys.Get(LongDesc.Key));
		Else
			Result.Insert(Id, Common.MetadataObjectByFullName(LongDesc.Key));
		EndIf;
	EndDo;
	
	If IDsWithoutCache.Count() = 0 Then
		Return Result;
	EndIf;
	
	MetadataObjectsByIDs = MetadataObjectsByIDsWithRetryAttempt(IDsWithoutCache,
		RaiseException1);
	
	For Each KeyAndValue In MetadataObjectsByIDs Do
		MetadataObjectDetails = KeyAndValue.Value;
		If TypeOf(MetadataObjectDetails) = Type("Structure") Then
			Result.Insert(KeyAndValue.Key, MetadataObjectDetails.Object);
			MetadataObjectDetails.Object = Undefined;
		Else
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
			MetadataObjectDetails = New Structure("Object, Key, FullName", KeyAndValue.Value)
		EndIf;
		DetailsOfMetadataObjectsByIDs.Insert(KeyAndValue.Key, MetadataObjectDetails);
	EndDo;
	
	Return Result;
	
EndFunction

// See Common.AddRenaming.
Procedure AddRenaming(Total, IBVersion, PreviousFullName, NewFullName, LibraryID = "") Export
	
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck();
	
	PreviousCollectionName = Upper(CollectionName(PreviousFullName));
	NewCollectionName  = Upper(CollectionName(NewFullName));
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error in procedure %1 of common module %2.';"),
		"OnAddMetadataObjectsRenaming",
		"CommonOverridable");
	
	If PreviousCollectionName <> NewCollectionName Then
		ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Type mismatch in the renamed metadata object.
			           |Previous type: ""%1"",
			           |new type: ""%2"".';"),
			PreviousFullName,
			NewFullName);
		Raise ErrorText;
	EndIf;
	
	If Total.CollectionsWithoutKey[PreviousCollectionName] = Undefined Then
		
		AllowedTypesList = "";
		For Each KeyAndValue In Total.CollectionsWithoutKey Do
			AllowedTypesList = AllowedTypesList + KeyAndValue.Value + "," + Chars.LF;
		EndDo;
		AllowedTypesList = TrimR(AllowedTypesList);
		AllowedTypesList = ?(ValueIsFilled(AllowedTypesList),
			Left(AllowedTypesList, StrLen(AllowedTypesList) - 1), "");
		
		ErrorText = ErrorTitle + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Describing the renaming of ""%1"" metadata object is not required,
			           |as the details of metadata objects of this type are updated automatically.
			           |
			           |It is required only for the following types:
			           |%2.';"),
			PreviousFullName,
			AllowedTypesList);
		Raise ErrorText;
	EndIf;
	
	If Not ValueIsFilled(LibraryID) Then
		LibraryID = Metadata.Name;
	EndIf;
	
	LibraryOrder = Total.LibrariesOrder[LibraryID];
	If LibraryOrder = Undefined Then
		LibraryOrder = Total.LibrariesOrder.Count();
		Total.LibrariesOrder.Insert(LibraryID, LibraryOrder);
	EndIf;
	
	LibraryVersion = Total.LibrariesVersions[LibraryID];
	If LibraryVersion = Undefined Then
		LibraryVersion = InfobaseUpdateInternal.IBVersion(LibraryID);
		Total.LibrariesVersions.Insert(LibraryID, LibraryVersion);
	EndIf;
	
	If LibraryVersion = "0.0.0.0" Then
		// No renaming is required during the initial filling.
		Return;
	EndIf;
	
	Result = CommonClientServer.CompareVersions(IBVersion, LibraryVersion);
	If Result > 0 Then
		VersionParts = StrSplit(IBVersion, ".");
		
		RenamingTable = Total.Table; // See RenamingTableForCurrentVersion
		RenamingDetails = RenamingTable.Add();
		RenamingDetails.LibraryOrder = LibraryOrder;
		RenamingDetails.VersionPart1      = Number(VersionParts[0]);
		RenamingDetails.VersionPart2      = Number(VersionParts[1]);
		RenamingDetails.VersionPart3      = Number(VersionParts[2]);
		RenamingDetails.VersionPart4      = Number(VersionParts[3]);
		RenamingDetails.PreviousFullName   = PreviousFullName;
		RenamingDetails.NewFullName    = NewFullName;
		RenamingDetails.AdditionOrder = RenamingTable.IndexOf(RenamingDetails);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions intended to be called from other modules.

// For internal use only.
// FullName for the object must be specified and valid.
//
// Parameters:
//   Object - CatalogObject.MetadataObjectIDs
//          - CatalogObject.ExtensionObjectIDs
//          - FormDataStructure:
//             * Ref - CatalogRef.MetadataObjectIDs
//                      - CatalogRef.ExtensionObjectIDs
//
Procedure UpdateIDProperties(Object) Export
	
	If TypeOf(Object) <> Type("FormDataStructure") Then
		ExtensionsObjects = IsExtensionsObject(Object);
	Else
		ExtensionsObjects = IsExtensionsObject(Object.Ref);
	EndIf;
	
	If ExtensionsObjects
	   And Catalogs.ExtensionObjectIDs.ExtensionObjectDisabled(Object.Ref) Then
		Return;
	EndIf;
	
	FullName = Object.FullName;
	
	// Restore previous values.
	If ValueIsFilled(Object.Ref) Then
		PreviousValues1 = Common.ObjectAttributesValues(
			Object.Ref,
			"Description,
			|CollectionOrder,
			|Name,
			|FullName,
			|Synonym,
			|FullSynonym,
			|NoData,
			|EmptyRefValue,
			|MetadataObjectKey");
		FillPropertyValues(Object, PreviousValues1);
	EndIf;
	
	MetadataObject = MetadataFindByFullName(FullName);
	
	If MetadataObject = Undefined Then
		Object.DeletionMark       = True;
		Object.Parent              = EmptyCatalogRef(ExtensionsObjects);
		Object.Description          = InsertQuestionMark(Object.Description);
		Object.Name                   = InsertQuestionMark(Object.Name);
		Object.Synonym               = InsertQuestionMark(Object.Synonym);
		Object.FullName             = InsertQuestionMark(Object.FullName);
		Object.FullSynonym         = InsertQuestionMark(Object.FullSynonym);
		Object.EmptyRefValue  = Undefined;
		
		If ExtensionsObjects Then
			Object.ExtensionName           = InsertQuestionMark(Object.ExtensionName);
			Object.ExtensionID = InsertQuestionMark(Object.ExtensionID);
			Object.ExtensionHashsum      = InsertQuestionMark(Object.ExtensionHashsum);
		EndIf;
	Else
		Object.DeletionMark = False;
		
		FullName = MetadataObject.FullName();
		PointPosition = StrFind(FullName, ".");
		BaseTypeName = Left(FullName, PointPosition -1);
		
		CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
		Filter = New Structure("SingularName", BaseTypeName);
		Rows = CollectionsProperties.FindRows(Filter);
		
		MetadataObjectProperties1 = MetadataObjectProperties1(ExtensionsObjects,
			CollectionsProperties.Copy(Rows));
		
		ObjectProperties = MetadataObjectProperties1.Find(FullName, "FullName");
		
		FillPropertyValues(Object, ObjectProperties);
		
		If TypeOf(Object) <> Type("FormDataStructure") Then
			MetadataObjectKey = Object.MetadataObjectKey.Get();
			If MetadataObjectKey = Undefined
			 Or ObjectProperties.NoMetadataObjectKey
			     <> (MetadataObjectKey = Type("Undefined")) Then
				
				Object.MetadataObjectKey = New ValueStorage(MetadataObjectKey(ObjectProperties.FullName));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// For internal use only.
//
// Returns:
//  ValueTable:
//   * LibraryOrder - Number
//   * VersionPart1 - Number
//   * VersionPart2 - Number
//   * VersionPart3 - Number
//   * VersionPart4 - Number
//   * AdditionOrder - Number
//   * PreviousFullName - String
//   * NewFullName - String
//
Function RenamingTableForCurrentVersion() Export
	
	RenamingTable = New ValueTable;
	RenamingTable.Columns.Add("LibraryOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart1",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart2",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart3",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("VersionPart4",      New TypeDescription("Number"));
	RenamingTable.Columns.Add("AdditionOrder", New TypeDescription("Number"));
	RenamingTable.Columns.Add("PreviousFullName",   New TypeDescription("String"));
	RenamingTable.Columns.Add("NewFullName",    New TypeDescription("String"));
	
	CollectionsWithoutKey = New Map;
	
	Filter = New Structure("NoMetadataObjectKey", True);
	
	CollectionsWithoutMetadataObjectKey =
		StandardSubsystemsCached.MetadataObjectCollectionProperties().FindRows(Filter);
	
	For Each String In CollectionsWithoutMetadataObjectKey Do
		CollectionsWithoutKey.Insert(Upper(String.SingularName), String.SingularName);
	EndDo;
	CollectionsWithoutKey.Insert(Upper("Role"), "Role");
	
	Total = New Structure;
	Total.Insert("Table", RenamingTable);
	Total.Insert("CollectionsWithoutKey", CollectionsWithoutKey);
	Total.Insert("LibrariesVersions",  New Map);
	Total.Insert("LibrariesOrder", New Map);
	
	CommonOverridable.OnAddMetadataObjectsRenaming(Total);
	SSLSubsystemsIntegration.OnAddMetadataObjectsRenaming(Total);
	
	RenamingTable.Sort(
		"LibraryOrder ASC,
		|VersionPart1 ASC,
		|VersionPart2 ASC,
		|VersionPart3 ASC,
		|VersionPart4 ASC,
		|AdditionOrder ASC");
	
	Return RenamingTable;
	
EndFunction

// Parameters:
//  ExtensionsObjects - Boolean
//
// Returns:
//  ValueTable:
//   * Name              - String
//   * SingularName      - String
//   * Synonym          - String
//   * SingularSynonym  - String
//   * CollectionOrder - String
//   * NoData        - Boolean
//   * NoMetadataObjectKey - Boolean
//   * Id             - UUID
//   * ExtensionsObjects         - Boolean
//
Function MetadataObjectCollectionProperties(ExtensionsObjects = False) Export
	
	Result = New ValueTable;
	Result.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(50)));
	Result.Columns.Add("SingularName",               New TypeDescription("String",, New StringQualifiers(50)));
	Result.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	Result.Columns.Add("SingularSynonym",           New TypeDescription("String",, New StringQualifiers(255)));
	Result.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	Result.Columns.Add("NoData",                 New TypeDescription("Boolean"));
	Result.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	Result.Columns.Add("Id",             New TypeDescription("UUID"));
	Result.Columns.Add("ExtensionsObjects",         New TypeDescription("Boolean"));
	
	String = Result.Add();
	String.Id   = New UUID("627a6fb8-872a-11e3-bb87-005056c00008");
	String.Name             = "Constants";
	String.Synonym         = NStr("en = 'Constants';");
	String.SingularName     = "Constant";
	String.SingularSynonym = NStr("en = 'Constant';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("cdf5ac50-08e8-46af-9a80-4e63fd4a88ff");
	String.Name             = "Subsystems";
	String.Synonym         = NStr("en = 'Subsystems';");
	String.SingularName     = "Subsystem";
	String.SingularSynonym = NStr("en = 'Subsystem';");
	String.NoData       = True;
	String.NoMetadataObjectKey = True;
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("115c4f55-9c20-4e86-a6d0-d0167ec053a1");
	String.Name             = "Roles";
	String.Synonym         = NStr("en = 'Roles';");
	String.SingularName     = "Role";
	String.SingularSynonym = NStr("en = 'Role';");
	String.NoData       = True;
	String.NoMetadataObjectKey = False;
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("269651e0-4b06-4f9d-aaab-a8d2b6bc6077");
	String.Name             = "ExchangePlans";
	String.Synonym         = NStr("en = 'Exchange plans';");
	String.SingularName     = "ExchangePlan";
	String.SingularSynonym = NStr("en = 'Exchange plan';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("ede89702-30f5-4a2a-8e81-c3a823b7e161");
	String.Name             = "Catalogs";
	String.Synonym         = NStr("en = 'Catalogs';");
	String.SingularName     = "Catalog";
	String.SingularSynonym = NStr("en = 'Catalog';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("96c6ab56-0375-40d5-99a2-b83efa3dac8b");
	String.Name             = "Documents";
	String.Synonym         = NStr("en = 'Documents';");
	String.SingularName     = "Document";
	String.SingularSynonym = NStr("en = 'Document';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("07938234-e29b-4cff-961a-9af07a4c6185");
	String.Name             = "DocumentJournals";
	String.Synonym         = NStr("en = 'Document journals';");
	String.SingularName     = "DocumentJournal";
	String.SingularSynonym = NStr("en = 'Document journal';");
	String.NoData       = True;
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("706cf832-0ae5-45b5-8a4a-1f251d054f3b");
	String.Name             = "Reports";
	String.Synonym         = NStr("en = 'Reports';");
	String.SingularName     = "Report";
	String.SingularSynonym = NStr("en = 'Report';");
	String.NoData       = True;
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("ae480426-487e-40b2-98ba-d207777449f3");
	String.Name             = "DataProcessors";
	String.Synonym         = NStr("en = 'Data processors';");
	String.SingularName     = "DataProcessor";
	String.SingularSynonym = NStr("en = 'Data processor';");
	String.NoData       = True;
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("8b5649b9-cdd1-4698-9aac-12ba146835c4");
	String.Name             = "ChartsOfCharacteristicTypes";
	String.Synonym         = NStr("en = 'Charts of characteristic types';");
	String.SingularName     = "ChartOfCharacteristicTypes";
	String.SingularSynonym = NStr("en = 'Chart of characteristic types';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("4295af27-543f-4373-bcfc-c0ace9b7620c");
	String.Name             = "ChartsOfAccounts";
	String.Synonym         = NStr("en = 'Charts of accounts';");
	String.SingularName     = "ChartOfAccounts";
	String.SingularSynonym = NStr("en = 'Chart of accounts.';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("fca3e7e1-1bf1-49c8-9921-aafb4e787c75");
	String.Name             = "ChartsOfCalculationTypes";
	String.Synonym         = NStr("en = 'Charts of calculation types';");
	String.SingularName     = "ChartOfCalculationTypes";
	String.SingularSynonym = NStr("en = 'Chart of calculation types.';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("d7ecc1e9-c068-44dd-83c2-1323ec52dbbb");
	String.Name             = "InformationRegisters";
	String.Synonym         = NStr("en = 'Information registers';");
	String.SingularName     = "InformationRegister";
	String.SingularSynonym = NStr("en = 'Information register';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("74083488-b01e-4441-84a6-c386ce88cdb5");
	String.Name             = "AccumulationRegisters";
	String.Synonym         = NStr("en = 'Accumulation registers';");
	String.SingularName     = "AccumulationRegister";
	String.SingularSynonym = NStr("en = 'Accumulation register';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("9a0d75ff-0eda-454e-b2b7-d2412ffdff18");
	String.Name             = "AccountingRegisters";
	String.Synonym         = NStr("en = 'Accounting registers';");
	String.SingularName     = "AccountingRegister";
	String.SingularSynonym = NStr("en = 'Accounting register';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("f330686a-0acf-4e26-9cda-108f1404687d");
	String.Name             = "CalculationRegisters";
	String.Synonym         = NStr("en = 'Calculation registers';");
	String.SingularName     = "CalculationRegister";
	String.SingularSynonym = NStr("en = 'Calculation register';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("a8cdd0e0-c27f-4bf0-9718-10ec054dc468");
	String.Name             = "BusinessProcesses";
	String.Synonym         = NStr("en = 'Business processes';");
	String.SingularName     = "BusinessProcess";
	String.SingularSynonym = NStr("en = 'Business process';");
	String.ExtensionsObjects = True;
	
	String = Result.Add();
	String.Id   = New UUID("8d9153ad-7cea-4e25-9542-a557ee59fd16");
	String.Name             = "Tasks";
	String.Synonym         = NStr("en = 'Tasks';");
	String.SingularName     = "Task";
	String.SingularSynonym = NStr("en = 'Task';");
	String.ExtensionsObjects = True;
	
	For Each String In Result Do
		String.CollectionOrder = Result.IndexOf(String);
	EndDo;
	
	If ExtensionsObjects Then
		Result = Result.Copy(New Structure("ExtensionsObjects", True));
	EndIf;
	
	Result.Indexes.Add("Id");
	Result.Indexes.Add("Name");
	
	Return Result;
	
EndFunction

// Prevents illegal modification of the metadata object IDs.
// Processes duplicate objects in a subordinate node of the distributed infobase.
//
// Parameters:
//   Object - CatalogObject.MetadataObjectIDs
//          - CatalogObject.ExtensionObjectIDs
//
Procedure BeforeWriteObject(Object) Export
	
	ExtensionsObjects = IsExtensionsObject(Object);
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(, ExtensionsObjects);
	
	// Disabling the object registration mechanism.
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	// Registering the object in all DIB nodes.
	For Each ExchangePlan In StandardSubsystemsCached.DIBExchangePlans() Do
		StandardSubsystemsServer.RecordObjectChangesInAllNodes(Object, ExchangePlan, False);
	EndDo;
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	UpdateIsCompleted = New Structure(SessionParameters.UpdateIDCatalogs);
	If ExtensionsObjects Then
		UpdateIsCompleted.ExtensionObjectIDs = False;
	Else
		UpdateIsCompleted.MetadataObjectIDs = False;
	EndIf;
	SessionParameters.UpdateIDCatalogs = New FixedStructure(UpdateIsCompleted);
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	// ACC:75-off - "DataExchange.Import" check must follow the change records in the Event log.
	If Common.SeparatedDataUsageAvailable()
	   And UsersInternalCached.ShouldRegisterChangesInAccessRights()
	   And Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		Object.AdditionalProperties.Insert("StandardSubsystemsOldValues",
			Common.ObjectAttributesValues(Object.Ref,
				"DeletionMark, Name, Synonym"));
	EndIf;
	// ACC:75-on
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	CheckObjectBeforeWrite(Object);
	
EndProcedure

// Parameters:
//   Object - CatalogObject.MetadataObjectIDs
//          - CatalogObject.ExtensionObjectIDs
//
Procedure AtObjectWriting(Object) Export
	
	// ACC:75-off - "DataExchange.Import" check must follow the logging of changes.
	If Common.SeparatedDataUsageAvailable()
	   And UsersInternalCached.ShouldRegisterChangesInAccessRights()
	   And Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		
		SetSafeModeDisabled(True);
		SetPrivilegedMode(True);
		
		ModuleAccessGroupsProfiles = Common.CommonModule("Catalogs.AccessGroupProfiles");
		ModuleAccessGroupsProfiles.RegisterChangeInProfilesRoles(Object,
			Object.AdditionalProperties.StandardSubsystemsOldValues);
		
		SetPrivilegedMode(False);
		SetSafeModeDisabled(False);
	EndIf;
	// ACC:75-on
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

// Prevents the metadata object IDs without deletion mark from being deleted.
//
// Parameters:
//   Object - CatalogObject.MetadataObjectIDs
//          - CatalogObject.ExtensionObjectIDs
//
Procedure BeforeDeleteObject(Object) Export
	
	ExtensionsObjects = IsExtensionsObject(Object);
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(, ExtensionsObjects);
	
	// Disable the object registration mechanism.
	// ID references are deleted independently in all nodes
	// by the marked object deletion mechanism.
	Object.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Object.DeletionMark Then
		RaiseByError(ExtensionsObjects,
			NStr("en = 'Cannot delete IDs of objects that have
			           |the ""Deletion mark"" attribute set to False.';"));
	EndIf;
	
EndProcedure

// For internal use only.
// 
// Parameters:
//  Form - ClientApplicationForm:
//   * List - DynamicList
//
Procedure ListFormOnCreateAtServer(Form) Export
	
	SetListOrderAndAppearance(Form);
	
	If Form.Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(Form, "SelectionPick");
		Form.WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		Form.Items.List.ChoiceMode = False;
	EndIf;
	
	Form.SelectMetadataObjectsGroups = Form.Parameters.SelectMetadataObjectsGroups;
	
EndProcedure

// For internal use only.
// 
// Parameters:
//  Form - ClientApplicationForm:
//   * Object - FormDataStructure:
//    ** Ref - CatalogRef.MetadataObjectIDs
//              - CatalogRef.ExtensionObjectIDs
//    
Procedure ItemFormOnCreateAtServer(Form) Export
	
	ExtensionsObjects = IsExtensionsObject(Form.Object.Ref);
	
	Items  = Form.Items;
	
	Form.ReadOnly = True;
	Form.EmptyRefPresentation = String(TypeOf(Form.Object.EmptyRefValue));
	
	If Not Users.IsFullUser(, Not ExtensionsObjects)
	 Or CannotChangeFullName(Form.Object)
	 Or Not ExtensionsObjects And Common.IsSubordinateDIBNode()
	 Or ExtensionsObjects And Catalogs.ExtensionObjectIDs.ExtensionObjectDisabled(Form.Object.Ref) Then
		
		Items.FormEnableEditing.Visible = False;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// For the ImportDataToSubordinateNode procedure.
// 
// Parameters:
//  Upload0 - See ExportAllIDs
//
Procedure FindDuplicatesOnImportDataToSubordinateNode(Upload0, Filter, ObjectToImport, ObjectToImportRef, ItemsToImportTable)
	
	Rows = Upload0.FindRows(Filter);
	For Each String In Rows Do
		
		If String.Ref <> ObjectToImportRef
		   And ItemsToImportTable.Find(String.Ref, "Ref") = Undefined Then
			
			UpdateMarkedForDeletionItemProperties(String,,, True);
			String.NewRef = ObjectToImportRef;
			String.DuplicateUpdated = True;
			ObjectToImport.AdditionalProperties.Insert("IsDuplicateReplacement");
			// Replacing new references to the duplicate with a new reference specified for the duplicate (if any).
			PreviousDuplicates = Upload0.FindRows(New Structure("NewRef", String.Ref));
			For Each PreviousDuplicate In PreviousDuplicates Do
				UpdateMarkedForDeletionItemProperties(PreviousDuplicate,,, True);
				PreviousDuplicate.NewRef = ObjectToImportRef;
				PreviousDuplicate.DuplicateUpdated = True;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Procedure UpdateData1(HasChanges, HasDeletedItems, IsCheckOnly,
			HasCriticalChanges, ListOfCriticalChanges, ExtensionsObjects)
	
	If ExtensionsObjects Then
		ExtensionProperties = New Structure;
		DatabaseExtensions = New Array;
		ExtensionKeyIds = ExtensionKeyIds(DatabaseExtensions);
		ExtensionProperties.Insert("AttachedExtensionsNames",
			ExtensionNames(ConfigurationExtensionsSource.SessionApplied, ExtensionKeyIds));
		ExtensionProperties.Insert("UnattachedExtensionsNames",
			ExtensionNames(ConfigurationExtensionsSource.SessionDisabled, ExtensionKeyIds));
		AddNamesOfUnconnectedExtensionsInSessionWithoutDelimiters(ExtensionProperties, DatabaseExtensions);
	EndIf;
	
	MetadataObjectProperties1 = MetadataObjectProperties1(ExtensionsObjects,, ExtensionKeyIds);
	
	// Found - this status indicates that ID is found for the metadata object.
	MetadataObjectProperties1.Columns.Add("Found", New TypeDescription("Boolean"));
	
	// Update procedure:
	// 1. Rename metadata objects considering the child subsystems.
	// 2. Update the IDs of predefined metadata object collections.
	// 3. Update the IDs of metadata objects that have metadata object keys.
	// 4. Update the IDs of metadata objects that don't have metadata object keys.
	// 5. Mark the duplicate IDs from steps 3 and 4 for deletion (by the objects' full names).
	// 6. Assign new IDs.
	// 7. Update the parents of the IDs and write them.
	
	ExtensionsVersion = SessionParameters.ExtensionsVersion;
	
	Block = New DataLock;
	LockItem = Block.Add(CatalogName(ExtensionsObjects));
	If ExtensionsObjects Then
		LockItem = Block.Add("InformationRegister.ExtensionVersionObjectIDs");
		LockItem.SetValue("ExtensionsVersion", ExtensionsVersion);
	EndIf;
	
	BeginTransaction();
	Try
		Block.Lock();
		
		Upload0 = ExportAllIDs(ExtensionsObjects);
		Upload0.Columns.Add("Updated", New TypeDescription("Boolean"));
		Upload0.Columns.Add("MetadataObject");
		Upload0.Columns.Delete("NewRef");
		
		MetadataObjectRenamingList = "";
		If Not ExtensionsObjects
		   And Not Common.IsSubordinateDIBNode() Then
			// Change the full names before processing (for DIB, it applies to the master node only).
			// Not supported for extensions.
			RenameFullNames(Upload0, MetadataObjectRenamingList, HasCriticalChanges);
		EndIf;
		
		ProcessMetadataObjectIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			ExtensionProperties, HasDeletedItems, HasCriticalChanges, MetadataObjectRenamingList);
		
		NewMetadataObjectsList = "";
		AddNewMetadataObjectsIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			HasCriticalChanges, NewMetadataObjectsList);
		
		ListOfCriticalChanges = "";
		If ValueIsFilled(MetadataObjectRenamingList) Then
			ListOfCriticalChanges = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Rename IDs of metadata objects %1->%2:';"),
				"PreviousFullName",
				"NewFullName");
			ListOfCriticalChanges = ListOfCriticalChanges + Chars.LF
				+ MetadataObjectRenamingList + Chars.LF + Chars.LF;
		EndIf;
		If ValueIsFilled(NewMetadataObjectsList) Then
			ListOfCriticalChanges = ListOfCriticalChanges
				+ NStr("en = 'Added metadata object IDs:';")
				+ Chars.LF + NewMetadataObjectsList + Chars.LF;
		EndIf;
		
		If Not IsCheckOnly
		   And Not ExtensionsObjects
		   And ValueIsFilled(ListOfCriticalChanges)
		   And Common.IsSubordinateDIBNode() Then
			
			EventName = NStr("en = 'Metadata object IDs.Import of critical changes required';",
				Common.DefaultLanguageCode());
			
			EventLog.AddMessageForEventLog(EventName, EventLogLevel.Error, , , ListOfCriticalChanges);
			
			RaiseByError(ExtensionsObjects,
				NStr("en = 'Critical changes can only be applied
				           |to the master node of the distributed infobase.
				           |For the list of changes, see the event log.';"));
		EndIf;
		
		HasCurrentChanges = False;
		UpdateMetadataObjectIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			ExtensionProperties, ExtensionsVersion, HasCurrentChanges, IsCheckOnly);
		
		If HasCurrentChanges Then
			HasChanges = True;
		EndIf;
		
		If Not IsCheckOnly Then
			If Not ExtensionsObjects And HasCurrentChanges Then
				StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
			EndIf;
			If ValueIsFilled(ListOfCriticalChanges) Then
				EventLog.AddMessageForEventLog(?(ExtensionsObjects,
						NStr("en = 'Extension object IDs.Critical changes applied';",
							Common.DefaultLanguageCode()),
						NStr("en = 'Metadata object IDs.Critical changes applied';",
							Common.DefaultLanguageCode())),
					EventLogLevel.Information,,,
					ListOfCriticalChanges);
			EndIf;
			
			If Not ExtensionsObjects
			   And Not Common.IsSubordinateDIBNode() Then
				
				PrepareNewSubsystemsListInMasterNode(Upload0);
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns:
//  ValueTable:
//   * Ref - CatalogRef.MetadataObjectIDs
//            - CatalogRef.ExtensionObjectIDs
//   * PredefinedDataName - String
//   * Parent - CatalogRef.MetadataObjectIDs
//              - CatalogRef.ExtensionObjectIDs
//   * DeletionMark - Boolean
//   * Description - String
//   * CollectionOrder - Number
//   * Name - String
//   * Synonym - String
//   * FullName - String
//   * FullSynonym - String
//   * NoData - Boolean
//   * EmptyRefValue - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//   * KeyStorage - ValueStorage
//   * NewRef - CatalogRef.MetadataObjectIDs
//                 - CatalogRef.ExtensionObjectIDs
//   * ExtensionName - String
//   * ExtensionID - String
//   * ExtensionHashsum - String
//   * MetadataObjectKey - Type
//                           - String
//                           - Undefined
//   * NoMetadataObjectKey - Boolean
//   * IsCollection - Boolean
//   * IsNew - Boolean
//
Function ExportAllIDs(ExtensionsObjects = False)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.PredefinedDataName AS PredefinedDataName,
	|	IDs.Parent AS Parent,
	|	IDs.DeletionMark AS DeletionMark,
	|	IDs.Description AS Description,
	|	IDs.CollectionOrder,
	|	IDs.Name,
	|	IDs.Synonym,
	|	IDs.FullName,
	|	IDs.FullSynonym,
	|	IDs.NoData,
	|	IDs.EmptyRefValue,
	|	IDs.MetadataObjectKey AS KeyStorage,
	|	IDs.NewRef,
	|	&ExtensionName AS ExtensionName,
	|	&ExtensionID AS ExtensionID,
	|	&ExtensionHashsum AS ExtensionHashsum
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	ClarifyCatalogNameInQueryText(Query.Text, ExtensionsObjects);
	Query.Text = StrReplace(Query.Text, "&ExtensionName",
		?(ExtensionsObjects, "IDs.ExtensionName", """"""));
	Query.Text = StrReplace(Query.Text, "&ExtensionID",
		?(ExtensionsObjects, "IDs.ExtensionID", """"""));
	Query.Text = StrReplace(Query.Text, "&ExtensionHashsum",
		?(ExtensionsObjects, "IDs.ExtensionHashsum", """"""));
	
	Upload0 = Query.Execute().Unload();
	Upload0.Columns.Add("MetadataObjectKey");
	Upload0.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	Upload0.Columns.Add("IsCollection",              New TypeDescription("Boolean"));
	Upload0.Columns.Add("IsNew",                  New TypeDescription("Boolean"));
	
	// Ordering the IDs before processing.
	For Each String In Upload0 Do
		If Not ValueIsFilled(String.Ref) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The catalog ""%1"" contains corrupted data.
				           |Open Designer and select Administration > Verify and repair…';"),
				?(ExtensionsObjects, "ExtensionObjectIDs", "MetadataObjectIDs"));
			Raise ErrorText;
		EndIf;
		If TypeOf(String.KeyStorage) = Type("ValueStorage") Then
			String.MetadataObjectKey = String.KeyStorage.Get();
		Else
			String.MetadataObjectKey = Undefined;
		EndIf;
		String.NoMetadataObjectKey = String.MetadataObjectKey = Undefined
		                               Or String.MetadataObjectKey = Type("Undefined");
	EndDo;
	
	Upload0.Indexes.Add("Ref");
	Upload0.Indexes.Add("FullName");
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	
	For Each CollectionProperties In CollectionsProperties Do
		CollectionID = CollectionID(CollectionProperties.Id, ExtensionsObjects);
		String = Upload0.Find(CollectionID, "Ref");
		If String = Undefined Then
			String = Upload0.Add();
			String.Ref   = CollectionID;
			String.IsNew = True;
		EndIf;
		String.IsCollection = True;
	EndDo;
	
	Upload0.Sort("IsCollection DESC,
	                     |DeletionMark ASC,
	                     |NoMetadataObjectKey ASC");
	
	Return Upload0;
	
EndFunction

Procedure RenameFullNames(Upload0, MetadataObjectRenamingList = "", HasCriticalChanges = False)
	
	RenamingTable = StandardSubsystemsCached.RenamingTableForCurrentVersion();
	RenamedItems = New Map;
	
	For Each RenamingDetails In RenamingTable Do
		PreviousFullNameLength = StrLen(RenamingDetails.PreviousFullName);
		IsSubsystem = Upper(Left(RenamingDetails.PreviousFullName,
			StrLen("Subsystem."))) = Upper("Subsystem.");
		
		For Each String In Upload0 Do
			If String.IsCollection Then
				Continue;
			EndIf;
			
			NewFullName = "";
			
			If IsSubsystem Then
				If Upper(Left(String.FullName, PreviousFullNameLength))
				     = Upper(RenamingDetails.PreviousFullName) Then
					
					NewFullName = RenamingDetails.NewFullName
						+ Mid(String.FullName, PreviousFullNameLength + 1);
				EndIf;
			Else
				If Upper(String.FullName) = Upper(RenamingDetails.PreviousFullName) Then
					NewFullName = RenamingDetails.NewFullName;
				EndIf;
			EndIf;
			
			If Not ValueIsFilled(NewFullName) Then
				Continue;
			EndIf;
			
			Renaming = RenamedItems.Get(String);
			If Renaming = Undefined Then
				Renaming = New Structure;
				Renaming.Insert("PreviousFullName", String.FullName);
				Renaming.Insert("NewFullName",  NewFullName);
				RenamedItems.Insert(String, Renaming);
			Else
				Renaming.NewFullName = NewFullName;
			EndIf;
			String.FullName = NewFullName;
			String.Updated = True;
		EndDo;
	EndDo;
	
	For Each String In Upload0 Do
		Renaming = RenamedItems.Get(String);
		If Renaming = Undefined Then
			Continue;
		EndIf;
		
		HasCriticalChanges = True;
		MetadataObjectRenamingList = MetadataObjectRenamingList
			+ ?(ValueIsFilled(MetadataObjectRenamingList), "," + Chars.LF, "")
			+ Renaming.PreviousFullName + " -> " + Renaming.NewFullName;
	EndDo;
	
EndProcedure

Procedure ProcessMetadataObjectIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			ExtensionProperties, HasDeletedItems, HasCriticalChanges, MetadataObjectRenamingList)
	
	// Processing the metadata object IDs.
	For Each Properties In Upload0 Do
		
		// Validating and updating properties of the metadata object collection IDs.
		If Properties.IsCollection Then
			CheckUpdateCollectionProperties(Properties, ExtensionsObjects);
			Continue;
		EndIf;
		
		If ExtensionsObjects
		   And (    ExtensionProperties.UnattachedExtensionsNames[Lower(Properties.ExtensionName)] <> Undefined
		      Or ExtensionProperties.UnattachedExtensionsNames[Lower(Properties.ExtensionID)] <> Undefined)Then
			// In case the extension is disabled and then enabled, make sure
			// the objects marked for deletion are the related data are not deleted.
			Continue;
		EndIf;
		
		If ExtensionsObjects
		   And ExtensionProperties.AttachedExtensionsNames[Lower(Properties.ExtensionName)] = Undefined
		   And ExtensionProperties.AttachedExtensionsNames[Lower(Properties.ExtensionID)] = Undefined Then
			
			PropertiesUpdated = False;
			UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated, HasDeletedItems);
			If PropertiesUpdated Then
				Properties.Updated = True;
			EndIf;
		EndIf;
		
		MetadataObjectKey = Properties.MetadataObjectKey;
		MetadataObject = MetadataObjectByKey(MetadataObjectKey,
			Properties.ExtensionName, Properties.ExtensionID, Properties.ExtensionHashsum);
		
		If MetadataObject = Undefined Then
			If MetadataObjectKey = Type("Undefined") Then
				// If the metadata object has no key, it can be found by the full name only.
				MetadataObject = MetadataFindByFullName(Properties.FullName);
				If MetadataObject = Undefined And ExtensionsObjects Then
					MetadataObject = ExtensionMetadataFindByFullName(Properties);
				EndIf;
			EndIf;
		Else
			// If a metadata object was deleted in the course of restructuring,
			// then use the old ID for the new metadata object.
			// And create new IDs for old metadata objects.
			If Upper(Left(MetadataObject.Name, StrLen("Delete"))) =  Upper("Delete")
			   And Upper(Left(Properties.Name,         StrLen("Delete"))) <> Upper("Delete") Then
				
				NewMetadataObject = MetadataFindByFullName(Properties.FullName);
				If NewMetadataObject <> Undefined Then
					MetadataObject = NewMetadataObject;
					MetadataObjectKey = Undefined; // Required for the ID update.
				EndIf;
			EndIf;
		EndIf;
		
		// If the metadata object is found by key or full name,
		// prepare a string with the metadata object's properties.
		If MetadataObject <> Undefined Then
			ObjectProperties = MetadataObjectProperties1.Find(MetadataObject.FullName(), "FullName");
			If ObjectProperties = Undefined Then
				MetadataObject = Undefined;
			Else
				Properties.MetadataObject = MetadataObject;
			EndIf;
		EndIf;
		
		If MetadataObject = Undefined Or ObjectProperties.Found Then
			// If the object is not found or re-found,
			// mark its ID for deletion.
			IsDuplicate = MetadataObject <> Undefined And ObjectProperties.Found;
			PropertiesUpdated = False;
			UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated, HasDeletedItems, IsDuplicate);
			If PropertiesUpdated Then
				Properties.Updated = True;
			EndIf;
		Else
			// Updating properties of the existing metadata objects (if any changes were made).
			ObjectProperties.Found = True;
			If Properties.Description              <> ObjectProperties.Description
			 Or Properties.CollectionOrder          <> ObjectProperties.CollectionOrder
			 Or Properties.Name                       <> ObjectProperties.Name
			 Or Properties.Synonym                   <> ObjectProperties.Synonym
			 Or Properties.FullName                 <> ObjectProperties.FullName
			 Or Properties.FullSynonym             <> ObjectProperties.FullSynonym
			 Or Properties.NoData                 <> ObjectProperties.NoData
			 Or Properties.EmptyRefValue      <> ObjectProperties.EmptyRefValue
			 Or Properties.ExtensionName             <> ObjectProperties.ExtensionName
			 Or Properties.ExtensionID   <> ObjectProperties.ExtensionID
			 Or Properties.ExtensionHashsum        <> ObjectProperties.ExtensionHashsum
			 Or Properties.PredefinedDataName <> ObjectProperties.PredefinedDataName
			 Or Properties.DeletionMark
			 Or MetadataObjectKey = Undefined
			 Or ObjectProperties.NoMetadataObjectKey
			     <> (MetadataObjectKey = Type("Undefined")) Then
				
				If Upper(Properties.FullName) <> Upper(ObjectProperties.FullName) Then
					HasCriticalChanges = True;
					MetadataObjectRenamingList = MetadataObjectRenamingList
						+ ?(ValueIsFilled(MetadataObjectRenamingList), "," + Chars.LF, "")
						+ Properties.FullName + " -> " + ObjectProperties.FullName;
				EndIf;
				
				// Setting new properties for the metadata object ID.
				FillPropertyValues(Properties, ObjectProperties);
				
				Properties.PredefinedDataName = ObjectProperties.PredefinedDataName;
				
				If MetadataObjectKey = Undefined
				 Or ObjectProperties.NoMetadataObjectKey
				     <> (MetadataObjectKey = Type("Undefined")) Then
					
					Properties.MetadataObjectKey = MetadataObjectKey(ObjectProperties.FullName);
				EndIf;
				
				Properties.DeletionMark = False;
				Properties.Updated = True;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Function ExtensionMetadataFindByFullName(Properties)
	
	If Properties.ExtensionName = ""
	 Or Not StrStartsWith(Properties.FullName, "? ") Then
		Return Undefined;
	EndIf;
	
	// Restore the link with the metadata object ID of the extension
	// that is being reinstalled.
	OriginalFullName = FullNameOfDeletedItem(Properties.FullName);
	MetadataObject = MetadataFindByFullName(OriginalFullName);
	
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	ObjectExtension = MetadataObject.ConfigurationExtension();
	If ObjectExtension = Undefined Then
		Return Undefined;
	EndIf;
	
	If Lower(ObjectExtension.UUID) = Lower(Mid(Properties.ExtensionID, 3))
	 Or Lower(ObjectExtension.Name) = Lower(Mid(Properties.ExtensionName, 3)) Then
		
		Return MetadataObject;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ExtensionKeyIds(DatabaseExtensions = Undefined)
	
	Extensions = ConfigurationExtensions.Get();
	ExtensionKeyIds = New Map;
	For Each Extension In Extensions Do
		ExtensionKey = Lower(Extension.Name) + " " + Base64String(Extension.HashSum);
		ExtensionKeyIds.Insert(ExtensionKey, Lower(Extension.UUID));
		If TypeOf(DatabaseExtensions) = Type("Array") Then
			DatabaseExtensions.Add(Extension);
		EndIf;
	EndDo;
	
	Return ExtensionKeyIds;
	
EndFunction

Procedure AddNewMetadataObjectsIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			HasCriticalChanges, NewMetadataObjectsList)
	
	ObjectProperties = MetadataObjectProperties1.FindRows(New Structure("Found", False));
	
	For Each Var_156_ObjectProperties In ObjectProperties Do
		Properties = Upload0.Add();
		FillPropertyValues(Properties, Var_156_ObjectProperties);
		Properties.IsNew = True;
		Properties.Ref = NewCatalogRef(ExtensionsObjects);
		Properties.DeletionMark  = False;
		Properties.MetadataObject = Var_156_ObjectProperties.MetadataObject;
		Properties.MetadataObjectKey = MetadataObjectKey(Properties.FullName);
		HasCriticalChanges = True;
		NewMetadataObjectsList = NewMetadataObjectsList
			+ ?(ValueIsFilled(NewMetadataObjectsList), "," + Chars.LF, "")
			+ Var_156_ObjectProperties.FullName;
	EndDo;
	
EndProcedure

Procedure UpdateMetadataObjectIDs(Upload0, MetadataObjectProperties1, ExtensionsObjects,
			ExtensionProperties, ExtensionsVersion, HasChanges, IsCheckOnly)
		
	// ACC:1327-off #783.1.4.1 Managed lock is set in the calling code.
	If ExtensionsObjects Then
		RecordSet = InformationRegisters.ExtensionVersionObjectIDs.CreateRecordSet();
		RecordSet.Filter.ExtensionsVersion.Set(ExtensionsVersion);
		RecordSet.Read();
		RecordsTable = RecordSet.Unload();
		RecordsTable.Columns.Add("Delete", New TypeDescription("Boolean"));
		RecordsTable.FillValues(True, "Delete");
		RecordsTable.Indexes.Add("Id, FullObjectName, ExtensionsVersion");
		UpdateRecordSet = False;
	EndIf;
	
	For Each Properties In Upload0 Do
		
		// Updating parents of the metadata object IDs.
		If Not Properties.IsCollection Then
			ObjectProperties = MetadataObjectProperties1.Find(Properties.FullName, "FullName");
			NewParent = EmptyCatalogRef(ExtensionsObjects);
			
			If ObjectProperties <> Undefined Then
				If Not ValueIsFilled(ObjectProperties.FullParentName) Then
					// This is a collection of metadata objects.
					NewParent = ObjectProperties.Parent;
				Else
					// This is not a collection of metadata objects. Example: subsystem.
					ParentDetails = Upload0.Find(ObjectProperties.FullParentName, "FullName");
					If ParentDetails <> Undefined Then
						NewParent = ParentDetails.Ref;
					EndIf;
				EndIf;
			EndIf;
			
			If Properties.Parent <> NewParent Then
				Properties.Parent = NewParent;
				Properties.Updated = True;
			EndIf;
			
			If ExtensionsObjects
			   And Properties.DeletionMark = False
			   And ExtensionProperties.UnattachedExtensionsNames[Lower(Properties.ExtensionName)] = Undefined
			   And ExtensionProperties.UnattachedExtensionsNames[Lower(Properties.ExtensionID)] = Undefined Then
				
				Filter = New Structure;
				Filter.Insert("ExtensionsVersion", ExtensionsVersion);
				Filter.Insert("Id",    Properties.Ref);
				Filter.Insert("FullObjectName", Properties.FullName);
				Rows = RecordsTable.FindRows(Filter);
				If Rows.Count() = 0 Then
					UpdateRecordSet = True;
					FillPropertyValues(RecordsTable.Add(), Filter);
				Else
					Rows[0].Delete = False;
				EndIf;
			EndIf;
		EndIf;
		
		// Updating the metadata object IDs.
		If Properties.IsNew Then
			TableObject = CreateCatalogItem(ExtensionsObjects);
			TableObject.SetNewObjectRef(Properties.Ref);
			
		ElsIf Properties.Updated Then
			TableObject = Properties.Ref.GetObject();
		Else
			Continue;
		EndIf;
		
		HasChanges = True;
		If IsCheckOnly Then
			Return;
		EndIf;
		
		FillPropertyValues(TableObject, Properties);
		TableObject.MetadataObjectKey = New ValueStorage(Properties.MetadataObjectKey);
		TableObject.DataExchange.Load = True;
		// @skip-check query-in-loop - The query branch is not triggered in this option
		CheckObjectBeforeWrite(TableObject, True);
		TableObject.Write();
	EndDo;
	
	If ExtensionsObjects Then
		RecordsTable.Indexes.Add("Delete");
		Rows = RecordsTable.FindRows(New Structure("Delete", True));
		If Rows.Count() > 0
		   And (Rows.Count() <> 1
		      Or ValueIsFilled(Rows[0].FullObjectName)
		        And Rows[0].ExtensionsVersion = ExtensionsVersion) Then
			UpdateRecordSet = True;
			For Each String In Rows Do
				RecordsTable.Delete(String);
			EndDo;
		EndIf;
		If RecordsTable.Count() = 0
		   And ValueIsFilled(ExtensionsVersion) Then
			// In case the extension has no metadata object, add one record
			// so that the cache check returns "True".
			RecordsTable.Add().ExtensionsVersion = ExtensionsVersion;
			UpdateRecordSet = True;
		EndIf;
		If UpdateRecordSet Then
			HasChanges = True;
			If IsCheckOnly Then
				Return;
			EndIf;
			RecordSet.Load(RecordsTable);
			RecordSet.Write();
		EndIf;
	EndIf;
	// ACC:1327-off.
	
EndProcedure

Procedure UpdateMarkedForDeletionItemProperties(Properties, PropertiesUpdated = False, HasDeletedItems = False, IsDuplicate = False)
	
	ExtensionsObjects = IsExtensionsObject(Properties.Ref);
	
	If IsDuplicate Then
		MetadataObjectKey = ?(TypeOf(Properties.MetadataObjectKey) = Type("ValueStorage"),
			Properties.MetadataObjectKey.Get(), Properties.MetadataObjectKey);
	EndIf;
	
	If Not Properties.DeletionMark
	 Or ValueIsFilled(Properties.Parent)
	 Or Left(Properties.Description, 1)  <> "?"
	 Or Left(Properties.Name, 1)           <> "?"
	 Or Left(Properties.Synonym, 1)       <> "?"
	 Or Left(Properties.FullName, 1)     <> "?"
	 Or Left(Properties.FullSynonym, 1) <> "?"
	 Or ExtensionsObjects And Left(Properties.ExtensionName, 1)           <> "?"
	 Or ExtensionsObjects And Left(Properties.ExtensionID, 1) <> "?"
	 Or ExtensionsObjects And Left(Properties.ExtensionHashsum, 1)      <> "?"
	 Or StrFind(Properties.FullName, "(") = 0
	 Or Properties.EmptyRefValue  <> Undefined
	 Or Properties.PredefinedDataName <> ""
	 Or IsDuplicate
	   And MetadataObjectKey <> Undefined Then
		
		If Not Properties.DeletionMark Or Left(Properties.FullName, 1) <> "?" Then
			HasDeletedItems = True;
		EndIf;
		
		// Setting new properties for the metadata object ID.
		Properties.DeletionMark       = True;
		Properties.Parent              = EmptyCatalogRef(IsExtensionsObject(Properties.Ref));
		Properties.Description          = InsertQuestionMark(Properties.Description);
		Properties.Name                   = InsertQuestionMark(Properties.Name);
		Properties.Synonym               = InsertQuestionMark(Properties.Synonym);
		Properties.FullName             = UniqueFullName(Properties);
		Properties.FullSynonym         = InsertQuestionMark(Properties.FullSynonym);
		Properties.EmptyRefValue  = Undefined;
		Properties.PredefinedDataName = "";
		
		If ExtensionsObjects Then
			Properties.ExtensionName           = InsertQuestionMark(Properties.ExtensionName);
			Properties.ExtensionID = InsertQuestionMark(Properties.ExtensionID);
			Properties.ExtensionHashsum      = InsertQuestionMark(Properties.ExtensionHashsum);
		EndIf;
		
		If IsDuplicate Then
			If TypeOf(Properties.MetadataObjectKey) = Type("ValueStorage") Then
				Properties.MetadataObjectKey = New ValueStorage(Undefined);
			Else
				Properties.MetadataObjectKey = Undefined;
			EndIf;
		EndIf;
		PropertiesUpdated = True;
	EndIf;
	
EndProcedure

Procedure CheckUpdateCollectionProperties(Val CurrentProperties, ExtensionsObjects)
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	NewProperties = CollectionsProperties.Find(CurrentProperties.Ref.UUID(), "Id");
	
	CollectionDescription = NewProperties.Synonym;
	
	If CurrentProperties.Description              <> CollectionDescription
	 Or CurrentProperties.CollectionOrder          <> NewProperties.CollectionOrder
	 Or CurrentProperties.Name                       <> NewProperties.Name
	 Or CurrentProperties.Synonym                   <> NewProperties.Synonym
	 Or CurrentProperties.FullName                 <> NewProperties.Name
	 Or CurrentProperties.FullSynonym             <> NewProperties.Synonym
	 Or CurrentProperties.NoData                 <> False
	 Or CurrentProperties.EmptyRefValue      <> Undefined
	 Or CurrentProperties.PredefinedDataName <> ""
	 Or CurrentProperties.DeletionMark           <> False
	 Or CurrentProperties.MetadataObjectKey     <> Undefined Then
		
		// Set up new properties.
		CurrentProperties.Description              = CollectionDescription;
		CurrentProperties.CollectionOrder          = NewProperties.CollectionOrder;
		CurrentProperties.Name                       = NewProperties.Name;
		CurrentProperties.Synonym                   = NewProperties.Synonym;
		CurrentProperties.FullName                 = NewProperties.Name;
		CurrentProperties.FullSynonym             = NewProperties.Synonym;
		CurrentProperties.NoData                 = False;
		CurrentProperties.EmptyRefValue      = Undefined;
		CurrentProperties.PredefinedDataName = "";
		CurrentProperties.DeletionMark           = False;
		CurrentProperties.MetadataObjectKey     = Undefined;
		
		CurrentProperties.Updated = True;
	EndIf;
	
EndProcedure

// Parameters:
//  FullName - String
// 
// Returns:
//  - Type
//  - String
//
Function MetadataObjectKey(FullName)
	
	PointPosition = StrFind(FullName, ".");
	
	MetadataObjectClass = Upper(Left( FullName, PointPosition - 1));
	MetadataObjectName   = Mid(FullName, PointPosition + 1);
	
	If MetadataObjectClass = Upper("ExchangePlan") 
		Or MetadataObjectClass = Upper("Catalog")
		Or MetadataObjectClass = Upper("Document")
		Or MetadataObjectClass = Upper("ChartOfCharacteristicTypes")
		Or MetadataObjectClass = Upper("ChartOfAccounts")
		Or MetadataObjectClass = Upper("ChartOfCalculationTypes")
		Or MetadataObjectClass = Upper("BusinessProcess")
		Or MetadataObjectClass = Upper("Task") Then
		Return Type(MetadataObjectClass + "Ref." + MetadataObjectName);
		
	ElsIf MetadataObjectClass = Upper("Role") Then
		Return KeyRole(Metadata.Roles[MetadataObjectName]);
		
	ElsIf MetadataObjectClass = Upper("Constant")
		Or MetadataObjectClass = Upper("DocumentJournal") Then
		Return TypeOf(Common.ObjectManagerByFullName(FullName));
		
	ElsIf MetadataObjectClass = Upper("Report")
		Or MetadataObjectClass = Upper("DataProcessor") Then
		Return Type(MetadataObjectClass + "Object." + MetadataObjectName);
		
	ElsIf MetadataObjectClass = Upper("InformationRegister")
		Or MetadataObjectClass = Upper("AccumulationRegister")
		Or MetadataObjectClass = Upper("AccountingRegister")
		Or MetadataObjectClass = Upper("CalculationRegister") Then
		Return Type(MetadataObjectClass + "RecordKey." + MetadataObjectName);
	Else
		// No metadata object key.
		Return Type("Undefined");
	EndIf;
	
EndFunction 

Function IdenticalMetadataObjectKeys(Properties, Object)
	
	Return Properties.MetadataObjectKey = Object.MetadataObjectKey.Get();
	
EndFunction

// Parameters:
//  IDProperties - ValueTableRow:
//   * ExtensionID - String
//   * ExtensionName - String
//   * MetadataObjectKey - ValueStorage
//   * FullName - String
//   * FullCollectionName - String
//   * DeletionMark - Boolean
//   * Presentation - String
//   * Ref - CatalogRef.MetadataObjectIDs
//   * ExtensionHashsum - String
// 
// Returns:
//   Structure:
//     * NotRespond            - Boolean
//     * MetadataObjectKey      - Arbitrary
//     * MetadataObject           - MetadataObject
//     * RemoteMetadataObject - MetadataObject
//     * ViewOfTheRemote    - String
//
Function MetadataObjectKeyMatchesFullName(IDProperties)
	
	CheckResult = New Structure;
	CheckResult.Insert("NotRespond", True);
	CheckResult.Insert("MetadataObjectKey", Undefined);
	CheckResult.Insert("MetadataObject", Undefined);
	CheckResult.Insert("RemoteMetadataObject", Undefined);
	CheckResult.Insert("ViewOfTheRemote", "");
	
	MetadataObjectKey = IDProperties.MetadataObjectKey.Get();
	ExtensionsObjects = IsExtensionsObject(IDProperties.Ref);
	
	If MetadataObjectKey <> Undefined
	   And MetadataObjectKey <> Type("Undefined") Then
		// Key is specified; searching for metadata object by the key.
		CheckResult.MetadataObjectKey = MetadataObjectKey;
		MetadataObject = MetadataObjectByKey(MetadataObjectKey,
			IDProperties.ExtensionName,
			IDProperties.ExtensionID,
			IDProperties.ExtensionHashsum);
		If MetadataObject <> Undefined Then
			CheckResult.NotRespond = MetadataObject.FullName() <> IDProperties.FullName;
		EndIf;
	Else
		// Key is not specified; searching for metadata object by the full name.
		MetadataObject = MetadataFindByFullName(IDProperties.FullName);
		If MetadataObject = Undefined Then
			// A collection might have been specified.
			
			String = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects).Find(
				IDProperties.Ref.UUID(), "Id");
			
			If String <> Undefined Then
				MetadataObject = Metadata[String.Name];
				CheckResult.NotRespond = String.Name <> IDProperties.FullCollectionName;
			EndIf;
		Else
			CheckResult.NotRespond = False;
		EndIf;
	EndIf;
	
	CheckResult.MetadataObject = MetadataObject;
	
	If MetadataObject = Undefined
	   And IDProperties.DeletionMark
	   And StrStartsWith(IDProperties.FullCollectionName, "? ") Then
		
		CheckResult.RemoteMetadataObject = Common.MetadataObjectByFullName(
			FullNameOfDeletedItem(IDProperties.FullCollectionName));
	EndIf;
	If StrStartsWith(String(IDProperties.Presentation), "? ") Then
		CheckResult.ViewOfTheRemote =
			Mid(String(IDProperties.Presentation), 3);
	EndIf;
	
	Return CheckResult;
	
EndFunction

Function FullNameOfDeletedItem(FullName)
	
	FullNameOfDeletedItem = Mid(FullName, 3);
	ParenthesisPosition = StrFind(FullNameOfDeletedItem, "(");
	If ParenthesisPosition > 0 Then
		FullNameOfDeletedItem = Mid(FullNameOfDeletedItem, 1, ParenthesisPosition - 1);
	EndIf;
	
	Return TrimAll(FullNameOfDeletedItem);
	
EndFunction

Function CannotChangeFullName(Object)
	
	ExtensionsObjects = IsExtensionsObject(Object);
	If IsCollection(Object.Ref, ExtensionsObjects) Then
		Return True;
	EndIf;
	
	PointPosition = StrFind(Object.FullName, ".");
	BaseTypeName = Left(Object.FullName, PointPosition -1);
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	CollectionProperties = CollectionsProperties.Find(BaseTypeName, "SingularName");
	
	If CollectionProperties <> Undefined
	   And Not CollectionProperties.NoMetadataObjectKey Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function MetadataObjectByKey(MetadataObjectKey, ExtensionName, ExtensionID, ExtensionHashsum)
	
	MetadataObject = Undefined;
	MetadataObjectKeyType = TypeOf(MetadataObjectKey);
	
	If MetadataObjectKeyType = Type("Type") Then
		MetadataObject = Metadata.FindByType(MetadataObjectKey);
	ElsIf MetadataObjectKeyType = Type("String") Then
		MetadataObject = StandardSubsystemsCached.RolesByKeysMetadataObjects().Get(MetadataObjectKey);
	EndIf;
	
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	ObjectExtension = MetadataObject.ConfigurationExtension();
	If ObjectExtension = Undefined Then
		Return ?(ValueIsFilled(ExtensionName), Undefined, MetadataObject);
	EndIf;
	
	If Lower(ObjectExtension.UUID) = Lower(ExtensionID)
	 Or Lower(ObjectExtension.UUID) = Lower(Mid(ExtensionID, 3))
	 Or Lower(ObjectExtension.Name) = Lower(ExtensionName)
	 Or Lower(ObjectExtension.Name) = Lower(Mid(ExtensionName, 3)) Then
		
		Return MetadataObject;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Intended to be called from StandardSubsystemsCached.RolesByMetadataObjectsKeys.
// 
// Returns:
//  Map of KeyAndValue:
//   * Key - String - Key of the "Role" metadata object.
//   * Value - MetadataObject - Role.
//
Function RolesByKeysMetadataObjects() Export
	
	RolesByKeys = New Map;
	For Each Role In Metadata.Roles Do
		RolesByKeys.Insert(KeyRole(Role), Role);
	EndDo;
	
	Return RolesByKeys;
	
EndFunction

Function KeyRole(MetadataObjectRole, RaiseException1 = True)
	
	IBUser = InfoBaseUsers.CreateUser();
	IBUser.Roles.Add(MetadataObjectRole);
	
	String = Lower(StrReplace(ValueToStringInternal(IBUser.Roles), Chars.LF, ""));
	SearchString = "{""#"",d6d05c81-8b72-4eef-96d3-f795c1424c29,{1,";
	Position = StrFind(String, SearchString);
	If Position = 1 Then
		Id = Mid(String, StrLen(SearchString) + 1, 36);
		If StringFunctionsClientServer.IsUUID(Id) Then
			Return Id;
		EndIf;
	EndIf;
	
	If Not RaiseException1 Then
		Return Undefined;
	EndIf;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Cannot receive a key of role %1';"), MetadataObjectRole.Name);
	
	Raise ErrorText;
	
EndFunction

// Parameters:
//  ExtensionsObjects - Boolean
//  CollectionsProperties - See MetadataObjectCollectionProperties
//  ExtensionKeyIds - Map
//
// Returns:
//  ValueTable:
//   * Description         - String
//   * FullName            - String
//   * FullParentName    - String
//   * CollectionOrder     - Number
//   * Parent             - CatalogRef.MetadataObjectIDs
//                          - CatalogRef.ExtensionObjectIDs
//   * Name                  - String
//   * PredefinedDataName - String
//   * Synonym              - String
//   * FullSynonym        - String
//   * NoData            - Boolean
//   * NoMetadataObjectKey - Boolean
//   * ExtensionName        - String
//   * ExtensionID - String
//   * ExtensionHashsum   - String
//   * EmptyRefValue - AnyRef
//   * MetadataObject     - MetadataObject
//
Function MetadataObjectProperties1(ExtensionsObjects, CollectionsProperties = Undefined, ExtensionKeyIds = Undefined)
	
	ParentTypesArray = New Array;
	ParentTypesArray.Add(TypeOf(EmptyCatalogRef(ExtensionsObjects)));
	
	MetadataObjectProperties1 = New ValueTable;
	MetadataObjectProperties1.Columns.Add("Description",              New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties1.Columns.Add("FullName",                 New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties1.Columns.Add("FullParentName",         New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties1.Columns.Add("CollectionOrder",          New TypeDescription("Number"));
	MetadataObjectProperties1.Columns.Add("Parent",                  New TypeDescription(ParentTypesArray));
	MetadataObjectProperties1.Columns.Add("Name",                       New TypeDescription("String",, New StringQualifiers(150)));
	MetadataObjectProperties1.Columns.Add("PredefinedDataName", New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties1.Columns.Add("Synonym",                   New TypeDescription("String",, New StringQualifiers(255)));
	MetadataObjectProperties1.Columns.Add("FullSynonym",             New TypeDescription("String",, New StringQualifiers(510)));
	MetadataObjectProperties1.Columns.Add("NoData",                 New TypeDescription("Boolean"));
	MetadataObjectProperties1.Columns.Add("NoMetadataObjectKey", New TypeDescription("Boolean"));
	MetadataObjectProperties1.Columns.Add("ExtensionName",             New TypeDescription("String",, New StringQualifiers(128)));
	MetadataObjectProperties1.Columns.Add("ExtensionID",   New TypeDescription("String",, New StringQualifiers(38)));
	MetadataObjectProperties1.Columns.Add("ExtensionHashsum",        New TypeDescription("String",, New StringQualifiers(30)));
	MetadataObjectProperties1.Columns.Add("EmptyRefValue");
	MetadataObjectProperties1.Columns.Add("MetadataObject");
	
	If CollectionsProperties = Undefined Then
		CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	EndIf;
	
	If ExtensionsObjects And ExtensionKeyIds = Undefined Then
		ExtensionKeyIds = ExtensionKeyIds();
	EndIf;
	
	PredefinedDataNames = ?(ExtensionsObjects,
		Metadata.Catalogs.ExtensionObjectIDs,
		Metadata.Catalogs.MetadataObjectIDs).GetPredefinedNames();
	
	PredefinedItemsNames = New Map;
	For Each PredefinedItemName In PredefinedDataNames Do
		PredefinedItemsNames.Insert(PredefinedItemName, False);
	EndDo;
	
	If Not ExtensionsObjects Or ValueIsFilled(SessionParameters.AttachedExtensions) Then
		For Each CollectionProperties In CollectionsProperties Do
			AddMetadataObjectProperties(Metadata[CollectionProperties.Name], CollectionProperties,
				MetadataObjectProperties1, ExtensionKeyIds, PredefinedItemsNames);
		EndDo;
		MetadataObjectProperties1.Indexes.Add("FullName");
	EndIf;
	
	Return MetadataObjectProperties1;
	
EndFunction

Procedure AddMetadataObjectProperties(Val MetadataObjectCollection,
                                             Val CollectionProperties,
                                             Val MetadataObjectProperties1,
                                             Val ExtensionKeyIds,
                                             Val PredefinedItemsNames,
                                             Val FullParentName = "",
                                             Val ParentFullSynonym = "")
	
	
	ExtensionsObjects = ExtensionKeyIds <> Undefined;
	
	For Each MetadataObject In MetadataObjectCollection Do
		
		FullName = MetadataObject.FullName();
		Extension = MetadataObject.ConfigurationExtension();
		ExtensionName           = ?(Extension = Undefined, "", Extension.Name);
		ExtensionID = ?(Extension = Undefined, "", Lower(Extension.UUID));
		ExtensionHashsum      = ?(Extension = Undefined, "", Base64String(Extension.HashSum));
		If ExtensionsObjects And Extension <> Undefined Then
			ExtensionKey = Lower(ExtensionName) + " " + ExtensionHashsum;
			NewExtensionId = ExtensionKeyIds.Get(ExtensionKey);
			If NewExtensionId <> Undefined
			   And NewExtensionId <> ExtensionID Then
				ExtensionID = NewExtensionId;
			EndIf;
		EndIf;
		If ValueIsFilled(ExtensionName) <> ExtensionsObjects Then
			Continue;
		EndIf;
		
		If StrFind(CollectionProperties.SingularName, "Subsystem") <> 0 Then
			MetadataFindByFullName(FullName);
		EndIf;
		
		If Not CollectionProperties.NoData
		   And Not StandardSubsystemsServer.IsRegisterTable(CollectionProperties.SingularName)
		   And StrFind(CollectionProperties.SingularName, "Constant") = 0 Then
			
			RefTypeName1 = CollectionProperties.SingularName + "Ref." + MetadataObject.Name;
			TypeDetails = New TypeDescription(RefTypeName1);
			EmptyRefValue = TypeDetails.AdjustValue(Undefined);
		Else
			EmptyRefValue = Undefined;
		EndIf;
		
		NewRow = MetadataObjectProperties1.Add();
		FillPropertyValues(NewRow, CollectionProperties);
		NewRow.Parent          = CollectionID(CollectionProperties.Id, ExtensionsObjects);
		NewRow.Description      = MetadataObjectPresentation(MetadataObject, CollectionProperties);
		NewRow.FullName         = FullName;
		NewRow.FullParentName = FullParentName;
		NewRow.Name               = MetadataObject.Name;
		
		NewRow.Synonym = ?(
			ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
		
		NewRow.FullSynonym =
			ParentFullSynonym + CollectionProperties.SingularSynonym + ". " + NewRow.Synonym;
		
		NewRow.EmptyRefValue    = EmptyRefValue;
		NewRow.MetadataObject        = MetadataObject;
		NewRow.ExtensionName           = ExtensionName;
		NewRow.ExtensionID = ExtensionID;
		NewRow.ExtensionHashsum      = ExtensionHashsum;
		
		If CollectionProperties.Name = "Subsystems" Then
			AddMetadataObjectProperties(
				MetadataObject.Subsystems,
				CollectionProperties,
				MetadataObjectProperties1,
				ExtensionKeyIds,
				PredefinedItemsNames,
				FullName,
				NewRow.FullSynonym + ". ");
		EndIf;
		PredefinedItemName = StrReplace(FullName, ".", "");
		If PredefinedItemsNames.Get(PredefinedItemName) <> Undefined Then
			NewRow.PredefinedDataName = PredefinedItemName;
			PredefinedItemsNames.Insert(PredefinedItemName, True);
		EndIf;
	EndDo;
	
EndProcedure

Function MetadataObjectPresentation(Val MetadataObject, Val CollectionProperties)
	
	Postfix = "(" + CollectionProperties.SingularSynonym + ")";
	
	Synonym = ?(ValueIsFilled(MetadataObject.Synonym), MetadataObject.Synonym, MetadataObject.Name);
	
	SynonymMaxLength = 150 - StrLen(Postfix);
	If StrLen(Synonym) > SynonymMaxLength + 1 Then
		Return Left(Synonym, SynonymMaxLength - 2) + "..." + Postfix;
	EndIf;
	
	Return Synonym + " (" + CollectionProperties.SingularSynonym + ")";
	
EndFunction

Function InsertQuestionMark(Val String)
	
	If Not StrStartsWith(String, "?") Then
		If Not StrStartsWith(String, " ") Then
			String = "? " + String;
		Else
			String = "?" + String;
		EndIf;
	EndIf;
	
	Return String;
	
EndFunction

Function UniqueFullName(Properties)
	
	FullName = InsertQuestionMark(Properties.FullName);
	
	If StrFind(FullName, "(") = 0 Then
		FullName = FullName + " (" + String(Properties.Ref.UUID())+ ")";
	EndIf;
	
	Return FullName;
	
EndFunction

Function MetadataFindByFullName(FullName)
	
	If StrStartsWith(FullName, "?") Then
		Return Undefined;
	EndIf;
	
	Return Common.MetadataObjectByFullName(FullName);
	
EndFunction

Function FullNameUsed(Object, ExtensionObjects)
	
	Query = New Query;
	Query.SetParameter("FullName", Object.FullName);
	Query.SetParameter("Ref",    Object.Ref);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref <> &Ref
	|	AND MetadataObjectIDs.FullName = &FullName";
	ClarifyCatalogNameInQueryText(Query.Text, ExtensionObjects);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function IsCollection(Ref, ExtensionsObjects = False)
	
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	Return CollectionsProperties.Find(Ref.UUID(), "Id") <> Undefined;
	
EndFunction

Procedure PrepareNewSubsystemsListInMasterNode(Upload0)
	
	FoundDetails = Upload0.Find(Metadata.Subsystems.StandardSubsystems, "MetadataObject");
	If FoundDetails = Undefined Then
		Return;
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("IsNew", True);
	FoundADescriptionOf = Upload0.FindRows(Filter);
	
	InheritingSubsystems = New Array;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternal = Common.CommonModule("FilesOperationsInternal");
		ModuleFilesOperationsInternal.OnDefineSubsystemsInheritance(Upload0, InheritingSubsystems);
	EndIf;
	
	SearchString = Metadata.Subsystems.StandardSubsystems.FullName() + ".";
	NewSubsystems = New Array;
	AllNewSubsystems = New Array;
	For Each LongDesc In FoundADescriptionOf Do
		If InheritingSubsystems.Find(LongDesc) <> Undefined Then
			Continue;
		EndIf;
		If StrStartsWith(LongDesc.FullName, SearchString) Then
			NewSubsystems.Add(LongDesc.FullName);
		EndIf;
		
		If StrStartsWith(LongDesc.FullName, "Subsystem.") Then
			AllNewSubsystems.Add(LongDesc.FullName);
		EndIf;
	EndDo;
	
	UpdateNewSubsystemsList(NewSubsystems, AllNewSubsystems);
	
EndProcedure

Procedure PrepareNewSubsystemsListInSubordinateNode(ObjectsToWrite)
	
	NewSubsystems = New Array;
	AllNewSubsystems = New Array;
	NameBeginning = "Subsystem.StandardSubsystems.";
	KeyAllSubsystems = "Subsystem.";
	
	For Each Object In ObjectsToWrite Do
		If Not Object.IsNew()
			Or Object.AdditionalProperties.Property("IsDuplicateReplacement") Then
			Continue;
		EndIf;
		
		If Upper(Left(Object.FullName, StrLen(NameBeginning))) = Upper(NameBeginning) Then
			NewSubsystems.Add(Object.FullName);
		EndIf;
		
		If Upper(Left(Object.FullName, StrLen(KeyAllSubsystems))) = Upper(KeyAllSubsystems) Then
			AllNewSubsystems.Add(Object.FullName);
		EndIf;
	EndDo;
	
	UpdateNewSubsystemsList(NewSubsystems, AllNewSubsystems);
	
EndProcedure

Procedure UpdateNewSubsystemsList(NewSubsystems, AllNewSubsystems)
	
	InformationRecords = InfobaseUpdateInternal.InfobaseUpdateInfo();
	HasChanges = False;
	
	For Each SubsystemName In NewSubsystems Do
		If InformationRecords.NewSubsystems.Find(SubsystemName) = Undefined Then
			InformationRecords.NewSubsystems.Add(SubsystemName);
			HasChanges = True;
		EndIf;
	EndDo;
	
	// Removing the subsystem from the list of subsystems deleted from metadata.
	IndexOf = InformationRecords.NewSubsystems.Count() - 1;
	While IndexOf >= 0 Do
		SubsystemName = InformationRecords.NewSubsystems.Get(IndexOf);
		If Common.MetadataObjectByFullName(SubsystemName) = Undefined Then
			InformationRecords.NewSubsystems.Delete(IndexOf);
			HasChanges = True;
		EndIf;
		IndexOf = IndexOf - 1;
	EndDo;
	
	If AllNewSubsystems <> Undefined Then
		
		For Each SubsystemName In AllNewSubsystems Do
			If InformationRecords.AllNewSubsystems.Find(SubsystemName) = Undefined Then
				InformationRecords.AllNewSubsystems.Add(SubsystemName);
				HasChanges = True;
			EndIf;
		EndDo
		
	EndIf;
	
	If Not HasChanges Then
		Return;
	EndIf;
	
	InfobaseUpdateInternal.WriteInfobaseUpdateInfo(InformationRecords);
	
EndProcedure

Function CollectionID(UUID, ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.GetRef(UUID);
	Else
		Return GetRef(UUID);
	EndIf;
	
EndFunction

Function IsExtensionsObject(ObjectOrRef)
	
	Return TypeOf(ObjectOrRef) = Type("CatalogObject.ExtensionObjectIDs")
		Or TypeOf(ObjectOrRef) = Type("CatalogRef.ExtensionObjectIDs");
	
EndFunction

Function CreateCatalogItem(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.CreateItem();
	Else
		Return CreateItem();
	EndIf;
	
EndFunction

Function EmptyCatalogRef(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.EmptyRef();
	Else
		Return EmptyRef();
	EndIf;
	
EndFunction

Function NewCatalogRef(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return Catalogs.ExtensionObjectIDs.GetRef();
	Else
		Return GetRef();
	EndIf;
	
EndFunction

Function CatalogName(ExtensionsObjects)
	
	If ExtensionsObjects Then
		Return "Catalog.ExtensionObjectIDs";
	Else
		Return "Catalog.MetadataObjectIDs";
	EndIf;
	
EndFunction

Function CatalogDescription(ExtensionsObjects)
	
	If ExtensionsObjects Then
		CatalogDescription = NStr("en = 'Extension object IDs';");
	Else
		CatalogDescription = NStr("en = 'Metadata object IDs';");
	EndIf;
	
	Return CatalogDescription;
	
EndFunction

Procedure ClarifyCatalogNameInQueryText(QueryText, ExtensionsObjects)
	
	If ExtensionsObjects Then
		QueryText = StrReplace(QueryText, "Catalog.MetadataObjectIDs",
			CatalogName(ExtensionsObjects));
	EndIf;
	
EndProcedure

Procedure RaiseByError(ExtensionsObjects, ErrorText)
	
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '""%1"" catalog error.';"),
		CatalogDescription(ExtensionsObjects));
	
	ErrorText = ErrorTitle + Chars.LF + Chars.LF + ErrorText;
	Raise ErrorText;
	
EndProcedure

Function IsSubsystem(MetadataObject, SubsystemsCollection = Undefined)
	
	If SubsystemsCollection = Undefined Then
		SubsystemsCollection = Metadata.Subsystems;
	EndIf;
	
	If SubsystemsCollection.Contains(MetadataObject) Then
		Return True;
	EndIf;
	
	For Each Subsystem In SubsystemsCollection Do
		If IsSubsystem(MetadataObject, Subsystem.Subsystems) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// For the AddRenaming procedure.
Function CollectionName(FullName)
	
	PointPosition = StrFind(FullName, ".");
	
	If PointPosition > 0 Then
		Return Left(FullName, PointPosition - 1);
	EndIf;
	
	Return "";
	
EndFunction

// This method is required by UpdateData and BeforeWriteObject procedures.
Procedure CheckObjectBeforeWrite(Object, AutoUpdate = False)
	
	ExtensionsObjects = IsExtensionsObject(Object);
	
	If Not AutoUpdate Then
		
		If Object.IsNew() Then
			
			RaiseByError(ExtensionsObjects,
				NStr("en = 'A new object ID can be created only automatically
				           |when updating catalog data.';"));
				
		ElsIf CannotChangeFullName(Object) Then
			
			RaiseByError(ExtensionsObjects, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot set the full name ""%1""
				           |specified when changing the object ID.
				           |It can be set only automatically when updating catalog data.';"),
				Object.FullName));
		Else
			If FullNameUsed(Object, False) Then
				CatalogDescription = CatalogDescription(False);
				
			ElsIf ExtensionsObjects And FullNameUsed(Object, True) Then
				CatalogDescription = CatalogDescription(True);
			Else
				CatalogDescription = "";
			EndIf;
			If ValueIsFilled(CatalogDescription) Then
				RaiseByError(ExtensionsObjects, StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot set the full name ""%1""
					           |specified when changing the object ID.
					           |It is already in use in the ""%2"" catalog.';"),
					Object.FullName, CatalogDescription));
			EndIf;
		EndIf;
		
		UpdateIDProperties(Object);
	EndIf;
	
	If Not ExtensionsObjects And Common.IsSubordinateDIBNode() Then
		
		If Object.IsNew()
		   And Not IsCollection(Object.GetNewObjectRef(), IsExtensionsObject(Object)) Then
			
			RaiseByError(ExtensionsObjects,
				NStr("en = 'Adding items is only allowed
				           |in the main node of the distributed infobase.';"));
		EndIf;
		
		If Not Object.DeletionMark
		   And Not IsCollection(Object.Ref, IsExtensionsObject(Object)) Then
			
			If Upper(Object.FullName) <> Upper(Common.ObjectAttributeValue(Object.Ref, "FullName")) Then
				RaiseByError(ExtensionsObjects,
					NStr("en = 'The ""Full name"" attribute can be changed
					           |only in the main node of the distributed infobase.';"));
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// This method is required by CheckForUsage and DataUpdated procedures.
Function ExtensionObjectsIDsUnvailableInSharedModeErrorDescription()
	
	Return
		NStr("en = 'Cannot use the ""Extension object IDs"" catalog
		           |in shared mode.';");
	
EndFunction

// This method is required by OnCreateListFormAtServer procedure.
Procedure SetListOrderAndAppearance(Form)
	
	// Order.
	Order = Form.List.SettingsComposer.Settings.Order;
	Order.UserSettingID = "DefaultOrder";
	
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("DeletionMark");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("CollectionOrder");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Parent");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("FutureDeletionMark");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.Field = New DataCompositionField("Synonym");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Use = True;
	
	// Appearance.
	AppearanceItem = Form.List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	ColorItem = AppearanceItem.Appearance.Items.Find("TextColor");
	ColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	ColorItem.Use = True;
	
	FilterGroupItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroupItem.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	FilterElement = FilterGroupItem.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField("DeletionMark");
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	FilterElement.Use  = True;
	
	FilterElement = FilterGroupItem.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue  = New DataCompositionField("FutureDeletionMark");
	FilterElement.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;
	FilterElement.Use  = True;
	
EndProcedure

// This method is required by UpdateData procedure.
Function ExtensionNames(ExtensionSource, ExtensionKeyIds)
	
	ExtensionNames = New Map;
	Extensions = ConfigurationExtensions.Get(, ExtensionSource); // Array of ConfigurationExtension
	
	For Each Extension In Extensions Do
		ExtensionID = Lower(Extension.UUID);
		ExtensionNames.Insert(Lower(Extension.Name), Extension.Name);
		ExtensionNames.Insert(ExtensionID, Extension.Name);
		ExtensionKey = Lower(Extension.Name) + " " + Base64String(Extension.HashSum);
		NewExtensionId = ExtensionKeyIds.Get(ExtensionKey);
		If NewExtensionId <> Undefined
		   And NewExtensionId <> ExtensionID Then
			ExtensionNames.Insert(Lower(NewExtensionId), Extension.Name);
		EndIf;
	EndDo;
	
	Return ExtensionNames;
	
EndFunction

// This method is required by UpdateData procedure.
Procedure AddNamesOfUnconnectedExtensionsInSessionWithoutDelimiters(ExtensionProperties, DatabaseExtensions)
	
	If Not StandardSubsystemsServer.ThisIsSplitSessionModeWithNoDelimiters() Then
		Return;
	EndIf;
	
	AttachedExtensionsNames   = ExtensionProperties.AttachedExtensionsNames;
	UnattachedExtensionsNames = ExtensionProperties.UnattachedExtensionsNames;
	
	For Each Extension In DatabaseExtensions Do
		ExtensionID = Lower(Extension.UUID);
		NameOfSearchExtension = Lower(Extension.Name);
		If AttachedExtensionsNames.Get(ExtensionID) <> Undefined
		 Or AttachedExtensionsNames.Get(NameOfSearchExtension) <> Undefined
		 Or UnattachedExtensionsNames.Get(ExtensionID) <> Undefined
		 Or UnattachedExtensionsNames.Get(NameOfSearchExtension) <> Undefined Then
			Continue;
		EndIf;
		UnattachedExtensionsNames.Insert(NameOfSearchExtension, Extension.Name);
		UnattachedExtensionsNames.Insert(Lower(ExtensionID), Extension.Name);
	EndDo;
	
EndProcedure

// This method is required by MetadataObjectIDByFullName and MetadataObjectIDs functions.
Function MetadataObjectIDsWithRetryAttempt(FullMetadataObjectsNames, RaiseException1, OneItem)
	
	StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True,
		Common.SeparatedDataUsageAvailable());
	
	Try
		IDs = MetadataObjectIDsWithoutRetryAttempt(
			FullMetadataObjectsNames, True, OneItem, Not RaiseException1);
	Except
		IDs = Undefined;
	EndTry;
	
	If IDs = Undefined Then
		UpdateIsCompleted = UpdateIDCatalogs();
		
		If Not Common.DataSeparationEnabled()
		 Or Not Common.SeparatedDataUsageAvailable() Then
			
			If Not UpdateIsCompleted.MetadataObjectIDs Then
				UpdateCatalogData();
			EndIf;
		EndIf;
		
		If Common.SeparatedDataUsageAvailable() Then
			If Not UpdateIsCompleted.ExtensionObjectIDs Then
				Catalogs.ExtensionObjectIDs.UpdateCatalogData();
			EndIf;
		EndIf;
		
		IDs = MetadataObjectIDsWithoutRetryAttempt(
			FullMetadataObjectsNames, RaiseException1, OneItem, Not RaiseException1);
	EndIf;
	
	Return IDs;
	
EndFunction

// This method is required by MetadataObjectIDs function.
Function MetadataObjectIDsWithoutRetryAttempt(FullMetadataObjectsNames,
			RaiseException1, OneItem, SkipUnsupportedObjects)
	
	SetPrivilegedMode(True);
	
	ExtensionObjectIDsAvailable =
		ValueIsFilled(SessionParameters.AttachedExtensions)
		And Common.SeparatedDataUsageAvailable();
	
	Query = New Query;
	Query.SetParameter("FullNames", FullMetadataObjectsNames);
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey AS MetadataObjectKey,
	|	IDs.FullName AS FullName,
	|	IDs.Description AS Presentation,
	|	IDs.FullName AS FullCollectionName,
	|	IDs.DeletionMark AS DeletionMark,
	|	"""" AS ExtensionName,
	|	"""" AS ExtensionID,
	|	"""" AS ExtensionHashsum
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.FullName IN(&FullNames)
	|	AND NOT IDs.DeletionMark";
	
	If ExtensionObjectIDsAvailable Then
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
		QueryText =
		"SELECT
		|	IDsVersions.Id AS Ref,
		|	IDs.MetadataObjectKey AS MetadataObjectKey,
		|	IDsVersions.FullObjectName AS FullName,
		|	IDs.Description AS Presentation,
		|	IDs.FullName AS FullCollectionName,
		|	IDs.DeletionMark AS DeletionMark,
		|	IDs.ExtensionName AS ExtensionName,
		|	IDs.ExtensionID AS ExtensionID,
		|	IDs.ExtensionHashsum AS ExtensionHashsum
		|FROM
		|	InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
		|		INNER JOIN Catalog.ExtensionObjectIDs AS IDs
		|		ON (IDs.Ref = IDsVersions.Id)
		|			AND (IDsVersions.ExtensionsVersion = &ExtensionsVersion)
		|WHERE
		|	IDsVersions.FullObjectName IN(&FullNames)";
		
		Query.Text = Query.Text + "
		|
		|UNION ALL
		|
		|" + QueryText;
	EndIf;
	
	Upload0 = Query.Execute().Unload();
	Upload0.Indexes.Add("FullName");
	
	Errors = New Array;
	AddApplicationDeveloperParametersErrorClarification = False;
	
	DataBaseConfigurationChangedDynamically = DataBaseConfigurationChangedDynamically();
	IDsFromKeys = Undefined;
	
	Result = New Map;
	For Each FullMetadataObjectName In FullMetadataObjectsNames Do
		
		Filter = New Structure("FullName", FullMetadataObjectName);
		FoundRows = Upload0.FindRows(Filter);
		If FoundRows.Count() = 0 Then
			// One of the reasons why the ID is not found by the full name is that the full name is specified with an error.
			MetadataObject = Common.MetadataObjectByFullName(FullMetadataObjectName);
			If MetadataObject = Undefined Then
				If Not RaiseException1 Then
					Continue;
				EndIf;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The metadata object with the ""%1"" name does not exist.';"),
					FullMetadataObjectName);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			If Not Metadata.Roles.Contains(MetadataObject)
			   And Not Metadata.ExchangePlans.Contains(MetadataObject)
			   And Not Metadata.Constants.Contains(MetadataObject)
			   And Not Metadata.Catalogs.Contains(MetadataObject)
			   And Not Metadata.Documents.Contains(MetadataObject)
			   And Not Metadata.DocumentJournals.Contains(MetadataObject)
			   And Not Metadata.Reports.Contains(MetadataObject)
			   And Not Metadata.DataProcessors.Contains(MetadataObject)
			   And Not Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject)
			   And Not Metadata.ChartsOfAccounts.Contains(MetadataObject)
			   And Not Metadata.ChartsOfCalculationTypes.Contains(MetadataObject)
			   And Not Metadata.InformationRegisters.Contains(MetadataObject)
			   And Not Metadata.AccumulationRegisters.Contains(MetadataObject)
			   And Not Metadata.AccountingRegisters.Contains(MetadataObject)
			   And Not Metadata.CalculationRegisters.Contains(MetadataObject)
			   And Not Metadata.BusinessProcesses.Contains(MetadataObject)
			   And Not Metadata.Tasks.Contains(MetadataObject)
			   And Not IsSubsystem(MetadataObject) Then
				
				If SkipUnsupportedObjects Then
					Continue;
				EndIf;
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The metadata object is not supported:
					           |""%1"".
					           |
					           |Only the metadata object types listed in the comments to the function are allowed.';"),
					FullMetadataObjectName);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			Extension = MetadataObject.ConfigurationExtension();
			If Extension <> Undefined
			   And Not Common.SeparatedDataUsageAvailable() Then
			
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Extension metadata object IDs are not supported in shared mode.
					           |Cannot return the ID of metadata object ""%1""
					           |in extension ""%2"" version %3.';"),
					FullMetadataObjectName, Extension.Name, Extension.Version);
				Errors.Add(ErrorDescription);
				Continue;
			EndIf;
			
			If DataBaseConfigurationChangedDynamically Then
				If IDsFromKeys = Undefined Then
					// @skip-check query-in-loop - Called no more than once
					IDsFromKeys = IDsFromKeys();
				EndIf;
				Id = IDsFromKeys.Get(FullMetadataObjectName);
				If Id = Undefined Then
					StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
				EndIf;
				Result.Insert(FullMetadataObjectName, Id);
				Continue;
			EndIf;
			
			ErrorTemplate = ?(Extension <> Undefined,
				NStr("en = 'For metadata object ""%1"",
				           |no ID is found in the ""Extension version object IDs"" information register.';"),
				NStr("en = 'For metadata object ""%1""
				           |, no ID is found in the ""Metadata object IDs"" catalog.';"));
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, FullMetadataObjectName);
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
			
		ElsIf FoundRows.Count() > 1 Then
			
			ErrorTemplate = ?(ExtensionObjectIDsAvailable,
				NStr("en = 'For metadata object ""%1"",
				           |multiple IDs are found in the ""Metadata object IDs"" catalog
				           |and the ""Extension version object IDs"" information register.';"),
				NStr("en = 'For metadata object ""%1"",
				           |multiple IDs are found in the ""Metadata object IDs"" catalog.';"));
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(ErrorTemplate, FullMetadataObjectName);
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
			
		EndIf;
		
		// Checking whether the metadata object key matches the metadata object full name.
		TableRow = FoundRows[0];
		CheckResult = MetadataObjectKeyMatchesFullName(TableRow);
		If CheckResult.NotRespond Then
			CatalogDescription = CatalogDescription(IsExtensionsObject(TableRow.Ref));
			
			If CheckResult.MetadataObject = Undefined Then
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For metadata object ""%1"",
					           |an ID matching a deleted metadata object 
					           |is found in the ""%2"" catalog.';"),
					FullMetadataObjectName, CatalogDescription);
			Else
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For metadata object ""%1"",
					           |an ID matching another metadata object ""%3""
					           |is found in the ""%2"" catalog.';"),
					FullMetadataObjectName, CatalogDescription, CheckResult.MetadataObject);
			EndIf;
			
			AddApplicationDeveloperParametersErrorClarification = True;
			Errors.Add(ErrorDescription);
			Continue;
		EndIf;
		
		Result.Insert(FullMetadataObjectName, TableRow.Ref);
	EndDo;
	
	ErrorsCount = Errors.Count();
	If ErrorsCount > 0 Then
		
		If OneItem Then
			ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error executing function ""%1"".';"),
				"Common.MetadataObjectID");
			
		ElsIf ErrorsCount = 1 Then
			ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Error executing function ""%1"".';"),
				"Common.MetadataObjectIDs");
		Else
			ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Errors when executing function %1.';"),
				"Common.MetadataObjectIDs");
		EndIf;
		
		Separator = Chars.LF + Chars.LF;
		AllErrorsText = "";
		ErrorNumber = 0;
		For Each ErrorDescription In Errors Do
			ErrorNumber = ErrorNumber + 1;
			AllErrorsText = AllErrorsText + ?(ErrorNumber = 1, "", Separator) + ErrorDescription;
			If ErrorNumber = 3 And ErrorsCount > 5 Then
				
				ErrorDescription = "... " + StringFunctionsClientServer.StringWithNumberForAnyLanguage(
					NStr("en = ';and %1 more error;;;;and %1 more errors';"),
					(ErrorsCount - ErrorNumber));
				
				AllErrorsText = AllErrorsText + Separator + ErrorDescription;
				Break;
			EndIf;
		EndDo;
		
		AllErrorsText = AllErrorsText + ?(AddApplicationDeveloperParametersErrorClarification,
			StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper(), "");
		
		ErrorText = ErrorTitle + Separator + AllErrorsText;
		Raise ErrorText;
	EndIf;
	
	Return Result;
	
EndFunction

// This method is required by MetadataObjectIDsWithoutRetryAttempt function.
Function IDsFromKeys()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref AS Ref,
	|	IDs.MetadataObjectKey AS KeyStorage
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs";
	
	Selection = Query.Execute().Select();
	
	IDsFromKeys = New Map;
	
	While Selection.Next() Do
		If TypeOf(Selection.KeyStorage) <> Type("ValueStorage") Then
			Continue;
		EndIf;
		MetadataObjectKey = Selection.KeyStorage.Get();
		
		If MetadataObjectKey = Undefined
		 Or MetadataObjectKey = Type("Undefined") Then
			Continue;
		EndIf;
		
		MetadataObject = MetadataObjectByKey(MetadataObjectKey, "", "", "");
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		
		FullName = MetadataObject.FullName();
		If IDsFromKeys.Get(FullName) <> Undefined Then
			StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
		EndIf;
		
		IDsFromKeys.Insert(FullName, Selection.Ref);
	EndDo;
	
	Return IDsFromKeys;
	
EndFunction

// Intended for the functions MetadataObjectIDsWithRetryAttempt,
// MetadataObjectsByIDsWithRetryAttempt.
//
Function UpdateIDCatalogs()
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	Result = SessionParameters.UpdateIDCatalogs;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	Return Result;
	
EndFunction

// This method is required by MetadataObjectByID and MetadataObjectsByIDs functions.
Function MetadataObjectsByIDsWithRetryAttempt(IDs, RaiseException1)
	
	If IDs.Count() = 0 Then
		Return New Map;
	EndIf;
	
	ConfigurationIDs = New Array;
	ExtensionsIDs   = New Array;
	
	AddedConfigurationIDs = New Map;
	AddedExtensionsIDs   = New Map;
	
	ProcessedItems = New Map;
	
	For Each CurrentID In IDs Do
		If TypeOf(CurrentID) = Type("CatalogRef.MetadataObjectIDs")
		   And ValueIsFilled(CurrentID) Then
			
			If AddedConfigurationIDs[CurrentID] = Undefined Then
				ConfigurationIDs.Add(CurrentID);
				AddedConfigurationIDs.Insert(CurrentID, True);
			EndIf;
		
		ElsIf TypeOf(CurrentID) = Type("CatalogRef.ExtensionObjectIDs")
		   And ValueIsFilled(CurrentID) Then
			
			If AddedExtensionsIDs[CurrentID] = Undefined Then
				ExtensionsIDs.Add(CurrentID);
				AddedExtensionsIDs.Insert(CurrentID, True);
			EndIf;
		ElsIf RaiseException1 Then
			If TypeOf(CurrentID) = Type("CatalogRef.MetadataObjectIDs")
			 Or TypeOf(CurrentID) = Type("CatalogRef.ExtensionObjectIDs") Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error executing function ""%1"".
					           |
					           |Invalid ID: Empty reference of type ""%2"".';"),
					"Common.MetadataObjectByID",
					TypeOf(CurrentID));
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Error executing function ""%1"".
					           |
					           |Invalid metadata ID type:
					           |""%2"".';"),
					"Common.MetadataObjectByID",
					TypeOf(CurrentID));
			EndIf;
			Raise ErrorText;
		Else
			ProcessedItems.Insert(CurrentID, Null);
		EndIf;
	EndDo;
	
	If ConfigurationIDs.Count() > 0 Then
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, False);
	EndIf;
	
	If ExtensionsIDs.Count() > 0 Then
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, True);
	EndIf;
	
	If ConfigurationIDs.Count() > 0 Or ExtensionsIDs.Count() > 0 Then
		Try
			MetadataObjects = MetadataObjectsByIDsWithoutRetryAttempt(IDs,
				ConfigurationIDs, ExtensionsIDs, RaiseException1);
		Except
			If Not Common.DataSeparationEnabled()
			 Or Not Common.SeparatedDataUsageAvailable() Then
				// If an error occurs, update the catalog (if possible),
				// and retry to receive the ID.
				MetadataObjects = Undefined;
			Else
				Raise;
			EndIf;
		EndTry;
	Else
		MetadataObjects = New Map;
	EndIf;
	
	If MetadataObjects = Undefined Then
		UpdateIsCompleted = UpdateIDCatalogs();
		If Not UpdateIsCompleted.MetadataObjectIDs Then
			UpdateCatalogData();
		EndIf;
		MetadataObjects = MetadataObjectsByIDsWithoutRetryAttempt(IDs,
			ConfigurationIDs, ExtensionsIDs, RaiseException1);
	EndIf;
	
	For Each KeyAndValue In ProcessedItems Do
		MetadataObjects.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	Return MetadataObjects;
	
EndFunction

// This method is required by MetadataObjectsByIDsWithRetryAttempt function.
Function MetadataObjectsByIDsWithoutRetryAttempt(IDs,
			ConfigurationIDs, ExtensionsIDs, RaiseException1)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	If ConfigurationIDs.Count() > 0 Then
		Query.SetParameter("ConfigurationIDs", ConfigurationIDs);
		Query.Text =
		"SELECT
		|	IDs.Ref AS Ref,
		|	IDs.MetadataObjectKey AS MetadataObjectKey,
		|	IDs.FullName AS FullName,
		|	IDs.Description AS Presentation,
		|	IDs.FullName AS FullCollectionName,
		|	IDs.DeletionMark AS DeletionMark,
		|	FALSE AS ExtensionObject,
		|	"""" AS ExtensionName,
		|	"""" AS ExtensionID,
		|	"""" AS ExtensionHashsum
		|FROM
		|	Catalog.MetadataObjectIDs AS IDs
		|WHERE
		|	IDs.Ref IN(&ConfigurationIDs)";
	EndIf;
	
	If ExtensionsIDs.Count() > 0 Then
		Query.SetParameter("ExtensionsIDs", ExtensionsIDs);
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
		If ValueIsFilled(Query.Text) Then
			Query.Text = Query.Text +
			"
			|
			|UNION ALL
			|
			|";
		EndIf;
		Query.Text = Query.Text +
		"SELECT
		|	IDs.Ref AS Ref,
		|	IDs.MetadataObjectKey AS MetadataObjectKey,
		|	ISNULL(IDsVersions.FullObjectName, """") AS FullName,
		|	IDs.Description AS Presentation,
		|	IDs.FullName AS FullCollectionName,
		|	IDs.DeletionMark AS DeletionMark,
		|	TRUE AS ExtensionObject,
		|	IDs.ExtensionName AS ExtensionName,
		|	IDs.ExtensionID AS ExtensionID,
		|	IDs.ExtensionHashsum AS ExtensionHashsum
		|FROM
		|	Catalog.ExtensionObjectIDs AS IDs
		|		LEFT JOIN InformationRegister.ExtensionVersionObjectIDs AS IDsVersions
		|		ON (IDsVersions.Id = IDs.Ref)
		|			AND (IDsVersions.ExtensionsVersion = &ExtensionsVersion)
		|WHERE
		|	IDs.Ref IN(&ExtensionsIDs)";
	EndIf;
	
	Upload0 = Query.Execute().Unload();
	ErrorTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Error executing function ""%1""';"),
		"Common.MetadataObjectByID");
	
	IDsMetadataObjects = New Map;
	
	TotalIDs = ConfigurationIDs.Count() + ExtensionsIDs.Count();
	If Upload0.Count() < TotalIDs Then
		For Each Id In IDs Do
			If Upload0.Find(Id, "Ref") = Undefined Then
				If RaiseException1 Then
					Break;
				Else
					// The metadata object does not exist.
					IDsMetadataObjects.Insert(Id, Null);
					Continue;
				EndIf;
			EndIf;
		EndDo;
		If RaiseException1 Then
			If ExtensionsIDs.Find(Id) = Undefined Then
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The object ""%1"" was deleted from this app version.
					           |The related data and settings are no longer available.';"),
					String(Id));
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The object ""%1"" is deleted since either
					           |its extension was removed or the object was deleted from the extensions version.
					           |The related data and settings are no longer available.';"),
					String(Id));
			EndIf;
			Raise ErrorText;
		EndIf;
	EndIf;
	
	DataBaseConfigurationChangedDynamically = DataBaseConfigurationChangedDynamically();
	
	// Checking whether the metadata object key matches the metadata object full name.
	For Each Properties In Upload0 Do
		CheckResult = MetadataObjectKeyMatchesFullName(Properties);
		If CheckResult.NotRespond Then
			
			If CheckResult.MetadataObject = Undefined Then
				If ValueIsFilled(CheckResult.ViewOfTheRemote) Then
					IDPresentation = CheckResult.ViewOfTheRemote;
				Else
					IDPresentation = Properties.Presentation;
				EndIf;
				
				If Properties.ExtensionObject Then
					TheExtensionObjectDoesNotExist = Properties.DeletionMark;
					ExtensionName = "";
					ExtensionID = ?(StrStartsWith(Properties.ExtensionID, "? "),
						Mid(Properties.ExtensionID, 3), Properties.ExtensionID);
					If StringFunctionsClientServer.IsUUID(ExtensionID) Then
						Filter = New Structure("UUID", New UUID(ExtensionID));
						InstalledExtensions = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.Database);
						DetachedExtensions   = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.SessionDisabled);
						ActiveExtensions      = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.SessionApplied);
						If ActiveExtensions.Count() > 0 
							Or DetachedExtensions.Count() > 0 
							Or InstalledExtensions.Count() > 0 Then
							ExtensionName = InstalledExtensions[0].Name;
						EndIf;
					EndIf;
					If Not ValueIsFilled(ExtensionName) Then
						ExtensionName = ?(StrStartsWith(Properties.ExtensionName, "? "),
							Mid(Properties.ExtensionName, 3), Properties.ExtensionName);
						Filter = New Structure("Name", ExtensionName);
						InstalledExtensions = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.Database);
						DetachedExtensions   = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.SessionDisabled);
						ActiveExtensions      = ConfigurationExtensions.Get(Filter, ConfigurationExtensionsSource.SessionApplied);
					EndIf;
					If InstalledExtensions.Count() = 0 Then
						TheExtensionObjectDoesNotExist = True;
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The object ""%2"" does not exist since its extension ""%1"" was uninstalled.
							           |The related data and settings are no longer available.';"),
							ExtensionName,
							IDPresentation);
						
					ElsIf Not InstalledExtensions[0].Active Then
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The extension ""%1"" is installed but disabled.
							           |Enable the extensions and restart the app.';"),
							ExtensionName);
						
					ElsIf DetachedExtensions.Count() > 0 And Not DetachedExtensions[0].Active
					      Or DetachedExtensions.Count() = 0 And ActiveExtensions.Count() = 0 Then
						
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The extension ""%1"" is installed but the app requires a restart.%1Restart the app.';"),
							ExtensionName);
						
					ElsIf DetachedExtensions.Count() > 0 And DetachedExtensions[0].Active Then
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'The extension ""%1"" is installed but it was disabled at the startup.
							           |This means that an unexpected exception occurred.';"),
							ExtensionName);
						
					Else // ActiveExtensions.Count() > 0
						TheExtensionObjectDoesNotExist = True;
						
						If CheckResult.RemoteMetadataObject <> Undefined
						   And CheckResult.RemoteMetadataObject.ConfigurationExtension() <> Undefined
						   And CheckResult.RemoteMetadataObject.ConfigurationExtension().Name = ActiveExtensions[0].Name Then
							
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'The id of the ""%2"" metadata object, which is a part of the ""%1"" extension, is marked for deletion.
								           |Usually, this happens when an extension is uninstalled and then reinstalled (instead of being updated).
								           |The related data and settings are no longer available.';"),
								ExtensionName,
								IDPresentation);
						Else
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'The object ""%2"" was deleted in the current version of the extension ""%1"".
								           |The related data and settings are no longer available.';"),
								ExtensionName,
								IDPresentation);
						EndIf;
					EndIf;
					
					If RaiseException1 Then
						Raise ErrorText;
						
					ElsIf TheExtensionObjectDoesNotExist Then
						IDsMetadataObjects.Insert(Properties.Ref, Null);
					Else
						IDsMetadataObjects.Insert(Properties.Ref, Undefined);
						Continue;
					EndIf;
					
				ElsIf DataBaseConfigurationChangedDynamically Then
					// The metadata object might be available after restart.
					If RaiseException1 Then
						// Standard exception caused by dynamic update.
						StandardSubsystemsServer.RequireRestartDueToApplicationVersionDynamicUpdate();
					Else
						IDsMetadataObjects.Insert(Properties.Ref, Undefined);
						Continue;
					EndIf;
					
				ElsIf Not RaiseException1 Then
					// The metadata object does not exist.
					IDsMetadataObjects.Insert(Properties.Ref, Null);
					Continue;
					
				ElsIf CheckResult.RemoteMetadataObject <> Undefined
				        And CheckResult.RemoteMetadataObject.ConfigurationExtension() = Undefined Then
					
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The id of the ""%2"" metadata object is marked for deletion.
						           |Usually, this happens when an object is deleted and then re-added.
						           |The related data and settings are no longer available.';"),
						IDPresentation);
					Raise ErrorText;
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The object ""%1"" does not exist as it was removed from the current app version.
						           |The related data and settings are no longer available.';"),
						IDPresentation);
					Raise ErrorText;
				EndIf;
				
			ElsIf DataBaseConfigurationChangedDynamically Then
				// The metadata object might have been renamed.
				ErrorDescription = "";
			Else
				ErrorDescription =  StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The id ""%1"" from the catalog ""%2""
					           |corresponds with the metadata object ""%3"", whose full name
					           |does not match the full name in the id.';"),
					Properties.Presentation,
					CatalogDescription(Properties.ExtensionObject),
					CheckResult.MetadataObject.FullName())
					+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
			EndIf;
			
			If ValueIsFilled(ErrorDescription) Then
				ErrorText = ErrorTitle + Chars.LF + Chars.LF + ErrorDescription;
				Raise ErrorText;
			EndIf;
		EndIf;
		
		If Not Properties.ExtensionObject And Properties.DeletionMark And Not DataBaseConfigurationChangedDynamically Then
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The id ""%1"" from the catalog ""%2"" is marked for deletion.';"),
				Properties.Presentation,
				CatalogDescription(Properties.ExtensionObject));
			
			ErrorText = ErrorTitle + Chars.LF + Chars.LF + ErrorDescription
				+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper();
			Raise ErrorText;
		EndIf;
		
		MetadataObjectDetails = New Structure("Object, Key, FullName", CheckResult.MetadataObject);
		If CheckResult.MetadataObjectKey <> Undefined Then
			MetadataObjectDetails.Key = CheckResult.MetadataObjectKey;
		Else
			MetadataObjectDetails.Key      = Properties.FullName;
			MetadataObjectDetails.FullName = Properties.FullName;
		EndIf;
		IDsMetadataObjects.Insert(Properties.Ref, MetadataObjectDetails);
	EndDo;
	
	Return IDsMetadataObjects;
	
EndFunction

// This method is required by MetadataObjectsByIDs and MetadataObjectIDs functions.
Function IDCache()
	
	CachedDataKey = String(SessionParameters.CachedDataKey);
	
	Return StandardSubsystemsCached.MetadataObjectIDCache(CachedDataKey);
	
EndFunction

// Intended to be called from  StandardSubsystemsCached.MetadataObjectIDCache.
// 
// Parameters:
//  CachedDataKey - UUID
//
// Returns:
//  Structure:
//   * IDsByFullNames - Map
//   * DetailsOfMetadataObjectsByIDs - Map
//
Function MetadataObjectIDCache(CachedDataKey) Export
	
	Store = New Structure;
	Store.Insert("IDsByFullNames", New Map);
	Store.Insert("DetailsOfMetadataObjectsByIDs", New Map);
	
	Return New FixedStructure(Store);
	
EndFunction

// To be called from StandardSubsystemsCached.MetadataObjectIDPresentation.
// Used from the PresentationGetProcessing procedure.
// 
// Parameters:
//  Ref - CatalogRef.MetadataObjectIDs
//         - CatalogRef.ExtensionObjectIDs
//
// Returns:
//  String
//
Function IDPresentation(Ref) Export
	
	ExtensionsObjects = TypeOf(Ref) <> Type("CatalogRef.MetadataObjectIDs");
	CollectionsProperties = StandardSubsystemsCached.MetadataObjectCollectionProperties(ExtensionsObjects);
	
	CollectionProperties = CollectionsProperties.Find(Ref.UUID(), "Id");
	If CollectionProperties <> Undefined Then
		Return CollectionProperties.Synonym;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	
	If ExtensionsObjects Then
		Query.SetParameter("ExtensionsVersion", SessionParameters.ExtensionsVersion);
		Query.Text =
		"SELECT TOP 1
		|	ISNULL(ExtensionVersionObjectIDs.FullObjectName, ExtensionObjectIDs.FullName) AS FullName
		|FROM
		|	Catalog.ExtensionObjectIDs AS ExtensionObjectIDs
		|		LEFT JOIN InformationRegister.ExtensionVersionObjectIDs AS ExtensionVersionObjectIDs
		|		ON (ExtensionVersionObjectIDs.Id = ExtensionObjectIDs.Ref)
		|			AND (ExtensionVersionObjectIDs.ExtensionsVersion = &ExtensionsVersion)
		|WHERE
		|	ExtensionObjectIDs.Ref = &Ref";
	Else
		Query.Text =
		"SELECT TOP 1
		|	MetadataObjectIDs.FullName AS FullName
		|FROM
		|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
		|WHERE
		|	MetadataObjectIDs.Ref = &Ref";
	EndIf;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FullName = Selection.FullName;
	Else
		FullName = Undefined;
	EndIf;
	
	If FullName = Undefined Then
		Return NStr("en = 'The object does not exist.';");
	EndIf;
	
	If StrStartsWith(FullName, "?") Then
		Return "? " + StrSplit(FullName, " ")[1];
	EndIf;
	
	PointPosition = StrFind(FullName, ".");
	BaseTypeName = Left(FullName, PointPosition -1);
	
	Filter = New Structure("SingularName", BaseTypeName);
	Rows = CollectionsProperties.FindRows(Filter);
	
	If Rows.Count() <> 1 Then
		Return FullName;
	EndIf;
	
	MetadataObject = Common.MetadataObjectByFullName(FullName);
	If MetadataObject = Undefined Then
		Return FullName;
	EndIf;
	
	Return MetadataObjectPresentation(MetadataObject, Rows[0]);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for replacing IDs in databases.

Procedure ReplaceSubordinateNodeDuplicatesFoundOnImport(IsCheckOnly, HasChanges)
	
	If Common.DataSeparationEnabled() Then
		// Not supported in SaaS mode.
		Return;
	EndIf;
	
	If Not Common.IsSubordinateDIBNode() Then
		Return;
	EndIf;
	
	// Replacing the duplicates in a subordinate DIB node.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDs.Ref,
	|	IDs.NewRef
	|FROM
	|	Catalog.MetadataObjectIDs AS IDs
	|WHERE
	|	IDs.NewRef <> VALUE(Catalog.MetadataObjectIDs.EmptyRef)";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	If IsCheckOnly Then
		HasChanges = True;
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	RefsToReplace = New Array;
	PreviousAndNewRefs = New Map;
	While Selection.Next() Do
		RefsToReplace.Add(Selection.Ref);
		PreviousAndNewRefs.Insert(Selection.Ref, Selection.NewRef);
	EndDo;
	
	CurrentAttempt = 1;
	While True Do
		DataFound = FindByRef(RefsToReplace);
		DataFound.Columns[0].Name = "Ref";
		DataFound.Columns[1].Name = "Data";
		DataFound.Columns[2].Name = "Metadata";
		DataFound.Columns.Add("isEnabled");
		DataFound.FillValues(True, "isEnabled");
		
		If DataFound.Count() = 0 Then
			Block = New DataLock;
			LockItem = Block.Add("Catalog.MetadataObjectIDs");
			For Each RefToReplace In RefsToReplace Do
				LockItem.SetValue("Ref", RefToReplace);
			EndDo;
			BeginTransaction();
			Try
				Block.Lock();
				// Clearing new references from the duplicates IDs.
				For Each RefToReplace In RefsToReplace Do
					DuplicateObject1 = RefToReplace.GetObject();
					DuplicateObject1.NewRef = Undefined;
					DuplicateObject1.DataExchange.Load = True;
					DuplicateObject1.Write();
				EndDo;
				CommitTransaction();
			Except
				RollbackTransaction();
				Raise;
			EndTry;
			Break;
		EndIf;
		
		If CurrentAttempt > 10 Then
			ErrorText =
				NStr("en = 'Cannot replace duplicates of metadata object IDs.
				           |After 10 attempts, there is still data to be replaced.
				           |Please perform this operation in exclusive mode.';");
			Raise ErrorText;
		EndIf;
		
		WithoutErrors = ExecuteItemReplacement(PreviousAndNewRefs, DataFound, True);
		If Not WithoutErrors Then
			ErrorText =
				NStr("en = 'Cannot replace duplicate metadata object IDs.
				           |For more information, see the ID replacement errors in the event log.';");
			Raise ErrorText;
		EndIf;
		CurrentAttempt = CurrentAttempt + 1;
	EndDo;
	
EndProcedure

// The function from the ValueSearchingAndReplacing universal data processor.
// Changes:
// - operations with the progress bar form are no longer supported;
// - the UserInterruptProcessing procedure is deleted;
// - the InformationRegisters[СтрокаТаблицы.Метаданные.Имя] is replaced with
//   Common.ObjectManagerByFullName(TableRow.Metadata.FullName()).
//
Function ExecuteItemReplacement(Val Replaceable, Val RefsTable, Val DisableWriteControl = False, Val ExtensionsObjects = False)
	
	// ACC:1327-off - No.783.1.4.1
	// 1. It's not a transaction since it can be long-running.
	// 2. The execution follows a data import (infobase update) from the master node.
// 3. It's executed when duplicates of metadata object IDs are found (a rare occurrence).
	Parameters = ItemsReplacementParameters();
	
	For Each AccountingRegister In Metadata.AccountingRegisters Do
		Parameters.Insert(AccountingRegister.Name + "ExtDimension",        AccountingRegister.ChartOfAccounts.MaxExtDimensionCount);
		Parameters.Insert(AccountingRegister.Name + "Correspondence", AccountingRegister.Correspondence);
	EndDo;
	
	RefToProcess = Undefined;
	HadExceptions = False;
	
	Try
		For Each TableRow In RefsTable Do
			If Not TableRow.isEnabled Then
				Continue;
			EndIf;
			CorrectItem = Replaceable[TableRow.Ref];
			
			Ref = TableRow.Ref;
			
			If RefToProcess <> TableRow.Data Then
				If RefToProcess <> Undefined And Parameters.Object <> Undefined Then
					
					Try
						Parameters.Object.DataExchange.Load = True;
						If DisableWriteControl Then
							Parameters.Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(Parameters.Object, False);
						Else
							Parameters.Object.Write();
						EndIf;
					Except
						HadExceptions = True;
						ErrorInfo = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Couldn''t write object ""%1"" due to:
							           |%2';"),
							GetURL(Parameters.Object.Ref),
							ErrorProcessing.DetailErrorDescription(ErrorInfo));
						If TransactionActive() Then
							Raise ErrorText;
						EndIf;
						ReportError(ErrorText, ExtensionsObjects);
					EndTry;
					Parameters.Object = Undefined;
				EndIf;
				RefToProcess = TableRow.Data;
			EndIf;
			
			If Metadata.Documents.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
					
				For Each TabularSection In TableRow.Metadata.TabularSections Do
					For Each Attribute In TabularSection.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							LineOfATabularSection = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							While LineOfATabularSection <> Undefined Do
								LineOfATabularSection[Attribute.Name] = CorrectItem;
								LineOfATabularSection = Parameters.Object[TabularSection.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
				For Each Movement In TableRow.Metadata.RegisterRecords Do
					
					IsAccountingRegisterRecord = Metadata.AccountingRegisters.Contains(Movement);
					HasCorrespondence = IsAccountingRegisterRecord And Parameters[Movement.Name + "Correspondence"];
					
					RecordSet = Parameters.Object.RegisterRecords[Movement.Name];
					RecordSet.Read();
					MustWrite = False;
					SetTable = RecordSet.Unload();
					
					If SetTable.Count() = 0 Then
						Continue;
					EndIf;
					
					ColumnsNames = New Array;
					
					// Getting names of dimensions that might contain references.
					For Each Dimension In Movement.Dimensions Do
						
						If Dimension.Type.ContainsType(TypeOf(Ref)) Then
							
							If IsAccountingRegisterRecord Then
								
								If Dimension.AccountingFlag <> Undefined Then
									
									ColumnsNames.Add(Dimension.Name + "Dr");
									ColumnsNames.Add(Dimension.Name + "Cr");
								Else
									ColumnsNames.Add(Dimension.Name);
								EndIf;
							Else
								ColumnsNames.Add(Dimension.Name);
							EndIf;
						EndIf;
					EndDo;
					
					// Getting names of resources that might contain references.
					If Metadata.InformationRegisters.Contains(Movement) Then
						For Each Resource In Movement.Resources Do
							If Resource.Type.ContainsType(TypeOf(Ref)) Then
								ColumnsNames.Add(Resource.Name);
							EndIf;
						EndDo;
					EndIf;
					
					// Getting names of resources that might contain references.
					For Each Attribute In Movement.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							ColumnsNames.Add(Attribute.Name);
						EndIf;
					EndDo;
					
					// Making replacements in the table.
					For Each ColumnName In ColumnsNames Do
						TabSectionRow = SetTable.Find(Ref, ColumnName);
						While TabSectionRow <> Undefined Do
							TabSectionRow[ColumnName] = CorrectItem;
							MustWrite = True;
							TabSectionRow = SetTable.Find(Ref, ColumnName);
						EndDo;
					EndDo;
					
					If Metadata.AccountingRegisters.Contains(Movement) Then
						
						For ExtDimensionIndex = 1 To Parameters[Movement.Name + "ExtDimension"] Do
							If HasCorrespondence Then
								TabSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimensionDr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimensionDr"+ExtDimensionIndex);
								EndDo;
								TabSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimensionCr"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimensionCr"+ExtDimensionIndex);
								EndDo;
							Else
								TabSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								While TabSectionRow <> Undefined Do
									TabSectionRow["ExtDimension"+ExtDimensionIndex] = CorrectItem;
									MustWrite = True;
									TabSectionRow = SetTable.Find(Ref, "ExtDimension"+ExtDimensionIndex);
								EndDo;
							EndIf;
						EndDo;
						
						If Ref.Metadata() = Movement.ChartOfAccounts Then
							For Each TabSectionRow In SetTable Do
								If HasCorrespondence Then
									If TabSectionRow.AccountDr = Ref Then
										TabSectionRow.AccountDr = CorrectItem;
										MustWrite = True;
									EndIf;
									If TabSectionRow.AccountCr = Ref Then
										TabSectionRow.AccountCr = CorrectItem;
										MustWrite = True;
									EndIf;
								Else
									If TabSectionRow.Account = Ref Then
										TabSectionRow.Account = CorrectItem;
										MustWrite = True;
									EndIf;
								EndIf;
							EndDo;
						EndIf;
					EndIf;
					
					If Metadata.CalculationRegisters.Contains(Movement) Then
						TabSectionRow = SetTable.Find(Ref, "CalculationType");
						While TabSectionRow <> Undefined Do
							TabSectionRow["CalculationType"] = CorrectItem;
							MustWrite = True;
							TabSectionRow = SetTable.Find(Ref, "CalculationType");
						EndDo;
					EndIf;
					
					If MustWrite Then
						RecordSet.Load(SetTable);
						Try
							If DisableWriteControl Then
								RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
								InfobaseUpdate.WriteData(RecordSet, False);
							Else
								RecordSet.Write();
							EndIf;
						Except
							HadExceptions = True;
							ErrorInfo = ErrorInfo();
							ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Couldn''t add to ""%2"" a record for object ""%1"" due to:
								           |%3';"),
								GetURL(Parameters.Object.Ref),
								RecordSet.Metadata().FullName(),
								ErrorProcessing.DetailErrorDescription(ErrorInfo));
							If TransactionActive() Then
								Raise ErrorText;
							EndIf;
							ReportError(ErrorText, ExtensionsObjects);
						EndTry;
					EndIf;
				EndDo;
				
				For Each Sequence In Metadata.Sequences Do
					If Sequence.Documents.Contains(TableRow.Metadata) Then
						MustWrite = False;
						SingleRecordSet = Sequences[Sequence.Name].CreateRecordSet(); // SequenceRecordSet 
						SingleRecordSet.Filter.Recorder.Set(TableRow.Data);
						SingleRecordSet.Read();
						
						If SingleRecordSet.Count() > 0 Then
							For Each Dimension In Sequence.Dimensions Do
								If Dimension.Type.ContainsType(TypeOf(Ref)) And SingleRecordSet[0][Dimension.Name]=Ref Then
									SingleRecordSet[0][Dimension.Name] = CorrectItem;
									MustWrite = True;
								EndIf;
							EndDo;
							If MustWrite Then
								Try
									If DisableWriteControl Then
										SingleRecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
										InfobaseUpdate.WriteData(SingleRecordSet, False);
									Else
										SingleRecordSet.Write();
									EndIf;
								Except
									HadExceptions = True;
									ErrorInfo = ErrorInfo();
									ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
											NStr("en = 'Couldn''t add to ""%2"" data for recorder ""%1"" due to:
											           |%3';"),
											GetURL(TableRow.Data),
											SingleRecordSet.Metadata().FullName(),
											ErrorProcessing.DetailErrorDescription(ErrorInfo));
									If TransactionActive() Then
										Raise ErrorText;
									EndIf;
									ReportError(ErrorText, ExtensionsObjects);
								EndTry;
							EndIf;
						EndIf;
					EndIf;
				EndDo;
				
			ElsIf Metadata.Catalogs.Contains(TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				If TableRow.Metadata.Owners.Contains(Ref.Metadata()) And Parameters.Object.Owner = Ref Then
					Parameters.Object.Owner = CorrectItem;
				EndIf;
				
				If TableRow.Metadata.Hierarchical And Parameters.Object.Parent = Ref Then
					Parameters.Object.Parent = CorrectItem;
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabSectionRow <> Undefined Do
								TabSectionRow[Attribute.Name] = CorrectItem;
								TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(TableRow.Metadata)
			      Or Metadata.ChartsOfAccounts.Contains            (TableRow.Metadata)
			      Or Metadata.ChartsOfCalculationTypes.Contains      (TableRow.Metadata)
			      Or Metadata.Tasks.Contains                 (TableRow.Metadata)
			      Or Metadata.BusinessProcesses.Contains         (TableRow.Metadata) Then
				
				If Parameters.Object = Undefined Then
					Parameters.Object = TableRow.Data.GetObject();
				EndIf;
				
				For Each Attribute In TableRow.Metadata.Attributes Do
					If Attribute.Type.ContainsType(TypeOf(Ref)) And Parameters.Object[Attribute.Name] = Ref Then
						Parameters.Object[Attribute.Name] = CorrectItem;
					EndIf;
				EndDo;
				
				For Each TS In TableRow.Metadata.TabularSections Do
					For Each Attribute In TS.Attributes Do
						If Attribute.Type.ContainsType(TypeOf(Ref)) Then
							TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							While TabSectionRow <> Undefined Do
								TabSectionRow[Attribute.Name] = CorrectItem;
								TabSectionRow = Parameters.Object[TS.Name].Find(Ref, Attribute.Name);
							EndDo;
						EndIf;
					EndDo;
				EndDo;
				
			ElsIf Metadata.Constants.Contains(TableRow.Metadata) Then
				
				Common.ObjectManagerByFullName(
					TableRow.Metadata.FullName()).Set(CorrectItem);
				
			ElsIf Metadata.InformationRegisters.Contains(TableRow.Metadata) Then
				
				DimensionStructure = New Structure;
				RegisterManager = Common.ObjectManagerByFullName(TableRow.Metadata.FullName());
				RecordSet = RegisterManager.CreateRecordSet(); // InformationRegisterRecordSet
				For Each Dimension In TableRow.Metadata.Dimensions Do
					RecordSet.Filter[Dimension.Name].Set(TableRow.Data[Dimension.Name]);
					DimensionStructure.Insert(Dimension.Name, TableRow.Data[Dimension.Name]);
				EndDo;
				If TableRow.Metadata.InformationRegisterPeriodicity <> Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
					RecordSet.Filter["Period"].Set(TableRow.Data.Period);
				EndIf;
				RecordSet.Read();
				
				If RecordSet.Count() = 0 Then
					Continue;
				EndIf;
				
				SetTable = RecordSet.Unload();
				RecordSet.Clear();
				
				ErrorText = "";
				BeginTransaction();
				Try
					Try
						If DisableWriteControl Then
							RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(RecordSet, False);
						Else
							RecordSet.Write();
						EndIf;
					Except
						ErrorInfo = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Record ""%1"" was not deleted due to:
							           |%2';"),
							GetURL(RegisterManager.CreateRecordKey(DimensionStructure)),
							ErrorProcessing.DetailErrorDescription(ErrorInfo));
						Raise;
					EndTry;
					
					For Each Column In SetTable.Columns Do
						If SetTable[0][Column.Name] = Ref Then
							SetTable[0][Column.Name] = CorrectItem;
							If DimensionStructure.Property(Column.Name) Then
								RecordSet.Filter[Column.Name].Set(CorrectItem);
								DimensionStructure[Column.Name] = CorrectItem;
							EndIf;
						EndIf;
					EndDo;
					
					RecordSet.Load(SetTable);
					
					Try
						If DisableWriteControl Then
							RecordSet.AdditionalProperties.Insert("SkipObjectVersionRecord");
							InfobaseUpdate.WriteData(RecordSet, False);
						Else
							RecordSet.Write();
						EndIf;
					Except
						ErrorInfo = ErrorInfo();
						ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Record ""%1"" was not added due to:
							           |%2';"),
							GetURL(RegisterManager.CreateRecordKey(DimensionStructure)),
							ErrorProcessing.DetailErrorDescription(ErrorInfo));
						Raise;
					EndTry;
					
					CommitTransaction();
				Except
					RollbackTransaction();
					HadExceptions = True;
					If Not ValueIsFilled(ErrorText) Then
						Raise;
					EndIf;
					If TransactionActive() Then
						Raise ErrorText;
					EndIf;
					ReportError(ErrorText, ExtensionsObjects);
				EndTry;
			Else
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot replace the values in data of the following type: %1.';"),
					String(TableRow.Metadata));
					
				ReportError(ErrorText, ExtensionsObjects);
			EndIf;
		EndDo;
	
		If Parameters.Object <> Undefined Then
			Try
				If DisableWriteControl Then
					Parameters.Object.AdditionalProperties.Insert("SkipObjectVersionRecord");
					InfobaseUpdate.WriteData(Parameters.Object, False);
				Else
					Parameters.Object.Write();
				EndIf;
			Except
				HadExceptions = True;
				ErrorInfo = ErrorInfo();
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Couldn''t write object ""%1"" due to:
					           |%2';"),
					GetURL(Parameters.Object.Ref),
					ErrorProcessing.DetailErrorDescription(ErrorInfo));
				If TransactionActive() Then
					Raise ErrorText;
				EndIf;
				ReportError(ErrorText, ExtensionsObjects);
			EndTry;
		EndIf;
		
	Except
		HadExceptions = True;
		Raise;
	EndTry;
	
	Return Not HadExceptions;
	// ACC:1327-off.
	
EndFunction

// Returns:
//  Structure:
//   * Object - CatalogObject 
//            - Undefined
// 
Function ItemsReplacementParameters()
	
	Parameters = New Structure;
	Parameters.Insert("Object", Undefined);
	Return Parameters;
	
EndFunction


// Procedure from the ValueSearchingAndReplacing universal data processor.
// Changes:
// - the Message(…) method is replaced with the WriteLogEvent(…) method.
//
Procedure ReportError(Val LongDesc, ExtensionsObjects)
	
	WriteLogEvent(
		?(ExtensionsObjects,
			NStr("en = 'Extension object IDs.ID replacement';",
				Common.DefaultLanguageCode()),
			NStr("en = 'Metadata object IDs.ID replacement';",
				Common.DefaultLanguageCode())),
		EventLogLevel.Error,
		,
		,
		LongDesc,
		EventLogEntryTransactionMode.Independent);
	
EndProcedure

#EndRegion

#EndIf

#EndIf