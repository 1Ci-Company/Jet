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

// Generates a reminder with arbitrary time or execution schedule.
//
// Parameters:
//  Text - String - Reminder text;
//  EventTime - Date - Date and time of the event, which needs a reminder.
//               - JobSchedule - Repeated event schedule.
//               - String - Name of the subject's attribute that contains the event time.
//  IntervalTillEvent - Number - time in seconds, prior to which it is necessary to remind of the event time;
//  SubjectOf - AnyRef - Reminder's subject.
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
Procedure SetReminder(Text, EventTime, IntervalTillEvent = 0, SubjectOf = Undefined, Id = Undefined) Export
	UserRemindersInternal.AttachArbitraryReminder(
		Text, EventTime, IntervalTillEvent, SubjectOf, Id);
EndProcedure

// Returns a list of reminders for the current user.
//
// Parameters:
//  SubjectOf - AnyRef
//          - Array - Reminder subject(s).
//  Id - String - Describes the reminder's subject. For example, "Birthday".
//
// Returns:
//    Array - Reminder collection as structures with fields repeating the fields of the UserReminders  information register.
//
Function FindReminders(Val SubjectOf = Undefined, Id = Undefined) Export
	
	QueryText =
	"SELECT
	|	*
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND &IsFilterBySubject
	|	AND &FilterByID";
	
	IsFilterBySubject = "TRUE";
	If ValueIsFilled(SubjectOf) Then
		IsFilterBySubject = "UserReminders.Source IN(&SubjectOf)";
	EndIf;
	
	FilterByID = "TRUE";
	If ValueIsFilled(Id) Then
		FilterByID = "UserReminders.Id = &Id";
	EndIf;
	
	QueryText = StrReplace(QueryText, "&IsFilterBySubject", IsFilterBySubject);
	QueryText = StrReplace(QueryText, "&FilterByID", FilterByID);
	
	Query = New Query(QueryText);
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("SubjectOf", SubjectOf);
	Query.SetParameter("Id", Id);
	
	RemindersTable = Query.Execute().Unload();
	RemindersTable.Sort("ReminderTime");
	
	Return Common.ValueTableToArray(RemindersTable);
	
EndFunction

// Deletes a user reminder.
//
// Parameters:
//  Reminder - Structure - Collection element returned by FindReminders().
//
Procedure DeleteReminder(Reminder) Export
	UserRemindersInternal.DisableReminder(Reminder, False);
EndProcedure

// Checks attribute changes for the subjects the user subscribed to.
// If necessary, changes the reminder time.
//
// Parameters:
//  Subjects - Array - Subjects whose reminder dates must be updated.
// 
Procedure UpdateRemindersForSubjects(Subjects) Export
	
	UserRemindersInternal.UpdateRemindersForSubjects(Subjects);
	
EndProcedure

// Checks if user reminders are enabled.
// 
// Returns:
//  Boolean - User reminders enablement flag.
//
Function UsedUserReminders() Export
	
	Return GetFunctionalOption("UseUserReminders") 
		And AccessRight("Update", Metadata.InformationRegisters.UserReminders);
	
EndFunction

// A handler of the form's same-name event. Places reminder settings elements on the form.
//
// Parameters:
//  Form - ClientApplicationForm - The form the reminder settings elements should be placed in.
//  PlacementParameters - See PlacementParameters
//
Procedure OnCreateAtServer(Form, PlacementParameters) Export
	
	UserRemindersInternal.OnCreateAtServer(Form, PlacementParameters);
	
EndProcedure

// Determines the location parameters of placing reminder settings on form.
// 
// Returns:
//  Structure:
//   * Group - FormGroup - The location of the reminder settings items.
//   * NameOfAttributeWithEventDate - String - The attribute associated with the event reminder.
//   * ReminderInterval - Number - The default reminder interval. By default, "0".
//   * ShouldAddFlag - Boolean - If set to True, a checkbox for toggling the reminder is displayed next to the interval field. 
//                                If set to False, users can toggle the reminder in the interval choice list.
//                                By default, False.
//                                
//
Function PlacementParameters() Export
	
	Return UserRemindersInternal.PlacementParameters();
	
EndFunction

// A handler of the form's same-name event. Updates the form elements associated with the reminder setting.
//
// Parameters:
//  Form - ClientApplicationForm - The form the reminder settings elements should be placed in.
//  CurrentObject       - CatalogObject
//                      - DocumentObject
//                      - ChartOfCharacteristicTypesObject
//                      - ChartOfAccountsObject
//                      - ChartOfCalculationTypesObject
//                      - BusinessProcessObject
//                      - TaskObject
//                      - ExchangePlanObject - Reminder's subject.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	UserRemindersInternal.OnReadAtServer(Form, CurrentObject);
	
EndProcedure

// A handler of the form's same-name even. Sets a topic reminder when the object is written on the form.
//
// Parameters:
//   Form - ClientApplicationForm - The form containing the reminder settings elements.
//   Cancel - Boolean - shows whether writing is canceled.
//   CurrentObject  - CatalogObject
//                  - DocumentObject
//                  - ChartOfCharacteristicTypesObject
//                  - ChartOfAccountsObject
//                  - ChartOfCalculationTypesObject
//                  - BusinessProcessObject
//                  - TaskObject
//                  - ExchangePlanObject - Reminder's subject.
//   WriteParameters - Structure
//   ReminderText - String - The reminder text. If empty, the reminder's topic is displayed.
//                               
//  
Procedure OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters, ReminderText = "") Export
	
	UserRemindersInternal.OnWriteAtServer(Form, Cancel, CurrentObject, WriteParameters, ReminderText);
	
EndProcedure

#EndRegion
