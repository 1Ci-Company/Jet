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
	
	List.Parameters.SetParameterValue("User", Users.CurrentUser());
	Items.AllReminders.Visible = Users.IsFullUser();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	RowIsSelected = Not Item.CurrentRow = Undefined;
	Items.DeleteButton.Enabled = RowIsSelected;
	Items.ChangeButton.Enabled = RowIsSelected;
EndProcedure

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	Cancel = True;
	DeleteReminder();
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	If Field.Name = "Source" Then
		StandardProcessing = False;
		If ValueIsFilled(Items.List.CurrentData.Source) Then
			ShowValue(, Items.List.CurrentData.Source);
		Else
			ShowMessageBox(, NStr("en = 'Please specify the reminder source.';"));
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Change(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", Items.List.CurrentRow));
EndProcedure

&AtClient
Procedure Delete(Command)
	DeleteReminder();
EndProcedure

&AtClient
Procedure Create(Command)
	OpenForm("InformationRegister.UserReminders.Form.Reminder");
EndProcedure

&AtClient
Procedure AllReminders(Command)
	
	OpenForm("InformationRegister.UserReminders.Form.AllReminders");
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure DisableReminder(ReminderParameters)
	UserRemindersInternal.DisableReminder(ReminderParameters, False, True);
EndProcedure

&AtClient
Procedure DeleteReminder()
	
	DialogButtons = New ValueList;
	DialogButtons.Add(DialogReturnCode.Yes, NStr("en = 'Delete';"));
	DialogButtons.Add(DialogReturnCode.Cancel, NStr("en = 'Do not delete';"));
	NotifyDescription = New NotifyDescription("DeleteReminderCompletion", ThisObject);
	
	ShowQueryBox(NotifyDescription, NStr("en = 'Delete the reminder?';"), DialogButtons);
	
EndProcedure

&AtClient
Procedure DeleteReminderCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;

	RecordKey = Items.List.CurrentRow;
	ReminderParameters = New Structure("User,EventTime,Source");
	FillPropertyValues(ReminderParameters, Items.List.CurrentData);
	
	DisableReminder(ReminderParameters);
	UserRemindersClient.DeleteRecordFromNotificationsCache(ReminderParameters);
	Notify("Write_UserReminders", New Structure, RecordKey);
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
EndProcedure

#EndRegion
