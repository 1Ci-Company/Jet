///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Public

// Returns the annual schedule for the event as of the specified date.
//
// Parameters:
//  EventDate - Date - custom date.
//
// Returns:
//  JobSchedule - schedule.
//
Function AnnualSchedule(EventDate) Export
	Months = New Array;
	Months.Add(Month(EventDate));
	DayInMonth = Day(EventDate);
	
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.Months = Months;
	Schedule.DayInMonth = DayInMonth;
	Schedule.BeginTime = '000101010000' + (EventDate - BegOfDay(EventDate));
	
	Return Schedule;
EndFunction

#EndRegion

#Region Private

// Returns the reminder structure with filled values.
//
// Parameters:
//  DataToFill - Structure - values used to fill reminder parameters.
//  AllAttributes - Boolean - if true, the function also returns attributes related to
//                          reminder time settings.
//
Function ReminderDetails(DataToFill = Undefined, AllAttributes = False) Export
	
	Result = New Structure("User,EventTime,Source,ReminderTime,LongDesc,Id,URL");
	
	If AllAttributes Then 
		Result.Insert("ReminderTimeSettingMethod");
		Result.Insert("ReminderInterval", 0);
		Result.Insert("SourceAttributeName");
		Result.Insert("Schedule");
		Result.Insert("PictureIndex", 2);
		Result.Insert("RepeatAnnually", False);
	EndIf;
	
	If DataToFill <> Undefined Then
		FillPropertyValues(Result, DataToFill);
	EndIf;
	
	If AllAttributes 
		And Result.ReminderTimeSettingMethod <> Undefined
		And Result.ReminderTimeSettingMethod <> PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime") Then
		Result.SourceAttributeName = "";
	EndIf;
	
	Return Result;
EndFunction

Function ServerNotificationName() Export
	
	Return "StandardSubsystems.UserReminders";
	
EndFunction

// Returns a text presentation of a time interval specified in seconds.
//
// Parameters:
//
//  Time - Number - Time interval in seconds.
//
//  FullPresentation	- Boolean - The brief or full presentation of a time interval.
//		For example, if the interval is 1,000,000 seconds::
//		1. Its full presentation is "11 days 13 hours 46 minutes 40 seconds".
//		2. Its brief presentation is "11 days 13 hours".
//  
//  OutputSeconds - Boolean - False if seconds are not required.
//  
// Returns:
//   String - A time interval presentation.
//
Function TimePresentation(Val Time, FullPresentation = True, OutputSeconds = True) Export
	Result = "";
	
	// Presentation of time measurement units in Accusative for quantities: 1, 2-4, and 5-20.
	WeeksPresentation = NStr("en = ';%1 week;;;;%1 weeks';");
	DaysPresentation   = NStr("en = ';%1 day;;;;%1 days';");
	HoursPresentation  = NStr("en = ';%1 hour;;;;%1 hours';");
	MinutesPresentation  = NStr("en = ';%1 minute;;;;%1 minutes';");
	SecondsPresentation = NStr("en = ';%1 second;;;;%1 seconds';");
	
	Time = Number(Time);
	
	If Time < 0 Then
		Time = -Time;
	EndIf;
	
	WeeksCount = Int(Time / 60/60/24/7);
	DaysCount   = Int(Time / 60/60/24);
	HoursCount  = Int(Time / 60/60);
	MinutesCount  = Int(Time / 60);
	SecondsCount = Int(Time);
	
	SecondsCount = SecondsCount - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysCount * 24;
	DaysCount   = DaysCount - WeeksCount * 7;
	
	If Not OutputSeconds Then
		SecondsCount = 0;
	EndIf;
	
	If WeeksCount > 0 And DaysCount+HoursCount+MinutesCount+SecondsCount=0 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(WeeksPresentation, WeeksCount);
	Else
		DaysCount = DaysCount + WeeksCount * 7;
		
		Counter = 0;
		If DaysCount > 0 Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(DaysPresentation, DaysCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If HoursCount > 0 Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(HoursPresentation, HoursCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If (FullPresentation Or Counter < 2) And MinutesCount > 0 Or Time = 0 And Not OutputSeconds Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(MinutesPresentation, MinutesCount) + " ";
			Counter = Counter + 1;
		EndIf;
		
		If OutputSeconds And (FullPresentation Or Counter < 2) And (SecondsCount > 0 Or WeeksCount+DaysCount+HoursCount+MinutesCount = 0) Then
			Result = Result + StringFunctionsClientServer.StringWithNumberForAnyLanguage(SecondsPresentation, SecondsCount);
		EndIf;
		
	EndIf;
	
	Return TrimR(Result);
	
EndFunction

Function FieldNameRemindAboutEvent() Export
	
	Return "RemindAboutEvent";
	
EndFunction

Function FieldNameReminderTimeInterval() Export
	Return "ReminderInterval";
EndFunction

Function NameOfReminderSettingsField() Export
	Return "SettingsOfReminder";
EndFunction

Function ReminderSettingsInForm(Form) Export
	
	AttributesValues = New Structure(NameOfReminderSettingsField());
	FillPropertyValues(AttributesValues, Form);
	Return AttributesValues[NameOfReminderSettingsField()];
	
EndFunction

// Gets a time interval in seconds from text details.
//
// Parameters:
//  StringWithTime - String - text details of time, where numbers are written in digits
//								and units of measure are written as a string. 
//
// Returns:
//  Number - Time interval in seconds.
// 
Function TimeIntervalFromString(Val StringWithTime) Export
	
	If IsBlankString(StringWithTime) Then
		Return 0;
	EndIf;
	
	StringWithTime = Lower(StringWithTime);
	StringWithTime = StrReplace(StringWithTime, Chars.NBSp," ");
	StringWithTime = StrReplace(StringWithTime, ".",",");
	StringWithTime = StrReplace(StringWithTime, "+","");
	
	SubstringWithDigits = "";
	SubstringWithLetters = "";
	
	PreviousCharIsDigit = False;
	HasFractionalPart = False;
	
	Result = 0;
	For Position = 1 To StrLen(StringWithTime) Do
		CurrentCharCode = CharCode(StringWithTime,Position);
		Char = Mid(StringWithTime,Position,1);
		If (CurrentCharCode >= CharCode("0") And CurrentCharCode <= CharCode("9"))
			Or (Char="," And PreviousCharIsDigit And Not HasFractionalPart) Then
			If Not IsBlankString(SubstringWithLetters) Then
				SubstringWithDigits = StrReplace(SubstringWithDigits,",",".");
				Result = Result + ?(IsBlankString(SubstringWithDigits), 1, Number(SubstringWithDigits))
					* ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters);
					
				SubstringWithDigits = "";
				SubstringWithLetters = "";
				
				PreviousCharIsDigit = False;
				HasFractionalPart = False;
			EndIf;
			
			SubstringWithDigits = SubstringWithDigits + Mid(StringWithTime,Position,1);
			
			PreviousCharIsDigit = True;
			If Char = "," Then
				HasFractionalPart = True;
			EndIf;
		Else
			If Char = " " And ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters) = "0" Then
				SubstringWithLetters = "";
			EndIf;
			
			SubstringWithLetters = SubstringWithLetters + Mid(StringWithTime,Position,1);
			PreviousCharIsDigit = False;
		EndIf;
	EndDo;
	
	If Not IsBlankString(SubstringWithLetters) Then
		SubstringWithDigits = StrReplace(SubstringWithDigits,",",".");
		Result = Result + ?(IsBlankString(SubstringWithDigits), 1, Number(SubstringWithDigits))
			* ReplaceUnitOfMeasureByMultiplier(SubstringWithLetters);
	EndIf;
	
	Return Result;
	
EndFunction

// Analyzes the word for compliance with the time unit of measure and if it complies,
// the function returns the number of seconds contained in the time unit of measure.
//
// Parameters:
//  Unit - String - Word being analyzed.
//
// Returns:
//  Number - The number of seconds in the unit. If the unit is unidentified or empty, returns "0".
//
Function ReplaceUnitOfMeasureByMultiplier(Val Unit)
	
	Result = 0;
	Unit = Lower(Unit);
	
	AllowedChars = NStr("en = 'abcdefghijklmnopqrstuvwxyz';"); // 
	ProhibitedChars = StrConcat(StrSplit(Unit, AllowedChars, False), "");
	If ProhibitedChars <> "" Then
		Unit = StrConcat(StrSplit(Unit, ProhibitedChars, False), "");
	EndIf;
	
	WordFormsForWeek = StrSplit(NStr("en = 'wk,w,wee';"), ",", False);
	WordFormsForDay = StrSplit(NStr("en = 'day,d';"), ",", False);
	WordFormsForHour = StrSplit(NStr("en = 'hrs,hr,h,hou';"), ",", False);
	WordFormsForMinute = StrSplit(NStr("en = 'min,m';"), ",", False);
	WordFormsForSecond = StrSplit(NStr("en = 'sec,s';"), ",", False);
	
	FirstThreeChars = Left(Unit,3);
	If WordFormsForWeek.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60*24*7;
	ElsIf WordFormsForDay.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60*24;
	ElsIf WordFormsForHour.Find(FirstThreeChars) <> Undefined Then
		Result = 60*60;
	ElsIf WordFormsForMinute.Find(FirstThreeChars) <> Undefined Then
		Result = 60;
	ElsIf WordFormsForSecond.Find(FirstThreeChars) <> Undefined Then
		Result = 1;
	EndIf;
	
	Return Format(Result,"NZ=0; NG=0");
	
EndFunction

Function EnumPresentationDoNotRemind() Export
	
	Return NStr("en = 'do not remind';");
	
EndFunction

Function EnumPresentationOnOccurrence() Export
	
	Return NStr("en = 'on occurrence';");
	
EndFunction

Function EnumPresentationOnSchedule()
	
	Return NStr("en = 'on schedule';");
	
EndFunction

// Parameters:
//  Reminder - See ReminderDetails
//
Function ReminderTimePresentation(Reminder) Export
	
	If Reminder.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime") Then
		If Reminder.ReminderInterval = 0 Then
			Return EnumPresentationOnOccurrence();
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 before';"), TimePresentation(Reminder.ReminderInterval));
		EndIf;
	ElsIf Reminder.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.AtSpecifiedTime")
		Or Reminder.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToCurrentTime") Then
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1';"), Format(Reminder.ReminderTime, "DLF=DT;"));
	Else
		Return EnumPresentationOnSchedule();
	EndIf;
	
EndFunction

Function IsMessageURL(URL) Export
	Return StrStartsWith(URL, "e1ccs/data/msg?id=");
EndFunction

#EndRegion
