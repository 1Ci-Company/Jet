///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ErrorInRateCalculationByFormula;
Var CurrencyCodes;

#EndRegion

#Region EventHandlers

// The dependent currency rates are controlled while writing.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("DisableDependentCurrenciesControl") Then
		Return;
	EndIf;
		
	AdditionalProperties.Insert("DependentCurrencies", New Map);
	
	If Count() > 0 Then
		UpdateSubordinateCurrenciesRates();
	Else
		DeleteDependentCurrencyRates();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Finds all dependent currencies and changes their rate.
//
Procedure UpdateSubordinateCurrenciesRates()
	
	SelectedCurrency = Undefined;
	AdditionalProperties.Property("UpdateSubordinateCurrencyRate", SelectedCurrency);
	
	For Each BaseCurrencyRecord In ThisObject Do
	
		If SelectedCurrency <> Undefined Then // Only the given currency's rate must be updated.
			BlockDependentCurrencyRate(SelectedCurrency, BaseCurrencyRecord.Period); 
		Else
			DependentCurrencies = CurrencyRateOperations.DependentCurrenciesList(BaseCurrencyRecord.Currency, AdditionalProperties);
			For Each DependentCurrency In DependentCurrencies Do
				BlockDependentCurrencyRate(DependentCurrency, BaseCurrencyRecord.Period); 
			EndDo;
		EndIf;
		
	EndDo;
	
	For Each BaseCurrencyRecord In ThisObject Do

		If SelectedCurrency <> Undefined Then // Only the given currency's rate must be updated.
			UpdatedPeriods = Undefined;
			If Not AdditionalProperties.Property("UpdatedPeriods", UpdatedPeriods) Then
				UpdatedPeriods = New Map;
				AdditionalProperties.Insert("UpdatedPeriods", UpdatedPeriods);
			EndIf;
			// The rate is not updated more than once over the same period of time.
			If UpdatedPeriods[BaseCurrencyRecord.Period] = Undefined Then
				//@skip-check query-in-loop. Batch processing of a large amount of data.
				UpdateSubordinateCurrencyRate(SelectedCurrency, BaseCurrencyRecord); 
				UpdatedPeriods.Insert(BaseCurrencyRecord.Period, True);
			EndIf;
		Else	// Refresh the rate for all dependent currencies.
			DependentCurrencies = CurrencyRateOperations.DependentCurrenciesList(BaseCurrencyRecord.Currency, AdditionalProperties);
			For Each DependentCurrency In DependentCurrencies Do
				//@skip-check query-in-loop. Batch processing of a large amount of data.
				UpdateSubordinateCurrencyRate(DependentCurrency, BaseCurrencyRecord); 
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BlockDependentCurrencyRate(DependentCurrency, BaseCurrencyPeriod)
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExchangeRates");
	LockItem.SetValue("Currency", DependentCurrency.Ref);
	If ValueIsFilled(BaseCurrencyPeriod) Then
		LockItem.SetValue("Period", BaseCurrencyPeriod);
	EndIf;
	Block.Lock();
	
EndProcedure
	
Procedure UpdateSubordinateCurrencyRate(DependentCurrency, BaseCurrencyRecord)
	
	RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(DependentCurrency.Ref, True);
	RecordSet.Filter.Period.Set(BaseCurrencyRecord.Period, True);
	
	WriteCurrencyRate = RecordSet.Add();
	WriteCurrencyRate.Currency = DependentCurrency.Ref;
	WriteCurrencyRate.Period = BaseCurrencyRecord.Period;
	If DependentCurrency.RateSource = Enums.RateSources.MarkupForOtherCurrencyRate Then
		WriteCurrencyRate.Rate = BaseCurrencyRecord.Rate + BaseCurrencyRecord.Rate * DependentCurrency.Markup / 100;
		WriteCurrencyRate.Repetition = BaseCurrencyRecord.Repetition;
	Else // Calculate by formula.
		Rate = CurrencyRateByFormula(DependentCurrency.Ref, DependentCurrency.RateCalculationFormula, BaseCurrencyRecord.Period);
		If Rate <> Undefined Then
			WriteCurrencyRate.Rate = Rate;
			WriteCurrencyRate.Repetition = 1;
		EndIf;
	EndIf;
		
	If WriteCurrencyRate.Rate = 0 Then
		Return;
	EndIf;
	
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl");
	RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExchangeRates");
	LockItem.SetValue("Currency", WriteCurrencyRate.Currency);
	LockItem.SetValue("Period", WriteCurrencyRate.Period);
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordSet.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Clears rates for dependent currencies.
//
Procedure DeleteDependentCurrencyRates()
	
	CurrencyOwner = Filter.Currency.Value;
	Period = Filter.Period.Value;
	
	DependentCurrency = Undefined;
	If AdditionalProperties.Property("UpdateSubordinateCurrencyRate", DependentCurrency) Then
		BlockDependentCurrencyRate(DependentCurrency, Period);
		DeleteCurrencyRates(DependentCurrency, Period);
	Else
		DependentCurrencies = CurrencyRateOperations.DependentCurrenciesList(CurrencyOwner, AdditionalProperties);
		For Each DependentCurrency In DependentCurrencies Do
			BlockDependentCurrencyRate(DependentCurrency.Ref, Period); 
		EndDo;
		For Each DependentCurrency In DependentCurrencies Do
			DeleteCurrencyRates(DependentCurrency.Ref, Period);
		EndDo;
	EndIf;
	
EndProcedure

Procedure DeleteCurrencyRates(CurrencyRef, Period)
	RecordSet = InformationRegisters.ExchangeRates.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Filter.Period.Set(Period);
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl");
	RecordSet.Write();
EndProcedure
	
Function CurrencyRateByFormula(Currency, Formula, Period)
	
	Try
		Result = Catalogs.Currencies.CurrencyRateByFormula(Formula, Period, CurrencyCodes());
	Except
		If ErrorInRateCalculationByFormula = Undefined Then
			ErrorInRateCalculationByFormula = New Map;
		EndIf;
		If ErrorInRateCalculationByFormula[Currency] = Undefined Then
			ErrorInRateCalculationByFormula.Insert(Currency, True);
			ErrorInfo = ErrorInfo();
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot calculate the ""%1"" currency exchange rate using the ""%2"" formula for period ""%3"":';",
				Common.DefaultLanguageCode()), Currency, Formula, Period);
				
			Common.MessageToUser(ErrorText + Chars.LF + ErrorProcessing.BriefErrorDescription(ErrorInfo), 
				Currency, "Object.RateCalculationFormula");
				
			If AdditionalProperties.Property("UpdateSubordinateCurrencyRate") Then
				Raise ErrorText + Chars.LF + ErrorProcessing.BriefErrorDescription(ErrorInfo);
			EndIf;
			
			WriteLogEvent(NStr("en = 'Currencies.Import exchange rates';", Common.DefaultLanguageCode()),
				EventLogLevel.Error, Currency.Metadata(), Currency, 
				ErrorText + Chars.LF + ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EndIf;
		Result = Undefined;
	EndTry;
	
	Return Result;
EndFunction

Function CurrencyCodes()
	
	CurrencyCodes = Undefined;
	AdditionalProperties.Property("CurrencyCodes", CurrencyCodes);
	
	If CurrencyCodes = Undefined Then
		CurrencyCodes = Catalogs.Currencies.CurrencyCodes();
	EndIf;
	
	Return CurrencyCodes;
	
EndFunction

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf