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

	If Object.Ref.IsEmpty() Then
		If Not (Parameters.Property("CopyingValue") And ValueIsFilled(Parameters.CopyingValue)) Then
			Object.RateSource = Enums.RateSources.ManualInput;
		EndIf;
	EndIf;

	ProcessingExchangeRatesImport = Metadata.DataProcessors.Find("CurrenciesRatesImport");
	Items.CurrencyRateImportedFromInternet.Visible = ProcessingExchangeRatesImport <> Undefined;
	SetItemsAvailability(ThisObject);

	FillInTheCurrencyRegistrationParametersSubmenu();
	Items.HyperlinkCurrencyInWordsParameters.Visible = WritingInWordsInputForms.Count() = 1;
	Items.GroupCurrencyInWordsParameters.Visible = WritingInWordsInputForms.Count() > 1;

	If Common.IsMobileClient() Then
		Items.RateCalculationFormula.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
		Items.MainCurrency.TitleLocation = FormItemTitleLocation.Auto;
		Items.HeaderGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
	EndIf;

	If Metadata.DataProcessors.Find("CurrenciesRatesImport") <> Undefined Then
		CurrenciesImportedFromInternetCodes.LoadValues(
			DataProcessors["CurrenciesRatesImport"].CurrenciesImportedFromInternetCodes());
	EndIf;

	DownloadFromTheInternetIsAvailable = ValueIsFilled(Object.Code) And ValueIsFilled(CurrenciesImportedFromInternetCodes)
		And CurrenciesImportedFromInternetCodes.FindByValue(Object.Code) <> Undefined;
	Items.CurrencyRateImportedFromInternet.Enabled = DownloadFromTheInternetIsAvailable;

	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		FormulaPresentation = ModuleConstructorFormula.FormulaPresentation(FormulaParameters(
			Object.RateCalculationFormula, UUID));
	Else
		Items.RateCalculationFormula.ChoiceButton = False;
	EndIf;

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If Source = ThisObject And EventName = "CurrencyInWordsParameters" Then
		SetThePrescriptionsInTheLanguage(Parameter.AmountInWordsParameters, Parameter.LanguageCode);
		If Parameter.Write Then
			Write();
		Else
			Modified = True;
		EndIf;
		If Parameter.Close Then
			Close();
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Basic Additional Data page.

&AtClient
Procedure MainCurrencyStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	PrepareSubordinateCurrencyChoiceData(ChoiceData, Object.Ref);

EndProcedure

&AtClient
Procedure CurrencyRateOnChange(Item)
	SetItemsAvailability(ThisObject);
EndProcedure

&AtClient
Procedure CurrencyInWordsParametersClick(Item)

	OpenCurrencyRegistrationParameters(0);

EndProcedure

&AtClient
Procedure CodeOnChange(Item)

	DownloadFromTheInternetIsAvailable = ValueIsFilled(Object.Code) And ValueIsFilled(CurrenciesImportedFromInternetCodes)
		And CurrenciesImportedFromInternetCodes.FindByValue(Object.Code) <> Undefined;
	Items.CurrencyRateImportedFromInternet.Enabled = DownloadFromTheInternetIsAvailable;
	If DownloadFromTheInternetIsAvailable Then
		Object.RateSource = PredefinedValue("Enum.RateSources.DownloadFromInternet");
	Else
		If Object.RateSource = PredefinedValue("Enum.RateSources.DownloadFromInternet") Then
			Object.RateSource = PredefinedValue("Enum.RateSources.ManualInput");
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure PrepareSubordinateCurrencyChoiceData(ChoiceData, Ref)
	
	// Prepare a choice list for the child currency so that the child currency itself is excluded from the list.
	// 

	ChoiceData = New ValueList;

	Query = New Query;

	Query.Text =
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.DescriptionFull AS DescriptionFull,
	|	Currencies.Description AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.Ref <> &Ref
	|	AND Currencies.MainCurrency = VALUE(Catalog.Currencies.EmptyRef)
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Query.Parameters.Insert("Ref", Ref);

	Selection = Query.Execute().Select();

	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.DescriptionFull + " (" + Selection.Description + ")");
	EndDo;

EndProcedure

&AtClientAtServerNoContext
Procedure SetItemsAvailability(Form)
	Items = Form.Items;
	Object = Form.Object;
	Items.IncreaseByGroup.Enabled = Object.RateSource = PredefinedValue(
		"Enum.RateSources.MarkupForOtherCurrencyRate");
	Items.RateCalculationFormula.Enabled = Object.RateSource = PredefinedValue(
		"Enum.RateSources.CalculationByFormula");
EndProcedure

&AtClient
Procedure SetThePrescriptionsInTheLanguage(AmountInWordsParameters, LanguageCode)

	If LanguageCode = CommonClient.DefaultLanguageCode() Then
		Object.AmountInWordsParameters = AmountInWordsParameters;
		Return;
	EndIf;

	FoundRow = Undefined;
	For Each TableRow In Object.Presentations Do
		If TableRow.LanguageCode = LanguageCode Then
			FoundRow = TableRow;
			Break;
		EndIf;
	EndDo;

	If FoundRow = Undefined Then
		FoundRow = Object.Presentations.Add();
		FoundRow.LanguageCode = LanguageCode;
	EndIf;

	FoundRow.AmountInWordsParameters = AmountInWordsParameters;

EndProcedure

&AtClient
Function ParametersOfCurrencyRegistrationInTheLanguage(LanguageCode)

	If LanguageCode = CommonClient.DefaultLanguageCode() Then
		Return Object.AmountInWordsParameters;
	EndIf;

	FoundRow = Undefined;
	For Each TableRow In Object.Presentations Do
		If TableRow.LanguageCode = LanguageCode Then
			FoundRow = TableRow;
		EndIf;
	EndDo;

	If FoundRow = Undefined Then
		Return "";
	EndIf;

	Return FoundRow.AmountInWordsParameters;

EndFunction

&AtServer
Procedure FillInTheCurrencyRegistrationParametersSubmenu()

	Button = Undefined;
	WritingInWordsInputForms = CurrencyRateOperationsInternal.WritingInWordsInputForms();
	For IndexOf = 0 To WritingInWordsInputForms.Count() - 1 Do
		CommandName = "CurrencyInWordsParameters_" + XMLString(IndexOf);

		LanguageCode = WritingInWordsInputForms[IndexOf].Value;
		Command = Commands.Add(CommandName);
		If ValueIsFilled(LanguageCode) Then
			Command.Title = StringFunctionsClientServer.SubstituteParametersToString("%1...", 
				CurrencyRateOperationsInternal.LanguagePresentation(LanguageCode));
		Else
			Command.Title = NStr("en = 'In other languages…';");
		EndIf;

		Command.Action = "Attachable_OpenCurrencyRegistrationParametersForm";

		Button = Items.Add(CommandName, Type("FormButton"), Items.GroupCurrencyInWordsParameters);
		Button.Type = FormButtonType.CommandBarButton;
		Button.CommandName = CommandName;
	EndDo;

EndProcedure

// Parameters:
//   Command - FormCommand
//
&AtClient
Procedure Attachable_OpenCurrencyRegistrationParametersForm(Command)

	IndexOf = Number(Mid(Command.Name, StrLen("CurrencyInWordsParameters_") + 1));
	OpenCurrencyRegistrationParameters(IndexOf);

EndProcedure

&AtClient
Procedure OpenCurrencyRegistrationParameters(IndexOf)

	NameOfTheRegistrationForm = WritingInWordsInputForms[IndexOf].Presentation;
	LanguageCode = WritingInWordsInputForms[IndexOf].Value;

	If NameOfTheRegistrationForm = "CurrencyInWordsInOtherLanguagesParameters" Then
		CurrencyInWordsInOtherLanguagesParameters();
	Else
		FormParameters = New Structure;
		FormParameters.Insert("AmountInWordsParameters", ParametersOfCurrencyRegistrationInTheLanguage(LanguageCode));
		FormParameters.Insert("LanguageCode", LanguageCode);

		OpenForm(NameOfTheRegistrationForm, FormParameters, ThisObject,,, URL);
	EndIf;

EndProcedure

&AtClient
Procedure Attachable_CurrencyInWordsInOtherLanguagesParameters(Command)

	CurrencyInWordsInOtherLanguagesParameters();

EndProcedure

&AtClient
Procedure CurrencyInWordsInOtherLanguagesParameters()

	AttributeName = "AmountInWordsParameters";

	FormParameters = New Structure;
	FormParameters.Insert("AttributeName", AttributeName);
	FormParameters.Insert("CurrentValue", Object.AmountInWordsParameters);
	FormParameters.Insert("ReadOnly", ReadOnly);
	FormParameters.Insert("Presentations", Object.Presentations);

	OpenForm("Catalog.Currencies.Form.CurrencyInWordsInOtherLanguagesParameters", FormParameters, ThisObject,,,,,
		FormWindowOpeningMode.LockOwnerWindow);

EndProcedure

&AtClient
Procedure RateCalculationFormulaStartChoice(Item, ChoiceData, StandardProcessing)

	If CommonClient.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormulaClient = CommonClient.CommonModule("FormulasConstructorClient");
		StandardProcessing = False;
		NotifyDescription = New NotifyDescription("WhenFinishedEditingFormulas", ThisObject);
		ModuleConstructorFormulaClient.StartEditingTheFormula(FormulaParameters(Object.RateCalculationFormula, UUID), 
			NotifyDescription);
	EndIf;

EndProcedure

&AtServerNoContext
Function FormulaParameters(RateCalculationFormula, UUID)

	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");

		FormulaParameters = ModuleConstructorFormula.FormulaEditingOptions();
		FormulaParameters.Formula = RateCalculationFormula;
		FormulaParameters.BracketsOperands = False;
		FormulaParameters.Operands = OperandsFormulasCalculationCourse(UUID);
		FormulaParameters.Operators = OperatorsFormulasCalculationCourse(UUID);

		Return FormulaParameters;
	EndIf;

EndFunction

&AtServerNoContext
Function OperandsFormulasCalculationCourse(UUID)

	Return PutToTempStorage(OperandsTable(), UUID);

EndFunction

&AtServerNoContext
Function OperatorsFormulasCalculationCourse(UUID)

	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");
		ListOfOperators = ModuleConstructorFormula.ListOfOperators("Operators, NumericFunction");
		Return PutToTempStorage(ListOfOperators, UUID);
	EndIf;

EndFunction

&AtServerNoContext
Function OperandsTable()

	If Common.SubsystemExists("StandardSubsystems.FormulasConstructor") Then
		ModuleConstructorFormula = Common.CommonModule("FormulasConstructor");

		OperandsTable = ModuleConstructorFormula.FieldTable();

		For Each CurrencyDescription In Catalogs.Currencies.CurrencyCodes() Do
			Operand = OperandsTable.Add();
			Operand.Id = CurrencyDescription.AlphabeticCode;
			Operand.Presentation = CurrencyDescription.AlphabeticCode;
			Operand.ValueType = New TypeDescription("Number");
		EndDo;

		Return OperandsTable;

	EndIf;

EndFunction

&AtClient
Procedure WhenFinishedEditingFormulas(FormulaDescription, AdditionalParameters) Export

	If FormulaDescription = Undefined Then
		Return;
	EndIf;

	Object.RateCalculationFormula = FormulaDescription.Formula;
	FormulaPresentation = FormulaDescription.FormulaPresentation;
	Modified = True;

EndProcedure

#EndRegion