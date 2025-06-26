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

#Region Variables

Var OldRecords, ReminderPeriodBoundary;

#EndRegion

#Region EventHandlers

// ACC:75-off Notify about each reminder change.
Procedure BeforeWrite(Cancel, Replacing)
	
	If Not ShouldDisableClientNotifications(ThisObject) Then
		ReminderPeriodBoundary = CurrentSessionDate()
			+ UserRemindersInternal.ReminderTimeReserveForCache();
		OldRecords = OldRecords(ThisObject, Cancel, Replacing);
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record In ThisObject Do
		Record.SourcePresentation = Common.SubjectString(Record.Source);
		If Record.ReminderTimeSettingMethod <> Enums.ReminderTimeSettingMethods.RelativeToSubjectTime Then
			Record.SourceAttributeName = "";
		EndIf;
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If Not ShouldDisableClientNotifications(ThisObject) Then
		SendClientNotification(OldRecords, ThisObject, Cancel, Replacing);
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure
// ACC:75-on

#EndRegion

#Region Private

Function ShouldDisableClientNotifications(CurrentObject)
	
	Return CurrentObject.WriteDataHistory.AdditionalDataFieldsPresentations.Get("ShouldDisableClientNotifications") <> Undefined
	    Or CurrentObject.AdditionalProperties.Property("ShouldDisableClientNotifications");

EndFunction

Procedure SendClientNotification(OldRecords, NewRecords, Cancel, Replacing)
	
	If Cancel
	 Or Not GetFunctionalOption("UseUserReminders") Then
		Return;
	EndIf;
	
	FieldList = "User, EventTime, Source, ReminderTime, LongDesc, Id";
	If Replacing Then
		ModifiedRecords = ModifiedRecords(OldRecords, NewRecords, FieldList);
	Else
		ModifiedRecords = ThisObject;
	EndIf;
	
	UsersReminders = New Map;
	For Each Record In ModifiedRecords Do
		If Record.ReminderTime > ReminderPeriodBoundary Then
			Continue;
		EndIf;
		Reminders = UsersReminders.Get(Record.User);
		If Reminders = Undefined Then
			Reminders = UserRemindersInternal.NewModifiedReminders();
			UsersReminders.Insert(Record.User, Reminders);
		EndIf;
		Properties = New Structure(FieldList);
		FillPropertyValues(Properties, Record);
		Properties.Insert("PictureIndex", 2);
		Properties.Insert("URL", UserRemindersInternal.ReminderURL(Properties));
		If Not Replacing Or Record.LineChangeType = 1 Then
			Reminders.Added1.Add(Properties);
		Else
			Reminders.Trash.Add(Properties);
		EndIf;
	EndDo;
	
	NameOfAlert = UserRemindersClientServer.ServerNotificationName();
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	
	For Each KeyAndValue In UsersReminders Do
		IBUser = Users.FindByReference(KeyAndValue.Key);
		If IBUser = Undefined Then
			Continue;
		EndIf;
		SMSMessageRecipients = New Map;
		SMSMessageRecipients.Insert(IBUser.UUID,
			CommonClientServer.ValueInArray("*"));
		ServerNotifications.SendServerNotification(NameOfAlert,
			KeyAndValue.Value, SMSMessageRecipients);
	EndDo;
	
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
EndProcedure

Function OldRecords(RecordSet, Cancel, Replacing)
	
	If Cancel
	 Or Not Replacing
	 Or Not GetFunctionalOption("UseUserReminders") Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderTime AS ReminderTime,
	|	Reminders.LongDesc AS LongDesc,
	|	Reminders.Id AS Id,
	|	-1 AS LineChangeType
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTime <= &ReminderPeriodBoundary
	|	AND &FilterCriterion";
	
	Query.SetParameter("ReminderPeriodBoundary", ReminderPeriodBoundary);
	
	FilterCriterion = "TRUE";
	For Each FilterElement In RecordSet.Filter Do
		If Not FilterElement.Use Then
			Continue;
		EndIf;
		FilterCriterion = FilterCriterion + "
		|	AND " + FilterElement.Name + " = &" + FilterElement.Name;
		Query.SetParameter(FilterElement.Name, FilterElement.Value);
	EndDo;
	Query.Text = StrReplace(Query.Text, "&FilterCriterion", FilterCriterion);
	
	Return Query.Execute().Unload();
	
EndFunction

Function ModifiedRecords(OldRecords, NewRecords, FieldList)
	
	For Each Record In NewRecords Do
		If Record.ReminderTime > ReminderPeriodBoundary Then
			Continue;
		EndIf;
		NewRow = OldRecords.Add();
		FillPropertyValues(NewRow, Record);
		NewRow.LineChangeType = 1;
	EndDo;
	
	OldRecords.GroupBy(FieldList, "LineChangeType");
	
	Rows = OldRecords.FindRows(New Structure("LineChangeType", 0));
	For Each String In Rows Do
		OldRecords.Delete(String);
	EndDo;
	
	Return OldRecords;
	
EndFunction

#EndRegion


#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf