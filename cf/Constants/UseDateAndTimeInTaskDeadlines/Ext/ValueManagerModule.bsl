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

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Use = Constants.UseBusinessProcessesAndTasks.Get();
	
	SearchParameters = New Structure;
	SearchParameters.Insert("Metadata", Metadata.ScheduledJobs.StartDeferredProcesses);
	JobsList = ScheduledJobsServer.FindJobs(SearchParameters);
	
	If JobsList.Count() = 0 Then
		JobParameters = New Structure("Use", Use);
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs.StartDeferredProcesses);
		SetSchedule(Value, JobParameters);
		ScheduledJobsServer.AddJob(JobParameters);
		Return;
	EndIf;
	
	For Each Job In JobsList Do
		
		JobParameters = New Structure("Use", Use);
		If Use Then
			If Value Then
				If Job.Schedule.BeginTime = Date("00010101070000")
					Or Job.Schedule.BeginTime = Date("00010101000000") Then
					SetSchedule(Value, JobParameters);
				EndIf;
			Else
				If Job.Schedule.RepeatPeriodInDay = 900
					Or Job.Schedule.BeginTime = Date("00010101000000") Then
					SetSchedule(Value, JobParameters);
				EndIf;
			EndIf;
		EndIf;
		
		ScheduledJobsServer.ChangeJob(Job, JobParameters);
	EndDo;
	
EndProcedure


#EndRegion

#Region Private

Procedure SetSchedule(UseTimeInTaskDeadlines, JobParameters)
	
	Schedule = New JobSchedule;
	
	If UseTimeInTaskDeadlines Then
		Schedule.RepeatPeriodInDay = 900;
		Schedule.BeginTime              = Date("00000000");
		Schedule.DaysRepeatPeriod        = 1;
	Else
		Schedule.RepeatPeriodInDay = 0;
		Schedule.BeginTime              = Date("00010101070000");
		Schedule.DaysRepeatPeriod        = 1;
	EndIf;
	
	JobParameters.Insert("Schedule", Schedule);

EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.';");
#EndIf