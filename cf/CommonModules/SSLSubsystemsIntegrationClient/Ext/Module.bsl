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

#Region ForCallsFromOtherSubsystems

#Region CTLEventHandlers
// Handle software events that occur in CTL subsystems.
// Intended only for calls from CTL to SSL.

// Defines events, to which this library is subscribed.
//
// Parameters:
//  Subscriptions - See CTLSubsystemsIntegration.EventsCTL.
//
Procedure OnDefineEventsSubscriptionsCTL(Subscriptions) Export
	
	
EndProcedure

#EndRegion

#Region OSLEventHandlers
// Handle software events that occur in Online Support subsystems.
// Intended only for calls from Online Support to SSL.

// Defines events, to which this library is subscribed.
//
// Parameters:
//  Subscriptions - Structure - structure property keys are names of events, to which
//           this library is subscribed.
//
Procedure OnDefineEventsSubscriptionsOSL(Subscriptions) Export

EndProcedure

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Deprecated. For proper integration with 1C-Connect, use the "Connect integration" subsystem
// (see Online Support Library version 2.4.2 or later).
//
Procedure IntegrationOnlineSupportCallClientNotificationProcessing(EventName, Item) Export
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Internal

#Region Core

// See CommonClientOverridable.BeforeStart
Procedure BeforeStart(Parameters) Export
	
	// Start measuring application start time.
	If CommonClient.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
		ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
		Parameters.Modules.Add(ModulePerformanceMonitorClient);
	EndIf;
	
	// Checking whether the user has minimum rights to access the application.
	Parameters.Modules.Add(UsersInternalClient);
	
	// Checking whether the infobase is locked for updating.
	Parameters.Modules.Add(InfobaseUpdateClient);
	
	// Checking whether the current version is equal or higher than the recommended one.
	Parameters.Modules.Add(New Structure("Module, Number", StandardSubsystemsClient, 2));
	
	// Checking whether reconnection the master node is necessary. 
	Parameters.Modules.Add(New Structure("Module, Number", StandardSubsystemsClient, 3));
	
	Parameters.Modules.Add(ServerNotificationsClient);
	
	// Checking whether it is necessary to select initial unchanged infobase settings (main language and time zone).
	Parameters.Modules.Add(New Structure("Module, Number", StandardSubsystemsClient, 4));

	// Checking whether updating the infobase is legal.
	If CommonClient.SubsystemExists(
		   "StandardSubsystems.SoftwareLicenseCheck") Then
		
		ModuleSoftwareLicenseCheckClient =
			CommonClient.CommonModule("SoftwareLicenseCheckClient");
		
		Parameters.Modules.Add(ModuleSoftwareLicenseCheckClient);
	EndIf;
	
	// Asking the user to continue with or without repeating data exchange message import.
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		Parameters.Modules.Add(ModuleDataExchangeClient);
	EndIf;
	
	// Checking the status for deferred update handler.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 2));
	
	// Exporting and updating application operating settings.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 3));
	
	// Initial standalone workstation setup.
	If CommonClient.SubsystemExists(
		"StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		
		ModuleStandaloneModeInternalClient = CommonClient.CommonModule("StandaloneModeInternalClient");
		Parameters.Modules.Add(ModuleStandaloneModeInternalClient);
	EndIf;
	
	// Checking user authorization.
	Parameters.Modules.Add(New Structure("Module, Number", UsersInternalClient, 2));
	
	// Checking for locks to access the infobase.
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		Parameters.Modules.Add(ModuleIBConnectionsClient);
	EndIf;
	
	// Updating an infobase.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 4));
	
	// Handling the UpdateAndExit startup key.
	Parameters.Modules.Add(New Structure("Module, Number", InfobaseUpdateClient, 5));
	
	// Change password or check the old password's strength if needed.
	Parameters.Modules.Add(New Structure("Module, Number", UsersInternalClient, 3));
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().BeforeStart Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.BeforeStart(Parameters);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().BeforeStart Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.BeforeStart(Parameters);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.OnStart
Procedure OnStart(Parameters) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
		Parameters.Modules.Add(ModuleReportsOptionsClient);
	EndIf;
	
	// Opening a subordinate DIB node on the initial start.
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		Parameters.Modules.Add(ModuleDataExchangeClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaSClient = CommonClient.CommonModule("DataExchangeSaaSClient");
		Parameters.Modules.Add(ModuleDataExchangeSaaSClient);
	EndIf;
	
	// Opening the change log.
	If CommonClient.SubsystemExists("StandardSubsystems.IBVersionUpdate") Then
		ModuleUpdatingInfobaseClient = CommonClient.CommonModule("InfobaseUpdateClient");
		Parameters.Modules.Add(ModuleUpdatingInfobaseClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		Parameters.Modules.Add(ModuleConfigurationUpdateClient);
	EndIf;
	
	// Showing the form tor manage external resources locks, if necessary.
	If CommonClient.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsClient = CommonClient.CommonModule("ScheduledJobsClient");
		Parameters.Modules.Add(ModuleScheduledJobsClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		Parameters.Modules.Add(ModuleIBBackupClient);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
		Parameters.Modules.Add(ModuleMonitoringCenterClientInternal);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Conversations") Then
		ModuleConversationsInternalClient = CommonClient.CommonModule("ConversationsInternalClient");
		Parameters.Modules.Add(ModuleConversationsInternalClient);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnStart Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnStart(Parameters);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnStart Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnStart(Parameters);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.AfterStart.
Procedure AfterStart() Export
	
	StandardSubsystemsClient.AfterStart();
	ServerNotificationsClient.AfterStart();
	
	If CommonClient.SubsystemExists("StandardSubsystems.Banks") Then
		ModuleBankManagerClient = CommonClient.CommonModule("BankManagerClient");
		ModuleBankManagerClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Currencies") Then
		ModuleCurrencyExchangeRatesClient = CommonClient.CommonModule("CurrencyRateOperationsClient");
		ModuleCurrencyExchangeRatesClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.InformationOnStart") Then
		ModuleInformationOnStartClient = CommonClient.CommonModule("InformationOnStartClient");
		ModuleInformationOnStartClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserReminders") Then
		ModuleUserReminderClient = CommonClient.CommonModule("UserRemindersClient");
		ModuleUserReminderClient.AfterStart();
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.DataExchange") Then
		ModuleDataExchangeClient = CommonClient.CommonModule("DataExchangeClient");
		ModuleDataExchangeClient.AfterStart();
	EndIf;
	
	InfobaseUpdateClient.AfterStart();
	UsersInternalClient.AfterStart();
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleExternalResourcePermissionsClient = CommonClient.CommonModule("ExternalResourcesPermissionsSetupClient");
		ModuleExternalResourcePermissionsClient.AfterStart();
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().AfterStart Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.AfterStart();
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().AfterStart Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.AfterStart();
	EndIf;
	
EndProcedure

// See CommonClientOverridable.LaunchParametersOnProcess.
Procedure LaunchParametersOnProcess(StartupParameters, Cancel) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.LaunchParametersOnProcess(StartupParameters, Cancel);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().LaunchParametersOnProcess Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.LaunchParametersOnProcess(StartupParameters, Cancel);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().LaunchParametersOnProcess Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.LaunchParametersOnProcess(StartupParameters, Cancel);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeExit.
Procedure BeforeExit(Cancel, Warnings) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UsersSessions") Then
		ModuleIBConnectionsClient = CommonClient.CommonModule("IBConnectionsClient");
		ModuleIBConnectionsClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then
		ModuleConfigurationUpdateClient = CommonClient.CommonModule("ConfigurationUpdateClient");
		ModuleConfigurationUpdateClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleDataExchangeSaaSClient = CommonClient.CommonModule("DataExchangeSaaSClient");
		ModuleDataExchangeSaaSClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
		ModuleFilesOperationsInternalClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().BeforeExit Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().BeforeExit Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.BeforeExit(Cancel, Warnings);
	EndIf;
	
EndProcedure

// See CommonClientOverridable.BeforeRecurringClientDataSendToServer
Procedure BeforeRecurringClientDataSendToServer(Parameters) Export
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		StandardSubsystemsClient.BeforeRecurringClientDataSendToServer(Parameters);
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"StandardSubsystemsClient.BeforeRecurringClientDataSendToServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If CommonClient.SubsystemExists("StandardSubsystems.PerformanceMonitor") Then
			ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
			ModulePerformanceMonitorClient.BeforeRecurringClientDataSendToServer(Parameters);
		EndIf;
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"PerformanceMonitorClient.BeforeRecurringClientDataSendToServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
			ModuleMonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer(Parameters);
		EndIf;
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"MonitoringCenterClientInternal.BeforeRecurringClientDataSendToServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If SSLSubsystemsIntegrationClientCached.EDLSubscriptions().BeforeRecurringClientDataSendToServer Then
			ModuleEDLSubsystemsIntegrationClient = CommonClient.CommonModule("EDLSubsystemsIntegrationClient");
			ModuleEDLSubsystemsIntegrationClient.BeforeRecurringClientDataSendToServer(Parameters);
		EndIf;
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"EDLSubsystemsIntegrationClient.BeforeRecurringClientDataSendToServer");
	
EndProcedure

// See CommonClientOverridable.AfterRecurringReceiptOfClientDataOnServer
Procedure AfterRecurringReceiptOfClientDataOnServer(Results) Export
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		StandardSubsystemsClient.AfterRecurringReceiptOfClientDataOnServer(Results);
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"StandardSubsystemsClient.AfterRecurringReceiptOfClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If CommonClient.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
			ModuleMonitoringCenterClientInternal = CommonClient.CommonModule("MonitoringCenterClientInternal");
			ModuleMonitoringCenterClientInternal.AfterRecurringReceiptOfClientDataOnServer(Results);
		EndIf;
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"MonitoringCenterClientInternal.AfterRecurringReceiptOfClientDataOnServer");
	
	StartMoment = CurrentUniversalDateInMilliseconds();
	Try
		If SSLSubsystemsIntegrationClientCached.EDLSubscriptions().AfterRecurringReceiptOfClientDataOnServer Then
			ModuleEDLSubsystemsIntegrationClient = CommonClient.CommonModule("EDLSubsystemsIntegrationClient");
			ModuleEDLSubsystemsIntegrationClient.AfterRecurringReceiptOfClientDataOnServer(Results);
		EndIf;
	Except
		ServerNotificationsClient.HandleError(ErrorInfo());
	EndTry;
	ServerNotificationsClient.AddIndicator(StartMoment,
		"EDLSubsystemsIntegrationClient.AfterRecurringReceiptOfClientDataOnServer");
	
EndProcedure

#EndRegion

#Region ReportsOptions

// See ReportsClientOverridable.AfterGenerate.
Procedure AfterGenerate(ReportForm, ReportCreated) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().AfterGenerate Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.AfterGenerate(ReportForm, ReportCreated);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().AfterGenerate Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.AfterGenerate(ReportForm, ReportCreated);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.DetailProcessing.
Procedure OnProcessDetails(ReportForm, Item, Details, StandardProcessing) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternalClient =
			CommonClient.CommonModule("UserMonitoringInternalClient");
		ModuleUserMonitoringInternalClient.OnProcessDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.OnProcessDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternalClient = CommonClient.CommonModule("AccessManagementInternalClient");
		ModuleAccessManagementInternalClient.OnProcessDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessDetails Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessDetails Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.AdditionalDetailProcessing.
Procedure OnProcessAdditionalDetails(ReportForm, Item, Details, StandardProcessing) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternalClient =
			CommonClient.CommonModule("UserMonitoringInternalClient");
		ModuleUserMonitoringInternalClient.OnProcessAdditionalDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessAdditionalDetails Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessAdditionalDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessAdditionalDetails Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessAdditionalDetails(ReportForm,
			Item, Details, StandardProcessing);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.HandlerCommands.
Procedure OnProcessCommand(ReportForm, Command, Result) Export
	
	InfobaseUpdateClient.OnProcessCommand(ReportForm, Command, Result);
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.OnProcessCommand(ReportForm, Command, Result);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternalClient = CommonClient.CommonModule("DigitalSignatureInternalClient");
		ModuleDigitalSignatureInternalClient.OnProcessCommand(ReportForm, Command, Result);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessCommand Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessCommand(ReportForm, Command, Result);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessCommand Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessCommand(ReportForm, Command, Result);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.AtStartValueSelection.
Procedure AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.UserMonitoring") Then
		ModuleUserMonitoringInternalClient = CommonClient.CommonModule("UserMonitoringInternalClient");
		ModuleUserMonitoringInternalClient.AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternalClient = CommonClient.CommonModule("AccessManagementInternalClient");
		ModuleAccessManagementInternalClient.AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().AtStartValueSelection Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().AtStartValueSelection Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.AtStartValueSelection(ReportForm, SelectionConditions, ClosingNotification1, StandardProcessing);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.ChoiceProcessing.
Procedure OnProcessChoice(ReportForm, ValueSelected, ChoiceSource, Result) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessChoice Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessChoice(ReportForm, ValueSelected, ChoiceSource, Result);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessChoice Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessChoice(ReportForm, ValueSelected, ChoiceSource, Result);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.SpreadsheetDocumentSelectionHandler.
Procedure OnProcessSpreadsheetDocumentSelection(ReportForm, Item, Area, StandardProcessing) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.DocumentRecordsReport") Then
		ModuleDocumentRecordsReportInternalClient = CommonClient.CommonModule("DocumentRecordsReportInternalClient");
		ModuleDocumentRecordsReportInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccountingAudit") Then
		ModuleAccountingAuditInternalClient = CommonClient.CommonModule("AccountingAuditInternalClient");
		ModuleAccountingAuditInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternalClient = CommonClient.CommonModule("AccessManagementInternalClient");
		ModuleAccessManagementInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClient= CommonClient.CommonModule("FilesOperationsInternalClient");
		ModuleFilesOperationsInternalClient.SpreadsheetDocumentSelectionHandler(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessSpreadsheetDocumentSelection Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessSpreadsheetDocumentSelection(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessSpreadsheetDocumentSelection Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessSpreadsheetDocumentSelection(ReportForm, Item, Area, StandardProcessing);
	EndIf;
	
	InfobaseUpdateClient.OnProcessSpreadsheetDocumentSelection(ReportForm, Item, Area, StandardProcessing);
	
EndProcedure

// See ReportsClientOverridable.NotificationProcessing.
Procedure OnProcessNotification(ReportForm, EventName, Parameter, Source, NotificationProcessed) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnProcessNotification Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnProcessNotification(ReportForm, EventName, Parameter, Source, NotificationProcessed);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnProcessNotification Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnProcessNotification(ReportForm, EventName, Parameter, Source, NotificationProcessed);
	EndIf;
	
EndProcedure

// See ReportsClientOverridable.OnClickPeriodSelectionButton.
Procedure OnClickPeriodSelectionButton(ReportForm, Period, StandardProcessing, ResultHandler) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnClickPeriodSelectionButton Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnClickPeriodSelectionButton(ReportForm, Period, StandardProcessing, ResultHandler);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnClickPeriodSelectionButton Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnClickPeriodSelectionButton(ReportForm, Period, StandardProcessing, ResultHandler);
	EndIf;
	
EndProcedure

#EndRegion

#Region UsersSessions

// Called upon session termination using the UsersSessions subsystem.
//
// Parameters:
//  OwnerForm - ClientApplicationForm - used to terminate the session,
//  SessionsNumbers - Number - a number 8 characters long, a number of the session to terminate,
//  StandardProcessing - Boolean - Indicates whether standard session termination processing is executed
//    (connection to the server agent via COM connection or administration server
//    requesting cluster connection parameters from the current user). Can be
//    set to False in the event handler. In this case, standard
//    session termination processing is not performed,
//  NotificationAfterTerminateSession - NotifyDescription - the procedure
//    called after the session is terminated (to automatically refresh the active
//    user list). If the StandardProcessing parameter value is set to False,
//    once the session is terminated, use the ExecuteNotificationProcessing method
//    to execute a data processor for the passed notification details. Pass DialogReturnCode.OK
//    as the Result parameter value if the session
//    is terminated successfully). You can omit the parameter and skip
//    the notification processing.
//
Procedure OnEndSessions(OwnerForm, Val SessionsNumbers, StandardProcessing, Val NotificationAfterTerminateSession = Undefined) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnEndSessions Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnEndSessions(OwnerForm, SessionsNumbers, StandardProcessing, NotificationAfterTerminateSession);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnEndSessions Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnEndSessions(OwnerForm, SessionsNumbers, StandardProcessing, NotificationAfterTerminateSession);
	EndIf;
	
EndProcedure

#EndRegion

#Region Print

// See PrintManagementClientOverridable.PrintDocumentsAfterOpen.
Procedure PrintDocumentsAfterOpen(Form) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().PrintDocumentsAfterOpen Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.PrintDocumentsAfterOpen(Form);
	EndIf;
		
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().PrintDocumentsAfterOpen Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.PrintDocumentsAfterOpen(Form);
	EndIf;
	
EndProcedure

// See PrintManagementClientOverridable.PrintDocumentsURLProcessing.
Procedure PrintDocumentsURLProcessing(Form, Item, FormattedStringURL, StandardProcessing) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().PrintDocumentsURLProcessing Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.PrintDocumentsURLProcessing(
			Form, Item, FormattedStringURL, StandardProcessing);
	EndIf;
		
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().PrintDocumentsURLProcessing Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.PrintDocumentsURLProcessing(
			Form, Item, FormattedStringURL, StandardProcessing);
	EndIf;
	
EndProcedure

// See PrintManagementClientOverridable.PrintDocumentsExecuteCommand.
Procedure PrintDocumentsExecuteCommand(Form, Command, ContinueExecutionAtServer, AdditionalParameters) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().PrintDocumentsExecuteCommand Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.PrintDocumentsExecuteCommand(
			Form, Command, ContinueExecutionAtServer, AdditionalParameters);
	EndIf;
		
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().PrintDocumentsExecuteCommand Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.PrintDocumentsExecuteCommand(
			Form, Command, ContinueExecutionAtServer, AdditionalParameters);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.EDLSubscriptions().PrintDocumentsExecuteCommand Then
		ModuleEDLSubsystemsIntegrationClient = CommonClient.CommonModule("EDLSubsystemsIntegrationClient");
		ModuleEDLSubsystemsIntegrationClient.PrintDocumentsExecuteCommand(
			Form, Command, ContinueExecutionAtServer, AdditionalParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// See SafeModeManagerClientOverridable.OnConfirmRequestsToUseExternalResources.
Procedure OnConfirmRequestsToUseExternalResources(IDs, OwnerForm, ClosingNotification1, StandardProcessing) Export
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnConfirmRequestsToUseExternalResources Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnConfirmRequestsToUseExternalResources(IDs, 
			OwnerForm, ClosingNotification1, StandardProcessing);
	EndIf;
		
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnConfirmRequestsToUseExternalResources Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnConfirmRequestsToUseExternalResources(IDs, OwnerForm, ClosingNotification1, StandardProcessing);
	EndIf;
	
EndProcedure

#EndRegion

#Region IBBackup

// Checks whether a backup can be performed in user mode.
//
// Parameters:
//  Result - Boolean - a return value.
//
Procedure OnCheckIfCanBackUpInUserMode(Result) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.OnCheckIfCanBackUpInUserMode(Result);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnCheckIfCanBackUpInUserMode Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode(Result);
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnCheckIfCanBackUpInUserMode Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnCheckIfCanBackUpInUserMode(Result);
	EndIf;
	
EndProcedure

// Called when the user is prompted to back up.
Procedure OnPromptUserForBackup() Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.IBBackup") Then
		ModuleIBBackupClient = CommonClient.CommonModule("IBBackupClient");
		ModuleIBBackupClient.OnPromptUserForBackup();
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsCTL().OnPromptUserForBackup Then
		ModuleCTLSubsystemsIntegrationClient = CommonClient.CommonModule("CTLSubsystemsIntegrationClient");
		ModuleCTLSubsystemsIntegrationClient.OnPromptUserForBackup();
	EndIf;
	
	If SSLSubsystemsIntegrationClientCached.SubscriptionsOSL().OnPromptUserForBackup Then
		ModuleOSLSubsystemsIntegrationClient = CommonClient.CommonModule("OSLSubsystemsIntegrationClient");
		ModuleOSLSubsystemsIntegrationClient.OnPromptUserForBackup();
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

// Defines events, to which other libraries can subscribe.
//
// Returns:
//   Structure - structure property keys are names of events, to which
//               libraries can be subscribed.
//
Function SSLEvents() Export
	
	Events = New Structure;
	
	// Core
	Events.Insert("BeforeStart", False);
	Events.Insert("OnStart", False);
	Events.Insert("AfterStart", False);
	Events.Insert("LaunchParametersOnProcess", False);
	Events.Insert("BeforeExit", False);
	Events.Insert("BeforeRecurringClientDataSendToServer", False);
	Events.Insert("AfterRecurringReceiptOfClientDataOnServer", False);
	
	// ReportsOptions
	Events.Insert("AfterGenerate", False);
	Events.Insert("AtStartValueSelection", False);
	Events.Insert("OnProcessDetails", False);
	Events.Insert("OnProcessAdditionalDetails", False);
	Events.Insert("OnProcessCommand", False);
	Events.Insert("OnProcessChoice", False);
	Events.Insert("OnProcessSpreadsheetDocumentSelection", False);
	Events.Insert("OnProcessNotification", False);
	Events.Insert("OnClickPeriodSelectionButton", False);
	
	// UsersSessions
	Events.Insert("OnEndSessions", False);
	
	// PrintTools
	Events.Insert("PrintDocumentsAfterOpen", False);
	Events.Insert("PrintDocumentsURLProcessing", False);
	Events.Insert("PrintDocumentsExecuteCommand", False);
	
	// SecurityProfiles
	Events.Insert("OnConfirmRequestsToUseExternalResources", False);
	
	// IBBackup
	Events.Insert("OnCheckIfCanBackUpInUserMode", False);
	Events.Insert("OnPromptUserForBackup", False);
	
	Return Events;
	
EndFunction

#EndRegion