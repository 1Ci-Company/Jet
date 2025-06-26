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

	LanguagesSet = New ValueTable;
	LanguagesSet.Columns.Add("LanguageCode", Common.StringTypeDetails(10));
	LanguagesSet.Columns.Add("Presentation", Common.StringTypeDetails(150));

	AvailableLanguages = New Array;
	For Each Language In Metadata.Languages Do
		AvailableLanguages.Add(Language.LanguageCode);
	EndDo;

	If Common.SubsystemExists("StandardSubsystems.NationalLanguageSupport.Print") Then
		PrintManagementModuleNationalLanguageSupport = Common.CommonModule("PrintManagementNationalLanguageSupport");
		AvailableLanguages = PrintManagementModuleNationalLanguageSupport.AvailableLanguages();
	EndIf;

	For Each LanguageCode In AvailableLanguages Do
		NewLanguage = LanguagesSet.Add();
		NewLanguage.LanguageCode = LanguageCode;
		NewLanguage.Presentation = CurrencyRateOperationsInternal.LanguagePresentation(LanguageCode);
	EndDo;

	AvailableScriptInputLanguages = AvailableScriptInputLanguages();

	For Each ConfigurationLanguage In LanguagesSet Do
		If AvailableScriptInputLanguages.Find(ConfigurationLanguage.LanguageCode) <> Undefined Then
			Continue;
		EndIf;
		NewRow = Languages.Add();
		FillPropertyValues(NewRow, ConfigurationLanguage);
		NewRow.Name = "Language_" + ConfigurationLanguage.LanguageCode;
	EndDo;

	GenerateInputFieldsInDifferentLanguages(False, Parameters.ReadOnly);

	DefaultLanguage = Common.DefaultLanguageCode();
	LanguageDetails = LanguageDetails(DefaultLanguage);
	
	If LanguageDetails <> Undefined Then
		ThisObject[LanguageDetails.Name] = Parameters.CurrentValue;
	EndIf;

	For Each Presentation In Parameters.Presentations Do

		LanguageDetails = LanguageDetails(Presentation.LanguageCode);
		If LanguageDetails <> Undefined Then
			If StrCompare(LanguageDetails.LanguageCode, DefaultLanguage) = 0 Then
				ThisObject[LanguageDetails.Name] = ?(ValueIsFilled(Parameters.CurrentValue),
					Parameters.CurrentValue, Presentation[Parameters.AttributeName]);
			Else
				ThisObject[LanguageDetails.Name] = Presentation[Parameters.AttributeName];
			EndIf;
		EndIf;

	EndDo;

EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	AmountInDigits = 123.45;
	SetAmountInWords();

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PagesOnCurrentPageChange(Item, CurrentPage)

	SetAmountInWords();

EndProcedure

&AtClient
Procedure AmountInDigitsOnChange(Item)

	SetAmountInWords();

EndProcedure

&AtClient
Procedure Attachable_InputFieldOnChange(Item)

	Modified = True;
	SetAmountInWords();
	NotifyOwner();

EndProcedure

&AtClient
Procedure Attachable_InputFieldEditTextChange(Item, Text, StandardProcessing)

	Modified = True;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)

	NotifyOwner(True, True);

EndProcedure

&AtClient
Procedure Write(Command)

	NotifyOwner(True);
	Modified = FormOwner.Modified;

EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure GenerateInputFieldsInDifferentLanguages(MultiLine, Var_ReadOnly)

	Add = New Array;
	StringType = New TypeDescription("String");
	For Each ConfigurationLanguage In Languages Do
		Add.Add(New FormAttribute(ConfigurationLanguage.Name, StringType, ,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Parameters for spelling out numbers in %1';"),
			ConfigurationLanguage.Presentation)));
		Add.Add(New FormAttribute("InputHint" + ConfigurationLanguage.Name, StringType, ,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Input tooltip for the %1 language';"),
			ConfigurationLanguage.Presentation)));
	EndDo;

	ChangeAttributes(Add);
	ItemsParent = Items.Pages;

	For Each ConfigurationLanguage In Languages Do

		If StrCompare(ConfigurationLanguage.LanguageCode, CurrentLanguage().LanguageCode) = 0
			And ItemsParent.ChildItems.Count() > 0 Then
			Page = Items.Insert("Page" + ConfigurationLanguage.Name, Type("FormGroup"), ItemsParent,
				ItemsParent.ChildItems.Get(0));
		Else
			Page = Items.Add("Page" + ConfigurationLanguage.Name, Type("FormGroup"), ItemsParent);
		EndIf;

		ConfigurationLanguage.Page = Page.Name;

		Page.Type = FormGroupType.Page;
		Page.Title = ConfigurationLanguage.Presentation;

		InputField = Items.Add(ConfigurationLanguage.Name, Type("FormField"), Page);
		InputField.DataPath = ConfigurationLanguage.Name;

		If ValueIsFilled(ConfigurationLanguage.EditForm) Then
			InputField.Type = FormFieldType.LabelField;
			InputField.Hyperlink = True;
			InputField.SetAction("Click", "Attachable_Click");
		Else
			InputField.Type                = FormFieldType.InputField;
			InputField.Width             = 40;
			InputField.MultiLine = MultiLine;
			InputField.ReadOnly     = Var_ReadOnly;
			InputField.TitleLocation = FormItemTitleLocation.None;
			InputField.SetAction("OnChange", "Attachable_InputFieldOnChange");
			InputField.SetAction("EditTextChange",
				"Attachable_InputFieldEditTextChange");

			ToolTip = HintForFillingInTheRegistrationParameters(ConfigurationLanguage.LanguageCode);
			InputField.InputHint = ToolTip.InputHint;

			InputHint = Items.Add("InputHint" + ConfigurationLanguage.Name, Type("FormField"), Page);
			InputHint.DataPath = "InputHint" + ConfigurationLanguage.Name;
			InputHint.Type = FormFieldType.InputField;
			InputHint.ReadOnly = True;
			InputHint.TextColor = StyleColors.NoteText;
			InputHint.VerticalStretch = True;
			InputHint.AutoMaxHeight = False;
			InputHint.MultiLine = True;
			InputHint.TitleLocation = FormItemTitleLocation.None;
			InputHint.BorderColor = StyleColors.FormBackColor;

			If Not ValueIsFilled(ToolTip.Instruction) Then
				ToolTip.Instruction = NStr("en = 'Cannot set up writing amounts in words for this language.';");
			EndIf;
			
			ThisObject["InputHint" + ConfigurationLanguage.Name] = ToolTip.Instruction;
		EndIf;

	EndDo;

EndProcedure

&AtServer
Function LanguageDetails(LanguageCode)

	Filter = New Structure("LanguageCode", LanguageCode);
	FoundItems1 = Languages.FindRows(Filter);
	If FoundItems1.Count() > 0 Then
		Return FoundItems1[0];
	EndIf;

	Return Undefined;

EndFunction

&AtClient
Procedure SetAmountInWords()

	CurrentLanguage = DescriptionOfTheCurrentLanguage();
	If CurrentLanguage = Undefined Then
		Return;
	EndIf;

	AmountInWordsParameters = ThisObject[CurrentLanguage.Name];
	AmountInWords = NumberInWords(AmountInDigits, "L=" + CurrentLanguage.LanguageCode + ";DP=False", AmountInWordsParameters); // ACC:1357

EndProcedure

&AtClient
Function DescriptionOfTheCurrentLanguage()

	CurrentPage = Items.Pages.CurrentPage;
	If CurrentPage = Undefined Then
		Return Undefined;
	EndIf;

	Return Languages.FindRows(New Structure("Page", CurrentPage.Name))[0];

EndFunction

&AtClient
Procedure NotifyOwner(Write = False, Close = False)

	CurrentLanguage = DescriptionOfTheCurrentLanguage();

	AmountInWordsParameters = New Structure;
	AmountInWordsParameters.Insert("LanguageCode", CurrentLanguage.LanguageCode);
	AmountInWordsParameters.Insert("AmountInWordsParameters", ThisObject[CurrentLanguage.Name]);
	AmountInWordsParameters.Insert("Write", Write);
	AmountInWordsParameters.Insert("Close", Close);

	Notify("CurrencyInWordsParameters", AmountInWordsParameters, FormOwner);

EndProcedure

&AtServer
Function AvailableScriptInputLanguages()

	Return CurrencyRateOperationsInternal.WritingInWordsInputForms().UnloadValues();

EndFunction

&AtServer
Function HintForFillingInTheRegistrationParameters(Val LanguageCode)

	Result = New Structure;
	Result.Insert("Instruction", "");
	Result.Insert("InputHint", "");

	If Not ValueIsFilled(LanguageCode) Then
		Return Result;
	EndIf;

	LanguageCode = StrSplit(LanguageCode, "_", True)[0];

	If LanguageCode = "ru" Or LanguageCode = "be" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Russian and Belarusian (ru_RU, be_BY):
		|
		|рубль, рубля, рублей, м, копейка, копейки, копеек, ж, 2
		|
		|""рубль, рубля, рублей, м"" – the calculation object:
		|рубль – nominative singular
		|рубля – genitive singular
		|рублей – genitive plural
		|м – masculine (ж – feminine, с – neuter)
		|""копейка, копейки, копеек, ж"" – the fractional part similar to the calculation object (may be missing)
		|""2"" – the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'рубль, рубля, рублей, м, копейка, копейки, копеек, ж, 2';");

	ElsIf LanguageCode = "uk" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Ukrainian (uk_UA):
		|
		|гривна, гривны, гривен, м, копейка, копейки, копеек, ж, 2
		|
		|""гривна, гривны, гривен, м"" – the calculation object:
		|""гривна – nominative singular
		|гривны – genitive singular
		|гривен – genitive plural
		|м – masculine (ж – feminine, с – neuter)
		|""копейка, копейки, копеек, ж"" – the fractional part similar to the calculation object (may be missing)
		|""2"" – the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'гривна, гривны, гривен, м, копейка, копейки, копеек, ж, 2';");

	ElsIf LanguageCode = "pl" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Polish (pl_PL):
		|
		|złoty, złote, złotych, m, grosz, grosze, groszy, m, 2
		|
		|""złoty, złote, złotych, m "" - the calculation subject (m - masculine, ż - feminine, ń - neuter, mo – masculine personal).
		|złoty - nominative singular
		|złote - accusative singular
		|złotych - accusative plural
		|m - masculine (ż - feminine, ń - neuter, mo – masculine personal)
		|""grosz, grosze, groszy, m "" - the fractional part (may be missing) (similar to the integral part)
		|2 - the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'złoty, złote, złotych, m, grosz, grosze, groszy, m, 2';");

	ElsIf LanguageCode = "en" Or LanguageCode = "fr" Or LanguageCode = "fi" Or LanguageCode = "kk" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for English, French, Finnish and Kazakh (en_US, fr_CA,fi_FI, kk_KZ):
		|
		|dollar, dollars, cent, cents, 2
		|
		|""dollar, dollars"" – calculation object singular and plural
		|""cent, cents"" - fractional part singular and plural (may be missing)
		|""2"" - the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'dollar, dollars, cent, cents, 2';");

	ElsIf LanguageCode = "de" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for German (de_DE):
		|
		|EURO, EURO, M, Cent, Cent, M, 2
		|
		|""EURO, EURO, M"" – the calculation object:
		|EURO, EURO - calculation object singular and plural
		|M – masculine (F – feminine, N - neuter)
		|""Cent, Cent, M"" – the fractional part similar to the calculation object (may be missing)
		|""2"" – the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'EURO, EURO, M, Cent, Cent, M, 2';");

	ElsIf LanguageCode = "lv" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Latvian (lv_LV):
		|
		|lats, lati, latu, V, santīms, santīmi, santīmu, V, 2, J, J
		|
		|""lats, lati, latu, v"" – the calculation object:
		|lats – for numbers ending with 1, except for 11
		|lati – for numbers ending with 2-9 and 11
		|latu – plural (genitive) used for numerals 0, 10, 20,…, 90, 100, 200, …, 1000, …, 100000
		|v – masculine (s – feminine)
		|""santīms, santīmi, santīmu, V"" – the fractional part similar to the calculation object (may be missing)
		|""2"" – the number of decimal places (may be missing; the default value is 2)
		|""J"" - the number 100 is displayed as ""One hundred"" for the calculation object (N - the number 100 is displayed as ""Hundred"");
		|may be missing; the default value is ""J""
		|""J"" - the number 100 is displayed as ""One hundred"" for the fractional part (N - the number 100 is displayed as ""Hundred"")
		|may be missing; the default value is ""J"".';"));

		Result.InputHint = NStr("en = 'lats, lati, latu, V, santīms, santīmi, santīmu, V, 2, J, J';");

	ElsIf LanguageCode = "lt" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Lithuanian (lt_LT):
		|
		|litas, litai, litų, M, centas, centai, centų, M, 2
		|
		|""litas, litai, litų, M"" – the calculation object:
		|litas - integral part singular
		|litai - integral part plural (from 2 to 9)
		|litų - integral part plural (other)
		|m - the integral part gender (f - feminine),
		|""centas, centai, centų, M"" – the fractional part similar to the calculation object (may be missing)
		|""2"" - the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'litas, litai, litų, M, centas, centai, centų, M, 2';");

	ElsIf LanguageCode = "et" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Estonian (et_EE):
		|
		|kroon, krooni, sent, senti, 2
		|
		|""kroon, krooni"" – calculation object singular and plural
		|""sent, senti"" - fractional part singular and plural (may be missing)
		|2 - the number of decimal places (may be missing; the default value is 2).';"));

		Result.InputHint = NStr("en = 'kroon, krooni, sent, senti, 2';");

	ElsIf LanguageCode = "bg" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Bulgarian (bg_BG):
		|
		|лев, лева, м, стотинка, стотинки, ж, 2
		|
		|""лев, лева, м"" – the calculation object:
		|лев - integral part singular
		|лева - integral part plural
		|м - the integral part gender
		|""стотинка, стотинки, ж"" - the fractional part:
		|стотинка - fractional part singular
		|стотинки - fractional part plural
		|ж - the fractional part gender
		|""2"" - the number of decimal places.';"));

		Result.InputHint = NStr("en = 'лев, лева, м, стотинка, стотинки, ж, 2';");

	ElsIf LanguageCode = "ro" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Romanian (ro_RO):
		|
		|leu, lei, M, ban, bani, W, 2
		|
		|""leu, lei, M"" – the calculation object:
		|leu - integral part singular
		|lei - integral part plural
		|M - the integral part gender
		|""ban, bani, W"" - the fractional part:
		|ban - fractional part singular
		|bani - fractional part plural
		|W - the fractional part gender
		|""2"" - the number of decimal places.';"));

		Result.InputHint = NStr("en = 'leu, lei, M, ban, bani, W, 2';");

	ElsIf LanguageCode = "ka" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Georgian (ka_GE):
		|
		|ლარი, თეთრი, 2
		|
		|ლარი - the integral part
		|თეთრი - the fractional part
		|2 - the number of decimal places.';"));

		Result.InputHint = NStr("en = 'ლარი, თეთრი, 2';");

	ElsIf LanguageCode = "az" Or LanguageCode = "tk" Then

		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Azerbaijani (az) and Turkmen (tk):
		|
		|TL,Kr,2
		|
		|""TL"" - the calculation object
		|""Kr"" - the fractional part (may be missing)
		|2 - the number of decimal places (may be missing; the default value is 2)';"));

		Result.InputHint = NStr("en = 'TL,Kr,2';");

	ElsIf LanguageCode = "vi" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Vietnamese (vi_VN):
		|
		|dong, xu, 2
		|
		|dong, - the integral part
		|xu, - the fractional part
		|2 - the number of decimal places.';"));

		Result.InputHint = NStr("en = 'dong, xu, 2';");

	ElsIf LanguageCode = "tr" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Turkish (tr_TR):
		|
		|TL,Kr,2,Separate
		|
		|TL - the integral part
		|Kr - the fractional part (may be missing)
		|2 - the number of decimal places (may be missing; the default value is 2)
		|""Separate"" - indicates whether to write words separately, ""Solid"" - indicates whether to write words solid (may be missing; the default value is ""Solid"").';"));

		Result.InputHint = NStr("en = 'TL,Kr,2,Separate';");

	ElsIf LanguageCode = "hu" Then

		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for Hungarian (hu):
		|
		|Forint, fillér, 2
		|
		|Forint - the integral part
		|fillér - the fractional part
		|""2"" - the number of decimal places.';"));

		Result.InputHint = NStr("en = 'Forint, fillér, 2';");

	EndIf;

	Return Result;

EndFunction

#EndRegion