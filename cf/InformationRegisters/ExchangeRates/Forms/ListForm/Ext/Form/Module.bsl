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
	
	If Parameters.Property("Filter") And Parameters.Filter.Property("Currency") Then
		Currency = Parameters.Filter.Currency;
	EndIf;
	
	WaitForExchangeRatesImport = Common.DataSeparationEnabled() And CoursesAreBeingUploaded(Currency);
	If WaitForExchangeRatesImport Then
		Items.Pages.CurrentPage = Items.PendingImport;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If WaitForExchangeRatesImport Then
		AttachIdleHandler("WaitForExchangeRatesImport", 15, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function CoursesAreBeingUploaded(Currency)
	
	CurrenciesImportedFromInternet = New Array;
	If Metadata.DataProcessors.Find("CurrenciesRatesImport") <> Undefined Then
		CurrenciesImportedFromInternet = DataProcessors["CurrenciesRatesImport"].CurrenciesImportedFromInternet();
	EndIf;
	
	If CurrenciesImportedFromInternet.Find(Currency) = Undefined Then
		Return False;
	EndIf;
	
	QueryText =
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	InformationRegister.ExchangeRates AS ExchangeRates
	|WHERE
	|	ExchangeRates.Period > &Period
	|	AND ExchangeRates.Currency = &Currency";
	
	Query = New Query(QueryText);
	Query.SetParameter("Period", '19800101');
	Query.SetParameter("Currency", Currency);
	
	Return Query.Execute().IsEmpty();
	
EndFunction

&AtClient
Procedure WaitForExchangeRatesImport()
	
	If CoursesAreBeingUploaded(Currency) Then
		AttachIdleHandler("WaitForExchangeRatesImport", 15, True);
	Else
		Items.Pages.CurrentPage = Items.ExRates;
	EndIf;
	
EndProcedure

#EndRegion
