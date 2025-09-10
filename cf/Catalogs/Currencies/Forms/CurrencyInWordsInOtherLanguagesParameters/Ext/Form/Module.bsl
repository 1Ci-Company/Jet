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
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Parameters for spelling out numbers in %1';tr = '%1 için sayıları okuma parametreleri'"),
			ConfigurationLanguage.Presentation)));
		Add.Add(New FormAttribute("InputHint" + ConfigurationLanguage.Name, StringType, ,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Input tooltip for the %1 language';tr = '%1 dili için araç ipucu gir'"),
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
				ToolTip.Instruction = NStr("en = 'Cannot set up writing amounts in words for this language.';tr = 'Bu dil için tutarların sayıyla yazılışı ayarlanamıyor.'");
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

	If LanguageCode = "en" Then

		//@skip-check module-nstr-camelcase
		Result.Instruction = StringFunctions.FormattedString(NStr(
		"en = 'List comma-separated parameters for writing amounts in words.
		|Example of filling for English (en_US):
		|
		|dollar, dollars, cent, cents, 2
		|
		|""dollar, dollars"" – calculation object singular and plural
		|""cent, cents"" - fractional part singular and plural (may be missing)
		|""2"" - the number of decimal places (may be missing; the default value is 2).';tr = 'Tutarların yazılışı için virgülle ayrılmış parametreler.
		|İngilizce (en_US) için doldurma örneği:
		|
		|dollar, dollars, cent, cents, 2
		|
		|""dollar, dollars"" – tekil ve çoğul hesaplama nesnesi
		|""cent, cents"" - tekil ve çoğul ondalık kısım (bulunmayabilir)
		|""2"" - ondalık basamak sayısı (bulunmayabilir; varsayılan değer 2''dir).'"));

		Result.InputHint = NStr("en = 'dollar, dollars, cent, cents, 2';tr = 'dolar, dolar, cent, cent, 2'");

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
		|""Separate"" - indicates whether to write words separately, ""Solid"" - indicates whether to write words solid (may be missing; the default value is ""Solid"").';tr = 'Tutarların yazılışı için virgülle ayrılmış parametreler.
		|Türkçe (tr_TR) için doldurma örneği:
		|
		|TL,Kr,2,Ayrı
		|
		|TL - tam sayı kısmı
		|Kr - ondalık kısım (bulunmayabilir)
		|2 - ondalık basamak sayısı (bulunmayabilir; varsayılan değer 2''dir)
		|""Ayrı"" - kelimelerin ayrı yazıldığını gösterir, ""Bitişik"" - kelimelerin bitişik yazıldığını gösterir (bulunmayabilir; varsayılan değer ""Bitişik""tir).'"));

		Result.InputHint = NStr("en = 'TL,Kr,2,Separate';tr = 'TL,Kr,2,Ayrı'");

	EndIf;

	Return Result;

EndFunction

#EndRegion