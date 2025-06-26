///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

// Obsolete API for module ClusterAdministrationClientServer.

#If Not WebClient And Not MobileClient Then

#Region Internal

#Region SessionAndJobLock

// Returns the current state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   See ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties
//
Function InfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Result = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, SessionAndScheduledJobLockPropertiesDictionary());
	
	If Result.DateFrom1 = ClusterAdministrationClientServer.DateEmpty() Then
		Result.DateFrom1 = Undefined;
	EndIf;
	
	If Result.DateTo = ClusterAdministrationClientServer.DateEmpty() Then
		Result.DateTo = Undefined;
	EndIf;
	
	If Not ValueIsFilled(Result.KeyCode) Then
		Result.KeyCode = "";
	EndIf;
	
	If Not ValueIsFilled(Result.Message) Then
		Result.Message = "";
	EndIf;
	
	If Not ValueIsFilled(Result.LockParameter) Then
		Result.LockParameter = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Sets the state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  SessionAndJobLockProperties - See ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties
//
Procedure SetInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val SessionAndJobLockProperties) Export
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		SessionAndScheduledJobLockPropertiesDictionary(),
		SessionAndJobLockProperties);
	
EndProcedure

// Checks whether administration parameters are correct.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified in the structure
// passed as the ClusterAdministrationParameters parameter value.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  CheckClusterAdministrationParameters - Boolean - Indicates whether a check of cluster 
//                                                administration parameters is required
//  CheckClusterAdministrationParameters - Boolean - Indicates whether cluster administration
//                                                          parameters check is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckInfobaseAdministrationParameters = True,
	CheckClusterAdministrationParameters = True) Export
	
	
	If CheckClusterAdministrationParameters Or CheckInfobaseAdministrationParameters Then
		
		ClusterID = ClusterID(ClusterAdministrationParameters);
		WorkingProcessesProperties(ClusterID, ClusterAdministrationParameters);
		
	EndIf;
	
	If CheckInfobaseAdministrationParameters Then
		
		Dictionary = New Structure();
		Dictionary.Insert("SessionsLock", "sessions-deny");
		
		InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LockScheduledJobs

// Returns the current state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   Boolean
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	
	IBProperties = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary);
	Return IBProperties.JobsLock;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  LockScheduledJobs - Boolean - Indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val LockScheduledJobs) Export
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	Properties = New Structure("JobsLock", LockScheduledJobs);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Properties);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//           , Array of
//
// Returns:
//   Array of See ClusterAdministrationClientServer.SessionProperties
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Return SessionsProperties(ClusterID, ClusterAdministrationParameters, InfoBaseID, Filter);
	
EndFunction

// Deletes infobase sessions according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//           , Array of
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% terminate --session=%session%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	AttemptsNumber = 3;
	AllSessionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptsNumber Do
		
		Sessions = SessionsProperties(ClusterID, ClusterAdministrationParameters, InfoBaseID, Filter, False);
		
		If Sessions.Count() = 0 Then
			
			AllSessionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptsNumber Then
			
			Break;
			
		EndIf;
		
		For Each Session In Sessions Do
			
			Try
				
				Parameters.Insert("session", Session.Get("session"));
				ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
				
			Except
				
				// The session might close before rac session terminate is called.
				Continue;
				
			EndTry;
			
		EndDo;
		
	EndDo;
	
	If Not AllSessionsTerminated Then
	
		Raise NStr("en = 'Cannot delete sessions.';");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseConnections

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//           , Array of
//
// Returns:
//   Array of See ClusterAdministrationClientServer.ConnectionProperties
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Return ConnectionsProperties(ClusterID, ClusterAdministrationParameters, InfoBaseID, IBAdministrationParameters, Filter, True);
	
EndFunction

// Terminates infobase connections according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//           , Array of
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% disconnect --process=%process% --connection=%connection% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfoBaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	Value = New Array;
	Value.Add("1CV8");               // ID of 1C:Enterprise application running in thick client mode.
	Value.Add("1CV8C");              // ID of 1C:Enterprise application running in thin client mode.
	Value.Add("WebClient");          // ID of 1C:Enterprise application running in web client mode.
	Value.Add("Designer");           // Designer ID.
	Value.Add("COMConnection");      // ID of 1C:Enterprise external COM connection session.
	Value.Add("WSConnection");       // Web service session ID.
	Value.Add("BackgroundJob");      // ID of job processing session.
	Value.Add("WebServerExtension"); // Web server extension ID.

	ClusterAdministrationClientServer.AddFilterCondition(Filter, "ClientApplicationID", ComparisonType.InList, Value);
	
	AttemptsNumber = 3;
	AllConnectionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptsNumber Do
	
		Joins = ConnectionsProperties(ClusterID, ClusterAdministrationParameters, InfoBaseID, IBAdministrationParameters, Filter, False);
		
		If Joins.Count() = 0 Then
			
			AllConnectionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptsNumber Then
			
			Break;
			
		EndIf;
	
		For Each Join In Joins Do
			
			Try
				
				Parameters.Insert("process", Join.Get("process"));
				Parameters.Insert("connection", Join.Get("connection"));
				ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
				
			Except
				
				// The connection might terminate before rac connection disconnect is called.
				Continue;
				
			EndTry;
			
		EndDo;
		
	EndDo;
	
	If Not AllConnectionsTerminated Then
	
		Raise NStr("en = 'Cannot close connections.';");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Returns the name of a security profile assigned to the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   String - name of the security profile set for the infobase. If
//  the infobase is not assigned with a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Result = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
EndFunction

// Returns the name of the security profile that was set as the infobase safe mode
//  security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   String - name of the security profile set for the infobase as the safe mode security
//  profile. If the infobase is not assigned with a security profile, returns
//  an empty string.
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Result = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
EndFunction

// Assigns a security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  ProfileName - String - Security profile name. If the passed string is empty, the security profile is
//    disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Values);
	
EndProcedure

// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is
//    disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Dictionary,
		Values);
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - name of the security profile whose existence is checked.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	Return (SecurityProfiles.Count() = 1);
	
EndFunction

// Returns properties of a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - Security profile name.
//
// Returns:
//   See ClusterAdministrationClientServer.SecurityProfileProperties
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %2 is not registered in server cluster %1.';"), ClusterID, ProfileName);
	EndIf;
	
	Result = SecurityProfiles[0];
	Result = ConvertAccessListsUsagePropertyValues(Result);
	
	// Virtual directories.
	Result.Insert("VirtualDirectories",
		GetVirtualDirectories(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Allowed COM classes.
	Result.Insert("COMClasses",
		GetAllowedCOMClass(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Add-ins.
	Result.Insert("AddIns",
		GetAllowedAddIns(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// External modules.
	Result.Insert("ExternalModules",
		GetAllowedExternalModules(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// OS applications.
	Result.Insert("OSApplications",
		GetAllowedOSApplications(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	// Internet resources.
	Result.Insert("InternetResources",
		GetAllowedInternetResources(ClusterID, ClusterAdministrationParameters, ProfileName));
	
	Return Result;
	
EndFunction

// Creates a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() = 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %2 is already registered in server cluster %1.';"), ClusterID, ProfileName);
	EndIf;
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties, False);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %2 is not registered in server cluster %1.';"), ClusterID, ProfileName);
	EndIf;
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties, True);
	
EndProcedure

// Deletes a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - Security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% remove --name=%name%";
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

#EndRegion

#Region Infobases

// Returns an internal infobase ID.
//
// Parameters:
//  ClusterID - String -internal server cluster ID.
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfobaseAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   String - Internal infobase ID.
//
Function InfoBaseID(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	Filter = New Structure("name", InfobaseAdministrationParameters.NameInCluster);
	
	Infobases = InfobasesProperties(ClusterID, ClusterAdministrationParameters, Filter);
	
	If Infobases.Count() = 1 Then
		Return Infobases[0].Get("infobase");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Infobase %2 is not registered in server cluster %1.';"), ClusterID, InfobaseAdministrationParameters.NameInCluster);
	EndIf;
	
EndFunction

// Returns infobase descriptions
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - Infobase filtering criteria.
//
// Returns:
//   Array of Structure
//
Function InfobasesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac infobase summary --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

#Region Cluster

// Returns an internal ID of a server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//
// Returns:
//  String - Internal server cluster ID.
//
Function ClusterID(Val ClusterAdministrationParameters) Export
	
	Filter = New Structure("port", ClusterAdministrationParameters.ClusterPort);
	
	Clusters = ClusterProperties(ClusterAdministrationParameters, Filter);
	
	If Clusters.Count() = 1 Then
		Return Clusters[0].Get("cluster");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot find a server cluster with port %1.';"), ClusterAdministrationParameters.ClusterPort);
	EndIf;
	
EndFunction

// Returns server cluster descriptions.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - server cluster filtering criteria.
//
// Returns:
//   Array of Structure
//
Function ClusterProperties(Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac cluster list";
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

#Region WorkingProcessesServers

// Returns descriptions of active processes.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID.
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - active process filtering criteria.
//
// Returns:
//   Array of Structure
//
Function WorkingProcessesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac process --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --server=%server%";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Result = New Array();
	WorkingServers = WorkingServerProperties(ClusterID, ClusterAdministrationParameters);
	For Each ServerName In WorkingServers Do
		Parameters.Insert("server", ServerName.Get("server"));
		OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
		ServerWorkingProcesses = OutputParser(OutputStream, Undefined, Filter);
		For Each IWorkingProcessInfo In ServerWorkingProcesses Do
			Result.Add(IWorkingProcessInfo);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns descriptions of active servers.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - active server filtering criteria.
//
// Returns:
//   Array of Structure
//
Function WorkingServerProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Template = "%rac server --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Undefined, Filter);
	Return Result;
	
EndFunction

#EndRegion

// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfoBaseID - String - Internal infobase ID.
//  InfobaseAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//           , Array of
//  UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns:
//   - Array of See ClusterAdministrationClientServer.SessionProperties
//   - Array of Map
//
Function SessionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val Filter = Undefined, Val UseDictionary = True) Export
	
	Template = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --infobase=%infobase%";	
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfoBaseID);
	
	If UseDictionary Then
		Dictionary = SessionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, SessionPropertiesDictionary());
	EndIf;
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary, Filter);
	Return Result;
	
EndFunction

// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID.
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfoBaseID - String - Internal infobase ID.
//  InfobaseAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//           , Array of
//  UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns:
//   - Array of See ClusterAdministrationClientServer.ConnectionProperties
//   - Array of Map
//
Function ConnectionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val InfobaseAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	Template = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --process=%process% --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfoBaseID);
	FillIBAuthenticationParameters(InfobaseAdministrationParameters, Parameters);
	
	If UseDictionary Then
		Dictionary = ConnectionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, ConnectionPropertiesDictionary());
	EndIf;
	
	Result = New Array();
	WorkingProcesses = WorkingProcessesProperties(ClusterID, ClusterAdministrationParameters);
	
	For Each IWorkingProcessInfo In WorkingProcesses Do
		
		Parameters.Insert("process", IWorkingProcessInfo.Get("process"));
		OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
		WorkingProcessConnections = OutputParser(OutputStream, Dictionary, Filter);
		For Each Join In WorkingProcessConnections Do
			If Not UseDictionary Then
				Join.Insert("process", IWorkingProcessInfo.Get("process"));
			EndIf;
			Result.Add(Join);
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns path to the console client of the administration server.
//
// Returns:
//  String
//
Function PathToAdministrationServerClient() Export
	
	StartDirectory = PlatformExecutableFilesDirectory();
	Client = StartDirectory + "rac";
	
	SysInfo = New SystemInfo();
	If (SysInfo.PlatformType = PlatformType.Windows_x86) Or (SysInfo.PlatformType = PlatformType.Windows_x86_64) Then
		Client = Client + ".exe";
	EndIf;
	
	Return Client;
	
EndFunction

#EndRegion

#Region Private

Function PlatformExecutableFilesDirectory()
	
	Result = BinDir();
	SeparatorChar = GetPathSeparator();
	
	If Not StrEndsWith(Result, SeparatorChar) Then
		Result = Result + SeparatorChar;
	EndIf;
	
	Return Result;
	
EndFunction

Function InfobaseProperties1(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary)
	
	Template = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% info --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfoBaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary);
	Return Result[0];
	
EndFunction

Procedure SetInfobaseProperties(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary, Val PropertiesValues)
	
	Template = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update --infobase=%infobase% --infobase-user=%?infobase-user% --infobase-pwd=%?infobase-pwd%";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Parameters.Insert("infobase", InfoBaseID);
	FillIBAuthenticationParameters(IBAdministrationParameters, Parameters);
	
	FillParametersByDictionary(Dictionary, PropertiesValues, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

Function GetSecurityProfiles(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, SecurityProfilePropertiesDictionary(), Filter);
	Return Result;
	
EndFunction

Function GetVirtualDirectories(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"directory", // Not localizable.
		VirtualDirectoryPropertiesDictionary());
	
EndFunction

Function GetAllowedCOMClass(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"com", // Not localizable.
		COMClassPropertiesDictionary());
	
EndFunction

Function GetAllowedAddIns(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"addin", // Not localizable.
		AddInPropertiesDictionary());
	
EndFunction

Function GetAllowedExternalModules(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"module", // Not localizable.
		ExternalModulePropertiesDictionary());
	
EndFunction

Function GetAllowedOSApplications(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"app", // Not localizable.
		OSApplicationPropertiesDictionary());
	
EndFunction

Function GetAllowedInternetResources(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"inet", // Not localizable.
		InternetResourcePropertiesDictionary());
	
EndFunction

// Parameters:
//  ClusterID - String
//  ClusterAdministrationParameters - Structure:
//   * AttachmentType - String
//   * ServerAgentAddress - String
//   * ServerAgentPort - Number
//   * AdministrationServerAddress - String
//   * AdministrationServerPort - Number
//   * ClusterPort - Number
//   * ClusterAdministratorName - String
//   * ClusterAdministratorPassword - String
//  ProfileName - String
//  ListName - String
//  Dictionary - FixedStructure:
//   * Name - String
//   * LongDesc - String
//   * HashSum - String - for backward compatibility.
//  Filter - Undefined
// Returns:
//  Array of See AddInPropertiesDictionary
//
Function AccessManagementLists(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val Filter = Undefined)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory list";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("name", ProfileName);
	
	OutputStream = ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputStream, Dictionary, Filter);
	Return Result;
	
EndFunction

Procedure UpdateSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties, Val ClearAccessManagementLists)
	
	ProfileName = SecurityProfileProperties.Name;
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update ";
	
	Parameters = New Map();
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterID);
	
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	FillParametersByDictionary(SecurityProfilePropertiesDictionary(False), SecurityProfileProperties, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
	AccessManagementListsUsagePropertiesDictionary = AccessManagementListUsagePropertiesDictionary();
	For Each DictionaryFragment In AccessManagementListsUsagePropertiesDictionary Do
		SetAccessManagementListUsage(ClusterID, ClusterAdministrationParameters, ProfileName, DictionaryFragment.Value, Not SecurityProfileProperties[DictionaryFragment.Key]);
	EndDo;
	
	// Virtual directories.
	ListName = "directory";
	CurrentDictionary = VirtualDirectoryPropertiesDictionary();
	If ClearAccessManagementLists Then
		VirtualDirectoriesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each VirtualDirectoryToDelete In VirtualDirectoriesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, VirtualDirectoryToDelete.LogicalURL);
		EndDo;
	EndIf;
	VirtualDirectoriesToCreate = SecurityProfileProperties.VirtualDirectories;
	For Each VirtualDirectoryToCreate In VirtualDirectoriesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, VirtualDirectoryToCreate);
	EndDo;
	
	// Allowed COM classes.
	ListName = "com";
	CurrentDictionary = COMClassPropertiesDictionary();
	If ClearAccessManagementLists Then
		COMClassesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each COMClassToDelete In COMClassesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, COMClassToDelete.Name);
		EndDo;
	EndIf;
	COMClassesToCreate = SecurityProfileProperties.COMClasses;
	For Each COMClassToCreate In COMClassesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, COMClassToCreate);
	EndDo;
	
	// Add-ins.
	ListName = "addin";
	CurrentDictionary = AddInPropertiesDictionary();
	If ClearAccessManagementLists Then
		AddInsToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each AddInToDelete In AddInsToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, AddInToDelete.Name);
		EndDo;
	EndIf;
	AddInsToCreate = SecurityProfileProperties.AddIns;
	For Each AddInToCreate In AddInsToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, AddInToCreate);
	EndDo;
	
	// External modules.
	ListName = "module";
	CurrentDictionary = ExternalModulePropertiesDictionary();
	If ClearAccessManagementLists Then
		ExternalModulesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each ExternalModuleToDelete In ExternalModulesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, ExternalModuleToDelete.Name);
		EndDo;
	EndIf;
	ExternalModulesToCreate = SecurityProfileProperties.ExternalModules;
	For Each ExternalModuleToCreate In ExternalModulesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, ExternalModuleToCreate);
	EndDo;
	
	// OS applications.
	ListName = "app";
	CurrentDictionary = OSApplicationPropertiesDictionary();
	If ClearAccessManagementLists Then
		OSApplicationsToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each OSApplicationToDelete In OSApplicationsToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, OSApplicationToDelete.Name);
		EndDo;
	EndIf;
	OSApplicationsToCreate = SecurityProfileProperties.OSApplications;
	For Each OSApplicationToCreate In OSApplicationsToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, OSApplicationToCreate);
	EndDo;
	
	// Internet resources.
	ListName = "inet";
	CurrentDictionary = InternetResourcePropertiesDictionary();
	If ClearAccessManagementLists Then
		InternetResourcesToDelete = AccessManagementLists(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each InternetResourceToDelete In InternetResourcesToDelete Do
			DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, InternetResourceToDelete.Name);
		EndDo;
	EndIf;
	InternetResourcesToCreate = SecurityProfileProperties.InternetResources;
	For Each InternetResourceToCreate In InternetResourcesToCreate Do
		CreateAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, InternetResourceToCreate);
	EndDo;
	
EndProcedure

Procedure SetAccessManagementListUsage(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Use)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory --access=%access%";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	If Use Then
		Parameters.Insert("access", "list");
	Else
		Parameters.Insert("access", "full");
	EndIf;
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

Procedure DeleteAccessManagementListItem(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val ItemKey)
	
	ListKey = AccessManagementListsKeys()[ListName];
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name% directory remove --key=%key%";
	Template = StrReplace(Template, "directory", ListName);
	Template = StrReplace(Template, "key", ListKey);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	Parameters.Insert(ListKey, ItemKey);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

Procedure CreateAccessManagementListItem(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val ItemProperties)
	
	Template = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%profile_name% directory update";
	Template = StrReplace(Template, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterID);
	FillClusterAuthenticationParameters(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("profile_name", ProfileName);
	
	FillParametersByDictionary(Dictionary, ItemProperties, Parameters, Template);
	
	ExecuteCommand(Template, ClusterAdministrationParameters, Parameters);
	
EndProcedure

Function ConvertAccessListsUsagePropertyValues(Val DetailsStructure)
	
	Dictionary = AccessManagementListUsagePropertiesDictionary();
	
	Result = New Structure;
	
	For Each KeyAndValue In DetailsStructure Do
		
		If Dictionary.Property(KeyAndValue.Key) Then
			
			If KeyAndValue.Value = "list" Then
				
				Value = False;
				
			ElsIf KeyAndValue.Value = "full" Then
				
				Value = True;
				
			EndIf;
			
			Result.Insert(KeyAndValue.Key, Value);
			
		Else
			
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function AdjustValue(Val Value, Val ParameterName = "")
	
	If TypeOf(Value) = Type("Date") Then
		Return Format(Value, "DF=yyyy-MM-ddTHH:mm:ss");
	EndIf;
	
	If TypeOf(Value) = Type("Boolean") Then
		
		If IsBlankString(ParameterName) Then
			FormatString = "BF=off; BT=on";
		Else
			FormatString = BooleanPropertyFormatDictionary()[ParameterName];
		EndIf;
		
		Return Format(Value, FormatString);
		
	EndIf;
	
	If TypeOf(Value) = Type("Number") Then
		Return Format(Value, "NDS=,; NZ=0; NG=0; NN=1");
	EndIf;
	
	If TypeOf(Value) = Type("String") Then
		If StrFind(Value, """") > 0 Or StrFind(Value, " ") > 0 Or StrFind(Value, "-") > 0 Or StrFind(Value, "!") > 0 Then
			Return """" + StrReplace(Value, """", """""") + """";
		EndIf;
	EndIf;
	
	Return String(Value);
	
EndFunction

Function CastOutputItem(OutputItem)
	
	If IsBlankString(OutputItem) Then
		Return Undefined;
	EndIf;
	
	OutputItem = StrReplace(OutputItem, """""", """");
	
	If OutputItem = "on" Or OutputItem = "yes" Then
		Return True;
	EndIf;
	
	If OutputItem = "off" Or OutputItem = "no" Then
		Return False;
	EndIf;
	
	If StringFunctionsClientServer.OnlyNumbersInString(OutputItem) Then
		Return Number(OutputItem);
	EndIf;
	
	Try
		Return XMLValue(Type("Date"), OutputItem);
	Except
		// Skip exception handling.
		// Expected exception is an error casting to Date.
		Return OutputItem;
	EndTry;
	
EndFunction

Function ExecuteCommand(Val Template, Val ClusterAdministrationParameters, Val ParameterValues = Undefined)
	
	// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
	
#If Server Then
		
		If SafeMode() <> False Then
			Raise NStr("en = 'Warning! Cluster administration is unavailable in safe mode.';");
		EndIf;
		
		If Common.DataSeparationEnabled() Then
			Raise NStr("en = 'Warning! The infobase features related to cluster administration are unavailable in SaaS mode.';");
		EndIf;
		
#EndIf
	
	// ACC:547-on
	
	// Substituting path to the rac utility and the ras server address to the command line.
	Client = PathToAdministrationServerClient();
	ClientFile = New File(Client);
	If Not ClientFile.Exists() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot perform the operation of server cluster administration as the %1 file does not exist.
			      |
			      |To administer the cluster via the administration server (ras), install the server administration client (rac) on this
			      |computer.
			      |To install it:
			      |- For Windows, reinstall 1C:Enterprise platform with ""1C:Enterprise server administration"" component selected.
			      |- For Linux, install the 1c-enterprise83-server* package.';"),
			ClientFile.FullName);
		
	EndIf;
	
	If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerAddress) Then
		Server = TrimAll(ClusterAdministrationParameters.AdministrationServerAddress);
		If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerPort) Then
			Server = Server + ":" + AdjustValue(ClusterAdministrationParameters.AdministrationServerPort);
		Else
			Server = Server + ":1545";
		EndIf;
	Else
		Server = "";
	EndIf;
	
	CommandLine = """" + Client + """ " + StrReplace(Template, "%rac", Server);
	
	// Substituting parameter values to the command line.
	If ValueIsFilled(ParameterValues) Then
		For Each Parameter In ParameterValues Do
			// Populate the parameter.
			CommandLine = StrReplace(CommandLine, "%" + Parameter.Key + "%", AdjustValue(Parameter.Value, Parameter.Key));
			If ValueIsFilled(Parameter.Value) Then
				// Optional parameters can be used.
				CommandLine = StrReplace(CommandLine, "%?" + Parameter.Key + "%", AdjustValue(Parameter.Value, Parameter.Key));
			Else
				// Removing the optional parameter from the command line if its value was not specified.
				CommandLine = StrReplace(CommandLine, "--" + Parameter.Key + "=%?" + Parameter.Key + "%", "");
			EndIf;
		EndDo;
	EndIf;
	
	// ACC:223-off This code is required for backward compatibility. It is used in an obsolete API.
	
	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
	ApplicationStartupParameters.CurrentDirectory = PlatformExecutableFilesDirectory();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	Result = CommonClientServer.StartApplication(CommandLine, ApplicationStartupParameters);
	
	// ACC:223-on
	
	OutputStream = Result.OutputStream;
	ErrorStream = Result.ErrorStream;
	
	If ValueIsFilled(ErrorStream) Then
		Raise ErrorStream;
	EndIf;
	
	Return OutputStream;
	
EndFunction

Function OutputParser(Val OutputStream, Val Dictionary, Val Filter = Undefined)
	
	Result = New Array();
	ResultItem = New Map();
	
	OutputSize = StrLineCount(OutputStream);
	For Step = 1 To OutputSize Do
		StreamItem = StrGetLine(OutputStream, Step);
		StreamItem = TrimAll(StreamItem);
		SeparatorLocation = StrFind(StreamItem, ":");
		If SeparatorLocation > 0 Then
			
			PropertyName = TrimAll(Left(StreamItem, SeparatorLocation - 1));
			PropertyValue = CastOutputItem(TrimAll(Right(StreamItem, StrLen(StreamItem) - SeparatorLocation)));
			
			If PropertiesEscapedWithQuotationMarks().Get(PropertyName) <> Undefined Then
				If StrStartsWith(PropertyValue, """") And StrEndsWith(PropertyValue, """") Then
					PropertyValue = Left(PropertyValue, StrLen(PropertyValue) - 1);
					PropertyValue = Right(PropertyValue, StrLen(PropertyValue) - 1)
				EndIf;
			EndIf;
			
			ResultItem.Insert(PropertyName, PropertyValue);
			
		Else
			
			If ResultItem.Count() > 0 Then
				OutputItemParser(ResultItem, Result, Dictionary, Filter);
				ResultItem = New Map();
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If ResultItem.Count() > 0 Then
		OutputItemParser(ResultItem, Result, Dictionary, Filter);
	EndIf;
	
	Return Result;
	
EndFunction

Procedure OutputItemParser(ResultItem, Result, Dictionary, Filter)
	
	If Dictionary <> Undefined Then
		Object = ParseOutputItem(ResultItem, Dictionary);
	Else
		Object = ResultItem;
	EndIf;
	
	If Filter <> Undefined And Not ClusterAdministrationClientServer.CheckFilterConditions(Object, Filter) Then
		Return;
	EndIf;
	
	Result.Add(Object);
	
EndProcedure

Function ParseOutputItem(Val OutputItem, Val Dictionary)
	
	Result = New Structure();
	
	For Each DictionaryFragment In Dictionary Do
		
		Result.Insert(DictionaryFragment.Key, OutputItem[DictionaryFragment.Value]);
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillClusterAuthenticationParameters(Val ClusterAdministrationParameters, Parameters)
	
	Parameters.Insert("cluster-user", ClusterAdministrationParameters.ClusterAdministratorName);
	Parameters.Insert("cluster-pwd", ClusterAdministrationParameters.ClusterAdministratorPassword);
	
EndProcedure

Procedure FillIBAuthenticationParameters(Val IBAdministrationParameters, Parameters)
	
	Parameters.Insert("infobase-user", IBAdministrationParameters.InfobaseAdministratorName);
	Parameters.Insert("infobase-pwd", IBAdministrationParameters.InfobaseAdministratorPassword);
	
EndProcedure

Procedure FillParametersByDictionary(Val Dictionary, Val Source, Parameters, Template)
	
	For Each DictionaryFragment In Dictionary Do
		
		Template = Template + " --" + DictionaryFragment.Value + "=%" + DictionaryFragment.Value + "%";
		Parameters.Insert(DictionaryFragment.Value, Source[DictionaryFragment.Key]);
		
	EndDo;
	
EndProcedure

Function FilterToRacNotation(Val Filter, Val Dictionary)
	
	If Filter = Undefined Then
		Return Undefined;
	EndIf;
	
	If Dictionary = Undefined Then
		Return Filter;
	EndIf;
	
	Result = New Array();
	
	For Each Condition In Filter Do
		
		If TypeOf(Condition) = Type("KeyAndValue") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Key], ComparisonType.Equal, Condition.Value));
			
		ElsIf TypeOf(Condition) = Type("Structure") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Property], Condition.ComparisonType, Condition.Value));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function SessionAndScheduledJobLockPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "sessions-deny");
	Result.Insert("DateFrom1", "denied-from");
	Result.Insert("DateTo", "denied-to");
	Result.Insert("Message", "denied-message");
	Result.Insert("KeyCode", "permission-code");
	Result.Insert("LockParameter", "denied-parameter");
	Result.Insert("LockScheduledJobs", "scheduled-jobs-deny");
	
	Return New FixedStructure(Result);
	
EndFunction

Function SessionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "session-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationID", "app-id");
	Result.Insert("LanguageID", "locale");
	Result.Insert("SessionCreationTime", "started-at");
	Result.Insert("LatestSessionActivityTime", "last-active-at");
	Result.Insert("DBMSLock", "blocked-by-dbms");
	Result.Insert("Block", "blocked-by-ls");
	Result.Insert("Passed", "bytes-all");
	Result.Insert("PassedIn5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsIn5Minutes", "calls-last-5min");
	Result.Insert("ServerCallDurations", "duration-all");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("ServerCallDurationsIn5Minutes", "duration-last-5min");
	Result.Insert("ExchangedWithDBMS", "dbms-bytes-all");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("DBMSCallDuration", "duration-all-dbms");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("DBMSCallDurationsIn5Minutes", "duration-last-3min-dbms");
	Result.Insert("DBMSConnection", "db-proc-info");
	Result.Insert("DBMSConnectionTime", "db-proc-took");
	Result.Insert("DBMSConnectionSeizeTime", "db-proc-took-at");
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "conn-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationID", "app-id");
	Result.Insert("ConnectionEstablishingTime", "connected-at");
	Result.Insert("InfobaseConnectionMode", "ib-conn-mode");
	Result.Insert("DataBaseConnectionMode", "db-conn-mode");
	Result.Insert("DBMSLock", "blocked-by-dbms");
	Result.Insert("Passed", "bytes-all");
	Result.Insert("PassedIn5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsIn5Minutes", "calls-last-5min");
	Result.Insert("ExchangedWithDBMS", "dbms-bytes-all");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("DBMSConnection", "db-proc-info");
	Result.Insert("DBMSTime", "db-proc-took");
	Result.Insert("DBMSConnectionSeizeTime", "db-proc-took-at");
	Result.Insert("ServerCallDurations", "duration-all");
	Result.Insert("DBMSCallDuration", "duration-all-dbms");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("ServerCallDurationsIn5Minutes", "duration-last-5min");
	Result.Insert("DBMSCallDurationsIn5Minutes", "duration-last-5min-dbms");
	
	Return New FixedStructure(Result);
	
EndFunction

Function SecurityProfilePropertiesDictionary(Val IncludeAccessManagementListsUsageProperties = True)
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	Result.Insert("SafeModeProfile", "config");
	Result.Insert("FullAccessToPrivilegedMode", "priv");
	
	If IncludeAccessManagementListsUsageProperties Then
		
		AccessManagementListsUsagePropertiesDictionary = AccessManagementListUsagePropertiesDictionary();
		
		For Each DictionaryFragment In AccessManagementListsUsagePropertiesDictionary Do
			Result.Insert(DictionaryFragment.Key, DictionaryFragment.Value);
		EndDo;
		
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

Function AccessManagementListUsagePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("FileSystemFullAccess", "directory");
	Result.Insert("COMObjectFullAccess", "com");
	Result.Insert("AddInFullAccess", "addin");
	Result.Insert("ExternalModuleFullAccess", "module");
	Result.Insert("FullOperatingSystemApplicationAccess", "app");
	Result.Insert("InternetResourcesFullAccess", "inet");
	
	Return New FixedStructure(Result);
	
EndFunction

Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "alias");
	Result.Insert("PhysicalURL", "physicalPath");
	
	Result.Insert("LongDesc", "descr");
	
	Result.Insert("DataReader", "allowedRead");
	Result.Insert("DataWriter", "allowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	
	Result.Insert("FileMoniker", "fileName");
	Result.Insert("CLSID", "id");
	Result.Insert("Computer", "host");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns:
//  FixedStructure:
//   * Name - String
//   * LongDesc - String
//   * HashSum - String - for backward compatibility.
//
Function AddInPropertiesDictionary()
	
	Result = New Structure();
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	Result.Insert("HashSum", "hash"); // ACC:1036 for backward compatibility.
	Return New FixedStructure(Result);
	
EndFunction

Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	Result.Insert("HashSum", "hash"); // ACC:1036 for backward compatibility.	
	Return New FixedStructure(Result);
	
EndFunction

Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	
	Result.Insert("CommandLinePattern", "wild");
	
	Return New FixedStructure(Result);
	
EndFunction

Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("LongDesc", "descr");
	
	Result.Insert("Protocol", "protocol");
	Result.Insert("Address", "url");
	Result.Insert("Port", "port");
	
	Return New FixedStructure(Result);
	
EndFunction

Function AccessManagementListsKeys()
	
	Result = New Structure();
	
	Result.Insert("directory", "alias");
	Result.Insert("com", "name");
	Result.Insert("addin", "name");
	Result.Insert("module", "name");
	Result.Insert("inet", "name");
	
	Return New FixedStructure(Result);
	
EndFunction

Function BooleanPropertyFormatDictionary()
	
	OnOffFormat = "BF=off; BT=on";
	YesNoFormat = "BF=no; BT=yes";
	
	Result = New Map();
	
	// Session and job lock properties
	Dictionary = SessionAndScheduledJobLockPropertiesDictionary();
	Result.Insert(Dictionary.SessionsLock, OnOffFormat);
	Result.Insert(Dictionary.LockScheduledJobs, OnOffFormat);
	
	// Security profile properties.
	Dictionary = SecurityProfilePropertiesDictionary(False);
	Result.Insert(Dictionary.SafeModeProfile, YesNoFormat);
	Result.Insert(Dictionary.FullAccessToPrivilegedMode, YesNoFormat);
	
	// Virtual directory properties.
	Dictionary = VirtualDirectoryPropertiesDictionary();
	Result.Insert(Dictionary.DataReader, YesNoFormat);
	Result.Insert(Dictionary.DataWriter, YesNoFormat);
	
	Return New FixedMap(Result);
	
EndFunction

Function PropertiesEscapedWithQuotationMarks()
	
	Result = New Map();
	Result["denied-message"] = True;
	Result["permission-code"] = True;
	Result["denied-parameter"] = True;
	Return New FixedMap(Result);
	
EndFunction

#EndRegion

#EndIf