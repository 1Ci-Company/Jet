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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Result = COMAdministratorObjectModelObjectDetails(
		InfoBase,
		SessionAndScheduledJobLockPropertiesDictionary());
	
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
	
	LockToSet = New Structure();
	For Each KeyAndValue In SessionAndJobLockProperties Do
		LockToSet.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If Not ValueIsFilled(LockToSet.DateFrom1) Then
		LockToSet.DateFrom1 = ClusterAdministrationClientServer.DateEmpty();
	EndIf;
	
	If Not ValueIsFilled(LockToSet.DateTo) Then
		LockToSet.DateTo = ClusterAdministrationClientServer.DateEmpty();
	EndIf;
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	FillCOMAdministratorObjectModelObjectPropertiesByDeclaration(
		InfoBase,
		LockToSet,
		SessionAndScheduledJobLockPropertiesDictionary());
	
	IWorkingProcessConnection.UpdateInfoBase(InfoBase);
	
EndProcedure

// Checks whether administration parameters are filled correctly.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - Structure - Describes infobase connection parameters.
//    Details -  See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//    The parameter can be skipped if the same fields have been filled in the structure passed
//    as the ClusterAdministrationParameters parameter value,
//  CheckClusterAdministrationParameters - Boolean - Indicates whether a check of cluster
//                                                administration parameters is required,
//  CheckClusterAdministrationParameters - Boolean - Indicates whether cluster administration
//                                                          parameters check is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckInfobaseAdministrationParameters = True,
	CheckClusterAdministrationParameters = True) Export
	
	If CheckClusterAdministrationParameters Or CheckInfobaseAdministrationParameters Then
		
		Try
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
		Except
#If WebClient Or MobileClient Then
			Raise;
#Else
			Raise ErrorProcessing.BriefErrorDescription(ErrorInfo()) + Chars.LF + Chars.LF
				+ StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'If the comcntr version mismatch error occurs, register comcntr on computer %1
					|using a Windows account under which 1C:Enterprise runs. Example:
					|regsvr32.exe ""%2\comcntr.dll""';"), ComputerName(), BinDir());
#EndIf
		EndTry;
		
	EndIf;
	
	If CheckInfobaseAdministrationParameters Then
		
		IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
		
		GetIB(
			IWorkingProcessConnection,
			Cluster,
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
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   Boolean
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	Return InfoBase.ScheduledJobsDenied;
	
EndFunction

// Sets the state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  LockScheduledJobs - Boolean - Indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val LockScheduledJobs) Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	InfoBase.ScheduledJobsDenied = LockScheduledJobs;
	IWorkingProcessConnection.UpdateInfoBase(InfoBase);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Returns descriptions of infobase sessions.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
//
// Returns:
//   Array of See ClusterAdministrationClientServer.SessionProperties
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.SessionsFilter See ClusterAdministration.SessionsFilter
//            , Array of
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//            , Array of
//
// Returns:
//   Array of See ClusterAdministrationClientServer.ConnectionProperties
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters See ClusterAdministration.JoinsFilters
//            , Array of
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val Filter = Undefined) Export
	
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

	ClusterAdministrationClientServer.AddFilterCondition(Filter, "ClientApplicationID", ComparisonType.InList, Value);
		
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   String - name of the security profile set for the infobase. If
//            the infobase is not assigned with a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(InfoBase.SecurityProfileName) Then
		Result = InfoBase.SecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	InfoBase = Undefined;
	IWorkingProcessConnection = Undefined;
	Cluster = Undefined;
	IServerAgentConnection = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
EndFunction

// Returns the name of the security profile that was set as the infobase safe mode
//  security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//
// Returns:
//   String - name of the security profile set for the infobase as the safe mode security
//            profile. If the infobase is not assigned with a security profile, returns
//            an empty string.
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters) Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	If ValueIsFilled(InfoBase.SafeModeSecurityProfileName) Then
		Result = InfoBase.SafeModeSecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	InfoBase = Undefined;
	IWorkingProcessConnection = Undefined;
	Cluster = Undefined;
	IServerAgentConnection = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
EndFunction

// Assigns a security profile to an infobase.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the security profile is
//                disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	InfoBase.SecurityProfileName = ProfileName;
	
	IWorkingProcessConnection.UpdateInfoBase(InfoBase);
	
	InfoBase = Undefined;
	IWorkingProcessConnection = Undefined;
	Cluster = Undefined;
	IServerAgentConnection = Undefined;
	COMConnector = Undefined
	
EndProcedure

// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is
//                disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val ProfileName = "") Export
	
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
	
	IWorkingProcessConnection = IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster);
	
	InfoBase = GetIB(
		IWorkingProcessConnection,
		Cluster,
		IBAdministrationParameters.NameInCluster,
		IBAdministrationParameters.InfobaseAdministratorName,
		IBAdministrationParameters.InfobaseAdministratorPassword);
	
	InfoBase.SafeModeSecurityProfileName = ProfileName;
	
	IWorkingProcessConnection.UpdateInfoBase(InfoBase);
	
	InfoBase = Undefined;
	IWorkingProcessConnection = Undefined;
	Cluster = Undefined;
	IServerAgentConnection = Undefined;
	COMConnector = Undefined
	
EndProcedure

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   ProfileName - String - name of the security profile whose existence is checked.
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//
// Returns:
//   See ClusterAdministrationClientServer.SecurityProfileProperties
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties
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
//   ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties
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
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - Security profile name.
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
	
	// ACC:547-off This code is required for backward compatibility. It is used in an obsolete API.
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then 
	If SafeMode() <> False Then
		Raise NStr("en = 'Warning! Cluster administration is unavailable in safe mode.';");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("en = 'Warning! The infobase features related to cluster administration are unavailable in SaaS mode.';");
	EndIf;
	
	Return New COMObject(CommonClientServer.COMConnectorName());
#ElsIf MobileClient Then
	Raise NStr("en = 'Warning! The mobile client does not support cluster administration.';");
#Else
	Return New COMObject(CommonClientServer.COMConnectorName());
#EndIf
	
	// ACC:547-on
	
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

Function IWorkingProcessConnection(COMConnector, IServerAgentConnection, Cluster)
	
	For Each IWorkingProcessInfo In IServerAgentConnection.GetWorkingProcesses(Cluster) Do
		If IWorkingProcessInfo.Running And IWorkingProcessInfo.IsEnable  Then
			WorkingProcessConnectionString = IWorkingProcessInfo.HostName + ":" + Format(IWorkingProcessInfo.MainPort, "NG=");
			Return COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString);
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'There are no active working processes on server cluster %1:%2.';"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"));
	
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

Function GetIB(IWorkingProcessConnection, Cluster, Val NameInCluster, Val IBAdministratorName, Val IBAdministratorPassword)
	
	IWorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
	
	For Each InfoBase In IWorkingProcessConnection.GetInfoBases() Do
		
		If Lower(InfoBase.Name) = Lower(NameInCluster) Then
			
			If Not ValueIsFilled(InfoBase.DBMS) Then
				
				Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Incorrect administrator name or password for infobase %1, server cluster %2:%3 (name: ""%4"").';"),
					NameInCluster,
					Cluster.HostName, 
					Cluster.MainPort,
					IBAdministratorName);
				
			EndIf;
			
			Return InfoBase;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Infobase ""%3"" does not exist on server cluster %1:%2';"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster);
	
EndFunction

Function GetSessions(IServerAgentConnection, Cluster, InfoBase, Val Filter = Undefined, Val DetailsList1 = False)
	
	Sessions = New Array;
	
	Dictionary = SessionPropertiesDictionary();
	
	For Each Session In IServerAgentConnection.GetInfoBaseSessions(Cluster, InfoBase) Do
		
		SessionDetails = COMAdministratorObjectModelObjectDetails(Session, Dictionary);
		
		If ClusterAdministrationClientServer.CheckFilterConditions(SessionDetails, Filter) Then
			
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
	
	// active processes that are registered in the cluster.
	For Each IWorkingProcessInfo In IServerAgentConnection.GetWorkingProcesses(Cluster) Do
		
		// Administrative connection with the active process.
		WorkingProcessConnectionString = IWorkingProcessInfo.HostName + ":" + Format(IWorkingProcessInfo.MainPort, "NG=");
		IWorkingProcessConnection = COMConnector.ConnectWorkingProcess(WorkingProcessConnectionString);
		
		// Getting infobases (no authentication required).
		For Each InfoBase In IWorkingProcessConnection.GetInfoBases() Do
			
			// This is a required infobase.
			If Lower(InfoBase.Name) = Lower(NameInCluster) Then
				
				// Authentication is required to get infobase connection data.
				IWorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
				
				// Getting infobase connections.
				For Each Join In IWorkingProcessConnection.GetInfoBaseConnections(InfoBase) Do
					
					IConnectionShort = COMAdministratorObjectModelObjectDetails(Join, Dictionary);
					
					// Checking whether the connection passes the filters.
					If ClusterAdministrationClientServer.CheckFilterConditions(IConnectionShort, Filter) Then
						
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
	
	LongDesc = New Structure();
	For Each DictionaryFragment In Dictionary Do
		If ValueIsFilled(Object[DictionaryFragment.Value]) Then
			LongDesc.Insert(DictionaryFragment.Key, Object[DictionaryFragment.Value]);
		Else
			LongDesc.Insert(DictionaryFragment.Key, Undefined);
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
	
	For Each DictionaryFragment In Dictionary Do
		
		PropertyName = DictionaryFragment.Value;
		PropertyValue = LongDesc[DictionaryFragment.Key];
		
		Object[PropertyName] = PropertyValue;
		
	EndDo;
	
EndProcedure

Function SessionAndScheduledJobLockPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "SessionsDenied");
	Result.Insert("DateFrom1", "DeniedFrom");
	Result.Insert("DateTo", "DeniedTo");
	Result.Insert("Message", "DeniedMessage");
	Result.Insert("KeyCode", "PermissionCode");
	Result.Insert("LockParameter", "DeniedParameter");
	Result.Insert("LockScheduledJobs", "ScheduledJobsDenied");
	
	Return New FixedStructure(Result);
	
EndFunction

Function SessionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "SessionID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "Host");
	Result.Insert("ClientApplicationID", "AppID");
	Result.Insert("LanguageID", "Locale");
	Result.Insert("SessionCreationTime", "StartedAt");
	Result.Insert("LatestSessionActivityTime", "LastActiveAt");
	Result.Insert("DBMSLock", "blockedByDBMS");
	Result.Insert("Block", "blockedByLS");
	Result.Insert("Passed", "bytesAll");
	Result.Insert("PassedIn5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsIn5Minutes", "callsLast5Min");
	Result.Insert("ServerCallDurations", "durationAll");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("ServerCallDurationsIn5Minutes", "durationLast5Min");
	Result.Insert("ExchangedWithDBMS", "dbmsBytesAll");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("DBMSCallDuration", "durationAllDBMS");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("DBMSCallDurationsIn5Minutes", "durationLast5MinDBMS");
	Result.Insert("DBMSConnection", "dbProcInfo");
	Result.Insert("DBMSConnectionTime", "dbProcTook");
	Result.Insert("DBMSConnectionSeizeTime", "dbProcTookAt");
	
	Return New FixedStructure(Result);
	
EndFunction

Function ConnectionPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "ConnID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "HostName");
	Result.Insert("ClientApplicationID", "AppID");
	Result.Insert("ConnectionEstablishingTime", "ConnectedAt");
	Result.Insert("InfobaseConnectionMode", "IBConnMode");
	Result.Insert("DataBaseConnectionMode", "dbConnMode");
	Result.Insert("DBMSLock", "blockedByDBMS");
	Result.Insert("Passed", "bytesAll");
	Result.Insert("PassedIn5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsIn5Minutes", "callsLast5Min");
	Result.Insert("ExchangedWithDBMS", "dbmsBytesAll");
	Result.Insert("ExchangedWithDBMSIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("DBMSConnection", "dbProcInfo");
	Result.Insert("DBMSTime", "dbProcTook");
	Result.Insert("DBMSConnectionSeizeTime", "dbProcTookAt");
	Result.Insert("ServerCallDurations", "durationAll");
	Result.Insert("DBMSCallDuration", "durationAllDBMS");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("ServerCallDurationsIn5Minutes", "durationLast5Min");
	Result.Insert("DBMSCallDurationsIn5Minutes", "durationLast5MinDBMS");
	
	Return New FixedStructure(Result);
	
EndFunction

Function SecurityProfilePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	Result.Insert("SafeModeProfile", "SafeModeProfile");
	Result.Insert("FullAccessToPrivilegedMode", "PrivilegedModeInSafeModeAllowed");
	
	Result.Insert("FileSystemFullAccess", "FileSystemFullAccess");
	Result.Insert("COMObjectFullAccess", "COMFullAccess");
	Result.Insert("AddInFullAccess", "AddInFullAccess");
	Result.Insert("ExternalModuleFullAccess", "UnSafeExternalModuleFullAccess");
	Result.Insert("FullOperatingSystemApplicationAccess", "ExternalAppFullAccess");
	Result.Insert("InternetResourcesFullAccess", "InternetFullAccess");
	
	Return New FixedStructure(Result);
	
EndFunction

Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "Alias");
	Result.Insert("PhysicalURL", "PhysicalPath");
	
	Result.Insert("LongDesc", "Descr");
	
	Result.Insert("DataReader", "AllowedRead");
	Result.Insert("DataWriter", "AllowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	
	Result.Insert("FileMoniker", "FileName");
	Result.Insert("CLSID", "ObjectUUID");
	Result.Insert("Computer", "ComputerName");
	
	Return New FixedStructure(Result);
	
EndFunction

Function AddInPropertiesDictionary()
	
	Result = New Structure();
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	Result.Insert("HashSum", "AddInHash"); // ACC:1036 for backward compatibility.
	Return New FixedStructure(Result);
	
EndFunction

Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	Result.Insert("HashSum", "ExternalModuleHash"); // ACC:1036 for backward compatibility.
	Return New FixedStructure(Result);
	
EndFunction

Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	
	Result.Insert("CommandLinePattern", "CommandMask");
	
	Return New FixedStructure(Result);
	
EndFunction

Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("LongDesc", "Descr");
	
	Result.Insert("Protocol", "Protocol");
	Result.Insert("Address", "Address");
	Result.Insert("Port", "Port");
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion