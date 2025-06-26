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

#Region ObsoleteProceduresAndFunctions

#Region ProgramInterfaceParameterConstructors

// Deprecated. Instead, use ClusterAdministration.ClusterAdministrationParameters.
// Constructor of a structure that defines the connection parameters of the server cluster
// being administrated.
//
// Returns:
//  Structure:
//    * AttachmentType - String - possible values:
//        "COM" - when connecting to the server agent using the V8*.ComConnector COM object,
//        "RAS" - when connecting the administration server (ras) using the console
//                client of the administration server (rac),
//    * ServerAgentAddress - String - network address of the server agent (only for ConnectionType = "COM"),
//    * ServerAgentPort - Number - network port of the server agent (only for ConnectionType = "COM").
//      Usually, 1540,
//    * AdministrationServerAddress - String - network address of the ras administration server (only
//      with ConnectionType = "RAS"),
//    * AdministrationServerPort - Number - network port of the ras administration server (only with
//      ConnectionType = "RAS"). Usually, 1545,
//    * ClusterPort - Number - network port of the cluster manager. Usually, 1541,
//    * ClusterAdministratorName - String - cluster administrator account name (if the list of administrators
//      is not specified for the cluster, the value is set to empty string),
//    * ClusterAdministratorPassword - String - cluster administrator account password. If
//      the list of administrators is not specified for the cluster or the administrator account password is not set,
//      the value is a blank string.
//
Function ClusterAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("AttachmentType", "COM"); // "COM" or "RAS"
	
	// For "COM" only
	Result.Insert("ServerAgentAddress", "");
	Result.Insert("ServerAgentPort", 1540);
	
	// For "RAS" only
	Result.Insert("AdministrationServerAddress", "");
	Result.Insert("AdministrationServerPort", 1545);
	
	Result.Insert("ClusterPort", 1541);
	Result.Insert("ClusterAdministratorName", "");
	Result.Insert("ClusterAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.ClusterInfobaseAdministrationParameters.
// Constructor of a structure that defines the cluster
//  infobase connection parameters being administered.
//
// Returns: 
//  Structure:
//    * NameInCluster - String - name of the infobase in cluster server,
//    * InfobaseAdministratorName - String - name of the infobase user with administrative
//      rights (if the list of infobase users is not set, the value is set
//      to empty string),
//    * InfobaseAdministratorPassword - String - password of the infobase user
//      with administrative rights (if the list of infobase users is not set
//      or the infobase user password is not set, the value is set to empty string).
//
Function ClusterInfobaseAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("NameInCluster", "");
	Result.Insert("InfobaseAdministratorName", "");
	Result.Insert("InfobaseAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.CheckAdministrationParameters.
// Checks whether administration parameters are filled correctly.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  CheckClusterAdministrationParameters - Boolean - Indicates whether a check of cluster administration parameters is required,
//  CheckInfobaseAdministrationParameters - Boolean - Indicates whether a check of cluster
//                                                                   administration parameters is required.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined,
	CheckClusterAdministrationParameters = True,
	CheckInfobaseAdministrationParameters = True) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	AdministrationManager.CheckAdministrationParameters(ClusterAdministrationParameters, IBAdministrationParameters, CheckInfobaseAdministrationParameters, CheckClusterAdministrationParameters);
	
EndProcedure

#EndRegion

#Region SessionAndScheduledJobLock

// Deprecated. Instead, use ClusterAdministration.SessionAndScheduleJobLockProperties.
// Constructor of a structure that defines infobase session and
//  scheduled job lock properties.
//
// Returns:
//  Structure:
//    * SessionsLock - Boolean - Indicates whether new infobase sessions are locked,
//    * DateFrom1 - Date - (Date and time) a moment of time after which new infobase sessions are prohibited,
//    * DateTo - Date - (Date and time) a moment of time after which new infobase sessions are allowed,
//    * Message - String - the message displayed to the user when a new session is being established
//      with the locked infobase,
//    * KeyCode - String - a pass code that allows to connect to a locked infobase,
//    * LockScheduledJobs - Boolean - flag that shows whether infobase
//      scheduled jobs must be locked.
//
Function SessionAndScheduleJobLockProperties() Export
	
	Result = New Structure();
	
	Result.Insert("SessionsLock");
	Result.Insert("DateFrom1");
	Result.Insert("DateTo");
	Result.Insert("Message");
	Result.Insert("KeyCode");
	Result.Insert("LockParameter");
	Result.Insert("LockScheduledJobs");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InfobaseSessionAndJobLock.
// Returns the current state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
// Returns: 
//    See ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties.
//
Function InfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.SetInfobaseSessionAndJobLock.
// Sets the state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  SessionAndJobLockProperties - See ClusterAdministrationClientServer.SessionAndScheduleJobLockProperties.
//
Procedure SetInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val SessionAndJobLockProperties) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		SessionAndJobLockProperties);
	
EndProcedure

// Deprecated. Instead, use ClusterAdministration.RemoveInfobaseSessionAndJobLock.
// Unlocks infobase sessions and scheduled jobs.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
Procedure RemoveInfobaseSessionAndJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	LockProperties = SessionAndScheduleJobLockProperties();
	LockProperties.SessionsLock = False;
	LockProperties.DateFrom1 = Undefined;
	LockProperties.DateTo = Undefined;
	LockProperties.Message = "";
	LockProperties.KeyCode = "";
	LockProperties.LockScheduledJobs = False;
	
	SetInfobaseSessionAndJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		LockProperties);
	
EndProcedure

#EndRegion

#Region LockScheduledJobs

// Deprecated. Instead, use ClusterAdministration.InfobaseScheduledJobLock.
// Returns the current state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
// Returns:
//    Boolean - True if scheduled jobs are successfully locked, False otherwise.
//
Function InfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseScheduledJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.SetInfobaseScheduledJobLock.
// Sets the state of infobase scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters
//  LockScheduledJobs - Boolean - Indicates whether infobase scheduled jobs are locked.
//
Procedure SetInfobaseScheduledJobLock(Val ClusterAdministrationParameters, Val IBAdministrationParameters, Val LockScheduledJobs) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseScheduledJobLock(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		LockScheduledJobs);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Deprecated. Instead, use ClusterAdministration.SessionProperties.
// Constructor of a structure that describes infobase session properties.
//
// Returns: 
//  Structure:
//   * Number - Number - session number. The number is unique across the infobase sessions,
//   * UserName - String - Infobase user's name,
//   * ClientComputerName - String - name or network address of the computer that established
//     the session with the infobase,
//   * ClientApplicationID - String - ID of the application that established the session.
//     See the description of the ApplicationPresentation global function.
//   * LanguageID - String - Interface language ID,
//   * SessionCreationTime - Date - Date and time the session was created,
//   * LatestSessionActivityTime - Date - Date and time of the session last activity,
//   * Block - Number - number of the session that resulted in managed transactional
//     lock wait if the session sets managed transactional locks
//     and waits for locks set by another session to be disabled. Otherwise, the value is 0,
//   * DBMSLock - Number - number of the session that caused transactional
//     lock wait if the session performs a DBMS call and waits for a transactional
//     lock set by another session to be disabled. Otherwise, the value is 0,
//   * Passed - Number - volume of data passed between the 1C:Enterprise server and the current session
//     client application since the session start, in bytes,
//   * PassedIn5Minutes - Number - volume of data passed between the 1C:Enterprise server and the current session client
//     application in the last 5 minutes, in bytes,
//   * ServerCalls - Number - number of the 1C:Enterprise server calls made by the current session since
//     the session started,
//   * ServerCallsIn5Minutes - Number - number of the 1C:Enterprise server calls made by the current session
//     in the last 5 minutes,
//   * ServerCallDurations - Number - total 1C:Enterprise server call time made by the
//     current session since the session start, in milliseconds,
//   * CurrentServerCallDuration - Number - time interval since the 1C:Enterprise server call
//     start. If there is no server call, the value is 0,
//   * ServerCallDurationsIn5Minutes - Number - total time of 1C:Enterprise server calls made by
//     the current session in the last 5 minutes, in milliseconds,
//   * ExchangedWithDBMS - Number - volume of data passed and received from DBMS on behalf of the current session
//     since the session start, in bytes,
//   * ExchangedWithDBMSIn5Minutes - Number - volume of data passed and received from DBMS on behalf of the current session
//     in the last 5 minutes, in bytes,
//   * DBMSCallDuration - Number - total time spent on executing DBMS queries made on behalf of the current session since the session
//     start, in milliseconds,
//   * CurrentDBMSCallDuration - Number - time interval since the current DBMS query
//     execution start, in milliseconds. If there is no query, the value is 0,
//   * DBMSCallDurationsIn5Minutes - Number - total time spent on executing DBMS queries made on behalf of the current session
//     in the last 5 minutes (in milliseconds),
//   * DBMSConnection - String - DBMS connection number in the terms of DBMS if when the session
//     list is retrieved, the DBMS query is executed, a transaction is opened, or temporary tables are defined (DBMS connection
//     is seized). If the DBMS session is not seized, the value is a blank string,
//   * DBMSConnectionTime - Number - the period since the DBMS connection capture, in milliseconds. If the
//     DBMS session is not seized - the value is 0,
//   * DBMSConnectionSeizeTime - Date - The date and time of the last
//     DBMS connection capture.
//
Function SessionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationID");
	Result.Insert("LanguageID");
	Result.Insert("SessionCreationTime");
	Result.Insert("LatestSessionActivityTime");
	Result.Insert("Block");
	Result.Insert("DBMSLock");
	Result.Insert("Passed");
	Result.Insert("PassedIn5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsIn5Minutes");
	Result.Insert("ServerCallDurations");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("ServerCallDurationsIn5Minutes");
	Result.Insert("ExchangedWithDBMS");
	Result.Insert("ExchangedWithDBMSIn5Minutes");
	Result.Insert("DBMSCallDuration");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("DBMSCallDurationsIn5Minutes");
	Result.Insert("DBMSConnection");
	Result.Insert("DBMSConnectionTime");
	Result.Insert("DBMSConnectionSeizeTime");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InfobaseSessions.
// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  Filter - Array of Structure:
//             * Property - See ClusterAdministrationClientServer.SessionProperties
//             * ComparisonType - ComparisonType - a value of system enumeration ComparisonType,
//             * Value - Number
//                        - String
//                        - Date
//                        - Boolean
//                        - ValueList
//                        - Array
//                        - Structure - the value
//               the matching session property value is compared with.
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value - the value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//           
//
// Returns:
//   Array of See ClusterAdministrationClientServer.SessionProperties
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.DeleteInfobaseSessions.
// Deletes infobase sessions according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  Filter - Array of Structure:
//             * Property - See ClusterAdministrationClientServer.SessionProperties
//             * ComparisonType - ComparisonType - a value of system enumeration ComparisonType,
//             * Value - Number
//                        - String
//                        - Date
//                        - Boolean
//                        - ValueList
//                        - Array
//                        - Structure - the value
//               the matching session property value is compared with,
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value - the value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteInfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region InfobaseConnections

// Deprecated. Instead, use ClusterAdministration.ConnectionProperties.
// Constructor of a structure that defines infobase connection properties.
//
// Returns:
//  Structure:
//    * Number - Number - a number of infobase connection,
//    * UserName - String - a name of the 1C:Enterprise user connected to the infobase,
//    * ClientComputerName - String - a name of the computer that established the connection,
//    * ClientApplicationID - String - ID of the application that established the connection. See the description of the
//                                                    ApplicationPresentation global function,
//    * ConnectionEstablishingTime - Date - the date and time when the connection was established,
//    * InfobaseConnectionMode - Number - the infobase connection mode (0 
//      if shared, 1 if exclusive),
//    * DataBaseConnectionMode - Number - database connection mode (0 if no connection,
//      1 - shared, 2 - exclusive),
//    * DBMSLock - Number - an ID of the connection that locks the current connection in the DBMS,
//    * Passed - Number - a volume of data that the connection sent and received,
//    * PassedIn5Minutes - Number - the volume of data sent and received by the connection in the last 5 minutes,
//    * ServerCalls - Number - the number of server calls,
//    * ServerCallsIn5Minutes - Number - the number of server calls in the last 5 minutes,
//    * ExchangedWithDBMS - Number - the data volume passed between the 1C:Enterprise server and the database server
//      since the connection was established,
//    * ExchangedWithDBMSIn5Minutes - Number - the volume of data passed between the 1C:Enterprise server and the database
//        server in the last 5 minutes,
//    * DBMSConnection - String - the DBMS connection process ID if the connection is contacting a DBMS server when the list
//      is requested. Otherwise, the value is a blank
//      string. The ID is returned in the DBMS server terms,
//    * DBMSTime - Number - the DBMS server call duration in seconds if the connection is contacting a DBMS server when the list
//      is requested. Otherwise, the value
//      is 0,
//    * DBMSConnectionSeizeTime - Date - the date and time of the last DBMS server connection capture,
//    * ServerCallDurations - Number - the duration of all connection server calls,
//    * DBMSCallDuration - Number - the duration of all DBMS calls the connection initiated,
//    * CurrentServerCallDuration - Number - the duration of the current server call,
//    * CurrentDBMSCallDuration - Number - the duration of the current DBMS server call,
//    * ServerCallDurationsIn5Minutes - Number - the duration of server calls in the last 5 minutes,
//    * DBMSCallDurationsIn5Minutes - Number - the duration of DBMS server calls in the last 5 minutes.
//
Function ConnectionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationID");
	Result.Insert("ConnectionEstablishingTime");
	Result.Insert("InfobaseConnectionMode");
	Result.Insert("DataBaseConnectionMode");
	Result.Insert("DBMSLock");
	Result.Insert("Passed");
	Result.Insert("PassedIn5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsIn5Minutes");
	Result.Insert("ExchangedWithDBMS");
	Result.Insert("ExchangedWithDBMSIn5Minutes");
	Result.Insert("DBMSConnection");
	Result.Insert("DBMSTime");
	Result.Insert("DBMSConnectionSeizeTime");
	Result.Insert("ServerCallDurations");
	Result.Insert("DBMSCallDuration");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("ServerCallDurationsIn5Minutes");
	Result.Insert("DBMSCallDurationsIn5Minutes");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InfobaseConnections.
// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  Filter - Array of Structure:
//             * Property - See ClusterAdministrationClientServer.ConnectionProperties
//             * ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of comparing the connection
//               values and the filter values,
//             * Value - Number
//                        - String
//                        - Date
//                        - Boolean
//                        - ValueList
//                        - Array
//                        - Structure - the value the matching connection property value
//               is compared with,
//         - Structure - Structure. Key - Name of the connection property (mentioned above). Value - Value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//
// Returns: 
//   Array of See ClusterAdministrationClientServer.ConnectionProperties.
//
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.TerminateInfobaseConnections.
// Terminates infobase connections according to filter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  Filter - Array of Structure:
//              * Property - See ClusterAdministrationClientServer.ConnectionProperties
//              * ComparisonType - ComparisonType - value of system enumeration ComparisonType, the type of comparing the connection
//                values and the filter values,
//              * Value - Number
//                         - String
//                         - Date
//                         - Boolean
//                         - ValueList
//                         - Array
//                         - Structure - the value the matching connection property value
//                is compared with,
//         - Structure - Structure. Key - Name of the connection property (mentioned above). Value - Value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.TerminateInfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Deprecated. Instead, use ClusterAdministration.InfobaseSecurityProfile.
// Returns the name of a security profile assigned to the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
// Returns:
//  String - name of the security profile set for the infobase. If
//  the infobase is not assigned with a security profile, returns an empty string.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InfobaseSafeModeSecurityProfile.
// Returns the name of the security profile that was set as the infobase safe mode
//  security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
// Returns:
//  String - name of the security profile set for the infobase as the safe mode security
//  profile. If the infobase is not assigned with a security profile, returns an empty
//  String
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.SetInfobaseSecurityProfile.
// Assigns a security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  ProfileName - String - Security profile name. If the passed string is empty, the security profile is
//    disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ProfileName);
	
EndProcedure

// Deprecated. Instead, use ClusterAdministration.SetInfobaseSafeModeSecurityProfile.
// Assigns a safe-mode security profile to an infobase.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is
//    disabled for the infobase.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ProfileName);
	
EndProcedure

// Deprecated. Instead, use ClusterAdministration.SecurityProfileExists.
// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - name of the security profile whose existence is checked.
//
// Returns:
//   Boolean - True if the profile with the specified name exists, False otherwise.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfileExists(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.SecurityProfileProperties.
// Constructor of the structure that defines security profile properties.
//
// Returns: 
//   Structure:
//     * Name - String - a security profile name,
//     * LongDesc - String - details of the security profile,
//     * SafeModeProfile - Boolean - flag that shows whether the security profile can be used
//       as a security profile of the safe mode (both when the profile
//       is specified for the infobase and when the SetSafeMode(<Profile name>) is called from the applied solution script),
//     * FullAccessToPrivilegedMode - Boolean - Indicates whether the privileged
//       mode can be set from the safe mode of the security profile,
//     * FileSystemFullAccess - Boolean - the flag that shows whether there are file
//       system access restrictions. If the value is False, infobase users can access only file
//       system directories specified in the VirtualDirectories property,
//     * COMObjectFullAccess - Boolean - the flag that shows whether there are restrictions to access
//       COM objects. If the value is False, infobase users can access only COM classes
//       specified in the COMClasses property,
//     * AddInFullAccess - Boolean - the flag that defines whether there are add-in
//       access restrictions. If the value is False, infobase users can access only add-ins
//       specified in the AddIns property,
//     * ExternalModuleFullAccess - Boolean - flag that shows whether there are external module
//       (external reports and data processors, Execute() and Evaluate() calls in the unsafe mode) access restrictions.
//       If the value is False, infobase users can use in the unsafe
//       mode only external modules specified in the ExternalModules property,
//     * FullOperatingSystemApplicationAccess - Boolean - the flag that shows whether there are operating system application
//       access restrictions. If the value is False, infobase users can
//       use operating system applications specified in the OSApplications property,
//     * InternetResourcesFullAccess - Boolean - Indicates if there are restrictions to access
//       Internet resources. If the value is False, infobase users can only
//       use Internet resources specified in the InternetResources property,
//     * VirtualDirectories - Array of See ClusterAdministrationClientServer.VirtualDirectoryProperties
//     * COMClasses - Array of See ClusterAdministrationClientServer.COMClassProperties
//     * AddIns - Array of See ClusterAdministrationClientServer.AddInProperties
//     * ExternalModules - Array of See ClusterAdministrationClientServer.ExternalModuleProperties
//     * OSApplications - Array of See ClusterAdministrationClientServer.OSApplicationProperties
//     * InternetResources - Array of See ClusterAdministrationClientServer.InternetResourceProperties
//
Function SecurityProfileProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name", "");
	Result.Insert("LongDesc", "");
	Result.Insert("SafeModeProfile", False);
	Result.Insert("FullAccessToPrivilegedMode", False);
	
	Result.Insert("FileSystemFullAccess", False);
	Result.Insert("COMObjectFullAccess", False);
	Result.Insert("AddInFullAccess", False);
	Result.Insert("ExternalModuleFullAccess", False);
	Result.Insert("FullOperatingSystemApplicationAccess", False);
	Result.Insert("InternetResourcesFullAccess", False);
	
	Result.Insert("VirtualDirectories", New Array());
	Result.Insert("COMClasses", New Array());
	Result.Insert("AddIns", New Array());
	Result.Insert("ExternalModules", New Array());
	Result.Insert("OSApplications", New Array());
	Result.Insert("InternetResources", New Array());
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.VirtualDirectoryProperties.
// Constructor of a structure that describe virtual directory properties.
//
// Returns: 
//   Structure:
//     * LogicalURL - String - the logical URL of a directory,
//     * PhysicalURL - String - the physical URL of the server directory where virtual directory
//       data is stored,
//     * LongDesc - String - virtual directory details,
//     * DataReader - Boolean - Indicates whether virtual directory data reading is allowed,
//     * DataWriter - Boolean - the flag that shows whether virtual directory data writing is allowed.
//
Function VirtualDirectoryProperties() Export
	
	Result = New Structure();
	
	Result.Insert("LogicalURL");
	Result.Insert("PhysicalURL");
	
	Result.Insert("LongDesc");
	
	Result.Insert("DataReader");
	Result.Insert("DataWriter");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.COMClassProperties.
// Constructor of a structure that describes COM class properties.
//
// Returns:
//   Structure:
//     * Name - String - the name of a COM class that is used as a search key,
//     * LongDesc - String - the COM class details,
//     * FileMoniker - String - the file name used to create an object with the GetCOMObject global 
//       context method. The object second parameter has a blank value,
//     * CLSID - String - the COM class ID presentation in the Windows system registry format 
//       without curly brackets, which the operating system uses to create the COM class,
//     * Computer - String - the name of the computer on which you can create the COM object.
//
Function COMClassProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("LongDesc");
	
	Result.Insert("FileMoniker");
	Result.Insert("CLSID");
	Result.Insert("Computer");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.AddInProperties.
// Constructor of the structure that describes the add-in properties.
//
// Returns:
//   Structure:
//     * Name - String - the name of the add-in. Used as a search key,
//     * LongDesc - String - the add-in details,
//     * HashSum - String - contains the checksum of the allowed add-in, calculated with SHA-1
//       algorithm and converted to a base64 string.
//
Function AddInProperties() Export
	
	Result = New Structure();
	Result.Insert("Name");
	Result.Insert("LongDesc");
	Result.Insert("HashSum"); // ACC:1036 for backward compatibility.
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.ExternalModuleProperties.
// Constructor of the structure that describes external module properties.
//
// Returns:
//   Structure:
//     * Name - String - name of the external module that is used as a search key,
//     * LongDesc - String - external module details,
//     * HashSum - String - contains the checksum of the allowed external module, calculated with SHA-1
//       algorithm and converted to a base64 string.
//
Function ExternalModuleProperties() Export
	
	Result = New Structure();
	Result.Insert("Name");
	Result.Insert("LongDesc");
	Result.Insert("HashSum"); // ACC:1036 for backward compatibility.
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.OSApplicationProperties.
// Constructor of a structure that defines operating system application properties.
//
// Returns:
//   Structure:
//     * Name - String - name of the operating system application that is used as a search key,
//     * LongDesc - String - the operating system application details,
//     * CommandLinePattern - String - application command line pattern, which consists of space-separated
//       pattern words.
//
Function OSApplicationProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("LongDesc");
	
	Result.Insert("CommandLinePattern");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InternetResourceProperties.
// Constructor of a structure that describes the Internet resource.
//
// Returns:
//   Structure:
//     * Name - String - name of the Internet resource that is used as a search key,
//     * LongDesc - String - Internet resource details,
//     * Protocol - String - an allowed network protocol. Possible values:
//         HTTP,
//         HTTPS,
//         FTP,
//         FTPS,
//         POP3,
//         SMTP,
//         IMAP,
//     * Address - String - a network address with no protocol and port,
//     * Port - Number - an Internet resource port.
//
Function InternetResourceProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("LongDesc");
	
	Result.Insert("Protocol");
	Result.Insert("Address");
	Result.Insert("Port");
	
	Return Result;
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.SecurityProfile.
// Returns properties of a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - Security profile name.
//
// Returns:
//   See ClusterAdministrationClientServer.SecurityProfileProperties.
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.CreateSecurityProfile.
// Creates a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties.
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.CreateSecurityProfile(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Deprecated. Instead, use ClusterAdministration.SetSecurityProfileProperties.
// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  SecurityProfileProperties - See ClusterAdministrationClientServer.SecurityProfileProperties.
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetSecurityProfileProperties(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Deprecated. Instead, use ClusterAdministration.DeleteSecurityProfile.
// Deletes a security profile.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  ProfileName - String - Security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteSecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndProcedure

#EndRegion

#Region Infobases

// Deprecated. Instead, use ClusterAdministration.InfobaseID.
// Returns an internal infobase ID.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfobaseAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//
// Returns:
//   String - Internal infobase ID.
//
Function InfoBaseID(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfoBaseID(
		ClusterID,
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.InfobasesProperties.
// Returns infobase descriptions.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - Infobase filtering criteria.
//
// Returns:
//  Array of Structure
//
Function InfobasesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobasesProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

#EndRegion

#Region Cluster

// Deprecated. Instead, use ClusterAdministration.ClusterID.
// Returns an internal ID of a server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters.
//
// Returns:
//   String - Internal server cluster ID.
//
Function ClusterID(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ClusterID(ClusterAdministrationParameters);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.ClusterProperties.
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
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ClusterProperties(ClusterAdministrationParameters, Filter);
	
EndFunction

#EndRegion

#Region WorkingProcessesServers

// Deprecated. Instead, use ClusterAdministration.WorkingProcessesProperties.
// Returns descriptions of active processes.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  Filter - Structure - active process filtering criteria.
//
// Returns:
//   Array of Structure 
//
Function WorkingProcessesProperties(Val ClusterID, Val ClusterAdministrationParameters, Val Filter = Undefined) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.WorkingProcessesProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.WorkingServerProperties.
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
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.WorkingServerProperties(
		ClusterID,
		ClusterAdministrationParameters,
		Filter);
	
EndFunction

#EndRegion

// Deprecated. Instead, use ClusterAdministration.SessionsProperties.
// Returns descriptions of infobase sessions.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfoBaseID - String - Internal infobase ID,
//  Filter - Array of Structure:
//             * Property - See ClusterAdministrationClientServer.SessionProperties
//             * ComparisonType - ComparisonType - a value of system enumeration ComparisonType,
//             * Value - Number
//                        - String
//                        - Date
//                        - Boolean
//                        - ValueList
//                        - Array
//                        - Structure - the value
//               the matching session property value is compared with.
//         - Structure - Structure. Key - the name of the session property (mentioned above). Value - the value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//           
//  UseDictionary - Boolean - If True, the return value is generated using a dictionary. Otherwise, the dictionary is not
//    used.
//
// Returns:
//   - Array of See ClusterAdministrationClientServer.SessionProperties
//   - Array of Map
//
Function SessionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val Filter = Undefined, Val UseDictionary = True) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SessionsProperties(
		ClusterID,
		ClusterAdministrationParameters,
		InfoBaseID,
		Filter,
		UseDictionary);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.ConnectionsProperties.
// Returns descriptions of infobase connections.
//
// Parameters:
//  ClusterID - String - Internal server cluster ID,
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters
//  InfoBaseID - String - Internal infobase ID,
//  InfobaseAdministrationParameters - See ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters.
//  Filter - Array of Structure:
//             * Property - See ClusterAdministrationClientServer.ConnectionsProperties
//             * ComparisonType - ComparisonType - a value of system enumeration ComparisonType,
//             * Value - Number
//                        - String
//                        - Date
//                        - Boolean
//                        - ValueList
//                        - Array
//                        - Structure - the value the matching connection property value
//               is compared with.
//         - Structure - Structure. Key - Name of the connection property (mentioned above). Value - Value to compare with.
//           When you use this filter description, the comparison type is "equal to".
//           
//  UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns:
//   - Array of See ClusterAdministrationClientServer.ConnectionsProperties
//   - Array of Map
//
Function ConnectionsProperties(Val ClusterID, Val ClusterAdministrationParameters, Val InfoBaseID, Val InfobaseAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ConnectionsProperties(
		ClusterID,
		ClusterAdministrationParameters,
		InfoBaseID,
		InfobaseAdministrationParameters,
		Filter,
		UseDictionary);
	
EndFunction

// Deprecated. Instead, use ClusterAdministration.PathToAdministrationServerClient.
// Returns path to the console client of the administration server.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministrationClientServer.ClusterAdministrationParameters.
//
// Returns:
//  String
//
Function PathToAdministrationServerClient(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.PathToAdministrationServerClient();
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Procedure AddFilterCondition(Filter, Val Property, Val ValueComparisonType, Val Value) Export
	
	If Filter = Undefined Then
		
		If ValueComparisonType = ComparisonType.Equal Then
			
			Filter = New Structure;
			Filter.Insert(Property, Value);
			
		Else
			
			Filter = New Array;
			AddFilterCondition(Filter, Property, ValueComparisonType, Value);
			
		EndIf;
		
	ElsIf TypeOf(Filter) = Type("Structure") Then
		
		NewFilter1 = New Array;
		
		For Each KeyAndValue In Filter Do
			
			AddFilterCondition(NewFilter1, KeyAndValue.Key, ComparisonType.Equal, KeyAndValue.Value);
			
		EndDo;
		
		AddFilterCondition(NewFilter1, Property, ValueComparisonType, Value);
		
		Filter = NewFilter1;
		
	ElsIf TypeOf(Filter) = Type("Array") Then
		
		Filter.Add(New Structure("Property, ComparisonType, Value", Property, ValueComparisonType, Value));
		
	Else
		
		Raise NStr("en = 'Invalid filter description.';");
		
	EndIf;
	
EndProcedure

Function CheckFilterConditions(Val ObjectToCheck, Val Filter = Undefined) Export
	
	If Filter = Undefined Or Filter.Count() = 0 Then
		Return True;
	EndIf;
	
	ConditionsMet = 0;
	
	For Each Condition In Filter Do
		
		If TypeOf(Condition) = Type("Structure") Then
			
			Field = Condition.Property;
			RequiredValue = Condition.Value;
			ValueComparisonType = Condition.ComparisonType;
			
		ElsIf TypeOf(Condition) = Type("KeyAndValue") Then
			
			Field = Condition.Key;
			RequiredValue = Condition.Value;
			ValueComparisonType = ComparisonType.Equal;
			
		Else
			
			Raise NStr("en = 'Invalid filter.';");
			
		EndIf;
		
		ValueToCheck = ObjectToCheck[Field];
		ConditionMet = CheckFilterCondition(ValueToCheck, ValueComparisonType, RequiredValue);
		
		If ConditionMet Then
			ConditionsMet = ConditionsMet + 1;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Return ConditionsMet = Filter.Count();
	
EndFunction

Function CheckFilterCondition(Val ValueToCheck, Val ValueComparisonType, Val Value)
	
	If ValueComparisonType = ComparisonType.Equal Then
		
		Return ValueToCheck = Value;
		
	ElsIf ValueComparisonType = ComparisonType.NotEqual Then
		
		Return ValueToCheck <> Value;
		
	ElsIf ValueComparisonType = ComparisonType.Greater Then
		
		Return ValueToCheck > Value;
		
	ElsIf ValueComparisonType = ComparisonType.GreaterOrEqual Then
		
		Return ValueToCheck >= Value;
		
	ElsIf ValueComparisonType = ComparisonType.Less Then
		
		Return ValueToCheck < Value;
		
	ElsIf ValueComparisonType = ComparisonType.LessOrEqual Then
		
		Return ValueToCheck <= Value;
		
	ElsIf ValueComparisonType = ComparisonType.InList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(ValueToCheck) <> Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(ValueToCheck) <> Undefined;
			
		EndIf;
		
	ElsIf ValueComparisonType = ComparisonType.NotInList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(ValueToCheck) = Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(ValueToCheck) = Undefined;
			
		EndIf;
		
	ElsIf ValueComparisonType = ComparisonType.Interval Then
		
		Return ValueToCheck > Value.From1 And ValueToCheck < Value.On;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingBounds Then
		
		Return ValueToCheck >= Value.From1 And ValueToCheck <= Value.On;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingLowerBound Then
		
		Return ValueToCheck >= Value.From1 And ValueToCheck < Value.On;
		
	ElsIf ValueComparisonType = ComparisonType.IntervalIncludingUpperBound Then
		
		Return ValueToCheck > Value.From1 And ValueToCheck <= Value.On;
		
	EndIf;
	
EndFunction

Function AdministrationManager(Val AdministrationParameters)
	
	If AdministrationParameters.AttachmentType = "COM" Then
		
		Return ClusterAdministrationCOMClientServer;
		
	ElsIf AdministrationParameters.AttachmentType = "RAS" Then
		
		Return ClusterAdministrationRASClientServer;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Unknown connection type: %1.';"), AdministrationParameters.AttachmentType);
		
	EndIf;
	
EndFunction

Function DateEmpty() Export
	
	Return Date(1, 1, 1, 0, 0, 0);
	
EndFunction

#EndRegion


