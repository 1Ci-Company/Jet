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
	
	ReadOnly = Parameters.ReadOnly;
	
	Items.Ref.TypeRestriction  = Parameters.ValueType;
	RefTypeString             = Parameters.RefTypeString;
	Items.Presentation.Visible = RefTypeString;
	Items.Ref.Title        = Parameters.AttributeDescription;
	
	UsageKey = ?(RefTypeString, "EditRow", "EditReferenceObject");
	StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, UsageKey);
	
	If Not Parameters.RefTypeString
		And PropertyManagerInternal.ValueTypeContainsPropertyValues(Parameters.ValueType) Then
		ChoiceParameter = ?(ValueIsFilled(Parameters.AdditionalValuesOwner),
			Parameters.AdditionalValuesOwner, Parameters.Property);
	EndIf;
	
	ReturnValue = New Structure;
	ReturnValue.Insert("AttributeName", Parameters.AttributeName);
	ReturnValue.Insert("RefTypeString", RefTypeString);
	If Parameters.RefTypeString Then
		ReturnValue.Insert("RefAttributeName", Parameters.RefAttributeName);
		
		LinkAndPresentation = PropertyManagerInternal.AddressAndPresentation(Parameters.AttributeValue);
		Ref        = LinkAndPresentation.Ref;
		Presentation = LinkAndPresentation.Presentation;
	Else
		Ref = Parameters.AttributeValue;
	EndIf;
	
	If Common.IsMobileClient() Then
		CommandBarLocation = FormCommandBarLabelLocation.Top;
		Items.FormOKButton.Representation = ButtonRepresentation.Picture;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ChoiceParameter = Undefined Then
		Return;
	EndIf;
	
	ChoiceParametersArray1 = New Array;
	ChoiceParametersArray1.Add(New ChoiceParameter("Filter.Owner", ChoiceParameter));
	
	Items.Ref.ChoiceParameters = New FixedArray(ChoiceParametersArray1);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OKButton(Command)
	If RefTypeString Then
		Template = "<a href = ""%1"">%2</a>";
		If Not ValueIsFilled(Presentation) Then
			Presentation = Ref;
		EndIf;
		If Not ValueIsFilled(Ref) Then
			Value = "";
			ReturnValue.Insert("FormattedString", BlankFormattedString());
		Else
			Value = StringFunctionsClientServer.SubstituteParametersToString(Template, Ref, Presentation);
			ReturnValue.Insert("FormattedString", StringFunctionsClient.FormattedString(Value));
		EndIf;
	Else
		Value = Ref;
	EndIf;
	
	ReturnValue.Insert("Value", Value);
	Close(ReturnValue);
EndProcedure

&AtClient
Procedure CancelButton(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function BlankFormattedString()
	ValuePresentation= NStr("en = 'not set';");
	EditLink1 = "NotDefined";
	Result            = New FormattedString(ValuePresentation,, StyleColors.EmptyHyperlinkColor,, EditLink1);
	
	Return Result;
EndFunction

#EndRegion