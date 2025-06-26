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

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If RateSource = Enums.RateSources.CalculationByFormula Then
		QueryText =
		"SELECT
		|	Currencies.Description AS AlphabeticCode
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.RateSource = VALUE(Enum.RateSources.MarkupForOtherCurrencyRate)
		|
		|UNION ALL
		|
		|SELECT
		|	Currencies.Description
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.RateSource = VALUE(Enum.RateSources.CalculationByFormula)";

		Query = New Query(QueryText);
		DependentCurrencies = Query.Execute().Unload().UnloadColumn("AlphabeticCode");

		For Each Currency In DependentCurrencies Do
			If StrFind(RateCalculationFormula, Currency) > 0 Then
				Cancel = True;
			EndIf;
		EndDo;
	EndIf;

	If ValueIsFilled(Common.ObjectAttributeValue(MainCurrency, "MainCurrency")) Then
		Cancel = True;
	EndIf;

	If Cancel Then
		Common.MessageToUser(
			NStr("en = 'An exchange rate can only depend on an independent exchange rate.';"));
	EndIf;

	If RateSource <> Enums.RateSources.MarkupForOtherCurrencyRate Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("MainCurrency");
		AttributesToExclude.Add("Markup");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;

	If RateSource <> Enums.RateSources.CalculationByFormula Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("RateCalculationFormula");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;

	If Not IsNew() And RateSource = Enums.RateSources.MarkupForOtherCurrencyRate
		And CurrencyRateOperations.DependentCurrenciesList(Ref).Count() > 0 Then
		Common.MessageToUser(
			NStr("en = 'The currency cannot be subordinate because it is used as the base currency for other currencies.';"));
		Cancel = True;
	EndIf;

EndProcedure

Procedure BeforeWrite(Cancel)

	If DataExchange.Load Then
		Return;
	EndIf;

	RateImportedFromInternet = RateSource = Enums.RateSources.DownloadFromInternet;
	RateDependsOnOtherCurrency = RateSource = Enums.RateSources.MarkupForOtherCurrencyRate;
	RateCalculatedByFormula = RateSource = Enums.RateSources.CalculationByFormula;

	If IsNew() Then
		If RateDependsOnOtherCurrency Or RateCalculatedByFormula Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;
		AdditionalProperties.Insert("IsNew");
		AdditionalProperties.Insert("ScheduleCopyCurrencyRates");
	Else
		PreviousValues = Common.ObjectAttributesValues(Ref,
			"Code,RateSource,MainCurrency,Markup,RateCalculationFormula");

		RateSourceChanged = PreviousValues.RateSource <> RateSource;
		CurrencyCodeChanged = PreviousValues.Code <> Code;
		BaseCurrencyChanged = PreviousValues.MainCurrency <> MainCurrency;
		IncreaseByValueChanged = PreviousValues.Markup <> Markup;
		FormulaChanged = PreviousValues.RateCalculationFormula <> RateCalculationFormula;

		If (RateDependsOnOtherCurrency And (BaseCurrencyChanged Or IncreaseByValueChanged Or RateSourceChanged)) 
			Or (RateCalculatedByFormula And (FormulaChanged Or RateSourceChanged)) Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;

		If RateImportedFromInternet And (RateSourceChanged Or CurrencyCodeChanged) Then
			AdditionalProperties.Insert("ScheduleCopyCurrencyRates");
		EndIf;
	EndIf;

	If RateSource <> Enums.RateSources.MarkupForOtherCurrencyRate Then
		MainCurrency = Catalogs.Currencies.EmptyRef();
		Markup = 0;
	EndIf;

	If RateSource <> Enums.RateSources.CalculationByFormula Then
		RateCalculationFormula = "";
	EndIf;
	
	If ValueIsFilled(RateCalculationFormula) Then
		Try
			CheckFormula(RateCalculationFormula);
		Except
			ErrorInfo = ErrorInfo();
			Refinement = CommonClientServer.ExceptionClarification(ErrorInfo,
				NStr("en = 'Failed to calculate the exchange rate using the formula:';"));
			Raise(Refinement.Text, Refinement.Category, , , ErrorInfo);
		EndTry;
	EndIf;

EndProcedure

Procedure OnWrite(Cancel)

	If DataExchange.Load Then
		Return;
	EndIf;

	UpdateRates = AdditionalProperties.Property("UpdateRates");
	IsNew = AdditionalProperties.Property("IsNew");
	RecordingOfCoursesIsRequired = UpdateRates Or IsNew;
	IsBackgroundCurrencyExchangeRatesRecalculationRunning = IsBackgroundCurrencyExchangeRatesRecalculationRunning();
	
	If RecordingOfCoursesIsRequired And IsBackgroundCurrencyExchangeRatesRecalculationRunning Then
		Raise NStr("en = 'Couldn''t save the currency because the background calculation of exchange rates is running.
							   |Try to save the currency later.';");
	EndIf;

	If UpdateRates Then
		StartBackgroundCurrencyExchangeRatesUpdate();
	ElsIf Not IsBackgroundCurrencyExchangeRatesRecalculationRunning Then
		CurrencyRateOperations.CheckCurrencyRateAvailabilityFor01011980(Ref);
	EndIf;

	If AdditionalProperties.Property("ScheduleCopyCurrencyRates") Then
		ScheduleCopyCurrencyRates();
	EndIf;

EndProcedure

#EndRegion

#Region Private

Function IsBackgroundCurrencyExchangeRatesRecalculationRunning()

	JobParameters = New Structure;
	JobParameters.Insert("Description", "CurrencyRateOperations.UpdateCurrencyRate");
	JobParameters.Insert("State", BackgroundJobState.Active);

	Return Common.FileInfobase() 
		And BackgroundJobs.GetBackgroundJobs(JobParameters).Count() > 0;

EndFunction

Procedure StartBackgroundCurrencyExchangeRatesUpdate()

	CurrencyParameters = New Structure;
	CurrencyParameters.Insert("MainCurrency");
	CurrencyParameters.Insert("Ref");
	CurrencyParameters.Insert("Markup");
	CurrencyParameters.Insert("AdditionalProperties");
	CurrencyParameters.Insert("RateCalculationFormula");
	CurrencyParameters.Insert("RateSource");
	CurrencyParameters.Insert("CurrenciesUsedInCalculatingTheExchangeRate", CurrenciesUsedInCalculatingTheExchangeRate());
	FillPropertyValues(CurrencyParameters, ThisObject);

	JobParameters = New Structure;
	JobParameters.Insert("Currency", CurrencyParameters);
	JobParameters.Insert("CurrencyCodes", Catalogs.Currencies.CurrencyCodes());

	If InfobaseUpdate.InfobaseUpdateRequired() Then
		CurrencyRateOperations.UpdateCurrencyRate(JobParameters, Undefined);
		Return;
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitCompletion = 0;

	Result = TimeConsumingOperations.ExecuteInBackground("CurrencyRateOperations.UpdateCurrencyRate", JobParameters,
		ExecutionParameters);
	
	If Result.Status = "Error" Then
		Refinement = CommonClientServer.ExceptionClarification(Result.ErrorInfo,
			NStr("en = 'Couldn''t update exchange rates due to:';"));
		Raise(Refinement.Text, Refinement.Category,,, Result.ErrorInfo);
	EndIf;

EndProcedure

Procedure ScheduleCopyCurrencyRates()

	If Common.DataSeparationEnabled() And Common.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesInternal = Common.CommonModule("CurrencyRateOperationsInternal");
		ModuleCurrencyExchangeRatesInternal.ScheduleCopyCurrencyRates(ThisObject);
	EndIf;

EndProcedure

Function CurrenciesUsedInCalculatingTheExchangeRate()

	If RateSource = Enums.RateSources.MarkupForOtherCurrencyRate Then
		Return CommonClientServer.ValueInArray(MainCurrency);
	EndIf;

	If RateSource <> Enums.RateSources.CalculationByFormula Then
		Return New Array;
	EndIf;

	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	&RateCalculationFormula LIKE ""%"" + Currencies.Description + ""%"" ESCAPE ""~""
	|	AND Currencies.Description <> """"";

	Query = New Query(QueryText);
	Query.SetParameter("RateCalculationFormula", RateCalculationFormula);
	QueryResult = Query.Execute();

	If QueryResult.IsEmpty() Then
		ErrorText = NStr("en = 'The formula must include at least one base currency.';");
		Common.MessageToUser(ErrorText,, "Object.RateCalculationFormula");
		Raise ErrorText;
	EndIf;

	Return QueryResult.Unload().UnloadColumn("Ref");

EndFunction

Procedure CheckFormula(Formula) Export
	
	CurrencyCodes = Catalogs.Currencies.CurrencyCodes();
	Expression = Catalogs.Currencies.FormatNumbers(Formula);
	
	For Each Currency In CurrencyCodes Do
		Expression = StrReplace(Expression, Currency.AlphabeticCode, "1");
	EndDo;
	
	Common.CalculateInSafeMode(Expression);
	
EndProcedure

#EndRegion

#Else
	Raise NStr("en = 'Invalid object call on the client.';");
#EndIf