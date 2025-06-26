
#If Server Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingJet.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SalesInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Movements on the Sales register
	PostingManagement.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Total = Inventory.Total("Total");
	
EndProcedure

#EndRegion

#EndIf