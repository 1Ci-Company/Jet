#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Returns the zero VAT rate.
//
// Returns:
//  CatalogRef.VATRates -
//
Function GetExemptFromVATRate() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	VATRates.Ref AS Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	NOT VATRates.DeletionMark
	|	AND VATRates.Rate = 0";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Ref;
	EndIf;
	
	NewVATRate = Catalogs.VATRates.CreateItem();
	NewVATRate.Description = "0%";
	NewVATRate.Rate = 0;
	NewVATRate.Write();
	
	Return NewVATRate.Ref;
	
EndFunction

#EndRegion

#EndIf
