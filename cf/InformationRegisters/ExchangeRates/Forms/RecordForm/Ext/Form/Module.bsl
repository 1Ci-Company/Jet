///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Record.SourceRecordKey) Then
		Record.Period = CurrentSessionDate();
	EndIf;
	
	FillCurrency();

	CurrencySelectionAvailable = Not Parameters.FillingValues.Property("Currency") And Not ValueIsFilled(Parameters.Key);
	Items.CurrencyLabel.Visible = Not CurrencySelectionAvailable;
	Items.CurrencyList.Visible = CurrencySelectionAvailable;
	
	WindowOptionsKey = ?(CurrencySelectionAvailable, "WithCurrencyChoice", "NoCurrencyChoice");
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_ExchangeRates", WriteParameters, Record);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not CurrencySelectionAvailable Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("CurrencyList");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CurrencyOnChange(Item)
	Record.Currency = CurrencyList;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillCurrency()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS AlphabeticCode,
	|	Currencies.DescriptionFull AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description";
	
	CurrencySelection = Query.Execute().Select();
	
	While CurrencySelection.Next() Do
		CurrencyPresentation = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", CurrencySelection.Description, CurrencySelection.AlphabeticCode);
		Items.CurrencyList.ChoiceList.Add(CurrencySelection.Ref, CurrencyPresentation);
		If CurrencySelection.Ref = Record.Currency Then
			CurrencyLabel = CurrencyPresentation;
			CurrencyList = Record.Currency;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
