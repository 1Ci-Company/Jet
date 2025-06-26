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

#Region SessionAndJobLock

// Returns the current state of infobase session locks and scheduled job locks.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   See ClusterAdministration.SessionAndScheduleJobLockProperties
//
Function InfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Result = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, SessionAndScheduledJobLockPropertiesDictionary());
	
	If Result.DateFrom1 = ClusterAdministration.DateEmpty() Then
		Result.DateFrom1 = Undefined;
	EndIf;
	
	If Result.DateTo = ClusterAdministration.DateEmpty() Then
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   SessionAndJobLockProperties - See ClusterAdministration.SessionAndScheduleJobLockProperties
//
Procedure SetInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val SessionAndJobLockProperties) Export
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		SessionAndScheduledJobLockPropertiesDictionary(),
		SessionAndJobLockProperties);
	
EndProcedure

// Validates administration parameters.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   CheckInfobaseAdministrationParameters - Boolean - Flag indicating whether to validate administration parameters.
//                  
//   CheckClusterAdministrationParameters - Boolean - Flag indicating whether to validate administration parameters.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckInfobaseAdministrationParameters = True,
	CheckClusterAdministrationParameters = True) Export
	
	If CheckClusterAdministrationParameters Or CheckInfobaseAdministrationParameters Then
		
		Try
			ClusterID = ClusterID(ClusterAdministrationParameters);
			WorkingProcessesProperties(ClusterID, ClusterAdministrationParameters);
		Except
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot connect to the server cluster from computer %1. Reason:
					|%2
				    |
					|If administration server (ras) is not running on computer %1, start it.
					|Example:
					|""%3"" cluster --port=%4 %5:%6
					|
					|It is also recommended that you check the connection parameters and firewall settings.';"),
				ComputerName(), ErrorProcessing.BriefErrorDescription(ErrorInfo()),
				BinDir() + ?(Common.IsWindowsServer(), "ras.exe", "ras"),
				XMLString(ClusterAdministrationParameters.AdministrationServerPort),
				ClusterAdministrationParameters.ServerAgentAddress,
				XMLString(ClusterAdministrationParameters.ServerAgentPort));
		EndTry;
		
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns:
//   Boolean
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	Dictionary = New Structure("LockScheduledJobs", "scheduled-jobs-deny");
	
	IBProperties = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Dictionary);
	Return IBProperties.LockScheduledJobs;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   LockScheduledJobs - Boolean - Indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val LockScheduledJobs) Export
	
	Dictionary = New Structure("LockScheduledJobs", "scheduled-jobs-deny");
	Properties = New Structure("LockScheduledJobs", LockScheduledJobs);
	
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
//
// Returns: 
//   Array of See ClusterAdministration.SessionProperties
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
		
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	// Process licenses.
	Command = "process list --licenses " + ClusterParameters;
	ProcessLicenses = New Map;
	For Each ILicenseInfo In RunCommand(Command, ClusterAdministrationParameters, , , LicensePropertyTypes()) Do
		ILicenseInfo.Insert("license-type", ?(ILicenseInfo["license-type"] = "soft", 0, 1));
		ProcessLicenses.Insert(ILicenseInfo["process"], ILicenseInfo); 
	EndDo;
	
	// Processes.
	Command = "process list " + ClusterParameters;
	Processes = New Map;
	For Each Process_ In RunCommand(Command, ClusterAdministrationParameters, , , WorkingProcessPropertyTypes()) Do
		Process_.Insert("license", ProcessLicenses[Process_["process"]]);
		Process_.Insert("running", ?(Process_["running"], 1, 0));
		Process_.Insert("use", ?(Process_["use"] = "used", 1, ?(Process_["use"] = "not-used", 0, 2)));  // "not-used" is inaccurate value.
		Processes.Insert(Process_["process"], Process_);
	EndDo;
	
	// Connection details.
	Command = "connection list " + ClusterParameters;
	ConnectionDetails1 = New Map;
	For Each Join In RunCommand(Command, ClusterAdministrationParameters, , , ConnectionDetailsPropertyTypes()) Do
		Join.Insert("process", Processes[Join["process"]]);
		ConnectionDetails1.Insert(Join["connection"], Join);
	EndDo;
	
	// Sessions licenses.
	Command = "session list --licenses " + ClusterParameters;
	SessionLicenses = New Map;
	For Each SessionLicense In RunCommand(Command, ClusterAdministrationParameters, , , LicensePropertyTypes()) Do
		SessionLicense.Insert("license-type", ?(SessionLicense["license-type"] = "soft", 0, 1));
		SessionLicenses.Insert(SessionLicense["session"], SessionLicense);
	EndDo;
	
	// Session locks.
	Command = "lock list --infobase=%1 " + ClusterParameters;
	SubstituteParametersToCommand(Command, InfoBaseID);
	SessionLocks = New Map();
	For Each SessionLock In RunCommand(Command, ClusterAdministrationParameters, , , LockPropertyTypes()) Do
		ClusterAdministration.SessionDataFromLock(SessionLocks,
		                                                               SessionLock["descr"],
		                                                               SessionLock["session"],
		                                                               IBAdministrationParameters.NameInCluster); 

	EndDo;
	
	// Sessions.
	Command = "session list --infobase=%1 " + ClusterParameters;
	SubstituteParametersToCommand(Command, InfoBaseID);
	Filter = FilterToRacNotation(Filter, SessionPropertiesDictionary());
	Result = New Array;
	For Each Session In RunCommand(Command, ClusterAdministrationParameters, , Filter, SessionPropertyTypes()) Do
		Session.Insert("process", Processes[Session["process"]]);
		Session.Insert("license", SessionLicenses[Session["session"]]);
		Session.Insert("connection", ConnectionDetails1[Session["connection"]]);
		ParsedSession = ParseOutputItem(Session, SessionPropertiesDictionary());
		
		ParsedSession.Insert("DBLockMode", ?(SessionLocks[Session["session"]] <> Undefined, SessionLocks[Session["session"]].DBLockMode, ""));
		ParsedSession.Insert("Separator", ?(SessionLocks[Session["session"]] <> Undefined, SessionLocks[Session["session"]].Separator, ""));
		
		Result.Add(ParsedSession);
	EndDo;
	
	Return Result;
	
EndFunction

// Deletes infobase sessions according to filter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
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
				
				Command = "session terminate --session=%1 " + ClusterParameters;
				SubstituteParametersToCommand(Command,  Session.Get("session"));
				RunCommand(Command, ClusterAdministrationParameters);
				
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//            , Array of
//
// Returns:
//   Array of See ClusterAdministration.ConnectionProperties
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	Return ConnectionsProperties(ClusterID, ClusterAdministrationParameters, InfoBaseID, IBAdministrationParameters, Filter, True);
	
EndFunction

// Terminates infobase connections by filter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//            , Array of
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	Value = New Array;
	Value.Add("1CV8");               // ID of 1C:Enterprise application running in thick client mode.
	Value.Add("1CV8C");              // ID of 1C:Enterprise application running in thin client mode.
	Value.Add("WebClient");          // ID of 1C:Enterprise application running in web client mode.
	Value.Add("Designer");           // Designer ID.
	Value.Add("COMConnection");      // ID of 1C:Enterprise external COM connection session.
	Value.Add("WSConnection");       // Web service session ID.
	Value.Add("BackgroundJob");      // ID of job processing session.
	Value.Add("WebServerExtension"); // Web server extension ID.

	ClusterAdministration.AddFilterCondition(Filter, "ClientApplicationID", ComparisonType.InList, Value);
	
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
				
				Command = "connection disconnect --process=%1 --connection=%2 --infobase-user=%3 --infobase-pwd=%4 " + ClusterParameters;
				SubstituteParametersToCommand(Command,
					Join.Get("process"),
					Join.Get("connection"),
					IBAdministrationParameters.InfobaseAdministratorName,
					IBAdministrationParameters.InfobaseAdministratorPassword);
				RunCommand(Command, ClusterAdministrationParameters);
				
			Except
				
				// Connection might terminate before "rac connection disconnect" is called.
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String - Name of the security profile assigned for the infobase.
//            If no profile is assigned, returns an empty string.
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

// Returns the name of the security profile that was set as the infobase safe mode security profile.
//  
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String - Name of the security profile assigned as a safe mode security profile.
//            If no profile is assigned, returns an empty string.
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the security profile is 
//                         disabled for the infobase.
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is
//                         disabled for the infobase.
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Name of the security profile being checked.
//
// Returns:
//   Boolean
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//   ClusterID - String - Internal server cluster ID.
//
// Returns: 
//   See ClusterAdministration.SecurityProfileProperties
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName, Val ClusterID = Undefined) Export
	
	Filter = New Structure("Name", ProfileName);
	
	If ClusterID = Undefined Then
		ClusterID = ClusterID(ClusterAdministrationParameters);
	EndIf;
	
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
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() = 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %2 is already registered in server cluster %1.';"), ClusterID, ProfileName);
	EndIf;
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterID, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile %2 is not registered in server cluster %1.';"), ClusterID, ProfileName);
	EndIf;
	
	PreviousProperties = SecurityProfile(ClusterAdministrationParameters, ProfileName, ClusterID);
	
	UpdateSecurityProfileProperties(ClusterAdministrationParameters, SecurityProfileProperties, PreviousProperties);
	
EndProcedure

// Deletes a security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Command = "profile remove --name=%1 " + ClusterParameters(ClusterAdministrationParameters);
	SubstituteParametersToCommand(Command, ProfileName);
	RunCommand(Command, ClusterAdministrationParameters);
	
EndProcedure

#EndRegion

#Region Infobases

// Returns an internal infobase ID.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String
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

// Returns infobase details.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - Infobase filter criteria.
//
// Returns:
//   Array of Structure
//
Function InfobasesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Command = "infobase summary list " + ClusterParameters(ClusterAdministrationParameters, ClusterID);
	Properties = RunCommand(Command, ClusterAdministrationParameters, , Filter, BaseDetailsPropertyTypes());
	
	Return Properties;
	
EndFunction

#EndRegion

#Region Cluster

// Returns an internal ID of a server cluster.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//
// Returns:
//   String
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

// Returns server cluster details.
//
// Parameters:  
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - Server cluster filter criteria.
//
// Returns: 
//   Array - Array of mappings and cluster details in the rac notation.
//
Function ClusterProperties(Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerAddress) Then
		Server = TrimAll(ClusterAdministrationParameters.AdministrationServerAddress);
		If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerPort) Then
			Server = Server + ":" + AdjustValue(ClusterAdministrationParameters.AdministrationServerPort);
		EndIf;
	Else
		Server = "";
	EndIf;
	
	Return RunCommand("cluster list " + Server, ClusterAdministrationParameters, , Filter, ClusterPropertyTypes());
	
EndFunction

#EndRegion

#Region WorkingProcessesServers

// Returns active process details.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - Active process filter criteria.
//
// Returns: 
//   Array - Array of mappings and running process details in the rac notation.
//
Function WorkingProcessesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	Return RunCommand("process list " + ClusterParameters(ClusterAdministrationParameters, ClusterID), ClusterAdministrationParameters, , Filter);
	
EndFunction

// Returns descriptions of active servers.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - Active server filter criteria.
//
// Returns: 
//   Array - an array of map, and active process details in the rac notation.
//
Function WorkingServerProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	Return RunCommand("server list " + ClusterParameters, ClusterAdministrationParameters, , Filter, WorkingServerPropertyTypes());
	
EndFunction

#EndRegion

// Returns descriptions of infobase sessions.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   InfoBaseID - String - Internal infobase ID.
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
//   UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns: 
//   - Array of See ClusterAdministration.SessionProperties
//   - Array of Map
//
Function SessionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val Filter = Undefined, Val UseDictionary = True) Export
	
	Command = "session list --infobase=%1 " + ClusterParameters(ClusterAdministrationParameters, ClusterID);	
	SubstituteParametersToCommand(Command, InfoBaseID);	
	
	If UseDictionary Then
		Dictionary = SessionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, SessionPropertiesDictionary());
	EndIf;
	
	Result = RunCommand(Command, ClusterAdministrationParameters, Dictionary, Filter, SessionPropertyTypes());
	
	Return Result;                                       
	
EndFunction

// Returns descriptions of infobase connections.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   InfoBaseID - String - Internal infobase ID.
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
//   UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns: 
//   - Array of See ClusterAdministration.ConnectionProperties
//   - Array of Map
//
Function ConnectionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val IBAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	If UseDictionary Then
		Dictionary = ConnectionPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, ConnectionPropertiesDictionary());
	EndIf;
	
	Result = New Array();
	WorkingProcesses = WorkingProcessesProperties(ClusterID, ClusterAdministrationParameters);
	
	For Each IWorkingProcessInfo In WorkingProcesses Do
		
		Command = "connection list --process=%1 --infobase=%2 --infobase-user=%3 --infobase-pwd=%4 " + ClusterParameters;
		SubstituteParametersToCommand(Command,
			IWorkingProcessInfo.Get("process"),
			InfoBaseID,
			IBAdministrationParameters.InfobaseAdministratorName,
			IBAdministrationParameters.InfobaseAdministratorPassword);
			
		WorkingProcessConnections = RunCommand(Command, ClusterAdministrationParameters, Dictionary, Filter, ConnectionPropertyTypes());
		For Each Join In WorkingProcessConnections Do
			If UseDictionary Then
				If Join.DataBaseConnectionMode = "none" Then
					Join.Insert("DataBaseConnectionMode", 0);
				ElsIf Join.DataBaseConnectionMode = "shared" Then
					Join.Insert("DataBaseConnectionMode", 1);
				Else // exclusive
					Join.Insert("DataBaseConnectionMode", 2);
				EndIf;
				Join.Insert("InfobaseConnectionMode", ?(Join.InfobaseConnectionMode = "shared", 0, 1));
				Join.Insert("ControlIsOnServer", ?(Join.ControlIsOnServer = "client", 0, 1));
			Else
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
//   String
//
Function PathToAdministrationServerClient() Export
	
	StartDirectory = PlatformExecutableFilesDirectory();
	Client = StartDirectory + "rac";
	
	If Common.IsWindowsServer() Then
		Client = Client + ".exe";
	EndIf;
	
	Return Client;
	
EndFunction

#EndRegion

#Region Private

Function PlatformExecutableFilesDirectory()
	
	Result = BinDir();
	SeparatorChar = GetPathSeparator();
	
	If Right(Result, 1) <> SeparatorChar Then
		Result = Result + SeparatorChar;
	EndIf;
	
	Return Result;
	
EndFunction

Function InfobaseProperties1(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary)
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	Command = "infobase info --infobase=%1 --infobase-user=%2 --infobase-pwd=%3";
	SubstituteParametersToCommand(Command, 
		InfoBaseID, 
		IBAdministrationParameters.InfobaseAdministratorName, 
		IBAdministrationParameters.InfobaseAdministratorPassword);
		
	Result = RunCommand(Command + " " + ClusterParameters, ClusterAdministrationParameters, Dictionary, , InfoBasePropertyTypes());
	
	Return Result[0];
	
EndFunction

Procedure SetInfobaseProperties(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Dictionary, Val PropertiesValues)
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	InfoBaseID = InfoBaseID(ClusterID, ClusterAdministrationParameters, IBAdministrationParameters);
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("ClusterAdministrationParameters", ClusterAdministrationParameters);
	ReceivingParameters.Insert("IBAdministrationParameters", IBAdministrationParameters);
	ReceivingParameters.Insert("ObjectType", "infobase");
	SupportedProperties = SupportedObjectProperties(ReceivingParameters);
	
	Command = "infobase update --infobase=%1 --infobase-user=%2 --infobase-pwd=%3";
	SubstituteParametersToCommand(Command, 
		InfoBaseID, 
		IBAdministrationParameters.InfobaseAdministratorName, 
		IBAdministrationParameters.InfobaseAdministratorPassword);
		
	// For these two boolean properties the presentation differs.
	NewPropertiesValues = Common.CopyRecursive(PropertiesValues);
	For Each KeyAndValue In Dictionary Do
		If KeyAndValue.Value = "scheduled-jobs-deny" Or KeyAndValue.Value = "sessions-deny" Then
			NewPropertiesValues.Insert(KeyAndValue.Key, Format(NewPropertiesValues[KeyAndValue.Key], "BF=off; BT=on"));
		EndIf;
	EndDo;
	
	AddCommandParametersByDictionary(Command, Dictionary, NewPropertiesValues, SupportedProperties);
	
	RunCommand(Command + " " + ClusterParameters, ClusterAdministrationParameters);
	
EndProcedure

Function GetSecurityProfiles(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined)
	
	Command = "profile list " + ClusterParameters(ClusterAdministrationParameters, ClusterID);
	Result = RunCommand(Command, ClusterAdministrationParameters, SecurityProfilePropertiesDictionary(), Filter, ProfilePropertyTypes()); 
	
	Return Result;
	
EndFunction

Function GetVirtualDirectories(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"directory", // Not localizable.
		VirtualDirectoryPropertiesDictionary(),
		,
		VirtualDirectoryPropertyTypes());
	
EndFunction

Function GetAllowedCOMClass(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"com", // Not localizable.
		COMClassPropertiesDictionary(),
		,
		COMClassPropertyTypes());
	
EndFunction

Function GetAllowedAddIns(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"addin", // Not localizable.
		AddInPropertiesDictionary(),
		,
		AddInPropertyTypes());
	
EndFunction

Function GetAllowedExternalModules(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"module", // Not localizable.
		ExternalModulePropertiesDictionary(),
		,
		ExternalModulePropertyType());
	
EndFunction

Function GetAllowedOSApplications(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"app", // Not localizable.
		OSApplicationPropertiesDictionary(),
		,
		OSApplicationPropertyTypes());
	
EndFunction

Function GetAllowedInternetResources(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return AccessManagementLists(
		ClusterID,
		ClusterAdministrationParameters,
		ProfileName,
		"inet", // Not localizable.
		InternetResourcePropertiesDictionary(),
		,
		InternetResourcePropertyTypes());
	
EndFunction

Function AccessManagementLists(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val Filter = Undefined, Val PropertyTypes = Undefined)
	
	Command = "profile acl --name=%1 %2 list " + ClusterParameters(ClusterAdministrationParameters, ClusterID);
	SubstituteParametersToCommand(Command, ProfileName, ListName);
	
	Result = RunCommand(Command, ClusterAdministrationParameters, Dictionary, Filter, PropertyTypes);
	
	Return Result;
	
EndFunction

Procedure UpdateSecurityProfileProperties(Val ClusterAdministrationParameters, Val NewProperties, Val PreviousProperties = Undefined)
	
	If PreviousProperties = Undefined Then
		PreviousProperties = ClusterAdministration.SecurityProfileProperties();
	EndIf;
	
	ClusterID = ClusterID(ClusterAdministrationParameters);
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	ProfileName = NewProperties.Name;
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("ClusterAdministrationParameters", ClusterAdministrationParameters);
	ReceivingParameters.Insert("ObjectType", "profile");
	SupportedProperties = SupportedObjectProperties(ReceivingParameters);
	
	ProfilePropertiesDictionary = SecurityProfilePropertiesDictionary(False);
	For Each DictionaryFragment In ProfilePropertiesDictionary Do
		If NewProperties.Property(DictionaryFragment.Key) Then
			If NewProperties[DictionaryFragment.Key] <> PreviousProperties[DictionaryFragment.Key] Then
				Command = "profile update";
				AddCommandParametersByDictionary(Command, ProfilePropertiesDictionary, NewProperties, SupportedProperties.profile); 
				RunCommand(Command + " " + ClusterParameters, ClusterAdministrationParameters);
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	For Each DictionaryFragment In AccessManagementListUsagePropertiesDictionary() Do
		If NewProperties[DictionaryFragment.Key] = PreviousProperties[DictionaryFragment.Key] Then
			Continue;
		EndIf;
		SetAccessManagementListUsage(ClusterID, ClusterAdministrationParameters, ProfileName, DictionaryFragment.Value, Not NewProperties[DictionaryFragment.Key]);
	EndDo;
	
	// Virtual directories.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters, 
		ProfileName, 
		"directory", 
		VirtualDirectoryPropertiesDictionary(), 
		NewProperties.VirtualDirectories,
		PreviousProperties.VirtualDirectories);
	
	// Allowed COM classes.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters, 
		ProfileName, 
		"com", 
		COMClassPropertiesDictionary(), 
		NewProperties.COMClasses,
		PreviousProperties.COMClasses);
	
	// Add-ins.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters, 
		ProfileName, 
		"addin", 
		AddInPropertiesDictionary(), 
		NewProperties.AddIns,
		PreviousProperties.AddIns);
	
	// External modules.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters, 
		ProfileName, 
		"module", 
		ExternalModulePropertiesDictionary(),
		NewProperties.ExternalModules,
		PreviousProperties.ExternalModules);
		
	// OS applications.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters, 
		ProfileName, 
		"app", 
		OSApplicationPropertiesDictionary(), 
		NewProperties.OSApplications,
		PreviousProperties.OSApplications);
	
	// Internet resources.
	UpdateAccessControlListItems(ClusterID, 
		ClusterAdministrationParameters,
		ProfileName, 
		"inet", 
		InternetResourcePropertiesDictionary(), 
		NewProperties.InternetResources,
		PreviousProperties.InternetResources);
	
EndProcedure

Procedure SetAccessManagementListUsage(Val ClusterID, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Use)
	
	Command = "profile acl --name=%1 %2 --access=%3 " + ClusterParameters(ClusterAdministrationParameters, ClusterID);
	SubstituteParametersToCommand(Command, ProfileName, ListName, ?(Use, "list", "full"));
	RunCommand(Command, ClusterAdministrationParameters);
	
EndProcedure

Procedure DeleteAccessManagementListItem(Val ClusterID, Val ClusterAdministrationParameters, 
	Val ProfileName, Val ListName, Val ItemKey)
	
	ListKey = AccessManagementListsKeys()[ListName];
	
	Command = "profile acl --name=%1 %2 remove --%3=%4 " + ClusterParameters(ClusterAdministrationParameters, ClusterID);
	SubstituteParametersToCommand(Command, ProfileName, ListName, ListKey, ItemKey); 
	
	RunCommand(Command, ClusterAdministrationParameters);
	
EndProcedure

Procedure UpdateAccessControlListItem(Val ClusterID, Val ClusterAdministrationParameters, 
	Val ProfileName, Val ListName, Val Dictionary, Val ItemProperties)
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters, ClusterID);
	
	ReceivingParameters = New Structure;
	ReceivingParameters.Insert("ClusterAdministrationParameters", ClusterAdministrationParameters);
	ReceivingParameters.Insert("ObjectType", "profile");
	SupportedProperties = SupportedObjectProperties(ReceivingParameters);
	
	Command = "profile acl --name=%1 %2 update";
	SubstituteParametersToCommand(Command, ProfileName, ListName);
	AddCommandParametersByDictionary(Command, Dictionary, ItemProperties, SupportedProperties["profile_" + ListName]);
	
	RunCommand(Command + " " + ClusterParameters, ClusterAdministrationParameters);
	
EndProcedure

Procedure UpdateAccessControlListItems(Val ClusterID, Val ClusterAdministrationParameters, 
	Val ProfileName, Val ListName, Val Dictionary, Val NewItems, Val OldItems = Undefined)
	
	If OldItems = Undefined Or OldItems.Count() = 0 Then
		For Each NewItem In NewItems Do
			UpdateAccessControlListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, Dictionary, NewItem);
		EndDo;
		Return;
	EndIf;
	
	ListKey = AccessManagementListsKeys()[ListName];
	KeyParameterName = "";
	For Each KeyAndValue In Dictionary Do
		If KeyAndValue.Value = ListKey Then
			KeyParameterName = KeyAndValue.Key;
			EndIf;
	EndDo;
	
	ItemsToDelete1 = New Map;
	For Each OldItem In OldItems Do
		ItemsToDelete1.Insert(OldItem[KeyParameterName], OldItem);
	EndDo;
	
	// Create or update (if properties differ).
	For Each NewItem In NewItems Do
		Var_Key = NewItem[KeyParameterName];
		OldItem = ItemsToDelete1.Get(Var_Key);
		If OldItem = Undefined Then
			UpdateAccessControlListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, Dictionary, NewItem);
		Else
			ItemsToDelete1.Delete(Var_Key);
			// Update only if properties differ.
			For Each KeyAndValue In NewItem Do
				If KeyAndValue.Value <> OldItem[KeyAndValue.Key] Then
					UpdateAccessControlListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, Dictionary, NewItem);
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	// Delete redundant items.
	For Each KeyAndValue In ItemsToDelete1 Do
		DeleteAccessManagementListItem(ClusterID, ClusterAdministrationParameters, ProfileName, ListName, KeyAndValue.Key);
	EndDo;
	
EndProcedure

Function ConvertAccessListsUsagePropertyValues(Val LongDesc)
	
	Dictionary = AccessManagementListUsagePropertiesDictionary();
	
	Result = New Structure;
	
	For Each KeyAndValue In LongDesc Do
		
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

Function AdjustValue(Val Value)
	
	If TypeOf(Value) = Type("Date") Then
		
		Return XMLString(Value);
		
	ElsIf TypeOf(Value) = Type("Boolean") Then
		
		Return Format(Value, "BF=no; BT=yes");
		
	ElsIf TypeOf(Value) = Type("Number") Then
		
		Return Format(Value, "NDS=,; NZ=0; NG=0; NN=1");
		
	ElsIf TypeOf(Value) = Type("String") Then
		
		// The documentation stipulates:
		// Arbitrary strings are enclosed in double quotation marks, and double quotation marks within such strings should be duplicated.
		Digits = "0123456789";
		LatinCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
		CyrillicCharacters = "ABVGDEZHZIYKLMNOPRSTUFKHTSCHSHSHYEYUYaabvgdezhziyklmnoprstufkhtschshyeyu"; // ACC:1036 - Orthography check is not required.
		AllowedChars = Digits + LatinCharacters + CyrillicCharacters + "-";
		If StringContainsAllowedCharsOnly(Value, AllowedChars) Then
			Return Value;
		Else
			Return """" + StrReplace(Value, """", """""") + """";
		EndIf;
		
	EndIf;
	
	Return String(Value);
	
EndFunction

Function StringContainsAllowedCharsOnly(String, AllowedChars)
	
	AllAllowedChars = New Map;
	For Position = 1 To StrLen(AllowedChars) Do
		AllAllowedChars[Mid(AllowedChars, Position, 1)] = True;
	EndDo;
	
	For Position = 1 To StrLen(String) Do
		If AllAllowedChars[Mid(String, Position, 1)] = Undefined Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

Function CastOutputItem(OutputItem, ElementType)
	
	If ElementType = Type("String") Then
		
		Return OutputItem;
		
	ElsIf ElementType = Type("Number") Then
		
		If IsBlankString(OutputItem) Then
			Return 0;
		EndIf;
		
		Try
			Return Number(OutputItem);
		Except
			Raise NStr("en = 'Invalid format.';");
		EndTry;
		
	ElsIf ElementType = Type("Date") Then
		
		If IsBlankString(OutputItem) Then
			Return Date(1, 1, 1);
		EndIf;
		
		Try
			Return XMLValue(Type("Date"), OutputItem);
		Except
			Raise NStr("en = 'Invalid format.';");
		EndTry;
		
	ElsIf ElementType = Type("Boolean") Then
		
		If OutputItem = "on" Or OutputItem = "yes" Then
			Return True;
		ElsIf OutputItem = "off" Or OutputItem = "no" Then
			Return False;
		Else
			Raise NStr("en = 'Invalid format.';");
		EndIf;
		
	ElsIf ElementType = Undefined Then
		
		// Skip identifying the data type in the string as 
		// an empty string may be an empty date, and 
		// the string can contain only numbers (for example, a process PID).
		
		If IsBlankString(OutputItem) Then
			Return Undefined;
		EndIf;
		
		Return OutputItem;
		
	Else
		
		Raise NStr("en = 'Invalid item type.';");
		
	EndIf;
	
	Return OutputItem;
	
EndFunction

Function OutputParser(Val OutputStream, Val Dictionary, Val Filter = Undefined, PropertyTypes = Undefined)
	
	Result = New Array;
	ResultItem = New Map;
	
	Position = 1;
	OutputEnd = StrLen(OutputStream);
	
	While Position <= OutputEnd Do
		
		PropertyName = ReadUpToSeparator(OutputStream, Position, ":");
		PropertyRow = ReadUpToSeparator(OutputStream, Position, Chars.LF);
		PropertyType1 = ?(PropertyTypes = Undefined, Undefined, PropertyTypes.Get(PropertyName));
		PropertyValue = CastOutputItem(PropertyRow, PropertyType1);
		ResultItem.Insert(PropertyName, PropertyValue);
		
		If Mid(OutputStream, Position, 1) = Chars.LF Then
			Position = Position + 1;
			OutputItemParser(ResultItem, Result, Dictionary, Filter);
			ResultItem = New Map;
		EndIf;
		
	EndDo;
	
	If ResultItem.Count() > 0 Then
		OutputItemParser(ResultItem, Result, Dictionary, Filter);
	EndIf;
	
	Return Result;
	
EndFunction

Function ReadUpToSeparator(Stream, Position, Separator)
	
	CurrentChar = Mid(Stream, Position, 1);
	
	// Offset the position up to a meaningful character.
	While IsBlankString(CurrentChar) And Not CurrentChar = Separator And Position < StrLen(Stream) Do
		Position = Position + 1;
		CurrentChar = Mid(Stream, Position, 1);
	EndDo;
	
	If CurrentChar = Separator Then
		Position = Position + 1;
		Return "";
	EndIf;
	
	QuotationMark = """";
	If CurrentChar = QuotationMark Then
		Position = Position + 1;
		StartPosition = Position;
		// Find the next single quotation mark.
		While Position <= StrLen(Stream) Do
			FoundQuotationMark = StrFind(Stream, QuotationMark, SearchDirection.FromBegin, Position); 
			If FoundQuotationMark = 0 Then
				Raise NStr("en = 'Invalid format.';");
			ElsIf Mid(Stream, FoundQuotationMark + 1, 1) = QuotationMark Then
				Position = FoundQuotationMark + 2;
			Else
				Position = FoundQuotationMark + 1;
				// A quotation mark might be followed by a separator.
				If Mid(Stream, Position, 1) = Separator Then
					Position = Position + 1;
				EndIf;
				Break;
			EndIf;
		EndDo;
		If Position > StrLen(Stream) Then
			Raise NStr("en = 'Invalid format.';");
		EndIf;
		Value = TrimAll(Mid(Stream, StartPosition, FoundQuotationMark - StartPosition));
		Value = StrReplace(Value, QuotationMark + QuotationMark, QuotationMark);
		Return Value;
	Else
		// A simple case: Read till the next separator.
		SeparatorPosition = StrFind(Stream, Separator, SearchDirection.FromBegin, Position);
		Value = TrimAll(Mid(Stream, Position, SeparatorPosition - Position));
		Position = SeparatorPosition + 1;
		Return Value;
	EndIf;
	
EndFunction

Procedure OutputItemParser(ResultItem, Result, Dictionary, Filter)
	
	If Dictionary <> Undefined Then
		Object = ParseOutputItem(ResultItem, Dictionary);
	Else
		Object = ResultItem;
	EndIf;
	
	If Filter <> Undefined And Not ClusterAdministration.CheckFilterConditions(Object, Filter) Then
		Return;
	EndIf;
	
	Result.Add(Object);
	
EndProcedure

Function ParseOutputItem(Val OutputItem, Val Dictionary)
	
	Result = New Structure();
	
	For Each DictionaryFragment In Dictionary Do
		If TypeOf(DictionaryFragment.Value) = Type("FixedStructure") Then
			SubordinateObject = OutputItem[DictionaryFragment.Value.Key];
			If SubordinateObject = Undefined Then
				Result.Insert(DictionaryFragment.Key, Undefined);
			Else
				Property = ParseOutputItem(OutputItem[DictionaryFragment.Value.Key], DictionaryFragment.Value.Dictionary);
				Result.Insert(DictionaryFragment.Key, Property);
			EndIf;
		Else
			Result.Insert(DictionaryFragment.Key, OutputItem[DictionaryFragment.Value]);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

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
	
	Result = ClusterAdministration.SessionAndScheduleJobLockProperties();
	
	Result.SessionsLock = "sessions-deny";
	Result.DateFrom1 = "denied-from";
	Result.DateTo = "denied-to";
	Result.Message = "denied-message";
	Result.KeyCode = "permission-code";
	Result.LockParameter = "denied-parameter";
	Result.LockScheduledJobs = "scheduled-jobs-deny";
	
	Return New FixedStructure(Result);
	
EndFunction

Function SessionPropertiesDictionary()
	
	ILicenseInfo = New Structure;
	ILicenseInfo.Insert("Key", "license");
	ILicenseInfo.Insert("Dictionary", LicensePropertiesDictionary());
	
	IConnectionShort = New Structure;
	IConnectionShort.Insert("Key", "connection");
	IConnectionShort.Insert("Dictionary", ConnectionDetailsPropertiesDictionary());
	
	IWorkingProcessInfo = New Structure;
	IWorkingProcessInfo.Insert("Key", "process");
	IWorkingProcessInfo.Insert("Dictionary", WorkingProcessPropertiesDictionary());
	
	Result = ClusterAdministration.SessionProperties();
	
	Result.Number = "session-id";
	Result.UserName = "user-name";
	Result.ClientComputerName = "host";
	Result.ClientApplicationID = "app-id";
	Result.LanguageID = "locale";
	Result.SessionCreationTime = "started-at";
	Result.LatestSessionActivityTime = "last-active-at";
	Result.DBMSLock = "blocked-by-dbms";
	Result.Block = "blocked-by-ls";
	Result.Passed = "bytes-all";
	Result.PassedIn5Minutes = "bytes-last-5min";
	Result.ServerCalls = "calls-all";
	Result.ServerCallsIn5Minutes = "calls-last-5min";
	Result.ServerCallDurations = "duration-all";
	Result.CurrentServerCallDuration = "duration-current";
	Result.ServerCallDurationsIn5Minutes = "duration-last-5min";
	Result.ExchangedWithDBMS = "dbms-bytes-all";
	Result.ExchangedWithDBMSIn5Minutes = "dbms-bytes-last-5min";
	Result.DBMSCallDuration = "duration-all-dbms";
	Result.CurrentDBMSCallDuration = "duration-current-dbms";
	Result.DBMSCallDurationsIn5Minutes = "duration-last-5min-dbms";
	Result.DBMSConnection = "db-proc-info";
	Result.DBMSConnectionTime = "db-proc-took";
	Result.DBMSConnectionSeizeTime = "db-proc-took-at";
	Result.Sleep = "hibernate";
	Result.TerminateIn = "hibernate-session-terminate-time";
	Result.SleepIn = "passive-session-hibernate-time";
	Result.ReadFromDisk = "read-total";
	Result.ReadFromDiskInCurrentCall = "read-current";
	Result.ReadFromDiskIn5Minutes = "read-last-5min";
	Result.OccupiedMemory = "memory-total";
	Result.OccupiedMemoryInCurrentCall = "memory-current";
	Result.OccupiedMemoryIn5Minutes = "memory-last-5min";
	Result.WrittenOnDisk = "write-total";
	Result.WrittenOnDiskInCurrentCall = "write-current";
	Result.WrittenOnDiskIn5Minutes = "write-last-5min";
	Result.ILicenseInfo = New FixedStructure(ILicenseInfo);
	Result.IConnectionShort = New FixedStructure(IConnectionShort);
	Result.IWorkingProcessInfo = New FixedStructure(IWorkingProcessInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionPropertiesDictionary()
	
	Result = ClusterAdministration.ConnectionProperties();
	
	Result.Number = "conn-id";
	Result.UserName = "user-name";
	Result.ClientComputerName = "host";
	Result.ClientApplicationID = "app-id";
	Result.ConnectionEstablishingTime = "connected-at";
	Result.InfobaseConnectionMode = "ib-conn-mode";
	Result.DataBaseConnectionMode = "db-conn-mode";
	Result.DBMSLock = "blocked-by-dbms";
	Result.Passed = "bytes-all";
	Result.PassedIn5Minutes = "bytes-last-5min";
	Result.ServerCalls = "calls-all";
	Result.ServerCallsIn5Minutes = "calls-last-5min";
	Result.ExchangedWithDBMS = "dbms-bytes-all";
	Result.ExchangedWithDBMSIn5Minutes = "dbms-bytes-last-5min";
	Result.DBMSConnection = "db-proc-info";
	Result.DBMSTime = "db-proc-took";
	Result.DBMSConnectionSeizeTime = "db-proc-took-at";
	Result.ServerCallDurations = "duration-all";
	Result.DBMSCallDuration = "duration-all-dbms";
	Result.CurrentServerCallDuration = "duration-current";
	Result.CurrentDBMSCallDuration = "duration-current-dbms";
	Result.ServerCallDurationsIn5Minutes = "duration-last-5min";
	Result.DBMSCallDurationsIn5Minutes = "duration-last-5min-dbms";
	Result.ReadFromDisk = "read-total";
	Result.ReadFromDiskInCurrentCall = "read-current";
	Result.ReadFromDiskIn5Minutes = "read-last-5min";
	Result.OccupiedMemory = "memory-total";
	Result.OccupiedMemoryInCurrentCall = "memory-current";
	Result.OccupiedMemoryIn5Minutes = "memory-last-5min";
	Result.WrittenOnDisk = "write-total";
	Result.WrittenOnDiskInCurrentCall = "write-current";
	Result.WrittenOnDiskIn5Minutes = "write-last-5min";
	Result.ControlIsOnServer = "thread-mode";
	
	Return New FixedStructure(Result);
	
EndFunction

Function SecurityProfilePropertiesDictionary(Val IncludeAccessManagementListsUsageProperties = True)
	
	Result = ClusterAdministration.SecurityProfileProperties();
	
	Result.Delete("COMClasses");
	Result.Delete("VirtualDirectories");
	Result.Delete("AddIns");
	Result.Delete("ExternalModules");
	Result.Delete("InternetResources");
	Result.Delete("OSApplications");
	
	Result.Name = "name";
	Result.LongDesc = "descr";
	Result.SafeModeProfile = "config";
	Result.FullAccessToPrivilegedMode =  "priv";
	Result.FullAccessToCryptoFunctions = "crypto";
	Result.FullAccessToAllModulesExtension = "all-modules-extension";
	Result.ModulesAvailableForExtension = "modules-available-for-extension";
	Result.ModulesNotAvailableForExtension = "modules-not-available-for-extension";
	Result.FullAccessToAccessRightsExtension = "right-extension";
	Result.AccessRightsExtensionLimitingRoles = "right-extension-definition-roles";
	
	AccessManagementListsUsagePropertiesDictionary = AccessManagementListUsagePropertiesDictionary();
	For Each DictionaryFragment In AccessManagementListsUsagePropertiesDictionary Do
		If IncludeAccessManagementListsUsageProperties Then
			Result[DictionaryFragment.Key] = DictionaryFragment.Value;
		Else
			Result.Delete(DictionaryFragment.Key);
		EndIf;
	EndDo;
	
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
	
	Result = ClusterAdministration.VirtualDirectoryProperties();
	
	Result.LogicalURL = "alias";
	Result.PhysicalURL = "physicalPath";
	
	Result.LongDesc = "descr";
	
	Result.DataReader = "allowedRead";
	Result.DataWriter = "allowedWrite";
	
	Return New FixedStructure(Result);
	
EndFunction

Function COMClassPropertiesDictionary()
	
	Result = ClusterAdministration.COMClassProperties();
	
	Result.Name = "name";
	Result.LongDesc = "descr";
	
	Result.FileMoniker = "fileName";
	Result.CLSID = "id";
	Result.Computer = "host";
	
	Return New FixedStructure(Result);
	
EndFunction

Function AddInPropertiesDictionary()
	
	Result = ClusterAdministration.AddInProperties();
	Result.Name = "name";
	Result.LongDesc = "descr";
	Result.HashSum = "hash";
	Return New FixedStructure(Result);
	
EndFunction

Function ExternalModulePropertiesDictionary()
	
	Result = ClusterAdministration.ExternalModuleProperties();
	Result.Name = "name";
	Result.LongDesc = "descr";
	Result.HashSum = "hash";
	Return New FixedStructure(Result);
	
EndFunction

Function OSApplicationPropertiesDictionary()
	
	Result = ClusterAdministration.OSApplicationProperties();
	
	Result.Name = "name";
	Result.LongDesc = "descr";
	
	Result.CommandLinePattern = "wild";
	
	Return New FixedStructure(Result);
	
EndFunction

Function InternetResourcePropertiesDictionary()
	
	Result = ClusterAdministration.InternetResourceProperties();
	
	Result.Name = "name";
	Result.LongDesc = "descr";
	
	Result.Protocol = "protocol";
	Result.Address = "url";
	Result.Port = "port";
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionDetailsPropertiesDictionary()
	
	IWorkingProcessInfo = New Structure;
	IWorkingProcessInfo.Insert("Key", "process");
	IWorkingProcessInfo.Insert("Dictionary", WorkingProcessPropertiesDictionary());
	
	Result = ClusterAdministration.ConnectionDetailsProperties();
	
	Result.ApplicationName = "application";
	Result.Block = "blocked-by-ls";
	Result.ConnectionEstablishingTime = "connected-at";
	Result.Number = "conn-id";
	Result.ClientComputerName = "host";
	Result.SessionNumber = "session-number";
	Result.IWorkingProcessInfo = New FixedStructure(IWorkingProcessInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

Function LicensePropertiesDictionary()
	
	Result = ClusterAdministration.LicenseProperties();
	
	Result.FileName = "full-name";
	Result.FullPresentation = "full-presentation";
	Result.BriefPresentation = "short-presentation";
	Result.IssuedByServer = "issued-by-server";
	Result.LisenceType = "license-type";
	Result.MaxUsersForSet = "max-users-all";
	Result.MaxUsersInKey = "max-users-cur";
	Result.LicenseIsReceivedViaAladdinLicenseManager = "net";
	Result.ProcessAddress = "rmngr-address";
	Result.ProcessID = "rmngr-pid";
	Result.ProcessPort = "rmngr-port";
	Result.KeySeries = "series";
	
	Return New FixedStructure(Result);
	
EndFunction

Function WorkingProcessPropertiesDictionary()
	
	ILicenseInfo = New Structure;
	ILicenseInfo.Insert("Key", "license");
	ILicenseInfo.Insert("Dictionary", LicensePropertiesDictionary());
	
	Result = ClusterAdministration.WorkingProcessProperties();
	
	Result.AvailablePerformance = "available-perfomance";
	Result.SpentByTheClient = "avg-back-call-time";
	Result.ServerReaction = "avg-call-time";
	Result.SpentByDBMS = "avg-db-call-time";
	Result.SpentByTheLockManager = "avg-lock-call-time";
	Result.SpentByTheServer = "avg-server-call-time";
	Result.ClientStreams = "avg-threads";
	Result.Capacity = "capacity";
	Result.Connections = "connections";
	Result.ComputerName = "host";
	Result.Enabled = "is-enable";
	Result.Port = "port";
	Result.ExceedingTheCriticalValue = "memory-excess-time";
	Result.OccupiedMemory = "memory-size";
	Result.Id = "pid";
	Result.Started2 = "running";
	Result.CallsCountByWhichTheStatisticsIsCalculated = "selection-size";
	Result.StartedAt = "started-at";
	Result.Use = "use";
	Result.ILicenseInfo = New FixedStructure(ILicenseInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

Function AccessManagementListsKeys()
	
	Result = New Structure();
	
	Result.Insert("directory", "alias");
	Result.Insert("com", "name");
	Result.Insert("addin", "name");
	Result.Insert("module", "name");
	Result.Insert("app", "name");
	Result.Insert("inet", "name");
	
	Return New FixedStructure(Result);
	
EndFunction

Function ClusterPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("cluster", Type("String"));
	Types.Insert("host", Type("String"));
	Types.Insert("port", Type("Number"));
	Types.Insert("name", Type("String"));
	Types.Insert("expiration-timeout", Type("Number"));
	Types.Insert("lifetime-limit", Type("Number"));
	Types.Insert("max-memory-size", Type("Number"));
	Types.Insert("max-memory-time-limit", Type("Number"));
	Types.Insert("security-level", Type("Number"));
	Types.Insert("session-fault-tolerance-level", Type("Number"));
	Types.Insert("load-balancing-mode", Type("String"));
	Types.Insert("errors-count-threshold", Type("Number"));
	Types.Insert("kill-problem-processes", Type("Number"));
	
	Return New FixedMap(Types);

EndFunction

Function WorkingServerPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("server", Type("String"));
	Types.Insert("agent-host", Type("String"));
	Types.Insert("agent-port", Type("Number"));
	Types.Insert("port-range", Type("String"));
	Types.Insert("name", Type("String"));
	Types.Insert("using", Type("String"));
	Types.Insert("dedicate-managers", Type("String"));
	Types.Insert("infobases-limit", Type("Number"));
	Types.Insert("memory-limit", Type("Number"));
	Types.Insert("connections-limit", Type("Number"));
	Types.Insert("safe-working-processes-memory-limit", Type("Number"));
	Types.Insert("safe-call-memory-limit", Type("Number"));
	Types.Insert("cluster-port", Type("Number"));

	Return New FixedMap(Types);
	
EndFunction

Function BaseDetailsPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("infobase", Type("String"));
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));

	Return New FixedMap(Types);
	
EndFunction

Function InfoBasePropertyTypes()
	
	Types = New Map;
	
	Types.Insert("infobase", Type("String"));
	Types.Insert("name", Type("String"));
	Types.Insert("dbms", Type("String"));
	Types.Insert("db-server", Type("String"));
	Types.Insert("db-name", Type("String"));
	Types.Insert("db-user", Type("String"));
	Types.Insert("security-level", Type("Number"));
	Types.Insert("license-distribution", Type("String"));
	Types.Insert("scheduled-jobs-deny", Type("Boolean"));
	Types.Insert("sessions-deny", Type("Boolean"));
	Types.Insert("denied-from", Type("Date"));
	Types.Insert("denied-message", Type("String"));
	Types.Insert("denied-parameter", Type("String"));
	Types.Insert("denied-to", Type("Date"));
	Types.Insert("permission-code", Type("String"));
	Types.Insert("external-session-manager-connection-string", Type("String"));
	Types.Insert("external-session-manager-required", Type("Boolean"));
	Types.Insert("security-profile-name", Type("String"));
	Types.Insert("safe-mode-security-profile-name", Type("String"));
	Types.Insert("descr", Type("String"));

	Return New FixedMap(Types);
	
EndFunction

Function SessionPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("session", Type("String"));
	Types.Insert("session-id", Type("Number"));
	Types.Insert("infobase", Type("String"));
	Types.Insert("connection", Type("String"));
	Types.Insert("process", Type("String"));
	Types.Insert("user-name", Type("String"));
	Types.Insert("host", Type("String"));
	Types.Insert("app-id", Type("String"));
	Types.Insert("locale", Type("String"));
	Types.Insert("started-at", Type("Date"));
	Types.Insert("last-active-at", Type("Date"));
	Types.Insert("hibernate", Type("Boolean"));
	Types.Insert("passive-session-hibernate-time", Type("Number"));
	Types.Insert("hibernate-session-terminate-time", Type("Number"));
	Types.Insert("blocked-by-dbms", Type("Number"));
	Types.Insert("blocked-by-ls", Type("Number"));
	Types.Insert("bytes-all", Type("Number"));
	Types.Insert("bytes-last-5min", Type("Number"));
	Types.Insert("calls-all", Type("Number"));
	Types.Insert("calls-last-5min", Type("Number"));
	Types.Insert("dbms-bytes-all", Type("Number"));
	Types.Insert("dbms-bytes-last-5min", Type("Number"));
	Types.Insert("db-proc-info", Type("String"));
	Types.Insert("db-proc-took", Type("Number"));
	Types.Insert("db-proc-took-at", Type("Date"));
	Types.Insert("duration-all", Type("Number"));
	Types.Insert("duration-all-dbms", Type("Number"));
	Types.Insert("duration-current", Type("Number"));
	Types.Insert("duration-current-dbms", Type("Number"));
	Types.Insert("duration-last-5min", Type("Number"));
	Types.Insert("duration-last-5min-dbms", Type("Number"));
	Types.Insert("memory-current", Type("Number"));
	Types.Insert("memory-last-5min", Type("Number"));
	Types.Insert("memory-total", Type("Number"));
	Types.Insert("read-current", Type("Number"));
	Types.Insert("read-last-5min", Type("Number"));
	Types.Insert("read-total", Type("Number"));
	Types.Insert("write-current", Type("Number"));
	Types.Insert("write-last-5min", Type("Number"));
	Types.Insert("write-total", Type("Number"));
	
	Return New FixedMap(Types);
	
EndFunction

Function ConnectionPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("connection", Type("String"));
	Types.Insert("conn-id", Type("Number"));
	Types.Insert("user-name", Type("String"));
	Types.Insert("host", Type("String"));
	Types.Insert("app-id", Type("String"));
	Types.Insert("connected-at", Type("Date"));
	Types.Insert("thread-mode", Type("String"));
	Types.Insert("ib-conn-mode", Type("String"));
	Types.Insert("db-conn-mode", Type("String"));
	Types.Insert("blocked-by-dbms", Type("Number"));
	Types.Insert("bytes-all", Type("Number"));
	Types.Insert("bytes-last-5min", Type("Number"));
	Types.Insert("calls-all", Type("Number"));
	Types.Insert("calls-last-5min", Type("Number"));
	Types.Insert("dbms-bytes-all", Type("Number"));
	Types.Insert("dbms-bytes-last-5min", Type("Number"));
	Types.Insert("db-proc-info", Type("String"));
	Types.Insert("db-proc-took", Type("Number"));
	Types.Insert("db-proc-took-at", Type("Date"));
	Types.Insert("duration-all", Type("Number"));
	Types.Insert("duration-all-dbms", Type("Number"));
	Types.Insert("duration-current", Type("Number"));
	Types.Insert("duration-current-dbms", Type("Number"));
	Types.Insert("duration-last-5min", Type("Number"));
	Types.Insert("duration-last-5min-dbms", Type("Number"));
	Types.Insert("memory-current", Type("Number"));
	Types.Insert("memory-last-5min", Type("Number"));
	Types.Insert("memory-total", Type("Number"));
	Types.Insert("read-current", Type("Number"));
	Types.Insert("read-last-5min", Type("Number"));
	Types.Insert("read-total", Type("Number"));
	Types.Insert("write-current", Type("Number"));
	Types.Insert("write-last-5min", Type("Number"));
	Types.Insert("write-total", Type("Number"));
	
	Return New FixedMap(Types);
	
EndFunction

Function ProfilePropertyTypes()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("config", Type("Boolean"));
	Types.Insert("priv", Type("Boolean"));
	Types.Insert("directory", Type("String"));
	Types.Insert("com", Type("String"));
	Types.Insert("addin", Type("String"));
	Types.Insert("module", Type("String"));
	Types.Insert("app", Type("String"));
	Types.Insert("inet", Type("String"));
	Types.Insert("crypto", Type("Boolean"));
	Types.Insert("right-extension", Type("Boolean"));
	Types.Insert("right-extension-definition-roles", Type("String"));
	Types.Insert("all-modules-extension", Type("Boolean"));
	Types.Insert("modules-available-for-extension", Type("String"));
	Types.Insert("modules-not-available-for-extension", Type("String"));
	
	Return New FixedMap(Types);
		
EndFunction

Function ConnectionDetailsPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("connection", Type("String"));
	Types.Insert("conn-id", Type("Number"));
	Types.Insert("host", Type("String"));
	Types.Insert("process", Type("String"));
	Types.Insert("infobase", Type("String"));
	Types.Insert("application", Type("String"));
	Types.Insert("connected-at", Type("Date"));
	Types.Insert("session-number", Type("Number"));
	Types.Insert("blocked-by-ls", Type("Number"));
	
	Return New FixedMap(Types);
		
EndFunction

Function LicensePropertyTypes()
	
	Types = New Map;
	
	// Returns only for active process license.
	Types.Insert("process", Type("String"));
	Types.Insert("port", Type("Number"));
	Types.Insert("pid", Type("String"));
	Types.Insert("host", Type("String"));
	
	// Returns only for session license.
	Types.Insert("session", Type("String"));
	Types.Insert("user-name", Type("String"));
	Types.Insert("app-id", Type("String"));	
	Types.Insert("host", Type("String"));
	
	// Common to all licenses.
	Types.Insert("full-name", Type("String"));
	Types.Insert("series", Type("String"));
	Types.Insert("issued-by-server", Type("Boolean"));
	Types.Insert("license-type", Type("String"));
	Types.Insert("net", Type("Boolean"));
	Types.Insert("max-users-all", Type("Number"));
	Types.Insert("max-users-cur", Type("Number"));
	Types.Insert("rmngr-address", Type("String"));
	Types.Insert("rmngr-port", Type("Number"));
	Types.Insert("rmngr-pid", Type("String"));
	Types.Insert("short-presentation", Type("String"));
	Types.Insert("full-presentation", Type("String"));
	
	Return New FixedMap(Types);
		
EndFunction

Function LockPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("connection", Type("String"));
	Types.Insert("session", Type("String"));
	Types.Insert("object", Type("String"));
	Types.Insert("locked", Type("Date"));
	Types.Insert("descr", Type("String"));
	
	Return New FixedMap(Types);
		
EndFunction

Function WorkingProcessPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("process", Type("String"));
	Types.Insert("host", Type("String"));
	Types.Insert("port", Type("Number"));
	Types.Insert("pid", Type("String"));
	Types.Insert("is-enable", Type("Boolean"));
	Types.Insert("running", Type("Boolean"));
	Types.Insert("started-at", Type("Date"));
	Types.Insert("use", Type("String"));
	Types.Insert("available-perfomance", Type("Number"));
	Types.Insert("capacity", Type("Number"));
	Types.Insert("connections", Type("Number"));
	Types.Insert("memory-size", Type("Number"));
	Types.Insert("memory-excess-time", Type("Number"));
	Types.Insert("selection-size", Type("Number"));
	Types.Insert("avg-back-call-time", Type("Number"));
	Types.Insert("avg-call-time", Type("Number"));
	Types.Insert("avg-db-call-time", Type("Number"));
	Types.Insert("avg-lock-call-time", Type("Number"));
	Types.Insert("avg-server-call-time", Type("Number"));
	Types.Insert("avg-threads", Type("Number"));

	Return New FixedMap(Types);
		
EndFunction

Function VirtualDirectoryPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("alias", Type("String"));
	Types.Insert("physicalPath", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("allowedRead", Type("Boolean"));
	Types.Insert("allowedWrite", Type("Boolean"));

	Return New FixedMap(Types);
	
EndFunction

Function COMClassPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("fileName", Type("String"));
	Types.Insert("id", Type("String"));
	Types.Insert("host", Type("String"));
	
	Return New FixedMap(Types);
	
EndFunction

Function AddInPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("hash", Type("String"));
	
	Return New FixedMap(Types);
	
EndFunction

Function ExternalModulePropertyType()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("hash", Type("String"));
	
	Return New FixedMap(Types);
	
EndFunction

Function OSApplicationPropertyTypes()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("wild", Type("String"));
	
	Return New FixedMap(Types);
	
EndFunction

Function InternetResourcePropertyTypes()
	
	Types = New Map;
	
	Types.Insert("name", Type("String"));
	Types.Insert("descr", Type("String"));
	Types.Insert("protocol", Type("String"));
	Types.Insert("url", Type("String"));
	Types.Insert("port", Type("Number"));
	
	Return New FixedMap(Types);
	
EndFunction

Function SupportedProperties(Command, ClusterAdministrationParameters, PropertyTypes)
	
	Result = RunCommand(Command, ClusterAdministrationParameters, , , PropertyTypes);
	
	Properties = New Map;
	For Each KeyAndValue In Result[0] Do
		Properties.Insert(KeyAndValue.Key, True);
	EndDo;
	
	Return Properties;
	
EndFunction

Function RunCommand(Command, ClusterAdministrationParameters, Dictionary = Undefined, Filter = Undefined, PropertyTypes = Undefined)
	
	If SafeMode() <> False Then
		Raise NStr("en = 'Safe mode does not support cluster administration.';");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("en = 'SaaS mode does not support cluster administration.';");
	EndIf;
	
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
			           |- For Windows, reinstall 1C:Enterprise platform with ""1C:Enterprise server"" component selected.
			           |- For Linux, install the 1c-enterprise83-server* package.';"),
			ClientFile.FullName);
		
	EndIf;
	
	CommandLine = """" + Client + """ " + Command;
	
	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.CurrentDirectory = PlatformExecutableFilesDirectory();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	ApplicationStartupParameters.GetErrorStream = True;
	
	Result = FileSystem.StartApplication(ConvertACommandLineToAnArray(CommandLine),
		ApplicationStartupParameters);
	
	OutputStream = Result.OutputStream;
	ErrorStream = Result.ErrorStream;
	
	If ValueIsFilled(ErrorStream) Then
		Raise ErrorStream;
	EndIf;
	
	If IsBlankString(OutputStream) Then
		Return New Array;
	EndIf;
	
	Result = OutputParser(OutputStream, Dictionary, Filter, PropertyTypes);
	Return Result;
	
EndFunction

Function ClusterParameters(ClusterAdministrationParameters, ClusterID = Undefined)
	
	If ClusterID = Undefined Then
		ClusterID = ClusterID(ClusterAdministrationParameters);
	EndIf;
	
	ClusterParameters = "--cluster=" + ClusterID;
	If ValueIsFilled(ClusterAdministrationParameters.ClusterAdministratorName) Then
		ClusterParameters = ClusterParameters + " --cluster-user=""" + ClusterAdministrationParameters.ClusterAdministratorName + """";
		If ValueIsFilled(ClusterAdministrationParameters.ClusterAdministratorPassword) Then
			ClusterParameters = ClusterParameters + " --cluster-pwd=""" + ClusterAdministrationParameters.ClusterAdministratorPassword + """";
		EndIf;
	EndIf;
	
	If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerAddress) Then
		Server = TrimAll(ClusterAdministrationParameters.AdministrationServerAddress);
		If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerPort) Then
			Server = Server + ":" + AdjustValue(ClusterAdministrationParameters.AdministrationServerPort);
		EndIf;
		ClusterParameters = ClusterParameters + " " + Server;
	EndIf;
	
	Return ClusterParameters;
	
EndFunction

Procedure SubstituteParametersToCommand(Command, Val Parameter1, 
	Val Parameter2 = Undefined, 
	Val Parameter3 = Undefined, 
	Val Parameter4 = Undefined)
	
	Command = StringFunctionsClientServer.SubstituteParametersToString(Command, 
		AdjustValue(Parameter1),
		AdjustValue(Parameter2),
		AdjustValue(Parameter3),
		AdjustValue(Parameter4));
	
EndProcedure

Procedure AddCommandParametersByDictionary(Command, Dictionary, PropertiesValues, SupportedProperties = Undefined)
	
	For Each DictionaryFragment In Dictionary Do
		ParameterName = DictionaryFragment.Value;	
		If SupportedProperties <> Undefined And SupportedProperties.Get(ParameterName) = Undefined Then
			Continue;
		EndIf;
		
		If PropertiesValues.Property(DictionaryFragment.Key) Then
			
			ParameterValue = AdjustValue(PropertiesValues[DictionaryFragment.Key]);
			Command = Command + " --" + ParameterName + "=" + ParameterValue;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function SupportedObjectProperties(ReceivingParameters)
	
	If ReceivingParameters.ObjectType = "profile" Then
		Return ProfileSupportedProperties(ReceivingParameters.ClusterAdministrationParameters);
	ElsIf ReceivingParameters.ObjectType = "infobase" Then
		Return InfobaseSupportedProperties(ReceivingParameters.ClusterAdministrationParameters, 
			ReceivingParameters.IBAdministrationParameters);
	EndIf;
	
EndFunction

Function ProfileSupportedProperties(ClusterAdministrationParameters)
	
	ProfileName = "ServiceProfile-81e39185-997c-4ae3-81f7-e7582cfdfa03";
	ProfileDetails = NStr("en = 'Service profile for testing supported properties.';");
	
	ClusterParameters = ClusterParameters(ClusterAdministrationParameters);
	
	Command = "profile update --name=%1 --descr=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, ProfileDetails);
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 directory update --alias=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "Directory");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 com update --name=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "COMObject");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 addin update --name=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "AddIn");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 module update --name=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "ExternalModule");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 app update --name=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "Package");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Command = "profile acl --name=%1 inet update --name=%2 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName, "InternetResources");
	RunCommand(Command, ClusterAdministrationParameters);
	
	Properties = New Structure;
	
	Command = "profile list " + ClusterParameters;
	Properties.Insert("profile", SupportedProperties(Command, ClusterAdministrationParameters, ProfilePropertyTypes()));
	
	Command = "profile acl --name=%1 directory list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_directory", SupportedProperties(Command, ClusterAdministrationParameters, VirtualDirectoryPropertyTypes()));
	
	Command = "profile acl --name=%1 com list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_com", SupportedProperties(Command, ClusterAdministrationParameters, COMClassPropertyTypes()));
		
	Command = "profile acl --name=%1 addin list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_addin", SupportedProperties(Command, ClusterAdministrationParameters, AddInPropertyTypes()));
	
	Command = "profile acl --name=%1 module list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_module", SupportedProperties(Command, ClusterAdministrationParameters, ExternalModulePropertyType()));
	
	Command = "profile acl --name=%1 app list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_app", SupportedProperties(Command, ClusterAdministrationParameters, OSApplicationPropertyTypes()));
		
	Command = "profile acl --name=%1 inet list " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	Properties.Insert("profile_inet", SupportedProperties(Command, ClusterAdministrationParameters, InternetResourcePropertyTypes()));
		
	Command = "profile remove --name=%1 " + ClusterParameters;
	SubstituteParametersToCommand(Command, ProfileName);
	RunCommand(Command, ClusterAdministrationParameters);

	Return Properties;
	
EndFunction

Function InfobaseSupportedProperties(ClusterAdministrationParameters, IBAdministrationParameters)
	
	InfobaseProperties = InfobaseProperties1(ClusterAdministrationParameters, IBAdministrationParameters, Undefined);
	
	Properties = New Map;
	
	For Each KeyAndValue In InfobaseProperties Do
		Properties.Insert(KeyAndValue.Key, True);
	EndDo;
	
	Return Properties;
	
EndFunction

Function ConvertACommandLineToAnArray(Val CommandLine)
	
	Result = New Array;
	
	TheQuotationMarksAreOpen = False;
	StringLength = StrLen(CommandLine);
	PreviousChar = "";
	NewItem = "";
	
	For IndexOf = 1 To StringLength Do
		
		Char = Mid(CommandLine, IndexOf, 1);
		If Char = """" Then
			TheQuotationMarksAreOpen = Not TheQuotationMarksAreOpen;
		EndIf;
		
		If Not Char = """" Then
			NewItem = NewItem + Char;
		EndIf;
		
		If PreviousChar = """" And Char = """"
			 And TheQuotationMarksAreOpen Then
			NewItem = NewItem + PreviousChar;
		EndIf;
		
		If (Char = " " And Not TheQuotationMarksAreOpen) Or IndexOf = StringLength Then
			If Not IsBlankString(NewItem) Then
				Result.Add(TrimAll(NewItem));
			EndIf;
			
			NewItem = "";
			Continue;
		EndIf;
		
		PreviousChar = Char;
		
	EndDo;
		
	Return Result;
	
EndFunction

#EndRegion