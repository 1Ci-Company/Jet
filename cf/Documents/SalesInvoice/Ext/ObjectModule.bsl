
#If Server Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingJet.FillDocument(ThisObject, FillingData);
	
	VATWithholding = GetFunctionalOption("UseVATWithholdingFromSales");
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// EDI
	If EDIServer.DocumentCanceled(Ref) Then
		MessageText = NStr("en = 'Document has already been canceled on EDI system. It is prohibited to post documents after cancelation.'; tr = 'Belge EDI sisteminde iptal edilmiştir. İptal edildikten sonra belge kaydedilemez.'");
		Common.MessageToUser(MessageText,,,, Cancel);
	EndIf;
	
	// Check for rejected e-document
	If EDIServer.DocumentRejected(Ref) = 1 Then
		MessageText = NStr("en = 'Document is rejected by counterparty on EDI system. It is prohibited to post documents after rejection.'; tr = 'Belge alıcı tarafından EDI sisteminde reddedilmiştir. Reddedildikten sonra belge kaydedilemez.'");
		Common.MessageToUser(MessageText,,,, Cancel);
	EndIf;
	// End EDI
	
	// Initialization of additional properties for document posting.
	PostingManagement.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SalesInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	PostingManagement.PrepareRecordSetsForWriting(ThisObject);
	
	// Movements on the Sales register
	PostingManagement.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	
	// Movements on the InventoryInWarehouses register
	PostingManagement.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Movements on the CustomerBalance register
	PostingManagement.ReflectCustomerBalance(AdditionalProperties, RegisterRecords, Cancel);
	
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

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Total = Inventory.Total("Total");
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	// EDI
	EDocumentNumber = "";
	// End EDI
	
EndProcedure

#EndRegion

#EndIf