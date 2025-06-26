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
	
	BeginOfPeriod = Parameters.BeginOfPeriod;
	EndOfPeriod  = Parameters.EndOfPeriod;
	
	If BegOfDay(BeginOfPeriod) = BegOfDay(EndOfPeriod) Then
		Day = BeginOfPeriod;
	Else
		Day = CurrentSessionDate();
	EndIf;
	
	If Day < Parameters.LowLimit Then
		Day = Parameters.LowLimit;
	EndIf;
	
	Items.Day.BeginOfRepresentationPeriod = Parameters.LowLimit;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DayOnChange(Item)
	
	SelectionResult = New Structure("BeginOfPeriod, EndOfPeriod", BegOfDay(Day), EndOfDay(Day));
	Close(SelectionResult);
	
EndProcedure

#EndRegion