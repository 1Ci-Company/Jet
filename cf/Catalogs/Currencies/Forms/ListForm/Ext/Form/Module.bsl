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

	Items.Currencies.ChoiceMode = Parameters.ChoiceMode;

	DateOfCourse = BegOfDay(CurrentSessionDate());
	List.SettingsComposer.Settings.AdditionalProperties.Insert("DateOfCourse", DateOfCourse);

	EditableFields = New Array;
	EditableFields.Add("Rate");
	EditableFields.Add("Repetition");
	List.SetRestrictionsForUseInGroup(EditableFields);
	List.SetRestrictionsForUseInOrder(EditableFields);
	List.SetRestrictionsForUseInFilter(EditableFields);

	CurrenciesChangeAvailable = CurrencyRateOperationsInternal.HasRightToChangeExchangeRates();
	CurrenciesImportAvailable = Metadata.DataProcessors.Find("CurrenciesRatesImport") <> Undefined And CurrenciesChangeAvailable;

	Items.FormPickFromClassifier.Visible = CurrenciesImportAvailable;
	Items.FormImportCurrenciesRates.Visible = CurrenciesImportAvailable;
	If Not CurrenciesImportAvailable Then
		If CurrenciesChangeAvailable Then
			Items.CreateCurrency.Title = NStr("en = 'Create';");
		EndIf;
		Items.Create.Type = FormGroupType.ButtonGroup;
	EndIf;

EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectionResult, ChoiceSource)

	Items.Currencies.Refresh();
	Items.Currencies.CurrentRow = SelectionResult;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If EventName = "Write_ExchangeRates" Or EventName = "Write_CurrenciesRatesImport" Then
		Items.Currencies.Refresh();
	EndIf;

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersCurrencies

&AtServerNoContext
Procedure CurrenciesOnGetDataAtServer(TagName, Settings, Rows)

	Var DateOfCourse;

	If Not Settings.AdditionalProperties.Property("DateOfCourse", DateOfCourse) Then
		Return;
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT
	|	ExchangeRates.Currency AS Currency,
	|	ExchangeRates.Rate AS Rate,
	|	ExchangeRates.Repetition AS Repetition
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&EndOfPeriod, Currency IN (&Currencies)) AS ExchangeRates";
	Query.SetParameter("Currencies", Rows.GetKeys());
	Query.SetParameter("EndOfPeriod", DateOfCourse);

	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ListLine = Rows[Selection.Currency];
		ListLine.Data["Rate"] = Selection.Rate;
		If Selection.Repetition <> 1 Then
			Explanation = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'for %1 %2';"),
				Selection.Repetition, ListLine.Data["Description"]);
			ListLine.Data["Repetition"] = Explanation;
		EndIf;
	EndDo;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure PickFromClassifier(Command)

	PickingFormName = "DataProcessor.CurrenciesRatesImport.Form.PickCurrenciesFromClassifier";
	OpenForm(PickingFormName,, ThisObject);

EndProcedure

&AtClient
Procedure ImportCurrenciesRates(Command)

	FormParameters = New Structure("OpeningFromList", True);

	CurrencyRateOperationsClient.ShowExchangeRatesImport(FormParameters);

EndProcedure

#EndRegion