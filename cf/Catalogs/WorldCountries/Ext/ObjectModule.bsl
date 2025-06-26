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

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Or AdditionalProperties.Property("DoNotCheckUniqueness") Then
		Return;
	EndIf;
	
	If Predefined And Not IsNew() Then
		
		CheckTheChangeOfAPredefinedElement();
		
	EndIf;
	
	If Not CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	ErrorList = CheckTheUniquenessOfTheElements();
	
	If ErrorList.Count() > 0 Then
		
		Cancel = True;
		For Each ErrorDescription In ErrorList Do
			Common.MessageToUser(ErrorDescription.MessageText,, ErrorDescription.FieldName);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	If FillingData<>Undefined Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Controls item uniqueness in the infobase.
// If there are code or description duplicates, returns its list.
//
//  Returns:
//      Array of See NewErrorMessage - Details of duplicate items (if found).
//        
//
Function CheckTheUniquenessOfTheElements()
	
	Result = New Array;
	
	// Skip non-numerical codes.
	NumberType = New TypeDescription("Number", New NumberQualifiers(3, 0, AllowedSign.Nonnegative));
	If Code= "0" Or Code = "00" Or Code = "000" Then
		SearchCode = "000";
	Else
		SearchCode = Format(NumberType.AdjustValue(Code), "ND=3; NZ=; NLZ=");
	EndIf;
		
	Query = New Query("
		|SELECT TOP 10
		|	Code                AS Code,
		|	Description       AS Description,
		|	DescriptionFull AS DescriptionFull,
		|	CodeAlpha2          AS CodeAlpha2,
		|	CodeAlpha3          AS CodeAlpha3,
		|	EEUMember       AS EEUMember,
		|	Ref             AS Ref
		|FROM
		|	Catalog.WorldCountries
		|WHERE
		|	(Code = &Code
		|	OR Description = &Description
		|	OR CodeAlpha2 = &CodeAlpha2
		|	OR CodeAlpha3 = &CodeAlpha3
		|	OR DescriptionFull = &DescriptionFull)
		|	AND Ref <> &Ref
		|");
	Query.SetParameter("Ref",                Ref);
	Query.SetParameter("Code",                   SearchCode);
	Query.SetParameter("Description",          Description);
	Query.SetParameter("DescriptionFull",    DescriptionFull);
	Query.SetParameter("CodeAlpha2",             CodeAlpha2);
	Query.SetParameter("CodeAlpha3",             CodeAlpha3);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Result;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		Message = NewErrorMessage();
		If StrCompare(Selection.Code, Code) = 0 Then
			
			Message.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Code %1 already assigned to country %2. Change the code, or use the existing data.';"),
				Code, Selection.Description);
			Message.FieldName = "Object.Code";
			
		ElsIf StrCompare(Selection.Description, Description) = 0 Then
			
			Message.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Description %1 already assigned to the country. Change the description, or use the existing data.';"),
				Selection.Description);
			Message.FieldName = "Object.Description";
			
		ElsIf ValueIsFilled(DescriptionFull)
				  And StrCompare(Selection.DescriptionFull, DescriptionFull) = 0 Then
			
			Message.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Full description %1 already assigned to country %2. Change the full description, or use the existing data.';"),
				DescriptionFull, Selection.Description);
			Message.FieldName = "Object.DescriptionFull";
			
		ElsIf ValueIsFilled(CodeAlpha2)
				  And StrCompare(Selection.CodeAlpha2, CodeAlpha2) = 0 Then
			
			Message.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Alpha-2 code %1 already assigned to country %2. Change the Alpha-2 code, or use the existing data.';"),
				CodeAlpha2, Selection.Description);
			Message.FieldName = "Object.CodeAlpha2";
			
		ElsIf ValueIsFilled(CodeAlpha3)
				  And StrCompare(Selection.CodeAlpha3, CodeAlpha3) = 0 Then
			
			Message.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Alpha-3 code %1 already assigned to country %2. Change the Alpha-3 code, or use the existing data.';"),
				CodeAlpha3, Selection.Description);
			Message.FieldName = "Object.CodeAlpha3";
			
		EndIf;
		
		If ValueIsFilled(Message.FieldName) Then
			Result.Add(Message);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns:
//  Structure:
//   FieldName - String
//   MessageText - String
//
Function NewErrorMessage()
	
	Result = New Structure;
	Result.Insert("FieldName",        "");
	Result.Insert("MessageText", "");
	
	Return Result;
	
EndFunction

Procedure CheckTheChangeOfAPredefinedElement()
	
	PreviousValues = Common.ObjectAttributesValues(Ref, "Code, Description");
	If StrCompare(PreviousValues.Description, Description) <> 0 Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Description cannot be changed for country %1';"), PreviousValues.Description);
		Raise MessageText;
		
	EndIf;
	
	If StrCompare(PreviousValues.Code, Code) <> 0 Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Code cannot be changed for country %1';"), PreviousValues.Description);
		Raise MessageText;
		
	EndIf;

EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf