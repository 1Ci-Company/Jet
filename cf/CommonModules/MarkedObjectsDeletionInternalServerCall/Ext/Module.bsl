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

// Set the automatic deletion of marked objects.
//
// Parameters:
//   Changes - Structure:
//   * Use - Boolean - indicates whether a scheduled job is used
//   * Schedule - JobSchedule - sets the scheduled job schedule.
//
// Returns:
//   Boolean
//
Procedure SetDeleteOnScheduleMode(Changes) Export

	If Not Users.IsFullUser(,, False) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation.';"), ErrorCategory.AccessViolation);
	EndIf;

	Parameters = New Structure;
	Parameters.Insert("Use", Changes.Use);
	Parameters.Insert("Schedule", Changes.Schedule);
	JobID = ScheduledJobsServer.UUID(
		Metadata.ScheduledJobs.MarkedObjectsDeletion);
	ScheduledJobsServer.ChangeJob(JobID, Parameters);

EndProcedure

// Returns the scheduled job schedule.
//
// Returns:
//   Structure:
//   * DetailedDailySchedules - Array
//   * Use - Boolean
//   * DataSeparationEnabled - Boolean
//
Function ModeDeleteOnSchedule() Export
	Result = New Structure;
	Result.Insert("Use", False);
	Result.Insert("Schedule", CommonClientServer.ScheduleToStructure(
		New JobSchedule));
	Result.Insert("DataSeparationEnabled", Common.DataSeparationEnabled());

	Filter = New Structure;
	Filter.Insert("Metadata", Metadata.ScheduledJobs.MarkedObjectsDeletion);
	Jobs = ScheduledJobsServer.FindJobs(Filter);
	If Jobs.Count() > 0 Then
		Jobs = Jobs[0];
		Result.Use = Jobs.Use;
		If Result.DataSeparationEnabled Then
			Result.Schedule = Jobs.Schedule;
		Else
			Result.Schedule = ScheduledJobsServer.JobSchedule(
				Jobs.UUID, True);
		EndIf;
	EndIf;

	Return Result;

EndFunction

// See MarkedObjectsDeletion.DeleteOnScheduleCheckBoxValue
Function DeleteOnScheduleCheckBoxValue() Export
	Return ModeDeleteOnSchedule().Use;
EndFunction

Procedure SaveViewSettingForItemsMarkedForDeletion(FormName, ListName, CheckMarkValue) Export
	SettingsKey = MarkedObjectsDeletionInternal.SettingsKey(FormName, ListName);
	Common.FormDataSettingsStorageSave(FormName, SettingsKey, CheckMarkValue);
EndProcedure

#EndRegion