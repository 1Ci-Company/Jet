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
	
	If Not Users.IsFullUser(, True) Then
		Raise NStr("en = 'Insufficient access rights.
		                             |Only administrators can change scheduled job settings.';",
			ErrorCategory.AccessViolation);
	EndIf;
	
	Action = Parameters.Action;
	If StrFind(", Add, Copy, Change,", ", " + Action + ",") = 0 Then
		Raise NStr("en = 'Cannot open the ""Scheduled job"" form. Invalid opening parameters.';",
			ErrorCategory.ConfigurationError);
	EndIf;
	
	If Action = "Add" Then
		
		ParameterizedJobs = New Map;
		JobDependencies     = ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions();
		
		FilterParameters        = New Structure;
		FilterParameters.Insert("IsParameterized", True);
		SearchResult = JobDependencies.FindRows(FilterParameters);
		
		For Each TableRow In SearchResult Do
			ParameterizedJobs[TableRow.ScheduledJob] = True;
		EndDo;
		
		Schedule = New JobSchedule;
		
		For Each ScheduledJobMetadata1 In Metadata.ScheduledJobs Do
			If ParameterizedJobs[ScheduledJobMetadata1] <> Undefined Then
				Continue;
			EndIf;
			
			ScheduledJobMetadataDetailsCollection.Add(ScheduledJobMetadata1.Name + Chars.LF
					+ ScheduledJobMetadata1.Synonym + Chars.LF
					+ ScheduledJobMetadata1.MethodName,
				?(IsBlankString(ScheduledJobMetadata1.Synonym),
				  ScheduledJobMetadata1.Name,
				  ScheduledJobMetadata1.Synonym) );
		EndDo;
	Else
		Job = ScheduledJobsServer.GetScheduledJob(Parameters.Id);
		FillPropertyValues(
			ThisObject,
			Job,
			"Key,
			|Predefined,
			|Use,
			|Description,
			|UserName,
			|RestartIntervalOnFailure,
			|RestartCountOnFailure");
		
		Id = String(Job.UUID);
		If Job.Metadata = Undefined Then
			NameOfMetadataObjects        = NStr("en = '<no metadata>';");
			MetadataSynonym    = NStr("en = '<no metadata>';");
			MetadataMethodName  = NStr("en = '<no metadata>';");
		Else
			NameOfMetadataObjects        = Job.Metadata.Name;
			MetadataSynonym    = Job.Metadata.Synonym;
			MetadataMethodName  = Job.Metadata.MethodName;
		EndIf;
		Schedule = Job.Schedule;
		
		If Action = "Copy" Then
			Predefined = False;
		Else
			MessagesToUserAndErrorDescription =
				ScheduledJobsInternal.ScheduledJobMessagesAndErrorDescriptions(Job);
		EndIf;
		
		Items.Description.Visible = Not Predefined;
	EndIf;
	
	If Action <> "Change" Then
		Id = NStr("en = '<will be generated automatically>';");
		Use = False;
		
		Description = ?(Action = "Add", "", ScheduledJobsInternal.ScheduledJobPresentation(Job));
	EndIf;
	
	// Populate the choice list with usernames.
	UsersArray = InfoBaseUsers.GetUsers(); // Array of InfoBaseUser
	For Each User In UsersArray Do
		Items.UserName.ChoiceList.Add(User.Name);
	EndDo;
	
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If Action = "Add" Then
		AttachIdleHandler("SelectNewScheduledJobTemplate", 0.1, True);
	Else
		RefreshFormTitle();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseCompletion", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Write(Command)
	
	WriteScheduledJob();
	
EndProcedure

&AtClient
Procedure WriteAndCloseExecute()
	
	WriteAndCloseCompletion();
	
EndProcedure

&AtClient
Procedure SetUpScheduleExecute()

	Dialog = New ScheduledJobDialog(Schedule);
	Dialog.Show(New NotifyDescription("OpenScheduleEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure WriteAndCloseCompletion(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WriteScheduledJob();
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SelectNewScheduledJobTemplate()
	
	// Scheduled job template selection (metadata).
	ScheduledJobMetadataDetailsCollection.ShowChooseItem(
		New NotifyDescription("SelectNewScheduledJobTemplateCompletion", ThisObject),
		NStr("en = 'Select a scheduled job template';"));
	
EndProcedure

&AtClient
Procedure SelectNewScheduledJobTemplateCompletion(ListItem, Context) Export
	
	If ListItem = Undefined Then
		Close();
		Return;
	EndIf;
	
	NameOfMetadataObjects       = StrGetLine(ListItem.Value, 1);
	MetadataSynonym   = StrGetLine(ListItem.Value, 2);
	MetadataMethodName = StrGetLine(ListItem.Value, 3);
	Description        = ListItem.Presentation;
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, Context) Export

	If NewSchedule <> Undefined Then
		Schedule = NewSchedule;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteScheduledJob()
	
	If Not ValueIsFilled(NameOfMetadataObjects) Then
		Return;
	EndIf;
	
	CurrentID = ?(Action = "Change", Id, Undefined);
	
	WriteScheduledJobAtServer();
	RefreshFormTitle();
	
	Notify("Write_ScheduledJobs", CurrentID);
	
EndProcedure

&AtServer
Procedure WriteScheduledJobAtServer()
	
	JobParameters = New Structure(
	"Key,
	|Description,
	|Use,
	|UserName,
	|RestartIntervalOnFailure,
	|RestartCountOnFailure,
	|Schedule");
	FillPropertyValues(JobParameters, ThisObject);
	
	If Action = "Change" Then
		ScheduledJobsServer.ChangeScheduledJob(Id, JobParameters);
	Else
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs[NameOfMetadataObjects]);
		
		Job = ScheduledJobsServer.AddARoutineTask(JobParameters);
		
		Id = String(Job.UUID);
		Action = "Change";
	EndIf;
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure RefreshFormTitle()
	
	If Not IsBlankString(Description) Then
		Presentation = Description;
		
	ElsIf Not IsBlankString(MetadataSynonym) Then
		Presentation = MetadataSynonym;
	Else
		Presentation = NameOfMetadataObjects;
	EndIf;
	
	If Action = "Change" Then
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 (Scheduled job)';"), Presentation);
	Else
		Title = NStr("en = 'Scheduled job (Create)';");
	EndIf;
	
EndProcedure

#EndRegion
