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
	
	ReminderMethod = ?(UserRemindersInternal.ShouldShowRemindersInNotificationCenter(), 1, 0);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RemindInNotificationCenter_OnChange(Item)

	Modified = True;

EndProcedure

&AtClient
Procedure RemindInPopupWindowOnChange(Item)
	Modified = True;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	ShouldSaveSettings();
	Close();
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	CheckOnTheServer();
	RefreshReusableValues();
	UserRemindersClient.OpenNotificationForm();
	ServerNotificationsClient.AttachServerNotificationReceiptCheckHandler(, True);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckOnTheServer()
	
	Settings = New Structure;
	Settings.Insert("ShouldShowRemindersInNotificationCenter", ReminderMethod = 1);
	SpecifySettingsAtServer(Settings);
	Modified = False;
	UserReminders.SetReminder(NStr("en = 'My reminder';"), CurrentSessionDate() - 15);
	
EndProcedure

&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export

	ShouldSaveSettings();
	Close();
	
EndProcedure

&AtClient
Procedure ShouldSaveSettings()
	
	Settings = New Structure;
	Settings.Insert("ShouldShowRemindersInNotificationCenter", ReminderMethod = 1);
	SpecifySettingsAtServer(Settings);
	RefreshReusableValues();
	Modified = False;
	
EndProcedure

&AtServerNoContext
Procedure SpecifySettingsAtServer(Settings)
	For Each Setting In Settings Do
		Common.CommonSettingsStorageSave("UserCommonSettings", Setting.Key, Setting.Value);
	EndDo;
EndProcedure

#EndRegion