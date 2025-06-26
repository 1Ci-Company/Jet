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

// Executed on app startup (before opening the main window). 
// You can use the handler procedure to set up checks and the parameter that prevents opening the app. 
// It is intended for determining the list or warnings shown to the user before exit.
//
// During exiting the app, server calls are disabled and windows cannot be open.
// - It is an alternative to the BeforeStart handler.
// - In the SaaS mode, it is also called in the following cases:
// - On starting an Administrator session without separators specified.
// - When the Administrator signs on to a data area in a session without separators specified.
// To check the startup mode, see the CommonClient.SeparatedDataUsageAvailable function.
//
// Parameters:
//  Parameters - Structure:
//   * Cancel         - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - a return value. If True and the Cancel parameter
//                              is True, restarts the application.
// 
//   * AdditionalParametersOfCommandLine - String - a return value. Has a point when Cancel
//                              and Restart are True.
//
//   * InteractiveHandler - NotifyDescription - The return value. To open the window that prevents opening the app,
//                              assign the parameter to the details of the notification handler
//                              that opens the window. 
//
//   * ContinuationHandler   - NotifyDescription - If there is a window that prevents signing in to the app, the closure handler
//                              of this window must execute the ContinuationHandler notification. 
//
//   * Modules                 - Array - references to the modules that will run the procedure after the return.
//                              You can add modules only by calling an overridable module procedure.
//                              It helps to simplify the design where a sequence of asynchronous calls
//                              are made to a number of subsystems. See the example for SSLSubsystemsIntegrationClient.BeforeStart.
//
// Example:
//  The below code opens a window that blocks signing in to an application.
//
//		If OpenWindowOnStart Then
//			Parameter.InteractiveHandler = New NotificationDetails("OpenWindow", ThisObject);
//		EndIf;
//
//	Procedure OpenWindow(Parameters, AdditionalParameters) Export
//		// Showing the window. Once the window is closed, calling the OpenWindowCompletion notification handler.
//		Notification = New NotificationDetails("OpenWindowCompletion", ThisObject, Parameters);
//		Form = OpenForm(… ,,, … Notification);
//		If Not Form.IsOpen() Then // If OnCreateAtServer Cancel is True.
//			ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		EndIf;
//	EndProcedure
//
//	Procedure OpenWindowCompletion(Result, Parameters) Export
//		…
//		ExecuteNotifyProcessing(Parameters.ContinuationHandler);
//		
//	EndProcedure
//
Procedure BeforeStart(Parameters) Export
	
EndProcedure

// Executed on app startup (after opening the main window). 
// The hander is intended for setting up actions that must be performed on startup. 
// For example, to open a form. An alternative to the OnStart handler.
//
// In the SaaS mode, it is also called in the following cases:
// - On starting an Administrator session without separators specified.
// - When the Administrator signs on to a data area in a session without separators specified.
// To check the startup mode, see the CommonClient.SeparatedDataUsageAvailable function.
//
// Parameters:
//  Parameters - Structure:
//   * Cancel         - Boolean - a return value. If True, the application is terminated.
//   * Restart - Boolean - a return value. If True and the Cancel parameter
//                              is True, restarts the application.
//
//   * AdditionalParametersOfCommandLine - String - a return value. Has a point
//                              when Cancel and Restart are True.
//
//   * InteractiveHandler - NotifyDescription - a return value. To open the window that locks the application
//                              start, pass the notification description handler
//                              that opens the window. See the BeforeStart for an example.
//
//   * ContinuationHandler   - NotifyDescription - If there is a window that prevents signing in to the app, the closure handler
//                              of this window must execute the ContinuationHandler notification.
//                              
//   * Modules                 - Array - references to the modules that will run the procedure after the return.
//                              You can add modules only by calling an overridable module procedure.
//                              It helps to simplify the design where a sequence of asynchronous calls
//                              are made to a number of subsystems. See the example for SSLSubsystemsIntegrationClient.BeforeStart.
//
Procedure OnStart(Parameters) Export
	
	
	
	
	
EndProcedure

// The procedure is called to process the application startup parameters
// passed in the "/C" command line. For example: 
// 1cv8.exe /C DebugMode;OpenAndClose
//
// Parameters:
//  StartupParameters  - Array of String - Semicolon-delimited strings in the start parameter
//                      passed to the configuration using the "/C" command line key.
//  Cancel             - Boolean - If True, the start is aborted.
//
Procedure LaunchParametersOnProcess(StartupParameters, Cancel) Export
	
EndProcedure

// The procedure is called on app startup, after OnStart handler is completed.
// Intended for calling idle handlers that are not part of the OnStart and OnExit handlers.
// You must use an idle handler to open forms because
//
// the home page is not open at the startup moment.
// This event is not intended to be used for user interactions (such as ShowQueryBox).
// Place the code of user interactions in the OnStart procedure.
// 
//
Procedure AfterStart() Export
	
EndProcedure

// Executed before exiting the app (before closing the main window). 
// You can use the handler procedure to set up checks and the parameter that prevents exiting the app. 
// It is intended for determining the list or warnings shown to the user before exit. 
// During exiting the app, server calls are disabled and windows cannot be open.
// It is an analogue of the BeforeExit handler. 
// In the SaaS mode, it is also called in the following cases:
//
// - On terminating an Administrator session without separators specified.
// - When the Administrator exits a data area in a session without separators specified.
// - To check the startup mode, see the CommonClient.SeparatedDataUsageAvailable function.
// 
//
// Parameters:
//  Cancel          - Boolean - If True, the application exit 
//                            is interrupted.
//  Warnings - Array of See StandardSubsystemsClient.WarningOnExit - 
//                            you can add information about the warning appearance and the next steps.
//
Procedure BeforeExit(Cancel, Warnings) Export
	
EndProcedure

// Intended for overriding the app title.
//
// Parameters:
//  ApplicationCaption - String - App title text.
//  OnStart          - Boolean - True if the procedure is called on the application start.
//                                 It is forbidden to call configuration server functions
//                                 that require the application start to be completed first. 
//                                 For example, instead of StandardSubsystemsClient.ClientRunParameters
//                                 use StandardSubsystemsClient.ClientRunParametersOnStart. 
//
// Example:
//  To display the project title on the application start, define parameter 
//  CurrentProject in the CommonOverridable.OnAddClientParameters procedure and add the following code:
//
//	If Not CommonClient.SeparatedDataUsageAvailable() Then 
//		Return;
//	EndIf;
//	ClientParameters = ?(OnStart, StandardSubsystemsClient.ClientRunParametersOnStart(),
//		StandardSubsystemsClient.ClientRunParameters());
//	If ClientParameters.Property("CurrentProject")
//	   And ValueIsFilled(ClientParameters.CurrentProject) Then
//		ApplicationCaption = String(ClientParameters.CurrentProject) + " / " + ApplicationCaption;
//	EndIf;
//
Procedure ClientApplicationCaptionOnSet(ApplicationCaption, OnStart) Export
	
	
	
EndProcedure

// The procedure is called from the global idle handler every 60 seconds
// to provide for centralized data transfer from client to server.
// For example, to transfer the open window statistics.
// To minimize the number of server calls, we don't recommend that you create custom global idle handlers.
// We recommend that you send data less often than every 60 seconds, based on actual needs
//
// (the recommended frequency is once every 20 minutes).
// To keep the client app responsive, we recommend that you transfer the adequate minimum amount of data.
// To send data from client to server, fill the "Parameters" parameter, which then will be passed to
// CommonOverridable.OnReceiptRecurringClientDataOnServer.
//
// 
// 
// 
//
// Parameters:
//  Parameters - Map of KeyAndValue:
//    * Key     - String       - Name of the parameter to send to the server.
//    * Value - Arbitrary - Value of the parameter to send to the server.
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
//			ModuleMonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer(Parameters);
//		EndIf;
//	Exception
//		ServerNotificationsClient.HandleError(ErrorInformation());
//	EndTry;
//	ServerNotificationsClient.AddIndicator(StartMoment,
//		"MonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer");
//
Procedure BeforeRecurringClientDataSendToServer(Parameters) Export
	
EndProcedure

// The procedure is called from the global idle handler every 60 seconds after the server returned an outcome.
// Intended for cases when the server transfers an outcome for handling on the client side.
// For example, a flag indicating that the next batch of statistics data should be transferred to the server.
//
// For the client to receive server-side outcome, the outcome must be passed in the "Results" parameter
// of the CommonOverridable.OnReceiptRecurringClientDataOnServer procedure.
// 
//
// Parameters:
//  Results - Map of KeyAndValue:
//    * Key     - String       - Name of the parameter returned by server.
//    * Value - Arbitrary - Value of the parameter returned by server.
//
// Example:
//	StartMoment = CurrentUniversalDateInMilliseconds();
//	Try
//		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
//			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
//			ModuleMonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer(Parameters);
//		EndIf;
//	Exception
//		ServerNotificationsClient.HandleError(ErrorInformation());
//	EndTry;
//	ServerNotificationsClient.AddIndicator(StartMoment,
//		"MonitoringCenterClientInternal.AfterRecurringReceiptOfClientDataOnServer");
//
Procedure AfterRecurringReceiptOfClientDataOnServer(Results) Export
	
EndProcedure

#EndRegion
