///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// Creates a reminder for a time relative to the time in the subject.
Function AttachReminderTillSubjectTime(Text, Interval, SubjectOf, AttributeName, RepeatAnnually = False) Export
	
	Return UserRemindersInternal.AttachReminderTillSubjectTime(
		Text, Interval, SubjectOf, AttributeName, RepeatAnnually);
	
EndFunction

Function AttachReminder(Text, EventTime, IntervalTillEvent = 0, SubjectOf = Undefined, Id = Undefined) Export
	
	Return UserRemindersInternal.AttachArbitraryReminder(
		Text, EventTime, IntervalTillEvent, SubjectOf, Id);
	
EndFunction

Function GetRecordKeyAndDisableReminder(ReminderParameters) Export
	RecordKey = InformationRegisters.UserReminders.CreateRecordKey(ReminderParameters);
	UserRemindersInternal.DisableReminder(ReminderParameters, True, True);
	Return RecordKey;
EndFunction

#EndRegion
