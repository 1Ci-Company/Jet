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

// Sets the parameter that cancels the desktop form creating.
// The procedure is used if there is a need
// to interact with the user during the startup.
//
// Used from the StandardSubsystemsClient module procedure of the same name.
// The direct call on server has the meaning for reducing server call numbers
// if during preparing client parameters with Cached module it is already
// known that interactive processing is required.
//
// If the client parameter getting procedure directly calls this procedure,
// the state on the client is updated automatically, otherwise
// use the StandardSubsystemsClient module procedure of the same name
// to update it.
//
// Parameters:
//  Hide - Boolean - pass True to set the state
//           or False to clear it. You
//           can call the RefreshInterface method once the procedure is executed to recreate
//           the interface.
//
Procedure HideDesktopOnStart(Hide = True) Export
	
	If CurrentRunMode() = Undefined Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	// Saving or restoring the home page form content.
	ObjectKey         = "Common/HomePageSettings";
	StorageObjectKey = "Common/HomePageSettingsBeforeClear";
	SavedSettings = SystemSettingsStorage.Load(StorageObjectKey, "");
	
	If TypeOf(Hide) <> Type("Boolean") Then
		Hide = TypeOf(SavedSettings) = Type("ValueStorage");
	EndIf;
	
	If Hide Then
		If TypeOf(SavedSettings) <> Type("ValueStorage") Then
			CurrentSettings = SystemSettingsStorage.Load(ObjectKey);
			SavingSettings = New ValueStorage(CurrentSettings);
			SystemSettingsStorage.Save(StorageObjectKey, "", SavingSettings);
		EndIf;
		StandardSubsystemsServer.SetBlankFormOnHomePage();
	Else
		If TypeOf(SavedSettings) = Type("ValueStorage") Then
			SavedSettings = SavedSettings.Get();
			If SavedSettings = Undefined Then
				SystemSettingsStorage.Delete(ObjectKey, Undefined,
					InfoBaseUsers.CurrentUser().Name);
			Else
				SystemSettingsStorage.Save(ObjectKey, "", SavedSettings);
			EndIf;
			SystemSettingsStorage.Delete(StorageObjectKey, Undefined,
				InfoBaseUsers.CurrentUser().Name);
		EndIf;
	EndIf;
	
	CurrentParameters = New Map(SessionParameters.ClientParametersAtServer);
	
	If Hide Then
		CurrentParameters.Insert("HideDesktopOnStart", True);
		
	ElsIf CurrentParameters.Get("HideDesktopOnStart") <> Undefined Then
		CurrentParameters.Delete("HideDesktopOnStart");
	EndIf;
	
	SessionParameters.ClientParametersAtServer = New FixedMap(CurrentParameters);
	
EndProcedure

// See CommonInternalClientServer.CalculationCellsIndicators.
Function CalculationCellsIndicators(Val SpreadsheetDocument, SelectedAreas, UUID = Undefined) Export 
	
	If UUID = Undefined Then 
		Return CommonInternalClientServer.CalculationCellsIndicators(SpreadsheetDocument, SelectedAreas);
	EndIf;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Cell indicator calculation';");
	
	Return TimeConsumingOperations.ExecuteFunction(
		ExecutionParameters, 
		"CommonInternalClientServer.CalculationCellsIndicators",
		SpreadsheetDocument,
		SelectedAreas);
	
EndFunction

// See InformationRegisters.UsersInfo.ProcessAnswerOnDisconnectingOpenIDConnect
Procedure ProcessAnswerOnDisconnectingOpenIDConnect(Disconnect) Export
	
	// ACC:277-off - The "StandardSubsystemsServerCall" is used to
	// avoid creating "UsersServerCall" for one procedure.
	InformationRegisters.UsersInfo.ProcessAnswerOnDisconnectingOpenIDConnect(Disconnect);
	// ACC:277-on
	
EndProcedure

// See UsersInternal.AreCurrentUserRolesReduced
Function AreCurrentUserRolesReduced() Export
	Return UsersInternal.AreCurrentUserRolesReduced();
EndFunction

#EndRegion

#Region Private

// Returns the structure of parameters required for the operation of the client code configuration,
// that is in the BeforeStart, OnStart event handlers.
//
// To be called only from StandardSubsystemsClientCached.ClientParametersOnStart.
//
Function ClientParametersOnStart(Parameters) Export
	
	NewParameters = New Structure;
	AddTimeAdjustments(NewParameters, Parameters);
	HandleClientParametersAtServer(Parameters);
	
	StoreTempParameters(Parameters);
	CommonClientServer.SupplementStructure(Parameters, NewParameters);
	
	If Parameters.RetrievedClientParameters <> Undefined Then
		If Not Parameters.Property("SkipClearingDesktopHiding") Then
			// Update the desktop's hide state if the previous startup crashed
			// before running a restoration with the built-in mechanisms.
			HideDesktopOnStart(Undefined);
		EndIf;
	EndIf;
	
	If Not StandardSubsystemsServer.AddClientParametersOnStart(Parameters) Then
		Return FixedClientParametersWithoutTemporaryParameters(Parameters);
	EndIf;
	
	If Parameters.SeparatedDataUsageAvailable Then
		UsersInternal.OnAddClientParametersOnStart(Parameters, Undefined, False);
	EndIf;
	
	SSLSubsystemsIntegration.OnAddClientParametersOnStart(Parameters);
	
	If Parameters.SeparatedDataUsageAvailable Then
		AppliedParameters = New Structure;
		CommonOverridable.OnAddClientParametersOnStart(AppliedParameters);
		For Each Parameter In AppliedParameters Do
			Parameters.Insert(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
	
	Return FixedClientParametersWithoutTemporaryParameters(Parameters);
	
EndFunction

// Returns the structure of parameters required for the operation of the client code configuration. 
// To be called only from StandardSubsystemsClientCached.ClientRunParameters.
//
Function ClientRunParameters(ClientProperties) Export
	
	Parameters = New Structure;
	AddTimeAdjustments(Parameters, ClientProperties);
	HandleClientParametersAtServer(ClientProperties);
	
	SSLSubsystemsIntegration.OnAddClientParameters(Parameters);
	
	AppliedParameters = New Structure;
	CommonOverridable.OnAddClientParameters(AppliedParameters);
	For Each Parameter In AppliedParameters Do
		Parameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	
	Return Common.FixedData(Parameters);
	
EndFunction

// See SaaSOperations.SignInToDataArea.
Procedure SignInToDataArea(Val DataArea) Export
	
	If Common.SubsystemExists("CloudTechnology.Core") Then
		ModuleSaaSOperations = Common.CommonModule("SaaSOperations");
		ModuleSaaSOperations.SignInToDataArea(DataArea);
	EndIf;
	
EndProcedure

// Checks the right to disable the system logic and
// hides the desktop on the server if there is the right,
// otherwise an exception is thrown.
// 
Procedure CheckDisableStartupLogicRight(ClientProperties) Export
	
	HandleClientParametersAtServer(ClientProperties);
	HideDesktopOnStart(True);
	
	LoginDataArea = Common.DataSeparationEnabled()
		And Common.SeparatedDataUsageAvailable();
	
	If Not LoginDataArea And Not AccessRight("Administration", Metadata)
		Or LoginDataArea And Not AccessRight("DataAdministration", Metadata) Then
		
		ErrorText = NStr("en = 'Insufficient rights to perform the operation.';");
	Else
		ErrorText = UsersInternal.ErrorCheckingTheRightsOfTheCurrentUserWhenLoggingIn();
	EndIf;
	
	If ValueIsFilled(ErrorText) Then
		ClientProperties.Insert("ErrorThereIsNoRightToDisableTheSystemStartupLogic", ErrorText);
	EndIf;
	
EndProcedure

// For internal use only.
Procedure WriteErrorToEventLogOnStartOrExit(Shutdown, Val Event, Val ErrorText) Export
	
	If Event = "Run" Then
		EventName = NStr("en = 'Startup';", Common.DefaultLanguageCode());
		If Shutdown Then
			ErrorDescriptionBeginning = NStr("en = 'Startup failed due to:';");
		Else
			ErrorDescriptionBeginning = NStr("en = 'Exception occurred during startup:';");
		EndIf;
	Else
		EventName = NStr("en = 'Exit';", Common.DefaultLanguageCode());
		ErrorDescriptionBeginning = NStr("en = 'Exception occurred while exiting the app:';");
	EndIf;
	
	ErrorDescription = ErrorDescriptionBeginning + Chars.LF + Chars.LF + ErrorText;
	EventLog.AddMessageForEventLog(EventName, EventLogLevel.Error,,, ErrorDescription);

EndProcedure

// Returns full metadata object name by its type.
Function FullMetadataObjectName(Type) Export
	MetadataObject = Metadata.FindByType(Type);
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	Return MetadataObject.FullName();
EndFunction

// Returns a metadata object name by type.
//
// Parameters:
//  Source - Type - object.
//
// Returns:
//   String
//
Function MetadataObjectName(Type) Export
	MetadataObject = Metadata.FindByType(Type);
	If MetadataObject = Undefined Then
		Return Undefined;
	EndIf;
	Return MetadataObject.Name;
EndFunction

// See StandardSubsystemsServer.LibraryVersion.
Function LibraryVersion() Export
	
	Return StandardSubsystemsServer.LibraryVersion();
	
EndFunction

// Returns:
//  Array of String
//
Function NamesOfClientModules() Export
	
	Names = New Array;
	For Each MetadataObject In Metadata.CommonModules Do
		If MetadataObject.ClientManagedApplication
		   And Not MetadataObject.Global Then
			Names.Add(MetadataObject.Name);
		EndIf;
	EndDo;
	
	Return Names;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Predefined data processing.

// See StandardSubsystemsCached.RefsByPredefinedItemsNames
Function RefsByPredefinedItemsNames(FullMetadataObjectName) Export
	
	Return StandardSubsystemsCached.RefsByPredefinedItemsNames(FullMetadataObjectName);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// For the MetadataObjectIDs catalog.

// See Catalogs.MetadataObjectIDs.IDPresentation
Function MetadataObjectIDPresentation(Ref) Export
	
	Return Catalogs.MetadataObjectIDs.IDPresentation(Ref);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure AddTimeAdjustments(Parameters, ClientProperties)
	
	SessionDate = CurrentSessionDate();
	UniversalSessionDate = ToUniversalTime(SessionDate, SessionTimeZone());
	
	Parameters.Insert("SessionTimeOffset", SessionDate - ClientProperties.CurrentDateOnClient);
	Parameters.Insert("UniversalTimeCorrection", UniversalSessionDate - SessionDate);
	Parameters.Insert("StandardTimeOffset", StandardTimeOffset(SessionTimeZone()));
	Parameters.Insert("ClientDateOffset", CurrentUniversalDateInMilliseconds()
		- ClientProperties.CurrentUniversalDateInMillisecondsOnClient);
	
EndProcedure

Procedure StoreTempParameters(Parameters)
	
	Parameters.Insert("TempParameterNames", New Array);
	
	For Each KeyAndValue In Parameters Do
		TempParameterNames = Parameters.TempParameterNames; // Array
		TempParameterNames.Add(KeyAndValue.Key);
	EndDo;
	
EndProcedure

Procedure HandleClientParametersAtServer(Val Parameters)
	
	PrivilegedModeSetOnStart = PrivilegedMode();
	SetPrivilegedMode(True);
	
	If SessionParameters.ClientParametersAtServer.Get("TheFirstServerCallIsMade") <> True Then
		// First server call from client after start.
		ClientParameters = New Map(SessionParameters.ClientParametersAtServer);
		ClientParameters.Insert("TheFirstServerCallIsMade", True);
		ClientParameters.Insert("LaunchParameter", Parameters.LaunchParameter);
		ClientParameters.Insert("InfoBaseConnectionString", Parameters.InfoBaseConnectionString);
		ClientParameters.Insert("PrivilegedModeSetOnStart", PrivilegedModeSetOnStart);
		ClientParameters.Insert("IsWebClient", Parameters.IsWebClient);
		ClientParameters.Insert("IsMobileClient", Parameters.IsMobileClient);
		ClientParameters.Insert("IsLinuxClient", Parameters.IsLinuxClient);
		ClientParameters.Insert("IsMacOSClient", Parameters.IsMacOSClient);
		ClientParameters.Insert("IsWindowsClient", Parameters.IsWindowsClient);
		ClientParameters.Insert("ClientUsed", Parameters.ClientUsed);
		ClientParameters.Insert("RAM", Parameters.RAM);
		ClientParameters.Insert("BinDir", Parameters.BinDir);
		ClientParameters.Insert("ClientID", Parameters.ClientID);
		ClientParameters.Insert("MainDisplayResolotion", Parameters.MainDisplayResolotion);
		ClientParameters.Insert("SystemInfo", Parameters.SystemInfo);
		
		SessionParameters.ClientParametersAtServer = New FixedMap(ClientParameters);
		
		If StrFind(Lower(Parameters.LaunchParameter), Lower("StartInfobaseUpdate")) > 0 Then
			InfobaseUpdateInternal.SetInfobaseUpdateStartup(True);
		EndIf;
		
		If Not Common.DataSeparationEnabled() Then
			If ExchangePlans.MasterNode() <> Undefined
				Or ValueIsFilled(Constants.MasterNode.Get()) Then
				// Prevent an unwanted update of predefined data in a child node during:
				// - A startup with the master node temporarily disabled.
				// - A data restructuring when restoring the node.
				If GetInfoBasePredefinedData()
					<> PredefinedDataUpdate.DontAutoUpdate Then
					SetInfoBasePredefinedDataUpdate(
					PredefinedDataUpdate.DontAutoUpdate);
				EndIf;
				If ExchangePlans.MasterNode() <> Undefined
					And Not ValueIsFilled(Constants.MasterNode.Get()) Then
					// Saving the master node for recovery purpose.
					StandardSubsystemsServer.SaveMasterNode();
				EndIf;
			EndIf;
		EndIf;
		
		If StrFind(Parameters.LaunchParameter, "DisableSystemStartupLogic") = 0 Then
			InformationRegisters.ExtensionVersionParameters.OnFirstServerCall();
		EndIf;
	EndIf;

EndProcedure

Function FixedClientParametersWithoutTemporaryParameters(Parameters)
	
	ClientParameters = Parameters;
	Parameters = New Structure;
	
	For Each TemporaryParameterName In ClientParameters.TempParameterNames Do
		Parameters.Insert(TemporaryParameterName, ClientParameters[TemporaryParameterName]);
		ClientParameters.Delete(TemporaryParameterName);
	EndDo;
	Parameters.Delete("TempParameterNames");
	
	Parameters.HideDesktopOnStart =
		StandardSubsystemsServer.ClientParametersAtServer(False).Get(
			"HideDesktopOnStart") <> Undefined;
	
	Return Common.FixedData(ClientParameters);
	
EndFunction

Function TheComponentOfTheLatestVersion(Id, Location, AddIn) Export
	
	Return StandardSubsystemsServer.TheComponentOfTheLatestVersion(Id, Location, AddIn);
	
EndFunction

Function AppRestartTimeForApplyPatches() Export
	
	Return Common.CommonSettingsStorageLoad(
		"UserCommonSettings", 
		"AppRestartTimeForApplyPatches",,,
		UserName());
	
EndFunction

#EndRegion
