///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		If Users.IsFullUser() Then
			HasMail = Common.SubsystemExists("StandardSubsystems.EmailOperations");
			ScheduledJob = FindScheduledJob("TaskMonitoring");
			If HasMail And ScheduledJob <> Undefined Then
				TasksMonitoringUsage = ScheduledJob.Use;
				TaskMonitoringSchedule    = ScheduledJob.Schedule;
			Else
				Items.TasksMonitoringGroup.Visible = False;
			EndIf;
			ScheduledJob = FindScheduledJob("NewPerformerTaskNotifications");
			If HasMail And ScheduledJob <> Undefined Then
				NotifyPerformersAboutNewTasksUsage = ScheduledJob.Use;
				NewPerformerTaskNotificationsSchedule    = ScheduledJob.Schedule;
			Else
				Items.NotifyPerformersAboutNewTasksGroup.Visible = False;
			EndIf;
		Else
			Items.TasksMonitoringGroup.Visible = False;
			Items.NotifyPerformersAboutNewTasksGroup.Visible = False;
		EndIf;
		
		If Common.DataSeparationEnabled() Then
			Items.TasksMonitoringConfigureSchedule.Visible = False;
			Items.NotifyPerformersAboutNewTasksConfigureSchedule.Visible = False;
		EndIf;
	Else
		Items.BusinessProcessesAndTasksGroup.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.OrganizerOnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	RefreshApplicationInterface();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName <> "Write_ConstantsSet" Then
		Return;
	EndIf;
	
	If Source = "UseExternalUsers" Then
		
		Read();
		SetAvailability();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseEmailClientOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseOtherInteractionsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure SendEmailsInHTMLFormatOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseReviewedFlagOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure DenyDisplayingUnsafeContentInEmailsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseNotesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseUserRemindersOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseSurveyOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseMessageTemplatesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseBusinessProcessesAndTasksOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseSubordinateBusinessProcessesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure ChangeJobsBackdatedOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseTaskStartDateOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseDateAndTimeInTaskDeadlinesOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RolesAndTaskPerformers(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		ModuleBusinessProcessesAndTasksClient = CommonClient.CommonModule("BusinessProcessesAndTasksClient");
		ModuleBusinessProcessesAndTasksClient.OpenRolesAndTaskPerformersList();
	EndIf;
	
EndProcedure

&AtClient
Procedure TasksMonitoringConfigureSchedule(Command)
	Dialog = New ScheduledJobDialog(TaskMonitoringSchedule);
	Dialog.Show(New NotifyDescription("TaskMonitoringAfterScheduleChanged", ThisObject));
EndProcedure

&AtClient
Procedure NotifyPerformersAboutNewTasksConfigureSchedule(Command)
	Dialog = New ScheduledJobDialog(NewPerformerTaskNotificationsSchedule);
	Dialog.Show(New NotifyDescription("NewPerformerTaskNotificationsAfterChangeSchedule", ThisObject));
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client.

&AtClient
Procedure Attachable_OnChangeAttribute(Item, ShouldRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	RefreshReusableValues();
	
	If ShouldRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure TaskMonitoringAfterScheduleChanged(Schedule, ExecutionParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	TaskMonitoringSchedule = Schedule;
	TasksMonitoringUsage = True;
	WriteScheduledJob("TaskMonitoring", TasksMonitoringUsage, 
		TaskMonitoringSchedule, "TaskMonitoringSchedule");
EndProcedure

&AtClient
Procedure TasksMonitoringUsageOnChange(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") And TasksMonitoringUsage Then
		NotifyDescription = New NotifyDescription("TasksMonitoringUsageMailAvailabilityCheckCompleted", ThisObject);
		ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
		ModuleEmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
	Else
		TasksMonitoringUsageMailAvailabilityCheckCompleted(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure TasksMonitoringUsageMailAvailabilityCheckCompleted(CheckCompleted, AdditionalParameters = Undefined) Export
	
	If CheckCompleted = True Then
		WriteScheduledJob("TaskMonitoring", TasksMonitoringUsage, 
			TaskMonitoringSchedule, "TaskMonitoringSchedule");
	Else
		TasksMonitoringUsage = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure NewPerformerTaskNotificationsAfterChangeSchedule(Schedule, ExecutionParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	NewPerformerTaskNotificationsSchedule = Schedule;
	NotifyPerformersAboutNewTasksUsage = True;
	WriteScheduledJob("NewPerformerTaskNotifications", NotifyPerformersAboutNewTasksUsage, 
		NewPerformerTaskNotificationsSchedule, "NewPerformerTaskNotificationsSchedule");
EndProcedure

&AtClient
Procedure NotifyPerformersAboutNewTasksUsageOnChange(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") And NotifyPerformersAboutNewTasksUsage Then
		NotifyDescription = New NotifyDescription(
			"NotifyPerformersAboutNewTasksUsageEmailAvailabilityCheckCompleted", ThisObject);
		ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
		ModuleEmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
	Else
		NotifyPerformersAboutNewTasksUsageEmailAvailabilityCheckCompleted(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyPerformersAboutNewTasksUsageEmailAvailabilityCheckCompleted(CheckCompleted, AdditionalParameters = Undefined) Export
	
	If CheckCompleted = True Then
		WriteScheduledJob("NewPerformerTaskNotifications", NotifyPerformersAboutNewTasksUsage, 
			NewPerformerTaskNotificationsSchedule, "NewPerformerTaskNotificationsSchedule");
	Else
		NotifyPerformersAboutNewTasksUsage = False;
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server.

&AtServer
Function OnChangeAttributeServer(TagName)
	
	DataPathAttribute = Items[TagName].DataPath;
	ConstantName = SaveAttributeValue(DataPathAttribute);
	If (ConstantName = "UseEmailClient" Or ConstantName = "UseBusinessProcessesAndTasks") 
		And Not ConstantsSet[ConstantName] Then
		Read();
	EndIf;
	SetAvailability(DataPathAttribute);
	RefreshReusableValues();
	Return ConstantName;
	
EndFunction

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	NameParts = StrSplit(DataPathAttribute, ".");
	If NameParts.Count() <> 2 Then
		Return "";
	EndIf;
	
	ConstantName = NameParts[1];
	ConstantManager = Constants[ConstantName];
	ConstantValue = ConstantsSet[ConstantName];
	
	If ConstantManager.Get() <> ConstantValue Then
		ConstantManager.Set(ConstantValue);
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If (DataPathAttribute = "ConstantsSet.UseEmailClient" Or DataPathAttribute = "")
		And Common.SubsystemExists("StandardSubsystems.Interactions") Then
		
		Items.UseOtherInteractions.Enabled             = ConstantsSet.UseEmailClient;
		Items.UseReviewedFlag.Enabled               = ConstantsSet.UseEmailClient;
		Items.SendEmailsInHTMLFormat.Enabled                 = ConstantsSet.UseEmailClient;
		Items.DenyDisplayingUnsafeContentInEmails.Enabled = ConstantsSet.UseEmailClient;
		
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseMessageTemplates" Or DataPathAttribute = "")
		And Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		
		Items.MessageTemplatesSettingsGroup.Enabled = ConstantsSet.UseMessageTemplates;
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseBusinessProcessesAndTasks" Or DataPathAttribute = "")
		And Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		
		Items.OpenRolesAndPerformersForBusinessProcesses.Enabled = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseSubordinateBusinessProcesses.Enabled  = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.ChangeJobsBackdated.Enabled            = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseTaskStartDate.Enabled            = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.UseDateAndTimeInTaskDeadlines.Enabled     = ConstantsSet.UseBusinessProcessesAndTasks;
		Items.TasksMonitoringGroup.Enabled					= ConstantsSet.UseBusinessProcessesAndTasks;
		Items.NotifyPerformersAboutNewTasksGroup.Enabled = ConstantsSet.UseBusinessProcessesAndTasks;
		
	EndIf;
	
	If Items.TasksMonitoringGroup.Visible
		And (DataPathAttribute = "TaskMonitoringSchedule" Or DataPathAttribute = "")
		And Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Items.TasksMonitoringConfigureSchedule.Enabled	= TasksMonitoringUsage;
		If TasksMonitoringUsage Then
			SchedulePresentation = String(TaskMonitoringSchedule);
			Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			Presentation = "";
		EndIf;
		Items.TasksMonitoringNote.Title = Presentation;
	EndIf;
	
	If Items.NotifyPerformersAboutNewTasksGroup.Visible
		And (DataPathAttribute = "NewPerformerTaskNotificationsSchedule" Or DataPathAttribute = "")
		And Common.SubsystemExists("StandardSubsystems.BusinessProcessesAndTasks") Then
		Items.NotifyPerformersAboutNewTasksConfigureSchedule.Enabled	= NotifyPerformersAboutNewTasksUsage;
		If NotifyPerformersAboutNewTasksUsage Then
			SchedulePresentation = String(NewPerformerTaskNotificationsSchedule);
			Presentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			Presentation = "";
		EndIf;
		Items.NotifyPerformersAboutNewTasksNote.Title = Presentation;
	EndIf;
	
EndProcedure

&AtServer
Procedure WriteScheduledJob(PredefinedItemName, Use, Schedule, DataPathAttribute)
	ScheduledJob = FindScheduledJob(PredefinedItemName);
	
	JobParameters = New Structure;
	JobParameters.Insert("Use", Use);
	JobParameters.Insert("Schedule", Schedule);
	
	ScheduledJobsServer.ChangeJob(ScheduledJob, JobParameters);
	
	If DataPathAttribute <> Undefined Then
		SetAvailability(DataPathAttribute);
	EndIf;
EndProcedure

&AtServer
Function FindScheduledJob(PredefinedItemName)
	Filter = New Structure;
	Filter.Insert("Metadata", PredefinedItemName);
	
	SearchResult = ScheduledJobsServer.FindJobs(Filter);
	Return ?(SearchResult.Count() = 0, Undefined, SearchResult[0]);
EndFunction

#EndRegion
