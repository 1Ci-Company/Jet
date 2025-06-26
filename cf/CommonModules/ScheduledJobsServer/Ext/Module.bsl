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

// In the local mode of operation, it returns the scheduled jobs matching the filter.
// In SaaS mode, returns the value table which contains details of the jobs found in the JobsQueue catalog.
// 
//
// Parameters:
//  Filter - Structure - Has the following properties: 
//          1. Common for all run modes:
//             * UUID - UUID - a scheduled job ID in the local
//                                         mode or an ID of the queue job reference in SaaS mode.
//                                       - String - a string of the scheduled job UUID in the local
//                                         mode or an ID of the queue job reference in SaaS mode.
//                                       - CatalogRef.JobsQueue - - Queue job ID in the SaaS mode.
//                                            
//                                       - ValueTableRow of See FindJobs
//             * Metadata              - MetadataObjectScheduledJob - a scheduled job metadata.
//                                       - String - Name of the scheduled job metadata object.
//             * Use           - Boolean - If True, a job is enabled.
//             * Key                    - String - an applied ID of a job.
//          2) Allowed keys only for local mode:
//             * Description            - String - scheduled job description.
//             * Predefined        - Boolean - If True, scheduled job is defined in the metadata.
//          3) Allowed keys only for SaaS mode:
//             * MethodName               - String - a method name (or alias) of a job queue handler.
//             * DataArea           - Number - job data area separator value.
//             * JobState        - EnumRef.JobsStates - queue job state.
//             * Template                  - CatalogRef.QueueJobTemplates - a job template used
//                                            for separated queue jobs only.
//
// Returns:
//     Array of ScheduledJob - In the local mode, a scheduled job array.
//     ValueTable - In SaaS mode, has the following columns:
//        * Use                - Boolean - If True, a job is enabled.
//        * Key                         - String - an applied ID of a job.
//        * Parameters                    - Array - parameters to be passed to job handler.
//        * Schedule                   - JobSchedule - a job schedule.
//        * UUID      - CatalogRef.JobsQueue - - Queue job ID in the SaaS mode.
//                                            
//        * ScheduledStartTime - Date - date and time of scheduled job launch
//                                         (as adjusted for the data area time zone).
//        * MethodName                    - String - a method name (or alias) of a job queue handler.
//        * DataArea                - Number - job data area separator value.
//        * JobState             - EnumRef.JobsStates - queue job state.
//        * Template                       - CatalogRef.QueueJobTemplates - a job template
//                                            used for separated queue jobs only.
//        * ExclusiveExecution       - Boolean - If this flag is set, the job will be executed 
//                                                  even if session start is prohibited in the data
//                                                  area. If any jobs with this flag
//                                                  are available in a data area, they will be executed first.
//        * RestartIntervalOnFailure - Number - Interval between job restart
//                                                          attempts after its abnormal termination, in seconds.
//        * RestartCountOnFailure - Number - number of retries after job abnormal termination.
//
Function FindJobs(Filter) Export
	
	RaiseIfNoAdministrationRights();
	
	FilterCopy = Common.CopyRecursive(Filter); // See FindJobs.Filter
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("CloudTechnology.JobsQueue") Then
			
			If FilterCopy.Property("UUID") Then
				If Not FilterCopy.Property("Id") Then
					FilterCopy.Insert("Id", FilterCopy.UUID);
				EndIf;
				FilterCopy.Delete("UUID");
			EndIf;
			
			If Common.SeparatedDataUsageAvailable() Then
				// ACC:1386-off - The module is included in the CloudTechnology.Core subsystem.
				ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
				// ACC:1386-on
				DataArea = ModuleSaaSOperations.SessionSeparatorValue();
				FilterCopy.Insert("DataArea", DataArea);
			EndIf;
			
			ModuleJobsQueue  = Common.CommonModule("JobsQueue");
			
			If FilterCopy.Property("Metadata") Then
				If TypeOf(FilterCopy.Metadata) = Type("MetadataObject") Then
					MetadataScheduledJob = FilterCopy.Metadata;
				Else
					MetadataScheduledJob = Metadata.ScheduledJobs.Find(FilterCopy.Metadata);
				EndIf;
				FilterCopy.Delete("Metadata");
				FilterCopy.Delete("MethodName");
				FilterCopy.Delete("Template");
				If MetadataScheduledJob <> Undefined Then
					QueueJobTemplates = StandardSubsystemsCached.QueueJobTemplates();
					If QueueJobTemplates.Get(MetadataScheduledJob.Name) <> Undefined Then
						SetPrivilegedMode(True);
						Template = ModuleJobsQueue.TemplateByName_(MetadataScheduledJob.Name);
						SetPrivilegedMode(False);
						FilterCopy.Insert("Template", Template);
					Else
						FilterCopy.Insert("MethodName", MetadataScheduledJob.MethodName);
					EndIf;
				Else
					FilterCopy.Insert("MethodName", String(New UUID));
				EndIf;
			ElsIf FilterCopy.Property("Id") Then
				If TypeOf(FilterCopy.Id) = Type("String") Then
					FilterCopy.Id = New UUID(FilterCopy.Id);
				EndIf;
				If TypeOf(FilterCopy.Id) = Type("UUID") Then
					FilterCopy.Id = QueueJobLink(FilterCopy.Id, FilterCopy);
				ElsIf TypeOf(FilterCopy.Id) = Type("ValueTableRow") Then
					FilterCopy.Id = FilterCopy.Id.Id;
				EndIf;
			EndIf;
			
			Return UpdatedTaskList(ModuleJobsQueue.GetJobs(FilterCopy));
			
		EndIf;
	Else
		
		JobsList = ScheduledJobs.GetScheduledJobs(FilterCopy);
		
		Return JobsList;
		
	EndIf;
	
EndFunction

// Returns a queue job or a scheduled job.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                                     the predefined scheduled job.
//                - String - a name of the predefined scheduled job metadata in any mode or
//                           a string of the scheduled job UUID in the local mode, or
//                           a string of the queue job reference UUID in SaaS mode.
//                - UUID - a scheduled job ID in the local mode or
//                           an ID of the queue job reference in SaaS mode.
//                - ScheduledJob - a scheduled job from which you need to get the UUID
//                           for getting a fresh copy of the scheduled job in the local mode.
//                - CatalogRef.JobsQueue - an ID of a queue job in the SaaS mode.
//                - ValueTableRow of See FindJobs
// 
// Returns:
//  ScheduledJob - The local mode.
//  ValueTableRow from See FindJobs
//  Undefined - Job is not found.
//
Function Job(Val Id) Export
	
	RaiseIfNoAdministrationRights();
	
	Id = UpdatedTaskID(Id);
	ScheduledJob = Undefined;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("CloudTechnology.JobsQueue") Then
			Filter = ?(TypeOf(Id) = Type("MetadataObject"),
				New Structure("Metadata", Id),
				New Structure("UUID", Id));
			
			JobsList = FindJobs(Filter);
			For Each Job In JobsList Do
				ScheduledJob = Job;
				Break;
			EndDo;
		EndIf;
		
	Else
		
		If TypeOf(Id) = Type("MetadataObject") Then
			If Id.Predefined Then
				ScheduledJob = ScheduledJobs.FindPredefined(Id);
			Else
				JobsList = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", Id));
				If JobsList.Count() > 0 Then
					ScheduledJob = JobsList[0];
				EndIf;
			EndIf; 
		Else
			ScheduledJob = ScheduledJobs.FindByUUID(Id);
		EndIf;
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

// Adds a new queue job or a new scheduled job.
// 
// Parameters: 
//  Parameters - Structure - parameters of the job to be added. Possible properties:
//   * Use - Boolean - True if a scheduled job runs automatically on schedule. 
//   * Metadata    - MetadataObjectScheduledJob - required. The metadata object which will be used 
//                              to generate a scheduled job.
//   * Parameters     - Array - parameters of the scheduled job. The number of parameters must match 
//                              the parameters of the scheduled job method.
//   * Key          - String - an applied ID of a scheduled job.
//   * RestartIntervalOnFailure - Number - Interval between job restart attempts 
//                              after its abnormal termination, in seconds.
//   * Schedule    - JobSchedule - a job schedule.
//   * RestartCountOnFailure - Number - number of retries after job abnormal termination.
//
// Returns:
//  ScheduledJob - The local mode.
//  ValueTableRow from See FindJobs
// 
Function AddJob(Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("CloudTechnology.JobsQueue") Then
			
			JobParameters = Common.CopyRecursive(Parameters);
			
			If Common.SeparatedDataUsageAvailable() Then
				// ACC:1386-off - The module is included in the CloudTechnology.Core subsystem.
				ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
				// ACC:1386-on
				DataArea = ModuleSaaSOperations.SessionSeparatorValue();
				JobParameters.Insert("DataArea", DataArea);
			EndIf;
			
			JobMetadata = JobParameters.Metadata;
			MethodName = JobMetadata.MethodName;
			JobParameters.Insert("MethodName", MethodName);
			
			JobParameters.Delete("Metadata");
			JobParameters.Delete("Description");
			
			ModuleJobsQueue = Common.CommonModule("JobsQueue");
			Job = ModuleJobsQueue.AddJob(JobParameters);
			Filter = New Structure("Id", Job);
			JobsList = UpdatedTaskList(ModuleJobsQueue.GetJobs(Filter));
			For Each Job In JobsList Do
				Return Job;
			EndDo;
			
		EndIf;
		
	Else
		Job = AddARoutineTask(Parameters);
	EndIf;
	
	Return Job;
	
EndFunction

// Deletes a queue job or a scheduled job.
//
// Parameters:
//  Id - MetadataObject - a metadata object of a scheduled job to search for
//                                     the non-predefined scheduled job.
//                - String - a name of the predefined scheduled job metadata in any mode or
//                           a string of the scheduled job UUID in the local mode, or
//                           a string of the queue job reference UUID in SaaS mode.
//                - UUID - a scheduled job ID in the local mode or
//                           an ID of the queue job reference in SaaS mode.
//                - ScheduledJob - a scheduled job whose UUID is used 
//                  to identify the scheduled job instance to be deleted in the local mode.
//                - CatalogRef.JobsQueue - an ID of a queue job in the SaaS mode.
//                - ValueTableRow of See FindJobs
//
Procedure DeleteJob(Val Id) Export
	
	RaiseIfNoAdministrationRights();
	
	Id = UpdatedTaskID(Id);
	
	If Common.DataSeparationEnabled() Then
		If Common.SubsystemExists("CloudTechnology.JobsQueue") Then
			If TypeOf(Id) = Type("ValueTableRow") Then
				JobsList = CommonClientServer.ValueInArray(Id);
			Else
				Filter = ?(TypeOf(Id) = Type("MetadataObject"),
					New Structure("MethodName", Id.MethodName),
					New Structure("UUID", Id));
				JobsList = FindJobs(Filter);
			EndIf;
			ModuleJobsQueue = Common.CommonModule("JobsQueue");
			For Each Job In JobsList Do
				ModuleJobsQueue.DeleteJob(Job.Id);
			EndDo;
		EndIf;
	Else
		DeleteScheduledJob(Id);
	EndIf;
	
EndProcedure

// Changes a queue job or a scheduled one.
//
// In SaaS mode (separation is enabled):
// - If called within a transaction, object lock is set for the job.
// - If the job is based on a template or it is predefined,
// only the Usage property can be specified in the Parameters parameter. In this case, you cannot
// change the schedule as it is stored in the shared Job template
// and not saved for every area separately.
// 
// Parameters: 
//  Id - MetadataObject - Scheduled job metadata object for searching.
//                - String - a name of the predefined scheduled job metadata in any mode or
//                           a string of the scheduled job UUID in the local mode, or
//                           a string of the queue job reference UUID in SaaS mode.
//                - UUID - a scheduled job ID in the local mode or
//                            an ID of the queue job reference in SaaS mode.
//                - ScheduledJob - a scheduled job in the local mode.
//                - CatalogRef.JobsQueue - an ID of a queue job in the SaaS mode.
//                - ValueTableRow of See FindJobs
//
//  Parameters - Structure - parameters that should be set to the job, possible properties:
//   * Use - Boolean - True if a scheduled job is executed automatically according to the schedule.
//   * Parameters     - Array - parameters of the scheduled job. The number of parameters must match
//                              the parameters of the scheduled job method.
//   * Key          - String - an applied ID of a scheduled job.
//   * RestartIntervalOnFailure - Number - Interval between job restart attempts
//                              after its abnormal termination, in seconds.
//   * Schedule    - JobSchedule - a job schedule.
//   * RestartCountOnFailure - Number - number of retries after job abnormal termination.
//   
Procedure ChangeJob(Val Id, Val Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	Id = UpdatedTaskID(Id);
	
	If Common.DataSeparationEnabled() Then
		If Common.SubsystemExists("CloudTechnology.JobsQueue") Then
			JobParameters = Common.CopyRecursive(Parameters);
			JobParameters.Delete("Description");
			If JobParameters.Count() = 0 Then
				Return;
			EndIf;
			
			If TypeOf(Id) = Type("ValueTableRow") Then
				JobsList = CommonClientServer.ValueInArray(Id);
			Else
				Filter = ?(TypeOf(Id) = Type("MetadataObject"),
					New Structure("Metadata", Id),
					New Structure("UUID", Id));
				JobsList = FindJobs(Filter);
			EndIf;
			
			// If a scheduled job is predefined and there's a queue template,
			// then only "Use" can be modified.
			PredefinedJobParameters = New Structure;
			If JobParameters.Property("Use") Then
				PredefinedJobParameters.Insert("Use",
					JobParameters.Use);
			EndIf;
			
			ModuleJobsQueue = Common.CommonModule("JobsQueue");
			For Each Job In JobsList Do
				If Not ValueIsFilled(Job.Template) Then
					ModuleJobsQueue.ChangeJob(Job.Id, JobParameters);
				ElsIf ValueIsFilled(PredefinedJobParameters) Then
					ModuleJobsQueue.ChangeJob(Job.Id, PredefinedJobParameters);
				EndIf;
			EndDo;
		EndIf;
	Else
		ChangeScheduledJob(Id, Parameters);
	EndIf;
	
EndProcedure

// Returns the UUID of a queue job or a scheduled job.
// To call, you must have the administrator rights or SetPrivilegedMode.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                                     the scheduled job.
//                - String - a string of the scheduled job UUID or
//                           an ID of the queue job reference in SaaS mode.
//                - UUID - a scheduled job ID in the local mode or
//                            an ID of the queue job reference in SaaS mode.
//                - ScheduledJob - a scheduled job.
//
// Returns:
//  UUID - a scheduled job ID in the local mode or
//                             an ID of the queue job reference in SaaS mode.
// 
Function UUID(Val Id) Export
	
	Return UniqueIdentifierOfTheTask(Id, True);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions that don't support queue jobs in SaaS mode.

// Returns the use of a scheduled job.
// To call, you must have the administrator rights or SetPrivilegedMode.
//
// In SaaS mode, manages scheduled jobs of the platform but not queue jobs
// in the separated and shared modes.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                  the predefined scheduled job.
//                - UUID - a scheduled job ID.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
// Returns:
//  Boolean - True if the scheduled job is used.
// 
Function ScheduledJobUsed(Val Id) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(Id);
	
	Return Job.Use;
	
EndFunction

// Returns a scheduled job schedule.
// To call, you must have the administrator rights or SetPrivilegedMode.
//
// In SaaS mode, manages scheduled jobs of the platform but not queue jobs
// in the separated and shared modes.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                  the predefined scheduled job.
//                - UUID - a scheduled job ID.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
//  InStructure    - Boolean - If True, the schedule will be transformed
//                  into a structure that you can pass to the client.
// 
// Returns:
//  JobSchedule, Structure - the structure contains the same properties as the schedule.
// 
Function JobSchedule(Val Id, Val InStructure = False) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(Id);
	
	If InStructure Then
		Return CommonClientServer.ScheduleToStructure(Job.Schedule);
	EndIf;
	
	Return Job.Schedule;
	
EndFunction

// Sets the use of a scheduled job.
// To call, you must have the administrator rights or SetPrivilegedMode.
//
// In SaaS mode, manages scheduled jobs of the platform but not queue jobs
// in the separated and shared modes.
//
// Parameters:
//  Id - MetadataObject        - metadata object of a scheduled job to search
//                                            the predefined scheduled job.
//                - UUID - a scheduled job ID.
//                - String                  - a scheduled job UUID string.
//                - ScheduledJob     - a scheduled job.
//  Use - Boolean                  - a usage value to be set.
//
Procedure SetScheduledJobUsage(Val Id, Val Use) Export
	
	RaiseIfNoAdministrationRights();
	
	JobID = UniqueIdentifierOfTheTask(Id);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
	LockItem.SetValue("Id", String(JobID));
	
	BeginTransaction();
	Try
		Block.Lock();
		Job = GetScheduledJob(JobID);
		
		If Job.Use <> Use Then
			Job.Use = Use;
			Job.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Sets a scheduled job schedule.
// To call, you must have the administrator rights or SetPrivilegedMode.
//
// In SaaS mode, manages scheduled jobs of the platform but not queue jobs
// in the separated and shared modes.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                  the predefined scheduled job.
//                - UUID - a scheduled job ID.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
//  Schedule    - JobSchedule - a schedule.
//                - Structure - the value returned by the ScheduleToStructure function
//                  of the CommonUseClientServer common module.
// 
Procedure SetJobSchedule(Val Id, Val Schedule) Export
	
	RaiseIfNoAdministrationRights();
	
	JobID = UniqueIdentifierOfTheTask(Id);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
	LockItem.SetValue("Id", String(JobID));
	
	BeginTransaction();
	Try
		Block.Lock();
		Job = GetScheduledJob(JobID);
		
		If TypeOf(Schedule) = Type("JobSchedule") Then
			Job.Schedule = Schedule;
		Else
			Job.Schedule = CommonClientServer.StructureToSchedule(Schedule);
		EndIf;
		
		Job.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Returns ScheduledJob from the infobase.
//
// In SaaS mode, manages scheduled jobs of the platform but not queue jobs
// in the separated and shared modes.
//
// Parameters:
//  Id - MetadataObject - metadata object of a scheduled job to search
//                  the predefined scheduled job.
//                - UUID - a scheduled job ID.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job from which you need to get
//                  the unique ID for getting a fresh copy of the scheduled job.
// 
// Returns:
//  ScheduledJob - read from the database.
//
Function GetScheduledJob(Val Id) Export
	
	RaiseIfNoAdministrationRights();
	
	If TypeOf(Id) = Type("ScheduledJob") Then
		Id = Id.UUID;
	EndIf;
	
	If TypeOf(Id) = Type("String") Then
		Id = New UUID(Id);
	EndIf;
	
	If TypeOf(Id) = Type("MetadataObject") Then
		ScheduledJob = ScheduledJobs.FindPredefined(Id);
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(Id);
	EndIf;
	
	If ScheduledJob = Undefined Then
		Raise( NStr("en = 'The scheduled job does not exist.
		                              |It might have been deleted by another user.';") );
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

// Returns the result of the last run of the given scheduled job.
// Including when it was run manually from the "Scheduled and background jobs" data processor.
// 
// Parameters:
//  Job - ScheduledJob - Scheduled job whose last run results are to be obtained.
//                                  
//          - String - Scheduled job's UUID
//
// Returns:
//  Undefined
//  * Description - String:
//     * Key - String
//  * End - Date
//  * ScheduledJobID - String
//  * State - BackgroundJobState
//  * MethodName - String
//  * Placement - String
//  ErrorDetailsDescription - String
//  * StartAttempt - Number
//  * MessagesToUser - Array
//  * SessionNumber - Number
//  * SessionStart - Date
//     * Description - String
//     * Key - String
//     * End - Date
//     * ScheduledJobID - String
//     * State - BackgroundJobState
//     * MethodName - String
//     * Placement - String
//     ErrorDetailsDescription - String
//     * StartAttempt - Number
//     * MessagesToUser - Array
//     * SessionNumber - Number
//     * SessionStart - Date
//
Function PropertiesOfLastJob(Val Job) Export
	
	RaiseIfNoAdministrationRights();
	SetPrivilegedMode(True);
	
	If TypeOf(Job) = Type("ScheduledJob") Then
		Job = Job.UUID;
	EndIf;
	
	If TypeOf(Job) = Type("String") Then
		Job = New UUID(Job);
	EndIf;
	
	ScheduledJob = ScheduledJobs.FindByUUID(Job);
	CurrentFilter = New Structure("MethodName", ScheduledJob.Metadata.MethodName);
	Result = BackgroundJobs.GetBackgroundJobs(CurrentFilter);
	If Result.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	BackgroundJobLast = LastBackgroundJobInArray(Result);
	
	BackgroundJobProperties = NewBackgroundJobsProperties();
	FillPropertyValues(BackgroundJobProperties, BackgroundJobLast);
	
	BackgroundJobProperties.Id = BackgroundJobLast.UUID;
	BackgroundJobProperties.ScheduledJobID = Job;
	Return BackgroundJobProperties;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns a flag showing that operations with external resources are locked.
//
// Returns:
//   Boolean   - True if operations with external resources are locked.
//
Function OperationsWithExternalResourcesLocked() Export
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleWorkLockWithExternalResources = Common.CommonModule("ExternalResourcesOperationsLock");
		Return ModuleWorkLockWithExternalResources.OperationsWithExternalResourcesLocked();
	EndIf;
	
	Return False;
	
EndFunction

// Allows operating with external resources.
//
Procedure UnlockOperationsWithExternalResources() Export
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleWorkLockWithExternalResources = Common.CommonModule("ExternalResourcesOperationsLock");
		ModuleWorkLockWithExternalResources.AllowExternalResources();
	EndIf;
	
EndProcedure

// Denies operations with external resources.
//
Procedure LockOperationsWithExternalResources() Export
	
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleWorkLockWithExternalResources = Common.CommonModule("ExternalResourcesOperationsLock");
		ModuleWorkLockWithExternalResources.DenyExternalResources();
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// Sets the required values of scheduled job parameters.
// In SaaS mode, for a job created based on a job queue template,
// only the value of the Usage property can be changed.
//
// Parameters:
//  ScheduledJob - MetadataObjectScheduledJob - a job whose properties
//                        need to be changed.
//  ParametersToChange - Structure - properties of the scheduled job that need to be changed.
//                        Structure key - a parameter name, and value - a form parameter value.
//  Filter               - See FindJobs.Filter.
//
Procedure SetScheduledJobParameters(ScheduledJob, ParametersToChange, Filter = Undefined) Export
	
	If Filter = Undefined Then
		Filter = New Structure;
	EndIf;
	Filter.Insert("Metadata", ScheduledJob);
	
	JobsList = FindJobs(Filter);
	If JobsList.Count() = 0 Then
		ParametersToChange.Insert("Metadata", ScheduledJob);
		AddJob(ParametersToChange);
	Else
		For Each Job In JobsList Do
			ChangeJob(Job, ParametersToChange);
		EndDo;
	EndIf;
EndProcedure

// Defines whether a predefined scheduled job is used.
//
// Parameters:
//  MetadataJob - MetadataObject - predefined scheduled job metadata.
//  Use     - Boolean - If True, the job must be enabled. Otherwise, False.
//
Procedure SetPredefinedScheduledJobUsage(MetadataJob, Use) Export
	
	If Common.DataSeparationEnabled() Then
		Filter     = New Structure;
		Filter.Insert("Metadata", MetadataJob);
		Parameters = New Structure;
		Parameters.Insert("Use", Use);
		Jobs = FindJobs(Filter);
		For Each Job In Jobs Do
			ChangeJob(Job, Parameters);
			Break;
		EndDo;
	Else
		JobID = UniqueIdentifierOfTheTask(MetadataJob);
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
		LockItem.SetValue("Id", String(JobID));
		
		BeginTransaction();
		Try
			Block.Lock();
			Job = ScheduledJobs.FindByUUID(JobID);
			
			If Job.Use <> Use Then
				Job.Use = Use;
				Job.Write();
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

// Cancels background job execution for a scheduled job
// and writes to the event log.
//
Procedure CancelJobExecution(Val ScheduledJob, TextForLog) Export
	
	CurrentSession = GetCurrentInfoBaseSession().GetBackgroundJob();
	If CurrentSession = Undefined Then
		Return;
	EndIf;
	
	If ScheduledJob = Undefined Then
		For Each Job In Metadata.ScheduledJobs Do
			If Job.MethodName = CurrentSession.MethodName Then
				ScheduledJob = Job;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If ScheduledJob = Undefined Then
		Return;
	EndIf;
	
	EventName = NStr("en = 'Cancel background job';", Common.DefaultLanguageCode());
	
	WriteLogEvent(EventName,
		EventLogLevel.Warning,
		ScheduledJob,
		,
		TextForLog);
	
	CurrentSession.Cancel();
	CurrentSession.WaitForExecutionCompletion(1);
	
EndProcedure

Function ScheduledJobParameter(ScheduledJob, PropertyName, DefaultValue) Export
	
	JobParameters = New Structure;
	JobParameters.Insert("Metadata", ScheduledJob);
	
	SetPrivilegedMode(True);
	
	JobsList = FindJobs(JobParameters);
	For Each Job In JobsList Do
		Return Job[PropertyName];
	EndDo;
	
	Return DefaultValue;
	
EndFunction

// Sets an exclusive managed lock for saving scheduled jobs.
//  The lock is set to the ProgramInterfaceCache information register.
//
// Parameters:
//  Id - UUID - a scheduled job ID.
//                - MetadataObjectScheduledJob - Before adding a new metadata object without duplicates.
//
Procedure BlockARoutineTask(Id) Export 
	
	If TypeOf(Id) = Type("MetadataObject") Then
		LockID = Id.Name;
	Else
		LockID = String(Id);
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
	LockItem.SetValue("Id", LockID);
	Block.Lock();
	
EndProcedure

// Adds a new scheduled job ignoring the queue of SaaS mode jobs.
// 
// Parameters: 
//  Parameters - Structure - parameters of the job to be added. Possible properties:
//   * Use - Boolean - True if a scheduled job runs automatically on schedule. 
//   * Metadata    - MetadataObjectScheduledJob - required. The metadata object which will be used 
//                              to generate a scheduled job.
//   * Parameters     - Array - parameters of the scheduled job. The number of parameters must match 
//                              the parameters of the scheduled job method.
//   * Key          - String - an applied ID of a scheduled job.
//   * RestartIntervalOnFailure - Number - Interval between job restart attempts 
//                              after its abnormal termination, in seconds.
//   * Schedule    - JobSchedule - a job schedule.
//   * RestartCountOnFailure - Number - number of retries after job abnormal termination.
//
// Returns:
//  ScheduledJob
//
Function AddARoutineTask(Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	JobMetadata = Parameters.Metadata;
	Job = ScheduledJobs.CreateScheduledJob(JobMetadata);
	
	If Parameters.Property("Description") Then
		Job.Description = Parameters.Description;
	Else
		Job.Description = JobMetadata.Description;
	EndIf;
	
	If Parameters.Property("Use") Then
		Job.Use = Parameters.Use;
	Else
		Job.Use = JobMetadata.Use;
	EndIf;
	
	If Parameters.Property("Key") Then
		Job.Key = Parameters.Key;
	Else
		Job.Key = JobMetadata.Key;
	EndIf;
	
	If Parameters.Property("UserName") Then
		Job.UserName = Parameters.UserName;
	EndIf;
	
	If Parameters.Property("RestartIntervalOnFailure") Then
		Job.RestartIntervalOnFailure = Parameters.RestartIntervalOnFailure;
	Else
		Job.RestartIntervalOnFailure = JobMetadata.RestartIntervalOnFailure;
	EndIf;
	
	If Parameters.Property("RestartCountOnFailure") Then
		Job.RestartCountOnFailure = Parameters.RestartCountOnFailure;
	Else
		Job.RestartCountOnFailure = JobMetadata.RestartCountOnFailure;
	EndIf;
	
	If Parameters.Property("Parameters") Then
		Job.Parameters = Parameters.Parameters;
	EndIf;
	
	If Parameters.Property("Schedule") Then
		Job.Schedule = Parameters.Schedule;
	EndIf;
	
	Job.Write();
	
	Return Job;
	
EndFunction

// Deletes a custom scheduled job (ignoring the SaaS job queue).
//
// Parameters:
//  Id - MetadataObject - a metadata object of a scheduled job to search for
//                                     the non-predefined scheduled job.
//                - String - a name of the predefined scheduled job metadata or
//                           a string of the scheduled job UUID.
//                - UUID - a scheduled job ID.
//                - ScheduledJob - a scheduled job whose UUID is used 
//                  to identify the scheduled job instance to be deleted.
//
Procedure DeleteScheduledJob(Val Id) Export
	
	RaiseIfNoAdministrationRights();
	
	Id = UpdatedTaskID(Id);
	
	JobsList = New Array; // Array of ScheduledJob
	
	If TypeOf(Id) = Type("MetadataObject") Then
		Filter = New Structure("Metadata, Predefined", Id, False);
		JobsList = ScheduledJobs.GetScheduledJobs(Filter);
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(Id);
		If ScheduledJob <> Undefined Then
			JobsList.Add(ScheduledJob);
		EndIf;
	EndIf;
	
	For Each ScheduledJob In JobsList Do
		JobID = UniqueIdentifierOfTheTask(ScheduledJob);
		
		Block = New DataLock;
		LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
		LockItem.SetValue("Id", String(JobID));
		
		BeginTransaction();
		Try
			Block.Lock();
			Job = ScheduledJobs.FindByUUID(JobID);
			If Job <> Undefined Then
				Job.Delete();
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndDo;
	
EndProcedure

// Changes the scheduled job ignoring the queue of SaaS mode jobs.
//
// Parameters: 
//  Id - MetadataObject - a metadata object of a scheduled job to search for
//                                     the non-predefined scheduled job.
//                - String - a name of the predefined scheduled job metadata or
//                           a string of the scheduled job UUID.
//                - UUID - a scheduled job ID.
//                - ScheduledJob - a scheduled job.
//
//  Parameters - Structure - parameters that should be set to the job, possible properties:
//   * Use - Boolean - True if a scheduled job is executed automatically according to the schedule.
//   * Parameters     - Array - parameters of the scheduled job. The number of parameters must match
//                              the parameters of the scheduled job method.
//   * Key          - String - an applied ID of a scheduled job.
//   * RestartIntervalOnFailure - Number - Interval between job restart attempts
//                              after its abnormal termination, in seconds.
//   * Schedule    - JobSchedule - a job schedule.
//   * RestartCountOnFailure - Number - number of retries after job abnormal termination.
//   
Procedure ChangeScheduledJob(Val Id, Val Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	Id = UpdatedTaskID(Id);
	JobID = UniqueIdentifierOfTheTask(Id);
	
	If JobID = Undefined Then
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Scheduled job by the passed ID is not found.
				|
				|If the scheduled job is not predefined, first of all add
				|it to the list of jobs using method %1.';"),
			"ScheduledJobsServer.AddJob");
		
		Raise ExceptionText;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ProgramInterfaceCache");
	LockItem.SetValue("Id", String(JobID));
	
	BeginTransaction();
	Try
		Block.Lock();
		Job = ScheduledJobs.FindByUUID(JobID);
		If Job <> Undefined Then
			HasChanges = False;
			
			UpdateTheValueOfTheTaskProperty(Job, "Description", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "Use", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "Key", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "UserName", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "RestartIntervalOnFailure", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "RestartCountOnFailure", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "Parameters", Parameters, HasChanges);
			UpdateTheValueOfTheTaskProperty(Job, "Schedule", Parameters, HasChanges);
			
			If HasChanges Then
				Job.Write();
			EndIf;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Parameters:
//   BackgroundJobArray - Array of BackgroundJob
//   LastBackgroundJob - BackgroundJob
//                           - Undefined
// Returns:
//   BackgroundJob, Undefined
//
Function LastBackgroundJobInArray(BackgroundJobArray, LastBackgroundJob = Undefined) Export
	
	For Each CurrentBackgroundJob In BackgroundJobArray Do
		If LastBackgroundJob = Undefined Then
			LastBackgroundJob = CurrentBackgroundJob;
			Continue;
		EndIf;
		If ValueIsFilled(LastBackgroundJob.End) Then
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			 Or LastBackgroundJob.End < CurrentBackgroundJob.End Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		Else
			If Not ValueIsFilled(CurrentBackgroundJob.End)
			   And LastBackgroundJob.Begin < CurrentBackgroundJob.Begin Then
				LastBackgroundJob = CurrentBackgroundJob;
			EndIf;
		EndIf;
	EndDo;
	
	Return LastBackgroundJob;
	
EndFunction

#EndRegion

#Region Private

Function UpdatedTaskID(Val Id)
	
	If TypeOf(Id) = Type("ScheduledJob") Then
		Id = Id.UUID;
	EndIf;
	
	If TypeOf(Id) = Type("String") Then
		MetadataObject = Metadata.ScheduledJobs.Find(Id);
		If MetadataObject = Undefined Then
			Id = New UUID(Id);
		Else
			Id = MetadataObject;
		EndIf;
	EndIf;
	
	Return Id;
	
EndFunction

Function UniqueIdentifierOfTheTask(Val Id, InSplitModeTheQueueJobID = False)
	
	If TypeOf(Id) = Type("UUID") Then
		Return Id;
	EndIf;
	
	If TypeOf(Id) = Type("ScheduledJob") Then
		Return Id.UUID;
	EndIf;
	
	If TypeOf(Id) = Type("String") Then
		Return New UUID(Id);
	EndIf;
	
	If InSplitModeTheQueueJobID
	   And Common.DataSeparationEnabled() Then
		
		If TypeOf(Id) = Type("MetadataObject") Then
			JobParameters = New Structure("Metadata", Id);
			JobsList = FindJobs(JobParameters);
			If JobsList = Undefined Then
				Return Undefined;
			EndIf;
			
			For Each Job In JobsList Do
				Return Job.Id.UUID();
			EndDo;
		ElsIf TypeOf(Id) = Type("ValueTableRow") Then
			Return Id.Id.UUID();
		ElsIf Common.IsReference(TypeOf(Id)) Then
			Return Id.UUID();
		Else
			Return Undefined;
		EndIf;
	Else
		If TypeOf(Id) = Type("MetadataObject") And Id.Predefined Then
			Return ScheduledJobs.FindPredefined(Id).UUID;
		ElsIf TypeOf(Id) = Type("MetadataObject") And Not Id.Predefined Then
			JobsList = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", Id));
			For Each ScheduledJob In JobsList Do
				Return ScheduledJob.UUID;
			EndDo; 
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

// For the ChangeJob procedure.
Procedure UpdateTheValueOfTheTaskProperty(Job, PropertyName, JobParameters, HasChanges)
	
	If Not JobParameters.Property(PropertyName) Then
		Return;
	EndIf;
	
	If Job[PropertyName] = JobParameters[PropertyName]
	 Or TypeOf(Job[PropertyName]) = Type("JobSchedule")
	   And TypeOf(JobParameters[PropertyName]) = Type("JobSchedule")
	   And String(Job[PropertyName]) = String(JobParameters[PropertyName]) Then
		
		Return;
	EndIf;
	
	If TypeOf(Job[PropertyName]) = Type("JobSchedule") 
		And TypeOf(JobParameters[PropertyName]) = Type("Structure") Then
		FillPropertyValues(Job[PropertyName], JobParameters[PropertyName]);
	Else
		Job[PropertyName] = JobParameters[PropertyName];
	EndIf;
	
	HasChanges = True;
	
EndProcedure

// For functions FindJob, Job, AddJob.
Function UpdatedTaskList(JobsList)
	
	// For backward compatibility the ID field is not removed.
	ListCopy = JobsList.Copy();
	ListCopy.Columns.Add("UUID");
	For Each Job In ListCopy Do
		Job.UUID = Job.Id;
	EndDo;
	
	Return ListCopy;
	
EndFunction

// For functions FindJobs, Job, DeleteJob, ChangeJob.
Function QueueJobLink(Id, JobParameters)
	
	ModuleJobsQueue = Common.CommonModule("JobsQueue");
	CatalogForJob = ModuleJobsQueue.CatalogJobsQueue();
	
	Return CatalogForJob.GetRef(Id);
	
EndFunction

// Throws an exception if the user does not have the administration right.
Procedure RaiseIfNoAdministrationRights()
	
	CheckSystemAdministrationRights = True;
	If Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable() Then
		CheckSystemAdministrationRights = False;
	EndIf;
	
	If Not Users.IsFullUser(, CheckSystemAdministrationRights) Then
		Raise NStr("en = 'Access violation.';");
	EndIf;
	
EndProcedure

Function NewBackgroundJobsProperties()
	
	BackgroundJobsProperties = New Structure;
	BackgroundJobsProperties.Insert("Id");
	BackgroundJobsProperties.Insert("Key");
	BackgroundJobsProperties.Insert("Begin");
	BackgroundJobsProperties.Insert("End");
	BackgroundJobsProperties.Insert("ScheduledJobID");
	BackgroundJobsProperties.Insert("State");
	BackgroundJobsProperties.Insert("MethodName");
	BackgroundJobsProperties.Insert("Placement");
	BackgroundJobsProperties.Insert("StartAttempt");
	BackgroundJobsProperties.Insert("UserMessages");
	BackgroundJobsProperties.Insert("SessionNumber");
	BackgroundJobsProperties.Insert("SessionStarted");
	
	Return BackgroundJobsProperties;
	
EndFunction

#EndRegion