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

#Region ProgramInterfaceParameterConstructors

// Parameters of connection to the server cluster being administered.
//
// Returns:
//   Structure:
//     * AttachmentType - String - possible values:
//                  "COM" - when connecting to the server agent using the V8*.ComConnector COM object;
//                  "RAS" - when connecting the administration server (ras) using the console
//                  client of the administration server (rac);
//     * ServerAgentAddress - String - network address of the server agent (only for ConnectionType = "COM").
//     * ServerAgentPort - Number - network port of the server agent (only for ConnectionType = "COM").
//                  Usually, 1540;
//     * AdministrationServerAddress - String - network address of the ras administration server (only
//                  with ConnectionType = "RAS").
//     * AdministrationServerPort - Number - network port of the ras administration server (only with
//                  ConnectionType = "RAS"). Usually, 1545.
//     * ClusterPort - Number - network port of the cluster manager. Usually, 1541.
//     * ClusterAdministratorName - String - cluster administrator account name (if the list of administrators
//                  is not specified for the cluster, the value is set to empty string);
//     * ClusterAdministratorPassword - String - cluster administrator account password. If
//                  the list of administrators is not specified for the cluster or the administrator account password is not set,
//                  the value is a blank string.
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

// Parameters of connection to the cluster infobase being administered.
//
// Returns: 
//  Structure:
//    * NameInCluster - String - name of the infobase in cluster server.
//    * InfobaseAdministratorName - String - name of the infobase user with administrative
//                  rights (if the list of infobase users is not set, the value is set
//                  to empty string).
//    * InfobaseAdministratorPassword - String - password of the infobase user
//                  with administrative rights (if the list of infobase users is not set
//                  or the infobase user password is not set, the value is set to empty string).
//
Function ClusterInfobaseAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("NameInCluster", "");
	Result.Insert("InfobaseAdministratorName", "");
	Result.Insert("InfobaseAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Checks whether administration parameters are filled correctly.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//  CheckClusterAdministrationParameters - Boolean - Flag indicating whether a check of cluster administration parameters is required. 
//                  
//  CheckInfobaseAdministrationParameters - Boolean - Flag indicating whether a check of cluster administration parameters is required.
//                  
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

// Infobase session and scheduled job lock properties.
//
// Returns: 
//   Structure:
//     * SessionsLock - Boolean - Flag indicating whether new infobase sessions are locked.
//     * DateFrom1 - Date - a moment of time after which new infobase sessions are prohibited.
//     * DateTo - Date - a moment of time after which new infobase sessions are allowed.
//     * Message - String - the message displayed to the user when a new session is being established
//                            with the locked infobase.
//     * KeyCode - String - a pass code that allows to connect to a locked infobase.
//     * LockScheduledJobs - Boolean - flag that shows whether infobase scheduled jobs must be locked.
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

// Returns the current state of infobase session locks and scheduled job locks.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   See ClusterAdministration.SessionAndScheduleJobLockProperties
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

// Sets the state of infobase session locks and scheduled job locks.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//  SessionAndJobLockProperties - See ClusterAdministration.SessionAndScheduleJobLockProperties
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

// Unlocks infobase sessions and scheduled jobs.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
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

// Returns the current state of scheduled job locks for the infobase.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//  Boolean - the lock is set.
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

// Sets the state of infobase scheduled job locks.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//  IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
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

// Infobase session properties.
//
// Returns: 
//   Structure:
//     * Number - Number - session number. The number is unique across the infobase sessions,
//     * UserName - String - Infobase user's name,
//     * ClientComputerName - String - name or network address of the computer that established
//          the session with the infobase,
//     * ClientApplicationID - String - ID of the application that set up the session.
//          Possible values - see details of the global context functionApplicationPresentation(),
//     * LanguageID - String - Interface language ID,
//     * SessionCreationTime - Date - session setup time,
//     * LatestSessionActivityTime - Date - the moment of last session activity,
//     * Block - Number - a number of the session that resulted in managed transactional
//          lock wait if the session sets managed transactional locks
//          and waits for locks set by another session to be disabled. Otherwise, the value is 0,
//     * DBMSLock - Number - a number of the session that caused transactional
//          lock wait if the session performs a DBMS call and waits for a transactional
//          lock set by another session to be disabled. Otherwise, the value is 0,
//     * Passed - Number - volume of data passed between the 1C:Enterprise server and the current session
//          client application since the session start, in bytes,
//     * PassedIn5Minutes - Number - volume of data passed between the 1C:Enterprise server and the current session client
//          application in the last 5 minutes, in bytes,
//     * ServerCalls - Number - a number of the 1C:Enterprise server calls made by the current session since
//          the session started,
//     * ServerCallsIn5Minutes - Number - a number of the 1C:Enterprise server calls made by the current session
//          in the last 5 minutes,
//     * ServerCallDurations - Number - total 1C:Enterprise server call time made by
//          the current session since the session start, in seconds,
//     * CurrentServerCallDuration - Number - time interval in milliseconds since the 1C:Enterprise server call
//          start. If there is no server call, the value is 0,
//     * ServerCallDurationsIn5Minutes - Number - total time of 1C:Enterprise server calls made by
//          the current session in the last 5 minutes, in milliseconds,
//     * ExchangedWithDBMS - Number - volume of data passed and received from DBMS on behalf of the current session
//          since the session start, in bytes,
//     * ExchangedWithDBMSIn5Minutes - Number - volume of data passed and received from DBMS on behalf of the current session
//          in the last 5 minutes, in bytes,
//     * DBMSCallDuration - Number - total time spent on executing DBMS queries made on behalf of the current session since the session
//          start, in milliseconds,
//     * CurrentDBMSCallDuration - Number - time interval since the current DBMS query
//          execution start, in milliseconds. If there is no query, the value is 0,
//     * DBMSCallDurationsIn5Minutes - Number - total time spent on executing DBMS queries made on behalf of the current session
//          in the last 5 minutes (in milliseconds).
//     * DBMSConnection - String - DBMS connection number in the terms of DBMS if when the session
//          list is retrieved, the DBMS query is executed, a transaction is opened, or temporary tables are defined (DBMS connection
//          is seized). If the DBMS session is not seized, the value is a blank string,
//     * DBMSConnectionTime - Number - the period since the DBMS connection capture, in milliseconds. If the
//          DBMS session is not seized - the value is 0,
//     * DBMSConnectionSeizeTime - Date - Time of the last DBMS connection capture.
//          
//     * IConnectionShort - Structure
//                          - Undefined - Contains the details of the connection assigned to the session. 
//                  For field details, See ClusterAdministration.ConnectionDetailsProperties.
//                                           Otherwise, Undefined.
//     * Sleep - Boolean - the session is in the sleep mode.
//     * TerminateIn - Number - a time interval in seconds, after which the session in sleep mode is terminated.
//     * SleepIn - Number - a time interval in seconds, after which an inactive session is put into sleep
//                              mode.
//     * ReadFromDisk - Number - contains the amount of data in bytes read from the disk by the session since it has started.
//     * ReadFromDiskInCurrentCall - Number - contains the amount of data in bytes read from the disk since 
//                  the start of the current call.
//     * ReadFromDiskIn5Minutes - Number - contains the amount of data in bytes read from the disk during the last
//                                         5 minutes.
//     * ILicenseInfo - Structure
//                - Undefined - Contains information on the client license that is used by the current session,
//                  field details, See ClusterAdministration.LicenseProperties. 
//                  Undefined if the session does not use a license.
//     * OccupiedMemory - Number - contains memory volume in bytes used in the process of calls since the session start.
//     * OccupiedMemoryInCurrentCall - Number - contains memory volume in bytes used since the start of the current call. 
//                  If the call is not currently running, the value is 0.
//     * OccupiedMemoryIn5Minutes - Number - contains memory volume in bytes used in the process of calls during the last 5 minutes.
//     * WrittenOnDisk - Number - contains the amount of data in bytes written on the disk by the session since it has started.
//     * WrittenOnDiskInCurrentCall - Number - contains the amount of data in bytes written on the disk since the start
//                  of the current call.
//     * WrittenOnDiskIn5Minutes - Number - contains the amount of data in bytes written on the disk the disk during the last 5
//                                        minutes.
//     * IWorkingProcessInfo - Structure
//                      - Undefined - Contains a working process with which the connection is established if 
//                  the session is assigned to the connection, field details  See ClusterAdministration.WorkingProcessProperties. 
//                  Else - Undefined. 
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
	Result.Insert("IConnectionShort");
	Result.Insert("Sleep");
	Result.Insert("TerminateIn");
	Result.Insert("SleepIn");
	Result.Insert("ReadFromDisk");
	Result.Insert("ReadFromDiskInCurrentCall");
	Result.Insert("ReadFromDiskIn5Minutes");
	Result.Insert("ILicenseInfo");
	Result.Insert("OccupiedMemory");
	Result.Insert("OccupiedMemoryInCurrentCall");
	Result.Insert("OccupiedMemoryIn5Minutes");
	Result.Insert("WrittenOnDisk");
	Result.Insert("WrittenOnDiskInCurrentCall");
	Result.Insert("WrittenOnDiskIn5Minutes");
	Result.Insert("IWorkingProcessInfo");
	
	Return Result;
	
EndFunction

// License properties.
//
// Returns: 
//   Structure:
//     * FileName - String - Contains full name of the software license file being used. 
//     * FullPresentation - String - Contains localized string presentation of the license, as in property
//                  License of the session property dialog or properties of cluster console active process
//     * BriefPresentation - String - Contains localized string presentation of the license, as in column
//                  License of the list of sessions or active processes.
//     * IssuedByServer - Boolean - True - the license is received by the 1C:Enterprise server and issued to the client application.
//                  False - the license is received by the client application.
//     * LisenceType - Number - contains license type: 
//                  0 - platform software license; 
//                  1 is hardware license (software security key).
//     * MaxUsersForSet - Number - contains the maximum number of users allowed for this kit if the platform 
//                  software license is used. Otherwise, it matches
//                  with the MaxUsersCur property value.
//     * MaxUsersInKey - Number - contains the maximum number of users 
//                  in the used software security key or in the used program license file.
//     * LicenseIsReceivedViaAladdinLicenseManager - Boolean - True if the software security key for the hardware license is network,
//                  the license is obtained through the Aladdin License Manager,
//                  False otherwise.
//     * ProcessAddress - String - contains an address of the server where the process that got a license is running.
//     * ProcessID - String - contains an ID of the process that got a license assigned to it
//                  by the operating system.
//     * ProcessPort - Number - contains an IP port number of the server process that got a license.
//     * KeySeries - String - contains a series of a software security key for a hardware license or a kit registration
//                  number for a platform software license.
//
Function LicenseProperties() Export
	
	Result = New Structure();
	
	Result.Insert("FileName");
	Result.Insert("FullPresentation");
	Result.Insert("BriefPresentation");
	Result.Insert("IssuedByServer");
	Result.Insert("LisenceType");
	Result.Insert("MaxUsersForSet");
	Result.Insert("MaxUsersInKey");
	Result.Insert("LicenseIsReceivedViaAladdinLicenseManager");
	Result.Insert("ProcessAddress");
	Result.Insert("ProcessID");
	Result.Insert("ProcessPort");
	Result.Insert("KeySeries");
	
	Return Result;
	
EndFunction

// Connection details properties.
//
// Returns: 
//   Structure:
//     * ApplicationName - String - contains name of an application that established connection with 1C:Enterprise server farm.
//     * Block - Number - contains an ID of the connection that locks operation of this connection (in the transaction 
//                  lock service).
//     * ConnectionEstablishingTime - Date - contains the time when the connection was established.
//     * Number - Number - contains a connection ID. Allows you to distinguish between different connections established
//                  by the same application from the same client computer
//     * ClientComputerName - String - contains name of the user computer that established the connection.
//     * SessionNumber - Number - contains the session number if a session is assigned to it, 0 otherwise.
//     * IWorkingProcessInfo - Structure - contains object interface with server process details to which
//                  the connection is set.
//
Function ConnectionDetailsProperties() Export
	
	Result = New Structure();
	
	Result.Insert("ApplicationName");
	Result.Insert("Block");
	Result.Insert("ConnectionEstablishingTime");
	Result.Insert("Number");
	Result.Insert("ClientComputerName");
	Result.Insert("SessionNumber");
	Result.Insert("IWorkingProcessInfo");
	
	Return Result;
	
EndFunction

// active process properties.
//
// Returns:
//   Structure:
//     * AvailablePerformance - Number - average available performance over the last 5 minutes. It is determined
//                  by the reaction time of the active process to the reference query. According to the available 
//                  performance, the server cluster decides on the distribution of clients between working
//                  processes.
//     * SpentByTheClient - Number - shows the average time spent by the active process on callbacks of client application
//                  methods when performing one client call
//     * ServerReaction - Number - shows the average service time spent by the active process on one client call.
//                  It consists of: property values SpentByServer, SpentByDBMS, SpentByLocksManager, and
//                  SpentByClient.
//     * SpentByDBMS - Number - shows the average time spent by the active process to call the server without
//                  data when performing one client call.
//     * SpentByTheLockManager - Number - shows the average time of addressing the lock manager.
//     * SpentByTheServer - Number - shows the average time spent by the active process itself to execute
//                  single client call.
//     * ClientStreams - Number - shows the average number of client streams executed by the active process of cluster.
//     * Capacity - Number - relative process performance. The value can be 
//                  in the range from 1 to 1000. It is used to select the active process
//                  for connecting the next client. Clients are distributed between active processes in proportion
//                  to the active processes performance.
//     * Connections - Number - the number of active process connections to user applications.
//     * ComputerName - String - Contains the name or IP address of a computer to start the active process.
//     * Enabled - Boolean - set by the cluster if necessary to start or stop the active process.
//                  True - the process must be started and will be started when possible. 
//                  False - the process must be stopped and will be stopped after all users disconnect
//                  or after the time specified by the cluster settings has expired.
//     * Port - Number - Contains the number of main IP port of the active process. This port is selected dynamically at the start
//                  of the active process from the port ranges defined for the matching active server.
//     * ExceedingTheCriticalValue - Number - Contains the time during which the virtual memory
//                  of the active process exceeds the critical value set for the cluster, in seconds.
//     * OccupiedMemory - Number - Contains the size of virtual memory occupied by the active process, in kilobytes.
//     * Id - String - active active process ID in terms of the operating system.
//     * Started2 - Number - a active process status.
//                  0 - the process is inactive (not imported in memory or cannot execute client queries); 
//                  1 - the process is active (it works). 
//     * CallsCountByWhichTheStatisticsIsCalculated - Number - the number of calls by which statistics is calculated.
//     * StartedAt - Date - Contains the moment of the active process startup. If the process is not started up, the date is blank.
//     * Use - Number - determines usage of a active process by the cluster. It is set by the administrator. 
//                  Possible values: 
//                     0 - do not use, the process must not be started up; 
//                     1 - use, the process must be started up; 
//                     2 - use as a reserve, the process must be started up only if it is impossible to start up
//                         the process with value 1 of this property.
//     * ILicenseInfo - Structure
//                - Undefined - contains information about server license used by the working process. 
//                  Undefined - the working process does not use server license.
//
Function WorkingProcessProperties() Export
	
	Result = New Structure();
	
	Result.Insert("AvailablePerformance");
	Result.Insert("SpentByTheClient");
	Result.Insert("ServerReaction");
	Result.Insert("SpentByDBMS");
	Result.Insert("SpentByTheLockManager");
	Result.Insert("SpentByTheServer");
	Result.Insert("ClientStreams");
	Result.Insert("Capacity");
	Result.Insert("Connections");
	Result.Insert("ComputerName");
	Result.Insert("Enabled");
	Result.Insert("Port");
	Result.Insert("ExceedingTheCriticalValue");
	Result.Insert("OccupiedMemory");
	Result.Insert("Id");
	Result.Insert("Started2");
	Result.Insert("CallsCountByWhichTheStatisticsIsCalculated");
	Result.Insert("StartedAt");
	Result.Insert("Use");
	Result.Insert("ILicenseInfo");
	
	Return Result;
	
EndFunction

// Returns details of infobase sessions.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
// If a structure is specified in the Filter parameter (See ClusterAdministration.SessionsFilter) 
// ,
// the comparison type is "equal to".
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - Array of See ClusterAdministration.SessionsFilter
//          - See ClusterAdministration.SessionsFilter
//
// Returns: 
//   Array of See ClusterAdministration.SessionProperties
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, 
	Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Deletes infobase sessions according to the filter.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
// If a structure is specified in the Filter parameter (See ClusterAdministration.SessionsFilter) 
// ,
// the comparison type is "equal to".
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - Array of See ClusterAdministration.SessionsFilter
//          - See ClusterAdministration.SessionsFilter
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, 
	Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteInfobaseSessions(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

// Session filter properties.
// For use in the InfobaseSessions, DeleteInfobaseSessions and similar functions. 
//
// Returns:
//   Structure:
//     * Property - String - property name to be used in the filter. 
//                  For valid values, see return value of the ClusterAdministration.SessionProperties function.
//     * ComparisonType - ComparisonType - the type of comparing the session values and the filter values. 
//                  The following values are available:
//                  ComparisonType.Equal,
//                  ComparisonType.NotEqual,
//                  ComparisonType.Greater (for numeric values only),
//                  ComparisonType.GreaterOrEqual (for numeric values only),
//                  ComparisonType.Less (for numeric values only),
//                  ComparisonType.LessOrEqual (for numeric values only),
//                  ComparisonType.InList,
//                  ComparisonType.NotInList,
//                  ComparisonType.Interval (for numeric values only),
//                  ComparisonType.IntervalIncludingBounds (for numeric values only),
//                  ComparisonType.IntervalIncludingLowerBound (for numeric values only),
//                  ComparisonType.IntervalIncludingUpperBound (for numeric values only).
//     * Value - Number
//                - String
//                - Date
//                - Boolean
//                - ValueList
//                - Array
//                - Structure - the value the matching session property value
//               is compared with. For ComparisonType.InList and ComparisonType.NotInList,
//               the passed values are ValueList or Array that contain the set of values
//               to compare to. For ComparisonType.Interval, ComparisonType.IntervalIncludingBounds,
//               ComparisonType.IntervalIncludingLowerBound, and ComparisonType.IntervalIncludingUpperBound, the passed
//               value contains a structure with the From and To fields that forms an interval
//               to be compared to.
//
Function SessionsFilter() Export
	
	Result = New Structure();
	
	Result.Insert("Property");
	Result.Insert("ComparisonType", ComparisonType.Equal);
	Result.Insert("Value");
	
	Return Result;
	
EndFunction

#EndRegion

#Region InfobaseConnections

// Infobase connection properties.
//
// Returns: 
//   Structure:
//     * Number - Number - a number of infobase connection.
//     * UserName - String - a name of the 1C:Enterprise user connected to the infobase.
//     * ClientComputerName - String - a name of the computer that established the connection.
//     * ClientApplicationID - String - an ID of the application that set up the connection.
//                  Possible values - see details of the global context functionApplicationPresentation(),
//     * ConnectionEstablishingTime - Date - the time of connection establishment.
//     * InfobaseConnectionMode - Number - the infobase connection mode (0 
//                  if shared, 1 if exclusive),
//     * DataBaseConnectionMode - Number - database connection mode (0 if no connection,
//                  1 - shared, 2 - exclusive).
//     * DBMSLock - Number - an ID of the connection that locks the current connection in the DBMS.
//     * Passed - Number - a volume of data that the connection sent and received.
//     * PassedIn5Minutes - Number - the volume of data sent and received by the connection in the last 5 minutes.
//     * ServerCalls - Number - the number of server calls.
//     * ServerCallsIn5Minutes - Number - the number of server calls in the last 5 minutes.
//     * ExchangedWithDBMS - Number - the data volume passed between the 1C:Enterprise server and the database server
//                  since the connection was established,
//     * ExchangedWithDBMSIn5Minutes - Number - the volume of data passed between the 1C:Enterprise server and the database
//                  server in the last 5 minutes,
//     * DBMSConnection - String - the DBMS connection process ID if the connection is contacting a DBMS server when
//                  the list is requested. Otherwise, the value is
//                  a blank string. The ID is returned in the DBMS server terms.
//     * DBMSTime - Number - the DBMS server call duration in seconds if the connection is contacting a DBMS server when
//                  the list is requested. Otherwise,
//                  the value is 0.
//     * DBMSConnectionSeizeTime - Date - the moment of the last DBMS server connection capture.
//     * ServerCallDurations - Number - the duration of all connection server calls.
//     * DBMSCallDuration - Number - the duration of all DBMS calls the connection initiated.
//     * CurrentServerCallDuration - Number - the duration of the current server call.
//     * CurrentDBMSCallDuration - Number - the duration of the current DBMS server call.
//     * ServerCallDurationsIn5Minutes - Number - the duration of server calls in the last 5 minutes.
//     * DBMSCallDurationsIn5Minutes - Number - the duration of DBMS server calls in the last 5 minutes.
//     * ReadFromDisk - Number - contains the amount of data in bytes read from the disk by the session since it has started.
//     * ReadFromDiskInCurrentCall - Number - contains the amount of data in bytes read from the disk since
//                  the start of the current call.
//     * ReadFromDiskIn5Minutes - Number - contains the amount of data in bytes read from the disk during 
//                  the last 5 minutes.
//     * OccupiedMemory - Number - contains memory volume in bytes used in the process of calls since the session start.
//     * OccupiedMemoryInCurrentCall - Number - contains memory volume in bytes used since the start of the current
//                  call. If the call is not currently running, the value is 0.
//     * OccupiedMemoryIn5Minutes - Number - contains memory volume in bytes used in the process of calls during the last 5 minutes.
//     * WrittenOnDisk - Number - contains the amount of data in bytes written on the disk by the session since it has started.
//     * WrittenOnDiskInCurrentCall - Number - contains the amount of data in bytes written on the disk since the start
//                  of the current call.
//     * WrittenOnDiskIn5Minutes - Number - contains the amount of data in bytes written on the disk the disk during
//                  the last 5 minutes.
//     * ControlIsOnServer - Number - Indicates if management is on the server (0 - it is not on the server, otherwise 1).
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
	Result.Insert("ReadFromDisk");
	Result.Insert("ReadFromDiskInCurrentCall");
	Result.Insert("ReadFromDiskIn5Minutes");
	Result.Insert("OccupiedMemory");
	Result.Insert("OccupiedMemoryInCurrentCall");
	Result.Insert("OccupiedMemoryIn5Minutes");
	Result.Insert("WrittenOnDisk");
	Result.Insert("WrittenOnDiskInCurrentCall");
	Result.Insert("WrittenOnDiskIn5Minutes");
	Result.Insert("ControlIsOnServer");
	
	Return Result;
	
EndFunction

// Returns details of infobase connections.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
// If a structure is specified in the Filter parameter, (See ClusterAdministration.SessionsFilter) 
// 
// the comparison type is "equal to".
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
Function InfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, 
	Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndFunction

// Terminates infobase connections according to filter.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
// If a structure is specified in the Filter parameter (See ClusterAdministration.JoinsFilters) 
// , then
// the comparison is always performed for equality.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - Array of See ClusterAdministration.JoinsFilters
//          - See ClusterAdministration.JoinsFilters
//
Procedure TerminateInfobaseConnections(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, 
	Val Filter = Undefined) Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.TerminateInfobaseConnections(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		Filter);
	
EndProcedure

// Connection filter properties.
// For use in the InfobaseConnections, TerminateInfobaseConnections and similar functions. 
//
// Returns:
//   Structure:
//     * Property - String - the property name to filter by. 
//                  For possible values, see return value of the ClusterAdministration.ConnectionProperties function.
//     * ComparisonType - ComparisonType - the type of comparing the session values and the filter values. 
//                  The following values are available:
//                  ComparisonType.Equal,
//                  ComparisonType.NotEqual,
//                  ComparisonType.Greater (for numeric values only),
//                  ComparisonType.GreaterOrEqual (for numeric values only),
//                  ComparisonType.Less (for numeric values only),
//                  ComparisonType.LessOrEqual (for numeric values only),
//                  ComparisonType.InList,
//                  ComparisonType.NotInList,
//                  ComparisonType.Interval (for numeric values only),
//                  ComparisonType.IntervalIncludingBounds (for numeric values only),
//                  ComparisonType.IntervalIncludingLowerBound (for numeric values only),
//                  ComparisonType.IntervalIncludingUpperBound (for numeric values only).
//     * Value - Number
//                - String
//                - Date
//                - Boolean
//                - ValueList
//                - Array
//                - Structure - the value the matching session property value
//               is compared with. For ComparisonType.InList and ComparisonType.NotInList,
//               the passed values are ValueList or Array that contain the set of values
//               to compare to. For ComparisonType.Interval, ComparisonType.IntervalIncludingBounds,
//               ComparisonType.IntervalIncludingLowerBound, and ComparisonType.IntervalIncludingUpperBound, the passed
//               value contains a structure with the From and To fields that forms an interval
//               to be compared to.
//
Function JoinsFilters() Export
	
	Result = New Structure();
	
	Result.Insert("Property");
	Result.Insert("ComparisonType", ComparisonType.Equal);
	Result.Insert("Value");
	
	Return Result;
	
EndFunction

#EndRegion

#Region SecurityProfiles

// Returns the name of a security profile assigned to the infobase.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String - name of the security profile set for the infobase. If the infobase is not assigned
//            with a security profile, returns an empty string.
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

// Returns the name of the security profile that was set for the infobase as a
// security profile of the safe mode.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String - name of the security profile set for the infobase as the safe mode security
//            profile. If the infobase is not assigned with a security profile, returns an empty string.
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

// Assigns a security profile to an infobase.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the security profile is 
//                         disabled for the infobase.
//
Procedure SetInfobaseSecurityProfile(Val ClusterAdministrationParameters, Val IBAdministrationParameters = Undefined, 
	Val ProfileName = "") Export
	
	If IBAdministrationParameters = Undefined Then
		IBAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSecurityProfile(
		ClusterAdministrationParameters,
		IBAdministrationParameters,
		ProfileName);
	
EndProcedure

// Assigns a security profile of the safe mode to an infobase.
//
// The IBAdministrationParameters parameter can be skipped if the same fields are specified 
// in the ClusterAdministrationParameters parameter.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   IBAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   ProfileName - String - Security profile name. If the passed string is empty, the safe mode security profile is 
//                         disabled for the infobase.
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

// Checks whether a security profile exists in the server cluster.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters.
//   ProfileName - String - name of the security profile whose existence is checked.
//
// Returns:
//   Boolean
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfileExists(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Security profile properties.
//
// Returns: 
//   Structure:
//     * Name - String - a security profile name,
//     * LongDesc - String - details of the security profile,
//     * SafeModeProfile - Boolean - flag that shows whether the security profile
//                  can be used as a security profile of the safe mode (both when the profile is specified
//                  for the infobase and when calling.
//                  SetSafeMode(<Profile name>) is called from the configuration code.
//     * FullAccessToPrivilegedMode - Boolean - Indicates whether the privileged
//                  mode can be set from the safe mode of the security profile.
//     * FullAccessToCryptoFunctions - Boolean - determines the permission to use cryptographic functionality
//                  (signature, signature verification, encryption, decryption, operations with the certificate storage,
//                  certificate verification, certificate extraction from the signature) when working on the server.
//                  Cryptography functions are not locked on the client. 
//                  True - the execution is allowed. False - the execution is prohibited.
//     * FullAccessToAllModulesExtension - Boolean - determines if all modules are allowed to be modified in the configuration
//                  extension:
//                     True - extension of all modules is allowed.
//                     False - only modules from the allowed list are allowed to extend.
//     * ModulesAvailableForExtension - String - used when extension of all modules is not allowed.
//                  Contains a list of full names of configuration objects or modules whose extension is allowed, 
//                  separated by ";". Specifying full configuration object name allows to extend all object
//                  modules. Specifying full configuration object name allows to extend a specific module.
//     * ModulesNotAvailableForExtension - String - used when extension of all modules is allowed.
//                  Contains a list of full names of configuration objects or modules whose extension is not allowed,
//                  separated by ";". Specifying full configuration object name prohibits to extend all object
//                  modules.
//     * FullAccessToAccessRightsExtension - Boolean - determines whether it is allowed to elevate rights to configuration objects
//                  by extensions restricted by the security profile: 
//                     True - right elevation is allowed. 
//                     False - right elevation is prohibited. 
//                  If a list of extensible configuration roles is specified, right elevation is allowed if at least one
//                  role from the list includes the required right.
//     * AccessRightsExtensionLimitingRoles - String - contains a list of role names that affect the change of access rights
//                  from the extension. When changing the list of roles, changes in the composition of roles are considered only after
//                  restarting current sessions and for new sessions.
//     * FileSystemFullAccess - Boolean - the flag that shows whether there are file system access
//                  restrictions. If the value is False, infobase users can access only file
//                  system directories specified in the VirtualDirectories property.
//     * COMObjectFullAccess - Boolean - COM object access restriction flag.
//                  If False, infobase users can access only COM classes specified in the COMClasses property.
//                  
//     * AddInFullAccess - Boolean - the flag that defines whether there are add-in
//                  access restrictions. If the value is False, infobase users can access only add-ins
//                  specified in the AddIns property.
//     * ExternalModuleFullAccess - Boolean - flag that shows whether there are external 
//                  module (external reports and data processors, Execute() and Evaluate() calls in the unsafe mode) access restrictions.
//                  If the value is False, infobase users can use in the unsafe
//                  mode only external modules specified in the ExternalModules property.
//     * FullOperatingSystemApplicationAccess - Boolean - the flag that shows whether there are operating
//                  system application access restrictions. If the value is False, infobase
//                  users can use operating system applications
//                  specified in the OSApplications property.
//     * InternetResourcesFullAccess - Boolean - Indicates if there are restrictions to access
//                  Internet resources. If the value is False, infobase users can only
//                  use Internet resources specified in the InternetResources property.
//     * VirtualDirectories - Array of See ClusterAdministration.VirtualDirectoryProperties
//     * COMClasses - Array of See ClusterAdministration.COMClassProperties
//     * AddIns - Array of See ClusterAdministration.AddInProperties
//     * ExternalModules - Array of See ClusterAdministration.ExternalModuleProperties
//     * OSApplications - Array of See ClusterAdministration.OSApplicationProperties
//     * InternetResources - Array of See ClusterAdministration.InternetResourceProperties
//
Function SecurityProfileProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name", "");
	Result.Insert("LongDesc", "");
	Result.Insert("SafeModeProfile", False);
	Result.Insert("FullAccessToPrivilegedMode", False);
	Result.Insert("FullAccessToCryptoFunctions", False);
	
	Result.Insert("FullAccessToAllModulesExtension", False);
	Result.Insert("ModulesAvailableForExtension", "");
	Result.Insert("ModulesNotAvailableForExtension", "");
	
	Result.Insert("FullAccessToAccessRightsExtension", False);
	Result.Insert("AccessRightsExtensionLimitingRoles", "");
		
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

// Virtual directory properties to which access is granted.
//
// Returns: 
//    Structure:
//     * LogicalURL - String - the logical URL of a directory.
//     * PhysicalURL - String - the physical URL of the server directory where virtual directory data is stored.
//     * LongDesc - String - virtual directory details.
//     * DataReader - Boolean - Flag indicating whether virtual directory data reading is allowed.
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

// COM class properties to which access is granted.
//
// Returns: 
//    Structure:
//     * Name - String - the name of a COM class that is used as a search key.
//     * LongDesc - String - the COM class details.
//     * FileMoniker - String - the file name used to create an object with 
//                  the GetCOMObject global context method. The object second parameter has a blank value.
//     * CLSID - String - the COM class ID presentation in the Windows system registry format
//                  without curly brackets, which the operating system uses to create the COM class.
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

// Add-in properties to which access is granted.
//
// Returns: 
//    Structure:
//     * Name - String - the name of the add-in. Used as a search key.
//     * LongDesc - String - the add-in details.
//     * HashSum - String - contains the checksum of the allowed add-in, calculated with SHA-1 algorithm
//                  and converted to a base64 string.
//
Function AddInProperties() Export
	
	Result = New Structure();
	Result.Insert("Name");
	Result.Insert("LongDesc");
	Result.Insert("HashSum");
	Result.Insert("HashSum"); // ACC:1036 for backward compatibility.
	Return Result;
	
EndFunction

// External module properties to which access is granted.
//
// Returns: 
//    Structure:
//     * Name - String - name of the external module that is used as a search key.
//     * LongDesc - String - external module details.
//     * HashSum - String - contains the checksum of the allowed external module, calculated with SHA-1 algorithm
//                  and converted to a base64 string.
//
Function ExternalModuleProperties() Export
	
	Result = New Structure();
	Result.Insert("Name");
	Result.Insert("LongDesc");
	Result.Insert("HashSum");
	Result.Insert("HashSum"); // ACC:1036 for backward compatibility.
	Return Result;
	
EndFunction

// Operating system application properties to which access is granted.
//
// Returns: 
//    Structure:
//     * Name - String - name of the operating system application that is used as a search key.
//     * LongDesc - String - the operating system application details.
//     * CommandLinePattern - String - application command line pattern, which consists of space-separated
//                  pattern words.
//
Function OSApplicationProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("LongDesc");
	
	Result.Insert("CommandLinePattern");
	
	Return Result;
	
EndFunction

// Internet resource properties to which access is granted.
//
// Returns: 
//    Structure:
//     * Name - String - name of the Internet resource that is used as a search key.
//     * LongDesc - String - Internet resource details.
//     * Protocol - String - an allowed network protocol. Possible values:
//          HTTP,
//          HTTPS,
//          FTP,
//          FTPS,
//          POP3,
//          SMTP,
//          IMAP.
//     * Address - String - a network address with no protocol and port.
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
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Creates a security profile on the basis of the passed description.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.CreateSecurityProfile(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Sets properties for a security profile on the basis of the passed description.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   SecurityProfileProperties - See ClusterAdministration.SecurityProfileProperties
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetSecurityProfileProperties(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Deletes a security profile.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   ProfileName - String - Security profile name.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteSecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndProcedure

#EndRegion

#Region Infobases

// Returns an internal infobase ID.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   InfobaseAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//
// Returns: 
//   String
//
Function InfoBaseID(Val ClusterID, Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfoBaseID(
		ClusterID,
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
EndFunction

// Returns infobase descriptions
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - Infobase filter criteria.
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

// Returns an internal ID of a server cluster.
//
// Parameters:
//  ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters.
//
// Returns:
//   String
//
Function ClusterID(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.ClusterID(ClusterAdministrationParameters);
	
EndFunction

// Returns server cluster descriptions.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - server cluster filtering criteria.
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

// Returns descriptions of active processes.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - active process filtering criteria.
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

// Returns descriptions of active servers.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   Filter - Structure - active server filtering criteria.
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

// Returns details of infobase sessions.
//
// If a structure is specified in the Filter parameter,  (See ClusterAdministration.SessionsFilter) 
// 
// the comparison is always performed for equality.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   InfoBaseID - String - Internal infobase ID.
//   Filter - See ClusterAdministration.SessionsFilter
//          - Array of See ClusterAdministration.SessionsFilter
//   UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns: 
//   - Array of See ClusterAdministration.SessionProperties
//   - Array of Map - session properties in the rac utility notation if UseDictionary = False.
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

// Returns descriptions of infobase connections.
//
// Parameters:
//   ClusterID - String - Internal server cluster ID.
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//   InfoBaseID - String - Internal infobase ID.
//   InfobaseAdministrationParameters - See ClusterAdministration.ClusterInfobaseAdministrationParameters
//   Filter - See ClusterAdministration.JoinsFilters
//          - Array of See ClusterAdministration.JoinsFilters
//   UseDictionary - Boolean - If True, the return value is generated using a dictionary.
//
// Returns: 
//   - Array of See ClusterAdministration.ConnectionProperties
//   - Array of Map - connection properties in the rac utility notation if UseDictionary = False.
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

// Returns path to the console client of the administration server.
//
// Parameters:
//   ClusterAdministrationParameters - See ClusterAdministration.ClusterAdministrationParameters
//
// Returns:
//   String
//
Function PathToAdministrationServerClient(Val ClusterAdministrationParameters) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.PathToAdministrationServerClient();
	
EndFunction

#EndRegion

#Region Private

Procedure AddFilterCondition(Filter, Val Property, Val ValueComparisonType, Val Value) Export
	
	If Filter = Undefined Then
		
		If ValueComparisonType = ComparisonType.Equal Then
			
			Filter = New Structure;
			Filter.Insert(Property, Value);
			
		Else
			
			NewFilerItem = New Structure("Property, ComparisonType, Value", Property, ValueComparisonType, Value);
			
			Filter = New Array;
			Filter.Add(NewFilerItem);
			
		EndIf;
		
	ElsIf TypeOf(Filter) = Type("Structure") Then
		
		ExistingFilterItem = New Structure("Property, ComparisonType, Value", Filter.Key, ComparisonType.Equal, Filter.Value);
		NewFilerItem = New Structure("Property, ComparisonType, Value", Property, ValueComparisonType, Value);
		
		Filter = New Array;
		Filter.Add(ExistingFilterItem);
		Filter.Add(NewFilerItem);
		
	ElsIf TypeOf(Filter) = Type("Array") Then
		
		Filter.Add(New Structure("Property, ComparisonType, Value", Property, ValueComparisonType, Value));
		
	Else
		
		Raise NStr("en = 'Unexpected type of the Filter parameter. Expected type is <Structure> or <Array>.';");
		
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
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invalid value type of parameter %1, expected %2 or %3.';"),
					"Filter", "Structure", "KeyAndValue");
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
		
		Return ClusterAdministrationCOM;
		
	ElsIf AdministrationParameters.AttachmentType = "RAS" Then
		
		Return ClusterAdministrationRAS;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unknown type of parameter %1: %2. Expected values: ""%3"" or ""%4"".';"),
			"AdministrationParameters", AdministrationParameters.AttachmentType, "COM", "RAS");
		
	EndIf;
	
EndFunction

Function DateEmpty() Export
	
	Return Date(1, 1, 1, 0, 0, 0);
	
EndFunction

Procedure SessionDataFromLock(SessionData, Val LockText, Val SessionKey, Val InfobaseName) Export
	
	TextLower = Lower(LockText);
	
	TextLower = StrReplace(TextLower, "db(",			"db(");
	TextLower = StrReplace(TextLower, "(session,",		"(session,");
	TextLower = StrReplace(TextLower, ",shared",		",separable");
	TextLower = StrReplace(TextLower, ",exceptional",	",exceptional_");
	TextLower = StrReplace(TextLower, ",exclusive",	",exceptional_");
	
	If Left(TextLower, 9) = "db(session," Then
		LockValuesAsString = Mid(TextLower, StrFind(TextLower, "(") + 1, StrFind(TextLower, ")") - StrFind(TextLower, "(") - 1);
		LockValues = StringFunctionsClientServer.SplitStringIntoSubstringsArray(LockValuesAsString, ",");
		If LockValues.Count() >= 3
			And LockValues[0] = "session"
			And LockValues[1] = Lower(InfobaseName) Then
			
			If StrFind(LockValuesAsString, "'") > 0 Then
				SeparatorValue = Mid(LockValuesAsString, StrFind(LockValuesAsString, "'") + 1);
				SeparatorValue = Left(SeparatorValue, StrFind(SeparatorValue, "'") - 1);
			Else
				SeparatorValue = "";
			EndIf;
			
			SessionData[SessionKey] = New Structure("DBLockMode, Separator", LockValues[2], SeparatorValue);
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion
