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
	
	If Common.IsWebClient() Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	FillRepeatedReminderPeriod();
	
	If Common.IsMobileClient() Then
		Items.RepeatedNotificationPeriod.Visible = False;
		Items.SnoozeButton.Title = NStr("en = 'Snooze';");
		Items.SnoozeButton.DefaultButton = True;
		Items.OpenButton.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
		Items.StopButton.LocationInCommandBar = ButtonLocationInCommandBar.InAdditionalSubmenu;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	RepeatedNotificationPeriod = NStr("en = 'in 15 minutes';");
	RepeatedNotificationPeriod = UserRemindersClient.FormatTime(RepeatedNotificationPeriod);
	UpdateRemindersTable();
	UpdateTimeInRemindersTable();
	
	If StandardSubsystemsClient.ClientRunParameters().ShouldShowRemindersInNotificationCenter Then
		Cancel = True;
	Else
		Activate();
	EndIf;

EndProcedure

&AtClient
Procedure OnReopen()

	UpdateRemindersTable();
	UpdateTimeInRemindersTable();
	CurrentItem = Items.RepeatedNotificationPeriod;
	Activate();

EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	DeferActiveReminders();
	UserRemindersClient.ResetCurrentNotificationsCheckTimer();
	
	// Forced disabling of handlers is necessary as the form is not exported from the memory.
	DetachIdleHandler("UpdateRemindersTable");
	DetachIdleHandler("UpdateTimeInRemindersTable");
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RepeatedNotificationPeriodOnChange(Item)
	RepeatedNotificationPeriod = UserRemindersClient.FormatTime(RepeatedNotificationPeriod);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReminders

&AtClient
Procedure RemindersSelection(Item, RowSelected, Field, StandardProcessing)
	OpenReminder();
EndProcedure

&AtClient
Procedure RemindersOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
		
	Source = Item.CurrentData.Source;
	
	HasSource = ValueIsFilled(Source);
	Items.RemindersContextMenuOpen.Enabled = HasSource;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Change(Command)
	EditReminder();
EndProcedure

&AtClient
Procedure OpenCommand(Command)
	OpenReminder();
EndProcedure

&AtClient
Procedure Snooze(Command)
	DeferActiveReminders();
EndProcedure

&AtClient
Procedure Dismiss(Command)
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	
	For Each RowIndex In Items.Reminders.SelectedRows Do
		RowData = Reminders.FindByID(RowIndex);
	
		ReminderParameters = UserRemindersClientServer.ReminderDetails(RowData);
		
		DisableReminder(ReminderParameters);
		UserRemindersClient.DeleteRecordFromNotificationsCache(RowData);
	EndDo;
	
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
	UpdateRemindersTable();
EndProcedure

&AtClient
Procedure OpenSettings(Command)
	UserRemindersClient.OpenSettings();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure AttachReminder(ReminderParameters)
	UserRemindersInternal.AttachReminder(ReminderParameters, True, True);
EndProcedure

&AtServerNoContext
Procedure DisableReminder(ReminderParameters)
	UserRemindersInternal.DisableReminder(ReminderParameters, , True);
EndProcedure

&AtClient
Procedure UpdateRemindersTable() 

	DetachIdleHandler("UpdateRemindersTable");
	
	TimeOfClosest = Undefined;
	RemindersTable = UserRemindersClient.GetCurrentNotifications(TimeOfClosest);
	For Each Reminder In RemindersTable Do
		FoundRows = Reminders.FindRows(New Structure("Source,EventTime", Reminder.Source, Reminder.EventTime));
		If FoundRows.Count() > 0 Then
			FillPropertyValues(FoundRows[0], Reminder, , "ReminderTime");
		Else
			NewRow = Reminders.Add();
			FillPropertyValues(NewRow, Reminder);
		EndIf;
	EndDo;
	
	RowsToDelete = New Array;
	For Each Reminder In Reminders Do
		If ValueIsFilled(Reminder.Source) And IsBlankString(Reminder.SourceAsString) Then
			UpdateSubjectsPresentations();
		EndIf;
			
		RowFound = False;
		For Each CacheRow In RemindersTable Do
			If CacheRow.Source = Reminder.Source And CacheRow.EventTime = Reminder.EventTime Then
				RowFound = True;
				Break;
			EndIf;
		EndDo;
		If Not RowFound Then 
			RowsToDelete.Add(Reminder);
		EndIf;
	EndDo;
	
	For Each String In RowsToDelete Do
		Reminders.Delete(String);
	EndDo;
	
	If StandardSubsystemsClient.ClientRunParameters().ShouldShowRemindersInNotificationCenter Then

		RefsToMessages = New Array;
		MessagesReminders = New Map;
		For Each Reminder In Reminders Do
			RefsToMessages.Add(Reminder.URL);
			MessagesReminders.Insert(Reminder.URL, Reminder);
		EndDo;
		
		RefsPresentations = GetURLsPresentations(RefsToMessages);
		For Each RepresentationOfTheReference In RefsPresentations Do
			Reminder = MessagesReminders[RepresentationOfTheReference.URL];
			Context = New Structure("User,EventTime,Source,ReminderTime,LongDesc");
			FillPropertyValues(Context, Reminder);
			Context.Insert("URL", RepresentationOfTheReference.URL);
			
			NotifyDescription = New NotifyDescription("HandleOpenOfNotification", UserRemindersInternalClient, Context);
			
			ShowUserNotification(
				Reminder.LongDesc, NotifyDescription,
				RepresentationOfTheReference.Text, RepresentationOfTheReference.Picture,
				UserNotificationStatus.Important,
				Reminder.URL);
			
		EndDo;
		
		Cancel = True;
		Return;
	EndIf;
	
	SetVisibility1();
	
	Interval = 15; // Update the table at least once every 15 seconds.
	If TimeOfClosest <> Undefined Then 
		Interval = Max(Min(Interval, TimeOfClosest - CommonClient.SessionDate()), 1); 
	EndIf;
	
	AttachIdleHandler("UpdateRemindersTable", Interval, True);
	
EndProcedure

&AtServer
Procedure UpdateSubjectsPresentations()
	
	For Each Reminder In Reminders Do
		If ValueIsFilled(Reminder.Source) Then
			Reminder.SourceAsString = Common.SubjectString(Reminder.Source);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function ModuleNumbers(Number)
	If Number >= 0 Then
		Return Number;
	Else
		Return -Number;
	EndIf;
EndFunction

&AtClient
Procedure UpdateTimeInRemindersTable()
	DetachIdleHandler("UpdateTimeInRemindersTable");
	
	For Each TableRow In Reminders Do
		TimePresentation = NStr("en = 'n/a';");
		
		If ValueIsFilled(TableRow.EventTime) Then
			CurrentDate = CommonClient.SessionDate();
			Time = CurrentDate - TableRow.EventTime;
			If TableRow.EventTime - BegOfDay(TableRow.EventTime) < 60 // Events for the whole day.
				And BegOfDay(TableRow.EventTime) = BegOfDay(CurrentDate) Then
					TimePresentation = NStr("en = 'today';");
			Else
				If ModuleNumbers(Time) > 60*60*24 Then
					Time = BegOfDay(CommonClient.SessionDate()) - BegOfDay(TableRow.EventTime);
				EndIf;
				TimePresentation = TimeIntervalPresentation(Time);
			EndIf;
		EndIf;
		
		If TableRow.EventTimeString <> TimePresentation Then
			TableRow.EventTimeString = TimePresentation;
		EndIf;
		
	EndDo;
	
	AttachIdleHandler("UpdateTimeInRemindersTable", 5, True);
EndProcedure

&AtClient
Procedure DeferActiveReminders()
	TimeInterval = UserRemindersClient.GetTimeIntervalFromString(RepeatedNotificationPeriod);
	If TimeInterval = 0 Then
		TimeInterval = 5*60; // 5 minutes.
	EndIf;
	For Each TableRow In Reminders Do
		TableRow.ReminderTime = CommonClient.SessionDate() + TimeInterval;
		
		ReminderParameters = UserRemindersClientServer.ReminderDetails(TableRow);
		
		AttachReminder(ReminderParameters);
		UserRemindersClient.UpdateRecordInNotificationsCache(TableRow);
	EndDo;
	UpdateRemindersTable();
EndProcedure

&AtClient
Procedure OpenReminder()
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	Source = Items.Reminders.CurrentData.Source;
	If ValueIsFilled(Source) Then
		ShowValue(, Source);
	ElsIf UserRemindersClientServer.IsMessageURL(
		Items.Reminders.CurrentData.Id) Then
		FileSystemClient.OpenURL(Items.Reminders.CurrentData.URL);
	Else
		EditReminder();
	EndIf;
EndProcedure

&AtClient
Procedure EditReminder()
	ReminderParameters = New Structure("User,Source,EventTime");
	FillPropertyValues(ReminderParameters, Items.Reminders.CurrentData);
	
	OpenForm("InformationRegister.UserReminders.Form.Reminder", 
		New Structure("KeyData", ReminderParameters));
EndProcedure

&AtClient
Procedure SetVisibility1()
	HasTableData = Reminders.Count() > 0;
	
	If Not HasTableData And IsOpen() Then
		Close();
	EndIf;
	
	Items.ButtonsPanel.Enabled = HasTableData;
EndProcedure

&AtServer
Procedure FillRepeatedReminderPeriod()
	
	Items.RepeatedNotificationPeriod.ChoiceList.Clear();
	SubsystemSettings = UserRemindersInternal.SubsystemSettings();
	TimeIntervals = SubsystemSettings.StandardIntervals;
	
	For Each Interval In TimeIntervals Do
		Items.RepeatedNotificationPeriod.ChoiceList.Add(StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'in %1';"), Interval));
	EndDo;
	
EndProcedure	

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_UserReminders" Then 
		UpdateRemindersTable();
	EndIf;
EndProcedure

&AtClient
Function TimeIntervalPresentation(Val TimeCount)
	Result = "";
	
	WeeksPresentation = NStr("en = ';%1 week;;;;%1 weeks';");
	DaysPresentation   = NStr("en = ';%1 day;;;;%1 days';");
	HoursPresentation  = NStr("en = ';%1 hour;;;;%1 hours';");
	MinutesPresentation  = NStr("en = ';%1 minute;;;;%1 minutes';");
	
	TimeCount = Number(TimeCount);
	CurrentDate = CommonClient.SessionDate();
	
	EventCame = True;
	TodayEvent = BegOfDay(CurrentDate - TimeCount) = BegOfDay(CurrentDate);
	TemplateOfPresentation = NStr("en = '%1 ago';");
	If TimeCount < 0 Then
		TemplateOfPresentation = NStr("en = 'in %1';");
		TimeCount = -TimeCount;
		EventCame = False;
	EndIf;
	
	WeeksCount = Int(TimeCount / 60/60/24/7);
	DaysCount   = Int(TimeCount / 60/60/24);
	HoursCount  = Int(TimeCount / 60/60);
	MinutesCount  = Int(TimeCount / 60);
	SecondsCount = Int(TimeCount);
	
	SecondsCount = SecondsCount - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysCount * 24;
	DaysCount   = DaysCount - WeeksCount * 7;
	
	If WeeksCount > 4 Then
		If EventCame Then
			Return NStr("en = 'long ago';");
		Else
			Return NStr("en = 'a long way from now';");
		EndIf;
		
	ElsIf WeeksCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(WeeksPresentation, WeeksCount);
	ElsIf WeeksCount > 0 Then
		Result = NStr("en = 'a week';");
		
	ElsIf DaysCount > 1 Then
		If BegOfDay(CurrentDate) - BegOfDay(CurrentDate - TimeCount) = 60*60*24 * 2 Then
			If EventCame Then
				Return NStr("en = 'the day before yesterday';");
			Else
				Return NStr("en = 'the day after tomorrow';");
			EndIf;
		Else
			Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(DaysPresentation, DaysCount);
		EndIf;
	ElsIf HoursCount + DaysCount * 24 > 3 And Not TodayEvent Then
			If EventCame Then
				Return NStr("en = 'yesterday';");
			Else
				Return NStr("en = 'tomorrow';");
			EndIf;
	ElsIf DaysCount > 0 Then
		Result = NStr("en = 'a day';");
	ElsIf HoursCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(HoursPresentation, HoursCount);
	ElsIf HoursCount > 0 Then
		Result = NStr("en = 'an hour';");
		
	ElsIf MinutesCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(MinutesPresentation, MinutesCount);
	ElsIf MinutesCount > 0 Then
		Result = NStr("en = 'a minute';");
		
	Else
		Return NStr("en = 'now';");
	EndIf;
	
	Result = StringFunctionsClientServer.SubstituteParametersToString(TemplateOfPresentation, Result);
	
	Return Result;
EndFunction

#EndRegion
