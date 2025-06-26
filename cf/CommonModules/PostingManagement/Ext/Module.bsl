
#Region Public

// Initializes additional properties to post a document.
//
// Parameters:
//  DocumentRef - DocumentRef - ref to posting document.
//  AdditionalProperties - Structure - additional properties.
//
Procedure InitializeAdditionalPropertiesForPosting(DocumentRef, AdditionalProperties) Export
	
	// Structure that will contain values table with data for movings execution.
	AdditionalProperties.Insert("TableForRegisterRecords", New Structure);
	
	// Contains the properties required for posting.
	AdditionalProperties.Insert("ForPosting", New Structure);
	
	// Stores the value of the temporary table manager
	AdditionalProperties.ForPosting.Insert("TempTablesManager", New TempTablesManager);
	
	// Contains the document metadata.
	AdditionalProperties.Insert("DocumentMetadata", DocumentRef.Metadata());
	
EndProcedure

// Prepares document record sets.
//
// Parameters:
//  DocumentObject - DocumentObject - object of any documents
//
Procedure PrepareRecordSetsForWriting(DocumentObject) Export
	
	For Each RecordSet In DocumentObject.RegisterRecords Do
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
		EndIf;
	EndDo;
	
	RegisterNameArray = GetUsedRegisterNames(DocumentObject.Ref, DocumentObject.AdditionalProperties.DocumentMetadata);
	For Each RegisterName In RegisterNameArray Do
		DocumentObject.RegisterRecords[RegisterName].Write = True;
	EndDo;
	
EndProcedure

// Writes document record sets.
//
// Parameters:
//  DocumentObject - DocumentObject - object of any documents
//
Procedure WriteRecordSets(DocumentObject) Export
	
	For Each RecordSet In DocumentObject.RegisterRecords Do
		If RecordSet.Write Then
			RecordSet.AdditionalProperties.Insert("ForPosting", DocumentObject.AdditionalProperties.ForPosting);
			RecordSet.Write();
			RecordSet.Write = False;
		EndIf;
	EndDo;
	
EndProcedure

// Movements on the Purchases register.
//
// Parameters:
//  AdditionalProperties -  Structure - additional properties.
//  RegisterRecords - RegisterRecordsCollection - collection of document register record recordsets.
//  Cancel - Boolean - if set True, the document will not be posted.
//
Procedure ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePurchases = AdditionalProperties.TableForRegisterRecords.TablePurchases;
	
	If Cancel Or TablePurchases.Count() = 0 Then
		Return;
	EndIf;
	
	PurchaseRecord = RegisterRecords.Purchases;
	PurchaseRecord.Write = True;
	PurchaseRecord.Load(TablePurchases);
	
EndProcedure

// Movements on the Sales register.
//
// Parameters:
//  AdditionalProperties -  Structure - additional properties.
//  RegisterRecords - RegisterRecordsCollection - collection of document register record recordsets.
//  Cancel - Boolean - if set True, the document will not be posted.
//
Procedure ReflectSales(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSales = AdditionalProperties.TableForRegisterRecords.TableSales;
	
	If Cancel Or TableSales.Count() = 0 Then
		Return;
	EndIf;
	
	SalesRecord = RegisterRecords.Sales;
	SalesRecord.Write = True;
	SalesRecord.Load(TableSales);
	
EndProcedure

// Movements on the InventoryInWarehouses register.
//
// Parameters:
//  AdditionalProperties -  Structure - additional properties.
//  RegisterRecords - RegisterRecordsCollection - collection of document register record recordsets.
//  Cancel - Boolean - if set True, the document will not be posted.
//
Procedure ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryInWarehouses = AdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses;
	
	If Cancel Or TableInventoryInWarehouses.Count() = 0 Then
		Return;
	EndIf;
	
	InventoryInWarehousesRecord = RegisterRecords.InventoryInWarehouses;
	InventoryInWarehousesRecord.Write = True;
	InventoryInWarehousesRecord.Load(TableInventoryInWarehouses);
	
EndProcedure

#EndRegion

#Region Private

// Generates register names array on which there are document movements.
//
// Parameters:
//  Recorder - DocumentRef - recorder of register
//  DocumentMetadata - MetadataObject
// Returns:
//  Array - 
//
Function GetUsedRegisterNames(Recorder, DocumentMetadata)
	
	QueryText = "";
	
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + JetServer.GetQueryUnion();
			QueryText = QueryText +
			"SELECT TOP 1
			|	""&RegisterName"" AS RegisterName
			|FROM
			|	&RegisterFullName AS RegisterTable
			|WHERE
			|	RegisterTable.Recorder = &Recorder";
		Else
			QueryText = QueryText +
			"SELECT ALLOWED TOP 1
			|	""&RegisterName"" AS RegisterName
			|FROM
			|	&RegisterFullName AS RegisterTable
			|WHERE
			|	RegisterTable.Recorder = &Recorder";
		EndIf;
		
		QueryText = StrReplace(QueryText, "&RegisterName" , RegisterRecord.Name);
		QueryText = StrReplace(QueryText, "&RegisterFullName" , RegisterRecord.FullName());
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", Recorder);
	
	RegisterNameArray = Query.Execute().Unload().UnloadColumn("RegisterName");
	
	Return RegisterNameArray;
	
EndFunction

#EndRegion