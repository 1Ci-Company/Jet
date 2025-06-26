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

#Region Internal

// See StandardSubsystemsServer.ExtensionParameter
Function ExtensionParameter(ParameterName, IgnoreExtensionsVersion = False, IsAlreadyModified = Undefined) Export
	
	ExtensionsVersion = ?(IgnoreExtensionsVersion,
		Catalogs.ExtensionsVersions.EmptyRef(), SessionParameters.ExtensionsVersion);
	
	Query = New Query;
	Query.SetParameter("ExtensionsVersion", ExtensionsVersion);
	Query.SetParameter("ParameterName", ParameterName);
	Query.Text =
	"SELECT
	|	ExtensionVersionParameters.ParameterStorage
	|FROM
	|	InformationRegister.ExtensionVersionParameters AS ExtensionVersionParameters
	|WHERE
	|	ExtensionVersionParameters.ExtensionsVersion = &ExtensionsVersion
	|	AND ExtensionVersionParameters.ParameterName = &ParameterName";
	
	SetSafeModeDisabled(True);
	SetPrivilegedMode(True);
	Selection = Query.Execute().Select();
	SetPrivilegedMode(False);
	SetSafeModeDisabled(False);
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	Try
		Content = Selection.ParameterStorage.Get();
	Except
		// If a data extraction error occurs, the data processor runs the same way as if the parameter is empty.
		// 
		ErrorInfo = ErrorInfo();
		Comment = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'When getting extension version parameter
			           |%1
			           |, an error of retrieving the value from the storage occurred:
			           |%2';"),
			ParameterName,
			ErrorProcessing.DetailErrorDescription(ErrorInfo));
		EventName = NStr("en = 'Configuration extensions.Get extension parameter';",
			Common.DefaultLanguageCode());
		WriteLogEvent(EventName, EventLogLevel.Information,,, Comment);
		Return Undefined;
	EndTry;
	
	If Not IgnoreExtensionsVersion
	 Or TypeOf(Content) <> Type("Structure")
	 Or Content.Count() <> 5
	 Or Not Content.Property("NumberOfSessionThatModifiedParameter")
	 Or Not Content.Property("StartOfSessionThatModifiedParameter")
	 Or Not Content.Property("ComputerKeyForSessionThatModifiedParameter")
	 Or Not Content.Property("RealTimeTimestampOfSessionThatModifiedParameter")
	 Or Not Content.Property("ParameterValue") Then
		Return Content;
	EndIf;
	
	If TypeOf(IsAlreadyModified) <> Type("Boolean") Then
		Return Content.ParameterValue;
	EndIf;
	
	Timestamp1 = Catalogs.ExtensionsVersions.SessionRealtimeTimestamp();
	
	If TypeOf(Content.RealTimeTimestampOfSessionThatModifiedParameter) <> Type("Date")
	 Or Not ValueIsFilled(Content.RealTimeTimestampOfSessionThatModifiedParameter) Then
		IsAlreadyModified = True;
	Else
		SessionProperties = StandardSubsystemsCached.CurrentSessionProperties();
		If Common.FileInfobase()
		   And SessionProperties.ComputerKey <> Content.ComputerKeyForSessionThatModifiedParameter Then
			Move = 60*60;
		Else
			Move = 15;
		EndIf;
		If Content.RealTimeTimestampOfSessionThatModifiedParameter
				+ Move >= Timestamp1 Then
			IsAlreadyModified = True;
		EndIf;
	EndIf;
	
	If IsAlreadyModified Then
		ConfigurationChanged = DataBaseConfigurationChangedDynamically();
		ExtensionsChanged = Catalogs.ExtensionsVersions.ExtensionsChangedDynamically();
		If ConfigurationChanged Or ExtensionsChanged Then
			Comment = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'When getting extension version parameter
				           |%1
				           |to change in the current session (with outdated metadata version: %2),
				           |%3
				           |the system detected that the parameter had been changed in session
				           |%4';"),
				ParameterName,
				?(ConfigurationChanged And ExtensionsChanged, "Configuration, Extensions",
					?(ConfigurationChanged, "Configuration", "Extensions")),
				Format(SessionProperties.SessionStarted, "DLF=DT;")
					+ " " + Format(SessionProperties.SessionNumber, "NZ=0; NG=;")
					+ " [" + SessionProperties.ComputerKey + "]"
					+ " (" + Format(Timestamp1, "DLF=DT;") + ")",
				Format(Content.StartOfSessionThatModifiedParameter, "DLF=DT;")
					+ " " + Format(Content.NumberOfSessionThatModifiedParameter, "NZ=0; NG=;")
					+ " [" + Content.ComputerKeyForSessionThatModifiedParameter + "]"
					+ " (" + Format(Content.RealTimeTimestampOfSessionThatModifiedParameter, "DLF=DT;") + ")");
			EventName = NStr("en = 'Configuration extensions.Get extension parameter';",
				Common.DefaultLanguageCode());
			WriteLogEvent(EventName, EventLogLevel.Information,,, Comment);
		EndIf;
	EndIf;
	
	Return Content.ParameterValue;
	
EndFunction

// See StandardSubsystemsServer.SetExtensionParameter.
Procedure SetExtensionParameter(ParameterName, Value, IgnoreExtensionsVersion = False) Export
	
	UsersInternal.CheckSafeModeIsDisabled(
		"InformationRegisters.ExtensionVersionParameters.SetExtensionParameter");
	
	ExtensionsVersion = ?(IgnoreExtensionsVersion,
		Catalogs.ExtensionsVersions.EmptyRef(), SessionParameters.ExtensionsVersion);
	
	If IgnoreExtensionsVersion Then
		SessionProperties = StandardSubsystemsCached.CurrentSessionProperties();
		Content = New Structure;
		Content.Insert("ParameterValue", Value);
		Content.Insert("NumberOfSessionThatModifiedParameter",          SessionProperties.SessionNumber);
		Content.Insert("StartOfSessionThatModifiedParameter",         SessionProperties.SessionStarted);
		Content.Insert("ComputerKeyForSessionThatModifiedParameter", SessionProperties.ComputerKey);
		Content.Insert("RealTimeTimestampOfSessionThatModifiedParameter",
			Catalogs.ExtensionsVersions.SessionRealtimeTimestamp());
	Else
		Content = Value;
	EndIf;
	
	RecordSet = InformationRegisters.ApplicationRuntimeParameters.ServiceRecordSet(
		InformationRegisters.ExtensionVersionParameters);
	
	RecordSet.Filter.ExtensionsVersion.Set(ExtensionsVersion);
	RecordSet.Filter.ParameterName.Set(ParameterName);
	
	NewRecord = RecordSet.Add();
	NewRecord.ExtensionsVersion   = ExtensionsVersion;
	NewRecord.ParameterName       = ParameterName;
	NewRecord.ParameterStorage = New ValueStorage(Content);
	
	RecordSet.Write();
	
EndProcedure

// Forces all run parameters to be filled for the current extension version.
Procedure FillAllExtensionParameters() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	// Fill extension metadata object IDs.
	If ValueIsFilled(SessionParameters.AttachedExtensions) Then
		Refresh = Catalogs.ExtensionObjectIDs.CurrentVersionExtensionObjectIDsFilled();
		StandardSubsystemsCached.MetadataObjectIDsUsageCheck(True, True);
	Else
		Refresh = True;
	EndIf;
	
	If Refresh Then
		Catalogs.ExtensionObjectIDs.UpdateCatalogData();
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetARecordOfAccessRestrictionParametersInTheCurrentSession(True);
		Try
			SSLSubsystemsIntegration.OnFillAllExtensionParameters();
		Except
			ModuleAccessManagementInternal.SetARecordOfAccessRestrictionParametersInTheCurrentSession(False);
			Raise;
		EndTry;
		ModuleAccessManagementInternal.SetARecordOfAccessRestrictionParametersInTheCurrentSession(False);
	Else
		SSLSubsystemsIntegration.OnFillAllExtensionParameters();
	EndIf;
	
	ParameterName = "StandardSubsystems.Core.LastFillingDateOfAllExtensionsParameters";
	StandardSubsystemsServer.SetExtensionParameter(ParameterName, CurrentSessionDate(), True);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
EndProcedure

// Returns the date of the last filling in the extension version operation parameters.
// 
// Returns:
//  Date
//
Function LastFillingDateOfAllExtensionsParameters() Export
	
	ParameterName = "StandardSubsystems.Core.LastFillingDateOfAllExtensionsParameters";
	UpdateDate = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	If TypeOf(UpdateDate) <> Type("Date") Then
		UpdateDate = '00010101';
	EndIf;
	
	Return UpdateDate;
	
EndFunction

// Forces all run parameters to be cleared for the current extension version.
// Only registers are cleared, catalogs are not changed. Called to
// refill extension parameter values, for example, when you use the StartInfobaseUpdate launch
// parameter.
// 
// The ExtensionVersionParameters common register is cleared automatically. If you use
// your own information registers that store extension metadata object cache versions,
// attach the OnClearAllExtemsionRunParameters event of the SSLSubsystemsIntegration
// common module.
//
Procedure ClearAllExtensionParameters() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.ApplicationRuntimeParameters.ServiceRecordSet(
			InformationRegisters.ExtensionVersionObjectIDs);
		RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
		RecordSet.Write();
		
		RecordSet = InformationRegisters.ApplicationRuntimeParameters.ServiceRecordSet(
			InformationRegisters.ExtensionVersionParameters);
		RecordSet.Filter.ExtensionsVersion.Set(SessionParameters.ExtensionsVersion);
		RecordSet.Write();
		
		SSLSubsystemsIntegration.OnClearAllExtemsionParameters();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	RefreshReusableValues();
	
EndProcedure

// This is required for the Extensions common form.
Procedure FillAllExtensionParametersBackgroundJob(Parameters) Export
	
	ErrorText = "";
	UnattachedExtensions = "";
	
	If Parameters.ConfigurationName    <> Metadata.Name
	 Or Parameters.ConfigurationVersion <> Metadata.Version Then
		ErrorText =
			NStr("en = 'Cannot update all of the extension parameters
			           |because the configuration name or version was changed. Please restart the session.';");
	EndIf;
	
	InstalledExtensions = Catalogs.ExtensionsVersions.InstalledExtensions();
	
	If Parameters.InstalledExtensions.Main_    <> InstalledExtensions.Main_
	 Or Parameters.InstalledExtensions.Corrections <> InstalledExtensions.Corrections Then
		ErrorText =
			NStr("en = 'Cannot update all extension parameters
			           |as the extensions changed again before the update job started.
			           |Retry the operation.';");
	EndIf;
	
	If TypeOf(Parameters.ExtensionsToCheck) = Type("Map") Then
		Extensions = ConfigurationExtensions.Get(, ConfigurationExtensionsSource.SessionApplied); // Array of ConfigurationExtension -
		AttachedExtensions = New Map;
		For Each Extension In Extensions Do
			AttachedExtensions[Extension.Name] = True;
		EndDo;
		For Each ExtensionToCheck In Parameters.ExtensionsToCheck Do
			If AttachedExtensions[ExtensionToCheck.Key] = Undefined Then
				UnattachedExtensions = UnattachedExtensions
					 + ?(UnattachedExtensions = "", "", ", ") + ExtensionToCheck.Value;
			EndIf;
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(ErrorText) Then
		Try
			FillAllExtensionParameters();
		Except
			ErrorInfo = ErrorInfo();
			ErrorText = ErrorProcessing.DetailErrorDescription(ErrorInfo);
		EndTry;
	EndIf;
	
	If Not ValueIsFilled(ErrorText) Then
		MarkFillingOptionsExtensionsWork();
	EndIf;
	
	If ValueIsFilled(Parameters.AsynchronousCallText) Then
		If ValueIsFilled(ErrorText) Then
			ErrorText = Parameters.AsynchronousCallText + ":" + Chars.LF + ErrorText;
			Raise ErrorText;
		Else
			Return;
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ErrorText",              ErrorText);
	Result.Insert("UnattachedExtensions", UnattachedExtensions);
	
	PutToTempStorage(Result, Parameters.ResultAddress);
	
EndProcedure

Procedure UpdateExtensionParameters(ExtensionsToCheck = Undefined, UnattachedExtensions = "", AsynchronousCallText = "") Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ExecutionParameters = New Structure;
	ExecutionParameters.Insert("ConfigurationName",         Metadata.Name);
	ExecutionParameters.Insert("ConfigurationVersion",      Metadata.Version);
	ExecutionParameters.Insert("InstalledExtensions", Catalogs.ExtensionsVersions.InstalledExtensions());
	ExecutionParameters.Insert("ExtensionsToCheck",   ExtensionsToCheck);
	ExecutionParameters.Insert("ResultAddress",         PutToTempStorage(Undefined));
	ExecutionParameters.Insert("AsynchronousCallText", AsynchronousCallText);
	ProcedureParameters = New Array;
	ProcedureParameters.Add(ExecutionParameters);
	
	CurrentSession = GetCurrentInfoBaseSession();
	JobDescription =
		NStr("en = 'The common form of the ""Fill in extension parameters"" extension';",
			Common.DefaultLanguageCode())
		 + " (" + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'from the %1 session started on %2';", Common.DefaultLanguageCode()),
			Format(CurrentSession.SessionNumber, "NG="),
			Format(CurrentSession.SessionStarted, "DLF=DT")) + ")";
	
	BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
		"StandardSubsystemsServer.FillAllExtensionParametersBackgroundJob",
		ProcedureParameters, , JobDescription);
	
	If ValueIsFilled(AsynchronousCallText) Then
		Return;
	EndIf;
	BackgroundJob.WaitForExecutionCompletion();
	Filter = New Structure("UUID", BackgroundJob.UUID);
	BackgroundJob = BackgroundJobs.GetBackgroundJobs(Filter)[0];
	If BackgroundJob.ErrorInfo <> Undefined Then
		ErrorText = ErrorProcessing.DetailErrorDescription(BackgroundJob.ErrorInfo);
		Raise ErrorText;
	EndIf;
	
	Result = GetFromTempStorage(ExecutionParameters.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		ErrorText = NStr("en = 'The background job that prepares extensions did not return a result.';");
		Raise ErrorText;
	EndIf;
	
	If ValueIsFilled(Result.ErrorText) Then
		Raise Result.ErrorText;
	EndIf;
	
	If ValueIsFilled(Result.UnattachedExtensions) Then
		UnattachedExtensions = Result.UnattachedExtensions;
	EndIf;
	
EndProcedure

// For procedure HandleClientParametersAtServer of common module StandardSubsystemsServerCall.
Procedure OnFirstServerCall() Export
	
	SetPrivilegedMode(True);
	
	If CurrentRunMode() = Undefined
	 Or Not Common.SeparatedDataUsageAvailable()
	 Or Not RequiredEnableFillingExtensionsWorkParameters()
	 Or InformationRegisters.ApplicationRuntimeParameters.UpdateRequired1()
	 Or Not Common.DataSeparationEnabled()
	   And ExchangePlans.MasterNode() = Undefined
	   And ValueIsFilled(Constants.MasterNode.Get()) Then
		Return;
	EndIf;
	
	EnableFillingExtensionsWorkParameters(Common.DebugMode()
		Or Not Common.FileInfobase()
		  And Common.DataSeparationEnabled());
	
EndProcedure

// For procedure OnStartExecuteScheduledJob of common module Common.
Procedure UponSuccessfulStartoftheExecutionoftheScheduledTask() Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	If CurrentSession.ApplicationName <> "BackgroundJob" Then
		Return;
	EndIf;
	
	If Not Common.SeparatedDataUsageAvailable()
	 Or Not RequiredEnableFillingExtensionsWorkParameters() Then
		Return;
	EndIf;
	
	CurrentBackgroundJob = CurrentSession.GetBackgroundJob();
	JobMetadata = Metadata.ScheduledJobs.FillExtensionsOperationParameters;
	Run = CurrentBackgroundJob <> Undefined
		And CurrentBackgroundJob.MethodName <> JobMetadata.MethodName
		And (Not Common.DataSeparationEnabled()
		   Or DataAreaIsActivelyUsed());
	
	EnableFillingExtensionsWorkParameters(Run);
	
EndProcedure

// Can be called only from StandardSubsystemsServer.FillExtensionsOperationParameters.
// 
// Handles the FillExtensionsOperationParameters scheduled job.
// 
Procedure FillinAllJobParametersLatestVersionExtensions() Export
	
	If TransactionActive() Then
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	If CurrentSession.ApplicationName <> "BackgroundJob" Then
		Return;
	EndIf;
	CurrentBackgroundJob = CurrentSession.GetBackgroundJob();
	If CurrentBackgroundJob = Undefined Then
		Return;
	EndIf;
	CurrentJobID = CurrentBackgroundJob.UUID;
	
	// Register the active background job as running. Or close it if exists.
	ParameterName = "StandardSubsystems.Core.SettingFillingWorkParametersExtensions";
	JobID = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	ActiveBackgroundJob = Undefined;
	FillActiveBackgroundQuest(ActiveBackgroundJob, JobID);
	If ActiveBackgroundJob <> Undefined Then
		Return;
	EndIf;
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	LockSet = False;
	
	BeginTransaction();
	Try
		Block.Lock();
		LockSet = True;
		JobID = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
		FillActiveBackgroundQuest(ActiveBackgroundJob, JobID);
		If ActiveBackgroundJob = Undefined Then
			StandardSubsystemsServer.SetExtensionParameter(ParameterName,
				CurrentJobID, True);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		If LockSet Then
			Raise;
		EndIf;
		StartFillingWorkParametersExtensions(
			NStr("en = 'Restart due to an unsuccessful attempt to lock the parameter';"));
		Return;
	EndTry;
	
	If ActiveBackgroundJob <> Undefined Then
		Return;
	EndIf;
	
	// Restart if the metadata in outdated.
	ExtensionsVersion = SessionParameters.ExtensionsVersion;
	VersionOnStartup = Catalogs.ExtensionsVersions.LastExtensionsVersion();
	
	If VersionOnStartup.ExtensionsVersion <> ExtensionsVersion
	 Or DataBaseConfigurationChangedDynamically()
	 Or Catalogs.ExtensionsVersions.ExtensionsChangedDynamically() Then
		
		StandardSubsystemsServer.SetExtensionParameter(ParameterName, Undefined, True);
		StartFillingWorkParametersExtensions(
			NStr("en = 'Restart due to changing metadata of extensions or
			           |the configuration after startup before the update begins';"));
		Return;
	EndIf;
	
	// Populate all parameters of the current extension version.
	AttemptNumber = 1;
	AttemptsNumber = 3;
	PreviousError = "";
	While True Do
		Try
			FillAllExtensionParameters();
		Except
			ErrorInfo = ErrorInfo();
			SessionRestartRequired = StandardSubsystemsServer.SessionRestartRequired();
			If Not SessionRestartRequired
			 Or Not StandardSubsystemsServer.ThisErrorRequirementRestartSession(ErrorInfo) Then
				CurrentError = ErrorProcessing.DetailErrorDescription(ErrorInfo);
				If PreviousError = CurrentError Then
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'When attempting to fill in %1 from %2, the error of the previous attempt occurred again.';",
							Common.DefaultLanguageCode()),
						Format(AttemptNumber, "NG="),
						Format(AttemptsNumber, "NG="));
				Else
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'When attempting to fill in %1 from %2, the following error occurred:
						           |%3';",
							Common.DefaultLanguageCode()),
						Format(AttemptNumber, "NG="),
						Format(AttemptsNumber, "NG="),
						CurrentError);
					AddAdditionalDetails(ErrorText);
				EndIf;
				PreviousError = CurrentError;
				WriteLogEvent(ParameterFillingEventName(),
					EventLogLevel.Error,,, ErrorText);
			EndIf;
			If SessionRestartRequired Then
				StandardSubsystemsServer.SetExtensionParameter(ParameterName, Undefined, True);
				StartFillingWorkParametersExtensions(
					NStr("en = 'Restart due to changing metadata or
					           |extensions when filling the parameters';"));
				Return;
			EndIf;
			AttemptNumber = AttemptNumber + 1;
			If AttemptNumber <= AttemptsNumber Then
				Continue;
			EndIf;
		EndTry;
		Break;
	EndDo;
	
	If Not ValueIsFilled(PreviousError) Then
		Comment = NStr("en = 'Filled in successfully.';",
			Common.DefaultLanguageCode());
		AddAdditionalDetails(Comment);
		WriteLogEvent(ParameterFillingEventName(),
			EventLogLevel.Information,,, Comment);
	EndIf;
	
	Restart = False;
	DisableFillingExtensionsWorkParameters(VersionOnStartup, Restart);
	
	If Restart Then
		StandardSubsystemsServer.SetExtensionParameter(ParameterName, Undefined, True);
		StartFillingWorkParametersExtensions(
			NStr("en = 'Restart due to changing metadata or
			           |extensions after filling the parameters';"));
	EndIf;
	
EndProcedure

// Intended for procedure "UpdateParametersOfExtensionVersionsTakingIntoAccountExecutionMode"
// of the manager module of the "ApplicationParameters" information register
// and procedure "FillAllExtensionParametersBackgroundJob".
//
Procedure MarkFillingOptionsExtensionsWork() Export
	
	SetPrivilegedMode(True);
	
	Catalogs.ExtensionsVersions.RegisterExtensionsVersionUsage();
	ExtensionsVersion = SessionParameters.ExtensionsVersion;
	LatestVersion1 = Catalogs.ExtensionsVersions.LastExtensionsVersion();
	If LatestVersion1.ExtensionsVersion = ExtensionsVersion Then
		DisableFillingExtensionsWorkParameters(LatestVersion1);
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure

Function ParameterFillingEventName() Export
	
	Return NStr("en = 'Configuration extensions.Fill in extension parameters';",
		Common.DefaultLanguageCode());
	
EndFunction

Function TaskNameFillingParameters() Export
	
	Return NStr("en = 'Fill in extension parameters';",
		Common.DefaultLanguageCode());
	
EndFunction

Procedure LockForChangeInFileIB() Export
	
	If TransactionActive() And Common.FileInfobase() Then
		Block = New DataLock;
		Block.Add("InformationRegister.ExtensionVersionParameters");
		// ACC:1320:off - No.783.1.3. It's acceptable to call a lock in a transaction external to the file infobase.
		// It is intended to avoid deadlocks caused by an automatic shared
		// lock set to the table when it is read by a query within a transaction.
		Block.Lock();
		// ACC:1320-on
	EndIf;
	
EndProcedure

#Region DeveloperToolUpdateAuxiliaryData

// Parameters:
//  ShouldUpdate - Boolean - The initial value is False.
//
// Returns:
//  Structure:
//   * Core - Structure:
//      ** ExtensionObjectIDs - See UpdateParameterProperties.
//   * AttachableCommands - Structure:
//      ** ConnectableExtensionCommands - See UpdateParameterProperties.
//   * Users - Structure:
//      ** UserGroupsHierarchy - See UpdateParameterProperties.
//      ** UserGroupCompositions - See UpdateParameterProperties.
//      ** UsersInfo - See UpdateParameterProperties.
//   * AccessManagement - Structure:
//      ** SuppliedAccessGroupProfiles     - See UpdateParameterProperties.
//      ** UnsuppliedAccessGroupProfiles   - See UpdateParameterProperties.
//      ** InfobaseUsersRoles - See UpdateParameterProperties.
//      ** AccessRestrictionParameters         - See UpdateParameterProperties.
//      ** AccessGroupsTables                 - See UpdateParameterProperties.
//      ** AccessGroupsValues                - See UpdateParameterProperties.
//      ** ObjectRightsSettingsInheritance    - See UpdateParameterProperties.
//      ** ObjectsRightsSettings               - See UpdateParameterProperties.
//      ** AccessValuesGroups               - See UpdateParameterProperties.
//      ** AccessValuesSets               - See UpdateParameterProperties.
//   * ReportsOptions - Structure:
//      ** ConfigurationReports              - See UpdateParameterProperties.
//      ** IndexSearchReportsConfiguration - See UpdateParameterProperties.
//      ** ExtensionReports                - See UpdateParameterProperties.
//      ** IndexSearchReportsExtensions   - See UpdateParameterProperties.
//   * AccountingAudit - Structure:
//      ** AccountingCheckRules - See UpdateParameterProperties.
//
Function ParametersOfUpdate(ShouldUpdate = False) Export
	
	Parameters = New Structure;
	
	// StandardSubsystems Core
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("ExtensionObjectIDs", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("Core", ParametersSubsystems);
	
	// StandardSubsystems AttachableCommands
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("ConnectableExtensionCommands", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AttachableCommands", ParametersSubsystems);
	
	// StandardSubsystems Users
	ParametersSubsystems = New Structure;
	ParametersSubsystems.Insert("UserGroupsHierarchy", NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("UserGroupCompositions", NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("UsersInfo", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("Users", ParametersSubsystems);
	
	// StandardSubsystems AccessManagement
	ParametersSubsystems.Insert("SuppliedAccessGroupProfiles",     NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("UnsuppliedAccessGroupProfiles",   NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("InfobaseUsersRoles", NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessRestrictionParameters",         NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessGroupsTables",                 NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessGroupsValues",                NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("ObjectRightsSettingsInheritance",    NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("ObjectsRightsSettings",               NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessValuesGroups",               NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("AccessValuesSets",               NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AccessManagement", ParametersSubsystems);
	
	// StandardSubsystems ReportsOptions
	ParametersSubsystems.Insert("ConfigurationReports",              NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("IndexSearchReportsConfiguration", NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("ExtensionReports",                NewUpdateParameterProperties(ShouldUpdate));
	ParametersSubsystems.Insert("IndexSearchReportsExtensions",   NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("ReportsOptions", ParametersSubsystems);
	
	// StandardSubsystems AccountingAudit
	ParametersSubsystems.Insert("AccountingCheckRules", NewUpdateParameterProperties(ShouldUpdate));
	Parameters.Insert("AccountingAudit", ParametersSubsystems);
	
	Return Parameters;
	
EndFunction

// Parameters:
//  Parameters - See ParametersOfUpdate
//  FormIdentifier - UUID
//
Procedure ExecuteUpdateSplitDataInBackground(Parameters, FormIdentifier) Export
	
	OperationParametersList = TimeConsumingOperations.BackgroundExecutionParameters(FormIdentifier);
	OperationParametersList.BackgroundJobDescription = NStr("en = 'Update separated service data';");
	OperationParametersList.WithDatabaseExtensions = True;
	OperationParametersList.WaitCompletion = Undefined;
	
	ProcedureName = "InformationRegisters.ExtensionVersionParameters.LongOperationHandlerPerformUpdateSplitData";
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground(ProcedureName, Parameters, OperationParametersList);
	
	If TimeConsumingOperation.Status <> "Completed2" Then
		If TimeConsumingOperation.Status = "Error" Then
			ErrorText = TimeConsumingOperation.DetailErrorDescription;
		ElsIf TimeConsumingOperation.Status = "Canceled" Then
			ErrorText = NStr("en = 'The background job is canceled.';");
		Else
			ErrorText = NStr("en = 'Background job error';");
		EndIf;
		Raise ErrorText;
	EndIf;
	
	Result = GetFromTempStorage(TimeConsumingOperation.ResultAddress);
	If TypeOf(Result) <> Type("Structure") Then
		ErrorText = NStr("en = 'Background job did not return the result';");
		Raise ErrorText;
	EndIf;
	
	Parameters = Result;
	
EndProcedure

// Parameters:
//  Parameters - See ParametersOfUpdate
//  ResultAddress - String
//
Procedure LongOperationHandlerPerformUpdateSplitData(Parameters, ResultAddress) Export
	
	If Common.DataSeparationEnabled()
	   And Not Common.SeparatedDataUsageAvailable() Then
		ErrorText =
			NStr("en = 'Cannot update extension parameters. Reason:
			           |Cannot update in shared mode.';");
		Raise ErrorText;
	EndIf;
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	If Catalogs.ExtensionsVersions.ExtensionsChangedDynamically() Then
		StandardSubsystemsServer.RequireSessionRestartDueToDynamicUpdateOfProgramExtensions();
	EndIf;
	
	SetPrivilegedMode(True);
	
	// StandardSubsystems Core
	If Parameters.Core.ExtensionObjectIDs.ShouldUpdate Then
		Catalogs.ExtensionObjectIDs.UpdateCatalogData(
			Parameters.Core.ExtensionObjectIDs.HasChanges);
	EndIf;
	
	// StandardSubsystems AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		If Parameters.AttachableCommands.ConnectableExtensionCommands.ShouldUpdate Then
			Parameters.AttachableCommands.ConnectableExtensionCommands.HasChanges =
				ModuleAttachableCommands.OnFillAllExtensionParameters().HasChanges;
		EndIf;
	EndIf;
	
	// StandardSubsystems Users
	If Parameters.Users.UserGroupsHierarchy.ShouldUpdate Then
		InformationRegisters.UserGroupsHierarchy.UpdateRegisterData(
			Parameters.Users.UserGroupsHierarchy.HasChanges);
	EndIf;
	If Parameters.Users.UserGroupCompositions.ShouldUpdate Then
		InformationRegisters.UserGroupCompositions.UpdateRegisterData(
			Parameters.Users.UserGroupCompositions.HasChanges);
	EndIf;
	If Parameters.Users.UsersInfo.ShouldUpdate Then
		InformationRegisters.UsersInfo.UpdateRegisterData(,
			Parameters.Users.UsersInfo.HasChanges);
	EndIf;
	
	// StandardSubsystems AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		If Parameters.AccessManagement.SuppliedAccessGroupProfiles.ShouldUpdate Then
			AccessGroupModule = Common.CommonModule("Catalogs.AccessGroups");
			AccessGroupModule.MarkForDeletionSelectedProfilesAccessGroups(
				Parameters.AccessManagement.SuppliedAccessGroupProfiles.HasChanges);
			ModuleAccessGroupsProfiles = Common.CommonModule("Catalogs.AccessGroupProfiles");
			ModuleAccessGroupsProfiles.UpdateSuppliedProfiles(
				Parameters.AccessManagement.SuppliedAccessGroupProfiles.HasChanges);
		EndIf;
		If Parameters.AccessManagement.UnsuppliedAccessGroupProfiles.ShouldUpdate Then
			ModuleAccessGroupsProfiles = Common.CommonModule("Catalogs.AccessGroupProfiles");
			ModuleAccessGroupsProfiles.UpdateUnshippedProfiles(
				Parameters.AccessManagement.UnsuppliedAccessGroupProfiles.HasChanges);
		EndIf;
		If Parameters.AccessManagement.InfobaseUsersRoles.ShouldUpdate Then
			ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
			ModuleAccessManagementInternal.UpdateUserRoles(,,
				Parameters.AccessManagement.InfobaseUsersRoles.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessRestrictionParameters.ShouldUpdate Then
			ModuleParametersAccessRestrictions = Common.CommonModule(
				"InformationRegisters.AccessRestrictionParameters");
			ModuleParametersAccessRestrictions.UpdateRegisterData(
				Parameters.AccessManagement.AccessRestrictionParameters.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessGroupsTables.ShouldUpdate Then
			ModuleTableGroupAccess = Common.CommonModule(
				"InformationRegisters.AccessGroupsTables");
			ModuleTableGroupAccess.UpdateRegisterData(,,
				Parameters.AccessManagement.AccessGroupsTables.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessGroupsValues.ShouldUpdate Then
			ModuleAccessGroupValues = Common.CommonModule(
				"InformationRegisters.AccessGroupsValues");
			ModuleAccessGroupValues.UpdateRegisterData(,
				Parameters.AccessManagement.AccessGroupsValues.HasChanges);
		EndIf;
		If Parameters.AccessManagement.ObjectRightsSettingsInheritance.ShouldUpdate Then
			ModuleInheritanceSettingsRightsObjects = Common.CommonModule(
				"InformationRegisters.ObjectRightsSettingsInheritance");
			ModuleInheritanceSettingsRightsObjects.UpdateRegisterData(,
				Parameters.AccessManagement.ObjectRightsSettingsInheritance.HasChanges);
		EndIf;
		If Parameters.AccessManagement.ObjectsRightsSettings.ShouldUpdate Then
			ModuleSettingsRightsObjects = Common.CommonModule(
				"InformationRegisters.ObjectsRightsSettings");
			ModuleSettingsRightsObjects.UpdateAuxiliaryRegisterData(
				Parameters.AccessManagement.ObjectsRightsSettings.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessValuesGroups.ShouldUpdate Then
			AccessValueGroupModule = Common.CommonModule(
				"InformationRegisters.AccessValuesGroups");
			AccessValueGroupModule.UpdateRegisterData(
				Parameters.AccessManagement.AccessValuesGroups.HasChanges);
		EndIf;
		If Parameters.AccessManagement.AccessValuesSets.ShouldUpdate Then
			ModuleAccessValueSets = Common.CommonModule(
				"InformationRegisters.AccessValuesSets");
			ModuleAccessValueSets.UpdateRegisterData(
				Parameters.AccessManagement.AccessValuesSets.HasChanges);
		EndIf;
	EndIf;
	
	// StandardSubsystems ReportsOptions
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		
		Settings = ModuleReportsOptions.SettingsUpdateParameters();
		Settings.SharedData = False;
		Settings.SeparatedData = True;
		Settings.Configuration = True;
		Settings.Extensions = False;
		If Parameters.ReportsOptions.ConfigurationReports.ShouldUpdate Then
			Settings.Nonexclusive = True;
			Settings.Deferred2 = False;
			Parameters.ReportsOptions.ConfigurationReports.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
		If Parameters.ReportsOptions.IndexSearchReportsConfiguration.ShouldUpdate Then
			Settings.Nonexclusive = False;
			Settings.Deferred2 = True;
			Settings.IndexSchema = True;
			Parameters.ReportsOptions.IndexSearchReportsConfiguration.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
		
		Settings = ModuleReportsOptions.SettingsUpdateParameters();
		Settings.SharedData = True; // Predefined data.
		Settings.SeparatedData = True;
		Settings.Configuration = False;
		Settings.Extensions = True;
		If Parameters.ReportsOptions.ExtensionReports.ShouldUpdate Then
			Settings.Nonexclusive = True;
			Settings.Deferred2 = False;
			Parameters.ReportsOptions.ExtensionReports.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
		If Parameters.ReportsOptions.IndexSearchReportsExtensions.ShouldUpdate Then
			Settings.Nonexclusive = False;
			Settings.Deferred2 = True;
			Settings.IndexSchema = True;
			Parameters.ReportsOptions.IndexSearchReportsExtensions.HasChanges =
				ModuleReportsOptions.Refresh(Settings).HasChanges;
		EndIf;
	EndIf;
	
	// StandardSubsystems AccountingAudit
	If Common.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternal = Common.CommonModule("AccountingAuditInternal");
		If Parameters.AccountingAudit.AccountingCheckRules.ShouldUpdate Then
			ModuleAccountingAuditInternal.UpdateAuxiliaryRegisterDataByConfigurationChanges();
			Parameters.AccountingAudit.AccountingCheckRules.HasChanges = True;
		EndIf;
	EndIf;
	
	PutToTempStorage(Parameters, ResultAddress);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Intended for the procedures OnFirstServerCall, OnStartScheduledJobSucceed,
// and DisableExtensionParametersPopulation.
//
Function RequiredEnableFillingExtensionsWorkParameters()
	
	LastExtensionsVersion = Catalogs.ExtensionsVersions.LastExtensionsVersion();
	
	ParameterName = "StandardSubsystems.Core.IdFillingExtensionsJobParameters";
	FillId = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	Return LastExtensionsVersion.UpdateID <> FillId;
	
EndFunction

Function DataAreaIsActivelyUsed()
	
	Days1 =  60*60*24;
	ConstantName = "LastClientSessionStartDate";
	MetadataConstants = Metadata.Constants.Find(ConstantName);
	If MetadataConstants <> Undefined Then
		Query = New Query;
		Query.SetParameter("StartBoundary", CurrentUniversalDate() - Days1*2);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	&Table AS Table
		|WHERE
		|	Table.Value >= &StartBoundary";
		Query.Text = StrReplace(Query.Text, "&Table", MetadataConstants.FullName());
		If Not Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ActivityBoundary",
		BegOfDay(CurrentSessionDate() - 60*60) - Days1);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.UsersInfo AS UsersInfo
	|WHERE
	|	UsersInfo.LastActivityDate >= &ActivityBoundary";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

// Intended for the procedures OnFirstServerCall, OnStartScheduledJobSucceed,
// of the Extensions common form and StandardSubsystemsServer.AfterImportData.
//
// Parameters:
//  Run - Boolean
//  EnableDefinitely - Boolean
//
Procedure EnableFillingExtensionsWorkParameters(Run = True, EnableDefinitely = False) Export
	
	ParameterName = "StandardSubsystems.Core.IdFillingExtensionsJobParameters";
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	Filter = New Structure("Metadata", Metadata.ScheduledJobs.FillExtensionsOperationParameters);
	
	BeginTransaction();
	Try
		Block.Lock();
		UpdateID = Catalogs.ExtensionsVersions.LastExtensionsVersion().UpdateID;
		FillId = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
		If EnableDefinitely Or UpdateID <> FillId Then
			If UpdateID <> FillId Then
				StandardSubsystemsServer.SetExtensionParameter(ParameterName,
					UpdateID, True);
			EndIf;
			Jobs = ScheduledJobsServer.FindJobs(Filter);
			For Each Job In Jobs Do
				ScheduledJobsServer.ChangeJob(Job.UUID,
					New Structure("Use", True));
			EndDo;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Run Then
		StartFillingWorkParametersExtensions(
			NStr("en = 'Startup with app parameter setup enabled';"));
	EndIf;
	
EndProcedure

// For the PopulateAllLastExtensionsVersionsParameters procedure.
Procedure FillActiveBackgroundQuest(ActiveBackgroundJob, JobID)
	
	If TypeOf(JobID) = Type("UUID") Then
		ActiveBackgroundJob = BackgroundJobs.FindByUUID(JobID);
		If ActiveBackgroundJob <> Undefined
		   And ActiveBackgroundJob.State <> BackgroundJobState.Active Then
			ActiveBackgroundJob = Undefined;
		EndIf;
	EndIf;
	
EndProcedure

// Intended for the PopulateAllLastExtensionsVersionsParameters
// and MarkExtensionsParametersAsPopulated procedures.
//
// Parameters:
//  VersionOnStartup - See Catalogs.ExtensionsVersions.LastExtensionsVersion
//  Restart    - Boolean - Return value.
//
Procedure DisableFillingExtensionsWorkParameters(VersionOnStartup, Restart = False)
	
	ParameterName = "StandardSubsystems.Core.IdFillingExtensionsJobParameters";
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.ExtensionVersionParameters");
	LockItem.SetValue("ExtensionsVersion", Catalogs.ExtensionsVersions.EmptyRef());
	LockItem.SetValue("ParameterName", ParameterName);
	
	Filter = New Structure("Metadata", Metadata.ScheduledJobs.FillExtensionsOperationParameters);
	
	BeginTransaction();
	Try
		Block.Lock();
		CurrentVersion = Catalogs.ExtensionsVersions.LastExtensionsVersion();
		
		If VersionOnStartup.ExtensionsVersion = CurrentVersion.ExtensionsVersion
		   And VersionOnStartup.UpdateDate = CurrentVersion.UpdateDate
		   And Not DataBaseConfigurationChangedDynamically()
		   And Not Catalogs.ExtensionsVersions.ExtensionsChangedDynamically() Then
			
			UpdateID = CurrentVersion.UpdateID;
			FillId = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
			If UpdateID <> FillId Then
				StandardSubsystemsServer.SetExtensionParameter(ParameterName,
					UpdateID, True);
			EndIf;
			
			Jobs = ScheduledJobsServer.FindJobs(Filter);
			For Each Job In Jobs Do
				ScheduledJobsServer.ChangeJob(Job.UUID,
					New Structure("Use", False));
			EndDo;
		Else
			Restart = True;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Intended for the procedures EnableFillingExtensionsRuntimeParameters
// PopulateAllLastExtensionsVersionsParameters and
// StandardSubsystemsServer.AfterImportData.
// 
// Parameters:
//  WaitForCompletion - Boolean - Ignored in file infobases.
//
Procedure StartFillingWorkParametersExtensions(Comment, WaitForCompletion = False) Export
	
	If TransactionActive()
	 Or ExclusiveMode()
	   And Not WaitForCompletion
	 Or DataBaseConfigurationChangedDynamically()
	   And Common.FileInfobase() Then
		// For file infobases, a background job with database extensions is executed
		// with the same version of the dynamic configuration generation.
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	JobMetadata = Metadata.ScheduledJobs.FillExtensionsOperationParameters;
	
	JobDescription =
		NStr("en = 'Autostart';", Common.DefaultLanguageCode())
		+ ": " + JobMetadata.Synonym + " ("
		+ StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'from the %1 session started on %2';", Common.DefaultLanguageCode()),
			Format(CurrentSession.SessionNumber, "NG="),
			Format(CurrentSession.SessionStarted, "DLF=DT")) + ")";
	
	WriteLogEvent(ParameterFillingEventName(),
		EventLogLevel.Information,,, Comment);
	
	BackgroundJob = ConfigurationExtensions.ExecuteBackgroundJobWithDatabaseExtensions(
		JobMetadata.MethodName,,, JobDescription);
	
	If WaitForCompletion
	   And BackgroundJob <> Undefined
	   And (CurrentRunMode() <> Undefined
	      Or Not Common.FileInfobase()) Then
		
		BackgroundJob.WaitForExecutionCompletion();
	EndIf;
	
EndProcedure

// For the PopulateAllLastExtensionsVersionsParameters procedure.
Procedure AddAdditionalDetails(Comment)
	
	ExtensionsDetails = Catalogs.ExtensionsVersions.DescriptionExtensionsForJournal();
	
	AdditionalInfo = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '*** Additional information records ***
		           |
		           |1. Applied extensions (including patches):
		           |%1
		           |
		           |2. Disabled extensions (including patches):
		           |%2
		           |
		           |3. All database extensions (including patches):
		           |%3
		           |
		           |4. Extension version ""%4""
		           |%5';",
			Common.DefaultLanguageCode()),
		ExtensionsDetails.ConnectedNow,
		ExtensionsDetails.Disabled1,
		ExtensionsDetails.All,
		String(SessionParameters.ExtensionsVersion),
		Common.ObjectAttributeValue(SessionParameters.ExtensionsVersion, "MetadataDetails"));
	
	Comment = Comment + Chars.LF + Chars.LF + AdditionalInfo;
	
EndProcedure

#Region DeveloperToolUpdateAuxiliaryData

// Returns:
//  Structure:
//   * ShouldUpdate     - Boolean - an initial value is True.
//   * HasChanges - Boolean - the initial value is False.
//
Function NewUpdateParameterProperties(ShouldUpdate)
	
	NewProperties = New Structure;
	NewProperties.Insert("ShouldUpdate", ShouldUpdate);
	NewProperties.Insert("HasChanges", False);
	
	Return NewProperties;
	
EndFunction

#EndRegion

#EndRegion

#EndIf