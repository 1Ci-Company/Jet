
#If Server Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingJet.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SupplierInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Movements on the Purchases register
	PostingManagement.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	Total = Inventory.Total("Total");
	
EndProcedure

#EndRegion

#EndIf