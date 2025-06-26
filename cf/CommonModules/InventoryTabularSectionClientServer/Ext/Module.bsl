
#Region Public

// Calculates amount in Inventory tabular section
//
// Parameters:
//  TabSectionRow - FormDataCollectionItem - row of tabular section Inventory
//
Procedure CalculateAmount(TabSectionRow) Export
	
	TabSectionRow.Amount = TabSectionRow.Quantity * TabSectionRow.Price;
	CalculateVATAmountAndTotal(TabSectionRow);
	
EndProcedure

// Calculates VAT amount and total amount in Inventory tabular section
//
// Parameters:
//  TabSectionRow - FormDataCollectionItem - row of tabular section Inventory
//
Procedure CalculateVATAmountAndTotal(TabSectionRow) Export
	
	VATRate = JetServerCall.GetVATRateValue(TabSectionRow.VATRate);
	TabSectionRow.VATAmount = TabSectionRow.Amount * VATRate / 100;
	TabSectionRow.Total = TabSectionRow.Amount + TabSectionRow.VATAmount;
	
EndProcedure

#EndRegion