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
	
	If ValueIsFilled(Parameters.Repetition) Then
		If Parameters.Repetition <> Enums.AvailableReportPeriods.Day Then
			Items.SelectDay.Visible = False;
		EndIf;
	EndIf;
	
	FillPropertyValues(ThisObject, Parameters, "Period, BeginOfPeriod, EndOfPeriod, LowLimit, CommandName");
	
	InitializePeriodProperties();
	
	YearStartDate = BegOfYear(EndOfPeriod);
	
	ToCustomizeTheFormByLimitingThePeriodOf(ThisObject);
	
	// Determine the name of the active period.
	If BegOfDay(BeginOfPeriod) = BegOfDay(EndOfPeriod) Then
		CurrentItemName = "SelectDay";
	ElsIf BegOfMonth(BeginOfPeriod) = BegOfMonth(EndOfPeriod) Then
		MonthNumber = Month(BeginOfPeriod);
		CurrentItemName = "SelectMonth" + MonthNumber;
	ElsIf BegOfQuarter(BeginOfPeriod) = BegOfQuarter(EndOfPeriod) Then
		MonthNumber = Month(BeginOfPeriod);
		QuarterNumber = Int((MonthNumber + 3) / 3);
		CurrentItemName = "SelectAQuarter" + QuarterNumber;
	ElsIf BegOfYear(BeginOfPeriod) = BegOfYear(EndOfPeriod) Then
		TheNumberOfTheMonthBeginning = Month(BeginOfPeriod);
		TheNumberOfTheMonthEnd  = Month(EndOfPeriod);
		If TheNumberOfTheMonthBeginning <= 3 And TheNumberOfTheMonthEnd <= 6 Then
			CurrentItemName = "SelectHalfYear";
		ElsIf TheNumberOfTheMonthBeginning <= 3 And TheNumberOfTheMonthEnd <= 9 Then
			CurrentItemName = "Select9Months";
		Else
			CurrentItemName = "SelectYear";
		EndIf;
	Else
		CurrentItemName = "SelectYear";
	EndIf;
	
	CurrentItem = Items[CurrentItemName];
	SetTheTransitionImageToTheStandardPeriod();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ClearPeriod(Command)
	
	BeginOfPeriod = Date(1, 1, 1);
	EndOfPeriod = Date(1, 1, 1);
	ToCarryOutAPeriod();
	
EndProcedure

&AtClient
Procedure GoToStandardPeriodOption(Command)
	
	SelectionResult = New Structure("FormOwner, CommandName");
	FillPropertyValues(SelectionResult, ThisObject);
	SelectionResult.Insert("PeriodVariant", PredefinedValue("Enum.PeriodOptions.Standard"));
	SelectionResult.Insert("Event", Command.Name);
	
	Close(SelectionResult);
	
EndProcedure

&AtClient
Procedure GotoPreviousYear(Command)
	
	YearStartDate = BegOfYear(YearStartDate - 1);
	
	ToCustomizeTheFormByLimitingThePeriodOf(ThisObject);
	
	CurrentItem = Items[CurrentItemName];
	
EndProcedure

&AtClient
Procedure GotoNextYear(Command)
	
	YearStartDate = EndOfYear(YearStartDate) + 1;
	
	ToCustomizeTheFormByLimitingThePeriodOf(ThisObject);
	
	CurrentItem = Items[CurrentItemName];
	
EndProcedure

&AtClient
Procedure SelectMonth1(Command)
	
	SelectMonth(1);
	
EndProcedure

&AtClient
Procedure SelectMonth2(Command)
	
	SelectMonth(2);
	
EndProcedure

&AtClient
Procedure SelectMonth3(Command)
	
	SelectMonth(3);
	
EndProcedure

&AtClient
Procedure SelectMonth4(Command)
	
	SelectMonth(4);
	
EndProcedure

&AtClient
Procedure SelectMonth5(Command)
	
	SelectMonth(5);
	
EndProcedure

&AtClient
Procedure SelectMonth6(Command)
	
	SelectMonth(6);
	
EndProcedure

&AtClient
Procedure SelectMonth7(Command)
	
	SelectMonth(7);
	
EndProcedure

&AtClient
Procedure SelectMonth8(Command)
	
	SelectMonth(8);
	
EndProcedure

&AtClient
Procedure SelectMonth9(Command)
	
	SelectMonth(9);
	
EndProcedure

&AtClient
Procedure SelectMonth10(Command)
	
	SelectMonth(10);
	
EndProcedure

&AtClient
Procedure SelectMonth11(Command)
	
	SelectMonth(11);
	
EndProcedure

&AtClient
Procedure SelectMonth12(Command)
	
	SelectMonth(12);
	
EndProcedure

&AtClient
Procedure SelectAQuarter1(Command)
	
	SelectAQuarter(1);
	
EndProcedure

&AtClient
Procedure SelectAQuarter2(Command)
	
	SelectAQuarter(2);
	
EndProcedure

&AtClient
Procedure SelectAQuarter3(Command)
	
	SelectAQuarter(3);
	
EndProcedure

&AtClient
Procedure SelectAQuarter4(Command)
	
	SelectAQuarter(4);
	
EndProcedure

&AtClient
Procedure SelectDay(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("BeginOfPeriod",    BeginOfPeriod);
	FormParameters.Insert("EndOfPeriod",     EndOfPeriod);
	FormParameters.Insert("LowLimit", LowLimit);
	
	NotifyDescription = New NotifyDescription("SelectDayCompletion", ThisObject);
	OpenForm(
		"SettingsStorage.ReportsVariantsStorage.Form.SelectFiscalPeriodDay", 
		FormParameters, 
		ThisObject,
		,
		,
		,
		NotifyDescription);
	
EndProcedure

&AtClient
Procedure SelectHalfYear(Command)
	
	BeginOfPeriod = YearStartDate;
	EndOfPeriod  = EndOfMonth(AddMonth(BeginOfPeriod, 5));
	ToCarryOutAPeriod();
	
EndProcedure

&AtClient
Procedure Select9Months(Command)

	BeginOfPeriod = YearStartDate;
	EndOfPeriod  = Date(Year(YearStartDate), 9 , 30);
	ToCarryOutAPeriod();
	
EndProcedure

&AtClient
Procedure SelectYear(Command)

	BeginOfPeriod = YearStartDate;
	EndOfPeriod  = EndOfYear(YearStartDate);
	ToCarryOutAPeriod();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializePeriodProperties()
	
	If ValueIsFilled(Period.StartDate) Then 
		BeginOfPeriod = Period.StartDate;
	EndIf;
	
	If ValueIsFilled(Period.EndDate) Then 
		EndOfPeriod = Period.EndDate;
	EndIf;
	
	If Not ValueIsFilled(EndOfPeriod) Then
		EndOfPeriod  = EndOfMonth(CurrentSessionDate());
		BeginOfPeriod = BegOfMonth(EndOfPeriod);
	EndIf;
	
	If LowLimit > EndOfPeriod Then
		EndOfPeriod  = EndOfMonth(LowLimit);
		BeginOfPeriod = BegOfMonth(LowLimit);
	EndIf;
	
EndProcedure

&AtClient
Procedure ToCarryOutAPeriod()
	
	EndOfPeriod = EndOfDay(EndOfPeriod);
	Period.StartDate = BeginOfPeriod;
	Period.EndDate = EndOfPeriod;

	SelectionResult = New Structure("FormOwner, Period, BeginOfPeriod, EndOfPeriod");
	FillPropertyValues(SelectionResult, ThisObject);
	
	Close(SelectionResult);
	
EndProcedure 

&AtClient
Procedure SelectMonth(MonthNumber)
	
	BeginOfPeriod = Date(Year(YearStartDate), MonthNumber, 1);
	EndOfPeriod  = EndOfMonth(BeginOfPeriod);
	
	ToCarryOutAPeriod();
	
EndProcedure

&AtClient
Procedure SelectAQuarter(QuarterNumber)
	
	BeginOfPeriod = Date(Year(YearStartDate), 1 + (QuarterNumber - 1) * 3, 1);
	
	EndOfPeriod  = EndOfQuarter(BeginOfPeriod);
	
	ToCarryOutAPeriod();
	
EndProcedure

&AtClient
Procedure SelectDayCompletion(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		BeginOfPeriod = Result.BeginOfPeriod;
		EndOfPeriod  = Result.EndOfPeriod;
		ToCarryOutAPeriod();
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ToCustomizeTheFormByLimitingThePeriodOf(Form)
	
	If Not ValueIsFilled(Form.LowLimit) Then
		Return;
	EndIf;
	
	If Form.LowLimit < Form.YearStartDate
		And Not Form.SelectedYearLimited Then
		Return;
	EndIf;
	
	FirstYear = (BegOfYear(Form.LowLimit) = Form.YearStartDate);
	
	// Select a year.
	Form.SelectedYearLimited = FirstYear;
	
	Form.Items.GoBackOneYearAvailable.Visible   = Not FirstYear;
	Form.Items.GoBackOneYearUnavailable.Visible = FirstYear; // SelectStandardPeriodButtonBackground picture
	
	// Select a quarter.
	TheMinimumQuarter = ?(Not FirstYear, 1, Month(EndOfQuarter(Form.LowLimit)) / 3);
	
	TheNamesOfTheQuartersCumulatively = New Map;
	TheNamesOfTheQuartersCumulatively.Insert(2, "SelectHalfYear");
	TheNamesOfTheQuartersCumulatively.Insert(3, "Select9Months");
	TheNamesOfTheQuartersCumulatively.Insert(4, "SelectYear");
	
	For QuarterNumber = 1 To 4 Do
		
		SelectQuarter = (QuarterNumber >= TheMinimumQuarter);
		
		Form.Items["SelectAQuarter" + QuarterNumber].Enabled = SelectQuarter;
		
		NameCumulativeTotal = TheNamesOfTheQuartersCumulatively[QuarterNumber];
		If NameCumulativeTotal <> Undefined Then
			Form.Items[NameCumulativeTotal].Enabled = SelectQuarter;
		EndIf;
		
	EndDo;
		
	// Select a month.
	MinimumAMonth = ?(Not FirstYear, 1, Month(Form.LowLimit));
	For MonthNumber = 1 To 12 Do
		Form.Items["SelectMonth" + MonthNumber].Enabled = (MonthNumber >= MinimumAMonth);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTheTransitionImageToTheStandardPeriod()
	
	ThePictureOfTheTransitionToTheStandardPeriod = PictureLib.Calendar;
	
	Items.GoToStandardPeriodOption.Picture = ThePictureOfTheTransitionToTheStandardPeriod;
	Items.GoToStandardPeriodOption.Representation = ButtonRepresentation.Picture;
	
EndProcedure

#EndRegion
