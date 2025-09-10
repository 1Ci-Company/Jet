
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CatalogTaxExemptionReasons(Command)
	
	OpenForm("Catalog.TaxExemptionReasons.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogVATWithholdingCodes(Command)
	
	OpenForm("Catalog.VATWithholdingCodes.ListForm");
	
EndProcedure

&AtClient
Procedure CatalogVATWithholdingRates(Command)
	
	OpenForm("Catalog.VATWithholdingRates.ListForm");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseVATWithholdingFromSalesOnChange(Item)
	
	ErrorText = UseVATWithholdingFromSalesOnChangeProcessing();
	If Not IsBlankString(ErrorText) Then
		CommonClient.MessageToUser(ErrorText, , "ConstantsSet.UseVATWithholdingFromSales");
	Else
		AttachIdleHandler("RefreshAppInterface", 1, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure RefreshAppInterface()
	
	RefreshInterface();
	
EndProcedure

&AtServer
Function UseVATWithholdingFromSalesOnChangeProcessing()
	
	ErrorText = "";
	
	If Constants.UseVATWithholdingFromSales.Get() <> ConstantsSet.UseVATWithholdingFromSales
		And Not ConstantsSet.UseVATWithholdingFromSales Then
		
		ErrorText = CheckUseVATWithholdingFromSales();
		If Not IsBlankString(ErrorText) Then
			ConstantsSet.UseVATWithholdingFromSales = True;
			Return ErrorText
		EndIf;
		
	EndIf;
	
	If Constants.UseVATWithholdingFromSales.Get() <> ConstantsSet.UseVATWithholdingFromSales Then
		Constants.UseVATWithholdingFromSales.Set(ConstantsSet.UseVATWithholdingFromSales);
	EndIf;
	
	SetEnabled();
	
	RefreshReusableValues();
	
	Return ErrorText;
	
EndFunction

&AtServer
Function CheckUseVATWithholdingFromSales()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SalesInvoice.Ref AS Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.VATWithholding
	|	AND NOT SalesInvoice.DeletionMark";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		ErrorText = NStr("en = 'The check box cannon be cleared once VAT withholding is applied to any document.'; tr = 'Herhangi bir belgeye KDV tevkifatı uygulandıktan sonra onay kutusu temizlenemez.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

&AtServer
Procedure SetEnabled()
	
	CommonClientServer.SetFormItemProperty(Items, "CatalogVATWithholdingRates", "Enabled", ConstantsSet.UseVATWithholdingFromSales);
	CommonClientServer.SetFormItemProperty(Items, "CatalogVATWithholdingCodes", "Enabled", ConstantsSet.UseVATWithholdingFromSales);
	
EndProcedure

#EndRegion