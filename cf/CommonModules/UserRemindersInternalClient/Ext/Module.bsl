///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Internal

Procedure HandleOpenOfNotification(Context) Export
	
	If ValueIsFilled(Context.Source) 
		Or UserRemindersClientServer.IsMessageURL(Context.URL) Then
		ReminderParameters = UserRemindersClientServer.ReminderDetails(Context);
		
		ReminderKey = UserRemindersServerCall.GetRecordKeyAndDisableReminder(ReminderParameters);
		
		UserRemindersClient.DeleteRecordFromNotificationsCache(ReminderParameters);
		Notify("Write_UserReminders", New Structure, ReminderKey);
		NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
		FileSystemClient.OpenURL(Context.URL);
	Else
		OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("KeyData", Context));	
	EndIf;
	
EndProcedure

Procedure Remind(Ref, Parameters) Export
	FormParameters = New Structure("Source", Ref);
	OpenForm("InformationRegister.UserReminders.Form.Reminder", 
		FormParameters, Parameters.Form);
EndProcedure

#Region Conversations

Procedure AddConversationsCommands(CommandParameters_, Commands, DefaultCommand) Export
	
	If TypeOf(CommandParameters_.Message) <> Type("CollaborationSystemMessage") Then
		Return;
	EndIf;
	
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	If Not ClientRunParameters.UsedUserReminders Then
		Return;
	EndIf;
		
	RemindersCommands = New CollaborationSystemCommandDescription(New Array, NStr("en = 'Remind…';"));
	RemindersCommands.Picture = ?(ClientRunParameters.ShouldShowRemindersInNotificationCenter, 
		PictureLib.NotificationCenter, PictureLib.Reminder);
	
	AddCommand(RemindersCommands.Command, CommandParameters_, "RemindIn1Hour", NStr("en = 'In 1 hour';"));
	AddCommand(RemindersCommands.Command, CommandParameters_, "RemindIn2Hours", NStr("en = 'In 2 hours';"));
	AddCommand(RemindersCommands.Command, CommandParameters_, "RemindIn3Hours", NStr("en = 'In 4 hours';"));
	AddCommand(RemindersCommands.Command, CommandParameters_, "RemindTomorrowMorning", NStr("en = 'Next morning';"));
	AddCommand(RemindersCommands.Command, CommandParameters_, "RemindAtBeginningOfNextWeek", NStr("en = 'Start of next week';"));
	AddSeparator(RemindersCommands.Command);
	AddCommand(RemindersCommands.Command, CommandParameters_, "ReminderSettings", NStr("en = 'Settings…';"));
	
	Commands.Add(RemindersCommands);

EndProcedure

Procedure CreateReminder(AdditionalParameters) Export
	
	If AdditionalParameters.CommandID = "ReminderSettings" Then
		UserRemindersClient.OpenSettings();
		Return;
	EndIf;
	
	ReminderAlarmTime = CommonClient.SessionDate();
	If AdditionalParameters.CommandID = "RemindIn1Hour" Then
		ReminderAlarmTime = ReminderAlarmTime + 60*60;
	ElsIf AdditionalParameters.CommandID = "RemindIn2Hours" Then
		ReminderAlarmTime = ReminderAlarmTime + 2*60*60;
	ElsIf AdditionalParameters.CommandID = "RemindIn3Hours" Then
		ReminderAlarmTime = ReminderAlarmTime + 3*60*60;
	ElsIf AdditionalParameters.CommandID = "RemindTomorrowMorning" Then
		ReminderAlarmTime = EndOfDay(ReminderAlarmTime) + 9*60*60;
	ElsIf AdditionalParameters.CommandID = "RemindAtBeginningOfNextWeek" Then
		ReminderAlarmTime = EndOfWeek(ReminderAlarmTime) + 9*60*60;
	EndIf;           
	
	UserRemindersClient.RemindInSpecifiedTime(NStr("en = 'Deferred message reminder';"), 
		ReminderAlarmTime, , "e1ccs/data/msg?id=" + AdditionalParameters.MessageID);
		
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure AddCommand(SubmenuCommands, MessageParameters, CommandID, Presentation)
	
	CommandParameters = New Structure;
	CommandParameters.Insert("MessageText", MessageParameters.Message.Text);
	CommandParameters.Insert("MessageID", MessageParameters.Message.Id);
	CommandParameters.Insert("CommandID", CommandID);
	ReminderCommand = New CollaborationSystemCommandDescription(
		New NotifyDescription("CreateReminder", ThisObject, CommandParameters), Presentation);
	SubmenuCommands.Add(ReminderCommand);
	
EndProcedure

Procedure AddSeparator(SubmenuCommands)
	Separator = New CollaborationSystemCommandDescription(Undefined);
	SubmenuCommands.Add(Separator);
EndProcedure

#EndRegion