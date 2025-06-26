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
	
	LoadInWordParameters();
	
	If Common.IsMobileClient() Then
		Items.AmountInWordsPreviewGroup.ItemsAndTitlesAlign = ItemsAndTitlesAlignVariant.ItemsRightTitlesLeft;
		Items.AmountInWords.TitleLocation = FormItemTitleLocation.Top;
		Items.AmountInWords.Height = 2;
		Items.AmountInWords.MultiLine = True;
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AmountInDigits = 123.45;
	SetAmountInWords();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InputFieldOnChange(Item)
	
	Modified = True;
	SetAmountInWords();
	NotifyOwner();
	
EndProcedure

&AtClient
Procedure InputFieldEditTextChange(Item, Text, StandardProcessing)
	
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

&AtClientAtServerNoContext
Function AmountInWordsParameters(Form)
	
	AmountInWordsParameters = New Array;
	AmountInWordsParameters.Add(Form.IntegerPartSingularForm);
	AmountInWordsParameters.Add(Form.IntegerPartPluralForm);
	AmountInWordsParameters.Add(Form.FractionalPartSingularForm);
	AmountInWordsParameters.Add(Form.FractionalPartPluralForm);
	AmountInWordsParameters.Add(Form.FractionalPartLength);
	
	Return StrConcat(AmountInWordsParameters, ", ");
	
EndFunction

&AtClient
Procedure SetAmountInWords()
	
	If ValueIsFilled(Parameters.LanguageCode) Then
		AmountInWords = NumberInWords(AmountInDigits, "L=" + Parameters.LanguageCode + ";DP=False", AmountInWordsParameters(ThisObject)); // ACC:1357
	EndIf;
	
EndProcedure

&AtServer
Procedure LoadInWordParameters()
	
	AmountInWordsParameters = StrSplit(Parameters.AmountInWordsParameters, ",", True);
	If AmountInWordsParameters.Count() <> 5 Then
		Return;
	EndIf;
	
	IntegerPartSingularForm = TrimAll(AmountInWordsParameters[0]);
	IntegerPartPluralForm = TrimAll(AmountInWordsParameters[1]);
	FractionalPartSingularForm = TrimAll(AmountInWordsParameters[2]);
	FractionalPartPluralForm = TrimAll(AmountInWordsParameters[3]);
	FractionalPartLength = ClearTheStringWithTheNumberFromExtraneousCharacters(AmountInWordsParameters[4]);
	
EndProcedure

&AtServer
Function ClearTheStringWithTheNumberFromExtraneousCharacters(StringWithNumber)
	
	ProhibitedChars = StrConcat(StrSplit(StringWithNumber, "0123456789", False), "");
	Return StrConcat(StrSplit(StringWithNumber, ProhibitedChars, False), "");
	
EndFunction

&AtClient
Procedure NotifyOwner(Write = False, Close = False)
	
	AmountInWordsParameters = New Structure;
	AmountInWordsParameters.Insert("LanguageCode", Parameters.LanguageCode);
	AmountInWordsParameters.Insert("AmountInWordsParameters", AmountInWordsParameters(ThisObject));
	AmountInWordsParameters.Insert("Write", Write);
	AmountInWordsParameters.Insert("Close", Close);
	
	Notify("CurrencyInWordsParameters", AmountInWordsParameters, FormOwner);
	
EndProcedure

#EndRegion

