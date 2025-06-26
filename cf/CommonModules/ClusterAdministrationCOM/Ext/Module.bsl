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
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Result = COMAdministratorObjectModelObjectDetails(
		IB.InfoBase,
		SessionAndScheduledJobLockPropertiesDictionary());
	
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
	
	LockToSet = New Structure();
	For Each KeyAndValue In SessionAndJobLockProperties Do
		LockToSet.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If Not ValueIsFilled(LockToSet.DateFrom1) Then
		LockToSet.DateFrom1 = ClusterAdministration.DateEmpty();
	EndIf;
	
	If Not ValueIsFilled(LockToSet.DateTo) Then
		LockToSet.DateTo = ClusterAdministration.DateEmpty();
	EndIf;
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(IB.InfoBase,
		LockToSet,
		SessionAndScheduledJobLockPropertiesDictionary());
	
	IB.IWorkingProcessConnection.UpdateInfoBase(IB.InfoBase);
	
EndProcedure

// Checks whether administration parameters are filled correctly.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   CheckClusterAdministrationParameters - Boolean - Indicates whether a check of cluster 
//                  administration parameters is required.
//  CheckClusterAdministrationParameters - Boolean - Indicates whether cluster administration
//                  parameters check is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckInfobaseAdministrationParameters = True,
	CheckClusterAdministrationParameters = True) Export
	
	If CheckClusterAdministrationParameters Or CheckInfobaseAdministrationParameters Then
		
		ConnectionAttempt = 1;
		While ConnectionAttempt <= 2 Do
			Try
				COMConnector = COMConnector();
				
				IServerAgentConnection = IServerAgentConnection(COMConnector,
					ClusterAdministrationParameters.ServerAgentAddress,
					ClusterAdministrationParameters.ServerAgentPort);
				
				Cluster = GetCluster(IServerAgentConnection,
					ClusterAdministrationParameters.ClusterPort,
					ClusterAdministrationParameters.ClusterAdministratorName,
					ClusterAdministrationParameters.ClusterAdministratorPassword);

				ConnectionAttempt = ConnectionAttempt + 1;
			Except
				ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot connect to the server cluster from computer %1. Reason:
						|%2.';"),
					ComputerName(), ErrorProcessing.BriefErrorDescription(ErrorInfo()));
				If Common.IsWindowsServer() Then 
					If ConnectionAttempt = 1 Then
						If RegisterCOMConnector(ExceptionText + Chars.LF + Chars.LF) Then
							ConnectionAttempt = ConnectionAttempt + 1;
							Continue;
						EndIf;
					EndIf;
				EndIf;
				ExceptionText = ExceptionText + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'If you get the ""Class not registered"" or comcntr version mismatch error,
						|register comcntr on computer %1. Contact the administrator for assistance.
						|To register the comcntr component, run the regsvr32.exe comcntr.dll command
						|using a Windows account under which 1C:Enterprise server runs.';"),
					ComputerName());
				Raise ExceptionText
				
			EndTry;
		EndDo;
		
	EndIf;
	
	If CheckInfobaseAdministrationParameters Then
		
		WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
		
		GetIB(WorkingProcessesConnections, Cluster,
			IBAdministrationParameters.NameInCluster,
			IBAdministrationParameters.InfobaseAdministratorName,
			IBAdministrationParameters.InfobaseAdministratorPassword);
		
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
//   Boolean - the lock state.
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Return IB.InfoBase.ScheduledJobsDenied;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   LockScheduledJobs - Boolean - Indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val LockScheduledJobs) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	IB.InfoBase.ScheduledJobsDenied = LockScheduledJobs;
	IB.IWorkingProcessConnection.UpdateInfoBase(IB.InfoBase);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Returns descriptions of infobase sessions.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter
//          - Array of See ClusterAdministration.SessionsFilter
//
// Returns: 
//   Array of See ClusterAdministration.SessionProperties
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	IInfoBaseShort = GetIBDetails(
		IServerAgentConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster);
	
	Return GetSessions(IServerAgentConnection, Cluster, IInfoBaseShort, Filter, True);
	
EndFunction

// Deletes infobase sessions according to filter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter
//          - Array of See ClusterAdministration.SessionsFilter
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	IInfoBaseShort = GetIBDetails(
		IServerAgentConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster);
	
	AttemptsNumber = 3;
	AllSessionsTerminated = False;
	
	For CurrentAttempt = 0 To AttemptsNumber Do
		
		Sessions = GetSessions(IServerAgentConnection, Cluster, IInfoBaseShort, Filter, False);
		
		If Sessions.Count() = 0 Then
			
			AllSessionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptsNumber Then
			
			Break;
			
		EndIf;
		
		For Each Session In Sessions Do
			
			Try
				
				IServerAgentConnection.TerminateSession(Cluster, Session);
				
			Except
				
				// The session might close before TerminateSession is called.
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
//   Filter - See ClusterAdministration.JoinsFilters
//          - Array of See ClusterAdministration.JoinsFilters
//
// Returns: 
//   Array of See ClusterAdministration.ConnectionProperties
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, 
	Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	Return GetConnections(
		COMConnector,
		IServerAgentConnection,
		Cluster,
		IBAdministrationParameters,
		Filter,
		True);
	
EndFunction

// Terminates infobase connections according to filter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters
//          - Array of See ClusterAdministration.JoinsFilters
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, 
	Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
		
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
		
		Joins = GetConnections(
			COMConnector,
			IServerAgentConnection,
			Cluster,
			IBAdministrationParameters,
			Filter,
			False);
	
		If Joins.Count() = 0 Then
			
			AllConnectionsTerminated = True;
			Break;
			
		ElsIf CurrentAttempt = AttemptsNumber Then
			
			Break;
			
		EndIf;
	
		For Each Join In Joins Do
			
			Try
				
				Join.IWorkingProcessConnection.Disconnect(Join.Join);
				
			Except
				
				// The connection might terminate before TerminateSession is called.
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
//   String - name of the security profile set for the infobase. If the infobase is not assigned
//                  with a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(IB.InfoBase.SecurityProfileName) Then
		Result = IB.InfoBase.SecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the name of the security profile that was set as the infobase safe mode
//  security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String - name of the security profile set for the infobase as the safe
//                  mode security profile. If the infobase is not assigned with a security profile, an empty string is returned.
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(IB.InfoBase.SafeModeSecurityProfileName) Then
		Result = IB.InfoBase.SafeModeSecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Assigns a security profile to an infobase.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the security profile is 
//                  disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	IB.InfoBase.SecurityProfileName = ProfileName;
	IB.IWorkingProcessConnection.UpdateInfoBase(IB.InfoBase);
	
EndProcedure

// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is 
//                  disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessesConnections = WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster);
	
	IB = GetIB(WorkingProcessesConnections, Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	IB.InfoBase.SafeModeSecurityProfileName = ProfileName;
	IB.IWorkingProcessConnection.UpdateInfoBase(IB.InfoBase);
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - name of the security profile whose existence is checked.
//
// Returns:
//   Boolean
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	For Each SecurityProfile In IServerAgentConnection.GetSecurityProfiles(Cluster) Do
		
		If SecurityProfile.Name = ProfileName Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

// Returns properties of a security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//
// Returns: 
//   See ClusterAdministration.SecurityProfileProperties
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(IServerAgentConnection, Cluster, ProfileName);
	
	Result = COMAdministratorObjectModelObjectDetails(
		SecurityProfile,
		SecurityProfilePropertiesDictionary());
	
	// Virtual directories.
	Result.Insert("VirtualDirectories",
		COMAdministratorObjectModelObjectsDetails(
			GetVirtualDirectories(IServerAgentConnection, Cluster, ProfileName),
			VirtualDirectoryPropertiesDictionary()));
	
	// Allowed COM classes.
	Result.Insert("COMClasses",
		COMAdministratorObjectModelObjectsDetails(
			GetCOMClasses(IServerAgentConnection, Cluster, ProfileName),
			COMClassPropertiesDictionary()));
	
	// Add-ins.
	Result.Insert("AddIns",
		COMAdministratorObjectModelObjectsDetails(
			GetAddIns1(IServerAgentConnection, Cluster, ProfileName),
			AddInPropertiesDictionary()));
	
	// External modules.
	Result.Insert("ExternalModules",
		COMAdministratorObjectModelObjectsDetails(
			GetExternalModules(IServerAgentConnection, Cluster, ProfileName),
			ExternalModulePropertiesDictionary()));
	
	// OS applications.
	Result.Insert("OSApplications",
		COMAdministratorObjectModelObjectsDetails(
			GetOSApplications(IServerAgentConnection, Cluster, ProfileName),
			OSApplicationPropertiesDictionary()));
	
	// Internet resources.
	Result.Insert("InternetResources",
		COMAdministratorObjectModelObjectsDetails(
			GetInternetResources(IServerAgentConnection, Cluster, ProfileName),
			InternetResourcePropertiesDictionary()));
	
	Return Result;
	
EndFunction

// Creates a security profile on the basis of the passed description.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = IServerAgentConnection.CreateSecurityProfile();
	ApplySecurityProfilePropertyChanges(IServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(
		IServerAgentConnection,
		Cluster,
		SecurityProfileProperties.Name);
	
	ApplySecurityProfilePropertyChanges(IServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties);
	
EndProcedure

// Deletes a security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	IServerAgentConnection = IServerAgentConnection(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		IServerAgentConnection,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	GetSecurityProfile(
		IServerAgentConnection,
		Cluster,
		ProfileName);
	
	IServerAgentConnection.UnregSecurityProfile(Cluster, ProfileName);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Function COMConnector()
	
	If SafeMode() <> False Then
		Raise NStr("en = 'Safe mode does not support cluster administration.';");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("en = 'SaaS mode does not support cluster administration.';");
	EndIf;
	
	Return New COMObject(CommonClientServer.COMConnectorName());
	
EndFunction

Function RegisterCOMConnector(Val Message = "")
	ApplicationStartupParameters = FileSystem.ApplicationStartupParameters();
	ApplicationStartupParameters.WaitForCompletion = True;
	ApplicationStartupParameters.GetOutputStream = True;
	CommandText = StringFunctionsClientServer.SubstituteParametersToString(
		"regsvr32.exe /n /i:user /s ""%1\comcntr.dll""", BinDir());
	RunResult = FileSystem.StartApplication(CommandText, ApplicationStartupParameters);
	
	Comment = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1The comcntr component is reregistered on computer %2.
			|Command: %3
			|Return code:%4, message:
			|%5';"), 
		Message, ComputerName(), CommandText, RunResult.ReturnCode, RunResult.OutputStream);
	WriteLogEvent(NStr("en = 'Connect to server cluster';", Common.DefaultLanguageCode()),
		?(RunResult.ReturnCode = 0, EventLogLevel.Information, EventLogLevel.Warning),,, 
		Comment);
	Return RunResult.ReturnCode = 0;
EndFunction

Function IServerAgentConnection(COMConnector, Val ServerAgentAddress, Val ServerAgentPort)
	
	ServerAgentConnectionString = "tcp://" + ServerAgentAddress + ":" + Format(ServerAgentPort, "NG=0");
	IServerAgentConnection = COMConnector.ConnectAgent(ServerAgentConnectionString);
	Return IServerAgentConnection;
	
EndFunction

Function GetCluster(IServerAgentConnection, Val ClusterPort, Val ClusterAdministratorName, Val ClusterAdministratorPassword)
	
	For Each Cluster In IServerAgentConnection.GetClusters() Do
		If Cluster.MainPort = ClusterPort Then
			IServerAgentConnection.Authenticate(Cluster, ClusterAdministratorName, ClusterAdministratorPassword);
			Return Cluster;
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cluster %2 does not exist on production server %1';"),
		IServerAgentConnection.ConnectionString,
		ClusterPort);
	
EndFunction

Function WorkingProcessesConnections(COMConnector, IServerAgentConnection, Cluster)
	
	Result = New Array;
	
	For Each IWorkingProcessInfo In IServerAgentConnection.GetWorkingProcesses(Cluster) Do
		If IWorkingProcessInfo.Running And IWorkingProcessInfo.IsEnable  Then
			WorkingProcessConnectionString = IWorkingProcessInfo.HostName + ":" + Format(IWorkingProcessInfo.MainPort, "NG=");
			Result.Add(COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString));
		EndIf;
	EndDo;
	
	If Result.Count() = 0 Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'There are no active working processes on server cluster %1:%2.';"),
			Cluster.HostName,
			Format(Cluster.MainPort, "NG=0"));
	EndIf;
	Return Result;	
		
EndFunction

Function GetIBDetails(IServerAgentConnection, Cluster, Val NameInCluster)
	
	For Each IInfoBaseShort In IServerAgentConnection.GetInfoBases(Cluster) Do
		If Lower(IInfoBaseShort.Name) = Lower(NameInCluster) Then
			Return IInfoBaseShort;
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Infobase ""%3"" does not exist on server cluster %1:%2';"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster);
	
EndFunction

Function GetIB(WorkingProcessesConnections, Cluster, Val NameInCluster, Val IBAdministratorName, Val IBAdministratorPassword)
	
	InfobaseFound = False;

	For Each IWorkingProcessConnection In WorkingProcessesConnections Do
		IWorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
	
		For Each InfoBase In IWorkingProcessConnection.GetInfoBases() Do
			
			If Lower(InfoBase.Name) <> Lower(NameInCluster) Then
				Continue;
			EndIf;
			
			InfobaseFound = True;
			If Not ValueIsFilled(InfoBase.DBMS) Then
				Continue;
			EndIf;
			
			Result = New Structure("InfoBase, IWorkingProcessConnection");
			Result.InfoBase = InfoBase;
			Result.IWorkingProcessConnection = IWorkingProcessConnection;
			Return Result;
			
		EndDo;
	EndDo;
	
	If InfobaseFound Then	
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Incorrect administrator name or password for infobase %1, server cluster %2:%3 (name: ""%4"").';"),
			NameInCluster, Cluster.HostName, Cluster.MainPort, IBAdministratorName);
	Else		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Infobase ""%3"" does not exist on server cluster %1:%2';"),
			Cluster.HostName, Format(Cluster.MainPort, "NG=0"), NameInCluster);
	EndIf;
		
EndFunction

Function GetSessions(IServerAgentConnection, Cluster, InfoBase, Val Filter = Undefined, Val DetailsList1 = False)
	
	Sessions = New Array;
	
	Dictionary = SessionPropertiesDictionary();
	SessionLocks = New Map();
	
	For Each Block In IServerAgentConnection.GetInfoBaseLocks(Cluster, InfoBase) Do
		
		If Block.Session <> Undefined Then
			
			ClusterAdministration.SessionDataFromLock(
				SessionLocks,
				Block.LockDescr,
				Block.Session.SessionID,
				InfoBase.Name);
			
		EndIf;
		
	EndDo;
	
	For Each Session In IServerAgentConnection.GetInfoBaseSessions(Cluster, InfoBase) Do
		
		SessionDetails = COMAdministratorObjectModelObjectDetails(Session, Dictionary);
		SessionDetails.Insert("DBLockMode",
			?(SessionLocks[SessionDetails.Number] <> Undefined, SessionLocks[SessionDetails.Number].DBLockMode, ""));
		SessionDetails.Insert("Separator",
			?(SessionLocks[SessionDetails.Number] <> Undefined, SessionLocks[SessionDetails.Number].Separator, ""));
		
		If ClusterAdministration.CheckFilterConditions(SessionDetails, Filter) Then
			
			If DetailsList1 Then
				Sessions.Add(SessionDetails);
			Else
				Sessions.Add(Session);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Sessions;
	
EndFunction

Function GetConnections(COMConnector, IServerAgentConnection, Cluster, IBAdministrationParameters, Val Filter = Undefined, Val DetailsList1 = False)
	
	NameInCluster = IBAdministrationParameters.NameInCluster;
	IBAdministratorName = IBAdministrationParameters.InfobaseAdministratorName;
	IBAdministratorPassword = IBAdministrationParameters.InfobaseAdministratorPassword;
	
	Joins = New Array();
	Dictionary = ConnectionPropertiesDictionary();
	
	For Each IWorkingProcessInfo In IServerAgentConnection.GetWorkingProcesses(Cluster) Do
		
		If IWorkingProcessInfo.Running = 0 Then
			Continue;
		EndIf;
		
		WorkingProcessConnectionString = IWorkingProcessInfo.HostName + ":" + Format(IWorkingProcessInfo.MainPort, "NG=");
		IWorkingProcessConnection = COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString);
		
		For Each InfoBase In IWorkingProcessConnection.GetInfoBases() Do
			
			If Lower(InfoBase.Name) = Lower(NameInCluster) Then
				
				IWorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
				For Each Join In IWorkingProcessConnection.GetInfoBaseConnections(InfoBase) Do
					
					IConnectionShort = COMAdministratorObjectModelObjectDetails(Join, Dictionary);
					If ClusterAdministration.CheckFilterConditions(IConnectionShort, Filter) Then
						If DetailsList1 Then
							Joins.Add(IConnectionShort);
						Else
							Joins.Add(New Structure("IWorkingProcessConnection, Join", IWorkingProcessConnection, Join));
						EndIf;
					EndIf;
				
				EndDo;
			EndIf;
		EndDo;
	EndDo;
	
	Return Joins;
	
EndFunction

Function GetSecurityProfile(IServerAgentConnection, Cluster, ProfileName)
	
	For Each SecurityProfile In IServerAgentConnection.GetSecurityProfiles(Cluster) Do
		If Lower(SecurityProfile.Name) = Lower(ProfileName) Then
			Return SecurityProfile;
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Security profile ""%3"" does not exist on server cluster %1:%2';"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		ProfileName);
	
EndFunction

Function GetVirtualDirectories(IServerAgentConnection, Cluster, ProfileName)
	
	VirtualDirectories = New Array();
	
	For Each ISecurityProfileVirtualDirectory In IServerAgentConnection.GetSecurityProfileVirtualDirectories(Cluster, ProfileName) Do
		
		VirtualDirectories.Add(ISecurityProfileVirtualDirectory);
		
	EndDo;
	
	Return VirtualDirectories;
	
EndFunction

Function GetCOMClasses(IServerAgentConnection, Cluster, ProfileName)
	
	COMClasses = New Array();
	
	For Each COMClass In IServerAgentConnection.GetSecurityProfileCOMClasses(Cluster, ProfileName) Do
		
		COMClasses.Add(COMClass);
		
	EndDo;
	
	Return COMClasses;
	
EndFunction

Function GetAddIns1(IServerAgentConnection, Cluster, ProfileName)
	
	AddIns = New Array();
	
	For Each AddIn In IServerAgentConnection.GetSecurityProfileAddIns(Cluster, ProfileName) Do
		
		AddIns.Add(AddIn);
		
	EndDo;
	
	Return AddIns;
	
EndFunction

Function GetExternalModules(IServerAgentConnection, Cluster, ProfileName)
	
	ExternalModules = New Array();
	
	For Each ExternalModule In IServerAgentConnection.GetSecurityProfileUnSafeExternalModules(Cluster, ProfileName) Do
		
		ExternalModules.Add(ExternalModule);
		
	EndDo;
	
	Return ExternalModules;
	
EndFunction

Function GetOSApplications(IServerAgentConnection, Cluster, ProfileName)
	
	OSApplications = New Array();
	
	For Each OSApplication In IServerAgentConnection.GetSecurityProfileApplications(Cluster, ProfileName) Do
		
		OSApplications.Add(OSApplication);
		
	EndDo;
	
	Return OSApplications;
	
EndFunction

Function GetInternetResources(IServerAgentConnection, Cluster, ProfileName)
	
	InternetResources = New Array();
	
	For Each InternetResource In IServerAgentConnection.GetSecurityProfileInternetResources(Cluster, ProfileName) Do
		
		InternetResources.Add(InternetResource);
		
	EndDo;
	
	Return InternetResources;
	
EndFunction

Procedure ApplySecurityProfilePropertyChanges(IServerAgentConnection, Cluster, SecurityProfile, SecurityProfileProperties)
	
	FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
		SecurityProfile,
		SecurityProfileProperties,
		SecurityProfilePropertiesDictionary());
	
	ProfileName = SecurityProfileProperties.Name;
	
	IServerAgentConnection.RegSecurityProfile(Cluster, SecurityProfile);
	
	// Virtual directories.
	VirtualDirectoriesToDelete = GetVirtualDirectories(IServerAgentConnection, Cluster, ProfileName);
	For Each VirtualDirectoryToDelete In VirtualDirectoriesToDelete Do
		IServerAgentConnection.UnregSecurityProfileVirtualDirectory(
			Cluster,
			ProfileName,
			VirtualDirectoryToDelete.Alias);
	EndDo;
	VirtualDirectoriesToCreate = SecurityProfileProperties.VirtualDirectories;
	For Each VirtualDirectoryToCreate In VirtualDirectoriesToCreate Do
		ISecurityProfileVirtualDirectory = IServerAgentConnection.CreateSecurityProfileVirtualDirectory();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			ISecurityProfileVirtualDirectory,
			VirtualDirectoryToCreate,
			VirtualDirectoryPropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileVirtualDirectory(Cluster, ProfileName, ISecurityProfileVirtualDirectory);
	EndDo;
	
	// Allowed COM classes.
	COMClassesToDelete = GetCOMClasses(IServerAgentConnection, Cluster, ProfileName);
	For Each COMClassToDelete In COMClassesToDelete Do
		IServerAgentConnection.UnregSecurityProfileCOMClass(
			Cluster,
			ProfileName,
			COMClassToDelete.Name);
	EndDo;
	COMClassesToCreate = SecurityProfileProperties.COMClasses;
	For Each COMClassToCreate In COMClassesToCreate Do
		COMClass = IServerAgentConnection.CreateSecurityProfileCOMClass();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			COMClass,
			COMClassToCreate,
			COMClassPropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileCOMClass(Cluster, ProfileName, COMClass);
	EndDo;
	
	// Add-ins.
	AddInsToDelete = GetAddIns1(IServerAgentConnection, Cluster, ProfileName);
	For Each AddInToDelete In AddInsToDelete Do
		IServerAgentConnection.UnregSecurityProfileAddIn(
			Cluster,
			ProfileName,
			AddInToDelete.Name);
	EndDo;
	AddInsToCreate = SecurityProfileProperties.AddIns;
	For Each AddInToCreate In AddInsToCreate Do
		AddIn = IServerAgentConnection.CreateSecurityProfileAddIn();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			AddIn,
			AddInToCreate,
			AddInPropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileAddIn(Cluster, ProfileName, AddIn);
	EndDo;
	
	// External modules.
	ExternalModulesToDelete = GetExternalModules(IServerAgentConnection, Cluster, ProfileName);
	For Each ExternalModuleToDelete In ExternalModulesToDelete Do
		IServerAgentConnection.UnregSecurityProfileUnSafeExternalModule(
			Cluster,
			ProfileName,
			ExternalModuleToDelete.Name);
	EndDo;
	ExternalModulesToCreate = SecurityProfileProperties.ExternalModules;
	For Each ExternalModuleToCreate In ExternalModulesToCreate Do
		ExternalModule = IServerAgentConnection.CreateSecurityProfileUnSafeExternalModule();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			ExternalModule,
			ExternalModuleToCreate,
			ExternalModulePropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileUnSafeExternalModule(Cluster, ProfileName, ExternalModule);
	EndDo;
	
	// OS applications.
	OSApplicationsToDelete = GetOSApplications(IServerAgentConnection, Cluster, ProfileName);
	For Each OSApplicationToDelete In OSApplicationsToDelete Do
		IServerAgentConnection.UnregSecurityProfileApplication(
			Cluster,
			ProfileName,
			OSApplicationToDelete.Name);
	EndDo;
	OSApplicationsToCreate = SecurityProfileProperties.OSApplications;
	For Each OSApplicationToCreate In OSApplicationsToCreate Do
		OSApplication = IServerAgentConnection.CreateSecurityProfileApplication();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			OSApplication,
			OSApplicationToCreate,
			OSApplicationPropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileApplication(Cluster, ProfileName, OSApplication);
	EndDo;
	
	// Internet resources.
	InternetResourcesToDelete = GetInternetResources(IServerAgentConnection, Cluster, ProfileName);
	For Each InternetResourceToDelete In InternetResourcesToDelete Do
		IServerAgentConnection.UnregSecurityProfileInternetResource(
			Cluster,
			ProfileName,
			InternetResourceToDelete.Name);
	EndDo;
	InternetResourcesToCreate = SecurityProfileProperties.InternetResources;
	For Each InternetResourceToCreate In InternetResourcesToCreate Do
		InternetResource = IServerAgentConnection.CreateSecurityProfileInternetResource();
		FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
			InternetResource,
			InternetResourceToCreate,
			InternetResourcePropertiesDictionary());
		IServerAgentConnection.RegSecurityProfileInternetResource(Cluster, ProfileName, InternetResource);
	EndDo;
	
EndProcedure

Function COMAdministratorObjectModelObjectDetails(Val Object, Val Dictionary)
	
	ObjectProperties = New Structure;
	For Each DictionaryFragment In Dictionary Do
		If TypeOf(DictionaryFragment.Value) = Type("String") Then
			ObjectProperties.Insert(DictionaryFragment.Value);
		ElsIf TypeOf(DictionaryFragment.Value) = Type("FixedStructure") Then
			ObjectProperties.Insert(DictionaryFragment.Value.Key);
		EndIf;
	EndDo;
	FillPropertyValues(ObjectProperties, Object);
	
	LongDesc = New Structure();
	For Each DictionaryFragment In Dictionary Do
		If TypeOf(DictionaryFragment.Value) = Type("String") Then
			LongDesc.Insert(DictionaryFragment.Key, ObjectProperties[DictionaryFragment.Value]);
		ElsIf TypeOf(DictionaryFragment.Value) = Type("FixedStructure") Then
			SubordinateObject = ObjectProperties[DictionaryFragment.Value.Key];
			If SubordinateObject = Undefined Then
				LongDesc.Insert(DictionaryFragment.Key, Undefined);
			Else
				Property = COMAdministratorObjectModelObjectDetails(SubordinateObject, DictionaryFragment.Value.Dictionary);
				LongDesc.Insert(DictionaryFragment.Key, Property);
			EndIf;
		EndIf;
	EndDo;
	
	Return LongDesc;
	
EndFunction

Function COMAdministratorObjectModelObjectsDetails(Val Objects, Val Dictionary)
	
	DetailsList1 = New Array();
	
	For Each Object In Objects Do
		DetailsList1.Add(COMAdministratorObjectModelObjectDetails(Object, Dictionary));
	EndDo;
	
	Return DetailsList1;
	
EndFunction

Procedure FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(Object, Val LongDesc, Val Dictionary)
	
	ObjectProperties = New Structure;
	For Each DictionaryFragment In Dictionary Do
		If TypeOf(DictionaryFragment.Value) = Type("String") Then
			If LongDesc.Property(DictionaryFragment.Key) Then
				ObjectProperties.Insert(DictionaryFragment.Value, LongDesc[DictionaryFragment.Key]);
			EndIf;
		EndIf;
	EndDo;
	
	FillPropertyValues(Object, ObjectProperties);
	
EndProcedure

Function SessionAndScheduledJobLockPropertiesDictionary()
	
	Result = ClusterAdministration.SessionAndScheduleJobLockProperties();
	
	Result.SessionsLock = "SessionsDenied";
	Result.DateFrom1 = "DeniedFrom";
	Result.DateTo = "DeniedTo";
	Result.Message = "DeniedMessage";
	Result.KeyCode = "PermissionCode";
	Result.LockParameter = "DeniedParameter";
	Result.LockScheduledJobs = "ScheduledJobsDenied";
	
	Return New FixedStructure(Result);
	
EndFunction

Function SessionPropertiesDictionary()
	
	ILicenseInfo = New Structure;
	ILicenseInfo.Insert("Key", "License");
	ILicenseInfo.Insert("Dictionary", LicensePropertiesDictionary());
	
	IConnectionShort = New Structure;
	IConnectionShort.Insert("Key", "Connection");
	IConnectionShort.Insert("Dictionary", ConnectionDetailsPropertiesDictionary());
	
	IWorkingProcessInfo = New Structure;
	IWorkingProcessInfo.Insert("Key", "Process");
	IWorkingProcessInfo.Insert("Dictionary", WorkingProcessPropertiesDictionary());
	
	Result = ClusterAdministration.SessionProperties();
	
	Result.Number = "SessionID";
	Result.UserName = "UserName";
	Result.ClientComputerName = "Host";
	Result.ClientApplicationID = "AppID";
	Result.LanguageID = "Locale";
	Result.SessionCreationTime = "StartedAt";
	Result.LatestSessionActivityTime = "LastActiveAt";
	Result.DBMSLock = "blockedByDBMS";
	Result.Block = "blockedByLS";
	Result.Passed = "bytesAll";
	Result.PassedIn5Minutes = "bytesLast5Min";
	Result.ServerCalls = "callsAll";
	Result.ServerCallsIn5Minutes = "callsLast5Min";
	Result.ServerCallDurations = "durationAll";
	Result.CurrentServerCallDuration = "durationCurrent";
	Result.ServerCallDurationsIn5Minutes = "durationLast5Min";
	Result.ExchangedWithDBMS = "dbmsBytesAll";
	Result.ExchangedWithDBMSIn5Minutes = "dbmsBytesLast5Min";
	Result.DBMSCallDuration = "durationAllDBMS";
	Result.CurrentDBMSCallDuration = "durationCurrentDBMS";
	Result.DBMSCallDurationsIn5Minutes = "durationLast5MinDBMS";
	Result.DBMSConnection = "dbProcInfo";
	Result.DBMSConnectionTime = "dbProcTook";
	Result.DBMSConnectionSeizeTime = "dbProcTookAt";
	Result.Sleep = "Hibernate";
	Result.TerminateIn = "HibernateSessionTerminateTime";
	Result.SleepIn = "PassiveSessionHibernateTime";
	Result.ReadFromDisk = "InBytesAll";
	Result.ReadFromDiskInCurrentCall = "InBytesCurrent";
	Result.ReadFromDiskIn5Minutes = "InBytesLast5Min";
	Result.OccupiedMemory = "MemoryAll";
	Result.OccupiedMemoryInCurrentCall = "MemoryCurrent";
	Result.OccupiedMemoryIn5Minutes = "MemoryLast5Min";
	Result.WrittenOnDisk = "OutBytesAll";
	Result.WrittenOnDiskInCurrentCall = "OutBytesCurrent";
	Result.WrittenOnDiskIn5Minutes = "OutBytesLast5Min";
	Result.ILicenseInfo = New FixedStructure(ILicenseInfo);
	Result.IConnectionShort = New FixedStructure(IConnectionShort);
	Result.IWorkingProcessInfo = New FixedStructure(IWorkingProcessInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionPropertiesDictionary()
	
	Result = ClusterAdministration.ConnectionProperties();
	
	Result.Number = "ConnID";
	Result.UserName = "UserName";
	Result.ClientComputerName = "HostName";
	Result.ClientApplicationID = "AppID";
	Result.ConnectionEstablishingTime = "ConnectedAt";
	Result.InfobaseConnectionMode = "IBConnMode";
	Result.DataBaseConnectionMode = "dbConnMode";
	Result.DBMSLock = "blockedByDBMS";
	Result.Passed = "bytesAll";
	Result.PassedIn5Minutes = "bytesLast5Min";
	Result.ServerCalls = "callsAll";
	Result.ServerCallsIn5Minutes = "callsLast5Min";
	Result.ExchangedWithDBMS = "dbmsBytesAll";
	Result.ExchangedWithDBMSIn5Minutes = "dbmsBytesLast5Min";
	Result.DBMSConnection = "dbProcInfo";
	Result.DBMSTime = "dbProcTook";
	Result.DBMSConnectionSeizeTime = "dbProcTookAt";
	Result.ServerCallDurations = "durationAll";
	Result.DBMSCallDuration = "durationAllDBMS";
	Result.CurrentServerCallDuration = "durationCurrent";
	Result.CurrentDBMSCallDuration = "durationCurrentDBMS";
	Result.ServerCallDurationsIn5Minutes = "durationLast5Min";
	Result.DBMSCallDurationsIn5Minutes = "durationLast5MinDBMS";
	Result.ReadFromDisk = "InBytesAll";
	Result.ReadFromDiskInCurrentCall = "InBytesCurrent";
	Result.ReadFromDiskIn5Minutes = "InBytesLast5Min";
	Result.OccupiedMemory = "MemoryAll";
	Result.OccupiedMemoryInCurrentCall = "MemoryCurrent";
	Result.OccupiedMemoryIn5Minutes = "MemoryLast5Min";
	Result.WrittenOnDisk = "OutBytesAll";
	Result.WrittenOnDiskInCurrentCall = "OutBytesCurrent";
	Result.WrittenOnDiskIn5Minutes = "OutBytesLast5Min";
	Result.ControlIsOnServer = "ThreadMode";
	
	Return New FixedStructure(Result);
	
EndFunction

Function SecurityProfilePropertiesDictionary()
	
	Result = ClusterAdministration.SecurityProfileProperties();
	
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	Result.SafeModeProfile = "SafeModeProfile";
	Result.FullAccessToPrivilegedMode = "PrivilegedModeInSafeModeAllowed";
	Result.FullAccessToCryptoFunctions = "CryptographyAllowed";
	
	Result.FullAccessToAllModulesExtension = "AllModulesExtension";
	Result.ModulesAvailableForExtension = "ModulesAvailableForExtension";
	Result.ModulesNotAvailableForExtension = "ModulesNotAvailableForExtension";
	
	Result.FullAccessToAccessRightsExtension = "RightExtension";
	Result.AccessRightsExtensionLimitingRoles = "RightExtensionDefinitionRoles";
	
	Result.FileSystemFullAccess = "FileSystemFullAccess";
	Result.COMObjectFullAccess = "COMFullAccess";
	Result.AddInFullAccess = "AddInFullAccess";
	Result.ExternalModuleFullAccess = "UnSafeExternalModuleFullAccess";
	Result.FullOperatingSystemApplicationAccess = "ExternalAppFullAccess";
	Result.InternetResourcesFullAccess = "InternetFullAccess";
	
	Return New FixedStructure(Result);
	
EndFunction

Function VirtualDirectoryPropertiesDictionary()
	
	Result = ClusterAdministration.VirtualDirectoryProperties();
	
	Result.LogicalURL = "Alias";
	Result.PhysicalURL = "PhysicalPath";
	
	Result.LongDesc = "Descr";
	
	Result.DataReader = "AllowedRead";
	Result.DataWriter = "AllowedWrite";
	
	Return New FixedStructure(Result);
	
EndFunction

Function COMClassPropertiesDictionary()
	
	Result = ClusterAdministration.COMClassProperties();
	
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	
	Result.FileMoniker = "FileName";
	Result.CLSID = "ObjectUUID";
	Result.Computer = "ComputerName";
	
	Return New FixedStructure(Result);
	
EndFunction

Function AddInPropertiesDictionary()
	
	Result = ClusterAdministration.AddInProperties();
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	Result.HashSum = "AddInHash";
	Return New FixedStructure(Result);
	
EndFunction

Function ExternalModulePropertiesDictionary()
	
	Result = ClusterAdministration.ExternalModuleProperties();
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	Result.HashSum = "ExternalModuleHash";
	Return New FixedStructure(Result);
	
EndFunction

Function OSApplicationPropertiesDictionary()
	
	Result = ClusterAdministration.OSApplicationProperties();
	
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	
	Result.CommandLinePattern = "CommandMask";
	
	Return New FixedStructure(Result);
	
EndFunction

Function InternetResourcePropertiesDictionary()
	
	Result = ClusterAdministration.InternetResourceProperties();
	
	Result.Name = "Name";
	Result.LongDesc = "Descr";
	
	Result.Protocol = "Protocol";
	Result.Address = "Address";
	Result.Port = "Port";
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionDetailsPropertiesDictionary()
	
	IWorkingProcessInfo = New Structure;
	IWorkingProcessInfo.Insert("Key", "Process");
	IWorkingProcessInfo.Insert("Dictionary", WorkingProcessPropertiesDictionary());
	
	Result = ClusterAdministration.ConnectionDetailsProperties();
	
	Result.ApplicationName = "Application";
	Result.Block = "blockedByLS";
	Result.ConnectionEstablishingTime = "ConnectedAt";
	Result.Number = "ConnID";
	Result.ClientComputerName = "Host";
	Result.SessionNumber = "SessionID";
	Result.IWorkingProcessInfo = New FixedStructure(IWorkingProcessInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

Function LicensePropertiesDictionary()
	
	Result = ClusterAdministration.LicenseProperties();
	
	Result.FileName = "FileName";
	Result.FullPresentation = "FullPresentation";
	Result.BriefPresentation = "ShortPresentation";
	Result.IssuedByServer = "IssuedByServer";
	Result.LisenceType = "LicenseType";
	Result.MaxUsersForSet = "MaxUsersAll";
	Result.MaxUsersInKey = "MaxUsersCur";
	Result.LicenseIsReceivedViaAladdinLicenseManager = "Net";
	Result.ProcessAddress = "RMngrAddress";
	Result.ProcessID = "RMngrPID";
	Result.ProcessPort = "RMngrPort";
	Result.KeySeries = "Series";
	
	Return New FixedStructure(Result);
	
EndFunction

Function WorkingProcessPropertiesDictionary()
	
	ILicenseInfo = New Structure;
	ILicenseInfo.Insert("Key", "License");
	ILicenseInfo.Insert("Dictionary", LicensePropertiesDictionary());
	
	Result = ClusterAdministration.WorkingProcessProperties();
	
	Result.AvailablePerformance = "AvailablePerfomance";
	Result.SpentByTheClient = "AvgBackCallTime";
	Result.ServerReaction = "AvgCallTime";
	Result.SpentByDBMS = "AvgDBCallTime";
	Result.SpentByTheLockManager = "AvgLockCallTime";
	Result.SpentByTheServer = "AvgServerCallTime";
	Result.ClientStreams = "AvgThreads";
	Result.Capacity = "Capacity";
	Result.Connections = "Connections";
	Result.ComputerName = "HostName";
	Result.Enabled = "IsEnable";
	Result.Port = "MainPort";
	Result.ExceedingTheCriticalValue = "MemoryExcessTime";
	Result.OccupiedMemory = "MemorySize";
	Result.Id = "PID";
	Result.Started2 = "Running";
	Result.CallsCountByWhichTheStatisticsIsCalculated = "SelectionSize";
	Result.StartedAt = "StartedAt";
	Result.Use = "Use";
	Result.ILicenseInfo = New FixedStructure(ILicenseInfo);
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion