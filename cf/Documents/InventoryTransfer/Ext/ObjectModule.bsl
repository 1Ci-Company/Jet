#If Server Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingJet.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.InventoryTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Movements on the InventoryInWarehouses register
	PostingManagement.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Movements on the InventoryCost register
	PostingManagement.ReflectInventoryCost(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
	// Negative balance control
	AccumulationRegisters.InventoryInWarehouses.NegativeBalanceControl(Ref, AdditionalProperties, Cancel);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Writing of the records sets.
	PostingManagement.WriteRecordSets(ThisObject);
	
	// Negative balance control
	AccumulationRegisters.InventoryInWarehouses.NegativeBalanceControl(Ref, AdditionalProperties, Cancel);
	
EndProcedure

#EndRegion

#EndIf