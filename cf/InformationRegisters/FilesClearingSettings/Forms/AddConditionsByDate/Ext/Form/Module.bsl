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
	
	If Not ValueIsFilled(Parameters.AttributesOfDateType) Then // Return if there are no attributes with the date type.
		Return;
	EndIf;
	
	HasOnlyOneAttribute = Parameters.AttributesOfDateType.Count() = 1;
	
	For Each Attribute In Parameters.AttributesOfDateType Do
		Items.DateTypeAttribute.ChoiceList.Add(Attribute.Value, Attribute.Presentation);
		If HasOnlyOneAttribute Then
			DateTypeAttribute = Attribute.Value;
		EndIf;
	EndDo;
	
	If Common.IsMobileClient() Then
		Items.IntervalException.TitleLocation = FormItemTitleLocation.Top;
		Items.DateTypeAttribute.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ResultingStructure = New Structure();
	ResultingStructure.Insert("IntervalException", IntervalException);
	ResultingStructure.Insert("DateTypeAttribute", DateTypeAttribute);
	
	NotifyChoice(ResultingStructure);

EndProcedure

#EndRegion