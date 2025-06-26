///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

///////////////////////////////////////////////////////////////////////////////////////////////////////
// The external resource locking mechanism:
// - Disables the scheduled jobs that access external resources.
// - Disconnects the infobase from the Collaboration server (if "Conversations" subsystem is integrated).
// The lock is set if:
// - User signs in to the app.
// - A scheduled job that accesses external resources has started.
// The lock is always set automatically.
// The administrator can confirm the lock or unlock the infobase.
//
//  "BeforeStart" or "OnStartExecuteScheduledJob" obtains the session parameter
// "OperationsWithExternalResourcesLocked", and calls the
// "OnSetSessionParameters" event in the lock object if the environment has changed.
//
// "OnStartExecuteScheduledJob" disables the scheduled jobs if the session parameter's state is locked.
// 
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Internal

Function OperationsWithExternalResourcesLocked() Export
	
	Return SessionParameters.OperationsWithExternalResourcesLocked;
	
EndFunction

Procedure AllowExternalResources() Export
	
	BeginTransaction();
	Try
		BlockLockParametersData();
		
		LockParameters = SavedLockParameters();
		EnableDisabledScheduledJobs(LockParameters);
		
		NewLockParameters = CurrentLockParameters();
		NewLockParameters.CheckServerName = LockParameters.CheckServerName;
		SaveLockParameters(NewLockParameters);
		
		If Common.FileInfobase() Then
			WriteFileInfobaseIDToCheckFile(NewLockParameters.TheDatabaseID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SSLSubsystemsIntegration.WhenAllowingWorkWithExternalResources();
	ExternalResourcesOperationsLockOverridable.WhenAllowingWorkWithExternalResources();
	
	SessionParameters.OperationsWithExternalResourcesLocked = False;
	
	RefreshReusableValues();
	
EndProcedure

Procedure DenyExternalResources() Export
	
	BeginTransaction();
	Try
		InfoBaseID = New UUID();
		Constants.InfoBaseID.Set(String(InfoBaseID));
		
		BlockLockParametersData();
		
		LockParameters = SavedLockParameters();
		LockParameters.TheDatabaseID = InfoBaseID;
		LockParameters.OperationsWithExternalResourcesLocked = True;
		SaveLockParameters(LockParameters);
		
		If Common.FileInfobase() Then
			WriteFileInfobaseIDToCheckFile(LockParameters.TheDatabaseID);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SSLSubsystemsIntegration.WhenYouAreForbiddenToWorkWithExternalResources();
	ExternalResourcesOperationsLockOverridable.WhenYouAreForbiddenToWorkWithExternalResources();
	
	SessionParameters.OperationsWithExternalResourcesLocked = True;
	
	RefreshReusableValues();
	
EndProcedure

Procedure SetServerNameCheckInLockParameters(CheckServerName) Export
	
	BeginTransaction();
	Try
		BlockLockParametersData();
		
		LockParameters = SavedLockParameters();
		LockParameters.CheckServerName = CheckServerName;
		SaveLockParameters(LockParameters);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#Region EventsSubscriptionsHandlers

Procedure OnAddSessionParameterSettingHandlers(Handlers) Export
	
	Handlers.Insert("OperationsWithExternalResourcesLocked",
		"ExternalResourcesOperationsLock.OnSetSessionParameters");
	
EndProcedure


// Parameters:
//  ParameterName - String
//  SpecifiedParameters - See StandardSubsystemsServer.SessionParametersSetting
//
Procedure OnSetSessionParameters(ParameterName, SpecifiedParameters) Export 
	
	If ParameterName = "OperationsWithExternalResourcesLocked" Then
		
		BeginTransaction();
		Try
			
			SessionParameters.OperationsWithExternalResourcesLocked = SetExternalResourcesOperationsLock();
			SpecifiedParameters.Add("OperationsWithExternalResourcesLocked");
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
	EndIf;
	
EndProcedure

Procedure OnStartExecuteScheduledJob(ScheduledJob) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	JobStartAllowed = Common.SystemSettingsStorageLoad(
		"ScheduledJobs", 
		ScheduledJob.MethodName);
	
	If JobStartAllowed = True Then
		Return;
	EndIf;
	
	If Not ScheduledJobUsesExternalResources(ScheduledJob) Then
		Return;
	EndIf;
	
	If Not OperationsWithExternalResourcesLocked() Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		BlockLockParametersData();
		
		LockParameters = SavedLockParameters();
		DisableScheduledJob1(LockParameters, ScheduledJob);
		SaveLockParameters(LockParameters);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Common.DataSeparationEnabled() Then
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The application has been moved.
			           |The ""%1"" scheduled job, which requires online activities, is disabled.';"), 
			ScheduledJob.Synonym);
	Else 
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The infobase connection string has changed.
			           |The infobase might have been moved.
			           |The ""%1"" scheduled job is disabled.';"), 
			ScheduledJob.Synonym);
	EndIf;
	
	ScheduledJobsServer.CancelJobExecution(ScheduledJob, ExceptionText);
	
	Raise ExceptionText;
	
EndProcedure

Procedure OnAddClientParametersOnStart(ClientRunParameters, IsCallBeforeStart) Export
	
	ShowLockForm = False;
	
	If IsCallBeforeStart And OperationsWithExternalResourcesLocked() Then
		LockParameters = SavedLockParameters();
		
		FlagOfNecessityToFinalizeDecisionIsSet = 
			LockParameters.OperationsWithExternalResourcesLocked = Undefined;
		
		ShowLockForm = FlagOfNecessityToFinalizeDecisionIsSet And Users.IsFullUser();
	EndIf;
	
	ClientRunParameters.Insert("ShowExternalResourceLockForm", ShowLockForm);
	
EndProcedure

Procedure AfterImportData(Container) Export
	
	If Common.DataSeparationEnabled() Then
		LockParameters = CurrentLockParameters();
		SaveLockParameters(LockParameters);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region UpdateHandlers

Procedure UpdateExternalResourceAccessLockParameters() Export
	
	BeginTransaction();
	Try
		BlockLockParametersData();
		
		LockParameters = SavedLockParameters();
		
		DataSeparationEnabled = Common.DataSeparationEnabled();
		LockParameters.DataSeparationEnabled = DataSeparationEnabled;
		If DataSeparationEnabled Then
			LockParameters.ConnectionString = "";
			LockParameters.ComputerName = "";
		EndIf;
		
		SaveLockParameters(LockParameters);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#Region LockParameters

Function CurrentLockParameters()
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	ConnectionString = ?(DataSeparationEnabled, "", InfoBaseConnectionString());
	ComputerName = ?(DataSeparationEnabled, "", ComputerName());
	
	Result = New Structure;
	Result.Insert("TheDatabaseID", StandardSubsystemsServer.InfoBaseID());
	Result.Insert("IsFileInfobase", Common.FileInfobase());
	Result.Insert("DataSeparationEnabled", DataSeparationEnabled);
	Result.Insert("ConnectionString", ConnectionString);
	Result.Insert("ComputerName", ComputerName);
	Result.Insert("CheckServerName", True);
	Result.Insert("OperationsWithExternalResourcesLocked", False);
	Result.Insert("DisabledJobs", New Array);
	Result.Insert("LockReason", "");
	
	Return Result;
	
EndFunction

Function SavedLockParameters() Export 
	
	SetPrivilegedMode(True);
	SavedParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	SetPrivilegedMode(False);
	
	Result = CurrentLockParameters();
	
	If SavedParameters = Undefined Then 
		SaveLockParameters(Result); // Automatic initialization.
		If Common.FileInfobase() Then
			WriteFileInfobaseIDToCheckFile(Result.TheDatabaseID);
		EndIf;
	EndIf;
	
	If TypeOf(SavedParameters) = Type("Structure") Then 
		FillPropertyValues(Result, SavedParameters); // Reinitializing new properties.
	EndIf;
	
	Return Result;
	
EndFunction

Procedure BlockLockParametersData()
	
	Block = New DataLock;
	Block.Add("Constant.ExternalResourceAccessLockParameters");
	Block.Lock();
	
EndProcedure

Procedure SaveLockParameters(LockParameters)
	
	SetPrivilegedMode(True);
	
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region ScheduledJobs

// ACC:453-disable integrated scheduled jobs management in the block of operation lock.

Function ScheduledJobUsesExternalResources(ScheduledJob)
	
	JobDependencies = ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions();
	
	Filter = New Structure;
	Filter.Insert("ScheduledJob", ScheduledJob);
	Filter.Insert("UseExternalResources", True);
	
	FoundRows = JobDependencies.FindRows(Filter);
	Return FoundRows.Count() <> 0;
	
EndFunction

Procedure DisableScheduledJob1(LockParameters, ScheduledJob)
	
	Filter = New Structure;
	Filter.Insert("Metadata", ScheduledJob);
	Filter.Insert("Use", True);
	
	FoundJobs = ScheduledJobsServer.FindJobs(Filter);
	
	For Each Job In FoundJobs Do
		ScheduledJobsServer.ChangeJob(Job, New Structure("Use", False));
		LockParameters.DisabledJobs.Add(Job.UUID);
	EndDo;
	
EndProcedure

Procedure EnableDisabledScheduledJobs(LockParameters)
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	
	For Each JobID In LockParameters.DisabledJobs Do
		
		If DataSeparationEnabled = (TypeOf(JobID) = Type("UUID")) Then
			Continue;
		EndIf;
		
		Filter = New Structure;
		Filter.Insert("UUID", JobID);
		Filter.Insert("Use", False);
		
		FoundJobs = ScheduledJobsServer.FindJobs(Filter);
		
		For Each Job In FoundJobs Do
			ScheduledJobsServer.ChangeJob(Job, New Structure("Use", True));
			LockParameters.DisabledJobs.Add(Job.UUID);
		EndDo;
		
	EndDo;
	
EndProcedure

// ACC:453-on

#EndRegion

#Region FileInfobaseIDCheckFile

Function FileInfobaseIDCheckFileExists()
	
	FileInfo3 = New File(PathToFileInfobaseIDCheckFile());
	Return FileInfo3.Exists();
	
EndFunction

Function FileInfobaseIDFromCheckFile()
	
	TextReader = New TextReader(PathToFileInfobaseIDCheckFile());
	TheDatabaseID = TextReader.ReadLine();
	TextReader.Close();
	Return TheDatabaseID;
	
EndFunction

Procedure WriteFileInfobaseIDToCheckFile(TheDatabaseID)
	
	FileContent = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1
		           |
		           |The file is automatically created by the ""%2"" application.
		           |It contains the infobase ID and allows you to identify that this infobase was copied.
		           |
		           |Upon copying infobase files and creating a backup, do not copy this file.
		           |Using both infobase copies with the same ID at the same time can lead to conflicts
		           |while synchronizing data, sending emails, and performing other operations with external resources.
		           |
		           |If the file is missing from the infobase directory, the app will prompt
		           |the administrator if accessing external resources is allowed.';"), 
		TheDatabaseID, 
		Metadata.Synonym);
	
	FileName = PathToFileInfobaseIDCheckFile();
	
	TextWriter = New TextWriter(FileName);
	Try
		TextWriter.Write(FileContent);
	Except
		TextWriter.Close();
		Raise;
	EndTry;
	TextWriter.Close();
	
EndProcedure

Function PathToFileInfobaseIDCheckFile()
	
	Return CommonClientServer.FileInfobaseDirectory() + GetPathSeparator() + "DoNotCopy.txt";
	
EndFunction

#EndRegion

#Region LockSetting

Function SetExternalResourcesOperationsLock()
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return False;
	EndIf;
	
	LockParameters = SavedLockParameters();
	
	// Either the flag indicating that a decision about the lock should be made is raised,
	// or the administrator confirmed the lock.
	If LockParameters.OperationsWithExternalResourcesLocked = Undefined 
		Or LockParameters.OperationsWithExternalResourcesLocked = True Then
		Return True; 
	EndIf;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If DataSeparationEnabled Then
		Return False; // Infobase transfer is determined by the service manager in SaaS mode.
	EndIf;
	
	// The following code is for the case when data separation is disabled.
	
	DataSeparationChanged = LockParameters.DataSeparationEnabled <> DataSeparationEnabled;
	
	If DataSeparationChanged Then
		MessageText = NStr("en = 'The infobase has been moved from a web application.';");
		SetFlagShowsNecessityOfLock(LockParameters, MessageText);
		Return True;
	EndIf;
	
	ConnectionString = InfoBaseConnectionString();
	If ConnectionString = LockParameters.ConnectionString Then
		Return False; // If the connection string matches, do not perform any further check.
	EndIf;
	
	IsFileInfobase = Common.FileInfobase();
	
	MovedBetweenFileAndClientServerMode = IsFileInfobase <> LockParameters.IsFileInfobase;
	
	If MovedBetweenFileAndClientServerMode Then
		MessageText = 
			?(IsFileInfobase, 
				NStr("en = 'The infobase has been moved from the client/server mode to the file mode.';"),
				NStr("en = 'The infobase has been moved from the file mode to the client/server mode.';"));
		SetFlagShowsNecessityOfLock(LockParameters, MessageText);
		Return True;
	EndIf;
	
	// The code below assumes that the operation mode hasn't changed:
	// - A file infobase remains a file infobase
	// - A client/server infobase remains a client/server infobase
	
	If IsFileInfobase Then
		
		// For file infobases, the connection string may vary between devices.
		// Therefore, check if the infobase was re-located using the checking file.
		
		If Not FileInfobaseIDCheckFileExists() Then
			MessageText = NStr("en = 'The infobase folder does not contain check file %1.';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, "DoNotCopy.txt");
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
		
		InfobaseIDChanged = FileInfobaseIDFromCheckFile() <> LockParameters.TheDatabaseID;
		
		If InfobaseIDChanged Then
			MessageText = 
				NStr("en = 'The infobase ID in check file %1 does not match ID in the current infobase.';");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, "DoNotCopy.txt");
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
		
	Else // Client/server infobase.
		
		BaseName = Lower(StringFunctionsClientServer.ParametersFromString(ConnectionString).Ref);
		ConnectionManagerServerName = Lower(StringFunctionsClientServer.ParametersFromString(ConnectionString).Srvr);
		WorkingProcessServerName = Lower(ComputerName());
		
		SavedInfobaseName = 
			Lower(StringFunctionsClientServer.ParametersFromString(LockParameters.ConnectionString).Ref);
		SavedConnectionManagerServerName = 
			Lower(StringFunctionsClientServer.ParametersFromString(LockParameters.ConnectionString).Srvr);
		SavedWorkingProcessServerName = Lower(LockParameters.ComputerName);
		
		InfobaseNameChanged = BaseName <> SavedInfobaseName;
		ComputerNameChanged = LockParameters.CheckServerName
			And WorkingProcessServerName <> SavedWorkingProcessServerName
			And StrFind(SavedConnectionManagerServerName, ConnectionManagerServerName) = 0;
		
		// mIn scalable clusters, "SavedConnectionManagerServerName" might contain
		// multiple server names that act as connection managers.
		// When starting the scheduled job, "ConnectionManagerServerName" contains the name of the active manager. 
		// To work with that, search for the current server in the saved name.
		
		If InfobaseNameChanged Or ComputerNameChanged Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameters of client-server base uniqueness control were changed.
				           |
				           |Previous parameters:
				           |Connection string: <%1>
				           |Computer name: <%2>
				           |
				           |Current parameters:
				           |Connection string: <%3>
				           |Computer name: <%4>
				           |
				           |Check server name: <%5>';"),
				LockParameters.ConnectionString, 
				SavedWorkingProcessServerName,
				ConnectionString,
				WorkingProcessServerName,
				LockParameters.CheckServerName);
			
			SetFlagShowsNecessityOfLock(LockParameters, MessageText);
			Return True;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

Procedure SetFlagShowsNecessityOfLock(LockParameters, MessageText)
	
	BlockLockParametersData();
	
	CurrentBlockingParameters = SavedLockParameters();
	If CurrentBlockingParameters.OperationsWithExternalResourcesLocked = Undefined Then
		// If the flag indicating that a lock decision should be made was set in another session.
		Return;
	EndIf;
	
	LockParameters.OperationsWithExternalResourcesLocked = Undefined;
	LockParameters.LockReason = LockReasonPresentation(LockParameters);
	SaveLockParameters(LockParameters);
	
	SSLSubsystemsIntegration.WhenYouAreForbiddenToWorkWithExternalResources();
	ExternalResourcesOperationsLockOverridable.WhenYouAreForbiddenToWorkWithExternalResources();
	
	WriteLogEvent(EventLogEventName(), EventLogLevel.Warning,,, MessageText);
	
EndProcedure

Function LockReasonPresentation(LockParameters)
	
	CurrentDate = CurrentDate(); // ACC:143 Lock information is required in server date.
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'The lock was set on server <b>%1</b> on <b>%2</b> at <b>%3</b> %4.
		           |
		           |The infobase location has been changed. Old location: 
		           |<b>%5</b>
		           |New location: 
		           |<b>%6</b>';"),
		ComputerName(),
		Format(CurrentDate, "DLF=D"),
		Format(CurrentDate, "DLF=T"),
		CurrentOperationPresentation(),
		ConnectionStringPresentation(LockParameters.ConnectionString),
		ConnectionStringPresentation(InfoBaseConnectionString()));
	
EndFunction

Function CurrentOperationPresentation()
	
	CurrentInfobaseSession1 = GetCurrentInfoBaseSession();
	BackgroundJob = CurrentInfobaseSession1.GetBackgroundJob();
	IsScheduledJobSession = BackgroundJob <> Undefined And BackgroundJob.ScheduledJob <> Undefined;
	
	If IsScheduledJobSession Then
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'on attempt to execute scheduled job <b>%1</b>';"),
			BackgroundJob.ScheduledJob.Description);
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'when user <b>%1</b> logged in';"),
		UserName());
	
EndFunction

Function ConnectionStringPresentation(ConnectionString)
	
	Result = ConnectionString;
	
	Parameters = StringFunctionsClientServer.ParametersFromString(ConnectionString);
	If Parameters.Property("File") Then
		Result = Parameters.File;
	EndIf;
	
	Return Result;
	
EndFunction

Function EventLogEventName() Export 
	
	Return NStr("en = 'Online activities are disabled';", Common.DefaultLanguageCode());
	
EndFunction

#EndRegion

#EndRegion