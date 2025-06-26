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
	
	If Parameters.TypeDetails.Types().Count() > 0 Then
		FoundParameterType = Parameters.TypeDetails.Types()[0];
	EndIf;
	
	FillChoiceListInputOnBasis(FoundParameterType);
	
	For Each ParameterFromForm In Parameters.ParametersList Do
		If StrStartsWith(Parameters.ParameterName, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
			ParameterNameToCheck = Mid(Parameters.ParameterName, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2);
		Else
			ParameterNameToCheck = Parameters.ParameterName;
		EndIf;
		If ParameterFromForm.ParameterName = ParameterNameToCheck Then
			Continue;
		EndIf;
		ParametersList.Add(ParameterFromForm.ParameterName, ParameterFromForm.ParameterPresentation);
	EndDo;
	
	If StrStartsWith(Parameters.ParameterName, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
		ParameterName = Mid(Parameters.ParameterName, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2);
	Else
		ParameterName = Parameters.ParameterName;
	EndIf;
	ParameterPresentation = Parameters.ParameterPresentation;
	ParameterType = Parameters.TypeDetails;
	
EndProcedure

&AtServerNoContext
Function ParameterTypeAsString(FullTypeName)
	
	If StrCompare(FullTypeName, "Date") = 0 Then
		Result = Type("Date");
	ElsIf StrCompare(FullTypeName, "String") = 0 Then
		Result = Type("String");
	Else
		ObjectManager = Common.ObjectManagerByFullName(FullTypeName);
		If ObjectManager <> Undefined Then
			Result = TypeOf(ObjectManager.EmptyRef());
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ParameterTypeOnChange(Item)
	If IsBlankString(ParameterPresentation) And IsBlankString(ParameterName) Then
		ParameterPresentation = Items.TypeAsString.EditText;
		Position = StrFind(TypeAsString, ".", SearchDirection.FromEnd);
		If Position > 0 And Position < StrLen(TypeAsString) Then
			ParameterName = Mid(TypeAsString, Position + 1);
		Else
			ParameterName = TypeAsString;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	For Each ParameterFromForm In ParametersList Do
		If StrCompare(ParameterFromForm.Value, ParameterName) = 0 Then
			ShowMessageBox(, NStr("en = 'Placeholder name error. A placeholder with this name already exists.';"));
			Return;
		EndIf;
		If StrCompare(ParameterFromForm.Presentation, ParameterPresentation) = 0 Then
			ShowMessageBox(, NStr("en = 'Placeholder presentation error. A placeholder with this presentation already exists.';"));
			Return;
		EndIf;
	EndDo;
	
	If InvalidParameterName(ParameterName) Or IsBlankString(ParameterName) Then
		ShowMessageBox(, NStr("en = 'Invalid placeholder name. Special characters and whitespace are not allowed.';"));
		Return;
	EndIf;
	
	If IsBlankString(ParameterPresentation) Then
		ShowMessageBox(, NStr("en = 'Invalid placeholder presentation.';"));
		Return;
	EndIf;
	
	If IsBlankString(TypeAsString) Then
		ShowMessageBox(, NStr("en = 'Invalid placeholder type.';"));
		Return;
	EndIf;
	
	Result = New Structure("ParameterName, ParameterPresentation, ParameterType");
	FillPropertyValues(Result, ThisObject);
	Result.ParameterType = ParameterTypeAsString(TypeAsString);
	Close(Result);
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function InvalidParameterName(ParameterName)
	
	Try
		Test = New Structure(ParameterName, ParameterName);
	Except
		Return True;
	EndTry;
	
	Return TypeOf(Test) <> Type("Structure");
	
EndFunction

&AtServer
Procedure FillChoiceListInputOnBasis(ParameterType)
	
	TypePresentation = "";
	MessageTemplatesSettings = MessageTemplatesInternalCached.OnDefineSettings();
	For Each TemplateSubject In MessageTemplatesSettings.TemplatesSubjects Do
		If StrCompare(TemplateSubject.Name, Parameters.InputOnBasisParameterTypeFullName) = 0 Then
			Continue;
		EndIf;
		ObjectMetadata = Common.MetadataObjectByFullName(TemplateSubject.Name);
		If ObjectMetadata = Undefined Then
			Continue;
		EndIf;
		Items.TypeAsString.ChoiceList.Add(TemplateSubject.Name, TemplateSubject.Presentation);
		
		ObjectManager = Common.ObjectManagerByFullName(TemplateSubject.Name);
		If ObjectManager <> Undefined Then
			If ParameterType = TypeOf(ObjectManager.EmptyRef()) Then
				TypePresentation = TemplateSubject.Name;
			EndIf;
		EndIf;
	EndDo;
	
	If ParameterType = Type("String") Then
		TypePresentation = NStr("en = 'String';");
	ElsIf ParameterType = Type("Date") Then
		TypePresentation = NStr("en = 'Date';");
	EndIf;
	
	Items.TypeAsString.ChoiceList.Insert(0, "Date", NStr("en = 'Date';"));
	Items.TypeAsString.ChoiceList.Insert(0, "String", NStr("en = 'String';"));
	
	TypeAsString = TypePresentation;
	
EndProcedure

#EndRegion

