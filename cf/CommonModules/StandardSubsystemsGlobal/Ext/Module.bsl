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

// Continues starting the application in interaction with a user.
Procedure TheHandlerWaitsToStartInteractiveProcessingBeforeTheSystemStartsWorking() Export
	
	StandardSubsystemsClient.StartInteractiveProcessingBeforeStartingTheSystem();
	
EndProcedure

// Continues starting the application in interaction with a user.
Procedure OnStartIdleHandler() Export
	
	StandardSubsystemsClient.OnStart(, False);
	
EndProcedure

// Continues exiting in the mode of interactive interaction with the user
// after setting Cancel = True.
//
Procedure BeforeExitInteractiveHandlerIdleHandler() Export
	
	StandardSubsystemsClient.StartInteractiveHandlerBeforeExit();
	
EndProcedure

// Called when the application is started, opens the information window.
Procedure ShowInformationAfterStart() Export
	ModuleInformationOnStartClient = CommonClient.CommonModule("InformationOnStartClient");
	ModuleInformationOnStartClient.Show();
EndProcedure

// Called when the application is started, opens the security warning window.
Procedure ShowSecurityWarningAfterStart() Export
	UsersInternalClient.ShowSecurityWarningOnStartupIfNeeded();
EndProcedure

// Shows users a message about insufficient RAM.
Procedure ShowRAMRecommendation() Export
	StandardSubsystemsClient.NotifyLowMemory();
EndProcedure

// Displays a popup warning message about additional
// actions that have to be performed before exit the application.
//
Procedure ShowExitWarning() Export
	Warnings = StandardSubsystemsClient.ClientParameter("ExitWarnings");
	Explanation = NStr("en = 'and perform additional actions.';");
	If Warnings.Count() = 1 And Not IsBlankString(Warnings[0].HyperlinkText) Then
		Explanation = Warnings[0].HyperlinkText;
	EndIf;
	ShowUserNotification(NStr("en = 'Click here to exit';"), 
		"e1cib/command/CommonCommand.ExitWarnings",
		Explanation, PictureLib.ExitApplication, UserNotificationStatus.Important);
EndProcedure

Procedure RefreshInterfaceOnFunctionalOptionToggle() Export
	
	RefreshReusableValues();
	RefreshInterface();
	
EndProcedure

Procedure RestartingApplication() Export
	StandardSubsystemsClient.SkipExitConfirmation();
	Exit(True, True);
EndProcedure

Procedure NotificationFiveMinutesBeforeRestart() Export

	StandardSubsystemsClient.NotifyCurrentUserOfUpcomingRestart(300);

EndProcedure

Procedure NotificationThreeMinutesBeforeRestart() Export

	StandardSubsystemsClient.NotifyCurrentUserOfUpcomingRestart(180);

EndProcedure

Procedure NotificationOneMinuteBeforeRestart() Export

	StandardSubsystemsClient.NotifyCurrentUserOfUpcomingRestart(60);

EndProcedure

Procedure ControlRestartWhenAccessRightsReduced() Export
	UsersInternalClient.OnControlRestartWhenAccessRightsReduced();
EndProcedure

#EndRegion
