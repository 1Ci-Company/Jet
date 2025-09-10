
#Region Public

// Calculates amount in Inventory tabular section
//
// Parameters:
//  TabSectionRow - FormDataCollectionItem - row of tabular section Inventory
//  VATWithholding - Boolean - flag to use VAT withholding
//
Procedure CalculateAmount(TabSectionRow, VATWithholding = Undefined) Export
	
	TabSectionRow.Amount = TabSectionRow.Quantity * TabSectionRow.Price;
	CalculateVATAmountAndTotal(TabSectionRow, VATWithholding);
	
EndProcedure

// Calculates VAT amount and total amount in Inventory tabular section
//
// Parameters:
//  TabSectionRow - FormDataCollectionItem - row of tabular section Inventory
//  VATWithholding - Boolean - flag to use VAT withholding
//
Procedure CalculateVATAmountAndTotal(TabSectionRow, VATWithholding = Undefined) Export
	
	VATRate = JetServerCall.GetVATRateValue(TabSectionRow.VATRate);
	TabSectionRow.VATAmount = TabSectionRow.Amount * VATRate / 100;
	
	// VATWithholding
	If VATWithholding <> Undefined Then
		TabSectionRow.VATWithholdingAmount = 0;
		If VATWithholding And ValueIsFilled(TabSectionRow.VATWithholdingRate) Then
			VATWithholdingRate = VATWithholdingServerCall.GetVATWithholdingPercent(TabSectionRow.VATWithholdingRate);
			TabSectionRow.VATWithholdingAmount = TabSectionRow.VATAmount * VATWithholdingRate;
			TabSectionRow.VATAmount = TabSectionRow.VATAmount - TabSectionRow.VATWithholdingAmount;
		EndIf;
		TabSectionRow.VATTotal = TabSectionRow.VATAmount + TabSectionRow.VATWithholdingAmount;
	EndIf;
	
	TabSectionRow.Total = TabSectionRow.Amount + TabSectionRow.VATAmount;
	
EndProcedure

#EndRegion