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

// Runs a repeated check of current user reminders.
Procedure Enable() Export
	CheckCurrentReminders();
EndProcedure

// Disables repeated check of current user reminders.
Procedure Disable() Export
	DetachIdleHandler("CheckCurrentReminders");
EndProcedure

// Creates a reminder with the given due time.
//
// Parameters:
//  Text - String - Reminder text;
//  Time - Date - Reminder's due date and time.
//  SubjectOf - AnyRef - Reminder's subject.
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
Procedure RemindInSpecifiedTime(Text, Time, SubjectOf = Undefined, Id = Undefined) Export
	
	Reminder = UserRemindersServerCall.AttachReminder(
		Text, Time, , SubjectOf, Id);
		
	ShowUserNotification(NStr("en = 'Reminder saved';"),,
		Reminder.LongDesc, PictureLib.Reminder,
		UserNotificationStatus.Information, Id);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Creates a reminder for a time relative to the time in the subject.
//
// Parameters:
//  Text - String - Reminder text;
//  Interval - Number - Reminder interval in seconds before the subject attribute's date.
//  SubjectOf - AnyRef - Reminder's subject.
//  AttributeName - String - Name of the subject attribute, for which the reminder period is set.
//
Procedure RemindTillSubjectTime(Text, Interval, SubjectOf, AttributeName) Export
	
	Reminder = UserRemindersServerCall.AttachReminderTillSubjectTime(
		Text, Interval, SubjectOf, AttributeName, False);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Generates a reminder with arbitrary time or execution schedule.
//
// Parameters:
//  Text - String - Reminder text.
//  EventTime - Date - Date and time of the event, which needs a reminder;
//               - JobSchedule - a schedule of a periodic event;
//               - String - Name of the subject's attribute that contains the event time.
//  IntervalTillEvent - Number - time in seconds, prior to which it is necessary to remind of the event time;
//  SubjectOf - AnyRef - Reminder's subject.
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
Procedure Remind(Text, EventTime, IntervalTillEvent = 0, SubjectOf = Undefined, Id = Undefined) Export
	
	Reminder = UserRemindersServerCall.AttachReminder(
		Text, EventTime, IntervalTillEvent, SubjectOf, Id);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Creates an annual reminder with the subject's due date.
//
// Parameters:
//  Text - String - Reminder text;
//  Interval - Number - Reminder interval in seconds before the subject attribute's date.
//  SubjectOf - AnyRef - Reminder's subject.
//  AttributeName - String - Name of the subject attribute, for which the reminder period is set.
//
Procedure RemindOfAnnualSubjectEvent(Text, Interval, SubjectOf, AttributeName) Export
	
	Reminder = UserRemindersServerCall.AttachReminderTillSubjectTime(
		Text, Interval, SubjectOf, AttributeName, True);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// A handler of the form's same-name event.
//
// Parameters:
//   Item - FormField - The form containing the reminder settings elements.
//   Form - ClientApplicationForm - The form containing the reminder settings elements.
//	
Procedure OnChangeReminderSettings(Item, Form) Export
	
	FieldNameReminderTimeInterval = UserRemindersClientServer.FieldNameReminderTimeInterval();
	
	If Item.Name = FieldNameReminderTimeInterval Then
		SettingsOfReminder = ReminderSettingsInForm(Form);
		If Form[Item.Name] = UserRemindersClientServer.EnumPresentationDoNotRemind() Then
			ToRemind = False;
		Else
			ReminderInterval = GetTimeIntervalFromString(Form[Item.Name]);
			If Form[Item.Name] <> UserRemindersClientServer.EnumPresentationOnOccurrence() Then
				Form[Item.Name] = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 before';"), TimePresentation(ReminderInterval, , ReminderInterval <> 0));
			EndIf;
			SettingsOfReminder.ReminderInterval = ReminderInterval;
			ToRemind = True;
		EndIf;
		Form[UserRemindersClientServer.FieldNameRemindAboutEvent()] = ToRemind;
	EndIf;
	
EndProcedure

// A handler of the form's same-name event.
//
// Parameters:
//   Form - ClientApplicationForm - The form containing the reminder settings elements.
//   EventName  - String
//   Parameter    - See UserRemindersClientServer.ReminderDetails
//   Source    - ClientApplicationForm
//               - Arbitrary - Event source.
//	
Procedure NotificationProcessing(Form, EventName, Parameter, Source) Export
	
	If EventName = "Write_UserReminders" Then
		SettingsOfReminder = ReminderSettingsInForm(Form);

		If ValueIsFilled(Parameter) 
			And Parameter.Source = SettingsOfReminder.SubjectOf
			And Parameter.SourceAttributeName = SettingsOfReminder.NameOfAttributeWithEventDate Then
				
			FieldNameReminderTimeInterval = UserRemindersClientServer.FieldNameReminderTimeInterval();
			ReminderInterval = Parameter.ReminderInterval;
			If ReminderInterval > SettingsOfReminder.ReminderInterval Then
				SettingsOfReminder.ReminderInterval = ReminderInterval;
				Form[FieldNameReminderTimeInterval] = UserRemindersClientServer.ReminderTimePresentation(Parameter);
				Form[UserRemindersClientServer.FieldNameRemindAboutEvent()] = True;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Opens the reminder settings form.
Procedure OpenSettings() Export
	OpenForm("InformationRegister.UserReminders.Form.Settings");
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	If Not CommonClient.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ReminderSettings = StandardSubsystemsClient.ClientParametersOnStart().ReminderSettings;
	If ReminderSettings.UseReminders Then
		SettingsOnClient().CurrentRemindersList = ReminderSettings.CurrentRemindersList;
		AttachIdleHandler("CheckCurrentReminders", 60, True); // 60 seconds after starting the client.
	EndIf;
	
EndProcedure

// See StandardSubsystemsClient.OnReceiptServerNotification.
Procedure OnReceiptServerNotification(NameOfAlert, Result) Export
	
	If NameOfAlert <> UserRemindersClientServer.ServerNotificationName() Then
		Return;
	EndIf;
	
	Result = Result; // See UserRemindersInternal.NewModifiedReminders
	
	For Each Reminder In Result.Trash Do
		DeleteRecordFromNotificationsCache(Reminder);
	EndDo;
	
	For Each Reminder In Result.Added1 Do
		UpdateRecordInNotificationsCache(Reminder);
	EndDo;
	
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

#EndRegion

#Region Private

// Returns:
//  Structure:
//   * CurrentRemindersList - See UserRemindersInternal.CurrentUserRemindersList
//
Function SettingsOnClient()
	
	ParameterName = "StandardSubsystems.UserReminders";
	Settings = ApplicationParameters[ParameterName];
	
	If Settings = Undefined Then
		Settings = New Structure;
		Settings.Insert("CurrentRemindersList", New Array);
		ApplicationParameters[ParameterName] = Settings;
	EndIf;
	
	Return Settings;
	
EndFunction

Procedure ResetCurrentNotificationsCheckTimer() Export
	DetachIdleHandler("CheckCurrentReminders");
	AttachIdleHandler("CheckCurrentReminders", 0.1, True);
EndProcedure

Procedure OpenNotificationForm() Export
	
	// The form is stored in a variable to prevent opening its duplicates and make fewer server calls.
	// 
	ParameterName = "StandardSubsystems.NotificationForm";
	If ApplicationParameters[ParameterName] = Undefined Then
		NotificationFormName = "InformationRegister.UserReminders.Form.NotificationForm";
		ApplicationParameters.Insert(ParameterName, GetForm(NotificationFormName));
	EndIf;
	NotificationForm = ApplicationParameters[ParameterName];
	NotificationForm.Open();

EndProcedure

// Returns cached notifications for the current user, excluding the ones that are not due yet.
//
// Parameters:
//  TimeOfClosest - Date - this parameter returns time of the closest future reminder. If
//                           the closest reminder is outside the cache selection, Undefined returns.
//
// Returns: 
//   See UserRemindersInternal.CurrentUserRemindersList
//
Function GetCurrentNotifications(TimeOfClosest = Undefined) Export
	
	NotificationsTable = SettingsOnClient().CurrentRemindersList;
	Result = New Array;
	
	TimeOfClosest = Undefined;
	
	For Each Notification In NotificationsTable Do
		If Notification.ReminderTime <= CommonClient.SessionDate() Then
			Result.Add(Notification);
		Else                                                           
			If TimeOfClosest = Undefined Then
				TimeOfClosest = Notification.ReminderTime;
			Else
				TimeOfClosest = Min(TimeOfClosest, Notification.ReminderTime);
			EndIf;
		EndIf;
	EndDo;		
	
	Return Result;
	
EndFunction

// Updates a record in the current user's reminder cache.
Procedure UpdateRecordInNotificationsCache(NotificationParameters) Export
	NotificationsCache = SettingsOnClient().CurrentRemindersList;
	Record = FindRecordInNotificationsCache(NotificationsCache, NotificationParameters);
	If Record <> Undefined Then
		FillPropertyValues(Record, NotificationParameters);
	Else
		NotificationsCache.Add(NotificationParameters);
	EndIf;
EndProcedure

// Deletes a record from the current user's reminder cache.
Procedure DeleteRecordFromNotificationsCache(NotificationParameters) Export
	NotificationsCache = SettingsOnClient().CurrentRemindersList;
	Record = FindRecordInNotificationsCache(NotificationsCache, NotificationParameters);
	If Record <> Undefined Then
		NotificationsCache.Delete(NotificationsCache.Find(Record));
	EndIf;
EndProcedure

// Returns a record from the current user's reminder cache.
//
// Parameters:
//  NotificationsCache - See UserRemindersInternal.CurrentUserRemindersList
//  NotificationParameters - Structure:
//   * Source - DefinedType.ReminderSubject
//   * EventTime - Date
//
Function FindRecordInNotificationsCache(NotificationsCache, NotificationParameters)
	For Each Record In NotificationsCache Do
		If Record.Source = NotificationParameters.Source
		   And Record.EventTime = NotificationParameters.EventTime Then
			Return Record;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

// Gets a time interval from a string and returns its text presentation.
//
// Parameters:
//  TimeAsString - String - text details of time, where numbers are written in digits
//							and units of measure are written as a string.
//
// Returns:
//  String - an arranged time presentation.
//
Function FormatTime(TimeAsString) Export
	Return TimePresentation(GetTimeIntervalFromString(TimeAsString));
EndFunction

// See UserRemindersClientServer.TimePresentation
Function TimePresentation(Val Time, FullPresentation = True, OutputSeconds = True) Export
	
	Return UserRemindersClientServer.TimePresentation(Time, FullPresentation, OutputSeconds);
	
EndFunction

// See UserRemindersClientServer.TimeIntervalFromString
Function GetTimeIntervalFromString(Val StringWithTime) Export
	
	Return UserRemindersClientServer.TimeIntervalFromString(StringWithTime);
	
EndFunction

Function ReminderSettingsInForm(Form)
	
	Return UserRemindersClientServer.ReminderSettingsInForm(Form);
	
EndFunction

#EndRegion
