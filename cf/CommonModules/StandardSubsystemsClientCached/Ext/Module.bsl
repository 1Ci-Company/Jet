///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2024, OOO 1C-Soft
// All rights reserved. This software and the related materials 
// are licensed under a Creative Commons Attribution 4.0 International license (CC BY 4.0).
// To view the license terms, follow the link:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////
//
//

#Region Private

// See StandardSubsystemsClient.ClientParametersOnStart
// ().
Function ClientParametersOnStart() Export
	
	CheckIfAppStartupFinished(True);
	
	ApplicationStartParameters = ApplicationParameters["StandardSubsystems.ApplicationStartParameters"];
	
	Parameters = New Structure;
	Parameters.Insert("RetrievedClientParameters", Undefined);
	
	If ApplicationStartParameters.Property("RetrievedClientParameters")
		And TypeOf(ApplicationStartParameters.RetrievedClientParameters) = Type("Structure") Then
		
		Parameters.Insert("RetrievedClientParameters", CommonClient.CopyRecursive(
			ApplicationStartParameters.RetrievedClientParameters));
	EndIf;
	
	If ApplicationStartParameters.Property("SkipClearingDesktopHiding") Then
		Parameters.Insert("SkipClearingDesktopHiding");
	EndIf;
	
	If ApplicationStartParameters.Property("InterfaceOptions")
	   And TypeOf(Parameters.RetrievedClientParameters) = Type("Structure") Then
		
		Parameters.RetrievedClientParameters.Insert("InterfaceOptions");
	EndIf;
	
	StandardSubsystemsClient.FillInTheClientParametersOnTheServer(Parameters);
	
	ClientParameters = StandardSubsystemsServerCall.ClientParametersOnStart(Parameters);
	
	If ApplicationStartParameters.Property("RetrievedClientParameters")
		And ApplicationStartParameters.RetrievedClientParameters <> Undefined
		And Not ApplicationStartParameters.Property("InterfaceOptions") Then
		
		ApplicationStartParameters.Insert("InterfaceOptions", ClientParameters.InterfaceOptions);
	EndIf;
	
	StandardSubsystemsClient.FillClientParameters(ClientParameters);
	
	// Updating the desktop hiding status on client by the state on server.
	StandardSubsystemsClient.HideDesktopOnStart(
		Parameters.HideDesktopOnStart, True);
	
	Return ClientParameters;
	
EndFunction

// See StandardSubsystemsClient.ClientRunParameters
// ().
Function ClientRunParameters() Export
	
	CheckIfAppStartupFinished();
	
	ClientProperties = New Structure;
	StandardSubsystemsClient.FillInTheClientParametersOnTheServer(ClientProperties);
	ClientParameters = StandardSubsystemsServerCall.ClientRunParameters(ClientProperties);
	
	StandardSubsystemsClient.FillClientParameters(ClientParameters);
	
	Return ClientParameters;
	
EndFunction

// See StandardSubsystemsCached.RefsByPredefinedItemsNames
Function RefsByPredefinedItemsNames(FullMetadataObjectName) Export
	
	Return StandardSubsystemsServerCall.RefsByPredefinedItemsNames(FullMetadataObjectName);
	
EndFunction

Procedure CheckIfAppStartupFinished(OnlyBeforeSystemStartup = False)
	
	ParameterName = "StandardSubsystems.ApplicationStartCompleted";
	If ApplicationParameters[ParameterName] = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Exception occurred during startup.
			           |
			           |Technical details:
			           |Invalid call %1 during startup.
			           |The first procedure that is called from the %2 event handler must be %3.';"),
			"StandardSubsystemsClient.ClientRunParameters",
			"BeforeStart", 
			"StandardSubsystemsClient.BeforeStart");
		Raise ErrorText;
	EndIf;
	
	If OnlyBeforeSystemStartup Then
		Return;
	EndIf;
	
	If Not StandardSubsystemsClient.ApplicationStartCompleted() Then
		If StandardSubsystemsClient.ApplicationStartupLogicDisabled() Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The action is unavailable when running with the %1 parameter.';"),
				"DisableSystemStartupLogic");
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Exception occurred during startup.
			           |
			           |Technical details:
			           |Invalid call %1 during startup. Call %2 while the %3 procedure is not completed.
				       |The last called procedure is %4.';"),
				"StandardSubsystemsClient.ClientRunParameters", 
				"StandardSubsystemsClient.ClientParametersOnStart",
				"StandardSubsystemsClient.BeforeStart",
				StandardSubsystemsClient.FullNameOfLastProcedureBeforeStartingSystem());
		EndIf;
		Raise ErrorText;
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For the MetadataObjectIDs catalog.

// See Catalogs.MetadataObjectIDs.IDPresentation
Function MetadataObjectIDPresentation(Ref) Export
	
	Return StandardSubsystemsServerCall.MetadataObjectIDPresentation(Ref);
	
EndFunction

#EndRegion
